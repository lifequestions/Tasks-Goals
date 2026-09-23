import CoreGraphics
import Foundation

/// The Obsidian-style map. Every person, place, theme and activity is a node,
/// sized by how often it comes up and coloured by how you feel around it. Two
/// nodes are joined when they share entries; the line takes the colour of how
/// those shared entries felt, so a friend who keeps arriving with heavy days
/// is drawn with clay-coloured threads.
struct ConnectionGraph {
    struct Node: Identifiable {
        let id: String          // the entity's key
        let name: String
        let kind: EntityKind
        let count: Int
        let feeling: Double
        var position: CGPoint = .zero

        var radius: CGFloat { 5 + CGFloat(Double(count).squareRoot()) * 4 }
    }

    struct Edge: Identifiable {
        let a: Int
        let b: Int
        let weight: Int
        let feeling: Double
        var id: String { "\(a)-\(b)" }
    }

    private struct Pair: Hashable { let a: Int, b: Int }

    var nodes: [Node] = []
    var edges: [Edge] = []
    var bounds: CGRect = .zero

    static func build(from entries: [Entry], kinds: Set<EntityKind>, minMentions: Int, maxNodes: Int = 120) -> ConnectionGraph {
        var tally: [String: (entity: Entity, count: Int, feeling: Double)] = [:]
        for entry in entries {
            for mention in entry.mentions {
                guard let e = mention.entity, !e.hidden, kinds.contains(e.kind) else { continue }
                var slot = tally[e.key] ?? (e, 0, 0)
                slot.count += 1
                slot.feeling += mention.sentiment
                tally[e.key] = slot
            }
        }

        let chosen = tally.values
            .filter { $0.count >= minMentions }
            .sorted { $0.count > $1.count }
            .prefix(maxNodes)

        var graph = ConnectionGraph()
        var index: [String: Int] = [:]
        for item in chosen {
            index[item.entity.key] = graph.nodes.count
            graph.nodes.append(Node(id: item.entity.key, name: item.entity.name, kind: item.entity.kind, count: item.count,
                                    feeling: item.feeling / Double(item.count)))
        }

        var pairs: [Pair: (count: Int, mood: Double)] = [:]
        for entry in entries {
            let ids = Set(entry.mentions.compactMap { $0.entity.flatMap { index[$0.key] } }).sorted()
            guard ids.count > 1 else { continue }
            for i in 0..<ids.count {
                for j in (i + 1)..<ids.count {
                    let pair = Pair(a: ids[i], b: ids[j])
                    var slot = pairs[pair] ?? (0, 0)
                    slot.count += 1
                    slot.mood += entry.mood ?? 0
                    pairs[pair] = slot
                }
            }
        }
        graph.edges = pairs.map { Edge(a: $0.key.a, b: $0.key.b, weight: $0.value.count,
                                       feeling: $0.value.mood / Double($0.value.count)) }
        graph.layout()
        return graph
    }

    /// Fruchterman–Reingold: everything pushes apart, shared entries pull together,
    /// and a little gravity keeps islands from drifting off-screen.
    mutating func layout(iterations: Int = 350) {
        let n = nodes.count
        guard n > 0 else { return }
        let side = max(CGFloat(420), CGFloat(n).squareRoot() * 150)
        let k = side / CGFloat(n).squareRoot() * 0.75

        // Start on a golden-angle spiral, biggest in the middle, so layouts are stable.
        for i in 0..<n {
            let r = k * 0.5 * CGFloat(i).squareRoot()
            let theta = CGFloat(i) * 2.399963
            nodes[i].position = CGPoint(x: r * cos(theta), y: r * sin(theta))
        }

        // Gravity grows with the number of nodes, or big maps sprawl and shrink to specks on screen.
        let gravity = max(CGFloat(0.12), CGFloat(n) * 0.06)
        var temperature = side / 6
        var dx = [CGFloat](repeating: 0, count: n)
        var dy = [CGFloat](repeating: 0, count: n)

        for _ in 0..<iterations {
            for i in 0..<n { dx[i] = 0; dy[i] = 0 }

            for i in 0..<n {
                for j in (i + 1)..<n {
                    let x = nodes[i].position.x - nodes[j].position.x
                    let y = nodes[i].position.y - nodes[j].position.y
                    let d = max((x * x + y * y).squareRoot(), 0.01)
                    let push = k * k / d
                    dx[i] += x / d * push; dy[i] += y / d * push
                    dx[j] -= x / d * push; dy[j] -= y / d * push
                }
            }

            for edge in edges {
                let x = nodes[edge.a].position.x - nodes[edge.b].position.x
                let y = nodes[edge.a].position.y - nodes[edge.b].position.y
                let d = max((x * x + y * y).squareRoot(), 0.01)
                let pull = d * d / k * (0.6 + log(CGFloat(edge.weight)) * 0.4)
                dx[edge.a] -= x / d * pull; dy[edge.a] -= y / d * pull
                dx[edge.b] += x / d * pull; dy[edge.b] += y / d * pull
            }

            for i in 0..<n {
                dx[i] -= nodes[i].position.x * gravity
                dy[i] -= nodes[i].position.y * gravity
                let len = max((dx[i] * dx[i] + dy[i] * dy[i]).squareRoot(), 0.01)
                let step = min(len, temperature)
                nodes[i].position.x += dx[i] / len * step
                nodes[i].position.y += dy[i] / len * step
            }
            temperature = max(temperature * 0.985, 0.5)
        }

        let xs = nodes.map(\.position.x), ys = nodes.map(\.position.y)
        bounds = CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
            .insetBy(dx: -40, dy: -40)
    }

    func neighbours(of index: Int) -> Set<Int> {
        var out: Set<Int> = []
        for edge in edges {
            if edge.a == index { out.insert(edge.b) }
            if edge.b == index { out.insert(edge.a) }
        }
        return out
    }
}
