// ShardTwinNode.swift
// Sparkforge
//
// v1.8 Arena 4 enemy (Lyra canon): the early teacher of false/real bodies.
// Two overlapping shapes — one solid smoked-glass body that carries the FACE,
// the brighter core, and the only hitbox; one faint outlined reflection with
// NO face and NO physics. Attacks pass straight through the decoy for free, so
// the lesson emerges from collision itself: check the face, not the silhouette.
// The decoy flickers out and re-forms at a new angle so the read stays live.
// "Two shapes, one face. Strike the mask and you strike nothing."

import SpriteKit

final class ShardTwinNode: EnemyNode {

    /// The faceless reflection — visual only, never a physics body.
    private let decoy = SKShapeNode()

    // MARK: - Init

    init(elapsed: TimeInterval) {
        // Early tier: brittle. A touch of HP growth so late spawns aren't free.
        let health = elapsed < 60 ? 1 : 2
        super.init(health: health,
                   moveSpeed: GameConfig.Enemy.baseSpeed * 0.95,
                   xpValue: health + 1)
        applyTwinVisuals()
        buildDecoy()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Visuals

    private func applyTwinVisuals() {
        let cfg = GameConfig.MirrorwoundEnemies.self
        for child in children {
            guard let shape = child as? SKShapeNode else { continue }
            // Body → smoked glass with a brighter core than the decoy.
            if shape.fillColor != .clear && shape.glowWidth == 0 && shape.zPosition != 6 {
                shape.fillColor = SKColor(hex: cfg.glassBodyHex)
            }
            // Rim → pale glass edge (readability: the real body reads stronger).
            if shape.glowWidth > 0 && shape.fillColor == .clear {
                shape.strokeColor = SKColor(hex: cfg.glassEdgeHex, alpha: 0.85)
            }
            // Face → pale glass, so the real body is the one that looks back.
            if shape.zPosition == 6 && shape.fillColor != .clear {
                shape.fillColor = SKColor(hex: cfg.glassEdgeHex)
            }
        }
    }

    /// The decoy: same silhouette, faceless, thin outline, no core, no physics.
    private func buildDecoy() {
        let cfg = GameConfig.MirrorwoundEnemies.self
        let r = GameConfig.Enemy.visualRadius
        decoy.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2),
                            transform: nil)
        decoy.fillColor = SKColor(hex: cfg.glassBodyHex, alpha: 0.45)
        decoy.strokeColor = SKColor(hex: cfg.glassEdgeHex, alpha: 0.4)
        decoy.lineWidth = 1
        decoy.zPosition = 4.5  // under the real body's face layer
        decoy.position = decoyOffset(angle: CGFloat.random(in: 0...(2 * .pi)))
        addChild(decoy)

        // Flicker: hold, fade out, re-form at a new angle, fade back in — forever.
        let hold = SKAction.wait(forDuration: cfg.shardTwinDecoyHold,
                                 withRange: cfg.shardTwinDecoyHold * 0.5)
        let vanish = SKAction.fadeAlpha(to: 0.0, duration: cfg.shardTwinDecoyFade)
        let relocate = SKAction.run { [weak self] in
            guard let self = self else { return }
            self.decoy.position = self.decoyOffset(angle: CGFloat.random(in: 0...(2 * .pi)))
        }
        let reform = SKAction.fadeAlpha(to: 1.0, duration: cfg.shardTwinDecoyFade)
        decoy.run(SKAction.repeatForever(SKAction.sequence([hold, vanish, relocate, reform])))
    }

    private func decoyOffset(angle: CGFloat) -> CGPoint {
        let d = GameConfig.MirrorwoundEnemies.shardTwinDecoyOffset
        return CGPoint(x: cos(angle) * d, y: sin(angle) * d)
    }
}
