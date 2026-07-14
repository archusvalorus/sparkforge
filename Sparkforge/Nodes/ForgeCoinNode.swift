// ForgeCoinNode.swift
// Sparkforge
//
// v1.8 (Unit 2): Forge XP Coin — a large spinning ember-orange token that
// erupts from a boss's death and scatters arena-wide. NOT magnetized (walking
// to them is the point — health-orb philosophy). Grants FLAT forge XP on
// pickup, deliberately not boosted by the XP Boost ad. Despawns if uncollected.
// Visual identity is Lyra canon — docs/lyra-response-v1.8.md (Ask 4a):
// "spark-stamped forge token… a boss does not drop money, it sheds proof."

import SpriteKit

final class ForgeCoinNode: SKNode {

    let forgeXPValue: Int
    private let despawnTime: TimeInterval
    private var age: TimeInterval = 0

    private let discNode: SKShapeNode
    private let glowNode: SKShapeNode
    private let stampNode: SKShapeNode

    init(forgeXPValue: Int = GameConfig.ForgeCoin.forgeXPValue) {
        self.forgeXPValue = forgeXPValue
        self.despawnTime = GameConfig.ForgeCoin.despawnTime

        let r = GameConfig.ForgeCoin.visualRadius

        // Ember rim glow
        glowNode = SKShapeNode(circleOfRadius: r + 3)
        glowNode.fillColor = SKColor(hex: GameConfig.ForgeCoin.rimColorHex, alpha: 0.22)
        glowNode.strokeColor = .clear
        glowNode.glowWidth = 7
        glowNode.zPosition = 3

        // Coin disc — hot core, bold ember rim
        discNode = SKShapeNode(circleOfRadius: r)
        discNode.fillColor = SKColor(hex: GameConfig.ForgeCoin.coreColorHex, alpha: 0.95)
        discNode.strokeColor = SKColor(hex: GameConfig.ForgeCoin.rimColorHex)
        discNode.lineWidth = 2.5
        discNode.zPosition = 4

        // Four-point spark stamp struck into the coin
        stampNode = SKShapeNode()
        stampNode.path = ForgeCoinNode.sparkStampPath(radius: r * 0.62, waist: r * 0.16)
        stampNode.fillColor = SKColor(hex: GameConfig.ForgeCoin.stampColorHex)
        stampNode.strokeColor = .clear
        stampNode.zPosition = 5

        super.init()

        // Dark shadow edge behind the disc for weight/depth
        let shadow = SKShapeNode(circleOfRadius: r + 1)
        shadow.fillColor = SKColor(hex: GameConfig.ForgeCoin.shadowColorHex, alpha: 0.9)
        shadow.strokeColor = .clear
        shadow.zPosition = 3.5

        addChild(glowNode)
        addChild(shadow)
        addChild(discNode)
        addChild(stampNode)

        setupPhysics()
        startSpin()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Physics

    private func setupPhysics() {
        // No magnet — a plain contact body sized to pickupRadius. Walking over
        // the coin collects it; nothing pulls it toward the player.
        let body = SKPhysicsBody(circleOfRadius: GameConfig.ForgeCoin.pickupRadius)
        body.isDynamic = false
        body.categoryBitMask = GameConfig.Physics.forgeCoin
        body.contactTestBitMask = GameConfig.Physics.player
        body.collisionBitMask = 0
        physicsBody = body
    }

    // MARK: - Animation

    /// Spin via xScale oscillation — the disc narrows to an edge and back, and
    /// the stamp compresses with it; the rim glow breathes brightest near the
    /// wide frame. (Lyra: "xScale oscillation reads as spin.")
    private func startSpin() {
        let half = GameConfig.ForgeCoin.spinPeriod / 2
        let spin = SKAction.sequence([
            SKAction.scaleX(to: 0.15, y: 1.0, duration: half),
            SKAction.scaleX(to: 1.0, y: 1.0, duration: half)
        ])
        spin.timingMode = .easeInEaseOut
        run(SKAction.repeatForever(spin))

        let breathe = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.10, duration: half),
            SKAction.fadeAlpha(to: 0.30, duration: half)
        ])
        breathe.timingMode = .easeInEaseOut
        glowNode.run(SKAction.repeatForever(breathe))
    }

    // MARK: - Update

    /// Call each frame. Returns true when the coin should despawn.
    func update(deltaTime: TimeInterval) -> Bool {
        age += deltaTime
        if age > despawnTime - 2.0 {
            let remaining = despawnTime - age
            alpha = max(0, CGFloat(remaining / 2.0))
        }
        return age >= despawnTime
    }

    // MARK: - Collection

    func collect() {
        physicsBody = nil
        removeAllActions()  // stop the spin so the pop reads cleanly
        let pop = SKAction.group([
            SKAction.scale(to: 1.6, duration: 0.14),
            SKAction.fadeOut(withDuration: 0.14)
        ])
        run(SKAction.sequence([pop, SKAction.removeFromParent()]))
    }

    // MARK: - Geometry

    /// A four-point spark (✦): outer points at E/N/W/S, pinched waist between.
    private static func sparkStampPath(radius: CGFloat, waist: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let points = 4
        for i in 0..<(points * 2) {
            let rad = (i % 2 == 0) ? radius : waist  // alternate outer point / inner waist
            let angle = CGFloat(i) * .pi / CGFloat(points)  // 45° steps
            let p = CGPoint(x: cos(angle) * rad, y: sin(angle) * rad)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Scatter

    /// Random arena-wide target for the boss-death eruption — coins scatter
    /// across the whole arena, not clustered at the corpse.
    static func randomArenaPosition() -> CGPoint {
        let maxR = GameConfig.Arena.radius * 0.8
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance = CGFloat.random(in: 40...maxR)
        return CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
    }
}
