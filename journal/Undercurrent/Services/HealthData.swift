import Foundation

/// What the Health dashboard shares back — each day's sleep, HRV, workouts, energy and
/// tags, and the patterns it has found between those and the journal — cached on the
/// phone so entries, reflections and insights can use it without the Mac around.
///
/// GET /api/export/daily?days=60 (header X-App-Token) returns
///   { units, notes, days: [{ day, sleep_duration, deep_sleep, hrv, resting_hr, bedtime,
///     strength_minutes, energy, tags: […], … }], journalPatterns: [{ sentence, rho, days, q }] }
/// Sleep is filed under the day you woke up; hours are decimal; bedtime 24.5 = 00:30.
struct HealthData: Codable {
    struct Day: Codable {
        var values: [String: Double] = [:]
        var tags: [String] = []
    }

    struct JournalPattern: Codable, Hashable {
        var sentence: String
        var rho: Double?
        var days: Int?
        var q: Double?
    }

    var units: [String: String] = [:]
    /// "yyyy-MM-dd" → that day. Older days stay when a newer response doesn't cover them.
    var days: [String: Day] = [:]
    var journalPatterns: [JournalPattern] = []
    var updatedAt: Date?

    static let bedtimeKey = "bedtime"

    /// Measured overnight and filed under the morning you woke up.
    static func isOvernight(_ key: String) -> Bool {
        ["sleep", "hrv", "resting_hr", "bedtime"].contains { key.contains($0) }
    }

    func values(on day: String) -> [String: Double] { days[day]?.values ?? [:] }

    func label(_ key: String) -> String {
        switch key {
        case "sleep_duration": "sleep"
        case "deep_sleep": "deep sleep"
        case "hrv": "HRV"
        case "resting_hr": "resting heart rate"
        case "strength_minutes": "strength training"
        default: key.replacingOccurrences(of: "_", with: " ")
        }
    }

    func format(_ value: Double, for key: String) -> String {
        if key == Self.bedtimeKey { return Self.clock(value) }
        if key.contains("sleep") { return Self.duration(hours: value) }
        let unit = units[key].map { $0.isEmpty ? "" : " \($0)" } ?? ""
        let number = abs(value) < 10 ? String(format: "%.1f", value) : String(format: "%.0f", value)
        return number + unit
    }

    static func clock(_ hour: Double) -> String {
        let minutes = (Int((hour * 60).rounded()) % (24 * 60) + 24 * 60) % (24 * 60)
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    static func duration(hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        return minutes >= 60 ? "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m" : "\(minutes)m"
    }

    // MARK: For people and for Claude

    /// "7h 32m sleep · HRV 71 · strength training · sauna" — last night and the day.
    func line(for day: String, alsoDid: [String] = []) -> String? {
        let values = values(on: day)
        var parts: [String] = []
        if let sleep = values["sleep_duration"] { parts.append("\(Self.duration(hours: sleep)) sleep") }
        if let hrv = values["hrv"] { parts.append("HRV \(Int(hrv.rounded()))") }
        var things = (days[day]?.tags ?? []) + alsoDid
        if let strength = values["strength_minutes"], strength > 0,
           !things.contains(where: { $0.localizedCaseInsensitiveContains("strength") }) {
            things.append("strength \(Int(strength.rounded())) min")
        }
        var seen = Set<String>()
        parts += things.filter { seen.insert($0.lowercased()).inserted }.map { $0.lowercased() }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Everything known about one day, for Claude.
    func describe(_ day: String) -> String? {
        guard let entry = days[day] else { return nil }
        var parts = entry.values.sorted { $0.key < $1.key }.map { key, value in
            "\(label(key)) \(format(value, for: key))\(Self.isOvernight(key) ? " (night before)" : "")"
        }
        if !entry.tags.isEmpty { parts.append("tags: " + entry.tags.joined(separator: ", ")) }
        return parts.isEmpty ? nil : parts.joined(separator: "; ")
    }

    // MARK: Reading the dashboard's reply

    mutating func merge(_ data: Data) throws {
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        for (key, value) in reply.units ?? [:] { units[key] = value }
        for day in reply.days { days[day.day] = Day(values: day.values, tags: day.tags) }
        journalPatterns = reply.journalPatterns ?? []
        updatedAt = .now
    }

    private struct Reply: Decodable {
        let units: [String: String]?
        let days: [ReplyDay]
        let journalPatterns: [JournalPattern]?
    }

    /// A day's fields as they come: numbers become values, "tags" the day's tags, and
    /// anything else (text, nulls, nested objects) is passed over.
    private struct ReplyDay: Decodable {
        let day: String
        var values: [String: Double] = [:]
        var tags: [String] = []

        struct Key: CodingKey {
            var stringValue: String
            var intValue: Int? { nil }
            init(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Key.self)
            day = try c.decode(String.self, forKey: Key(stringValue: "day"))
            for key in c.allKeys where key.stringValue != "day" {
                if key.stringValue == "tags" {
                    tags = (try? c.decode([String].self, forKey: key)) ?? []
                } else if let number = try? c.decode(Double.self, forKey: key) {
                    values[key.stringValue] = number
                }
            }
        }
    }

    // MARK: Kept in a file beside the journal

    private static var file: URL {
        URL.applicationSupportDirectory.appending(path: "health-daily.json")
    }

    static func load() -> HealthData {
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode(HealthData.self, from: data) else { return HealthData() }
        return decoded
    }

    func save() {
        try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(self).write(to: Self.file, options: .atomic)
    }

    static func erase() {
        try? FileManager.default.removeItem(at: file)
    }
}
