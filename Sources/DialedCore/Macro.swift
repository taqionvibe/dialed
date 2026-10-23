import Foundation

/// A named sequence of actions with optional pauses, run by a press or a radial item.
public struct Macro: Codable, Hashable, Identifiable, Sendable {
    public enum Step: Codable, Hashable, Sendable {
        case action(Action)
        case wait(milliseconds: Int)
    }

    public var id: UUID
    public var name: String
    public var symbol: String
    public var steps: [Step]

    public init(id: UUID = UUID(), name: String, symbol: String = "wand.and.stars", steps: [Step]) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.steps = steps
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Macro"
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "wand.and.stars"
        steps = try c.decodeIfPresent([Step].self, forKey: .steps) ?? []
    }

    /// Total of all waits, for display.
    public var totalWait: Int {
        steps.reduce(0) { sum, step in
            if case .wait(let ms) = step { return sum + ms }
            return sum
        }
    }

    /// Flattens nested macros (up to a depth limit, so a macro that runs itself
    /// cannot loop forever). Returns the actions/waits in order.
    public func expanded(lookup: (UUID) -> Macro?, depth: Int = 0) -> [Step] {
        guard depth < 4 else { return [] }
        var out: [Step] = []
        for step in steps {
            if case .action(.runMacro(let id)) = step, let inner = lookup(id) {
                out += inner.expanded(lookup: lookup, depth: depth + 1)
            } else if case .action(.runMacro) = step {
                continue
            } else {
                out.append(step)
            }
        }
        return out
    }
}
