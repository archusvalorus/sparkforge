// FacetedLieNode.swift
// Sparkforge
//
// v1.8 Arena 4 boss (Lyra canon): The Faceted Lie.
// Titan = impact, Warden = pressure, Choir = rhythm — the Lie is DECEPTION.
// It misleads, delays, reflects, relocates. It never charges, slams, summons,
// or conducts. A central smoked-glass core wearing five asymmetric shard
// plates that rotate idle, separate on tells, and snap to a false symmetry
// before it strikes — never a full shield ring, never a stable face.
//
// Three patterns:
//   False Safe   — floor shards glow; most pale-silver (SAFE, never damage),
//                  one-plus purple (danger). The trick is anxiety, not betrayal.
//   Reflection Volley — a purple pattern fires, then a delayed mirrored copy
//                  follows from the opposite side. Dodge the first; don't step
//                  into the echo.
//   Pane Shift   — cracked circles mark the floor, one flickers purple; the
//                  boss vanishes, reappears on a marked pane, bursts. Don't camp.
// Enrage (No More Masks, <30% HP): tells shorten, Pane Shift gains a mirror
// point, a thin crack-mouth appears. "The lie stops pretending."

import SpriteKit

final class FacetedLieNode: SKNode, ArenaBossNode {

    // MARK: - Tuning

    static let baseHP = 90
    static let idleSpeed: CGFloat = 34
    static let bodyRadius: CGFloat = 30
    static let xpReward = 72
    // v1.8 (Brandon playtest): tightened the loop — ~2s less dead air between
    // attack cycles so the deception keeps coming (was 3.0).
    static let attackCooldown: TimeInterval = 1.0

    private var windupTime: TimeInterval { isEnraged ? 0.5 : 0.8 }
    private var recoverTime: TimeInterval { isEnraged ? 0.6 : 1.1 }

    // False Safe
    private var falseSafeTell: TimeInterval { isEnraged ? 0.7 : 1.1 }
    static let falseSafeLiveTime: TimeInterval = 0.6
    static let falseSafePlateCount = 6
    static let falseSafeRadius: CGFloat = 150      // spread of plates around the player
    static let falseSafePlateReach: CGFloat = 30   // how close counts as "standing on it"
    static let falseSafeDamage = 20

    // Reflection Volley — v1.8 (Brandon playtest): faster shots, and the fan
    // GROWS as the mask cracks — 3 per side, then 4 under 50% HP, 5 under 25%.
    private var volleyEchoDelay: TimeInterval { isEnraged ? 0.6 : 0.95 }
    static let volleyEndPad: TimeInterval = 0.5
    static let volleyProjectileSpeed: CGFloat = 250   // was the 180 ranged default
    private var volleyFanCount: Int {
        if healthPercent < 0.25 { return 5 }
        if healthPercent < 0.5 { return 4 }
        return 3
    }
    static let volleyFanSpread: CGFloat = 0.5

    // Pane Shift — v1.8 (Brandon playtest): more panes to read (was 5).
    private var paneShiftTell: TimeInterval { isEnraged ? 0.6 : 0.9 }
    static let paneShiftVanishTime: TimeInterval = 0.25
    static let paneMarkCount = 7
    static let paneSpread: CGFloat = 180
    static let paneBurstRadius: CGFloat = 95
    static let paneBurstDamage = 22

    // MARK: - State

    private(set) var health: Int
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

    var onFireProjectile: ((_ position: CGPoint, _ direction: CGPoint, _ speed: CGFloat) -> Void)?
    /// Real danger only — a purple shard the player is standing on, or a
    /// Pane Shift burst that caught them. Silver shards NEVER call this.
    var onHazardDamage: ((_ damage: Int) -> Void)?
    var onDeath: ((_ position: CGPoint, _ xpReward: Int) -> Void)?

    // MARK: - Phase Machine

    enum Phase {
        case idle
        case windingUp
        case falseSafe
        case reflectionVolley
        case paneShift
        case recovering
    }

    private(set) var phase: Phase = .idle
    private var attackTimer: TimeInterval = 3.0
    private var phaseTimer: TimeInterval = 0
    private var attackIndex: Int = 0

    // False Safe working state (world-space)
    private var falseSafePlates: [(node: SKShapeNode, danger: Bool)] = []
    private var falseSafeBeat = 0        // 0 preview, 1 live
    private var falseSafeStruck = false

    // Reflection Volley working state
    private var volleyFired = false
    private var echoFired = false
    private var volleyTarget: CGPoint = .zero
    private var volleyOrigin: CGPoint = .zero

    // Pane Shift working state (world-space)
    private var paneMarks: [(node: SKShapeNode, danger: Bool)] = []
    private var paneBeat = 0             // 0 preview, 1 vanished, 2 burst
    private var paneReentry: CGPoint = .zero

    // MARK: - Visual Nodes

    private let coreNode: SKShapeNode
    private let shardCluster: SKNode      // holds the five plates; rotates idle
    private var shardPlates: [SKShapeNode] = []
    private var plateEyes: [SKShapeNode] = []
    private let crackMouth: SKShapeNode   // hidden until enrage
    private let hpBarBG: SKShapeNode
    private let hpBarFill: SKShapeNode
    private let nameLabel: SKLabelNode

    // MARK: - Init

    init(hpScaling: Int = 0) {
        self.health = FacetedLieNode.baseHP + hpScaling
        self.maxHealth = FacetedLieNode.baseHP + hpScaling

        let r = FacetedLieNode.bodyRadius

        // Central smoked-glass core.
        coreNode = SKShapeNode(circleOfRadius: r * 0.6)
        coreNode.fillColor = SKColor(hex: 0x17161A)
        coreNode.strokeColor = SKColor(hex: 0xD6CCC2, alpha: 0.5)
        coreNode.lineWidth = 1.5
        coreNode.zPosition = 5

        shardCluster = SKNode()
        shardCluster.zPosition = 6

        // A thin crack-mouth, revealed only at enrage.
        crackMouth = SKShapeNode()
        let mouthPath = CGMutablePath()
        mouthPath.move(to: CGPoint(x: -r * 0.35, y: -r * 0.15))
        mouthPath.addLine(to: CGPoint(x: -r * 0.1, y: -r * 0.22))
        mouthPath.addLine(to: CGPoint(x: r * 0.1, y: -r * 0.13))
        mouthPath.addLine(to: CGPoint(x: r * 0.35, y: -r * 0.2))
        crackMouth.path = mouthPath
        crackMouth.strokeColor = SKColor(hex: 0x8E44FF, alpha: 0.9)
        crackMouth.lineWidth = 1.5
        crackMouth.zPosition = 7
        crackMouth.alpha = 0

        // HP bar + name (mirror-silver palette).
        let barW: CGFloat = r * 2
        let barH: CGFloat = 5

        hpBarBG = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 2)
        hpBarBG.fillColor = SKColor(hex: 0x1A1A1E)
        hpBarBG.strokeColor = SKColor(hex: 0x3E3A44, alpha: 0.5)
        hpBarBG.lineWidth = 0.5
        hpBarBG.position = CGPoint(x: 0, y: r + 18)
        hpBarBG.zPosition = 7

        hpBarFill = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 2)
        hpBarFill.fillColor = SKColor(hex: 0xD6CCC2)
        hpBarFill.strokeColor = .clear
        hpBarFill.position = CGPoint(x: 0, y: r + 18)
        hpBarFill.zPosition = 8

        nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = "The Faceted Lie"
        nameLabel.fontSize = 9
        nameLabel.fontColor = SKColor(hex: 0xD6CCC2)
        nameLabel.position = CGPoint(x: 0, y: r + 27)
        nameLabel.zPosition = 7

        super.init()

        addChild(coreNode)
        addChild(shardCluster)
        addChild(crackMouth)
        addChild(hpBarBG)
        addChild(hpBarFill)
        addChild(nameLabel)

        buildShardPlates()
        startIdleRotation()
        setupPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Shard silhouette

    /// Five asymmetric triangular plates at uneven angles and distances —
    /// deliberately NOT a ring. Two carry hidden eyes that surface on tells.
    private func buildShardPlates() {
        let r = FacetedLieNode.bodyRadius
        // Uneven angular placement (no even spacing) + uneven reach.
        let specs: [(angle: CGFloat, dist: CGFloat, size: CGFloat)] = [
            (0.3, r * 0.95, r * 0.55),
            (1.5, r * 1.10, r * 0.45),
            (2.7, r * 0.90, r * 0.60),
            (3.9, r * 1.15, r * 0.50),
            (5.3, r * 1.00, r * 0.52)
        ]
        for (i, spec) in specs.enumerated() {
            let center = CGPoint(x: cos(spec.angle) * spec.dist,
                                 y: sin(spec.angle) * spec.dist)
            let plate = SKShapeNode(path: Self.trianglePath(size: spec.size,
                                                            rotation: spec.angle + 0.4))
            plate.position = center
            plate.fillColor = SKColor(hex: 0x17161A, alpha: 0.95)
            plate.strokeColor = SKColor(hex: 0xD6CCC2, alpha: 0.55)
            plate.lineWidth = 1
            plate.zPosition = 6
            shardCluster.addChild(plate)
            shardPlates.append(plate)

            // Two plates hide an eye that opens during tells.
            if i == 1 || i == 3 {
                let eye = SKShapeNode(circleOfRadius: 2.2)
                eye.fillColor = SKColor(hex: 0x8E44FF)
                eye.strokeColor = .clear
                eye.glowWidth = 2
                eye.position = center
                eye.zPosition = 7
                eye.alpha = 0
                shardCluster.addChild(eye)
                plateEyes.append(eye)
            }
        }
    }

    private static func trianglePath(size: CGFloat, rotation: CGFloat) -> CGPath {
        let verts: [CGFloat] = [0.0, 2.2, 4.2]   // uneven → irregular triangle
        let radii: [CGFloat] = [1.0, 0.75, 0.9]
        let path = CGMutablePath()
        for (i, v) in verts.enumerated() {
            let a = v + rotation
            let p = CGPoint(x: cos(a) * size * radii[i], y: sin(a) * size * radii[i])
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    private func startIdleRotation() {
        shardCluster.removeAction(forKey: "idle")
        let spin = SKAction.rotate(byAngle: .pi * 2, duration: 14)
        shardCluster.run(SKAction.repeatForever(spin), withKey: "idle")
    }

    /// Plates drift outward and the hidden eyes open — the boss "looks" at you.
    private func separatePlates() {
        shardCluster.run(SKAction.scale(to: 1.28, duration: 0.25), withKey: "sep")
        for eye in plateEyes {
            eye.run(SKAction.fadeAlpha(to: 1.0, duration: 0.2))
        }
    }

    /// Plates snap inward to a tight FALSE symmetry an instant before striking.
    private func regroupPlates() {
        shardCluster.run(SKAction.scale(to: 1.0, duration: 0.2), withKey: "sep")
        for eye in plateEyes {
            eye.run(SKAction.fadeAlpha(to: 0.0, duration: 0.2))
        }
    }

    // MARK: - Physics

    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: FacetedLieNode.bodyRadius * 0.7)
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

    // MARK: - Update

    func update(deltaTime dt: TimeInterval, playerPosition: CGPoint) {
        guard !isDead else { return }

        lastTarget = playerPosition   // freshest read for windup-end capture
        updateHPBar()
        checkEnrage()

        switch phase {
        case .idle:
            updateIdle(dt: dt, target: playerPosition)
        case .windingUp:
            break  // holds; transition is action-driven
        case .falseSafe:
            updateFalseSafe(dt: dt, playerPosition: playerPosition)
        case .reflectionVolley:
            updateReflectionVolley(dt: dt)
        case .paneShift:
            updatePaneShift(dt: dt, playerPosition: playerPosition)
        case .recovering:
            phaseTimer -= dt
            if phaseTimer <= 0 {
                phase = .idle
                attackTimer = FacetedLieNode.attackCooldown * (isEnraged ? 0.65 : 1.0)
            }
        }
    }

    private func updateIdle(dt: TimeInterval, target: CGPoint) {
        // A slow, untrustworthy drift — never a beeline.
        let dir = (target - position).normalized
        position += dir * FacetedLieNode.idleSpeed * CGFloat(dt)

        attackTimer -= dt
        if attackTimer <= 0 {
            beginNextAttack(playerPosition: target)
        }
    }

    // MARK: - Attack Dispatch

    private func beginNextAttack(playerPosition: CGPoint) {
        let patterns: [Phase] = [.falseSafe, .reflectionVolley, .paneShift]
        let next = patterns[attackIndex % patterns.count]
        attackIndex += 1

        phase = .windingUp
        separatePlates()

        switch next {
        case .falseSafe:        showTell("△")
        case .reflectionVolley: showTell("◑")
        case .paneShift:        showTell("◇")
        default: break
        }

        run(SKAction.wait(forDuration: windupTime)) { [weak self] in
            guard let self = self, !self.isDead else { return }
            self.regroupPlates()
            self.phaseTimer = 0
            switch next {
            case .falseSafe:        self.startFalseSafe(playerPosition: self.currentTarget(fallback: playerPosition))
            case .reflectionVolley: self.startReflectionVolley(playerPosition: self.currentTarget(fallback: playerPosition))
            case .paneShift:        self.startPaneShift(playerPosition: self.currentTarget(fallback: playerPosition))
            default: break
            }
            self.phase = next
        }
    }

    /// The player keeps moving during the windup; attacks captured at the
    /// windup end read fairer than ones frozen at its start. GameScene passes
    /// the live position through update, so we just reuse the last known one.
    private var lastTarget: CGPoint = .zero
    private func currentTarget(fallback: CGPoint) -> CGPoint {
        return lastTarget == .zero ? fallback : lastTarget
    }

    private func endAttack() {
        phase = .recovering
        phaseTimer = recoverTime
    }

    private func showTell(_ text: String) {
        let warn = SKLabelNode(fontNamed: "Menlo-Bold")
        warn.text = text
        warn.fontSize = 22
        warn.fontColor = SKColor(hex: 0x8E44FF)
        warn.position = CGPoint(x: 0, y: FacetedLieNode.bodyRadius + 40)
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

    // MARK: - Pattern 1: False Safe

    /// Shards bloom around the player — most pale-silver (SAFE), one-plus
    /// purple (danger). Silver never damages: the trick is anxiety, not betrayal.
    private func startFalseSafe(playerPosition: CGPoint) {
        falseSafeBeat = 0
        falseSafeStruck = false
        falseSafePlates = []
        guard let world = parent else { return }

        let count = FacetedLieNode.falseSafePlateCount
        let dangerCount = isEnraged ? 2 : 1
        var dangerIndices = Set<Int>()
        while dangerIndices.count < dangerCount {
            dangerIndices.insert(Int.random(in: 0..<count))
        }

        let gapStart = CGFloat.random(in: 0...(2 * .pi))
        for i in 0..<count {
            let angle = gapStart + (2 * .pi) * CGFloat(i) / CGFloat(count)
            let reach = FacetedLieNode.falseSafeRadius * CGFloat.random(in: 0.5...1.0)
            let point = playerPosition + CGPoint(x: cos(angle) * reach, y: sin(angle) * reach)
            let danger = dangerIndices.contains(i)

            let plate = SKShapeNode(path: Self.trianglePath(size: 26,
                                                            rotation: CGFloat.random(in: 0...(2 * .pi))))
            plate.position = point
            plate.zPosition = 3
            // Silver = safe, purple = danger — legible from the first frame.
            let tint: UInt32 = danger ? 0x8E44FF : 0xD6CCC2
            plate.fillColor = SKColor(hex: tint, alpha: 0.12)
            plate.strokeColor = SKColor(hex: tint, alpha: 0.7)
            plate.lineWidth = 1.5
            plate.glowWidth = danger ? 3 : 0
            world.addChild(plate)
            falseSafePlates.append((plate, danger))

            plate.alpha = 0
            plate.run(SKAction.fadeIn(withDuration: 0.2))
        }
    }

    private func updateFalseSafe(dt: TimeInterval, playerPosition: CGPoint) {
        phaseTimer += dt

        // Beat 1: after the tell, the purple plates fire.
        if falseSafeBeat == 0 && phaseTimer >= falseSafeTell {
            falseSafeBeat = 1
            for (plate, danger) in falseSafePlates where danger {
                plate.fillColor = SKColor(hex: 0x8E44FF, alpha: 0.55)
                plate.run(SKAction.sequence([
                    SKAction.scale(to: 1.4, duration: 0.12),
                    SKAction.scale(to: 1.0, duration: 0.15)
                ]))
            }
        }

        // Live window: standing on a PURPLE plate hurts. Silver is inert.
        if falseSafeBeat == 1 && !falseSafeStruck {
            let reach = FacetedLieNode.falseSafePlateReach + GameConfig.Player.collisionRadius
            for (plate, danger) in falseSafePlates where danger {
                if playerPosition.distance(to: plate.position) < reach {
                    falseSafeStruck = true
                    onHazardDamage?(FacetedLieNode.falseSafeDamage)
                    break
                }
            }
        }

        if phaseTimer >= falseSafeTell + FacetedLieNode.falseSafeLiveTime {
            clearFalseSafe()
            endAttack()
        }
    }

    private func clearFalseSafe() {
        for (plate, _) in falseSafePlates {
            plate.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))
        }
        falseSafePlates = []
        falseSafeBeat = 0
    }

    // MARK: - Pattern 2: Reflection Volley

    /// A fan fires toward the player; a delayed mirrored copy follows from the
    /// opposite side (mirrored across the player). Dodge the first, then don't
    /// step into the echo.
    private func startReflectionVolley(playerPosition: CGPoint) {
        volleyFired = false
        echoFired = false
        volleyTarget = playerPosition
        volleyOrigin = position
    }

    private func updateReflectionVolley(dt: TimeInterval) {
        phaseTimer += dt

        // Beat 1: the real volley, from the boss toward the player.
        if !volleyFired {
            volleyFired = true
            fireFan(from: volleyOrigin, toward: volleyTarget)
            flashEyes()
        }

        // Beat 2: the echo, from the opposite side of the player.
        if !echoFired && phaseTimer >= volleyEchoDelay {
            echoFired = true
            let mirrorOrigin = volleyTarget + (volleyTarget - volleyOrigin)  // opposite side
            fireFan(from: mirrorOrigin, toward: volleyTarget)
            flashEyes()
        }

        if phaseTimer >= volleyEchoDelay + FacetedLieNode.volleyEndPad {
            endAttack()
        }
    }

    private func fireFan(from origin: CGPoint, toward target: CGPoint) {
        let base = (target - origin).normalized
        let baseAngle = atan2(base.y, base.x)
        let count = volleyFanCount
        let spread = FacetedLieNode.volleyFanSpread
        for k in 0..<count {
            let offset = spread * (CGFloat(k) - CGFloat(count - 1) / 2)
            let dir = CGPoint(x: cos(baseAngle + offset), y: sin(baseAngle + offset))
            onFireProjectile?(origin, dir, FacetedLieNode.volleyProjectileSpeed)
        }
    }

    private func flashEyes() {
        for eye in plateEyes {
            eye.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 1.0, duration: 0.05),
                SKAction.fadeAlpha(to: 0.0, duration: 0.25)
            ]))
        }
    }

    // MARK: - Pattern 3: Pane Shift

    /// Cracked circles mark the floor; one-plus flicker purple (the re-entry).
    /// The boss vanishes, reappears on a purple pane, and bursts. Don't camp.
    private func startPaneShift(playerPosition: CGPoint) {
        paneBeat = 0
        paneMarks = []
        guard let world = parent else { return }

        let count = FacetedLieNode.paneMarkCount
        let dangerCount = isEnraged ? 2 : 1
        var dangerIndices = Set<Int>()
        while dangerIndices.count < dangerCount {
            dangerIndices.insert(Int.random(in: 0..<count))
        }

        for i in 0..<count {
            let angle = CGFloat(i) * (2 * .pi / CGFloat(count)) + CGFloat.random(in: -0.3...0.3)
            let reach = FacetedLieNode.paneSpread * CGFloat.random(in: 0.55...1.0)
            let point = playerPosition + CGPoint(x: cos(angle) * reach, y: sin(angle) * reach)
            let danger = dangerIndices.contains(i)

            let mark = SKShapeNode(circleOfRadius: FacetedLieNode.paneBurstRadius * 0.5)
            mark.position = point
            mark.zPosition = 3
            let tint: UInt32 = danger ? 0x8E44FF : 0xD6CCC2
            mark.fillColor = .clear
            mark.strokeColor = SKColor(hex: tint, alpha: danger ? 0.85 : 0.4)
            mark.lineWidth = danger ? 2 : 1
            world.addChild(mark)
            paneMarks.append((mark, danger))

            if danger {
                mark.run(SKAction.repeatForever(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.4, duration: 0.18),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.18)
                ])))
            }
        }

        // Pick which purple pane the boss re-enters on.
        if let target = paneMarks.filter({ $0.danger }).randomElement() {
            paneReentry = target.node.position
        } else {
            paneReentry = position
        }
    }

    private func updatePaneShift(dt: TimeInterval, playerPosition: CGPoint) {
        phaseTimer += dt

        // Beat 1: after the tell, the boss vanishes.
        if paneBeat == 0 && phaseTimer >= paneShiftTell {
            paneBeat = 1
            physicsBody?.categoryBitMask = 0  // untouchable while gone
            run(SKAction.fadeAlpha(to: 0.0, duration: FacetedLieNode.paneShiftVanishTime))
        }

        // Beat 2: reappear on the marked pane and burst.
        if paneBeat == 1 && phaseTimer >= paneShiftTell + FacetedLieNode.paneShiftVanishTime {
            paneBeat = 2
            position = paneReentry
            physicsBody?.categoryBitMask = GameConfig.Physics.enemy
            run(SKAction.fadeAlpha(to: 1.0, duration: 0.12))
            emitReentryBurst()

            let reach = FacetedLieNode.paneBurstRadius + GameConfig.Player.collisionRadius
            if playerPosition.distance(to: paneReentry) < reach {
                onHazardDamage?(FacetedLieNode.paneBurstDamage)
            }
        }

        if paneBeat == 2 && phaseTimer >= paneShiftTell + FacetedLieNode.paneShiftVanishTime + 0.4 {
            clearPaneMarks()
            endAttack()
        }
    }

    private func emitReentryBurst() {
        let ring = SKShapeNode(circleOfRadius: 8)
        ring.strokeColor = SKColor(hex: 0x8E44FF, alpha: 0.85)
        ring.fillColor = .clear
        ring.lineWidth = 3
        ring.glowWidth = 4
        ring.zPosition = 4
        addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: FacetedLieNode.paneBurstRadius / 8, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.32)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func clearPaneMarks() {
        for (mark, _) in paneMarks {
            mark.removeAllActions()
            mark.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))
        }
        paneMarks = []
        paneBeat = 0
    }

    // MARK: - Enrage: No More Masks

    private func checkEnrage() {
        guard isEnraged, !enrageTriggered else { return }
        enrageTriggered = true

        // The lie stops pretending — the crack-mouth opens.
        crackMouth.run(SKAction.fadeAlpha(to: 1.0, duration: 0.3))
        coreNode.strokeColor = SKColor(hex: 0x8E44FF, alpha: 0.8)
        shardCluster.removeAction(forKey: "idle")
        let faster = SKAction.rotate(byAngle: .pi * 2, duration: 9)
        shardCluster.run(SKAction.repeatForever(faster), withKey: "idle")
    }

    // MARK: - HP Bar

    private func updateHPBar() {
        let pct = healthPercent
        let barW = FacetedLieNode.bodyRadius * 2
        let barH: CGFloat = 5
        let fillW = max(1, barW * pct)

        hpBarFill.path = CGPath(
            roundedRect: CGRect(x: -barW / 2, y: -barH / 2, width: fillW, height: barH),
            cornerWidth: 2, cornerHeight: 2, transform: nil
        )

        if pct < 0.3 {
            hpBarFill.fillColor = SKColor(hex: 0x8E44FF)  // No More Masks
        }
    }

    // MARK: - Damage

    @discardableResult
    func takeDamage(_ amount: Int) -> Bool {
        guard !isDead else { return false }
        health -= amount

        // Damage reads as a pale crack flash — never red/orange (Lyra).
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.coreNode.fillColor = SKColor(hex: 0x3A3742)
                self?.coreNode.strokeColor = SKColor(hex: 0xFFFFFF, alpha: 0.9)
            },
            SKAction.wait(forDuration: 0.06),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.coreNode.fillColor = SKColor(hex: 0x17161A)
                self.coreNode.strokeColor = self.isEnraged
                    ? SKColor(hex: 0x8E44FF, alpha: 0.8)
                    : SKColor(hex: 0xD6CCC2, alpha: 0.5)
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
        clearFalseSafe()
        clearPaneMarks()

        // The masks fall — plates scatter, the core shatters pale.
        let deathSequence = SKAction.sequence([
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.shardCluster.removeAction(forKey: "idle")
                for (i, plate) in self.shardPlates.enumerated() {
                    plate.run(SKAction.sequence([
                        SKAction.wait(forDuration: Double(i) * 0.07),
                        SKAction.group([
                            SKAction.moveBy(x: cos(CGFloat(i)) * 30, y: sin(CGFloat(i)) * 30, duration: 0.4),
                            SKAction.fadeOut(withDuration: 0.4)
                        ])
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
                self.onDeath?(self.position, FacetedLieNode.xpReward)
            },
            SKAction.removeFromParent()
        ])

        hpBarBG.run(SKAction.fadeOut(withDuration: 0.2))
        hpBarFill.run(SKAction.fadeOut(withDuration: 0.2))
        nameLabel.run(SKAction.fadeOut(withDuration: 0.2))

        run(deathSequence)
    }

    /// Clean up world-space plates/marks if the run ends mid-pattern.
    func cleanupWorldEffects() {
        clearFalseSafe()
        clearPaneMarks()
    }

    // MARK: - Spawn

    static func spawnPosition() -> CGPoint {
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance = GameConfig.Arena.radius + 80
        return CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
    }
}
