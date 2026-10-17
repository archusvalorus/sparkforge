// A7-4 DEBUG prototype policy: one fixed crossing, ordinary local withdrawal.
import Foundation
import CoreGraphics

struct SwitchwardenPlan: Equatable {
    let anchor: CGPoint
    let rect: CGRect
    let warning: TimeInterval
    let playerRadius: CGFloat
    let moveSpeed: CGFloat
    init(anchor: CGPoint, rect: CGRect, warning: TimeInterval,
         playerRadius: CGFloat = 10, moveSpeed: CGFloat = GameConfig.Player.speed) {
        self.anchor=anchor;self.rect=rect;self.warning=warning
        self.playerRadius=playerRadius;self.moveSpeed=moveSpeed
    }
    func supports(playerRadius: CGFloat, moveSpeed: CGFloat) -> Bool {
        playerRadius.isFinite && playerRadius >= 0 && moveSpeed.isFinite && moveSpeed > 0
            && playerRadius <= self.playerRadius+0.001
            && min(GameConfig.Player.speed,moveSpeed)+0.001 >= self.moveSpeed
    }
}

struct SwitchwardenState {
    enum Phase { case seek, warning, surge, recovery }
    private(set) var phase: Phase = .seek
    private(set) var remaining: TimeInterval = 0
    private(set) var cooldown: TimeInterval = 0
    private(set) var plan: SwitchwardenPlan?
    private var hitSpent = false
    var armed: Bool { phase == .warning || phase == .surge }
    mutating func cancel() {
        phase = .recovery; remaining = GameConfig.Switchwarden.recovery
        plan = nil; hitSpent = true
    }
    mutating func step(_ dt: TimeInterval, disabled: Bool, atAnchor: Bool, candidate: SwitchwardenPlan?) {
        guard dt.isFinite, dt >= 0 else { return }
        if disabled || (armed && !atAnchor) { cancel(); return }
        cooldown = max(0, cooldown-dt)
        switch phase {
        case .seek:
            if cooldown <= 0, atAnchor, let candidate = candidate {
                plan = candidate; hitSpent = false; phase = .warning
                remaining = candidate.warning; cooldown = max(GameConfig.Switchwarden.cycle,
                    candidate.warning + GameConfig.Switchwarden.surge + GameConfig.Switchwarden.recovery)
            }
        case .warning:
            remaining = max(0, remaining-dt)
            if remaining <= 0 { phase = .surge; remaining = GameConfig.Switchwarden.surge }
        case .surge:
            remaining = max(0, remaining-dt)
            if remaining <= 0 { phase = .recovery; remaining = GameConfig.Switchwarden.recovery; plan = nil }
        case .recovery:
            remaining = max(0, remaining-dt)
            if remaining <= 0 { phase = .seek }
        }
    }
    mutating func consumeHit(player: CGPoint, radius: CGFloat) -> Bool {
        guard phase == .surge, !hitSpent, let plan = plan,
              TollkeeperState.overlaps(rect: plan.rect, circle: player, radius: radius) else { return false }
        hitSpent = true; return true
    }

    static func choosePlan(from: CGPoint, player: CGPoint, playerRadius: CGFloat,
                           moveSpeed: CGFloat, geometry: ArenaGeometry, radius: CGFloat) -> SwitchwardenPlan? {
        guard playerRadius.isFinite, playerRadius >= 0, moveSpeed.isFinite, moveSpeed > 0 else { return nil }
        let body = radius*GameConfig.Switchwarden.bodyFraction
        let rect = CGRect(x: -0.43*radius, y: -0.18*radius, width: 0.86*radius, height: 0.36*radius)
        return [-0.65, 0.65].compactMap { side -> SwitchwardenPlan? in
            let anchor = CGPoint(x: CGFloat(side)*radius, y: 0)
            guard anchor.length+body < radius, !geometry.isBlocked(anchor, margin: body),
                  anchor.distance(to: player) > max(body+playerRadius+12, radius*0.35),
                  !geometry.segmentBlockedExact(anchor, player, travelRadius: GameConfig.Geometry.projectileTravelRadius),
                  !geometry.segmentBlockedExact(from, anchor, travelRadius: body)
                    || geometry.graphWaypoint(from: from, toward: anchor, travelRadius: body,
                        arriveRadius: GameConfig.Switchwarden.arriveRadius) != nil else { return nil }
            var withdrawal: CGFloat = 0
            if TollkeeperState.overlaps(rect: rect, circle: player, radius: playerRadius) {
                let margin = playerRadius+12*DeviceScale.gameplay
                let exits = [-1.0, 1.0].map { sign in CGPoint(x: CGFloat(sign)*(0.43*radius+margin),
                    y: max(-0.10*radius, min(0.10*radius, player.y))) }
                let distances = exits.compactMap { q -> CGFloat? in
                    guard q.length+playerRadius < radius, !geometry.isBlocked(q, margin: playerRadius),
                          !geometry.segmentBlockedExact(player, q, travelRadius: playerRadius) else { return nil }
                    // Segment must clear the boss's actual grounded body too.
                    let v = q-player; let length2 = v.dot(v)
                    let t = length2 > 0 ? max(0, min(1, (anchor-player).dot(v)/length2)) : 0
                    guard (player+v*t).distance(to: anchor) > body+playerRadius+GameConfig.Switchwarden.arriveRadius+4 else { return nil }
                    return player.distance(to: q)
                }
                guard let distance = distances.min() else { return nil }
                withdrawal = distance
            }
            let speed = min(GameConfig.Player.speed, moveSpeed)
            let warning = max(GameConfig.Switchwarden.warning, TimeInterval(withdrawal/speed)+0.3)
            return SwitchwardenPlan(anchor: anchor, rect: rect, warning: warning,
                playerRadius: playerRadius, moveSpeed: speed)
        }.min { from.distance(to: $0.anchor) < from.distance(to: $1.anchor) }
    }
}
