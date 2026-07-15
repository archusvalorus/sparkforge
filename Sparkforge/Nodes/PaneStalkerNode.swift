// PaneStalkerNode.swift
// Sparkforge
//
// v1.8 Arena 4 enemy (Lyra canon): mid-tier perception pressure.
// A medium body split by a vertical crack — one dot eye, one slit eye. It
// closes normally, then phases out (low alpha, no hitbox, no contact),
// slides to a fresh angle, and fades back in. There is no clean escape
// vector forever. No full-invuln machinery: while phased it is simply a
// ghost — it cannot hit you and you cannot hit it — for a readable beat.
// "It leaves through a door that was never there, and arrives where you weren't looking."

import SpriteKit

final class PaneStalkerNode: EnemyNode {

    private enum Phase { case solid, phased }

    private var phase: Phase = .solid
    private var phaseTimer: TimeInterval = 0
    private var reentryTarget: CGPoint = .zero

    // MARK: - Init

    init(elapsed: TimeInterval) {
        let health = elapsed < 90 ? 2 : 3
        super.init(health: health,
                   moveSpeed: GameConfig.Enemy.baseSpeed * 0.9,
                   xpValue: health + 2)
        applyStalkerVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Visuals

    private func applyStalkerVisuals() {
        let cfg = GameConfig.MirrorwoundEnemies.self
        var eyes: [SKShapeNode] = []
        for child in children {
            guard let shape = child as? SKShapeNode else { continue }
            if shape.fillColor != .clear && shape.glowWidth == 0 && shape.zPosition != 6 {
                shape.fillColor = SKColor(hex: cfg.glassBodyHex)
            }
            if shape.glowWidth > 0 && shape.fillColor == .clear {
                shape.strokeColor = SKColor(hex: cfg.glassEdgeHex, alpha: 0.7)
            }
            if shape.zPosition == 6 && shape.fillColor != .clear {
                shape.fillColor = SKColor(hex: cfg.glassEdgeHex)
                eyes.append(shape)
            }
        }

        // Asymmetry — one dot eye, one slit eye (squash the rightmost).
        if let slit = eyes.max(by: { $0.position.x < $1.position.x }) {
            slit.yScale = 0.3
        }

        // The vertical crack that splits the pane.
        let r = GameConfig.Enemy.visualRadius
        let crack = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 1, y: r - 1))
        path.addLine(to: CGPoint(x: -2, y: 2))
        path.addLine(to: CGPoint(x: 1, y: -r + 1))
        crack.path = path
        crack.strokeColor = SKColor(hex: cfg.glassEdgeHex, alpha: 0.8)
        crack.lineWidth = 1
        crack.zPosition = 7
        addChild(crack)
    }

    // MARK: - Phase-shift AI

    override func chase(target: CGPoint, deltaTime: TimeInterval, globalSlow: CGFloat = 0) {
        guard !isStunned else { return }

        let cfg = GameConfig.MirrorwoundEnemies.self
        let effectiveSlow = min(currentSlow + globalSlow, 0.8)
        let speed = moveSpeed * (1.0 - effectiveSlow)
        phaseTimer += deltaTime

        switch phase {
        case .solid:
            let toTarget = target - position
            if toTarget.length > 4 {
                position += toTarget.normalized * speed * CGFloat(deltaTime)
            }
            if phaseTimer >= cfg.paneStalkerSolidTime {
                beginPhase(around: target)
            }

        case .phased:
            // Slide toward the re-entry point over the phase window.
            let toReentry = reentryTarget - position
            if toReentry.length > 4 {
                let phaseSpeed = cfg.paneStalkerReentryDistance / CGFloat(cfg.paneStalkerPhaseTime)
                position += toReentry.normalized * phaseSpeed * CGFloat(deltaTime)
            }
            if phaseTimer >= cfg.paneStalkerPhaseTime {
                endPhase()
            }
        }
    }

    /// Ghost out: low alpha, drop the hitbox, choose a fresh re-entry angle.
    private func beginPhase(around target: CGPoint) {
        let cfg = GameConfig.MirrorwoundEnemies.self
        phase = .phased
        phaseTimer = 0
        physicsBody?.categoryBitMask = 0  // no contact, no incoming hits
        run(SKAction.fadeAlpha(to: cfg.paneStalkerPhaseAlpha, duration: 0.15))

        let angle = CGFloat.random(in: 0...(2 * .pi))
        reentryTarget = target + CGPoint(x: cos(angle) * cfg.paneStalkerReentryDistance,
                                         y: sin(angle) * cfg.paneStalkerReentryDistance)
    }

    /// Snap back to solid: restore alpha and the hitbox.
    private func endPhase() {
        phase = .solid
        phaseTimer = 0
        physicsBody?.categoryBitMask = GameConfig.Physics.enemy
        run(SKAction.fadeAlpha(to: 1.0, duration: 0.15))
    }
}
