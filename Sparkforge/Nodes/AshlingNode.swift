// AshlingNode.swift
// Sparkforge
//
// v1.6 Arena 2 enemy (Lyra canon): the splitter.
// Small ash-gray chaser that splits into two faster, fragile shards on
// death. "Arena 2 teaches the player that killing is no longer always
// clean." GameScene handles the split in onEnemyKilled.
// Burst kills (Ember Burst / Static Crown etc.) bypass onEnemyKilled by
// precedent, so AoE builds cleanly counter splitters — intentional.

import SpriteKit

final class AshlingNode: EnemyNode {

    /// Shards are the post-split children — they don't split again.
    let isShard: Bool

    private var moteEmitter: SKEmitterNode?

    // MARK: - Init

    init(elapsed: TimeInterval, isShard: Bool) {
        self.isShard = isShard

        let health: Int
        let speedScale: CGFloat
        let xp: Int
        if isShard {
            health = 1
            speedScale = 1.3
            xp = 1
        } else {
            health = elapsed < 60 ? 1 : 2
            speedScale = 0.95
            xp = 2
        }

        super.init(health: health,
                   moveSpeed: GameConfig.Enemy.baseSpeed * speedScale,
                   xpValue: xp)

        setScale(isShard ? 0.55 : 0.85)
        applyAshVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Visuals

    private func applyAshVisuals() {
        // Ash-gray outline, near-black body, ember-pin eyes
        for child in children {
            if let shape = child as? SKShapeNode {
                if shape.glowWidth > 0 && shape.fillColor == .clear {
                    shape.strokeColor = SKColor(hex: 0x8A8478, alpha: 0.55)
                }
                if shape.fillColor != .clear && shape.glowWidth == 0 {
                    shape.fillColor = SKColor(hex: 0x14161A)
                }
                // Eyes → tiny ember pins
                if shape.zPosition == 6, shape.fillColor == SKColor(hex: 0xFF2222) {
                    shape.fillColor = SKColor(hex: 0xFF7733)
                    shape.setScale(0.8)
                }
            }
        }

        // Full Ashlings shed pale ash motes while moving (shards don't — perf)
        if !isShard {
            let mote = SKEmitterNode()
            mote.particleBirthRate = 2.5
            mote.particleLifetime = 0.7
            mote.particleLifetimeRange = 0.3
            mote.particleSpeed = 6
            mote.particleSpeedRange = 4
            mote.emissionAngle = -.pi / 2
            mote.emissionAngleRange = 1.2
            mote.particleAlpha = 0.25
            mote.particleAlphaSpeed = -0.35
            mote.particleScale = 0.03
            mote.particleColor = SKColor(hex: 0xD8D0C4)
            mote.particleColorBlendFactor = 1.0
            mote.particleBlendMode = .alpha
            mote.zPosition = 3

            let dotSize = CGSize(width: 6, height: 6)
            let renderer = UIGraphicsImageRenderer(size: dotSize)
            mote.particleTexture = SKTexture(image: renderer.image { ctx in
                UIColor.white.setFill()
                ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: dotSize))
            })

            addChild(mote)
            moteEmitter = mote
        }
    }

    /// Point the mote trail at the world so motes linger where the Ashling was.
    func setMoteTarget(_ node: SKNode) {
        moteEmitter?.targetNode = node
    }
}
