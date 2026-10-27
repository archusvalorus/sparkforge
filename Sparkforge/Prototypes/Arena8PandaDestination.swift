// Ordinary six-room Panda destinations only; arrivals, acts and rolls stay unchanged.
#if DEBUG
import Foundation
import CoreGraphics

struct Arena8PandaDestination {
    private let map: Arena8GameMap
    init?(map: Arena8GameMap) {
        guard map.isSixRoom else { return nil }
        self.map = map
    }

    func destination(at point: CGPoint) -> CGPoint? {
        let clearance: CGFloat = 20
        guard point.x.isFinite, point.y.isFinite else { return nil }
        guard let center = Arena8GardenFootprint.placementRoot(in: map, toward: point,
                                                              clearance: clearance) else { return nil }
        let x = Float(center.x), y = Float(center.y)
        let rounded = CGPoint(x: CGFloat(x), y: CGFloat(y))
        if map.valid(rounded, radius: clearance) { return center }
        // SKNode stores positions at Float precision. A mathematically safe
        // boundary can round outside a fractional iPad clearance. Choose only
        // among the immediately neighboring representable points, preserving
        // the nominal clearance instead of weakening geometry checks.
        let neighbors = [x.nextDown, x, x.nextUp].flatMap { a in
            [y.nextDown, y, y.nextUp].map { b in CGPoint(x: CGFloat(a), y: CGFloat(b)) }
        }
        return neighbors.filter { map.valid($0, radius: clearance) }
            .min { $0.distance(to: center) < $1.distance(to: center) }
    }

}
#endif
