// main.swift — deterministic validators for v2.1 abilities Unit A2 (Chill):
// Glacial Drift's frozen ground (CL-11), the snowman melt rule (Q-C3, CL-7),
// and the reworked Chill cards applied through the REAL card pool. Each
// validator prints PASS/FAIL; exit 1 on any FAIL.

import CoreGraphics
import Foundation

var passed = 0, failed = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1; print("PASS  \(name)") }
    else { failed += 1; print("FAIL  \(name)  \(detail())") }
}
func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 1e-9 }
let C = GameConfig.Chill.self
func card(_ um: UpgradeManager, _ id: String) -> UpgradeManager.UpgradeCard {
    guard let c = um.allCards.first(where: { $0.id == id }) else { fatalError("missing card \(id)") }
    return c
}
func ground() -> ChillGround { ChillGround(bucketSize: C.driftRadius * 1.35, mergeFraction: C.driftMergeFraction) }

// G1 — per-segment lifetimes, measured from creation (CL-11).
do {
    var g = ground()
    g.drop(at: CGPoint(x: 0, y: 0), radius: 22, now: 0, lifetime: 2.0)
    g.drop(at: CGPoint(x: 100, y: 0), radius: 22, now: 1.5, lifetime: 2.0)
    check("G1a a segment chills its ground, not the ground beside it",
          g.isChilled(CGPoint(x: 10, y: 5)) && !g.isChilled(CGPoint(x: 50, y: 0)) && g.count == 2)
    let first = g.prune(now: 2.0)
    check("G1b each segment melts on ITS clock: the first at 2.0s, the second still there",
          first.count == 1 && !g.isChilled(.zero) && g.isChilled(CGPoint(x: 100, y: 0)))
    check("G1c …and the second at 3.5s", g.prune(now: 3.5).count == 1 && g.count == 0)
}

// G2 — merging bounds the ground; permanent stays permanent.
do {
    var g = ground()
    let a = g.drop(at: .zero, radius: 22, now: 0, lifetime: 2.0)
    let b = g.drop(at: CGPoint(x: 5, y: 0), radius: 22, now: 1.0, lifetime: 2.0)
    check("G2a a drop on top of a segment merges instead of stacking",
          a == .created(id: 0) && b == .merged(id: 0) && g.count == 1)
    check("G2b …and refreshes it (melts at 3.0s, not 2.0s)",
          g.prune(now: 2.5).isEmpty && g.prune(now: 3.0).count == 1)

    var p = ground()
    p.drop(at: .zero, radius: 22, now: 0, lifetime: nil)
    p.drop(at: CGPoint(x: 3, y: 0), radius: 22, now: 1, lifetime: 2.0)
    check("G2c T4 ground is permanent — a later timed drop can't un-permanent it",
          p.prune(now: 10_000).isEmpty && p.isChilled(.zero))
    var t = ground()
    t.drop(at: .zero, radius: 22, now: 0, lifetime: 2.0)
    t.drop(at: CGPoint(x: 3, y: 0), radius: 22 * 1.3, now: 1, lifetime: nil)
    check("G2d upgrading mid-walk: the merged segment grows (T3) and turns permanent (T4)",
          t.prune(now: 10_000).isEmpty && t.isChilled(CGPoint(x: 26, y: 0)))

    // Pace a permanent battlefield: wander a 600×600 yard for 20 game-minutes.
    var field = ground()
    var x: CGFloat = 0, y: CGFloat = 0, seed: UInt64 = 42
    func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(1 << 31) }
    for step in 0..<8000 {
        x = min(300, max(-300, x + (rnd() - 0.5) * 80)); y = min(300, max(-300, y + (rnd() - 0.5) * 80))
        field.drop(at: CGPoint(x: x, y: y), radius: 22 * 1.3, now: Double(step) * 0.15, lifetime: nil)
    }
    check("G2e merging BOUNDS permanent ground (8000 drops → \(field.count) segments, < 1500)", field.count < 1500)
}

// G3 — the rink replaces the trail; a new arena thaws the ground.
do {
    var g = ground()
    for i in 0..<10 { g.drop(at: CGPoint(x: CGFloat(i) * 40, y: 0), radius: 22, now: 0, lifetime: nil) }
    let cleared = g.becomeRink()
    check("G3a Ice Rink clears every trail segment and chills the WHOLE arena",
          cleared.count == 10 && g.count == 0 && g.isRink && g.isChilled(CGPoint(x: -999, y: 777)))
    check("G3b no more trail drops once the rink is up", g.drop(at: .zero, radius: 22, now: 1, lifetime: nil) == nil)
    var t = ground()
    t.drop(at: .zero, radius: 22, now: 0, lifetime: nil)
    check("G3c a new arena thaws even permanent ground (CL-11: permanent = this arena)",
          t.clear(keepRink: false).count == 1 && !t.isChilled(.zero))
}

// S — snowmen (Q-C3) and the melt (CL-7).
do {
    func begin(_ s: inout SnowmanState, tier3: Bool, elite: Bool = false, dur: TimeInterval = 3) -> TimeInterval? {
        s.begin(duration: dur, cooldown: C.snowmanCooldown, meltsOnDamage: tier3, isBossClass: elite, bossClassScale: 0.5)
    }
    var s = SnowmanState()
    check("S1a a transform lasts the tier's duration", begin(&s, tier3: false) == 3 && s.isSnowman)
    check("S1b no re-transform while already a snowman", begin(&s, tier3: false) == nil)
    var wore = false
    for _ in 0..<60 where s.tick(0.05) { wore = true }
    check("S1c the form wears off at 3s on game time", wore && !s.isSnowman)
    check("S1d once per enemy per 10s: still locked at 9.9s", { for _ in 0..<138 { _ = s.tick(0.05) }; return begin(&s, tier3: false) == nil }())
    check("S1e …and free again at 10s", { for _ in 0..<3 { _ = s.tick(0.05) }; return begin(&s, tier3: false) != nil }())
    var e = SnowmanState()
    check("S1f elites transform at the BossClass debuff scale (6s → 3s)", begin(&e, tier3: false, elite: true, dur: 6) == 3)
    var paused = SnowmanState(); _ = begin(&paused, tier3: false)
    check("S1g unticked (paused) snowmen stay snowmen", paused.isSnowman && paused.form.remaining == 3)

    var t1 = SnowmanState(); _ = begin(&t1, tier3: false)
    check("S2a below T3, damage does not melt",
          t1.onDamage(5, isBossClass: false, maxHealth: 10, eliteFraction: 0.2) == .none && t1.isSnowman)
    var n = SnowmanState(); _ = begin(&n, tier3: true)
    check("S2b T3: damaging a normal snowman melts it — it dies",
          n.onDamage(1, isBossClass: false, maxHealth: 10, eliteFraction: 0.2) == .dies && !n.isSnowman)
    var el = SnowmanState(); _ = begin(&el, tier3: true, elite: true)
    let first = el.onDamage(7, isBossClass: true, maxHealth: 200, eliteFraction: C.snowmanEliteMeltFraction)
    let second = el.onDamage(7, isBossClass: true, maxHealth: 200, eliteFraction: C.snowmanEliteMeltFraction)
    check("S2c T3 elite: an ADDITIONAL 20% of max HP on top of the hit (200 → +40)", first == .elite(extraDamage: 40))
    check("S2d the form is consumed first — the melt can never trigger twice", second == .none && !el.isSnowman)
    check("S2e a zero-damage touch doesn't melt", {
        var z = SnowmanState(); _ = begin(&z, tier3: true)
        return z.onDamage(0, isBossClass: false, maxHealth: 10, eliteFraction: 0.2) == .none && z.isSnowman }())
    check("S2f melting doesn't reset the 10s lockout", begin(&n, tier3: true) == nil)
}

// C — the reworked cards, through the real pool.
do {
    let um = UpgradeManager(), stats = PlayerStats()
    let frost = card(um, "chill_1")
    um.pickCard(frost, stats: stats, level: 1)
    let t1 = stats.slowAmount
    um.pickCard(frost, stats: stats, level: 2)
    let t2 = stats.slowAmount
    let before = stats.frostTouchShards
    um.pickCard(frost, stats: stats, level: 3)
    check("C1a Frost Touch tiers are TOTALS: 25% / 50% slow", near(t1, 0.25) && near(t2, 0.50))
    check("C1b T3 opts the shards in — and adds no more slow (CL-3)",
          !before && stats.frostTouchShards && near(stats.slowAmount, 0.50) && frost.maxTier == 3)

    um.pickCard(card(um, "chill_2"), stats: stats, level: 4)
    check("C2 Ice Shard: +30% projectile speed, no range",
          near(stats.projectileSpeedMultiplier, 1.30) && near(stats.projectileRangeMultiplier, 1.0))
    um.pickCard(card(um, "chill_3"), stats: stats, level: 5)
    check("C3 Permafrost: +25%", near(stats.slowedDamageBonus, 0.25))

    um.pickCard(card(um, "v16_hoarfrost"), stats: stats, level: 6)
    var healed = 0, ticks = 0
    for _ in 0..<150 { healed += stats.updateRegen(0.05); ticks += 1 }   // 7.5s
    check("C4 Hoarfrost: 5 HP every 7s", healed == 5 && near(CGFloat(stats.hoarfrostInterval), 7))
}

// D — Glacial Drift's ladder and its gates.
do {
    let um = UpgradeManager(), stats = PlayerStats()
    um.pickCard(card(um, "chill_1"), stats: stats, level: 1)
    let drift = card(um, "chill_4")
    var lifetimes: [TimeInterval?] = [], radii: [CGFloat] = []
    for level in 2...5 {
        um.pickCard(drift, stats: stats, level: level)
        lifetimes.append(stats.chillTrailLifetime); radii.append(stats.chillTrailRadius)
    }
    check("D1a CL-11 lifetimes: 2.0 / 3.5 / 5.0 / permanent", lifetimes == [2.0, 3.5, 5.0, nil], "got \(lifetimes)")
    check("D1b T3 onward is 30% wider", near(radii[0], 22) && near(radii[1], 22) && near(radii[2], 22 * 1.3) && near(radii[3], 22 * 1.3))
    check("D1c five tiers", drift.maxTier == 5)

    // Q-C1: T5 needs Whiteout. At T4 without it, Drift is never offered again.
    var offeredWithout = false
    for level in 6...40 where um.drawCards(count: 3, level: level).contains(where: { $0.id == "chill_4" }) { offeredWithout = true }
    check("D2a Ice Rink is NOT offered without Whiteout", !offeredWithout && um.tier(of: "chill_4") == 4)
    um.pickCard(card(um, "v16_whiteout"), stats: stats, level: 41)
    var offeredWith = false
    for level in 42...120 where !offeredWith {
        if um.drawCards(count: 3, level: level).contains(where: { $0.id == "chill_4" }) { offeredWith = true }
    }
    check("D2b with Whiteout T1 the rink opens up", offeredWith || !um.activeFamilies.contains(.chill))
    let slowBefore = stats.globalEnemySlow, moveBefore = stats.moveSpeedMultiplier
    um.pickCard(drift, stats: stats, level: 121)
    check("D3 Ice Rink: every enemy −50% speed, Spark +25% move, and it IS an arena-wide slow (lights Permafrost, Q-C5)",
          stats.iceRinkActive && near(stats.globalEnemySlow - slowBefore, 0.50) && near(stats.moveSpeedMultiplier - moveBefore, 0.25))
}

// W — Whiteout's ladder.
do {
    let um = UpgradeManager(), stats = PlayerStats()
    let w = card(um, "v16_whiteout")
    var durs: [TimeInterval] = []
    for level in 1...3 { um.pickCard(w, stats: stats, level: level); durs.append(stats.snowmanDuration) }
    check("W1 snowmen: 3s / 6s / 6s + melt at T3", durs == [3, 6, 6] && stats.whiteoutTier == 3 && near(C.snowmanChance, 0.12))
    check("W2 T3 copy matches Brandon's wording",
          (w.detail ?? "").contains("Normal enemies die instantly; elites take an additional 20% of max HP as damage. Bosses cannot become snowmen."))
}

// E — eligibility: the tree, Spikes, the removal, and pity.
do {
    let um = UpgradeManager()
    let chill = um.allCards.filter { $0.tag == .chill }
    let rest = chill.filter { !$0.isSignature }
    check("E1 Frost Touch is the signature; every other Chill card sits behind it (\(rest.count) cards)",
          chill.filter { $0.isSignature }.map { $0.id } == ["chill_1"]
            && rest.allSatisfy { $0.requires.contains(.chillUnlocked) || $0.requires.contains(.glacialDrift) })
    check("E2 Glacial Spikes requires Glacial Drift", card(um, "v21_glacial_spikes").requires == [.glacialDrift]
            && card(um, "chill_4").provides.contains(.glacialDrift))
    // (The pool total moves as each tree lands; A7 audits the final count.)
    check("E3 Static Field is gone; Glacial Spikes took its slot (Chill stays 8 cards)",
          !um.allCards.contains { $0.id == "v13_static_field" } && chill.count == 8, "chill=\(chill.count)")
    check("E4 in-tree prerequisite cards are NOT signatures (so they get no gateway pity)",
          !card(um, "chill_4").isSignature && !card(um, "v16_whiteout").isSignature)

    var leaked: Set<String> = []
    for _ in 0..<40 {
        let run = UpgradeManager(), stats = PlayerStats()
        guard let opener = run.allCards.first(where: { $0.isSignature && $0.tag != .chill && run.activeFamilies.contains($0.tag) }) else { continue }
        run.pickCard(opener, stats: stats, level: 1)
        for level in 2...10 { for c in run.drawCards(count: 3, level: level) where c.tag == .chill && !c.isSignature { leaked.insert(c.id) } }
    }
    check("E5 without Frost Touch, no other Chill card is ever offered", leaked.isEmpty, "leaked \(leaked)")

    // The selection card: 4 lines × 17 chars, 3 beside a MORE chip.
    func lines(_ text: String) -> Int {
        var n = 0, cur = 0
        for w in text.split(separator: " ") {
            if cur == 0 { cur = w.count; n += 1 } else if cur + 1 + w.count <= 17 { cur += 1 + w.count } else { cur = w.count; n += 1 }
        }
        return n
    }
    var tooLong: [String] = []
    // (Polar Vortex is unchanged; its long legacy lines ride the MORE chip.)
    for c in chill where !c.isCapstone { for t in 1...c.maxTier where lines(c.description(forTier: t)) > (c.detail == nil ? 4 : 3) { tooLong.append("\(c.id) T\(t)") } }
    check("E6 every reworked Chill card line fits the selection card", tooLong.isEmpty, "truncated: \(tooLong)")
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
