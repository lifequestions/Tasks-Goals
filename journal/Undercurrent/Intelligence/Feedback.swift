import Foundation

/// What you've marked helpful or not helpful, turned into something the app can use:
/// weights for the kinds of pattern found on the phone, and examples for Claude.
struct Feedback {
    let helpful: [Insight]
    let unhelpful: [Insight]

    init(_ insights: [Insight]) {
        let rated = insights.filter { $0.feedback != nil }.sorted { $0.createdAt > $1.createdAt }
        helpful = rated.filter { ($0.feedback ?? 0) > 0 }
        unhelpful = rated.filter { ($0.feedback ?? 0) < 0 }
    }

    /// The kind of insight, for learning which kinds land: a pattern's type
    /// ("mood", "pair", "weekday", "quiet", "nextday"), or who found it.
    static func kind(of insight: Insight) -> String {
        if let signature = insight.signature, let type = signature.split(separator: ":").first {
            return String(type)
        }
        return insight.sourceRaw
    }

    /// Above 1 for kinds you've found helpful, below 1 for ones you haven't.
    func weight(forKind kind: String) -> Double {
        let up = Double(helpful.filter { Self.kind(of: $0) == kind }.count)
        let down = Double(unhelpful.filter { Self.kind(of: $0) == kind }.count)
        return min(2, max(0.25, (1 + up) / (1 + down)))
    }

    /// And the same for the people and things involved.
    func weight(forEntities keys: [String]) -> Double {
        guard !keys.isEmpty else { return 1 }
        let up = Double(helpful.filter { !Set($0.entityKeys).isDisjoint(with: keys) }.count)
        let down = Double(unhelpful.filter { !Set($0.entityKeys).isDisjoint(with: keys) }.count)
        return min(1.5, max(0.5, (2 + up) / (2 + down)))
    }

    var isEmpty: Bool { helpful.isEmpty && unhelpful.isEmpty }

    /// For Claude: recent examples of each, so it leans toward what helps.
    var prompt: String {
        guard !isEmpty else { return "" }
        var lines = ["<their_feedback>"]
        if !helpful.isEmpty {
            lines.append("They marked these insights helpful. Offer more of this kind — this depth, this tone, these subjects:")
            lines += helpful.prefix(10).map { "- \($0.text)" }
        }
        if !unhelpful.isEmpty {
            lines.append("They marked these not helpful. Avoid this kind of observation, and don't repeat them:")
            lines += unhelpful.prefix(10).map { "- \($0.text)" }
        }
        lines.append("</their_feedback>")
        return lines.joined(separator: "\n")
    }
}
