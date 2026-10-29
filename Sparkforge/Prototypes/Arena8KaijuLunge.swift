// Forced kaiju action displacement for the opt-in six-room preview only.
#if DEBUG
import Foundation
import CoreGraphics

struct Arena8KaijuLunge {
    let map: Arena8GameMap

    func step(from: CGPoint, toward desired: CGPoint, radius: CGFloat) -> CGPoint {
        guard map.isSixRoom, from.x.isFinite, from.y.isFinite,
              desired.x.isFinite, desired.y.isFinite, radius.isFinite, radius >= 0,
              map.valid(from, radius: radius),
              let clipped = map.shove(from: from, toward: desired, radius: radius) else { return from }
        // Validate the representation SKNode actually stores, including the
        // full swept segment. Never project across a wall to a nearby room.
        let x = Float(clipped.x), y = Float(clipped.y)
        let stored = CGPoint(x: CGFloat(x), y: CGFloat(y))
        func legal(_ q: CGPoint) -> Bool {
            q.x.isFinite && q.y.isFinite && map.valid(q, radius: radius)
                && !map.geometry.segmentBlockedExact(from, q, travelRadius: radius)
        }
        if legal(stored) { return stored }
        let neighbors = [x.nextDown, x, x.nextUp].flatMap { a in
            [y.nextDown, y, y.nextUp].map { b in CGPoint(x: CGFloat(a), y: CGFloat(b)) }
        }
        return neighbors.filter { legal($0) }
            .min { $0.distance(to: clipped) < $1.distance(to: clipped) } ?? from
    }
}
#endif
