// Six-room Growth contract only. No circle, two-room or production registration changes.
#if DEBUG
import Foundation
import CoreGraphics

struct Arena8GardenFootprint {
    let root: CGPoint
    let roomID: Int
    let maximumRadius: CGFloat
    /// World-space visibility boundary, shared by the crop mask and occupancy.
    let visibilityPolygon: [CGPoint]
    private let map: Arena8GameMap

    init?(map: Arena8GameMap, root: CGPoint, startingRadius: CGFloat) {
        guard map.isSixRoom, startingRadius.isFinite, startingRadius > 0,
              map.valid(root, radius: GameConfig.Growth.flowerRootMargin),
              let room = map.rooms.first(where: { $0.id == map.roomID(near: root) }),
              let polygon = Self.visibility(in: map, from: root) else { return nil }
        self.map = map
        self.root = root
        self.roomID = room.id
        // A room's half-short-side, not the entire floor or 0.55 of a room.
        // Never reduce an existing starting footprint to satisfy this new cap.
        maximumRadius = max(startingRadius, min(room.rect.width, room.rect.height) / 2)
        visibilityPolygon = polygon
    }

    func grownRadius(current: CGFloat, multiplier: CGFloat) -> CGFloat {
        guard current.isFinite, current > 0, multiplier.isFinite, multiplier >= 1 else { return current }
        return max(current, min(maximumRadius, current * multiplier))
    }

    /// The root stays put. Coverage can cross an open doorway along a clear
    /// chord, but does not bend around a corner or jump a solid wall.
    func visible(_ point: CGPoint) -> Bool {
        map.valid(point, radius: 0) && Self.contains(point, polygon: visibilityPolygon)
            && !map.geometry.segmentBlockedExact(root, point)
    }

    func covers(_ point: CGPoint, radius: CGFloat) -> Bool {
        radius.isFinite && radius > 0 && point.distance(to: root) < radius && visible(point)
    }

    func flowerPoint(radius: CGFloat, radialUnit: CGFloat, angularUnit: CGFloat,
                     margin: CGFloat) -> CGPoint? {
        guard radius.isFinite, radius > 0, radialUnit.isFinite, angularUnit.isFinite,
              (0...1).contains(radialUnit), (0...1).contains(angularUnit) else { return nil }
        let angle = angularUnit * 2 * CGFloat.pi
        let distance = radius * sqrt(radialUnit)
        let p = root + CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
        return map.valid(p, radius: margin) && covers(p, radius: radius) ? p : nil
    }

    /// Project the placement root onto authored floor with body clearance.
    /// This never uses the historical world-origin circle or an unsafe fallback.
    static func placementRoot(in map: Arena8GameMap, toward point: CGPoint,
                              clearance: CGFloat) -> CGPoint? {
        guard map.isSixRoom, point.x.isFinite, point.y.isFinite,
              clearance.isFinite, clearance >= 0 else { return nil }
        if map.valid(point, radius: clearance) { return point }
        var candidates: [CGPoint] = []
        if let bounded = map.bounds.clamped(point, bodyRadius: clearance) {
            let resolved = map.geometry.resolve(bounded, actorRadius: clearance)
            if map.valid(resolved, radius: clearance) { candidates.append(resolved) }
        }
        for rect in map.rooms.map(\.rect) + map.connections.map(\.corridor) {
            guard rect.width > 2 * clearance, rect.height > 2 * clearance else { continue }
            // A tiny inward allowance avoids ambiguous closed solid edges.
            let inset = rect.insetBy(dx: clearance + 0.000001, dy: clearance + 0.000001)
            let q = CGPoint(x: min(inset.maxX, max(inset.minX, point.x)),
                            y: min(inset.maxY, max(inset.minY, point.y)))
            if map.valid(q, radius: clearance) { candidates.append(q) }
        }
        return candidates.min { $0.distance(to: point) < $1.distance(to: point) }
    }

    private struct Segment { let a: CGPoint; let b: CGPoint }
    private static func cross(_ a: CGPoint, _ b: CGPoint) -> CGFloat { a.x * b.y - a.y * b.x }
    private static func edges(_ r: CGRect) -> [Segment] {
        let p = [CGPoint(x:r.minX,y:r.minY), CGPoint(x:r.maxX,y:r.minY),
                 CGPoint(x:r.maxX,y:r.maxY), CGPoint(x:r.minX,y:r.maxY)]
        return (0..<4).map { Segment(a:p[$0], b:p[($0 + 1) % 4]) }
    }
    private static func intersection(origin: CGPoint, direction: CGPoint, edge: Segment,
                                     limited: Bool) -> CGFloat? {
        let delta = edge.b - edge.a
        let denominator = cross(direction, delta)
        guard abs(denominator) > 0.000000000001 else { return nil }
        let offset = edge.a - origin
        let t = cross(offset, delta) / denominator
        let u = cross(offset, direction) / denominator
        guard t.isFinite, t >= 0, !limited || (u >= -0.000000001 && u <= 1.000000001) else { return nil }
        return t
    }

    /// Every angular interval between authored vertices has one nearest wall
    /// segment. Cast through its midpoint to choose that segment, then intersect
    /// both limiting rays with the same line. This preserves the exact radial
    /// shadow edges without an arbitrary ray count or +/- angle approximation.
    private static func visibility(in map: Arena8GameMap, from root: CGPoint) -> [CGPoint]? {
        guard map.geometry.blockedFootprints.allSatisfy({ $0.cornerRadius == 0 && $0.rotation == 0 }) else { return nil }
        let rectangles = [map.world] + map.geometry.blockedFootprints.map {
            CGRect(x:$0.center.x - $0.halfExtents.width, y:$0.center.y - $0.halfExtents.height,
                   width:2 * $0.halfExtents.width, height:2 * $0.halfExtents.height)
        }
        let segments = rectangles.flatMap { edges($0) }
        let angles = Array(Set(segments.flatMap { [$0.a, $0.b] }.map { atan2($0.y - root.y, $0.x - root.x) })).sorted()
        guard angles.count >= 3 else { return nil }
        var polygon: [CGPoint] = []
        for index in angles.indices {
            let lo = angles[index], hi = index + 1 < angles.count ? angles[index + 1] : angles[0] + 2 * .pi
            guard hi - lo > 0.000000000001 else { continue }
            let mid = (lo + hi) / 2, direction = CGPoint(x:cos(mid), y:sin(mid))
            let hits = segments.compactMap { edge -> (Segment, CGFloat)? in
                intersection(origin:root, direction:direction, edge:edge, limited:true).map { (edge, $0) }
            }
            guard let edge = hits.min(by: { $0.1 < $1.1 })?.0 else { return nil }
            for angle in [lo, hi] {
                let ray = CGPoint(x:cos(angle), y:sin(angle))
                guard let distance = intersection(origin:root, direction:ray, edge:edge, limited:false) else { return nil }
                let p = root + ray * distance
                guard p.x.isFinite, p.y.isFinite else { return nil }
                if polygon.last.map({ $0.distance(to:p) > 0.0000001 }) ?? true { polygon.append(p) }
            }
        }
        return polygon.count >= 3 ? polygon : nil
    }

    private static func contains(_ p: CGPoint, polygon: [CGPoint]) -> Bool {
        guard p.x.isFinite, p.y.isFinite else { return false }
        var inside = false
        for i in polygon.indices {
            let a = polygon[i], b = polygon[(i + 1) % polygon.count]
            let delta = b - a, offset = p - a
            if abs(cross(delta, offset)) < 0.0000001,
               p.x >= min(a.x,b.x) - 0.0000001, p.x <= max(a.x,b.x) + 0.0000001,
               p.y >= min(a.y,b.y) - 0.0000001, p.y <= max(a.y,b.y) + 0.0000001 { return true }
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x-a.x) * (p.y-a.y) / (b.y-a.y) + a.x { inside.toggle() }
        }
        return inside
    }
}
#endif
