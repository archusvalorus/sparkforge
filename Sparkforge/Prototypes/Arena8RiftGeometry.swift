// Six-room Rift origin/visual reach only. Sampling and combat stay unchanged.
#if DEBUG
import Foundation
import CoreGraphics

struct Arena8RiftGeometry {
    private let map: Arena8GameMap
    init?(map: Arena8GameMap) {
        guard map.isSixRoom else { return nil }
        self.map = map
    }

    func origin(at point: CGPoint) -> CGPoint? {
        let clearance: CGFloat = 16
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

    /// Preserve the old visual half-span when already longer. The furthest
    /// authored corner bounds every center-line projection onto a unit vector,
    /// so even off-center launches draw through the whole finite floor. This
    /// changes no damage width, length or wall interaction.
    func visualSpan(from origin: CGPoint, legacySpan: CGFloat) -> CGFloat? {
        guard origin.x.isFinite, origin.y.isFinite,
              legacySpan.isFinite, legacySpan > 0 else { return nil }
        let w = map.world
        let corners = [CGPoint(x:w.minX,y:w.minY), CGPoint(x:w.minX,y:w.maxY),
                       CGPoint(x:w.maxX,y:w.minY), CGPoint(x:w.maxX,y:w.maxY)]
        return max(legacySpan, corners.map { $0.distance(to: origin) }.max()!)
    }

}
#endif
