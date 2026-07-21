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
    /// v1.9 Polar Vortex (T4): a condensed icicle that shatters into shards on hit
    let isIcicle: Bool

    init(direction: CGPoint,
         speed: CGFloat = GameConfig.Projectile.speed,
         range: CGFloat = GameConfig.Projectile.maxRange,
         pierces: Int = 0,
         damageMultiplier: CGFloat = 1.0,
         isCrit: Bool = false,
         spawnsGravityWell: Bool = false,
         voidStyle: Bool = false,
         isIcicle: Bool = false,
         frostStyle: Bool = false) {
        self.isIcicle = isIcicle

        self.direction = direction.normalized
        self.projectileSpeed = speed
        self.maxRange = range
        self.remainingPierces = pierces
        self.damageMultiplier = damageMultiplier
        self.isCrit = isCrit
        self.spawnsGravityWell = spawnsGravityWell

        let config = GameConfig.Projectile.self
        let radius = isCrit ? config.radius * 1.5 : config.radius

        if isIcicle {
            // v1.9 Polar Vortex (T4): a big icy shard oriented along travel.
            bulletNode = SKShapeNode(ellipseOf: CGSize(width: radius * 5.0, height: radius * 2.2))
            bulletNode.fillColor = SKColor(hex: 0xCCF2FF)
            bulletNode.strokeColor = SKColor(hex: 0x66CCFF, alpha: 0.95)
            bulletNode.lineWidth = 1.5
            bulletNode.glowWidth = 7
            bulletNode.zRotation = atan2(direction.y, direction.x)
        } else if voidStyle {
            // v1.9 Erasure Void-Touched (T2): an empowered, elongated purple bolt
            // oriented along travel — reads as "these shots pierce reality."
            bulletNode = SKShapeNode(ellipseOf: CGSize(width: radius * 3.6, height: radius * 1.4))
            bulletNode.fillColor = isCrit ? SKColor(hex: 0xE060FF) : SKColor(hex: 0xB565D8)
            bulletNode.strokeColor = SKColor(hex: 0x6C3483, alpha: 0.9)
            bulletNode.lineWidth = 1
            bulletNode.glowWidth = isCrit ? 7 : 5
            bulletNode.zRotation = atan2(direction.y, direction.x)
        } else if frostStyle {
            // v1.9 Polar Vortex (T1+): the storm chills your shots frost-blue.
            bulletNode = SKShapeNode(circleOfRadius: radius)
            bulletNode.fillColor = isCrit ? SKColor(hex: 0xAEE9FF) : SKColor(hex: 0x66CCFF)
            bulletNode.strokeColor = SKColor(hex: 0x2E9BD6, alpha: 0.8)
            bulletNode.lineWidth = 0.5
            bulletNode.glowWidth = isCrit ? 5 : 3
        } else {
            bulletNode = SKShapeNode(circleOfRadius: radius)
            bulletNode.fillColor = isCrit ? SKColor(hex: 0xFF4444) : SKColor(hex: config.colorHex)
            bulletNode.strokeColor = .clear
            bulletNode.glowWidth = isCrit ? 5 : 3
        }

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
