import Foundation
import SwiftData
import Observation

/// Where the Health dashboard is and the token it expects. The Mac's install script
/// writes a class conforming to this into Undercurrent/Generated/ (gitignored, so the
/// token never reaches GitHub); builds without it just don't sync.
@objc protocol HealthDashboardPairing {
    static var url: String { get }
    static var token: String { get }
}

/// Sends a daily rollup of the journal — how each day read, how much was written,
/// and who and what came up — to the Health dashboard on the Mac, so it can set
/// what you write beside your sleep and energy.
@MainActor
@Observable
final class HealthDashboard {
    static let shared = HealthDashboard()

    private static let fullSentKey = "healthDashboard.fullHistorySent"
    private static let sentDaysKey = "healthDashboard.sentDays"
    private static let lastSyncKey = "healthDashboard.lastSync"
    private static let lastCountKey = "healthDashboard.lastCount"

    private(set) var syncing = false
    private(set) var lastSync: Date?
    private(set) var lastCount = 0
    private(set) var problem: String?
    private var again = false

    private init() {
        let defaults = UserDefaults.standard
        let at = defaults.double(forKey: Self.lastSyncKey)
        lastSync = at > 0 ? Date(timeIntervalSince1970: at) : nil
        lastCount = defaults.integer(forKey: Self.lastCountKey)
    }

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Prefs.healthDashboard) as? Bool ?? true
    }

    static var pairing: HealthDashboardPairing.Type? {
        NSClassFromString("UndercurrentHealthDashboardPairing") as? HealthDashboardPairing.Type
    }

    var isPaired: Bool { Self.pairing != nil }

    // MARK: Sending

    /// The last 30 days (the whole history the first time). Quiet when the Mac isn't
    /// reachable; the next save, reading or launch tries again.
    func sync(in context: ModelContext) async {
        guard Self.isEnabled, let pairing = Self.pairing,
              let base = URL(string: pairing.url) else { return }
        guard !syncing else { again = true; return }
        syncing = true
        defer {
            syncing = false
            if again {
                again = false
                Task { await sync(in: context) }
            }
        }

        let defaults = UserDefaults.standard
        let full = !defaults.bool(forKey: Self.fullSentKey)
        let calendar = Calendar.current
        let since = full ? nil : calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: .now))

        let entries = ((try? context.fetch(FetchDescriptor<Entry>())) ?? [])
            .filter { entry in entry.isSample != true && entry.createdAt >= (since ?? .distantPast) }
        let entities = (try? context.fetch(FetchDescriptor<Entity>())) ?? []
        var days = Self.rollup(entries, entities: entities)

        // Days sent before that have no entries now (deleted since) go as empty, to clear them.
        let sent = Set(defaults.stringArray(forKey: Self.sentDaysKey) ?? [])
        let current = Set(days.map(\.day))
        let windowStart = since.map(Self.dayString)
        for day in sent.subtracting(current) where windowStart.map({ day >= $0 }) ?? true {
            days.append(JournalDay(day: day, mood: nil, words: 0, mentions: []))
        }
        guard !days.isEmpty else {
            defaults.set(true, forKey: Self.fullSentKey)
            problem = nil
            return
        }

        var request = URLRequest(url: base.appending(path: "api/ingest/journal"), timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(pairing.token, forHTTPHeaderField: "X-App-Token")
        request.httpBody = try? JSONEncoder().encode(Payload(days: days.sorted { $0.day < $1.day }))

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status) else {
                problem = status == 401 || status == 403
                    ? "The dashboard didn't accept the token. Install from the Mac again to re-pair."
                    : "The dashboard answered with an error (\(status))."
                return
            }
            defaults.set(true, forKey: Self.fullSentKey)
            defaults.set(Array(sent.union(current)).sorted(), forKey: Self.sentDaysKey)
            lastSync = .now
            lastCount = current.count
            defaults.set(Date.now.timeIntervalSince1970, forKey: Self.lastSyncKey)
            defaults.set(lastCount, forKey: Self.lastCountKey)
            problem = nil
        } catch {
            problem = "Couldn't reach the Mac. It'll try again next time."
        }
    }

    // MARK: The rollup

    struct Payload: Encodable {
        let days: [JournalDay]
    }

    struct JournalDay: Encodable {
        struct Mention: Encodable {
            let key: String
            let name: String
            let kind: String
            let count: Int
            let feeling: Double
        }

        let day: String
        let mood: Double?
        /// Average energy you rated that day, 1 (drained) to 5 (full of it).
        var energy: Double? = nil
        let words: Int
        let mentions: [Mention]
    }

    /// One item per local calendar day: average mood of the entries that have one,
    /// total words, and each person, place, theme or activity that came up — how many
    /// times and how it felt on average. Old names count toward the entity they were
    /// merged into; hidden entities and links you removed from an entry are left out.
    static func rollup(_ entries: [Entry], entities: [Entity]) -> [JournalDay] {
        var main: [String: Entity] = [:]
        for entity in entities { main[entity.key] = entity }
        for entity in entities {
            for alias in entity.aliasKeys where alias != entity.key { main[alias] = entity }
        }

        let calendar = Calendar.current
        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.createdAt) }
        return byDay.map { day, entries in
            let moods = entries.compactMap(\.mood)
            var tally: [String: (entity: Entity, count: Int, total: Double)] = [:]
            for entry in entries {
                let excluded = Set(entry.excludedKeys ?? [])
                for mention in entry.mentions {
                    guard let found = mention.entity else { continue }
                    let entity = main[found.key] ?? found
                    guard !entity.hidden, !found.hidden,
                          !excluded.contains(found.key), !excluded.contains(entity.key) else { continue }
                    var slot = tally[entity.key] ?? (entity, 0, 0)
                    slot.count += 1
                    slot.total += mention.sentiment
                    tally[entity.key] = slot
                }
            }
            let mentions = tally.values
                .map { JournalDay.Mention(key: $0.entity.key, name: $0.entity.name, kind: $0.entity.kindRaw,
                                          count: $0.count, feeling: $0.total / Double($0.count)) }
                .sorted { $0.count > $1.count }
            return JournalDay(day: dayString(day),
                              mood: moods.isEmpty ? nil : moods.reduce(0, +) / Double(moods.count),
                              energy: Energy.mean(entries.compactMap(\.energy)),
                              words: entries.reduce(0) { $0 + $1.wordCount },
                              mentions: mentions)
        }
        .sorted { $0.day < $1.day }
    }

    static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
