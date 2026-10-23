import Foundation

/// The gesture state machine: which mode is active, whether the radial menu is open,
/// and what each turn or press should do. It has no side effects; it returns
/// `Effect`s that the app performs, which keeps it fully testable.
public final class DialEngine {
    public struct MenuState: Equatable, Sendable {
        public var items: [RadialItem]
        public var highlighted: Int
        public var lastInteraction: TimeInterval

        public var highlightedItem: RadialItem? {
            items.indices.contains(highlighted) ? items[highlighted] : nil
        }
    }

    public enum Effect: Equatable {
        case output(OutputCommand, mode: ModeID)
        case modeChanged(to: ModeID, from: ModeID?)
        case menuOpened(MenuState)
        case menuMoved(MenuState)
        case menuClosed(selected: RadialItem?)
        /// The accidental-turn guard swallowed a click.
        case armed(ModeID)
        /// Run an action that is not a mode switch (shortcut, macro, Shortcut…).
        case run(Action)
        /// A press had nothing to do (e.g. "previous mode" with no history).
        case nothingToDo(String)
    }

    public var settings: DialedSettings {
        didSet { turnGuard.idleThreshold = settings.general.guardIdleSeconds }
    }
    public var profile: Profile

    public private(set) var mode: ModeID
    public private(set) var previousMode: ModeID?
    public private(set) var menu: MenuState?
    public private(set) var horizontalScroll = false

    private var spin = SpinTracker()
    private var turnGuard: TurnGuard

    public init(settings: DialedSettings, profile: Profile? = nil) {
        self.settings = settings
        self.profile = profile ?? settings.defaultProfile
        let start = settings.modeExists(settings.general.startMode) ? settings.general.startMode : BuiltinMode.volume.id
        self.mode = start
        self.turnGuard = TurnGuard(idleThreshold: settings.general.guardIdleSeconds)
    }

    // MARK: Input

    public func handle(_ input: DialInput) -> [Effect] {
        switch input {
        case .turn(let raw, let time):
            let steps = settings.sensitivity.reverseDirection ? -raw : raw
            if var m = menu {
                guard !m.items.isEmpty else { return [] }
                let n = m.items.count
                m.highlighted = ((m.highlighted + steps) % n + n) % n
                m.lastInteraction = time
                menu = m
                return [.menuMoved(m)]
            }
            switch turnGuard.filter(steps: steps, at: time, guarded: settings.isGuarded(mode)) {
            case .armed:
                spin.reset()
                return [.armed(mode)]
            case .pass(let s):
                let mult = spin.multiplier(steps: s, at: time, acceleration: settings.sensitivity.acceleration)
                return ModePlanner.turn(mode: mode, steps: s, multiplier: mult, settings: settings,
                                        profile: profile, horizontalScroll: horizontalScroll)
                    .map { .output($0, mode: mode) }
            }

        case .press(let kind, let time):
            if let m = menu {
                if kind == .single { return select(m.highlightedItem) }
                _ = time
                return closeMenu(selected: nil)
            }
            switch profile.gestures[kind] {
            case .modeDefault:
                let outputs = ModePlanner.press(mode: mode, settings: settings)
                if outputs.isEmpty { return [.nothingToDo("\(settings.modeName(mode)) has no press action")] }
                return outputs.flatMap { out -> [Effect] in
                    if case .toggleScrollAxis = out { horizontalScroll.toggle() }
                    if case .perform(let action, _) = out, action.isEngineAction { return perform(action, at: time) }
                    return [.output(out, mode: mode)]
                }
            case .openRadialMenu:
                return openMenu(at: time)
            case .previousMode:
                return goBack()
            case .action(let a):
                return perform(a, at: time)
            }
        }
    }

    /// Call periodically (e.g. every 0.25 s) to close an idle radial menu.
    public func tick(now: TimeInterval) -> [Effect] {
        guard let m = menu, now - m.lastInteraction >= settings.general.radialTimeout else { return [] }
        if settings.general.radialTimeoutSelects, let item = m.highlightedItem, case .mode = item.target {
            return select(item)
        }
        return closeMenu(selected: nil)
    }

    // MARK: Commands

    public func openMenu(at time: TimeInterval) -> [Effect] {
        let items = profile.radialItems
        guard !items.isEmpty else { return [.nothingToDo("The radial menu has no items")] }
        let current = items.firstIndex { $0.target == .mode(mode) } ?? 0
        let m = MenuState(items: items, highlighted: current, lastInteraction: time)
        menu = m
        return [.menuOpened(m)]
    }

    public func closeMenu(selected: RadialItem?) -> [Effect] {
        guard menu != nil else { return [] }
        menu = nil
        return [.menuClosed(selected: selected)]
    }

    public func switchMode(_ id: ModeID) -> [Effect] {
        guard settings.modeExists(id) else { return [.nothingToDo("That mode no longer exists")] }
        guard id != mode else { return [.modeChanged(to: id, from: previousMode)] }
        let old = mode
        previousMode = old
        mode = id
        horizontalScroll = false
        spin.reset()
        turnGuard.reset()
        return [.modeChanged(to: id, from: old)]
    }

    public func goBack() -> [Effect] {
        guard let p = previousMode, settings.modeExists(p) else {
            return [.nothingToDo("No previous mode yet")]
        }
        return switchMode(p)
    }

    /// Apply a new profile (from automatic switching or the menu).
    public func activate(profile newProfile: Profile) -> [Effect] {
        profile = newProfile
        var effects: [Effect] = []
        if menu != nil { effects += closeMenu(selected: nil) }
        if let start = newProfile.startMode, start != mode { effects += switchMode(start) }
        return effects
    }

    /// Resets the guard and spin tracking (after sleep, reconnects…).
    public func resetMotion() {
        spin.reset()
        turnGuard.reset()
    }

    private func select(_ item: RadialItem?) -> [Effect] {
        var effects = closeMenu(selected: item)
        guard let item else { return effects }
        switch item.target {
        case .mode(let m): effects += switchMode(m)
        case .action(let a): effects += perform(a, at: 0)
        }
        return effects
    }

    private func perform(_ action: Action, at time: TimeInterval) -> [Effect] {
        switch action {
        case .none: return []
        case .switchMode(let m): return switchMode(m)
        case .openRadialMenu: return openMenu(at: time)
        case .previousMode: return goBack()
        default: return [.run(action)]
        }
    }
}

extension Action {
    /// Actions the engine handles itself rather than passing to the app.
    var isEngineAction: Bool {
        switch self {
        case .switchMode, .openRadialMenu, .previousMode: return true
        default: return false
        }
    }
}
