import AppKit
import SwiftUI
import DialedCore

/// What the on-screen feedback capsule shows.
struct HUDContent: Equatable {
    var symbol: String
    var title: String
    var subtitle: String?
    /// 0…1 shows a level bar (volume, brightness).
    var level: Double?
    var tint: Color = Theme.accent

    init(symbol: String, title: String, subtitle: String?, level: Double? = nil, tint: Color = Theme.accent) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.level = level
        self.tint = tint
    }
}

final class HUDModel: ObservableObject {
    @Published var content = HUDContent(symbol: "dial.medium", title: "", subtitle: nil)
    @Published var visible = false
    @Published var pulse = 0
}

/// Shows short, non-intrusive feedback near the bottom (or top/centre) of the screen.
@MainActor
final class HUDController {
    private let model = HUDModel()
    private lazy var panel = OverlayPanel(size: CGSize(width: 420, height: 110)) { HUDView(model: model) }
    private var hideWork: DispatchWorkItem?

    func show(_ content: HUDContent, settings: DialedSettings, force: Bool = false, duration: TimeInterval? = nil) {
        guard settings.general.showHUD || force else { return }
        let changedKind = model.content.title != content.title || !model.visible
        if changedKind {
            withAnimation(Theme.quick) { model.content = content }
        } else {
            model.content = content
            model.pulse += 1
        }
        position(settings.general.hudPosition)
        if !model.visible { withAnimation(Theme.spring) { model.visible = true } }
        scheduleHide(after: duration ?? (content.tint == .red ? 4.5 : (content.subtitle?.count ?? 0) > 40 ? 3 : 1.6))
    }

    /// Repeated outputs in the same mode (keys) — a small bump instead of a new card.
    func pulse(symbol: String, title: String, detail: String, settings: DialedSettings) {
        show(HUDContent(symbol: symbol, title: title, subtitle: detail), settings: settings)
    }

    private func position(_ where_: HUDPosition) {
        let screen = OverlayPanel.activeScreen.visibleFrame
        let y: CGFloat
        switch where_ {
        case .bottom: y = screen.minY + 110
        case .top: y = screen.maxY - 90
        case .center: y = screen.midY - 160
        }
        panel.present(centeredAt: NSPoint(x: screen.midX, y: y))
    }

    private func scheduleHide(after seconds: TimeInterval) {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(Theme.spring) { self.model.visible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if !self.model.visible { self.panel.orderOut(nil) }
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}

struct HUDView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        ZStack {
            if model.visible {
                capsule
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity),
                                            removal: .scale(scale: 0.96).combined(with: .opacity)))
            }
        }
        .frame(width: 420, height: 110)
    }

    private var capsule: some View {
        let c = model.content
        return HStack(spacing: 12) {
            Image(systemName: c.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(c.tint.gradient, in: Circle())
                .scaleEffect(model.pulse % 2 == 0 ? 1 : 1.08)
                .animation(.spring(response: 0.2, dampingFraction: 0.5), value: model.pulse)
            VStack(alignment: .leading, spacing: 3) {
                Text(c.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                if let level = c.level {
                    LevelBar(value: level, tint: c.tint)
                        .frame(width: 170, height: 6)
                        .padding(.vertical, 2)
                }
                if let s = c.subtitle {
                    Text(s)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .contentTransition(.numericText())
                }
            }
            .frame(minWidth: 150, maxWidth: 300, alignment: .leading)
        }
        .padding(.leading, 12)
        .padding(.trailing, 20)
        .padding(.vertical, 10)
        .fixedSize()
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 5)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([c.title, c.subtitle].compactMap { $0 }.joined(separator: ", "))
    }
}

struct LevelBar: View {
    var value: Double
    var tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule().fill(tint)
                    .frame(width: max(6, geo.size.width * min(1, max(0, value))))
                    .animation(Theme.spring, value: value)
            }
        }
    }
}
