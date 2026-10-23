import Foundation

/// Modifier keys for a shortcut. Raw values are stable on disk.
public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let command = Modifiers(rawValue: 1 << 0)
    public static let option = Modifiers(rawValue: 1 << 1)
    public static let control = Modifiers(rawValue: 1 << 2)
    public static let shift = Modifiers(rawValue: 1 << 3)
    public static let function = Modifiers(rawValue: 1 << 4)

    /// Symbols in Apple's canonical order: ⌃ ⌥ ⇧ ⌘.
    public var symbols: String {
        var s = ""
        if contains(.function) { s += "fn " }
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

/// A key press with modifiers, using macOS virtual key codes (kVK_*).
public struct KeyCombo: Codable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifiers: Modifiers

    public init(_ keyCode: UInt16, _ modifiers: Modifiers = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var displayString: String { modifiers.symbols + KeyCode.name(for: keyCode) }
}

/// Virtual key codes from HIToolbox/Events.h (ANSI positions).
public enum KeyCode {
    public static let a: UInt16 = 0x00, s: UInt16 = 0x01, d: UInt16 = 0x02, f: UInt16 = 0x03
    public static let h: UInt16 = 0x04, g: UInt16 = 0x05, z: UInt16 = 0x06, x: UInt16 = 0x07
    public static let c: UInt16 = 0x08, v: UInt16 = 0x09, b: UInt16 = 0x0B, q: UInt16 = 0x0C
    public static let w: UInt16 = 0x0D, e: UInt16 = 0x0E, r: UInt16 = 0x0F, y: UInt16 = 0x10
    public static let t: UInt16 = 0x11, o: UInt16 = 0x1F, u: UInt16 = 0x20, i: UInt16 = 0x22
    public static let p: UInt16 = 0x23, l: UInt16 = 0x25, j: UInt16 = 0x26, k: UInt16 = 0x28
    public static let n: UInt16 = 0x2D, m: UInt16 = 0x2E
    public static let equal: UInt16 = 0x18, minus: UInt16 = 0x1B, zero: UInt16 = 0x1D
    public static let leftBracket: UInt16 = 0x21, rightBracket: UInt16 = 0x1E
    public static let grave: UInt16 = 0x32, period: UInt16 = 0x2F, comma: UInt16 = 0x2B
    public static let slash: UInt16 = 0x2C, backslash: UInt16 = 0x2A
    public static let returnKey: UInt16 = 0x24, tab: UInt16 = 0x30, space: UInt16 = 0x31
    public static let delete: UInt16 = 0x33, escape: UInt16 = 0x35
    public static let command: UInt16 = 0x37, shift: UInt16 = 0x38, option: UInt16 = 0x3A
    public static let control: UInt16 = 0x3B
    public static let leftArrow: UInt16 = 0x7B, rightArrow: UInt16 = 0x7C
    public static let downArrow: UInt16 = 0x7D, upArrow: UInt16 = 0x7E
    public static let pageUp: UInt16 = 0x74, pageDown: UInt16 = 0x79
    public static let home: UInt16 = 0x73, end: UInt16 = 0x77
    public static let f1: UInt16 = 0x7A, f2: UInt16 = 0x78, f3: UInt16 = 0x63, f4: UInt16 = 0x76
    public static let f5: UInt16 = 0x60, f6: UInt16 = 0x61, f7: UInt16 = 0x62, f8: UInt16 = 0x64
    public static let f9: UInt16 = 0x65, f10: UInt16 = 0x6D, f11: UInt16 = 0x67, f12: UInt16 = 0x6F

    static let names: [UInt16: String] = {
        var m: [UInt16: String] = [
            0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E", 0x03: "F", 0x05: "G",
            0x04: "H", 0x22: "I", 0x26: "J", 0x28: "K", 0x25: "L", 0x2E: "M", 0x2D: "N",
            0x1F: "O", 0x23: "P", 0x0C: "Q", 0x0F: "R", 0x01: "S", 0x11: "T", 0x20: "U",
            0x09: "V", 0x0D: "W", 0x07: "X", 0x10: "Y", 0x06: "Z",
            0x1D: "0", 0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5", 0x16: "6",
            0x1A: "7", 0x1C: "8", 0x19: "9",
            0x18: "=", 0x1B: "-", 0x21: "[", 0x1E: "]", 0x32: "`", 0x2F: ".", 0x2B: ",",
            0x2C: "/", 0x2A: "\\", 0x29: ";", 0x27: "'",
            0x24: "↩", 0x30: "⇥", 0x31: "Space", 0x33: "⌫", 0x75: "⌦", 0x35: "⎋",
            0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
            0x74: "⇞", 0x79: "⇟", 0x73: "↖", 0x77: "↘",
        ]
        let fkeys: [UInt16] = [0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64, 0x65, 0x6D, 0x67, 0x6F]
        for (i, code) in fkeys.enumerated() { m[code] = "F\(i + 1)" }
        return m
    }()

    public static func name(for code: UInt16) -> String { names[code] ?? "Key \(code)" }

    /// True for codes that are modifiers on their own (not usable as the main key).
    public static func isModifier(_ code: UInt16) -> Bool {
        [0x37, 0x36, 0x38, 0x3C, 0x3A, 0x3D, 0x3B, 0x3E, 0x39, 0x3F].contains(code)
    }
}
