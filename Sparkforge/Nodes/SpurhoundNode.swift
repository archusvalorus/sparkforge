// SpurhoundNode.swift
// Sparkforge
//
// v2.1 (Geometry 2b) — Arena 6 "The Splitworks" roster #1: the fast flanker.
// Spatial verb: GO AROUND.
//
// A low industrial hunting construct built to run beside moving forge
// columns. It selects a route around the Fallen Carrier at a decision point
// (the 1B steer pass owns that; this node only adds a flank preference),
// SPRINTS while out of direct engagement, gives a bright exhaust tell the
// moment it emerges, COMMITS to a short readable lunge, and is briefly
// punishable after a miss or a wall clang. Lesson: breaking sightline does
// not erase a fast threat — remember what went behind the carrier.
// Design lock §5.1; tunables in GameConfig.Spurhound.

import SpriteKit

final class SpurhoundNode: EnemyNode {

    enum LungeOutcome { case hit, miss, clang }
    private enum Phase { case hunt, tell, lunge, recover }

    /// Scene-side telemetry hook (counters live in GeometryDebug).
    var onLungeOutcome: ((LungeOutcome) -> Void)?
    var onLungeCommitted: (() -> Void)?

    private var phase: Phase = .hunt
    private var phaseTimer: TimeInterval = 0
    private var lungeCooldown: TimeInterval = 0
    private var lungeDir: CGPoint = .zero
    /// 0…1 — how much of the sprint has built up while occluded.
    private var sprint: CGFloat = 0
    private var punishActive = false

    private let chassis = SKNode()          // rotates to face travel
    private let hull = SKShapeNode()
    private let exhaust = SKShapeNode()

    init(health: Int, xpValue: Int) {
        super.init(health: health,
                   moveSpeed: GameConfig.Enemy.baseSpeed * GameConfig.Spurhound.huntSpeedFactor,
                   xpValue: xpValue)

        // Charcoal iron, oxidized-teal rim, kiln-orange eye (lock §9 palette).
        setBodyPalette(body: 0x1A1816, rim: 0x3F8F8A, eye: 0xFF7722)

        let r = GameConfig.Enemy.visualRadius
        chassis.zPosition = 7
        addChild(chassis)

        // Low, forward-canted wedge pointing along +x.
        let p = CGMutablePath()
        p.move(to: CGPoint(x: r * 1.9, y: 0))                 // nose
        p.addLine(to: CGPoint(x: r * 0.5, y: r * 0.55))
        p.addLine(to: CGPoint(x: -r * 1.3, y: r * 0.62))
        p.addLine(to: CGPoint(x: -r * 1.55, y: 0))            // tail
        p.addLine(to: CGPoint(x: -r * 1.3, y: -r * 0.62))
        p.addLine(to: CGPoint(x: r * 0.5, y: -r * 0.55))
        p.closeSubpath()
        hull.path = p
        hull.fillColor = SKColor(hex: 0x2A2622)
        hull.strokeColor = SKColor(hex: 0x3F8F8A, alpha: 0.95)
        hull.lineWidth = 1
        hull.glowWidth = 1
        chassis.addChild(hull)

        // Rail-skate spurs at the rear corners — pale ceramic, the route-marking colour.
        for side: CGFloat in [1, -1] {
            let spur = SKShapeNode(circleOfRadius: r * 0.3)
            spur.position = CGPoint(x: -r * 0.95, y: side * r * 0.72)
            spur.fillColor = SKColor(hex: 0x4A4540)
            spur.strokeColor = SKColor(hex: 0xD9D2C4, alpha: 0.9)
            spur.lineWidth = 1
            chassis.addChild(spur)
        }

        // Exhaust plume behind the tail: dim while hunting, brighter as the
        // sprint builds, FLARES on the tell. "It should read as speed before
        // the first move occurs."
        exhaust.path = CGPath(ellipseIn: CGRect(x: -r * 0.6, y: -r * 0.3, width: r * 1.2, height: r * 0.6), transform: nil)
        exhaust.position = CGPoint(x: -r * 1.9, y: 0)
        exhaust.fillColor = SKColor(hex: 0xFF7722)
        exhaust.strokeColor = .clear
        exhaust.glowWidth = 4
        exhaust.alpha = 0.15
        exhaust.zPosition = -1
        chassis.addChild(exhaust)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - AI

    override func chase(target: CGPoint, deltaTime dt: TimeInterval, globalSlow: CGFloat = 0) {
        guard !isStunned && !isFrozen else { return }
        let C = GameConfig.Spurhound.self
        phaseTimer -= dt
        if lungeCooldown > 0 { lungeCooldown -= dt }

        switch phase {
        case .hunt:
            geometryDisplacedThisFrame = false   // brushing a corner while hunting is not a clang
            if isOccludedFromGoal {
                sprint = min(1, sprint + CGFloat(dt / C.sprintRampTime))
            } else {
                sprint = max(0, sprint - CGFloat(dt / C.sprintDecayTime))
            }
            let factor = C.huntSpeedFactor + (C.sprintSpeedFactor - C.huntSpeedFactor) * sprint
            let slow = min(currentSlow + globalSlow, 0.8)
            let dir = (target - position).normalized
            position += dir * GameConfig.Enemy.baseSpeed * factor * (1 - slow) * CGFloat(dt)
            aim(dir)
            exhaust.alpha = 0.15 + 0.5 * sprint

            // Emergence: in sight, in range, off cooldown → tell. `target` is
            // the real player position whenever we're not occluded (the steer
            // pass only substitutes a node while the line is blocked).
            if !isOccludedFromGoal, lungeCooldown <= 0,
               position.distance(to: target) < C.lungeRange {
                enterTell(toward: target)
            }

        case .tell:
            // Crouched and committed — no re-aim (the Star Needle grammar).
            if phaseTimer <= 0 { enterLunge() }

        case .lunge:
            if geometryDisplacedThisFrame {
                geometryDisplacedThisFrame = false
                endLunge(.clang)
                return
            }
            position += lungeDir * C.lungeSpeed * CGFloat(dt)
            if phaseTimer <= 0 { endLunge(.miss) }

        case .recover:
            if phaseTimer <= 0 {
                phase = .hunt
                punishActive = false
                hull.fillColor = SKColor(hex: 0x2A2622)
            }
        }
    }

    /// v2.1 (2b): flank preference. Nodes on the hound's own side of the
    /// player cost more, nodes on the far side cost less — so the pack goes
    /// AROUND rather than queuing at the near corner. Crowding spreads a pack
    /// across both routes.
    override func routeNodeBias(_ node: RouteNode, goal: CGPoint, occupancy: Int) -> CGFloat {
        let C = GameConfig.Spurhound.self
        let mySide = (position - goal).normalized
        let nodeSide = (node.position - goal).normalized
        let sameSide = mySide.dot(nodeSide)          // +1 my side … −1 far side
        return C.flankBias * sameSide + C.crowdPenalty * CGFloat(occupancy)
    }

    override func didStrikePlayer() {
        if phase == .lunge { endLunge(.hit) }
    }

    /// Punishable window: incoming damage is scaled up. Kept OFF the shared
    /// `vulnerabilityMultiplier` so card marks (Apex T4 etc.) are never stomped.
    override func takeDamage(_ amount: Int) -> Bool {
        let scaled = punishActive
            ? Int((CGFloat(amount) * GameConfig.Spurhound.punishVulnerability).rounded())
            : amount
        return super.takeDamage(scaled)
    }

    // MARK: - Phases

    private func aim(_ dir: CGPoint) {
        guard dir.x != 0 || dir.y != 0 else { return }
        chassis.zRotation = atan2(dir.y, dir.x)
    }

    private func enterTell(toward target: CGPoint) {
        let C = GameConfig.Spurhound.self
        phase = .tell
        phaseTimer = C.tellDuration
        lungeCooldown = C.lungeCooldown
        lungeDir = (target - position).normalized   // committed HERE, then frozen
        aim(lungeDir)
        sprint = 0

        // The tell: exhaust flares bright and wide, the hull crouches low.
        exhaust.removeAllActions()
        exhaust.run(SKAction.group([
            SKAction.fadeAlpha(to: 1.0, duration: C.tellDuration * 0.5),
            SKAction.scale(to: 1.7, duration: C.tellDuration * 0.5)
        ]))
        hull.run(SKAction.scaleY(to: 0.72, duration: C.tellDuration * 0.8))
    }

    private func enterLunge() {
        let C = GameConfig.Spurhound.self
        phase = .lunge
        phaseTimer = C.lungeDuration
        geometryDisplacedThisFrame = false
        onLungeCommitted?()
        hull.run(SKAction.scaleY(to: 1.0, duration: 0.08))
        // Exhaust streaks long behind the lunge, then dies with it.
        exhaust.removeAllActions()
        exhaust.run(SKAction.sequence([
            SKAction.group([
                SKAction.scaleX(to: 2.6, duration: 0.06),
                SKAction.scaleY(to: 0.9, duration: 0.06)
            ]),
            SKAction.wait(forDuration: C.lungeDuration * 0.6),
            SKAction.group([
                SKAction.fadeAlpha(to: 0.15, duration: 0.2),
                SKAction.scale(to: 1.0, duration: 0.2)
            ])
        ]))
    }

    private func endLunge(_ outcome: LungeOutcome) {
        let C = GameConfig.Spurhound.self
        phase = .recover
        onLungeOutcome?(outcome)
        exhaust.removeAllActions()
        exhaust.run(SKAction.group([
            SKAction.fadeAlpha(to: 0.15, duration: 0.15),
            SKAction.scale(to: 1.0, duration: 0.15)
        ]))

        switch outcome {
        case .hit:
            phaseTimer = C.recoverAfterHit
            punishActive = false
        case .miss:
            phaseTimer = C.recoverAfterMiss
            punishActive = true
            hull.fillColor = SKColor(hex: 0x3A2A22)        // overheated — readable "now"
            // A skid: the hull fishtails once.
            chassis.run(SKAction.sequence([
                SKAction.rotate(byAngle: 0.35, duration: 0.08),
                SKAction.rotate(byAngle: -0.55, duration: 0.12),
                SKAction.rotate(byAngle: 0.2, duration: 0.1)
            ]))
        case .clang:
            phaseTimer = C.recoverAfterMiss
            punishActive = true
            hull.fillColor = SKColor(hex: 0x3A2A22)
            // Bounce off the iron and flash the ceramic rim.
            position = position - lungeDir * 12
            hull.run(SKAction.sequence([
                SKAction.run { [weak self] in self?.hull.strokeColor = SKColor(hex: 0xD9D2C4) },
                SKAction.wait(forDuration: 0.12),
                SKAction.run { [weak self] in self?.hull.strokeColor = SKColor(hex: 0x3F8F8A, alpha: 0.95) }
            ]))
        }
    }
}
