// QuenchWardenNode.swift
// Sparkforge
//
// v1.6 Arena 2 boss (Lyra canon): The Quench Warden.
// "A cold forge sentinel that does not strike like the Slag Titan.
// It measures, compresses, redirects, and denies space until the
// player breaks rhythm." Personality: procedure, not rage.
//
// Three patterns, none of which are charge/slam/summon:
//   Pressure Lanes  — parallel cold-white bands press the arena
//   Cinder Aperture — satellites volley rotating arcs with readable gaps
//   Quench Field    — pull / push / reverse momentum pulses
// Enrage (Final Temper, <30% HP): same tools, less mercy — shorter
// telegraphs, tighter arcs. Nothing new is added; that's the identity.

import SpriteKit

final class QuenchWardenNode: SKNode, ArenaBossNode {

    // MARK: - Tuning

    static let baseHP = 70
    static let idleSpeed: CGFloat = 40
    static let bodyRadius: CGFloat = 34
    static let xpReward = 60
    static let attackCooldown: TimeInterval = 3.0

    // Pressure Lanes
    private var laneTelegraphTime: TimeInterval { isEnraged ? 0.7 : 1.2 }
    static let laneActiveTime: TimeInterval = 1.6
    static let laneSpacing: CGFloat = 95
    static let laneHalfWidth: CGFloat = 15
    static let laneDamage = 22

    // Cinder Aperture
    private var volleyInterval: TimeInterval { isEnraged ? 0.30 : 0.42 }
    private var volleyAngleStep: CGFloat { isEnraged ? 0.42 : 0.55 }
    static let apertureDuration: TimeInterval = 3.2

    // Quench Field — (pointsPerSecond toward boss when positive, duration)
    private var fieldPulses: [(time: TimeInterval, strength: CGFloat, duration: TimeInterval)] {
        let lead: TimeInterval = isEnraged ? 0.3 : 0.5
        return [
            (lead,        300, 0.35),   // pull in
            (lead + 0.8, -380, 0.35),   // shove out
            (lead + 1.6,  220, 0.25)    // reverse again
        ]
    }
    static let fieldDuration: TimeInterval = 2.4

    // MARK: - State

    private(set) var health: Int
    var vulnerabilityMultiplier: CGFloat = 1.0   // v1.9: capstone-debuff vulnerability
    var challengeFlatReduction: Int = 0          // v2.0 (B3): Boss Mode DEF dial
    private(set) var maxHealth: Int
    private(set) var isDead: Bool = false

    var healthPercent: CGFloat {
        guard maxHealth > 0 else { return 0 }
        return CGFloat(health) / CGFloat(maxHealth)
    }

    let contactDamage: Int = 35
    var isEnraged: Bool { healthPercent < 0.3 && !isDead }
    private var enrageTriggered = false

    // MARK: - Callbacks (GameScene wires these)

    var onFireProjectile: ((_ position: CGPoint, _ direction: CGPoint) -> Void)?
    var onLaneDamage: ((_ damage: Int) -> Void)?
    /// strength: points/sec toward the boss when positive; away when negative
    var onFieldPulse: ((_ strength: CGFloat, _ duration: TimeInterval) -> Void)?
    var onDeath: ((_ position: CGPoint, _ xpReward: Int) -> Void)?

    // MARK: - Phase Machine

    enum Phase {
        case idle
        case windingUp
        case pressureLanes
        case cinderAperture
        case quenchField
        case recovering
    }

    private(set) var phase: Phase = .idle
    private var attackTimer: TimeInterval = 3.0
    private var phaseTimer: TimeInterval = 0
    private var attackIndex: Int = 0

    // Pattern working state
    private var laneNodes: [SKShapeNode] = []
    private var laneOrigins: [CGPoint] = []
    private var laneDirection: CGPoint = .zero
    private var lanesArmed = false
    private var volleyTimer: TimeInterval = 0
    private var volleyBaseAngle: CGFloat = 0
    private var firedFieldPulses = 0

    // MARK: - Visual Nodes

    private let bodyNode: SKShapeNode
    private let brokenRing: SKShapeNode
    private let eyeNode: SKShapeNode
    private var satellites: [SKShapeNode] = []
    private var satelliteOrbits: [SKNode] = []
    private let hpBarBG: SKShapeNode
    private let hpBarFill: SKShapeNode
    private let nameLabel: SKLabelNode

    // MARK: - Init

    init(hpScaling: Int = 0) {
        self.health = QuenchWardenNode.baseHP + hpScaling
        self.maxHealth = QuenchWardenNode.baseHP + hpScaling

        let r = QuenchWardenNode.bodyRadius

        // Quenched-iron disk
        bodyNode = SKShapeNode(circleOfRadius: r)
        bodyNode.fillColor = SKColor(hex: 0x1A1D22)
        bodyNode.strokeColor = SKColor(hex: 0x6A6256, alpha: 0.6)
        bodyNode.lineWidth = 1.5
        bodyNode.zPosition = 5

        // One large broken outer ring, rotating clockwise
        brokenRing = SKShapeNode()
        let ringPath = CGMutablePath()
        ringPath.addArc(center: .zero, radius: r + 10,
                        startAngle: 0.3, endAngle: .pi * 1.75, clockwise: false)
        brokenRing.path = ringPath
        brokenRing.strokeColor = SKColor(hex: 0x6A6256, alpha: 0.85)
        brokenRing.fillColor = .clear
        brokenRing.lineWidth = 2.5
        brokenRing.glowWidth = 3
        brokenRing.zPosition = 4

        // Single horizontal slit eye — opens into a thin amber line on attack
        eyeNode = SKShapeNode(rectOf: CGSize(width: r * 0.9, height: 2), cornerRadius: 1)
        eyeNode.fillColor = SKColor(hex: 0xD8A94A)
        eyeNode.strokeColor = .clear
        eyeNode.glowWidth = 2
        eyeNode.yScale = 0.5   // nearly shut at rest
        eyeNode.zPosition = 6

        // HP bar + name (Titan styling, ash palette)
        let barW: CGFloat = r * 2
        let barH: CGFloat = 5

        hpBarBG = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 2)
        hpBarBG.fillColor = SKColor(hex: 0x1A1A18)
        hpBarBG.strokeColor = SKColor(hex: 0x44403A, alpha: 0.5)
        hpBarBG.lineWidth = 0.5
        hpBarBG.position = CGPoint(x: 0, y: r + 18)
        hpBarBG.zPosition = 7

        hpBarFill = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 2)
        hpBarFill.fillColor = SKColor(hex: 0xB8B0A4)
        hpBarFill.strokeColor = .clear
        hpBarFill.position = CGPoint(x: 0, y: r + 18)
        hpBarFill.zPosition = 8

        nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = "The Quench Warden"
        nameLabel.fontSize = 9
        nameLabel.fontColor = SKColor(hex: 0xB8B0A4)
        nameLabel.position = CGPoint(x: 0, y: r + 27)
        nameLabel.zPosition = 7

        super.init()

        addChild(brokenRing)
        addChild(bodyNode)
        addChild(eyeNode)
        addChild(hpBarBG)
        addChild(hpBarFill)
        addChild(nameLabel)

        // Three satellite nodes orbiting unevenly — body language, not summons
        let satSpecs: [(radius: CGFloat, speed: TimeInterval, size: CGFloat)] = [
            (r + 22, 3.2, 5),
            (r + 30, 4.6, 4),
            (r + 26, 2.5, 4.5)
        ]
        for (i, spec) in satSpecs.enumerated() {
            let orbit = SKNode()
            orbit.zRotation = CGFloat(i) * 2.1
            orbit.zPosition = 5

            let sat = SKShapeNode(circleOfRadius: spec.size)
            sat.fillColor = SKColor(hex: 0x2A2D33)
            sat.strokeColor = SKColor(hex: 0xD8A94A, alpha: 0.6)
            sat.lineWidth = 1
            sat.glowWidth = 2
            sat.position = CGPoint(x: spec.radius, y: 0)
            orbit.addChild(sat)

            addChild(orbit)
            satellites.append(sat)
            satelliteOrbits.append(orbit)

            orbit.run(SKAction.repeatForever(
                SKAction.rotate(byAngle: .pi * 2, duration: spec.speed)
            ), withKey: "orbit")
        }

        setupPhysics()
        startIdleAnimations()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Physics

    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: QuenchWardenNode.bodyRadius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = GameConfig.Physics.enemy
        body.contactTestBitMask = GameConfig.Physics.player | GameConfig.Physics.projectile
        body.collisionBitMask = 0
        body.linearDamping = 0
        body.friction = 0
        physicsBody = body
    }

    private func startIdleAnimations() {
        brokenRing.run(SKAction.repeatForever(
            SKAction.rotate(byAngle: -.pi * 2, duration: 6.0)  // clockwise
        ), withKey: "ringSpin")

        let breathe = SKAction.sequence([
            SKAction.scaleY(to: 0.3, duration: 1.4),
            SKAction.scaleY(to: 0.6, duration: 1.4)
        ])
        eyeNode.run(SKAction.repeatForever(breathe), withKey: "eyeBreathe")
    }

    // MARK: - Update

    func update(deltaTime dt: TimeInterval, playerPosition: CGPoint) {
        guard !isDead else { return }

        updateHPBar()
        checkEnrage()

        switch phase {
        case .idle:
            updateIdle(dt: dt, target: playerPosition)
        case .windingUp:
            break  // holds position; transition is action-driven
        case .pressureLanes:
            updatePressureLanes(dt: dt, playerPosition: playerPosition)
        case .cinderAperture:
            updateCinderAperture(dt: dt)
        case .quenchField:
            updateQuenchField(dt: dt)
        case .recovering:
            phaseTimer -= dt
            if phaseTimer <= 0 {
                phase = .idle
                attackTimer = QuenchWardenNode.attackCooldown
            }
        }
    }

    private func updateIdle(dt: TimeInterval, target: CGPoint) {
        let dir = (target - position).normalized
        position += dir * QuenchWardenNode.idleSpeed * CGFloat(dt)

        attackTimer -= dt
        if attackTimer <= 0 {
            beginNextAttack()
        }
    }

    // MARK: - Attack Dispatch

    private func beginNextAttack() {
        let patterns: [Phase] = [.pressureLanes, .cinderAperture, .quenchField]
        let next = patterns[attackIndex % patterns.count]
        attackIndex += 1

        phase = .windingUp
        openEye()

        let windup: TimeInterval = isEnraged ? 0.5 : 0.8
        switch next {
        case .pressureLanes:  showTell("≡", colorHex: 0xD8D0C4)
        case .cinderAperture: showTell("◈", colorHex: 0xBB44FF)
        case .quenchField:    showTell("◎", colorHex: 0xB8B0A4)
        default: break
        }

        run(SKAction.wait(forDuration: windup)) { [weak self] in
            guard let self = self, !self.isDead else { return }
            self.phaseTimer = 0
            switch next {
            case .pressureLanes:  self.startPressureLanes()
            case .cinderAperture: self.startCinderAperture()
            case .quenchField:    self.startQuenchField()
            default: break
            }
            self.phase = next
        }
    }

    private func endAttack() {
        closeEye()
        phase = .recovering
        phaseTimer = isEnraged ? 0.8 : 1.2
    }

    private func showTell(_ text: String, colorHex: UInt32) {
        let warn = SKLabelNode(fontNamed: "Menlo-Bold")
        warn.text = text
        warn.fontSize = 22
        warn.fontColor = SKColor(hex: colorHex)
        warn.position = CGPoint(x: 0, y: QuenchWardenNode.bodyRadius + 40)
        warn.zPosition = 10
        addChild(warn)

        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.12),
            SKAction.fadeAlpha(to: 1.0, duration: 0.12)
        ])
        warn.run(SKAction.sequence([
            SKAction.repeat(blink, count: 3),
            SKAction.removeFromParent()
        ]))
    }

    private func openEye() {
        eyeNode.removeAction(forKey: "eyeBreathe")
        eyeNode.run(SKAction.scaleY(to: 1.6, duration: 0.2))
    }

    private func closeEye() {
        eyeNode.run(SKAction.scaleY(to: 0.5, duration: 0.3)) { [weak self] in
            self?.startEyeBreathe()
        }
    }

    private func startEyeBreathe() {
        let breathe = SKAction.sequence([
            SKAction.scaleY(to: 0.3, duration: 1.4),
            SKAction.scaleY(to: 0.6, duration: 1.4)
        ])
        eyeNode.run(SKAction.repeatForever(breathe), withKey: "eyeBreathe")
    }

    // MARK: - Pattern 1: Pressure Lanes

    private func startPressureLanes() {
        guard let world = parent else { return }

        brokenRing.removeAction(forKey: "ringSpin")  // the tell: the ring stops

        let theta = CGFloat.random(in: 0...(2 * .pi))
        laneDirection = CGPoint(x: cos(theta), y: sin(theta))
        let perp = CGPoint(x: -laneDirection.y, y: laneDirection.x)

        laneNodes = []
        laneOrigins = []
        lanesArmed = false

        let span = GameConfig.Arena.radius * 2.2
        for k in -2...2 {
            let origin = perp * (CGFloat(k) * QuenchWardenNode.laneSpacing)

            let lane = SKShapeNode(rectOf: CGSize(width: span,
                                                  height: QuenchWardenNode.laneHalfWidth * 2),
                                   cornerRadius: 4)
            lane.fillColor = SKColor(hex: 0xD8D0C4, alpha: 0.08)
            lane.strokeColor = SKColor(hex: 0xD8D0C4, alpha: 0.25)
            lane.lineWidth = 1
            lane.position = origin
            lane.zRotation = theta
            lane.zPosition = 3
            world.addChild(lane)

            laneNodes.append(lane)
            laneOrigins.append(origin)
        }
    }

    private func updatePressureLanes(dt: TimeInterval, playerPosition: CGPoint) {
        phaseTimer += dt

        if !lanesArmed && phaseTimer >= laneTelegraphTime {
            lanesArmed = true
            for lane in laneNodes {
                lane.fillColor = SKColor(hex: 0xF0EDE6, alpha: 0.35)
                lane.strokeColor = SKColor(hex: 0xFFFFFF, alpha: 0.7)
                lane.glowWidth = 4
            }
        }

        if lanesArmed {
            // Distance from player to each lane's center line
            for origin in laneOrigins {
                let rel = playerPosition - origin
                let perpDist = abs(rel.x * (-laneDirection.y) + rel.y * laneDirection.x)
                if perpDist < QuenchWardenNode.laneHalfWidth + GameConfig.Player.collisionRadius {
                    onLaneDamage?(QuenchWardenNode.laneDamage)
                    break
                }
            }
        }

        if phaseTimer >= laneTelegraphTime + QuenchWardenNode.laneActiveTime {
            clearLanes()
            brokenRing.run(SKAction.repeatForever(
                SKAction.rotate(byAngle: -.pi * 2, duration: isEnraged ? 3.5 : 6.0)
            ), withKey: "ringSpin")
            endAttack()
        }
    }

    private func clearLanes() {
        for lane in laneNodes {
            lane.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.25),
                SKAction.removeFromParent()
            ]))
        }
        laneNodes = []
        laneOrigins = []
        lanesArmed = false
    }

    // MARK: - Pattern 2: Cinder Aperture

    private func startCinderAperture() {
        volleyTimer = 0
        volleyBaseAngle = CGFloat.random(in: 0...(2 * .pi))

        // Satellites lock into a triangle
        for (i, orbit) in satelliteOrbits.enumerated() {
            orbit.removeAction(forKey: "orbit")
            let target = CGFloat(i) * (2 * .pi / 3) + .pi / 2
            orbit.run(SKAction.rotate(toAngle: target, duration: 0.3, shortestUnitArc: true))
        }
    }

    private func updateCinderAperture(dt: TimeInterval) {
        phaseTimer += dt
        volleyTimer += dt

        if volleyTimer >= volleyInterval {
            volleyTimer = 0
            volleyBaseAngle += volleyAngleStep

            for (i, sat) in satellites.enumerated() {
                guard let world = parent else { break }
                let worldPos = sat.parent?.convert(sat.position, to: world) ?? position
                let angle = volleyBaseAngle + CGFloat(i) * (2 * .pi / 3)
                let dir = CGPoint(x: cos(angle), y: sin(angle))
                onFireProjectile?(worldPos, dir)
            }
        }

        if phaseTimer >= QuenchWardenNode.apertureDuration {
            // Satellites resume their uneven orbits
            for (i, orbit) in satelliteOrbits.enumerated() {
                let speeds: [TimeInterval] = [3.2, 4.6, 2.5]
                orbit.run(SKAction.repeatForever(
                    SKAction.rotate(byAngle: .pi * 2, duration: speeds[i % speeds.count])
                ), withKey: "orbit")
            }
            endAttack()
        }
    }

    // MARK: - Pattern 3: Quench Field

    private func startQuenchField() {
        firedFieldPulses = 0
    }

    private func updateQuenchField(dt: TimeInterval) {
        phaseTimer += dt

        let pulses = fieldPulses
        if firedFieldPulses < pulses.count && phaseTimer >= pulses[firedFieldPulses].time {
            let pulse = pulses[firedFieldPulses]
            firedFieldPulses += 1
            onFieldPulse?(pulse.strength, pulse.duration)
            showFieldRing(inward: pulse.strength > 0)
        }

        if phaseTimer >= QuenchWardenNode.fieldDuration {
            endAttack()
        }
    }

    private func showFieldRing(inward: Bool) {
        let startRadius: CGFloat = inward ? 180 : 40
        let endScale: CGFloat = inward ? 0.25 : 4.5

        let ring = SKShapeNode(circleOfRadius: startRadius)
        ring.strokeColor = SKColor(hex: 0xB8B0A4, alpha: 0.6)
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.glowWidth = 3
        ring.zPosition = 3
        addChild(ring)

        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: endScale, duration: 0.4),
                SKAction.fadeOut(withDuration: 0.4)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Enrage: Final Temper

    private func checkEnrage() {
        guard isEnraged, !enrageTriggered else { return }
        enrageTriggered = true

        // The ring cracks and spins faster. Same tools, less mercy.
        brokenRing.removeAction(forKey: "ringSpin")
        brokenRing.run(SKAction.repeatForever(
            SKAction.rotate(byAngle: -.pi * 2, duration: 3.5)
        ), withKey: "ringSpin")
        brokenRing.strokeColor = SKColor(hex: 0xD8A94A, alpha: 0.9)

        eyeNode.fillColor = SKColor(hex: 0xFFCC66)
        eyeNode.glowWidth = 4
    }

    // MARK: - HP Bar

    private func updateHPBar() {
        let pct = healthPercent
        let barW = QuenchWardenNode.bodyRadius * 2
        let barH: CGFloat = 5
        let fillW = max(1, barW * pct)

        hpBarFill.path = CGPath(
            roundedRect: CGRect(x: -barW / 2, y: -barH / 2, width: fillW, height: barH),
            cornerWidth: 2, cornerHeight: 2, transform: nil
        )

        if pct < 0.3 {
            hpBarFill.fillColor = SKColor(hex: 0xD8A94A)  // Final Temper amber
        }
    }

    // MARK: - Damage

    /// v2.0 (B3): Boss Mode HP dial. Applied at SPAWN only — scaling mid-fight
    /// would make the health bar lie about a fight already in progress.
    func applyChallengeHealthScale(_ factor: CGFloat) {
        guard factor != 1.0 else { return }
        maxHealth = max(1, Int((CGFloat(maxHealth) * factor).rounded()))
        health = maxHealth
    }

    @discardableResult
    func takeDamage(_ amount: Int) -> Bool {
        guard !isDead else { return false }
        let scaled = vulnerabilityMultiplier == 1.0
            ? amount
            : Int((CGFloat(amount) * vulnerabilityMultiplier).rounded())
        health -= challengedDamage(scaled, raw: amount)

        let flash = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.bodyNode.fillColor = SKColor(hex: 0x3A3D44)
                self?.eyeNode.fillColor = .white
            },
            SKAction.wait(forDuration: 0.06),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.bodyNode.fillColor = SKColor(hex: 0x1A1D22)
                self.eyeNode.fillColor = SKColor(hex: self.enrageTriggered ? 0xFFCC66 : 0xD8A94A)
            }
        ])
        run(flash)

        if health <= 0 {
            health = 0
            die()
            return true
        }
        return false
    }

    // MARK: - Death

    private func die() {
        isDead = true
        physicsBody?.categoryBitMask = 0
        phase = .idle
        clearLanes()

        // The eye opens fully, the ring shatters outward, the body collapses
        let deathSequence = SKAction.sequence([
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.eyeNode.run(SKAction.scaleY(to: 3.0, duration: 0.35))
                self.eyeNode.run(SKAction.fadeAlpha(to: 1.0, duration: 0.1))
                self.brokenRing.removeAction(forKey: "ringSpin")
                self.brokenRing.run(SKAction.group([
                    SKAction.scale(to: 2.2, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5)
                ]))
                for orbit in self.satelliteOrbits {
                    orbit.removeAction(forKey: "orbit")
                    orbit.run(SKAction.group([
                        SKAction.scale(to: 1.8, duration: 0.4),
                        SKAction.fadeOut(withDuration: 0.4)
                    ]))
                }
            },
            SKAction.wait(forDuration: 0.5),
            SKAction.group([
                SKAction.scale(to: 0.0, duration: 0.35),
                SKAction.fadeOut(withDuration: 0.35)
            ]),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.onDeath?(self.position, QuenchWardenNode.xpReward)
            },
            SKAction.removeFromParent()
        ])

        hpBarBG.run(SKAction.fadeOut(withDuration: 0.2))
        hpBarFill.run(SKAction.fadeOut(withDuration: 0.2))
        nameLabel.run(SKAction.fadeOut(withDuration: 0.2))

        run(deathSequence)
    }

    /// Clean up world-space lane nodes if the run ends mid-pattern.
    func cleanupWorldEffects() {
        clearLanes()
    }

    // MARK: - Spawn

    static func spawnPosition() -> CGPoint {
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance = GameConfig.Arena.radius + 80
        return CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
    }
}
