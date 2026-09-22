// ArenaBossNode.swift
// Sparkforge
//
// v1.6: Common surface for arena bosses so GameScene can host any of
// them through one reference. BossNode (Slag Titan) already satisfies
// every requirement, so its conformance is a one-liner — the validated
// Titan code stays untouched. A shared base class can wait until the
// third boss (Arena 3) proves what's truly common.

import SpriteKit

protocol ArenaBossNode: SKNode {
    var health: Int { get }
    var isDead: Bool { get }
    var healthPercent: CGFloat { get }
    /// Damage dealt to the player on body contact
    var contactDamage: Int { get }
    /// v1.9: general vulnerability — scales incoming damage (1.0 = none). The
    /// boss-side twin of EnemyNode.vulnerabilityMultiplier, so capstone debuffs
    /// (Skybeam Called, later Apex/Polar Vortex) can mark boss-class targets.
    var vulnerabilityMultiplier: CGFloat { get set }

    /// v2.0 (B3): Boss Mode DEF dial — a flat reduction subtracted from each
    /// incoming hit (the boss-side mirror of the player's DEF). 0 outside Boss
    /// Mode. Set once at spawn by the scene; execute effects bypass it (see the
    /// bosses' takeDamage), so an instant-kill stays an instant-kill.
    var challengeFlatReduction: Int { get set }

    /// v2.0: how far the boss's BODY extends from its origin. Range checks must
    /// measure to the surface, not the centre — a monument boss is so large that
    /// a player standing against it is still "far" from its origin, which
    /// silently broke auto-aim. Normal bosses default to 0 (centre == surface).
    var targetingRadius: CGFloat { get }

    /// v2.0 (B3): Boss Mode's HP dial. Scales max health at SPAWN, before the
    /// fight starts — never mid-fight, which would make the health bar lie.
    /// A no-op outside Boss Mode.
    func applyChallengeHealthScale(_ factor: CGFloat)

    @discardableResult
    func takeDamage(_ amount: Int) -> Bool

    /// v2.1 A4a: the one damage entry every conformer implements. `takeDamage(_:)`
    /// forwards here with `false`. Burn and Bleed ticks pass `true` — CL-18
    /// (Brandon, Sep 21): DoTs ignore the Boss Mode DEF dial's flat per-hit
    /// reduction (vulnerability and the HP dial still apply).
    @discardableResult
    func takeDamage(_ amount: Int, ignoresChallengeDEF: Bool) -> Bool

    /// v2.1 A4b: the boss-kill chokepoint. Every boss calls this exactly once,
    /// synchronously, on its killing blow — after `isDead` is set, before any
    /// death animation or `onDeath` — with the damage that blow dealt to
    /// REMAINING health. The scene credits the kill here (Siphon, Frenzy,
    /// Bloodlust, Sanguinarian, death bursts…), never from `takeDamage`'s
    /// return value (a dead Unmade Star still returns true).
    var onLethalHit: ((Int) -> Void)? { get set }

    /// v2.1 A4a: where the scene pins the Burn/Bleed status row, in the boss's
    /// own coordinates — beside the HP bar, so every boss reads the same way.
    var statusTellAnchor: CGPoint { get }
    /// Size of the status row (a monument's sits at monument scale).
    var statusTellScale: CGFloat { get }

    /// Called each frame with the player's position for AI targeting
    func update(deltaTime: TimeInterval, playerPosition: CGPoint)

    /// v2.1 (Geometry 1A): the radius this boss occupies for ARENA GEOMETRY —
    /// route clearance and resolution against blocked footprints. Deliberately
    /// separate from `targetingRadius` and the contact body (reconciliation
    /// §7.2: routing must never rebalance damage contacts). 0 = exempt (a
    /// monument IS geometry; it never resolves against other geometry).
    var geometryFootprintRadius: CGFloat { get }
}

/// Default: a normal-scale boss's centre is effectively its surface.
extension ArenaBossNode {
    var targetingRadius: CGFloat { 0 }
    /// Default: mobile arena bosses are ground-bound and take a body-sized
    /// footprint; monuments override to 0.
    var geometryFootprintRadius: CGFloat { max(targetingRadius, 30) }

    /// Default: bosses that predate the dials simply ignore them, so adding a
    /// boss never *requires* dial support to compile.
    func applyChallengeHealthScale(_ factor: CGFloat) {}

    /// Every ordinary hit: the DEF dial applies.
    @discardableResult
    func takeDamage(_ amount: Int) -> Bool {
        takeDamage(amount, ignoresChallengeDEF: false)
    }

    /// Default: just above the body; each boss overrides to sit beside its bar.
    var statusTellAnchor: CGPoint { CGPoint(x: 0, y: 60) }
    var statusTellScale: CGFloat { 1.0 }

    /// The health a hit should actually remove, after the DEF dial's flat
    /// reduction. Shared so all five bosses reduce identically.
    ///
    /// `scaled` is the post-vulnerability damage; `raw` is the original request.
    /// A hit whose RAW amount already meets current health is an execute
    /// (Erasure's delete, a scripted kill) and bypasses reduction entirely —
    /// blunting those would silently break capstone finishers. Reduced hits
    /// never fall below 1, so a dialled-up boss still takes chip damage.
    func challengedDamage(_ scaled: Int, raw: Int, ignoresChallengeDEF: Bool = false) -> Int {
        guard challengeFlatReduction > 0, !ignoresChallengeDEF else { return scaled }
        if raw >= health { return scaled }          // execute — always lands full
        return max(1, scaled - challengeFlatReduction)
    }
}

extension BossNode: ArenaBossNode {}
