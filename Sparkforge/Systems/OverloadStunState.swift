// OverloadStunState.swift
// Sparkforge
//
// v2.1 Abilities A3 (Shock): Overload's per-target stun + the immunity that
// follows it (closure table CL-2) — pure, on game time, proven by
// tools/shock-harness. EnemyNode owns one.
//
// CL-2 (Brandon, Sep 17): three seconds of PER-TARGET stun immunity after the
// stun ENDS. Without it, a 35% / 2s stun riding six-enemy chains re-stuns in a
// loop. The immunity is Overload's alone — other stuns (pandas, Erasure's phase
// lock, snowmen) neither grant nor respect it.

import Foundation

struct OverloadStunState {
    private(set) var stun = GameTimer()
    private(set) var immunity = GameTimer()

    var isStunned: Bool { stun.isActive }
    var isImmune: Bool { immunity.isActive }

    /// Try to stun. Refused while already Overload-stunned or immune.
    mutating func tryStun(duration: TimeInterval) -> Bool {
        guard duration > 0, !stun.isActive, !immunity.isActive else { return false }
        stun.start(duration)
        return true
    }

    /// Advance game time; the immunity window opens the moment the stun ends.
    mutating func tick(_ dt: TimeInterval, immunityDuration: TimeInterval) {
        immunity.tick(dt)
        if stun.tick(dt) { immunity.start(immunityDuration) }
    }
}
