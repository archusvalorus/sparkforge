// GravityWellNode.swift
// Sparkforge
//
// v1.6: Pull zone spawned by expired projectiles (Gravity Well card),
// upgraded by Event Horizon (longer duration + DOT), and spawned huge
// by the Singularity synergy.
//
// Visual is deep indigo-blue, deliberately NOT purple — purple is
// reserved for enemy danger (design canon).

import SpriteKit

final class GravityWellNode: SKNode {

    // MARK: - Config

    let radius: CGFloat
    let dps: CGFloat
    private var remaining: TimeInterval

    /// Pull speed applied to enemies inside the radius (points/sec)
    static let pullStrength: CGFloat = 70

    // MARK: - Visual Nodes

    private let ringNode: SKShapeNode
    private let swirlNode: SKShapeNode

    // MARK: - Init

    init(radius: CGFloat, duration: TimeInterval, dps: CGFloat) {
        self.radius = radius
        self.remaining = duration
        self.dps = dps

        ringNode = SKShapeNode(circleOfRadius: radius)
        ringNode.strokeColor = SKColor(hex: 0x4466DD, alpha: 0.5)
        ringNode.fillColor = SKColor(hex: 0x223366, alpha: 0.15)
        ringNode.lineWidth = 1.5
        ringNode.glowWidth = 4
        ringNode.zPosition = 0

        // Inner swirl — an arc that rotates to sell the pull
        swirlNode = SKShapeNode()
        let swirlPath = CGMutablePath()
        swirlPath.addArc(center: .zero, radius: radius * 0.5,
                         startAngle: 0, endAngle: .pi * 1.4, clockwise: false)
        swirlNode.path = swirlPath
        swirlNode.strokeColor = SKColor(hex: 0x6688FF, alpha: 0.6)
        swirlNode.fillColor = .clear
        swirlNode.lineWidth = 1.5
        swirlNode.zPosition = 1

        super.init()

        addChild(ringNode)
        addChild(swirlNode)

        swirlNode.run(SKAction.repeatForever(
            SKAction.rotate(byAngle: -.pi * 2, duration: 0.8)
        ))

        let pulse = SKAction.sequence([
            SKAction.scale(to: 0.92, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ])
        ringNode.run(SKAction.repeatForever(pulse))

        // Pop-in
        setScale(0.0)
        run(SKAction.scale(to: 1.0, duration: 0.15))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Update

    /// Tick the well. Pulls enemies inside the radius toward center and
    /// accumulates DOT. Returns (expired, dotDamage) — dotDamage is the
    /// whole damage to apply this frame to enemies inside (0 most frames).
    func update(deltaTime: TimeInterval, enemies: [EnemyNode]) -> (expired: Bool, dotDamage: Int) {
        remaining -= deltaTime

        for enemy in enemies where enemy.position.distance(to: position) < radius {
            let dir = (position - enemy.position).normalized
            enemy.position += dir * GravityWellNode.pullStrength * CGFloat(deltaTime)
        }

        var damage = 0
        if dps > 0 {
            dotAccumulator += dps * CGFloat(deltaTime)
            if dotAccumulator >= 1.0 {
                damage = Int(dotAccumulator)
                dotAccumulator -= CGFloat(damage)
            }
        }

        return (remaining <= 0, damage)
    }

    private var dotAccumulator: CGFloat = 0

    /// Collapse animation, then remove from parent.
    func collapseAndRemove() {
        removeAllActions()
        run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 0.0, duration: 0.2),
                SKAction.fadeOut(withDuration: 0.2)
            ]),
            SKAction.removeFromParent()
        ]))
    }
}
