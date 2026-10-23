import SwiftUI
import DialedCore

/// Two-pane list + editor used by Custom Modes and Macros.
private struct ListDetail<Item: Identifiable, Row: View, Detail: View, Empty: View>: View where Item.ID == UUID {
    var items: [Item]
    @Binding var selection: UUID?
    var addTitle: String
    var onAdd: () -> Void
    var onDelete: (UUID) -> Void
    @ViewBuilder var row: (Item) -> Row
    @ViewBuilder var detail: (Item) -> Detail
    @ViewBuilder var empty: () -> Empty

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(items, selection: $selection) { item in row(item).tag(item.id) }
                Divider()
                HStack {
                    Button(action: onAdd) { Image(systemName: "plus") }
                        .buttonStyle(.borderless).accessibilityLabel(addTitle)
                    Button { if let s = selection { onDelete(s) } } label: { Image(systemName: "minus") }
                        .buttonStyle(.borderless).disabled(selection == nil).accessibilityLabel("Delete")
                    Spacer()
                }
                .padding(8)
            }
            .frame(width: 230)
            Divider()
            if let s = selection, let item = items.first(where: { $0.id == s }) {
                detail(item)
            } else {
                empty().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct EmptyState: View {
    var symbol: String
    var title: String
    var message: String
    var buttonTitle: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            IconTile(symbol: symbol, size: 48)
            Text(title).font(.title3.weight(.semibold))
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 340)
            Button(buttonTitle, action: action).buttonStyle(.borderedProminent)
        }
        .padding(30)
    }
}

// MARK: - Custom modes

struct CustomModesPage: View {
    @EnvironmentObject private var app: AppController
    @State private var selection: UUID?

    var body: some View {
        ListDetail(items: app.settings.customModes, selection: $selection, addTitle: "Add custom mode",
                   onAdd: add, onDelete: delete) { m in
            Label(m.name, systemImage: m.symbol)
        } detail: { m in
            editor(m.id)
        } empty: {
            EmptyState(symbol: "slider.horizontal.3", title: "Make the dial do anything",
                       message: "A custom mode runs one action when you turn clockwise and another when you turn back — for example ↑ / ↓ in a code editor, or Shortcuts that nudge your smart lights.",
                       buttonTitle: "New Custom Mode", action: add)
        }
        .onAppear { if selection == nil { selection = app.settings.customModes.first?.id } }
    }

    private func add() {
        let m = CustomMode(name: "My Mode", symbol: "dial.medium",
                           clockwise: .keyboardShortcut(combo: KeyCombo(KeyCode.downArrow)),
                           counterClockwise: .keyboardShortcut(combo: KeyCombo(KeyCode.upArrow)),
                           press: .keyboardShortcut(combo: KeyCombo(KeyCode.returnKey)))
        app.update { $0.customModes.append(m) }
        selection = m.id
    }

    private func delete(_ id: UUID) {
        app.update { $0.customModes.removeAll { $0.id == id } }
        selection = app.settings.customModes.first?.id
    }

    private func editor(_ id: UUID) -> some View {
        let i = app.settings.customModes.firstIndex { $0.id == id } ?? 0
        return Form {
            Section {
                HStack {
                    TextField("Name", text: app.binding(\.customModes[i].name))
                    SymbolPicker(symbol: app.binding(\.customModes[i].symbol))
                }
            }
            Section("Actions") {
                LabeledContent("Turn clockwise") { ActionEditor(action: app.binding(\.customModes[i].clockwise), allowEngineActions: false) }
                LabeledContent("Turn back") { ActionEditor(action: app.binding(\.customModes[i].counterClockwise), allowEngineActions: false) }
                LabeledContent("Press") { ActionEditor(action: app.binding(\.customModes[i].press)) }
            }
            Section {
                Toggle("Repeat on fast spins", isOn: app.binding(\.customModes[i].repeatOnFastSpin))
                Toggle("Ignore a lone click after a pause", isOn: app.binding(\.customModes[i].guarded))
            } footer: {
                FormNote("Add the mode to the radial menu in Radial Menu, or bind a press to “Switch mode”.")
            }
            Section {
                HStack {
                    Button("Use Now") { app.switchMode(app.settings.customModes[i].modeID) }
                    Button("Add to Radial Menu") {
                        let mid = app.settings.customModes[i].modeID
                        app.update { s in
                            if !s.profiles[0].radialItems.contains(where: { $0.target == .mode(mid) }) {
                                s.profiles[0].radialItems.append(RadialItem(target: .mode(mid)))
                            }
                        }
                    }
                    .disabled(app.settings.defaultProfile.radialItems.contains { $0.target == .mode(app.settings.customModes[i].modeID) })
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Macros

struct MacrosPage: View {
    @EnvironmentObject private var app: AppController
    @State private var selection: UUID?

    var body: some View {
        ListDetail(items: app.settings.macros, selection: $selection, addTitle: "Add macro",
                   onAdd: add, onDelete: delete) { m in
            Label(m.name, systemImage: m.symbol)
        } detail: { m in
            editor(m.id)
        } empty: {
            EmptyState(symbol: "wand.and.stars", title: "Chain actions together",
                       message: "A macro runs several actions in order with optional pauses — open an app, wait, press a shortcut, type text, run a Shortcut. Trigger it from a press or the radial menu.",
                       buttonTitle: "New Macro", action: add)
        }
        .onAppear { if selection == nil { selection = app.settings.macros.first?.id } }
    }

    private func add() {
        let m = Macro(name: "New Macro", steps: [.action(.keyboardShortcut(combo: KeyCombo(KeyCode.space, .command)))])
        app.update { $0.macros.append(m) }
        selection = m.id
    }

    private func delete(_ id: UUID) {
        app.update { $0.macros.removeAll { $0.id == id } }
        selection = app.settings.macros.first?.id
    }

    private func editor(_ id: UUID) -> some View {
        let i = app.settings.macros.firstIndex { $0.id == id } ?? 0
        let steps = app.settings.macros[i].steps
        return Form {
            Section {
                HStack {
                    TextField("Name", text: app.binding(\.macros[i].name))
                    SymbolPicker(symbol: app.binding(\.macros[i].symbol))
                }
            }
            Section {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .center) {
                        Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary).frame(width: 18)
                        stepEditor(step, macro: i, index: index)
                        Spacer()
                        Button { move(i, index, -1) } label: { Image(systemName: "chevron.up") }
                            .buttonStyle(.borderless).disabled(index == 0).accessibilityLabel("Move step up")
                        Button { move(i, index, 1) } label: { Image(systemName: "chevron.down") }
                            .buttonStyle(.borderless).disabled(index == steps.count - 1).accessibilityLabel("Move step down")
                        Button { app.update { $0.macros[i].steps.remove(at: index) } } label: { Image(systemName: "minus.circle.fill") }
                            .buttonStyle(.borderless).foregroundStyle(.red).accessibilityLabel("Delete step")
                    }
                }
                HStack {
                    Button { app.update { $0.macros[i].steps.append(.action(.keyboardShortcut(combo: KeyCombo(KeyCode.space)))) } } label: {
                        Label("Add Action", systemImage: "plus")
                    }
                    Button { app.update { $0.macros[i].steps.append(.wait(milliseconds: 500)) } } label: {
                        Label("Add Pause", systemImage: "timer")
                    }
                    .disabled(steps.count >= 40)
                }
            } header: {
                Text("Steps")
            } footer: {
                FormNote("Steps run top to bottom. Total pause: \(String(format: "%.1f", Double(app.settings.macros[i].totalWait) / 1000)) s.")
            }
            Section {
                HStack {
                    Button("Run Now") {
                        let macro = app.settings.macros[i]
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { app.runMacro(macro) }
                    }
                    .help("Runs in 1.5 seconds so you can switch to the target app")
                    .disabled(steps.isEmpty)
                    Text("Starts after 1.5 s so you can switch apps.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private func stepEditor(_ step: Macro.Step, macro i: Int, index: Int) -> some View {
        switch step {
        case .action(let a):
            ActionEditor(action: Binding(get: { a }, set: { new in app.update { $0.macros[i].steps[index] = .action(new) } }),
                         allowEngineActions: false)
        case .wait(let ms):
            Stepper("Pause \(ms) ms", value: Binding(get: { ms }, set: { v in app.update { $0.macros[i].steps[index] = .wait(milliseconds: v) } }),
                    in: 50...10000, step: 50)
        }
    }

    private func move(_ i: Int, _ index: Int, _ delta: Int) {
        app.update { s in
            let j = index + delta
            guard s.macros[i].steps.indices.contains(j) else { return }
            s.macros[i].steps.swapAt(index, j)
        }
    }
}

// MARK: - About

struct AboutPage: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: AppIconImage.image).resizable().frame(width: 72, height: 72).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dialed").font(.title.weight(.semibold))
                        Text("Version \(Bundle.main.shortVersion)").foregroundStyle(.secondary)
                        Text("The CMF Buds Pro 2 Smart Dial, as a Mac controller.").foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            Section("Tested on real hardware") {
                HardwareFactsView()
            }
            Section("Privacy") {
                Text("Dialed runs entirely on your Mac and sends nothing anywhere. It reads the buds’ volume level and media commands, and posts the keys and scrolls you configure.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section("Credits") {
                Text("Dial decoding is based on research from [Orbit](https://github.com/harsha20599/orbit) by harsha20599 (MIT License). Dialed is not affiliated with or endorsed by Nothing or CMF.")
                    .fixedSize(horizontal: false, vertical: true)
                Link("Dialed on GitHub", destination: URL(string: "https://github.com/taqionvibe/dialed")!)
                Button("Open Diagnostics") { WindowManager.shared.showDiagnostics() }
            }
        }
        .formStyle(.grouped)
    }
}
