// StunHold.swift
// Sparkforge
//
// v2.1 Abilities A7b S5 (G1.7): an enemy's TIMED stun, kept independent of the
// snowman form — pure, on game time, proven by tools/shock-harness (SH) and
// wired in EnemyNode (catalog WR11).
//
// Closure table R2: one control can't lengthen or cut short another. The timed
// stun (Overload's CL-2 stun, a panda's prune, Erasure's Phase Lock) is held
// here; the snowman is its own hold (SnowmanState). Becoming a snowman never
// writes this timer and ending one never clears it, so an Overload stun that
// lands on a snowman runs its full remaining duration after the form ends. The
// body is stunned while EITHER hold is active. There is deliberately no way to
// clear the timed stun early.

import Foundation

struct StunHold {
    /// Seconds left on the timed stun (0 = none).
    private(set) var remaining: TimeInterval = 0

    /// Stunned while the timed stun runs OR the snowman form holds.
    func isStunned(snowman: Bool) -> Bool { remaining > 0 || snowman }

    /// A timed stun keeps whichever is longer, never shortened (the existing
    /// `stunTimer = max(stunTimer, duration)` rule, unchanged).
    mutating func stun(_ duration: TimeInterval) { remaining = max(remaining, duration) }

    /// Advance game time (unticked = paused: the hold stays).
    mutating func tick(_ dt: TimeInterval) { if remaining > 0 { remaining -= dt } }
}
