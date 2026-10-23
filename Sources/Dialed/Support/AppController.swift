import Foundation
import AppKit
import SwiftUI
import Combine
import DialedCore
import DialedPlatform

/// Connection state of the buds as shown in the menu bar and onboarding.
enum BudsState: Equatable {
    case searching
    case connected(name: String, isDefaultOutput: Bool)

    var isConnected: Bool { if case .connected = self { return true } else { return false } }
}

/// Wires the dial input, the gesture engine and every output together.
@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    // MARK: Published state

    @Published private(set) var settings: DialedSettings
    @Published private(set) var buds: BudsState = .searching
    @Published private(set) var accessibilityGranted = Permissions.accessibilityGranted
    @Published private(set) var currentMode: ModeID
    @Published private(set) var activeProfileID: UUID
    @Published private(set) var keepAliveRunning = false
    @Published private(set) var budsVolume: Float?
    @Published private(set) var launchAtLogin = LoginItem.isEnabled
    @Published var lastError: String?

    let diagnostics = DiagnosticsModel()
    let radial = RadialMenuController()
    let hud = HUDController()

    // MARK: Collaborators

    private let store = SettingsStore(url: SettingsStore.defaultURL)
    private let engine: DialEngine
    private let audio: BudsAudioMonitor
    private let decoder = VolumeClickDecoder()
    private let keepAlive = SilentKeepAlive()
    private let remote = RemoteCommandReceiver()
    private lazy var forwarder = MediaForwarder(receiver: remote)
    private let monitors = SystemMonitors()
    private let scroller = SmoothScroller()
    private let appSwitcher = AppSwitcher()
    private let brightness = BrightnessController()
    private var debouncer = PressDebouncer()

    /// The listening level the user chose; non-volume modes return the buds here.
    private var listeningLevel: Float?
    /// Presses arriving while we hand a media key to another player are our own echo.
    private var ignorePressesUntil: TimeInterval = 0
    private var timer: Timer?
    private var saveWork: DispatchWorkItem?
    private var tickCount = 0
    private var permissionWarned = false
    private var started = false

    private init() {
        let (loaded, warning) = store.load()
        settings = loaded
        engine = DialEngine(settings: loaded)
        currentMode = engine.mode
        activeProfileID = loaded.defaultProfile.id
        audio = BudsAudioMonitor(nameMatch: loaded.general.deviceNameMatch)
        lastError = warning
    }

    var enabled: Bool { settings.enabled }

    var activeProfile: Profile { settings.profile(id: activeProfileID) ?? settings.defaultProfile }

    var currentModeInfo: ModeInfo { settings.modeInfo(currentMode) }

    var isReady: Bool { enabled && buds.isConnected && accessibilityGranted }

    // MARK: Lifecycle

    func start() {
        guard !started else { return }
        started = true
        diagnostics.log(.system, "Dialed \(Bundle.main.shortVersion) started")

        audio.onVolume = { [weak self] level, time in self?.handleVolume(level, at: time) }
        audio.onDeviceChange = { [weak self] device in self?.handleDevice(device) }
        audio.onDefaultOutputChange = { [weak self] in self?.diagnostics.log(.system, "System output device changed") }
        remote.onCommand = { [weak self] command, time in self?.handleRemote(command, at: time) }
        forwarder.onError = { [weak self] message in self?.report(message) }
        radial.onMouseChoice = { [weak self] index in
            guard let self else { return }
            if let index { self.apply(self.engine.chooseMenuItem(at: index)) }
            else { self.apply(self.engine.closeMenu(selected: nil)) }
        }
        monitors.onWillSleep = { [weak self] in self?.handleSleep() }
        monitors.onDidWake = { [weak self] in self?.handleWake() }
        monitors.onFrontmostApp = { [weak self] app in self?.handleFrontmost(app) }
        monitors.onVolumeKey = { [weak self] in self?.decoder.noteVolumeKey(at: ProcessInfo.processInfo.systemUptime) }

        monitors.start()
        audio.start()
        if settings.enabled { activateInput() }

        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        if !settings.onboardingCompleted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { WindowManager.shared.showOnboarding() }
        }
    }

    func shutdown() {
        guard started else { return }
        appSwitcher.commit()
        scroller.stop()
        deactivateInput()
        audio.stop()
        monitors.stop()
        saveNow()
    }

    private func tick() {
        apply(engine.tick(now: ProcessInfo.processInfo.systemUptime))
        tickCount += 1
        if tickCount % 4 == 0 {
            let granted = Permissions.accessibilityGranted
            if granted != accessibilityGranted {
                accessibilityGranted = granted
                diagnostics.log(.system, granted ? "Accessibility permission granted" : "Accessibility permission removed")
                if granted { monitors.startKeyMonitor(); permissionWarned = false }
            }
            keepAliveRunning = keepAlive.isRunning
            launchAtLogin = LoginItem.isEnabled
        }
        // Another app that starts playing takes "now playing" (and with it the buds'
        // presses). Re-claim it every few seconds while Dialed is on.
        if tickCount % 12 == 0, settings.enabled, remote.isActive, !remote.isYielding,
           ProcessInfo.processInfo.systemUptime > ignorePressesUntil {
            remote.reassert()
        }
    }

    // MARK: Enable / disable

    func setEnabled(_ on: Bool) {
        guard on != settings.enabled else { return }
        update { $0.enabled = on }
        if on {
            activateInput()
            hud.show(.init(symbol: "dial.medium.fill", title: "Dialed on", subtitle: currentModeInfo.name), settings: settings)
        } else {
            deactivateInput()
            hud.show(.init(symbol: "dial.medium", title: "Dialed off", subtitle: "Buds control music normally"), settings: settings)
        }
    }

    /// Claim the buds' controls: become "now playing" and keep the audio link active.
    private func activateInput() {
        remote.title = currentModeInfo.name
        if let d = audio.device {
            remote.activate()
            keepAlive.start(on: d.id)
            decoder.reset(level: audio.volume)
            decoder.settle(until: ProcessInfo.processInfo.systemUptime + 0.8)
            listeningLevel = audio.volume
            moveToRestLevelIfNeeded()
        }
        keepAliveRunning = keepAlive.isRunning
        if let err = keepAlive.lastError { report("Couldn’t keep the buds’ audio link open: \(err)") }
        diagnostics.log(.system, audio.device == nil ? "Dialed on — waiting for the buds to connect"
                                                     : "Input active — Dialed receives the dial")
    }

    /// Give the buds back to macOS: presses and turns behave exactly as without Dialed.
    private func deactivateInput() {
        appSwitcher.commit()
        scroller.stop()
        radial.hide()
        _ = engine.closeMenu(selected: nil)
        remote.deactivate()
        keepAlive.stop()
        keepAliveRunning = false
        if let level = listeningLevel, let current = audio.volume, abs(current - level) > 0.001 {
            audio.setVolume(level)
        }
        diagnostics.log(.system, "Input released — buds control media normally")
    }

    // MARK: Input handling

    private func handleDevice(_ device: AudioOutputDevice?) {
        if let device {
            buds = .connected(name: device.name, isDefaultOutput: device.isDefaultOutput)
            budsVolume = audio.volume
            diagnostics.log(.system, "Buds connected: \(device.name) (device \(device.id))")
            decoder.reset(level: audio.volume)
            decoder.settle(until: ProcessInfo.processInfo.systemUptime + 1.5)
            listeningLevel = audio.volume
            engine.resetMotion()
            if settings.enabled {
                keepAlive.start(on: device.id)
                remote.activate()
                moveToRestLevelIfNeeded()
                hud.show(.init(symbol: "earbuds", title: "Buds connected", subtitle: currentModeInfo.name), settings: settings)
            }
        } else {
            let wasConnected = buds.isConnected
            buds = .searching
            budsVolume = nil
            keepAlive.stop()
            // Buds in the case: give media controls back to macOS and leave Now Playing.
            remote.deactivate()
            appSwitcher.commit()
            scroller.stop()
            radial.hide()
            _ = engine.closeMenu(selected: nil)
            if wasConnected {
                diagnostics.log(.warning, "Buds disconnected — waiting for them to come back")
                if settings.enabled {
                    hud.show(.init(symbol: "earbuds", title: "Buds disconnected", subtitle: "Dialed reconnects automatically", tint: .secondary), settings: settings)
                }
            }
        }
        keepAliveRunning = keepAlive.isRunning
    }

    private func handleVolume(_ level: Float, at time: TimeInterval) {
        budsVolume = level
        let raw = Int((Double(level) * 127).rounded())
        let result = decoder.ingest(level, at: time)
        switch result {
        case .click(let steps):
            diagnostics.log(.turn, "Click \(steps > 0 ? "⟳ +" : "⟲ ")\(steps)   (buds volume \(raw)/127)", uptime: time)
            diagnostics.observe(steps > 0 ? .turnForward : .turnBack, uptime: time)
            guard settings.enabled, remote.isActive else { listeningLevel = level; return }
            if currentMode.builtin?.usesDeviceVolume == true && engine.menu == nil {
                listeningLevel = level
            } else {
                restoreRestLevel(at: time)
            }
            if diagnostics.pauseActions { return }
            apply(engine.handle(.turn(steps: steps, at: time)))
        case .userChange(let v):
            listeningLevel = v
            diagnostics.log(.volume, "Volume set to \(Int(v * 100))% outside the dial", uptime: time)
        case .echo:
            diagnostics.log(.volume, "Restored level confirmed (\(raw)/127)", uptime: time)
        case .ignored(let reason):
            if reason != "unchanged" { diagnostics.log(.volume, "Volume \(raw)/127 ignored: \(reason)", uptime: time) }
        }
    }

    private func handleRemote(_ command: RemoteCommand, at time: TimeInterval) {
        guard time >= ignorePressesUntil else {
            diagnostics.log(.press, "\(command.rawValue) ignored (our own forwarded media key)", uptime: time)
            return
        }
        guard let kind = debouncer.accept(command, at: time) else { return }
        diagnostics.log(.press, "\(kind.title) (macOS command: \(command.rawValue))", uptime: time)
        diagnostics.observe(.from(kind), uptime: time)
        guard settings.enabled, !diagnostics.pauseActions else { return }
        apply(engine.handle(.press(kind, at: time)))
    }

    /// Non-volume modes: put the buds back on the user's level after each click.
    private func restoreRestLevel(at time: TimeInterval) {
        let rest = VolumeGrid.restTarget(for: listeningLevel ?? 0.5)
        decoder.noteOwnWrite(rest, at: time)
        audio.setVolume(rest)
    }

    private func moveToRestLevelIfNeeded() {
        guard currentMode.builtin?.usesDeviceVolume != true, let current = audio.volume else { return }
        let rest = VolumeGrid.restTarget(for: listeningLevel ?? current)
        if abs(rest - current) > 0.001 {
            decoder.noteOwnWrite(rest, at: ProcessInfo.processInfo.systemUptime)
            audio.setVolume(rest)
        }
    }

    private func handleSleep() {
        diagnostics.log(.system, "Mac going to sleep — pausing dial input")
        appSwitcher.commit()
        scroller.stop()
        radial.hide()
        _ = engine.closeMenu(selected: nil)
        keepAlive.stop()
    }

    private func handleWake() {
        diagnostics.log(.system, "Mac woke — reconnecting to the buds")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            self.audio.refresh()
            self.decoder.reset(level: self.audio.volume)
            self.decoder.settle(until: ProcessInfo.processInfo.systemUptime + 1.5)
            self.engine.resetMotion()
            if self.settings.enabled, let d = self.audio.device {
                self.keepAlive.start(on: d.id)
                self.remote.activate()
            }
            self.keepAliveRunning = self.keepAlive.isRunning
        }
    }

    private func handleFrontmost(_ app: NSRunningApplication) {
        guard settings.general.autoProfileSwitching, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        guard let profile = ProfileResolver.profile(for: app.bundleIdentifier, in: settings.profiles),
              profile.id != activeProfileID else { return }
        activate(profile: profile, announce: true)
    }

    func activate(profile: Profile, announce: Bool) {
        activeProfileID = profile.id
        apply(engine.activate(profile: profile))
        diagnostics.log(.mode, "Profile “\(profile.name)” active")
        if announce {
            hud.show(.init(symbol: "person.crop.rectangle.stack", title: profile.name,
                           subtitle: "Profile · \(currentModeInfo.name)"), settings: settings)
        }
    }

    // MARK: Effects

    private func apply(_ effects: [DialEngine.Effect]) {
        for effect in effects { perform(effect) }
        currentMode = engine.mode
    }

    private func perform(_ effect: DialEngine.Effect) {
        switch effect {
        case .output(let command, let mode):
            execute(command, mode: mode)
        case .modeChanged(let to, let from):
            appSwitcher.commit()
            scroller.stop()
            currentMode = to
            remote.title = settings.modeName(to)
            if to != from { diagnostics.log(.mode, "Mode: \(settings.modeName(to))") }
            moveToRestLevelIfNeeded()
            let info = settings.modeInfo(to)
            hud.show(.init(symbol: info.symbol, title: info.name, subtitle: info.turnHint), settings: settings)
        case .menuOpened(let m):
            radial.show(state: m, settings: settings)
            diagnostics.log(.mode, "Radial menu opened")
        case .menuMoved(let m):
            radial.update(state: m)
            if settings.general.soundFeedback { NSSound(named: "Tink")?.play() }
        case .menuClosed(let selected):
            radial.hide(selected: selected)
            if selected != nil, settings.general.soundFeedback { NSSound(named: "Pop")?.play() }
        case .armed(let mode):
            hud.show(.init(symbol: "hand.raised.fill", title: "Turn again to use \(settings.modeName(mode))",
                           subtitle: "Ignored one click after a pause", tint: .secondary), settings: settings)
        case .run(let action):
            run(action)
        case .nothingToDo(let message):
            hud.show(.init(symbol: "info.circle", title: message, subtitle: nil, tint: .secondary), settings: settings)
        }
    }

    private func needsAccessibility() -> Bool {
        if accessibilityGranted { return false }
        if !permissionWarned {
            permissionWarned = true
            hud.show(.init(symbol: "lock.fill", title: "Accessibility needed",
                           subtitle: "Allow Dialed in Privacy & Security", tint: .red), settings: settings, force: true)
            diagnostics.log(.warning, "Output dropped: Accessibility permission not granted")
        }
        return true
    }

    private func execute(_ command: OutputCommand, mode: ModeID) {
        let info = settings.modeInfo(mode)
        switch command {
        case .key(let combo, let count):
            if needsAccessibility() { return }
            EventPoster.key(combo, count: count)
            hud.pulse(symbol: info.symbol, title: info.name, detail: "\(combo.displayString)\(count > 1 ? " ×\(count)" : "")", settings: settings)
        case .scroll(let points, let horizontal):
            if needsAccessibility() { return }
            scroller.add(points: points, horizontal: horizontal)
        case .toggleScrollAxis:
            hud.show(.init(symbol: engine.horizontalScroll ? "arrow.left.and.right" : "arrow.up.and.down",
                           title: engine.horizontalScroll ? "Horizontal scrolling" : "Vertical scrolling", subtitle: "Press again to switch"), settings: settings)
        case .volumeChanged:
            let level = audio.volume ?? 0
            hud.show(.init(symbol: level == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill", title: "Volume",
                           subtitle: "\(Int((level * 100).rounded()))%", level: Double(level)), settings: settings)
        case .brightness(let delta):
            let level = brightness.adjust(by: delta)
            hud.show(.init(symbol: "sun.max.fill", title: "Brightness",
                           subtitle: level.map { "\(Int(($0 * 100).rounded()))%" } ?? "Using brightness keys",
                           level: level.map(Double.init)), settings: settings)
        case .toggleDim:
            let level = brightness.toggleDim()
            hud.show(.init(symbol: "moon.fill", title: (level ?? 0) < 0.1 ? "Screen dimmed" : "Brightness restored",
                           subtitle: nil, level: level.map(Double.init)), settings: settings)
        case .appSwitch(let steps):
            if needsAccessibility() { return }
            appSwitcher.step(steps)
        case .appSwitchCommit:
            if appSwitcher.isHolding { appSwitcher.commit() }
            else { hud.show(.init(symbol: info.symbol, title: "Turn to pick an app first", subtitle: nil, tint: .secondary), settings: settings) }
        case .perform(let action, let count):
            for _ in 0..<max(1, min(count, 30)) { run(action) }
        }
    }

    // MARK: Actions

    func run(_ action: Action) {
        diagnostics.log(.action, action.summary(modeName: settings.modeName, macroName: settings.macroName))
        switch action {
        case .none:
            break
        case .keyboardShortcut(let combo):
            if needsAccessibility() { return }
            EventPoster.key(combo)
        case .media(let command):
            if needsAccessibility() { return }
            ignorePressesUntil = ProcessInfo.processInfo.systemUptime + 1.0
            forwarder.send(command)
            hud.show(.init(symbol: command.symbol, title: command.title, subtitle: nil), settings: settings)
        case .system(let command):
            if let error = SystemActions.perform(command) { report(error) }
        case .appleShortcut(let name):
            guard !name.isEmpty else { report("This press is set to run a Shortcut, but none is chosen. Pick one in Dialed Settings."); return }
            hud.show(.init(symbol: "square.2.layers.3d", title: name, subtitle: "Running Shortcut…"), settings: settings)
            ShortcutsRunner.run(named: name) { [weak self] error in
                if let error { self?.report(error) }
            }
        case .openApplication(let bundleID, let name):
            guard !bundleID.isEmpty else { report("No app chosen for “Open app”. Pick one in Dialed Settings."); return }
            Launcher.openApp(bundleID: bundleID) { [weak self] error in
                if let error { self?.report("Couldn’t open \(name): \(error)") }
            }
        case .openURL(let url):
            if let error = Launcher.openURL(url) { report(error) }
        case .typeText(let text):
            if needsAccessibility() { return }
            EventPoster.type(text)
        case .runMacro(let id):
            guard let macro = settings.macro(id: id) else { report("That macro was deleted."); return }
            runMacro(macro)
        case .switchMode, .openRadialMenu, .previousMode:
            let t = ProcessInfo.processInfo.systemUptime
            switch action {
            case .switchMode(let m): apply(engine.switchMode(m))
            case .openRadialMenu: apply(engine.openMenu(at: t))
            default: apply(engine.goBack())
            }
        case .toggleEnabled:
            setEnabled(!settings.enabled)
        }
    }

    func runMacro(_ macro: Macro) {
        let steps = macro.expanded(lookup: settings.macro(id:))
        hud.show(.init(symbol: macro.symbol, title: macro.name, subtitle: "Macro · \(steps.count) step\(steps.count == 1 ? "" : "s")"), settings: settings)
        var delay: TimeInterval = 0
        for step in steps {
            switch step {
            case .wait(let ms):
                delay += Double(ms) / 1000
            case .action(let a):
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.run(a) }
                delay += 0.05
            }
        }
    }

    func switchMode(_ id: ModeID) { apply(engine.switchMode(id)) }

    func openRadialMenu() { apply(engine.openMenu(at: ProcessInfo.processInfo.systemUptime)) }

    func report(_ message: String) {
        lastError = message
        diagnostics.log(.warning, message)
        hud.show(.init(symbol: "exclamationmark.triangle.fill", title: "Something went wrong", subtitle: message, tint: .red),
                 settings: settings, force: true)
    }

    // MARK: Settings

    func update(_ body: (inout DialedSettings) -> Void) {
        var s = settings
        body(&s)
        guard s != settings else { return }
        s.repair()
        settings = s
        engine.settings = s
        if let p = s.profile(id: activeProfileID) {
            engine.profile = p
        } else {
            activeProfileID = s.defaultProfile.id
            engine.profile = s.defaultProfile
        }
        if audio.nameMatch != s.general.deviceNameMatch {
            audio.nameMatch = s.general.deviceNameMatch
            audio.refresh()
        }
        scheduleSave()
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.saveNow() } }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        do { try store.save(settings) }
        catch { lastError = "Couldn’t save settings: \(error.localizedDescription)" }
    }

    func replaceSettings(_ new: DialedSettings) {
        var s = new
        s.onboardingCompleted = true
        let wasEnabled = settings.enabled
        update { $0 = s }
        activeProfileID = settings.defaultProfile.id
        engine.profile = settings.defaultProfile
        if wasEnabled != settings.enabled { settings.enabled ? activateInput() : deactivateInput() }
    }

    func resetToDefaults() {
        var s = DialedSettings()
        s.onboardingCompleted = true
        replaceSettings(s)
        hud.show(.init(symbol: "arrow.counterclockwise", title: "Settings reset", subtitle: nil), settings: settings)
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            try LoginItem.set(on)
        } catch {
            lastError = "macOS didn’t allow Launch at Login: \(error.localizedDescription). Move Dialed to Applications and try again."
        }
        launchAtLogin = LoginItem.isEnabled
    }

    func requestAccessibility() {
        Permissions.requestAccessibility()
        Permissions.openAccessibilitySettings()
    }

    var budsDevices: [AudioOutputDevice] { BudsAudioMonitor.outputDevices() }
    var brightnessDirect: Bool { brightness.hasDirectControl }
}
