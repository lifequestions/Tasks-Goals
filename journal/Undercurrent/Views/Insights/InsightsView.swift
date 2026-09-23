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
    @State private var composing: ComposeMode?

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
                    insightSection(title: "Noticed for you", items: insights.filter { $0.source != .mine })
                    yourInsights
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .screenBackground()
            .navigationTitle("Insights")
            .journalDestinations()
            .fullScreenCover(item: $composing) { ComposeView(mode: $0) }
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
                    .font(.caption).foregroundStyle(Palette.ink3)
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
                Text("mostly \(Feeling.word(stats.averageMood))").font(.caption).foregroundStyle(Palette.ink2)
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
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.ink3)
                            .frame(width: 18)
                        Text(presence.entity.name).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(presence.count)").font(.subheadline.monospacedDigit()).foregroundStyle(Palette.ink3)
                        FeelingDot(value: presence.feeling)
                    }
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func insightSection(title: String, items: [Insight]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(title)
                ForEach(items.sorted { $0.pinned && !$1.pinned }.prefix(8)) { InsightCard(insight: $0) }
            }
        }
    }

    private var yourInsights: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow("Your insights")
                Spacer()
                Button { composing = .insight } label: { Label("Add", systemImage: "plus").font(.caption.weight(.semibold)) }
            }
            let mine = insights.filter { $0.source == .mine }
            if mine.isEmpty {
                Text("When something clicks — “I always feel flat after a night out” — note it here. The reflections will check it against what you write.")
                    .font(.footnote).foregroundStyle(Palette.ink3)
            }
            ForEach(mine) { InsightCard(insight: $0) }
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
                        .font(.caption2).foregroundStyle(Palette.ink3)
                }
            }

            if working {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Reading the \(period == .allTime ? "whole journal" : period.label.lowercased())…")
                        .font(.subheadline).foregroundStyle(Palette.ink2)
                }
                .padding(.vertical, 8)
            } else if let reflection {
                Text(reflection.headline).font(.headline2).foregroundStyle(Palette.ink)
                Text(reflection.body)
                    .font(.system(size: 16, design: .serif))
                    .lineSpacing(5)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !reflection.patterns.isEmpty {
                    Eyebrow("Connections").padding(.top, 6)
                    ForEach(reflection.patterns, id: \.self) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle().fill(Palette.accent).frame(width: 5, height: 5)
                            Text(line).font(.subheadline).foregroundStyle(Palette.ink)
                        }
                    }
                }
                if !reflection.questions.isEmpty {
                    Eyebrow("To sit with").padding(.top, 6)
                    ForEach(reflection.questions, id: \.self) { q in
                        Text(q).font(.system(size: 15, design: .serif)).italic().foregroundStyle(Palette.ink2)
                    }
                }
                Button("Write it again") { run() }
                    .font(.footnote.weight(.semibold))
                    .padding(.top, 4)
            } else if hasEntries {
                Text(intelligence.usesClaude
                     ? "Claude will read everything from this \(period == .allTime ? "journal" : period.label.lowercased()) and write back what it notices."
                     : "A short summary built on this phone. Add a Claude key in Settings for a fuller, written reflection.")
                    .font(.subheadline).foregroundStyle(Palette.ink2)
                Button("Write this \(period == .allTime ? "reflection" : period.label.lowercased() + "'s reflection")") { run() }
                    .buttonStyle(PillButtonStyle())
            } else {
                Text("Nothing written in this \(period.label.lowercased()) yet.")
                    .font(.subheadline).foregroundStyle(Palette.ink3)
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
                        .font(.system(size: 16, design: .serif))
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
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            } else {
                Text("With a Claude key you can ask things like “What was I worried about in spring?” or “Who do I mention when I'm happiest?”")
                    .font(.footnote).foregroundStyle(Palette.ink3)
            }
        }
    }

    private func send() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        Task { answer = await intelligence.ask(q, in: context) ?? intelligence.lastError }
    }
}
