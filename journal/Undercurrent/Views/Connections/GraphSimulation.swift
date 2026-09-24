import CoreGraphics
import Foundation
import Observation

/// A live force simulation, like Obsidian's graph view: nodes push each other
/// apart, shared entries pull them together, and the whole thing drifts into
/// place and settles. Dragging a node warms it up again so the rest follow.
///
/// Only `settled` is observed, so the view can stop animating once nothing
/// moves; everything else changes every frame and is read straight from the
/// Canvas.
@Observable
final class GraphSimulation {
    private(set) var settled = true

    @ObservationIgnored private(set) var x: [CGFloat] = []
    @ObservationIgnored private(set) var y: [CGFloat] = []
    @ObservationIgnored private var vx: [CGFloat] = []
    @ObservationIgnored private var vy: [CGFloat] = []
    @ObservationIgnored private var radii: [CGFloat] = []
    @ObservationIgnored private var links: [(a: Int, b: Int, strength: CGFloat)] = []
    @ObservationIgnored private var alpha: CGFloat = 1
    @ObservationIgnored private var alphaTarget: CGFloat = 0
    @ObservationIgnored private var pinned: Int?

    // Camera. Until you pinch or pan, it keeps the whole graph in view.
    @ObservationIgnored var zoom: CGFloat = 1
    @ObservationIgnored var pan: CGSize = .zero
    @ObservationIgnored var followsGraph = true
    @ObservationIgnored private(set) var fit: CGFloat = 1
    @ObservationIgnored private var centre: CGPoint = .zero

    func load(_ graph: ConnectionGraph) {
        let n = graph.nodes.count
        let previous = Dictionary(uniqueKeysWithValues: zip(ids, zip(x, y)))
        ids = graph.nodes.map(\.id)
        x = []; y = []
        for (i, node) in graph.nodes.enumerated() {
            if let p = previous[node.id] {
                x.append(p.0); y.append(p.1)
            } else {
                // New nodes bloom out from the middle.
                let angle = CGFloat(i) * 2.399963
                let r = 6 * CGFloat(i).squareRoot()
                x.append(r * cos(angle)); y.append(r * sin(angle))
            }
        }
        vx = Array(repeating: 0, count: n)
        vy = Array(repeating: 0, count: n)
        radii = graph.nodes.map { Self.radius(count: $0.count) }
        var degree = Array(repeating: 0, count: n)
        for e in graph.edges { degree[e.a] += 1; degree[e.b] += 1 }
        links = graph.edges.map { e in
            (e.a, e.b, min(1, 0.35 + 0.15 * CGFloat(e.weight)) / CGFloat(max(1, min(degree[e.a], degree[e.b]))))
        }
        alpha = 1
        alphaTarget = 0
        settled = n == 0
    }

    @ObservationIgnored private var ids: [String] = []

    static func radius(count: Int) -> CGFloat { 3.5 + CGFloat(count).squareRoot() * 2.2 }

    /// One step of the simulation. Called once per frame while unsettled.
    func tick() {
        let n = x.count
        guard n > 0, !settled else { return }
        alpha += (alphaTarget - alpha) * 0.028

        // Everything repels everything, gently, falling off with distance.
        let charge: CGFloat = -260
        for i in 0..<n {
            for j in (i + 1)..<n {
                var dx = x[j] - x[i], dy = y[j] - y[i]
                if dx == 0 && dy == 0 { dx = 0.1 * CGFloat(i - j); dy = 0.1 }
                let d2 = max(dx * dx + dy * dy, 25)
                let f = charge * alpha / d2
                vx[i] += dx * f; vy[i] += dy * f
                vx[j] -= dx * f; vy[j] -= dy * f

                // Keep circles and their labels from overlapping.
                let minGap = radii[i] + radii[j] + 16
                if d2 < minGap * minGap {
                    let d = d2.squareRoot()
                    let push = (minGap - d) / d * 0.25
                    vx[i] -= dx * push; vy[i] -= dy * push
                    vx[j] += dx * push; vy[j] += dy * push
                }
            }
        }

        // Shared entries act like springs.
        let rest: CGFloat = 64
        for link in links {
            let dx = x[link.b] + vx[link.b] - x[link.a] - vx[link.a]
            let dy = y[link.b] + vy[link.b] - y[link.a] - vy[link.a]
            let d = max((dx * dx + dy * dy).squareRoot(), 1)
            let l = (d - rest) / d * alpha * link.strength
            vx[link.b] -= dx * l * 0.5; vy[link.b] -= dy * l * 0.5
            vx[link.a] += dx * l * 0.5; vy[link.a] += dy * l * 0.5
        }

        // A soft pull to the middle stops islands drifting away.
        for i in 0..<n {
            vx[i] -= x[i] * 0.06 * alpha
            vy[i] -= y[i] * 0.06 * alpha
        }

        for i in 0..<n {
            if i == pinned { vx[i] = 0; vy[i] = 0; continue }
            vx[i] *= 0.6; vy[i] *= 0.6
            x[i] += vx[i]; y[i] += vy[i]
        }

        if alpha < 0.004 && pinned == nil { settled = true }
    }

    // MARK: Dragging

    func grab(_ i: Int) {
        pinned = i
        alphaTarget = 0.25
        wake()
    }

    func move(_ i: Int, to point: CGPoint) {
        guard x.indices.contains(i) else { return }
        x[i] = point.x; y[i] = point.y
    }

    func release() {
        pinned = nil
        alphaTarget = 0
    }

    func wake() {
        alpha = max(alpha, 0.3)
        settled = false
    }

    /// Draw again without stirring the nodes, for panning and zooming.
    func redraw() {
        settled = false
    }

    // MARK: Camera

    func point(_ i: Int, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2 + (x[i] - centre.x) * fit * zoom + pan.width,
                y: size.height / 2 + (y[i] - centre.y) * fit * zoom + pan.height)
    }

    func world(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: (p.x - size.width / 2 - pan.width) / (fit * zoom) + centre.x,
                y: (p.y - size.height / 2 - pan.height) / (fit * zoom) + centre.y)
    }

    func radius(_ i: Int) -> CGFloat { radii[i] * max(0.8, min(zoom, 1.5)) }

    /// Eases the camera towards showing the whole graph, until you take over.
    func frame(_ size: CGSize) {
        guard followsGraph, !x.isEmpty else { return }
        let pad: CGFloat = 60
        let minX = x.min()! - pad, maxX = x.max()! + pad
        let minY = y.min()! - pad, maxY = y.max()! + pad
        let target = min(size.width / (maxX - minX), size.height / (maxY - minY), 2.2)
        fit += (target - fit) * 0.12
        centre.x += ((minX + maxX) / 2 - centre.x) * 0.12
        centre.y += ((minY + maxY) / 2 - centre.y) * 0.12
    }

    func hit(_ p: CGPoint, in size: CGSize) -> Int? {
        var best: (Int, CGFloat)?
        for i in x.indices {
            let c = point(i, in: size)
            let d = hypot(c.x - p.x, c.y - p.y)
            if d <= radius(i) + 16, d < (best?.1 ?? .infinity) { best = (i, d) }
        }
        return best?.0
    }
}
