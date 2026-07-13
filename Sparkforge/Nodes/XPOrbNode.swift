// XPOrbNode.swift
// Sparkforge
//
// Phase 3: Magnet radius now comes from PlayerStats.

import SpriteKit

final class XPOrbNode: SKNode {
    
    // MARK: - Config
    
    static let baseMagnetRadius: CGFloat = 80
    static let magnetSpeed: CGFloat = 300
    /// v1.8: full-arena vacuum (blue magnet orb) homes toward the player's
    /// LIVE position at this speed — snappier than the passive pull.
    static let vacuumSpeed: CGFloat = 700
    static let visualRadius: CGFloat = 4

    // MARK: - State

    let xpValue: Int
    private let orbNode: SKShapeNode
    /// v1.8: set when a blue magnet orb vacuums every XP orb to the player.
    /// The orb then homes to the player's live position each frame — fixes
    /// orbs missing a moving player (the old one-shot move targeted a stale
    /// snapshot of player.position and felt like a bug).
    private(set) var isVacuuming = false
    
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
    
    /// Call each frame with effective pickup radius from PlayerStats.
    /// While vacuuming, the orb homes from anywhere; otherwise it only pulls
    /// once inside the pickup radius. Either way it tracks the LIVE player.
    func updateMagnet(playerPosition: CGPoint, pickupRadius: CGFloat, deltaTime: TimeInterval) {
        let dist = position.distance(to: playerPosition)
        guard isVacuuming || dist < pickupRadius else { return }

        let speed = isVacuuming ? XPOrbNode.vacuumSpeed : XPOrbNode.magnetSpeed
        let direction = (playerPosition - position).normalized
        position += direction * speed * CGFloat(deltaTime)
    }

    /// Blue magnet orb collected — start homing this orb to the live player.
    func startVacuum() {
        isVacuuming = true
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
