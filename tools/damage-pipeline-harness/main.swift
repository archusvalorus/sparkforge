// main.swift — deterministic validators for v2.1 abilities Unit A0: the
// player damage order (closure table CL-5 §D), Blood Barrier, lethal rescue
// ordering, kill-credit tiers and game-time timers. A7b S6 adds VC: the four
// independent vulnerability channels a body takes damage through (CL-107/116).
// A7b S7 adds DH: the direct-hit amplifier block, rounded once (CL-94/114/115).
// A7b S8 adds DH9–DH12: the vulnerability fold, the Overcharge split (CL-114) and the shield.
// Each validator prints PASS/FAIL; exit 1 on any FAIL.

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
    stats.maxHP = 50                                 // Glass Engine
    check("P10f PlayerStats reconciles the barrier whenever max HP falls, expiry intact",
          stats.bloodBarrier.amount == 25 && abs(stats.bloodBarrier.expiry.remaining - statsExpiry) < 1e-9,
          "barrier=\(stats.bloodBarrier.amount)")
    stats.maxHP = 200
    check("P10g …and leaves it alone when max HP rises", stats.bloodBarrier.amount == 25)
}

// VC — independent vulnerability channels (A7b S6, G1.8: CL-107 + CL-116).
// Four sources (Frostbite, Marked, Called, Fracture) each own a channel; a body
// takes the STRONGEST active one, never a stack; each source clears only
// itself. Executed on the REAL VulnerabilityChannels (and the shared
// VulnerabilityCarrier accessor every body reads), with the REAL per-source
// values: Fracture and BossClass from the extracted config, the other three read
// from the app's GameConfig.swift (their Stubs mirrors don't carry them). `Body`
// below drives the channels with EnemyNode's own timers (GameTimer,
// DelayedWindow) exactly as its applyFracture / scheduleFrostbite /
// updateStatusEffects do — that wiring, the scene's Called / Marked writers and
// every boss conformer are pinned on the executable view by catalog WR12.
do {
    typealias V = VulnerabilityChannels
    let configText = (try? String(contentsOfFile: ProcessInfo.processInfo.environment["DP_CONFIG"] ?? "", encoding: .utf8)) ?? ""
    func configValue(_ key: String) -> CGFloat {
        guard let r = configText.range(of: "static let \(key): CGFloat = ") else { return .nan }
        return CGFloat(Double(configText[r.upperBound...].prefix { "0123456789.".contains($0) }) ?? .nan)
    }
    let frost = configValue("frostbiteVuln"), called = configValue("calledVulnerability"), marked = configValue("markVulnerability")
    let fracture = GameConfig.Erasure.fractureVulnerability
    let value: [V.Source: CGFloat] = [.frostbite: frost, .marked: marked, .called: called, .fracture: fracture]
    let boss = value.mapValues { GameConfig.BossClass.scaledDebuff($0, isBossClass: true) }
    check("VC0 the per-source values are unchanged: Frostbite ×2.0, Marked ×1.35, Called ×1.35, Fracture ×1.4; boss-class halves each bonus (×1.5 / ×1.175 / ×1.175 / ×1.2)",
          frost == 2.0 && marked == 1.35 && called == 1.35 && fracture == 1.4
            && boss[.frostbite] == 1.5 && boss[.marked] == 1.175 && boss[.called] == 1.175 && boss[.fracture] == 1.2,
          "\(value) boss \(boss)")

    let fresh = V()
    let solo = V.Source.allCases.filter { s in
        var v = V(); v.set(s, value[s]!)
        return !(v.multiplier == value[s]! && v.isActive(s) && V.Source.allCases.allSatisfy { $0 == s || (!v.isActive($0) && v[$0] == 1.0) })
    }
    check("VC1 a fresh store (every enemy and boss spawns with one) carries nothing; each of the four sources activates ITS OWN channel alone",
          fresh.multiplier == 1.0 && V.Source.allCases.allSatisfy { !fresh.isActive($0) } && solo.isEmpty, "\(solo)")

    var all = V()
    for s in V.Source.allCases { all.set(s, value[s]!) }
    let product = value.values.reduce(1, *), sum = 1 + value.values.reduce(0) { $0 + ($1 - 1) }
    check("VC2 all four active: the strongest alone applies (×2.0), never a product (×\(product)) or a sum (×\(sum))",
          all.multiplier == 2.0 && all.multiplier == value.values.max() && all.multiplier != product && all.multiplier != sum)
    check("VC3 the weaker channels stay stored underneath the winner",
          all.frostbite == frost && all.marked == marked && all.called == called && all.fracture == fracture
            && V.Source.allCases.allSatisfy { all.isActive($0) })

    var chain = all, revealed = [chain.multiplier]
    for s in [V.Source.frostbite, .fracture, .called, .marked] { chain.clear(s); revealed.append(chain.multiplier) }
    check("VC4 clearing the strongest reveals the next strongest, all the way down: ×2.0 → ×1.4 → ×1.35 → ×1.35 → none",
          revealed == [2.0, 1.4, 1.35, 1.35, 1.0], "\(revealed)")

    let crossClears = V.Source.allCases.flatMap { s -> [String] in
        var v = all; v.clear(s)
        return V.Source.allCases.compactMap { o in (o == s ? !v.isActive(o) : v[o] == value[o]!) ? nil : "\(s)→\(o)" }
    }
    check("VC5 clearing one source never clears another (Called ending leaves Marked, Frostbite and Fracture; Marked leaves the rest)",
          crossClears.isEmpty, "\(crossClears)")

    func permutations<T>(_ a: [T]) -> [[T]] {
        guard a.count > 1 else { return [a] }
        return a.indices.flatMap { i -> [[T]] in var r = a; let x = r.remove(at: i); return permutations(r).map { [x] + $0 } }
    }
    let orders = permutations(V.Source.allCases)
    let stores = orders.map { order -> V in var v = V(); for s in order { v.set(s, value[s]!) }; return v }
    var churn = V()
    for _ in 0..<5 { for s in V.Source.allCases.reversed() { churn.set(s, value[s]!) } }   // Called re-written each frame
    check("VC6 order-free: all \(orders.count) acquisition orders (and a Called re-write every frame) give the same store and ×2.0",
          orders.count == 24 && stores.allSatisfy { $0 == all } && churn == all)

    // EnemyNode's timers driving the channels (A0 game time), as updateStatusEffects does.
    final class Body: VulnerabilityCarrier {
        var vulnerability = VulnerabilityChannels()
        var fractureWindow = GameTimer(), frostbiteWindow = DelayedWindow(), frostbiteMultiplier: CGFloat = 1.0
        func applyFracture(_ m: CGFloat, duration: TimeInterval) { vulnerability.set(.fracture, m); fractureWindow.start(duration) }
        func scheduleFrostbite(_ m: CGFloat, after delay: TimeInterval, lasting d: TimeInterval) {
            frostbiteMultiplier = m; frostbiteWindow.schedule(after: delay, lasting: d)
        }
        func tick(_ dt: TimeInterval) {
            if fractureWindow.tick(dt) { vulnerability.clear(.fracture) }
            switch frostbiteWindow.tick(dt) {
            case .opened: vulnerability.set(.frostbite, frostbiteMultiplier)
            case .closed: vulnerability.clear(.frostbite)
            case .none: break
            }
        }
        func run(_ seconds: TimeInterval) { for _ in 0..<Int(seconds * 64) { tick(1.0 / 64) } }
    }
    // The recon's real losses (CL-116): Frostbite +100% for 4s after a 3s freeze;
    // Skybeam's Called attaches at 3.5s and lets go at 4.5s; Fracture lands at 5s.
    let b = Body()
    b.scheduleFrostbite(frost, after: 3, lasting: 4)
    b.run(3.5)
    let opened = b.vulnerabilityMultiplier
    for _ in 0..<64 { b.vulnerability.set(.called, called); b.tick(1.0 / 64) }   // attached: re-written every frame
    let whileCalled = b.vulnerabilityMultiplier
    b.vulnerability.clear(.called)                                              // the lasso lets go (clearCalled)
    let afterCalled = b.vulnerabilityMultiplier
    b.run(0.5)                                                                  // t = 5s
    b.applyFracture(fracture, duration: 3)
    b.run(2)                                                                    // t = 7s: Frostbite closes
    let frostClosed = b.vulnerabilityMultiplier
    b.run(1)                                                                    // t = 8s: Fracture expires
    check("VC7 lifetimes stay each source's own: Called never downgrades a Frostbitten body (×2.0, was ×1.35), letting go keeps Frostbite (was wiped), Frostbite closing reveals Fracture (×1.4), Fracture's expiry ends at none",
          opened == 2.0 && whileCalled == 2.0 && afterCalled == 2.0 && frostClosed == fracture && b.vulnerabilityMultiplier == 1.0,
          "\(opened) \(whileCalled) \(afterCalled) \(frostClosed) \(b.vulnerabilityMultiplier)")

    // Marked lands whatever else is on the body, and no other source's timer ends it.
    let m = Body()
    m.applyFracture(fracture, duration: 3)
    m.vulnerability.set(.called, called)
    let markable = !m.vulnerability.isActive(.marked)
    m.vulnerability.set(.marked, marked)
    m.vulnerability.clear(.called)
    m.run(4)
    check("VC8 Marked lands on a body already Called and Fractured (it used to wait for an empty slot) and outlives both",
          markable && m.vulnerability.isActive(.marked) && m.vulnerabilityMultiplier == marked
            && !m.vulnerability.isActive(.called) && !m.vulnerability.isActive(.fracture))

    // Boss-class: the halved values keep their order, and a boss body resolves
    // through the same shared accessor as an enemy body.
    final class BossProbe: VulnerabilityCarrier { var vulnerability = VulnerabilityChannels() }
    let bp = BossProbe(), ep = Body()
    for s in V.Source.allCases { bp.vulnerability.set(s, boss[s]!); ep.vulnerability.set(s, boss[s]!) }
    var bossChain: [CGFloat] = [bp.vulnerabilityMultiplier]
    for s in [V.Source.frostbite, .fracture, .called] { bp.vulnerability.clear(s); bossChain.append(bp.vulnerabilityMultiplier) }
    check("VC9 boss-class: ×1.5 > ×1.2 > ×1.175 keep CL-116's order, and a boss body resolves exactly as an enemy body (one shared accessor)",
          ep.vulnerabilityMultiplier == 1.5 && bossChain == [1.5, 1.2, 1.175, 1.175], "\(bossChain)")
}

// DH — the direct-hit amplifier block (A7b S7, G1.9 94a: CL-94 / CL-114 / CL-115).
// Executed on the REAL DirectHitDamage / DirectHitAmplifiers / DirectHitRounding
// and the REAL CL-70 VoidRounding it rounds with. The per-source values are the
// app's: Permafrost from the extracted GameConfig.Chill, Brittle Cold and Open
// Wounds read from GameConfig.swift (their Stubs mirrors lack or mirror them).
// Means are taken over an evenly spaced grid of rounding units (u = (k + ½)/N),
// so every expectation is exact, not sampled. Each GameScene chain's call into
// this routine — its arguments, Forge ahead of it, its result reaching the
// target's takeDamage — is pinned on the executable view (catalog WR13; the gun
// chains also by redsmile MW7/MW8).
do {
    let configText = (try? String(contentsOfFile: ProcessInfo.processInfo.environment["DP_CONFIG"] ?? "", encoding: .utf8)) ?? ""
    func configValue(_ key: String) -> CGFloat {
        guard let r = configText.range(of: "static let \(key): CGFloat = ") else { return .nan }
        return CGFloat(Double(configText[r.upperBound...].prefix { "0123456789.".contains($0) }) ?? .nan)
    }
    let permafrost = GameConfig.Chill.permafrostBonus, brittle = configValue("brittleColdVuln"), wounds = configValue("openWoundsBonus")
    func enemy(_ p: Bool = false, _ b: Bool = false, _ w: Bool = false) -> DirectHitAmplifiers {
        .onEnemy(permafrostBonus: p ? permafrost : 0, slowed: p || b, arenaSlowed: false,
                 brittleCold: b, brittleColdFactor: brittle, frozen: false, stunned: false,
                 openWoundsBonus: w ? wounds : 0, bleeding: w)
    }
    let grid = 10_000
    func outcomes(_ prefix: Int, _ a: DirectHitAmplifiers) -> [Int] {
        (0..<grid).map { DirectHitDamage.resolve(prefix, a, rounding: DirectHitRounding(unit: (CGFloat($0) + 0.5) / CGFloat(grid))) }
    }
    func mean(_ xs: [Int]) -> CGFloat { CGFloat(xs.reduce(0, +)) / CGFloat(xs.count) }
    check("DH0 the real values: Permafrost +25%, Brittle Cold ×1.4, Open Wounds +25%",
          permafrost == 0.25 && brittle == 1.4 && wounds == 0.25, "\(permafrost) \(brittle) \(wounds)")

    let singles: [(String, DirectHitAmplifiers, CGFloat)] = [("Permafrost", enemy(true), 1.25), ("Brittle Cold", enemy(false, true), 1.4), ("Open Wounds", enemy(false, false, true), 1.25)]
    let unmoved = singles.filter { name, a, x in
        let o = outcomes(1, a)
        return !(Set(o) == [1, 2] && abs(mean(o) - x) < 1e-3 && abs(a.product - x) < 1e-12)
    }.map { $0.0 }
    check("DH1 each amplifier alone now moves a 1-damage hit: Permafrost / Open Wounds average 1.25, Brittle Cold 1.4 (it truncated to 1 before)",
          unmoved.isEmpty, "\(unmoved)")

    let all3 = enemy(true, true, true), x3 = 1.25 * 1.4 * 1.25
    let o3 = outcomes(1, all3)
    let scaled = (1...40).filter { p in abs(mean(outcomes(p, all3)) - CGFloat(p) * x3) > 2e-3 }
    check("DH2 all three on a 1-damage hit multiply as fractions: 2 or 3, averaging exactly ×2.1875 (and ×2.1875 for every prefix 1…40)",
          Set(o3) == [2, 3] && abs(mean(o3) - x3) < 1e-3 && scaled.isEmpty, "mean \(mean(o3)) off \(scaled)")

    var combos: [DirectHitAmplifiers] = []
    for p in [false, true] { for b in [false, true] { for w in [false, true] { combos.append(enemy(p, b, w)) } } }
    combos += [.onBoss(openWoundsBonus: wounds, bleeding: true), .onBoss(openWoundsBonus: wounds, bleeding: false)]
    var outside: [String] = []
    for p in 1...60 { for a in combos { for k in 0..<64 {
        let u = (CGFloat(k) + 0.5) / 64, x = CGFloat(p) * a.product
        let r = DirectHitDamage.resolve(p, a, rounding: DirectHitRounding(unit: u))
        if r != Int(floor(x + 1e-9)) && r != Int(ceil(x - 1e-9)) { outside.append("p\(p)×\(a.product) u\(u) → \(r)") }
    } } }
    // One rounding vs a rounding per step with the same unit: prefix 1, all three, u = 0.5.
    let once = DirectHitDamage.resolve(1, all3, rounding: DirectHitRounding(unit: 0.5))
    var stepped = 1
    for f in [1.25, 1.4, 1.25] as [CGFloat] { stepped = VoidRounding.damage(CGFloat(stepped) * f, unit: 0.5) }
    check("DH3 ONE rounding, not one per step: every result is ⌊x⌋ or ⌈x⌉ of the exact product (60 prefixes × 10 combos × 64 units); at u = 0.5 one rounding gives 2 where rounding each step gives 1",
          outside.isEmpty && once == 2 && stepped == 1, "\(outside.prefix(3)) once \(once) stepped \(stepped)")

    let floorOK = (1...200).allSatisfy { p in combos.allSatisfy { a in [0.0, 0.5, 0.999999].allSatisfy { u in
        let r = DirectHitDamage.resolve(p, a, rounding: DirectHitRounding(unit: u)); return r >= 1 && r >= p } } }
    check("DH4 minimum 1: a landed hit never deals less than 1, nor less than its integer prefix (every factor is ≥ 1); a 0 prefix stays 0",
          floorOK && DirectHitDamage.resolve(0, all3, rounding: DirectHitRounding(unit: 0)) == 0)

    let none = DirectHitAmplifiers()
    let identity = (0...5000).allSatisfy { p in [0.0, 0.25, 0.5, 0.75, 0.999999].allSatisfy { u in
        DirectHitDamage.resolve(p, none, rounding: DirectHitRounding(unit: u)) == p } }
    check("DH5 identity: with no amplifier the block returns its integer prefix EXACTLY (0…5000, every unit) — the base, crit, Lucky Break, execute and Forge steps reach it untouched",
          identity && none.product == 1 && enemy() == none && DirectHitAmplifiers.onBoss(openWoundsBonus: wounds, bleeding: false) == none)

    // CL-114(3)'s own case: a Warp shot at ×1.5 (CL-70 rounding on the shot's
    // A6 threshold), then Permafrost's ×1.25 in the block. Exact mean 1.875.
    let n = 400
    var independent = 0, reused = 0
    for i in 0..<n { for j in 0..<n {
        let u1 = (CGFloat(i) + 0.5) / CGFloat(n), u2 = (CGFloat(j) + 0.5) / CGFloat(n)
        let base = VoidRounding.a6Damage(multiplier: 1, fraction: 1.5, unit: u1)
        independent += DirectHitDamage.resolve(base, enemy(true), rounding: DirectHitRounding(unit: u2))
        if j == 0 { reused += DirectHitDamage.resolve(base, enemy(true), rounding: DirectHitRounding(unit: u1)) }
    } }
    let meanIndependent = CGFloat(independent) / CGFloat(n * n), meanReused = CGFloat(reused) / CGFloat(n)
    check("DH6 CL-114(e): an INDEPENDENT threshold is unbiased (Warp ×1.5 then Permafrost ×1.25 averages exactly 1.875); reusing the shot's spent A6 threshold is biased (2.0)",
          abs(meanIndependent - 1.875) < 1e-3 && abs(meanReused - 2.0) < 1e-3, "independent \(meanIndependent) reused \(meanReused)")

    // Corrective 8: the default draw's DISTRIBUTION, not just its mean and range —
    // the review showed a two-point draw ({0, 0.999999}) passed the old check.
    // Bounds sit ≥ 5σ out over 20,000 production draws (unseeded by design).
    var units: [CGFloat] = [], pairs: [(CGFloat, CGFloat)] = []
    for _ in 0..<20_000 { let a6 = A6Rounding(), hit = DirectHitRounding(); units.append(hit.unit); pairs.append((a6.unit, hit.unit)) }
    let mu = units.reduce(0, +) / CGFloat(units.count)
    let ma = pairs.map { $0.0 }.reduce(0, +) / CGFloat(pairs.count)
    let cov = pairs.map { ($0.0 - ma) * ($0.1 - mu) }.reduce(0, +) / CGFloat(pairs.count)
    let va = pairs.map { ($0.0 - ma) * ($0.0 - ma) }.reduce(0, +) / CGFloat(pairs.count)
    let vh = units.map { ($0 - mu) * ($0 - mu) }.reduce(0, +) / CGFloat(units.count)
    let r = cov / (va * vh).squareRoot()
    let sortedUnits = units.sorted(), nu = CGFloat(units.count)
    var ks: CGFloat = 0
    for (i, x) in sortedUnits.enumerated() { ks = max(ks, abs(CGFloat(i) / nu - x), abs(CGFloat(i + 1) / nu - x)) }
    let deciles = stride(from: 0.1, through: 0.9, by: 0.1).map { q in (CGFloat(q), CGFloat(units.filter { $0 < CGFloat(q) }.count) / nu) }
    let viaDefault = (0..<20_000).map { _ in DirectHitDamage.resolve(1, enemy(true), rounding: DirectHitRounding()) }
    let defaultMean = CGFloat(viaDefault.reduce(0, +)) / CGFloat(viaDefault.count)
    check("DH7 a default DirectHitRounding is a fresh UNIFORM draw on [0, 1) (mean ≈ ½ and the full range, as before; now also Kolmogorov–Smirnov < 0.02 and every decile's CDF within 0.02), uncorrelated with the A6 threshold drawn beside it (|r| < 0.03, as before); rounding a 1-damage Permafrost hit through the block on default draws averages ×1.25",
          units.allSatisfy { $0 >= 0 && $0 < 1 } && abs(mu - 0.5) < 0.01 && units.min()! < 0.01 && units.max()! > 0.99 && abs(r) < 0.03
            && ks < 0.02 && deciles.allSatisfy { abs($0.0 - $0.1) < 0.02 }
            && Set(viaDefault).isSubset(of: [1, 2]) && abs(defaultMean - 1.25) < 0.02,
          "ks \(ks) deciles \(deciles.map { $0.1 }) r \(r) mean \(defaultMean)")

    // The ruled applicability, as a truth table over every flag combination.
    var wrong: [String] = []
    for bits in 0..<(1 << 8) {
        let f = (0..<8).map { bits & (1 << $0) != 0 }
        let (pOwned, slowed, arena, bOwned, frozen, stunned, wOwned, bleeding) = (f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7])
        let a = DirectHitAmplifiers.onEnemy(permafrostBonus: pOwned ? permafrost : 0, slowed: slowed, arenaSlowed: arena,
                                            brittleCold: bOwned, brittleColdFactor: brittle, frozen: frozen, stunned: stunned,
                                            openWoundsBonus: wOwned ? wounds : 0, bleeding: bleeding)
        let wantP: CGFloat = pOwned && (slowed || arena) ? 1.25 : 1
        let wantB: CGFloat = bOwned && (slowed || frozen || stunned) ? 1.4 : 1
        let wantW: CGFloat = wOwned && bleeding ? 1.25 : 1
        if a.permafrost != wantP || a.brittleCold != wantB || a.openWounds != wantW { wrong.append("enemy \(f)") }
        let boss = DirectHitAmplifiers.onBoss(openWoundsBonus: wOwned ? wounds : 0, bleeding: bleeding)
        if boss.permafrost != 1 || boss.brittleCold != 1 || boss.openWounds != wantW { wrong.append("boss \(f)") }
    }
    check("DH8 applicability, all 256 flag combinations: Permafrost on any slow (the arena's included), Brittle Cold on slowed / frozen / stunned, Open Wounds on bleeding; a boss only ever gets Open Wounds",
          wrong.isEmpty, "\(wrong.prefix(4))")
}

// DH9–DH11 — A7b S8 (G1.9 94b/94c; CL-114a–d). Executed on the REAL block,
// OverchargeSplit and PlayerStats. The scene wiring (which values each chain
// passes, the fire-time split, the direct entries) is pinned by catalog WR13/WR14;
// the target-side direct entries run on the real nodes (vulnerability RN4/RN5).
do {
    let grid = 4096
    func units() -> [DirectHitRounding] { (0..<grid).map { DirectHitRounding(unit: (CGFloat($0) + 0.5) / CGFloat(grid)) } }
    let none = DirectHitAmplifiers()
    func meanDealt(_ p: Int, _ a: DirectHitAmplifiers, _ o: CGFloat, _ v: CGFloat) -> CGFloat {
        CGFloat(units().map { DirectHitDamage.resolve(p, a, overcharge: o, vulnerability: v, rounding: $0).dealt }.reduce(0, +)) / CGFloat(grid)
    }
    // DH9 — the resolved vulnerability joins the ONE rounding (CL-114b).
    let frostbittenMini = meanDealt(1, none, 1, 1.5), fractured = meanDealt(1, none, 1, 1.4)
    var foldWrong: [String] = []
    for p in 1...40 { for v: CGFloat in [1, 1.175, 1.2, 1.35, 1.4, 1.5, 2.0] { for o: CGFloat in [1, 1.05, 1.5] { for r in units().enumerated() where r.offset % 64 == 0 {
        let h = DirectHitDamage.resolve(p, .onEnemy(permafrostBonus: 0.25, slowed: true, arenaSlowed: false, brittleCold: false, brittleColdFactor: 1.4,
                                                    frozen: false, stunned: false, openWoundsBonus: 0, bleeding: false),
                                        overcharge: o, vulnerability: v, rounding: r.element)
        let x = CGFloat(p) * 1.25 * o * v, xb = CGFloat(p) * 1.25 * o
        let oneRounding = (h.dealt == Int(floor(x + 1e-9)) || h.dealt == Int(ceil(x - 1e-9))) && (h.basis == Int(floor(xb + 1e-9)) || h.basis == Int(ceil(xb - 1e-9)))
        if !oneRounding || h.basis > h.dealt || (v == 1 && h.basis != h.dealt) { foldWrong.append("p\(p) v\(v) o\(o) → \(h)") }
    } } } }
    check("DH9 the resolved vulnerability folds into the ONE rounding: dealt = ⌊x⌋ or ⌈x⌉ of prefix × amplifiers × Overcharge × vulnerability, basis the same without it (≤ dealt; equal at ×1); a 1-damage hit on a Frostbitten mini-boss now averages 1.5 (in-node it was 2) and a Fractured one 1.4 (it was 1)",
          foldWrong.isEmpty && abs(frostbittenMini - 1.5) < 1e-3 && abs(fractured - 1.4) < 1e-3
            && abs(meanDealt(1, .onEnemy(permafrostBonus: 0.25, slowed: true, arenaSlowed: false, brittleCold: false, brittleColdFactor: 1.4,
                                         frozen: false, stunned: false, openWoundsBonus: 0, bleeding: false), 1.5, 2.0) - 1.25 * 1.5 * 2.0) < 2e-3,
          "\(foldWrong.prefix(3)) mini \(frostbittenMini) fractured \(fractured)")

    // DH10 — the Overcharge split over an integer-crossing grid (CL-114a).
    let scales: [CGFloat] = [0.15, 0.25, 0.3, 0.4, 0.5, 0.6, 0.75, 1.0, 2.0]
    var splitWrong: [String] = []
    for bi in 30...600 { for oi in 0...10 { for s in scales {
        let B = CGFloat(bi) / 100, O = CGFloat(oi) * 0.05
        let split = OverchargeSplit(multiplier: (B + O) * s, overchargeFree: B * s, overcharge: O * s)
        let today = max(1, Int((B + O) * s)), want = max(CGFloat(today), CGFloat(Int(B * s)) + O * s)
        let lowest = DirectHitDamage.resolve(split.base, none, overcharge: split.factor, vulnerability: 1, rounding: DirectHitRounding(unit: CGFloat(1).nextDown)).dealt
        if split.todayFloor != today || split.base != max(1, Int(B * s)) || split.factor < 1
            || CGFloat(split.base) * split.factor < CGFloat(today) || abs(CGFloat(split.base) * split.factor - want) > 1e-9
            || lowest < today || (O == 0 && (split.factor != 1 || split.base != today)) {
            splitWrong.append("B\(B) O\(O) s\(s) base \(split.base) factor \(split.factor) today \(today) lowest \(lowest)")
        }
    } } }
    let oneDamage = (0...10).map { oi -> CGFloat in
        let O = CGFloat(oi) * 0.05, split = OverchargeSplit(multiplier: 1 + O, overchargeFree: 1, overcharge: O)
        return meanDealt(split.base, none, split.factor, 1) - (1 + O) }
    let crossing = OverchargeSplit(multiplier: 1.8 + 0.4, overchargeFree: 1.8, overcharge: 0.4)
    check("DH10 the Overcharge split (56,529 cases over B, O and the real damage scales): base ⌊B·s⌋ (min 1), factor ≥ 1 bringing it to max(today's floor, ⌊B·s⌋ + O·s) EXACTLY, so no shot's BASE pays below today's floor even at the highest unit (the integer prefix after the base — a non-integer crit multiplier such as Deadeye's ×2.1 / ×3.1, Lucky Break, Forge offense, Killing Stroke — is not covered: A7b review M1); no Overcharge = no change; a 1-damage shot averages 1 + O; an Iron Skin crossing (1.8 + 0.4) stays at 2",
          splitWrong.isEmpty && oneDamage.allSatisfy { abs($0) < 2e-3 } && crossing.base == 1 && CGFloat(crossing.base) * crossing.factor == 2,
          "\(splitWrong.count) wrong: \(splitWrong.prefix(3)) oneDamage \(oneDamage)")

    // DH11 — the REAL PlayerStats parts: today's multiplier bit-identical, the
    // Overcharge-free part plus Overcharge's share = it; other users unchanged.
    var partsWrong: [String] = []
    var gen = SystemRandomNumberGenerator()
    for k in 0..<400 {
        let st = PlayerStats()
        st.damageMultiplier = CGFloat(Int.random(in: 50...600, using: &gen)) / 100
        st.overchargeDamagePerSecond = 0.1; st.overchargeMaxBonus = 0.5
        st.updateOvercharge(TimeInterval(k % 6))
        if k % 3 == 0 { st.ironSkinDefToDmg = 0.02; st.defense = Int.random(in: 0...40, using: &gen) }
        if k % 4 == 0 { st.everglowAtkGrowth = CGFloat(Int.random(in: 0...30, using: &gen)) / 100 }
        for s: CGFloat in [0.5, 1, 2] {
            let parts = st.overchargeParts(scale: s)
            if parts.multiplier != st.effectiveDamageMultiplier * s || abs(parts.overchargeFree + parts.overcharge - parts.multiplier) > 1e-9
                || parts.overcharge != st.overchargeCurrentBonus * s || st.shotFractionDamage(s) != max(1, Int(st.effectiveDamageMultiplier * s)) {
                partsWrong.append("k\(k) s\(s) \(parts)")
            }
        }
    }
    check("DH11 the real PlayerStats split: its whole multiplier is today's effectiveDamageMultiplier × scale bit for bit, the Overcharge-free part + Overcharge's share equals it (400 states incl. Iron Skin, Everglow), and shotFractionDamage's other users are unchanged",
          partsWrong.isEmpty, "\(partsWrong.prefix(3))")
    // DH12 — Braceguard's halving on the DirectHit: both the delivered value and
    // the pre-vulnerability basis, exactly today's `max(1, Int(x × multiplier))`.
    var shieldWrong: [String] = []
    for b in 1...60 { for d in b...(b * 3) {
        var h = DirectHit(basis: b, dealt: d)
        h.shield(by: 0.5)
        if h.basis != max(1, Int(CGFloat(b) * 0.5)) || h.dealt != max(1, Int(CGFloat(d) * 0.5)) { shieldWrong.append("\(b)/\(d) → \(h)") }
    } }
    check("DH12 Braceguard's halving applies to BOTH the delivered hit and its pre-vulnerability basis, exactly as before (max 1, truncated)",
          shieldWrong.isEmpty, "\(shieldWrong.prefix(3))")
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
