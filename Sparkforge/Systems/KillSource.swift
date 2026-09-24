// KillSource.swift
// Sparkforge
//
// v2.1 Abilities A0: what landed a killing blow. Every enemy death routes
// through GameScene.onEnemyKilled with one of these, so a kill is credited
// exactly once and on-kill effects can tell a Spark shot from a burst, a DoT
// tick, a chain hop or (A6) a returned projectile — without each card
// re-deriving it from call sites.

import Foundation

enum KillSource: String, CaseIterable {
    /// Spark's own projectiles that carry modifiers.
    case primary
    /// Shards, fragments, echoes and seed bursts (fired without modifiers).
    case fragment
    /// Burn / Bleed / other damage-over-time ticks.
    case statusTick
    /// Chain lightning hops and Relay Burn arcs.
    case chain
    /// Capstone strikes, beams, wells and Erasure effects.
    case capstone
    /// Companions: pandas, woodland animals, bats, the samurai, flowers.
    case summon
    /// Iron Bloom, Thornwall, Iron Maiden thorns and retaliation.
    case retaliation
    /// Zones and clouds: cultivated ground, poison clouds.
    case ground
    /// Radius AoE — on-kill bursts, pulses, explosions.
    case burst
    /// The frame-top prune of an enemy that died without being credited.
    case sweep
    /// v2.1 A4c: Red Smile's melee sweep — a primary ATTACK (each body struck
    /// takes a primary hit), full credit. Named `melee` because `sweep` above
    /// is the reward-only prune, not an attack.
    case melee

    /// Credit tier — legacy-preserving. Radius bursts and the sweep have only
    /// ever paid the XP orb: no kill count, bestiary, arena gates or on-kill
    /// cascade (the reason a burst can't chain into another burst). Every other
    /// source is a full kill.
    var credit: KillCredit {
        switch self {
        case .burst, .sweep: return .rewardOnly
        default: return .full
        }
    }
}

enum KillCredit: Equatable {
    /// XP, kill count, progression, bestiary, on-kill effects.
    case full
    /// XP orb only.
    case rewardOnly
}
