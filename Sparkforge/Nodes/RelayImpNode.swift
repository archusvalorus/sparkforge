// RelayImpNode.swift
// Sparkforge
//
// v1.7 Arena 3 enemy (Lyra canon): chain pressure.
// A small, nervous chaser that's weak alone — but when two imps drift
// near each other, a danger arc charges between them and fires.
// GameScene owns the pairing and the arc lifecycle (updateRelayArcs);
// the imp itself is just a fast little body with a gold face.

import SpriteKit

final class RelayImpNode: EnemyNode {

    /// Stable identity for arc pair bookkeeping in GameScene
    let impID: Int
    private static var nextImpID = 0

    // MARK: - Init

    init(elapsed: TimeInterval) {
        impID = Self.nextImpID
        Self.nextImpID += 1

        let health = elapsed < 60 ? 1 : 2
        super.init(health: health,
                   moveSpeed: GameConfig.Enemy.baseSpeed * 1.1,
                   xpValue: 2)

        setScale(0.8)
        applyImpVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Visuals

    private func applyImpVisuals() {
        for child in children {
            if let shape = child as? SKShapeNode {
                if shape.fillColor != .clear && shape.glowWidth == 0 && shape.zPosition != 6 {
                    shape.fillColor = SKColor(hex: 0x14161A)
                }
                if shape.glowWidth > 0 && shape.fillColor == .clear {
                    shape.strokeColor = SKColor(hex: 0xF6D36B, alpha: 0.5)
                }
                if shape.zPosition == 6 {
                    if shape.fillColor != .clear {
                        shape.fillColor = SKColor(hex: 0xF6D36B)
                    }
                    if shape.strokeColor != .clear {
                        shape.strokeColor = SKColor(hex: 0xE8C455, alpha: 0.85)
                    }
                }
            }
        }

        // A tiny anode tick above the body — the arc's attachment point
        let tick = SKShapeNode(rectOf: CGSize(width: 2.5, height: 5), cornerRadius: 1)
        tick.fillColor = SKColor(hex: 0xF6D36B, alpha: 0.9)
        tick.strokeColor = .clear
        tick.position = CGPoint(x: 0, y: GameConfig.Enemy.visualRadius + 4)
        tick.zPosition = 7
        addChild(tick)

        // Nervous idle — quick, tiny jitter
        let jitter = SKAction.sequence([
            SKAction.moveBy(x: 1.2, y: 0.6, duration: 0.07),
            SKAction.moveBy(x: -1.2, y: -0.6, duration: 0.07),
            SKAction.wait(forDuration: 0.4, withRange: 0.5)
        ])
        tick.run(SKAction.repeatForever(jitter))
    }
}
