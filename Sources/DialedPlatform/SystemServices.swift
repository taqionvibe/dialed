import Foundation
import AppKit
import ApplicationServices
import ServiceManagement
import DialedCore

/// Accessibility permission (needed to post keys, scrolls and media keys).
public enum Permissions {
    public static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt (once per app identity) and returns current state.
    @discardableResult
    public static func requestAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    public static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    public static func openAutomationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }

    public static func openBluetoothSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings")!
        NSWorkspace.shared.open(url)
    }

    public static func openSoundSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!
        NSWorkspace.shared.open(url)
    }
}

/// Launch at login via SMAppService (shows in System Settings → General → Login Items).
public enum LoginItem {
    public static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    public static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    public static func set(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}

/// Runs Apple Shortcuts through the `shortcuts` command-line tool.
public enum ShortcutsRunner {
    private static let tool = URL(fileURLWithPath: "/usr/bin/shortcuts")

    public static func list(completion: @escaping ([String]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let out = run(["list"]).output
            let names = out.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            DispatchQueue.main.async { completion(names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) }
        }
    }

    /// Runs a shortcut; completion receives an error message on failure.
    public static func run(named name: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = run(["run", name])
            let message: String? = result.status == 0 ? nil :
                (result.error.isEmpty ? "The shortcut “\(name)” didn’t finish (exit \(result.status))." : result.error)
            DispatchQueue.main.async { completion(message) }
        }
    }

    private static func run(_ args: [String]) -> (status: Int32, output: String, error: String) {
        let p = Process()
        p.executableURL = tool
        p.arguments = args
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        do { try p.run() } catch { return (-1, "", "Couldn’t start the Shortcuts tool: \(error.localizedDescription)") }
        let o = out.fileHandleForReading.readDataToEndOfFile()
        let e = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: o, as: UTF8.self),
                String(decoding: e, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

/// Forwards play/pause/next/previous to the user's real player. While Dialed is the
/// "now playing" app, media keys would come straight back to it, so scriptable
/// players get Apple Events and everything else gets a brief hand-over.
public final class MediaForwarder {
    private let receiver: RemoteCommandReceiver
    public var onError: ((String) -> Void)?

    public init(receiver: RemoteCommandReceiver) { self.receiver = receiver }

    private static let scriptable: [(bundleID: String, name: String)] = [
        ("com.spotify.client", "Spotify"), ("com.apple.Music", "Music"),
    ]

    public func send(_ command: MediaCommand) {
        if let player = activeScriptablePlayer() {
            let verb: String
            switch command {
            case .playPause: verb = "playpause"
            case .nextTrack: verb = "next track"
            case .previousTrack: verb = "previous track"
            }
            runScript("tell application \"\(player)\" to \(verb)")
            return
        }
        handOver(command)
    }

    /// Spotify or Music if running and playing (or the only one running).
    private func activeScriptablePlayer() -> String? {
        let running = Self.scriptable.filter { p in
            NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == p.bundleID }
        }
        if running.count <= 1 { return running.first?.name }
        for p in running where playerState(p.name) == "playing" { return p.name }
        return running.first?.name
    }

    private func playerState(_ app: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: "tell application \"\(app)\" to return (player state as text)")?
            .executeAndReturnError(&error)
        return result?.stringValue
    }

    private func runScript(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error, let code = error[NSAppleScript.errorNumber] as? Int, code == -1743 {
            onError?("Dialed isn’t allowed to control your music app. Allow it in System Settings → Privacy & Security → Automation.")
        }
    }

    /// Step out of "now playing", post the media key so macOS routes it to the
    /// previous player (browsers, video apps), then take the dial back.
    private func handOver(_ command: MediaCommand) {
        receiver.yield()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            switch command {
            case .playPause: EventPoster.systemKey(.play)
            case .nextTrack: EventPoster.systemKey(.next)
            case .previousTrack: EventPoster.systemKey(.previous)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.receiver.resume()
                // The player that just resumed claims "now playing" too; claim it back
                // quickly so the next press reaches Dialed.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self?.receiver.reassert() }
            }
        }
    }
}

/// Opens apps and links.
public enum Launcher {
    public static func openApp(bundleID: String, completion: @escaping (String?) -> Void) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            completion("Couldn’t find the app \(bundleID). It may have been moved or deleted.")
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            DispatchQueue.main.async { completion(error?.localizedDescription) }
        }
    }

    public static func openURL(_ string: String) -> String? {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespaces)), url.scheme != nil else {
            return "“\(string)” isn’t a valid link. Include https:// at the start."
        }
        return NSWorkspace.shared.open(url) ? nil : "macOS couldn’t open \(string)."
    }
}
