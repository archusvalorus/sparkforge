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

    @discardableResult
    func takeDamage(_ amount: Int) -> Bool

    /// Called each frame with the player's position for AI targeting
    func update(deltaTime: TimeInterval, playerPosition: CGPoint)
}

extension BossNode: ArenaBossNode {}
