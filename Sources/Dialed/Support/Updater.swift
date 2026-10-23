import AppKit
import Combine
import Sparkle

/// Automatic updates through Sparkle. Each release publishes an EdDSA-signed
/// `appcast.xml` next to `Dialed.dmg`; Dialed checks it once a day and offers (or,
/// if the user allows, silently installs) new versions.
@MainActor
final class UpdaterModel: NSObject, ObservableObject {
    static let shared = UpdaterModel()

    /// False for development builds without a feed URL / public key, or when
    /// running as a bare binary (render mode, `swift run`).
    let isAvailable: Bool
    @Published private(set) var canCheck = false
    @Published private(set) var lastCheck: Date?

    private var controller: SPUStandardUpdaterController?
    private var observations: [NSKeyValueObservation] = []

    private override init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let key = (info["SUPublicEDKey"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let feed = info["SUFeedURL"] as? String ?? ""
        isAvailable = Bundle.main.bundleURL.pathExtension == "app" && !key.isEmpty && !key.hasPrefix("__") && !feed.isEmpty
        super.init()
    }

    func start() {
        guard isAvailable, controller == nil else { return }
        let c = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
        controller = c
        let updater = c.updater
        observations = [
            updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] u, _ in
                MainActor.assumeIsolated { self?.canCheck = u.canCheckForUpdates }
            },
            updater.observe(\.lastUpdateCheckDate, options: [.initial, .new]) { [weak self] u, _ in
                MainActor.assumeIsolated { self?.lastCheck = u.lastUpdateCheckDate }
            },
        ]
    }

    func checkForUpdates() {
        NSApp.activate()
        controller?.checkForUpdates(nil)
    }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue; objectWillChange.send() }
    }

    var automaticallyInstalls: Bool {
        get { controller?.updater.automaticallyDownloadsUpdates ?? false }
        set { controller?.updater.automaticallyDownloadsUpdates = newValue; objectWillChange.send() }
    }
}

extension UpdaterModel: SPUStandardUserDriverDelegate {
    /// Dialed is a menu bar app; Sparkle's "gentle reminders" keep scheduled update
    /// alerts from popping up behind other windows.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        DispatchQueue.main.async { NSApp.activate() }
    }
}
