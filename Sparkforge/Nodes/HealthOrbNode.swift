// HealthOrbNode.swift
// Sparkforge
//
// v1.4: Green health pickup that spawns periodically in the arena.
// NOT magnetized — player must deliberately walk to it.
// Despawns after configured time if not collected.

import SpriteKit

final class HealthOrbNode: SKNode {
    
    let healAmount: Int
    private let despawnTime: TimeInterval
    private var age: TimeInterval = 0
    
    private let orbNode: SKShapeNode
    private let glowNode: SKShapeNode
    private let crossNode: SKShapeNode
    
    init(healAmount: Int = GameConfig.HealthOrb.healAmount) {
        self.healAmount = healAmount
        self.despawnTime = GameConfig.HealthOrb.despawnTime
        
        let r = GameConfig.HealthOrb.visualRadius
        
        // Outer glow
        glowNode = SKShapeNode(circleOfRadius: r + 4)
        glowNode.fillColor = SKColor(hex: GameConfig.HealthOrb.glowColorHex, alpha: 0.2)
        glowNode.strokeColor = .clear
        glowNode.glowWidth = 6
        glowNode.zPosition = 3
        
        // Core orb
        orbNode = SKShapeNode(circleOfRadius: r)
        orbNode.fillColor = SKColor(hex: GameConfig.HealthOrb.colorHex, alpha: 0.9)
        orbNode.strokeColor = SKColor(hex: GameConfig.HealthOrb.colorHex, alpha: 0.5)
        orbNode.lineWidth = 1.5
        orbNode.zPosition = 4
        
        // Health cross icon
        let crossPath = CGMutablePath()
        let cs: CGFloat = r * 0.5  // cross size
        let ct: CGFloat = r * 0.18  // cross thickness
        // Horizontal bar
        crossPath.addRect(CGRect(x: -cs, y: -ct, width: cs * 2, height: ct * 2))
        // Vertical bar
        crossPath.addRect(CGRect(x: -ct, y: -cs, width: ct * 2, height: cs * 2))
        
        crossNode = SKShapeNode()
        crossNode.path = crossPath
        crossNode.fillColor = .white
        crossNode.strokeColor = .clear
        crossNode.alpha = 0.9
        crossNode.zPosition = 5
        
        super.init()
        
        addChild(glowNode)
        addChild(orbNode)
        addChild(crossNode)
        
        setupPhysics()
        startAnimations()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Physics
    
    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: GameConfig.HealthOrb.pickupRadius)
        body.isDynamic = false
        body.categoryBitMask = GameConfig.Physics.healthOrb
        body.contactTestBitMask = GameConfig.Physics.player
        body.collisionBitMask = 0
        physicsBody = body
    }
    
    // MARK: - Animation
    
    private func startAnimations() {
        // Gentle hover bob
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 4, duration: 0.8),
            SKAction.moveBy(x: 0, y: -4, duration: 0.8)
        ])
        run(SKAction.repeatForever(bob))
        
        // Subtle pulse
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.6),
            SKAction.scale(to: 0.95, duration: 0.6)
        ])
        orbNode.run(SKAction.repeatForever(pulse))
        
        // Glow breathe
        let breathe = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.35, duration: 0.7),
            SKAction.fadeAlpha(to: 0.15, duration: 0.7)
        ])
        glowNode.run(SKAction.repeatForever(breathe))
        
        // Spawn pop-in
        setScale(0.01)
        run(SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.15),
            SKAction.scale(to: 0.95, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.06)
        ]))
    }
    
    // MARK: - Update
    
    /// Call each frame. Returns true when orb should despawn.
    func update(deltaTime: TimeInterval) -> Bool {
        age += deltaTime
        
        // Start fading in last 2 seconds
        if age > despawnTime - 2.0 {
            let remaining = despawnTime - age
            let fadeAlpha = max(0, CGFloat(remaining / 2.0))
            alpha = fadeAlpha
        }
        
        return age >= despawnTime
    }
    
    // MARK: - Collection
    
    /// Play collection effect and remove
    func collect() {
        physicsBody = nil
        
        // Pop + fade
        let collect = SKAction.group([
            SKAction.scale(to: 1.5, duration: 0.15),
            SKAction.fadeOut(withDuration: 0.15)
        ])
        run(SKAction.sequence([collect, SKAction.removeFromParent()]))
    }
    
    // MARK: - Spawn Position
    
    /// Random position within the arena, away from edges
    static func randomArenaPosition() -> CGPoint {
        let maxR = GameConfig.Arena.radius * 0.75  // Keep away from arena edge
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance = CGFloat.random(in: 30...maxR)
        return CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
    }
}
