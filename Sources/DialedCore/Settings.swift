import Foundation

public struct Sensitivity: Codable, Hashable, Sendable {
    /// Pixels scrolled per dial click.
    public var scrollPixelsPerClick: Double = 160
    /// 0 = off … 1 = fast spins move up to 3×.
    public var acceleration: Double = 0.6
    /// Brightness change per click, 0…1.
    public var brightnessStep: Double = 0.0625
    /// Arrow-key presses per click in Video Seek.
    public var seekPressesPerClick: Int = 1
    /// Flip the dial direction for every mode.
    public var reverseDirection: Bool = false
    /// Scroll using the system "natural" direction (content follows the dial).
    public var naturalScroll: Bool = true

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Sensitivity()
        scrollPixelsPerClick = try c.decodeIfPresent(Double.self, forKey: .scrollPixelsPerClick) ?? d.scrollPixelsPerClick
        acceleration = try c.decodeIfPresent(Double.self, forKey: .acceleration) ?? d.acceleration
        brightnessStep = try c.decodeIfPresent(Double.self, forKey: .brightnessStep) ?? d.brightnessStep
        seekPressesPerClick = try c.decodeIfPresent(Int.self, forKey: .seekPressesPerClick) ?? d.seekPressesPerClick
        reverseDirection = try c.decodeIfPresent(Bool.self, forKey: .reverseDirection) ?? d.reverseDirection
        naturalScroll = try c.decodeIfPresent(Bool.self, forKey: .naturalScroll) ?? d.naturalScroll
    }

    /// Clamp everything into the ranges the UI offers.
    public func sanitized() -> Sensitivity {
        var s = self
        s.scrollPixelsPerClick = min(800, max(20, scrollPixelsPerClick))
        s.acceleration = min(1, max(0, acceleration))
        s.brightnessStep = min(0.25, max(0.01, brightnessStep))
        s.seekPressesPerClick = min(10, max(1, seekPressesPerClick))
        return s
    }
}

public enum HUDPosition: String, Codable, CaseIterable, Sendable {
    case bottom, top, center
    public var title: String { rawValue.capitalized }
}

public struct GeneralSettings: Codable, Hashable, Sendable {
    public var showHUD = true
    public var hudPosition: HUDPosition = .bottom
    public var autoProfileSwitching = true
    /// Seconds before an open radial menu closes on its own.
    public var radialTimeout: Double = 6
    /// When the radial menu times out on a mode, switch to it.
    public var radialTimeoutSelects = true
    public var accidentalTurnGuard = true
    public var guardIdleSeconds: Double = 20
    /// Case-insensitive part of the audio device name that identifies the buds.
    public var deviceNameMatch = "CMF Buds"
    /// Mode the app starts in.
    public var startMode: ModeID = BuiltinMode.volume.id
    /// Play a soft click when a radial menu item is chosen.
    public var soundFeedback = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = GeneralSettings()
        showHUD = try c.decodeIfPresent(Bool.self, forKey: .showHUD) ?? d.showHUD
        hudPosition = try c.decodeIfPresent(HUDPosition.self, forKey: .hudPosition) ?? d.hudPosition
        autoProfileSwitching = try c.decodeIfPresent(Bool.self, forKey: .autoProfileSwitching) ?? d.autoProfileSwitching
        radialTimeout = try c.decodeIfPresent(Double.self, forKey: .radialTimeout) ?? d.radialTimeout
        radialTimeoutSelects = try c.decodeIfPresent(Bool.self, forKey: .radialTimeoutSelects) ?? d.radialTimeoutSelects
        accidentalTurnGuard = try c.decodeIfPresent(Bool.self, forKey: .accidentalTurnGuard) ?? d.accidentalTurnGuard
        guardIdleSeconds = try c.decodeIfPresent(Double.self, forKey: .guardIdleSeconds) ?? d.guardIdleSeconds
        deviceNameMatch = try c.decodeIfPresent(String.self, forKey: .deviceNameMatch) ?? d.deviceNameMatch
        startMode = try c.decodeIfPresent(ModeID.self, forKey: .startMode) ?? d.startMode
        soundFeedback = try c.decodeIfPresent(Bool.self, forKey: .soundFeedback) ?? d.soundFeedback
    }
}

/// Everything the user can configure. Stored as JSON; unknown or missing keys fall
/// back to defaults so older exports keep importing.
public struct DialedSettings: Codable, Hashable, Sendable {
    public static let currentSchema = 1

    public var schemaVersion = DialedSettings.currentSchema
    public var enabled = true
    public var onboardingCompleted = false
    public var general = GeneralSettings()
    public var sensitivity = Sensitivity()
    public var customModes: [CustomMode] = []
    public var macros: [Macro] = []
    /// First profile is the default profile and always exists.
    public var profiles: [Profile] = [DialedSettings.makeDefaultProfile()]

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        onboardingCompleted = try c.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        general = try c.decodeIfPresent(GeneralSettings.self, forKey: .general) ?? GeneralSettings()
        sensitivity = try c.decodeIfPresent(Sensitivity.self, forKey: .sensitivity) ?? Sensitivity()
        customModes = try c.decodeIfPresent([CustomMode].self, forKey: .customModes) ?? []
        macros = try c.decodeIfPresent([Macro].self, forKey: .macros) ?? []
        profiles = try c.decodeIfPresent([Profile].self, forKey: .profiles) ?? []
        if profiles.isEmpty { profiles = [DialedSettings.makeDefaultProfile()] }
    }

    public static func makeDefaultProfile() -> Profile {
        Profile(name: "Everywhere", radialItems: Profile.defaultRadialItems)
    }

    /// Ready-made profiles offered in Settings → Profiles.
    public static func suggestedProfiles() -> [Profile] {
        [
            Profile(name: "Presentations",
                    apps: [AppRef(bundleID: "com.apple.iWork.Keynote", name: "Keynote"),
                           AppRef(bundleID: "com.microsoft.Powerpoint", name: "PowerPoint")],
                    startMode: BuiltinMode.slides.id,
                    radialItems: [.mode(.slides), .mode(.volume), .mode(.brightness), .mode(.zoom)]),
            Profile(name: "Browsing",
                    apps: [AppRef(bundleID: "com.apple.Safari", name: "Safari"),
                           AppRef(bundleID: "com.google.Chrome", name: "Google Chrome"),
                           AppRef(bundleID: "company.thebrowser.Browser", name: "Arc")],
                    startMode: BuiltinMode.scroll.id,
                    radialItems: [.mode(.scroll), .mode(.tabs), .mode(.zoom), .mode(.video), .mode(.volume)]),
            Profile(name: "Video",
                    apps: [AppRef(bundleID: "com.apple.QuickTimePlayerX", name: "QuickTime Player"),
                           AppRef(bundleID: "org.videolan.vlc", name: "VLC"),
                           AppRef(bundleID: "com.colliderli.iina", name: "IINA")],
                    startMode: BuiltinMode.video.id,
                    radialItems: [.mode(.video), .mode(.volume), .mode(.brightness)]),
        ]
    }

    // MARK: Lookups

    public var defaultProfile: Profile { profiles[0] }

    public func profile(id: UUID) -> Profile? { profiles.first { $0.id == id } }
    public func macro(id: UUID) -> Macro? { macros.first { $0.id == id } }
    public func customMode(id: UUID) -> CustomMode? { customModes.first { $0.id == id } }

    public func modeInfo(_ id: ModeID) -> ModeInfo {
        if let b = id.builtin {
            return ModeInfo(id: id, name: b.name, symbol: b.symbol, turnHint: b.turnHint, pressHint: b.pressHint)
        }
        if let uuid = id.customID, let m = customMode(id: uuid) {
            let cw = m.clockwise.summary(modeName: modeName, macroName: macroName)
            let press = m.press == .none ? "" : "Press: " + m.press.summary(modeName: modeName, macroName: macroName)
            return ModeInfo(id: id, name: m.name, symbol: m.symbol, turnHint: "Turn: \(cw)", pressHint: press)
        }
        return .unknown(id)
    }

    public func modeExists(_ id: ModeID) -> Bool {
        id.builtin != nil || id.customID.flatMap(customMode(id:)) != nil
    }

    public func modeName(_ id: ModeID) -> String { modeInfo(id).name }
    public func macroName(_ id: UUID) -> String { macro(id: id)?.name ?? "missing macro" }

    /// Every mode the user can pick, built-ins first.
    public var allModes: [ModeInfo] {
        BuiltinMode.allCases.map { modeInfo($0.id) } + customModes.map { modeInfo($0.modeID) }
    }

    public func isGuarded(_ id: ModeID) -> Bool {
        guard general.accidentalTurnGuard else { return false }
        if let b = id.builtin { return b.guardedByDefault }
        if let uuid = id.customID, let m = customMode(id: uuid) { return m.guarded }
        return false
    }

    public func label(for item: RadialItem) -> String {
        if let l = item.label, !l.isEmpty { return l }
        switch item.target {
        case .mode(let m): return modeName(m)
        case .action(let a): return a.summary(modeName: modeName, macroName: macroName)
        }
    }

    public func symbol(for item: RadialItem) -> String {
        if let s = item.symbol, !s.isEmpty { return s }
        switch item.target {
        case .mode(let m): return modeInfo(m).symbol
        case .action(.runMacro(let id)): return macro(id: id)?.symbol ?? "wand.and.stars"
        case .action(let a): return a.symbol
        }
    }

    // MARK: Validation

    /// Repairs references to deleted modes/macros and clamps values. Returns notes
    /// describing what was fixed so imports can tell the user.
    @discardableResult
    public mutating func repair() -> [String] {
        var notes: [String] = []
        sensitivity = sensitivity.sanitized()
        general.radialTimeout = min(30, max(2, general.radialTimeout))
        general.guardIdleSeconds = min(300, max(3, general.guardIdleSeconds))
        if profiles.isEmpty { profiles = [Self.makeDefaultProfile()]; notes.append("Added a default profile.") }
        if !modeExists(general.startMode) {
            general.startMode = BuiltinMode.volume.id
            notes.append("Start mode was missing; reset to Volume.")
        }
        for i in profiles.indices {
            let items = profiles[i].radialItems
            let kept = items.filter { item in
                switch item.target {
                case .mode(let m): return modeExists(m)
                case .action(.runMacro(let id)): return macro(id: id) != nil
                case .action: return true
                }
            }
            profiles[i].radialItems = kept
            if kept.count != items.count {
                notes.append("Removed \(items.count - kept.count) radial item(s) from “\(profiles[i].name)” that pointed to deleted modes or macros.")
            }
            if profiles[i].radialItems.isEmpty { profiles[i].radialItems = [.mode(.volume)] }
            if let s = profiles[i].startMode, !modeExists(s) { profiles[i].startMode = nil }
            profiles[i].sensitivityScale = min(4, max(0.25, profiles[i].sensitivityScale))
        }
        if Set(profiles.map(\.id)).count != profiles.count {
            for i in profiles.indices.dropFirst() { profiles[i].id = UUID() }
            notes.append("Gave duplicate profiles new IDs.")
        }
        schemaVersion = Self.currentSchema
        return notes
    }
}
