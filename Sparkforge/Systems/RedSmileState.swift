// RedSmileState.swift
// Sparkforge
//
// v2.1 Abilities A4c: Red Smile's clocks, as a pure value type. The scene
// owns one, ticks it from `update()` on game time, and acts on the Step it
// returns (draw the form, resolve a swing, tear the form down).
//
// Rulings (closure table §B3):
//   • CL-34: a 10s START-TO-START cycle measured only during active combat.
//     The first form comes after 10 accumulated seconds of active combat;
//     lulls pause the cycle (never reset it); the cycle restarts at each form
//     START. A form always gets its full 3s — only the kaiju ends one early.
//   • CL-42: the form owns a SEPARATE melee clock (its own FireClock) that
//     reads the same shared effective interval as the gun. The first swing
//     lands the frame the form begins; later swings follow the interval, with
//     the FireClock's bounded remainder. Empty swings still happen (the scene
//     decides what, if anything, a swing hits). No minimum interval.
//   • CL-44: the kaiju has priority. While it is active the cycle is paused
//     and no form begins, banks or queues; if it activates mid-form the scene
//     calls `interrupt()` on the spot. When it ends, the cycle resumes from
//     its remaining time.
//
// The gun's clock is the scene's business (CL-43): it simply isn't advanced
// while `formActive`, so its remainder is preserved and no debt builds.
//
// Proven by tools/redsmile-harness.

import Foundation

struct RedSmileState {
    struct Tuning {
        /// Start-to-start cycle length, counted only in active combat.
        var period: TimeInterval
        /// How long each transformation lasts (game time).
        var duration: TimeInterval
    }

    /// What happened this frame.
    struct Step: Equatable {
        var formStarted = false
        /// Swings to resolve this frame (0 or 1 — the melee clock never
        /// releases more than one per frame).
        var swings = 0
        var formEnded = false
    }

    let tuning: Tuning

    /// Active-combat time accumulated toward the next form, since the last
    /// form START.
    private(set) var cycleElapsed: TimeInterval = 0
    /// Game time left in the current form (0 = no form).
    private(set) var formRemaining: TimeInterval = 0
    /// The form's own melee clock (never the gun's).
    private var swingClock = FireClock()

    var formActive: Bool { formRemaining > 0 }

    /// Time until the next form could begin, if combat holds.
    var timeToNextForm: TimeInterval { max(0, tuning.period - cycleElapsed) }

    /// A form whose remaining time falls within this of zero has ended —
    /// keeps float drift from sneaking a 7th swing into a 3.0s form.
    private static let endEpsilon: TimeInterval = 1e-6

    init(tuning: Tuning) {
        self.tuning = tuning
    }

    /// Advance one frame of game time.
    /// - Parameters:
    ///   - inCombat: the shared active-combat state (CL-33).
    ///   - kaijuActive: the kaiju holds priority (CL-44).
    ///   - swingInterval: the shared effective attack interval (CL-42).
    mutating func tick(_ dt: TimeInterval, inCombat: Bool, kaijuActive: Bool,
                       swingInterval: TimeInterval) -> Step {
        var step = Step()
        let dt = max(0, dt)

        // CL-44: while the kaiju is up nothing about Red Smile moves. The
        // scene interrupts a live form when the kaiju begins; this is the
        // belt to that brace.
        if kaijuActive {
            if formActive {
                formRemaining = 0
                step.formEnded = true
            }
            return step
        }

        // 1. A running form runs out its full duration, in or out of combat.
        if formActive {
            formRemaining -= dt
            if formRemaining <= Self.endEpsilon {
                formRemaining = 0
                step.formEnded = true
            } else if swingClock.advance(dt, interval: swingInterval, hasTarget: { true }) {
                step.swings += 1
            }
        }

        // 2. The cycle counts only in active combat — including during a
        //    form (it's start-to-start).
        if inCombat {
            cycleElapsed += dt
            if !formActive && cycleElapsed >= tuning.period {
                // Restart at this START, carrying the sub-frame overshoot so
                // the spacing stays exactly one period.
                cycleElapsed = min(cycleElapsed - tuning.period, tuning.period)
                formRemaining = tuning.duration
                swingClock.reset()
                step.formStarted = true
                step.swings += 1            // the first swing lands immediately
            }
        }
        return step
    }

    /// End a live form at once (the kaiju has begun). Returns true if a form
    /// was actually ended. The cycle is untouched — it resumes afterwards.
    @discardableResult
    mutating func interrupt() -> Bool {
        guard formActive else { return false }
        formRemaining = 0
        return true
    }

    /// Run start, death, revive: no form, and the cycle starts over.
    mutating func reset() {
        cycleElapsed = 0
        formRemaining = 0
        swingClock.reset()
    }
}

/// v2.1 A4c (CL-39; corrective F1/F2): the kinds of LANDED Red Smile contact.
/// Every kind is a primary hit (an ordinary enemy hit, a Shatter, or the
/// boss), so every kind gives each hit meter (The Hunter's pounce gauge,
/// Erasure's Unstable meter) exactly ONE registration opportunity. The meters'
/// own methods keep their cooldown, capacity and eligibility rules — this only
/// asks, once each; the meter decides.
enum RedSmileContact: String, CaseIterable {
    case enemy, shatter, boss

    /// Give each hit meter this contact's single registration opportunity.
    func chargeHitMeters(apex: () -> Void, erasure: () -> Void) {
        apex()
        erasure()
    }
}
