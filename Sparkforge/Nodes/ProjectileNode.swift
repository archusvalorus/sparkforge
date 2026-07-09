// ProjectileNode.swift
// Sparkforge
//
// Phase 3: Supports pierce, variable speed/range, carries stat snapshot.

import SpriteKit

final class ProjectileNode: SKNode {
    
    private let bulletNode: SKShapeNode
    private let direction: CGPoint
    private var distanceTraveled: CGFloat = 0
    
    /// Max range for this specific projectile
    let maxRange: CGFloat
    /// Speed for this projectile
    let projectileSpeed: CGFloat
    /// How many enemies this can still pierce through
    var remainingPierces: Int
    /// Damage multiplier snapshot
    let damageMultiplier: CGFloat
    /// Crit check snapshot
    let isCrit: Bool
    /// Whether to spawn gravity well on expire
    let spawnsGravityWell: Bool
    
    init(direction: CGPoint,
         speed: CGFloat = GameConfig.Projectile.speed,
         range: CGFloat = GameConfig.Projectile.maxRange,
         pierces: Int = 0,
         damageMultiplier: CGFloat = 1.0,
         isCrit: Bool = false,
         spawnsGravityWell: Bool = false) {
        
        self.direction = direction.normalized
        self.projectileSpeed = speed
        self.maxRange = range
        self.remainingPierces = pierces
        self.damageMultiplier = damageMultiplier
        self.isCrit = isCrit
        self.spawnsGravityWell = spawnsGravityWell
        
        let config = GameConfig.Projectile.self
        let radius = isCrit ? config.radius * 1.5 : config.radius
        
        bulletNode = SKShapeNode(circleOfRadius: radius)
        bulletNode.fillColor = isCrit ? SKColor(hex: 0xFF4444) : SKColor(hex: config.colorHex)
        bulletNode.strokeColor = .clear
        bulletNode.glowWidth = isCrit ? 5 : 3
        
        super.init()
        
        addChild(bulletNode)
        setupPhysics()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: GameConfig.Projectile.radius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.categoryBitMask = GameConfig.Physics.projectile
        body.contactTestBitMask = GameConfig.Physics.enemy
        body.collisionBitMask = 0
        physicsBody = body
    }
    
    /// Call each frame. Returns true if projectile should be removed.
    func move(deltaTime: TimeInterval) -> Bool {
        let displacement = direction * projectileSpeed * CGFloat(deltaTime)
        position += displacement
        distanceTraveled += displacement.length
        return distanceTraveled >= maxRange
    }
    
    /// Called when hitting an enemy. Returns true if projectile should be consumed.
    func onHitEnemy() -> Bool {
        if remainingPierces > 0 {
            remainingPierces -= 1
            // Brief flash to show pierce
            let flash = SKAction.sequence([
                SKAction.scale(to: 0.7, duration: 0.03),
                SKAction.scale(to: 1.0, duration: 0.03)
            ])
            run(flash)
            return false  // Don't consume
        }
        return true  // Consume projectile
    }
}
