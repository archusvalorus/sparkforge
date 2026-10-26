// Six-room coil roots only. Targeting, damage, cadence and walls stay unchanged.
#if DEBUG
import Foundation
import CoreGraphics

struct Arena8SentryPlacement {
    private let map: Arena8GameMap
    init?(map: Arena8GameMap) {
        guard map.isSixRoom else { return nil }
        self.map = map
    }

    func center(at point: CGPoint, clearance: CGFloat) -> CGPoint? {
        guard point.x.isFinite, point.y.isFinite,
              clearance.isFinite, clearance > 0 else { return nil }
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
    func nearSpark(existing: [CGPoint], spacing: CGFloat,
                   nextCandidate: () -> CGPoint) -> CGPoint? {
        guard spacing.isFinite, spacing >= 0 else { return nil }
        var last = CGPoint.zero
        for _ in 0..<16 {
            last = nextCandidate()
            guard last.x.isFinite, last.y.isFinite else { continue }
            if map.valid(last, radius: 16),
               !existing.contains(where: { $0.distance(to: last) < spacing }),
               let stored = center(at: last, clearance: 16),
               !existing.contains(where: { $0.distance(to: CGPoint(x: CGFloat(Float(stored.x)), y: CGFloat(Float(stored.y)))) < spacing }) {
                return stored
            }
        }
        // As in the circle path, spacing is best-effort after sixteen attempts.
        // Geometry safety is mandatory, including the actual SKNode Float root.
        return center(at: last, clearance: 16)
    }

}
#endif
