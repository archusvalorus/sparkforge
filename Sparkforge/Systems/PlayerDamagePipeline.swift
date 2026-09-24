// PlayerDamagePipeline.swift
// Sparkforge
//
// v2.1 Abilities A0: the ONE resolver for damage Spark takes (closure table
// CL-5 §D). Pure value math, no scene and no nodes, so the ordering is proven
// by the deterministic harness (tools/damage-pipeline-harness) instead of by
// feel. GameScene gathers the inputs, calls `resolve`, then owns cooldowns,
// FX and the reactive events; PlayerStats commits the numbers.
//
// Order:
//   1. input scaling       Boss Mode ATK dial (boss-class sources, gauntlet)
//   2. percentage layer    Unyielding × Forge Path bucket (additive inside,
//                          capped, ONE factor) × Ironhide × Aegis × kaiju —
//                          multiplicative, global ceiling
//   3. flat DEF            floor of 1 damage
//   4. Blood Barrier       absorbs before health
//   5. health              lethal is computed, then Brace, then Unbroken Core,
//                          THEN survival or death is final
// Explicit invulnerability (i-frames, Phase Skin, Silver Skin) is not here:
// those contacts are ignored before step 1.
//
// Legacy parity: the % layer multiplies in the same order, with the same float
// operations, as the v1.9–v2.0 `applyPlayerDamage`, so every hit the ceiling
// doesn't clamp resolves to exactly the pre-A0 number. The harness checks it.

import CoreGraphics
import Foundation

enum PlayerDamagePipeline {

    /// Tuning the resolver reads — built from GameConfig by the scene.
    struct Tuning {
        /// Global cap on the whole percentage layer (Brandon: 0.90).
        var reductionCeiling: CGFloat
        /// Forge Path DR bucket cap (`ForgePath.drCap`) — the bucket stays
        /// additive inside and counts as one factor.
        var forgeBucketCap: CGFloat
        /// Unyielding qualifies on a hit larger than this × max HP.
        var unyieldingThreshold: CGFloat
        /// Fraction of a qualifying hit Unyielding lets through
        /// (`ForgePath.unyieldingReduction`, used as a multiplier since v1.9).
        var unyieldingMultiplier: CGFloat
        /// Kaiju damage reduction — inside the ceiling (CL-5 ruling, Sep 15).
        var kaijuReduction: CGFloat
        /// Blood Barrier pool cap as a fraction of max HP (Q-B3).
        var barrierCapFraction: CGFloat
        /// Blood Barrier expires this long after the last positive gain (Q-B3).
        var barrierExpiry: TimeInterval
    }

    /// One incoming hit, as the scene sees it before any mitigation.
    struct Hit {
        /// The enemy's hit, before anything. Unyielding's threshold reads THIS
        /// (pre-dial), exactly as it has since v1.9.
        var raw: Int
        /// Boss Mode ATK dial for boss-class sources in the gauntlet; 1 otherwise.
        var inputScale: CGFloat = 1
        /// Σ active Forge Path DR sources this hit (uncapped — capped here).
        var forgeBucket: CGFloat = 0
        /// Unyielding owned AND off cooldown.
        var unyieldingReady = false
        /// Ironhide % (v2.1 A5, CL-52): 9% per qualifying nearby hostile, ≤ 0.90.
        var ironhide: CGFloat = 0
        /// Aegis shield % (v2.1 A5, CL-58): 0 / 0.25 / 0.25 / 0.35 by tier.
        var aegis: CGFloat = 0
        var kaijuActive = false
        /// DEF plus every temporary/conditional flat DEF source.
        var flatDEF: Int = 0
    }

    /// The player's state the hit lands on.
    struct Defender {
        var currentHP: Int
        var maxHP: Int
        var barrier: Int = 0
        /// Brace (guard_1) has a save left.
        var braceAvailable = false
        /// Unbroken Core's once-per-run rescue is armed (Guard ×7, v2.1 A5).
        var unbrokenAvailable = false
    }

    enum Rescue: Equatable { case none, brace, unbrokenCore }

    struct Outcome {
        /// The hit after the % layer, before flat DEF (floor 1) — what the
        /// hit flash scales by.
        let percentDamage: Int
        /// Damage after the % layer and flat DEF — what the hit is worth.
        let damage: Int
        /// Eaten by Blood Barrier.
        let absorbed: Int
        /// Reached health.
        let toHP: Int
        let hpAfter: Int
        let barrierAfter: Int
        /// True when health damage would have killed, before any rescue. A
        /// barrier-only hit is never lethal.
        let wasLethal: Bool
        let rescue: Rescue
        let died: Bool
        /// Unyielding halved this hit — the scene starts its cooldown.
        let unyieldingFired: Bool
        /// Effective percentage layer, 0…ceiling (validators and debug).
        let reduction: CGFloat
        /// The ceiling clamped this hit.
        let ceilingApplied: Bool

        /// Every resolved hit is a HIT for the reactive effects (Overcharge
        /// reset, Defiant, the undamaged clocks) — barrier-only hits included.
        var isHit: Bool { damage > 0 }
        /// Fully absorbed by Blood Barrier: a hit, but nothing reached health.
        var barrierOnly: Bool { damage > 0 && toHP == 0 }
    }

    /// Which rescue a lethal result spends: Brace first, then Unbroken Core,
    /// never both on one lethal event (Q-G1). The ONE ordering rule — v2.1 A5
    /// (CL-54): Unstable Core's self-damage, which doesn't resolve through
    /// the pipeline, asks this too.
    static func lethalRescue(for defender: Defender) -> Rescue {
        if defender.braceAvailable { return .brace }
        if defender.unbrokenAvailable { return .unbrokenCore }
        return .none
    }

    static func resolve(_ hit: Hit, against defender: Defender, tuning: Tuning) -> Outcome {
        // 1. Input scaling — stays outside the player's mitigation.
        let scaled = CGFloat(hit.raw) * hit.inputScale

        // 2. Percentage layer, in the legacy multiplication order.
        let unyieldingFired = hit.unyieldingReady
            && CGFloat(hit.raw) > CGFloat(defender.maxHP) * tuning.unyieldingThreshold
        var dmg = scaled
        if unyieldingFired { dmg *= tuning.unyieldingMultiplier }
        let bucket = min(hit.forgeBucket, tuning.forgeBucketCap)
        if bucket > 0 { dmg *= (1 - bucket) }
        if hit.ironhide > 0 { dmg *= (1 - hit.ironhide) }
        if hit.aegis > 0 { dmg *= (1 - hit.aegis) }
        if hit.kaijuActive { dmg *= (1 - tuning.kaijuReduction) }

        let ceilingFloor = scaled * (1 - tuning.reductionCeiling)
        let ceilingApplied = scaled > 0 && dmg < ceilingFloor
        // Snap a clamped hit to micro-units so float noise can't truncate the
        // ceiling's own number (100 × (1 − 0.9) is 9.999…, not 10). New path —
        // unclamped hits keep the legacy float math untouched.
        if ceilingApplied { dmg = (ceilingFloor * 1_000_000).rounded() / 1_000_000 }
        let reduction: CGFloat = scaled > 0 ? 1 - dmg / scaled : 0

        // 3. Flat DEF with its floor of 1 (legacy truncation, then subtraction).
        let percentDamage = max(1, Int(dmg))
        let damage = max(1, percentDamage - hit.flatDEF)

        // 4. Blood Barrier before health.
        let barrier = max(0, defender.barrier)
        let absorbed = min(barrier, damage)
        let toHP = damage - absorbed

        // 5. Health — compute lethal, rescue, THEN finalize.
        var hp = defender.currentHP - toHP
        let wasLethal = toHP > 0 && hp <= 0
        var rescue = Rescue.none
        if wasLethal {
            rescue = lethalRescue(for: defender)
            if rescue != .none { hp = 1 }
        }
        let died = wasLethal && rescue == .none
        if hp < 0 { hp = 0 }

        return Outcome(percentDamage: percentDamage, damage: damage,
                       absorbed: absorbed, toHP: toHP,
                       hpAfter: hp, barrierAfter: barrier - absorbed,
                       wasLethal: wasLethal, rescue: rescue, died: died,
                       unyieldingFired: unyieldingFired,
                       reduction: reduction, ceilingApplied: ceilingApplied)
    }
}

// MARK: - Blood Barrier

/// A pre-health shield pool (Q-B3): capped at a fraction of max HP; every
/// positive grant refreshes its expiry; spending it does not. The expiry runs
/// on game time — tick it from the scene's update, never from an SKAction.
struct BloodBarrier {
    private(set) var amount: Int = 0
    private(set) var expiry = GameTimer()

    /// Grant barrier. Any positive grant refreshes the expiry, including one
    /// that lands on a full pool (a capped barrier stays up while you keep
    /// earning it). Returns the amount actually added.
    @discardableResult
    mutating func gain(_ value: Int, maxHP: Int, tuning: PlayerDamagePipeline.Tuning) -> Int {
        guard value > 0 else { return 0 }
        let cap = max(0, Int(CGFloat(maxHP) * tuning.barrierCapFraction))
        // v2.1 A4b: a pool left above a LOWERED cap (Glass Engine, Mass Tax)
        // trims to it on the next grant — refreshing never keeps it over cap.
        amount = min(amount, cap)
        let before = amount
        amount = min(amount + value, cap)
        expiry.start(tuning.barrierExpiry)
        return amount - before
    }

    /// v2.1 A4b (independent review, finding 1): reconcile the pool when MAX HP
    /// FALLS (Glass Engine, Mass Tax) and leaves it above its newly valid cap.
    /// This is state reconciliation, NOT a grant: it never starts, extends or
    /// refreshes the expiry, and it never raises the amount.
    mutating func clampToCap(maxHP: Int, capFraction: CGFloat) {
        let cap = max(0, Int(CGFloat(maxHP) * capFraction))
        if amount > cap { amount = cap }
    }

    /// Remove what a hit absorbed.
    mutating func spend(_ absorbed: Int) {
        guard absorbed > 0 else { return }
        amount = max(0, amount - absorbed)
    }

    /// Game-time tick. The pool empties when the expiry runs out.
    mutating func tick(_ dt: TimeInterval) {
        guard amount > 0 else { return }
        if expiry.tick(dt) { amount = 0 }
    }

    mutating func clear() {
        amount = 0
        expiry.cancel()
    }
}
