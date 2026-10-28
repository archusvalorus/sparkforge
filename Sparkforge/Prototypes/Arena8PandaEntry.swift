// Same random-angle approach, mapped to the authored building rim.
#if DEBUG
import Foundation
import CoreGraphics

struct Arena8PandaEntry {
    static func entry(in world: CGRect, angle: CGFloat, rimFraction: CGFloat) -> CGPoint? {
        guard world.origin.x.isFinite, world.origin.y.isFinite,
              world.size.width.isFinite, world.size.height.isFinite,
              world.size.width > 0, world.size.height > 0,
              angle.isFinite, rimFraction.isFinite,
              rimFraction > 0, rimFraction <= 1 else { return nil }
        let x = cos(angle), y = sin(angle)
        let halfX = world.width * rimFraction / 2
        let halfY = world.height * rimFraction / 2
        let tx = x == 0 ? CGFloat.infinity : halfX / abs(x)
        let ty = y == 0 ? CGFloat.infinity : halfY / abs(y)
        let distance = min(tx, ty)
        let point = CGPoint(x: world.midX + x * distance,
                            y: world.midY + y * distance)
        guard point.x.isFinite, point.y.isFinite else { return nil }
        return point
    }
}
#endif
