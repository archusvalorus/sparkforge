// Rectangle-only foundation; internal solids/routing remain ArenaGeometry's job.
import Foundation
import CoreGraphics

struct Arena9StageBounds {
    let definition: Arena9StageDefinition

    /// Safe outer-boundary clamp, not a swept-wall movement adapter.
    func clamped(_ point: CGPoint, bodyRadius: CGFloat) -> CGPoint? {
        let world = definition.world
        guard Arena9StageDefinition.finite(point), bodyRadius.isFinite, bodyRadius >= 0,
              bodyRadius <= world.width / 2, bodyRadius <= world.height / 2 else { return nil }
        return CGPoint(x: min(world.maxX - bodyRadius, max(world.minX + bodyRadius, point.x)),
                       y: min(world.maxY - bodyRadius, max(world.minY + bodyRadius, point.y)))
    }

    func contains(_ point: CGPoint, bodyRadius: CGFloat) -> Bool {
        guard let projected = clamped(point, bodyRadius: bodyRadius) else { return false }
        return projected == point
    }

    /// Camera can follow in either direction. It never enforces a retreat rule.
    /// An oversized viewport is centered on that axis; visibleFootprint clips it.
    func cameraCenter(following point: CGPoint, viewport: CGSize) -> CGPoint? {
        guard Arena9StageDefinition.finite(point), viewport.width.isFinite, viewport.height.isFinite,
              viewport.width > 0, viewport.height > 0 else { return nil }
        let world = definition.world
        func axis(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat, _ size: CGFloat) -> CGFloat {
            if size >= high - low { return low + (high - low) / 2 }
            return min(high - size / 2, max(low + size / 2, value))
        }
        return CGPoint(x: axis(point.x, world.minX, world.maxX, viewport.width),
                       y: axis(point.y, world.minY, world.maxY, viewport.height))
    }

    func visibleFootprint(following point: CGPoint, viewport: CGSize) -> CGRect? {
        guard let center = cameraCenter(following: point, viewport: viewport) else { return nil }
        let proposed = CGRect(x: center.x - viewport.width / 2, y: center.y - viewport.height / 2,
                              width: viewport.width, height: viewport.height)
        guard Arena9StageDefinition.finite(proposed) else { return nil }
        let visible = proposed.intersection(definition.world)
        return visible.isNull || visible.isEmpty ? nil : visible
    }
}
