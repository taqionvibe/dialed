import Foundation

/// Stable identifier for a dial mode. Built-in modes use their case name; custom
/// modes use "custom.<uuid>".
public struct ModeID: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
    public var description: String { rawValue }

    public var builtin: BuiltinMode? { BuiltinMode(rawValue: rawValue) }
    public static func custom(_ id: UUID) -> ModeID { ModeID(rawValue: "custom.\(id.uuidString)") }
    public var customID: UUID? {
        guard rawValue.hasPrefix("custom.") else { return nil }
        return UUID(uuidString: String(rawValue.dropFirst(7)))
    }
}

/// The modes that ship with Dialed.
public enum BuiltinMode: String, CaseIterable, Codable, Sendable {
    case volume, scroll, media, video, brightness, zoom, tabs, slides, apps, windows, undo

    public var id: ModeID { ModeID(rawValue: rawValue) }

    public var name: String {
        switch self {
        case .volume: return "Volume"
        case .scroll: return "Scroll"
        case .media: return "Media"
        case .video: return "Video Seek"
        case .brightness: return "Brightness"
        case .zoom: return "Zoom"
        case .tabs: return "Browser Tabs"
        case .slides: return "Slides"
        case .apps: return "App Switcher"
        case .windows: return "Windows"
        case .undo: return "Undo / Redo"
        }
    }

    public var symbol: String {
        switch self {
        case .volume: return "speaker.wave.2.fill"
        case .scroll: return "arrow.up.and.down"
        case .media: return "music.note"
        case .video: return "film"
        case .brightness: return "sun.max.fill"
        case .zoom: return "plus.magnifyingglass"
        case .tabs: return "square.on.square"
        case .slides: return "play.rectangle.fill"
        case .apps: return "square.grid.2x2.fill"
        case .windows: return "macwindow.on.rectangle"
        case .undo: return "arrow.uturn.backward"
        }
    }

    /// What turning does, in a few words (shown in the HUD, menus and settings).
    public var turnHint: String {
        switch self {
        case .volume: return "Turn to change volume"
        case .scroll: return "Turn to scroll smoothly"
        case .media: return "Turn to skip tracks"
        case .video: return "Turn to seek"
        case .brightness: return "Turn to change brightness"
        case .zoom: return "Turn to zoom in and out"
        case .tabs: return "Turn to change tabs"
        case .slides: return "Turn for next / previous slide"
        case .apps: return "Turn to pick an app"
        case .windows: return "Turn to cycle windows"
        case .undo: return "Turn back to undo, forward to redo"
        }
    }

    public var pressHint: String {
        switch self {
        case .volume, .media: return "Press to play / pause"
        case .scroll: return "Press to switch vertical / horizontal"
        case .video: return "Press to play / pause"
        case .brightness: return "Press to dim / restore"
        case .zoom: return "Press to reset zoom"
        case .tabs: return "Press for a new tab"
        case .slides: return "Press to black out the screen"
        case .apps: return "Press to switch to the app"
        case .windows: return "Press for Mission Control"
        case .undo: return "Press to save"
        }
    }

    /// Modes where a stray click does something you would notice.
    public var guardedByDefault: Bool {
        switch self {
        case .media, .tabs, .apps, .windows, .undo: return true
        case .volume, .scroll, .video, .brightness, .zoom, .slides: return false
        }
    }

    /// True when Dialed should leave the buds' volume where the dial put it.
    public var usesDeviceVolume: Bool { self == .volume }
}

/// A user-defined mode: one action per direction plus a press action.
public struct CustomMode: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var symbol: String
    public var clockwise: Action
    public var counterClockwise: Action
    public var press: Action
    /// Repeat the action for the extra clicks a fast spin implies.
    public var repeatOnFastSpin: Bool
    public var guarded: Bool

    public init(id: UUID = UUID(), name: String, symbol: String = "dial.medium",
                clockwise: Action, counterClockwise: Action, press: Action = .none,
                repeatOnFastSpin: Bool = false, guarded: Bool = false) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.clockwise = clockwise
        self.counterClockwise = counterClockwise
        self.press = press
        self.repeatOnFastSpin = repeatOnFastSpin
        self.guarded = guarded
    }

    public var modeID: ModeID { .custom(id) }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Custom"
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "dial.medium"
        clockwise = try c.decodeIfPresent(Action.self, forKey: .clockwise) ?? .none
        counterClockwise = try c.decodeIfPresent(Action.self, forKey: .counterClockwise) ?? .none
        press = try c.decodeIfPresent(Action.self, forKey: .press) ?? .none
        repeatOnFastSpin = try c.decodeIfPresent(Bool.self, forKey: .repeatOnFastSpin) ?? false
        guarded = try c.decodeIfPresent(Bool.self, forKey: .guarded) ?? false
    }
}

/// A resolved description of any mode, built-in or custom.
public struct ModeInfo: Hashable, Sendable {
    public var id: ModeID
    public var name: String
    public var symbol: String
    public var turnHint: String
    public var pressHint: String

    public static func unknown(_ id: ModeID) -> ModeInfo {
        ModeInfo(id: id, name: "Missing mode", symbol: "questionmark.circle",
                 turnHint: "This mode was deleted", pressHint: "")
    }
}
