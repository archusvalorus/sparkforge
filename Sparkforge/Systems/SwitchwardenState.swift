// One declared crossing at a time, with local withdrawal proved for live Spark.
import Foundation
import CoreGraphics

enum SwitchwardenMotion {
    /// Exact swept grounded-body clearance and first-stop bisection. Convex
    /// circle containment plus an exact island segment test prevents tunneling;
    /// this never resolves an endpoint through a wall or slides around impact.
    static func advance(from: CGPoint, to: CGPoint, bodyRadius: CGFloat,
                        arenaRadius: CGFloat, geometry: ArenaGeometry,
                        avoiding player: CGPoint? = nil, standOff: CGFloat = 0) -> (position: CGPoint, stopped: Bool) {
        guard from.x.isFinite, from.y.isFinite, to.x.isFinite, to.y.isFinite,
              bodyRadius.isFinite, bodyRadius >= 0, arenaRadius.isFinite, arenaRadius > bodyRadius,
              from.length+bodyRadius <= arenaRadius+0.000001,
              !geometry.isBlocked(from, margin: bodyRadius) else { return (from, true) }
        func safe(_ q: CGPoint) -> Bool {
            guard q.length+bodyRadius <= arenaRadius,
                  !geometry.segmentBlockedExact(from, q, travelRadius: bodyRadius) else { return false }
            if let player = player {
                let v=q-from, n=v.dot(v)
                let t=n > 0 ? max(0,min(1,(player-from).dot(v)/n)) : 0
                guard (from+v*t).distance(to:player) >= standOff else { return false }
            }
            return true
        }
        if safe(to) { return (to, false) }
        var lo: CGFloat=0, hi: CGFloat=1
        for _ in 0..<24 {
            let mid=(lo+hi)/2
            if safe(from+(to-from)*mid) { lo=mid } else { hi=mid }
        }
        return (from+(to-from)*lo, true)
    }
}

enum SwitchwardenCrossing: CaseIterable {
    case north, middle, south
    var next: SwitchwardenCrossing {
        switch self { case .north: return .middle; case .middle: return .south; case .south: return .north }
    }

    /// Outer bands fit the real island ends and circle, rather than translating
    /// the taller middle rectangle and its anchors beyond the perimeter.
    func footprint(geometry: ArenaGeometry, radius: CGFloat) -> CGRect? {
        guard radius.isFinite, radius > 0 else { return nil }
        if self == .middle {
            return CGRect(x: -0.43*radius, y: -0.18*radius, width: 0.86*radius, height: 0.36*radius)
        }
        let sign: CGFloat = self == .north ? 1 : -1
        guard let island = geometry.blockedFootprints.first(where: { $0.center.y*sign > 0 }) else { return nil }
        let inner = abs(island.center.y)+island.halfExtents.height+island.cornerRadius+0.025*radius
        let outer = 0.88*radius
        guard inner < outer else { return nil }
        let halfWidth = min(0.43*radius, sqrt(max(0, radius*radius-outer*outer))-0.02*radius)
        guard halfWidth > 0 else { return nil }
        return CGRect(x: -halfWidth, y: sign > 0 ? inner : -outer,
                      width: halfWidth*2, height: outer-inner)
    }
}

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
    mutating func reserveRamCycle() {
        cooldown = max(GameConfig.Switchwarden.cycle, GameConfig.Switchwarden.ramWarning
                       + GameConfig.Switchwarden.ramDuration + GameConfig.Switchwarden.ramRecovery)
    }
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
                           moveSpeed: CGFloat, geometry: ArenaGeometry, radius: CGFloat,
                           crossing: SwitchwardenCrossing = .middle,
                           plantAtCurrentPosition: Bool = false) -> SwitchwardenPlan? {
        guard playerRadius.isFinite, playerRadius >= 0, moveSpeed.isFinite, moveSpeed > 0 else { return nil }
        let body = radius*GameConfig.Switchwarden.bodyFraction
        guard let rect = crossing.footprint(geometry: geometry, radius: radius) else { return nil }
        let anchors = plantAtCurrentPosition ? [from] : [-0.65, 0.65].map { side in
            crossing == .middle ? CGPoint(x: CGFloat(side)*radius, y: 0)
                : CGPoint(x: (side < 0 ? -1 : 1)*(rect.maxX+body+0.04*radius),
                          y: (crossing == .north ? 1 : -1)*(abs(rect.midY)-0.065*radius))
        }
        return anchors.compactMap { anchor -> SwitchwardenPlan? in
            guard anchor.length+body < radius, !geometry.isBlocked(anchor, margin: body),
                  !TollkeeperState.overlaps(rect:rect, circle:anchor,
                      radius:body+GameConfig.Switchwarden.arriveRadius+4),
                  anchor.distance(to: player) >= (plantAtCurrentPosition
                    ? body+playerRadius+GameConfig.Switchwarden.standOff : max(body+playerRadius+12, radius*0.35)),
                  !geometry.segmentBlockedExact(anchor, player, travelRadius: GameConfig.Geometry.projectileTravelRadius),
                  !geometry.segmentBlockedExact(from, anchor, travelRadius: body)
                    || geometry.graphWaypoint(from: from, toward: anchor, travelRadius: body,
                        arriveRadius: GameConfig.Switchwarden.arriveRadius) != nil else { return nil }
            // A ram may finish near Spark. Prefer a casting station that can
            // be approached without crossing Spark's body/stand-off circle;
            // the nearest geometric station can lie on Spark's far side.
            if !geometry.segmentBlockedExact(from,anchor,travelRadius:body) {
                let clearance=min(from.distance(to:player),body+playerRadius+GameConfig.Switchwarden.standOff)
                guard clearance <= 0.001 || !SwitchwardenRamPlan.overlaps(from:from,to:anchor,player:player,
                    radius:max(0,clearance-0.001)) else { return nil }
            }
            var withdrawal: CGFloat = 0
            if TollkeeperState.overlaps(rect: rect, circle: player, radius: playerRadius) {
                let margin = playerRadius+12*DeviceScale.gameplay
                let ySlack = min(0.10*radius, rect.height*0.25)
                let exits = [-1.0, 1.0].map { sign in CGPoint(x: CGFloat(sign)*(rect.maxX+margin),
                    y: max(rect.midY-ySlack, min(rect.midY+ySlack, player.y))) }
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

struct SwitchwardenRamPlan: Equatable {
    let origin: CGPoint
    let direction: CGPoint
    let end: CGPoint
    let playerRadius: CGFloat
    let moveSpeed: CGFloat
    var distance: CGFloat { origin.distance(to:end) }
    func supports(playerRadius: CGFloat, moveSpeed: CGFloat) -> Bool {
        playerRadius.isFinite && playerRadius >= 0 && moveSpeed.isFinite && moveSpeed > 0
            && playerRadius <= self.playerRadius+0.001
            && min(GameConfig.Player.speed,moveSpeed)+0.001 >= self.moveSpeed
    }
    static func choose(from origin: CGPoint, player: CGPoint, playerRadius: CGFloat,
                       moveSpeed: CGFloat, bodyRadius: CGFloat, geometry: ArenaGeometry,
                       arenaRadius: CGFloat) -> SwitchwardenRamPlan? {
        guard playerRadius.isFinite, playerRadius >= 0, moveSpeed.isFinite, moveSpeed > 0,
              player.x.isFinite, player.y.isFinite,
              origin.distance(to:player) >= bodyRadius+playerRadius+GameConfig.Switchwarden.standOff else { return nil }
        let direction=(player-origin).normalized
        guard direction.length > 0 else { return nil }
        let move=SwitchwardenMotion.advance(from:origin,
            to:origin+direction*(GameConfig.Switchwarden.ramSpeed*CGFloat(GameConfig.Switchwarden.ramDuration)),
            bodyRadius:bodyRadius,arenaRadius:arenaRadius,geometry:geometry)
        guard origin.distance(to:move.position) > 1 else { return nil }
        let speed=min(GameConfig.Player.speed,moveSpeed)
        if overlaps(from:origin,to:move.position,player:player,radius:bodyRadius+playerRadius) {
            // The fixed tell is never shortened or silently stretched. If a
            // live slow/grown body cannot leave the capsule on ordinary feet,
            // defer this declaration instead.
            let normal=CGPoint(x:-direction.y,y:direction.x)
            let withdrawal=bodyRadius+playerRadius+12
            let exits: [CGPoint]=[-1,1].map { player+normal*(CGFloat($0)*withdrawal) }
            guard TimeInterval(withdrawal/speed)+0.3 <= GameConfig.Switchwarden.ramWarning,
                  exits.contains(where: { q in
                      q.length+playerRadius < arenaRadius && !geometry.isBlocked(q,margin:playerRadius)
                        && !geometry.segmentBlockedExact(player,q,travelRadius:playerRadius)
                        && !overlaps(from:player,to:q,player:origin,radius:bodyRadius+playerRadius+4)
                  }) else { return nil }
        }
        return SwitchwardenRamPlan(origin:origin,direction:direction,end:move.position,
                                   playerRadius:playerRadius,moveSpeed:speed)
    }
    static func overlaps(from: CGPoint, to: CGPoint, player: CGPoint, radius: CGFloat) -> Bool {
        let v=to-from, n=v.dot(v)
        let t=n > 0 ? max(0,min(1,(player-from).dot(v)/n)) : 0
        return (from+v*t).distance(to:player) <= radius
    }
}

struct SwitchwardenRamState {
    enum Phase { case ready, warning, rushing, recovery }
    private(set) var phase: Phase = .ready
    private(set) var remaining: TimeInterval = 0
    private(set) var plan: SwitchwardenRamPlan?
    private(set) var position: CGPoint = .zero
    private(set) var sweepFrom: CGPoint = .zero
    private(set) var sweepTo: CGPoint = .zero
    private(set) var pendingSweep = false
    private(set) var hitSpent = true
    var armed: Bool { phase == .warning || phase == .rushing }
    mutating func commit(_ plan: SwitchwardenRamPlan) {
        guard phase == .ready else { return }
        self.plan=plan;position=plan.origin;sweepFrom=position;sweepTo=position
        pendingSweep=false;hitSpent=false;phase = .warning;remaining=GameConfig.Switchwarden.ramWarning
    }
    mutating func cancel() {
        phase = .recovery;remaining=GameConfig.Switchwarden.ramRecovery
        plan=nil;pendingSweep=false;hitSpent=true
    }
    mutating func step(_ dt: TimeInterval, geometry: ArenaGeometry, bodyRadius: CGFloat, arenaRadius: CGFloat) {
        guard dt.isFinite, dt >= 0 else { return }
        pendingSweep=false
        switch phase {
        case .ready: break
        case .warning:
            remaining=max(0,remaining-dt)
            if remaining <= 0 { phase = .rushing;remaining=GameConfig.Switchwarden.ramDuration }
        case .rushing:
            guard let plan=plan else { cancel();return }
            let travel=min(position.distance(to:plan.end),GameConfig.Switchwarden.ramSpeed*CGFloat(min(dt,remaining)))
            sweepFrom=position
            let move=SwitchwardenMotion.advance(from:position,to:position+plan.direction*travel,
                bodyRadius:bodyRadius,arenaRadius:arenaRadius,geometry:geometry)
            position=move.position;sweepTo=position;pendingSweep=true
            remaining=max(0,remaining-dt)
            if move.stopped || position.distance(to:plan.end) < 0.001 || remaining <= 0 {
                phase = .recovery;remaining=GameConfig.Switchwarden.ramRecovery
            }
        case .recovery:
            remaining=max(0,remaining-dt)
            if remaining <= 0 { phase = .ready;plan=nil }
        }
    }
    mutating func consumeContactAttempt() -> Bool {
        guard phase != .ready else { return true }
        guard !hitSpent else { return false }
        hitSpent=true;return true
    }
    mutating func consumeSweep(player: CGPoint, radius: CGFloat, bodyRadius: CGFloat) -> Bool {
        guard pendingSweep else { return false }
        pendingSweep=false
        guard !hitSpent, SwitchwardenRamPlan.overlaps(from:sweepFrom,to:sweepTo,player:player,
                                                     radius:radius+bodyRadius) else { return false }
        hitSpent=true;return true
    }
}
