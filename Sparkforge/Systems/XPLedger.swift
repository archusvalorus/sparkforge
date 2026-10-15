//
//  XPLedger.swift
//  Sparkforge
//
//  v2.2 Neutral rework, Unit N2 (R5): the run's XP ledger — pure rules, no
//  scene, no node. PlayerNode owns one and presents it; the scene takes levels
//  from it ONE AT A TIME (the serialized level queue), never here.
//
//  Rules (docs/v2.2-neutral-design-spec.md "XP Boost", N0 §4 R5, Brandon's
//  ruling Oct 11):
//    • A pickup is scaled by the run multiplier (XP Boost, external bonuses);
//      the whole part is credited and the fraction is CARRIED to the next
//      pickup, so +25% / +50% on 1-XP orbs is exact over time and never
//      manufactures XP. Boss Mode's 5×–9× is applied at the orb seam before
//      this ledger, so it is already integral.
//    • XP always accumulates. At the run's level cap it BANKS: no level is
//      taken, the bar reads full, collection effects keep firing. When the
//      cap rises (XP Boost T3), the banked XP levels the player through the
//      same queue.
//    • A granted level (XP Boost T3) keeps the XP as an ABSOLUTE amount; the
//      next threshold is the new level's. The gauntlet opener's grant clears
//      XP (its empty-XP initialization) and says so explicitly.
//

import Foundation
import CoreGraphics

struct XPLedger {
    /// The run level (1-based).
    private(set) var level: Int = 1
    /// Whole XP toward the next level — past the cap, the bank.
    private(set) var xp: Int = 0
    /// The fractional remainder of scaled pickups, in [0, 1).
    private(set) var carry: CGFloat = 0

    /// XP required to reach `level` (the v1 curve, unchanged).
    static func xpRequired(forLevel level: Int) -> Int {
        let base = Double(GameConfig.Leveling.baseXPRequired)
        let factor = GameConfig.Leveling.xpScalingFactor
        return Int(base * pow(factor, Double(level - 2)))
    }

    var requiredForNext: Int { Self.xpRequired(forLevel: level + 1) }

    /// Collect a pickup: scale, credit the whole part, keep the fraction.
    /// Never takes a level and never discards XP (banks at the cap).
    mutating func collect(_ amount: Int, multiplier: CGFloat) {
        guard amount > 0 else { return }
        let scaled = CGFloat(amount) * max(0, multiplier) + carry
        let whole = scaled.rounded(.down)
        carry = scaled - whole
        xp += Int(whole)
    }

    /// An earned level is due when the threshold is met and the cap allows it.
    func isLevelDue(cap: Int) -> Bool { level < cap && xp >= requiredForNext }

    /// Consume ONE due level (the caller presents its screen before asking again).
    @discardableResult
    mutating func takeDueLevel(cap: Int) -> Bool {
        guard isLevelDue(cap: cap) else { return false }
        xp -= requiredForNext
        level += 1
        return true
    }

    /// A granted level: one step up when below the cap. `keepingXP` leaves the
    /// XP (and its carry) exactly as they are — XP Boost's grant; false clears
    /// both — the gauntlet opener's empty-XP initialization.
    @discardableResult
    mutating func grantLevel(cap: Int, keepingXP: Bool) -> Bool {
        guard level < cap else { return false }
        if !keepingXP { xp = 0; carry = 0 }
        level += 1
        return true
    }

    /// Bar fill: full at the cap (the bank is not shown as overflow), else the
    /// fraction of the next threshold, clamped.
    func progress(cap: Int) -> CGFloat {
        if level >= cap { return 1 }
        let required = requiredForNext
        guard required > 0 else { return 0 }
        return min(1, CGFloat(xp) / CGFloat(required))
    }

    mutating func reset() { level = 1; xp = 0; carry = 0 }
}
