import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @State private var search = ""
    @State private var composing: ComposeMode?

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing written yet", systemImage: "book.closed")
                    } description: {
                        Text("Your entries will gather here, newest first.")
                    } actions: {
                        Button("Write the first one") { composing = .write }.buttonStyle(PillButtonStyle())
                    }
                } else {
                    list
                }
            }
            .screenBackground()
            .navigationTitle("Journal")
            .searchable(text: $search, prompt: "Search your entries")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { composing = .write } label: { Image(systemName: "square.and.pencil") }
                }
            }
            .journalDestinations()
            .fullScreenCover(item: $composing) { ComposeView(mode: $0) }
        }
    }

    private var list: some View {
        List {
            ForEach(months) { group in
                Section {
                    ForEach(group.entries) { entry in
                        NavigationLink(value: entry) { EntryRow(entry: entry) }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Palette.line)
                    }
                    .onDelete { offsets in
                        for i in offsets { context.delete(group.entries[i]) }
                        Store.pruneOrphans(in: context)
                        try? context.save()
                    }
                } header: {
                    Text(group.month.stamp("MMMMyyyy"))
                        .font(.system(size: 20, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var filtered: [Entry] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return entries }
        return entries.filter { entry in
            entry.text.localizedCaseInsensitiveContains(q)
                || entry.entities.contains { $0.name.localizedCaseInsensitiveContains(q) }
        }
    }

    struct MonthGroup: Identifiable {
        let month: Date
        let entries: [Entry]
        var id: Date { month }
    }

    private var months: [MonthGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filtered) {
            calendar.dateInterval(of: .month, for: $0.createdAt)?.start ?? $0.createdAt
        }
        return groups.sorted { $0.key > $1.key }.map { MonthGroup(month: $0.key, entries: $0.value) }
    }
}

struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Text(entry.createdAt.stamp("d")).font(.system(size: 24, weight: .light, design: .serif))
                Text(entry.createdAt.stamp("EEE").uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
            }
            .frame(width: 38)

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                if entry.summary != nil {
                    Text(entry.text)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .lineLimit(2)
                }
                let people = entry.mentions.filter { $0.entity?.kind == .person }.prefix(3)
                if !people.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(people), id: \.persistentModelID) { m in
                            if let e = m.entity { EntityChip(name: e.name, kind: e.kind, feeling: m.sentiment) }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
            FeelingDot(value: entry.mood).padding(.top, 8)
        }
        .padding(.vertical, 6)
    }
}
