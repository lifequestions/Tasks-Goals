import Foundation
import SwiftData

/// Connections day by day, across everything the journal knows about a day: what you
/// ticked on Today (sauna, alcohol, meds…), who and what you wrote about, how the day
/// read, your energy, and the numbers the Health dashboard shares back (sleep, bedtime…).
/// Each thing is compared with how that day — and the next — went, with and without it.
enum DayPatterns {
    private struct Day {
        var mood: Double?
        var energy: Double?
        var factors: Set<String> = []
        var logged = false
        var wrote = false
    }

    private enum Outcome: Hashable {
        case mood, energy, metric(String)
    }

    static func find(in entries: [Entry], health: HealthData = .load(),
                     done: [String: [String]] = CheckIn.done,
                     energyCheckIns: [String: Int] = Energy.checkIns) -> [FoundPattern] {
        var days: [String: Day] = [:]
        var names: [String: String] = [:]

        // What you wrote: mood, energy and who or what came up.
        let written = Dictionary(grouping: entries.filter { $0.isSample != true }) { Energy.day($0.createdAt) }
        for (key, entries) in written {
            var day = days[key] ?? Day()
            day.wrote = true
            let moods = entries.compactMap(\.mood)
            day.mood = moods.isEmpty ? nil : PatternFinder.mean(moods)
            for entry in entries {
                for mention in entry.mentions {
                    guard let entity = mention.entity, !entity.hidden,
                          !(entry.excludedKeys ?? []).contains(entity.key) else { continue }
                    day.factors.insert("entity:" + entity.key)
                    names["entity:" + entity.key] = entity.name
                }
            }
            days[key] = day
        }

        // Energy from entries and from Today's check-in.
        for (key, entries) in written {
            let levels = entries.compactMap(\.energy) + [energyCheckIns[key]].compactMap { $0 }
            days[key]?.energy = Energy.mean(levels)
        }
        for (key, level) in energyCheckIns where written[key] == nil {
            var day = days[key] ?? Day()
            day.energy = Double(level)
            day.logged = true
            days[key] = day
        }

        // What you ticked on Today.
        for (key, habits) in done {
            var day = days[key] ?? Day()
            day.logged = true
            for habit in habits {
                day.factors.insert("habit:" + habit)
                names["habit:" + habit] = habit
            }
            days[key] = day
        }
        for key in energyCheckIns.keys { days[key]?.logged = true }

        // The dashboard's tags for each day count the same as ticking them here.
        var habitNames: [String: String] = [:]
        for name in CheckIn.habits + done.values.flatMap({ $0 }) { habitNames[name.lowercased()] = name }
        for (key, entry) in health.days where !entry.tags.isEmpty {
            var day = days[key] ?? Day()
            day.logged = true
            for tag in entry.tags {
                let name = habitNames[tag.lowercased()] ?? (tag.prefix(1).uppercased() + String(tag.dropFirst()))
                day.factors.insert("habit:" + name)
                names["habit:" + name] = name
            }
            days[key] = day
        }
        for (key, day) in days where day.logged {
            // Normalise case so "sauna" from the dashboard and "Sauna" from Today are one thing.
            days[key]?.factors = Set(day.factors.map { factor in
                guard factor.hasPrefix("habit:") else { return factor }
                let name = String(factor.dropFirst(6))
                return "habit:" + (habitNames[name.lowercased()] ?? name)
            })
        }

        func value(_ outcome: Outcome, on key: String) -> Double? {
            switch outcome {
            case .mood: days[key]?.mood
            case .energy: days[key]?.energy
            case .metric(let metric): health.days[key]?.values[metric]
            }
        }

        // The dashboard's own energy is left out: it's the same ratings, sent from here.
        let metrics = Set(health.days.values.flatMap(\.values.keys)).subtracting(["energy"])
        var out: [FoundPattern] = []

        // How often each factor turns up, so one-offs are left alone.
        var counts: [String: Int] = [:]
        for day in days.values { for factor in day.factors { counts[factor, default: 0] += 1 } }

        for (factor, count) in counts where count >= 3 {
            let isHabit = factor.hasPrefix("habit:")
            // A habit counts as not done only on days you checked in; a subject as
            // not there only on days you wrote.
            let eligible = days.filter { isHabit ? $0.value.logged : $0.value.wrote }
            let with = eligible.filter { $0.value.factors.contains(factor) }.map(\.key)
            let without = eligible.filter { !$0.value.factors.contains(factor) }.map(\.key)
            guard with.count >= 3, without.count >= 3 else { continue }

            // Subjects against mood and energy are already covered entry by entry.
            var outcomes: [Outcome] = metrics.sorted().map { .metric($0) }
            if isHabit { outcomes = [.mood, .energy] + outcomes }

            var found: [(effect: Double, pattern: FoundPattern)] = []
            for outcome in outcomes {
                // Sleep, HRV and the like are filed under the morning after, so for those
                // only the night after the day counts; the rest, that day and the next.
                var lags = [0, 1]
                if case .metric(let key) = outcome, HealthData.isOvernight(key) { lags = [1] }
                for lag in lags {
                    let a = with.compactMap { shift($0, by: lag) }.compactMap { value(outcome, on: $0) }
                    let b = without.compactMap { shift($0, by: lag) }.compactMap { value(outcome, on: $0) }
                    guard a.count >= 3, b.count >= 3 else { continue }
                    let spread = deviation(a + b)
                    guard spread > 0 else { continue }
                    let diff = PatternFinder.mean(a) - PatternFinder.mean(b)
                    let effect = diff / spread
                    guard abs(effect) >= 0.5 else { continue }
                    let name = names[factor] ?? factor
                    found.append((effect, describe(name: name, factor: factor, isHabit: isHabit, outcome: outcome,
                                                   lag: lag, with: PatternFinder.mean(a), without: PatternFinder.mean(b),
                                                   strength: abs(effect) * log(Double(min(a.count, b.count)) + 1) * 0.7,
                                                   health: health)))
                }
            }
            out += found.sorted { abs($0.effect) > abs($1.effect) }.prefix(2).map(\.pattern)
        }

        if let bedtime = bestBedtime(health: health, value: value) { out.append(bedtime) }
        return out
    }

    // MARK: Words

    private static func describe(name: String, factor: String, isHabit: Bool, outcome: Outcome, lag: Int,
                                 with: Double, without: Double, strength: Double, health: HealthData) -> FoundPattern {
        var overnight = false
        if case .metric(let key) = outcome { overnight = HealthData.isOvernight(key) }
        let when = isHabit
            ? (lag == 0 ? "On \(name) days" : overnight ? "The night after \(name)" : "The day after \(name)")
            : (lag == 0 ? "On days you write about \(name)"
               : overnight ? "The night after you write about \(name)" : "The day after you write about \(name)")
        let higher = with > without
        let text: String
        let type: String
        var detail: String?
        switch outcome {
        case .mood:
            type = "daymood"
            text = "\(when), your entries read \(higher ? "lighter" : "heavier") — mostly \(Feeling.word(with)), against \(Feeling.word(without)) otherwise."
        case .energy:
            type = "dayenergy"
            text = "\(when), your energy is \(higher ? "higher" : "lower") — about \(String(format: "%.1f", with)) out of 5, against \(String(format: "%.1f", without)) otherwise."
        case .metric(let key):
            type = "dayhealth"
            let label = health.label(key)
            if key == HealthData.bedtimeKey {
                text = "\(when), you tend to go to bed \(higher ? "later" : "earlier") — around \(health.format(with, for: key)), against \(health.format(without, for: key)) otherwise."
                detail = "\(name) (\(higher ? "later" : "earlier") bedtime)"
            } else {
                text = "\(when), your \(label) is \(higher ? "higher" : "lower") — \(health.format(with, for: key)), against \(health.format(without, for: key)) otherwise."
                detail = "\(name) (\(higher ? "more" : "less") \(label))"
            }
        }
        let outcomeKey: String = switch outcome {
        case .mood: "mood"
        case .energy: "energy"
        case .metric(let key): key
        }
        return FoundPattern(signature: "\(type):\(factor):\(outcomeKey):\(lag)", text: text,
                            entityKeys: factor.hasPrefix("entity:") ? [String(factor.dropFirst(7))] : [],
                            strength: strength,
                            lift: type == "dayhealth" ? nil : with - without,
                            names: [name], detail: detail)
    }

    /// The hour-long bedtime window your best days follow: energy where you've rated
    /// enough of it, otherwise how the day's entries read. Bedtime is filed under the
    /// morning after, so it's compared with that same day.
    private static func bestBedtime(health: HealthData, value: (Outcome, String) -> Double?) -> FoundPattern? {
        let nights = health.days.compactMap { key, values -> (String, Double)? in
            values.values[HealthData.bedtimeKey].map { (key, $0) }
        }
        guard nights.count >= 9 else { return nil }

        for outcome in [Outcome.energy, .mood] {
            let pairs = nights.compactMap { key, bedtime -> (Double, Double)? in
                guard let v = value(outcome, key) else { return nil }
                return (bedtime, v)
            }
            guard pairs.count >= 9 else { continue }
            let buckets = Dictionary(grouping: pairs) { floor($0.0) }.filter { $0.value.count >= 3 }
            guard buckets.count >= 2 else { continue }
            let overall = PatternFinder.mean(pairs.map(\.1))
            guard let best = buckets.max(by: { PatternFinder.mean($0.value.map(\.1)) < PatternFinder.mean($1.value.map(\.1)) })
            else { continue }
            let bestMean = PatternFinder.mean(best.value.map(\.1))
            guard bestMean - overall >= (outcome == .energy ? 0.3 : 0.15) else { continue }
            let window = "\(HealthData.clock(best.key)) and \(HealthData.clock(best.key + 1))"
            let measure = outcome == .energy
                ? "your energy that day is about \(String(format: "%.1f", bestMean)) out of 5, against \(String(format: "%.1f", overall)) overall"
                : "that day's entries read \(Feeling.word(bestMean)), against \(Feeling.word(overall)) overall"
            return FoundPattern(signature: "bedtime:best", text: "Your best days follow a bedtime between \(window) — \(measure).",
                                entityKeys: [], strength: 2, names: [], detail: "bedtime between \(window)")
        }
        return nil
    }

    // MARK: Arithmetic

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func shift(_ day: String, by days: Int) -> String? {
        guard days != 0 else { return day }
        guard let date = dayFormatter.date(from: day),
              let moved = Calendar.current.date(byAdding: .day, value: days, to: date) else { return nil }
        return dayFormatter.string(from: moved)
    }

    private static func deviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let m = PatternFinder.mean(values)
        return (values.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(values.count - 1)).squareRoot()
    }
}
