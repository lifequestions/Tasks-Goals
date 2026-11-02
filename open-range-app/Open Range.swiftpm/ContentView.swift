import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var bike: BikeManager
    @StateObject private var speed = SpeedMonitor()
    @StateObject private var history = History()

    @State private var boost: Boost = .fifteen
    @State private var keepAfterLock = false
    @State private var confirmUnleash = false
    @State private var confirmKeep = false
    @AppStorage("lastApplied") private var lastApplied = ""
    /// What the bike was last set to by this app: "", "legal", "unleashed", "unleashedKept" or "refused".
    @AppStorage("bikeMode") private var bikeMode = ""
    @AppStorage("bikeBoost") private var bikeBoost = 0
    @AppStorage("bikeModeSince") private var bikeModeSince = 0.0

    var body: some View {
        NavigationStack {
            Form {
                modeSection
                speedSection
                bikeSection
                if bike.isConnected {
                    unleashSection
                    restoreSection
                }
                historySection
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
        .onAppear {
            speed.start()
            migrateLastApplied()
        }
        .onDisappear { speed.stop() }
        .onChange(of: speed.kmh) { _, kmh in
            if let kmh { history.recordSpeed(kmh) }
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

    /// A glanceable on/off line at the top, so the rider can see the setting while riding.
    private var modeSection: some View {
        Section {
            switch bikeMode {
            case "unleashed", "unleashedKept":
                modeRow(icon: "bolt.fill", color: .orange, title: "Unleashed",
                        detail: (bikeBoost == 0 ? "No 25 km/h cut-off" : "No 25 km/h cut-off · \(bikeBoost)% extra speed") +
                            (bikeMode == "unleashedKept" ? " · stays on after locking" : " · until the bike is locked"))
            case "legal":
                modeRow(icon: "checkmark.shield.fill", color: .green, title: "Road-legal",
                        detail: "25 km/h limit, factory settings")
            case "refused":
                modeRow(icon: "exclamationmark.triangle.fill", color: .red, title: "Not sure",
                        detail: "The bike refused part of the last change. Tap Restore road-legal settings to be safe.")
            default:
                modeRow(icon: "questionmark.circle", color: .secondary, title: "Not set yet",
                        detail: "Not changed with this app yet")
            }
        } header: {
            Text("Bike setting")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if bikeModeSince > 0 {
                    Text("Since \(Date(timeIntervalSince1970: bikeModeSince).formatted(date: .abbreviated, time: .shortened)).")
                }
                if bikeMode == "unleashed" {
                    Text("If you've locked the bike since then, it's back to road-legal.")
                }
                if let latest = history.entries.first {
                    Text(confirmation(of: latest) + ".")
                }
                Text("This is the last change made with this app. Changes made elsewhere don't show here.")
            }
        }
    }

    private func modeRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2.bold()).foregroundStyle(color == .secondary ? Color.primary : color)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

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
        let mode = keepAfterLock ? "unleashedKept" : "unleashed"
        let level = boost.rawValue
        bike.send(commands) { result in record(result, mode: mode, boost: level) }
    }

    private func restore() {
        let commands = [BikeCommands.speedLimit(on: true), BikeCommands.fieldWeakening(percent: 0)] + BikeCommands.saveToBike
        bike.send(commands) { result in record(result, mode: "legal", boost: 0) }
        keepAfterLock = false
    }

    private func record(_ result: BikeManager.SendResult, mode: String, boost level: Int) {
        let finalMode = result.ok ? mode : "refused"
        setMode(finalMode, boost: level)
        bikeModeSince = Date().timeIntervalSince1970
        history.add(mode: finalMode, boost: level, sent: result.sent, accepted: result.accepted)
    }

    private func setMode(_ mode: String, boost level: Int) {
        bikeMode = mode
        bikeBoost = level
    }

    /// Earlier versions only saved a text summary. Turn it into the on/off status once.
    private func migrateLastApplied() {
        guard bikeMode.isEmpty, !lastApplied.isEmpty else { return }
        if lastApplied.hasPrefix("Unleashed") {
            let level = lastApplied.range(of: "\\d+(?=%)", options: .regularExpression)
                .flatMap { Int(lastApplied[$0]) } ?? 0
            setMode(lastApplied.contains("kept after locking") ? "unleashedKept" : "unleashed", boost: level)
        } else if lastApplied.hasPrefix("Road-legal") {
            setMode("legal", boost: 0)
        }
        lastApplied = ""
    }

    // MARK: History

    private var historySection: some View {
        Section {
            if history.entries.isEmpty {
                Text("Changes you make will be listed here.").foregroundStyle(.secondary)
            }
            ForEach(history.entries) { entry in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(title(of: entry)).font(.headline).foregroundStyle(color(of: entry))
                        Spacer()
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(confirmation(of: entry)).font(.subheadline)
                    Text(duration(of: entry)).font(.subheadline).foregroundStyle(.secondary)
                    if entry.topKmh > 0 {
                        Text(String(format: "Top GPS speed %.1f km/h (includes pedalling)", entry.topKmh))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            if !history.entries.isEmpty {
                Button("Clear history", role: .destructive) { history.clear() }
            }
        } header: {
            Text("History")
        } footer: {
            Text("\"Bike confirmed\" means the bike itself answered that it accepted the change. Top speed is only measured while this app is open on screen.")
        }
    }

    private func title(of entry: ModeChange) -> String {
        switch entry.mode {
        case "unleashed", "unleashedKept":
            return entry.boost == 0 ? "Unleashed" : "Unleashed · \(entry.boost)%"
        case "legal": return "Road-legal"
        default: return "Refused"
        }
    }

    private func color(of entry: ModeChange) -> Color {
        switch entry.mode {
        case "unleashed", "unleashedKept": return .orange
        case "legal": return .green
        default: return .red
        }
    }

    private func confirmation(of entry: ModeChange) -> String {
        if entry.mode == "refused" {
            return "Bike refused it (\(entry.accepted) of \(entry.sent) confirmed)"
        }
        if entry.accepted == 0 {
            return "Sent, but the bike didn't confirm it"
        }
        return entry.accepted >= entry.sent
            ? "✓ Bike confirmed all \(entry.sent) commands"
            : "Bike confirmed \(entry.accepted) of \(entry.sent) commands"
    }

    private func duration(of entry: ModeChange) -> String {
        let end = history.end(of: entry)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        let length = formatter.string(from: entry.date, to: end ?? Date()) ?? ""
        let lockNote = entry.mode == "unleashed" ? ", or until the bike was locked" : ""
        if end == nil {
            return entry.mode == "refused" ? "Latest change" : "Current setting · \(length) so far\(lockNote)"
        }
        return "Lasted \(length)\(lockNote)"
    }
}
