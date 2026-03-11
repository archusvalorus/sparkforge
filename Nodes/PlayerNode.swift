// PlayerNode.swift
// Sparkforge
//
// The player's spark core.
// Phase 3: Now reads speed/collision from PlayerStats.
// Supports lethal save (Brace/Iron Skin).

import SpriteKit

final class PlayerNode: SKNode {
    
    // MARK: - State
    
    private(set) var currentLevel: Int = 1
    private(set) var currentXP: Int = 0
    var isDead: Bool = false
    
    /// Reference to runtime stats — set by GameScene
    weak var stats: PlayerStats?
    
    // MARK: - Visual Nodes
    
    private let coreNode: SKShapeNode
    private let glowNode: SKShapeNode
    
    // MARK: - Init
    
    override init() {
        let config = GameConfig.Player.self
        
        coreNode = SKShapeNode(circleOfRadius: config.visualRadius)
        coreNode.fillColor = SKColor(hex: config.coreColorHex)
        coreNode.strokeColor = .clear
        coreNode.zPosition = 10
        
        glowNode = SKShapeNode(circleOfRadius: config.visualRadius + config.baseGlowWidth)
        glowNode.fillColor = SKColor(hex: config.glowColorHex, alpha: 0.3)
        glowNode.strokeColor = .clear
        glowNode.zPosition = 9
        glowNode.glowWidth = config.baseGlowWidth
        
        super.init()
        
        addChild(glowNode)
        addChild(coreNode)
        
        setupPhysics()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Physics
    
    private func setupPhysics() {
        let config = GameConfig.Player.self
        let body = SKPhysicsBody(circleOfRadius: config.collisionRadius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = GameConfig.Physics.player
        body.contactTestBitMask = GameConfig.Physics.enemy | GameConfig.Physics.xpOrb
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
        body.contactTestBitMask = GameConfig.Physics.enemy | GameConfig.Physics.xpOrb
        body.collisionBitMask = 0
        body.linearDamping = 0
        body.friction = 0
        physicsBody = body
    }
    
    // MARK: - Movement
    
    func move(direction: CGPoint, deltaTime: TimeInterval) {
        guard !isDead else { return }
        
        let speed = stats?.effectiveMoveSpeed ?? GameConfig.Player.speed
        let displacement = direction * speed * CGFloat(deltaTime)
        position += displacement
        
        clampToArena()
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
    
    // MARK: - Level Up Effects
    
    private func onLevelUp() {
        let glowScale = 1.0 + CGFloat(currentLevel - 1) * 0.08
        glowNode.setScale(glowScale)
        
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.15)
        ])
        coreNode.run(pulse)
    }
    
    // MARK: - Lethal Save
    
    /// Try to survive a lethal hit. Returns true if saved.
    func tryLethalSave() -> Bool {
        guard let stats = stats, stats.lethalSaves > 0 else { return false }
        stats.lethalSaves -= 1
        
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
        
        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.0, duration: 0.1),
            SKAction.fadeAlpha(to: 0.8, duration: 0.05),
            SKAction.fadeAlpha(to: 0.0, duration: 0.15)
        ])
        run(flash)
    }
    
    func reset() {
        isDead = false
        currentLevel = 1
        currentXP = 0
        position = .zero
        alpha = 1.0
        glowNode.setScale(1.0)
        physicsBody?.categoryBitMask = GameConfig.Physics.player
        setupPhysics()  // Reset collision radius to base
    }
}
