import Foundation
import AppKit

/// Sleep/wake, frontmost-app changes and hardware volume keys.
public final class SystemMonitors {
    public var onWillSleep: (() -> Void)?
    public var onDidWake: (() -> Void)?
    public var onFrontmostApp: ((NSRunningApplication) -> Void)?
    /// A volume key (or mute) was pressed on the keyboard.
    public var onVolumeKey: (() -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var keyMonitor: Any?

    public init() {}

    public func start() {
        let nc = NSWorkspace.shared.notificationCenter
        observers.append(nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.onWillSleep?()
        })
        observers.append(nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.onDidWake?()
        })
        observers.append(nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.onFrontmostApp?(app)
            }
        })
        startKeyMonitor()
    }

    /// Needs Accessibility; call again once it has been granted.
    public func startKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard event.subtype.rawValue == 8 else { return }
            let key = (event.data1 & 0xFFFF0000) >> 16
            if key == 0 || key == 1 || key == 7 { self?.onVolumeKey?() }
        }
    }

    public func stop() {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}
