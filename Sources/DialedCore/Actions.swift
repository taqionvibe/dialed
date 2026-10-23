import Foundation

public enum MediaCommand: String, Codable, CaseIterable, Sendable {
    case playPause, nextTrack, previousTrack

    public var title: String {
        switch self {
        case .playPause: return "Play / Pause"
        case .nextTrack: return "Next track"
        case .previousTrack: return "Previous track"
        }
    }

    public var symbol: String {
        switch self {
        case .playPause: return "playpause.fill"
        case .nextTrack: return "forward.end.fill"
        case .previousTrack: return "backward.end.fill"
        }
    }
}

public enum SystemCommand: String, Codable, CaseIterable, Sendable {
    case missionControl, appExpose, showDesktop, launchpad, lockScreen, screenshot,
         spotlight, toggleMute, sleepDisplay

    public var title: String {
        switch self {
        case .missionControl: return "Mission Control"
        case .appExpose: return "App windows"
        case .showDesktop: return "Show Desktop"
        case .launchpad: return "Apps (Launchpad)"
        case .lockScreen: return "Lock Screen"
        case .screenshot: return "Screenshot"
        case .spotlight: return "Spotlight"
        case .toggleMute: return "Mute / Unmute"
        case .sleepDisplay: return "Sleep display"
        }
    }

    public var symbol: String {
        switch self {
        case .missionControl: return "rectangle.3.group"
        case .appExpose: return "macwindow.on.rectangle"
        case .showDesktop: return "menubar.dock.rectangle"
        case .launchpad: return "square.grid.3x3"
        case .lockScreen: return "lock.fill"
        case .screenshot: return "camera.viewfinder"
        case .spotlight: return "magnifyingglass"
        case .toggleMute: return "speaker.slash.fill"
        case .sleepDisplay: return "moon.fill"
        }
    }
}

/// Everything a press, a radial menu item, a custom mode or a macro step can do.
public enum Action: Codable, Hashable, Sendable {
    case none
    case keyboardShortcut(combo: KeyCombo)
    case media(command: MediaCommand)
    case system(command: SystemCommand)
    case appleShortcut(name: String)
    case openApplication(bundleID: String, name: String)
    case openURL(url: String)
    case typeText(text: String)
    case runMacro(id: UUID)
    case switchMode(mode: ModeID)
    case openRadialMenu
    case previousMode
    case toggleEnabled

    public var kind: ActionKind {
        switch self {
        case .none: return .none
        case .keyboardShortcut: return .keyboardShortcut
        case .media: return .media
        case .system: return .system
        case .appleShortcut: return .appleShortcut
        case .openApplication: return .openApplication
        case .openURL: return .openURL
        case .typeText: return .typeText
        case .runMacro: return .runMacro
        case .switchMode: return .switchMode
        case .openRadialMenu: return .openRadialMenu
        case .previousMode: return .previousMode
        case .toggleEnabled: return .toggleEnabled
        }
    }

    /// Human readable summary. Macro and mode names are resolved by the caller.
    public func summary(modeName: (ModeID) -> String = { $0.rawValue },
                        macroName: (UUID) -> String = { _ in "Macro" }) -> String {
        switch self {
        case .none: return "Nothing"
        case .keyboardShortcut(let combo): return "Press \(combo.displayString)"
        case .media(let c): return c.title
        case .system(let c): return c.title
        case .appleShortcut(let name): return name.isEmpty ? "Run Shortcut…" : "Shortcut “\(name)”"
        case .openApplication(_, let name): return name.isEmpty ? "Open app…" : "Open \(name)"
        case .openURL(let url): return url.isEmpty ? "Open link…" : "Open \(url)"
        case .typeText(let text): return text.isEmpty ? "Type text…" : "Type “\(text.prefix(24))”"
        case .runMacro(let id): return "Run \(macroName(id))"
        case .switchMode(let m): return "Switch to \(modeName(m))"
        case .openRadialMenu: return "Open radial menu"
        case .previousMode: return "Back to previous mode"
        case .toggleEnabled: return "Turn Dialed off"
        }
    }

    public var symbol: String {
        switch self {
        case .none: return "circle.dashed"
        case .keyboardShortcut: return "command"
        case .media(let c): return c.symbol
        case .system(let c): return c.symbol
        case .appleShortcut: return "square.2.layers.3d"
        case .openApplication: return "app.badge"
        case .openURL: return "link"
        case .typeText: return "character.cursor.ibeam"
        case .runMacro: return "wand.and.stars"
        case .switchMode: return "dial.medium"
        case .openRadialMenu: return "circle.circle"
        case .previousMode: return "arrow.uturn.backward"
        case .toggleEnabled: return "power"
        }
    }
}

/// Flat list of action types, used by pickers in the UI.
public enum ActionKind: String, CaseIterable, Identifiable, Sendable {
    case none, keyboardShortcut, media, system, appleShortcut, openApplication, openURL,
         typeText, runMacro, switchMode, openRadialMenu, previousMode, toggleEnabled

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return "Nothing"
        case .keyboardShortcut: return "Keyboard shortcut"
        case .media: return "Media control"
        case .system: return "System action"
        case .appleShortcut: return "Apple Shortcut"
        case .openApplication: return "Open app"
        case .openURL: return "Open link"
        case .typeText: return "Type text"
        case .runMacro: return "Run macro"
        case .switchMode: return "Switch mode"
        case .openRadialMenu: return "Open radial menu"
        case .previousMode: return "Previous mode"
        case .toggleEnabled: return "Turn Dialed off"
        }
    }

    /// A sensible starting value when the user picks this type in an editor.
    public func defaultAction(firstMacro: UUID?) -> Action {
        switch self {
        case .none: return .none
        case .keyboardShortcut: return .keyboardShortcut(combo: KeyCombo(KeyCode.space))
        case .media: return .media(command: .playPause)
        case .system: return .system(command: .missionControl)
        case .appleShortcut: return .appleShortcut(name: "")
        case .openApplication: return .openApplication(bundleID: "", name: "")
        case .openURL: return .openURL(url: "")
        case .typeText: return .typeText(text: "")
        case .runMacro: return firstMacro.map { .runMacro(id: $0) } ?? .none
        case .switchMode: return .switchMode(mode: BuiltinMode.volume.id)
        case .openRadialMenu: return .openRadialMenu
        case .previousMode: return .previousMode
        case .toggleEnabled: return .toggleEnabled
        }
    }
}
