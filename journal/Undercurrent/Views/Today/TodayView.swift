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
    @State private var composingQuestion: String?
    @State private var skip = 0
    @State private var pickedQuestion: String?
    @State private var composingTags: [Tag] = []
    @State private var choosingSubject = false
    @State private var subject: Tag?
    /// People and subjects added on the question card, carried into what you write next.
    @State private var cardTags: [Tag] = []
    @State private var taggingCard = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    if hasSample { sampleBanner }
                    questionCard
                    if let next = nextQuestion { followUpCard(next) }
                    if !todays.isEmpty { todaySection }
                    rhythmCard
                    if !noticed.isEmpty { noticedSection }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .screenBackground()
            .journalDestinations()
            .fullScreenCover(item: $composing, onDismiss: {
                // Saved something just now: the card starts fresh. Cancelled: keep the tags.
                if let latest = entries.first, latest.createdAt > .now.addingTimeInterval(-120) { cardTags = [] }
            }) { mode in
                ComposeView(mode: mode, question: composingQuestion, presetTags: composingTags)
            }
            .sheet(isPresented: $choosingSubject, onDismiss: {
                // Open the writing screen once the picker has gone.
                guard let tag = subject else { return }
                subject = nil
                compose(.write, answering: Questions.about(tag.name, kind: tag.kind), tags: [tag])
            }) {
                TagPicker { subject = $0 }
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
        let opener = pickedQuestion.map { Questions.Question(text: $0) } ?? Questions.opener()
        return Card(padding: 22) {
            HStack {
                Spacer()
                Menu {
                    Section("Pick a question") {
                        ForEach(Questions.openers, id: \.self) { q in
                            Button(q) { withAnimation(.snappy) { pickedQuestion = q } }
                        }
                    }
                    Button("About someone or something…", systemImage: "person.2") { choosingSubject = true }
                } label: {
                    Label("Another question", systemImage: "chevron.down.circle")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(Palette.accent)
            }
            Text(opener.text)
                .font(.headline2)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let hint = opener.hint {
                Text(hint).font(.callout).foregroundStyle(Palette.ink2)
            }
            cardTagRow
            HStack(spacing: 10) {
                Button { compose(.write, answering: opener.text) } label: { Label("Write", systemImage: "pencil") }
                    .buttonStyle(PillButtonStyle())
                Button { compose(.speak, answering: opener.text) } label: { Label("Speak", systemImage: "mic.fill") }
                    .buttonStyle(PillButtonStyle(prominent: false))
                Spacer()
                Button { compose(.insight, answering: nil) } label: {
                    Image(systemName: "lightbulb").font(.system(.body, weight: .medium))
                }
                .buttonStyle(PillButtonStyle(prominent: false))
                .accessibilityLabel("Note an insight")
            }
            .padding(.top, 6)
        }
    }

    /// Who or what this is about, chosen before you start; + Tag adds more.
    private var cardTagRow: some View {
        FlowLayout(spacing: 8) {
            ForEach(cardTags) { tag in
                RemovableTag(tag: tag) { withAnimation(.snappy) { cardTags.removeAll { $0 == tag } } }
            }
            Button { taggingCard = true } label: {
                Label(cardTags.isEmpty ? "Add a person or subject" : "Tag", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Palette.raised))
            }
            .foregroundStyle(Palette.accent)
        }
        .sheet(isPresented: $taggingCard) {
            TagPicker { tag in
                if !cardTags.contains(where: { $0.key == tag.key }) {
                    withAnimation(.snappy) { cardTags.append(tag) }
                }
            }
        }
    }

    /// A second, smaller question: Claude's follow-up if there is one, otherwise an everyday one.
    private func followUpCard(_ next: (text: String, fromClaude: Bool, label: String)) -> some View {
        Card {
            HStack {
                if next.fromClaude {
                    Image(systemName: "sparkles").font(.system(.footnote, weight: .semibold)).foregroundStyle(Palette.accent)
                }
                Eyebrow(next.label)
                Spacer()
                if !next.fromClaude {
                    Button { withAnimation(.snappy) { skip += 1 } } label: {
                        Label("Another", systemImage: "arrow.triangle.2.circlepath").font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(Palette.accent)
                }
            }
            Text(next.text)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            HStack(spacing: 10) {
                Button { compose(.write, answering: next.text) } label: { Label("Answer", systemImage: "pencil") }
                    .buttonStyle(PillButtonStyle(prominent: false))
                Button { compose(.speak, answering: next.text) } label: { Image(systemName: "mic.fill") }
                    .buttonStyle(PillButtonStyle(prominent: false))
                    .accessibilityLabel("Answer by speaking")
            }
        }
    }

    private var sampleBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "testtube.2").foregroundStyle(Palette.accent)
            Text("Sample entries are showing. Remove them in You → Settings.")
                .font(.subheadline).foregroundStyle(Palette.ink2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.accentSoft))
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Today")
            ForEach(todays) { entry in
                NavigationLink(value: entry) {
                    Card {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.createdAt.stamp("jmm")).font(.footnote).foregroundStyle(Palette.ink3)
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
                Text(streakText).font(.footnote).foregroundStyle(Palette.ink2)
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
                            .font(.system(.caption2, weight: .medium))
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

    private func compose(_ mode: ComposeMode, answering question: String?, tags: [Tag] = []) {
        composingQuestion = question
        composingTags = cardTags + tags.filter { t in !cardTags.contains { $0.key == t.key } }
        composing = mode
    }

    private var hasSample: Bool { entries.contains { $0.isSample == true } }

    /// After you've written today: Claude's follow-up from today, or an everyday one.
    /// Before you've written: yesterday's follow-up from Claude, if there is one.
    private var nextQuestion: (text: String, fromClaude: Bool, label: String)? {
        let calendar = Calendar.current
        let answered = Set(todays.compactMap(\.question))
        if !todays.isEmpty {
            if skip == 0, let claude = todays.compactMap(\.followUp).first, !answered.contains(claude) {
                return (claude, true, "Following on")
            }
            for offset in 0..<8 {
                let text = Questions.followUp(skip: skip + offset)
                if !answered.contains(text) { return (text, false, "Another question") }
            }
            return nil
        }
        if let from = entries.first(where: { calendar.isDateInYesterday($0.createdAt) && $0.followUp != nil })?.followUp {
            return (from, true, "From yesterday")
        }
        return nil
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
                Image(systemName: symbol).font(.system(.footnote, weight: .semibold)).foregroundStyle(Palette.accent)
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
                .font(.system(.body, design: .serif))
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
