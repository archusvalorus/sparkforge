// Rolling ignores internal walls; only the outer rectangle retires it.
#if DEBUG
import Foundation
import CoreGraphics

struct Arena8PandaRollBounds {
    static func outside(_ point: CGPoint, world: CGRect, fraction: CGFloat) -> Bool {
        guard point.x.isFinite, point.y.isFinite,
              world.origin.x.isFinite, world.origin.y.isFinite,
              world.size.width.isFinite, world.size.height.isFinite,
              world.size.width > 0, world.size.height > 0,
              fraction.isFinite, fraction > 0, fraction <= 1 else { return true }
        let halfX = world.width * fraction / 2, halfY = world.height * fraction / 2
        let minX = world.midX - halfX, maxX = world.midX + halfX
        let minY = world.midY - halfY, maxY = world.midY + halfY
        guard minX.isFinite, maxX.isFinite, minY.isFinite, maxY.isFinite else { return true }
        // Equality stays in, matching the original circle's strict > test.
        return point.x < minX || point.x > maxX || point.y < minY || point.y > maxY
    }
}
#endif
