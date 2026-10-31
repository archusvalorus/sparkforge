// Authored Debug floor. The committed two-room model remains an exact
// delegated control; six rooms use the same demonstrated bounds/geometry APIs.
#if DEBUG
import Foundation
import CoreGraphics

struct Arena8GameMap {
    struct Room {
        let id: Int
        let rect: CGRect
        var center: CGPoint { CGPoint(x: rect.midX, y: rect.midY) }
    }
    struct Connection {
        let from: Int
        let to: Int
        let corridor: CGRect
        var center: CGPoint { CGPoint(x: corridor.midX, y: corridor.midY) }
    }
    private let control: Arena8P0Model?
    let world: CGRect
    let rooms: [Room]
    let connections: [Connection]
    let geometry: ArenaGeometry
    let player: CGPoint
    var isSixRoom: Bool { control == nil }
    var bounds: Arena8P0Bounds { .rectangle(world) }

    static var twoRoom: Self {
        let old = Arena8P0Model()
        return Self(control: old, world: GameConfig.Arena8Prototype.world,
            rooms: [Room(id: 0, rect: CGRect(x: -420, y: -240, width: 320, height: 480)),
                    Room(id: 1, rect: CGRect(x: 100, y: -240, width: 320, height: 480))],
            connections: [Connection(from: 0, to: 1, corridor: CGRect(x: -100, y: -60, width: 200, height: 120))],
            geometry: old.geometry, player: old.player)
    }
    static var sixRoom: Self {
        typealias C = GameConfig.Arena8Game
        let half = C.roomSide / 2
        let rooms = C.rowCenters.enumerated().flatMap { row, y in
            C.columnCenters.enumerated().map { col, x in
                Room(id: row * C.columnCenters.count + col,
                    rect: CGRect(x: x - half, y: y - half, width: C.roomSide, height: C.roomSide))
            }
        }
        let pairs = [(0, 1), (1, 2), (3, 4), (4, 5), (0, 3), (1, 4), (2, 5)]
        let corridors = pairs.map { a, b -> Connection in
            let first = rooms[a], second = rooms[b]
            let rect: CGRect
            if first.center.y == second.center.y {
                rect = CGRect(x: first.rect.maxX, y: first.center.y - C.doorwayWidth / 2,
                              width: second.rect.minX - first.rect.maxX, height: C.doorwayWidth)
            } else {
                rect = CGRect(x: first.center.x - C.doorwayWidth / 2, y: second.rect.maxY,
                              width: C.doorwayWidth, height: first.rect.minY - second.rect.maxY)
            }
            return Connection(from: a, to: b, corridor: rect)
        }
        let world = rooms.reduce(CGRect.null) { $0.union($1.rect) }
        let walkable = rooms.map(\.rect) + corridors.map(\.corridor)
        let walls = wallComplement(of: walkable, in: world)
        let nodes = rooms.map { RouteNode(id: $0.id, position: $0.center, label: "room_\($0.id + 1)") }
            + corridors.enumerated().map { RouteNode(id: rooms.count + $0.offset, position: $0.element.center, label: "corridor_\($0.offset + 1)") }
        let edges = corridors.enumerated().flatMap { index, c in
            [RouteEdge(from: c.from, to: rooms.count + index), RouteEdge(from: rooms.count + index, to: c.to)]
        }
        let start = rooms[0].center
        let geo = ArenaGeometry(blockedFootprints: walls, routeNodes: nodes, routeEdges: edges,
            safeAnchors: [SafeAnchor(position: start, label: "player_fixture")], usesRouteGraph: true)
        return Self(control: nil, world: world, rooms: rooms, connections: corridors, geometry: geo, player: start)
    }

    /// Transitional shared rectangular adapters; a single open stage, no
    /// room cells or invented internal-wall layout. Ability coverage is gated
    /// separately from traversal and must not be inferred from this adapter.
    static func openStage(world rect: CGRect, start: CGPoint) -> Self {
        Self(control: nil, world: rect, rooms: [Room(id: 0, rect: rect)],
             connections: [], geometry: ArenaGeometry(), player: start)
    }

    /// Exact complement of these authored rectangles, not a random level
    /// generator. Merge adjacent empty cells into continuous wall rectangles.
    private static func wallComplement(of walkable: [CGRect], in world: CGRect) -> [Footprint] {
        let xs = Array(Set(walkable.flatMap { [$0.minX, $0.maxX] } + [world.minX, world.maxX])).sorted()
        let ys = Array(Set(walkable.flatMap { [$0.minY, $0.maxY] } + [world.minY, world.maxY])).sorted()
        var rectangles: [CGRect] = []
        for row in 0..<(ys.count - 1) {
            var col = 0
            while col < xs.count - 1 {
                let mid = CGPoint(x: (xs[col] + xs[col + 1]) / 2, y: (ys[row] + ys[row + 1]) / 2)
                if walkable.contains(where: { $0.contains(mid) }) { col += 1; continue }
                let start = col
                while col < xs.count - 1 {
                    let q = CGPoint(x: (xs[col] + xs[col + 1]) / 2, y: mid.y)
                    if walkable.contains(where: { $0.contains(q) }) { break }
                    col += 1
                }
                let cell = CGRect(x: xs[start], y: ys[row], width: xs[col] - xs[start], height: ys[row + 1] - ys[row])
                if let previous = rectangles.lastIndex(where: { $0.minX == cell.minX && $0.width == cell.width && $0.maxY == cell.minY }) {
                    rectangles[previous] = rectangles[previous].union(cell)
                } else { rectangles.append(cell) }
            }
        }
        return rectangles.enumerated().map { index, rect in
            Footprint(center: CGPoint(x: rect.midX, y: rect.midY), halfExtents: CGSize(width: rect.width / 2, height: rect.height / 2), cornerRadius: 0, label: "building_wall_\(index)")
        }
    }

    func roomID(near point: CGPoint) -> Int {
        if let room = rooms.first(where: { $0.rect.contains(point) }) { return room.id }
        return rooms.min { $0.center.distance(to: point) < $1.center.distance(to: point) }?.id ?? 0
    }
    /// Run at delayed Echo firing time. Unit perimeter distance gives equal
    /// weight per wall length, including exact corners; room ties keep the
    /// existing authored-order lookup. No world-circle or camera fallback.
    func echoOrigin(near point: CGPoint, perimeterUnit: CGFloat) -> CGPoint? {
        guard isSixRoom, point.x.isFinite, point.y.isFinite,
              perimeterUnit.isFinite, (0...1).contains(perimeterUnit),
              let room = rooms.first(where: { $0.id == roomID(near: point) }) else { return nil }
        let fraction = GameConfig.Arena8Game.echoEdgeFraction
        let rect = room.rect.insetBy(dx: room.rect.width * (1 - fraction) / 2,
                                     dy: room.rect.height * (1 - fraction) / 2)
        let distance = perimeterUnit * 2 * (rect.width + rect.height)
        let origin: CGPoint
        if distance < rect.width {
            origin = CGPoint(x: rect.minX + distance, y: rect.minY)
        } else if distance < rect.width + rect.height {
            origin = CGPoint(x: rect.maxX, y: rect.minY + distance - rect.width)
        } else if distance < 2 * rect.width + rect.height {
            origin = CGPoint(x: rect.maxX - (distance - rect.width - rect.height), y: rect.maxY)
        } else {
            origin = CGPoint(x: rect.minX, y: rect.maxY - (distance - 2 * rect.width - rect.height))
        }
        return valid(origin, radius: GameConfig.Arena8Game.echoOriginClearance) ? origin : nil
    }

    func neighborhood(near point: CGPoint) -> [Int] {
        let current = roomID(near: point)
        let adjacent = connections.compactMap { $0.from == current ? $0.to : ($0.to == current ? $0.from : nil) }.sorted()
        return [current] + adjacent
    }
    private func anchors(in id: Int) -> [CGPoint] {
        guard let room = rooms.first(where: { $0.id == id }) else { return [] }
        let d = GameConfig.Arena8Game.spawnAnchorOffset
        return [.zero, CGPoint(x: -d, y: -d), CGPoint(x: d, y: -d), CGPoint(x: -d, y: d), CGPoint(x: d, y: d)].map { room.center + $0 }
    }
    func spawnCandidates(near point: CGPoint) -> [CGPoint] {
        if !isSixRoom {
            return [-300.0, -200.0, 200.0, 300.0].flatMap { x in [-160.0, 0, 160.0].map { CGPoint(x: x, y: $0) } }
        }
        return neighborhood(near: point).flatMap { anchors(in: $0) }
    }
    func pickupCandidates(near point: CGPoint) -> [CGPoint] {
        guard isSixRoom else { return spawnCandidates(near: point) }
        return anchors(in: roomID(near: point)).sorted { $0.distance(to: point) > $1.distance(to: point) }
    }
    func valid(_ point: CGPoint, radius: CGFloat) -> Bool {
        if let control { return control.valid(point, radius: radius) }
        return bounds.contains(point, bodyRadius: radius) && !geometry.isBlocked(point, margin: radius)
    }
    private func walkingSweep(from: CGPoint, to: CGPoint, radius: CGFloat) -> CGPoint {
        let delta = to - from
        let obstacles = geometry.blockedFootprints.filter { f in
            let nearest = CGPoint(x: min(f.center.x + f.halfExtents.width, max(f.center.x - f.halfExtents.width, from.x)),
                                  y: min(f.center.y + f.halfExtents.height, max(f.center.y - f.halfExtents.height, from.y)))
            let normal = (from - nearest).normalized
            guard normal.length > 0 else { return true }
            return delta.x * normal.x + delta.y * normal.y < 0
        }
        return ArenaGeometry(blockedFootprints: obstacles).pathShove(from: from, to: to, radius: radius)
    }
    /// Match the Float representation SKNode stores, using the same nearest
    /// neighboring representable-point rule as existing Sentry/Kaiju roots.
    /// A candidate must retain full body clearance AND the caller's approved
    /// swept path; no radius/tolerance relaxation or across-wall projection.
    private func storedSafeEnd(_ point: CGPoint, radius: CGFloat,
                               reachable: (CGPoint) -> Bool) -> CGPoint? {
        guard valid(point, radius: radius) else { return nil }
        let x = Float(point.x), y = Float(point.y)
        guard x.isFinite, y.isFinite else { return nil }
        let stored = CGPoint(x: CGFloat(x), y: CGFloat(y))
        if stored == point { return point } // Already the validated endpoint.
        func legal(_ q: CGPoint) -> Bool { valid(q, radius: radius) && reachable(q) }
        if legal(stored) { return point } // Preserve existing raw API result.
        let neighbors = [x.nextDown, x, x.nextUp].flatMap { a in
            [y.nextDown, y, y.nextUp].map { b in CGPoint(x: CGFloat(a), y: CGFloat(b)) }
        }
        return neighbors.filter { legal($0) }
            .min { $0.distance(to: point) < $1.distance(to: point) }
    }

    func move(from: CGPoint, toward desired: CGPoint, radius: CGFloat) -> CGPoint? {
        if let control { return control.move(from: from, toward: desired, radius: radius) }
        guard valid(from, radius: radius), let end = bounds.clamped(desired, bodyRadius: radius) else { return nil }
        let x = walkingSweep(from: from, to: CGPoint(x: end.x, y: from.y), radius: radius)
        let result = walkingSweep(from: x, to: CGPoint(x: x.x, y: end.y), radius: radius)
        return storedSafeEnd(result, radius: radius) { q in
            // Retain the existing X-then-Y face-slide path, rather than
            // replacing ordinary walking with a straight diagonal shove.
            let first = walkingSweep(from: from, to: CGPoint(x: q.x, y: from.y), radius: radius)
            let last = walkingSweep(from: first, to: CGPoint(x: first.x, y: q.y), radius: radius)
            return last == q
        }
    }
    func shove(from: CGPoint, toward desired: CGPoint, radius: CGFloat) -> CGPoint? {
        if let control { return control.shove(from: from, toward: desired, radius: radius) }
        guard valid(from, radius: radius), let end = bounds.clamped(desired, bodyRadius: radius) else { return nil }
        let stopped = geometry.pathShove(from: from, to: end, radius: radius)
        return storedSafeEnd(stopped, radius: radius) { q in
            geometry.pathShove(from: from, to: q, radius: radius) == q
        }
    }
    func approach(_ goal: CGPoint, radius: CGFloat) -> CGPoint? {
        if let control { return control.approach(goal, radius: radius) }
        guard bounds.contains(goal), !geometry.isBlocked(goal) else { return nil }
        if valid(goal, radius: radius) { return goal }
        let margin = radius + GameConfig.Arena8Prototype.approachClearance
        guard let contained = bounds.clamped(goal, bodyRadius: margin) else { return nil }
        let q = geometry.resolve(contained, actorRadius: margin)
        return valid(q, radius: radius) ? q : nil
    }
    func spawn(candidates: [CGPoint], radius: CGFloat, avoiding point: CGPoint, clearance: CGFloat) -> CGPoint? {
        if let control { return control.spawn(candidates: candidates, radius: radius, avoiding: point, clearance: clearance) }
        return candidates.first { valid($0, radius: radius) && $0.distance(to: point) >= clearance + radius }
    }
}
#endif
