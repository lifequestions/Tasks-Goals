import Foundation
import SwiftData

// The journal is five kinds of thing:
//   Entry      what you wrote or said
//   Entity     a person, place, theme or activity that turns up in entries
//   Mention    one entity in one entry, with how you felt about it there
//   Insight    something noticed — by you, by the pattern finder, or by Claude
//   Reflection a written summary of a week, month, quarter, year or all of it
// plus TraitResult for personality questionnaires.
//
// Feelings are always -1 (heavy) … 0 (even) … +1 (light).

enum EntityKind: String, Codable, CaseIterable, Identifiable {
    case person, place, theme, activity

    var id: String { rawValue }

    var plural: String {
        switch self {
        case .person: "People"
        case .place: "Places"
        case .theme: "Themes"
        case .activity: "Activities"
        }
    }

    var symbol: String {
        switch self {
        case .person: "person.fill"
        case .place: "mappin"
        case .theme: "circle.hexagongrid.fill"
        case .activity: "figure.walk"
        }
    }
}

@Model
final class Entry {
    var createdAt: Date
    var text: String
    var wasDictated: Bool
    var mood: Double?
    var summary: String?
    /// "device" or "claude" — which reader last understood this entry.
    var analysedBy: String?
    var analysedAt: Date?
    /// The question this entry was written in answer to, if any.
    var question: String?
    /// A question Claude suggests asking next, drawn from this entry.
    var followUp: String?
    /// Part of the sample journal, so it can be removed without touching real entries.
    var isSample: Bool?

    @Relationship(deleteRule: .cascade, inverse: \Mention.entry)
    var mentions: [Mention] = []

    init(text: String, createdAt: Date = .now, wasDictated: Bool = false, question: String? = nil) {
        self.text = text
        self.question = question
        self.createdAt = createdAt
        self.wasDictated = wasDictated
    }

    var title: String {
        if let summary, !summary.isEmpty { return summary }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return firstLine.count > 90 ? String(firstLine.prefix(88)) + "…" : firstLine
    }

    var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    var entities: [Entity] {
        mentions.compactMap(\.entity)
    }
}

@Model
final class Entity {
    @Attribute(.unique) var key: String
    var name: String
    var kindRaw: String
    var createdAt: Date
    var hidden: Bool = false
    /// Keys of other names that mean this one ("sam" after merging Sam into Samantha).
    var aliasKeys: [String] = []

    @Relationship(deleteRule: .cascade, inverse: \Mention.entity)
    var mentions: [Mention] = []

    init(name: String, kind: EntityKind) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.key = Entity.makeKey(name: name, kind: kind)
        self.createdAt = .now
    }

    var kind: EntityKind { EntityKind(rawValue: kindRaw) ?? .theme }

    var averageFeeling: Double? {
        guard !mentions.isEmpty else { return nil }
        return mentions.map(\.sentiment).reduce(0, +) / Double(mentions.count)
    }

    var firstMentioned: Date? { mentions.compactMap { $0.entry?.createdAt }.min() }
    var lastMentioned: Date? { mentions.compactMap { $0.entry?.createdAt }.max() }

    static func makeKey(name: String, kind: EntityKind) -> String {
        let folded = name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return "\(kind.rawValue):\(folded)"
    }
}

@Model
final class Mention {
    var sentiment: Double
    var quote: String
    var entry: Entry?
    var entity: Entity?

    init(sentiment: Double, quote: String) {
        self.sentiment = sentiment
        self.quote = quote
    }
}

enum InsightSource: String, Codable {
    case mine      // you told the app
    case pattern   // the on-device pattern finder
    case claude    // Claude noticed it

    var label: String {
        switch self {
        case .mine: "Yours"
        case .pattern: "Pattern"
        case .claude: "Noticed"
        }
    }
}

@Model
final class Insight {
    var createdAt: Date
    var text: String
    var sourceRaw: String
    /// Stable id for computed patterns, so re-running the finder updates rather than duplicates.
    var signature: String?
    var entityKeys: [String] = []
    var pinned: Bool = false
    var dismissed: Bool = false

    init(text: String, source: InsightSource, entityKeys: [String] = [], signature: String? = nil) {
        self.text = text
        self.sourceRaw = source.rawValue
        self.entityKeys = entityKeys
        self.signature = signature
        self.createdAt = .now
    }

    var source: InsightSource { InsightSource(rawValue: sourceRaw) ?? .mine }
}

@Model
final class Reflection {
    var periodRaw: String
    var start: Date
    var end: Date
    var createdAt: Date
    var headline: String
    var body: String
    var patterns: [String] = []
    var questions: [String] = []
    var entryCount: Int
    var averageMood: Double?
    var writtenBy: String

    init(period: Period, interval: DateInterval, headline: String, body: String,
         patterns: [String], questions: [String], entryCount: Int, averageMood: Double?, writtenBy: String) {
        self.periodRaw = period.rawValue
        self.start = interval.start
        self.end = interval.end
        self.createdAt = .now
        self.headline = headline
        self.body = body
        self.patterns = patterns
        self.questions = questions
        self.entryCount = entryCount
        self.averageMood = averageMood
        self.writtenBy = writtenBy
    }

    var period: Period { Period(rawValue: periodRaw) ?? .week }
}

@Model
final class TraitResult {
    var testID: String
    var takenAt: Date
    var scoresData: Data

    init(testID: String, scores: [String: Double]) {
        self.testID = testID
        self.takenAt = .now
        self.scoresData = (try? JSONEncoder().encode(scores)) ?? Data()
    }

    /// Each trait 0 … 1.
    var scores: [String: Double] {
        (try? JSONDecoder().decode([String: Double].self, from: scoresData)) ?? [:]
    }
}

enum Period: String, CaseIterable, Identifiable, Codable {
    case week, month, quarter, year, allTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .quarter: "Quarter"
        case .year: "Year"
        case .allTime: "All"
        }
    }

    func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        switch self {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
        case .month:
            return calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 30 * 86_400)
        case .quarter:
            // Calendar's own .quarter support is unreliable; work it out from the month.
            let parts = calendar.dateComponents([.year, .month], from: date)
            let firstMonth = ((parts.month ?? 1) - 1) / 3 * 3 + 1
            let start = calendar.date(from: DateComponents(year: parts.year, month: firstMonth, day: 1)) ?? date
            let end = calendar.date(byAdding: .month, value: 3, to: start) ?? date
            return DateInterval(start: start, end: end)
        case .year:
            return calendar.dateInterval(of: .year, for: date) ?? DateInterval(start: date, duration: 365 * 86_400)
        case .allTime:
            return DateInterval(start: .distantPast, end: .distantFuture)
        }
    }

    func shift(_ interval: DateInterval, by steps: Int, calendar: Calendar = .current) -> DateInterval {
        let component: Calendar.Component
        var value = steps
        switch self {
        case .week: component = .weekOfYear
        case .month: component = .month
        case .quarter: component = .month; value = steps * 3
        case .year: component = .year
        case .allTime: return interval
        }
        let moved = calendar.date(byAdding: component, value: value, to: interval.start) ?? interval.start
        return self.interval(containing: moved, calendar: calendar)
    }

    func title(for interval: DateInterval, now: Date = .now) -> String {
        let current = self.interval(containing: now)
        switch self {
        case .week:
            if interval == current { return "This week" }
            if interval == shift(current, by: -1) { return "Last week" }
            return "Week of \(interval.start.stamp("dMMM"))"
        case .month:
            return interval.start.stamp("MMMMyyyy")
        case .quarter:
            let month = Calendar.current.component(.month, from: interval.start)
            return "Q\((month - 1) / 3 + 1) \(interval.start.stamp("yyyy"))"
        case .year:
            return interval.start.stamp("yyyy")
        case .allTime:
            return "Everything so far"
        }
    }

    /// The shorter period whose reflections feed this one's, so a year can be
    /// read from four quarters instead of 365 entries.
    var child: Period? {
        switch self {
        case .week, .month: nil
        case .quarter: .month
        case .year: .quarter
        case .allTime: .year
        }
    }
}
