// ArenaGeometry.swift
// Sparkforge
//
// v2.1 (Geometry Unit 1A) — the arena geometry contract.
//
// Locked in docs/arena6-geometry-reconciliation.md §4: ONE authored convex
// rounded-rect footprint per blocked region, enforced by MANUAL DISPLACEMENT
// (the monument-boss house pattern — see MonumentBossNode's rationale), never
// the SpriteKit collision solver. No navmesh, no GameplayKit, no polygon
// meshes. Sparkforge has no solver collision anywhere; this file keeps it
// that way and gives the whole engine one place to ask three questions:
//
//   • is this point inside solid geometry (with a margin)?
//   • where should this actor stand instead?
//   • does this segment cross solid geometry?
//
// The Fallen Carrier (Arena 6) is the first consumer, not the architecture.
// The API takes an ARRAY of footprints so The Twin Channels / Lockworks can
// inherit it, but everything is proven on the one-footprint case.
//
// Compatibility principle (reconciliation §7.1): OPEN ARENAS BEHAVE AS
// BEFORE. With no footprints, every query short-circuits to "clear" and every
// resolve returns its input — arenas 1–5 pay nothing and change nothing.

import CoreGraphics
import Foundation

// MARK: - Footprint

/// A convex rounded rectangle in world space. Rotation is about `center`,
/// counter-clockwise, radians. `halfExtents` describes the CORE rectangle;
/// `cornerRadius` is padding around it (so the true half-size is
/// halfExtents + cornerRadius on each axis). Slightly off-center, asymmetric,
/// tilted — all expressible; the math stays a handful of FLOPs.
struct Footprint {
    let center: CGPoint
    let halfExtents: CGSize
    let cornerRadius: CGFloat
    let rotation: CGFloat
    /// Optional debug/telemetry label ("fallen_carrier").
    let label: String

    init(center: CGPoint, halfExtents: CGSize, cornerRadius: CGFloat,
         rotation: CGFloat = 0, label: String = "") {
        self.center = center
        self.halfExtents = halfExtents
        self.cornerRadius = cornerRadius
        self.rotation = rotation
        self.label = label
    }

    /// Bounding-circle radius — the cheap reject before any real test.
    var boundingRadius: CGFloat {
        CGPoint(x: halfExtents.width + cornerRadius,
                y: halfExtents.height + cornerRadius).length
    }

    /// Signed distance from `p` to the footprint surface. Negative = inside.
    /// Standard rounded-box SDF in the footprint's local frame.
    func signedDistance(to p: CGPoint) -> CGFloat {
        let local = (p - center).rotated(by: -rotation)
        let q = CGPoint(x: abs(local.x) - halfExtents.width,
                        y: abs(local.y) - halfExtents.height)
        let outside = CGPoint(x: max(q.x, 0), y: max(q.y, 0)).length
        let inside = min(max(q.x, q.y), 0)
        return outside + inside - cornerRadius
    }

    /// Outward surface normal at (or nearest to) `p`. Dead-centre is
    /// degenerate; that case is handled by `resolve` (pushes toward the
    /// arena's play space, never through the far side).
    func normal(at p: CGPoint) -> CGPoint {
        // Numerical gradient of the SDF — cheap and exact enough for a
        // resolve step; avoids per-edge case analysis.
        let e: CGFloat = 0.5
        let dx = signedDistance(to: CGPoint(x: p.x + e, y: p.y)) - signedDistance(to: CGPoint(x: p.x - e, y: p.y))
        let dy = signedDistance(to: CGPoint(x: p.x, y: p.y + e)) - signedDistance(to: CGPoint(x: p.x, y: p.y - e))
        return CGPoint(x: dx, y: dy).normalized
    }

    /// True if `p` lies inside the footprint expanded by `margin`.
    func contains(_ p: CGPoint, margin: CGFloat = 0) -> Bool {
        // Cheap reject: bounding circle.
        if p.distance(to: center) > boundingRadius + margin { return false }
        return signedDistance(to: p) < margin
    }

    /// The nearest valid position for an actor of `actorRadius` centred at
    /// `p`. Returns `p` unchanged when already valid.
    func resolve(_ p: CGPoint, actorRadius: CGFloat) -> CGPoint {
        var q = p
        // A rounded-box SDF is exact OUTSIDE (one step lands on the surface)
        // but only a lower bound INSIDE (interior corner regions bend the
        // gradient), so a single push undershoots from deep within. Iterate:
        // each step lands closer, and it converges in 2–3 rounds for anything
        // the game can produce (an actor is never deeper than the half-width).
        for _ in 0..<4 {
            let d = signedDistance(to: q)
            if d >= actorRadius - 0.01 { return q }
            var n = normal(at: q)
            if n == .zero {
                // Exact dead centre of a square-ish footprint — a true
                // saddle. Push out along the footprint's short axis, biased
                // toward the arena's play space (down), like the monument.
                n = CGPoint(x: 0, y: -1).rotated(by: rotation)
            }
            q = q + n * (actorRadius - d)
        }
        return q
    }

    /// Does the swept segment a→b (thickened by `travelRadius`) cross the
    /// footprint? Conservative march at a step ≤ min half-extent, which is
    /// tunneling-safe for anything the game fires today (Star Needle dash
    /// 640pt/s, XP vacuum 700pt/s at 60fps = ~12pt/frame).
    func intersectsSegment(_ a: CGPoint, _ b: CGPoint, travelRadius: CGFloat = 0) -> Bool {
        // Cheap reject: segment's bounding circle vs footprint's.
        let mid = a.lerp(to: b, t: 0.5)
        let segHalf = a.distance(to: b) / 2
        if mid.distance(to: center) > boundingRadius + segHalf + travelRadius { return false }

        let minHalf = max(4, min(halfExtents.width, halfExtents.height) + cornerRadius)
        let steps = max(1, Int(ceil(a.distance(to: b) / minHalf)))
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            if contains(a.lerp(to: b, t: t), margin: travelRadius) { return true }
        }
        return false
    }
}

// MARK: - Route graph (data only in 1A — behavior lands in 1B)

struct RouteNode {
    let id: Int
    let position: CGPoint
    /// "narrow", "broad", "merge_n", … — for debug overlay + telemetry.
    let label: String
}

struct RouteEdge {
    let from: Int
    let to: Int
}

// MARK: - Spawn zones + anchors

/// An authored spawn region: an arc of the arena rim (angles in radians,
/// counter-clockwise from +x) with an optional gate label for the
/// Marchwarden's Muster Signal and the overlay.
struct SpawnZone {
    let startAngle: CGFloat
    let endAngle: CGFloat
    let label: String
}

/// A guaranteed-valid authored point: the player's Boss-Mode swap anchor,
/// the boss anchor, a fallback for pickups when sampling fails.
struct SafeAnchor {
    let position: CGPoint
    let label: String
}

// MARK: - ArenaGeometry

/// Everything an arena declares about its shape beyond the circle. Every
/// field defaults to empty, which is exactly "an open circular arena" — the
/// five shipped arenas use `.open` and behave as before.
struct ArenaGeometry {
    var blockedFootprints: [Footprint] = []
    var routeNodes: [RouteNode] = []
    var routeEdges: [RouteEdge] = []
    var spawnZones: [SpawnZone] = []
    var safeAnchors: [SafeAnchor] = []

    static let open = ArenaGeometry()

    var hasBlockedGeometry: Bool { !blockedFootprints.isEmpty }

    // MARK: Queries — every one short-circuits when there is no geometry.

    /// Is `p` inside ANY blocked footprint (expanded by `margin`)?
    func isBlocked(_ p: CGPoint, margin: CGFloat = 0) -> Bool {
        guard hasBlockedGeometry else { return false }
        return blockedFootprints.contains { $0.contains(p, margin: margin) }
    }

    /// Nearest valid position for an actor of `actorRadius` at `p`. With
    /// several footprints this resolves against each in turn (adequate for
    /// the authored, non-overlapping layouts the arc will use).
    func resolve(_ p: CGPoint, actorRadius: CGFloat) -> CGPoint {
        guard hasBlockedGeometry else { return p }
        var q = p
        for f in blockedFootprints { q = f.resolve(q, actorRadius: actorRadius) }
        return q
    }

    /// Does the swept segment cross any blocked footprint?
    func segmentBlocked(_ a: CGPoint, _ b: CGPoint, travelRadius: CGFloat = 0) -> Bool {
        guard hasBlockedGeometry else { return false }
        return blockedFootprints.contains { $0.intersectsSegment(a, b, travelRadius: travelRadius) }
    }

    /// v2.1 A4c (CL-38): the EXACT version, for short direct attacks (Red
    /// Smile's sweep). `segmentBlocked` marches at the footprint's
    /// half-thickness — right for per-frame motion, but a segment shorter than
    /// that is only tested at its endpoints and can pass a rounded corner
    /// unblocked. This one measures the segment's true distance to each box.
    func segmentBlockedExact(_ a: CGPoint, _ b: CGPoint, travelRadius: CGFloat = 0) -> Bool {
        guard hasBlockedGeometry else { return false }
        return blockedFootprints.contains {
            MeleeSector.segmentCrossesRoundedBox(a, b, center: $0.center, halfExtents: $0.halfExtents,
                                                 cornerRadius: $0.cornerRadius, rotation: $0.rotation,
                                                 margin: travelRadius)
        }
    }

    /// The safe anchor with this label, if authored.
    func anchor(_ label: String) -> CGPoint? {
        safeAnchors.first { $0.label == label }?.position
    }
}

// MARK: - Shared placement sampler

/// v2.1 (1A): THE one way to pick a random world point that must not land in
/// solid geometry. Replaces ~15 copy-pasted polar samplers for interior
/// placements (pickups, wells, rift origins, panda destinations…). Rim spawns
/// (outside the arena) don't need it — they're never inside a footprint.
///
/// Semantics: uniform-by-area in the annulus `minR...maxR`, rejecting points
/// within `margin` of blocked geometry. Falls back to the nearest valid
/// resolve of the last candidate so a caller ALWAYS gets a usable point —
/// never a nil that leaves a health orb unspawned. Rejections are counted for
/// the debug overlay / telemetry.
enum PlacementSampler {
    /// Debug/telemetry: rejections since the counter was last read.
    static private(set) var rejectionCount = 0
    static func resetRejectionCount() { rejectionCount = 0 }

    static func randomPoint(in geometry: ArenaGeometry,
                            minRadius: CGFloat, maxRadius: CGFloat,
                            margin: CGFloat, attempts: Int = 12) -> CGPoint {
        let lo = max(0, minRadius), hi = max(lo + 1, maxRadius)
        var last = CGPoint.zero
        for _ in 0..<attempts {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            // sqrt for area-uniform distribution (not radius-uniform).
            let r = sqrt(CGFloat.random(in: (lo * lo)...(hi * hi)))
            last = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if !geometry.isBlocked(last, margin: margin) { return last }
            rejectionCount += 1
        }
        // Give up gracefully: resolve the last candidate out of the geometry.
        return geometry.resolve(last, actorRadius: margin)
    }
}

// MARK: - Authored layouts

extension ArenaGeometry {
    /// v2.1 (1A): The Splitworks. One footprint — the Fallen Carrier — as an
    /// asymmetric, slightly off-centre, tilted rounded rect making a NARROW
    /// route (right/east side) and a BROAD route (left/west side) with two
    /// merge spaces at the top and bottom of the field. All dimensions are
    /// fractions of the arena radius so it survives device scaling and the
    /// 1.15 radiusScale. The lock (§4) targets a carrier footprint of ~1/3 of
    /// the usable arena length; nothing here is final until Brandon walks it.
    ///
    /// Route nodes/edges are AUTHORED DATA ONLY in 1A — no behavior consumes
    /// them until Unit 1B. They exist now so the overlay can draw them and
    /// the shell can be tuned with the graph visible.
    static var splitworks: ArenaGeometry {
        let r = GameConfig.Arena.radius
        // Fallen Carrier: long axis roughly north-south, tilted ~12°, nudged
        // east so the east passage is the NARROW one.
        let carrier = Footprint(
            center: CGPoint(x: r * 0.10, y: r * 0.04),
            halfExtents: CGSize(width: r * 0.16, height: r * 0.34),
            cornerRadius: r * 0.06,
            rotation: -0.21,
            label: "fallen_carrier")

        // Waypoints: south merge → (narrow | broad) → north merge.
        let nodes = [
            RouteNode(id: 0, position: CGPoint(x: 0,        y: -r * 0.66), label: "merge_s"),
            RouteNode(id: 1, position: CGPoint(x: r * 0.52, y: -r * 0.28), label: "narrow_s"),
            RouteNode(id: 2, position: CGPoint(x: r * 0.56, y:  r * 0.30), label: "narrow_n"),
            RouteNode(id: 3, position: CGPoint(x: -r * 0.48, y: -r * 0.30), label: "broad_s"),
            RouteNode(id: 4, position: CGPoint(x: -r * 0.52, y:  r * 0.30), label: "broad_n"),
            RouteNode(id: 5, position: CGPoint(x: 0,        y:  r * 0.68), label: "merge_n"),
        ]
        let edges = [
            RouteEdge(from: 0, to: 1), RouteEdge(from: 1, to: 2), RouteEdge(from: 2, to: 5),
            RouteEdge(from: 0, to: 3), RouteEdge(from: 3, to: 4), RouteEdge(from: 4, to: 5),
        ]
        // Deployment gates: outer wall arcs the Muster Signal (Unit 3) can name.
        let zones = [
            SpawnZone(startAngle: .pi * 0.35, endAngle: .pi * 0.65, label: "gate_n"),
            SpawnZone(startAngle: .pi * 1.35, endAngle: .pi * 1.65, label: "gate_s"),
            SpawnZone(startAngle: .pi * 0.85, endAngle: .pi * 1.15, label: "gate_w"),
            SpawnZone(startAngle: -.pi * 0.15, endAngle: .pi * 0.15, label: "gate_e"),
        ]
        let anchors = [
            SafeAnchor(position: CGPoint(x: 0, y: -r * 0.66), label: "player_spawn"),
            SafeAnchor(position: CGPoint(x: 0, y:  r * 0.68), label: "boss_anchor"),
        ]
        return ArenaGeometry(blockedFootprints: [carrier], routeNodes: nodes,
                             routeEdges: edges, spawnZones: zones, safeAnchors: anchors)
    }
}

// MARK: - Route guidance lookups (Unit 1B)

extension ArenaGeometry {
    func node(_ id: Int) -> RouteNode? { routeNodes.first { $0.id == id } }
    /// Adjacency (edges are undirected). Unused by the 1B greedy chooser —
    /// kept for the overlay and for 1C+ congestion weighting.
    func neighbors(of id: Int) -> [Int] {
        routeEdges.compactMap { $0.from == id ? $0.to : ($0.to == id ? $0.from : nil) }
    }
}
