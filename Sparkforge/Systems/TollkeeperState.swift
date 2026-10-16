// A7-2: authoritative attack state and plan geometry; active-play time only.
import Foundation
import CoreGraphics

struct TollkeeperPlan: Equatable {
    let anchor: CGPoint
    let rect: CGRect
}

struct TollkeeperState {
    enum Phase { case seek, windup, pulse, recovery }
    private(set) var phase: Phase = .seek
    private(set) var remaining: TimeInterval = 0
    private(set) var cooldown: TimeInterval = 0
    private(set) var plan: TollkeeperPlan?
    private(set) var hitSpent = false

    var attackRect: CGRect? { phase == .windup || phase == .pulse ? plan?.rect : nil }

    mutating func cancel() {
        plan = nil
        phase = .recovery
        remaining = GameConfig.Tollkeeper.recovery
        hitSpent = true
    }

    /// At most one transition per step: even a long frame cannot skip the tell.
    mutating func step(_ dt: TimeInterval, disabled: Bool, atAnchor: Bool, candidate: TollkeeperPlan?) {
        guard dt.isFinite, dt >= 0 else { return }
        if disabled { cancel(); return }
        cooldown = max(0, cooldown - dt)
        if (phase == .windup || phase == .pulse) && !atAnchor { cancel(); return }
        switch phase {
        case .seek:
            if cooldown <= 0, atAnchor, let candidate = candidate {
                plan = candidate; hitSpent = false
                phase = .windup; remaining = GameConfig.Tollkeeper.windup
                cooldown = GameConfig.Tollkeeper.cycle
            }
        case .windup:
            remaining = max(0, remaining - dt)
            if remaining <= 0 { phase = .pulse; remaining = GameConfig.Tollkeeper.pulse }
        case .pulse:
            remaining = max(0, remaining - dt)
            if remaining <= 0 { phase = .recovery; remaining = GameConfig.Tollkeeper.recovery; plan = nil }
        case .recovery:
            remaining = max(0, remaining - dt)
            if remaining <= 0 { phase = .seek }
        }
    }

    mutating func consumeHit(player: CGPoint, radius: CGFloat) -> Bool {
        guard phase == .pulse, !hitSpent, let rect = plan?.rect,
              Self.overlaps(rect: rect, circle: player, radius: radius) else { return false }
        hitSpent = true
        return true
    }

    static func overlaps(rect: CGRect, circle: CGPoint, radius: CGFloat) -> Bool {
        let x = max(rect.minX, min(rect.maxX, circle.x))
        let y = max(rect.minY, min(rect.maxY, circle.y))
        return circle.distance(to: CGPoint(x: x, y: y)) <= max(0, radius)
    }

    static func shouldSpawn(elapsed: TimeInterval, lastSpawn: TimeInterval, living: Int) -> Bool {
        elapsed >= GameConfig.Tollkeeper.firstSpawn && living == 0
            && elapsed - lastSpawn >= GameConfig.Tollkeeper.spawnInterval
    }

    static func valid(_ plan: TollkeeperPlan, player: CGPoint, bodyRadius: CGFloat,
                      geometry: ArenaGeometry, radius: CGFloat) -> Bool {
        guard plan.anchor.length + bodyRadius <= radius,
              !geometry.isBlocked(plan.anchor, margin: bodyRadius),
              plan.anchor.distance(to: player) <= radius * GameConfig.Tollkeeper.engageFraction,
              !geometry.segmentBlockedExact(plan.anchor, player,
                  travelRadius: GameConfig.Geometry.projectileTravelRadius) else { return false }
        let rect = plan.rect
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX, y: rect.maxY),
                       CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY)]
        return corners.allSatisfy { p in
            p.length < radius && !geometry.isBlocked(p)
                && !geometry.segmentBlockedExact(plan.anchor, p)
        }
    }

    static func choosePlan(from: CGPoint, player: CGPoint, bodyRadius: CGFloat,
                           geometry: ArenaGeometry, radius: CGFloat) -> TollkeeperPlan? {
        let C = GameConfig.Tollkeeper.self
        var choices: [TollkeeperPlan] = []
        for y: CGFloat in [-0.78, 0, 0.78] {
            for side: CGFloat in [-1, 1] {
                let anchor = CGPoint(x: side * radius * C.anchorFraction, y: y * radius)
                let center = CGPoint(x: side * radius * C.centerFraction, y: y * radius)
                let plan = TollkeeperPlan(anchor: anchor,
                    rect: CGRect(x: center.x - radius*C.halfLengthFraction,
                                 y: center.y - radius*C.halfDepthFraction,
                                 width: radius*C.halfLengthFraction*2, height: radius*C.halfDepthFraction*2))
                guard valid(plan, player: player, bodyRadius: bodyRadius, geometry: geometry, radius: radius) else { continue }
                let direct = !geometry.segmentBlockedExact(from, anchor, travelRadius: bodyRadius)
                if direct || geometry.graphWaypoint(from: from, toward: anchor,
                    travelRadius: bodyRadius, arriveRadius: C.arriveRadius) != nil { choices.append(plan) }
            }
        }
        return choices.min { from.distance(to: $0.anchor) < from.distance(to: $1.anchor) }
    }
}
