import Foundation
import SwiftData
import Observation

enum Prefs {
    static let model = "claudeModel"
    static let onDeviceOnly = "onDeviceOnly"
    static let aboutMe = "aboutMe"
    static let reminderOn = "reminderOn"
    static let reminderTime = "reminderTime"
    static let apiKeyAccount = "anthropic-api-key"
    static let provider = "aiProvider"            // "anthropic" or "openrouter"
    static let openRouterModel = "openRouterModel"
    static let openRouterKeyAccount = "openrouter-api-key"
}

/// The app's understanding of the journal. Every entry is read on the phone
/// first, straight away; if Claude is set up it then reads it again, more deeply.
@MainActor
@Observable
final class Intelligence {
    /// Things in flight, so views can show a quiet spinner.
    var working: Set<String> = []
    var lastError: String?

    var claude: (any AIClient)? {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Prefs.onDeviceOnly) { return nil }
        if defaults.string(forKey: Prefs.provider) == "openrouter" {
            guard let key = Keychain.get(Prefs.openRouterKeyAccount), !key.isEmpty else { return nil }
            let chosen = defaults.string(forKey: Prefs.openRouterModel) ?? ""
            return OpenRouterClient(apiKey: key, model: chosen.isEmpty ? OpenRouterClient.defaultModel : chosen)
        }
        guard let key = Keychain.get(Prefs.apiKeyAccount), !key.isEmpty else { return nil }
        let model = UserDefaults.standard.string(forKey: Prefs.model) ?? ClaudeClient.defaultModel
        return ClaudeClient(apiKey: key, model: model)
    }

    var usesClaude: Bool { claude != nil }

    // MARK: Writing

    @discardableResult
    func saveEntry(text: String, dictated: Bool, question: String? = nil, tags: [Tag] = [], dropped: [String] = [],
                   date: Date = .now, in context: ModelContext) -> Entry {
        let entry = Entry(text: text, createdAt: date, wasDictated: dictated, question: question)
        entry.chosenTags = tags
        entry.excludedKeys = dropped.isEmpty ? nil : dropped
        context.insert(entry)
        Store.apply(LocalReader().read(text), to: entry, by: "device", in: context)
        try? context.save()
        Task { await read(entry, in: context) }
        return entry
    }

    func saveInsight(text: String, in context: ModelContext) {
        let found = LocalReader().read(text).entities
        let keys = found.compactMap { f in
            EntityKind(rawValue: f.kind).map { Entity.makeKey(name: f.name, kind: $0) }
        }
        context.insert(Insight(text: text, source: .mine, entityKeys: keys))
        try? context.save()
    }

    /// Reads (or re-reads) an entry: on the phone, then with Claude if available.
    func read(_ entry: Entry, in context: ModelContext) async {
        if entry.analysedBy == nil || entry.analysedAt ?? .distantPast < entry.createdAt {
            Store.apply(LocalReader().read(entry.text), to: entry, by: "device", in: context)
            try? context.save()
        }

        if let claude {
            let tag = "entry:\(entry.persistentModelID.hashValue)"
            working.insert(tag)
            defer { working.remove(tag) }
            do {
                let known = try context.fetch(FetchDescriptor<Entity>()).sorted { $0.mentions.count > $1.mentions.count }
                var recentQuery = FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
                recentQuery.fetchLimit = 12
                let recent = try context.fetch(recentQuery).filter { $0.persistentModelID != entry.persistentModelID }

                let result = try await claude.structured(
                    EntryAnalysis.self,
                    system: Prompts.readingSystem,
                    user: Prompts.readingRequest(entry: entry, known: known, recent: recent, profile: profile(in: context)),
                    schema: Prompts.readingSchema,
                    effort: "medium")

                guard !entry.isDeleted else { return }
                Store.apply(result, to: entry, by: "claude", in: context)
                let noticed = result.noticed.trimmingCharacters(in: .whitespacesAndNewlines)
                if !noticed.isEmpty {
                    let keys = entry.mentions.compactMap { $0.entity?.key }
                    context.insert(Insight(text: noticed, source: .claude, entityKeys: keys))
                }
                try? context.save()
            } catch {
                lastError = error.localizedDescription
            }
        }

        Store.pruneOrphans(in: context)
        try? context.save()
        refreshPatterns(in: context)
    }

    // MARK: Patterns

    func refreshPatterns(in context: ModelContext) {
        let entries = (try? context.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let found = PatternFinder.find(in: entries)
        let source = InsightSource.pattern.rawValue
        let existing = (try? context.fetch(FetchDescriptor<Insight>(predicate: #Predicate { $0.sourceRaw == source }))) ?? []
        var bySignature: [String: Insight] = [:]
        for insight in existing { bySignature[insight.signature ?? ""] = insight }

        let current = Set(found.map(\.signature))
        for pattern in found.prefix(20) {
            if let insight = bySignature[pattern.signature] {
                insight.text = pattern.text
            } else {
                context.insert(Insight(text: pattern.text, source: .pattern,
                                       entityKeys: pattern.entityKeys, signature: pattern.signature))
            }
        }
        for insight in existing where !current.contains(insight.signature ?? "") && !insight.pinned {
            context.delete(insight)
        }
        try? context.save()
    }

    // MARK: Reflections

    func reflectionKey(_ period: Period, _ interval: DateInterval) -> String {
        "reflection:\(period.rawValue):\(interval.start.timeIntervalSince1970)"
    }

    /// Writes the reflection for one period, replacing any earlier one.
    func reflect(on period: Period, interval: DateInterval, in context: ModelContext) async {
        let tag = reflectionKey(period, interval)
        guard !working.contains(tag) else { return }
        working.insert(tag)
        defer { working.remove(tag) }

        let start = interval.start, end = interval.end
        let entries = (try? context.fetch(FetchDescriptor<Entry>(
            predicate: #Predicate { $0.createdAt >= start && $0.createdAt < end },
            sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        guard !entries.isEmpty else { return }
        let stats = PeriodStats(entries: entries)

        let allReflections = (try? context.fetch(FetchDescriptor<Reflection>(sortBy: [SortDescriptor(\.start)]))) ?? []
        let children = period.child.map { child in
            allReflections.filter { $0.periodRaw == child.rawValue && $0.start >= start && $0.end <= end }
        } ?? []
        let previousInterval = period.shift(interval, by: -1)
        let previous = period == .allTime ? nil : allReflections.first {
            $0.periodRaw == period.rawValue && $0.start == previousInterval.start
        }
        let insights = ((try? context.fetch(FetchDescriptor<Insight>())) ?? [])
            .filter { !$0.dismissed && $0.createdAt >= start && $0.createdAt < end }

        var draft = localDraft(period: period, stats: stats, entries: entries)
        var writtenBy = "device"
        if let claude {
            do {
                draft = try await claude.structured(
                    Prompts.ReflectionDraft.self,
                    system: Prompts.reflectionSystem(for: period),
                    user: Prompts.reflectionRequest(period: period, interval: interval, entries: entries,
                                                    childReflections: children, previous: previous,
                                                    insights: insights, stats: stats, profile: profile(in: context)),
                    schema: Prompts.reflectionSchema,
                    effort: "high")
                writtenBy = "claude"
            } catch {
                lastError = error.localizedDescription
            }
        }

        for old in allReflections where old.periodRaw == period.rawValue && old.start == start {
            context.delete(old)
        }
        context.insert(Reflection(period: period, interval: interval, headline: draft.headline, body: draft.body,
                                  patterns: draft.patterns, questions: draft.questions,
                                  entryCount: stats.entryCount, averageMood: stats.averageMood, writtenBy: writtenBy))
        try? context.save()
    }

    /// Without Claude, a reflection is built from the numbers and the patterns.
    private func localDraft(period: Period, stats: PeriodStats, entries: [Entry]) -> Prompts.ReflectionDraft {
        let people = stats.top.filter { $0.entity.kind == .person }.prefix(3)
        let others = stats.top.filter { $0.entity.kind != .person }.prefix(3)
        var body = "You wrote \(stats.entryCount) \(stats.entryCount == 1 ? "entry" : "entries") and \(stats.wordCount) words. "
        body += "On the whole it read \(Feeling.word(stats.averageMood))."
        if !people.isEmpty {
            body += "\n\nThe people who came up most: " + people.map { "\($0.entity.name) (\($0.count), mostly \(Feeling.word($0.feeling)))" }.joined(separator: ", ") + "."
        }
        if !others.isEmpty {
            body += " Also on your mind: " + others.map { "\($0.entity.name.lowercased())" }.joined(separator: ", ") + "."
        }
        let heaviest = entries.filter { $0.mood != nil }.min { ($0.mood ?? 0) < ($1.mood ?? 0) }
        let lightest = entries.filter { $0.mood != nil }.max { ($0.mood ?? 0) < ($1.mood ?? 0) }
        if let lightest, let heaviest, lightest.persistentModelID != heaviest.persistentModelID {
            body += "\n\nThe lightest moment was \(lightest.createdAt.stamp("EEEEdMMM")) — “\(lightest.title)”. The heaviest was \(heaviest.createdAt.stamp("EEEEdMMM")) — “\(heaviest.title)”."
        }
        let patterns = PatternFinder.find(in: entries).prefix(4).map(\.text)
        return Prompts.ReflectionDraft(
            headline: "\(period == .allTime ? "Everything" : "A \(period.label.lowercased())") that read \(Feeling.word(stats.averageMood))",
            body: body,
            patterns: patterns,
            questions: people.first.map { ["What do you need from \($0.entity.name) right now?"] } ?? [])
    }

    /// Writes any reflections for periods that have just ended.
    func catchUp(in context: ModelContext) async {
        refreshPatterns(in: context)
        let existing = (try? context.fetch(FetchDescriptor<Reflection>())) ?? []
        for period in [Period.week, .month, .quarter, .year] {
            let last = period.shift(period.interval(containing: .now), by: -1)
            let done = existing.contains { $0.periodRaw == period.rawValue && $0.start == last.start }
            guard !done else { continue }
            let start = last.start, end = last.end
            let count = (try? context.fetchCount(FetchDescriptor<Entry>(
                predicate: #Predicate { $0.createdAt >= start && $0.createdAt < end }))) ?? 0
            if count >= 2 {
                await reflect(on: period, interval: last, in: context)
            }
        }
    }

    // MARK: Deeper readings

    func readEntity(_ entity: Entity, in context: ModelContext) async -> String? {
        guard let claude else { return nil }
        let tag = "entity:\(entity.key)"
        working.insert(tag)
        defer { working.remove(tag) }
        do {
            let result = try await claude.structured(
                Prompts.EntityReading.self,
                system: Prompts.entitySystem,
                user: Prompts.entityRequest(entity, alongside: alongside(entity), profile: profile(in: context)),
                schema: Prompts.entitySchema,
                effort: "high")
            context.insert(Insight(text: result.reading, source: .claude, entityKeys: [entity.key]))
            try? context.save()
            return result.reading
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func ask(_ question: String, in context: ModelContext) async -> String? {
        guard let claude else { return nil }
        working.insert("ask")
        defer { working.remove("ask") }
        var recent = FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        recent.fetchLimit = 300
        let entries = ((try? context.fetch(recent)) ?? []).reversed()
        let reflections = (try? context.fetch(FetchDescriptor<Reflection>(sortBy: [SortDescriptor(\.start)]))) ?? []
        do {
            let result = try await claude.structured(
                Prompts.Answer.self,
                system: Prompts.askSystem,
                user: Prompts.askRequest(question: question, entries: Array(entries),
                                         reflections: reflections, profile: profile(in: context)),
                schema: Prompts.askSchema,
                effort: "medium")
            return result.answer
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    /// Other entities that share entries with this one, most frequent first.
    func alongside(_ entity: Entity) -> [(String, Int)] {
        var counts: [String: (String, Int)] = [:]
        for mention in entity.mentions {
            for other in mention.entry?.mentions ?? [] {
                guard let e = other.entity, e.key != entity.key else { continue }
                counts[e.key, default: (e.name, 0)].1 += 1
            }
        }
        return counts.values.sorted { $0.1 > $1.1 }
    }

    // MARK: What Claude knows about you

    func profile(in context: ModelContext) -> String {
        var parts: [String] = []
        let about = UserDefaults.standard.string(forKey: Prefs.aboutMe) ?? ""
        if !about.isEmpty { parts.append(about) }
        let results = (try? context.fetch(FetchDescriptor<TraitResult>(sortBy: [SortDescriptor(\.takenAt, order: .reverse)]))) ?? []
        var seen = Set<String>()
        for result in results where seen.insert(result.testID).inserted {
            guard let test = Questionnaire.catalog.first(where: { $0.id == result.testID }) else { continue }
            parts.append(test.describe(result.scores))
        }
        return parts.joined(separator: "\n\n")
    }
}
