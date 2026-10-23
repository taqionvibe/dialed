import Foundation
import SwiftUI
import DialedCore

/// One line in the live diagnostics log.
struct DiagnosticEvent: Identifiable, Hashable {
    enum Category: String {
        case turn, press, volume, mode, action, system, warning

        var color: Color {
            switch self {
            case .turn: return .orange
            case .press: return .blue
            case .volume: return .secondary
            case .mode: return .purple
            case .action: return .green
            case .system: return .teal
            case .warning: return .red
            }
        }

        var label: String { rawValue.uppercased() }
    }

    let id = UUID()
    let date: Date
    let uptime: TimeInterval
    let category: Category
    let text: String
}

/// Physical gestures we can observe, for the test lights.
enum ObservedGesture: String, CaseIterable, Identifiable {
    case turnBack, turnForward, single, double, triple, hold
    var id: String { rawValue }

    var title: String {
        switch self {
        case .turnBack: return "Turn back"
        case .turnForward: return "Turn forward"
        case .single: return "Single"
        case .double: return "Double"
        case .triple: return "Triple"
        case .hold: return "Hold"
        }
    }

    var symbol: String {
        switch self {
        case .turnBack: return "arrow.counterclockwise"
        case .turnForward: return "arrow.clockwise"
        case .single: return "circle.fill"
        case .double: return "circle.grid.2x1.fill"
        case .triple: return "ellipsis"
        case .hold: return "hand.point.up.left.fill"
        }
    }

    /// Hold never reaches macOS (verified: bluetoothd receives nothing).
    var isSupported: Bool { self != .hold }

    static func from(_ press: PressKind) -> ObservedGesture {
        switch press {
        case .single: return .single
        case .double: return .double
        case .triple: return .triple
        }
    }
}

/// Live diagnostics state shared by the Diagnostics window and onboarding.
final class DiagnosticsModel: ObservableObject {
    @Published private(set) var events: [DiagnosticEvent] = []
    @Published private(set) var counts: [ObservedGesture: Int] = [:]
    @Published private(set) var lastSeen: [ObservedGesture: Date] = [:]
    @Published private(set) var lastReportInterval: TimeInterval?
    /// When true, inputs are logged but not acted on.
    @Published var pauseActions = false

    private var lastTurnUptime: TimeInterval?
    private let limit = 400

    func log(_ category: DiagnosticEvent.Category, _ text: String, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        events.append(DiagnosticEvent(date: Date(), uptime: uptime, category: category, text: text))
        if events.count > limit { events.removeFirst(events.count - limit) }
    }

    func observe(_ gesture: ObservedGesture, uptime: TimeInterval) {
        counts[gesture, default: 0] += 1
        lastSeen[gesture] = Date()
        if gesture == .turnBack || gesture == .turnForward {
            if let last = lastTurnUptime { lastReportInterval = uptime - last }
            lastTurnUptime = uptime
        }
    }

    func clear() {
        events.removeAll()
        counts.removeAll()
        lastSeen.removeAll()
        lastReportInterval = nil
        lastTurnUptime = nil
    }

    var exportText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        var lines = ["Dialed diagnostics — \(Date())",
                     "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
                     "App \(Bundle.main.shortVersion)", ""]
        lines += events.map { "\(f.string(from: $0.date))  \($0.category.label.padding(toLength: 7, withPad: " ", startingAt: 0))  \($0.text)" }
        return lines.joined(separator: "\n")
    }
}

extension Bundle {
    var shortVersion: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }
}
