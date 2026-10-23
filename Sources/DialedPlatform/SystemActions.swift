import Foundation
import AppKit
import DialedCore

public enum SystemActions {
    /// Returns an error message if the action couldn't run.
    @discardableResult
    public static func perform(_ command: SystemCommand) -> String? {
        switch command {
        case .missionControl:
            return openSystemApp(["/System/Applications/Mission Control.app"], args: [])
        case .appExpose:
            EventPoster.key(KeyCombo(KeyCode.downArrow, .control))
        case .showDesktop:
            return openSystemApp(["/System/Applications/Mission Control.app"], args: ["1"])
        case .launchpad:
            return openSystemApp(["/System/Applications/Apps.app", "/System/Applications/Launchpad.app"], args: [])
        case .lockScreen:
            EventPoster.key(KeyCombo(KeyCode.q, [.control, .command]))
        case .screenshot:
            EventPoster.key(KeyCombo(0x17, [.shift, .command])) // ⇧⌘5
        case .spotlight:
            EventPoster.key(KeyCombo(KeyCode.space, .command))
        case .toggleMute:
            EventPoster.systemKey(.mute)
        case .sleepDisplay:
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            p.arguments = ["displaysleepnow"]
            do { try p.run() } catch { return "Couldn’t sleep the display: \(error.localizedDescription)" }
        }
        return nil
    }

    private static func openSystemApp(_ paths: [String], args: [String]) -> String? {
        guard let path = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return "This macOS version doesn’t include that feature."
        }
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = args
        config.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: config)
        return nil
    }
}
