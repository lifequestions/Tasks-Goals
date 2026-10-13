import SwiftUI
import SwiftData

/// Write down something you've realised about yourself — or change one you wrote.
/// It goes in your insights, and Claude keeps it in mind when it reads and reflects.
struct InsightComposer: View {
    var editing: Insight? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Intelligence.self) private var intelligence
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                Text(editing == nil ? "What have you noticed about yourself?" : "Your insight")
                    .font(.headline2)
                    .foregroundStyle(Palette.ink)
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("“I always feel flat the day after a night out.” “Saying no to Jordan gets easier when I've slept.”")
                            .font(.reading)
                            .foregroundStyle(Palette.ink3)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .font(.reading)
                        .lineSpacing(6)
                        .foregroundStyle(Palette.ink)
                        .scrollContentBackground(.hidden)
                        .focused($focused)
                }
                Text("Your insights stay in your own words. Claude keeps them in mind when it reads entries and writes reflections, and says whether what you write bears them out.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink3)
            }
            .padding(20)
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Store.saveYourInsight(text, editing: editing, in: context)
                        intelligence.refreshPatterns(in: context)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            text = editing?.text ?? ""
            focused = true
        }
    }
}
