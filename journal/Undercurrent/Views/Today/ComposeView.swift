import SwiftUI
import SwiftData

/// Full-screen, distraction-free writing. Type, or tap the microphone and talk.
struct ComposeView: View {
    let mode: ComposeMode
    var question: String? = nil
    var editing: Entry? = nil
    var presetTags: [Tag] = []

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Intelligence.self) private var intelligence

    @State private var text = ""
    @State private var isInsight = false
    @State private var dictation = Dictation()
    @State private var textBeforeDictation = ""
    @State private var usedDictation = false
    @FocusState private var focused: Bool
    @State private var chosen: [Tag] = []
    @State private var detected: [Tag] = []
    @State private var dropped: Set<String> = []
    @State private var pickingTag = false

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

                if !isInsight { tagRow }
                bottomBar
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { close() }
                }
                ToolbarItem(placement: .principal) {
                    Text(Date.now.stamp("EEEEdMMM")).font(.callout.weight(.semibold)).foregroundStyle(Palette.ink2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: text) {
            // Spot people, places and themes as you write, once you pause.
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            detected = LocalReader().read(text).entities.compactMap { found in
                EntityKind(rawValue: found.kind).map { Tag(name: found.name, kind: $0) }
            }
        }
        .sheet(isPresented: $pickingTag) {
            TagPicker { tag in
                dropped.remove(tag.key)
                if !chosen.contains(tag) { chosen.append(tag) }
            }
        }
        .onAppear {
            chosen = editing?.chosenTags ?? presetTags
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

    /// Your tags, then the ones spotted in the text (dashed), then + Tag.
    private var tagRow: some View {
        let chosenKeys = Set(chosen.map(\.key))
        let suggestions = detected.filter { !chosenKeys.contains($0.key) && !dropped.contains($0.key) }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chosen) { tag in
                    RemovableTag(tag: tag) { withAnimation { chosen.removeAll { $0 == tag }; dropped.insert(tag.key) } }
                }
                ForEach(suggestions) { tag in
                    RemovableTag(tag: tag, suggested: true) { withAnimation { _ = dropped.insert(tag.key) } }
                }
                Button { pickingTag = true } label: {
                    Label("Tag", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Palette.raised))
                }
                .foregroundStyle(Palette.accent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .animation(.snappy, value: suggestions.map(\.key))
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Text(wordCount)
                .font(.footnote.monospacedDigit())
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
                        .font(.system(.title2, weight: .semibold))
                        .foregroundStyle(Palette.paper)
                }
            }
            .accessibilityLabel(dictation.isListening ? "Stop dictation" : "Start dictation")
            .sensoryFeedback(.impact(weight: .medium), trigger: dictation.isListening)

            Spacer()

            Text(dictation.isListening ? "Listening…" : (dictation.problem ?? ""))
                .font(.footnote)
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
            editing.chosenTags = chosen
            editing.excludedKeys = Array(Set(editing.excludedKeys ?? []).union(dropped).subtracting(chosen.map(\.key)))
            editing.analysedBy = nil
            editing.analysedAt = nil
            try? context.save()
            Task { await intelligence.read(editing, in: context) }
        } else if isInsight {
            intelligence.saveInsight(text: body, in: context)
        } else {
            intelligence.saveEntry(text: body, dictated: usedDictation, question: question,
                                   tags: chosen, dropped: Array(dropped), in: context)
        }
        dismiss()
    }

    private func close() {
        dictation.stop()
        dismiss()
    }
}
