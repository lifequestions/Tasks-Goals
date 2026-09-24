import SwiftUI
import SwiftData
import Charts

/// Everything about one person, place, theme or activity: how often, how it
/// feels, what comes with it, and every moment it appears.
struct EntityDetailView: View {
    let entity: Entity
    /// Start the closer look as soon as the page opens.
    var startReading = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Intelligence.self) private var intelligence
    @Query(sort: \Entry.createdAt) private var allEntries: [Entry]
    @Query(sort: \Entity.name) private var allEntities: [Entity]
    @State private var reading: String?
    @State private var renaming = false
    @State private var newName = ""
    @State private var askingForKey = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statsRow
                if moments.count >= 2 { feelingChart }
                moodEffect
                if !alongside.isEmpty { alongsideSection }
                readingCard
                momentsSection
            }
            .padding(20)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { menu }
        .alert("Rename", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { Store.rename(entity, to: newName, in: context) }
        }
        .onAppear {
            reading = latestReading
            if startReading && reading == nil { closerLook() }
        }
        .sheet(isPresented: $askingForKey) {
            ClaudeKeySheet { closerLook() }
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(entity.kind.rawValue.capitalized, systemImage: entity.kind.symbol)
                .font(.system(.footnote, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(Palette.ink3)
            Text(entity.name).font(.display).foregroundStyle(Palette.ink)
        }
    }

    private var statsRow: some View {
        Card {
            HStack {
                Stat(label: "Mentions", value: "\(entity.mentions.count)")
                Stat(label: "Usually", value: Feeling.word(entity.averageFeeling))
                Stat(label: "Since", value: entity.firstMentioned?.stamp("MMMyy") ?? "—")
            }
        }
    }

    private var feelingChart: some View {
        Card {
            Eyebrow("How it has felt over time")
            Chart(moments, id: \.persistentModelID) { mention in
                let date = mention.entry?.createdAt ?? .now
                LineMark(x: .value("Date", date), y: .value("Feeling", mention.sentiment))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Palette.ink3.opacity(0.5))
                PointMark(x: .value("Date", date), y: .value("Feeling", mention.sentiment))
                    .foregroundStyle(Palette.feeling(mention.sentiment))
                    .symbolSize(60)
            }
            .chartYScale(domain: -1.0...1.0)
            .chartYAxis {
                AxisMarks(values: [-1.0, 0, 1]) { value in
                    AxisGridLine().foregroundStyle(Palette.line)
                    AxisValueLabel {
                        Text(value.as(Double.self).map { $0 < 0 ? "heavy" : $0 > 0 ? "light" : "" } ?? "")
                    }
                }
            }
            .frame(height: 170)
        }
    }

    /// The Jordan test: do entries with this in them feel different from the rest?
    private var moodEffect: some View {
        let ids = Set(entity.mentions.compactMap { $0.entry?.persistentModelID })
        let with = allEntries.filter { ids.contains($0.persistentModelID) }.compactMap(\.mood)
        let without = allEntries.filter { !ids.contains($0.persistentModelID) }.compactMap(\.mood)
        let a = PatternFinder.mean(with), b = PatternFinder.mean(without)

        return Card {
            Eyebrow("Entries with \(entity.name)")
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Feeling.word(with.isEmpty ? nil : a).capitalized).font(.bigNumber)
                        .foregroundStyle(Palette.feeling(a))
                    Text("when they come up").font(.footnote).foregroundStyle(Palette.ink3)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(Feeling.word(without.isEmpty ? nil : b).capitalized).font(.bigNumber)
                        .foregroundStyle(Palette.feeling(b))
                    Text("the rest of the time").font(.footnote).foregroundStyle(Palette.ink3)
                }
            }
            if with.count >= 3, without.count >= 3, abs(a - b) >= 0.2 {
                Text(a < b ? "Your entries tend to be heavier when \(entity.name) is in them."
                           : "Your entries tend to be lighter when \(entity.name) is in them.")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Palette.ink)
            } else if with.count < 3 {
                Text("A few more entries and a pattern may show.").font(.subheadline).foregroundStyle(Palette.ink3)
            }
        }
    }

    private var alongsideSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Often alongside")
            FlowLayout {
                ForEach(alongside.prefix(12)) { item in
                    NavigationLink(value: item.entity) {
                        HStack(spacing: 4) {
                            EntityChip(name: item.entity.name, kind: item.entity.kind, feeling: item.entity.averageFeeling)
                            Text("\(item.count)").font(.caption).foregroundStyle(Palette.ink3)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var readingCard: some View {
        Card {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(Palette.accent)
                Eyebrow("A closer reading")
            }
            if let reading {
                Text(reading)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if intelligence.working.contains("entity:\(entity.key)") {
                HStack { ProgressView(); Text("Reading every mention…").font(.subheadline).foregroundStyle(Palette.ink3) }
            } else {
                if reading == nil {
                    Text("Claude reads every moment \(entity.name) comes up and tells you what connects them.")
                        .font(.subheadline).foregroundStyle(Palette.ink2)
                }
                Button { closerLook() } label: {
                    Label(reading == nil ? "Take a closer look" : "Look again", systemImage: "sparkles")
                }
                .buttonStyle(PillButtonStyle(prominent: reading == nil))
            }
            if let error = readingError {
                Text(error).font(.subheadline).foregroundStyle(Palette.feeling(-0.8))
            }
        }
    }

    private var momentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Every moment")
            ForEach(moments.reversed(), id: \.persistentModelID) { mention in
                if let entry = mention.entry {
                    HStack(alignment: .top, spacing: 4) {
                        NavigationLink(value: entry) {
                            HStack(alignment: .top, spacing: 12) {
                                FeelingDot(value: mention.sentiment).padding(.top, 6)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.createdAt.stamp("EEEdMMMyyyy")).font(.footnote).foregroundStyle(Palette.ink3)
                                    Text("“\(mention.quote)”")
                                        .font(.system(.body, design: .serif))
                                        .foregroundStyle(Palette.ink)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        Menu {
                            Button("Not about \(entity.name)", systemImage: "minus.circle", role: .destructive) {
                                withAnimation { detach(mention) }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(Palette.ink3)
                                .frame(width: 32, height: 32)
                        }
                    }
                    Divider().overlay(Palette.line)
                }
            }
        }
    }

    @State private var readingError: String?

    private func closerLook() {
        guard intelligence.usesClaude else {
            askingForKey = true
            return
        }
        readingError = nil
        Task {
            if let text = await intelligence.readEntity(entity, in: context) {
                withAnimation { reading = text }
            } else {
                readingError = intelligence.lastError
            }
        }
    }

    private func detach(_ mention: Mention) {
        Store.detach(mention, in: context)
        intelligence.refreshPatterns(in: context)
    }

    private var menu: some View {
        Menu {
            Button("Rename", systemImage: "pencil") {
                newName = entity.name
                renaming = true
            }
            Menu("Merge into…") {
                ForEach(allEntities.filter { $0.kind == entity.kind && $0.key != entity.key }) { other in
                    Button(other.name) {
                        let source = entity
                        dismiss()
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            Store.merge(source, into: other, in: context)
                            intelligence.refreshPatterns(in: context)
                        }
                    }
                }
            }
            Button(entity.hidden ? "Show on the map" : "Hide from the map",
                   systemImage: entity.hidden ? "eye" : "eye.slash") {
                entity.hidden.toggle()
                try? context.save()
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: Derived

    private var moments: [Mention] {
        entity.mentions
            .filter { $0.entry != nil }
            .sorted { ($0.entry?.createdAt ?? .distantPast) < ($1.entry?.createdAt ?? .distantPast) }
    }

    struct Companion: Identifiable {
        let entity: Entity
        var count: Int
        var id: String { entity.key }
    }

    private var alongside: [Companion] {
        var counts: [String: Companion] = [:]
        for mention in entity.mentions {
            for other in mention.entry?.mentions ?? [] {
                guard let e = other.entity, e.key != entity.key, !e.hidden else { continue }
                counts[e.key, default: Companion(entity: e, count: 0)].count += 1
            }
        }
        return counts.values.sorted { $0.count > $1.count }
    }

    private var latestReading: String? {
        let key = entity.key
        let source = InsightSource.claude.rawValue
        var d = FetchDescriptor<Insight>(predicate: #Predicate { $0.sourceRaw == source },
                                         sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        d.fetchLimit = 50
        return (try? context.fetch(d))?.first { $0.entityKeys == [key] }?.text
    }
}
