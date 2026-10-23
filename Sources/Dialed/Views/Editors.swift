import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DialedCore
import DialedPlatform

/// Records a keyboard shortcut: click, then press the keys.
struct KeyRecorder: View {
    @Binding var combo: KeyCombo
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? "Press a shortcut…" : combo.displayString)
                .font(.system(.body, design: .rounded).weight(.medium))
                .frame(minWidth: 110)
                .foregroundStyle(recording ? Theme.accent : .primary)
        }
        .help(recording ? "Press keys now, or click to cancel" : "Click to record a new shortcut")
        .accessibilityLabel("Shortcut \(combo.displayString)")
        .accessibilityHint("Activate, then press the key combination")
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard !KeyCode.isModifier(event.keyCode) else { return event }
            var m: Modifiers = []
            let f = event.modifierFlags
            if f.contains(.command) { m.insert(.command) }
            if f.contains(.option) { m.insert(.option) }
            if f.contains(.control) { m.insert(.control) }
            if f.contains(.shift) { m.insert(.shift) }
            combo = KeyCombo(event.keyCode, m)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }
}

/// Grid of curated SF Symbols.
struct SymbolPicker: View {
    @Binding var symbol: String
    @State private var open = false

    static let symbols = [
        "dial.medium", "speaker.wave.2.fill", "arrow.up.and.down", "music.note", "film", "sun.max.fill",
        "plus.magnifyingglass", "square.on.square", "play.rectangle.fill", "square.grid.2x2.fill",
        "macwindow.on.rectangle", "arrow.uturn.backward", "wand.and.stars", "bolt.fill", "star.fill",
        "heart.fill", "bookmark.fill", "flag.fill", "bell.fill", "moon.fill", "camera.fill", "mic.fill",
        "message.fill", "envelope.fill", "calendar", "clock.fill", "timer", "keyboard", "command",
        "text.cursor", "character.cursor.ibeam", "paintbrush.fill", "pencil", "scissors", "doc.fill",
        "folder.fill", "tray.fill", "globe", "link", "safari.fill", "terminal.fill", "hammer.fill",
        "gamecontroller.fill", "headphones", "earbuds", "lightbulb.fill", "house.fill", "cart.fill",
        "chart.bar.fill", "lock.fill", "eye.fill", "hand.thumbsup.fill", "sparkles", "square.2.layers.3d",
        "rectangle.3.group", "arrow.left.arrow.right", "chevron.left.forwardslash.chevron.right",
    ]

    var body: some View {
        Button { open.toggle() } label: {
            Image(systemName: symbol).frame(width: 22)
        }
        .accessibilityLabel("Icon")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 6), count: 8), spacing: 6) {
                    ForEach(Self.symbols, id: \.self) { s in
                        Button {
                            symbol = s
                            open = false
                        } label: {
                            Image(systemName: s)
                                .font(.system(size: 15))
                                .frame(width: 34, height: 34)
                                .background(s == symbol ? Theme.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(s)
                    }
                }
                .padding(10)
            }
            .frame(width: 330, height: 260)
        }
    }
}

/// Shared cache of the user's Apple Shortcuts.
final class ShortcutsCatalog: ObservableObject {
    static let shared = ShortcutsCatalog()
    @Published private(set) var names: [String] = []
    @Published private(set) var loaded = false

    func load(force: Bool = false) {
        guard force || !loaded else { return }
        ShortcutsRunner.list { [weak self] names in
            self?.names = names
            self?.loaded = true
        }
    }
}

/// Edits any `Action`, showing only the fields that action needs.
struct ActionEditor: View {
    @Binding var action: Action
    var allowEngineActions = true
    @EnvironmentObject private var app: AppController
    @ObservedObject private var shortcuts = ShortcutsCatalog.shared

    private var kinds: [ActionKind] {
        ActionKind.allCases.filter { allowEngineActions || ![.openRadialMenu, .previousMode, .switchMode].contains($0) }
    }

    var body: some View {
        HStack(spacing: 8) {
            Picker("Action", selection: Binding(
                get: { action.kind },
                set: { action = $0.defaultAction(firstMacro: app.settings.macros.first?.id) })) {
                ForEach(kinds) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            detail
        }
    }

    @ViewBuilder private var detail: some View {
        switch action {
        case .keyboardShortcut(let combo):
            KeyRecorder(combo: Binding(get: { combo }, set: { action = .keyboardShortcut(combo: $0) }))
        case .media(let c):
            Picker("Command", selection: Binding(get: { c }, set: { action = .media(command: $0) })) {
                ForEach(MediaCommand.allCases, id: \.self) { Text($0.title).tag($0) }
            }.labelsHidden().fixedSize()
        case .system(let c):
            Picker("System action", selection: Binding(get: { c }, set: { action = .system(command: $0) })) {
                ForEach(SystemCommand.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
            }.labelsHidden().fixedSize()
        case .appleShortcut(let name):
            shortcutPicker(name)
        case .openApplication(_, let name):
            Button(name.isEmpty ? "Choose App…" : name) { chooseApp() }
        case .openURL(let url):
            TextField("https://", text: Binding(get: { url }, set: { action = .openURL(url: $0) }))
                .frame(minWidth: 180)
        case .typeText(let text):
            TextField("Text to type", text: Binding(get: { text }, set: { action = .typeText(text: $0) }))
                .frame(minWidth: 180)
        case .runMacro(let id):
            if app.settings.macros.isEmpty {
                Button("Create a macro…") { WindowManager.shared.showSettings(page: .macros) }
            } else {
                Picker("Macro", selection: Binding(get: { id }, set: { action = .runMacro(id: $0) })) {
                    ForEach(app.settings.macros) { Text($0.name).tag($0.id) }
                }.labelsHidden().fixedSize()
            }
        case .switchMode(let m):
            ModePicker(selection: Binding(get: { m }, set: { action = .switchMode(mode: $0) }))
        default:
            EmptyView()
        }
    }

    @ViewBuilder private func shortcutPicker(_ name: String) -> some View {
        if shortcuts.names.isEmpty {
            HStack {
                TextField("Shortcut name", text: Binding(get: { name }, set: { action = .appleShortcut(name: $0) }))
                    .frame(minWidth: 160)
                if !shortcuts.loaded { ProgressView().controlSize(.small) }
            }
            .onAppear { shortcuts.load() }
        } else {
            Picker("Shortcut", selection: Binding(get: { name }, set: { action = .appleShortcut(name: $0) })) {
                if name.isEmpty { Text("Choose…").tag("") }
                if !name.isEmpty && !shortcuts.names.contains(name) { Text("\(name) (missing)").tag(name) }
                ForEach(shortcuts.names, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            Button { shortcuts.load(force: true) } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
                .help("Reload Shortcuts")
                .accessibilityLabel("Reload Shortcuts")
        }
    }

    private func chooseApp() {
        guard let app = AppChooser.choose() else { return }
        action = .openApplication(bundleID: app.bundleID, name: app.name)
    }
}

/// Picker over every built-in and custom mode.
struct ModePicker: View {
    @Binding var selection: ModeID
    var title = "Mode"
    @EnvironmentObject private var app: AppController

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(app.settings.allModes, id: \.id) { info in
                Label(info.name, systemImage: info.symbol).tag(info.id)
            }
        }
        .fixedSize()
    }
}

/// Edits what a press does.
struct GestureBindingEditor: View {
    @Binding var binding: GestureBinding

    private enum Choice: String, CaseIterable, Identifiable {
        case modeDefault, openRadialMenu, previousMode, action
        var id: String { rawValue }
        var title: String {
            switch self {
            case .modeDefault: return "Mode’s own action"
            case .openRadialMenu: return "Open radial menu"
            case .previousMode: return "Back to previous mode"
            case .action: return "Custom action"
            }
        }
    }

    private var choice: Choice {
        switch binding {
        case .modeDefault: return .modeDefault
        case .openRadialMenu: return .openRadialMenu
        case .previousMode: return .previousMode
        case .action: return .action
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Picker("Does", selection: Binding(get: { choice }, set: { c in
                switch c {
                case .modeDefault: binding = .modeDefault
                case .openRadialMenu: binding = .openRadialMenu
                case .previousMode: binding = .previousMode
                case .action: binding = .action(.keyboardShortcut(combo: KeyCombo(KeyCode.space)))
                }
            })) {
                ForEach(Choice.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            if case .action(let a) = binding {
                ActionEditor(action: Binding(get: { a }, set: { binding = .action($0) }), allowEngineActions: false)
            }
        }
    }
}

enum AppChooser {
    /// Lets the user pick an app bundle; returns its bundle ID and display name.
    static func choose() -> AppRef? {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose an app"
        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return nil }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        return AppRef(bundleID: id, name: name)
    }

    /// Apps currently open, for quick picking.
    static var running: [AppRef] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .map { AppRef(bundleID: $0.bundleIdentifier!, name: $0.localizedName ?? $0.bundleIdentifier!) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func icon(for bundleID: String) -> NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }
}
