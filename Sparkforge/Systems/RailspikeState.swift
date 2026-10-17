// A7-3: axis-locked double shot; no SpriteKit clocks or delayed callbacks.
import Foundation
import CoreGraphics

struct RailspikePlan: Equatable {
    let anchor: CGPoint
    let direction: CGPoint
    let range: CGFloat
    var end: CGPoint { anchor + direction * range }
    var rect: CGRect {
        let w = GameConfig.Railspike.boltRadius
        return CGRect(x: anchor.x - w, y: min(anchor.y, end.y) - w,
                      width: 2*w, height: abs(end.y-anchor.y) + 2*w)
    }
}

struct RailspikeState {
    enum Phase { case seek, windup, interval, recovery }
    private(set) var phase: Phase = .seek
    private(set) var remaining: TimeInterval = 0
    private(set) var cooldown: TimeInterval = 0
    private(set) var plan: RailspikePlan?
    private(set) var shots = 0
    private var pending = false
    var armed: Bool { phase == .windup || phase == .interval }

    mutating func cancel() {
        phase = .recovery; remaining = GameConfig.Railspike.recovery
        plan = nil; pending = false
    }

    mutating func step(_ dt: TimeInterval, disabled: Bool, atAnchor: Bool, candidate: RailspikePlan?) {
        guard dt.isFinite, dt >= 0 else { return }
        if disabled || (armed && !atAnchor) { cancel(); return }
        cooldown = max(0, cooldown-dt)
        switch phase {
        case .seek:
            if cooldown <= 0, atAnchor, let candidate = candidate {
                plan = candidate; shots = 0; pending = false
                phase = .windup; remaining = GameConfig.Railspike.tell
                cooldown = GameConfig.Railspike.cycle
            }
        case .windup, .interval:
            // A queued shot must be dispatched after this frame's deaths before
            // the next interval can advance; long frames never bunch launches.
            if !pending {
                remaining = max(0, remaining-dt)
                if remaining <= 0 { pending = true }
            }
        case .recovery:
            remaining = max(0, remaining-dt)
            if remaining <= 0 { phase = .seek }
        }
    }

    mutating func consumeLaunch() -> RailspikePlan? {
        guard pending, armed, let plan = plan else { return nil }
        pending = false; shots += 1
        if shots == 1 { phase = .interval; remaining = GameConfig.Railspike.interval }
        else { phase = .recovery; remaining = GameConfig.Railspike.recovery; self.plan = nil }
        return plan
    }

    static func choosePlan(from: CGPoint, player: CGPoint, bodyRadius: CGFloat,
                           geometry: ArenaGeometry, radius: CGFloat) -> RailspikePlan? {
        let C = GameConfig.Railspike.self
        // Anchor on Spark's sampled x, only in the SAME broad lane. Reposition
        // at an end of that lane, never rotate a denied shot across an island.
        guard abs(player.x) > radius*0.12 + bodyRadius, from.x*player.x > 0 else { return nil }
        let anchors = [-0.55, 0.55].map { CGPoint(x: player.x, y: CGFloat($0)*radius) }
        return anchors.compactMap { a -> RailspikePlan? in
            let dy = player.y-a.y
            guard abs(dy) >= radius*0.35, a.length + bodyRadius < radius,
                  !geometry.isBlocked(a, margin: bodyRadius),
                  !geometry.segmentBlockedExact(a, player, travelRadius: C.boltRadius),
                  !geometry.segmentBlockedExact(from, a, travelRadius: bodyRadius) || geometry.graphWaypoint(from: from, toward: a,
                    travelRadius: bodyRadius, arriveRadius: GameConfig.Railspike.arriveRadius) != nil else { return nil }
            let dir = CGPoint(x: 0, y: dy > 0 ? 1 : -1)
            let edgeY = sqrt(max(0, pow(radius-C.boltRadius, 2)-a.x*a.x))
            var length = min(C.rangeFraction*radius, dir.y > 0 ? edgeY-a.y : a.y+edgeY)
            if geometry.segmentBlockedExact(a, a+dir*length, travelRadius: C.boltRadius) {
                var lo: CGFloat = 0; var hi = length
                for _ in 0..<24 {
                    let mid = (lo+hi)/2
                    if geometry.segmentBlockedExact(a, a+dir*mid, travelRadius: C.boltRadius) { hi = mid }
                    else { lo = mid }
                }
                length = lo
            }
            guard length >= abs(dy)+C.boltRadius else { return nil }
            // At least one ordinary local sidestep is clear. No cross-map or
            // speed-card assumption. Revalidated at the start of the tell.
            let escape = bodyRadius+C.boltRadius+12*DeviceScale.gameplay
            let canDodge = [-escape, escape].contains { dx in
                let q = player + CGPoint(x: dx, y: 0)
                return q.length+bodyRadius < radius && !geometry.isBlocked(q, margin: bodyRadius)
                    && !geometry.segmentBlockedExact(player, q, travelRadius: bodyRadius)
            }
            guard canDodge else { return nil }
            return RailspikePlan(anchor: a, direction: dir, range: length)
        }.min { from.distance(to: $0.anchor) < from.distance(to: $1.anchor) }
    }
}
