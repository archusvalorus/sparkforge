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
func runHost(_ h: inout StatusDoTs, _ seconds: TimeInterval, scale: CGFloat = 1) -> StatusDoTs.Payout {
    var total = StatusDoTs.Payout()
    for _ in 0..<Int((seconds / frame).rounded()) {
        let p = h.tick(frame, scale: scale,
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
    // v2.1 A4c: the legacy low-HP multiplier (old Red Smile ×1.5) is GONE —
    // the parameter no longer exists, and a Bleed pays exactly its ticks.
    check("D4 A4c: no situational Bleed multiplier remains — 6 ticks of 1 pay exactly 6",
          runHost(&red, 4).bleed == 6)

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
        newPaid += host.tick(frame, scale: 1,
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
            paid += h.tick(frame, scale: scale,
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
    check("E2 A4b: −Blood Price, +Berserk, +Sanguinarian → Bleed is 13 cards",
          bleed.count == 13 && !um.allCards.contains { $0.id == "v16_blood_price" }
            && um.allCards.contains { $0.id == "v21_berserk" } && um.allCards.contains { $0.id == "v21_sanguinarian" },
          "bleed=\(bleed.count)")
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


// ═══════════════════════════════════════════════════════════════════════
// v2.1 A4b — the rest of the Bleed tree (closure table CL-19…CL-32).
// ═══════════════════════════════════════════════════════════════════════

// L — Glass Blood lineage (CL-28 + Lyra's ancestry correction).
do {
    var b = BleedState()
    b.inflict(tickDamage: 1, duration: B.duration, interval: B.tickInterval, generation: 0)
    check("L1 a primary wound is generation 0", b.generation == 0)
    b.inflict(tickDamage: 1, duration: B.duration, interval: B.tickInterval, generation: 1)
    check("L2 a fragment refreshing a primary wound never overwrites its root (stays 0)", b.generation == 0)

    var f = BleedState()
    f.inflict(tickDamage: 1, duration: B.duration, interval: B.tickInterval, generation: 2)
    check("L3 a fresh fragment Bleed takes the fragment's generation", f.generation == 2)
    f.inflict(tickDamage: 1, duration: B.duration, interval: B.tickInterval, generation: 1)
    check("L4 refresh: the LOWER lineage wins (2 → 1) — and a fragment never becomes a fresh root", f.generation == 1)
    f.inflict(tickDamage: 1, duration: B.duration, interval: B.tickInterval, generation: 0)
    check("L5 a genuine primary hit re-roots the wound at 0", f.generation == 0)
    var e = BleedState()
    e.inflict(tickDamage: 1, duration: B.duration, interval: B.tickInterval, generation: 2)
    e.run(3.0)
    check("L6 when the Bleed ends its lineage resets (next application decides)", !e.isBleeding && e.generation == 0)
    e.inflict(tickDamage: 1, duration: B.duration, interval: B.tickInterval, generation: 1)
    check("L7 …so a later fragment starts that lineage fresh at ITS generation", e.generation == 1)

    // The outbreak: primary Bleed kill → gen-1 fragments → gen-1 Bleed kill →
    // gen-2 fragments → gen-2 Bleed kill → no burst. Two hops per lineage.
    func ctx(_ gen: Int) -> KillContext {
        KillContext(position: .zero, diedBleeding: true, killedByBleed: true, bleedGeneration: gen,
                    finishingDamage: 1, isBoss: false)
    }
    var hops = 0, gen = 0
    while ctx(gen).burstsGlassBlood(maxGeneration: B.glassBloodMaxGeneration) { hops += 1; gen += 1 }
    check("L8 generations 0 and 1 burst, 2 does not → exactly two hops per lineage", hops == 2 && gen == 2)
    let shotKill = KillContext(position: .zero, diedBleeding: true, killedByBleed: false, bleedGeneration: 0,
                               finishingDamage: 1, isBoss: false)
    check("L9 strict rule: a bleeding enemy finished by a SHOT does not burst",
          !shotKill.burstsGlassBlood(maxGeneration: B.glassBloodMaxGeneration))
}

// KC — kill context + boss credit (CL-29/30, Lyra's correction 4).
do {
    // The final Bleed tick both lands AND ends the Bleed in the same step.
    var status = StatusDoTs()
    status.bleed.inflict(tickDamage: 1, duration: B.duration, interval: B.tickInterval, generation: 1)
    _ = runHost(&status, 2.95, scale: GameConfig.BossClass.dotScale)
    let wasBleeding = status.bleed.isBleeding, wasGen = status.bleed.generation
    let pay = status.tick(0.1, scale: GameConfig.BossClass.dotScale,
                          burnDecayInterval: GameConfig.Fire.burnStackDecayInterval, bleedInterval: B.tickInterval)
    let dot = KillContext.DoTHit(channel: .bleed, wasBleeding: wasBleeding, generation: wasGen)
    let finalTick = KillContext.boss(at: CGPoint(x: 5, y: 7), finishingDamage: 1, dot: dot,
                                     liveBleeding: status.bleed.isBleeding, liveGeneration: status.bleed.generation)
    check("KC1 setup: the final tick lands and the Bleed ends in one step", pay.bleedTicks == 1 && !status.bleed.isBleeding)
    check("KC2 …yet the kill still qualifies: bleeding, killed by Bleed, lineage kept (gen 1)",
          finalTick.diedBleeding && finalTick.killedByBleed && finalTick.bleedGeneration == 1 && finalTick.isBoss)

    let burnKill = KillContext.boss(at: .zero, finishingDamage: 2,
                                    dot: .init(channel: .burn, wasBleeding: true, generation: 0),
                                    liveBleeding: false, liveGeneration: 0)
    check("KC3 a Burn tick killing a bleeding boss: bleeding YES, killed-by-Bleed NO",
          burnKill.diedBleeding && !burnKill.killedByBleed)
    let shotOnBleeder = KillContext.boss(at: .zero, finishingDamage: 3, dot: nil, liveBleeding: true, liveGeneration: 0)
    check("KC4 a shot killing a bleeding boss: bleeding (Frenzy/Bloodlust qualify), no Glass Blood",
          shotOnBleeder.diedBleeding && !shotOnBleeder.killedByBleed)
    let lapsed = KillContext.boss(at: .zero, finishingDamage: 3, dot: nil, liveBleeding: false, liveGeneration: 0)
    check("KC5 a Bleed that ran out silently before the killing shot does not count", !lapsed.diedBleeding)

    // Snapshot first: clearing the boss's status afterwards can't change it.
    var live = StatusDoTs()
    live.bleed.inflict(tickDamage: 1, duration: B.duration, interval: B.tickInterval)
    let snap = KillContext.boss(at: CGPoint(x: 1, y: 2), finishingDamage: 9, dot: nil,
                                liveBleeding: live.bleed.isBleeding, liveGeneration: live.bleed.generation)
    live = StatusDoTs()      // the Unmade Star's onDeath clears the slot → resetBossStatus
    check("KC6 a non-DoT kill reads the Bleed live at the lethal hit, and the context is a value — the slot clearing afterwards can't change it",
          snap.diedBleeding && snap.finishingDamage == 9 && snap.position == CGPoint(x: 1, y: 2) && !live.bleed.isBleeding)

    final class Boss {}
    let a = Boss(), c = Boss()
    let idA = ObjectIdentifier(a), idC = ObjectIdentifier(c)
    var latch = BossKillLatch()
    latch.arm(idA)
    check("KC7 the boss in the slot is credited once", latch.claim(idA))
    check("KC8 …a nested effect re-entering the chokepoint can't credit it again", !latch.claim(idA))
    latch.arm(nil)           // the Star clears the slot mid-resolution
    check("KC9 the slot clearing can't reopen its credit", !latch.claim(idA))
    latch.arm(idC)           // the next gauntlet boss
    check("KC10 a new boss re-arms the latch; the old one stays shut", !latch.claim(idA) && latch.claim(idC))
    var fresh = BossKillLatch()
    check("KC11 nothing is credited before a boss is armed", !fresh.claim(idA))
    withExtendedLifetime((a, c)) {}
}

// A — attack speed: Frenzy / Berserk / Bloodlust in ONE firing calculation (CL-22), and the clock (CL-23).
do {
    let stats = PlayerStats()
    let base = GameConfig.Projectile.fireInterval
    check("A0 nothing owned: the interval is the base", abs(stats.effectiveFireInterval - base) < 1e-12)

    stats.frenzyOwned = true
    stats.recordBleedingKill()
    check("A1 Frenzy: a bleeding kill → +15% for 4s", near(stats.frenzyAttackSpeed, 0.15))
    stats.tickBleedBuffs(3.0)
    stats.recordBleedingKill()
    stats.tickBleedBuffs(3.9)
    check("A2 a further bleeding kill RESETS the 4s (still up 6.9s after the first)", near(stats.frenzyAttackSpeed, 0.15))
    for _ in 0..<5 { stats.recordBleedingKill() }
    check("A3 …and never stacks past +15%", near(stats.frenzyAttackSpeed, 0.15))
    stats.tickBleedBuffs(4.0)
    check("A4 it ends 4s after the last qualifying kill", near(stats.frenzyAttackSpeed, 0))

    let b = PlayerStats()
    b.berserkOwned = true
    b.maxHP = 100
    b.currentHP = 100
    let full = b.berserkAttackSpeed
    b.currentHP = 50
    let half = b.berserkAttackSpeed
    b.currentHP = 10
    let low = b.berserkAttackSpeed
    check("A5 Berserk is linear: full HP +0%, half HP +25%, 10% HP +45%",
          near(full, 0) && near(half, 0.25) && near(low, 0.45), "\(full) \(half) \(low)")
    b.currentHP = 50
    b.bloodBarrier.gain(50, maxHP: 100, tuning: .init(reductionCeiling: 0.9, forgeBucketCap: 0.6,
        unyieldingThreshold: 0.2, unyieldingMultiplier: 0.5, kaijuReduction: 0.85, barrierCapFraction: 0.5, barrierExpiry: 4.0))
    check("A6 Blood Barrier is not HP — Berserk ignores it", near(b.berserkAttackSpeed, 0.25))

    let l = PlayerStats()
    l.bloodlustOwned = true
    for _ in 0..<150 { l.recordBleedingKill() }
    let mid = l.bloodlustAttackSpeed
    for _ in 0..<250 { l.recordBleedingKill() }
    check("A7 Bloodlust: +0.1% per bleeding kill (150 → +15%), capped at +30%",
          abs(mid - 0.15) < 1e-9 && abs(l.bloodlustAttackSpeed - 0.30) < 1e-9, "\(mid) \(l.bloodlustAttackSpeed)")
    let unowned = PlayerStats()
    unowned.recordBleedingKill()
    check("A8 unowned cards give nothing", near(unowned.frenzyAttackSpeed, 0) && near(unowned.bloodlustAttackSpeed, 0))

    let c = PlayerStats()
    c.fireRateMultiplier = 1 / 1.5          // Static T3: +50%
    c.frenzyOwned = true; c.recordBleedingKill()
    c.berserkOwned = true; c.maxHP = 100; c.currentHP = 50
    c.forgeBloodrushBonus = 0.10
    let rate = 1 / c.effectiveFireInterval
    let expect = (1 / base) * 1.5 * 1.15 * 1.25 * 1.10
    check("A9 every bonus is its own true-rate multiplier in one calculation", abs(rate - expect) < 1e-9, "\(rate) vs \(expect)")

    // The fire clock at 60 fps: observed sustained rate == calculated rate.
    func observed(_ interval: TimeInterval, seconds: Double = 60) -> Double {
        var clock = FireClock(), shots = 0
        for _ in 0..<Int(seconds * 60) where clock.advance(1.0 / 60, interval: interval, hasTarget: { true }) { shots += 1 }
        return Double(shots) / seconds
    }
    func legacy(_ interval: TimeInterval, seconds: Double = 60) -> Double {
        var t = 0.0, shots = 0
        for _ in 0..<Int(seconds * 60) { t += 1.0 / 60; if t >= interval { shots += 1; t = 0 } }
        return Double(shots) / seconds
    }
    let frenzyRate = base / 1.15
    check("A10 CL-23: +15% now PLAYS as +15% (2.30/s observed; the old reset loop gave \(String(format: "%.2f", legacy(frenzyRate))))",
          abs(observed(frenzyRate) - 1 / frenzyRate) < 0.02, "observed \(observed(frenzyRate))")
    let tiny = base / 1.001
    check("A11 a +0.1% step is no longer swallowed by frame snapping",
          observed(tiny, seconds: 600) > observed(base, seconds: 600))
    var idle = FireClock()
    for _ in 0..<600 { _ = idle.advance(1.0 / 60, interval: 0.5, hasTarget: { false }) }
    var burst = 0
    if idle.advance(1.0 / 60, interval: 0.5, hasTarget: { true }) { burst += 1 }
    if idle.advance(1.0 / 60, interval: 0.5, hasTarget: { true }) { burst += 1 }
    check("A12 idle builds no debt: 10s with no target → ONE shot, not a volley", burst == 1 && idle.elapsed <= 0.5)
    var hitch = FireClock(), hitchShots = 0
    for _ in 0..<10 where hitch.advance(0.1, interval: 0.03, hasTarget: { true }) { hitchShots += 1 }
    check("A13 catch-up is bounded: at most one shot per frame, never more than one interval banked",
          hitchShots == 10 && hitch.elapsed <= 0.03 + 1e-12)
    var paused = FireClock()
    _ = paused.advance(0.3, interval: 0.5, hasTarget: { true })
    let before = paused.elapsed
    check("A14 no game time (pause / level-up) → no firing debt", !paused.advance(0, interval: 0.5, hasTarget: { true }) && paused.elapsed == before)
}

// S — Siphon ×4, Sanguinarian and the barrier (CL-19/20, Q-B3/B5).
do {
    let um = UpgradeManager(), stats = PlayerStats()
    let siphon = card(um, "bleed_4")
    var totals: [Int] = []
    for lv in 1...4 { um.pickCard(siphon, stats: stats, level: lv); totals.append(stats.killHealAmount) }
    check("S1 Siphon tiers are TOTALS 1 / 2 / 4 / 5 HP", totals == [1, 2, 4, 5] && siphon.maxTier == 4, "\(totals)")
    check("S2 approved Siphon copy per tier", (1...4).map { siphon.description(forTier: $0) }
          == ["Kills restore 1 HP.", "Kills restore 2 HP.", "Kills restore 4 HP.", "Kills restore 5 HP."])

    stats.maxHP = 100; stats.currentHP = 100
    check("S3 heal() reports the overheal: at full HP all 5 overflow", stats.heal(5) == 5 && stats.currentHP == 100)
    stats.currentHP = 97
    check("S4 …at 97/100 a 5 heal lands 3 and overflows 2", stats.heal(5) == 2 && stats.currentHP == 100)

    let sang = PlayerStats()
    check("S5 Sanguinarian unowned grants nothing", sang.sanguinarianGrant(finishingDamage: 10) == 0)
    sang.sanguinarianOwned = true
    let grants = [1, 4, 5, 10, 90].map { sang.sanguinarianGrant(finishingDamage: $0) }
    check("S6 CL-19: max(1, floor(20% × finishing)) — 1/4/5 → 1, 10 → 2, a 90-HP execute → 18", grants == [1, 1, 1, 2, 18], "\(grants)")

    // Lyra's gate number: Siphon T4 + Sanguinarian at full HP fill 50 in NINE kills.
    let t = PlayerDamagePipeline.Tuning(reductionCeiling: 0.9, forgeBucketCap: 0.6, unyieldingThreshold: 0.2,
                                        unyieldingMultiplier: 0.5, kaijuReduction: 0.85,
                                        barrierCapFraction: 0.5, barrierExpiry: 4.0)
    stats.sanguinarianOwned = true
    stats.currentHP = stats.maxHP
    var kills = 0
    while stats.bloodBarrier.amount < 50 && kills < 50 {
        kills += 1
        let over = stats.heal(stats.killHealAmount)                // Siphon first…
        if over > 0 { stats.bloodBarrier.gain(over, maxHP: stats.maxHP, tuning: t) }
        stats.bloodBarrier.gain(stats.sanguinarianGrant(finishingDamage: 1), maxHP: stats.maxHP, tuning: t)   // …then Sanguinarian
    }
    check("S7 at full HP, Siphon T4 (5) + Sanguinarian (≥1) fill the 50-point barrier in NINE kills", kills == 9 && stats.bloodBarrier.amount == 50, "kills=\(kills) barrier=\(stats.bloodBarrier.amount)")
    let capped = stats.bloodBarrier.gain(6, maxHP: stats.maxHP, tuning: t)
    check("S8 the 50% cap holds, and a grant on a full pool still refreshes the 4s expiry (A0 rule)",
          capped == 0 && stats.bloodBarrier.amount == 50 && abs(stats.bloodBarrier.expiry.remaining - 4.0) < 1e-9)
}

// X — Exsanguinate + Execution Protocol: ONE ×2, never ×4 (CL-26).
do {
    let s = PlayerStats()
    s.executionThreshold = GameConfig.Bleed.exsanguinateThreshold
    check("X1 Exsanguinate alone: ×2 below 25%, nothing at 25%+",
          near(s.executeMultiplier(healthPercent: 0.24), 2) && near(s.executeMultiplier(healthPercent: 0.26), 1))
    s.executionProtocolThreshold = 0.30
    check("X2 with Execution Protocol: ONE ×2 below 25% (was ×4)", near(s.executeMultiplier(healthPercent: 0.10), 2))
    check("X3 …Execution Protocol keeps its wider 25–30% window", near(s.executeMultiplier(healthPercent: 0.27), 2))
    check("X4 …and nothing above 30%", near(s.executeMultiplier(healthPercent: 0.31), 1))
}

// W — Open Wounds on DoTs, before rounding (CL-25).
do {
    var h = StatusDoTs()
    h.bleed.inflict(tickDamage: 1, duration: B.duration, interval: B.tickInterval)
    var paid = 0
    for _ in 0..<Int((4.0 / frame).rounded()) {
        paid += h.tick(frame, scale: 1, openWounds: GameConfig.Bleed.openWoundsBonus,
                       burnDecayInterval: GameConfig.Fire.burnStackDecayInterval, bleedInterval: B.tickInterval).bleed
    }
    check("W1 six 1-point Bleed ticks on a bleeding target pay 7 (7.5 before rounding) — the DoT share survives rounding",
          paid == 7 && near(h.bleedCarry, 0.5), "paid \(paid) carry \(h.bleedCarry)")
    var boss = StatusDoTs(), bossPaid = 0
    for _ in 0..<10 {
        boss.bleed.inflict(tickDamage: 1, duration: B.duration, interval: B.tickInterval)
        for _ in 0..<Int((3.0 / frame).rounded()) {
            bossPaid += boss.tick(frame, scale: GameConfig.BossClass.dotScale,
                                  openWounds: GameConfig.Bleed.openWoundsBonus,
                                  burnDecayInterval: GameConfig.Fire.burnStackDecayInterval, bleedInterval: B.tickInterval).bleed
        }
    }
    check("W2 on a boss: 60 ticks × 0.5 (CL-17) × 1.25 (Open Wounds, unscaled) = 37.5 → 37", bossPaid == 37, "paid \(bossPaid)")
    var dry = StatusDoTs(), dryPaid = 0
    dry.burn.ignite(dps: 2, duration: 2, source: .kindleHit, stackCap: 1, stackInterval: 3)
    var wet = StatusDoTs(), wetPaid = 0
    wet.burn.ignite(dps: 2, duration: 2, source: .kindleHit, stackCap: 1, stackInterval: 3)
    wet.bleed.inflict(tickDamage: 0.01, duration: 10, interval: 100)
    for _ in 0..<Int((2.0 / frame).rounded()) {
        dryPaid += dry.tick(frame, scale: 1, openWounds: 0.25,
                            burnDecayInterval: GameConfig.Fire.burnStackDecayInterval, bleedInterval: B.tickInterval).burn
        wetPaid += wet.tick(frame, scale: 1, openWounds: 0.25,
                            burnDecayInterval: GameConfig.Fire.burnStackDecayInterval, bleedInterval: 100).burn
    }
    check("W3 Burn on a BLEEDING target gets Open Wounds too; on a dry one it doesn't", wetPaid == 5 && (3...4).contains(dryPaid),
          "wet \(wetPaid) dry \(dryPaid)")
}

// CB — the reworked Bleed cards through the real pool.
do {
    let um = UpgradeManager(), stats = PlayerStats()
    let gouge = card(um, "bleed_1")
    um.pickCard(gouge, stats: stats, level: 1); let t1 = stats.critChance
    um.pickCard(gouge, stats: stats, level: 2)
    check("CBa Nick → Gouge: crit chance TOTALS 10 / 20%, copy matches",
          gouge.name == "Gouge" && near(t1, 0.10) && near(stats.critChance, 0.20)
            && (1...2).map { gouge.description(forTier: $0) } == ["+10% critical hit chance", "+20% critical hit chance"])
    let deadeye = PlayerStats()
    deadeye.critMultiplier += 0.10                 // Forge Path Deadeye
    um.pickCard(card(um, "bleed_2"), stats: deadeye, level: 3)
    check("CBb CL-31: Hemorrhage ADDS +1.0 — Deadeye's +0.10 survives (2.10 → 3.10)", near(deadeye.critMultiplier, 3.10))
    let flags = PlayerStats()
    for id in ["bleed_3", "v21_berserk", "v18_bloodlust", "v21_sanguinarian", "v18_glass_blood"] {
        um.pickCard(card(um, id), stats: flags, level: 4)
    }
    check("CBc Frenzy / Berserk / Bloodlust / Sanguinarian / Glass Blood arm their mechanics",
          flags.frenzyOwned && flags.berserkOwned && flags.bloodlustOwned && flags.sanguinarianOwned && flags.glassBloodActive)
    flags.reset()
    check("CBd run reset disarms them all", !flags.frenzyOwned && !flags.berserkOwned && !flags.bloodlustOwned
          && !flags.sanguinarianOwned && !flags.glassBloodActive && near(flags.bloodlustAttackSpeed, 0))
    check("CBe approved sentences verbatim in the details",
          card(um, "bleed_3").detail?.hasPrefix("Killing a bleeding enemy grants +15% attack speed for 4s. Further qualifying kills reset the duration.") == true
            && card(um, "v21_berserk").detail == "Gain attack speed as health falls: +0.5% for every 1% of max HP missing."
            && card(um, "v18_bloodlust").detail == "Killing a bleeding enemy permanently grants +0.1% attack speed this run, up to +30%."
            && card(um, "v18_glass_blood").detail?.hasPrefix("Enemies killed by Bleed burst into fragments that damage and inflict Bleed on nearby enemies.") == true
            && card(um, "v21_sanguinarian").detail?.hasSuffix("With Siphon: Siphon's overhealing becomes Blood Barrier.") == true)
    check("CBf Glass Blood is no longer a Chill bridge", card(um, "v18_glass_blood").secondaryTag == nil)

    let syn = UpgradeManager(), synStats = PlayerStats()
    let bleedIDs = ["v21_bloodthirsty", "bleed_1", "bleed_2", "bleed_3", "bleed_4"]
    for (i, id) in bleedIDs.enumerated() {
        syn.pickCard(card(syn, id), stats: synStats, level: i + 1)
        _ = syn.checkSynergies(stats: synStats)      // as GameScene does after every pick
    }
    check("CBg synergies: Open Wounds ×3 = +25% (CL-25), Exsanguinate ×5 = below 25% (CL-26)",
          near(synStats.bleedingEnemyDamageTaken, 0.25) && near(synStats.executionThreshold, 0.25),
          "\(synStats.bleedingEnemyDamageTaken) \(synStats.executionThreshold)")
}

// EB — eligibility ships with the tree (every card past Bloodthirsty needs it).
do {
    let um = UpgradeManager()
    let bleed = um.allCards.filter { $0.tag == .bleed }
    let rest = bleed.filter { !$0.isSignature }
    check("EBa every non-signature Bleed card (\(rest.count), capstone included) requires Bloodthirsty",
          rest.count == 12 && rest.allSatisfy { $0.requires.contains(.bleedUnlocked) })
    var leaked: Set<String> = []
    for _ in 0..<40 {
        let run = UpgradeManager(), stats = PlayerStats()
        guard let opener = run.allCards.first(where: { $0.isSignature && $0.tag != .bleed && run.activeFamilies.contains($0.tag) }) else { continue }
        run.pickCard(opener, stats: stats, level: 1)
        for level in 2...10 { for c in run.drawCards(count: 3, level: level) where c.tag == .bleed && !c.isSignature { leaked.insert(c.id) } }
    }
    check("EBb without Bloodthirsty, no other Bleed card is ever offered", leaked.isEmpty, "leaked \(leaked)")
    func lines(_ text: String) -> Int {
        var n = 0, cur = 0
        for w in text.split(separator: " ") {
            if cur == 0 { cur = w.count; n += 1 } else if cur + 1 + w.count <= 17 { cur += 1 + w.count } else { cur = w.count; n += 1 }
        }
        return n
    }
    var tooLong: [String] = []
    for c in rest where !c.isCapstone {
        for t in 1...c.maxTier where lines(c.description(forTier: t)) > (c.detail == nil ? 4 : 3) { tooLong.append("\(c.id) T\(t)") }
    }
    check("EBc every Bleed card line fits the selection card (3 lines beside a MORE chip)", tooLong.isEmpty, "truncated: \(tooLong)")
}


// BT — v2.1 A4b (independent review, finding 2): a hit that empties the
// barrier still shows its absorption tell before the strip hides.
do {
    var t = BarrierTellState()
    check("BT0 nothing drawn, nothing shown", !t.isVisible)
    check("BT1 a first pool draws the strip", t.update(amount: 30) && t.isVisible)

    // Partial absorption: the pool survives, the strip just redraws smaller.
    t.absorbedHit()
    check("BT2 partial absorption: still visible, and it redraws at the new amount",
          t.update(amount: 10) && t.isVisible && t.drawnAmount == 10)
    check("BT3 …the flash ending doesn't hide a pool that still has barrier",
          !t.flashEnded() && t.isVisible)

    // Exact depletion: zero for gameplay at once, the tell still plays.
    t.absorbedHit()
    check("BT4 exact depletion: the strip does NOT redraw (or hide) mid-flash",
          !t.update(amount: 0) && t.isVisible && t.isFlashing && t.hideDeferred)
    check("BT5 …and hides when the flash ends", t.flashEnded() && !t.isVisible)
    check("BT6 no ghost strip: a later 0 changes nothing", !t.update(amount: 0) && !t.isVisible)

    // A hit bigger than the remaining barrier: same tell, HP takes the rest
    // (the damage split itself is damage-harness P10c).
    var big = BarrierTellState()
    _ = big.update(amount: 25)
    big.absorbedHit()
    check("BT7 an over-absorbing hit keeps the tell, then hides",
          !big.update(amount: 0) && big.isVisible && big.flashEnded() && !big.isVisible)

    // P3: a refill DURING the flash cancels the deferred hide.
    var refill = BarrierTellState()
    _ = refill.update(amount: 20)
    refill.absorbedHit()
    check("BT10 a depleted pool defers its hide", !refill.update(amount: 0) && refill.hideDeferred)
    check("BT11 …and a refill mid-flash cancels that deferred hide",
          refill.update(amount: 15) && !refill.hideDeferred && refill.drawnAmount == 15)
    check("BT12 …so the flash ending leaves the refilled strip on screen",
          !refill.flashEnded() && refill.isVisible)

    // With no flash running, an empty pool hides immediately, as before.
    var quiet = BarrierTellState()
    _ = quiet.update(amount: 12)
    check("BT8 without a flash, an emptied pool hides at once",
          quiet.update(amount: 0) && !quiet.isVisible)
    check("BT9 a flash that absorbed nothing new still clears its own hold",
          !quiet.flashEnded() && !quiet.isVisible)
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
