import SwiftUI
import SwiftData

@main
struct UndercurrentApp: App {
    @State private var intelligence = Intelligence()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(intelligence)
                .tint(Palette.accent)
        }
        .modelContainer(for: [Entry.self, Entity.self, Mention.self, Insight.self, Reflection.self, TraitResult.self])
    }
}

struct RootView: View {
    enum Screen: Hashable { case today, journal, connections, insights, you }

    @Environment(\.modelContext) private var context
    @Environment(Intelligence.self) private var intelligence
    @State private var screen: Screen = .today

    var body: some View {
        TabView(selection: $screen) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.horizon") }
                .tag(Screen.today)
            JournalView()
                .tabItem { Label("Journal", systemImage: "book.closed") }
                .tag(Screen.journal)
            ConnectionsView()
                .tabItem { Label("Connections", systemImage: "point.3.connected.trianglepath.dotted") }
                .tag(Screen.connections)
            InsightsView()
                .tabItem { Label("Insights", systemImage: "sparkles") }
                .tag(Screen.insights)
            YouView()
                .tabItem { Label("You", systemImage: "person.crop.circle") }
                .tag(Screen.you)
        }
        .task {
            SampleJournal.tagUntagged(in: context)
            Store.cleanUpLeftovers(in: context)
            await intelligence.catchUp(in: context)
        }
    }
}
