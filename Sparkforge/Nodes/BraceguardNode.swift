// BraceguardNode.swift
// Sparkforge
//
// v1.6 Arena 2 enemy (Lyra canon): the shield-bearer.
// v1.6 tuning (Brandon playtest 7/9/26): the shield is now FIXED at one
// of four cardinal directions and reduces projectile damage 50% instead
// of blocking outright — readable at a glance mid-chaos, and auto-aim
// still makes progress while flanking doubles it. The original
// rotating full-block version is banked as a later-arena elite.
// Shield affects PROJECTILES only — AoE, DOT, thorns, and zones bypass
// it (shots are stopped by steel; magic isn't).

import SpriteKit

final class BraceguardNode: EnemyNode {

    /// Half-angle of the protected arc (radians) — ~60° each side
    static let shieldHalfAngle: CGFloat = 1.05
    /// Damage multiplier for shots absorbed by the shield
    static let shieldDamageMultiplier: CGFloat = 0.5

    private let shieldNode = SKShapeNode()

    // MARK: - Init

    init(elapsed: TimeInterval) {
        let health = 4 + Int(elapsed / 40)
        super.init(health: health,
                   moveSpeed: GameConfig.Enemy.baseSpeed * 0.5,
                   xpValue: health + 2)
        setScale(1.25)
        buildShieldVisuals()

        // v1.6 tuning: shield locks to a random cardinal direction at spawn
        let cardinals: [CGFloat] = [0, .pi / 2, .pi, .pi * 1.5]
        zRotation = cardinals.randomElement() ?? 0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Visuals

    private func buildShieldVisuals() {
        let r = GameConfig.Enemy.visualRadius

        // Dim the inherited face — it hides behind the shield line
        for child in children {
            if let shape = child as? SKShapeNode, shape.zPosition == 6 {
                shape.alpha = 0.35
            }
            if let shape = child as? SKShapeNode,
               shape.fillColor != .clear && shape.glowWidth == 0 {
                shape.fillColor = SKColor(hex: 0x181A1E)
            }
        }

        // The shield — a thick ash-metal arc across the facing (+x) side
        let shieldPath = CGMutablePath()
        shieldPath.addArc(center: .zero, radius: r + 5,
                          startAngle: -BraceguardNode.shieldHalfAngle,
                          endAngle: BraceguardNode.shieldHalfAngle,
                          clockwise: false)
        shieldNode.path = shieldPath
        shieldNode.strokeColor = SKColor(hex: 0x6A6256, alpha: 0.95)
        shieldNode.fillColor = .clear
        shieldNode.lineWidth = 5
        shieldNode.glowWidth = 2
        shieldNode.zPosition = 8
        addChild(shieldNode)

        // One tiny wary eye peeking above the shield line
        let eye = SKShapeNode(circleOfRadius: 1.6)
        eye.fillColor = SKColor(hex: 0xFF2222)
        eye.strokeColor = .clear
        eye.glowWidth = 3
        eye.position = CGPoint(x: r * 0.2, y: r * 0.45)
        eye.zPosition = 9
        addChild(eye)
    }

    // v1.6 tuning: movement is the standard chase — the body advances on
    // the player but the shield NEVER rotates. Positioning solves it.

    // MARK: - Shield

    /// True if an attack from this position hits the protected arc.
    func blocksHit(from sourcePosition: CGPoint) -> Bool {
        let toSource = sourcePosition - position
        let angleToSource = atan2(toSource.y, toSource.x)
        var diff = angleToSource - zRotation
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        return abs(diff) < BraceguardNode.shieldHalfAngle
    }

    /// Visual feedback for a blocked shot.
    func flashShield() {
        shieldNode.removeAction(forKey: "shieldFlash")
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.shieldNode.strokeColor = SKColor(hex: 0xD8D0C4)
            },
            SKAction.wait(forDuration: 0.08),
            SKAction.run { [weak self] in
                self?.shieldNode.strokeColor = SKColor(hex: 0x6A6256, alpha: 0.95)
            }
        ])
        shieldNode.run(flash, withKey: "shieldFlash")
    }
}
