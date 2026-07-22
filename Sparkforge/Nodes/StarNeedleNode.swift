// StarNeedleNode.swift
// Sparkforge
//
// v2.0 (Unit 2b) — Arena 5 "The Star Anvil" enemy family, mid-pressure #2.
//
// A forged lance of committed trajectory. It approaches, LOCKS a firing line
// through the player (a clear telegraph), then COMMITS to a high-speed linear
// dash along that fixed line — it does NOT re-aim mid-commit. Punishes LATE
// movement, not random movement: the player must pick a dodge direction and
// go. Lesson: "Decision beats panic." A more elegant, readable upgrade to
// generic ranged pressure. See docs/arena5-star-anvil-creative.md.

import SpriteKit

final class StarNeedleNode: EnemyNode {

    private enum Phase { case approach, lock, dash, recover }

    // Tunables (Unit 2b playtest).
    static let approachSpeedFactor: CGFloat = 0.75
    static var lockRange: CGFloat { 300 * DeviceScale.gameplay }
    static let lockDuration: TimeInterval = 0.85     // telegraph window
    static let dashSpeed: CGFloat = 640
    static let dashDuration: TimeInterval = 0.5      // ~320pt lunge
    static let recoverDuration: TimeInterval = 1.3

    private var phase: Phase = .approach
    private var phaseTimer: TimeInterval = 0
    private var dashDir: CGPoint = .zero

    private let shard = SKShapeNode()          // the luminous lance body (identity)
    private let telegraph = SKShapeNode()      // the committed-line tell

    init(health: Int, xpValue: Int) {
        super.init(health: health,
                   moveSpeed: GameConfig.Enemy.baseSpeed * StarNeedleNode.approachSpeedFactor,
                   xpValue: xpValue)

        // Dim the round core; the shard is the readable body.
        setBodyPalette(body: 0x14122A, rim: 0xFFD98A, eye: 0xFFF0C0)

        // Elongated gold-white shard pointing along +x (rotated to aim/travel).
        let r = GameConfig.Enemy.visualRadius
        let p = CGMutablePath()
        p.move(to: CGPoint(x: r * 2.6, y: 0))         // tip
        p.addLine(to: CGPoint(x: -r * 0.4, y: r * 0.5))
        p.addLine(to: CGPoint(x: -r * 1.2, y: 0))     // trailing spine
        p.addLine(to: CGPoint(x: -r * 0.4, y: -r * 0.5))
        p.closeSubpath()
        shard.path = p
        shard.fillColor = SKColor(hex: 0xFFE8B0)
        shard.strokeColor = SKColor(hex: 0xFFD98A, alpha: 0.9)
        shard.lineWidth = 1
        shard.glowWidth = 3
        shard.zPosition = 7
        addChild(shard)

        telegraph.strokeColor = SKColor(hex: 0xFFE0A0, alpha: 0.0)
        telegraph.lineWidth = 2
        telegraph.glowWidth = 3
        telegraph.zPosition = 2
        addChild(telegraph)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func chase(target: CGPoint, deltaTime dt: TimeInterval, globalSlow: CGFloat = 0) {
        guard !isStunned && !isFrozen else { return }
        phaseTimer -= dt

        switch phase {
        case .approach:
            let slow = min(currentSlow + globalSlow, 0.8)
            let dir = (target - position).normalized
            position += dir * moveSpeed * (1 - slow) * CGFloat(dt)
            aim(dir)
            if position.distance(to: target) < StarNeedleNode.lockRange { enterLock(target: target) }

        case .lock:
            // Hold; the telegraph stays fixed on the COMMITTED line (no re-aim).
            if phaseTimer <= 0 { enterDash() }

        case .dash:
            position += dashDir * StarNeedleNode.dashSpeed * CGFloat(dt)
            if phaseTimer <= 0 { enterRecover() }

        case .recover:
            if phaseTimer <= 0 { phase = .approach }
        }
    }

    private func aim(_ dir: CGPoint) {
        guard dir.x != 0 || dir.y != 0 else { return }
        shard.zRotation = atan2(dir.y, dir.x)
    }

    private func enterLock(target: CGPoint) {
        phase = .lock
        phaseTimer = StarNeedleNode.lockDuration
        dashDir = (target - position).normalized   // committed here, then frozen
        aim(dashDir)

        // Draw the committed line from the needle forward along dashDir.
        let len = StarNeedleNode.dashSpeed * CGFloat(StarNeedleNode.dashDuration) + 60
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: dashDir.x * len, y: dashDir.y * len))
        telegraph.path = path
        telegraph.removeAllActions()
        telegraph.strokeColor = SKColor(hex: 0xFFE0A0, alpha: 0.85)
        // A quick "winding up" flicker on the shard as the tell.
        shard.run(SKAction.sequence([
            SKAction.scale(to: 1.25, duration: StarNeedleNode.lockDuration * 0.7),
            SKAction.scale(to: 1.0, duration: StarNeedleNode.lockDuration * 0.3)
        ]))
    }

    private func enterDash() {
        phase = .dash
        phaseTimer = StarNeedleNode.dashDuration
        telegraph.run(SKAction.fadeAlpha(to: 0, duration: 0.15))
    }

    private func enterRecover() {
        phase = .recover
        phaseTimer = StarNeedleNode.recoverDuration
    }
}
