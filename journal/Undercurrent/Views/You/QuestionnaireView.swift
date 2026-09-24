import SwiftUI
import SwiftData

/// One statement at a time, big and calm, with the answers stacked below.
struct QuestionnaireView: View {
    let test: Questionnaire

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var answers: [Int] = []
    @State private var finished: [String: Double]?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ProgressView(value: Double(answers.count), total: Double(test.items.count))
                .tint(Palette.accent)

            if let finished {
                results(finished)
            } else if answers.count < test.items.count {
                question(test.items[answers.count])
            }
            Spacer()
        }
        .padding(20)
        .screenBackground()
        .navigationTitle(test.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !answers.isEmpty, finished == nil {
                Button("Back") { withAnimation(.snappy) { _ = answers.popLast() } }
            }
        }
        .animation(.snappy, value: answers.count)
    }

    private func question(_ item: Questionnaire.Item) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("\(answers.count + 1) of \(test.items.count)")
                if !test.stem.isEmpty {
                    Text(test.stem).font(.callout).foregroundStyle(Palette.ink2)
                }
                Text(item.text).font(.display).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .id(answers.count)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity))

            VStack(spacing: 8) {
                ForEach(Array(test.scale.enumerated()), id: \.offset) { index, label in
                    Button {
                        answers.append(index + 1)
                        if answers.count == test.items.count { finish() }
                    } label: {
                        Text(label)
                            .font(.system(.body, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(Palette.ink)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: answers.count)
                }
            }
        }
    }

    private func results(_ scores: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Eyebrow("Your results")
            Text("Saved. Every reading and reflection will now take this into account.")
                .font(.headline2).foregroundStyle(Palette.ink)
            Card { TraitBars(test: test, scores: scores) }
            Text("A short questionnaire gives a rough sketch, not a verdict. Source: \(test.source).")
                .font(.footnote).foregroundStyle(Palette.ink3)
            Button("Done") { dismiss() }.buttonStyle(PillButtonStyle())
        }
    }

    private func finish() {
        let scores = test.score(answers)
        context.insert(TraitResult(testID: test.id, scores: scores))
        try? context.save()
        withAnimation(.snappy) { finished = scores }
    }
}
