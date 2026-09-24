import SwiftUI
import SwiftData

/// Full-screen, distraction-free writing. Type, or tap the microphone and talk.
struct ComposeView: View {
    let mode: ComposeMode
    var question: String? = nil
    var editing: Entry? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Intelligence.self) private var intelligence

    @State private var text = ""
    @State private var isInsight = false
    @State private var dictation = Dictation()
    @State private var textBeforeDictation = ""
    @State private var usedDictation = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if editing == nil {
                    Picker("Kind", selection: $isInsight) {
                        Text("Entry").tag(false)
                        Text("Insight").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }

                if let asked, !isInsight {
                    Text(asked)
                        .font(.headline2)
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 25)
                        .padding(.top, 8)
                }

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.reading)
                            .foregroundStyle(Palette.ink3)
                            .padding(.horizontal, 25)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .font(.reading)
                        .lineSpacing(6)
                        .foregroundStyle(Palette.ink)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .focused($focused)
                }

                bottomBar
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { close() }
                }
                ToolbarItem(placement: .principal) {
                    Text(Date.now.stamp("EEEEdMMM")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if let editing { text = editing.text }
            isInsight = mode == .insight
            if mode == .speak {
                Task { await startDictation() }
            } else {
                focused = true
            }
        }
        .onChange(of: dictation.transcript) { _, spoken in
            guard dictation.isListening || !spoken.isEmpty else { return }
            let joiner = textBeforeDictation.isEmpty || textBeforeDictation.hasSuffix("\n") ? "" : " "
            text = textBeforeDictation + joiner + spoken
        }
        .onDisappear { dictation.stop() }
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Text(wordCount)
                .font(.caption.monospacedDigit())
                .foregroundStyle(Palette.ink3)
                .frame(width: 80, alignment: .leading)

            Spacer()

            Button {
                Task {
                    if dictation.isListening { dictation.stop() } else { await startDictation() }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Palette.accent.opacity(0.18))
                        .frame(width: 76, height: 76)
                        .scaleEffect(dictation.isListening ? 1 + CGFloat(dictation.level) * 0.5 : 0.8)
                        .animation(.easeOut(duration: 0.12), value: dictation.level)
                    Circle()
                        .fill(dictation.isListening ? Palette.feeling(-0.6) : Palette.accent)
                        .frame(width: 58, height: 58)
                    Image(systemName: dictation.isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Palette.paper)
                }
            }
            .accessibilityLabel(dictation.isListening ? "Stop dictation" : "Start dictation")
            .sensoryFeedback(.impact(weight: .medium), trigger: dictation.isListening)

            Spacer()

            Text(dictation.isListening ? "Listening…" : (dictation.problem ?? ""))
                .font(.caption)
                .foregroundStyle(Palette.ink3)
                .lineLimit(2)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Palette.paper)
    }

    /// The question on screen: the one passed in, or the entry's own when editing.
    private var asked: String? { editing?.question ?? question }

    private var placeholder: String {
        if isInsight { return "Something you've realised about yourself…" }
        if mode == .speak { return "Start talking — it'll appear here." }
        return asked == nil ? Questions.opener().text : "Write as much or as little as you like."
    }

    private var wordCount: String {
        let n = text.split { $0.isWhitespace || $0.isNewline }.count
        return n == 0 ? "" : "\(n) words"
    }

    private func startDictation() async {
        focused = false
        textBeforeDictation = text
        usedDictation = true
        await dictation.start()
    }

    private func save() {
        dictation.stop()
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }

        if let editing {
            editing.text = body
            editing.analysedBy = nil
            editing.analysedAt = nil
            try? context.save()
            Task { await intelligence.read(editing, in: context) }
        } else if isInsight {
            intelligence.saveInsight(text: body, in: context)
        } else {
            intelligence.saveEntry(text: body, dictated: usedDictation, question: question, in: context)
        }
        dismiss()
    }

    private func close() {
        dictation.stop()
        dismiss()
    }
}
