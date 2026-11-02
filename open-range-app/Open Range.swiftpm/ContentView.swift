import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var bike: BikeManager

    @State private var boost: Boost = .fifteen
    @State private var keepAfterLock = false
    @State private var confirmUnleash = false
    @State private var confirmKeep = false
    @AppStorage("lastApplied") private var lastApplied = ""

    var body: some View {
        NavigationStack {
            Form {
                bikeSection
                if bike.isConnected {
                    unleashSection
                    restoreSection
                }
                if !lastApplied.isEmpty {
                    Section("Last change") { Text(lastApplied) }
                }
                if !bike.log.isEmpty {
                    Section("Activity") {
                        ForEach(bike.log, id: \.self) { line in
                            Text(line).font(.caption.monospaced())
                        }
                    }
                }
            }
            .navigationTitle("Open Range")
        }
        .confirmationDialog("Remove the speed limit?", isPresented: $confirmUnleash, titleVisibility: .visible) {
            Button("Unleash for private land") { unleash() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(keepAfterLock
                 ? "This stays on the bike until you restore it here."
                 : "Locking the bike will put the limit back.")
        }
    }

    // MARK: Sections

    private var bikeSection: some View {
        Section {
            switch bike.status {
            case .bluetoothOff:
                Label("Turn on Bluetooth to find your bike.", systemImage: "antenna.radiowaves.left.and.right.slash")
            case .ready, .sending:
                HStack {
                    Label(bike.connectedName ?? "Bike", systemImage: "bicycle")
                    Spacer()
                    Button("Disconnect") { bike.disconnect() }
                }
            case .connecting:
                HStack { ProgressView(); Text("Connecting…") }
            case .idle, .scanning:
                Button {
                    bike.scan()
                } label: {
                    HStack {
                        Label(bike.status == .scanning ? "Searching…" : "Find my bike", systemImage: "magnifyingglass")
                        if bike.status == .scanning { Spacer(); ProgressView() }
                    }
                }
                ForEach(bike.found) { item in
                    Button { bike.connect(item) } label: {
                        HStack {
                            Text(item.name).fontWeight(item.looksLikeCowboy ? .semibold : .regular)
                            Spacer()
                            Text("\(item.rssi) dBm").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Bike")
        } footer: {
            if !bike.isConnected {
                Text("First unlock the bike in the Cowboy app, then close the Cowboy app completely (swipe it away). The bike accepts only one phone connection at a time.")
            }
        }
    }

    private var unleashSection: some View {
        Section {
            Picker("Extra speed", selection: $boost) {
                ForEach(Boost.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Keep after locking", isOn: $keepAfterLock)
                .onChange(of: keepAfterLock) { _, on in if on { confirmKeep = true } }
                .alert("Keep it after locking?", isPresented: $confirmKeep) {
                    Button("Keep it") {}
                    Button("Cancel", role: .cancel) { keepAfterLock = false }
                } message: {
                    Text("The bike will stay unleashed even after it's locked, so it will still be illegal if someone takes it on a public road. Only turn this on if the bike never leaves private land.")
                }
            Button {
                confirmUnleash = true
            } label: {
                Label("Unleash", systemImage: "bolt.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(bike.status == .sending)
        } header: {
            Text("Private land mode")
        } footer: {
            Text("\"Extra speed\" lets the motor help above 30 km/h. \"Off\" removes only the 25 km/h cut-off.")
        }
    }

    private var restoreSection: some View {
        Section {
            Button {
                restore()
            } label: {
                Label("Restore road-legal settings", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .disabled(bike.status == .sending)
        } footer: {
            Text("Puts the 25 km/h limit and factory motor settings back, and saves them to the bike.")
        }
    }

    // MARK: Actions

    private func unleash() {
        var commands = [BikeCommands.speedLimit(on: false), BikeCommands.fieldWeakening(percent: boost.rawValue)]
        if keepAfterLock { commands += BikeCommands.saveToBike }
        let summary = "Unleashed, extra speed \(boost.rawValue)%, " +
            (keepAfterLock ? "kept after locking" : "until the bike is locked")
        bike.send(commands) { lastApplied = summary }
    }

    private func restore() {
        let commands = [BikeCommands.speedLimit(on: true), BikeCommands.fieldWeakening(percent: 0)] + BikeCommands.saveToBike
        bike.send(commands) { lastApplied = "Road-legal: 25 km/h limit, factory settings" }
        keepAfterLock = false
    }
}
