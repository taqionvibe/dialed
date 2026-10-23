import Foundation

/// What a press does. `.modeDefault` lets the current mode decide (e.g. play/pause in
/// Volume, black screen in Slides).
public enum GestureBinding: Codable, Hashable, Sendable {
    case modeDefault
    case openRadialMenu
    case previousMode
    case action(Action)

    public func summary(modeName: (ModeID) -> String, macroName: (UUID) -> String) -> String {
        switch self {
        case .modeDefault: return "Mode’s own action"
        case .openRadialMenu: return "Open radial menu"
        case .previousMode: return "Back to previous mode"
        case .action(let a): return a.summary(modeName: modeName, macroName: macroName)
        }
    }
}

public struct GestureMap: Codable, Hashable, Sendable {
    public var single: GestureBinding
    public var double: GestureBinding
    public var triple: GestureBinding

    /// Defaults chosen in hardware testing: double press keeps its familiar
    /// "next track" meaning for your music, triple press opens the radial menu.
    public init(single: GestureBinding = .modeDefault,
                double: GestureBinding = .action(.media(command: .nextTrack)),
                triple: GestureBinding = .openRadialMenu) {
        self.single = single
        self.double = double
        self.triple = triple
    }

    public static let standard = GestureMap()

    public subscript(kind: PressKind) -> GestureBinding {
        get {
            switch kind {
            case .single: return single
            case .double: return double
            case .triple: return triple
            }
        }
        set {
            switch kind {
            case .single: single = newValue
            case .double: double = newValue
            case .triple: triple = newValue
            }
        }
    }
}

/// One slot on the radial menu.
public struct RadialItem: Codable, Hashable, Identifiable, Sendable {
    public enum Target: Codable, Hashable, Sendable {
        case mode(ModeID)
        case action(Action)
    }

    public var id: UUID
    public var target: Target
    /// Optional custom label / SF Symbol; nil uses the mode's or action's own.
    public var label: String?
    public var symbol: String?

    public init(id: UUID = UUID(), target: Target, label: String? = nil, symbol: String? = nil) {
        self.id = id
        self.target = target
        self.label = label
        self.symbol = symbol
    }

    public static func mode(_ m: BuiltinMode) -> RadialItem { RadialItem(target: .mode(m.id)) }
}

public struct AppRef: Codable, Hashable, Identifiable, Sendable {
    public var bundleID: String
    public var name: String
    public var id: String { bundleID }
    public init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }
}

/// A set of dial behaviours. The first profile in Settings is the default; others
/// are activated automatically when one of their apps comes to the front.
public struct Profile: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var apps: [AppRef]
    /// Mode to switch to when this profile becomes active (nil keeps the current mode).
    public var startMode: ModeID?
    public var gestures: GestureMap
    public var radialItems: [RadialItem]
    /// Per-profile override of the scroll / seek sensitivity multiplier (1 = global).
    public var sensitivityScale: Double

    public init(id: UUID = UUID(), name: String, apps: [AppRef] = [], startMode: ModeID? = nil,
                gestures: GestureMap = .standard, radialItems: [RadialItem],
                sensitivityScale: Double = 1) {
        self.id = id
        self.name = name
        self.apps = apps
        self.startMode = startMode
        self.gestures = gestures
        self.radialItems = radialItems
        self.sensitivityScale = sensitivityScale
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Profile"
        apps = try c.decodeIfPresent([AppRef].self, forKey: .apps) ?? []
        startMode = try c.decodeIfPresent(ModeID.self, forKey: .startMode)
        gestures = try c.decodeIfPresent(GestureMap.self, forKey: .gestures) ?? .standard
        radialItems = try c.decodeIfPresent([RadialItem].self, forKey: .radialItems) ?? Profile.defaultRadialItems
        sensitivityScale = try c.decodeIfPresent(Double.self, forKey: .sensitivityScale) ?? 1
    }

    public static let defaultRadialItems: [RadialItem] = [
        .mode(.volume), .mode(.scroll), .mode(.media), .mode(.video), .mode(.brightness),
        .mode(.zoom), .mode(.tabs), .mode(.apps), .mode(.undo),
    ]
}

/// Picks the profile for the frontmost app.
public enum ProfileResolver {
    public static func profile(for bundleID: String?, in profiles: [Profile]) -> Profile? {
        guard !profiles.isEmpty else { return nil }
        if let bundleID,
           let match = profiles.dropFirst().first(where: { $0.apps.contains { $0.bundleID == bundleID } }) {
            return match
        }
        return profiles.first
    }
}
