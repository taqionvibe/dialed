import SwiftUI
import AppKit
import DialedCore

@main
struct DialedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(AppController.shared)
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.window)
    }
}

/// Only the icon symbol is observed here, so the status item redraws only when the
/// symbol actually changes (redrawing it is expensive).
final class MenuBarIconModel: ObservableObject {
    static let shared = MenuBarIconModel()
    @Published var symbol = "dial.medium"
}

private struct MenuBarIcon: View {
    @ObservedObject private var model = MenuBarIconModel.shared
    var body: some View {
        Image(systemName: model.symbol).accessibilityLabel("Dialed")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hidden preference for testing and screen recording tools:
        //   defaults write io.github.taqionvibe.dialed ShowDockIcon -bool YES
        // `Dialed --render-screenshots <dir>`: render every screen to PNG and quit.
        // Doesn't touch audio, the buds or permissions (used for docs and visual review).
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--render-screenshots"), args.count > i + 1 {
            NSApp.setActivationPolicy(.accessory)
            MainActor.assumeIsolated {
                Task {
                    await ScreenshotRenderer.renderAll(to: URL(fileURLWithPath: args[i + 1]))
                    NSApp.terminate(nil)
                }
            }
            return
        }
        let showDock = UserDefaults.standard.bool(forKey: "ShowDockIcon")
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)
        MainActor.assumeIsolated {
            AppController.shared.start()
            UpdaterModel.shared.start()
            ScreenshotRenderer.installHook()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { AppController.shared.shutdown() }
    }

    /// Opening Dialed again (Finder, Spotlight) while it runs shows Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated { WindowManager.shared.showSettings() }
        return true
    }
}
