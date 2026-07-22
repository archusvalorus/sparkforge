// AnvilbornNode.swift
// Sparkforge
//
// v2.0 (Unit 2b) — Arena 5 "The Star Anvil" enemy family, late/elite #3.
//
// A heavy star-metal construct. Not fast. Not deceptive. Just mass, occupation,
// and force. It advances with stubborn certainty, then ANCHORS (briefly immovable
// while it winds up) and SLAMS a localized shockwave. Pairs viciously with
// Gravemote pulls (dragged into a slam) and Star Needle lanes.
// Lesson: "The arena is running out of room, and it means it."
// See docs/arena5-star-anvil-creative.md.

import SpriteKit

final class AnvilbornNode: EnemyNode {

    // Tunables (Unit 2b playtest).
    static let speedFactor: CGFloat = 0.45             // stubborn, slow advance
    static var slamRadius: CGFloat { 125 * DeviceScale.gameplay }
    static let slamInterval: TimeInterval = 5.0        // between slams
    static let anchorTelegraph: TimeInterval = 0.9     // anchored wind-up before impact
    static let slamDamage: Int = 16

    private var slamTimer: TimeInterval
    private var anchorTimer: TimeInterval = 0
    /// Anchored = planted mid-wind-up (projecting pressure, not advancing).
    var isAnchored: Bool { anchorTimer > 0 }

    private let windup = SKShapeNode(circleOfRadius: 10)

    init(health: Int, xpValue: Int) {
        slamTimer = TimeInterval.random(in: 2.0...AnvilbornNode.slamInterval)
        super.init(health: health,
                   moveSpeed: GameConfig.Enemy.baseSpeed * AnvilbornNode.speedFactor,
                   xpValue: xpValue)

        // Dark forged shell with a star-core; gold seams.
        setBodyPalette(body: 0x1B1830, rim: 0xFFD98A, eye: 0xFFE0A0)
        setScale(1.35)   // occupies space (matches the existing beefy-enemy pattern)

        let r = GameConfig.Enemy.visualRadius

        // Asymmetrical plate mass — "hammered into shape," not natural.
        for side in [CGFloat(-1), 1] {
            let plate = SKShapeNode()
            let p = CGMutablePath()
            p.move(to: CGPoint(x: side * r * 0.5, y: r * 0.75))
            p.addLine(to: CGPoint(x: side * r * 1.45, y: r * 0.30))
            p.addLine(to: CGPoint(x: side * r * 1.20, y: -r * 0.55))
            p.addLine(to: CGPoint(x: side * r * 0.45, y: -r * 0.30))
            p.closeSubpath()
            plate.path = p
            plate.fillColor = SKColor(hex: 0x241F3C)
            plate.strokeColor = SKColor(hex: 0xFFD98A, alpha: 0.35)   // gold seam
            plate.lineWidth = 1
            plate.zPosition = 4.5
            // Asymmetry: one shoulder rides higher.
            plate.position = CGPoint(x: 0, y: side > 0 ? r * 0.12 : -r * 0.06)
            addChild(plate)
        }

        // Embedded star core.
        let core = SKShapeNode(circleOfRadius: r * 0.3)
        core.fillColor = SKColor(hex: 0xFFF4D8)
        core.strokeColor = .clear
        core.blendMode = .add
        core.glowWidth = 4
        core.zPosition = 6.5
        addChild(core)
        core.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.55, duration: 0.9),
            SKAction.fadeAlpha(to: 1.0, duration: 0.9)
        ])))

        // Wind-up / shockwave ring (hidden at rest).
        windup.fillColor = .clear
        windup.strokeColor = SKColor(hex: 0xFFD98A, alpha: 0.0)
        windup.lineWidth = 2.5
        windup.glowWidth = 5
        windup.zPosition = 3
        addChild(windup)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    /// Anchored Anvilborn plants itself — no advance while winding up.
    override func chase(target: CGPoint, deltaTime: TimeInterval, globalSlow: CGFloat = 0) {
        guard !isAnchored else { return }
        super.chase(target: target, deltaTime: deltaTime, globalSlow: globalSlow)
    }

    /// Drives the anchor → slam cadence. Returns true on the frame the slam
    /// RESOLVES; GameScene damages the player if they're inside `slamRadius`.
    func updateSlam(deltaTime dt: TimeInterval) -> Bool {
        guard !isStunned && !isFrozen else { return false }

        if anchorTimer > 0 {
            anchorTimer -= dt
            if anchorTimer <= 0 {
                fireShockwave()
                slamTimer = AnvilbornNode.slamInterval
                return true
            }
            return false
        }

        slamTimer -= dt
        if slamTimer <= 0 { beginAnchor() }
        return false
    }

    /// Plant + telegraph: a gold ring contracts inward as the impact charges.
    private func beginAnchor() {
        anchorTimer = AnvilbornNode.anchorTelegraph
        windup.removeAllActions()
        windup.alpha = 1                      // a prior slam faded the node out
        windup.setScale(AnvilbornNode.slamRadius / 10)
        windup.strokeColor = SKColor(hex: 0xFFD98A, alpha: 0.75)
        let contract = SKAction.scale(to: 0.5, duration: AnvilbornNode.anchorTelegraph)
        contract.timingMode = .easeIn
        windup.run(contract)
    }

    /// Impact: the ring snaps outward to the slam radius and fades.
    private func fireShockwave() {
        windup.removeAllActions()
        windup.alpha = 1
        windup.setScale(0.5)
        windup.strokeColor = SKColor(hex: 0xFFF0C0, alpha: 0.95)
        let burst = SKAction.scale(to: AnvilbornNode.slamRadius / 10, duration: 0.22)
        burst.timingMode = .easeOut
        windup.run(SKAction.group([burst, SKAction.fadeAlpha(to: 0.0, duration: 0.3)]))
    }
}
