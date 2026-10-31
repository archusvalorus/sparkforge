#if DEBUG
import SpriteKit

/// Controlled Arena 8 moving anchor. No aura, shield, ranged attack or troops.
/// The scene supplies ordinary melee health/XP progression and packet intent.
final class CinderCarrierNode: EnemyNode {
    var packetNavigationTarget: CGPoint?
    var packetNavigationSafePhase: Bool { !isStunned && !isFrozen }

    override var geometryFootprintRadius: CGFloat { GameConfig.Arena8CarrierFixture.geometryRadius }
    override var hitBodyRadius: CGFloat { GameConfig.Arena8CarrierFixture.hitRadius }

    init(health: Int, xpValue: Int) {
        let tuning = GameConfig.Arena8CarrierFixture.self
        super.init(health: health, moveSpeed: tuning.moveSpeed, xpValue: xpValue)
        setBodyPalette(body: 0x2A2420, rim: 0x3F8F8A, eye: 0xFF7722)

        // Keep the inherited body/rim objects so normal status tint and death
        // handling still address their actual visible shapes. The low crate's
        // 10x6 half-extents (including stroke) stay inside the 14-point body.
        let box = CGRect(x: -10, y: -6, width: 20, height: 12)
        for shape in children.compactMap({ $0 as? SKShapeNode }) {
            if shape.zPosition == 4 || shape.zPosition == 5 {
                shape.path = CGPath(roundedRect: box, cornerWidth: 2, cornerHeight: 2, transform: nil)
            }
            shape.glowWidth = min(shape.glowWidth, 0.5)
        }
        let ribs = SKShapeNode()
        let path = CGMutablePath()
        for x in [CGFloat(-5), CGFloat(5)] {
            path.move(to: CGPoint(x: x, y: -6))
            path.addLine(to: CGPoint(x: x, y: 6))
        }
        ribs.path = path
        ribs.strokeColor = SKColor(hex: 0xD9D2C4, alpha: 0.6)
        ribs.lineWidth = 1
        ribs.zPosition = 5.5
        addChild(ribs)

        let body = SKPhysicsBody(circleOfRadius: tuning.hitRadius)
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

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func chase(target: CGPoint, deltaTime: TimeInterval, globalSlow: CGFloat = 0) {
        super.chase(target: packetNavigationTarget ?? target, deltaTime: deltaTime, globalSlow: globalSlow)
    }
}
#endif
