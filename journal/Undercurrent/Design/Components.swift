import SwiftUI

/// Small uppercase label that sits above a heading, as in Things.
struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(.footnote, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(Palette.ink3)
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Palette.line, lineWidth: 0.5)
            )
    }
}

struct FeelingDot: View {
    let value: Double?
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(value.map(Palette.feeling) ?? Palette.line)
            .frame(width: size, height: size)
            .overlay(Circle().fill((value.map(Palette.feeling) ?? .clear).opacity(0.25)).scaleEffect(1.9))
            .accessibilityLabel("Feeling: \(Feeling.word(value))")
    }
}

/// A horizontal bar from heavy to light with a marker at `value`.
struct FeelingScale: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            let x = (value + 1) / 2 * geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: [Palette.feeling(-1), Palette.feeling(0), Palette.feeling(1)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 6)
                    .opacity(0.55)
                Circle()
                    .fill(Palette.feeling(value))
                    .overlay(Circle().strokeBorder(Palette.card, lineWidth: 2))
                    .frame(width: 16, height: 16)
                    .offset(x: max(0, min(geo.size.width - 16, x - 8)))
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 16)
    }
}

struct EntityChip: View {
    let name: String
    let kind: EntityKind
    var feeling: Double?

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: kind.symbol).font(.system(.caption2, weight: .semibold))
            Text(name).font(.system(.subheadline, weight: .medium))
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill((feeling.map(Palette.feeling) ?? Palette.ink3).opacity(0.16))
        )
    }
}

struct Stat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.bigNumber).foregroundStyle(Palette.ink)
            Eyebrow(label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PillButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: .semibold))
            // A button's words never break across lines; they shrink a little first.
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .foregroundStyle(prominent ? Palette.paper : Palette.ink)
            .background(Capsule().fill(prominent ? Palette.accent : Palette.raised))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Chips spread over a few rows that scroll sideways together, so many show at once.
/// Each chip goes on whichever row is shortest so far, which keeps the first ones
/// (the ones you use most) at the left and the rows about the same length.
struct ChipRows<Item: Identifiable, Chip: View>: View {
    let items: [Item]
    var maxRows = 3
    /// Space before the first chip, and how far the rows reach past the parent's padding.
    var inset: CGFloat = 20
    var bleed: CGFloat = 0
    /// Roughly how long a chip's label is, in characters.
    let length: (Item) -> Int
    @ViewBuilder let chip: (Item) -> Chip

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows.indices, id: \.self) { i in
                    HStack(spacing: 8) {
                        ForEach(rows[i]) { chip($0) }
                    }
                }
            }
            .padding(.horizontal, inset)
        }
        .padding(.horizontal, -bleed)
    }

    private var rows: [[Item]] {
        // About four chips before a second row is worth it.
        let count = max(1, min(maxRows, (items.count + 3) / 4))
        var rows = Array(repeating: [Item](), count: count)
        var widths = Array(repeating: 0, count: count)
        for item in items {
            let shortest = widths.indices.min { widths[$0] < widths[$1] } ?? 0
            rows[shortest].append(item)
            widths[shortest] += length(item) + 6
        }
        return rows
    }
}

/// Wraps children onto new lines, for rows of chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

extension View {
    /// Every tab's NavigationStack can open an entry or a person/place/theme.
    func journalDestinations() -> some View {
        self
            .navigationDestination(for: Entry.self) { EntryDetailView(entry: $0) }
            .navigationDestination(for: Entity.self) { EntityDetailView(entity: $0) }
    }

    func screenBackground() -> some View {
        self.background(Palette.paper.ignoresSafeArea())
    }
}

extension Date {
    func stamp(_ template: String) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate(template)
        return f.string(from: self)
    }
}
