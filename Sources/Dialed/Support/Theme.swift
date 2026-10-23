import SwiftUI

/// Shared visual language: one accent, soft materials, rounded geometry.
enum Theme {
    /// CMF-inspired warm orange. Works on light and dark materials.
    static let accent = Color(red: 1.0, green: 0.42, blue: 0.17)
    static let accentSoft = accent.opacity(0.16)
    static let cornerRadius: CGFloat = 14
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.78)
    static let quick = Animation.easeOut(duration: 0.18)
}

/// A rounded "card" used across settings, onboarding and diagnostics.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
    }
}

/// Small coloured status dot + label.
struct StatusRow: View {
    enum Level { case ok, warning, error, neutral }

    var level: Level
    var title: String
    var detail: String?

    var color: Color {
        switch level {
        case .ok: return .green
        case .warning: return .orange
        case .error: return .red
        case .neutral: return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.medium))
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Icon tile in the accent colour.
struct IconTile: View {
    var symbol: String
    var size: CGFloat = 28
    var tint: Color = Theme.accent

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Explanatory text under a settings section (small, secondary, leading-aligned).
struct FormNote: View {
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
