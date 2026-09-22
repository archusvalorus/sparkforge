// KillContext.swift
// Sparkforge
//
// v2.1 Abilities A4b: everything a kill's rewards need, snapshotted at the
// killing blow — BEFORE any reward resolves (Lyra's packet correction 4).
// Enemy kills and arena-boss kills both resolve through one reward path
// (GameScene.resolveKillRewards / resolveDeathBursts) from one of these.
// Pure value types, proven by tools/bleed-harness.
//
// Rules (Brandon, Sep 21–22):
//   • "Killed a bleeding enemy" = the target was ALREADY bleeding when the
//     killing damage began. A killing hit never counts its own Bleed.
//   • Glass Blood is stricter: a Bleed TICK must deliver the kill, and only a
//     generation 0 or 1 Bleed bursts (CL-28's two-hop limit per lineage).
//   • A DoT death is judged from the state as its step BEGAN — the final
//     Bleed tick can land on the instant the Bleed ends.

import CoreGraphics
import Foundation

struct KillContext: Equatable {
    /// Where the target died — every death burst resolves here, once.
    let position: CGPoint
    /// Bleeding before the killing damage (Frenzy, Bloodlust, Red Harvest, Open Vein).
    let diedBleeding: Bool
    /// A Bleed tick dealt the killing blow (Glass Blood).
    let killedByBleed: Bool
    /// The lineage of the Bleed the target carried (Glass Blood's hop limit).
    let bleedGeneration: Int
    /// The killing blow's damage to REMAINING health — no overkill (Sanguinarian).
    let finishingDamage: Int
    /// An arena boss (no kill count, no bat growth — CL-29).
    let isBoss: Bool

    /// Does this death burst into Glass Blood fragments? (CL-27/28)
    func burstsGlassBlood(maxGeneration: Int) -> Bool {
        killedByBleed && bleedGeneration < maxGeneration
    }

    /// The DoT payout that was in flight when a boss took its killing damage.
    /// Published BEFORE each DoT `takeDamage`, because the Unmade Star dies
    /// (and clears the boss slot and its status) inside that very call.
    struct DoTHit: Equatable {
        let channel: StatusDoTs.Channel
        /// Was the boss bleeding as this DoT step began?
        let wasBleeding: Bool
        /// Its Bleed's generation as the step began.
        let generation: Int
    }

    /// The boss's context at its lethal hit. `dot` is the payout in flight (nil
    /// for any other killing blow); `liveBleeding` / `liveGeneration` are the
    /// boss's Bleed right now — which, for a non-DoT kill, IS "before the
    /// killing damage": every Bleed source lands only on a survivor.
    static func boss(at position: CGPoint, finishingDamage: Int, dot: DoTHit?,
                     liveBleeding: Bool, liveGeneration: Int) -> KillContext {
        KillContext(position: position,
                    diedBleeding: dot?.wasBleeding ?? liveBleeding,
                    killedByBleed: dot?.channel == .bleed,
                    bleedGeneration: dot?.generation ?? liveGeneration,
                    finishingDamage: max(0, finishingDamage),
                    isBoss: true)
    }
}

/// Credits an arena boss's kill exactly once. Armed with the boss in the slot
/// (every slot change re-arms it); a claim succeeds only for THAT boss, once.
/// The boss is marked credited BEFORE any reward resolves, so a nested effect
/// can't re-enter, and when the Unmade Star clears the slot mid-resolution the
/// re-arm to nil can't reopen its credit.
struct BossKillLatch {
    private(set) var armedID: ObjectIdentifier?
    private(set) var credited = false

    mutating func arm(_ id: ObjectIdentifier?) {
        armedID = id
        credited = false
    }

    /// True exactly once, for the armed boss.
    mutating func claim(_ id: ObjectIdentifier) -> Bool {
        guard id == armedID, !credited else { return false }
        credited = true
        return true
    }
}
