import Foundation

/// Platform-neutral output produced by a mode. The app layer turns these into
/// CGEvents, scroll animations, brightness changes and so on.
public enum OutputCommand: Equatable, Sendable {
    /// Press a shortcut `count` times.
    case key(KeyCombo, count: Int)
    /// Smooth scroll by this many points. Positive = content moves down/right.
    case scroll(points: Double, horizontal: Bool)
    case toggleScrollAxis
    /// Volume mode: the buds already changed the volume; just report it.
    case volumeChanged(steps: Int)
    case brightness(delta: Double)
    case toggleDim
    /// Move the system app switcher (held ⌘⇥) by `steps`.
    case appSwitch(steps: Int)
    case appSwitchCommit
    case perform(Action, count: Int)
}

/// Pure mapping from (mode, turn/press) to output commands.
public enum ModePlanner {
    public static func turn(mode: ModeID, steps: Int, multiplier: Double,
                            settings: DialedSettings, profile: Profile,
                            horizontalScroll: Bool = false) -> [OutputCommand] {
        guard steps != 0 else { return [] }
        let n = abs(steps)
        let forward = steps > 0
        let sens = settings.sensitivity
        let accelerated = max(n, Int((Double(n) * multiplier).rounded()))

        if let custom = mode.customID.flatMap(settings.customMode(id:)) {
            let action = forward ? custom.clockwise : custom.counterClockwise
            guard action != .none else { return [] }
            return [.perform(action, count: custom.repeatOnFastSpin ? accelerated : n)]
        }
        guard let b = mode.builtin else { return [] }

        switch b {
        case .volume:
            return [.volumeChanged(steps: steps)]
        case .scroll:
            let points = Double(steps) * sens.scrollPixelsPerClick * multiplier * profile.sensitivityScale
            return [.scroll(points: sens.naturalScroll ? points : -points, horizontal: horizontalScroll)]
        case .media:
            return [.perform(.media(command: forward ? .nextTrack : .previousTrack), count: n)]
        case .video:
            let presses = Int((Double(accelerated * sens.seekPressesPerClick) * profile.sensitivityScale).rounded())
            return [.key(KeyCombo(forward ? KeyCode.rightArrow : KeyCode.leftArrow), count: max(1, presses))]
        case .brightness:
            return [.brightness(delta: Double(steps) * sens.brightnessStep * multiplier)]
        case .zoom:
            return [.key(KeyCombo(forward ? KeyCode.equal : KeyCode.minus, .command), count: n)]
        case .tabs:
            return [.key(KeyCombo(KeyCode.tab, forward ? [.control] : [.control, .shift]), count: n)]
        case .slides:
            return [.key(KeyCombo(forward ? KeyCode.rightArrow : KeyCode.leftArrow), count: n)]
        case .apps:
            return [.appSwitch(steps: steps)]
        case .windows:
            return [.key(KeyCombo(KeyCode.grave, forward ? [.command] : [.command, .shift]), count: n)]
        case .undo:
            return [.key(forward ? KeyCombo(KeyCode.z, [.command, .shift]) : KeyCombo(KeyCode.z, .command), count: n)]
        }
    }

    public static func press(mode: ModeID, settings: DialedSettings) -> [OutputCommand] {
        if let custom = mode.customID.flatMap(settings.customMode(id:)) {
            return custom.press == .none ? [] : [.perform(custom.press, count: 1)]
        }
        guard let b = mode.builtin else { return [] }
        switch b {
        case .volume, .media: return [.perform(.media(command: .playPause), count: 1)]
        case .scroll: return [.toggleScrollAxis]
        case .video: return [.key(KeyCombo(KeyCode.space), count: 1)]
        case .brightness: return [.toggleDim]
        case .zoom: return [.key(KeyCombo(KeyCode.zero, .command), count: 1)]
        case .tabs: return [.key(KeyCombo(KeyCode.t, .command), count: 1)]
        case .slides: return [.key(KeyCombo(KeyCode.b), count: 1)]
        case .apps: return [.appSwitchCommit]
        case .windows: return [.perform(.system(command: .missionControl), count: 1)]
        case .undo: return [.key(KeyCombo(KeyCode.s, .command), count: 1)]
        }
    }
}
