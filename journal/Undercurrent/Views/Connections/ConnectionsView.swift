import SwiftUI
import SwiftData

struct ConnectionsView: View {
    enum Span: String, CaseIterable, Identifiable {
        case month = "30 days", quarter = "90 days", year = "Year", all = "All"
        var id: String { rawValue }

        var since: Date? {
            let days: Int? = switch self {
            case .month: 30
            case .quarter: 90
            case .year: 365
            case .all: nil
            }
            return days.flatMap { Calendar.current.date(byAdding: .day, value: -$0, to: .now) }
        }
    }

    @Query(sort: \Entry.createdAt) private var entries: [Entry]
    @Query private var entities: [Entity]
    @State private var span: Span = .quarter
    @State private var kinds: Set<EntityKind> = Set(EntityKind.allCases)
    @State private var minMentions = 2
    @State private var graph = ConnectionGraph()
    @State private var selected: Int?
    @State private var zoom: CGFloat = 1
    @State private var settledZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var settledPan: CGSize = .zero
    @State private var opened: Entity?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Palette.paper.ignoresSafeArea()

                if graph.nodes.isEmpty {
                    ContentUnavailableView {
                        Label("No connections yet", systemImage: "point.3.connected.trianglepath.dotted")
                    } description: {
                        Text("As you write, the people, places and themes in your life will appear here, joined by the entries they share.")
                    }
                } else {
                    GeometryReader { geo in
                        canvas(size: geo.size)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }

                VStack(spacing: 10) {
                    Spacer()
                    if let selected, graph.nodes.indices.contains(selected) {
                        selectionCard(graph.nodes[selected], index: selected)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    legend
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .safeAreaInset(edge: .top) { filters }
            .navigationTitle("Connections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Show things mentioned at least", selection: $minMentions) {
                            Text("Once").tag(1)
                            Text("Twice").tag(2)
                            Text("3 times").tag(3)
                            Text("5 times").tag(5)
                        }
                        Button("Reset view", systemImage: "arrow.counterclockwise") { resetView() }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .task(id: rebuildKey) { rebuild() }
            .navigationDestination(item: $opened) { EntityDetailView(entity: $0) }
            .journalDestinations()
        }
    }

    // MARK: Drawing

    private func canvas(size: CGSize) -> some View {
        let fit = fitScale(for: size)
        let focus = selected.map { graph.neighbours(of: $0).union([$0]) }

        return Canvas { context, size in
            func point(_ node: ConnectionGraph.Node) -> CGPoint {
                screen(node.position, size: size, fit: fit)
            }

            for edge in graph.edges {
                let lit = focus.map { $0.contains(edge.a) && $0.contains(edge.b) } ?? true
                var path = Path()
                path.move(to: point(graph.nodes[edge.a]))
                path.addLine(to: point(graph.nodes[edge.b]))
                let opacity = lit ? min(0.18 + 0.1 * Double(edge.weight), 0.75) : 0.05
                context.stroke(path, with: .color(Palette.feeling(edge.feeling).opacity(opacity)),
                               lineWidth: min(0.8 + CGFloat(edge.weight) * 0.5, 5))
            }

            for (i, node) in graph.nodes.enumerated() {
                let lit = focus?.contains(i) ?? true
                let c = point(node)
                let r = node.radius * max(0.7, min(zoom, 1.6))
                let colour = Palette.feeling(node.feeling)
                let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)

                context.opacity = lit ? 1 : 0.18
                context.fill(Path(ellipseIn: rect.insetBy(dx: -r * 0.7, dy: -r * 0.7)), with: .color(colour.opacity(0.13)))
                switch node.kind {
                case .person:
                    context.fill(Path(ellipseIn: rect), with: .color(colour))
                case .place:
                    context.fill(Path(roundedRect: rect, cornerRadius: r * 0.35), with: .color(colour))
                case .theme:
                    context.stroke(Path(ellipseIn: rect.insetBy(dx: 1.5, dy: 1.5)), with: .color(colour), lineWidth: 3)
                case .activity:
                    context.fill(Path(ellipseIn: rect), with: .color(colour.opacity(0.55)))
                }
                if i == selected {
                    context.stroke(Path(ellipseIn: rect.insetBy(dx: -5, dy: -5)), with: .color(Palette.ink), lineWidth: 1.5)
                }

                let showLabel = lit && (node.count >= labelThreshold || zoom > 1.4 || focus != nil)
                if showLabel {
                    context.draw(Text(node.name)
                                    .font(.system(size: node.count >= labelThreshold * 2 ? 13 : 11, weight: .medium))
                                    .foregroundStyle(Palette.ink),
                                 at: CGPoint(x: c.x, y: c.y + r + 4), anchor: .top)
                }
                context.opacity = 1
            }
        }
        .contentShape(Rectangle())
        .gesture(
            SimultaneousGesture(
                MagnifyGesture()
                    .onChanged { zoom = max(0.4, min(settledZoom * $0.magnification, 5)) }
                    .onEnded { _ in settledZoom = zoom },
                DragGesture()
                    .onChanged { pan = CGSize(width: settledPan.width + $0.translation.width,
                                              height: settledPan.height + $0.translation.height) }
                    .onEnded { _ in settledPan = pan }
            )
        )
        .onTapGesture(coordinateSpace: .local) { location in
            withAnimation(.snappy) { selected = hit(location, size: size, fit: fit) }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func fitScale(for size: CGSize) -> CGFloat {
        guard graph.bounds.width > 0, graph.bounds.height > 0 else { return 1 }
        return min(size.width / graph.bounds.width, (size.height - 140) / graph.bounds.height, 2)
    }

    private func screen(_ p: CGPoint, size: CGSize, fit: CGFloat) -> CGPoint {
        CGPoint(x: size.width / 2 + (p.x - graph.bounds.midX) * fit * zoom + pan.width,
                y: size.height / 2 - 40 + (p.y - graph.bounds.midY) * fit * zoom + pan.height)
    }

    private func hit(_ location: CGPoint, size: CGSize, fit: CGFloat) -> Int? {
        var best: (Int, CGFloat)?
        for (i, node) in graph.nodes.enumerated() {
            let c = screen(node.position, size: size, fit: fit)
            let d = hypot(c.x - location.x, c.y - location.y)
            if d <= node.radius * max(0.7, min(zoom, 1.6)) + 14, d < (best?.1 ?? .infinity) { best = (i, d) }
        }
        return best?.0
    }

    // MARK: Chrome

    private var filters: some View {
        VStack(spacing: 10) {
            Picker("Span", selection: $span) {
                ForEach(Span.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                ForEach(EntityKind.allCases) { kind in
                    let on = kinds.contains(kind)
                    Button {
                        if on, kinds.count > 1 { kinds.remove(kind) } else { kinds.insert(kind) }
                    } label: {
                        Label(kind.plural, systemImage: kind.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(on ? Palette.paper : Palette.ink2)
                            .background(Capsule().fill(on ? Palette.accent : Palette.raised))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Text("heavier").font(.caption2)
            Capsule()
                .fill(LinearGradient(colors: [Palette.feeling(-1), Palette.feeling(0), Palette.feeling(1)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 90, height: 5)
            Text("lighter").font(.caption2)
            Spacer()
            Text("\(graph.nodes.count) things · \(graph.edges.count) threads").font(.caption2)
        }
        .foregroundStyle(Palette.ink3)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(.ultraThinMaterial))
    }

    private func selectionCard(_ node: ConnectionGraph.Node, index: Int) -> some View {
        let links = graph.edges
            .filter { $0.a == index || $0.b == index }
            .sorted { $0.weight > $1.weight }
            .prefix(4)
            .map { graph.nodes[$0.a == index ? $0.b : $0.a].name }

        return Button { opened = entities.first { $0.key == node.id } } label: {
            Card {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow(node.kind.rawValue)
                        Text(node.name).font(.headline2).foregroundStyle(Palette.ink)
                        Text("\(node.count) mentions · mostly \(Feeling.word(node.feeling))")
                            .font(.subheadline).foregroundStyle(Palette.ink2)
                    }
                    Spacer()
                    FeelingDot(value: node.feeling, size: 14).padding(.top, 6)
                }
                if !links.isEmpty {
                    Text("Often with " + links.joined(separator: ", "))
                        .font(.footnote).foregroundStyle(Palette.ink3)
                }
                HStack {
                    Spacer()
                    Label("Open", systemImage: "chevron.right").labelStyle(.titleOnly)
                        .font(.footnote.weight(.semibold)).foregroundStyle(Palette.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: State

    private var labelThreshold: Int {
        let counts = graph.nodes.map(\.count).sorted(by: >)
        return counts.count > 14 ? counts[14] : 0
    }

    private var rebuildKey: String {
        let latest = entries.last?.analysedAt?.timeIntervalSince1970 ?? 0
        return "\(entries.count)-\(entities.count)-\(latest)-\(span.rawValue)-\(kinds.map(\.rawValue).sorted())-\(minMentions)"
    }

    private func rebuild() {
        let since = span.since
        let chosen = since.map { date in entries.filter { $0.createdAt >= date } } ?? entries
        graph = ConnectionGraph.build(from: chosen, kinds: kinds, minMentions: minMentions)
        selected = nil
    }

    private func resetView() {
        withAnimation(.snappy) {
            zoom = 1; settledZoom = 1
            pan = .zero; settledPan = .zero
            selected = nil
        }
    }
}
