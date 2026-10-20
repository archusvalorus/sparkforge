// Opt-in DEBUG proof only. No live arena bounds consumer changes.
#if DEBUG
import Foundation
import CoreGraphics

enum Arena8P0Bounds {
    case circle(center: CGPoint, radius: CGFloat)
    case rectangle(CGRect)

    init() { self = .circle(center: .zero, radius: GameConfig.Arena8Prototype.defaultCircleRadius) }

    func clamped(_ point: CGPoint, bodyRadius: CGFloat) -> CGPoint? {
        guard point.x.isFinite, point.y.isFinite, bodyRadius.isFinite, bodyRadius >= 0 else { return nil }
        switch self {
        case let .circle(center, radius):
            guard center.x.isFinite, center.y.isFinite, radius.isFinite, radius >= bodyRadius else { return nil }
            let offset = point - center
            let available = radius - bodyRadius
            return offset.length > available ? center + offset.normalized * available : point
        case let .rectangle(rect):
            guard !rect.isNull, rect.minX.isFinite, rect.minY.isFinite,
                  rect.width.isFinite, rect.height.isFinite,
                  rect.width > 0, rect.height > 0,
                  rect.width >= bodyRadius * 2, rect.height >= bodyRadius * 2 else { return nil }
            return CGPoint(x: min(rect.maxX - bodyRadius, max(rect.minX + bodyRadius, point.x)),
                           y: min(rect.maxY - bodyRadius, max(rect.minY + bodyRadius, point.y)))
        }
    }

    func contains(_ point: CGPoint, bodyRadius: CGFloat = 0) -> Bool {
        guard let clamped = clamped(point, bodyRadius: bodyRadius) else { return false }
        return clamped.distance(to: point) < 0.000001
    }
}
#endif
