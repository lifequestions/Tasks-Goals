import Foundation
import SwiftData

/// Plain arithmetic over the journal, run on the phone after every entry.
/// This is what catches "whenever I write about Jordan, the entry turns heavy"
/// without needing Claude at all.
struct FoundPattern {
    var signature: String
    var text: String
    var entityKeys: [String]
    var strength: Double
}

enum PatternFinder {
    static func find(in entries: [Entry], now: Date = .now) -> [FoundPattern] {
        let rated = entries.filter { $0.mood != nil }
        guard rated.count >= 6 else { return [] }
        let calendar = Calendar.current
        let baseline = mean(rated.compactMap(\.mood))
        var out: [FoundPattern] = []

        // Which entries each entity appears in.
        var appearances: [String: (entity: Entity, ids: Set<PersistentIdentifier>)] = [:]
        for entry in entries {
            for mention in entry.mentions {
                guard let entity = mention.entity, !entity.hidden else { continue }
                appearances[entity.key, default: (entity, [])].ids.insert(entry.persistentModelID)
            }
        }
        var moodByID: [PersistentIdentifier: Double] = [:]
        for entry in rated { moodByID[entry.persistentModelID] = entry.mood }

        // 1. An entity that shifts the mood of the entries it's in.
        for (key, item) in appearances {
            let with = item.ids.compactMap { moodByID[$0] }
            let without = moodByID.filter { !item.ids.contains($0.key) }.map(\.value)
            guard with.count >= 3, without.count >= 3 else { continue }
            let diff = mean(with) - mean(without)
            guard abs(diff) >= 0.2 else { continue }
            let name = item.entity.name
            let text = diff < 0
                ? "When \(name) comes up, your entries run heavier — mostly \(Feeling.word(mean(with))), against \(Feeling.word(mean(without))) the rest of the time."
                : "Entries with \(name) in them run lighter — mostly \(Feeling.word(mean(with))), against \(Feeling.word(mean(without))) otherwise."
            out.append(FoundPattern(signature: "mood:\(key)", text: text, entityKeys: [key],
                                    strength: abs(diff) * log(Double(with.count) + 1)))
        }

        // 2. Two things that nearly always arrive together.
        let frequent = appearances.filter { $0.value.ids.count >= 3 }.keys.sorted()
        for i in frequent.indices {
            for j in frequent.indices where j > i {
                guard let a = appearances[frequent[i]], let b = appearances[frequent[j]] else { continue }
                let together = a.ids.intersection(b.ids).count
                guard together >= 3 else { continue }
                let overlap = Double(together) / Double(a.ids.union(b.ids).count)
                guard overlap >= 0.5 else { continue }
                let togetherMoods = a.ids.intersection(b.ids).compactMap { moodByID[$0] }
                let feeling = togetherMoods.isEmpty ? "" : ", and those entries are mostly \(Feeling.word(mean(togetherMoods)))"
                out.append(FoundPattern(signature: "pair:\(frequent[i])|\(frequent[j])",
                                        text: "\(a.entity.name) and \(b.entity.name) tend to turn up together — \(together) entries mention both\(feeling).",
                                        entityKeys: [frequent[i], frequent[j]],
                                        strength: overlap * log(Double(together) + 1) * 0.8))
            }
        }

        // 3. A day of the week that runs heavier or lighter.
        var byWeekday: [Int: [Double]] = [:]
        for entry in rated {
            byWeekday[calendar.component(.weekday, from: entry.createdAt), default: []].append(entry.mood ?? 0)
        }
        let dayMeans = byWeekday.filter { $0.value.count >= 3 }.mapValues(mean)
        if let low = dayMeans.min(by: { $0.value < $1.value }), low.value - baseline <= -0.2 {
            let day = calendar.weekdaySymbols[low.key - 1]
            out.append(FoundPattern(signature: "weekday:low:\(low.key)",
                                    text: "Your \(day) entries tend to be heavier than the rest of the week.",
                                    entityKeys: [], strength: abs(low.value - baseline)))
        }
        if let high = dayMeans.max(by: { $0.value < $1.value }), high.value - baseline >= 0.2 {
            let day = calendar.weekdaySymbols[high.key - 1]
            out.append(FoundPattern(signature: "weekday:high:\(high.key)",
                                    text: "\(day)s are usually your lightest day on the page.",
                                    entityKeys: [], strength: abs(high.value - baseline)))
        }

        // 4. Something that used to come up often and has gone quiet.
        for (key, item) in appearances where item.ids.count >= 4 {
            guard let last = item.entity.lastMentioned,
                  let days = calendar.dateComponents([.day], from: last, to: now).day, days >= 21 else { continue }
            let who = item.entity.kind == .person ? "They" : "It"
            out.append(FoundPattern(signature: "quiet:\(key)",
                                    text: "You haven't written about \(item.entity.name) for \(days / 7) weeks. \(who) used to come up often.",
                                    entityKeys: [key], strength: 0.3))
        }

        return out.sorted { $0.strength > $1.strength }
    }

    static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}

/// The numbers behind a period, for the Insights screen and for Claude.
struct PeriodStats {
    struct Presence {
        let entity: Entity
        let count: Int
        let feeling: Double
    }

    let entryCount: Int
    let wordCount: Int
    let averageMood: Double?
    let top: [Presence]

    init(entries: [Entry]) {
        entryCount = entries.count
        wordCount = entries.reduce(0) { $0 + $1.wordCount }
        let moods = entries.compactMap(\.mood)
        averageMood = moods.isEmpty ? nil : PatternFinder.mean(moods)

        var tally: [String: (Entity, Int, Double)] = [:]
        for entry in entries {
            for mention in entry.mentions {
                guard let entity = mention.entity, !entity.hidden else { continue }
                var slot = tally[entity.key] ?? (entity, 0, 0)
                slot.1 += 1
                slot.2 += mention.sentiment
                tally[entity.key] = slot
            }
        }
        top = tally.values
            .map { Presence(entity: $0.0, count: $0.1, feeling: $0.2 / Double($0.1)) }
            .sorted { $0.count > $1.count }
    }

    func describe() -> String {
        var lines = ["Entries: \(entryCount), words: \(wordCount), overall feeling: \(Feeling.word(averageMood))"]
        for p in top.prefix(25) {
            lines.append("- \(p.entity.name) (\(p.entity.kindRaw)): \(p.count) mentions, mostly \(Feeling.word(p.feeling))")
        }
        return lines.joined(separator: "\n")
    }
}
