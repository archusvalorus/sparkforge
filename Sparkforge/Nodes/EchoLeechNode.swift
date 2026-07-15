// EchoLeechNode.swift
// Sparkforge
//
// v1.8 Arena 4 enemy (Lyra canon): the late/elite teacher — your own rhythm
// turned against you. A small pale-glass body with a trailing reflection line
// and two hungry eyes, no mouth. It does NOT clone every attack (unreadable +
// expensive). Instead it closes to range and fires ONE hostile purple echo
// shot on a loose cadence; the tell implies a copy even though it's simplified.
// Deliberately avoids Shatter/freeze machinery — this is reflected aggression.
// "It cannot fight you. It only waits for you to fight yourself, then agrees."

import SpriteKit

final class EchoLeechNode: EnemyNode {

    /// Fire one echo shot toward the player. GameScene spawns the purple bullet.
    var onEchoShot: ((_ position: CGPoint, _ direction: CGPoint) -> Void)?

    private var fireTimer: TimeInterval = 0
    private var nextShotDelay: TimeInterval

    // MARK: - Init

    init(elapsed: TimeInterval) {
        let health = elapsed < 110 ? 3 : 4
        // Seed the first shot with the full loose cadence so it doesn't fire
        // the instant it enters range.
        let cfg = GameConfig.MirrorwoundEnemies.self
        nextShotDelay = cfg.echoLeechShotInterval
            + TimeInterval.random(in: -cfg.echoLeechShotJitter...cfg.echoLeechShotJitter)
        super.init(health: health,
                   moveSpeed: GameConfig.Enemy.baseSpeed * 0.8,
                   xpValue: health + 2)
        setScale(0.9)
        applyLeechVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Visuals

    private func applyLeechVisuals() {
        let cfg = GameConfig.MirrorwoundEnemies.self
        for child in children {
            guard let shape = child as? SKShapeNode else { continue }
            if shape.fillColor != .clear && shape.glowWidth == 0 && shape.zPosition != 6 {
                shape.fillColor = SKColor(hex: cfg.glassBodyHex)
            }
            if shape.glowWidth > 0 && shape.fillColor == .clear {
                shape.strokeColor = SKColor(hex: cfg.glassEdgeHex, alpha: 0.6)
            }
            if shape.zPosition == 6 {
                // Hungry pale eyes; strip the mouth + brows (stroke-only shapes).
                if shape.fillColor != .clear {
                    shape.fillColor = SKColor(hex: cfg.glassEdgeHex)
                } else if shape.strokeColor != .clear {
                    shape.path = nil
                }
            }
        }

        // A faint trailing reflection line behind the body.
        let r = GameConfig.Enemy.visualRadius
        let trail = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: -r * 1.6, y: 0))
        trail.path = path
        trail.strokeColor = SKColor(hex: cfg.glassEdgeHex, alpha: 0.3)
        trail.lineWidth = 1.5
        trail.zPosition = 3
        addChild(trail)
    }

    // MARK: - Echo AI

    override func chase(target: CGPoint, deltaTime: TimeInterval, globalSlow: CGFloat = 0) {
        guard !isStunned else { return }

        let cfg = GameConfig.MirrorwoundEnemies.self
        let effectiveSlow = min(currentSlow + globalSlow, 0.8)
        let speed = moveSpeed * (1.0 - effectiveSlow)

        let toTarget = target - position
        let dist = toTarget.length

        // Close to echo range, then hold and reflect the player's rhythm back.
        if dist > cfg.echoLeechEngageRange {
            position += toTarget.normalized * speed * CGFloat(deltaTime)
            return
        }

        // Keep a little spacing so it doesn't collapse into melee range.
        if dist < cfg.echoLeechEngageRange * 0.65 {
            position = position - toTarget.normalized * speed * 0.5 * CGFloat(deltaTime)
        }

        fireTimer += deltaTime
        if fireTimer >= nextShotDelay {
            fireTimer = 0
            nextShotDelay = cfg.echoLeechShotInterval
                + TimeInterval.random(in: -cfg.echoLeechShotJitter...cfg.echoLeechShotJitter)
            fireEcho(toward: target)
        }
    }

    /// Fire one purple echo, flashing purple only during the shot.
    private func fireEcho(toward target: CGPoint) {
        let dir = (target - position).normalized
        onEchoShot?(position, dir)

        let purple = SKColor(hex: GameConfig.MirrorwoundEnemies.hostilePurpleHex)
        let glass = SKColor(hex: GameConfig.MirrorwoundEnemies.glassEdgeHex)
        for child in children {
            guard let shape = child as? SKShapeNode, shape.zPosition == 6,
                  shape.fillColor != .clear else { continue }
            shape.run(SKAction.sequence([
                SKAction.run { shape.fillColor = purple },
                SKAction.wait(forDuration: 0.22),
                SKAction.run { shape.fillColor = glass }
            ]))
        }
    }
}
