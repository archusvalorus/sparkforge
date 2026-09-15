// RamplateNode.swift
// Sparkforge
//
// v2.1 (Geometry 2d) — Arena 6 "The Splitworks" roster #3: the mobile
// obstruction. Spatial verb: OCCUPY A ROUTE.
//
// A broad armored construct built from a gate segment. It walks to the
// NARROW passage and patrols it, braces (telegraphing its facing and the
// charge footprint), commits to a fixed-line charge it cannot steer, SHOVES
// Spark on a clean hit, stops dead at a wall or the Carrier, and is
// vulnerable while it recovers. Lesson: the short route is efficient until
// something else owns it — rotate through the long side.
// Design lock §5.3; tunables in GameConfig.Ramplate. Charge termination
// follows the BossNode precedent (wall clamp ends the attack).

import SpriteKit

final class RamplateNode: EnemyNode {

    enum ChargeOutcome { case hit, miss, wall }
    private enum Phase { case patrol, brace, charge, recover }

    /// Scene-provided: the route nodes this plate occupies (narrow passage).
    var passageAnchors: (() -> [CGPoint])?
    /// Scene applies the displacement + geometry/wall resolve.
    var onShovePlayer: ((CGPoint) -> Void)?
    var onBrace: (() -> Void)?
    var onChargeEnded: ((ChargeOutcome) -> Void)?

    private var phase: Phase = .patrol
    private var phaseTimer: TimeInterval = 0
    private var chargeCooldown: TimeInterval = 0
    private var chargeDir: CGPoint = .zero
    private var chargeDistance: CGFloat = 0
    private var punishActive = false
    private var anchors: [CGPoint]? = nil
    private var patrolIndex = 0

    private let chassis = SKNode()
    private let plate = SKShapeNode()
    private let telegraph = SKShapeNode()
    private var seams: [SKShapeNode] = []

    init(health: Int, xpValue: Int) {
        super.init(health: health,
                   moveSpeed: GameConfig.Enemy.baseSpeed * GameConfig.Ramplate.moveSpeedFactor,
                   xpValue: xpValue)
        let r = GameConfig.Enemy.visualRadius
        geometryFootprintOverride = r * GameConfig.Ramplate.footprintScale

        setBodyPalette(body: 0x1A1816, rim: 0x3F8F8A, eye: 0xFF7722)
        chassis.zPosition = 7
        addChild(chassis)

        // Wide plated face ahead of the core (+x = facing).
        plate.path = CGPath(roundedRect: CGRect(x: r * 0.8, y: -r * 1.7, width: r * 0.9, height: r * 3.4),
                            cornerWidth: r * 0.15, cornerHeight: r * 0.15, transform: nil)
        plate.fillColor = SKColor(hex: 0x2A2622)
        plate.strokeColor = SKColor(hex: 0x3F8F8A, alpha: 0.95)
        plate.lineWidth = 1.5
        chassis.addChild(plate)

        // Furnace seams across the face — kiln orange, brighter when bracing.
        for dy: CGFloat in [-1.0, 0, 1.0] {
            let seam = SKShapeNode()
            let sp = CGMutablePath()
            sp.move(to: CGPoint(x: r * 0.9, y: r * dy))
            sp.addLine(to: CGPoint(x: r * 1.6, y: r * dy))
            seam.path = sp
            seam.strokeColor = SKColor(hex: 0xFF7722, alpha: 0.5)
            seam.lineWidth = 1.5
            seam.glowWidth = 2
            chassis.addChild(seam)
            seams.append(seam)
        }

        // Heavy rear drive assembly: two battered blocks behind the core.
        for dy: CGFloat in [-0.95, 0.95] {
            let block = SKShapeNode(rect: CGRect(x: -r * 1.45, y: r * dy - r * 0.35, width: r * 0.9, height: r * 0.7),
                                    cornerRadius: r * 0.1)
            block.fillColor = SKColor(hex: 0x24211E)
            block.strokeColor = SKColor(hex: 0xD9D2C4, alpha: 0.6)
            block.lineWidth = 1
            chassis.addChild(block)
        }

        // Charge footprint telegraph: the lane it will own. Hidden until brace.
        telegraph.fillColor = SKColor(hex: 0xFF7722, alpha: 0)
        telegraph.strokeColor = SKColor(hex: 0xFF7722, alpha: 0)
        telegraph.lineWidth = 1
        telegraph.zPosition = -2
        chassis.addChild(telegraph)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - AI

    override func chase(target: CGPoint, deltaTime dt: TimeInterval, globalSlow: CGFloat = 0) {
        guard !isStunned && !isFrozen else { return }
        let C = GameConfig.Ramplate.self
        phaseTimer -= dt
        if chargeCooldown > 0 { chargeCooldown -= dt }
        let goal = goalPosition

        switch phase {
        case .patrol:
            geometryDisplacedThisFrame = false
            if anchors == nil { anchors = passageAnchors?() ?? [] }
            let slow = min(currentSlow + globalSlow, 0.8)
            if let a = anchors, !a.isEmpty {
                // Own the passage: walk to the nearest end, then pace between ends.
                let dest = a[patrolIndex % a.count]
                if position.distance(to: dest) < C.patrolArriveRadius {
                    patrolIndex += 1
                } else {
                    let dir = (dest - position).normalized
                    position += dir * moveSpeed * (1 - slow) * CGFloat(dt)
                    face(dir)
                }
            } else {
                // No authored passage (open arena): a slow, patient pursuer.
                let dir = (target - position).normalized
                position += dir * moveSpeed * (1 - slow) * CGFloat(dt)
                face(dir)
            }
            if chargeCooldown <= 0, !isOccludedFromGoal,
               position.distance(to: goal) < C.braceRange {
                enterBrace(toward: goal)
            }

        case .brace:
            if phaseTimer <= 0 { enterCharge() }

        case .charge:
            if geometryDisplacedThisFrame {
                geometryDisplacedThisFrame = false
                endCharge(.wall)
                return
            }
            let step = C.chargeSpeed * CGFloat(dt)
            position += chargeDir * step
            chargeDistance += step
            // Arena wall ends the charge (BossNode precedent): clamp, then stop.
            let limit = GameConfig.Arena.radius - geometryFootprintRadius
            if position.length > limit {
                position = position.normalized * limit
                endCharge(.wall)
                return
            }
            if chargeDistance >= C.maxChargeDistance { endCharge(.miss) }

        case .recover:
            if phaseTimer <= 0 {
                phase = .patrol
                punishActive = false
                plate.fillColor = SKColor(hex: 0x2A2622)
            }
        }
    }

    override func didStrikePlayer() {
        guard phase == .charge else { return }
        onShovePlayer?(chargeDir)
        endCharge(.hit)
    }

    /// Vulnerable recovery after a miss or a wall — same idiom as the Spurhound.
    override func takeDamage(_ amount: Int) -> Bool {
        let scaled = punishActive
            ? Int((CGFloat(amount) * GameConfig.Ramplate.punishVulnerability).rounded())
            : amount
        return super.takeDamage(scaled)
    }

    // MARK: - Phases

    private func face(_ dir: CGPoint) {
        guard dir.x != 0 || dir.y != 0 else { return }
        chassis.zRotation = atan2(dir.y, dir.x)
    }

    private func enterBrace(toward goal: CGPoint) {
        let C = GameConfig.Ramplate.self
        phase = .brace
        phaseTimer = C.braceDuration
        chargeCooldown = C.chargeCooldown
        chargeDir = (goal - position).normalized   // committed here; no pivot after
        onBrace?()

        // Telegraph: swing to face, light the seams, lay down the lane.
        let r = GameConfig.Enemy.visualRadius
        chassis.run(SKAction.rotate(toAngle: atan2(chargeDir.y, chargeDir.x), duration: 0.15, shortestUnitArc: true))
        telegraph.path = CGPath(rect: CGRect(x: r * 1.7, y: -r * 1.7, width: C.maxChargeDistance, height: r * 3.4), transform: nil)
        telegraph.removeAllActions()
        telegraph.run(SKAction.customAction(withDuration: C.braceDuration) { [weak self] _, t in
            let f = CGFloat(t / C.braceDuration)
            self?.telegraph.fillColor = SKColor(hex: 0xFF7722, alpha: 0.04 + 0.16 * f)
            self?.telegraph.strokeColor = SKColor(hex: 0xFF7722, alpha: 0.2 + 0.5 * f)
        })
        for s in seams { s.run(SKAction.customAction(withDuration: C.braceDuration) { node, t in
            (node as? SKShapeNode)?.strokeColor = SKColor(hex: 0xFF7722, alpha: 0.5 + 0.5 * CGFloat(t / C.braceDuration))
        }) }
        // Crouch back onto the drive, then launch.
        chassis.run(SKAction.sequence([
            SKAction.moveBy(x: -chargeDir.x * 6, y: -chargeDir.y * 6, duration: C.braceDuration * 0.7),
            SKAction.moveBy(x: chargeDir.x * 6, y: chargeDir.y * 6, duration: C.braceDuration * 0.3)
        ]))
    }

    private func enterCharge() {
        phase = .charge
        chargeDistance = 0
        geometryDisplacedThisFrame = false
        telegraph.removeAllActions()
        telegraph.run(SKAction.customAction(withDuration: 0.2) { [weak self] _, t in
            self?.telegraph.fillColor = SKColor(hex: 0xFF7722, alpha: max(0, 0.2 - CGFloat(t)))
            self?.telegraph.strokeColor = SKColor(hex: 0xFF7722, alpha: max(0, 0.7 - CGFloat(t) * 3.5))
        })
    }

    private func endCharge(_ outcome: ChargeOutcome) {
        let C = GameConfig.Ramplate.self
        phase = .recover
        onChargeEnded?(outcome)
        for s in seams { s.removeAllActions(); s.strokeColor = SKColor(hex: 0xFF7722, alpha: 0.5) }
        telegraph.fillColor = .clear; telegraph.strokeColor = .clear

        switch outcome {
        case .hit:
            phaseTimer = C.recoverAfterHit
            punishActive = false
        case .miss, .wall:
            phaseTimer = C.recoverAfterMiss
            punishActive = true
            plate.fillColor = SKColor(hex: 0x3A2A22)          // overheated: "now"
            // The impact: recoil back off the line and rattle.
            position = position - chargeDir * (outcome == .wall ? 14 : 6)
            chassis.run(SKAction.sequence([
                SKAction.moveBy(x: -chargeDir.x * 5, y: -chargeDir.y * 5, duration: 0.05),
                SKAction.moveBy(x: chargeDir.x * 5, y: chargeDir.y * 5, duration: 0.12)
            ]))
        }
    }
}
