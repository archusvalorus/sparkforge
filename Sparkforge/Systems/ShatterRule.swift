// ShatterRule.swift
// Sparkforge
//
// v2.1 Abilities A7b S10 (G1.11; CL-99, CL-118): Shatter (Chill ×5), one pure
// rule for the gun's enemy hit and the Red Smile sweep, executed by
// tools/chill-harness (SR checks).
//
// A struck non-boss enemy whose total slow (its own + the arena's) reaches the
// threshold has the Shatter chance to shatter. The chance and threshold are
// unchanged. A normal enemy dies outright, as before; an elite (a mini-boss,
// CL-73) now takes the elite chunk instead — 20% of max HP through the Anomaly
// helper, the Glacial Spikes / Whiteout melt convention — and the vulnerability
// scales it like any plain hit. A shatter that kills ends the hit; an elite that
// survives its chunk takes the rest of the hit (CL-118a). No rate limit (CL-118b).

import CoreGraphics

enum ShatterRule {
    enum Outcome: Equatable {
        /// A normal enemy: dies outright (today's early exit).
        case execute
        /// An elite: takes this chunk; the hit goes on if it survives.
        case chunk(Int)
    }

    /// The shatter this hit lands, or nil. `roll` is drawn in 0...1.
    static func outcome(chance: CGFloat, threshold: CGFloat, slowed: Bool, totalSlow: CGFloat,
                        elite: Bool, maxHealth: Int, roll: CGFloat) -> Outcome? {
        guard chance > 0, slowed, totalSlow >= threshold, roll < chance else { return nil }
        guard elite else { return .execute }
        return .chunk(AnomalyState.chunkDamage(maxHealth: maxHealth,
                                               fraction: GameConfig.Chill.shatterEliteFraction))
    }
}

extension ShatterRule.Outcome {
    /// What the shatter deals: a normal enemy's whole remaining health, or the chunk.
    func damage(health: Int) -> Int {
        switch self {
        case .execute: return health
        case .chunk(let amount): return amount
        }
    }

    /// Whether the hit ends here even if the target lives: an execute always
    /// ends it (today's exit); a chunk ends it only by killing.
    var endsHit: Bool { self == .execute }
}
