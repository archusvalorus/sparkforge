// EnemyProjectileNode.swift
// Sparkforge
//
// Projectile fired by ranged enemies toward the player.
// Slower than player projectiles. Purple glow. Damages player on contact.
//
// v1.4: Carries a damage value instead of instant-kill.

import SpriteKit

final class EnemyProjectileNode: SKNode {
    
    /// v1.4: Damage this projectile deals to the player
    let damage: Int
    
    private let bulletNode: SKShapeNode
    private let direction: CGPoint
    private let projectileSpeed: CGFloat
    private let maxRange: CGFloat
    private var distanceTraveled: CGFloat = 0
    
    init(direction: CGPoint,
         damage: Int = GameConfig.Enemy.baseRangedDamage,
         speed: CGFloat = GameConfig.RangedEnemy.projectileSpeed,
         range: CGFloat = GameConfig.RangedEnemy.projectileRange,
         colorHex: UInt32 = GameConfig.RangedEnemy.projectileColorHex,
         elongated: Bool = false) {

        self.direction = direction.normalized
        self.damage = damage
        self.projectileSpeed = speed
        self.maxRange = range

        let radius = GameConfig.RangedEnemy.projectileRadius

        if elongated {
            // v2.1 (2c): a narrow bolt for the Linekeeper — a capsule along
            // its travel direction. Same contact radius as the orb.
            let len = radius * 5
            bulletNode = SKShapeNode(rect: CGRect(x: -len / 2, y: -radius * 0.55, width: len, height: radius * 1.1),
                                     cornerRadius: radius * 0.55)
            bulletNode.zRotation = atan2(self.direction.y, self.direction.x)
        } else {
            bulletNode = SKShapeNode(circleOfRadius: radius)
        }
        bulletNode.fillColor = SKColor(hex: colorHex)
        bulletNode.strokeColor = .clear
        bulletNode.glowWidth = 4
        
        super.init()
        
        addChild(bulletNode)
        setupPhysics()
        
        if !elongated {
            // Subtle pulse (the orb); the bolt stays crisp.
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.3),
                SKAction.scale(to: 0.9, duration: 0.3)
            ])
            bulletNode.run(SKAction.repeatForever(pulse))
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: GameConfig.RangedEnemy.projectileRadius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.categoryBitMask = GameConfig.Physics.enemyProjectile
        body.contactTestBitMask = GameConfig.Physics.player
        body.collisionBitMask = 0
        physicsBody = body
    }
    
    /// Move each frame. Returns true if expired.
    func move(deltaTime: TimeInterval) -> Bool {
        let displacement = direction * projectileSpeed * CGFloat(deltaTime)
        position += displacement
        distanceTraveled += displacement.length
        return distanceTraveled >= maxRange
    }
}
