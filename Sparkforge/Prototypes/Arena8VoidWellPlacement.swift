// Six-room well births only; area, travel and wall policies stay unchanged.
#if DEBUG
import Foundation
import CoreGraphics

struct Arena8VoidWellPlacement {
    private let map: Arena8GameMap
    init?(map: Arena8GameMap) {
        guard map.isSixRoom else { return nil }
        self.map = map
    }

    func center(at point: CGPoint, wellRadius: CGFloat) -> CGPoint? {
        guard point.x.isFinite, point.y.isFinite,
              wellRadius.isFinite, wellRadius > 0 else { return nil }
        // The established contract uses HALF the initial well radius, not the
        // whole aura or a new wall-shadow rule for its growing effect.
        let clearance = wellRadius * 0.5
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
