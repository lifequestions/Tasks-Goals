import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(Intelligence.self) private var intelligence

    @AppStorage(Prefs.model) private var model = ClaudeClient.defaultModel
    @AppStorage(Prefs.onDeviceOnly) private var onDeviceOnly = false
    @AppStorage(Prefs.reminderOn) private var reminderOn = false
    @AppStorage(Prefs.reminderTime) private var reminderTime: Double = 21 * 3600

    @State private var apiKey = ""
    @State private var check: String?
    @State private var checking = false
    @State private var exportURL: URL?
    @State private var confirmErase = false

    var body: some View {
        Form {
            Section {
                SecureField("sk-ant-…", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(saveKey)
                    .onChange(of: apiKey) { _, _ in check = nil }
                Picker("Model", selection: $model) {
                    ForEach(ClaudeClient.models) { Text($0.label).tag($0.id) }
                }
                HStack {
                    Button("Save and test") {
                        saveKey()
                        Task { await test() }
                    }
                    .disabled(apiKey.isEmpty || checking)
                    Spacer()
                    if checking { ProgressView() } else if let check { Text(check).font(.footnote).foregroundStyle(Palette.ink2) }
                }
            } header: {
                Text("Claude")
            } footer: {
                Text("Your key is kept in the iPhone Keychain and only ever sent to Anthropic. Get one at console.anthropic.com. Writing daily costs roughly $2–4 a month on Opus, less on Sonnet.")
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
                Button("Load a sample journal") {
                    SampleJournal.load(into: context, intelligence: intelligence)
                }
                Button("Erase everything", role: .destructive) { confirmErase = true }
            } header: {
                Text("Your data")
            } footer: {
                Text("The sample journal is three months of made-up entries so you can see the map and patterns straight away. Erase it before you start for real.")
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Settings")
        .onAppear { apiKey = Keychain.get(Prefs.apiKeyAccount) ?? "" }
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

    private func saveKey() {
        Keychain.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: Prefs.apiKeyAccount)
    }

    private func test() async {
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
