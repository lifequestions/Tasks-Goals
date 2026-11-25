import Foundation
import SwiftData

/// The whole journal, day by day, in a form Claude can actually analyse: one line per
/// day with everything known about it, what's changed lately, and what came before
/// your best and worst days.
extension Intelligence {
    func allDays(in context: ModelContext) -> [JournalDay] {
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        return JournalDay.all(from: entries).sorted { $0.day < $1.day }
    }

    /// One line per day, oldest first.
    func dayTable(_ days: [JournalDay]) -> String {
        let health = HealthDashboard.shared.health
        let lines = days.map { day -> String in
            var parts = [day.date.stamp("EEEdMMMyyyy")]
            if let mood = day.mood { parts.append("mood \(Feeling.word(mood)) (\(String(format: "%.2f", mood)))") }
            if let energy = day.dayEnergy { parts.append("energy \(String(format: "%.1f", energy))/5") }
            for key in ["sleep_duration", "deep_sleep", "bedtime", "hrv", "resting_hr", "strength_minutes"] {
                if let value = day.health[key] { parts.append("\(health.label(key)) \(health.format(value, for: key))") }
            }
            let did = Array(Set(day.habits + day.healthTags)).sorted()
            if !did.isEmpty { parts.append("did: " + did.joined(separator: ", ")) }
            let about = Array(Set(day.entries.flatMap { $0.entities.filter { !$0.hidden }.map(\.name) })).sorted()
            if !about.isEmpty { parts.append("about: " + about.prefix(8).joined(separator: ", ")) }
            if day.words > 0 { parts.append("\(day.words) words") }
            if let first = day.entries.first { parts.append("“\(first.summary ?? first.title)”") }
            return parts.joined(separator: " | ")
        }
        return "<every_day>\nSleep, HRV and bedtime are for the night before each day. Mood runs -1 (heavy) to 1 (light).\n"
            + lines.joined(separator: "\n") + "\n</every_day>"
    }

    /// The full text of recent entries, newest first, up to a budget.
    func recentWriting(_ days: [JournalDay], budget: Int = 40_000) -> String {
        var used = 0
        var blocks: [String] = []
        for entry in days.reversed().flatMap({ $0.entries.reversed() }) {
            let block = "### \(entry.createdAt.stamp("EEEdMMMyyyyjmm")) [\(Feeling.word(entry.mood))\(Energy.note(entry.energy))]\n\(entry.text)"
            guard used + block.count <= budget else { break }
            used += block.count
            blocks.append(block)
        }
        guard !blocks.isEmpty else { return "" }
        return "<recent_writing>\nThe full text of their most recent entries, newest first:\n\n"
            + blocks.joined(separator: "\n\n") + "\n</recent_writing>"
    }

    /// The last two weeks against the six before, and what came before the best and worst days.
    func trends(_ days: [JournalDay]) -> String {
        let health = HealthDashboard.shared.health
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func age(_ day: JournalDay) -> Int { calendar.dateComponents([.day], from: day.date, to: today).day ?? 0 }
        let recent = days.filter { age($0) < 14 }
        let earlier = days.filter { age($0) >= 14 && age($0) < 56 }
        var lines: [String] = []

        func compare(_ name: String, _ value: (JournalDay) -> Double?, format: (Double) -> String) {
            let a = recent.compactMap(value), b = earlier.compactMap(value)
            guard a.count >= 4, b.count >= 4 else { return }
            lines.append("- \(name): \(format(PatternFinder.mean(a))) in the last two weeks, against \(format(PatternFinder.mean(b))) in the six before")
        }
        compare("mood", { $0.mood }) { String(format: "%.2f", $0) }
        compare("energy", { $0.dayEnergy }) { String(format: "%.1f/5", $0) }
        for key in ["sleep_duration", "deep_sleep", "bedtime", "hrv", "resting_hr"] {
            compare(health.label(key), { $0.health[key] }) { health.format($0, for: key) }
        }

        // How often each thing happened, recent against earlier.
        func share(_ name: String, in set: [JournalDay]) -> Double {
            let logged = set.filter { !$0.habits.isEmpty || !$0.healthTags.isEmpty || $0.energy != nil }
            guard !logged.isEmpty else { return 0 }
            return Double(logged.filter { ($0.habits + $0.healthTags).contains { $0.caseInsensitiveCompare(name) == .orderedSame } }.count)
                / Double(logged.count)
        }
        let habits = Set(days.flatMap { $0.habits + $0.healthTags }.map { $0.lowercased() })
        for habit in habits.sorted() {
            let a = share(habit, in: recent), b = share(habit, in: earlier)
            if abs(a - b) >= 0.2 {
                lines.append("- \(habit): \(Int(a * 100))% of checked-in days lately, against \(Int(b * 100))% before")
            }
        }

        // People and subjects coming up more or less.
        func mentions(_ set: [JournalDay]) -> [String: Int] {
            var out: [String: Int] = [:]
            for day in set { for name in Set(day.entries.flatMap { $0.entities.map(\.name) }) { out[name, default: 0] += 1 } }
            return out
        }
        let ma = mentions(recent), mb = mentions(earlier)
        for name in Set(ma.keys).union(mb.keys).sorted() {
            let a = ma[name] ?? 0, b = Int((Double(mb[name] ?? 0) / 3).rounded())   // six weeks scaled to two
            if abs(a - b) >= 3 { lines.append("- \(name): on \(a) days in the last two weeks, against about \(b) per two weeks before") }
        }

        // The best and worst days, and the day and night before each.
        let byKey = Dictionary(uniqueKeysWithValues: days.map { ($0.day, $0) })
        func before(_ day: JournalDay) -> String {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day.date),
                  let p = byKey[Energy.day(prev)] else { return "nothing logged the day before" }
            var bits: [String] = []
            let did = p.habits + p.healthTags
            if !did.isEmpty { bits.append("did " + did.joined(separator: ", ")) }
            if let mood = p.mood { bits.append("mood \(Feeling.word(mood))") }
            if let sleep = day.health["sleep_duration"] { bits.append("then slept \(HealthData.duration(hours: sleep))") }
            if let bed = day.health[HealthData.bedtimeKey] { bits.append("bed at \(HealthData.clock(bed))") }
            return bits.isEmpty ? "little logged the day before" : "day before: " + bits.joined(separator: ", ")
        }
        let rated = days.filter { $0.mood != nil || $0.dayEnergy != nil }
        if rated.count >= 10 {
            func score(_ d: JournalDay) -> Double { (d.mood ?? 0) + ((d.dayEnergy ?? 3) - 3) / 2 }
            let sorted = rated.sorted { score($0) > score($1) }
            lines.append("Best days:")
            lines += sorted.prefix(5).map { "  - \($0.date.stamp("EEEdMMM")): \(before($0))" }
            lines.append("Worst days:")
            lines += sorted.suffix(5).reversed().map { "  - \($0.date.stamp("EEEdMMM")): \(before($0))" }
        }
        guard !lines.isEmpty else { return "" }
        return "<trends>\n" + lines.joined(separator: "\n") + "\n</trends>"
    }
}
