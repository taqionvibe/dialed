import SwiftUI
import DialedCore

/// "Editing: [profile ▾]" header for pages that edit one profile.
struct ProfileSelector: View {
    @ObservedObject var navigation: SettingsNavigation
    @EnvironmentObject private var app: AppController

    var body: some View {
        Picker("Profile", selection: Binding(get: { currentID }, set: { navigation.profileID = $0 })) {
            ForEach(app.settings.profiles) { p in
                Text(p.apps.isEmpty ? p.name : "\(p.name) (\(p.apps.count) app\(p.apps.count == 1 ? "" : "s"))").tag(p.id)
            }
        }
    }

    var currentID: UUID {
        if let id = navigation.profileID, app.settings.profile(id: id) != nil { return id }
        return app.settings.defaultProfile.id
    }
}

extension AppController {
    func profileIndex(_ id: UUID?) -> Int {
        guard let id, let i = settings.profiles.firstIndex(where: { $0.id == id }) else { return 0 }
        return i
    }
}

// MARK: - Presses

struct GesturesPage: View {
    @ObservedObject var navigation: SettingsNavigation
    @EnvironmentObject private var app: AppController

    var body: some View {
        let i = app.profileIndex(navigation.profileID)
        Form {
            Section {
                ProfileSelector(navigation: navigation)
            } footer: {
                FormNote("Each profile can use the dial differently. App profiles activate when their app is in front.")
            }
            Section("When a mode is active") {
                ForEach(PressKind.allCases, id: \.self) { kind in
                    LabeledContent {
                        GestureBindingEditor(binding: app.binding(\.profiles[i].gestures[kind]))
                    } label: {
                        Label(kind.title, systemImage: ObservedGesture.from(kind).symbol)
                    }
                }
                LabeledContent {
                    Text("Drives the current mode").foregroundStyle(.secondary)
                } label: {
                    Label("Turn", systemImage: "arrow.clockwise")
                }
                LabeledContent {
                    Text("Not available on macOS").foregroundStyle(.secondary)
                } label: {
                    Label("Press and hold", systemImage: "hand.point.up.left.fill").foregroundStyle(.secondary)
                }
            }
            Section("While the radial menu is open") {
                LabeledContent("Turn", value: "Moves the highlight")
                LabeledContent("Single press", value: "Chooses the highlighted item")
                LabeledContent("Double or triple press", value: "Closes without changing anything")
            }
            Section("What “Mode’s own action” does") {
                ForEach(BuiltinMode.allCases, id: \.self) { m in
                    LabeledContent { Text(m.pressHint).foregroundStyle(.secondary) } label: {
                        Label(m.name, systemImage: m.symbol)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Radial menu

struct RadialPage: View {
    @ObservedObject var navigation: SettingsNavigation
    @EnvironmentObject private var app: AppController
    @State private var editing: UUID?

    var body: some View {
        let i = app.profileIndex(navigation.profileID)
        let items = app.settings.profiles[i].radialItems
        Form {
            Section {
                ProfileSelector(navigation: navigation)
            }
            Section {
                RadialPreview(items: items)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            Section {
                List {
                    ForEach(items) { item in
                        RadialItemRow(item: item, isEditing: editing == item.id,
                                      binding: itemBinding(profile: i, id: item.id),
                                      onEdit: { editing = editing == item.id ? nil : item.id },
                                      onDelete: { delete(item.id, profile: i) },
                                      canDelete: items.count > 1)
                    }
                    .onMove { from, to in app.update { $0.profiles[i].radialItems.move(fromOffsets: from, toOffset: to) } }
                }
                HStack {
                    Menu {
                        ForEach(app.settings.allModes, id: \.id) { info in
                            Button { add(.mode(info.id), profile: i) } label: { Label(info.name, systemImage: info.symbol) }
                        }
                    } label: { Label("Add Mode", systemImage: "plus") }
                    .fixedSize()
                    Button { add(.action(.keyboardShortcut(combo: KeyCombo(KeyCode.space))), profile: i) } label: {
                        Label("Add Action", systemImage: "bolt.fill")
                    }
                    Spacer()
                    Text("\(items.count) of 12").foregroundStyle(.secondary).font(.caption)
                }
                .disabled(items.count >= 12)
            } header: {
                Text("Items")
            } footer: {
                FormNote("Drag to reorder. Turning the dial moves clockwise through this list.")
            }
        }
        .formStyle(.grouped)
    }

    private func itemBinding(profile i: Int, id: UUID) -> Binding<RadialItem> {
        Binding(
            get: { app.settings.profiles[i].radialItems.first { $0.id == id } ?? RadialItem(target: .action(.none)) },
            set: { new in app.update { s in
                if let j = s.profiles[i].radialItems.firstIndex(where: { $0.id == id }) { s.profiles[i].radialItems[j] = new }
            } })
    }

    private func add(_ target: RadialItem.Target, profile i: Int) {
        let item = RadialItem(target: target)
        app.update { $0.profiles[i].radialItems.append(item) }
        if case .action = target { editing = item.id }
    }

    private func delete(_ id: UUID, profile i: Int) {
        app.update { $0.profiles[i].radialItems.removeAll { $0.id == id } }
    }
}

private struct RadialItemRow: View {
    var item: RadialItem
    var isEditing: Bool
    @Binding var binding: RadialItem
    var onEdit: () -> Void
    var onDelete: () -> Void
    var canDelete: Bool
    @EnvironmentObject private var app: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary).accessibilityHidden(true)
                IconTile(symbol: app.settings.symbol(for: item), size: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.settings.label(for: item))
                    Text(kindText).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(isEditing ? "Done" : "Edit", action: onEdit).buttonStyle(.borderless)
                Button(role: .destructive, action: onDelete) { Image(systemName: "minus.circle.fill") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .disabled(!canDelete)
                    .help(canDelete ? "Remove from the radial menu" : "The radial menu needs at least one item")
                    .accessibilityLabel("Remove \(app.settings.label(for: item))")
            }
            if isEditing { editor.padding(.leading, 34) }
        }
        .padding(.vertical, 2)
    }

    private var kindText: String {
        switch item.target {
        case .mode: return "Mode"
        case .action(let a): return "Action · \(a.kind.title)"
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Label").frame(width: 56, alignment: .leading)
                TextField(app.settings.label(for: RadialItem(target: item.target)),
                          text: Binding(get: { binding.label ?? "" }, set: { binding.label = $0.isEmpty ? nil : $0 }))
                SymbolPicker(symbol: Binding(get: { app.settings.symbol(for: binding) }, set: { binding.symbol = $0 }))
            }
            HStack {
                Text(item.target.isMode ? "Mode" : "Action").frame(width: 56, alignment: .leading)
                switch item.target {
                case .mode(let m):
                    ModePicker(selection: Binding(get: { m }, set: { binding.target = .mode($0) })).labelsHidden()
                case .action(let a):
                    ActionEditor(action: Binding(get: { a }, set: { binding.target = .action($0) }), allowEngineActions: false)
                }
            }
        }
    }
}

extension RadialItem.Target {
    var isMode: Bool { if case .mode = self { return true } else { return false } }
}

/// A small static rendering of the radial menu for the settings page.
struct RadialPreview: View {
    var items: [RadialItem]
    @EnvironmentObject private var app: AppController

    var body: some View {
        ZStack {
            Circle().fill(.black.opacity(0.85))
                .overlay(Circle().strokeBorder(.white.opacity(0.1)))
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                previewItem(item, highlighted: index == 0)
                    .offset(offset(for: index))
            }
            Text(items.first.map { app.settings.label(for: $0) } ?? "")
                .font(.caption.weight(.semibold)).foregroundStyle(.white)
                .frame(width: 80)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 190, height: 190)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Radial menu preview with \(items.count) items")
    }

    private func offset(for index: Int) -> CGSize {
        let angle: CGFloat = CGFloat(index) / CGFloat(max(1, items.count)) * 2 * .pi - .pi / 2
        return CGSize(width: CoreGraphics.cos(angle) * 70, height: CoreGraphics.sin(angle) * 70)
    }

    private func previewItem(_ item: RadialItem, highlighted: Bool) -> some View {
        let fill: AnyShapeStyle = highlighted ? AnyShapeStyle(Theme.accent.gradient) : AnyShapeStyle(Color.white.opacity(0.1))
        let tint: Color = highlighted ? .white : .white.opacity(0.75)
        return Image(systemName: app.settings.symbol(for: item))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(fill, in: Circle())
    }
}

// MARK: - Profiles

struct ProfilesPage: View {
    @ObservedObject var navigation: SettingsNavigation
    @EnvironmentObject private var app: AppController
    @State private var confirmDelete: UUID?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
    }

    private var selectedIndex: Int { app.profileIndex(navigation.profileID) }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: Binding(get: { app.settings.profiles[selectedIndex].id }, set: { navigation.profileID = $0 })) {
                ForEach(app.settings.profiles) { p in
                    HStack {
                        Image(systemName: p.id == app.settings.defaultProfile.id ? "globe" : "app.badge")
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading) {
                            Text(p.name)
                            Text(p.id == app.settings.defaultProfile.id ? "Default" : p.apps.map(\.name).joined(separator: ", "))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        if p.id == app.activeProfileID {
                            Spacer()
                            Text("Active").font(.caption2.weight(.semibold)).foregroundStyle(Theme.accent)
                        }
                    }
                    .tag(p.id)
                }
            }
            .overlay(alignment: .bottom) {
                if app.settings.profiles.count == 1 {
                    VStack(spacing: 6) {
                        Image(systemName: "app.badge").font(.title2).foregroundStyle(Theme.accent)
                        Text("Add a profile to give apps like Keynote, Safari or QuickTime their own dial setup.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Text("Click + below.").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .padding(16)
                }
            }
            Divider()
            HStack {
                Menu {
                    Button("Blank Profile") { add(Profile(name: "New Profile", radialItems: Profile.defaultRadialItems)) }
                    Divider()
                    ForEach(DialedSettings.suggestedProfiles(), id: \.name) { p in
                        Button(p.name) { add(p) }
                    }
                } label: { Image(systemName: "plus") }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("Add profile")
                Button { confirmDelete = app.settings.profiles[selectedIndex].id } label: { Image(systemName: "minus") }
                    .buttonStyle(.borderless)
                    .disabled(selectedIndex == 0)
                    .accessibilityLabel("Delete profile")
                Spacer()
            }
            .padding(8)
        }
        .frame(width: 230)
        .confirmationDialog("Delete this profile?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let id = confirmDelete { app.update { $0.profiles.removeAll { $0.id == id } } }
                navigation.profileID = nil
            }
        }
    }

    private func add(_ p: Profile) {
        var copy = p
        copy.id = UUID()
        app.update { $0.profiles.append(copy) }
        navigation.profileID = copy.id
    }

    private var detail: some View {
        let i = selectedIndex
        let isDefault = i == 0
        return Form {
            Section {
                TextField("Name", text: app.binding(\.profiles[i].name))
                if !isDefault {
                    Picker("Start in", selection: Binding(
                        get: { app.settings.profiles[i].startMode?.rawValue ?? "" },
                        set: { v in app.update { $0.profiles[i].startMode = v.isEmpty ? nil : ModeID(rawValue: v) } })) {
                        Text("Keep current mode").tag("")
                        ForEach(app.settings.allModes, id: \.id) { Label($0.name, systemImage: $0.symbol).tag($0.id.rawValue) }
                    }
                }
                LabeledSlider(title: "Scroll & seek speed", value: app.binding(\.profiles[i].sensitivityScale),
                              range: 0.25...4, step: 0.25, format: { String(format: "%.2g×", $0) })
            } footer: {
                if isDefault { FormNote("Used whenever no app profile matches the front app.") }
            }
            if !isDefault {
                Section("Apps") {
                    ForEach(app.settings.profiles[i].apps) { a in
                        HStack {
                            if let icon = AppChooser.icon(for: a.bundleID) {
                                Image(nsImage: icon).resizable().frame(width: 20, height: 20).accessibilityHidden(true)
                            }
                            Text(a.name)
                            Text(a.bundleID).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button { app.update { $0.profiles[i].apps.removeAll { $0.bundleID == a.bundleID } } } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.borderless).foregroundStyle(.red)
                            .accessibilityLabel("Remove \(a.name)")
                        }
                    }
                    HStack {
                        Menu("Add Open App") {
                            ForEach(AppChooser.running) { r in Button(r.name) { addApp(r, to: i) } }
                        }
                        .fixedSize()
                        Button("Choose App…") { if let r = AppChooser.choose() { addApp(r, to: i) } }
                    }
                }
            }
            Section {
                HStack {
                    Button("Edit Presses") { navigation.profileID = app.settings.profiles[i].id; navigation.page = .gestures }
                    Button("Edit Radial Menu") { navigation.profileID = app.settings.profiles[i].id; navigation.page = .radial }
                    Spacer()
                    Button("Use Now") { app.activate(profile: app.settings.profiles[i], announce: true) }
                        .disabled(app.activeProfileID == app.settings.profiles[i].id)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func addApp(_ r: AppRef, to i: Int) {
        app.update { s in
            for j in s.profiles.indices where j != i { s.profiles[j].apps.removeAll { $0.bundleID == r.bundleID } }
            if !s.profiles[i].apps.contains(r) { s.profiles[i].apps.append(r) }
        }
    }
}
