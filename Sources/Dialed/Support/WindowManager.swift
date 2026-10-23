import AppKit
import SwiftUI

/// Owns Dialed's regular windows. Dialed is a menu bar (accessory) app, so windows
/// are created on demand and the app is activated to bring them forward.
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()

    enum Kind: String { case settings, diagnostics, onboarding }

    private var windows: [Kind: NSWindow] = [:]
    /// Settings page to show when the window opens (set before `showSettings`).
    let settingsNavigation = SettingsNavigation()

    func showSettings(page: SettingsPage? = nil) {
        if let page { settingsNavigation.page = page }
        show(.settings, title: "Dialed Settings", size: CGSize(width: 880, height: 620), minSize: CGSize(width: 760, height: 520)) {
            SettingsView(navigation: self.settingsNavigation).environmentObject(AppController.shared)
        }
    }

    func showDiagnostics() {
        show(.diagnostics, title: "Dialed Diagnostics", size: CGSize(width: 820, height: 640), minSize: CGSize(width: 680, height: 520)) {
            DiagnosticsView(diagnostics: AppController.shared.diagnostics).environmentObject(AppController.shared)
        }
    }

    func showOnboarding() {
        show(.onboarding, title: "Welcome to Dialed", size: CGSize(width: 720, height: 560), minSize: CGSize(width: 720, height: 560), resizable: false) {
            OnboardingView(diagnostics: AppController.shared.diagnostics).environmentObject(AppController.shared)
        }
    }

    func close(_ kind: Kind) { windows[kind]?.close() }

    private func show<Content: View>(_ kind: Kind, title: String, size: CGSize, minSize: CGSize,
                                     resizable: Bool = true, content: () -> Content) {
        NSApp.activate()
        if let w = windows[kind] {
            w.makeKeyAndOrderFront(nil)
            return
        }
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        if resizable { style.insert(.resizable) }
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: style, backing: .buffered, defer: false)
        w.title = title
        w.titlebarAppearsTransparent = kind == .onboarding
        w.isReleasedWhenClosed = false
        w.contentMinSize = minSize
        w.contentViewController = NSHostingController(rootView: content())
        w.setContentSize(size)
        w.center()
        w.setFrameAutosaveName("Dialed.\(kind.rawValue)")
        w.delegate = self
        w.identifier = NSUserInterfaceItemIdentifier(kind.rawValue)
        windows[kind] = w
        w.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? NSWindow, let id = w.identifier?.rawValue, let kind = Kind(rawValue: id) else { return }
        windows[kind] = nil
        if kind == .onboarding { AppController.shared.update { $0.onboardingCompleted = true } }
    }
}
