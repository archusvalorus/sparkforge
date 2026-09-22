// main.swift — deterministic validators for v2.1 abilities Unit A0: the
// player damage order (closure table CL-5 §D), Blood Barrier, lethal rescue
// ordering, kill-credit tiers and game-time timers. Each validator prints
// PASS/FAIL; exit 1 on any FAIL.

import CoreGraphics
import Foundation

var passed = 0, failed = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1; print("PASS  \(name)") }
    else { failed += 1; print("FAIL  \(name)  \(detail())") }
}

// Mirrors GameConfig: ForgePath.drCap / unyieldingThreshold / unyieldingReduction,
// Panda.kaijuDamageReduction, and the A0 values approved in CL-5 + Q-B3.
let tuning = PlayerDamagePipeline.Tuning(
    reductionCeiling: 0.90, forgeBucketCap: 0.60,
    unyieldingThreshold: 0.20, unyieldingMultiplier: 0.5,
    kaijuReduction: 0.85, barrierCapFraction: 0.5, barrierExpiry: 4.0)

typealias Hit = PlayerDamagePipeline.Hit
typealias Defender = PlayerDamagePipeline.Defender
func resolve(_ h: Hit, _ d: Defender) -> PlayerDamagePipeline.Outcome {
    PlayerDamagePipeline.resolve(h, against: d, tuning: tuning)
}

// The pre-A0 enemy-hit math, transcribed from 0806262:
// GameScene.applyPlayerDamage (5779–5833) + PlayerStats.takeDamage (181–203).
// Returns the float after the % layer too, so the ceiling test can use the
// identical expression the pipeline uses.
func legacy(raw: Int, dial: CGFloat, unyieldingReady: Bool, maxHP: Int,
            bucket: CGFloat, kaiju: Bool, def: Int, hp: Int)
    -> (pctFloat: CGFloat, scaled: CGFloat, damage: Int, hpAfter: Int, died: Bool) {
    var dmg = CGFloat(raw)
    if dial != 1 { dmg *= dial }
    let scaled = dmg
    if unyieldingReady, CGFloat(raw) > CGFloat(maxHP) * 0.20 { dmg *= 0.5 }
    let dr = min(bucket, 0.6)
    if dr > 0 { dmg *= (1 - dr) }
    if kaiju { dmg *= (1 - 0.85) }
    let pctFloat = dmg
    let reduced = max(1, max(1, Int(dmg)) - def)
    var after = hp - reduced
    if after < 0 { after = 0 }
    return (pctFloat, scaled, reduced, after, after <= 0)
}

// Every combination of the five real Forge Path DR sources, ignoring the
// forks (so the bucket is stressed past what a player can own), plus a
// synthetic over-cap bucket.
let drSources: [CGFloat] = [0.05, 0.10, 0.08, 0.10, 0.25]
var buckets: [CGFloat] = []
for mask in 0..<(1 << drSources.count) {
    var sum: CGFloat = 0
    for (i, v) in drSources.enumerated() where mask & (1 << i) != 0 { sum += v }
    buckets.append(sum)
}
buckets.append(0.75)

// P1/P2 — legacy parity everywhere the ceiling doesn't clamp; the ceiling's
// number everywhere legacy went past 90%.
do {
    var parityCases = 0, parityFails = 0, ceilingCases = 0, ceilingFails = 0
    var firstFail = ""
    for raw in [1, 2, 5, 9, 10, 15, 20, 21, 33, 50, 64, 99, 100, 150, 240] {
        for dial: CGFloat in [1, 0.5, 1.5, 2] {
            for maxHP in [100, 250] {
                for unyielding in [false, true] {
                    for bucket in buckets {
                        for kaiju in [false, true] {
                            for def in [0, 3, 10, 25] {
                                for hp in [1, 10, 100] {
                                    let l = legacy(raw: raw, dial: dial, unyieldingReady: unyielding,
                                                   maxHP: maxHP, bucket: bucket, kaiju: kaiju, def: def, hp: hp)
                                    let o = resolve(Hit(raw: raw, inputScale: dial, forgeBucket: bucket,
                                                        unyieldingReady: unyielding, kaijuActive: kaiju,
                                                        flatDEF: def),
                                                    Defender(currentHP: hp, maxHP: maxHP))
                                    if l.pctFloat < l.scaled * (1 - 0.90) {
                                        ceilingCases += 1
                                        let floor = ((l.scaled * 0.1) * 1_000_000).rounded() / 1_000_000
                                        let expect = max(1, max(1, Int(floor)) - def)
                                        if !o.ceilingApplied || o.damage != expect {
                                            ceilingFails += 1
                                            if firstFail.isEmpty { firstFail = "ceiling raw=\(raw) dial=\(dial) b=\(bucket) k=\(kaiju) def=\(def): got \(o.damage) want \(expect)" }
                                        }
                                    } else {
                                        parityCases += 1
                                        if o.ceilingApplied || o.damage != l.damage || o.hpAfter != l.hpAfter || o.died != l.died {
                                            parityFails += 1
                                            if firstFail.isEmpty { firstFail = "parity raw=\(raw) dial=\(dial) b=\(bucket) k=\(kaiju) def=\(def) hp=\(hp): got \(o.damage)/\(o.hpAfter) want \(l.damage)/\(l.hpAfter)" }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    check("P1 legacy parity: every unclamped hit resolves to the pre-A0 number (\(parityCases) cases)",
          parityFails == 0 && parityCases > 0, "\(parityFails) fails; \(firstFail)")
    check("P2 hits legacy reduced past 90% now land exactly on the ceiling (\(ceilingCases) cases)",
          ceilingFails == 0 && ceilingCases > 0, "\(ceilingFails) fails; \(firstFail)")
}

// P3 — the CL-5 interactions A0 must explicitly verify.
do {
    let fresh = Defender(currentHP: 1000, maxHP: 100)

    let kaiju = resolve(Hit(raw: 100, kaijuActive: true), fresh)
    check("P3a kaiju alone keeps its full 85% (ruling: inside the ceiling, no exception)",
          kaiju.damage == 15 && !kaiju.ceilingApplied, "got \(kaiju.damage)")

    // Unyielding (0.5) × max real bucket (Last Stand 10 + Giantkiller 10 +
    // Braced 25 = 45%) × kaiju = 95.9% under legacy → the ceiling.
    let stack = resolve(Hit(raw: 100, forgeBucket: 0.45, unyieldingReady: true, kaijuActive: true), fresh)
    check("P3b Unyielding + Forge Path bucket + kaiju are capped at 90% (legacy: 95.9%)",
          stack.ceilingApplied && stack.damage == 10 && abs(stack.reduction - 0.90) < 1e-9,
          "got \(stack.damage) r=\(stack.reduction)")

    let noKaiju = resolve(Hit(raw: 100, forgeBucket: 0.45, unyieldingReady: true), fresh)
    check("P3c Unyielding + bucket without kaiju (72.5%) is below the ceiling and unchanged",
          !noKaiju.ceilingApplied && noKaiju.damage == 27, "got \(noKaiju.damage)")

    check("P3d Unyielding fires once per resolved qualifying hit and reports it",
          stack.unyieldingFired && !resolve(Hit(raw: 100, forgeBucket: 0.45), fresh).unyieldingFired)

    let ironAegis = resolve(Hit(raw: 100, ironhide: 0.90, aegis: 0.35), fresh)
    check("P3e A5 slots: Ironhide 90% + Aegis 35% hold at 90%",
          ironAegis.ceilingApplied && ironAegis.damage == 10, "got \(ironAegis.damage)")

    let kaijuIron = resolve(Hit(raw: 1000, ironhide: 0.90, kaijuActive: true), Defender(currentHP: 5000, maxHP: 100))
    check("P3f kaiju × Ironhide 90% is 90%, not 98.5%",
          kaijuIron.damage == 100, "got \(kaijuIron.damage)")

    let bucketCap = resolve(Hit(raw: 100, forgeBucket: 0.75), fresh)
    check("P3g the Forge Path bucket stays capped at 60% as one factor",
          bucketCap.damage == 40, "got \(bucketCap.damage)")
}

// P4 — flat DEF after the % layer, floor of 1.
do {
    let d = Defender(currentHP: 100, maxHP: 100)
    check("P4a flat DEF can't zero a hit (5 raw vs 100 DEF = 1)",
          resolve(Hit(raw: 5, flatDEF: 100), d).damage == 1)
    check("P4b DEF applies after the ceiling (100 raw, 90% clamp, 4 DEF = 6)",
          resolve(Hit(raw: 100, ironhide: 0.95, flatDEF: 4), d).damage == 6)
    check("P4c a zero raw hit still lands for 1 (legacy floor)",
          resolve(Hit(raw: 0), d).damage == 1)
}

// P5 — one lethal event, exactly one rescue; Brace first, then Unbroken Core.
do {
    let stats = PlayerStats()
    stats.maxHP = 100; stats.currentHP = 10
    stats.lethalSaves = 1
    stats.unbrokenRescueAvailable = true

    let first = resolve(Hit(raw: 50), stats.damageDefender)
    stats.commit(first)
    check("P5a first lethal: Brace only, survive at 1 HP",
          first.rescue == .brace && !first.died && stats.currentHP == 1
            && stats.lethalSaves == 0 && stats.unbrokenRescueAvailable,
          "rescue=\(first.rescue) hp=\(stats.currentHP) saves=\(stats.lethalSaves) unbroken=\(stats.unbrokenRescueAvailable)")

    let second = resolve(Hit(raw: 50), stats.damageDefender)
    stats.commit(second)
    check("P5b second lethal: Unbroken Core, survive at 1 HP",
          second.rescue == .unbrokenCore && !second.died && stats.currentHP == 1 && !stats.unbrokenRescueAvailable)

    let third = resolve(Hit(raw: 50), stats.damageDefender)
    stats.commit(third)
    check("P5c third lethal: no rescue left, death is final at 0 HP",
          third.rescue == .none && third.died && stats.currentHP == 0)

    let onlyUnbroken = resolve(Hit(raw: 50), Defender(currentHP: 10, maxHP: 100, unbrokenAvailable: true))
    check("P5d Unbroken Core alone rescues", onlyUnbroken.rescue == .unbrokenCore && !onlyUnbroken.died)

    let nonLethal = resolve(Hit(raw: 5), Defender(currentHP: 10, maxHP: 100, braceAvailable: true, unbrokenAvailable: true))
    check("P5e a non-lethal hit spends nothing", nonLethal.rescue == .none && !nonLethal.wasLethal && nonLethal.hpAfter == 5)

    let exact = resolve(Hit(raw: 10), Defender(currentHP: 10, maxHP: 100, braceAvailable: true))
    check("P5f landing on exactly 0 HP is lethal (legacy: HP <= 0) and rescued", exact.wasLethal && exact.rescue == .brace)
}

// P6–P8 — Blood Barrier before health.
do {
    let overflow = resolve(Hit(raw: 50), Defender(currentHP: 100, maxHP: 100, barrier: 20))
    check("P6 barrier overflow continues into HP (20 absorbed, 30 to HP)",
          overflow.absorbed == 20 && overflow.toHP == 30 && overflow.hpAfter == 70 && overflow.barrierAfter == 0)

    let stats = PlayerStats()
    stats.maxHP = 100; stats.currentHP = 1; stats.lethalSaves = 1
    stats.bloodBarrier.gain(50, maxHP: 100, tuning: tuning)
    let everglowBefore = stats.everglowPulseGrowth
    stats.everglowRageScaling = true
    let barrierOnly = resolve(Hit(raw: 40), stats.damageDefender)
    stats.commit(barrierOnly)
    check("P7a barrier-only hit at 1 HP: a HIT (Overcharge/Defiant fire), nothing to health",
          barrierOnly.isHit && barrierOnly.barrierOnly && barrierOnly.toHP == 0 && stats.currentHP == 1)
    check("P7b barrier-only hit never consumes a rescue",
          !barrierOnly.wasLethal && barrierOnly.rescue == .none && stats.lethalSaves == 1)
    check("P7c barrier spent by the hit, not refreshed", stats.bloodBarrier.amount == 10)
    check("P7d Everglow rage still grows on a barrier-only hit (every hit is a hit)",
          stats.everglowPulseGrowth > everglowBefore)

    let pierce = resolve(Hit(raw: 30), Defender(currentHP: 5, maxHP: 100, barrier: 10, braceAvailable: true))
    check("P8 overflow that kills goes through rescue handling (10 absorbed, 20 lethal → Brace)",
          pierce.absorbed == 10 && pierce.toHP == 20 && pierce.rescue == .brace && pierce.hpAfter == 1)
}

// P9 — Blood Barrier pool rules (Q-B3) on game time.
do {
    var b = BloodBarrier()
    check("P9a gain caps at 50% max HP", b.gain(80, maxHP: 100, tuning: tuning) == 50 && b.amount == 50)
    b.tick(3.9)
    check("P9b still up at 3.9s", b.amount == 50)
    check("P9c a grant on a full pool adds nothing but refreshes the 4s expiry",
          b.gain(5, maxHP: 100, tuning: tuning) == 0 && b.expiry.remaining == 4.0)
    b.tick(3.9)
    check("P9d refreshed pool survives another 3.9s", b.amount == 50)
    b.spend(20)
    check("P9e spending doesn't refresh", b.amount == 30 && abs(b.expiry.remaining - 0.1) < 1e-9)
    check("P9f zero/negative grants neither add nor refresh",
          b.gain(0, maxHP: 100, tuning: tuning) == 0 && b.gain(-5, maxHP: 100, tuning: tuning) == 0
            && abs(b.expiry.remaining - 0.1) < 1e-9)
    b.tick(0.2)
    check("P9g pool empties when the expiry runs out", b.amount == 0)

    var paused = BloodBarrier()
    paused.gain(30, maxHP: 100, tuning: tuning)
    // A paused run never ticks — the pool must still be there on resume.
    check("P9h no ticks (paused run) = no expiry", paused.amount == 30 && paused.expiry.remaining == 4.0)

    let stats = PlayerStats()
    stats.bloodBarrier.gain(30, maxHP: 100, tuning: tuning)
    stats.unbrokenRescueAvailable = true
    stats.reset()
    var trim = BloodBarrier()
    trim.gain(50, maxHP: 100, tuning: tuning)            // 50 = the cap at 100 max HP
    let trimmed = trim.gain(2, maxHP: 60, tuning: tuning) // max HP fell to 60 → cap 30
    check("P9j v2.1 A4b: a pool above a LOWERED cap trims to it on the next grant (never kept over cap)",
          trim.amount == 30 && trimmed == 0 && abs(trim.expiry.remaining - 4.0) < 1e-9, "amount=\(trim.amount)")
    check("P9i run reset clears the barrier and the Unbroken rescue",
          stats.bloodBarrier.amount == 0 && !stats.unbrokenRescueAvailable)
}

// P10 — Unyielding's threshold (legacy: the PRE-dial hit).
do {
    let d = Defender(currentHP: 1000, maxHP: 100)
    check("P10a exactly 20% of max HP does not qualify", !resolve(Hit(raw: 20, unyieldingReady: true), d).unyieldingFired)
    check("P10b 21% qualifies and halves", {
        let o = resolve(Hit(raw: 21, unyieldingReady: true), d)
        return o.unyieldingFired && o.damage == 10
    }())
    check("P10c threshold reads the pre-dial hit (15 raw × 2.0 dial doesn't qualify)",
          !resolve(Hit(raw: 15, inputScale: 2, unyieldingReady: true), d).unyieldingFired)
    check("P10d on cooldown never fires", !resolve(Hit(raw: 90), d).unyieldingFired)
}

// P11 — kill-credit tiers.
do {
    let rewardOnly = KillSource.allCases.filter { $0.credit == .rewardOnly }
    check("P11a only bursts and the sweep are XP-only (legacy)",
          Set(rewardOnly) == [.burst, .sweep], "got \(rewardOnly)")
    check("P11b every other source is a full kill",
          KillSource.allCases.filter { $0.credit == .full }.count == KillSource.allCases.count - 2)
}

// P12 — game-time timers.
do {
    var t = GameTimer()
    t.start(1.0)
    let a = t.tick(0.6), b = t.tick(0.6), c = t.tick(0.6)
    check("P12a a timer reports its expiry exactly once", !a && b && !c && !t.isActive)
    t.start(1.0); t.extend(atLeast: 0.5)
    check("P12b extend keeps the longer duration", t.remaining == 1.0)
    t.extend(atLeast: 2.0)
    check("P12c extend lengthens", t.remaining == 2.0)

    var w = DelayedWindow()
    w.schedule(after: 0.5, lasting: 1.0)
    var events: [DelayedWindow.Event] = []
    for _ in 0..<20 { let e = w.tick(0.1); if e != .none { events.append(e) } }
    check("P12d a delayed window opens once, then closes once", events == [.opened, .closed], "got \(events)")

    var frozen = DelayedWindow()
    frozen.schedule(after: 0.5, lasting: 1.0)
    check("P12e an unticked window never opens (pause-safe)", frozen.isPending && !frozen.isOpen)

    var re = DelayedWindow()
    re.schedule(after: 0.2, lasting: 1.0)
    _ = re.tick(0.3)
    re.schedule(after: 0.2, lasting: 1.0)
    check("P12f rescheduling replaces an open window", re.isPending && !re.isOpen)
}


// P10 — v2.1 A4b (independent review, finding 1): an existing barrier
// reconciles the moment MAX HP drops below what it can support.
do {
    var b = BloodBarrier()
    b.gain(50, maxHP: 100, tuning: tuning)          // cap 50 at 100 max HP
    b.tick(1.0)                                     // expiry now 3.0s in
    let before = b.expiry.remaining
    b.clampToCap(maxHP: 50, capFraction: 0.5)       // Glass Engine: cap is now 25
    check("P10a a max-HP drop clamps the pool to the new cap at once (50 → 25)", b.amount == 25)
    check("P10b the reconciliation is NOT a grant: the expiry is untouched",
          abs(b.expiry.remaining - before) < 1e-9, "remaining=\(b.expiry.remaining) was \(before)")

    // The reviewer's case: 45 damage against the reconciled pool.
    let out = resolve(Hit(raw: 45), Defender(currentHP: 50, maxHP: 50, barrier: b.amount))
    check("P10c after the clamp a 45 hit absorbs 25 and sends 20 through to HP",
          out.absorbed == 25 && out.toHP == 20, "absorbed=\(out.absorbed) toHP=\(out.toHP)")

    var under = BloodBarrier()
    under.gain(10, maxHP: 100, tuning: tuning)
    let untouched = under.expiry.remaining
    under.clampToCap(maxHP: 50, capFraction: 0.5)   // 10 is already under the new cap of 25
    check("P10d a pool already under the new cap is left alone",
          under.amount == 10 && abs(under.expiry.remaining - untouched) < 1e-9)

    var grown = BloodBarrier()
    grown.gain(50, maxHP: 100, tuning: tuning)
    grown.clampToCap(maxHP: 200, capFraction: 0.5)  // max HP ROSE: nothing to reconcile
    check("P10e a max-HP rise never changes the pool", grown.amount == 50)

    // The hook itself: PlayerStats reconciles on any max-HP drop.
    let stats = PlayerStats()
    stats.maxHP = 100
    stats.bloodBarrier.gain(50, maxHP: stats.maxHP, tuning: tuning)
    stats.bloodBarrier.tick(1.0)
    let statsExpiry = stats.bloodBarrier.expiry.remaining
    stats.maxHP = 50                                 // Glass Engine / Mass Tax
    check("P10f PlayerStats reconciles the barrier whenever max HP falls, expiry intact",
          stats.bloodBarrier.amount == 25 && abs(stats.bloodBarrier.expiry.remaining - statsExpiry) < 1e-9,
          "barrier=\(stats.bloodBarrier.amount)")
    stats.maxHP = 200
    check("P10g …and leaves it alone when max HP rises", stats.bloodBarrier.amount == 25)
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
