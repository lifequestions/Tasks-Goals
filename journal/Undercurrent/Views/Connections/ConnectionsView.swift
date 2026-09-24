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
    @State private var sim = GraphSimulation()
    @State private var selected: Int?
    @State private var opened: Entity?
    @State private var openForReading = false

    // Gesture bookkeeping.
    @State private var dragging: Int?
    @State private var panStart: CGSize?
    @State private var zoomStart: CGFloat?

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
            .safeAreaInset(edge: .top) {
                Picker("Span", selection: $span) {
                    ForEach(Span.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
            .navigationTitle("Connections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { filterMenu }
            }
            .task(id: rebuildKey) { rebuild() }
            .navigationDestination(item: $opened) { EntityDetailView(entity: $0, startReading: openForReading) }
            .journalDestinations()
        }
    }

    // MARK: The living graph

    private func canvas(size: CGSize) -> some View {
        let focus = selected.map { graph.neighbours(of: $0).union([$0]) }
        let feelings = RelativeFeeling(graph.nodes.map(\.feeling))
        let labelled = Set(graph.nodes.indices.sorted { graph.nodes[$0].count > graph.nodes[$1].count }.prefix(10))

        return TimelineView(.animation(paused: sim.settled && dragging == nil)) { _ in
            Canvas { context, size in
                sim.tick()
                sim.frame(size)
                let n = min(graph.nodes.count, sim.x.count)
                guard n > 0 else { return }

                // Threads: faint and neutral, until you pick something —
                // then its own threads take the colour of the days they share.
                for edge in graph.edges where edge.a < n && edge.b < n {
                    let lit = focus.map { $0.contains(edge.a) && $0.contains(edge.b) }
                    var path = Path()
                    path.move(to: sim.point(edge.a, in: size))
                    path.addLine(to: sim.point(edge.b, in: size))
                    let width = min(0.6 + CGFloat(edge.weight) * 0.35, 2.6)
                    if lit == true {
                        context.stroke(path, with: .color(Palette.feeling(feelings.relative(edge.feeling)).opacity(0.85)),
                                       lineWidth: width + 0.6)
                    } else {
                        context.stroke(path, with: .color(Palette.ink.opacity(lit == false ? 0.04 : 0.13)), lineWidth: width)
                    }
                }

                // Dots, small and clean. People are solid; everything else is a ring.
                for i in 0..<n {
                    let node = graph.nodes[i]
                    let lit = focus?.contains(i) ?? true
                    let c = sim.point(i, in: size)
                    let r = sim.radius(i)
                    let colour = Palette.feeling(feelings.relative(node.feeling))
                    let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)

                    context.opacity = lit ? 1 : 0.15
                    if i == selected {
                        context.fill(Path(ellipseIn: rect.insetBy(dx: -r * 0.9, dy: -r * 0.9)), with: .color(colour.opacity(0.22)))
                    }
                    if node.kind == .person {
                        context.fill(Path(ellipseIn: rect), with: .color(colour))
                    } else {
                        context.fill(Path(ellipseIn: rect), with: .color(Palette.paper))
                        context.stroke(Path(ellipseIn: rect.insetBy(dx: 1, dy: 1)), with: .color(colour), lineWidth: 2)
                    }

                    let showLabel = lit && (labelled.contains(i) || focus != nil || sim.zoom > 1.5)
                    if showLabel {
                        let strong = focus?.contains(i) == true
                        context.draw(Text(node.name)
                                        .font(.system(size: strong ? 12.5 : 11, weight: strong ? .semibold : .regular))
                                        .foregroundStyle(strong ? Palette.ink : Palette.ink2),
                                     at: CGPoint(x: c.x, y: c.y + r + 3), anchor: .top)
                    }
                    context.opacity = 1
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(dragOrPan(size: size))
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    if zoomStart == nil { zoomStart = sim.zoom }
                    sim.followsGraph = false
                    sim.zoom = max(0.5, min((zoomStart ?? 1) * value.magnification, 4))
                    sim.redraw()
                }
                .onEnded { _ in zoomStart = nil }
        )
        .sensoryFeedback(.selection, trigger: selected)
    }

    /// Touch a dot to grab it and drag it about; touch empty space to pan.
    /// A touch that barely moves is a tap: it selects, or clears the selection.
    private func dragOrPan(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragging == nil && panStart == nil {
                    if let i = sim.hit(value.startLocation, in: size) {
                        dragging = i
                        sim.grab(i)
                    } else {
                        panStart = sim.pan
                    }
                }
                let moved = hypot(value.translation.width, value.translation.height) > 4
                if let i = dragging, moved {
                    sim.move(i, to: sim.world(value.location, in: size))
                } else if let start = panStart, moved {
                    sim.followsGraph = false
                    sim.pan = CGSize(width: start.width + value.translation.width,
                                     height: start.height + value.translation.height)
                    sim.redraw()
                }
            }
            .onEnded { value in
                let tapped = hypot(value.translation.width, value.translation.height) <= 4
                if tapped {
                    withAnimation(.snappy) { selected = (dragging == selected) ? nil : dragging }
                }
                if dragging != nil { sim.release() }
                dragging = nil
                panStart = nil
            }
    }

    // MARK: Chrome

    private var filterMenu: some View {
        Menu {
            Section("Show") {
                ForEach(EntityKind.allCases) { kind in
                    Toggle(isOn: Binding(
                        get: { kinds.contains(kind) },
                        set: { on in
                            if on { kinds.insert(kind) } else if kinds.count > 1 { kinds.remove(kind) }
                        })) {
                        Label(kind.plural, systemImage: kind.symbol)
                    }
                }
            }
            Picker("Mentioned at least", selection: $minMentions) {
                Text("Once").tag(1)
                Text("Twice").tag(2)
                Text("3 times").tag(3)
                Text("5 times").tag(5)
            }
            Button("Fit to screen", systemImage: "arrow.down.right.and.arrow.up.left") { resetView() }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Circle().fill(Palette.ink2).frame(width: 7, height: 7)
            Text("person").font(.caption2)
            Circle().strokeBorder(Palette.ink2, lineWidth: 1.5).frame(width: 8, height: 8)
            Text("theme, place, activity").font(.caption2)
            Spacer()
            Text("heavier").font(.caption2)
            Capsule()
                .fill(LinearGradient(colors: [Palette.feeling(-1), Palette.feeling(0), Palette.feeling(1)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 50, height: 4)
            Text("lighter").font(.caption2)
        }
        .foregroundStyle(Palette.ink3)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(.ultraThinMaterial))
        .accessibilityLabel("Colours show whether something comes with heavier or lighter days than usual for you")
    }

    private func selectionCard(_ node: ConnectionGraph.Node, index: Int) -> some View {
        let links = graph.edges
            .filter { $0.a == index || $0.b == index }
            .sorted { $0.weight > $1.weight }
            .prefix(4)
            .map { graph.nodes[$0.a == index ? $0.b : $0.a].name }
        let feelings = RelativeFeeling(graph.nodes.map(\.feeling))
        let relative = feelings.relative(node.feeling)

        let open: (Bool) -> Void = { reading in
            openForReading = reading
            opened = entities.first { $0.key == node.id }
        }

        return Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(node.kind.rawValue)
                    Text(node.name).font(.headline2).foregroundStyle(Palette.ink)
                    Text("\(node.count) mentions · \(feelings.phrase(relative))")
                        .font(.subheadline).foregroundStyle(Palette.ink2)
                }
                Spacer()
                FeelingDot(value: relative, size: 14).padding(.top, 6)
            }
            if !links.isEmpty {
                Text("Often with " + links.joined(separator: ", "))
                    .font(.footnote).foregroundStyle(Palette.ink3)
            }
            HStack(spacing: 10) {
                Button { open(true) } label: { Label("Closer look", systemImage: "sparkles") }
                    .buttonStyle(PillButtonStyle())
                Button { open(false) } label: { Text("Open") }
                    .buttonStyle(PillButtonStyle(prominent: false))
                Spacer()
            }
        }
        .contentShape(Rectangle())
            .onTapGesture { open(false) }
    }

    // MARK: State

    private var rebuildKey: String {
        let latest = entries.last?.analysedAt?.timeIntervalSince1970 ?? 0
        return "\(entries.count)-\(entities.count)-\(latest)-\(span.rawValue)-\(kinds.map(\.rawValue).sorted())-\(minMentions)"
    }

    private func rebuild() {
        let since = span.since
        let chosen = since.map { date in entries.filter { $0.createdAt >= date } } ?? entries
        graph = ConnectionGraph.build(from: chosen, kinds: kinds, minMentions: minMentions)
        sim.load(graph)
        sim.followsGraph = true
        selected = nil
    }

    private func resetView() {
        sim.zoom = 1
        sim.pan = .zero
        sim.followsGraph = true
        sim.wake()
        withAnimation(.snappy) { selected = nil }
    }
}

/// Colours are relative to your own usual. Read on the phone, most entries
/// come out a little heavy, so a fixed scale paints everything clay; this
/// spreads the colours around your own average instead.
struct RelativeFeeling {
    let mean: Double
    let spread: Double

    init(_ values: [Double]) {
        let average = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        mean = average
        spread = max(0.12, values.map { abs($0 - average) }.max() ?? 0)
    }

    func relative(_ value: Double) -> Double {
        max(-1, min(1, (value - mean) / spread))
    }

    func phrase(_ relative: Double) -> String {
        switch relative {
        case ..<(-0.45): "much heavier than usual"
        case ..<(-0.15): "a bit heavier than usual"
        case ..<0.15: "about your usual"
        case ..<0.45: "a bit lighter than usual"
        default: "much lighter than usual"
        }
    }
}
