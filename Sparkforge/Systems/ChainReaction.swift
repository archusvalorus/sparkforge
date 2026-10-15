//
//  ChainReaction.swift
//  Sparkforge
//
//  v2.2 Neutral rework, Unit N5 (R6): Chain Reaction's pure rules — the tier
//  ladder, the per-generation amount, the one rounding per victim, and the
//  FIFO burst queue the scene drains once a frame. No scene, no node: the
//  neutral harness compiles this file alone. Numbers live in GameConfig.Neutral.
//  Contracts: docs/v2.2-neutral-n5-checkpoint.md (Q1–Q6, C1–C2, D1–D4).
//

import Foundation
import CoreGraphics

enum ChainReaction {

    // MARK: The ladder (D1)

    /// The flat base for an owned tier (1…3); 0 when not owned.
    static func base(tier: Int) -> Int {
        let bases = GameConfig.Neutral.chainReactionBases
        guard tier >= 1 else { return 0 }
        return bases[min(tier, bases.count) - 1]
    }

    /// The purchased tier's radius (never generation-scaled); 0 when not owned.
    static func radius(tier: Int) -> CGFloat {
        let radii = GameConfig.Neutral.chainReactionRadii
        guard tier >= 1 else { return 0 }
        return radii[min(tier, radii.count) - 1]
    }

    /// The generation multiplier: 1 below the escalation tier; from it,
    /// 1 + step × min(g, cap) — additive on the base, never compounded.
    static func generationBonus(tier: Int, generation: Int) -> CGFloat {
        guard tier >= GameConfig.Neutral.chainEscalationTier else { return 1 }
        let g = min(max(0, generation), GameConfig.Neutral.chainGenerationCap)
        return 1 + GameConfig.Neutral.chainGenerationStep * CGFloat(g)
    }

    /// One victim's EXACT amount (D2): the owned tier's flat `base` × the
    /// generation bonus × (mini-boss ? the boss-class damage scale : 1), each
    /// applied once, before any rounding.
    static func exactDamage(base: Int, tier: Int, generation: Int, bossClass: Bool) -> CGFloat {
        let scale = bossClass ? GameConfig.BossClass.damageScale : 1
        return CGFloat(base) * generationBonus(tier: tier, generation: generation) * scale
    }

    /// The one rounding (D2): chance-rounded with no floor on ONE threshold —
    /// `basis` from the exact amount, `dealt` with the victim's resolved
    /// vulnerability folded in (delivered as a direct hit, so the node does
    /// not apply it again). Zero stays zero.
    static func hit(exact: CGFloat, vulnerability: CGFloat, rounding: DirectHitRounding) -> DirectHit {
        DirectHit(basis: DirectHitRounding.chanceRound(exact, unit: rounding.unit),
                  dealt: DirectHitRounding.chanceRound(exact * vulnerability, unit: rounding.unit))
    }

    /// N5-R1 — the DELIVERED hit (the entry contract, D2a). For a resolved direct
    /// hit EnemyNode reads `basis` for one thing only — Whiteout's melt test
    /// (`snowman.onDamage`) and the elite-melt path that rebuilds the hit around
    /// it; the health it loses is `dealt`. A sub-1 exact amount whose vulnerability
    /// carries it over the threshold resolves to basis 0 / dealt 1, which would
    /// cost health WITHOUT melting. So a positive resolved hit is delivered with a
    /// basis of at least 1. `dealt` — the fractional budget — is untouched, and a
    /// zero hit stays zero (with vulnerability ≥ 1 on one threshold, dealt ≥ basis,
    /// so dealt 0 means basis 0).
    static func entry(_ hit: DirectHit) -> DirectHit {
        hit.dealt > 0 && hit.basis == 0 ? DirectHit(basis: 1, dealt: hit.dealt) : hit
    }

    // MARK: The queue (Q2/Q3)

    struct Burst: Equatable {
        /// Where the emitter died — the burst's centre.
        let origin: CGPoint
        /// 0 for a root; the lethal burst's generation + 1 for a chain victim.
        let generation: Int
        /// The dying body, excluded by identity (never by position).
        let emitter: ObjectIdentifier?
    }

    /// FIFO, iterative: `enqueue` appends; `next` pops the oldest. Drained in
    /// one `while` loop per frame; a burst's children append to the same queue.
    struct Queue {
        private var items: [Burst] = []
        private var head = 0
        var isEmpty: Bool { head >= items.count }
        var count: Int { items.count - head }

        mutating func enqueue(_ burst: Burst) { items.append(burst) }

        mutating func next() -> Burst? {
            guard head < items.count else { return nil }
            let burst = items[head]
            head += 1
            if head == items.count { items.removeAll(keepingCapacity: true); head = 0 }
            return burst
        }

        mutating func reset() { items.removeAll(); head = 0 }
    }
}
