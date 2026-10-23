import Foundation

/// The buds report dial turns as AVRCP absolute-volume changes on a 16-step grid
/// (raw AVRCP volume = round(k × 127 / 16)). Hardware-verified on macOS 27 with
/// CMF Buds Pro 2: every report is exactly one grid step, and slow clicks arrive
/// ~0.8–1.2 s apart while fast spins are rate-limited to roughly one report per 0.45 s.
public enum VolumeGrid {
    public static let steps = 16
    public static let avrcpMax: Double = 127

    /// Grid position (0…16) of a CoreAudio volume scalar. May be fractional when off-grid.
    public static func position(of volume: Float) -> Double {
        let raw = (Double(volume) * avrcpMax).rounded()
        return raw * Double(steps) / avrcpMax
    }

    /// The nearest grid index for a scalar.
    public static func index(of volume: Float) -> Int {
        Int(position(of: volume).rounded())
    }

    /// The scalar CoreAudio uses for a grid index (what the buds would report).
    public static func scalar(forIndex k: Int) -> Float {
        let clamped = max(0, min(steps, k))
        let raw = (Double(clamped) * avrcpMax / Double(steps)).rounded()
        return Float(raw / avrcpMax)
    }

    /// True when a volume sits on (or within rounding of) the buds' 16-step grid.
    public static func isOnGrid(_ volume: Float, tolerance: Double = 0.12) -> Bool {
        let p = position(of: volume)
        return abs(p - p.rounded()) <= tolerance
    }

    /// A safe "rest" level for non-volume modes: the grid point nearest the user's
    /// listening level, kept one step away from both ends so turns in either
    /// direction are still reported by the buds.
    public static func restLevel(near volume: Float) -> Float {
        scalar(forIndex: max(1, min(steps - 1, index(of: volume))))
    }

    /// The level to return to after a click in a non-volume mode: exactly the user's
    /// listening level, unless that sits on the first/last step (where the buds stop
    /// reporting turns in one direction).
    public static func restTarget(for listening: Float) -> Float {
        min(max(listening, scalar(forIndex: 1)), scalar(forIndex: steps - 1))
    }
}

/// Turns a stream of CoreAudio volume readings into dial clicks, while telling apart
/// our own restore writes, keyboard/menu-bar volume changes and reconnect noise.
public final class VolumeClickDecoder {
    public enum Result: Equatable {
        case click(steps: Int)
        case userChange(Float)
        case echo
        case ignored(String)
    }

    public private(set) var lastLevel: Float?
    private var pendingWrites: [(value: Float, at: TimeInterval)] = []
    private var settleUntil: TimeInterval = 0
    private var lastVolumeKeyAt: TimeInterval = -.infinity

    /// How long a write of ours may take to come back as a notification.
    public var echoWindow: TimeInterval = 0.8
    /// Volume-key presses within this window make the next change a user change.
    public var volumeKeyWindow: TimeInterval = 0.5
    /// Jumps larger than this many steps are treated as the user dragging a slider.
    public var maxStepsPerReport = 3

    public init() {}

    /// Forget history, e.g. after the buds reconnect.
    public func reset(level: Float?) {
        lastLevel = level
        pendingWrites.removeAll()
    }

    /// Call right before writing the device volume ourselves.
    public func noteOwnWrite(_ value: Float, at time: TimeInterval) {
        pendingWrites.append((value, time))
        lastLevel = value
    }

    /// A hardware volume key (or the menu bar slider) was used.
    public func noteVolumeKey(at time: TimeInterval) { lastVolumeKeyAt = time }

    /// Ignore every change until `time` (reconnects and wake-ups produce stale reports).
    public func settle(until time: TimeInterval) { settleUntil = max(settleUntil, time) }

    public func ingest(_ value: Float, at time: TimeInterval) -> Result {
        pendingWrites.removeAll { time - $0.at > echoWindow }
        guard let last = lastLevel else {
            lastLevel = value
            return .ignored("first reading")
        }
        if abs(value - last) < 0.002 { return .ignored("unchanged") }

        if let i = pendingWrites.firstIndex(where: { abs($0.value - value) < 0.002 }) {
            pendingWrites.remove(at: i)
            lastLevel = value
            return .echo
        }
        lastLevel = value
        if time < settleUntil { return .ignored("settling") }
        if time - lastVolumeKeyAt < volumeKeyWindow { return .userChange(value) }
        if !VolumeGrid.isOnGrid(value) { return .userChange(value) }

        var steps = VolumeGrid.index(of: value) - VolumeGrid.index(of: last)
        if steps == 0 { steps = value > last ? 1 : -1 }
        if abs(steps) > maxStepsPerReport { return .userChange(value) }
        return .click(steps: steps)
    }
}
