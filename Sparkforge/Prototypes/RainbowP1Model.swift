// Owner-authorized isolated P1 proof. No production combat or reward caller.
#if DEBUG
import Foundation
import CoreGraphics

struct RainbowP1Model {
    typealias C = GameConfig.RainbowPrototype
    nonisolated enum Hold: Hashable { case pause, levelUp, placement, reveal, background }

    struct Attacker {
        // Ordinary pre-Rainbow shot basis, including passive attacker bonuses.
        var ordinaryBasis: CGFloat = C.ordinaryBasis
        var critChance: CGFloat = 0
        var critMultiplier: CGFloat = 2
        var luckyBreak = false
        var longShotT4 = false
    }
    struct Target {
        let id: Int
        var previous: CGPoint
        var position: CGPoint
        var radius: CGFloat = C.targetRadius
        var health: Int = 100
        var hittable = true
        var arenaBoss = false
        var snowman = false
        var vulnerability: CGFloat = 1
        var defenseFactor: CGFloat = 1
        var amplifiers = DirectHitAmplifiers.onBoss(openWoundsBonus: 0, bleeding: false)
    }
    struct Contact {
        let targetID: Int
        let position: CGPoint
        let cycle: Int
        let crit: Bool
        let hit: DirectHit
        let meltsSnowman: Bool
        let killed: Bool
        let emitsChainRoot: Bool
        var entry: DirectHit { hit.targetEntry }
        // KillSource.capstone is full credit. The fixture sink is not the
        // production progression/reward path, and creates no shot/hit procs.
        var source: KillSource { .capstone }
    }
    struct Sweep {
        let cycle: Int
        let footprint: CGRect
        let origin: CGPoint
        let attacker: Attacker
        var age: TimeInterval = 0
        var hitIDs: Set<Int> = []
        var frontX: CGFloat {
            footprint.minX + footprint.width * CGFloat(min(1, age / C.crossing))
        }
    }
    struct Frame {
        var launched = false
        var contacts: [Contact] = []
    }

    private(set) var owned = false
    private(set) var holds: Set<Hold> = []
    private(set) var elapsed: TimeInterval = 0
    private(set) var sweep: Sweep?
    private(set) var launches = 0
    var remaining: TimeInterval { max(0, C.cadence - elapsed) }
    var warning: Bool { owned && remaining <= C.warning }
    var primaryMultiplier: CGFloat { owned ? C.primaryMultiplier : 1 }

    mutating func select() {
        guard !owned else { return }
        owned = true
        elapsed = 0
        sweep = nil
    }
    mutating func setHold(_ hold: Hold, _ enabled: Bool) {
        if enabled { holds.insert(hold) } else { holds.remove(hold) }
    }
    mutating func endRun() {
        owned = false
        elapsed = 0
        sweep = nil
    }
    mutating func newRun() { self = RainbowP1Model() }
    mutating func boardHandoff() {
        elapsed = 0
        sweep = nil
        // Ownership and independent hold reasons survive the board change.
    }
    func activeStep(_ raw: TimeInterval) -> TimeInterval {
        guard owned, holds.isEmpty, raw.isFinite else { return 0 }
        return min(max(0, raw), C.maximumActiveStep)
    }

    /// Spark aims the lane; clipping never shifts its proposed center away
    /// from him. Warning and launch use the same geometry calculation.
    static func laneFootprint(viewport: CGRect, origin: CGPoint, board: CGRect) -> CGRect {
        let visible = viewport.intersection(board)
        guard !visible.isNull && !visible.isEmpty else { return .null }
        let height = visible.height * C.laneHeightFraction
        let proposed = CGRect(x: visible.minX, y: origin.y - height / 2,
                              width: visible.width, height: height)
        return proposed.intersection(visible)
    }

    /// Caller supplies linear body motion during this bounded active frame.
    /// Capture interpolated viewport/origin precisely when the clock fires.
    mutating func advance(_ raw: TimeInterval, fromViewport: CGRect, toViewport: CGRect,
                          fromOrigin: CGPoint, toOrigin: CGPoint, board: CGRect,
                          attacker: Attacker, targets: [Target], geometry: ArenaGeometry,
                          random: () -> CGFloat = { CGFloat.random(in: 0..<1) }) -> Frame {
        let dt = activeStep(raw)
        guard dt > 0 else { return Frame() }
        var frame = Frame()
        let before = elapsed
        elapsed += dt
        if elapsed >= C.cadence {
            let delay = max(0, C.cadence - before)
            let fraction = CGFloat(min(1, delay / dt))
            let visible = CGRect(x: fromViewport.minX + (toViewport.minX - fromViewport.minX) * fraction,
                                 y: fromViewport.minY + (toViewport.minY - fromViewport.minY) * fraction,
                                 width: fromViewport.width + (toViewport.width - fromViewport.width) * fraction,
                                 height: fromViewport.height + (toViewport.height - fromViewport.height) * fraction)
            elapsed -= C.cadence
            launches += 1
            let origin = fromOrigin.lerp(to: toOrigin, t: fraction)
            let captured = Self.laneFootprint(viewport: visible, origin: origin, board: board)
            if !captured.isNull && !captured.isEmpty {
                sweep = Sweep(cycle: launches, footprint: captured,
                              origin: origin, attacker: attacker)
                frame.contacts = advanceSweep(dt - delay, startFraction: fraction,
                                              targets: targets, geometry: geometry, random: random)
            } else { sweep = nil }
            frame.launched = true
        } else if sweep != nil {
            frame.contacts = advanceSweep(dt, startFraction: 0,
                                          targets: targets, geometry: geometry, random: random)
        }
        return frame
    }

    private mutating func advanceSweep(_ dt: TimeInterval, startFraction: CGFloat,
                                       targets: [Target], geometry: ArenaGeometry,
                                       random: () -> CGFloat) -> [Contact] {
        guard var current = sweep else { return [] }
        let before = current.age
        let actual = min(max(0, dt), C.crossing - before)
        let endFraction: CGFloat = dt > 0 ? startFraction + (1 - startFraction) * CGFloat(actual / dt) : startFraction
        let fromX = current.frontX
        current.age += actual
        let toX = current.frontX
        let centerY = current.footprint.midY
        var candidates: [(target: Target, fraction: CGFloat, position: CGPoint)] = []
        for target in targets where target.hittable && target.health > 0 && !current.hitIDs.contains(target.id) {
            let a = target.previous.lerp(to: target.position, t: startFraction)
            let b = target.previous.lerp(to: target.position, t: endFraction)
            let relativeA = a - CGPoint(x: fromX, y: centerY)
            let relativeB = b - CGPoint(x: toX, y: centerY)
            guard let entry = Self.firstContact(relativeA, relativeB,
                                                halfHeight: current.footprint.height / 2, radius: target.radius),
                  let reverseEntry = Self.firstContact(relativeB, relativeA,
                                                       halfHeight: current.footprint.height / 2, radius: target.radius) else { continue }
            let exit = 1 - reverseEntry
            guard let t = current.attacker.longShotT4 ? entry : Self.firstVisibleContact(
                entry: entry, exit: exit, from: a, to: b, origin: current.origin, geometry: geometry) else { continue }
            let at = a.lerp(to: b, t: t)
            candidates.append((target, t, at))
        }
        // Deterministic contact order, independent of fixture array order.
        candidates.sort { $0.fraction == $1.fraction ? $0.target.id < $1.target.id : $0.fraction < $1.fraction }
        var contacts: [Contact] = []
        for candidate in candidates {
            let target = candidate.target
            // Duplicate IDs cannot receive two hits from one input frame.
            guard current.hitIDs.insert(target.id).inserted else { continue }
            let crit = random() < current.attacker.critChance
            var prefix = max(0, current.attacker.ordinaryBasis) * C.sweepMultiplier
            if crit {
                prefix *= current.attacker.critMultiplier
                if current.attacker.luckyBreak && random() < C.luckyBreakChance {
                    prefix *= C.luckyBreakMultiplier
                }
            }
            let hit = DirectHitDamage.resolveExact(prefix, target.amplifiers, overcharge: 1,
                                                   vulnerability: target.vulnerability,
                                                   extra: target.defenseFactor,
                                                   rounding: DirectHitRounding(unit: random()))
            let killed = hit.dealt >= target.health
            contacts.append(Contact(targetID: target.id, position: candidate.position,
                                    cycle: current.cycle, crit: crit, hit: hit,
                                    meltsSnowman: target.snowman && hit.targetEntry.basis > 0 && hit.targetEntry.dealt > 0,
                                    killed: killed, emitsChainRoot: killed && !target.arenaBoss))
        }
        sweep = current.age >= C.crossing ? nil : current
        return contacts
    }

    /// Continuous target-circle vs moving vertical segment, in relative space.
    /// Find the earliest intersecting prefix, not just endpoint overlap. The
    /// leading contact line always lies inside the captured Spark-aimed lane.
    private static func firstContact(_ a: CGPoint, _ b: CGPoint,
                                      halfHeight: CGFloat, radius: CGFloat) -> CGFloat? {
        func crosses(_ end: CGPoint) -> Bool {
            MeleeSector.segmentCrossesRoundedBox(a, end, center: .zero,
                                                 halfExtents: CGSize(width: 0, height: halfHeight),
                                                 cornerRadius: 0, rotation: 0, margin: max(0, radius))
        }
        guard crosses(b) else { return nil }
        if crosses(a) { return 0 }
        var low: CGFloat = 0, high: CGFloat = 1
        for _ in 0..<C.contactSearchSteps {
            let mid = (low + high) / 2
            if crosses(a.lerp(to: b, t: mid)) { high = mid } else { low = mid }
        }
        return high
    }

    /// Each authored footprint is convex, so its shadow from a fixed origin
    /// intersects a straight target trajectory in one interval. Walk past the
    /// shadows currently covering contact, rather than sampling a doorway or
    /// rejecting the whole frame at an occluded first body touch. A shadow
    /// already exited cannot re-enter along this segment; iterations are thus
    /// bounded by footprint count, not an arbitrary gameplay/substep cap.
    private static func firstVisibleContact(entry: CGFloat, exit: CGFloat,
                                            from a: CGPoint, to b: CGPoint, origin: CGPoint,
                                            geometry: ArenaGeometry) -> CGFloat? {
        var candidate = entry
        for _ in 0...geometry.blockedFootprints.count {
            var next = candidate
            var blocked = false
            for footprint in geometry.blockedFootprints {
                func occluded(_ t: CGFloat) -> Bool {
                    MeleeSector.segmentCrossesRoundedBox(origin, a.lerp(to: b, t: t),
                        center: footprint.center, halfExtents: footprint.halfExtents,
                        cornerRadius: footprint.cornerRadius, rotation: footprint.rotation, margin: 0)
                }
                guard occluded(candidate) else { continue }
                blocked = true
                if occluded(exit) { return nil }
                var low = candidate, high = exit
                for _ in 0..<C.contactSearchSteps {
                    let mid = (low + high) / 2
                    if occluded(mid) { low = mid } else { high = mid }
                }
                next = max(next, high)
            }
            if !blocked { return candidate }
            guard next > candidate, next <= exit else { return nil }
            candidate = next
        }
        return nil
    }
}
#endif
