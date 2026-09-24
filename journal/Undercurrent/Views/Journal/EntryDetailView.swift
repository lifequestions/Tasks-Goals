import SwiftUI
import SwiftData

struct EntryDetailView: View {
    let entry: Entry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Intelligence.self) private var intelligence
    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(entry.createdAt.stamp("EEEEdMMMMyyyyjmm") + (entry.wasDictated ? " · spoken" : ""))
                    if let summary = entry.summary {
                        Text(summary).font(.headline2).foregroundStyle(Palette.ink)
                    }
                }

                Card {
                    HStack {
                        Eyebrow("How it reads")
                        Spacer()
                        Text(Feeling.word(entry.mood).capitalized)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(entry.mood.map(Palette.feeling) ?? Palette.ink3)
                    }
                    FeelingScale(value: entry.mood ?? 0)
                    HStack {
                        Text("heavier").font(.caption).foregroundStyle(Palette.ink3)
                        Spacer()
                        Text("lighter").font(.caption).foregroundStyle(Palette.ink3)
                    }
                }

                Text(entry.text)
                    .font(.reading)
                    .lineSpacing(7)
                    .foregroundStyle(Palette.ink)
                    .textSelection(.enabled)

                if !entry.mentions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow("In this entry")
                        ForEach(entry.mentions.sorted { ($0.entity?.name ?? "") < ($1.entity?.name ?? "") }) { mention in
                            if let entity = mention.entity {
                                HStack(alignment: .top, spacing: 4) {
                                    NavigationLink(value: entity) {
                                        HStack(alignment: .top, spacing: 10) {
                                            EntityChip(name: entity.name, kind: entity.kind, feeling: mention.sentiment)
                                            Text("“\(mention.quote)”")
                                                .font(.subheadline)
                                                .foregroundStyle(Palette.ink2)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                            Spacer(minLength: 0)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    Menu {
                                        Button("Not about \(entity.name)", systemImage: "minus.circle", role: .destructive) {
                                            withAnimation {
                                                Store.detach(mention, in: context)
                                                intelligence.refreshPatterns(in: context)
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .foregroundStyle(Palette.ink3)
                                            .frame(width: 32, height: 28)
                                    }
                                }
                            }
                        }
                    }
                }

                footer
            }
            .padding(20)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                Button("Edit", systemImage: "pencil") { editing = true }
                if intelligence.usesClaude {
                    Button("Read again with Claude", systemImage: "sparkles") {
                        Task { await intelligence.read(entry, in: context) }
                    }
                }
                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .fullScreenCover(isPresented: $editing) { ComposeView(mode: .write, editing: entry) }
        .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                // Leave the screen first so nothing reads the entry after it's gone.
                let doomed = entry
                dismiss()
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    context.delete(doomed)
                    Store.pruneOrphans(in: context)
                    try? context.save()
                    intelligence.refreshPatterns(in: context)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if intelligence.working.contains("entry:\(entry.persistentModelID.hashValue)") {
                ProgressView().controlSize(.mini)
                Text("Claude is reading…")
            } else if let by = entry.analysedBy {
                Image(systemName: by == "claude" ? "sparkles" : "iphone")
                Text(by == "claude" ? "Read by Claude" : "Read on this phone")
            }
            Spacer()
            Text("\(entry.wordCount) words")
        }
        .font(.footnote)
        .foregroundStyle(Palette.ink3)
    }
}
