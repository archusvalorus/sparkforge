// G6: existing Tree moving summons in the six-room Debug preview only.
#if DEBUG
import Foundation
import CoreGraphics

struct Arena8SummonRules {
    private let map: Arena8GameMap

    init?(map: Arena8GameMap) {
        guard map.isSixRoom else { return nil }
        self.map = map
    }

    /// Closed outer rectangle: the historical boundary retains a payload
    /// exactly on its rim. Internal walls are not a flying cleanup boundary.
    fileprivate static func contains(_ point: CGPoint, in rect: CGRect) -> Bool {
        point.x.isFinite && point.y.isFinite
            && point.x >= rect.minX && point.x <= rect.maxX
            && point.y >= rect.minY && point.y <= rect.maxY
    }

    private func normalBounds(allowance: CGFloat) -> CGRect? {
        guard allowance.isFinite, allowance >= 0 else { return nil }
        let outer = map.world.insetBy(dx: -allowance, dy: -allowance)
        guard outer.minX.isFinite, outer.minY.isFinite,
              outer.maxX.isFinite, outer.maxY.isFinite else { return nil }
        return outer
    }

    func payloadOutside(_ point: CGPoint, allowance: CGFloat) -> Bool {
        guard let outer = normalBounds(allowance: allowance) else { return true }
        return !Self.contains(point, in: outer)
    }

    /// Capture once at launch. A valid Tree's tall canopy may begin outside
    /// the ordinary padded floor, so the approved entry envelope includes
    /// that birth point. It never follows Spark, Tree, target or camera.
    func payloadFlight(from birth: CGPoint, allowance: CGFloat) -> PayloadFlight? {
        guard birth.x.isFinite, birth.y.isFinite,
              let ordinary = normalBounds(allowance: allowance) else { return nil }
        return PayloadFlight(normalBounds: ordinary, birth: birth)
    }

    struct PayloadFlight {
        let normalBounds: CGRect
        let launchEnvelope: CGRect
        private(set) var enteredNormalBounds: Bool

        fileprivate init(normalBounds: CGRect, birth: CGPoint) {
            self.normalBounds = normalBounds
            let left = min(normalBounds.minX, birth.x)
            let bottom = min(normalBounds.minY, birth.y)
            launchEnvelope = CGRect(x: left, y: bottom,
                width: max(normalBounds.maxX, birth.x) - left,
                height: max(normalBounds.maxY, birth.y) - bottom)
            enteredNormalBounds = Arena8SummonRules.contains(birth, in: normalBounds)
        }

        /// The caller retires on true, using its original arrival/TTL paths.
        /// Entry permanently removes the launch exception; it never buys time.
        mutating func outsideAfterAdvance(to point: CGPoint) -> Bool {
            if Arena8SummonRules.contains(point, in: normalBounds) {
                enteredNormalBounds = true
                return false
            }
            return enteredNormalBounds || !Arena8SummonRules.contains(point, in: launchEnvelope)
        }
    }

    /// Keep the original canopy birth whenever it fits. If blocked, root the
    /// birth near the Tree instead of resolving from inside a solid wall.
    /// This selects a spawn point; it adds no stalking route or terrain rule.
    func lionSpawn(near root: CGPoint, canopyOffset: CGFloat,
                   bodyRadius: CGFloat) -> CGPoint? {
        guard root.x.isFinite, root.y.isFinite, canopyOffset.isFinite,
              bodyRadius.isFinite, bodyRadius >= 0,
              map.valid(root, radius: 0) else { return nil }
        let preferred = root + CGPoint(x: 0, y: canopyOffset)
        if map.valid(preferred, radius: bodyRadius) { return preferred }
        return Arena8GardenFootprint.placementRoot(in: map, toward: root, clearance: bodyRadius)
    }
}
#endif
