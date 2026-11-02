import SwiftUI

@main
struct OpenRangeApp: App {
    @StateObject private var bike = BikeManager()
    @AppStorage("acceptedRules") private var acceptedRules = false

    var body: some Scene {
        WindowGroup {
            if acceptedRules {
                ContentView()
                    .environmentObject(bike)
            } else {
                RulesView { acceptedRules = true }
            }
        }
    }
}
