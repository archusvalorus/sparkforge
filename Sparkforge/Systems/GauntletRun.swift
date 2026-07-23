// GauntletRun.swift
// Sparkforge
//
// v2.0 (Unit B2a) — the Boss Mode GAUNTLET: the run-state object behind
// "one button → bosses back-to-back until you clear them all or die."
//
// Boss Mode is NOT a practice selector. The roster view stays as a liked
// secondary layer, but the mode itself is a single uninterrupted run:
//   • every boss fights in its OWN home arena (monuments are unreadable
//     anywhere else) — so the gauntlet swaps arenas between stages
//   • no adds — normal play already spawns nothing while a boss lives
//   • death = run over. No ads, no revives. It's pure boss mode.
//
// This type owns ONLY the ordering and the per-stage numbers. Everything
// scene-side (arena teardown/rebuild, boss handoff, interstitials) lives in
// GameScene, and all tuning lives in GameConfig.BossMode.

import CoreGraphics

@MainActor
final class GauntletRun {

    enum Order {
        /// The order the player met them (by arena).
        case sequential
        /// Random draw, capped. (Wired in B2b.)
        case mixup(count: Int)
    }

    /// The bosses this run will face, in the order it will face them.
    let lineup: [BossEntry]

    /// How this run was ordered, kept so a retry rebuilds the SAME mode. A
    /// mixup retry re-shuffles — a fresh random order is the point of mixup —
    /// but it never silently drops you back into sequential.
    let order: Order

    /// 0-based index into `lineup`. `stage` (1-based) is what the design speaks in.
    private(set) var index: Int = 0

    /// True once the last boss in the lineup has fallen.
    private(set) var isComplete: Bool = false

    /// How many bosses have actually been felled this run — the run-summary number.
    private(set) var bossesFelled: Int = 0

    init?(order: Order) {
        self.order = order
        let registry = BossRegistry.shared
        switch order {
        case .sequential:
            lineup = registry.sequential
        case .mixup(let count):
            lineup = registry.mixup(count: count)
        }
        // A gauntlet with nothing in it isn't a run.
        guard !lineup.isEmpty else { return nil }

        #if DEBUG
        // Dev-only: open partway in so a late fight can be reached directly.
        // Stages skipped this way are never counted as felled — a forced run's
        // summary must not claim kills that never happened.
        let start = GameConfig.BossMode.debugStartStage
        if start > 1 { index = min(start, lineup.count) - 1 }
        #endif
    }

    // MARK: - Stage queries

    /// 1-based stage number, which is what every tuning rule is written against.
    var stage: Int { index + 1 }

    var totalStages: Int { lineup.count }

    /// The boss currently being fought, or nil once the gauntlet is complete.
    var currentEntry: BossEntry? {
        guard !isComplete, index < lineup.count else { return nil }
        return lineup[index]
    }

    var isFinalStage: Bool { index == lineup.count - 1 }

    // MARK: - Difficulty

    /// The fractional difficulty bump for the CURRENT stage.
    ///
    /// Arena bosses ramp with the stage; monuments are decoupled and flat. The
    /// ramp deliberately does not compound — each buff applies to that boss's
    /// own base, so a late monument doesn't become a cliff.
    var currentRampFraction: Double {
        guard let entry = currentEntry else { return 0 }
        switch entry.grammar {
        case .monument:
            return GameConfig.BossMode.monumentFlatRamp
        case .arena:
            return GameConfig.BossMode.arenaRampPerStage * Double(stage)
        }
    }

    /// The ramp expressed in the same currency normal play uses for boss HP
    /// (`Int(elapsed / 30) * step`), so bosses take their existing `hpScaling`
    /// initializer unchanged.
    var currentHPScaling: Int {
        Int((currentRampFraction * GameConfig.BossMode.hpScalingBudget).rounded())
    }

    /// Stage 1 = 5×, stage 2 = 6×, … — you level as you go.
    var currentXPMultiplier: Double {
        GameConfig.BossMode.baseXPMultiplier
            + GameConfig.BossMode.xpMultiplierPerStage * Double(index)
    }

    // MARK: - Progression

    /// Advance past the boss that just fell. Returns the next entry, or nil when
    /// the gauntlet has been cleared.
    @discardableResult
    func advance() -> BossEntry? {
        guard !isComplete else { return nil }
        bossesFelled += 1
        if index >= lineup.count - 1 {
            isComplete = true
            return nil
        }
        index += 1
        return lineup[index]
    }
}
