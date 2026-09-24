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
        return graph
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
