//
//  BeamTick.swift
//  Sparkforge
//
//  v2.2 Neutral rework, Unit N4 (R2/R4): the chaos beam's pure rules — the
//  lane tick formula, its exact multiplicative prefix, the line geometry
//  (contacts, termini) and the grouping of branch contacts into ONE hit per
//  (parent lane, target, tick). No scene, no node: tools/neutral-harness
//  compiles this file alone. Numbers live in GameConfig.Neutral.
//

import Foundation
import CoreGraphics

enum BeamTick {

    // MARK: The tick formula (R2, approved)

    /// A parent lane's tick, before Fracture and target modifiers:
    /// retention × D × (tick interval ÷ I). `D` is the gun's pre-conversion
    /// standard-shot basis (the Overcharge-free integer base; Overcharge rides
    /// the block as its factor, CL-114a); `I` is the effective firing interval
    /// with every attack-speed source in it once. Fractional, never floored.
    static func laneTick(basis D: Int, interval I: TimeInterval) -> CGFloat {
        guard I > 0, D > 0 else { return 0 }
        return GameConfig.Neutral.beamDamageRetention * CGFloat(D)
            * CGFloat(GameConfig.Neutral.beamTickInterval / I)
    }

    /// The lane-tick's crit, rolled ONCE per parent lane per tick.
    struct LaneCrit: Equatable {
        var isCrit = false
        var luckyBreak = false
        static let none = LaneCrit()
    }

    /// The exact prefix of one (lane, target) hit: the lane tick × Riftline's
    /// falloff for the target's rank along the lane × the crit (and Lucky
    /// Break) × the execute × the Forge offense factor. Every factor exact; no
    /// integer step, no floor — a fractional tick keeps its expectation.
    static func exactPrefix(laneTick: CGFloat, riftlineRank: Int, riftlineActive: Bool, riftlineFalloff: CGFloat,
                            crit: LaneCrit, critMultiplier: CGFloat, luckyBreakFactor: CGFloat,
                            execute: CGFloat, forge: CGFloat) -> CGFloat {
        var p = laneTick
        if riftlineActive, riftlineRank > 0 { p *= pow(riftlineFalloff, CGFloat(riftlineRank)) }
        if crit.isCrit {
            p *= critMultiplier
            if crit.luckyBreak { p *= luckyBreakFactor }
        }
        if execute > 1 { p *= execute }
        return p * forge
    }

    // MARK: Geometry

    struct Target: Equatable {
        let index: Int            // the caller's index (an enemy, or the boss)
        let position: CGPoint
        let radius: CGFloat
    }

    struct Contact: Equatable {
        let target: Int           // Target.index
        let along: CGFloat        // distance from the line's origin
        let point: CGPoint        // the closest point on the line (sizzle spot)
    }

    /// The targets a line touches: origin + direction × [0, length], a target
    /// counting when its body circle comes within `halfWidth` of the line.
    /// Sorted by distance along the line. Every target hit at most once per line.
    static func contacts(origin: CGPoint, direction d: CGPoint, length: CGFloat,
                         halfWidth: CGFloat, targets: [Target]) -> [Contact] {
        guard length > 0 else { return [] }
        var out: [Contact] = []
        for t in targets {
            let rx = t.position.x - origin.x, ry = t.position.y - origin.y
            let along = rx * d.x + ry * d.y
            let clamped = max(0, min(length, along))
            let cx = origin.x + d.x * clamped, cy = origin.y + d.y * clamped
            let dx = t.position.x - cx, dy = t.position.y - cy
            let reach = t.radius + halfWidth
            if dx * dx + dy * dy <= reach * reach {
                out.append(Contact(target: t.index, along: clamped, point: CGPoint(x: cx, y: cy)))
            }
        }
        return out.sorted { $0.along < $1.along || ($0.along == $1.along && $0.target < $1.target) }
    }

    /// The line's length: the first of `maxLength` (range), the first solid
    /// terrain (when `blocked` is given — nil passes terrain, Long Shot T4)
    /// and the arena boundary (a circle of `arenaRadius` about the origin of
    /// the arena). Terrain by bisection on the `blocked(a, b)` predicate.
    static func length(origin: CGPoint, direction d: CGPoint, maxLength: CGFloat, arenaRadius: CGFloat,
                       blocked: ((CGPoint, CGPoint) -> Bool)?, steps: Int) -> CGFloat {
        // The arena boundary: the positive root of |origin + d t| = R (origin inside).
        let b = origin.x * d.x + origin.y * d.y
        let c = origin.x * origin.x + origin.y * origin.y - arenaRadius * arenaRadius
        let disc = b * b - c
        let toBoundary = disc >= 0 ? max(0, -b + disc.squareRoot()) : 0
        var limit = min(maxLength, toBoundary)
        guard limit > 0, let blocked else { return max(0, limit) }
        let end = CGPoint(x: origin.x + d.x * limit, y: origin.y + d.y * limit)
        guard blocked(origin, end) else { return limit }
        var lo: CGFloat = 0, hi = limit
        for _ in 0..<max(1, steps) {
            let mid = (lo + hi) / 2
            if blocked(origin, CGPoint(x: origin.x + d.x * mid, y: origin.y + d.y * mid)) { hi = mid } else { lo = mid }
        }
        limit = lo
        return limit
    }

    /// Rectangular counterpart of the existing positive-exit circle rule.
    /// Directions come from the same unit headings. Parallel offset origins
    /// may begin just outside the floor; only rays intersecting the rectangle
    /// have a positive exit. This never moves origins or changes lane counts.
    /// Positive infinite range is Long Shot3+, not an invalid input.
    static func length(origin: CGPoint, direction d: CGPoint, maxLength: CGFloat, arenaRect rect: CGRect,
                       blocked: ((CGPoint, CGPoint) -> Bool)?, steps: Int) -> CGFloat {
        guard origin.x.isFinite, origin.y.isFinite, d.x.isFinite, d.y.isFinite,
              d.x != 0 || d.y != 0, !maxLength.isNaN, maxLength >= 0,
              !rect.isNull, !rect.isInfinite, rect.minX.isFinite, rect.minY.isFinite,
              rect.maxX.isFinite, rect.maxY.isFinite, rect.width > 0, rect.height > 0,
              rect.minX < rect.maxX, rect.minY < rect.maxY else { return 0 }
        var entry = -CGFloat.infinity, exit = CGFloat.infinity
        for (value, delta, low, high) in [(origin.x, d.x, rect.minX, rect.maxX),
                                          (origin.y, d.y, rect.minY, rect.maxY)] {
            if delta == 0 {
                if value < low || value > high { return 0 }
                continue
            }
            let first = (low - value) / delta, second = (high - value) / delta
            entry = max(entry, min(first, second)); exit = min(exit, max(first, second))
        }
        guard exit.isFinite, exit >= max(0, entry) else { return 0 }
        var limit = min(maxLength, max(0, exit))
        guard limit > 0, let blocked else { return max(0, limit) }
        let end = CGPoint(x: origin.x + d.x * limit, y: origin.y + d.y * limit)
        guard blocked(origin, end) else { return limit }
        var lo: CGFloat = 0, hi = limit
        for _ in 0..<max(1, steps) {
            let mid = (lo + hi) / 2
            if blocked(origin, CGPoint(x: origin.x + d.x * mid, y: origin.y + d.y * mid)) { hi = mid } else { lo = mid }
        }
        limit = lo
        return limit
    }

    // MARK: One hit per (parent lane, target, tick)

    struct LaneHit: Equatable {
        let lane: Int
        let target: Int
        /// Branches of this lane that touched the target this tick.
        let branches: Int
        /// The lane's fan size (n): the hit carries branches ÷ n of the lane.
        let fanSize: Int
        /// The lane's centre branch is among them (a primary hit), else a fragment hit.
        let centre: Bool
        /// The target's order of distance along the lane among the lane's
        /// contacted targets (0 = nearest) — Riftline's falloff rank.
        let rank: Int
        var share: CGFloat { CGFloat(branches) / CGFloat(max(1, fanSize)) }
    }

    /// Group each branch's contacts into one hit per (lane, target). `branches`
    /// and `contacts` are parallel (contacts[i] = branch i's contacts).
    static func group(branches: [AttackPattern.Branch], contacts: [[Contact]]) -> [LaneHit] {
        var fan: [Int: Int] = [:]
        for b in branches { fan[b.lane, default: 0] += 1 }
        struct Acc { var count = 0; var centre = false; var nearest = CGFloat.greatestFiniteMagnitude }
        var acc: [Int: [Int: Acc]] = [:]
        for (i, b) in branches.enumerated() where i < contacts.count {
            for c in contacts[i] {
                var a = acc[b.lane, default: [:]][c.target, default: Acc()]
                a.count += 1
                a.centre = a.centre || b.isCenter
                a.nearest = min(a.nearest, c.along)
                acc[b.lane, default: [:]][c.target] = a
            }
        }
        var out: [LaneHit] = []
        for lane in acc.keys.sorted() {
            let byTarget = acc[lane] ?? [:]
            let ordered = byTarget.keys.sorted { (byTarget[$0]?.nearest ?? 0, $0) < (byTarget[$1]?.nearest ?? 0, $1) }
            for (rank, target) in ordered.enumerated() {
                guard let a = byTarget[target] else { continue }
                out.append(LaneHit(lane: lane, target: target, branches: a.count, fanSize: fan[lane] ?? 1,
                                   centre: a.centre, rank: rank))
            }
        }
        return out
    }
}
