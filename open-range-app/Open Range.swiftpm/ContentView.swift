import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var bike: BikeManager
    @StateObject private var speed = SpeedMonitor()

    @State private var boost: Boost = .fifteen
    @State private var keepAfterLock = false
    @State private var confirmUnleash = false
    @State private var confirmKeep = false
    @AppStorage("lastApplied") private var lastApplied = ""

    var body: some View {
        NavigationStack {
            Form {
                speedSection
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
        .onAppear { speed.start() }
        .onDisappear { speed.stop() }
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

    private var speedSection: some View {
        Section {
            if speed.denied {
                Label("Allow location in Settings → Open Range to see your speed.", systemImage: "location.slash")
            } else {
                VStack(spacing: 4) {
                    Text(speed.kmh.map { String(format: "%.0f", $0) } ?? "–")
                        .font(.system(size: 88, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle((speed.kmh ?? 0) > 25 ? Color.orange : Color.primary)
                    Text("km/h · GPS").font(.headline).foregroundStyle(.secondary)
                    if (speed.kmh ?? 0) > 25 {
                        Text("Above the 25 km/h road limit")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                HStack {
                    Text("Top speed")
                    Spacer()
                    Text(String(format: "%.1f km/h", speed.topKmh)).monospacedDigit()
                    Button("Reset") { speed.resetTop() }
                        .buttonStyle(.borderless)
                        .padding(.leading, 8)
                }
            }
        } header: {
            Text("Speed")
        } footer: {
            Text("Measured by your phone's GPS, so you can compare it with the speed in the Cowboy app. GPS lags about a second and can be off by 1–2 km/h.")
        }
    }

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
