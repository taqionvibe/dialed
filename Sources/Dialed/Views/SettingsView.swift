import SwiftUI
import UniformTypeIdentifiers
import DialedCore
import DialedPlatform

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, dial, gestures, radial, profiles, modes, macros, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .dial: return "Dial & Sensitivity"
        case .gestures: return "Presses"
        case .radial: return "Radial Menu"
        case .profiles: return "App Profiles"
        case .modes: return "Custom Modes"
        case .macros: return "Macros"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .dial: return "dial.medium.fill"
        case .gestures: return "hand.tap.fill"
        case .radial: return "circle.circle.fill"
        case .profiles: return "person.crop.rectangle.stack.fill"
        case .modes: return "slider.horizontal.3"
        case .macros: return "wand.and.stars"
        case .about: return "info.circle.fill"
        }
    }
}

final class SettingsNavigation: ObservableObject {
    @Published var page: SettingsPage = .general
    /// The profile edited on the Presses and Radial Menu pages.
    @Published var profileID: UUID?
}

struct SettingsView: View {
    @ObservedObject var navigation: SettingsNavigation
    @EnvironmentObject private var app: AppController

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: Binding(get: { navigation.page }, set: { if let p = $0 { navigation.page = p } })) { page in
                Label { Text(page.title) } icon: { IconTile(symbol: page.symbol, size: 22) }
                    .tag(page)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
        } detail: {
            Group {
                switch navigation.page {
                case .general: GeneralPage()
                case .dial: DialPage()
                case .gestures: GesturesPage(navigation: navigation)
                case .radial: RadialPage(navigation: navigation)
                case .profiles: ProfilesPage(navigation: navigation)
                case .modes: CustomModesPage()
                case .macros: MacrosPage()
                case .about: AboutPage()
                }
            }
            .navigationTitle(navigation.page.title)
        }
        .tint(Theme.accent)
    }
}

/// Binding helper that writes through `AppController.update`.
extension AppController {
    func binding<T>(_ keyPath: WritableKeyPath<DialedSettings, T>) -> Binding<T> {
        Binding(get: { self.settings[keyPath: keyPath] }, set: { v in self.update { $0[keyPath: keyPath] = v } })
    }
}

// MARK: - General

struct GeneralPage: View {
    @EnvironmentObject private var app: AppController
    @State private var importNotes: [String] = []
    @State private var showImportNotes = false
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable Dialed", isOn: Binding(get: { app.enabled }, set: { app.setEnabled($0) }))
                Text("When off, Dialed releases the buds completely: turning changes volume and presses control your music, exactly as without Dialed.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Launch at login", isOn: Binding(get: { app.launchAtLogin }, set: { app.setLaunchAtLogin($0) }))
                if LoginItem.needsApproval {
                    Text("Approve Dialed in System Settings → General → Login Items.").font(.caption).foregroundStyle(.orange)
                }
            }
            Section("On-screen feedback") {
                Toggle("Show feedback when the dial is used", isOn: app.binding(\.general.showHUD))
                Picker("Position", selection: app.binding(\.general.hudPosition)) {
                    ForEach(HUDPosition.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .disabled(!app.settings.general.showHUD)
                Toggle("Play a soft sound in the radial menu", isOn: app.binding(\.general.soundFeedback))
            }
            Section("Modes & profiles") {
                ModePicker(selection: app.binding(\.general.startMode), title: "Start in")
                Toggle("Switch profiles automatically with the front app", isOn: app.binding(\.general.autoProfileSwitching))
            }
            Section {
                TextField("Buds name contains", text: app.binding(\.general.deviceNameMatch))
                LabeledContent("Detected") {
                    switch app.buds {
                    case .connected(let name, let isDefault):
                        Text("\(name)\(isDefault ? " · current output" : "")").foregroundStyle(.secondary)
                    case .searching:
                        Text("Not connected").foregroundStyle(.orange)
                    }
                }
            } header: {
                Text("Buds")
            } footer: {
                FormNote("Dialed listens to the Bluetooth audio device whose name contains this text.")
            }
            UpdatesSection()
            Section("Settings file") {
                HStack {
                    Button("Export…", action: exportSettings)
                    Button("Import…", action: importSettings)
                    Spacer()
                    Button("Run Setup Again") { WindowManager.shared.showOnboarding() }
                    Button("Reset…", role: .destructive) { confirmReset = true }
                }
            }
        }
        .formStyle(.grouped)
        .alert("Imported settings", isPresented: $showImportNotes) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importNotes.joined(separator: "\n"))
        }
        .confirmationDialog("Reset all Dialed settings?", isPresented: $confirmReset) {
            Button("Reset to Defaults", role: .destructive) { app.resetToDefaults() }
        } message: {
            Text("Profiles, custom modes and macros will be removed. Export first if you want a backup.")
        }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Dialed Settings.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try SettingsStore.exportData(app.settings).write(to: url, options: .atomic)
        } catch {
            app.report("Couldn’t export settings: \(error.localizedDescription)")
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let (settings, notes) = try SettingsStore.importData(Data(contentsOf: url))
            app.replaceSettings(settings)
            importNotes = notes.isEmpty ? ["Everything was imported."] : notes
            showImportNotes = true
        } catch {
            app.report((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

// MARK: - Dial

struct DialPage: View {
    @EnvironmentObject private var app: AppController

    var body: some View {
        Form {
            Section("Speed") {
                LabeledSlider(title: "Scroll distance per click", value: app.binding(\.sensitivity.scrollPixelsPerClick),
                              range: 20...800, step: 10, format: { "\(Int($0)) pt" })
                LabeledSlider(title: "Fast-spin boost", value: app.binding(\.sensitivity.acceleration),
                              range: 0...1, step: 0.05, format: { $0 == 0 ? "Off" : "up to \(String(format: "%.1f", 1 + 4 * $0))×" })
                LabeledSlider(title: "Brightness per click", value: app.binding(\.sensitivity.brightnessStep),
                              range: 0.01...0.25, step: 0.01, format: { "\(Int(($0 * 100).rounded()))%" })
                Stepper("Seek presses per click: \(app.settings.sensitivity.seekPressesPerClick)",
                        value: app.binding(\.sensitivity.seekPressesPerClick), in: 1...10)
            }
            Section("Direction") {
                Toggle("Reverse dial direction", isOn: app.binding(\.sensitivity.reverseDirection))
                Toggle("Clockwise scrolls down", isOn: app.binding(\.sensitivity.naturalScroll))
            }
            Section {
                Toggle("Ignore a lone click after a pause", isOn: app.binding(\.general.accidentalTurnGuard))
                LabeledSlider(title: "Pause length", value: app.binding(\.general.guardIdleSeconds),
                              range: 5...120, step: 5, format: { "\(Int($0)) s" })
                    .disabled(!app.settings.general.accidentalTurnGuard)
            } header: {
                Text("Accidental turns")
            } footer: {
                FormNote("Applies to Media, Browser Tabs, App Switcher, Windows and Undo / Redo, where a stray click would do something you’d notice. The first click after the pause only wakes the dial.")
            }
            Section("Radial menu") {
                LabeledSlider(title: "Close after", value: app.binding(\.general.radialTimeout),
                              range: 2...30, step: 1, format: { "\(Int($0)) s" })
                Toggle("Switch to the highlighted mode when it closes", isOn: app.binding(\.general.radialTimeoutSelects))
            }
            Section("How the dial reaches your Mac") {
                HardwareFactsView()
            }
        }
        .formStyle(.grouped)
    }
}

struct LabeledSlider: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var format: (Double) -> String

    var body: some View {
        LabeledContent {
            HStack {
                Slider(value: $value, in: range, step: step)
                    .frame(minWidth: 160)
                    .accessibilityLabel(title)
                    .accessibilityValue(format(value))
                Text(format(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 84, alignment: .trailing)
            }
        } label: {
            Text(title)
        }
    }
}

extension LabeledSlider {
    init(title: String, value: Binding<Int>, range: ClosedRange<Double>, step: Double, format: @escaping (Double) -> String) {
        self.init(title: title, value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0) }),
                  range: range, step: step, format: format)
    }
}

/// The tested facts about the buds on macOS, shown in Settings and onboarding.
struct HardwareFactsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            fact("checkmark.circle.fill", .green, "Turn", "Arrives as a volume step (16 per full range). Dialed restores your volume after each click.")
            fact("checkmark.circle.fill", .green, "Single / double press", "Arrive as play-pause / next track.")
            fact("checkmark.circle.fill", .green, "Triple press", "Arrives as previous track — only if Nothing X sets Triple to “Previous track”. Opens the radial menu by default.")
            fact("xmark.circle.fill", .red, "Hold", "Handled inside the buds (hold ~3 s = noise cancellation, press then hold = lock turning) and never reaches macOS.")
            fact("lock.circle.fill", .orange, "Turning locked", "If turning does nothing, the dial may be locked — press once, then hold, to unlock it.")
            fact("exclamationmark.circle.fill", .orange, "Fast spins", "The buds report about one click every half second while spinning; Dialed boosts fast spins to make up for dropped clicks.")
        }
        .font(.callout)
    }

    private func fact(_ symbol: String, _ color: Color, _ title: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color).accessibilityHidden(true)
            Text("**\(title)** — \(text)").fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Settings → General → Updates.
struct UpdatesSection: View {
    @ObservedObject private var updater = UpdaterModel.shared

    var body: some View {
        Section {
            if updater.isAvailable {
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { updater.automaticallyChecks }, set: { updater.automaticallyChecks = $0 }))
                Toggle("Download and install updates automatically", isOn: Binding(
                    get: { updater.automaticallyInstalls }, set: { updater.automaticallyInstalls = $0 }))
                    .disabled(!updater.automaticallyChecks)
                LabeledContent("Last checked") {
                    if let date = updater.lastCheck {
                        Text(date, format: .relative(presentation: .named)).foregroundStyle(.secondary)
                    } else {
                        Text("Never").foregroundStyle(.secondary)
                    }
                }
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheck)
            } else {
                Text("This is a development build, so automatic updates are off. Release builds from GitHub update themselves.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        } header: {
            Text("Updates")
        } footer: {
            FormNote("Updates are signed; Dialed only installs versions published by its developer. Because the app isn’t notarized, macOS may ask for Accessibility again after an update.")
        }
    }
}
