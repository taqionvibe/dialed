import Foundation

/// Fast spins lose clicks inside the buds (they report at most ~2 per second), so
/// reports that arrive close together are scaled up. Careful single clicks and the
/// first click after a direction change always stay exact.
public struct SpinTracker: Sendable {
    /// Reports slower than this are deliberate single clicks (multiplier 1).
    public var slowInterval: TimeInterval = 0.9
    /// Reports at or faster than this are a full-speed spin.
    public var fastInterval: TimeInterval = 0.45

    private var lastAt: TimeInterval?
    private var lastDirection = 0

    public init() {}

    public mutating func reset() { lastAt = nil; lastDirection = 0 }

    /// - Parameter acceleration: 0 (off) … 1 (fast spins move up to 3×).
    public mutating func multiplier(steps: Int, at time: TimeInterval, acceleration: Double) -> Double {
        let direction = steps.signum()
        defer { lastAt = time; lastDirection = direction }
        guard let lastAt, direction == lastDirection, acceleration > 0 else { return 1 }
        let interval = time - lastAt
        if interval >= slowInterval { return 1 }
        let t = min(1, max(0, (slowInterval - interval) / (slowInterval - fastInterval)))
        return 1 + t * 2 * min(1, acceleration)
    }
}

/// Protects against accidental turns: after the dial has been idle for a while, the
/// first click only wakes it up (the HUD says "Turn again to …"). Any further click
/// within the idle threshold acts normally. Applies only to modes where a stray click
/// does something you would notice (undo, tabs, app switching, track skipping…).
public struct TurnGuard: Sendable {
    public enum Verdict: Equatable { case pass(Int), armed }

    public var idleThreshold: TimeInterval
    private var lastTurnAt: TimeInterval?

    public init(idleThreshold: TimeInterval = 20) {
        self.idleThreshold = idleThreshold
    }

    public mutating func reset() { lastTurnAt = nil }

    public mutating func filter(steps: Int, at time: TimeInterval, guarded: Bool) -> Verdict {
        defer { lastTurnAt = time }
        guard guarded else { return .pass(steps) }
        if let lastTurnAt, time - lastTurnAt <= idleThreshold { return .pass(steps) }
        return .armed
    }
}
