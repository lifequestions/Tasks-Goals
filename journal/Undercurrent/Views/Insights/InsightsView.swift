import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Environment(\.modelContext) private var context
    @Environment(Intelligence.self) private var intelligence
    @Query(sort: \Entry.createdAt) private var entries: [Entry]
    @Query(sort: \Reflection.createdAt, order: .reverse) private var reflections: [Reflection]
    @Query(filter: #Predicate<Insight> { !$0.dismissed }, sort: \Insight.createdAt, order: .reverse)
    private var insights: [Insight]

    @State private var period: Period = .week
    @State private var interval = Period.week.interval(containing: .now)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Picker("Period", selection: $period) {
                        ForEach(Period.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    navigator
                    if !periodEntries.isEmpty { moodCard }
                    ReflectionCard(period: period, interval: interval, reflection: reflection,
                                   hasEntries: !periodEntries.isEmpty)
                    if !stats.top.isEmpty { presenceCard }
                    AskCard()
                    ConnectionsSection()
                    insightsCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .screenBackground()
            .navigationTitle("Insights")
            .journalDestinations()
            .onChange(of: period) { _, p in interval = p.interval(containing: .now) }
        }
    }

    // MARK: Parts

    private var navigator: some View {
        HStack {
            Button { interval = period.shift(interval, by: -1) } label: {
                Image(systemName: "chevron.left").frame(width: 36, height: 36)
            }
            .disabled(period == .allTime)
            Spacer()
            VStack(spacing: 2) {
                Text(period.title(for: interval)).font(.headline2).foregroundStyle(Palette.ink)
                Text("\(periodEntries.count) \(periodEntries.count == 1 ? "entry" : "entries")")
                    .font(.footnote).foregroundStyle(Palette.ink3)
            }
            Spacer()
            Button { interval = period.shift(interval, by: 1) } label: {
                Image(systemName: "chevron.right").frame(width: 36, height: 36)
            }
            .disabled(period == .allTime || interval.end > .now)
        }
        .foregroundStyle(Palette.ink2)
    }

    private var moodCard: some View {
        Card {
            HStack {
                Eyebrow("How it felt")
                Spacer()
                Text("mostly \(Feeling.word(stats.averageMood))").font(.footnote).foregroundStyle(Palette.ink2)
            }
            Chart(moodPoints) { point in
                AreaMark(x: .value("Date", point.date), yStart: .value("Zero", 0), yEnd: .value("Feeling", point.mood))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Palette.accent.opacity(0.25), .clear],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", point.date), y: .value("Feeling", point.mood))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Palette.accent)
                PointMark(x: .value("Date", point.date), y: .value("Feeling", point.mood))
                    .foregroundStyle(Palette.feeling(point.mood))
                    .symbolSize(40)
            }
            .chartYScale(domain: -1.0...1.0)
            .chartYAxis {
                AxisMarks(values: [-1.0, 0, 1]) { value in
                    AxisGridLine().foregroundStyle(Palette.line)
                    AxisValueLabel {
                        Text(value.as(Double.self).map { $0 < 0 ? "heavy" : $0 > 0 ? "light" : "even" } ?? "")
                    }
                }
            }
            .frame(height: 150)
        }
    }

    private var presenceCard: some View {
        Card {
            Eyebrow("Who and what came up")
            ForEach(stats.top.prefix(6), id: \.entity.key) { presence in
                NavigationLink(value: presence.entity) {
                    HStack(spacing: 10) {
                        Image(systemName: presence.entity.kind.symbol)
                            .font(.system(.subheadline))
                            .foregroundStyle(Palette.ink3)
                            .frame(width: 18)
                        Text(presence.entity.name).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(presence.count)").font(.callout.monospacedDigit()).foregroundStyle(Palette.ink3)
                        FeelingDot(value: presence.feeling)
                    }
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The newest few insights from your entries, and the way into all of them.
    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow("Insights")
                Spacer()
                NavigationLink { InsightListView() } label: {
                    Text(insights.isEmpty ? "Open" : "See all \(insights.count)").font(.footnote.weight(.semibold))
                }
                .foregroundStyle(Palette.accent)
            }
            if insights.isEmpty {
                Text("As you write, the things you realise about yourself — and the connections between entries — gather here as a list.")
                    .font(.subheadline).foregroundStyle(Palette.ink3)
            }
            ForEach(insights.sorted { $0.pinned && !$1.pinned }.prefix(4)) { InsightCard(insight: $0) }
        }
    }

    // MARK: Derived

    private var periodEntries: [Entry] {
        entries.filter { interval.contains($0.createdAt) && $0.createdAt < interval.end }
    }

    private var stats: PeriodStats { PeriodStats(entries: periodEntries) }

    private var reflection: Reflection? {
        reflections.first { $0.periodRaw == period.rawValue && $0.start == interval.start }
    }

    struct MoodPoint: Identifiable {
        let date: Date
        let mood: Double
        var id: Date { date }
    }

    /// One point per entry for a week or month; weekly averages beyond that.
    private var moodPoints: [MoodPoint] {
        let rated = periodEntries.filter { $0.mood != nil }
        if period == .week || period == .month {
            return rated.map { MoodPoint(date: $0.createdAt, mood: $0.mood ?? 0) }
        }
        let calendar = Calendar.current
        let weeks = Dictionary(grouping: rated) { calendar.dateInterval(of: .weekOfYear, for: $0.createdAt)?.start ?? $0.createdAt }
        return weeks.map { MoodPoint(date: $0.key, mood: PatternFinder.mean($0.value.compactMap(\.mood))) }
            .sorted { $0.date < $1.date }
    }
}

struct ReflectionCard: View {
    let period: Period
    let interval: DateInterval
    let reflection: Reflection?
    let hasEntries: Bool

    @Environment(\.modelContext) private var context
    @Environment(Intelligence.self) private var intelligence

    var body: some View {
        Card(padding: 22) {
            HStack {
                Image(systemName: "text.quote").foregroundStyle(Palette.accent)
                Eyebrow("Reflection")
                Spacer()
                if let reflection {
                    Text(reflection.writtenBy == "claude" ? "by Claude" : "on this phone")
                        .font(.caption).foregroundStyle(Palette.ink3)
                }
            }

            if working {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Reading the \(period == .allTime ? "whole journal" : period.label.lowercased())…")
                        .font(.callout).foregroundStyle(Palette.ink2)
                }
                .padding(.vertical, 8)
            } else if let reflection {
                Text(reflection.headline).font(.headline2).foregroundStyle(Palette.ink)
                Text(reflection.body)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(5)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !reflection.patterns.isEmpty {
                    Eyebrow("Connections").padding(.top, 6)
                    ForEach(reflection.patterns, id: \.self) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle().fill(Palette.accent).frame(width: 5, height: 5)
                            Text(line).font(.callout).foregroundStyle(Palette.ink)
                        }
                    }
                }
                if !reflection.questions.isEmpty {
                    Eyebrow("To sit with").padding(.top, 6)
                    ForEach(reflection.questions, id: \.self) { q in
                        Text(q).font(.system(.body, design: .serif)).italic().foregroundStyle(Palette.ink2)
                    }
                }
                Button("Write it again") { run() }
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)
            } else if hasEntries {
                Text(intelligence.usesClaude
                     ? "Claude will read everything from this \(period == .allTime ? "journal" : period.label.lowercased()) and write back what it notices."
                     : "A short summary built on this phone. Add a Claude key in Settings for a fuller, written reflection.")
                    .font(.callout).foregroundStyle(Palette.ink2)
                Button("Write this \(period == .allTime ? "reflection" : period.label.lowercased() + "'s reflection")") { run() }
                    .buttonStyle(PillButtonStyle())
            } else {
                Text("Nothing written in this \(period.label.lowercased()) yet.")
                    .font(.callout).foregroundStyle(Palette.ink3)
            }
        }
    }

    private var working: Bool {
        intelligence.working.contains(intelligence.reflectionKey(period, interval))
    }

    private func run() {
        Task { await intelligence.reflect(on: period, interval: interval, in: context) }
    }
}

struct AskCard: View {
    @Environment(\.modelContext) private var context
    @Environment(Intelligence.self) private var intelligence
    @State private var question = ""
    @State private var answer: String?

    var body: some View {
        Card {
            HStack {
                Image(systemName: "questionmark.bubble").foregroundStyle(Palette.accent)
                Eyebrow("Ask your journal")
            }
            if intelligence.usesClaude {
                HStack {
                    TextField("When did I last feel really rested?", text: $question, axis: .vertical)
                        .font(.system(.body, design: .serif))
                        .onSubmit(send)
                    if intelligence.working.contains("ask") {
                        ProgressView()
                    } else {
                        Button(action: send) { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                            .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                if let answer {
                    Text(answer)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            } else {
                Text("With a Claude key you can ask things like “What was I worried about in spring?” or “Who do I mention when I'm happiest?”")
                    .font(.subheadline).foregroundStyle(Palette.ink3)
            }
        }
    }

    private func send() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        Task { answer = await intelligence.ask(q, in: context) ?? intelligence.lastError }
    }
}

/// Connections and correlations across the whole journal, each one rated helpful or
/// not, and under them a summary of what they seem to add up to.
struct ConnectionsSection: View {
    @Environment(\.modelContext) private var context
    @Environment(Intelligence.self) private var intelligence
    @Query(filter: #Predicate<Insight> { !$0.dismissed }, sort: \Insight.createdAt, order: .reverse)
    private var insights: [Insight]
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @AppStorage(Prefs.connectionsSummary) private var summary = ""
    @AppStorage(Prefs.connectionsWrittenAt) private var writtenAt = 0.0
    @AppStorage(Prefs.connectionsWrittenBy) private var writtenBy = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow("Connections & correlations")
                Spacer()
                if working {
                    ProgressView().controlSize(.small)
                } else {
                    Button { run() } label: {
                        Label("Look again", systemImage: "arrow.clockwise").font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(Palette.accent)
                }
            }

            if connections.isEmpty && !working {
                Text("Once there are a few weeks of entries, the people, places and habits that go together — and how you feel around them — show up here.")
                    .font(.subheadline).foregroundStyle(Palette.ink3)
            }
            ForEach(connections.prefix(5)) { InsightCard(insight: $0) }
            if connections.count > 5 {
                NavigationLink { InsightListView() } label: {
                    Text("All \(connections.count) connections").font(.footnote.weight(.semibold))
                }
                .foregroundStyle(Palette.accent)
            }

            summaryCard
        }
        .task(id: entries.first?.analysedAt) {
            // Written again once there's something new, at most every few hours.
            let latest = entries.first?.createdAt.timeIntervalSince1970 ?? 0
            let stale = summary.isEmpty || (latest > writtenAt && Date.now.timeIntervalSince1970 - writtenAt > 6 * 3600)
            if stale && !entries.isEmpty { run() }
        }
    }

    private var summaryCard: some View {
        Card {
            HStack {
                Image(systemName: "text.quote").foregroundStyle(Palette.accent)
                Eyebrow("What it adds up to")
                Spacer()
                if writtenAt > 0 {
                    Text(writtenBy == "claude" ? "by Claude" : "on this phone")
                        .font(.caption).foregroundStyle(Palette.ink3)
                }
            }
            if working && summary.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Looking across your journal…").font(.callout).foregroundStyle(Palette.ink2)
                }
            } else if summary.isEmpty {
                Button("Find connections") { run() }.buttonStyle(PillButtonStyle())
            } else {
                Text(summary)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(5)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if writtenAt > 0 {
                    Text("Updated \(Date(timeIntervalSince1970: writtenAt).stamp("EEEdMMMjmm"))")
                        .font(.caption).foregroundStyle(Palette.ink3)
                }
            }
        }
    }

    /// Links across entries: Claude's, then the patterns counted on the phone.
    /// Ones you marked helpful and pinned ones come first.
    private var connections: [Insight] {
        let links = insights.filter { $0.source == .pattern || $0.signature?.hasPrefix("link:") == true }
        func rank(_ i: Insight) -> Int {
            (i.pinned ? 4 : 0) + (i.feedback == 1 ? 2 : 0) + (i.source == .claude ? 1 : 0)
        }
        return links.enumerated()
            .sorted { rank($0.element) != rank($1.element) ? rank($0.element) > rank($1.element) : $0.offset < $1.offset }
            .map(\.element)
    }

    private var working: Bool { intelligence.working.contains("connections") }

    private func run() {
        Task { await intelligence.findConnections(in: context) }
    }
}
