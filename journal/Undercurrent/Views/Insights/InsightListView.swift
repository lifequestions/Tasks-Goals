import SwiftUI
import SwiftData

/// Every insight in the journal, newest first: what you realised in your own words,
/// the connections Claude saw, and the patterns found on the phone.
struct InsightListView: View {
    @Environment(\.modelContext) private var context
    @Environment(Intelligence.self) private var intelligence
    @Query(sort: \Insight.createdAt, order: .reverse) private var all: [Insight]
    @Query private var entries: [Entry]
    @State private var filter: Filter = .all
    @State private var showDismissed = false

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", yours = "Yours", connections = "Connections", patterns = "Patterns"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if !pinned.isEmpty {
                    section(title: "Pinned", items: pinned)
                }
                ForEach(months, id: \.month) { group in
                    section(title: group.month.stamp("MMMMyyyy"), items: group.items)
                }

                if shown.isEmpty {
                    Text("Insights appear here as you write — the things you realise about yourself, and the connections between entries.")
                        .font(.callout).foregroundStyle(Palette.ink3)
                        .padding(.top, 20)
                }

                if intelligence.usesClaude && !unread.isEmpty { findMore }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .screenBackground()
        .navigationTitle("Insights")
        .toolbar {
            Menu {
                Toggle("Show dismissed", isOn: $showDismissed)
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
    }

    private func section(title: String, items: [Insight]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(title)
            ForEach(items) { InsightCard(insight: $0).opacity($0.dismissed ? 0.5 : 1) }
        }
    }

    /// Asks Claude to read entries that were only read on the phone, for sharper insights.
    private var findMore: some View {
        Card {
            Eyebrow("Earlier entries")
            Text("\(unread.count) \(unread.count == 1 ? "entry was" : "entries were") only read on this phone. Claude can look through \(unread.count == 1 ? "it" : "them") for insights and connections.")
                .font(.callout).foregroundStyle(Palette.ink2)
            if intelligence.working.contains("insights") {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Reading…").font(.callout).foregroundStyle(Palette.ink2)
                }
            } else {
                Button("Find insights") {
                    Task { await intelligence.readAgain(unread, in: context) }
                }
                .buttonStyle(PillButtonStyle())
            }
        }
    }

    // MARK: Derived

    private var shown: [Insight] {
        all.filter { insight in
            guard showDismissed || !insight.dismissed else { return false }
            switch filter {
            case .all: return true
            case .yours: return insight.source == .mine
            case .connections: return insight.source == .claude
            case .patterns: return insight.source == .pattern
            }
        }
    }

    private var pinned: [Insight] { shown.filter(\.pinned) }

    private var months: [(month: Date, items: [Insight])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: shown.filter { !$0.pinned }) {
            calendar.dateInterval(of: .month, for: $0.createdAt)?.start ?? $0.createdAt
        }
        return groups.sorted { $0.key > $1.key }.map { ($0.key, $0.value) }
    }

    private var unread: [Entry] {
        entries.filter { $0.analysedBy != "claude" && $0.isSample != true }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
