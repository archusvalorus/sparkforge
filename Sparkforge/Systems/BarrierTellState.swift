// BarrierTellState.swift
// Sparkforge
//
// v2.1 Abilities A4b (independent review, finding 2): when a hit empties the
// Blood Barrier, the pool is zero IMMEDIATELY for gameplay — but the strip must
// still show its absorption flash before it disappears. The HUD update runs
// every frame, so it used to hide the strip mid-flash and the tell was never
// seen (CL-21 wants a hit the barrier absorbed to read as absorbed).
//
// This is presentation state ONLY. It never touches the barrier amount, the
// damage math or the 4s expiry: it decides when the strip may hide.
//   • a flash starts → the strip stays on screen, at its last drawn width
//   • the pool emptying DURING a flash defers the hide, it doesn't cancel it
//   • the flash ends → an empty pool hides then (never a persistent 0 strip)
//   • a REFILL during the flash cancels that deferred hide
//   • with no flash running, an empty pool hides at once, as before
//
// Pure value type, proven by tools/bleed-harness.

import Foundation

struct BarrierTellState: Equatable {
    /// The amount the strip is currently drawn for; -1 = nothing drawn yet.
    private(set) var drawnAmount = -1
    /// An absorption flash is playing.
    private(set) var isFlashing = false
    /// The pool emptied while that flash was playing.
    private(set) var hideDeferred = false

    /// Is the strip on screen right now?
    var isVisible: Bool { drawnAmount > 0 || isFlashing }

    /// A hit absorbed barrier: the flash begins and holds the strip on screen.
    mutating func absorbedHit() {
        isFlashing = true
        hideDeferred = false
    }

    /// The pool changed. Returns true when the strip should redraw now
    /// (hiding itself when the new amount is 0).
    mutating func update(amount: Int) -> Bool {
        // A refill DURING a flash cancels a deferred hide — the strip must not
        // vanish at the end of the flash when barrier exists again.
        if amount > 0 { hideDeferred = false }
        if amount <= 0, isFlashing {
            hideDeferred = true      // wait for the flash — don't hide mid-tell
            return false
        }
        guard amount != drawnAmount else { return false }
        drawnAmount = amount
        return true
    }

    /// The flash finished. Returns true when the strip should hide now.
    mutating func flashEnded() -> Bool {
        isFlashing = false
        guard hideDeferred else { return false }
        hideDeferred = false
        drawnAmount = 0
        return true
    }
}
