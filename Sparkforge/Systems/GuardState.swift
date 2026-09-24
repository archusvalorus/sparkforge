// GuardState.swift
// Sparkforge
//
// v2.1 Abilities A5 (Guard rework): the pure state behind the reworked tree.
// Rulings: closure table §B4 (CL-49…CL-69, Brandon Sep 24). No scene and no
// nodes — Foundation/CoreGraphics only — so every rule is proven by the
// deterministic harness (tools/guard-harness) instead of by feel. GameScene
// ticks these on game time from `update()`, gathers the inputs, and owns the
// FX; PlayerStats holds the run's copies.

import CoreGraphics
import Foundation

// MARK: - Stillness (CL-64 / CL-65)

/// Guard's stand-still accumulator. "Still" means NO meaningful stick input —
/// the joystick is either zero (inside its dead zone) or a unit vector — so a
/// forced shove, a pull or a geometry push-out never breaks it, and pushing the
/// stick into a wall always does (CL-64: one input-based definition across
/// Guard). The scene reads the one signal (`hasInput`); each card keeps its own
/// accumulator from the moment it's owned — Fortify this clock, Grounded Core
/// its combat-gated bank.
struct StillnessClock {
    private(set) var stillSeconds: TimeInterval = 0

    /// Advance one frame. `hasInput` = the stick is outside its dead zone.
    mutating func update(_ dt: TimeInterval, hasInput: Bool) {
        if hasInput {
            stillSeconds = 0
        } else {
            stillSeconds += max(0, dt)
        }
    }

    mutating func reset() { stillSeconds = 0 }
}

// MARK: - Fortify (CL-64)

/// +1 temporary DEF each 0.5s without movement input (= +2/s), capped at +30.
/// Any stick input resets the stack (via Fortify's stillness clock); combat is
/// not required. Pure function of that clock, so it can never drift.
enum FortifyDEF {
    struct Tuning {
        var step: TimeInterval     // 0.5s
        var perStep: Int           // +1
        var cap: Int               // +30
    }

    /// Frame sums leave float dust (ten 0.05s frames are 0.4999…); anything
    /// this close to a step boundary has reached it.
    private static let epsilon: TimeInterval = 1e-9

    static func temporaryDEF(stillSeconds: TimeInterval, tuning: Tuning) -> Int {
        guard stillSeconds > 0, tuning.step > 0 else { return 0 }
        let steps = Int((stillSeconds + epsilon) / tuning.step)
        return min(tuning.cap, max(0, steps * tuning.perStep))
    }
}

// MARK: - Grounded Core (CL-65, MODIFIED Sep 24)

/// +1 PERMANENT DEF for each uninterrupted 7.5s stationary while in active
/// combat, capped at +30 for the run. Unfinished progress resets when active
/// combat ends (no pausing across safe lulls) and when Spark moves; earned
/// points are kept. Death/revive resets unfinished progress only.
struct GroundedCoreBank {
    struct Tuning {
        var interval: TimeInterval  // 7.5s
        var cap: Int                // +30 per run
    }

    let tuning: Tuning
    /// Points earned this run (the scene adds each one to base DEF, CL-51).
    private(set) var earned = 0
    /// Seconds toward the next point.
    private(set) var progress: TimeInterval = 0

    init(tuning: Tuning) { self.tuning = tuning }

    var isCapped: Bool { earned >= tuning.cap }
    /// 0…1 toward the next point — the tell's arc.
    var fraction: CGFloat {
        guard !isCapped, tuning.interval > 0 else { return 0 }
        return CGFloat(min(1, progress / tuning.interval))
    }

    private static let epsilon: TimeInterval = 1e-9

    /// Advance one frame. Returns the points newly earned this frame (usually
    /// 0, at most one per interval of `dt`).
    @discardableResult
    mutating func update(_ dt: TimeInterval, still: Bool, inCombat: Bool) -> Int {
        guard !isCapped else { progress = 0; return 0 }
        // CL-65: movement OR the end of active combat resets unfinished progress.
        guard still, inCombat else { progress = 0; return 0 }
        progress += max(0, dt)
        var gained = 0
        while progress + Self.epsilon >= tuning.interval, earned < tuning.cap {
            progress = max(0, progress - tuning.interval)
            earned += 1
            gained += 1
        }
        if isCapped { progress = 0 }
        return gained
    }

    /// Death / revive: earned DEF persists, the unfinished interval does not.
    mutating func resetProgress() { progress = 0 }

    /// A new run.
    mutating func reset() {
        earned = 0
        progress = 0
    }
}

// MARK: - Ironhide (CL-52)

/// 9% damage reduction per qualifying nearby hostile, capped at 10
/// contributors (90%). The scene counts; this is the curve. The shared 90%
/// ceiling is the pipeline's job (Aegis multiplies inside it).
enum Ironhide {
    struct Tuning {
        var perHostile: CGFloat     // 0.09
        var maxContributors: Int    // 10
    }

    static func reduction(contributors: Int, tuning: Tuning) -> CGFloat {
        CGFloat(min(max(0, contributors), tuning.maxContributors)) * tuning.perHostile
    }

    /// Does this body count? Hittable (not phased / vanished / dying), not a
    /// harmless snowman, and its SURFACE within the radius. (An arena boss is
    /// one contributor, measured the same way.)
    static func qualifies(surfaceDistance: CGFloat, radius: CGFloat,
                          hittable: Bool, snowman: Bool) -> Bool {
        hittable && !snowman && surfaceDistance < radius
    }
}

// MARK: - Contact retaliation on boss-class (CL-53 / CL-67)

/// The boss-lever arithmetic for Guard's contact retaliation, applied ONCE
/// before the mechanic's own rounding.
enum GuardRetaliation {
    /// Thornwall (CL-53): `multiplier` × the valid contact's pre-mitigation
    /// hit; an ARENA boss (only) takes it through the boss lever. Min 1.
    static func thornwall(raw: Int, multiplier: CGFloat, isArenaBoss: Bool, bossScale: CGFloat) -> Int {
        max(1, Int(CGFloat(raw) * multiplier * (isArenaBoss ? bossScale : 1)))
    }

    /// Iron Maiden thorns (CL-67): a flat bite; boss-class (mini-boss or arena
    /// boss) takes it through the capstone lever, rounded like
    /// `BossClass.scaledDamage`. Min 1 when scaled.
    static func ironThorns(_ base: Int, isBossClass: Bool, bossScale: CGFloat) -> Int {
        isBossClass ? max(1, Int((CGFloat(base) * bossScale).rounded())) : base
    }

    /// Iron Maiden Retaliate (CL-67): a fraction of the pre-mitigation hit,
    /// boss-class through the capstone lever, truncated as before.
    static func ironRetaliate(raw: Int, fraction: CGFloat, isBossClass: Bool, bossScale: CGFloat) -> Int {
        Int(CGFloat(raw) * fraction * (isBossClass ? bossScale : 1))
    }
}

// MARK: - Unbroken Core's window (CL-55 / CL-56)

/// The 10s full-invulnerability window the Unbroken rescue opens, on its OWN
/// game-time timer — never the scene's shared `invulnerableTimer`, which
/// unpause, level-up, the boss reveal and the Remove-Ads prompt overwrite.
/// At the rescue it snapshots current DEF and the ATK the conversion reads, and
/// holds `bonus multiplier = DEF / max(1, ATK)` fixed for the whole window:
/// "+ATK equal to DEF" expressed in the gun's multiplier model.
struct UnbrokenWindow {
    private var timer = GameTimer()
    private(set) var bonusMultiplier: CGFloat = 0
    private(set) var snappedDEF = 0
    private(set) var snappedATK: CGFloat = 0

    var isActive: Bool { timer.isActive }
    var remaining: TimeInterval { timer.remaining }

    /// The ruled conversion (CL-56).
    static func bonusMultiplier(def: Int, atk: CGFloat) -> CGFloat {
        CGFloat(max(0, def)) / max(1, atk)
    }

    /// Open (or re-open) the window with a fresh snapshot.
    mutating func open(duration: TimeInterval, def: Int, atk: CGFloat) {
        snappedDEF = max(0, def)
        snappedATK = atk
        bonusMultiplier = Self.bonusMultiplier(def: def, atk: atk)
        timer.start(duration)
    }

    /// Advance one frame. Returns true on the tick the window closes.
    @discardableResult
    mutating func tick(_ dt: TimeInterval) -> Bool {
        guard timer.isActive else { return false }
        let closed = timer.tick(dt)
        if closed { bonusMultiplier = 0 }
        return closed
    }

    /// Death / restart end it early.
    mutating func end() {
        timer.cancel()
        bonusMultiplier = 0
    }
}

// MARK: - Unbroken Core's projectile shield (CL-57)

/// Guard ×7's persistent shield: blocks one hostile projectile, then rearms
/// after 6s. Independent of whether the rescue has fired. Invulnerability
/// takes precedence — a projectile that couldn't hurt Spark anyway never
/// spends the block (the scene checks i-frames and the damage cooldown first;
/// `tryBlock` refuses while the Unbroken window is open as a second line).
struct ProjectileShieldCharge {
    let rearm: TimeInterval
    private(set) var isOwned = false
    private var cooldown = GameTimer()

    init(rearm: TimeInterval) { self.rearm = rearm }

    var isReady: Bool { isOwned && !cooldown.isActive }
    /// 0 just after a block → 1 when ready again (the tell).
    var readiness: CGFloat {
        guard isOwned else { return 0 }
        guard cooldown.isActive, rearm > 0 else { return 1 }
        return CGFloat(1 - cooldown.remaining / rearm)
    }

    /// Guard ×7 equips it, ready.
    mutating func grant() { isOwned = true }

    /// Block a projectile if ready. Never spends while `invulnerable`.
    mutating func tryBlock(invulnerable: Bool) -> Bool {
        guard isReady, !invulnerable else { return false }
        cooldown.start(rearm)
        return true
    }

    /// Advance one frame. Returns true on the tick it rearms.
    @discardableResult
    mutating func tick(_ dt: TimeInterval) -> Bool {
        guard isOwned else { return false }
        return cooldown.tick(dt)
    }

    mutating func reset() {
        isOwned = false
        cooldown.cancel()
    }
}

// MARK: - Contact bounce (CL-58 Aegis T2/T3, CL-59 Harden)

/// Harden and Aegis share ONE bounce: on EVERY real touch-begin (the confirmed
/// CL-59 reading — contact is edge-triggered, so there is no resting-body case
/// to throttle), the contacting enemy is shoved away by the largest owned
/// distance, and Aegis (T2+) adds its spike of current DEF. The bounce never
/// creates damage to Spark.
enum ContactBounce {
    struct Tuning {
        var harden: CGFloat              // 40
        var aegisByTier: [CGFloat]       // index = tier − 1: [0, 40, 70]
        var spikeByTier: [CGFloat]       // index = tier − 1: [0, 0.50, 0.75]
    }

    /// Shove distance, 0 when nothing bounces.
    static func distance(hardenOwned: Bool, aegisTier: Int, tuning: Tuning) -> CGFloat {
        var d: CGFloat = hardenOwned ? tuning.harden : 0
        if aegisTier >= 1, aegisTier <= tuning.aegisByTier.count {
            d = max(d, tuning.aegisByTier[aegisTier - 1])
        }
        return d
    }

    /// The Aegis spike on a qualifying bounce — `max(1, Int(fraction × DEF))`,
    /// or 0 when this tier has no spike.
    static func spikeDamage(aegisTier: Int, currentDEF: Int, tuning: Tuning) -> Int {
        guard aegisTier >= 1, aegisTier <= tuning.spikeByTier.count else { return 0 }
        let fraction = tuning.spikeByTier[aegisTier - 1]
        guard fraction > 0 else { return 0 }
        return max(1, Int(fraction * CGFloat(max(0, currentDEF))))
    }
}

// MARK: - Iron Bloom (CL-60 / CL-61)

/// Every 4s (game time) a radial spike pulse for 50% of current DEF. Piercing
/// (CL-61) = bypasses FLAT enemy DEF only — in today's runtime, the Boss Mode
/// DEF dial — which the scene expresses through the existing
/// `takeDamage(_:ignoresChallengeDEF: true)` route. No new damage type.
enum IronBloom {
    static func pulseDamage(currentDEF: Int, fraction: CGFloat) -> Int {
        max(1, Int(fraction * CGFloat(max(0, currentDEF))))
    }
}

// MARK: - Repulse T3 launch (CL-62 / CL-63, MODIFIED Sep 24)

/// One launched enemy's flight: up to 400pt over a short, decelerating path.
/// It collides with up to 3 other ordinary enemies (normals and elites — never
/// boss-class), each at most once per launch. The scene stops it at walls and
/// the Carrier. Collision damage is 25% of current ATK with the integer
/// convention (min 1).
struct RepulseFlight {
    struct Tuning {
        var distance: CGFloat        // 400
        var duration: TimeInterval   // 0.35s
        var maxStrikes: Int          // 3
    }

    let tuning: Tuning
    /// Unit direction of travel.
    let direction: CGPoint
    private(set) var elapsed: TimeInterval = 0
    private(set) var isLanded = false
    private(set) var struck: Set<ObjectIdentifier> = []

    init(direction: CGPoint, tuning: Tuning) {
        let len = (direction.x * direction.x + direction.y * direction.y).squareRoot()
        self.direction = len > 0 ? CGPoint(x: direction.x / len, y: direction.y / len) : CGPoint(x: 0, y: 1)
        self.tuning = tuning
        if tuning.distance <= 0 || tuning.duration <= 0 { isLanded = true }
    }

    /// Ease-out: fraction of the distance covered at progress `u` ∈ [0, 1].
    static func coverage(_ u: CGFloat) -> CGFloat {
        let c = min(max(u, 0), 1)
        return 1 - (1 - c) * (1 - c)
    }

    /// Distance covered so far.
    var traveled: CGFloat {
        tuning.distance * Self.coverage(CGFloat(elapsed / tuning.duration))
    }

    /// Advance one frame; returns this frame's displacement (zero once landed).
    mutating func advance(_ dt: TimeInterval) -> CGPoint {
        guard !isLanded else { return .zero }
        let before = traveled
        elapsed = min(tuning.duration, elapsed + max(0, dt))
        let step = traveled - before
        if elapsed >= tuning.duration { isLanded = true }
        return CGPoint(x: direction.x * step, y: direction.y * step)
    }

    /// Strikes left. The scene tests each step's path — the step that lands
    /// included — and drops a flight once it has landed, so nothing strikes
    /// after touchdown.
    var canStrike: Bool { struck.count < tuning.maxStrikes }

    /// Record a collision with `target`. False if this launch already struck
    /// it or has used its strikes.
    mutating func strike(_ target: ObjectIdentifier) -> Bool {
        guard canStrike, !struck.contains(target) else { return false }
        struck.insert(target)
        return true
    }

    /// Who is ever launched: ordinary enemies only (CL-63 build reading:
    /// normals and elites). Mini-bosses take the T1 shove; snowmen never fly.
    static func isLaunchable(isMiniBoss: Bool, isSnowman: Bool) -> Bool {
        !isMiniBoss && !isSnowman
    }

    /// Repulse's shove when a hit doesn't launch (A5 gate rulings, Sep 24):
    /// ordinary enemies take their tier's distance; mini-bosses a fixed T1
    /// shove at every tier (Q4); snowmen are fully knockback-immune (Q3).
    /// (Arena bosses never reach Repulse — they resist knockback.)
    static func shoveDistance(tierShove: CGFloat, t1Shove: CGFloat,
                              isMiniBoss: Bool, isSnowman: Bool) -> CGFloat {
        if isSnowman { return 0 }
        return isMiniBoss ? min(tierShove, t1Shove) : tierShove
    }

    /// Who can be a bowling pin: hittable ordinary enemies — never boss-class
    /// (arena bosses aren't in the enemy list at all), and never a snowman,
    /// which takes no part in Repulse at all (Q3).
    static func isPin(isMiniBoss: Bool, isSnowman: Bool, isHittable: Bool) -> Bool {
        !isMiniBoss && !isSnowman && isHittable
    }

    /// Distance from `p` to the segment a→b.
    static func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let abx = b.x - a.x, aby = b.y - a.y
        let len2 = abx * abx + aby * aby
        var t: CGFloat = 0
        if len2 > 0 { t = min(1, max(0, ((p.x - a.x) * abx + (p.y - a.y) * aby) / len2)) }
        let dx = p.x - (a.x + abx * t), dy = p.y - (a.y + aby * t)
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Did a body swept along a→b (radius folded into `radius`) touch a pin at
    /// `center`? Tested along the whole step, not just where it ended — a
    /// 37pt first step would otherwise skip pins beside the line.
    static func sweepOverlaps(from a: CGPoint, to b: CGPoint, center: CGPoint, radius: CGFloat) -> Bool {
        distance(from: center, toSegment: a, b) < radius
    }

    /// Walls and the Carrier stop the launch.
    mutating func land() { isLanded = true }

    /// 25% of current ATK, integer convention, minimum 1 (CL-63).
    static func collisionDamage(effectiveAttack: CGFloat, fraction: CGFloat) -> Int {
        max(1, Int(fraction * max(0, effectiveAttack)))
    }
}
