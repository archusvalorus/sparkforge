// BleedState.swift
// Sparkforge
//
// v2.1 Abilities A4a: one target's Bleed — the approved tick model (closure
// table CL-1, Option B). Pure value type on game time, proven by
// tools/bleed-harness; EnemyNode and the boss host each own one (through
// StatusDoTs) and draw it.
//
// Rules:
//   • Bleed deals `tickDamage` every `interval` for `duration`: a fresh 3s
//     Bleed at 0.5s ticks lands six ticks, the first 0.5s after it starts and
//     the last on the instant it ends.
//   • Re-applying REFRESHES: the duration restarts, the damage never stacks,
//     and the next tick is never delayed (a Bleed kept topped up ticks on the
//     same steady beat).
//   • The tick damage is the latest application's — it tracks Spark's ATK as
//     it changes, instead of freezing the strongest value ever seen.
//   • Ticks run on game time only — unticked (paused, level-up) = frozen.

import CoreGraphics
import Foundation

struct BleedState {

    private(set) var active = GameTimer()
    /// Damage each tick deals; 0 once the Bleed has ended.
    private(set) var tickDamage: CGFloat = 0
    /// Time until the next tick lands.
    private(set) var untilTick: TimeInterval = 0
    /// Ticks landed by the most recent `tick` call — drives the tell's pulse.
    private(set) var ticksThisFrame = 0

    var isBleeding: Bool { active.isActive }

    /// Inflict or refresh Bleed. Returns true when this started a new Bleed
    /// (false for a refresh or an invalid application).
    @discardableResult
    mutating func inflict(tickDamage: CGFloat, duration: TimeInterval, interval: TimeInterval) -> Bool {
        guard tickDamage > 0, duration > 0, interval > 0 else { return false }
        let fresh = !active.isActive
        active.start(duration)                 // refresh RESETS the duration
        self.tickDamage = tickDamage           // never stacks — latest ATK wins
        if fresh { untilTick = interval }      // a refresh never delays the next tick
        return fresh
    }

    /// Advance by `dt` of game time. Returns the damage from every tick that
    /// came due inside this step (0 on most frames).
    mutating func tick(_ dt: TimeInterval, interval: TimeInterval) -> CGFloat {
        ticksThisFrame = 0
        guard active.isActive, interval > 0 else { return 0 }
        let epsilon: TimeInterval = 1e-9
        var left = max(0, dt)
        var dealt: CGFloat = 0
        while active.isActive {
            // The next tick lands after this step: just run the clocks.
            if untilTick > left + epsilon {
                untilTick -= left
                active.tick(left)
                break
            }
            // A tick is due inside this step — unless the Bleed ends first.
            if untilTick > active.remaining + epsilon {
                active.tick(left)
                break
            }
            let step = max(0, untilTick)
            left -= step
            active.tick(step)                  // the final tick lands as it ends
            dealt += tickDamage
            ticksThisFrame += 1
            untilTick = interval
        }
        if !active.isActive {
            tickDamage = 0
            untilTick = 0
        }
        return dealt
    }
}
