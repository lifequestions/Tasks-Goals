import SwiftUI
import SwiftData

/// Choose someone or something already in the journal, or start a new one.
struct TagPicker: View {
    var onPick: (Tag) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var entities: [Entity]
    @State private var search = ""
    @State private var newKind: EntityKind = .person

    var body: some View {
        NavigationStack {
            List {
                let typed = search.trimmingCharacters(in: .whitespacesAndNewlines)
                if !typed.isEmpty && !matches.contains(where: { $0.name.localizedCaseInsensitiveCompare(typed) == .orderedSame }) {
                    Section("New") {
                        Picker("Kind", selection: $newKind) {
                            ForEach(EntityKind.allCases) { Text($0.rawValue.capitalized).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Button {
                            pick(Tag(name: typed, kind: newKind))
                        } label: {
                            Label("Add “\(typed)”", systemImage: "plus.circle.fill")
                        }
                    }
                }
                Section(search.isEmpty ? "In your journal" : "Matches") {
                    ForEach(matches) { entity in
                        Button { pick(Tag(entity)) } label: {
                            HStack {
                                EntityChip(name: entity.name, kind: entity.kind, feeling: entity.averageFeeling)
                                Spacer()
                                Text("\(entity.mentions.count)").font(.footnote).foregroundStyle(Palette.ink3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Person, place or theme")
            .navigationTitle("Add a tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var matches: [Entity] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return entities
            .filter { !$0.hidden && (q.isEmpty || $0.name.localizedCaseInsensitiveContains(q)) }
            .sorted { $0.mentions.count > $1.mentions.count }
    }

    private func pick(_ tag: Tag) {
        onPick(tag)
        dismiss()
    }
}

/// A tag chip with a small ✕, for the compose screen.
struct RemovableTag: View {
    let tag: Tag
    var suggested = false
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: tag.kind.symbol).font(.caption2.weight(.semibold))
            Text(tag.name).font(.subheadline.weight(.medium))
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.caption2.weight(.bold))
            }
            .accessibilityLabel("Remove \(tag.name)")
        }
        .foregroundStyle(suggested ? Palette.ink2 : Palette.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(suggested ? Color.clear : Palette.accentSoft))
        .overlay(Capsule().strokeBorder(suggested ? Palette.line : Color.clear, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
    }
}
