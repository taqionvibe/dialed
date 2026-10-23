import Foundation

/// A dial press as macOS sees it. The buds turn presses into AVRCP media commands:
/// single → play/pause, double → next track, triple → previous track
/// (only when Nothing X maps them that way). Hold never reaches macOS.
public enum PressKind: String, Codable, CaseIterable, Sendable {
    case single, double, triple

    public var title: String {
        switch self {
        case .single: return "Single press"
        case .double: return "Double press"
        case .triple: return "Triple press"
        }
    }
}

/// Raw media commands delivered by MPRemoteCommandCenter.
public enum RemoteCommand: String, Sendable {
    case play, pause, togglePlayPause, nextTrack, previousTrack

    public var press: PressKind {
        switch self {
        case .play, .pause, .togglePlayPause: return .single
        case .nextTrack: return .double
        case .previousTrack: return .triple
        }
    }
}

/// Normalised input fed into the gesture engine.
public enum DialInput: Equatable, Sendable {
    /// Positive = clockwise (volume up), negative = counter-clockwise.
    case turn(steps: Int, at: TimeInterval)
    case press(PressKind, at: TimeInterval)
}

/// Collapses the duplicate commands macOS sometimes delivers for one physical press
/// (for example `pause` followed by `togglePlayPause` within a few milliseconds).
public struct PressDebouncer: Sendable {
    public var window: TimeInterval
    private var last: (kind: PressKind, at: TimeInterval)?

    public init(window: TimeInterval = 0.15) { self.window = window }

    public mutating func accept(_ command: RemoteCommand, at time: TimeInterval) -> PressKind? {
        let kind = command.press
        if let last, last.kind == kind, time - last.at < window { return nil }
        last = (kind, time)
        return kind
    }
}
