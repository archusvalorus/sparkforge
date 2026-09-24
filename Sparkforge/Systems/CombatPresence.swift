// CombatPresence.swift
// Sparkforge
//
// v2.1 Abilities A4c (CL-33): the ONE shared definition of "active combat".
// Red Smile's cycle reads it now; Grounded Core (A5) reuses it.
//
// Active combat = at least one currently HITTABLE hostile (enemy or boss)
// exists in the encounter. Distance, line of sight and gun range do not
// matter — hiding behind the Carrier is not leaving combat while valid
// hostiles exist. Phased / vanished actors don't qualify (the scene's shared
// hittability predicate decides that, CL-40). When the last qualifying
// hostile stops qualifying, the state holds for a short linger (0.5s) before
// it drops, so a single flicker never toggles it.
//
// Pure value type, ticked on game time from `update()`; proven by
// tools/redsmile-harness.

import Foundation

struct CombatPresence {
    /// How long active combat survives after the last qualifying hostile.
    let linger: TimeInterval

    private(set) var isActive = false
    private var lingerRemaining: TimeInterval = 0

    init(linger: TimeInterval) {
        self.linger = max(0, linger)
    }

    /// Advance one frame. `hostilePresent` = a hittable hostile exists right
    /// now. Returns the (possibly updated) active state.
    @discardableResult
    mutating func update(_ dt: TimeInterval, hostilePresent: Bool) -> Bool {
        if hostilePresent {
            isActive = true
            lingerRemaining = linger
        } else if isActive {
            lingerRemaining -= max(0, dt)
            if lingerRemaining <= 0 {
                lingerRemaining = 0
                isActive = false
            }
        }
        return isActive
    }

    mutating func reset() {
        isActive = false
        lingerRemaining = 0
    }
}
