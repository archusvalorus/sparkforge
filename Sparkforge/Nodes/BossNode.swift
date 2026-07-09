// BossNode.swift
// Sparkforge
//
// v1.4: Arena boss with attack patterns.
// Arena 1 — "The Slag Titan"
// 3 attack patterns: Charge (dash across arena), Slam (AoE shockwave),
// Spawn (summons minions). Rotates patterns with cooldowns.
//
// NOT an EnemyNode subclass — boss has unique physics, AI, and visuals.
// GameScene manages the boss separately from the enemies array.

import SpriteKit

final class BossNode: SKNode {
    
    // MARK: - Config
    
    struct BossConfig {
        let name: String
        let maxHP: Int
        let moveSpeed: CGFloat
        let contactDamage: Int
        let bodyRadius: CGFloat
        let bodyColorHex: UInt32
        let rimColorHex: UInt32
        let eyeColorHex: UInt32
        let xpReward: Int
        
        // Attack timing
        let attackCooldown: TimeInterval     // Time between attacks
        let chargeWindUp: TimeInterval       // Warning time before charge
        let chargeSpeed: CGFloat             // Dash speed
        let chargeDamage: Int                // Damage if charge connects
        let slamRadius: CGFloat              // AoE radius
        let slamDamage: Int                  // AoE damage
        let spawnCount: Int                  // Minions per spawn
    }
    
    static let slagTitan = BossConfig(
        name: "The Slag Titan",
        maxHP: 50,
        moveSpeed: 50,
        contactDamage: 40,
        bodyRadius: 36,
        bodyColorHex: 0x1A1008,
        rimColorHex: 0xFF6611,
        eyeColorHex: 0xFF4400,
        xpReward: 50,
        attackCooldown: 3.5,
        chargeWindUp: 1.0,
        chargeSpeed: 450,
        chargeDamage: 35,
        slamRadius: 120,
        slamDamage: 30,
        spawnCount: 4
    )
    
    // MARK: - State
    
    let config: BossConfig
    private(set) var health: Int
    private(set) var maxHealth: Int
    private(set) var isDead: Bool = false
    
    var healthPercent: CGFloat {
        guard maxHealth > 0 else { return 0 }
        return CGFloat(health) / CGFloat(maxHealth)
    }
    
    // MARK: - AI State
    
    enum Phase {
        case idle           // Moving slowly toward player
        case windingUp      // Telegraphing next attack
        case charging       // Dashing across arena
        case slamming       // AoE shockwave
        case spawning       // Summoning minions
        case recovering     // Brief post-attack pause
    }
    
    private(set) var phase: Phase = .idle
    private var attackTimer: TimeInterval = 2.0  // Start with a delay
    private var phaseTimer: TimeInterval = 0
    private var attackIndex: Int = 0  // Cycles through patterns
    private var chargeDirection: CGPoint = .zero
    private var chargeDistanceTraveled: CGFloat = 0
    
    /// Callbacks for GameScene
    var onSpawnMinions: ((_ position: CGPoint, _ count: Int) -> Void)?
    var onSlamHit: ((_ position: CGPoint, _ radius: CGFloat, _ damage: Int) -> Void)?
    var onChargeHit: ((_ damage: Int) -> Void)?
    var onDeath: ((_ position: CGPoint, _ xpReward: Int) -> Void)?
    
    // MARK: - Visual Nodes
    
    private let bodyNode: SKShapeNode
    private let rimGlowNode: SKShapeNode
    private let leftEye: SKShapeNode
    private let rightEye: SKShapeNode
    private let mouth: SKShapeNode
    private let hpBarBG: SKShapeNode
    private let hpBarFill: SKShapeNode
    private let nameLabel: SKLabelNode
    
    // MARK: - Init
    
    init(config: BossConfig = BossNode.slagTitan, hpScaling: Int = 0) {
        self.config = config
        self.health = config.maxHP + hpScaling
        self.maxHealth = config.maxHP + hpScaling
        
        let r = config.bodyRadius
        
        // Body — dark with molten rim
        bodyNode = SKShapeNode(circleOfRadius: r)
        bodyNode.fillColor = SKColor(hex: config.bodyColorHex)
        bodyNode.strokeColor = .clear
        bodyNode.zPosition = 5
        
        rimGlowNode = SKShapeNode(circleOfRadius: r + 3)
        rimGlowNode.fillColor = .clear
        rimGlowNode.strokeColor = SKColor(hex: config.rimColorHex, alpha: 0.8)
        rimGlowNode.lineWidth = 3
        rimGlowNode.glowWidth = 8
        rimGlowNode.zPosition = 4
        
        // Eyes — larger, molten orange
        let eyeR: CGFloat = 4
        let eyeSpacing = r * 0.35
        let eyeY = r * 0.15
        
        leftEye = SKShapeNode(circleOfRadius: eyeR)
        leftEye.fillColor = SKColor(hex: config.eyeColorHex)
        leftEye.strokeColor = .clear
        leftEye.glowWidth = 5
        leftEye.position = CGPoint(x: -eyeSpacing, y: eyeY)
        leftEye.zPosition = 6
        
        rightEye = SKShapeNode(circleOfRadius: eyeR)
        rightEye.fillColor = SKColor(hex: config.eyeColorHex)
        rightEye.strokeColor = .clear
        rightEye.glowWidth = 5
        rightEye.position = CGPoint(x: eyeSpacing, y: eyeY)
        rightEye.zPosition = 6
        
        // Mouth — jagged
        mouth = SKShapeNode()
        let mouthPath = CGMutablePath()
        let mouthY = -r * 0.25
        mouthPath.move(to: CGPoint(x: -r * 0.4, y: mouthY))
        mouthPath.addLine(to: CGPoint(x: -r * 0.2, y: mouthY - 4))
        mouthPath.addLine(to: CGPoint(x: 0, y: mouthY))
        mouthPath.addLine(to: CGPoint(x: r * 0.2, y: mouthY - 4))
        mouthPath.addLine(to: CGPoint(x: r * 0.4, y: mouthY))
        mouth.path = mouthPath
        mouth.strokeColor = SKColor(hex: config.rimColorHex, alpha: 0.9)
        mouth.lineWidth = 2
        mouth.zPosition = 6
        
        // HP bar above boss
        let barW: CGFloat = r * 2
        let barH: CGFloat = 5
        
        hpBarBG = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 2)
        hpBarBG.fillColor = SKColor(hex: 0x331111)
        hpBarBG.strokeColor = SKColor(hex: 0x441111, alpha: 0.5)
        hpBarBG.lineWidth = 0.5
        hpBarBG.position = CGPoint(x: 0, y: r + 15)
        hpBarBG.zPosition = 7
        
        hpBarFill = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 2)
        hpBarFill.fillColor = SKColor(hex: config.rimColorHex)
        hpBarFill.strokeColor = .clear
        hpBarFill.position = CGPoint(x: 0, y: r + 15)
        hpBarFill.zPosition = 8
        
        // Name label
        nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = config.name
        nameLabel.fontSize = 9
        nameLabel.fontColor = SKColor(hex: config.rimColorHex)
        nameLabel.position = CGPoint(x: 0, y: r + 24)
        nameLabel.zPosition = 7
        
        super.init()
        
        addChild(rimGlowNode)
        addChild(bodyNode)
        addChild(leftEye)
        addChild(rightEye)
        addChild(mouth)
        addChild(hpBarBG)
        addChild(hpBarFill)
        addChild(nameLabel)
        
        setupPhysics()
        startIdleAnimations()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Physics
    
    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: config.bodyRadius)
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
    
    // MARK: - Animations
    
    private func startIdleAnimations() {
        // Rim pulse
        let pulse = SKAction.sequence([
            SKAction.run { [weak self] in self?.rimGlowNode.glowWidth = 12 },
            SKAction.wait(forDuration: 0.8),
            SKAction.run { [weak self] in self?.rimGlowNode.glowWidth = 6 },
            SKAction.wait(forDuration: 0.8)
        ])
        rimGlowNode.run(SKAction.repeatForever(pulse), withKey: "rimPulse")
        
        // Eye glow pulse
        let eyePulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.6),
            SKAction.fadeAlpha(to: 1.0, duration: 0.6)
        ])
        leftEye.run(SKAction.repeatForever(eyePulse))
        rightEye.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.15),
            SKAction.repeatForever(eyePulse)
        ]))
    }
    
    // MARK: - Update
    
    /// Call each frame. Provide player position for AI targeting.
    func update(deltaTime dt: TimeInterval, playerPosition: CGPoint) {
        guard !isDead else { return }
        
        updateHPBar()
        
        switch phase {
        case .idle:
            updateIdle(dt: dt, target: playerPosition)
        case .windingUp:
            updateWindUp(dt: dt, target: playerPosition)
        case .charging:
            updateCharge(dt: dt)
        case .slamming:
            updateSlam(dt: dt)
        case .spawning:
            updateSpawn(dt: dt)
        case .recovering:
            updateRecovering(dt: dt)
        }
    }
    
    // MARK: - AI Phases
    
    private func updateIdle(dt: TimeInterval, target: CGPoint) {
        // Slowly move toward player
        let dir = (target - position).normalized
        position += dir * config.moveSpeed * CGFloat(dt)
        
        // Count down to next attack
        attackTimer -= dt
        if attackTimer <= 0 {
            beginNextAttack(target: target)
        }
    }
    
    private func beginNextAttack(target: CGPoint) {
        let patterns: [Phase] = [.charging, .slamming, .spawning]
        let nextPattern = patterns[attackIndex % patterns.count]
        attackIndex += 1
        
        phase = .windingUp
        phaseTimer = config.chargeWindUp
        
        // Store which attack is coming
        switch nextPattern {
        case .charging:
            chargeDirection = (target - position).normalized
            chargeDistanceTraveled = 0
            showWindUpEffect(color: 0xFF2200, text: "!")
        case .slamming:
            showWindUpEffect(color: 0xFF6600, text: "◉")
        case .spawning:
            showWindUpEffect(color: 0xAA4400, text: "⊕")
        default: break
        }
        
        // After wind-up, transition to the actual attack
        run(SKAction.wait(forDuration: config.chargeWindUp)) { [weak self] in
            guard let self = self, !self.isDead else { return }
            self.phase = nextPattern
            self.phaseTimer = 0
        }
    }
    
    private func showWindUpEffect(color: UInt32, text: String) {
        // Warning indicator above boss
        let warn = SKLabelNode(fontNamed: "Menlo-Bold")
        warn.text = text
        warn.fontSize = 24
        warn.fontColor = SKColor(hex: color)
        warn.position = CGPoint(x: 0, y: config.bodyRadius + 40)
        warn.zPosition = 10
        addChild(warn)
        
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.15),
            SKAction.fadeAlpha(to: 1.0, duration: 0.15)
        ])
        warn.run(SKAction.sequence([
            SKAction.repeat(blink, count: Int(config.chargeWindUp / 0.3)),
            SKAction.removeFromParent()
        ]))
        
        // Body flash
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in self?.bodyNode.fillColor = SKColor(hex: color, alpha: 0.4) },
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in self?.bodyNode.fillColor = SKColor(hex: self?.config.bodyColorHex ?? 0x1A1008) }
        ])
        run(SKAction.repeat(flash, count: 3))
    }
    
    private func updateWindUp(dt: TimeInterval, target: CGPoint) {
        // Hold position during wind-up (or slowly track)
        let dir = (target - position).normalized
        position += dir * (config.moveSpeed * 0.3) * CGFloat(dt)
    }
    
    // MARK: - Charge Attack
    
    private func updateCharge(dt: TimeInterval) {
        let moveAmount = config.chargeSpeed * CGFloat(dt)
        position += chargeDirection * moveAmount
        chargeDistanceTraveled += moveAmount
        
        // Clamp to arena
        let distFromCenter = position.length
        if distFromCenter > GameConfig.Arena.radius - config.bodyRadius {
            let n = position.normalized
            position = n * (GameConfig.Arena.radius - config.bodyRadius)
            // Charge ends when hitting arena wall
            endAttack()
            return
        }
        
        // Max charge distance
        if chargeDistanceTraveled > GameConfig.Arena.radius * 1.5 {
            endAttack()
        }
    }
    
    // MARK: - Slam Attack
    
    private func updateSlam(dt: TimeInterval) {
        // Slam is instant — fire once then recover
        onSlamHit?(position, config.slamRadius, config.slamDamage)
        showSlamVisual()
        endAttack()
    }
    
    private func showSlamVisual() {
        let ring = SKShapeNode(circleOfRadius: 1)
        ring.strokeColor = SKColor(hex: config.rimColorHex, alpha: 0.7)
        ring.fillColor = SKColor(hex: config.rimColorHex, alpha: 0.1)
        ring.lineWidth = 3
        ring.glowWidth = 4
        ring.position = .zero
        ring.zPosition = 3
        addChild(ring)
        
        let expand = SKAction.group([
            SKAction.scale(to: config.slamRadius, duration: 0.4),
            SKAction.fadeOut(withDuration: 0.5)
        ])
        ring.run(SKAction.sequence([expand, SKAction.removeFromParent()]))
    }
    
    // MARK: - Spawn Attack
    
    private func updateSpawn(dt: TimeInterval) {
        // Spawn is instant — fire once then recover
        onSpawnMinions?(position, config.spawnCount)
        showSpawnVisual()
        endAttack()
    }
    
    private func showSpawnVisual() {
        // Dark burst effect
        for i in 0..<config.spawnCount {
            let angle = (CGFloat(i) / CGFloat(config.spawnCount)) * .pi * 2
            let spark = SKShapeNode(circleOfRadius: 4)
            spark.fillColor = SKColor(hex: config.rimColorHex, alpha: 0.6)
            spark.strokeColor = .clear
            spark.glowWidth = 3
            spark.position = .zero
            spark.zPosition = 3
            addChild(spark)
            
            let target = CGPoint(x: cos(angle) * 60, y: sin(angle) * 60)
            let fly = SKAction.group([
                SKAction.move(to: target, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ])
            spark.run(SKAction.sequence([fly, SKAction.removeFromParent()]))
        }
    }
    
    private func updateRecovering(dt: TimeInterval) {
        phaseTimer -= dt
        if phaseTimer <= 0 {
            phase = .idle
            attackTimer = config.attackCooldown
        }
    }
    
    private func endAttack() {
        phase = .recovering
        phaseTimer = 1.0  // Brief pause after each attack
    }
    
    // MARK: - HP Bar
    
    private func updateHPBar() {
        let pct = healthPercent
        let barW = config.bodyRadius * 2
        let barH: CGFloat = 5
        let fillW = max(1, barW * pct)
        
        hpBarFill.path = CGPath(
            roundedRect: CGRect(x: -barW / 2, y: -barH / 2, width: fillW, height: barH),
            cornerWidth: 2, cornerHeight: 2, transform: nil
        )
        
        // Color shift at low HP
        if pct < 0.3 {
            hpBarFill.fillColor = SKColor(hex: 0xFF1111)
        } else if pct < 0.6 {
            hpBarFill.fillColor = SKColor(hex: 0xFF4411)
        }
    }
    
    // MARK: - Damage
    
    @discardableResult
    func takeDamage(_ amount: Int) -> Bool {
        guard !isDead else { return false }
        health -= amount
        
        // Hit flash
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.bodyNode.fillColor = SKColor(hex: 0x443322)
                self?.leftEye.fillColor = .white
                self?.rightEye.fillColor = .white
            },
            SKAction.wait(forDuration: 0.06),
            SKAction.run { [weak self] in
                self?.bodyNode.fillColor = SKColor(hex: self?.config.bodyColorHex ?? 0x1A1008)
                self?.leftEye.fillColor = SKColor(hex: self?.config.eyeColorHex ?? 0xFF4400)
                self?.rightEye.fillColor = SKColor(hex: self?.config.eyeColorHex ?? 0xFF4400)
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
        
        // Epic death: eyes flare, body cracks, explosion
        let deathSequence = SKAction.sequence([
            // Eyes flare huge
            SKAction.run { [weak self] in
                self?.leftEye.run(SKAction.scale(to: 3.0, duration: 0.3))
                self?.rightEye.run(SKAction.scale(to: 3.0, duration: 0.3))
                self?.rimGlowNode.run(SKAction.sequence([
                    SKAction.run { self?.rimGlowNode.glowWidth = 20 },
                    SKAction.wait(forDuration: 0.3)
                ]))
            },
            SKAction.wait(forDuration: 0.4),
            // Shrink and explode
            SKAction.group([
                SKAction.scale(to: 0.0, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.onDeath?(self.position, self.config.xpReward)
            },
            SKAction.removeFromParent()
        ])
        
        hpBarBG.run(SKAction.fadeOut(withDuration: 0.2))
        hpBarFill.run(SKAction.fadeOut(withDuration: 0.2))
        nameLabel.run(SKAction.fadeOut(withDuration: 0.2))
        
        run(deathSequence)
    }
    
    // MARK: - Contact Damage
    
    /// Damage dealt on contact with player (used by GameScene collision handler)
    var contactDamage: Int { config.contactDamage }
    
    /// Spawn position — enters from edge of arena with dramatic entrance
    static func spawnPosition() -> CGPoint {
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance = GameConfig.Arena.radius + 80
        return CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
    }
}
