import SwiftUI
import SwiftData

enum ComposeMode: String, Identifiable {
    case write, speak, insight
    var id: String { rawValue }
}

struct TodayView: View {
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @Query(filter: #Predicate<Insight> { !$0.dismissed }, sort: \Insight.createdAt, order: .reverse)
    private var insights: [Insight]
    @State private var composing: ComposeMode?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    questionCard
                    if !todays.isEmpty { todaySection }
                    rhythmCard
                    if !noticed.isEmpty { noticedSection }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .screenBackground()
            .journalDestinations()
            .fullScreenCover(item: $composing) { mode in
                ComposeView(mode: mode)
            }
        }
    }

    // MARK: Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(Date.now.stamp("EEEEdMMMM"))
            Text(greeting).font(.display).foregroundStyle(Palette.ink)
        }
        .padding(.top, 24)
    }

    private var questionCard: some View {
        Card(padding: 22) {
            Eyebrow("Today's question")
            Text(DailyQuestion.today)
                .font(.headline2)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button { composing = .write } label: { Label("Write", systemImage: "pencil") }
                    .buttonStyle(PillButtonStyle())
                Button { composing = .speak } label: { Label("Speak", systemImage: "mic.fill") }
                    .buttonStyle(PillButtonStyle(prominent: false))
                Spacer()
                Button { composing = .insight } label: {
                    Image(systemName: "lightbulb").font(.system(size: 17, weight: .medium))
                }
                .buttonStyle(PillButtonStyle(prominent: false))
                .accessibilityLabel("Note an insight")
            }
            .padding(.top, 6)
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Today")
            ForEach(todays) { entry in
                NavigationLink(value: entry) {
                    Card {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.createdAt.stamp("jmm")).font(.caption).foregroundStyle(Palette.ink3)
                                Text(entry.text).font(.reading).foregroundStyle(Palette.ink).lineLimit(3)
                            }
                            Spacer(minLength: 0)
                            FeelingDot(value: entry.mood)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Two weeks of dots, one per day, coloured by how the day read — the Oura ring, flattened.
    private var rhythmCard: some View {
        let calendar = Calendar.current
        let days = (0..<14).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: .now)) }
        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.createdAt) }
        return Card {
            HStack {
                Eyebrow("Last two weeks")
                Spacer()
                Text(streakText).font(.caption).foregroundStyle(Palette.ink2)
            }
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    let moods = (byDay[day] ?? []).compactMap(\.mood)
                    VStack(spacing: 6) {
                        Circle()
                            .fill(moods.isEmpty ? Color.clear : Palette.feeling(PatternFinder.mean(moods)))
                            .overlay(Circle().strokeBorder(moods.isEmpty ? Palette.line : .clear, lineWidth: 1))
                            .frame(width: 14, height: 14)
                        Text(day.stamp("EEEEE"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(calendar.isDateInToday(day) ? Palette.ink : Palette.ink3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var noticedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Noticed lately")
            ForEach(noticed.prefix(3)) { insight in
                InsightCard(insight: insight)
            }
        }
    }

    // MARK: Derived

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning."
        case 12..<17: "Good afternoon."
        case 17..<22: "Good evening."
        default: "Still up?"
        }
    }

    private var todays: [Entry] {
        entries.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    private var noticed: [Insight] {
        insights.filter { $0.source != .mine }
    }

    private var streakText: String {
        let calendar = Calendar.current
        let days = Set(entries.map { calendar.startOfDay(for: $0.createdAt) })
        var day = calendar.startOfDay(for: .now)
        if !days.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        var streak = 0
        while days.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak == 0 ? "\(entries.count) entries" : "\(streak)-day streak"
    }
}

struct InsightCard: View {
    @Environment(\.modelContext) private var context
    let insight: Insight

    var body: some View {
        Card {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.accent)
                Eyebrow(insight.source.label)
                Spacer()
                Menu {
                    Button(insight.pinned ? "Unpin" : "Pin", systemImage: insight.pinned ? "pin.slash" : "pin") {
                        insight.pinned.toggle()
                        try? context.save()
                    }
                    Button("Dismiss", systemImage: "xmark", role: .destructive) {
                        insight.dismissed = true
                        try? context.save()
                    }
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(Palette.ink3).frame(width: 28, height: 20)
                }
            }
            Text(insight.text)
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var symbol: String {
        switch insight.source {
        case .mine: "lightbulb.fill"
        case .pattern: "waveform.path.ecg"
        case .claude: "sparkles"
        }
    }
}
