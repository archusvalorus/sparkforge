#if DEBUG
import SpriteKit

/// Grounded contact enemy with a non-damaging planted command tell.
/// Command eligibility/timing/ownership stay in the Scene and packet ledger.
final class LatchSignalerNode: EnemyNode {
    private(set) var isSignaling = false
    private let routeLamp = SKShapeNode(circleOfRadius: 1.5)
    var signalingSafePhase: Bool { !isStunned && !isFrozen && !isFeared && !isVoidTrapped }
    override var geometryFootprintRadius: CGFloat { GameConfig.Arena8SignalerFixture.geometryRadius }
    override var hitBodyRadius: CGFloat { GameConfig.Arena8SignalerFixture.hitRadius }

    init(health: Int, xpValue: Int) {
        let tuning = GameConfig.Arena8SignalerFixture.self
        super.init(health: health, moveSpeed: tuning.moveSpeed, xpValue: xpValue)
        setBodyPalette(body: 0x272D2E, rim: 0xBFA766, eye: 0xE5D8AA)
        let chassis = CGRect(x: -4, y: -10, width: 8, height: 20)
        for shape in children.compactMap({ $0 as? SKShapeNode }) {
            if shape.zPosition == 4 || shape.zPosition == 5 {
                shape.path = CGPath(roundedRect: chassis, cornerWidth: 2, cornerHeight: 2, transform: nil)
            }
            shape.glowWidth = min(shape.glowWidth, 0.5)
        }
        let fork = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -6, y: 10)); path.addLine(to: CGPoint(x: 0, y: 7))
        path.addLine(to: CGPoint(x: 6, y: 10))
        fork.path = path; fork.strokeColor = SKColor(hex: 0xE5D8AA)
        fork.lineWidth = 0.8; fork.zPosition = 5.5; addChild(fork)
        routeLamp.position = CGPoint(x: 0, y: 10.5)
        routeLamp.fillColor = SKColor(hex: 0xFFC65A); routeLamp.strokeColor = .clear
        routeLamp.glowWidth = 0.2; routeLamp.zPosition = 6; addChild(routeLamp)
        let body = SKPhysicsBody(circleOfRadius: tuning.hitRadius)
        body.isDynamic = true; body.affectedByGravity = false; body.allowsRotation = false
        body.categoryBitMask = GameConfig.Physics.enemy
        body.contactTestBitMask = GameConfig.Physics.player | GameConfig.Physics.projectile
        body.collisionBitMask = 0; body.linearDamping = 0; body.friction = 0
        physicsBody = body
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    func setSignaling(_ value: Bool) {
        guard value != isSignaling else { return }
        isSignaling = value; routeLamp.removeAction(forKey: "signalPulse")
        routeLamp.alpha = 1; routeLamp.glowWidth = value ? 0.5 : 0.2
        if value {
            routeLamp.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 0.2), .fadeAlpha(to: 1, duration: 0.2)])), withKey: "signalPulse")
        }
    }
    override func chase(target: CGPoint, deltaTime: TimeInterval, globalSlow: CGFloat = 0) {
        // Plant only while ordinary movement is available. Fear/trap/freeze
        // behavior and Scene-owned forced flight are never replaced by a tell.
        if isSignaling && signalingSafePhase { return }
        super.chase(target: target, deltaTime: deltaTime, globalSlow: globalSlow)
    }
}
#endif
