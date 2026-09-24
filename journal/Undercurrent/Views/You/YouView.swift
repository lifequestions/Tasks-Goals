import SwiftUI
import SwiftData

struct YouView: View {
    @Query private var entries: [Entry]
    @Query private var entities: [Entity]
    @Query(sort: \TraitResult.takenAt, order: .reverse) private var results: [TraitResult]
    @AppStorage(Prefs.aboutMe) private var aboutMe = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Card {
                        Eyebrow("What your journal holds")
                        HStack {
                            Stat(label: "Entries", value: "\(entries.count)")
                            Stat(label: "Days", value: "\(days)")
                            Stat(label: "Words", value: words)
                        }
                        HStack {
                            Stat(label: "People", value: "\(count(.person))")
                            Stat(label: "Places", value: "\(count(.place))")
                            Stat(label: "Themes", value: "\(count(.theme) + count(.activity))")
                        }
                    }

                    NavigationLink { AboutMeView() } label: {
                        Card {
                            HStack {
                                Eyebrow("About you")
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Palette.ink3)
                            }
                            Text(aboutMe.isEmpty
                                 ? "Tell Undercurrent anything it should always keep in mind — your situation, what you're working on, who the important people are."
                                 : aboutMe)
                                .font(.system(.body, design: .serif))
                                .foregroundStyle(aboutMe.isEmpty ? Palette.ink3 : Palette.ink)
                                .lineLimit(4)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow("Understand yourself")
                        Text("Each questionnaire you take is shared with every reading and reflection, so the more you answer, the better it knows how to read you.")
                            .font(.subheadline).foregroundStyle(Palette.ink3)
                        ForEach(Questionnaire.catalog) { test in
                            questionnaireRow(test)
                        }
                    }

                    NavigationLink { SettingsView() } label: {
                        Label("Settings", systemImage: "gearshape")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.raised))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .screenBackground()
            .navigationTitle("You")
        }
    }

    @ViewBuilder
    private func questionnaireRow(_ test: Questionnaire) -> some View {
        let latest = results.first { $0.testID == test.id }
        let card = Card {
            HStack(alignment: .firstTextBaseline) {
                Text(test.title).font(.system(.title3, design: .serif)).foregroundStyle(Palette.ink)
                Spacer()
                Text(test.isAvailable ? (latest == nil ? "\(test.minutes) min" : "Retake") : "Coming")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(test.isAvailable ? Palette.accent : Palette.ink3)
            }
            if let latest {
                TraitBars(test: test, scores: latest.scores)
            } else {
                Text(test.blurb).font(.subheadline).foregroundStyle(Palette.ink2)
            }
        }
        if test.isAvailable {
            NavigationLink { QuestionnaireView(test: test) } label: { card }.buttonStyle(.plain)
        } else {
            card.opacity(0.7)
        }
    }

    private func count(_ kind: EntityKind) -> Int { entities.filter { $0.kind == kind }.count }

    private var days: Int {
        Set(entries.map { Calendar.current.startOfDay(for: $0.createdAt) }).count
    }

    private var words: String {
        let n = entries.reduce(0) { $0 + $1.wordCount }
        return n >= 10_000 ? "\(n / 1000)k" : "\(n)"
    }
}

struct TraitBars: View {
    let test: Questionnaire
    let scores: [String: Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(test.traits, id: \.id) { trait in
                let v = scores[trait.id] ?? 0.5
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(trait.name).font(.callout.weight(.medium)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(Int(v * 100))").font(.footnote.monospacedDigit()).foregroundStyle(Palette.ink3)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.raised)
                            Capsule().fill(Palette.accent).frame(width: max(6, geo.size.width * v))
                        }
                    }
                    .frame(height: 6)
                    HStack {
                        Text(trait.low)
                        Spacer()
                        Text(trait.high)
                    }
                    .font(.caption)
                    .foregroundStyle(Palette.ink3)
                }
            }
        }
    }
}

struct AboutMeView: View {
    @AppStorage(Prefs.aboutMe) private var aboutMe = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Written once, remembered always. Claude reads this before every entry and reflection.")
                .font(.subheadline)
                .foregroundStyle(Palette.ink3)
                .padding(.horizontal, 20)
            TextEditor(text: $aboutMe)
                .font(.reading)
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .screenBackground()
        .navigationTitle("About you")
        .navigationBarTitleDisplayMode(.inline)
    }
}
