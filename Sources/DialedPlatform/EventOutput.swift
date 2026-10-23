import Foundation
import AppKit
import CoreGraphics
import DialedCore

/// Posts synthetic keyboard, scroll and media-key events. Needs Accessibility;
/// without it macOS drops the events silently, so callers check `Permissions` first.
public enum EventPoster {
    private static let source = CGEventSource(stateID: .hidSystemState)

    static func flags(_ m: Modifiers) -> CGEventFlags {
        var f: CGEventFlags = []
        if m.contains(.command) { f.insert(.maskCommand) }
        if m.contains(.option) { f.insert(.maskAlternate) }
        if m.contains(.control) { f.insert(.maskControl) }
        if m.contains(.shift) { f.insert(.maskShift) }
        if m.contains(.function) { f.insert(.maskSecondaryFn) }
        return f
    }

    public static func key(_ combo: KeyCombo, count: Int = 1) {
        let f = flags(combo.modifiers)
        for _ in 0..<max(1, min(count, 60)) {
            for down in [true, false] {
                guard let e = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: down) else { continue }
                e.flags = f
                e.post(tap: .cghidEventTap)
            }
        }
    }

    /// Hold or release a modifier key (used by the app switcher).
    public static func modifier(_ keyCode: UInt16, down: Bool, flags: CGEventFlags) {
        guard let e = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down) else { return }
        e.flags = down ? flags : []
        e.post(tap: .cghidEventTap)
    }

    /// Like `key`, but keeps extra modifier flags (e.g. ⌘ held by the app switcher).
    public static func key(_ keyCode: UInt16, flags: CGEventFlags) {
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down) else { continue }
            e.flags = flags
            e.post(tap: .cghidEventTap)
        }
    }

    /// Pixel scroll. Positive `down` moves the view toward the end of the document.
    public static func scroll(down: Int32, right: Int32) {
        guard let e = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                              wheel1: -down, wheel2: -right, wheel3: 0) else { return }
        e.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        e.post(tap: .cghidEventTap)
    }

    /// NX_KEYTYPE_* system keys (media, brightness, volume).
    public enum SystemKey: Int32 {
        case soundUp = 0, soundDown = 1, brightnessUp = 2, brightnessDown = 3, mute = 7
        case play = 16, next = 17, previous = 18
    }

    public static func systemKey(_ key: SystemKey) {
        for down in [true, false] {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
            let data1 = Int((key.rawValue << 16) | ((down ? 0xa : 0xb) << 8))
            guard let e = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: flags,
                                             timestamp: 0, windowNumber: 0, context: nil, subtype: 8,
                                             data1: data1, data2: -1) else { continue }
            e.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    /// Types text using Unicode key events (layout independent).
    public static func type(_ text: String) {
        let utf16 = Array(text.utf16)
        var i = 0
        while i < utf16.count {
            let chunk = Array(utf16[i..<min(i + 16, utf16.count)])
            for down in [true, false] {
                guard let e = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { continue }
                chunk.withUnsafeBufferPointer { e.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: $0.baseAddress) }
                e.post(tap: .cghidEventTap)
            }
            i += 16
        }
    }
}

/// Turns coarse dial clicks into a smooth, eased scroll animation at display rate.
public final class SmoothScroller {
    private var remainingDown: Double = 0
    private var remainingRight: Double = 0
    private var carryDown: Double = 0
    private var carryRight: Double = 0
    private var timer: Timer?

    /// Fraction of the remaining distance covered each frame (ease-out).
    public var easing: Double = 0.16

    public init() {}

    public func add(points: Double, horizontal: Bool) {
        // Reversing direction cancels the leftover glide for a precise feel.
        if horizontal {
            if remainingRight.sign != points.sign { remainingRight = 0 }
            remainingRight += points
        } else {
            if remainingDown.sign != points.sign { remainingDown = 0 }
            remainingDown += points
        }
        if timer == nil {
            let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in self?.step() }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        remainingDown = 0; remainingRight = 0; carryDown = 0; carryRight = 0
    }

    private func step() {
        func take(_ remaining: inout Double, _ carry: inout Double) -> Int32 {
            guard abs(remaining) > 0.5 else { remaining = 0; return 0 }
            var delta = remaining * easing
            if abs(delta) < 1 { delta = remaining.sign == .minus ? -1 : 1 }
            remaining -= delta
            carry += delta
            let whole = carry.rounded(.towardZero)
            carry -= whole
            return Int32(whole)
        }
        let dy = take(&remainingDown, &carryDown)
        let dx = take(&remainingRight, &carryRight)
        if dy != 0 || dx != 0 { EventPoster.scroll(down: dy, right: dx) }
        if remainingDown == 0, remainingRight == 0 {
            timer?.invalidate()
            timer = nil
        }
    }
}

/// Drives the real macOS app switcher by holding ⌘ and pressing ⇥ per click.
/// ⌘ is always released: on press, after a pause, on mode change, sleep and quit.
public final class AppSwitcher {
    public private(set) var isHolding = false
    private var releaseWork: DispatchWorkItem?
    /// Seconds without a click before the highlighted app is chosen.
    public var commitDelay: TimeInterval = 1.6

    public init() {}

    public func step(_ steps: Int) {
        if !isHolding {
            EventPoster.modifier(KeyCode.command, down: true, flags: .maskCommand)
            isHolding = true
        }
        for _ in 0..<abs(steps) {
            EventPoster.key(KeyCode.tab, flags: steps > 0 ? .maskCommand : [.maskCommand, .maskShift])
        }
        scheduleCommit()
    }

    public func commit() {
        releaseWork?.cancel()
        releaseWork = nil
        guard isHolding else { return }
        EventPoster.modifier(KeyCode.command, down: false, flags: [])
        isHolding = false
    }

    private func scheduleCommit() {
        releaseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.commit() }
        releaseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + commitDelay, execute: work)
    }
}
