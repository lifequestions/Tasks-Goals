import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(Intelligence.self) private var intelligence

    @AppStorage(Prefs.model) private var model = ClaudeClient.defaultModel
    @AppStorage(Prefs.provider) private var provider = "anthropic"
    @AppStorage(Prefs.openRouterModel) private var openRouterModel = OpenRouterClient.defaultModel
    @AppStorage(Prefs.onDeviceOnly) private var onDeviceOnly = false
    @AppStorage(Prefs.reminderOn) private var reminderOn = false
    @AppStorage(Prefs.reminderTime) private var reminderTime: Double = 21 * 3600

    @State private var apiKey = ""
    @State private var openRouterModels: [String] = []
    @State private var check: String?
    @State private var checking = false
    @State private var exportURL: URL?
    @State private var confirmErase = false
    @Query(filter: #Predicate<Entry> { $0.isSample == true }) private var sampleEntries: [Entry]

    private var hasSample: Bool { !sampleEntries.isEmpty }

    var body: some View {
        Form {
            Section {
                Picker("Through", selection: $provider) {
                    Text("Anthropic").tag("anthropic")
                    Text("OpenRouter").tag("openrouter")
                }
                .pickerStyle(.segmented)
                .onChange(of: provider) { _, _ in
                    apiKey = Keychain.get(keyAccount) ?? ""
                    check = nil
                }
                SecureField(provider == "openrouter" ? "sk-or-…" : "sk-ant-…", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(saveKey)
                    .onChange(of: apiKey) { _, _ in check = nil }
                if provider == "openrouter" {
                    if openRouterModels.isEmpty {
                        TextField("Model", text: $openRouterModel)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.body.monospaced())
                    } else {
                        Picker("Model", selection: $openRouterModel) {
                            ForEach(openRouterModels, id: \.self) { id in
                                Text(id.replacingOccurrences(of: "anthropic/", with: "")).tag(id)
                            }
                        }
                    }
                } else {
                    Picker("Model", selection: $model) {
                        ForEach(ClaudeClient.models) { Text($0.label).tag($0.id) }
                    }
                }
                HStack {
                    Button("Save and test") {
                        saveKey()
                        Task { await test() }
                    }
                    .disabled(apiKey.isEmpty || checking)
                    Spacer()
                    if checking { ProgressView() } else if let check { Text(check).font(.subheadline).foregroundStyle(Palette.ink2) }
                }
            } header: {
                Text("Claude")
            } footer: {
                Text(provider == "openrouter"
                     ? "Uses your OpenRouter credits. Get a key at openrouter.ai/keys. The model is Claude by default; any model id from openrouter.ai/models works. Your entries pass through OpenRouter on their way to the model."
                     : "Your key is kept in the iPhone Keychain and only ever sent to Anthropic. Get one at console.anthropic.com. Writing daily costs roughly $2–4 a month on Opus, less on Sonnet.")
            }

            Section {
                Toggle("Keep everything on this iPhone", isOn: $onDeviceOnly)
            } footer: {
                Text("When on, nothing is sent to Claude. Entries are still read on the phone, the map still draws and patterns are still found — just with less depth, and reflections are built from the numbers.")
            }

            Section("Daily reminder") {
                Toggle("Remind me to write", isOn: $reminderOn)
                    .onChange(of: reminderOn) { _, on in Task { await updateReminder(on) } }
                if reminderOn {
                    DatePicker("At", selection: reminderBinding, displayedComponents: .hourAndMinute)
                        .onChange(of: reminderTime) { _, _ in Task { await updateReminder(true) } }
                }
            }

            Section {
                Button("Prepare an export of everything") {
                    exportURL = try? Store.export(from: context)
                }
                if let exportURL {
                    ShareLink(item: exportURL) { Label("Share export", systemImage: "square.and.arrow.up") }
                }
                if hasSample {
                    Button("Remove the sample journal", role: .destructive) {
                        SampleJournal.remove(from: context, intelligence: intelligence)
                    }
                } else {
                    Button("Load a sample journal") {
                        SampleJournal.load(into: context, intelligence: intelligence)
                    }
                }
                Button("Erase everything", role: .destructive) { confirmErase = true }
            } header: {
                Text("Your data")
            } footer: {
                Text("The sample journal is three months of made-up entries so you can see the map and patterns straight away. Removing it only takes out the sample — anything you've written stays.")
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Settings")
        .onAppear { apiKey = Keychain.get(keyAccount) ?? "" }
        .task(id: provider) {
            guard provider == "openrouter", openRouterModels.isEmpty else { return }
            openRouterModels = (try? await OpenRouterClient.claudeModels()) ?? []
            if !openRouterModels.isEmpty, !openRouterModels.contains(openRouterModel),
               let pick = OpenRouterClient.best(of: openRouterModels) {
                openRouterModel = pick
            }
        }
        .onDisappear(perform: saveKey)
        .confirmationDialog("Erase every entry, insight and reflection?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) { Store.eraseEverything(in: context) }
        } message: {
            Text("This can't be undone. Export first if you might want it back.")
        }
    }

    private var reminderBinding: Binding<Date> {
        Binding {
            Calendar.current.startOfDay(for: .now).addingTimeInterval(reminderTime)
        } set: { date in
            reminderTime = date.timeIntervalSince(Calendar.current.startOfDay(for: date))
        }
    }

    private var keyAccount: String {
        provider == "openrouter" ? Prefs.openRouterKeyAccount : Prefs.apiKeyAccount
    }

    private func saveKey() {
        Keychain.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: keyAccount)
    }

    private func test() async {
        if provider == "openrouter" { await OpenRouterClient.settleModel() }
        guard let client = intelligence.claude else {
            check = onDeviceOnly ? "Turn off “Keep everything on this iPhone” first." : "No key saved."
            return
        }
        checking = true
        defer { checking = false }
        do {
            try await client.check()
            check = "Connected ✓"
        } catch {
            check = error.localizedDescription
        }
    }

    private func updateReminder(_ on: Bool) async {
        if on {
            let time = Calendar.current.startOfDay(for: .now).addingTimeInterval(reminderTime)
            if !(await Reminders.schedule(at: time)) { reminderOn = false }
        } else {
            Reminders.cancel()
        }
    }
}
