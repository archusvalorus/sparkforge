// DirectHitDamage.swift
// Sparkforge
//
// v2.1 Abilities A7b S7 (G1.9 94a; CL-94, CL-114, CL-115): the ONE damage
// routine every direct hit calls — gun → enemy, gun → boss, sweep → enemy,
// sweep → boss — pure, proven by tools/damage-pipeline-harness (DH) and wired in
// GameScene's four hit chains (catalog WR13, redsmile MW7/MW8).
//
// CL-114(b): the chain's INTEGER prefix is unchanged — base (A6's rounding
// included), crit and Lucky Break, executes — and ends with Forge offense, moved
// up here. This block then takes the percentage amplifiers that apply to the hit
// as FRACTIONS and rounds ONCE with CL-70's unbiased rule (VoidRounding.damage),
// minimum 1. 94a folds Permafrost, Brittle Cold and Open Wounds' direct arm
// (before A7b each truncated on its own, so a 1-damage hit gained nothing).
// A7b S8 (94b/94c) adds the Overcharge factor (OverchargeSplit, CL-114a) and the
// target's resolved vulnerability (CL-107/116's strongest channel, CL-114b) to
// this same block, rounded ONCE. The hit reaches the target through its DIRECT
// entry, which never applies the vulnerability again (CL-114c); the same block
// without the vulnerability, on the same threshold, is the pre-vulnerability
// basis Overkill and Chain Lightning keep (CL-114d). Braceguard's halving and
// the Boss Mode DEF dial stay AFTER it, unchanged.

import CoreGraphics

/// The percentage amplifiers one direct hit takes (1 = none), built only
/// through the two applicability rules below.
struct DirectHitAmplifiers: Equatable {
    private(set) var permafrost: CGFloat = 1
    private(set) var brittleCold: CGFloat = 1
    private(set) var openWounds: CGFloat = 1

    /// Their product: the block multiplies them as fractions, never rounding between.
    var product: CGFloat { permafrost * brittleCold * openWounds }

    /// An EnemyNode target. Permafrost: any slow source counts, including an
    /// arena-wide slow (Ice Rink / Absolute Zero, Q-C5). Brittle Cold (Polar
    /// Vortex T2): a slowed, frozen or stunned foe. Open Wounds (Bleed ×3): a
    /// bleeding foe (its DoT share rides the ticks instead, CL-25).
    static func onEnemy(permafrostBonus: CGFloat, slowed: Bool, arenaSlowed: Bool,
                        brittleCold: Bool, brittleColdFactor: CGFloat, frozen: Bool, stunned: Bool,
                        openWoundsBonus: CGFloat, bleeding: Bool) -> DirectHitAmplifiers {
        var a = DirectHitAmplifiers()
        if permafrostBonus > 0 && (slowed || arenaSlowed) { a.permafrost = 1 + permafrostBonus }
        if brittleCold && (slowed || frozen || stunned) { a.brittleCold = brittleColdFactor }
        if openWoundsBonus > 0 && bleeding { a.openWounds = 1 + openWoundsBonus }
        return a
    }

    /// An arena boss: Open Wounds only. Bosses are never slowed, frozen or
    /// Brittle-Cold-amplified, so Permafrost and Brittle Cold never apply.
    static func onBoss(openWoundsBonus: CGFloat, bleeding: Bool) -> DirectHitAmplifiers {
        var a = DirectHitAmplifiers()
        if openWoundsBonus > 0 && bleeding { a.openWounds = 1 + openWoundsBonus }
        return a
    }
}

/// CL-114(e): the block's OWN rounding threshold — independent of CL-70's
/// Warp/Riftline one (a projectile's `a6Rounding`), because reusing a spent
/// threshold for a second rounding is biased. A shot draws it at launch; a
/// sweep draws one per target. Injectable for tests.
struct DirectHitRounding: Equatable {
    let unit: CGFloat

    init(unit: CGFloat = CGFloat.random(in: 0..<1)) {
        self.unit = unit
    }

    /// Chance-rounding WITHOUT a floor (v2.2 N3): `exact` resolves to ⌊exact⌋
    /// or ⌊exact⌋ + 1 with probability (exact − ⌊exact⌋) for the latter, so the
    /// expectation is exactly `exact` and 0 stays 0. CL-70's `VoidRounding.damage`
    /// keeps its minimum of 1 for the whole-shot paths it serves.
    static func chanceRound(_ exact: CGFloat, unit: CGFloat) -> Int {
        guard exact > 0 else { return 0 }
        let whole = exact.rounded(.down)
        return Int(whole) + (unit < exact - whole ? 1 : 0)
    }
}

/// A7b S8 (CL-114a): Overcharge split out of a shot's integer base. `multiplier`
/// is today's whole shot multiplier (Overcharge included), `overchargeFree` the
/// same without Overcharge, `overcharge` the Overcharge share (O·s). The hit
/// chain floors the Overcharge-free part (`base`), and Overcharge rides the
/// block as `factor`, which brings that base to max(today's floor, ⌊B·s⌋ + O·s):
/// a 1-damage hit gains its +5…+50% by chance, and no base ever pays less than
/// today's floor (Iron Skin / Everglow builds crossing an integer included).
struct OverchargeSplit: Equatable {
    let multiplier: CGFloat
    let overchargeFree: CGFloat
    let overcharge: CGFloat

    init(multiplier: CGFloat, overchargeFree: CGFloat, overcharge: CGFloat) {
        self.multiplier = multiplier
        self.overchargeFree = overchargeFree
        self.overcharge = overcharge
    }

    /// From PlayerStats.overchargeParts(scale:).
    init(_ parts: (multiplier: CGFloat, overchargeFree: CGFloat, overcharge: CGFloat)) {
        self.init(multiplier: parts.multiplier, overchargeFree: parts.overchargeFree, overcharge: parts.overcharge)
    }

    /// Today's integer base, Overcharge included (the floor never paid below).
    var todayFloor: Int { max(1, Int(multiplier)) }
    /// The integer base the hit chain starts from: Overcharge-free, minimum 1.
    var base: Int { max(1, Int(overchargeFree)) }
    /// Overcharge's block factor (≥ 1; exactly 1 with no Overcharge).
    var factor: CGFloat {
        var f = max(CGFloat(todayFloor), CGFloat(Int(overchargeFree)) + overcharge) / CGFloat(base)
        // Exact, not approximate: base × factor never falls a hair under today's
        // floor (a quotient like (n + 1) / n can lose an ulp).
        while CGFloat(base) * f < CGFloat(todayFloor) { f = f.nextUp }
        return f
    }
}

/// One direct hit out of the block: `dealt` reaches the target's direct entry
/// (its resolved vulnerability already folded in); `basis` is the same block
/// without the vulnerability — the pre-vulnerability basis (CL-114d).
struct DirectHit: Equatable {
    private(set) var basis: Int
    private(set) var dealt: Int

    init(basis: Int, dealt: Int) {
        self.basis = basis
        self.dealt = dealt
    }

    /// The Braceguard's directional halving — after the block, on both values.
    /// A positive hit keeps its floor of 1 (legacy); a zero hit stays zero
    /// (v2.2 N3 corrective: a Fracture share that resolved to 0 is never
    /// resurrected by the shield).
    mutating func shield(by multiplier: CGFloat) {
        basis = basis == 0 ? 0 : max(1, Int(CGFloat(basis) * multiplier))
        dealt = dealt == 0 ? 0 : max(1, Int(CGFloat(dealt) * multiplier))
    }

    /// v2.2 N3 corrective (R1/R2): a Fracture branch's share of its PARENT's
    /// fully processed hit — the last step of the chain, so every integer
    /// floor above (the crit's 2, the block's and shield's 1, the DEF dial's 1)
    /// belongs to the parent and is divided with it. Both values are
    /// chance-rounded on the share's own threshold with NO floor:
    /// expectation = parent × share exactly; a sub-1 share is 0 or 1, never a
    /// free 1. `share == 1` is a whole shot and changes nothing.
    mutating func scale(by share: CGFloat, rounding: DirectHitRounding) {
        guard share < 1 else { return }
        basis = DirectHitRounding.chanceRound(CGFloat(basis) * share, unit: rounding.unit)
        dealt = DirectHitRounding.chanceRound(CGFloat(dealt) * share, unit: rounding.unit)
    }

    /// v2.2 Whiteout × Fracture / beam (Oct 14, contract W1): the hit as DELIVERED
    /// at the final enemy entry. A resolved hit's `basis` is read there only by
    /// Whiteout's melt test (and the elite-melt rebuild); the health lost is
    /// `dealt`. A Fracture share or a sub-1 beam prefix can resolve to basis 0 /
    /// positive dealt, which would cost health WITHOUT melting — so such a hit is
    /// delivered with basis 1. `dealt` is unchanged; any other hit (a true zero
    /// included) is delivered as is. Used ONLY at the gun handler's and the beam
    /// copy's final `takeDirectHit` — never earlier, so riders keep the original basis.
    var targetEntry: DirectHit {
        dealt > 0 && basis == 0 ? DirectHit(basis: 1, dealt: dealt) : self
    }
}

enum DirectHitDamage {
    /// The block: `prefix` (the integer steps, Forge offense included) times the
    /// amplifiers and Overcharge's factor — and, for `dealt`, the target's resolved
    /// vulnerability — rounded ONCE each on the hit's own threshold, unbiased,
    /// minimum 1. With every factor 1 both return the prefix exactly.
    static func resolve(_ prefix: Int, _ amplifiers: DirectHitAmplifiers, overcharge: CGFloat,
                        vulnerability: CGFloat, rounding: DirectHitRounding) -> DirectHit {
        let exact = CGFloat(prefix) * amplifiers.product * overcharge
        return DirectHit(basis: VoidRounding.damage(exact, unit: rounding.unit),
                         dealt: VoidRounding.damage(exact * vulnerability, unit: rounding.unit))
    }

    /// v2.2 N4: the block for an EXACT (fractional) prefix — the chaos beam's
    /// lane-tick hits. `extra` folds in a further exact factor (the Braceguard
    /// shield on the beam). Rounded ONCE each, unbiased, on the hit's own
    /// threshold, with NO floor: the expectation is the exact product and a
    /// zero stays zero (`DirectHitRounding.chanceRound`). Whole shots keep
    /// `resolve(_:…)` and its legacy minimum of 1.
    static func resolveExact(_ prefix: CGFloat, _ amplifiers: DirectHitAmplifiers, overcharge: CGFloat,
                             vulnerability: CGFloat, extra: CGFloat, rounding: DirectHitRounding) -> DirectHit {
        let exact = prefix * amplifiers.product * overcharge * extra
        return DirectHit(basis: DirectHitRounding.chanceRound(exact, unit: rounding.unit),
                         dealt: DirectHitRounding.chanceRound(exact * vulnerability, unit: rounding.unit))
    }

    /// S7's form (no Overcharge, no vulnerability): the same block, one value.
    static func resolve(_ prefix: Int, _ amplifiers: DirectHitAmplifiers, rounding: DirectHitRounding) -> Int {
        resolve(prefix, amplifiers, overcharge: 1, vulnerability: 1, rounding: rounding).dealt
    }
}
