import SwiftUI
import SwiftData

/// Everything known about one day: what you wrote, how it read, your energy and
/// check-ins, and the Health dashboard's numbers for it.
struct JournalDay: Identifiable, Hashable {
    let day: String          // "yyyy-MM-dd"
    let date: Date
    var entries: [Entry]
    var energy: Int?
    var habits: [String]
    var health: [String: Double]
    var healthTags: [String]

    var id: String { day }

    var mood: Double? {
        let moods = entries.compactMap(\.mood)
        return moods.isEmpty ? nil : PatternFinder.mean(moods)
    }

    var dayEnergy: Double? {
        Energy.mean(entries.compactMap(\.energy) + [energy].compactMap { $0 })
    }

    var words: Int { entries.reduce(0) { $0 + $1.wordCount } }

    static func == (a: JournalDay, b: JournalDay) -> Bool { a.day == b.day }
    func hash(into hasher: inout Hasher) { hasher.combine(day) }

    /// Every day with anything on it, newest first: entries, a check-in or health numbers.
    @MainActor
    static func all(from entries: [Entry]) -> [JournalDay] {
        let health = HealthDashboard.shared.health
        let checkIns = Energy.checkIns
        let done = CheckIn.done
        let written = Dictionary(grouping: entries.filter { $0.isSample != true }) { Energy.day($0.createdAt) }
        let keys = Set(written.keys).union(checkIns.keys).union(done.keys).union(health.days.keys)
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = .current
        parser.dateFormat = "yyyy-MM-dd"
        let today = Energy.day(.now)
        return keys.filter { $0 <= today }.compactMap { key -> JournalDay? in
            guard let date = parser.date(from: key) else { return nil }
            return JournalDay(day: key, date: date,
                              entries: (written[key] ?? []).sorted { $0.createdAt < $1.createdAt },
                              energy: checkIns[key], habits: done[key] ?? [],
                              health: health.days[key]?.values ?? [:], healthTags: health.days[key]?.tags ?? [])
        }
        .sorted { $0.day > $1.day }
    }
}

/// Every day, newest first, to scroll back through. Tap one to read it whole.
struct DaysView: View {
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]

    var body: some View {
        let days = JournalDay.all(from: entries)
        List {
            ForEach(days) { day in
                NavigationLink {
                    DayPager(days: days, start: day.day)
                } label: {
                    DayRow(day: day)
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Palette.line)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Every day")
        .overlay {
            if days.isEmpty {
                ContentUnavailableView("No days yet", systemImage: "calendar",
                                       description: Text("Write, or check in on Today, and each day gathers here."))
            }
        }
    }
}

struct DayRow: View {
    let day: JournalDay

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Text(day.date.stamp("d")).font(.system(.title, design: .serif, weight: .light))
                Text(day.date.stamp("EEE").uppercased())
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
            }
            .frame(width: 38)

            VStack(alignment: .leading, spacing: 5) {
                Text(day.date.stamp("MMMMyyyy")).font(.caption).foregroundStyle(Palette.ink3)
                if let first = day.entries.first {
                    Text(first.summary ?? first.title)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                } else {
                    Text("No entry").font(.body).foregroundStyle(Palette.ink3)
                }
                let facts = DayFacts.short(day)
                if !facts.isEmpty {
                    Text(facts).font(.footnote).foregroundStyle(Palette.ink2).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            FeelingDot(value: day.mood).padding(.top, 8)
        }
        .padding(.vertical, 6)
    }
}

/// Swipe between days, oldest to the left.
struct DayPager: View {
    let days: [JournalDay]
    @State var start: String

    var body: some View {
        TabView(selection: $start) {
            ForEach(days.reversed()) { day in
                ScrollView { DayDetail(day: day).padding(20) }
                    .tag(day.day)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .screenBackground()
        .navigationTitle(days.first { $0.day == start }?.date.stamp("EEEdMMM") ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One day in full.
struct DayDetail: View {
    let day: JournalDay

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(day.date.stamp("EEEEdMMMMyyyy"))
                Text(day.mood.map { "A \(Feeling.word($0)) day" } ?? "A day without an entry")
                    .font(.headline2).foregroundStyle(Palette.ink)
            }

            Card {
                Eyebrow("The day")
                ForEach(DayFacts.lines(day), id: \.self) { line in
                    Text(line).font(.callout).foregroundStyle(Palette.ink)
                }
                if DayFacts.lines(day).isEmpty {
                    Text("Nothing checked in or measured.").font(.callout).foregroundStyle(Palette.ink3)
                }
            }

            ForEach(day.entries) { entry in
                NavigationLink(value: entry) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(entry.createdAt.stamp("jmm")).font(.footnote).foregroundStyle(Palette.ink3)
                            Spacer()
                            FeelingDot(value: entry.mood)
                        }
                        if let question = entry.question {
                            Text(question).font(.callout.italic()).foregroundStyle(Palette.ink2)
                        }
                        Text(entry.text)
                            .font(.reading)
                            .lineSpacing(6)
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                        ForEach(entry.insights.filter { !$0.dismissed }) { insight in
                            Label(insight.text, systemImage: "sparkles")
                                .font(.callout)
                                .foregroundStyle(Palette.ink2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                Divider().overlay(Palette.line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The day's facts in words, for the list and the day page.
enum DayFacts {
    @MainActor
    static func lines(_ day: JournalDay) -> [String] {
        let health = HealthDashboard.shared.health
        var out: [String] = []
        if let energy = day.dayEnergy {
            out.append("Energy \(String(format: "%.0f", energy.rounded())) of 5 — \(Energy.word(Int(energy.rounded())))")
        }
        let did = uniqued(day.habits + day.healthTags)
        if !did.isEmpty { out.append("Did: " + did.joined(separator: ", ")) }
        let order = ["sleep_duration", "deep_sleep", "bedtime", "hrv", "resting_hr", "strength_minutes"]
        let keys = order.filter { day.health[$0] != nil }
            + day.health.keys.filter { !order.contains($0) && $0 != "energy" }.sorted()
        for key in keys {
            guard let value = day.health[key] else { continue }
            let night = HealthData.isOvernight(key) ? " (night before)" : ""
            out.append("\(health.label(key).prefix(1).uppercased() + health.label(key).dropFirst()) \(health.format(value, for: key))\(night)")
        }
        if day.words > 0 { out.append("\(day.words) words written") }
        return out
    }

    @MainActor
    static func short(_ day: JournalDay) -> String {
        HealthDashboard.shared.health.line(for: day.day, alsoDid: day.habits) ?? ""
    }

    private static func uniqued(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { seen.insert($0.lowercased()).inserted }
    }
}
