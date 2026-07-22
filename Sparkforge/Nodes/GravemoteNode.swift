// GravemoteNode.swift
// Sparkforge
//
// v2.0 (Unit 2b) — Arena 5 "The Star Anvil" enemy family, teacher #1.
//
// A small, unstable gravity ember. Looks harmless, but teaches the player that
// positional control is no longer fully theirs: it drifts slowly and, on a
// telegraphed cadence, emits a LOCALIZED PULL that drags the player toward it —
// the first enemy in the game to displace the player. Lesson: "Your position
// can be stolen." Deliberately GENTLE (disrupts clean lines, never traps) and
// telegraphed (a violet ripple) so it respects Sparkforge's readability + the
// player's movement agency. See docs/arena5-star-anvil-creative.md.

import SpriteKit

final class GravemoteNode: EnemyNode {

    // Tunables (Unit 2b playtest — the pull is the movement-feel knob).
    static let driftSpeedFactor: CGFloat = 0.55        // slow drift vs base enemy speed
    static var pullRadius: CGFloat { 150 * DeviceScale.gameplay }
    static let pullStrength: CGFloat = 54              // points/sec nudge during a pulse (Brandon: +a smidge, Jul 22)
    static let pullInterval: TimeInterval = 4.2        // between pulses
    static let pullDuration: TimeInterval = 1.1        // length of a pulse

    private var pullTimer: TimeInterval
    private var pullActive: TimeInterval = 0
    private let ripple = SKShapeNode(circleOfRadius: 10)

    init(health: Int, xpValue: Int) {
        // Stagger first pulse so a cluster doesn't pull in unison.
        pullTimer = TimeInterval.random(in: 1.5...GravemoteNode.pullInterval)
        super.init(health: health,
                   moveSpeed: GameConfig.Enemy.baseSpeed * GravemoteNode.driftSpeedFactor,
                   xpValue: xpValue)

        // Gravity-mote look: dark compressed core, violet rim, star-white eyes.
        setBodyPalette(body: 0x0E0C1C, rim: 0x8A6AD0, eye: 0xE0D8FF)

        // A faint violet gravity ripple that sits behind the body and pulses on
        // a pull (telegraph). Hidden at rest.
        ripple.fillColor = .clear
        ripple.strokeColor = SKColor(hex: 0x8A6AD0, alpha: 0.0)
        ripple.lineWidth = 2
        ripple.glowWidth = 4
        ripple.zPosition = 3
        addChild(ripple)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    /// Drive the pull cadence. Returns the pull strength (points/sec) to apply
    /// this frame if a pulse is active, else 0. GameScene applies the direction
    /// (toward this mote) to the player when in range.
    func updatePull(deltaTime dt: TimeInterval) -> CGFloat {
        if pullActive > 0 {
            pullActive -= dt
            return GravemoteNode.pullStrength
        }
        pullTimer -= dt
        if pullTimer <= 0 {
            pullTimer = GravemoteNode.pullInterval
            pullActive = GravemoteNode.pullDuration
            telegraphPull()
            return GravemoteNode.pullStrength
        }
        return 0
    }

    /// A violet ripple expands outward — the "a pull is coming" tell.
    private func telegraphPull() {
        ripple.removeAllActions()
        ripple.alpha = 1                      // a prior pulse faded the node out
        ripple.setScale(0.4)
        ripple.strokeColor = SKColor(hex: 0x8A6AD0, alpha: 0.8)
        let expand = SKAction.scale(to: (GravemoteNode.pullRadius / 10) * 0.9, duration: GravemoteNode.pullDuration)
        expand.timingMode = .easeOut
        ripple.run(SKAction.group([
            expand,
            SKAction.fadeAlpha(to: 0.0, duration: GravemoteNode.pullDuration)
        ]))
    }
}
