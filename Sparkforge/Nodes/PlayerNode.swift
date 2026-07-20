// PlayerNode.swift
// Sparkforge
//
// The player's spark core.
// Reads speed/collision from PlayerStats.
// Supports lethal save (Brace/Iron Skin).
//
// v1.4: HP system — player has health pool, takes damage with DEF reduction,
// lethal saves trigger at 0 HP instead of on every hit.
//
// v1.7 Spark Glow-Up (procedural-plus, per Lyra's art direction):
// layered core (white-hot inner / ember body / soft outer glow),
// directional ember-fleck trail while moving, level-up corona flare,
// damage contraction. "A coal learning to become a star."

import SpriteKit

final class PlayerNode: SKNode {

    // MARK: - State

    private(set) var currentLevel: Int = 1
    private(set) var currentXP: Int = 0
    var isDead: Bool = false

    /// Reference to runtime stats — set by GameScene
    weak var stats: PlayerStats?

    // MARK: - Visual Nodes

    private let innerCoreNode: SKShapeNode  // v1.7: white-hot center
    private let emberWrap = SKNode()        // v1.7: carries the breathe so pulses don't fight it
    private let coreNode: SKShapeNode       // ember body — the readable player mass
    private let glowNode: SKShapeNode       // soft outer aura, grows with level
    private let trailEmitter = SKEmitterNode()

    // v1.8: base-Spark eyes — two black dots that look toward travel.
    private let eyesNode = SKNode()
    private let leftEye: SKShapeNode
    private let rightEye: SKShapeNode
    private let eyeR: CGFloat   // v1.9: cached to rebuild the eye shapes (hit face)
    private var eyeOffset: CGPoint = .zero   // current directional slide (smoothed)

    // MARK: - Init

    override init() {
        let config = GameConfig.Player.self

        coreNode = SKShapeNode(circleOfRadius: config.visualRadius)
        coreNode.fillColor = SKColor(hex: config.coreColorHex)
        coreNode.strokeColor = .clear
        coreNode.zPosition = 10

        innerCoreNode = SKShapeNode(circleOfRadius: config.visualRadius * GameConfig.Spark.innerCoreRadiusFactor)
        innerCoreNode.fillColor = SKColor(hex: GameConfig.Spark.innerCoreColorHex)
        innerCoreNode.strokeColor = .clear
        innerCoreNode.blendMode = .add
        innerCoreNode.zPosition = 12

        glowNode = SKShapeNode(circleOfRadius: config.visualRadius + config.baseGlowWidth)
        glowNode.fillColor = SKColor(hex: config.glowColorHex, alpha: 0.3)
        glowNode.strokeColor = .clear
        glowNode.zPosition = 9
        glowNode.glowWidth = config.baseGlowWidth

        // v1.8: two small black eyes, above the white-hot core so they read
        // clearly. They ride an eyesNode container that slides toward travel.
        eyeR = config.visualRadius * GameConfig.Spark.eyeRadiusFactor
        leftEye = SKShapeNode(circleOfRadius: eyeR)
        rightEye = SKShapeNode(circleOfRadius: eyeR)
        for eye in [leftEye, rightEye] {
            eye.fillColor = SKColor(hex: GameConfig.Spark.eyeColorHex)
            eye.strokeColor = .clear
            eye.zPosition = 13  // above innerCore (12)
        }
        let half = config.visualRadius * GameConfig.Spark.eyeSpacingHalfFactor
        leftEye.position = CGPoint(x: -half, y: 0)
        rightEye.position = CGPoint(x: half, y: 0)

        super.init()

        addChild(glowNode)
        emberWrap.addChild(coreNode)
        addChild(emberWrap)
        addChild(innerCoreNode)

        eyesNode.zPosition = 13
        eyesNode.addChild(leftEye)
        eyesNode.addChild(rightEye)
        eyesNode.position = CGPoint(x: 0, y: config.visualRadius * GameConfig.Spark.eyeBaseYFactor)
        addChild(eyesNode)

        setupTrail()
        addChild(trailEmitter)

        // The ember body breathes — molten, alive
        let breathe = SKAction.sequence([
            SKAction.scale(to: 1.045, duration: 1.4),
            SKAction.scale(to: 1.0, duration: 1.4)
        ])
        breathe.timingMode = .easeInEaseOut
        emberWrap.run(SKAction.repeatForever(breathe))

        applyLevelVisuals()
        setupPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - v1.7: Ember Trail

    private func setupTrail() {
        let size = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: size)
        let dot = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        trailEmitter.particleTexture = SKTexture(image: dot)
        trailEmitter.particleBlendMode = .add
        trailEmitter.particleColor = SKColor(hex: 0xFF9933)
        trailEmitter.particleColorBlendFactor = 1.0
        trailEmitter.particleLifetime = GameConfig.Spark.trailLifetime
        trailEmitter.particleAlpha = 0.9
        trailEmitter.particleAlphaSpeed = -2.2
        trailEmitter.particleScale = 0.45
        trailEmitter.particleScaleRange = 0.2
        trailEmitter.particleScaleSpeed = -1.0
        trailEmitter.particleSpeed = GameConfig.Spark.trailSpeed
        trailEmitter.particleSpeedRange = 12
        trailEmitter.emissionAngleRange = 0.5
        trailEmitter.particlePositionRange = CGVector(dx: 6, dy: 6)
        trailEmitter.particleZPosition = 8
        trailEmitter.particleBirthRate = 0
    }

    private func updateTrail(direction: CGPoint) {
        // Flecks live in world space so they linger behind the spark
        if trailEmitter.targetNode == nil, let parent = parent {
            trailEmitter.targetNode = parent
        }
        let magnitude = min(direction.length, 1.0)
        guard magnitude > 0.05, !isDead else {
            trailEmitter.particleBirthRate = 0
            return
        }
        // Trail gains flecks with level — confident by mid-game
        let levelBoost = min(1.0 + CGFloat(currentLevel) * 0.06, 1.8)
        trailEmitter.particleBirthRate = GameConfig.Spark.trailMaxBirthRate * magnitude * levelBoost
        trailEmitter.emissionAngle = atan2(-direction.y, -direction.x)
    }

    // MARK: - Physics

    private func setupPhysics() {
        let config = GameConfig.Player.self
        let body = SKPhysicsBody(circleOfRadius: config.collisionRadius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = GameConfig.Physics.player
        body.contactTestBitMask = GameConfig.Physics.enemy
            | GameConfig.Physics.xpOrb
            | GameConfig.Physics.enemyProjectile
            | GameConfig.Physics.healthOrb
            | GameConfig.Physics.magnetOrb
        body.collisionBitMask = 0
        body.linearDamping = 0
        body.friction = 0
        physicsBody = body
    }

    /// Update collision radius based on stats (call after card pick)
    func updateCollisionRadius() {
        guard let stats = stats else { return }
        let radius = stats.effectiveCollisionRadius
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = GameConfig.Physics.player
        body.contactTestBitMask = GameConfig.Physics.enemy
            | GameConfig.Physics.xpOrb
            | GameConfig.Physics.enemyProjectile
            | GameConfig.Physics.healthOrb
            | GameConfig.Physics.magnetOrb
        body.collisionBitMask = 0
        body.linearDamping = 0
        body.friction = 0
        physicsBody = body
    }

    // MARK: - Movement

    func move(direction: CGPoint, deltaTime: TimeInterval) {
        updateTrail(direction: direction)
        updateEyes(direction: direction, deltaTime: deltaTime)
        guard !isDead else { return }

        let speed = stats?.effectiveMoveSpeedWithBoosts ?? GameConfig.Player.speed
        let displacement = direction * speed * CGFloat(deltaTime)
        position += displacement

        clampToArena()
    }

    /// The eyes drift toward the travel direction — the spark looks where it
    /// floats — and recenter at rest. Framerate-normalized smoothing.
    private func updateEyes(direction: CGPoint, deltaTime: TimeInterval) {
        let config = GameConfig.Player.self
        let maxShift = config.visualRadius * GameConfig.Spark.eyeMaxShiftFactor
        let magnitude = min(direction.length, 1.0)

        let target = magnitude > 0.05
            ? direction.normalized * (maxShift * magnitude)
            : .zero  // recenter when idle

        let lerp = min(1.0, CGFloat(deltaTime) * GameConfig.Spark.eyeFollowRate)
        eyeOffset = eyeOffset + (target - eyeOffset) * lerp

        let baseY = config.visualRadius * GameConfig.Spark.eyeBaseYFactor
        eyesNode.position = CGPoint(x: eyeOffset.x, y: baseY + eyeOffset.y)
    }

    private func clampToArena() {
        let collisionRadius = stats?.effectiveCollisionRadius ?? GameConfig.Player.collisionRadius
        let arenaRadius = GameConfig.Arena.radius - collisionRadius
        let distFromCenter = position.length

        if distFromCenter > arenaRadius {
            let normalized = position.normalized
            position = normalized * arenaRadius
        }
    }

    // MARK: - XP & Leveling

    @discardableResult
    func addXP(_ amount: Int) -> Bool {
        guard !isDead else { return false }

        let xpMult = stats?.xpMultiplier ?? 1.0
        let adjusted = Int(CGFloat(amount) * xpMult)
        currentXP += adjusted

        let required = xpRequired(forLevel: currentLevel + 1)
        if currentXP >= required {
            currentXP -= required
            currentLevel += 1
            onLevelUp()
            return true
        }
        return false
    }

    func xpRequired(forLevel level: Int) -> Int {
        let base = Double(GameConfig.Leveling.baseXPRequired)
        let factor = GameConfig.Leveling.xpScalingFactor
        return Int(base * pow(factor, Double(level - 2)))
    }

    var xpProgress: CGFloat {
        let required = xpRequired(forLevel: currentLevel + 1)
        guard required > 0 else { return 0 }
        return CGFloat(currentXP) / CGFloat(required)
    }

    // MARK: - v1.7: Level-based Feel

    /// Lyra's bands: 1–2 spark freshly struck, 3–5 knows how to stay lit,
    /// 6–9 answering, 10+ a coal learning to become a star.
    private func applyLevelVisuals() {
        let glowScale = min(1.0 + CGFloat(currentLevel - 1) * 0.08, GameConfig.Spark.maxGlowScale)
        glowNode.setScale(glowScale)

        switch currentLevel {
        case ..<3:
            innerCoreNode.alpha = 0.75
            innerCoreNode.setScale(1.0)
        case 3..<6:
            innerCoreNode.alpha = 0.85
            innerCoreNode.setScale(1.05)
        case 6..<10:
            innerCoreNode.alpha = 0.95
            innerCoreNode.setScale(1.1)
        default:
            innerCoreNode.alpha = 1.0
            innerCoreNode.setScale(1.2)
        }

        // From level 6 the outer glow breathes subtly
        if currentLevel >= 6 && glowNode.action(forKey: "glowBreathe") == nil {
            let breathe = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.72, duration: 1.2),
                SKAction.fadeAlpha(to: 1.0, duration: 1.2)
            ])
            breathe.timingMode = .easeInEaseOut
            glowNode.run(SKAction.repeatForever(breathe), withKey: "glowBreathe")
        }
    }

    // MARK: - Level Up Effects

    private func onLevelUp() {
        applyLevelVisuals()

        // White-hot core flash
        let flash = SKShapeNode(circleOfRadius: GameConfig.Player.visualRadius * 0.7)
        flash.fillColor = SKColor(hex: 0xFFFFFF)
        flash.strokeColor = .clear
        flash.blendMode = .add
        flash.zPosition = 13
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.9, duration: 0.22),
                SKAction.fadeOut(withDuration: 0.22)
            ]),
            SKAction.removeFromParent()
        ]))

        // Expanding ember ring — grows with level
        let ring = SKShapeNode(circleOfRadius: GameConfig.Player.visualRadius)
        ring.fillColor = .clear
        ring.strokeColor = SKColor(hex: GameConfig.Spark.flareRingColorHex)
        ring.lineWidth = 2.5
        ring.glowWidth = 4
        ring.blendMode = .add
        ring.zPosition = 11
        addChild(ring)
        let ringScale = 2.5 + min(CGFloat(currentLevel) * 0.15, 2.5)
        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: ringScale, duration: 0.35),
                SKAction.fadeOut(withDuration: 0.35)
            ]),
            SKAction.removeFromParent()
        ]))

        // Tiny outward sparks
        for i in 0..<8 {
            let angle = CGFloat(i) / 8 * 2 * .pi + CGFloat.random(in: -0.2...0.2)
            let fleck = SKShapeNode(circleOfRadius: 2)
            fleck.fillColor = SKColor(hex: GameConfig.Spark.flareRingColorHex)
            fleck.strokeColor = .clear
            fleck.blendMode = .add
            fleck.zPosition = 11
            addChild(fleck)
            let dist = CGFloat.random(in: 28...44)
            let target = CGPoint(x: cos(angle) * dist, y: sin(angle) * dist)
            fleck.run(SKAction.sequence([
                SKAction.group([
                    SKAction.move(to: target, duration: 0.3),
                    SKAction.fadeOut(withDuration: 0.3)
                ]),
                SKAction.removeFromParent()
            ]))
        }

        // Ember body pulse — settles back slightly brighter (glow scale above)
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.15)
        ])
        coreNode.run(pulse)
    }

    // MARK: - v1.4: HP Damage

    /// Apply damage to player via stats. Returns true if player should die.
    /// Phase Skin and lethal saves are handled by GameScene before calling this.
    /// v1.9: the ">_<" squint — the eyes flick to ">" and "<" for a beat when
    /// hit, then round back out. Pure personality.
    private func showHitFace() {
        guard !isDead else { return }
        let e = eyeR * 1.6
        let eyeColor = SKColor(hex: GameConfig.Spark.eyeColorHex)

        let leftPath = CGMutablePath()   // ">"
        leftPath.move(to: CGPoint(x: -e, y: e))
        leftPath.addLine(to: CGPoint(x: e, y: 0))
        leftPath.addLine(to: CGPoint(x: -e, y: -e))

        let rightPath = CGMutablePath()  // "<"
        rightPath.move(to: CGPoint(x: e, y: e))
        rightPath.addLine(to: CGPoint(x: -e, y: 0))
        rightPath.addLine(to: CGPoint(x: e, y: -e))

        for (eye, path) in [(leftEye, leftPath), (rightEye, rightPath)] {
            eye.path = path
            eye.fillColor = .clear
            eye.strokeColor = eyeColor
            eye.lineWidth = max(1.5, eyeR)
            eye.lineCap = .round
            eye.lineJoin = .round
        }
        removeAction(forKey: "hitFace")
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.4),
            SKAction.run { [weak self] in self?.restoreEyes() }
        ]), withKey: "hitFace")
    }

    /// Round eyes back out (also called on reset).
    func restoreEyes() {
        let circle = CGPath(ellipseIn: CGRect(x: -eyeR, y: -eyeR, width: eyeR * 2, height: eyeR * 2),
                            transform: nil)
        for eye in [leftEye, rightEye] {
            eye.path = circle
            eye.fillColor = SKColor(hex: GameConfig.Spark.eyeColorHex)
            eye.strokeColor = .clear
            eye.lineWidth = 0
        }
    }

    func applyDamage(_ rawDamage: Int) -> Bool {
        guard let stats = stats else { return true }
        let died = stats.takeDamage(rawDamage)

        // Visual feedback — red flash proportional to damage
        let flashIntensity = min(CGFloat(rawDamage) / CGFloat(stats.maxHP) * 2.0, 1.0)
        let flashColor = SKColor(red: 1.0, green: 1.0 - flashIntensity * 0.7, blue: 1.0 - flashIntensity * 0.7, alpha: 1.0)

        let flash = SKAction.sequence([
            SKAction.run { [weak self] in self?.coreNode.fillColor = flashColor },
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in
                self?.coreNode.fillColor = SKColor(hex: GameConfig.Player.coreColorHex)
            }
        ])
        run(flash, withKey: "damageFlash")

        // v1.7: core contracts, outer glow flickers
        let contract = SKAction.sequence([
            SKAction.scale(to: 0.82, duration: 0.06),
            SKAction.scale(to: 1.0, duration: 0.15)
        ])
        coreNode.run(contract, withKey: "damageContract")
        let flicker = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.45, duration: 0.05),
            SKAction.fadeAlpha(to: 1.0, duration: 0.12)
        ])
        glowNode.run(flicker, withKey: "damageFlicker")

        showHitFace()   // v1.9: a little ">_<" personality on every hit

        return died
    }

    // MARK: - Lethal Save

    /// Try to survive at 0 HP. Returns true if saved.
    /// v1.4: Only called when currentHP <= 0
    func tryLethalSave() -> Bool {
        guard let stats = stats, stats.lethalSaves > 0 else { return false }
        stats.lethalSaves -= 1
        stats.currentHP = 1  // Survive with 1 HP

        // Brief invulnerability flash
        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 0.05),
            SKAction.fadeAlpha(to: 1.0, duration: 0.05),
            SKAction.fadeAlpha(to: 0.2, duration: 0.05),
            SKAction.fadeAlpha(to: 1.0, duration: 0.05),
            SKAction.fadeAlpha(to: 0.2, duration: 0.05),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        run(flash)
        return true
    }

    // MARK: - Death

    func die() {
        isDead = true
        physicsBody?.categoryBitMask = 0
        trailEmitter.particleBirthRate = 0

        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.0, duration: 0.1),
            SKAction.fadeAlpha(to: 0.8, duration: 0.05),
            SKAction.fadeAlpha(to: 0.0, duration: 0.15)
        ])
        run(flash)
    }

    func reset() {
        // Cancel any in-flight animation (notably die()'s fade-to-0) — else a
        // quick RESTART lets the leftover fade complete AFTER reset and hide the
        // spark. removeAllActions must precede the alpha/visual restore below.
        removeAllActions()
        isDead = false
        currentLevel = 1
        currentXP = 0
        position = .zero
        alpha = 1.0
        glowNode.setScale(1.0)
        glowNode.alpha = 1.0
        glowNode.removeAction(forKey: "glowBreathe")
        coreNode.fillColor = SKColor(hex: GameConfig.Player.coreColorHex)
        trailEmitter.particleBirthRate = 0
        eyeOffset = .zero
        eyesNode.position = CGPoint(x: 0, y: GameConfig.Player.visualRadius * GameConfig.Spark.eyeBaseYFactor)
        restoreEyes()   // clear any ">_<" hit face left from the prior run
        applyLevelVisuals()
        physicsBody?.categoryBitMask = GameConfig.Physics.player
        setupPhysics()  // Reset collision radius to base
    }
}
