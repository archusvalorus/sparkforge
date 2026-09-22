// main.swift — deterministic validators for v2.1 abilities Unit A4a (bosses
// take DoTs): the ticking Bleed (closure table CL-1, Option B), the two-channel
// DoT host with the boss-class scale (CL-17), and Bloodthirsty through the REAL
// card pool. Each validator prints PASS/FAIL; exit 1 on any FAIL.

import CoreGraphics
import Foundation

var passed = 0, failed = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1; print("PASS  \(name)") }
    else { failed += 1; print("FAIL  \(name)  \(detail())") }
}
func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 1e-9 }
func card(_ um: UpgradeManager, _ id: String) -> UpgradeManager.UpgradeCard {
    guard let c = um.allCards.first(where: { $0.id == id }) else { fatalError("missing card \(id)") }
    return c
}

let B = GameConfig.Bleed.self
let frame: TimeInterval = 0.05
let tickAt10: CGFloat = 1.0                  // 10% of base ATK 10

extension BleedState {
    @discardableResult
    mutating func cut(_ damage: CGFloat = tickAt10) -> Bool {
        inflict(tickDamage: damage, duration: B.duration, interval: B.tickInterval)
    }
    /// Advance `seconds` in harness frames; returns (damage, ticks) landed.
    @discardableResult
    mutating func run(_ seconds: TimeInterval) -> (damage: CGFloat, ticks: Int) {
        var dmg: CGFloat = 0, n = 0
        for _ in 0..<Int((seconds / frame).rounded()) {
            dmg += tick(frame, interval: B.tickInterval)
            n += ticksThisFrame
        }
        return (dmg, n)
    }
}

// K — the tick model (CL-1): 10% ATK every 0.5s for 3s; refresh resets the
// duration, never stacks, never delays the next tick.
do {
    var b = BleedState()
    check("K1a a fresh Bleed starts (inflict reports it) and is bleeding", b.cut() && b.isBleeding)
    check("K1b no tick before 0.5s", b.run(0.45).ticks == 0)
    check("K1c the first tick lands at 0.5s", b.run(0.05).ticks == 1)
    let rest = b.run(2.5)
    check("K1d six ticks over the 3s — the last lands as it ends", rest.ticks == 5 && !b.isBleeding, "rest=\(rest)")
    check("K1e one application = 60% ATK (6 at base ATK 10)", near(rest.damage + tickAt10, 6))
    check("K1f an ended Bleed deals nothing more", b.run(2.0).ticks == 0 && near(b.tickDamage, 0))

    var r = BleedState()
    r.cut()
    let early = r.run(1.2)                   // ticks at 0.5 and 1.0
    check("K2a a refresh is not a fresh Bleed", !r.cut() && early.ticks == 2)
    check("K2b a refresh never delays the next tick (still lands at 1.5s)",
          r.run(0.25).ticks == 0 && r.run(0.05).ticks == 1)
    let after = r.run(3.0)                   // refreshed at 1.2 → ends at 4.2: ticks 2.0 … 4.0
    check("K2c the refresh restarted the full 3s: ticks through 4.0s, then it ends",
          after.ticks == 5 && !r.isBleeding, "after=\(after)")
    check("K2d damage never stacked: every tick was one tick's worth", near(early.damage + 1 + after.damage, 8))

    var s = BleedState()
    s.cut(1.0); s.run(0.5)
    s.cut(2.0)
    let up = s.run(0.5)
    s.cut(0.5)
    let down = s.run(0.5)
    check("K3 the tick damage is the LATEST application's (ATK now, not the best ever)",
          near(up.damage, 2.0) && near(down.damage, 0.5), "up=\(up) down=\(down)")

    var steady = BleedState()
    var ticks = 0
    steady.cut()
    for f in 1...200 {                       // 10s of frames, re-applied every 0.4s
        if f % 8 == 0 { steady.cut() }
        ticks += steady.run(frame).ticks
    }
    check("K4 re-applied every 0.4s, it ticks on a steady 0.5s beat (20 ticks in 10s)", ticks == 20, "ticks=\(ticks)")

    var p = BleedState()
    p.cut(); p.run(1.0)
    let frozen = (p.active.remaining, p.untilTick)
    let none = p.tick(0, interval: B.tickInterval)
    check("K5 no game time, no Bleed (paused / level-up): nothing ticks, nothing runs down",
          near(none, 0) && p.active.remaining == frozen.0 && p.untilTick == frozen.1 && p.isBleeding)

    var hitch = BleedState()
    hitch.cut()
    let big = hitch.tick(1.2, interval: B.tickInterval)
    check("K6 a long step lands every tick that came due (1.2s → 2 ticks)",
          near(big, 2) && hitch.ticksThisFrame == 2)
    let tail = hitch.tick(5.0, interval: B.tickInterval)
    check("K7 …and never a tick past the end (5s step from 1.2s → 4 more, then over)",
          near(tail, 4) && !hitch.isBleeding)

    var bad = BleedState()
    check("K8 zero damage or zero duration inflicts nothing",
          !bad.inflict(tickDamage: 0, duration: 3, interval: 0.5)
            && !bad.inflict(tickDamage: 1, duration: 0, interval: 0.5) && !bad.isBleeding)

    var again = BleedState()
    again.cut(); again.run(3.0)
    check("K9 after it ends, the next application is fresh — first tick 0.5s later",
          again.cut() && again.run(0.45).ticks == 0 && again.run(0.05).ticks == 1)
}

// D — the two-channel DoT host (StatusDoTs) and the boss-class scale (CL-17).
func runHost(_ h: inout StatusDoTs, _ seconds: TimeInterval, scale: CGFloat = 1,
             bleedMult: CGFloat = 1) -> StatusDoTs.Payout {
    var total = StatusDoTs.Payout()
    for _ in 0..<Int((seconds / frame).rounded()) {
        let p = h.tick(frame, scale: scale, bleedMultiplier: bleedMult,
                       burnDecayInterval: GameConfig.Fire.burnStackDecayInterval, bleedInterval: B.tickInterval)
        total.burn += p.burn; total.bleed += p.bleed; total.bleedTicks += p.bleedTicks
    }
    return total
}
do {
    var h = StatusDoTs()
    h.bleed.inflict(tickDamage: tickAt10, duration: B.duration, interval: B.tickInterval)
    let bleedOnly = runHost(&h, 4)
    check("D1a a Bleed pays on the Bleed channel only — 6 per application at base",
          bleedOnly.bleed == 6 && bleedOnly.burn == 0 && bleedOnly.bleedTicks == 6, "\(bleedOnly)")
    var g = StatusDoTs()
    g.burn.ignite(dps: 2, duration: 2, source: .kindleHit, stackCap: 1, stackInterval: 3)
    let burnOnly = runHost(&g, 3)
    check("D1b a Burn pays on the Burn channel only (2 DPS × 2s ≈ 4)",
          (3...4).contains(burnOnly.burn) && burnOnly.bleed == 0 && burnOnly.bleedTicks == 0, "\(burnOnly)")

    // The runtime fact CL-17 answers: BossClass.scaledDamage(1) is still 1.
    var boss = StatusDoTs(), minted = 0
    for _ in 0..<10 {                          // ten back-to-back applications = 60 one-point ticks
        boss.bleed.inflict(tickDamage: tickAt10, duration: B.duration, interval: B.tickInterval)
        minted += runHost(&boss, 3, scale: GameConfig.BossClass.dotScale).bleed
    }
    check("D2 CL-17: boss-class takes a TRUE half of 1-point Bleed ticks (60 ticks → 30, not 60)",
          minted == 30, "paid \(minted)")

    // Brandon (gate, Sep 21): the half is applied ONCE, to the resulting DoT
    // damage — never to the application, the duration or the tick count.
    var once = StatusDoTs()
    once.bleed.inflict(tickDamage: tickAt10, duration: B.duration, interval: B.tickInterval)
    let early = runHost(&once, 2.95, scale: GameConfig.BossClass.dotScale)
    let stillBleeding = once.bleed.isBleeding
    let last = runHost(&once, 1.0, scale: GameConfig.BossClass.dotScale)
    check("D9 boss-class keeps the full 3s and all six ticks — only their damage halves (6 → 3)",
          stillBleeding && early.bleedTicks + last.bleedTicks == 6 && early.bleed + last.bleed == 3,
          "ticks=\(early.bleedTicks + last.bleedTicks) dmg=\(early.bleed + last.bleed)")

    // Five Crucible stacks on each (one Kindle hit per 3s gate), then 2s of full Burn.
    func fiveStacks(_ h: inout StatusDoTs, scale: CGFloat) {
        for _ in 0..<5 {
            h.burn.ignite(dps: 2, duration: 2, source: .kindleHit, stackCap: 5, stackInterval: 3)
            _ = runHost(&h, 3, scale: scale)
        }
        h.burn.ignite(dps: 2, duration: 2, source: .kindleHit, stackCap: 5, stackInterval: 3)
    }
    var hot = StatusDoTs(), cold = StatusDoTs()
    fiveStacks(&hot, scale: 1)
    fiveStacks(&cold, scale: GameConfig.BossClass.dotScale)
    let full = runHost(&hot, 2, scale: 1).burn
    let half = runHost(&cold, 2, scale: GameConfig.BossClass.dotScale).burn
    check("D3 CL-17: a five-stack Burn on boss-class deals half (stacks and duration unscaled)",
          hot.burn.stacks == 5 && cold.burn.stacks == 5 && abs(CGFloat(half) - CGFloat(full) / 2) <= 1,
          "full=\(full) half=\(half) stacks=\(hot.burn.stacks)/\(cold.burn.stacks)")

    var red = StatusDoTs()
    red.bleed.inflict(tickDamage: tickAt10, duration: B.duration, interval: B.tickInterval)
    check("D4 the situational Bleed multiplier (legacy Glass Blood / Red Smile ×1.5) rides each tick",
          runHost(&red, 4, bleedMult: 1.5).bleed == 9)

    var frac = StatusDoTs()
    frac.bleed.inflict(tickDamage: 1.5, duration: B.duration, interval: B.tickInterval)
    let f = runHost(&frac, 4)
    check("D5 fractional ticks carry — 1.5 × 6 = 9, nothing lost to rounding", f.bleed == 9, "\(f)")

    var stale = StatusDoTs()
    stale.bleed.inflict(tickDamage: tickAt10, duration: B.duration, interval: B.tickInterval)
    _ = runHost(&stale, 3.0)
    let after = runHost(&stale, 1.0)
    check("D6 once the Bleed ends, no tick is ever reported again (the tell never pulses stale)",
          after.bleedTicks == 0 && after.bleed == 0 && stale.bleed.ticksThisFrame == 0)

    // Legacy parity: the Burn channel at scale 1 pays exactly what the pre-A4a
    // shared accumulator paid for Burn alone (EnemyNode @ 68dd811).
    var host = StatusDoTs(), legacy = BurnState()
    var legacyAcc: CGFloat = 0, legacyPaid = 0, newPaid = 0
    let script: [(TimeInterval, CGFloat)] = [(0.0, 0.5), (1.0, 1.0), (4.5, 2.0), (9.0, 0.5)]
    var next = 0, t: TimeInterval = 0
    while t < 14 {
        while next < script.count, script[next].0 <= t + 1e-9 {
            host.burn.ignite(dps: script[next].1, duration: 2, source: .kindleHit, stackCap: 5, stackInterval: 3)
            legacy.ignite(dps: script[next].1, duration: 2, source: .kindleHit, stackCap: 5, stackInterval: 3)
            next += 1
        }
        if legacy.stacks > 0 {
            legacyAcc += legacy.tick(frame, decayInterval: GameConfig.Fire.burnStackDecayInterval) * CGFloat(frame)
            if legacyAcc >= 1 { let d = Int(legacyAcc); legacyAcc -= CGFloat(d); legacyPaid += d }
        }
        newPaid += host.tick(frame, scale: 1, bleedMultiplier: 1,
                             burnDecayInterval: GameConfig.Fire.burnStackDecayInterval, bleedInterval: B.tickInterval).burn
        t += frame
    }
    check("D7 a normal enemy's Burn pays exactly as before (legacy accumulator parity)",
          legacyPaid == newPaid && newPaid > 0, "legacy=\(legacyPaid) new=\(newPaid)")

    // CL-17 halves Kindle's BURN — the Shock tesla field only rides the burn
    // channel, so on a mini-boss it keeps its full (legacy) DPS.
    func teslaPaid(scale: CGFloat) -> Int {
        var h = StatusDoTs(), paid = 0
        for _ in 0..<Int((10.0 / frame).rounded()) {
            h.burn.ignite(dps: 0.3, duration: 0.5, source: .other, stackCap: 1, stackInterval: 3)
            paid += h.tick(frame, scale: scale, bleedMultiplier: 1,
                           burnDecayInterval: GameConfig.Fire.burnStackDecayInterval, bleedInterval: B.tickInterval).burn
        }
        return paid
    }
    let teslaFull = teslaPaid(scale: 1), teslaBoss = teslaPaid(scale: GameConfig.BossClass.dotScale)
    check("D8 the flat tesla field is NOT scaled on boss-class (only Kindle's Burn is)",
          teslaBoss == teslaFull && teslaFull >= 2, "full=\(teslaFull) boss=\(teslaBoss)")
}

// C — Bloodthirsty, through the real pool.
do {
    let um = UpgradeManager(), stats = PlayerStats()
    let bt = card(um, "v21_bloodthirsty")
    check("C1 Bloodthirsty is Bleed's signature and unlocks the tree",
          bt.tag == .bleed && bt.isSignature && bt.provides == [.bleedUnlocked] && bt.requires.isEmpty && bt.maxTier == 1)
    check("C2a before the pick nothing bleeds", !stats.bloodthirstyApplies(isPrimaryHit: true, roll: 0))
    um.pickCard(bt, stats: stats, level: 1)
    check("C2b CL-1: 50% per hit", near(stats.bleedApplyChance, 0.5))
    check("C2c the roll: under 50% bleeds, 50% and up doesn't",
          stats.bloodthirstyApplies(isPrimaryHit: true, roll: 0.49) && !stats.bloodthirstyApplies(isPrimaryHit: true, roll: 0.5))
    check("C2d PRIMARY hits only — shards, echoes, summons, capstones never bleed",
          !stats.bloodthirstyApplies(isPrimaryHit: false, roll: 0))
    check("C3a a tick is 10% of effective ATK — 1 at base ATK 10", near(stats.bleedTickDamage, 1.0))
    stats.damageMultiplier = 2.0
    check("C3b …and it scales with ATK (×2 damage → 2 per tick)", near(stats.bleedTickDamage, 2.0))
    stats.reset()
    check("C4 run reset clears the Bleed source", near(stats.bleedApplyChance, 0))
    check("C5 the approved CL-1 sentences are verbatim in the detail (+ the CL-17 boss line)",
          bt.detail == "Primary hits have a 50% chance to inflict Bleed, dealing 10% ATK every 0.5s for 3s. Reapplying Bleed refreshes its duration without stacking damage or delaying the next tick. Bosses and mini-bosses take 50% less Bleed damage.")
    check("C6 Kindle's detail names the boss-class half (CL-17)",
          card(um, "fire_1").detail?.hasSuffix("Bosses and mini-bosses take 50% less Burn damage.") == true)
}

// E — eligibility, removals, copy fit.
do {
    let um = UpgradeManager()
    let bleed = um.allCards.filter { $0.tag == .bleed }
    check("E1 Needlepoint is retired; Bloodthirsty is the only Bleed signature",
          !um.allCards.contains { $0.id == "v18_needlepoint" }
            && bleed.filter { $0.isSignature }.map { $0.id } == ["v21_bloodthirsty"])
    check("E2 one out, one in: Bleed stays 12 cards", bleed.count == 12, "bleed=\(bleed.count)")
    check("E3 still one signature per tree (7)", um.allCards.filter { $0.isSignature && !$0.isSecret }.count == 7)
    var offered = false
    for _ in 0..<60 {
        let run = UpgradeManager()
        if run.drawCards(count: 3, level: 1).contains(where: { $0.id == "v21_bloodthirsty" }) { offered = true; break }
    }
    check("E4 Bloodthirsty shows up in the opening signature spread", offered)
    func lines(_ text: String) -> Int {
        var n = 0, cur = 0
        for w in text.split(separator: " ") {
            if cur == 0 { cur = w.count; n += 1 } else if cur + 1 + w.count <= 17 { cur += 1 + w.count } else { cur = w.count; n += 1 }
        }
        return n
    }
    var tooLong: [String] = []
    for c in [card(um, "v21_bloodthirsty"), card(um, "fire_1")] {
        for t in 1...c.maxTier where lines(c.description(forTier: t)) > (c.detail == nil ? 4 : 3) { tooLong.append("\(c.id) T\(t)") }
    }
    check("E5 Bloodthirsty's and Kindle's card lines fit beside the MORE chip", tooLong.isEmpty, "truncated: \(tooLong)")
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
