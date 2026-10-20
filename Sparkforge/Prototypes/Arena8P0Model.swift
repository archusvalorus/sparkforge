// Isolated two-room proof; no registry, production AI/combat or save caller.
#if DEBUG
import Foundation
import CoreGraphics

struct Arena8P0Model {
    typealias C = GameConfig.Arena8Prototype
    let bounds = Arena8P0Bounds.rectangle(C.world)
    let geometry: ArenaGeometry
    var player = CGPoint(x: -280, y: 150)
    var enemies = [CGPoint(x: 280, y: 150), CGPoint(x: 300, y: -130), CGPoint(x: 240, y: 0)]
    var held = false
    var longShot = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var shotAge: TimeInterval = 0
    private(set) var lastShotClear = false
    private(set) var shotCount = 0
    private(set) var lastShotFrom: CGPoint?
    private(set) var lastShotEnd: CGPoint?

    init() {
        let voidHeight = (C.world.height / 2 - C.doorwayHalfHeight) / 2
        let voidY = C.doorwayHalfHeight + voidHeight
        let solids = [-voidY, voidY].map { y in
            Footprint(center: CGPoint(x: 0, y: y), halfExtents: CGSize(width: C.roomHalfWidth, height: voidHeight),
                      cornerRadius: 0, label: y < 0 ? "south_wall_block" : "north_wall_block")
        }
        let xs: [CGFloat] = [-280, -140, 0, 140, 280]
        let nodes = xs.enumerated().map { RouteNode(id: $0.offset, position: CGPoint(x: $0.element, y: 0), label: "door_route_\($0.offset)") }
        geometry = ArenaGeometry(blockedFootprints: solids, routeNodes: nodes,
            routeEdges: (0..<4).map { RouteEdge(from: $0, to: $0 + 1) },
            safeAnchors: [SafeAnchor(position: CGPoint(x: -280, y: 150), label: "player_fixture"),
                          SafeAnchor(position: CGPoint(x: 280, y: 150), label: "enemy_fixture")], usesRouteGraph: true)
    }

    func valid(_ point: CGPoint, radius: CGFloat) -> Bool {
        bounds.contains(point, bodyRadius: radius) && !geometry.isBlocked(point, margin: radius)
    }

    /// For the fixture's axis-aligned boxes, a supporting plane proves an
    /// outward/tangent walking segment cannot penetrate that wall. Excluding
    /// only those walls lets exact body contact slide/escape instead of the
    /// closed-segment query treating its initial touch as an obstruction.
    private func walkingSweep(from: CGPoint, to: CGPoint, radius: CGFloat) -> CGPoint {
        let delta = to - from
        let obstacles = geometry.blockedFootprints.filter { f in
            guard f.rotation == 0, f.cornerRadius == 0 else { return true }
            let nearest = CGPoint(x: min(f.center.x + f.halfExtents.width, max(f.center.x - f.halfExtents.width, from.x)),
                                  y: min(f.center.y + f.halfExtents.height, max(f.center.y - f.halfExtents.height, from.y)))
            let normal = (from - nearest).normalized
            guard normal.length > 0 else { return true }
            return delta.x * normal.x + delta.y * normal.y < 0
        }
        return ArenaGeometry(blockedFootprints: obstacles).pathShove(from: from, to: to, radius: radius)
    }

    /// Axis sweeps preserve sliding without endpoint tunneling. Every axis
    /// uses the existing exact path-shove seam, then validates the result.
    /// Invalid starts/candidates return nil; there is no unsafe teleport.
    func move(from: CGPoint, toward desired: CGPoint, radius: CGFloat) -> CGPoint? {
        guard valid(from, radius: radius), let end = bounds.clamped(desired, bodyRadius: radius) else { return nil }
        let x = walkingSweep(from: from, to: CGPoint(x: end.x, y: from.y), radius: radius)
        let result = walkingSweep(from: x, to: CGPoint(x: x.x, y: end.y), radius: radius)
        return valid(result, radius: radius) ? result : nil
    }

    /// Straight forced displacement keeps the existing stop-before-wall
    /// contract. It does not use the L-shaped walking slide path.
    func shove(from: CGPoint, toward desired: CGPoint, radius: CGFloat) -> CGPoint? {
        guard valid(from, radius: radius), let end = bounds.clamped(desired, bodyRadius: radius) else { return nil }
        let stopped = geometry.pathShove(from: from, to: end, radius: radius)
        return valid(stopped, radius: radius) ? stopped : nil
    }

    /// Fixture pursuit approaches a small player's wall-adjacent center via
    /// a validated body-clear point; it never teleports the chasing actor.
    /// This is not an integration/change to production enemy behavior.
    func approach(_ goal: CGPoint, radius: CGFloat) -> CGPoint? {
        guard bounds.contains(goal), !geometry.isBlocked(goal) else { return nil }
        if valid(goal, radius: radius) { return goal }
        guard let contained = bounds.clamped(goal, bodyRadius: radius + C.approachClearance) else { return nil }
        let clear = geometry.resolve(contained, actorRadius: radius + C.approachClearance)
        return valid(clear, radius: radius) ? clear : nil
    }

    func chase(from: CGPoint, goal: CGPoint, radius: CGFloat, dt: TimeInterval) -> CGPoint? {
        guard valid(from, radius: radius), let goal = approach(goal, radius: radius), dt.isFinite, dt >= 0 else { return nil }
        let next: CGPoint
        if !geometry.segmentBlockedExact(from, goal, travelRadius: radius) { next = goal }
        else if let waypoint = geometry.graphWaypoint(from: from, toward: goal, travelRadius: radius, arriveRadius: C.arrival) {
            next = waypoint.position
        } else { return nil }
        let distance = min(C.enemySpeed * CGFloat(min(dt, C.maximumStep)), from.distance(to: next))
        return move(from: from, toward: from + (next - from).normalized * distance, radius: radius)
    }

    func spawn(candidates: [CGPoint], radius: CGFloat, avoiding point: CGPoint, clearance: CGFloat) -> CGPoint? {
        candidates.first { valid($0, radius: radius) && $0.distance(to: point) >= clearance + radius }
    }

    func shotClear(from: CGPoint, to: CGPoint, longShot: Bool) -> Bool {
        guard bounds.contains(from), bounds.contains(to) else { return false }
        return longShot || !geometry.segmentBlockedExact(from, to)
    }

    func projectileAlive(_ point: CGPoint) -> Bool {
        Arena8P0Bounds.rectangle(C.world.insetBy(dx: -C.projectileMargin, dy: -C.projectileMargin)).contains(point)
    }

    mutating func step(_ raw: TimeInterval, direction: CGPoint) {
        guard !held, raw.isFinite, raw > 0 else { return }
        let dt = min(raw, C.maximumStep)
        elapsed += dt
        if let moved = move(from: player, toward: player + direction * (C.playerSpeed * CGFloat(dt)), radius: C.playerRadius) { player = moved }
        for i in enemies.indices {
            if let moved = chase(from: enemies[i], goal: player, radius: C.enemyRadii[i], dt: dt) { enemies[i] = moved }
        }
        shotAge += dt
        if shotAge >= C.shotEvery {
            shotAge -= C.shotEvery
            shotCount += 1
            let target = CGPoint(x: 280, y: 150)
            lastShotClear = shotClear(from: player, to: target, longShot: longShot)
            lastShotFrom = player
            lastShotEnd = longShot ? target : geometry.pathShove(from: player, to: target, radius: 0)
        }
    }
}
#endif
