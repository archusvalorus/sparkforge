//
//  BeamClock.swift
//  Sparkforge
//
//  v2.2 Neutral rework, Unit N4 (R2/R4, contract C1): the chaos beam's two
//  clocks, on ACTIVE beam time only. Pure value type — no scene.
//
//  • The VIRTUAL VOLLEY clock compares accumulated active beam time with the
//    CURRENT effective firing interval `I` every frame (a speed change applies
//    at the next comparison; progress in seconds is kept, never rescaled).
//  • The DAMAGE TICK clock fires every `GameConfig.Neutral.beamTickInterval`.
//  Both use the gun's `FireClock` rule (CL-23): the leftover carries, bounded
//  to one interval; at most one event per frame each; with nothing to fire at
//  ("idle") a clock holds ready without banking time. Time only enters through
//  `advance`, which the scene calls only on `.playing` frames when the beam is
//  not suspended — so selection, reveals, placement, pause, background, death,
//  Red Smile's form and the kaiju spend nothing and owe nothing.
//

import Foundation

struct BeamClock {
    private(set) var volleyClock = FireClock()
    private(set) var tickClock = FireClock()

    /// One frame of beam time. `firing` = a target is in reach this frame.
    /// The virtual volley is resolved before the damage tick (C1).
    mutating func advance(_ dt: TimeInterval, volleyInterval: TimeInterval, firing: Bool) -> (volley: Bool, tick: Bool) {
        let volley = volleyClock.advance(dt, interval: volleyInterval, hasTarget: { firing })
        let tick = tickClock.advance(dt, interval: GameConfig.Neutral.beamTickInterval, hasTarget: { firing })
        return (volley, tick)
    }

    mutating func reset() {
        volleyClock.reset()
        tickClock.reset()
    }
}
