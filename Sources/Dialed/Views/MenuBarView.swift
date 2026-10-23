import SwiftUI
import DialedCore
import DialedPlatform

/// The panel that drops down from the menu bar icon.
struct MenuBarView: View {
    @EnvironmentObject private var app: AppController
    @Environment(\.dismiss) private var dismiss

    /// The middle area keeps one height in every state: MenuBarExtra windows on
    /// macOS 27 don't shrink when content gets shorter, which left an empty band.
    static let bodyHeight: CGFloat = 300

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Group {
                if !app.enabled { offCard }
                else if app.isReady { readyBody }
                else { setupBody }
            }
            .frame(height: Self.bodyHeight, alignment: .top)
            Divider()
            footer
            MadeWithLove(font: .caption2)
                .frame(maxWidth: .infinity)
                .padding(.top, -6)
        }
        .padding(16)
        .frame(width: 340)
    }

    private var readyBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            status
            if let error = app.lastError { errorBanner(error) }
            ScrollView { modeGrid }
                .scrollIndicators(.automatic)
        }
    }

    private var setupBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            status
            if let error = app.lastError { errorBanner(error) }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 8) {
                Label("Finish setup to use the dial", systemImage: "checklist").font(.callout.weight(.semibold))
                Text("Dialed needs the buds connected and Accessibility allowed. The setup guide walks you through it.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Open Setup Guide") { dismiss(); WindowManager.shared.showOnboarding() }
                    .controlSize(.small)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var offCard: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            Image(systemName: "dial.low")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("Dialed is off").font(.title3.weight(.semibold))
            Text("Your buds work normally: turning changes the volume and presses control your music.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
            Button("Turn On") { app.setEnabled(true) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 12) {
            IconTile(symbol: app.enabled ? "dial.medium.fill" : "dial.low", size: 36,
                     tint: app.enabled ? Theme.accent : .gray)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dialed").font(.headline)
                Text(headline).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Toggle("Enabled", isOn: Binding(get: { app.enabled }, set: { app.setEnabled($0) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Theme.accent)
                .accessibilityLabel("Dialed enabled")
                .help(app.enabled ? "Turn off: the buds control music normally" : "Turn on the dial controller")
        }
    }

    private var headline: String {
        if !app.enabled { return "Off — buds control music normally" }
        if !app.buds.isConnected { return "Waiting for CMF Buds Pro 2" }
        if !app.accessibilityGranted { return "Needs Accessibility permission" }
        return "\(app.currentModeInfo.name) · \(app.activeProfile.name)"
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch app.buds {
            case .connected(let name, _):
                StatusRow(level: app.keepAliveRunning ? .ok : .warning, title: name,
                          detail: app.keepAliveRunning ? "Dial link active" : "Connected — starting dial link…")
            case .searching:
                HStack {
                    StatusRow(level: .warning, title: "Buds not connected", detail: "Open the case and connect them to this Mac")
                    Spacer()
                    Button("Bluetooth…") { Permissions.openBluetoothSettings() }.controlSize(.small)
                }
            }
            if !app.accessibilityGranted {
                HStack {
                    StatusRow(level: .error, title: "Accessibility not allowed", detail: "Needed to send keys and scroll")
                    Spacer()
                    Button("Allow…") { app.requestAccessibility() }.controlSize(.small)
                }
            }
        }
    }

    private var modeGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Mode").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text(app.currentModeInfo.turnHint).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(app.settings.allModes, id: \.id) { info in
                    ModeButton(info: info, selected: info.id == app.currentMode) { app.switchMode(info.id) }
                }
            }
        }
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(text).font(.caption).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { app.lastError = nil } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .accessibilityLabel("Dismiss message")
        }
        .padding(10)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private var footer: some View {
        HStack(spacing: 2) {
            FooterButton(title: "Settings", symbol: "gearshape") { dismiss(); WindowManager.shared.showSettings() }
            FooterButton(title: "Diagnostics", symbol: "waveform.path.ecg") { dismiss(); WindowManager.shared.showDiagnostics() }
            FooterButton(title: "Radial", symbol: "circle.circle") { dismiss(); app.openRadialMenu() }
                .disabled(!app.enabled)
            Spacer()
            FooterButton(title: "Quit", symbol: "power") { NSApp.terminate(nil) }
        }
    }
}

private struct ModeButton: View {
    var info: ModeInfo
    var selected: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: info.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(height: 18)
                Text(info.name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(selected ? .white : .primary)
            .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(info.turnHint)
        .accessibilityLabel(info.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var background: AnyShapeStyle {
        if selected { return AnyShapeStyle(Theme.accent.gradient) }
        return AnyShapeStyle(Color.primary.opacity(hovering ? 0.1 : 0.05))
    }
}

private struct FooterButton: View {
    var title: String
    var symbol: String
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.callout)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(hovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

