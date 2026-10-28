// Directional fear adapter for the opt-in six-room floor only.
#if DEBUG
import Foundation
import CoreGraphics

struct Arena8RoomFear {
    let map: Arena8GameMap

    private func stored(_ p: CGPoint) -> CGPoint {
        CGPoint(x: CGFloat(Float(p.x)), y: CGFloat(Float(p.y)))
    }

    /// Check the entire segment at the live body clearance. A nearest-floor
    /// projection is deliberately not used: it could move toward Spark.
    private func legal(from: CGPoint, to q: CGPoint, spark: CGPoint,
                       radius: CGFloat, maximum: CGFloat) -> Bool {
        q.x.isFinite && q.y.isFinite
            && map.valid(q, radius: radius)
            && hypot(q.x - from.x, q.y - from.y) <= maximum + FleeRule.tolerance
            && FleeRule.keepsAway(from: from, toward: q, spark: spark)
            && !map.geometry.segmentBlockedExact(from, q, travelRadius: radius)
    }

    /// Float storage must also obey separation, length and clearance. Reject
    /// invalid rounding rather than weakening the footprint or snapping.
    private func endpoint(from: CGPoint, requested: CGPoint, spark: CGPoint,
                          radius: CGFloat, maximum: CGFloat) -> CGPoint? {
        let rounded = stored(requested)
        if legal(from: from, to: rounded, spark: spark, radius: radius, maximum: maximum) { return rounded }
        let x = Float(requested.x), y = Float(requested.y)
        return [x.nextDown, x, x.nextUp].flatMap { a in
            [y.nextDown, y, y.nextUp].map { b in CGPoint(x: CGFloat(a), y: CGFloat(b)) }
        }.filter { legal(from: from, to: $0, spark: spark, radius: radius, maximum: maximum) }
            .min { hypot($0.x-requested.x, $0.y-requested.y) < hypot($1.x-requested.x, $1.y-requested.y) }
    }

    private func ray(from p: CGPoint, direction: CGPoint, length: CGFloat,
                     spark: CGPoint, radius: CGFloat) -> CGPoint? {
        func point(_ t: CGFloat) -> CGPoint {
            CGPoint(x: p.x + direction.x * length * t, y: p.y + direction.y * length * t)
        }
        if let full = endpoint(from: p, requested: point(1), spark: spark, radius: radius, maximum: length) { return full }
        // The authored rectangle and swept-solid predicate are monotone along
        // this ray. Find the last clear point on this side of the first wall.
        var low: CGFloat = 0, high: CGFloat = 1
        for _ in 0..<32 {
            let mid = (low + high) / 2
            if legal(from: p, to: point(mid), spark: spark, radius: radius, maximum: length) { low = mid }
            else { high = mid }
        }
        return endpoint(from: p, requested: point(low), spark: spark, radius: radius, maximum: length)
    }

    private func candidates(from p: CGPoint, spark: CGPoint, radius: CGFloat,
                            length: CGFloat, minimum: CGFloat) -> CGPoint? {
        let away = FleeRule.awayDirection(from: p, spark: spark)
        for degrees in [CGFloat(0)] + FleeRule.deviations {
            var best: CGPoint?
            for sign: CGFloat in (degrees == 0 ? [1] : [1, -1]) {
                let dir = FleeRule.rotate(away, degrees: sign * degrees)
                guard let q = ray(from: p, direction: dir, length: length, spark: spark, radius: radius),
                      hypot(q.x-p.x, q.y-p.y) > minimum else { continue }
                if best.map({ hypot(q.x-spark.x,q.y-spark.y) > hypot($0.x-spark.x,$0.y-spark.y) }) ?? true { best = q }
            }
            if let q = best { return q }
        }
        return nil
    }

    func goal(from p: CGPoint, spark: CGPoint, lookahead: CGFloat, radius: CGFloat) -> CGPoint? {
        guard map.isSixRoom, p.x.isFinite, p.y.isFinite, spark.x.isFinite, spark.y.isFinite,
              radius.isFinite, radius >= 0, lookahead.isFinite, lookahead > 0,
              map.valid(p, radius: radius) else { return nil }
        return candidates(from: p, spark: spark, radius: radius, length: lookahead, minimum: 1)
    }

    func step(from p: CGPoint, spark: CGPoint, preferred: CGPoint?, moveSpeed: CGFloat,
              slow: CGFloat, dt: TimeInterval, radius: CGFloat) -> CGPoint {
        guard map.isSixRoom, p.x.isFinite, p.y.isFinite, spark.x.isFinite, spark.y.isFinite,
              radius.isFinite, radius >= 0, moveSpeed.isFinite, moveSpeed >= 0, slow.isFinite, dt.isFinite, dt >= 0,
              map.valid(p, radius: radius) else { return p }
        let length = moveSpeed * (1 - min(max(slow, 0), 0.8)) * CGFloat(dt)
        guard length.isFinite, length > 0 else { return p }
        if let target = preferred, target.x.isFinite, target.y.isFinite {
            let dx = target.x-p.x, dy = target.y-p.y, distance = hypot(dx,dy)
            if distance > 0.0001 {
                let amount = min(distance,length)
                let requested = CGPoint(x:p.x+dx/distance*amount,y:p.y+dy/distance*amount)
                if let q = endpoint(from:p,requested:requested,spark:spark,radius:radius,maximum:length),
                   hypot(q.x-p.x,q.y-p.y) > 1e-9 { return q }
            }
        }
        return candidates(from:p,spark:spark,radius:radius,length:length,minimum:1e-9) ?? p
    }
}
#endif
