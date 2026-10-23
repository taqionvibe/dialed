import SwiftUI
import DialedCore
import DialedPlatform

/// First-run setup: Nothing X gestures, connection, permission, and a live test.
struct OnboardingView: View {
    @ObservedObject var diagnostics: DiagnosticsModel
    @EnvironmentObject private var app: AppController
    @State private var step: Step

    init(diagnostics: DiagnosticsModel, initialStep: Step = .welcome) {
        self.diagnostics = diagnostics
        _step = State(initialValue: initialStep)
    }

    enum Step: Int, CaseIterable {
        case welcome, nothingX, connect, permission, tryIt, done
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                content
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 44)
            .padding(.top, 36)
            Divider()
            footer
        }
        .frame(width: 720, height: 560)
        .tint(Theme.accent)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: welcome
        case .nothingX: nothingX
        case .connect: connect
        case .permission: permission
        case .tryIt: tryIt
        case .done: done
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { s in
                    Capsule().fill(s == step ? Theme.accent : Color.primary.opacity(0.15))
                        .frame(width: s == step ? 18 : 7, height: 7)
                }
            }
            .animation(Theme.spring, value: step)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
            Spacer()
            if step != .welcome && step != .done {
                Button("Back") { go(-1) }
            }
            if let skip = skipTitle {
                Button(skip) { go(1) }
            }
            Button(primaryTitle) {
                if step == .done { finish() } else { go(1) }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!canContinue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: return "Get Started"
        case .done: return "Finish"
        default: return "Continue"
        }
    }

    private var skipTitle: String? {
        switch step {
        case .connect where !app.buds.isConnected: return "Skip for Now"
        case .permission where !app.accessibilityGranted: return "Skip for Now"
        case .tryIt: return (diagnostics.counts.values.reduce(0, +) == 0) ? "Skip Test" : nil
        default: return nil
        }
    }

    private var canContinue: Bool {
        switch step {
        case .connect: return app.buds.isConnected
        case .permission: return app.accessibilityGranted
        case .tryIt: return diagnostics.counts.values.reduce(0, +) > 0
        default: return true
        }
    }

    private func go(_ delta: Int) {
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        if next == .tryIt { diagnostics.clear(); diagnostics.pauseActions = true }
        if step == .tryIt { diagnostics.pauseActions = false }
        withAnimation(Theme.spring) { step = next }
    }

    private func finish() {
        diagnostics.pauseActions = false
        app.update { $0.onboardingCompleted = true }
        WindowManager.shared.close(.onboarding)
    }

    // MARK: Steps

    private func header(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            IconTile(symbol: symbol, size: 44)
            Text(title).font(.system(size: 26, weight: .bold))
            Text(subtitle).font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            Image(nsImage: AppIconImage.image).resizable().frame(width: 110, height: 110)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Welcome to Dialed").font(.system(size: 30, weight: .bold))
                Text("Turn the Smart Dial on your CMF Buds Pro 2 case into a controller for your Mac.")
                    .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            HStack(spacing: 14) {
                feature("arrow.clockwise", "Turn", "Volume, scrolling, seeking, tabs, slides and more")
                feature("circle.circle", "Triple-press", "Opens a radial menu to switch modes")
                feature("person.crop.rectangle.stack", "Per app", "Profiles switch automatically with the front app")
            }
            .padding(.top, 8)
            MadeWithLove()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func feature(_ symbol: String, _ title: String, _ text: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                IconTile(symbol: symbol, size: 30)
                Text(title).font(.headline)
                Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var nothingX: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("slider.horizontal.below.square.and.square.filled", "Set up the dial in Nothing X",
                   "Dialed reads the dial through the buds’ music controls. In the Nothing X app open CMF Buds Pro 2 → Controls → Dial and set:")
            Card(padding: 0) {
                VStack(spacing: 0) {
                    gestureRow("Single press", "Play / Pause", "Required", .green)
                    Divider()
                    gestureRow("Double press", "Next track", "Required — skips to the next song", .green)
                    Divider()
                    gestureRow("Triple press", "Previous track", "Required — opens the radial menu. Low lag mode etc. never reach the Mac", .green)
                    Divider()
                    gestureRow("Press and hold", "Anything", "Stays in the buds (e.g. noise cancellation)", .secondary)
                    Divider()
                    gestureRow("Turn", "Volume (default)", "Required", .green)
                }
            }
            Label("If your phone is also connected to the buds, let the Mac be the active device. Dialed keeps the Mac active automatically while it runs.", systemImage: "iphone.gen3")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func gestureRow(_ gesture: String, _ setting: String, _ note: String, _ color: Color) -> some View {
        HStack {
            Text(gesture).font(.body.weight(.medium)).frame(width: 140, alignment: .leading)
            Text(setting).font(.body.weight(.semibold)).foregroundStyle(Theme.accent).frame(width: 150, alignment: .leading)
            Text(note).font(.callout).foregroundStyle(color == .secondary ? .secondary : .primary)
            Spacer()
            Circle().fill(color).frame(width: 8, height: 8).accessibilityHidden(true)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var connect: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("earbuds", "Connect your buds", "Pair CMF Buds Pro 2 with this Mac and keep them connected. Dialed finds them automatically and reconnects after sleep or when you take them out of the case.")
            Card {
                HStack(spacing: 14) {
                    if app.buds.isConnected {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 30)).foregroundStyle(.green)
                    } else {
                        ProgressView().controlSize(.regular)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        switch app.buds {
                        case .connected(let name, _):
                            Text("\(name) connected").font(.headline)
                            Text("Ready to receive the dial.").foregroundStyle(.secondary)
                        case .searching:
                            Text("Looking for CMF Buds Pro 2…").font(.headline)
                            Text("Open the case near your Mac, or connect from Bluetooth settings.").foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if !app.buds.isConnected {
                        Button("Bluetooth Settings…") { Permissions.openBluetoothSettings() }
                    }
                }
            }
            .animation(Theme.spring, value: app.buds)
        }
    }

    private var permission: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("lock.open.fill", "Allow Accessibility", "Dialed needs Accessibility permission to send keyboard shortcuts, smooth scrolling and media keys to your apps. It doesn’t read what you type.")
            Card {
                HStack(spacing: 14) {
                    Image(systemName: app.accessibilityGranted ? "checkmark.circle.fill" : "hand.raised.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(app.accessibilityGranted ? .green : .orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.accessibilityGranted ? "Accessibility allowed" : "Not allowed yet").font(.headline)
                        Text(app.accessibilityGranted ? "You’re all set." :
                                "Click Open Settings, then switch on Dialed under Privacy & Security → Accessibility. If Dialed is already listed, switch it off and on.")
                            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if !app.accessibilityGranted {
                        Button("Open Settings…") { app.requestAccessibility() }
                    }
                }
            }
            .animation(Theme.spring, value: app.accessibilityGranted)
        }
    }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("dial.medium.fill", "Try the dial", "Turn the dial both ways and try each press. Tiles light up as Dialed receives them. Nothing is sent to your apps during this test.")
            GestureLights(diagnostics: diagnostics)
            if let last = diagnostics.events.last(where: { $0.category == .turn || $0.category == .press }) {
                Label(last.text, systemImage: "waveform")
                    .font(.callout.monospaced()).foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if !app.buds.isConnected {
                Label("The buds aren’t connected, so nothing can arrive yet.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                Label("Waiting for the dial…", systemImage: "ellipsis").foregroundStyle(.secondary)
            }
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("checkmark.seal.fill", "You’re ready", "Dialed lives in the menu bar. Turn to use the current mode, triple-press to open the radial menu. Single press is the mode’s action, double press skips to the next song.")
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch Dialed at login", isOn: Binding(get: { app.launchAtLogin }, set: { app.setLaunchAtLogin($0) }))
                    Toggle("Show on-screen feedback", isOn: app.binding(\.general.showHUD))
                    Toggle("Switch profiles automatically with the front app", isOn: app.binding(\.general.autoProfileSwitching))
                }
            }
            HStack {
                Button("Customize in Settings…") { finish(); WindowManager.shared.showSettings() }
                Button("Open Diagnostics") { finish(); WindowManager.shared.showDiagnostics() }
            }
        }
    }
}
