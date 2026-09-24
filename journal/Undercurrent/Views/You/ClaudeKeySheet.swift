import SwiftUI

/// The shortest way to switch Claude on: paste a key, test it, carry on.
struct ClaudeKeySheet: View {
    var onConnected: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(Intelligence.self) private var intelligence
    @AppStorage(Prefs.onDeviceOnly) private var onDeviceOnly = false
    @AppStorage(Prefs.provider) private var provider = "anthropic"
    @State private var key = ""
    @State private var checking = false
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "sparkles").font(.title2).foregroundStyle(Palette.accent)
                Text("Switch on Claude").font(.headline2).foregroundStyle(Palette.ink)
                Text("Claude reads your entries properly, writes the closer looks and reflections, and suggests follow-up questions. Use a key from Anthropic (console.anthropic.com) or from OpenRouter (openrouter.ai/keys) if you have credits there.")
                    .font(.callout).foregroundStyle(Palette.ink2)

                Picker("Through", selection: $provider) {
                    Text("Anthropic").tag("anthropic")
                    Text("OpenRouter").tag("openrouter")
                }
                .pickerStyle(.segmented)
                .onChange(of: provider) { _, _ in
                    key = Keychain.get(keyAccount) ?? ""
                    problem = nil
                }

                SecureField(provider == "openrouter" ? "Paste your key (sk-or-…)" : "Paste your key (sk-ant-…)", text: $key)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.raised))

                if let problem {
                    Text(problem).font(.subheadline).foregroundStyle(Palette.feeling(-0.8))
                }

                Button {
                    Task { await connect() }
                } label: {
                    HStack {
                        if checking { ProgressView().tint(Palette.paper) }
                        Text(checking ? "Checking…" : "Save and continue")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle())
                .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty || checking)

                Text(provider == "openrouter"
                     ? "The key stays in this iPhone's Keychain. Entries go through OpenRouter to Claude."
                     : "The key stays in this iPhone's Keychain and is only ever sent to Anthropic.")
                    .font(.footnote).foregroundStyle(Palette.ink3)
                Spacer()
            }
            .padding(24)
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } }
            }
        }
        .onAppear { key = Keychain.get(keyAccount) ?? "" }
    }

    private var keyAccount: String {
        provider == "openrouter" ? Prefs.openRouterKeyAccount : Prefs.apiKeyAccount
    }

    private func connect() async {
        problem = nil
        checking = true
        defer { checking = false }
        Keychain.set(key.trimmingCharacters(in: .whitespacesAndNewlines), for: keyAccount)
        onDeviceOnly = false
        if provider == "openrouter" { await OpenRouterClient.settleModel() }
        guard let client = intelligence.claude else {
            problem = "That key didn't save. Try pasting it again."
            return
        }
        do {
            try await client.check()
            dismiss()
            onConnected()
        } catch {
            problem = error.localizedDescription
        }
    }
}
