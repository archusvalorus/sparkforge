// MonumentBossNode.swift
// Sparkforge
//
// v2.0 (Unit 2c.1) — the reusable MONUMENT boss base class.
//
// Sparkforge has two boss grammars:
//   • ARENA bosses  — player-scale, mobile, direct pursuit (Titan/Warden/Choir/Lie)
//   • MONUMENT bosses — colossal set-pieces anchored across the TOP THIRD of a
//     doubled arena. The player fights in the lower two-thirds; the boss's
//     attacks DESCEND, radiate, or collapse into that space.
//
// Monument bosses appear at every 5th level (5/10/15/20), with LEGEND bosses
// overriding the quarter-marks (25/50/75/100). This base exists so instance #2
// (Arena 10) costs a fraction of instance #1 — build the platform once.
//
// Design discipline (Lyra): huge does NOT mean unreadable. A monument needs a
// memorable silhouette, ONE dominant pressure axis, 2–3 evolving mechanics,
// exceptionally clean tells, a spectacle phase, and an enrage — not a
// fifty-mechanic raid script.
//
// See docs/arena5-star-anvil-creative.md + the monument-boss-class memory.

import SpriteKit

class MonumentBossNode: SKNode, ArenaBossNode {

    // MARK: - ArenaBossNode surface

    private(set) var health: Int
    let maxHealth: Int
    private(set) var isDead = false
    var healthPercent: CGFloat { maxHealth > 0 ? max(0, CGFloat(health) / CGFloat(maxHealth)) : 0 }
    let contactDamage: Int
    var vulnerabilityMultiplier: CGFloat = 1.0

    // MARK: - Monument state

    /// Reward + death callback, matching the arena-boss convention.
    var onDeath: ((CGPoint, Int) -> Void)?
    let xpValue: Int

    /// Fires ONCE the first time the boss drops below 50% health. Monument fights
    /// suppress all pickup spawns, and this is the single sanctioned HP orb grant
    /// (locked rule — see monument-boss-class memory).
    var onHalfHealth: (() -> Void)?
    private var halfHealthFired = false

    /// Descending healthPercent boundaries, e.g. [0.66, 0.33] = three phases.
    private let phaseThresholds: [CGFloat]
    private(set) var phase: Int = 0

    // MARK: - Init

    init(health: Int, contactDamage: Int, xpValue: Int, phaseThresholds: [CGFloat]) {
        self.health = health
        self.maxHealth = health
        self.contactDamage = contactDamage
        self.xpValue = xpValue
        self.phaseThresholds = phaseThresholds
        super.init()
        zPosition = 6
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Physics

    /// A monument is colossal, but it must still be HITTABLE (projectiles) and
    /// solid enough to punish standing inside it (contact damage). Category is
    /// `.enemy` so the existing projectile-contact path damages it for free.
    /// The whole body is the hitbox — deliberately NOT a small weak-point, since
    /// auto-aim-nearest is canon and a precision target the player can't aim at
    /// would be pure frustration. Call once the subclass knows its radius.
    func configurePhysics(radius: CGFloat) {
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = GameConfig.Physics.enemy
        body.contactTestBitMask = GameConfig.Physics.player | GameConfig.Physics.projectile
        body.collisionBitMask = 0
        body.linearDamping = 0
        body.friction = 0
        physicsBody = body
    }

    // MARK: - Anchoring

    /// Monument bosses sit high: the player keeps the lower two-thirds as a
    /// readable play space while the boss dominates the top of the field.
    static func anchorPosition(arenaRadius: CGFloat) -> CGPoint {
        CGPoint(x: 0, y: arenaRadius * 0.52)
    }

    // MARK: - Damage / phases

    @discardableResult
    func takeDamage(_ amount: Int) -> Bool {
        guard !isDead else { return true }
        let scaled = vulnerabilityMultiplier == 1.0
            ? amount
            : Int((CGFloat(amount) * vulnerabilityMultiplier).rounded())
        health -= scaled

        if !halfHealthFired && healthPercent <= 0.5 {
            halfHealthFired = true
            onHalfHealth?()
        }

        // Advance phases as thresholds are crossed (descending).
        var newPhase = 0
        for (i, t) in phaseThresholds.enumerated() where healthPercent <= t {
            newPhase = i + 1
        }
        if newPhase != phase {
            phase = newPhase
            phaseDidChange(to: phase)
        }

        if health <= 0 {
            health = 0
            isDead = true
            physicsBody?.categoryBitMask = 0   // stop registering hits mid-collapse
            onDeath?(position, xpValue)
            beginDeathSequence()
            return true
        }
        takeDamageFeedback()
        return false
    }

    // MARK: - Per-frame

    func update(deltaTime: TimeInterval, playerPosition: CGPoint) {
        guard !isDead else { return }
        updateBehavior(deltaTime: deltaTime, playerPosition: playerPosition)
    }

    // MARK: - Subclass hooks (override these; base versions are intentionally empty)

    /// Per-frame behaviour for the concrete monument (orbits, marks, sequences).
    func updateBehavior(deltaTime: TimeInterval, playerPosition: CGPoint) {}

    /// Called when a phase threshold is crossed. Escalate here.
    func phaseDidChange(to phase: Int) {}

    /// Brief hit feedback. Override for a bespoke flash.
    func takeDamageFeedback() {}

    /// The monument's collapse. Override for the bespoke cinematic; the base
    /// just fades out so a subclass that forgets still cleans itself up.
    func beginDeathSequence() {
        run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.8),
            SKAction.removeFromParent()
        ]))
    }
}
