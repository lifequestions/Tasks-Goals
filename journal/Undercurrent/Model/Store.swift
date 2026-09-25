import Foundation
import SwiftData

/// What a reader (on-device or Claude) makes of one entry.
struct EntryAnalysis: Codable {
    struct Found: Codable {
        var name: String
        var kind: String
        var sentiment: Double
        var quote: String
    }

    /// One insight in an entry: something they realised themselves ("theirs"),
    /// or a link to the rest of the journal the reader saw ("connection").
    struct Extracted: Codable {
        var text: String
        var kind: String = "theirs"
    }

    var mood: Double
    var summary: String
    var entities: [Found]
    var insights: [Extracted] = []
    var followUp: String = ""

    init(mood: Double, summary: String, entities: [Found], insights: [Extracted] = [], followUp: String = "") {
        self.mood = mood
        self.summary = summary
        self.entities = entities
        self.insights = insights
        self.followUp = followUp
    }

    private enum CodingKeys: String, CodingKey { case mood, summary, entities, insights, noticed, followUp }

    /// Lenient, since not every model on OpenRouter returns every field.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mood = (try? c.decode(Double.self, forKey: .mood)) ?? 0
        summary = (try? c.decode(String.self, forKey: .summary)) ?? ""
        entities = (try? c.decode([Found].self, forKey: .entities)) ?? []
        insights = (try? c.decode([Extracted].self, forKey: .insights))
            ?? (try? c.decode([String].self, forKey: .insights))?.map { Extracted(text: $0) }
            ?? []
        // Older replies had a single "noticed" line.
        if let noticed = try? c.decode(String.self, forKey: .noticed), !noticed.isEmpty {
            insights.append(Extracted(text: noticed, kind: "connection"))
        }
        followUp = (try? c.decode(String.self, forKey: .followUp)) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(mood, forKey: .mood)
        try c.encode(summary, forKey: .summary)
        try c.encode(entities, forKey: .entities)
        try c.encode(insights, forKey: .insights)
        try c.encode(followUp, forKey: .followUp)
    }
}

/// Writes to the journal. Views read with @Query; changes go through here.
enum Store {
    static func apply(_ analysis: EntryAnalysis, to entry: Entry, by reader: String, in context: ModelContext) {
        let old = entry.mentions
        entry.mentions = []
        for mention in old { context.delete(mention) }

        entry.mood = clamp(analysis.mood)
        entry.summary = analysis.summary.isEmpty ? nil : analysis.summary
        entry.analysedBy = reader
        entry.analysedAt = .now
        if reader == "claude" {
            let next = analysis.followUp.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.followUp = Questions.isUsable(next) ? next : nil
        }

        var seen = Set<String>()
        for found in analysis.entities {
            let name = found.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.count > 1 else { continue }
            let kind = EntityKind(rawValue: found.kind.lowercased()) ?? .theme
            let target = Self.entity(named: name, kind: kind, in: context)
            guard !(entry.excludedKeys ?? []).contains(target.key),
                  seen.insert(target.key).inserted else { continue }

            let mention = Mention(sentiment: clamp(found.sentiment), quote: String(found.quote.prefix(280)))
            context.insert(mention)
            mention.entry = entry
            mention.entity = target
        }

        for tag in entry.chosenTags {
            let target = Self.entity(named: tag.name, kind: tag.kind, in: context)
            guard seen.insert(target.key).inserted else { continue }
            attach(target, to: entry, in: context)
        }

        replaceInsights(on: entry, with: analysis.insights, in: context)
    }

    /// A reading's insights take the place of the last reading's, except the ones
    /// you pinned or rated. Ones you dismissed stay dismissed if the new reading finds them again.
    static func replaceInsights(on entry: Entry, with found: [EntryAnalysis.Extracted], in context: ModelContext) {
        let old = entry.insights
        let dismissed = Set(old.filter(\.dismissed).map { $0.text.lowercased() })
        let keep: (Insight) -> Bool = { $0.pinned || $0.feedback != nil }
        var kept = Set(old.filter(keep).map { $0.text.lowercased() })
        for insight in old where !keep(insight) {
            insight.entry = nil
            context.delete(insight)
        }
        let keys = entry.mentions.compactMap { $0.entity?.key }
        for item in found.prefix(5) {
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count > 8, kept.insert(text.lowercased()).inserted else { continue }
            let insight = Insight(text: text, source: item.kind == "connection" ? .claude : .mine, entityKeys: keys)
            insight.createdAt = entry.createdAt
            insight.dismissed = dismissed.contains(text.lowercased())
            context.insert(insight)
            insight.entry = entry
        }
    }

    /// Links an entity to an entry, quoting the sentence that names it if there is one.
    private static func attach(_ entity: Entity, to entry: Entry, in context: ModelContext) {
        let sentence = LocalReader.sentences(in: entry.text)
            .first { $0.localizedCaseInsensitiveContains(entity.name) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let mention = Mention(sentiment: entry.mood ?? 0, quote: String((sentence ?? entry.title).prefix(280)))
        context.insert(mention)
        mention.entry = entry
        mention.entity = entity
    }

    /// You tagged this entry by hand: it stays tagged through every re-read.
    static func addTag(_ tag: Tag, to entry: Entry, in context: ModelContext) {
        guard !tag.name.isEmpty else { return }
        let target = entity(named: tag.name, kind: tag.kind, in: context)
        entry.excludedKeys = (entry.excludedKeys ?? []).filter { $0 != target.key }
        if !entry.chosenTags.contains(where: { $0.key == target.key }) {
            entry.chosenTags.append(Tag(target))
        }
        if !entry.mentions.contains(where: { $0.entity?.key == target.key }) {
            attach(target, to: entry, in: context)
        }
        try? context.save()
    }

    /// Finds an entity by name or alias, or makes a new one.
    static func entity(named name: String, kind: EntityKind, in context: ModelContext) -> Entity {
        let key = Entity.makeKey(name: name, kind: kind)
        var byKey = FetchDescriptor<Entity>(predicate: #Predicate { $0.key == key })
        byKey.fetchLimit = 1
        if let found = try? context.fetch(byKey).first { return found }

        let kindRaw = kind.rawValue
        let sameKind = (try? context.fetch(FetchDescriptor<Entity>(predicate: #Predicate { $0.kindRaw == kindRaw }))) ?? []
        if let alias = sameKind.first(where: { $0.aliasKeys.contains(key) }) { return alias }

        let entity = Entity(name: name, kind: kind)
        context.insert(entity)
        return entity
    }

    /// "This entry isn't about that": removes the link and stops it coming back on a re-read.
    static func detach(_ mention: Mention, in context: ModelContext) {
        guard let entry = mention.entry, let entity = mention.entity else { return }
        entry.excludedKeys = (entry.excludedKeys ?? []) + [entity.key]
        entry.chosenTags.removeAll { $0.key == entity.key }
        mention.entry = nil
        mention.entity = nil
        context.delete(mention)
        try? context.save()
    }

    /// Moves every mention of `source` onto `target` and remembers the old name.
    static func merge(_ source: Entity, into target: Entity, in context: ModelContext) {
        guard source.persistentModelID != target.persistentModelID else { return }
        let moved = source.mentions
        source.mentions = []
        for mention in moved { mention.entity = target }
        target.aliasKeys.append(contentsOf: [source.key] + source.aliasKeys)
        context.delete(source)
        try? context.save()
    }

    static func rename(_ entity: Entity, to newName: String, in context: ModelContext) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entity.name = trimmed
        let newKey = Entity.makeKey(name: trimmed, kind: entity.kind)
        if newKey != entity.key, !entity.aliasKeys.contains(newKey) {
            entity.aliasKeys.append(newKey)
        }
        try? context.save()
    }

    /// Entities nobody mentions any more (a re-read dropped them).
    static func pruneOrphans(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<Entity>())) ?? []
        for entity in all where entity.mentions.isEmpty {
            context.delete(entity)
        }
    }

    /// Deletes entries and everything that was worked out from them: their mentions,
    /// what Claude noticed in them, readings of people who are no longer in the journal,
    /// and reflections of the periods they were in (those get written again).
    static func delete(_ entries: [Entry], in context: ModelContext) {
        guard !entries.isEmpty else { return }
        let dates = entries.map(\.createdAt)
        for entry in entries { context.delete(entry) }
        try? context.save()

        let reflections = (try? context.fetch(FetchDescriptor<Reflection>())) ?? []
        for reflection in reflections where dates.contains(where: { $0 >= reflection.start && $0 < reflection.end }) {
            context.delete(reflection)
        }
        pruneOrphans(in: context)
        try? context.save()
        pruneStaleInsights(in: context)
        try? context.save()
    }

    /// Claude's insights about people, places and themes that have left the journal.
    static func pruneStaleInsights(in context: ModelContext) {
        let entities = (try? context.fetch(FetchDescriptor<Entity>())) ?? []
        let known = Set(entities.flatMap { [$0.key] + $0.aliasKeys })
        let claude = InsightSource.claude.rawValue
        let insights = (try? context.fetch(FetchDescriptor<Insight>(predicate: #Predicate { $0.sourceRaw == claude }))) ?? []
        for insight in insights where !insight.pinned && !insight.entityKeys.isEmpty
            && !insight.entityKeys.contains(where: known.contains) {
            context.delete(insight)
        }
    }

    /// Once, for journals from before insights were tied to their entry: links each of
    /// Claude's notes to the entry it came from, drops the ones whose entry is gone,
    /// and drops reflections that counted entries which have since been deleted.
    static func cleanUpLeftovers(in context: ModelContext) {
        let flag = "leftoversCleaned.v1"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        let readByClaude = entries.filter { $0.analysedBy == "claude" && $0.analysedAt != nil }
        let claude = InsightSource.claude.rawValue
        let insights = (try? context.fetch(FetchDescriptor<Insight>(predicate: #Predicate { $0.sourceRaw == claude }))) ?? []
        for insight in insights where insight.entry == nil {
            // A note is written in the same moment its entry's reading is saved.
            if let source = readByClaude.first(where: { abs(($0.analysedAt ?? .distantPast).timeIntervalSince(insight.createdAt)) < 5 }) {
                insight.entry = source
            } else if insight.entityKeys.count != 1 && !insight.pinned {
                // Not a reading of one person or theme, and its entry is gone.
                context.delete(insight)
            }
        }
        for reflection in (try? context.fetch(FetchDescriptor<Reflection>())) ?? [] {
            let count = entries.filter { $0.createdAt >= reflection.start && $0.createdAt < reflection.end }.count
            if count < reflection.entryCount { context.delete(reflection) }
        }
        pruneOrphans(in: context)
        pruneStaleInsights(in: context)
        try? context.save()
        UserDefaults.standard.set(true, forKey: flag)
    }

    /// Once, for journals from before insights were taken from entries: finds the
    /// ones in entries written so far, on the phone.
    static func extractEarlierInsights(in context: ModelContext) {
        let flag = "insightsExtracted.v1"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        for entry in entries where entry.insights.isEmpty {
            let found = LocalReader.realisations(in: LocalReader.sentences(in: entry.text))
            replaceInsights(on: entry, with: found.map { EntryAnalysis.Extracted(text: $0) }, in: context)
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: flag)
    }

    /// Claude's journal-wide connections and the summary under them, which are
    /// out of date once whole sets of entries go.
    static func forgetConnections(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<Insight>())) ?? []
        for insight in all where insight.signature?.hasPrefix("link:") == true && !insight.pinned {
            context.delete(insight)
        }
        for key in [Prefs.connectionsSummary, Prefs.connectionsWrittenAt, Prefs.connectionsWrittenBy] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        try? context.save()
    }

    static func eraseEverything(in context: ModelContext) {
        forgetConnections(in: context)
        try? context.delete(model: Mention.self)
        try? context.delete(model: Entry.self)
        try? context.delete(model: Entity.self)
        try? context.delete(model: Insight.self)
        try? context.delete(model: Reflection.self)
        try? context.delete(model: TraitResult.self)
        try? context.save()
    }

    /// Everything, as JSON, for keeping or moving elsewhere.
    static func export(from context: ModelContext) throws -> URL {
        let entries = try context.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.createdAt)]))
        let insights = try context.fetch(FetchDescriptor<Insight>(sortBy: [SortDescriptor(\.createdAt)]))
        let reflections = try context.fetch(FetchDescriptor<Reflection>(sortBy: [SortDescriptor(\.start)]))
        let iso = ISO8601DateFormatter()

        let json: [String: Any] = [
            "exportedAt": iso.string(from: .now),
            "entries": entries.map { entry in
                [
                    "date": iso.string(from: entry.createdAt),
                    "text": entry.text,
                    "mood": entry.mood.map { $0 as Any } ?? NSNull(),
                    "summary": entry.summary.map { $0 as Any } ?? NSNull(),
                    "mentions": entry.mentions.compactMap { m -> [String: Any]? in
                        guard let e = m.entity else { return nil }
                        return ["name": e.name, "kind": e.kindRaw, "feeling": m.sentiment, "quote": m.quote]
                    },
                ] as [String: Any]
            },
            "insights": insights.map { ["date": iso.string(from: $0.createdAt), "text": $0.text, "source": $0.sourceRaw] },
            "reflections": reflections.map {
                ["period": $0.periodRaw, "start": iso.string(from: $0.start), "headline": $0.headline,
                 "body": $0.body, "patterns": $0.patterns, "questions": $0.questions] as [String: Any]
            },
        ]
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("undercurrent-\(iso.string(from: .now).prefix(10)).json")
        try data.write(to: url)
        return url
    }

    static func clamp(_ v: Double) -> Double { max(-1, min(1, v.isFinite ? v : 0)) }
}
