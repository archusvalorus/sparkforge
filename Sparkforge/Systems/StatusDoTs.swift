// StatusDoTs.swift
// Sparkforge
//
// v2.1 Abilities A4a: one target's damage-over-time — Burn (BurnState) and
// Bleed (BleedState) as two SEPARATE channels. EnemyNode owns one; the scene
// owns one for the arena boss (bosses take DoTs from A4a on). Pure value type
// on game time, proven by tools/bleed-harness.
//
// Why two channels: Burn and Bleed used to sum into one accumulator and one
// `takeDamage`, so a DoT death could never say what killed it. Each channel now
// pays out on its own, so the host can report "killed by Bleed" (Glass Blood's
// strict rule, A4) and count each separately.
//
// Boss-class (CL-17, Brandon Sep 21): arena bosses AND mini-bosses take Burn
// and Bleed at `scale` (0.5) — Kindle's Burn, not the flat tesla field that
// rides the burn channel. It is applied to the FRACTIONAL damage before
// anything rounds — `BossClass.scaledDamage` can't halve a 1-point tick (1
// stays 1), and the Bleed tick is exactly 1 at base ATK. Remainders carry, so
// over a fight a boss takes a true half.

import CoreGraphics
import Foundation

struct StatusDoTs {

    /// Which channel a DoT payout (or a DoT death) came from.
    enum Channel: String {
        case burn
        case bleed
    }

    var burn = BurnState()
    var bleed = BleedState()
    /// Fractional damage owed by each channel, carried between payouts.
    private(set) var burnCarry: CGFloat = 0
    private(set) var bleedCarry: CGFloat = 0

    /// Whole damage each channel owes after one step. The host deals them as
    /// two separate hits (Burn first — the legacy order).
    struct Payout: Equatable {
        var burn = 0
        var bleed = 0
        /// Bleed ticks that landed this step (the tell pulses on each).
        var bleedTicks = 0
    }

    /// Advance by `dt` of game time.
    /// - Parameters:
    ///   - scale: boss-class DoT scale (1 for normal enemies).
    ///   - bleedMultiplier: situational Bleed scaling (legacy Glass Blood /
    ///     Red Smile until their A4 rework); 1 = none.
    mutating func tick(_ dt: TimeInterval, scale: CGFloat, bleedMultiplier: CGFloat,
                       burnDecayInterval: TimeInterval, bleedInterval: TimeInterval) -> Payout {
        var out = Payout()
        if burn.stacks > 0 {
            // CL-17 scales Kindle's Burn only. A flat source on the burn channel
            // (the Shock tesla field) is not Burn and keeps its full DPS; the
            // stronger of the two still wins, never the sum. Rates are read
            // before the tick — the frame Burn expires on still burns.
            let rate = max(burn.kindleRate * scale, burn.flatRate)
            _ = burn.tick(dt, decayInterval: burnDecayInterval)
            burnCarry += rate * CGFloat(dt)
            if burnCarry >= 1 {
                out.burn = Int(burnCarry)
                burnCarry -= CGFloat(out.burn)
            }
        }
        // Always ticked (a no-op once it has ended) so `ticksThisFrame` is never stale.
        let bled = bleed.tick(dt, interval: bleedInterval)
        out.bleedTicks = bleed.ticksThisFrame
        if bled > 0 {
            bleedCarry += bled * bleedMultiplier * scale
            if bleedCarry >= 1 {
                out.bleed = Int(bleedCarry)
                bleedCarry -= CGFloat(out.bleed)
            }
        }
        return out
    }
}
