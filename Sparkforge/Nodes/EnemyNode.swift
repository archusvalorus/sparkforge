// EnemyNode.swift
// Sparkforge
//
// Visual overhaul: darker bodies with menacing faces.
// Randomized face expressions for variety.
// Status effects tint the face/body.

import SpriteKit

class EnemyNode: SKNode {
    
    // MARK: - State
    
    private(set) var health: Int
    private(set) var maxHealth: Int
    private(set) var moveSpeed: CGFloat
    private(set) var xpValue: Int
    
    // MARK: - Status Effects
    
    private(set) var currentSlow: CGFloat = 0.0
    private var slowTimer: TimeInterval = 0
    private(set) var burnDPS: CGFloat = 0.0
    private var burnTimer: TimeInterval = 0
    private(set) var bleedDPS: CGFloat = 0.0
    private var bleedTimer: TimeInterval = 0
    private var stunTimer: TimeInterval = 0
    private var dotAccumulator: CGFloat = 0.0
    
    var isBurning: Bool { burnDPS > 0 && burnTimer > 0 }
    var isSlowed: Bool { currentSlow > 0 && slowTimer > 0 }
    var isBleeding: Bool { bleedDPS > 0 && bleedTimer > 0 }
    var isStunned: Bool { stunTimer > 0 }
    
    var healthPercent: CGFloat {
        guard maxHealth > 0 else { return 0 }
        return CGFloat(health) / CGFloat(maxHealth)
    }
    
    // MARK: - Visual
    
    private let bodyNode: SKShapeNode
    private let rimGlowNode: SKShapeNode
    private let leftEye: SKShapeNode
    private let rightEye: SKShapeNode
    private let mouth: SKShapeNode
    
    // MARK: - Face Styles
    
    private enum FaceStyle: CaseIterable {
        case angry       // .\ _ /.   — angled brows, flat mouth
        case menacing    // V  V  ___  — V eyes, wide grin
        case glaring     // -  -  ^    — slit eyes, small frown
        case furious     // >  <  ~~~  — chevron eyes, zigzag mouth
    }
    
    // MARK: - Init
    
    init(health: Int = GameConfig.Enemy.baseHealth,
         moveSpeed: CGFloat = GameConfig.Enemy.baseSpeed,
         xpValue: Int = GameConfig.Leveling.baseEnemyXP) {
        
        self.health = health
        self.maxHealth = health
        self.moveSpeed = moveSpeed
        self.xpValue = xpValue
        
        let config = GameConfig.Enemy.self
        let r = config.visualRadius
        
        // Darker body
        bodyNode = SKShapeNode(circleOfRadius: r)
        bodyNode.fillColor = SKColor(hex: 0x1A1A1A)
        bodyNode.strokeColor = .clear
        bodyNode.zPosition = 5
        
        // Rim glow
        rimGlowNode = SKShapeNode(circleOfRadius: r + 2)
        rimGlowNode.fillColor = .clear
        rimGlowNode.strokeColor = SKColor(hex: 0x661111, alpha: 0.7)
        rimGlowNode.lineWidth = 2
        rimGlowNode.glowWidth = 4
        rimGlowNode.zPosition = 4
        
        // Eyes — small glowing red dots
        let eyeRadius: CGFloat = 1.8
        let eyeSpacing: CGFloat = r * 0.38
        let eyeY: CGFloat = r * 0.15
        
        leftEye = SKShapeNode(circleOfRadius: eyeRadius)
        leftEye.fillColor = SKColor(hex: 0xFF2222)
        leftEye.strokeColor = .clear
        leftEye.glowWidth = 3
        leftEye.position = CGPoint(x: -eyeSpacing, y: eyeY)
        leftEye.zPosition = 6
        
        rightEye = SKShapeNode(circleOfRadius: eyeRadius)
        rightEye.fillColor = SKColor(hex: 0xFF2222)
        rightEye.strokeColor = .clear
        rightEye.glowWidth = 3
        rightEye.position = CGPoint(x: eyeSpacing, y: eyeY)
        rightEye.zPosition = 6
        
        // Mouth — varies by style
        mouth = SKShapeNode()
        mouth.strokeColor = SKColor(hex: 0xCC1111, alpha: 0.8)
        mouth.lineWidth = 1.2
        mouth.zPosition = 6
        
        super.init()
        
        addChild(rimGlowNode)
        addChild(bodyNode)
        addChild(leftEye)
        addChild(rightEye)
        addChild(mouth)
        
        // Randomize face
        applyFaceStyle(FaceStyle.allCases.randomElement() ?? .angry)
        
        // Subtle idle eye pulse
        startEyePulse()
        
        setupPhysics()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Face Styles
    
    private func applyFaceStyle(_ style: FaceStyle) {
        let r = GameConfig.Enemy.visualRadius
        let mouthY: CGFloat = -r * 0.25
        
        switch style {
        case .angry:
            // Angled brow lines above eyes + flat mouth
            addBrowLine(from: CGPoint(x: -r * 0.55, y: r * 0.4),
                       to: CGPoint(x: -r * 0.2, y: r * 0.3))
            addBrowLine(from: CGPoint(x: r * 0.55, y: r * 0.4),
                       to: CGPoint(x: r * 0.2, y: r * 0.3))
            let mouthPath = CGMutablePath()
            mouthPath.move(to: CGPoint(x: -r * 0.3, y: mouthY))
            mouthPath.addLine(to: CGPoint(x: r * 0.3, y: mouthY))
            mouth.path = mouthPath
            
        case .menacing:
            // Slightly larger eyes, curved grin
            leftEye.setScale(1.2)
            rightEye.setScale(1.2)
            let mouthPath = CGMutablePath()
            mouthPath.move(to: CGPoint(x: -r * 0.35, y: mouthY + 2))
            mouthPath.addQuadCurve(to: CGPoint(x: r * 0.35, y: mouthY + 2),
                                    control: CGPoint(x: 0, y: mouthY - 3))
            mouth.path = mouthPath
            
        case .glaring:
            // Slit eyes (horizontal lines), small frown
            leftEye.path = CGPath(rect: CGRect(x: -3, y: -0.8, width: 6, height: 1.6), transform: nil)
            rightEye.path = CGPath(rect: CGRect(x: -3, y: -0.8, width: 6, height: 1.6), transform: nil)
            let mouthPath = CGMutablePath()
            mouthPath.move(to: CGPoint(x: -r * 0.2, y: mouthY))
            mouthPath.addQuadCurve(to: CGPoint(x: r * 0.2, y: mouthY),
                                    control: CGPoint(x: 0, y: mouthY + 3))
            mouth.path = mouthPath
            
        case .furious:
            // Chevron eyes, zigzag mouth
            let chevronL = CGMutablePath()
            chevronL.move(to: CGPoint(x: -r * 0.5, y: r * 0.25))
            chevronL.addLine(to: CGPoint(x: -r * 0.35, y: r * 0.1))
            chevronL.addLine(to: CGPoint(x: -r * 0.2, y: r * 0.25))
            leftEye.path = chevronL
            leftEye.fillColor = .clear
            leftEye.strokeColor = SKColor(hex: 0xFF2222)
            leftEye.lineWidth = 1.5
            
            let chevronR = CGMutablePath()
            chevronR.move(to: CGPoint(x: r * 0.2, y: r * 0.25))
            chevronR.addLine(to: CGPoint(x: r * 0.35, y: r * 0.1))
            chevronR.addLine(to: CGPoint(x: r * 0.5, y: r * 0.25))
            rightEye.path = chevronR
            rightEye.fillColor = .clear
            rightEye.strokeColor = SKColor(hex: 0xFF2222)
            rightEye.lineWidth = 1.5
            
            let mouthPath = CGMutablePath()
            mouthPath.move(to: CGPoint(x: -r * 0.35, y: mouthY))
            mouthPath.addLine(to: CGPoint(x: -r * 0.15, y: mouthY - 2))
            mouthPath.addLine(to: CGPoint(x: 0, y: mouthY))
            mouthPath.addLine(to: CGPoint(x: r * 0.15, y: mouthY - 2))
            mouthPath.addLine(to: CGPoint(x: r * 0.35, y: mouthY))
            mouth.path = mouthPath
        }
    }
    
    private func addBrowLine(from: CGPoint, to: CGPoint) {
        let brow = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        brow.path = path
        brow.strokeColor = SKColor(hex: 0xCC2222, alpha: 0.7)
        brow.lineWidth = 1.2
        brow.zPosition = 6
        addChild(brow)
    }
    
    // MARK: - Eye Pulse
    
    private func startEyePulse() {
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.8 + CGFloat.random(in: 0...0.4)),
            SKAction.fadeAlpha(to: 1.0, duration: 0.6 + CGFloat.random(in: 0...0.3))
        ])
        leftEye.run(SKAction.repeatForever(pulse))
        
        // Offset right eye slightly for asymmetry
        let pulseR = SKAction.sequence([
            SKAction.wait(forDuration: 0.2),
            SKAction.fadeAlpha(to: 0.5, duration: 0.7 + CGFloat.random(in: 0...0.4)),
            SKAction.fadeAlpha(to: 1.0, duration: 0.7 + CGFloat.random(in: 0...0.3))
        ])
        rightEye.run(SKAction.repeatForever(pulseR))
    }
    
    // MARK: - Physics
    
    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: GameConfig.Enemy.collisionRadius)
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
    
    // MARK: - AI
    
    func chase(target: CGPoint, deltaTime: TimeInterval, globalSlow: CGFloat = 0) {
        guard !isStunned else {
            stunTimer -= deltaTime
            return
        }
        
        let effectiveSlow = min(currentSlow + globalSlow, 0.8)
        let effectiveSpeed = moveSpeed * (1.0 - effectiveSlow)
        
        let direction = (target - position).normalized
        let displacement = direction * effectiveSpeed * CGFloat(deltaTime)
        position += displacement
    }
    
    // MARK: - Status Effect Application
    
    func applySlow(_ amount: CGFloat, duration: TimeInterval) {
        currentSlow = max(currentSlow, amount)
        slowTimer = max(slowTimer, duration)
        bodyNode.fillColor = SKColor(hex: 0x112233)
        leftEye.fillColor = SKColor(hex: 0x4488FF)
        rightEye.fillColor = SKColor(hex: 0x4488FF)
    }
    
    func applyBurn(_ dps: CGFloat, duration: TimeInterval) {
        burnDPS = max(burnDPS, dps)
        burnTimer = max(burnTimer, duration)
        rimGlowNode.strokeColor = SKColor(hex: 0xFF6633, alpha: 0.9)
        rimGlowNode.glowWidth = 6
    }
    
    func applyBleed(_ dps: CGFloat, duration: TimeInterval) {
        bleedDPS = max(bleedDPS, dps)
        bleedTimer = max(bleedTimer, duration)
    }
    
    func applyStun(_ duration: TimeInterval) {
        stunTimer = max(stunTimer, duration)
    }
    
    // MARK: - Status Effect Update
    
    func updateStatusEffects(deltaTime: TimeInterval) -> Bool {
        var totalDOT: CGFloat = 0
        
        if burnTimer > 0 {
            burnTimer -= deltaTime
            totalDOT += burnDPS
            if burnTimer <= 0 {
                burnDPS = 0
                rimGlowNode.strokeColor = SKColor(hex: 0x661111, alpha: 0.7)
                rimGlowNode.glowWidth = 4
            }
        }
        
        if bleedTimer > 0 {
            bleedTimer -= deltaTime
            totalDOT += bleedDPS
            if bleedTimer <= 0 { bleedDPS = 0 }
        }
        
        if slowTimer > 0 {
            slowTimer -= deltaTime
            if slowTimer <= 0 {
                currentSlow = 0
                bodyNode.fillColor = SKColor(hex: 0x1A1A1A)
                leftEye.fillColor = SKColor(hex: 0xFF2222)
                rightEye.fillColor = SKColor(hex: 0xFF2222)
            }
        }
        
        if totalDOT > 0 {
            dotAccumulator += totalDOT * CGFloat(deltaTime)
            if dotAccumulator >= 1.0 {
                let dmg = Int(dotAccumulator)
                dotAccumulator -= CGFloat(dmg)
                return takeDamage(dmg)
            }
        }
        
        return false
    }
    
    // MARK: - Damage
    
    @discardableResult
    func takeDamage(_ amount: Int) -> Bool {
        health -= amount
        
        if health <= 0 {
            onDeath()
            return true
        }
        
        // Hit flash — eyes flare bright
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.bodyNode.fillColor = SKColor(hex: 0x333333)
                self?.leftEye.fillColor = .white
                self?.rightEye.fillColor = .white
            },
            SKAction.wait(forDuration: 0.06),
            SKAction.run { [weak self] in
                self?.bodyNode.fillColor = SKColor(hex: 0x1A1A1A)
                self?.leftEye.fillColor = SKColor(hex: 0xFF2222)
                self?.rightEye.fillColor = SKColor(hex: 0xFF2222)
            }
        ])
        run(flash)
        
        return false
    }
    
    // MARK: - Knockback
    
    func applyKnockback(from sourcePosition: CGPoint, force: CGFloat) {
        let direction = (position - sourcePosition).normalized
        position += direction * force
    }
    
    // MARK: - Death
    
    private func onDeath() {
        physicsBody?.categoryBitMask = 0
        
        // Eyes flare out, body shrinks
        let deathAnim = SKAction.group([
            SKAction.scale(to: 0.0, duration: 0.2),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.run { [weak self] in
                self?.leftEye.run(SKAction.scale(to: 2.0, duration: 0.15))
                self?.rightEye.run(SKAction.scale(to: 2.0, duration: 0.15))
            }
        ])
        run(SKAction.sequence([deathAnim, SKAction.removeFromParent()]))
    }
    
    // MARK: - Spawn
    
    static func spawnPosition() -> CGPoint {
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance = GameConfig.Wave.spawnDistance
        return CGPoint(
            x: cos(angle) * distance,
            y: sin(angle) * distance
        )
    }
}
