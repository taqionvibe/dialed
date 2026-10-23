import AppKit
import SwiftUI
import DialedCore

struct RadialSlot: Identifiable, Equatable {
    let id: UUID
    let title: String
    let symbol: String
    let subtitle: String
    let isCurrentMode: Bool
}

final class RadialModel: ObservableObject {
    @Published var slots: [RadialSlot] = []
    @Published var highlighted = 0
    /// Continuous position for the selection arc (avoids spinning the long way round).
    @Published var arcPosition: Double = 0
    @Published var visible = false
    @Published var chosen: UUID?
    var onTapItem: ((Int) -> Void)?
    var onDismiss: (() -> Void)?
}

/// The radial menu: a triple press opens it (by default), turning moves the highlight, a single
/// press chooses. It never takes keyboard focus away from the user's app.
@MainActor
final class RadialMenuController {
    static let size = CGSize(width: 480, height: 480)
    private let model = RadialModel()
    private lazy var panel = OverlayPanel(size: Self.size) { RadialMenuView(model: model) }
    private var hideWork: DispatchWorkItem?
    private var monitors: [Any] = []

    var isVisible: Bool { model.visible }

    /// Called when the user clicks an item (index) or clicks away / presses Esc (nil).
    var onMouseChoice: ((Int?) -> Void)? {
        didSet {
            model.onTapItem = { [weak self] i in self?.onMouseChoice?(i) }
            model.onDismiss = { [weak self] in self?.onMouseChoice?(nil) }
        }
    }

    private func installDismissMonitors() {
        removeMonitors()
        panel.ignoresMouseEvents = false
        // Clicks anywhere else on screen close the menu (they still reach that app).
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.onMouseChoice?(nil) }
        }) { monitors.append(m) }
        // Esc closes it too.
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
            guard e.keyCode == 53 else { return }
            MainActor.assumeIsolated { self?.onMouseChoice?(nil) }
        }) { monitors.append(m) }
    }

    private func removeMonitors() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        panel.ignoresMouseEvents = true
    }

    func show(state: DialEngine.MenuState, settings: DialedSettings) {
        hideWork?.cancel()
        let current = AppController.shared.currentMode
        model.slots = state.items.map { item in
            var subtitle = ""
            var isCurrent = false
            switch item.target {
            case .mode(let m):
                subtitle = settings.modeInfo(m).turnHint
                isCurrent = m == current
            case .action:
                subtitle = "Press to run"
            }
            return RadialSlot(id: item.id, title: settings.label(for: item), symbol: settings.symbol(for: item),
                              subtitle: subtitle, isCurrentMode: isCurrent)
        }
        model.highlighted = state.highlighted
        model.arcPosition = Double(state.highlighted)
        model.chosen = nil
        let screen = OverlayPanel.activeScreen.visibleFrame
        panel.present(centeredAt: NSPoint(x: screen.midX, y: screen.midY))
        installDismissMonitors()
        withAnimation(Theme.spring) { model.visible = true }
    }

    func update(state: DialEngine.MenuState) {
        let n = max(1, model.slots.count)
        // Move the arc the short way round so wrapping animates naturally.
        var delta = Double(state.highlighted - model.highlighted)
        if delta > Double(n) / 2 { delta -= Double(n) }
        if delta < -Double(n) / 2 { delta += Double(n) }
        withAnimation(Theme.spring) {
            model.highlighted = state.highlighted
            model.arcPosition += delta
        }
    }

    func hide(selected: RadialItem? = nil) {
        removeMonitors()
        guard model.visible else { return }
        if let selected { withAnimation(Theme.quick) { model.chosen = selected.id } }
        let delay = selected == nil ? 0 : 0.14
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(Theme.spring) { self.model.visible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !self.model.visible { self.panel.orderOut(nil) }
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}

struct RadialMenuView: View {
    @ObservedObject var model: RadialModel

    private let ringRadius: CGFloat = 138
    private let itemSize: CGFloat = 54
    private var innerRadius: CGFloat { ringRadius - itemSize / 2 - 16 }

    var body: some View {
        ZStack {
            // Clicking the empty area around the dial closes it.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { model.onDismiss?() }
            if model.visible {
                menu
                    .transition(.scale(scale: 0.86).combined(with: .opacity))
            }
        }
        .frame(width: RadialMenuController.size.width, height: RadialMenuController.size.height)
        .environment(\.colorScheme, .dark)
    }

    private var menu: some View {
        let n = max(1, model.slots.count)
        let segment = 1.0 / Double(n)
        return ZStack {
            Circle()
                .fill(.regularMaterial)
                .overlay(Circle().fill(Color.black.opacity(0.42)))
                .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 0.75))
                .shadow(color: .black.opacity(0.32), radius: 22, y: 8)
                .frame(width: 360, height: 360)
                .contentShape(Circle())
                .onTapGesture {} // clicks on the dial body don't close it

            // Inner track + indicator arc: reads like the needle of a dial and glides
            // to the highlighted item.
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 4)
                .frame(width: innerRadius * 2, height: innerRadius * 2)
            Circle()
                .trim(from: 0, to: segment * 0.7)
                .stroke(Theme.accent.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: innerRadius * 2, height: innerRadius * 2)
                .rotationEffect(.degrees(-90 + 360 * (model.arcPosition - 0.35) * segment))
                .shadow(color: Theme.accent.opacity(0.6), radius: 6)
                .opacity(model.slots.isEmpty ? 0 : 1)

            ForEach(Array(model.slots.enumerated()), id: \.element.id) { index, slot in
                item(slot, highlighted: index == model.highlighted)
                    .contentShape(Circle())
                    .onTapGesture { model.onTapItem?(index) }
                    .help(slot.title)
                    .offset(offset(for: index, of: n))
            }

            center
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dialed radial menu")
        .accessibilityValue(model.slots.indices.contains(model.highlighted) ? model.slots[model.highlighted].title : "")
    }

    private func offset(for index: Int, of n: Int) -> CGSize {
        let angle: CGFloat = CGFloat(index) / CGFloat(n) * 2 * .pi - .pi / 2
        return CGSize(width: CoreGraphics.cos(angle) * ringRadius, height: CoreGraphics.sin(angle) * ringRadius)
    }

    private func item(_ slot: RadialSlot, highlighted: Bool) -> some View {
        let chosen = model.chosen == slot.id
        return ZStack {
            Circle()
                .fill(highlighted ? AnyShapeStyle(Theme.accent.gradient) : AnyShapeStyle(.white.opacity(0.09)))
            Image(systemName: slot.symbol)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(highlighted ? .white : .white.opacity(0.78))
            if slot.isCurrentMode && !highlighted {
                Circle().strokeBorder(Theme.accent.opacity(0.8), lineWidth: 1.5)
            }
        }
        .frame(width: itemSize, height: itemSize)
        .scaleEffect(chosen ? 1.25 : highlighted ? 1.14 : 1)
        .shadow(color: highlighted ? Theme.accent.opacity(0.55) : .clear, radius: 12)
        .animation(Theme.spring, value: highlighted)
    }

    private var center: some View {
        let slot = model.slots.indices.contains(model.highlighted) ? model.slots[model.highlighted] : nil
        return VStack(spacing: 6) {
            Text(slot?.title ?? "")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(slot?.subtitle ?? "")
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Divider().overlay(.white.opacity(0.2)).frame(width: 60).padding(.vertical, 2)
            Text("Press to choose\nClick outside or Esc to close")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(width: 170)
        .id(slot?.id)
        .transition(.opacity)
        .animation(Theme.quick, value: model.highlighted)
    }
}
