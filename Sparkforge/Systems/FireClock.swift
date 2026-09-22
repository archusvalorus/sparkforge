// FireClock.swift
// Sparkforge
//
// v2.1 Abilities A4b (CL-23): Spark's auto-attack cadence. The old loop reset
// its timer to 0 on every shot, throwing away the part of the frame past the
// interval — so fire rate snapped to whole frames (+15% attack speed played as
// +11%, and small steps like Bloodlust's +0.1% did nothing for ~35 kills).
// The clock now CARRIES that leftover, so the sustained rate matches the
// calculated one, with BOUNDED catch-up:
//   • at most one interval of credit is ever banked, so a hitch can't unleash
//     a volley;
//   • with nothing to shoot the clock waits "ready" instead of banking time;
//   • it only advances on game time, so pauses and level-up screens can't
//     build firing debt either.
// Pure value type, proven by tools/bleed-harness.

import Foundation

struct FireClock {
    /// Game time banked toward the next shot.
    private(set) var elapsed: TimeInterval = 0

    /// Advance by `dt`. Returns true when a shot should fire this frame —
    /// `hasTarget` is asked only once the interval has come due.
    mutating func advance(_ dt: TimeInterval, interval: TimeInterval, hasTarget: () -> Bool) -> Bool {
        guard interval > 0 else { return false }
        elapsed += max(0, dt)
        guard elapsed >= interval else { return false }
        guard hasTarget() else {
            elapsed = interval               // ready, but nothing banked while idle
            return false
        }
        elapsed = min(elapsed - interval, interval)   // carry the partial frame, bounded
        return true
    }

    mutating func reset() { elapsed = 0 }
}
