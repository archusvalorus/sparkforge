// Panda spectacle may cross geometry; persistent grounded enemy endpoints may not.
#if DEBUG
import Foundation
import CoreGraphics

struct Arena8PandaEndpoints {
    private let map: Arena8GameMap
    init?(map: Arena8GameMap) {
        guard map.isSixRoom else { return nil }
        self.map = map
    }

    func resolved(from previous: CGPoint, toward desired: CGPoint, radius: CGFloat) -> CGPoint? {
        guard radius.isFinite, radius > 0, previous.x.isFinite, previous.y.isFinite,
              map.valid(previous, radius: radius) else { return nil }
        guard desired.x.isFinite, desired.y.isFinite else { return previous }
        // This is endpoint safety, not a travel-occlusion or pathfinding rule.
        return Arena8GardenFootprint.placementRoot(in: map, toward: desired, clearance: radius) ?? previous
    }
}
#endif
