import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DialedCore
import DialedPlatform

/// Live view of everything the buds send, how Dialed decodes it, and what it does.
struct DiagnosticsView: View {
    @ObservedObject var diagnostics: DiagnosticsModel
    @EnvironmentObject private var app: AppController
    @State private var filter: DiagnosticEvent.Category?

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                connectionCard
                linkCard
            }
            GestureLights(diagnostics: diagnostics)
            Label("No turns arriving? Turning may be locked — press the dial once, then hold, to unlock it. Holds themselves never reach the Mac.",
                  systemImage: "lightbulb")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            logCard
        }
        .padding(18)
        .frame(minWidth: 680, minHeight: 520)
    }

    private var connectionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Buds").font(.headline)
                switch app.buds {
                case .connected(let name, let isDefault):
                    StatusRow(level: .ok, title: name, detail: isDefault ? "Current audio output" : "Connected (not the current output)")
                case .searching:
                    StatusRow(level: .warning, title: "Not connected", detail: "Connect CMF Buds Pro 2 in Bluetooth settings")
                }
                if let v = app.budsVolume {
                    LabeledContent("Buds volume") {
                        Text("\(Int((v * 100).rounded()))%  ·  AVRCP \(Int((Double(v) * 127).rounded()))/127  ·  step \(VolumeGrid.index(of: v))/16")
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
        }
    }

    private var linkCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dial link").font(.headline)
                StatusRow(level: !app.enabled ? .neutral : (app.keepAliveRunning ? .ok : .warning),
                          title: !app.enabled ? "Dialed is off" : (app.keepAliveRunning ? "Receiving the dial" : "Waiting for the buds"),
                          detail: app.enabled ? "Silent audio keeps the Mac as the buds’ active device" : "Turn Dialed on to capture the dial")
                StatusRow(level: app.accessibilityGranted ? .ok : .error,
                          title: app.accessibilityGranted ? "Accessibility allowed" : "Accessibility not allowed",
                          detail: app.accessibilityGranted ? "Keys, scrolling and media keys can be sent" : "Outputs are dropped until you allow it")
                if let i = diagnostics.lastReportInterval {
                    LabeledContent("Last turn interval") {
                        Text(String(format: "%.2f s", i)).monospacedDigit().foregroundStyle(.secondary)
                    }.font(.callout)
                }
            }
        }
    }

    private var logCard: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Event log").font(.headline)
                    Picker("Show", selection: $filter) {
                        Text("All").tag(DiagnosticEvent.Category?.none)
                        Text("Turns").tag(DiagnosticEvent.Category?.some(.turn))
                        Text("Presses").tag(DiagnosticEvent.Category?.some(.press))
                        Text("Actions").tag(DiagnosticEvent.Category?.some(.action))
                        Text("System").tag(DiagnosticEvent.Category?.some(.system))
                        Text("Warnings").tag(DiagnosticEvent.Category?.some(.warning))
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 380)
                    Spacer()
                    Toggle("Test only", isOn: $diagnostics.pauseActions)
                        .toggleStyle(.checkbox)
                        .help("Log the dial without performing any actions")
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(diagnostics.exportText, forType: .string)
                    }
                    Button("Save…", action: save)
                    Button("Clear") { diagnostics.clear() }
                }
                .padding(12)
                Divider()
                ScrollViewReader { proxy in
                    List(filtered) { e in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(e.date, format: .dateTime.hour().minute().second())
                                .monospacedDigit().foregroundStyle(.secondary)
                            Text(e.category.label)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(e.category.color)
                                .frame(width: 58, alignment: .leading)
                            Text(e.text).textSelection(.enabled)
                        }
                        .font(.system(.callout, design: .monospaced))
                        .id(e.id)
                    }
                    .listStyle(.plain)
                    .overlay {
                        if filtered.isEmpty {
                            Text("Turn or press the dial — events appear here.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: diagnostics.events.count) {
                        if let last = filtered.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
            }
        }
    }

    private var filtered: [DiagnosticEvent] {
        guard let filter else { return diagnostics.events }
        return diagnostics.events.filter { $0.category == filter }
    }

    private func save() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Dialed Diagnostics.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try diagnostics.exportText.write(to: url, atomically: true, encoding: .utf8) }
        catch { app.report("Couldn’t save the log: \(error.localizedDescription)") }
    }
}

/// One tile per physical gesture that lights up when it is received.
struct GestureLights: View {
    @ObservedObject var diagnostics: DiagnosticsModel
    var compact = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ObservedGesture.allCases) { g in
                GestureLight(gesture: g, count: diagnostics.counts[g] ?? 0, lastSeen: diagnostics.lastSeen[g], compact: compact)
            }
        }
    }
}

private struct GestureLight: View {
    var gesture: ObservedGesture
    var count: Int
    var lastSeen: Date?
    var compact: Bool
    @State private var flash = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: gesture.symbol)
                .font(.system(size: compact ? 16 : 20, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: compact ? 40 : 48, height: compact ? 40 : 48)
                .background(background, in: Circle())
                .scaleEffect(flash ? 1.12 : 1)
            Text(gesture.title).font(.caption.weight(.medium))
            Text(caption).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 8 : 12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(gesture.isSupported ? 1 : 0.55)
        .onChange(of: count) {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { flash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { withAnimation(Theme.spring) { flash = false } }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(gesture.title): \(caption)")
        .help(gesture.isSupported ? "Lights up when Dialed receives this gesture" : "macOS never receives press-and-hold from the buds")
    }

    private var caption: String {
        if !gesture.isSupported { return "Not on macOS" }
        return count == 0 ? "Waiting" : "✓ \(count)×"
    }

    private var iconColor: Color { count > 0 || flash ? .white : .secondary }

    private var background: AnyShapeStyle {
        if !gesture.isSupported { return AnyShapeStyle(Color.primary.opacity(0.06)) }
        if count > 0 || flash { return AnyShapeStyle(Theme.accent.gradient) }
        return AnyShapeStyle(Color.primary.opacity(0.08))
    }
}
