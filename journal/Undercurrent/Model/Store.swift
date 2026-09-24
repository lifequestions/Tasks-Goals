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

    var mood: Double
    var summary: String
    var entities: [Found]
    var noticed: String
    var followUp: String = ""
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
            entry.followUp = next.isEmpty ? nil : next
        }

        var seen = Set<String>()
        for found in analysis.entities {
            let name = found.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.count > 1 else { continue }
            let kind = EntityKind(rawValue: found.kind.lowercased()) ?? .theme
            let target = Self.entity(named: name, kind: kind, in: context)
            guard seen.insert(target.key).inserted else { continue }

            let mention = Mention(sentiment: clamp(found.sentiment), quote: String(found.quote.prefix(280)))
            context.insert(mention)
            mention.entry = entry
            mention.entity = target
        }
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

    static func eraseEverything(in context: ModelContext) {
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
