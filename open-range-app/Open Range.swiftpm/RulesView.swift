import SwiftUI

/// Shown on first launch. Every rider has to agree before the app opens.
struct RulesView: View {
    let onAccept: () -> Void
    @State private var agreed = false

    private let rules: [(String, String)] = [
        ("signpost.right", "Private land only. Without the speed limit the bike is illegal on public roads and paths in most countries."),
        ("shield.slash", "Cowboy voids the warranty on any bike where an app like this has been used, even once."),
        ("gauge.with.dots.needle.67percent", "The brakes are built for 25 km/h. Stopping distances get much longer above that. Wear a helmet."),
        ("cpu", "Works on bike firmware 4.21 and older. Newer \"Adaptive Power 2.0\" firmware can cut power after a stop. Undo the change if that happens."),
        ("lock", "By default, the change lasts only until the bike is locked. Locking it puts the 25 km/h limit back.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Before you ride")
                    .font(.largeTitle.bold())
                ForEach(rules.indices, id: \.self) { i in
                    let (icon, text) = rules[i]
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(.orange)
                            .frame(width: 28)
                        Text(text)
                    }
                }
                Toggle("I understand and will only ride on private land", isOn: $agreed)
                    .padding(.top)
                Button {
                    onAccept()
                } label: {
                    Text("Continue").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!agreed)
            }
            .padding(24)
        }
    }
}
