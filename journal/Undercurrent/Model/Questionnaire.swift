import Foundation

/// Personality questionnaires. Results feed into everything Claude reads, so
/// the more you answer, the better it knows how to read you.
///
/// Only freely usable, research-backed instruments belong here. Myers-Briggs,
/// the VIA survey and CliftonStrengths are proprietary; the open alternatives
/// are listed in the plan.
struct Questionnaire: Identifiable {
    struct Item {
        let text: String
        let trait: String
        let reversed: Bool
    }

    struct Trait {
        let id: String
        let name: String
        let low: String
        let high: String
    }

    let id: String
    let title: String
    let blurb: String
    let minutes: Int
    let stem: String
    let scale: [String]
    let items: [Item]
    let traits: [Trait]
    let source: String

    var isAvailable: Bool { !items.isEmpty }

    /// Answers are 1…scale.count; each trait comes out 0…1.
    func score(_ answers: [Int]) -> [String: Double] {
        let top = Double(scale.count)
        var sums: [String: (Double, Int)] = [:]
        for (item, answer) in zip(items, answers) {
            let value = item.reversed ? top + 1 - Double(answer) : Double(answer)
            let slot = sums[item.trait] ?? (0, 0)
            sums[item.trait] = (slot.0 + value, slot.1 + 1)
        }
        return sums.mapValues { ($0.0 / Double($0.1) - 1) / (top - 1) }
    }

    func describe(_ scores: [String: Double]) -> String {
        let lines = traits.compactMap { trait -> String? in
            guard let v = scores[trait.id] else { return nil }
            let lean = v > 0.62 ? "leans \(trait.high)" : v < 0.38 ? "leans \(trait.low)" : "middle of the range"
            return "- \(trait.name): \(Int(v * 100))/100 (\(lean))"
        }
        return "\(title) results:\n" + lines.joined(separator: "\n")
    }

    static let catalog: [Questionnaire] = [bigFive, chronotype, attachment, values]

    // Ten Item Personality Inventory — Gosling, Rentfrow & Swann (2003). Free for non-commercial use.
    static let bigFive = Questionnaire(
        id: "tipi",
        title: "Big Five",
        blurb: "The five broad traits psychologists measure most: openness, conscientiousness, extraversion, agreeableness and emotional stability.",
        minutes: 2,
        stem: "I see myself as…",
        scale: ["Disagree strongly", "Disagree moderately", "Disagree a little", "Neither agree nor disagree",
                "Agree a little", "Agree moderately", "Agree strongly"],
        items: [
            Item(text: "Extraverted, enthusiastic.", trait: "E", reversed: false),
            Item(text: "Critical, quarrelsome.", trait: "A", reversed: true),
            Item(text: "Dependable, self-disciplined.", trait: "C", reversed: false),
            Item(text: "Anxious, easily upset.", trait: "S", reversed: true),
            Item(text: "Open to new experiences, complex.", trait: "O", reversed: false),
            Item(text: "Reserved, quiet.", trait: "E", reversed: true),
            Item(text: "Sympathetic, warm.", trait: "A", reversed: false),
            Item(text: "Disorganised, careless.", trait: "C", reversed: true),
            Item(text: "Calm, emotionally stable.", trait: "S", reversed: false),
            Item(text: "Conventional, uncreative.", trait: "O", reversed: true),
        ],
        traits: [
            Trait(id: "O", name: "Openness", low: "practical and familiar", high: "curious and inventive"),
            Trait(id: "C", name: "Conscientiousness", low: "flexible and spontaneous", high: "organised and dependable"),
            Trait(id: "E", name: "Extraversion", low: "reserved and solitary", high: "outgoing and energetic"),
            Trait(id: "A", name: "Agreeableness", low: "challenging and direct", high: "warm and cooperative"),
            Trait(id: "S", name: "Emotional stability", low: "sensitive and reactive", high: "calm and steady"),
        ],
        source: "Ten Item Personality Inventory (Gosling, Rentfrow & Swann, 2003)")

    // Reduced Morningness–Eveningness Questionnaire — Adan & Almirall (1991), simplified to one 5-point scale.
    static let chronotype = Questionnaire(
        id: "chronotype",
        title: "Chronotype",
        blurb: "Whether you're built for mornings or evenings — useful when the journal shows your heavy hours.",
        minutes: 1,
        stem: "How true is this of you?",
        scale: ["Not at all", "A little", "Somewhat", "Mostly", "Completely"],
        items: [
            Item(text: "If I could choose freely, I'd get up before 7am.", trait: "M", reversed: false),
            Item(text: "In the first half hour after waking, I feel alert.", trait: "M", reversed: false),
            Item(text: "I'm at my best in the morning.", trait: "M", reversed: false),
            Item(text: "I'd happily stay up past midnight most nights.", trait: "M", reversed: true),
            Item(text: "I'd call myself an evening person.", trait: "M", reversed: true),
        ],
        traits: [Trait(id: "M", name: "Morningness", low: "evening type", high: "morning type")],
        source: "Adapted from the reduced MEQ (Adan & Almirall, 1991)")

    static let attachment = Questionnaire(
        id: "attachment", title: "Attachment style",
        blurb: "How you tend to relate in close relationships — anxiety and avoidance. Planned: ECR-R short form.",
        minutes: 4, stem: "", scale: [], items: [], traits: [],
        source: "Experiences in Close Relationships – Revised (Fraley, Waller & Brennan, 2000)")

    static let values = Questionnaire(
        id: "values", title: "Personal values",
        blurb: "What matters most to you — security, achievement, kindness, freedom… Planned: Schwartz PVQ-21.",
        minutes: 5, stem: "", scale: [], items: [], traits: [],
        source: "Portrait Values Questionnaire (Schwartz, 2001)")
}
