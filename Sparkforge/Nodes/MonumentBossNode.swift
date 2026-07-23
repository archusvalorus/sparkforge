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
    /// Set by `configurePhysics` — monuments are huge, so every range check
    /// (auto-aim, the Apex familiar, Skybeam's lasso) must measure to the body
    /// surface rather than the origin.
    private(set) var targetingRadius: CGFloat = 0

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
        targetingRadius = radius
        installHealthBar(bodyRadius: radius)
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

    // MARK: - Health bar

    private var hpBarFill: SKShapeNode?
    private var hpBarBG: SKShapeNode?
    private var hpBarWidth: CGFloat = 0

    /// Monuments show their attrition. The mystique of a huge unknowable thing is
    /// good, but players are being taught compounding builds — they've earned the
    /// information to judge "am I actually chunking this down, or should I run?"
    /// Sits BELOW the body (a monument is already at the top of the field, so a
    /// bar above it would be off-screen).
    private func installHealthBar(bodyRadius r: CGFloat) {
        guard hpBarFill == nil else { return }
        let w = r * 1.7, h: CGFloat = 11
        hpBarWidth = w
        let y = -(r + 34)

        let bg = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 3)
        bg.fillColor = SKColor(hex: 0x140F26, alpha: 0.9)
        bg.strokeColor = SKColor(hex: 0xFFD98A, alpha: 0.45)
        bg.lineWidth = 1.5
        bg.position = CGPoint(x: 0, y: y)
        bg.zPosition = 8
        addChild(bg)
        hpBarBG = bg

        let fill = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 3)
        fill.fillColor = SKColor(hex: 0xFFD98A)
        fill.strokeColor = .clear
        fill.glowWidth = 3
        fill.position = CGPoint(x: 0, y: y)
        fill.zPosition = 8.1
        addChild(fill)
        hpBarFill = fill
    }

    /// The monument is collapsing — retire its bar rather than leaving an empty
    /// red sliver under the death animation.
    private func fadeOutHealthBar() {
        let fade = SKAction.fadeOut(withDuration: 0.3)
        hpBarFill?.run(fade)
        hpBarBG?.run(fade)
    }

    /// Shrink the fill from the RIGHT (left-anchored), and shift its tint as the
    /// monument comes apart — gold → hot amber → collapse red.
    private func refreshHealthBar() {
        guard let fill = hpBarFill else { return }
        let pct = max(0, min(1, healthPercent))
        fill.xScale = max(0.0001, pct)
        fill.position = CGPoint(x: -hpBarWidth * (1 - pct) / 2, y: fill.position.y)
        let hex: UInt32 = pct > 0.66 ? 0xFFD98A : (pct > 0.33 ? 0xFFA34D : 0xE8503C)
        fill.fillColor = SKColor(hex: hex)
    }

    // MARK: - Damage / phases

    @discardableResult
    func takeDamage(_ amount: Int) -> Bool {
        guard !isDead else { return true }
        let scaled = vulnerabilityMultiplier == 1.0
            ? amount
            : Int((CGFloat(amount) * vulnerabilityMultiplier).rounded())
        health -= scaled

        refreshHealthBar()

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
            fadeOutHealthBar()
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
