// VoidState.swift
// Sparkforge
//
// v2.1 Abilities A6 (Void): the tree's pure rules — Foundation/CoreGraphics
// only, proven by tools/void-harness. Every number is Brandon's Sep 24 ruling
// (closure table §B5) and lives in `GameConfig.VoidTree`; GameScene wires
// these to nodes. One black-hole primitive (`VoidWellState`) carries every
// preset — Gravity Well, Null Bloom, the ×3 Blackhole — and the synergy
// ladder upgrades all of them (CL-77).

import CoreGraphics
import Foundation

// MARK: - CL-70: probabilistic rounding

/// Unbiased rounding for A6's NEW direct-damage fractions only (older trees
/// keep their truncation — no retrofit). Exact positive damage `N + f` deals
/// `N + 1` with probability `f`, otherwise `N`; a landed positive hit deals at
/// least 1, so a sub-1 Riftline falloff hides at base damage rather than
/// letting a successful hit deal zero.
enum VoidRounding {
    /// `unit` is a uniform draw in [0, 1) — injected so tests are deterministic.
    static func damage(_ exact: CGFloat, unit: CGFloat) -> Int {
        guard exact > 0 else { return 0 }
        let whole = floor(exact)
        let n = Int(whole) + (unit < exact - whole ? 1 : 0)
        return max(1, n)
    }

    /// An A6 fraction applied to a shot's LEGACY damage: the older trees'
    /// multiplier is truncated first, exactly as a plain shot's would be (no
    /// retrofit), and only the A6 fraction is rounded by chance. So Riftline's
    /// falloff never climbs above the first body, and a Warp shot at full
    /// speed deals exactly what a plain shot deals (internal review, Sep 24).
    static func a6Damage(multiplier: CGFloat, fraction: CGFloat, unit: CGFloat) -> Int {
        damage(CGFloat(max(1, Int(multiplier))) * fraction, unit: unit)
    }
}

/// Independent review F3: ONE rounding threshold per projectile, drawn at
/// launch and shared by every A6 fractional damage it resolves. With one
/// threshold, rounding is monotone (a falling exact sequence — Warp over
/// flight, Riftline per body — can never realize a rise), and each
/// projectile stays unbiased over its draw.
struct A6Rounding {
    let unit: CGFloat

    init(unit: CGFloat = CGFloat.random(in: 0..<1)) {
        self.unit = unit
    }

    func damage(multiplier: CGFloat, fraction: CGFloat) -> Int {
        VoidRounding.a6Damage(multiplier: multiplier, fraction: fraction, unit: unit)
    }
}

// MARK: - CL-14: Warp Shot

/// A primary shot launches slow and accelerates; slower = more damage. Both
/// ramps are linear in the shot's age and read at the moment of the hit.
struct WarpCurve: Equatable {
    var startSpeed: CGFloat        // fraction of full speed at launch (0.40)
    var rampTime: TimeInterval     // seconds to full speed (0.6)
    var startDamage: CGFloat       // damage fraction at launch (1.50)

    func progress(age: TimeInterval) -> CGFloat {
        guard rampTime > 0 else { return 1 }
        return CGFloat(min(1, max(0, age / rampTime)))
    }
    func speedFraction(age: TimeInterval) -> CGFloat {
        startSpeed + (1 - startSpeed) * progress(age: age)
    }
    func damageFraction(age: TimeInterval) -> CGFloat {
        startDamage + (1 - startDamage) * progress(age: age)
    }
}

// MARK: - CL-81: Riftline

enum RiftlineFalloff {
    /// Damage fraction for the body a piercing shot strikes after `priorHits`
    /// others: 100%, 75%, 56.25% … (before CL-70 rounding).
    static func fraction(priorHits: Int, falloff: CGFloat) -> CGFloat {
        guard priorHits > 0 else { return 1 }
        return pow(falloff, CGFloat(priorHits))
    }
}

// MARK: - CL-71 / CL-72: Void affinity

/// What a hit carries from the Void. Affinity = Braceguard's directional
/// shield doesn't halve it. Flat-DEF penetration (Phase T2) = it skips the
/// Boss Mode flat DEF dial, and belongs ONLY to shot-class attacks: primary
/// gun shots and returned shots. Nothing here bypasses percentage DR,
/// invulnerability, terrain or hittability.
struct VoidHit: Equatable {
    let affinity: Bool
    let flatDEFPenetration: Bool

    static let none = VoidHit(affinity: false, flatDEFPenetration: false)
    /// Red Smile: Void melee — a primary hit, not a shot (CL-72, CL-85).
    static let redSmile = VoidHit(affinity: true, flatDEFPenetration: false)
    /// Shadow Edge: a secondary Void attack, not a shot (CL-72, CL-75).
    static let shadowEdge = VoidHit(affinity: true, flatDEFPenetration: false)
    /// A primary gun shot (pellet or replacement icicle): Void only at Phase T2.
    static func primaryShot(phaseT2: Bool) -> VoidHit {
        VoidHit(affinity: phaseT2, flatDEFPenetration: phaseT2)
    }
    /// A returned shot is always Void; it penetrates with Phase T2 (CL-4).
    static func returned(phaseT2: Bool) -> VoidHit {
        VoidHit(affinity: true, flatDEFPenetration: phaseT2)
    }
}

// MARK: - CL-73 / CL-74: Anomaly

/// Who a Void effect is landing on. "Elite" means mini-boss (CL-73).
enum VoidTargetClass: Equatable {
    case normal, miniBoss, boss
}

/// Phase's Anomaly on one target. Stacks from qualifying hits on a survivor;
/// at the threshold it triggers and clears. Normals are erased; mini-bosses
/// and bosses take a FINAL percentage of max HP (no second BossClass
/// reduction, CL-74) and then can't gain stacks for the cooldown.
struct AnomalyState {
    struct Tuning: Equatable {
        var threshold: Int
        var miniBossFraction: CGFloat
        var bossFraction: CGFloat
        var cooldown: TimeInterval
    }
    enum Outcome: Equatable {
        case none
        case erase
        case chunk(fraction: CGFloat)
    }

    private(set) var stacks = 0
    private(set) var cooldown = GameTimer()
    var isCooling: Bool { cooldown.isActive }

    /// Add `count` stacks (T3 = 2). Refused during the cooldown; overflow past
    /// the threshold is discarded — the hit that reaches it triggers.
    mutating func add(_ count: Int, target: VoidTargetClass, tuning: Tuning) -> Outcome {
        guard count > 0, tuning.threshold > 0, !cooldown.isActive else { return .none }
        stacks = min(tuning.threshold, stacks + count)
        guard stacks >= tuning.threshold else { return .none }
        stacks = 0
        switch target {
        case .normal:
            return .erase
        case .miniBoss:
            cooldown.start(tuning.cooldown)
            return .chunk(fraction: tuning.miniBossFraction)
        case .boss:
            cooldown.start(tuning.cooldown)
            return .chunk(fraction: tuning.bossFraction)
        }
    }

    mutating func tick(_ dt: TimeInterval) { cooldown.tick(dt) }
    mutating func reset() { stacks = 0; cooldown.cancel() }

    /// The chunk as whole damage (the Glacial Spikes convention).
    static func chunkDamage(maxHealth: Int, fraction: CGFloat) -> Int {
        max(1, Int(CGFloat(maxHealth) * fraction))
    }
}

// MARK: - CL-80: Void Horror's fear

/// Fear, then immunity once it ends (the OverloadStunState shape). Fear never
/// refreshes or stacks. A stronger control starting mid-fear cancels it and
/// starts the immunity window at once.
struct FearState {
    private(set) var fear = GameTimer()
    private(set) var immunity = GameTimer()

    var isFeared: Bool { fear.isActive }
    var isImmune: Bool { immunity.isActive }

    mutating func tryFear(duration: TimeInterval) -> Bool {
        guard duration > 0, !fear.isActive, !immunity.isActive else { return false }
        fear.start(duration)
        return true
    }

    /// A stronger hard control began: fear ends, immunity starts. Returns
    /// true when there was a fear to cancel.
    @discardableResult
    mutating func cancel(immunityDuration: TimeInterval) -> Bool {
        guard fear.isActive else { return false }
        fear.cancel()
        immunity.start(immunityDuration)
        return true
    }

    /// Returns true on the tick the fear runs out (immunity starts then).
    @discardableResult
    mutating func tick(_ dt: TimeInterval, immunityDuration: TimeInterval) -> Bool {
        immunity.tick(dt)
        if fear.tick(dt) {
            immunity.start(immunityDuration)
            return true
        }
        return false
    }

    mutating func reset() { fear.cancel(); immunity.cancel() }
}

enum VoidHorror {
    struct Tuning: Equatable {
        var chance: CGFloat
        var normalDuration: TimeInterval
        var miniBossDuration: TimeInterval
        var immunity: TimeInterval
    }

    /// What the scene knows about a target at the moment of the hit.
    struct Target: Equatable {
        var targetClass: VoidTargetClass
        var hittable: Bool
        var snowman: Bool
        var airborne: Bool
        var trapped: Bool
        /// stun (any source) or freeze — another hard control is running
        var hardControlled: Bool
    }

    /// Fear applies only to hittable actors that aren't snowmen, airborne,
    /// trapped or under another hard control; arena bosses are immune.
    static func eligible(_ t: Target) -> Bool {
        t.targetClass != .boss && t.hittable && !t.snowman && !t.airborne
            && !t.trapped && !t.hardControlled
    }

    static func duration(for targetClass: VoidTargetClass, tuning: Tuning) -> TimeInterval? {
        switch targetClass {
        case .normal: return tuning.normalDuration
        case .miniBoss: return tuning.miniBossDuration
        case .boss: return nil
        }
    }

    static func rolls(unit: CGFloat, tuning: Tuning) -> Bool { unit < tuning.chance }
}

/// Where a frightened enemy runs, and how it takes each step (CL-80). The
/// contract (independent review F1): a fear step NEVER reduces the body's
/// separation from Spark. The route steer and end-of-frame resolve still take
/// it round solid geometry; this rule only chooses headings and vetoes steps.
enum FleeRule {
    /// Degrees tried after straight-away, each on both sides: the nearest
    /// deviation from "away" that still keeps away wins.
    static let deviations: [CGFloat] = [30, 60, 90]
    /// Numeric tolerance for "didn't get closer".
    static let tolerance: CGFloat = 1e-6

    /// How far from the centre a body may stand this frame: inside the wall
    /// less its footprint — or, for a body already in that outer band, where
    /// it stands now. Fear never pulls a body inward just to satisfy the
    /// clamp (F1: an enemy at 345 of a 350 arena, Spark at 320).
    static func radiusLimit(of position: CGPoint, arenaRadius: CGFloat, footprint: CGFloat) -> CGFloat {
        max(max(0, arenaRadius - footprint), hypot(position.x, position.y))
    }

    static func clamp(_ q: CGPoint, toRadius limit: CGFloat) -> CGPoint {
        let r = hypot(q.x, q.y)
        guard r > limit, r > 0 else { return q }
        return CGPoint(x: q.x * limit / r, y: q.y * limit / r)
    }

    /// Does moving in a straight line from `p` toward `q` keep (or grow) the
    /// distance to `spark` the whole way? Distance from a point along a line
    /// is convex, so it never falls if it doesn't fall at the start.
    static func keepsAway(from p: CGPoint, toward q: CGPoint, spark s: CGPoint) -> Bool {
        (q.x - p.x) * (p.x - s.x) + (q.y - p.y) * (p.y - s.y) >= -tolerance
    }

    /// Straight away from Spark (straight up if they share a spot).
    static func awayDirection(from p: CGPoint, spark s: CGPoint) -> CGPoint {
        let dx = p.x - s.x, dy = p.y - s.y
        let len = hypot(dx, dy)
        return len < 0.0001 ? CGPoint(x: 0, y: 1) : CGPoint(x: dx / len, y: dy / len)
    }

    static func rotate(_ v: CGPoint, degrees: CGFloat) -> CGPoint {
        let a = degrees * .pi / 180
        return CGPoint(x: v.x * cos(a) - v.y * sin(a), y: v.x * sin(a) + v.y * cos(a))
    }

    /// The escape point the route steer aims at: straight away from Spark a
    /// lookahead ahead — or the nearest deviation (±30°, ±60°, ±90°) whose
    /// clamped point still keeps away along the whole straight line. nil = the
    /// body is outside the wall, or no heading keeps away (it holds, or
    /// slides via `fleeStep`).
    static func goal(from position: CGPoint, awayFrom spark: CGPoint, lookahead: CGFloat,
                     arenaRadius: CGFloat, footprint: CGFloat) -> CGPoint? {
        guard hypot(position.x, position.y) <= arenaRadius else { return nil }
        let limit = radiusLimit(of: position, arenaRadius: arenaRadius, footprint: footprint)
        let away = awayDirection(from: position, spark: spark)
        func separation(_ q: CGPoint) -> CGFloat { hypot(q.x - spark.x, q.y - spark.y) }
        for degrees in [CGFloat(0)] + deviations {
            var best: CGPoint?
            for sign: CGFloat in (degrees == 0 ? [1] : [1, -1]) {
                let dir = rotate(away, degrees: sign * degrees)
                let g = clamp(CGPoint(x: position.x + dir.x * lookahead, y: position.y + dir.y * lookahead),
                              toRadius: limit)
                guard hypot(g.x - position.x, g.y - position.y) > 1,
                      keepsAway(from: position, toward: g, spark: spark) else { continue }
                if best.map({ separation(g) > separation($0) }) ?? true { best = g }
            }
            if let g = best { return g }
        }
        return nil
    }

    /// Cut the escape ray at the last point that's still open ground, so the
    /// goal stays on the enemy's own side of any solid: pushing a blocked
    /// point out to the NEAREST surface can land it on the Carrier's far face,
    /// and routing there can lead the enemy past Spark (internal review H1).
    /// `blocked` tests a point (the scene passes its geometry with the body's
    /// footprint). Returns `from` when the very first step is blocked.
    static func truncate(from: CGPoint, to goal: CGPoint, steps: Int = 16,
                         blocked: (CGPoint) -> Bool) -> CGPoint {
        var last = from
        guard steps > 0 else { return from }
        for k in 1...steps {
            let t = CGFloat(k) / CGFloat(steps)
            let p = CGPoint(x: from.x + (goal.x - from.x) * t, y: from.y + (goal.y - from.y) * t)
            if blocked(p) { break }
            last = p
        }
        return last
    }

    /// One frame's step toward `target` at the chase speed formula (slows
    /// apply, capped 0.8), never past the target, never out past the wall.
    static func step(from position: CGPoint, toward target: CGPoint, moveSpeed: CGFloat,
                     slow: CGFloat, dt: TimeInterval, arenaRadius: CGFloat, footprint: CGFloat) -> CGPoint {
        let speed = moveSpeed * (1 - min(max(slow, 0), 0.8))
        let dx = target.x - position.x, dy = target.y - position.y
        let dist = hypot(dx, dy)
        guard dist > 0.0001 else { return position }
        let move = min(dist, speed * CGFloat(dt))
        let next = CGPoint(x: position.x + dx / dist * move, y: position.y + dy / dist * move)
        return clamp(next, toRadius: radiusLimit(of: position, arenaRadius: arenaRadius, footprint: footprint))
    }

    /// One frame of flight (CL-80, F1). First the route-aware `preferred`
    /// target (the steer pass's choice, obeying the route graph); if that step
    /// would bring the body closer to Spark, land in solid, or leave the
    /// allowed radius, the nearest heading to straight-away that doesn't —
    /// away, then ±30°, ±60°, ±90° (the better-separated side first). No such
    /// step: hold still this frame. It never moves toward Spark to satisfy a
    /// clamp or a route.
    static func fleeStep(from position: CGPoint, spark: CGPoint, preferred: CGPoint?,
                         moveSpeed: CGFloat, slow: CGFloat, dt: TimeInterval,
                         arenaRadius: CGFloat, footprint: CGFloat,
                         blocked: (CGPoint) -> Bool) -> CGPoint {
        guard hypot(position.x, position.y) <= arenaRadius else { return position }
        let limit = radiusLimit(of: position, arenaRadius: arenaRadius, footprint: footprint)
        let length = moveSpeed * (1 - min(max(slow, 0), 0.8)) * CGFloat(dt)
        guard length > 0 else { return position }
        let before = hypot(position.x - spark.x, position.y - spark.y)
        func separation(_ q: CGPoint) -> CGFloat { hypot(q.x - spark.x, q.y - spark.y) }
        func acceptable(_ q: CGPoint) -> Bool {
            hypot(q.x - position.x, q.y - position.y) > 1e-9
                && hypot(q.x, q.y) <= limit + tolerance
                && separation(q) >= before - tolerance
                && !blocked(q)
        }
        if let target = preferred {
            let q = step(from: position, toward: target, moveSpeed: moveSpeed, slow: slow, dt: dt,
                         arenaRadius: arenaRadius, footprint: footprint)
            if acceptable(q) { return q }
        }
        let away = awayDirection(from: position, spark: spark)
        for degrees in [CGFloat(0)] + deviations {
            var best: CGPoint?
            for sign: CGFloat in (degrees == 0 ? [1] : [1, -1]) {
                let dir = rotate(away, degrees: sign * degrees)
                let q = clamp(CGPoint(x: position.x + dir.x * length, y: position.y + dir.y * length), toRadius: limit)
                if acceptable(q), best.map({ separation(q) > separation($0) }) ?? true { best = q }
            }
            if let q = best { return q }
        }
        return position
    }
}

// MARK: - CL-76: the primary-volley counter

/// ONE counter per run. A qualifying volley is a primary firing event that
/// emitted at least one primary projectile (ruled Sep 24 — an empty volley is
/// no volley). Every 5th opens a Blackhole (×3), every 7th fires Shadow Edge,
/// so volley 35 does both. Echoes, chains, returned shots, Red Smile, summons
/// and extras never reach it.
struct VolleyCounter {
    struct Tuning: Equatable {
        var blackholeEvery: Int
        var bladeEvery: Int
    }
    struct Result: Equatable {
        var blackhole: Bool
        var blade: Bool
        static let nothing = Result(blackhole: false, blade: false)
    }

    private(set) var volleys = 0

    mutating func register(emitted: Bool, blackholeOwned: Bool, bladeOwned: Bool,
                           tuning: Tuning) -> Result {
        guard emitted else { return .nothing }
        volleys += 1
        return Result(
            blackhole: blackholeOwned && tuning.blackholeEvery > 0 && volleys % tuning.blackholeEvery == 0,
            blade: bladeOwned && tuning.bladeEvery > 0 && volleys % tuning.bladeEvery == 0)
    }

    mutating func reset() { volleys = 0 }
}

/// A projectile that can carry the ×3 Blackhole seed (ProjectileNode).
protocol BlackholeSeedCarrier: AnyObject {
    var seedsBlackhole: Bool { get set }
}

/// One volley's emission (CL-76, review F5 — the harness executes this): did
/// a PRIMARY projectile leave the gun, and which one led? The counter's
/// verdict then seeds that lead shot.
struct VolleyEmission<Shot: BlackholeSeedCarrier> {
    private(set) var emitted = false
    private(set) weak var lead: Shot?

    mutating func begin() {
        emitted = false
        lead = nil
    }

    /// A primary shot left the gun this volley; the first one leads.
    mutating func note(_ shot: Shot) {
        emitted = true
        if lead == nil { lead = shot }
    }

    /// Apply the counter's verdict: a Blackhole volley seeds its lead shot.
    /// Returns the seeded shot, if any. The volley is over either way.
    @discardableResult
    mutating func finish(_ result: VolleyCounter.Result) -> Shot? {
        defer { lead = nil }
        guard result.blackhole, let shot = lead else { return nil }
        shot.seedsBlackhole = true
        return shot
    }
}

enum BlackholeSeed {
    /// The seeded shot stopped (wall, max range, the body it hit): take its
    /// seed — once. true = open a Blackhole where it stopped.
    static func take<S: BlackholeSeedCarrier>(_ shot: S) -> Bool {
        guard shot.seedsBlackhole else { return false }
        shot.seedsBlackhole = false
        return true
    }
}

/// A6's own secondary Void attacks.
enum VoidSecondaryKind: Equatable {
    case none
    /// A hostile shot a black hole absorbed and sent back (CL-4).
    case returned
    /// Shadow Edge's blade (CL-75).
    case shadowEdge
}

/// CL-4 / CL-75 (QB): a returned shot's or Shadow Edge blade's hit, with
/// NAMED effects only — its damage, Void affinity against the Braceguard
/// shield, its own kill credit, and (returned only) Anomaly. One routine the
/// scene runs with its side effects injected, so the harness executes the
/// real rule (independent review F5). No crit, executes, riders, chains,
/// meters, counters or spawns can ride it: it has nowhere to call them.
enum VoidSecondaryHit {
    struct EnemyEffects {
        var flashShield: () -> Void
        var consume: () -> Void
        /// Deal the damage; true = it killed.
        var takeDamage: (Int) -> Bool
        /// Pay the kill through the chokepoint, at this attack's own source.
        var credit: () -> Void
        var stackAnomaly: () -> Void
    }

    struct BossEffects {
        var consume: () -> Void
        /// Deal the damage; the flag skips the flat Boss Mode DEF dial.
        var takeDamage: (_ damage: Int, _ ignoresChallengeDEF: Bool) -> Void
        var isDead: () -> Bool
        var stackAnomaly: () -> Void
    }

    static func onEnemy(kind: VoidSecondaryKind, hit: VoidHit, damage: Int, isDying: Bool,
                        shielded: Bool, shieldMultiplier: CGFloat, effects: EnemyEffects) {
        // A contact queued in the same physics step as the body's death
        // doesn't spend a strike on the corpse.
        guard kind != .none, !isDying else { return }
        var dealt = damage
        if shielded {
            effects.flashShield()   // it flashes; Void affinity goes through
            if !hit.affinity { dealt = max(1, Int(CGFloat(dealt) * shieldMultiplier)) }
        }
        effects.consume()
        if effects.takeDamage(dealt) {
            effects.credit()
        } else if kind == .returned {
            effects.stackAnomaly()
        }
    }

    static func onBoss(kind: VoidSecondaryKind, hit: VoidHit, damage: Int, effects: BossEffects) {
        guard kind != .none else { return }
        effects.consume()
        // Only a shot-class hit penetrates the dial (Phase T2, CL-4/72).
        effects.takeDamage(damage, hit.flatDEFPenetration)
        if kind == .returned, !effects.isDead() { effects.stackAnomaly() }
    }
}

// MARK: - CL-10 / CL-77 / CL-78: the black hole

enum VoidWellPreset: Equatable {
    /// Gravity Well (card): a spent primary shot leaves a pull zone.
    case gravityWell
    /// Null Bloom: kills may leave a small black hole.
    case nullBloom
    /// ×3 Blackhole: every 5th primary volley.
    case blackhole
}

/// One live black hole. Its lifetime, Dead Circuit matter and growth, the
/// hostile projectiles it absorbed (capacity), and the ones it still holds
/// for Listlessness's return.
struct VoidWellState {
    struct DeadCircuit: Equatable {
        var growthPerMatter: CGFloat    // +25% radius per matter
        var collapseAt: Int             // 3
    }

    let id: Int
    let preset: VoidWellPreset
    let baseRadius: CGFloat
    let capacity: Int
    let deadCircuit: DeadCircuit?
    private(set) var life = GameTimer()
    private(set) var matter = 0
    private(set) var absorbed = 0
    /// Countdowns to each held shot's return; ≤ 0 = ready (waiting for a target).
    private(set) var held: [TimeInterval] = []
    /// Reached `collapseAt` — the scene collapses it at its next pass.
    private(set) var collapsePending = false
    /// The scene has ended it (expiry, eviction, collapse) — it does nothing
    /// more, even for the rest of the frame it left in.
    private(set) var ended = false
    private var damageAccumulator: CGFloat = 0

    init(id: Int, preset: VoidWellPreset, baseRadius: CGFloat, lifetime: TimeInterval,
         capacity: Int, deadCircuit: DeadCircuit?) {
        self.id = id
        self.preset = preset
        self.baseRadius = baseRadius
        self.capacity = capacity
        self.deadCircuit = deadCircuit
        life.start(lifetime)
    }

    var radius: CGFloat {
        guard let dc = deadCircuit else { return baseRadius }
        return baseRadius * (1 + dc.growthPerMatter * CGFloat(matter))
    }
    var remaining: TimeInterval { life.remaining }
    /// Accepts captures, absorptions and matter only while live.
    var isLive: Bool { life.isActive && !collapsePending && !ended }
    var readyReturns: Int { held.filter { $0 <= 0 }.count }

    /// Returns true on the tick the lifetime runs out.
    @discardableResult
    mutating func tick(_ dt: TimeInterval) -> Bool {
        // Frame deltas don't sum exactly (nine 1/60s ticks leave dust above
        // 0.15) — the GameTimer epsilon: this close to zero is ready.
        for i in held.indices where held[i] > 0 {
            held[i] -= dt
            if held[i] <= 1e-9 { held[i] = 0 }
        }
        return life.tick(dt)
    }

    /// Absorb one hostile projectile (capacity counts every absorb, returned
    /// or not). `holdForReturn` = Listlessness: keep it to send back.
    mutating func tryAbsorb(holdForReturn: Bool, returnDelay: TimeInterval) -> Bool {
        guard isLive, absorbed < capacity else { return false }
        absorbed += 1
        if holdForReturn { held.append(returnDelay) }
        return true
    }

    /// One unit of Dead Circuit matter (an eligible kill inside it, or an
    /// absorbed hostile projectile). Returns true when this unit reaches the
    /// collapse. Without Dead Circuit, matter means nothing.
    @discardableResult
    mutating func addMatter() -> Bool {
        guard isLive, let dc = deadCircuit else { return false }
        matter += 1
        if matter >= dc.collapseAt { collapsePending = true; return true }
        return false
    }

    /// Take one READY held shot to fire (the scene found a target).
    mutating func takeReadyReturn() -> Bool {
        guard let i = held.firstIndex(where: { $0 <= 0 }) else { return false }
        held.remove(at: i)
        return true
    }

    /// Mark it ended. Returns false if it already was (ending is idempotent).
    mutating func end() -> Bool {
        guard !ended else { return false }
        ended = true
        return true
    }

    /// The well is ending: every shot still held leaves with it.
    mutating func drainHeld() -> Int {
        let n = held.count
        held.removeAll()
        return n
    }

    /// Dead Circuit's damage inside the well, fraction-first: whole damage to
    /// deal to each body inside this frame.
    mutating func damageTick(_ dt: TimeInterval, perSecond: CGFloat) -> Int {
        guard perSecond > 0 else { return 0 }
        damageAccumulator += perSecond * CGFloat(dt)
        let whole = Int(damageAccumulator + 1e-6)
        damageAccumulator -= CGFloat(whole)
        return whole
    }

    /// Is a body centred at `point` inside the hole?
    func contains(_ point: CGPoint, center: CGPoint) -> Bool {
        hypot(point.x - center.x, point.y - center.y) < radius
    }
}

/// Independent review F2: a hole's per-body pass (Dead Circuit damage) runs
/// callbacks that can resolve a death synchronously — and a death can open a
/// Null Bloom that evicts THIS hole. An ended hole acts no further, so its
/// liveness is re-checked before EVERY body, not once per pass.
enum VoidWellPass {
    static func forEachWhileLive<T>(_ bodies: [T], isLive: () -> Bool, _ act: (T) -> Void) {
        for body in bodies {
            guard isLive() else { return }
            act(body)
        }
    }
}

enum VoidWellCap {
    /// Creating a well when `cap` LIVE wells exist (oldest first): remove the
    /// oldest live ordinary Gravity Well; if none, the oldest live well. A
    /// well that is already ending (expired, collapse pending, ended) neither
    /// counts toward the cap nor is chosen — so a hole due to collapse still
    /// bursts (internal review MED-2). Never more than `cap` live (CL-10).
    static func evictionIndex(presets: [VoidWellPreset], live: [Bool], cap: Int) -> Int? {
        guard cap > 0, presets.count == live.count else { return nil }
        let liveIndices = presets.indices.filter { live[$0] }
        guard liveIndices.count >= cap else { return nil }
        return liveIndices.first(where: { presets[$0] == .gravityWell }) ?? liveIndices.first
    }
}

// MARK: - CL-79 / CL-9: Listlessness's trap + Singularity's decomposition

/// One enemy's hold in a black hole. Its own state and timer — it never
/// writes stun or freeze timers, so it can't lengthen or cut short another
/// control (R2). Normals are held until the well ends; a mini-boss for half
/// the well's remaining life at capture, then that well can't take it again.
/// With Singularity a captured normal enters a TERMINAL hold (≤ 2s) that
/// outlives its well, long enough to decompose to death.
struct VoidTrapState {
    struct Tuning: Equatable {
        var terminalHold: TimeInterval          // 2.0
        var decomposeNormal: CGFloat            // 50% max HP/s
        var decomposeMiniBoss: CGFloat          // 8% max HP/s
        var miniBossCapPerTrap: CGFloat         // 20% max HP
    }

    private(set) var wellID: Int? = nil
    private(set) var hold = GameTimer()
    private(set) var terminal = false
    private(set) var targetClass: VoidTargetClass = .normal
    /// Every well that released this mini-boss — none of them can re-trap it.
    private(set) var refusedWellIDs: Set<Int> = []
    /// Max-HP fraction decomposed during THIS trap (the mini-boss cap).
    private(set) var decomposedFraction: CGFloat = 0
    private var accumulator: CGFloat = 0

    var isTrapped: Bool { hold.isActive }

    /// Capture by a live well. Refused for arena bosses, while already held,
    /// and by the well that released this mini-boss before.
    mutating func capture(wellID: Int, wellRemaining: TimeInterval, target: VoidTargetClass,
                          singularity: Bool, tuning: Tuning) -> Bool {
        guard target != .boss, !hold.isActive, wellRemaining > 0,
              !(target == .miniBoss && refusedWellIDs.contains(wellID)) else { return false }
        self.wellID = wellID
        targetClass = target
        decomposedFraction = 0
        accumulator = 0
        switch target {
        case .normal:
            terminal = singularity
            hold.start(singularity ? tuning.terminalHold : wellRemaining)
        case .miniBoss:
            terminal = false
            hold.start(wellRemaining * 0.5)
        case .boss:
            return false
        }
        return true
    }

    /// The holding well ended (expiry, eviction, collapse): release — unless
    /// this is a Singularity terminal hold, which finishes on its own.
    mutating func wellEnded(_ id: Int) {
        guard wellID == id, !terminal else { return }
        release()
    }

    /// Forced exit: death, transformation, launch, cleanup.
    mutating func release() {
        if targetClass == .miniBoss, let id = wellID { refusedWellIDs.insert(id) }
        hold.cancel()
        wellID = nil
        terminal = false
    }

    /// Returns true on the tick the hold runs out.
    @discardableResult
    mutating func tick(_ dt: TimeInterval) -> Bool {
        guard hold.isActive else { return false }
        if hold.tick(dt) {
            release()
            return true
        }
        return false
    }

    /// Singularity: whole damage to deal this frame, fraction-first. A
    /// mini-boss stops at its per-trap cap; nothing decomposes while free.
    mutating func decompose(_ dt: TimeInterval, maxHealth: Int, tuning: Tuning) -> Int {
        guard hold.isActive, maxHealth > 0 else { return 0 }
        var fraction: CGFloat
        switch targetClass {
        case .normal: fraction = tuning.decomposeNormal * CGFloat(dt)
        case .miniBoss:
            fraction = min(tuning.decomposeMiniBoss * CGFloat(dt),
                           max(0, tuning.miniBossCapPerTrap - decomposedFraction))
        case .boss: return 0
        }
        guard fraction > 0 else { return 0 }
        decomposedFraction += fraction
        accumulator += fraction * CGFloat(maxHealth)
        let whole = Int(accumulator + 1e-6)
        accumulator -= CGFloat(whole)
        return whole
    }
}

/// Singularity on an arena boss: never trapped; 1% max HP/s while its body
/// overlaps ANY black hole — one rate however many overlap (CL-9).
struct BossDecompose {
    private var accumulator: CGFloat = 0

    mutating func tick(_ dt: TimeInterval, overlapping: Bool, maxHealth: Int, rate: CGFloat) -> Int {
        guard overlapping, maxHealth > 0, rate > 0 else { return 0 }
        accumulator += rate * CGFloat(dt) * CGFloat(maxHealth)
        let whole = Int(accumulator + 1e-6)
        accumulator -= CGFloat(whole)
        return whole
    }

    mutating func reset() { accumulator = 0 }
}
