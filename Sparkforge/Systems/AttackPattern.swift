//
//  AttackPattern.swift
//  Sparkforge
//
//  v2.2 Neutral rework, Unit N3 (R3 ruling, Oct 11): the pure attack-pattern
//  foundation — Scatter's lanes, Fracture's fans, and their composition under
//  the shared forward-spread rule. Projectiles consume it now (N3: every lane
//  and branch is a shot); the chaos beam consumes the same lanes and branches
//  in N4. No node, no scene, no physics: tools/neutral-harness compiles this
//  file alone.
//
//  Conventions: headings are radians OFFSET from the aim (positive = left);
//  origin offsets are points along the aim's left normal. All numbers live in
//  GameConfig.Neutral.
//
//  Rules (docs/v2.2-neutral-design-spec.md §2, N0 §4 R3, approved):
//    • Scatter is TOTAL lanes per volley: 2 / 3 / 5 / 9. T1 = two parallel
//      lanes 12 pt apart; T2 = 0, ±15°; T3 = 0, ±15°, ±30°; T4 = nine lanes
//      0, ±14.75°, …, ±59° (118° total). Each lane is a full-strength shot.
//    • Fracture is TOTAL branches per incoming shot: 3 / 5 / 9 / 17 spread
//      evenly over 30° / 60° / 120° / 180°, centre included. Each parent's
//      damage is divided equally among ALL its branches (share = 1/n): no
//      retained full-strength centre, no per-branch minimum of 1 (the share is
//      chance-rounded; see `chanceRounded`).
//    • Composition: every lane's fan is centred on the lane's heading. If the
//      outermost branch would exceed ±90° from the aim, EVERY angle in the
//      composed set is scaled by 90° / maxAbs, so the outermost lands at
//      exactly ±90° (Scatter T4 + Fracture T4: 149° → scale 90/149, 153
//      branches). Counts, origins and distinctness are preserved; coincident
//      branches (same origin and heading) are still two branches and both hit.
//    • Storm Engine's +2 pellets on its volley are +2 lanes: with Scatter they
//      take the next outward positions of the tier's own step (two more
//      parallel lanes at T1); without Scatter the legacy count fan stands
//      (1 straight, 2 parallel, 3+ the static cone) — unchanged from v1.9.
//

import Foundation
import CoreGraphics

struct AttackPattern {

    struct Lane: Equatable {
        /// Radians offset from the aim.
        let heading: CGFloat
        /// Points along the aim's left normal.
        let originOffset: CGFloat
    }

    struct Branch: Equatable {
        /// Index of the parent lane in the composed lane set.
        let lane: Int
        /// Index within the parent's fan (0 … n−1, centre at the middle).
        let index: Int
        /// Radians offset from the aim (after the forward-spread scaling).
        let heading: CGFloat
        /// Points along the aim's left normal (the parent lane's origin).
        let originOffset: CGFloat
        /// The parent's damage share carried by this branch: 1/n.
        let share: CGFloat
        /// The fan's centre branch — it carries the parent's primary identity
        /// (modifiers, kill credit) at its share; the others are fragments.
        let isCenter: Bool
    }

    static func radians(_ degrees: CGFloat) -> CGFloat { degrees * .pi / 180 }
    static func degrees(_ radians: CGFloat) -> CGFloat { radians * 180 / .pi }

    // MARK: Scatter

    /// Total lanes for a Scatter tier (0 = the single straight lane).
    static func scatterLaneCount(tier: Int) -> Int {
        let counts = GameConfig.Neutral.scatterLaneCounts
        return counts[max(0, min(tier, counts.count - 1))]
    }

    /// Symmetric headings for `count` lanes at `step` radians: 0, ±step, ±2·step …
    /// (an even count leaves out the centre and uses half-steps: ±½, ±1½ …).
    static func symmetricHeadings(count: Int, step: CGFloat) -> [CGFloat] {
        guard count > 0 else { return [] }
        let half = CGFloat(count - 1) / 2
        return (0..<count).map { (CGFloat($0) - half) * step }
    }

    /// Parallel origins for `count` lanes `spacing` apart, centred on the aim.
    static func parallelOrigins(count: Int, spacing: CGFloat) -> [CGFloat] {
        guard count > 0 else { return [] }
        let half = CGFloat(count - 1) / 2
        return (0..<count).map { (CGFloat($0) - half) * spacing }
    }

    /// Scatter's own lanes by tier.
    static func scatterLanes(tier: Int) -> [Lane] {
        lanes(count: scatterLaneCount(tier: tier), scatterTier: tier, legacyCone: 0)
    }

    /// A lane set of `count` lanes under Scatter tier `scatterTier`. `count`
    /// above the tier's own lanes (Storm Engine's +2) adds lanes outward at
    /// the tier's own step (parallel at T1). Without Scatter, `legacyCone` is
    /// the v1.9 static cone for 3+ pellets (radians).
    static func lanes(count: Int, scatterTier: Int, legacyCone: CGFloat) -> [Lane] {
        let count = max(1, count)
        let N = GameConfig.Neutral.self
        if scatterTier <= 0 {
            // The legacy count fan, unchanged: 1 straight; 2 parallel; 3+ a V
            // over the static cone (step = cone / (count − 1)).
            if count == 1 { return [Lane(heading: 0, originOffset: 0)] }
            if count == 2 { return parallelOrigins(count: 2, spacing: N.scatterParallelSpacing).map { Lane(heading: 0, originOffset: $0) } }
            return symmetricHeadings(count: count, step: legacyCone / CGFloat(count - 1)).map { Lane(heading: $0, originOffset: 0) }
        }
        if scatterTier == 1 {
            // Parallel lanes; extras are more parallel lanes at the same spacing.
            return parallelOrigins(count: count, spacing: N.scatterParallelSpacing).map { Lane(heading: 0, originOffset: $0) }
        }
        let step = radians(N.scatterStepDegrees[min(scatterTier, N.scatterStepDegrees.count - 1)])
        return symmetricHeadings(count: count, step: step).map { Lane(heading: $0, originOffset: 0) }
    }

    // MARK: Fracture

    /// Total branches for a Fracture tier (0 = the shot itself).
    static func fractureBranchCount(tier: Int) -> Int {
        let counts = GameConfig.Neutral.fractureBranchCounts
        return counts[max(0, min(tier, counts.count - 1))]
    }

    /// Fracture's fan: `count` branches evenly over the tier's coverage, centre
    /// included (tier 0 → the single branch at 0).
    static func fractureOffsets(tier: Int) -> [CGFloat] {
        guard tier > 0 else { return [0] }
        let N = GameConfig.Neutral.self
        let t = min(tier, N.fractureBranchCounts.count - 1)
        let count = N.fractureBranchCounts[t]
        let coverage = radians(N.fractureCoverageDegrees[t])
        guard count > 1 else { return [0] }
        return symmetricHeadings(count: count, step: coverage / CGFloat(count - 1))
    }

    // MARK: Composition (the shared forward-spread rule)

    /// The uniform scale the forward-spread rule applies to a composed set
    /// (1 when every branch is already within ±bound).
    static func forwardScale(lanes: [Lane], fracture: [CGFloat], bound: CGFloat = radians(GameConfig.Neutral.patternForwardBoundDegrees)) -> CGFloat {
        var maxAbs: CGFloat = 0
        for lane in lanes { for offset in fracture { maxAbs = max(maxAbs, abs(lane.heading + offset)) } }
        return maxAbs > bound && maxAbs > 0 ? bound / maxAbs : 1
    }

    /// Every lane's fan centred on its heading, scaled uniformly by the
    /// forward-spread rule. Lane-major order; each branch carries 1/n of its
    /// parent's damage; the fan's middle branch is the centre.
    static func compose(lanes: [Lane], fracture: [CGFloat], bound: CGFloat = radians(GameConfig.Neutral.patternForwardBoundDegrees)) -> [Branch] {
        let fan = fracture.isEmpty ? [0] : fracture
        let scale = forwardScale(lanes: lanes, fracture: fan, bound: bound)
        let share = 1 / CGFloat(fan.count)
        let center = (fan.count - 1) / 2
        var out: [Branch] = []
        out.reserveCapacity(lanes.count * fan.count)
        for (li, lane) in lanes.enumerated() {
            for (bi, offset) in fan.enumerated() {
                out.append(Branch(lane: li, index: bi, heading: (lane.heading + offset) * scale,
                                  originOffset: lane.originOffset, share: share, isCenter: bi == center))
            }
        }
        return out
    }

    // MARK: Damage shares

    /// Chance-rounding WITHOUT a floor: `exact` resolves to ⌊exact⌋ or ⌊exact⌋+1
    /// with probability (exact − ⌊exact⌋) for the latter, so the expectation
    /// is exactly `exact` and a sub-1 share is never a free 1. `unit` is the
    /// projectile's one launch-time threshold (monotone across its hits).
    static func chanceRounded(_ exact: CGFloat, unit: CGFloat) -> Int {
        guard exact > 0 else { return 0 }
        let whole = exact.rounded(.down)
        return Int(whole) + (unit < exact - whole ? 1 : 0)
    }
}
