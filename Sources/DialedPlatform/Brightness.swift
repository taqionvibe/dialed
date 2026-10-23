import Foundation
import CoreGraphics

/// Built-in display brightness through DisplayServices (a private framework used by
/// MonitorControl and others; no permission needed). Falls back to the system
/// brightness keys, which also cover Apple external displays.
public final class BrightnessController {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let getFn: GetFn?
    private let setFn: SetFn?
    private var dimRestore: Float?
    /// Accumulates fractional steps when using the key fallback (1 key = 1/16).
    private var keyCarry: Double = 0

    public init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        getFn = handle.flatMap { dlsym($0, "DisplayServicesGetBrightness") }.map { unsafeBitCast($0, to: GetFn.self) }
        setFn = handle.flatMap { dlsym($0, "DisplayServicesSetBrightness") }.map { unsafeBitCast($0, to: SetFn.self) }
    }

    /// The built-in display, if there is one and it is active.
    private var builtinDisplay: CGDirectDisplayID? {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return ids.first { CGDisplayIsBuiltin($0) != 0 }
    }

    /// Current brightness 0…1 of the built-in display, or nil if not readable.
    public var level: Float? {
        guard let getFn, let id = builtinDisplay else { return nil }
        var v: Float = 0
        return getFn(id, &v) == 0 ? v : nil
    }

    /// True when direct control works (otherwise brightness keys are used).
    public var hasDirectControl: Bool { level != nil && setFn != nil }

    /// Change brightness; returns the new level when known.
    @discardableResult
    public func adjust(by delta: Double) -> Float? {
        dimRestore = nil
        if let setFn, let id = builtinDisplay, let current = level {
            let next = max(0, min(1, current + Float(delta)))
            return setFn(id, next) == 0 ? next : nil
        }
        keyCarry += delta * 16
        while keyCarry >= 1 { EventPoster.systemKey(.brightnessUp); keyCarry -= 1 }
        while keyCarry <= -1 { EventPoster.systemKey(.brightnessDown); keyCarry += 1 }
        return nil
    }

    /// Dim to almost dark, or restore the level from before dimming.
    @discardableResult
    public func toggleDim() -> Float? {
        guard let setFn, let id = builtinDisplay, let current = level else {
            for _ in 0..<16 { EventPoster.systemKey(.brightnessDown) }
            return nil
        }
        if let restore = dimRestore {
            dimRestore = nil
            _ = setFn(id, restore)
            return restore
        }
        dimRestore = current
        _ = setFn(id, 0.04)
        return 0.04
    }
}
