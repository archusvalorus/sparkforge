// XPOrbNode.swift
// Sparkforge
//
// Phase 3: Magnet radius now comes from PlayerStats.

import SpriteKit

final class XPOrbNode: SKNode {
    
    // MARK: - Config
    
    static let baseMagnetRadius: CGFloat = 80
    static let magnetSpeed: CGFloat = 300
    static let visualRadius: CGFloat = 4
    
    // MARK: - State
    
    let xpValue: Int
    private let orbNode: SKShapeNode
    
    // MARK: - Init
    
    init(xpValue: Int = GameConfig.Leveling.baseEnemyXP) {
        self.xpValue = xpValue
        
        orbNode = SKShapeNode(circleOfRadius: XPOrbNode.visualRadius)
        orbNode.fillColor = SKColor(hex: 0xFFDD55)
        orbNode.strokeColor = .clear
        orbNode.glowWidth = 4
        orbNode.zPosition = 6
        
        super.init()
        
        addChild(orbNode)
        setupPhysics()
        startPulse()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: XPOrbNode.visualRadius + 4)
        body.isDynamic = true
        body.affectedByGravity = false
        body.categoryBitMask = GameConfig.Physics.xpOrb
        body.contactTestBitMask = GameConfig.Physics.player
        body.collisionBitMask = 0
        body.linearDamping = 0
        physicsBody = body
    }
    
    private func startPulse() {
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.4),
            SKAction.scale(to: 0.8, duration: 0.4)
        ])
        orbNode.run(SKAction.repeatForever(pulse))
    }
    
    /// Call each frame with effective pickup radius from PlayerStats
    func updateMagnet(playerPosition: CGPoint, pickupRadius: CGFloat, deltaTime: TimeInterval) {
        let dist = position.distance(to: playerPosition)
        
        if dist < pickupRadius {
            let direction = (playerPosition - position).normalized
            position += direction * XPOrbNode.magnetSpeed * CGFloat(deltaTime)
        }
    }
    
    func collect() {
        physicsBody?.categoryBitMask = 0
        
        let pop = SKAction.group([
            SKAction.scale(to: 2.0, duration: 0.1),
            SKAction.fadeOut(withDuration: 0.1)
        ])
        run(SKAction.sequence([pop, SKAction.removeFromParent()]))
    }
}
