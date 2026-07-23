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

    /// Called each frame with the player's position for AI targeting
    func update(deltaTime: TimeInterval, playerPosition: CGPoint)
}

/// Default: a normal-scale boss's centre is effectively its surface.
extension ArenaBossNode {
    var targetingRadius: CGFloat { 0 }

    /// Default: bosses that predate the dials simply ignore them, so adding a
    /// boss never *requires* dial support to compile.
    func applyChallengeHealthScale(_ factor: CGFloat) {}

    /// The health a hit should actually remove, after the DEF dial's flat
    /// reduction. Shared so all five bosses reduce identically.
    ///
    /// `scaled` is the post-vulnerability damage; `raw` is the original request.
    /// A hit whose RAW amount already meets current health is an execute
    /// (Erasure's delete, a scripted kill) and bypasses reduction entirely —
    /// blunting those would silently break capstone finishers. Reduced hits
    /// never fall below 1, so a dialled-up boss still takes chip damage.
    func challengedDamage(_ scaled: Int, raw: Int) -> Int {
        guard challengeFlatReduction > 0 else { return scaled }
        if raw >= health { return scaled }          // execute — always lands full
        return max(1, scaled - challengeFlatReduction)
    }
}

extension BossNode: ArenaBossNode {}
