// BurnState.swift
// Sparkforge
//
// v2.1 Abilities A1 (Fire): one enemy's Burn — Crucible's per-enemy stacks
// (Q-F2) and the dormant-stack decay (closure table CL-16). Pure value type on
// game time, proven by tools/fire-harness; EnemyNode owns one and draws it.
//
// Rules:
//   • The first Burn application is stack 1.
//   • Only a Kindle HIT may add a stack: at most one per `stackInterval` per
//     enemy, up to `stackCap` (1 without Crucible — exactly the pre-A1 Burn).
//     A burning enemy never stacks on its own; spread and other sources
//     re-ignite but never add.
//   • Each stack deals the full per-stack DPS. Per-stack DPS and duration keep
//     the legacy "strongest / longest wins" rule.
//   • When Burn ends its damage STOPS and the stacks go dormant: one fades
//     every `decayInterval`. Any new application reactivates the survivors
//     and resets decay progress; the stack-addition limit keeps running
//     through all of it. No stacks left → the next application starts at one.
//   • A non-Kindle source (the Shock tesla field rides the burn channel) is a
//     flat DPS that never multiplies by stacks.
//   • v2.1 A4a: Kindle and flat sources keep SEPARATE timers. The tesla field
//     re-applies every frame; on one shared timer it kept a stacked Kindle
//     Burn alive for as long as Spark stood close — Burn never ended (CL-16).
//     A flat source may still hold dormant stacks at its own DPS (B5b).

import CoreGraphics
import Foundation

struct BurnState {

    enum Source {
        /// A Kindle projectile hit — the only source that can add a stack.
        case kindleHit
        /// Spreading Flame: Kindle's Burn jumping to a neighbor.
        case kindleSpread
        /// Anything else on the burn channel. Flat — ignores stacks.
        case other
    }

    private(set) var stacks = 0
    /// Per-stack DPS from Kindle sources; 0 while dormant.
    private(set) var kindleDPS: CGFloat = 0
    /// Flat DPS from non-Kindle sources; 0 while dormant.
    private(set) var flatDPS: CGFloat = 0
    /// How long Kindle's (stacked) Burn keeps burning.
    private(set) var kindleActive = GameTimer()
    /// How long the flat source keeps burning — never prolongs Kindle's.
    private(set) var flatActive = GameTimer()
    private var stackGate = GameTimer()
    private var decayProgress: TimeInterval = 0

    /// Whichever source burns longest — the Burn as a whole.
    var active: GameTimer { kindleActive.remaining >= flatActive.remaining ? kindleActive : flatActive }
    var isBurning: Bool { active.isActive && dps > 0 }
    /// Burn has ended but stacks remain, fading.
    var isDormant: Bool { stacks > 0 && !active.isActive }
    /// Kindle's stacked Burn per second right now (0 once it has ended).
    var kindleRate: CGFloat { kindleActive.isActive ? kindleDPS * CGFloat(stacks) : 0 }
    /// The flat (non-Kindle) source's DPS right now.
    var flatRate: CGFloat { flatActive.isActive ? flatDPS : 0 }
    /// Damage per second right now — the stronger source, never the sum.
    var dps: CGFloat { max(kindleRate, flatRate) }

    /// Apply Burn. Returns true when this application added a stack.
    @discardableResult
    mutating func ignite(dps: CGFloat, duration: TimeInterval, source: Source,
                         stackCap: Int, stackInterval: TimeInterval) -> Bool {
        guard dps > 0, duration > 0 else { return false }
        switch source {
        case .kindleHit, .kindleSpread: kindleActive.extend(atLeast: duration)
        case .other: flatActive.extend(atLeast: duration)
        }
        decayProgress = 0

        var added = false
        if stacks == 0 {
            // Initial Burn is stack 1 — and it starts the addition limit, so
            // the second stack is never sooner than one interval later.
            stacks = 1
            stackGate.start(stackInterval)
        } else if source == .kindleHit, stacks < stackCap, !stackGate.isActive {
            stacks += 1
            stackGate.start(stackInterval)
            added = true
        }

        switch source {
        case .kindleHit, .kindleSpread: kindleDPS = max(kindleDPS, dps)
        case .other: flatDPS = max(flatDPS, dps)
        }
        return added
    }

    /// Advance by `dt` of game time. Returns the DPS that burned this frame
    /// (the frame Burn expires on still burns, as it always has).
    mutating func tick(_ dt: TimeInterval, decayInterval: TimeInterval) -> CGFloat {
        stackGate.tick(dt)
        if active.isActive {
            let burned = dps
            if kindleActive.isActive, kindleActive.tick(dt) { kindleDPS = 0 }
            if flatActive.isActive, flatActive.tick(dt) { flatDPS = 0 }
            if !active.isActive { decayProgress = 0 }
            return burned
        }
        if stacks > 0, decayInterval > 0 {
            decayProgress += dt
            while decayProgress >= decayInterval, stacks > 0 {
                stacks -= 1
                decayProgress -= decayInterval
            }
            if stacks == 0 { decayProgress = 0 }
        }
        return 0
    }
}
