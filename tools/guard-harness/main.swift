// main.swift — deterministic validators for v2.1 abilities Unit A5 (the Guard
// rework). Rulings: closure table §B4, CL-49…CL-69 (Brandon, Sep 24).
//   ST  Fortify's stillness clock (CL-64)      FO  Fortify (CL-64)
//   GC  Grounded Core, incl. CombatPresence (CL-65 MODIFIED)
//   DF  what "DEF" means (CL-51)               IH  Ironhide + the 90% ceiling (CL-52)
//   GR  contact retaliation on boss-class (CL-53 / CL-67)
//   UB  Unbroken Core: rescue order, window, conversion (CL-54/55/56)
//   SH  the projectile shield (CL-57)          BO  the contact bounce (CL-58/59)
//   IB  Iron Bloom (CL-60/61)                  RP  Repulse (CL-62/63)
//   CA  the cards, gates, copy and the ladder (CL-49/50/53/66/67/69)
//   EL  eligibility through the real draw      KS  kill credit
//   CF  the REAL GameConfig.Guard (extracted from source, compiled here) = the rulings
//   WR  the scene WIRING (GameScene isn't compiled — its source is read)
// Each validator prints PASS/FAIL; exit 1 on any FAIL. Everything is seeded
// except EL1/EL2, which sample the REAL card draw (its palette roll is random).

import CoreGraphics
import Foundation

var passed = 0, failed = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1; print("PASS  \(name)") }
    else { failed += 1; print("FAIL  \(name)  \(detail())") }
}
func near(_ a: CGFloat, _ b: CGFloat, _ eps: CGFloat = 1e-6) -> Bool { abs(a - b) <= eps }
func card(_ id: String, _ um: UpgradeManager) -> UpgradeManager.UpgradeCard {
    guard let c = um.allCards.first(where: { $0.id == id }) else { fatalError("missing card \(id)") }
    return c
}
/// 1/64s frames: binary-exact, so boundary counts are deterministic.
let frame: TimeInterval = 1.0 / 64
/// 1/60s frames: NOT binary-exact — the boundary checks that need an epsilon.
let frame60: TimeInterval = 1.0 / 60
let G = GameConfig.Guard.self
/// Stand still for `seconds` with Fortify owned (its own clock).
func standStill(_ s: PlayerStats, seconds: Double) {
    for _ in 0..<Int((seconds * 64).rounded()) { s.updateFortify(frame, hasInput: false) }
}

// ST — Fortify's stillness clock: no stick input accumulates; any input resets.
do {
    var s = StillnessClock()
    for _ in 0..<64 { s.update(frame, hasInput: false) }
    check("ST1 a second without stick input is one still second", s.stillSeconds == 1.0, "\(s.stillSeconds)")
    s.update(frame, hasInput: true)
    check("ST2 any stick input resets it", s.stillSeconds == 0)
}

// FO — Fortify: +1 temp DEF each 0.5s still (= +2/s), cap +30, input resets.
do {
    let t = G.fortifyTuning
    let at = { (sec: TimeInterval) in FortifyDEF.temporaryDEF(stillSeconds: sec, tuning: t) }
    check("FO1 +1 per 0.5s: 0.49s → 0, 0.5s → 1, 1s → 2 (+2 DEF/s)",
          at(0.49) == 0 && at(0.5) == 1 && at(1.0) == 2, "\(at(0.49)) \(at(0.5)) \(at(1.0))")
    check("FO2 capped at +30 (reached at 15s, held after)", at(14.9) == 29 && at(15) == 30 && at(120) == 30)
    var dust: TimeInterval = 0
    for _ in 0..<10 { dust += 0.05 }
    check("FO3 frame-sum float dust (ten 0.05s frames) still reaches the step", at(dust) == 1, "\(dust)")

    let stats = PlayerStats()
    check("FO4 not owned → no DEF", stats.updateFortify(10, hasInput: false) == 0 && stats.fortifyTempDEF == 0)
    stats.fortifyOwned = true
    var ticks = 0
    for _ in 0..<(64 * 3) where stats.updateFortify(frame, hasInput: false) > 0 { ticks += 1 }
    check("FO5 owned: 3s still → +6 temp DEF, one tick per point", stats.fortifyTempDEF == 6 && ticks == 6,
          "\(stats.fortifyTempDEF) ticks=\(ticks)")
    stats.updateFortify(frame, hasInput: true)
    check("FO6 any movement input resets the stack to 0", stats.fortifyTempDEF == 0)
    let late = PlayerStats()
    for _ in 0..<(64 * 20) { late.updateFortify(frame, hasInput: false) }   // standing still, not owned
    late.fortifyOwned = true
    late.updateFortify(frame, hasInput: false)
    check("FO7 standing still BEFORE the pick banks nothing (its clock starts at ownership)",
          late.fortifyTempDEF == 0, "\(late.fortifyTempDEF)")
    let dead = PlayerStats()
    dead.fortifyOwned = true
    standStill(dead, seconds: 5)
    dead.resetFortify()
    check("FO8 death breaks the stance (resetFortify)", dead.fortifyTempDEF == 0 && dead.fortifyClock.stillSeconds == 0)
}

// GC — Grounded Core: +1 permanent DEF per uninterrupted 7.5s still IN combat.
do {
    var bank = GroundedCoreBank(tuning: G.groundedTuning)
    for _ in 0..<(64 * 15) { bank.update(frame, still: true, inCombat: true) }
    check("GC1 7.5s still in combat → +1; 15s → +2", bank.earned == 2, "\(bank.earned)")

    var moved = GroundedCoreBank(tuning: G.groundedTuning)
    for _ in 0..<(64 * 7) { moved.update(frame, still: true, inCombat: true) }
    moved.update(frame, still: false, inCombat: true)
    for _ in 0..<(64 * 7) { moved.update(frame, still: true, inCombat: true) }
    check("GC2 movement resets unfinished progress (7s + move + 7s = 0)", moved.earned == 0)

    var lull = GroundedCoreBank(tuning: G.groundedTuning)
    for _ in 0..<(64 * 7) { lull.update(frame, still: true, inCombat: true) }
    lull.update(frame, still: true, inCombat: false)
    for _ in 0..<(64 * 7) { lull.update(frame, still: true, inCombat: true) }
    check("GC3 MODIFIED: leaving combat RESETS unfinished progress (no pausing across lulls)",
          lull.earned == 0 && lull.progress == 7.0, "earned=\(lull.earned) progress=\(lull.progress)")

    var capped = GroundedCoreBank(tuning: G.groundedTuning)
    for _ in 0..<(64 * 300) { capped.update(frame, still: true, inCombat: true) }
    check("GC4 cap +30 per run (300s still → 30, then it stops accruing)",
          capped.earned == 30 && capped.isCapped && capped.progress == 0 && capped.fraction == 0)

    var death = GroundedCoreBank(tuning: G.groundedTuning)
    for _ in 0..<(64 * 12) { death.update(frame, still: true, inCombat: true) }
    death.resetProgress()
    check("GC5 death/revive: earned DEF persists, the unfinished interval resets",
          death.earned == 1 && death.progress == 0)

    let stats = PlayerStats()
    stats.defense = 9
    check("GC6 not owned → no points", stats.updateGroundedCore(8, still: true, inCombat: true) == 0 && stats.defense == 9)
    stats.groundedCoreActive = true
    var gained = 0
    for _ in 0..<(64 * 8) { gained += stats.updateGroundedCore(frame, still: true, inCombat: true) }
    check("GC7 an earned point goes INTO base DEF (HUD-visible, feeds every DEF scaler)",
          gained == 1 && stats.defense == 10, "gained=\(gained) def=\(stats.defense)")
    stats.reset()
    check("GC8 a new run clears the bank (earned and cap counter)",
          stats.groundedCore.earned == 0 && stats.groundedCore.progress == 0 && !stats.groundedCoreActive)

    // Reusing A4c's CombatPresence (0.5s linger), exactly as the scene orders it.
    func run(absentFrames: Int) -> Int {
        var presence = CombatPresence(linger: 0.5)
        var b = GroundedCoreBank(tuning: G.groundedTuning)
        func step(_ hostile: Bool) {
            presence.update(frame, hostilePresent: hostile)
            b.update(frame, still: true, inCombat: presence.isActive)
        }
        for _ in 0..<(64 * 6) { step(true) }
        for _ in 0..<absentFrames { step(false) }
        for _ in 0..<72 { step(true) }
        return b.earned
    }
    check("GC9 a 0.4s gap inside the 0.5s linger is still combat — progress carries", run(absentFrames: 26) == 1)
    check("GC10 a 0.6s gap drops combat — the unfinished interval resets", run(absentFrames: 39) == 0)

    var sixty = GroundedCoreBank(tuning: G.groundedTuning)
    var landed = 0
    for f in 1...460 where sixty.update(frame60, still: true, inCombat: true) > 0 && landed == 0 { landed = f }
    check("GC11 at 60fps the point lands on frame 450 exactly (float dust can't cost a frame)", landed == 450, "\(landed)")
}

// DF — "current DEF" = base + Fortify temp + Deeproot ground (CL-51).
do {
    let stats = PlayerStats()
    stats.defense = 12
    stats.fortifyOwned = true
    standStill(stats, seconds: 3)                 // +6
    stats.groundDefBonus = 4
    check("DF1 flat DEF = base 12 + Fortify 6 + Deeproot 4 = 22; the HUD's +N = 10",
          stats.effectiveFlatDEF == 22 && stats.currentDEF == 22 && stats.temporaryDEF == 10,
          "\(stats.effectiveFlatDEF) \(stats.currentDEF) \(stats.temporaryDEF)")
}

// IH — Ironhide: 9% per qualifying hostile, 10 contributors max; the ceiling.
let tuning = PlayerDamagePipeline.Tuning(reductionCeiling: 0.90, forgeBucketCap: 0.60,
                                         unyieldingThreshold: 0.20, unyieldingMultiplier: 0.5,
                                         kaijuReduction: 0.85, barrierCapFraction: 0.5, barrierExpiry: 4)
do {
    let t = G.ironhideTuning
    let r = { (n: Int) in Ironhide.reduction(contributors: n, tuning: t) }
    check("IH1 0 → 0, 1 → 9%, 5 → 45%, 10 → 90%, 14 → still 90%",
          r(0) == 0 && near(r(1), 0.09) && near(r(5), 0.45) && near(r(10), 0.90) && near(r(14), 0.90))
    let def = PlayerDamagePipeline.Defender(currentHP: 100, maxHP: 100)
    var hit = PlayerDamagePipeline.Hit(raw: 100)
    hit.ironhide = r(10)
    hit.aegis = 0.35
    let capped = PlayerDamagePipeline.resolve(hit, against: def, tuning: tuning)
    check("IH2 Ironhide 90% × Aegis 35% clamps to the 90% ceiling (100 → 10)",
          capped.damage == 10 && capped.ceilingApplied && near(capped.reduction, 0.90), "\(capped.damage)")
    hit.ironhide = r(5)
    hit.aegis = 0.25
    let mixed = PlayerDamagePipeline.resolve(hit, against: def, tuning: tuning)
    check("IH3 below the ceiling they multiply: 1 − 0.55 × 0.75 = 58.75% (100 → 41)",
          mixed.damage == 41 && !mixed.ceilingApplied, "\(mixed.damage)")
    let q = { (d: CGFloat, h: Bool, s: Bool) in Ironhide.qualifies(surfaceDistance: d, radius: 150, hittable: h, snowman: s) }
    check("IH4 who counts: hittable, not a snowman, SURFACE within 150pt (149 yes, 150 no, phased no, snowman no)",
          q(149, true, false) && !q(150, true, false) && !q(10, false, false) && !q(10, true, true))
}

// GR — contact retaliation on boss-class (CL-53 / CL-67).
do {
    let scale: CGFloat = 0.5
    let tw = { (raw: Int, boss: Bool) in
        GuardRetaliation.thornwall(raw: raw, multiplier: G.thornwallReflect, isArenaBoss: boss, bossScale: scale) }
    check("GR1 Thornwall 1.50× the pre-mitigation hit: 40 → 60; an ARENA boss takes half once → 30",
          tw(40, false) == 60 && tw(40, true) == 30)
    check("GR2 Thornwall: 25 → 37 (truncated once) / boss 18; a 1-damage touch still reflects 1",
          tw(25, false) == 37 && tw(25, true) == 18 && tw(1, false) == 1 && tw(1, true) == 1)
    check("GR3 Iron Maiden thorns vs boss-class (mini-boss OR arena boss): 17 → 9, 5 → 3 (rounded like BossClass); normals full",
          GuardRetaliation.ironThorns(17, isBossClass: true, bossScale: scale) == 9
            && GuardRetaliation.ironThorns(5, isBossClass: true, bossScale: scale) == 3
            && GuardRetaliation.ironThorns(17, isBossClass: false, bossScale: scale) == 17)
    check("GR4 Iron Maiden Retaliate 150% of the raw hit: 40 → 60, boss-class → 30",
          GuardRetaliation.ironRetaliate(raw: 40, fraction: 1.5, isBossClass: false, bossScale: scale) == 60
            && GuardRetaliation.ironRetaliate(raw: 40, fraction: 1.5, isBossClass: true, bossScale: scale) == 30)
}

// UB — Unbroken Core.
do {
    let both = PlayerDamagePipeline.Defender(currentHP: 5, maxHP: 100, braceAvailable: true, unbrokenAvailable: true)
    let lethal = PlayerDamagePipeline.resolve(PlayerDamagePipeline.Hit(raw: 50), against: both, tuning: tuning)
    check("UB1 both armed: a lethal hit spends Brace ONLY", lethal.rescue == .brace && lethal.hpAfter == 1)
    let second = PlayerDamagePipeline.Defender(currentHP: 1, maxHP: 100, braceAvailable: false, unbrokenAvailable: true)
    check("UB2 Brace spent: the next lethal hit spends Unbroken Core",
          PlayerDamagePipeline.resolve(PlayerDamagePipeline.Hit(raw: 50), against: second, tuning: tuning).rescue == .unbrokenCore)
    check("UB3 self-damage asks the SAME order (lethalRescue)",
          PlayerDamagePipeline.lethalRescue(for: both) == .brace
            && PlayerDamagePipeline.lethalRescue(for: second) == .unbrokenCore
            && PlayerDamagePipeline.lethalRescue(for: .init(currentHP: 1, maxHP: 100)) == .none)
    let stats = PlayerStats()
    stats.lethalSaves = 1
    stats.unbrokenRescueAvailable = true
    stats.spendRescue(.brace)
    check("UB4 spending Brace leaves Unbroken armed (independent saves)",
          stats.lethalSaves == 0 && stats.unbrokenRescueAvailable)
    stats.spendRescue(.unbrokenCore)
    check("UB5 spending Unbroken disarms it", !stats.unbrokenRescueAvailable)

    check("UB6 conversion = DEF / max(1, ATK): 30/20 = 1.5, 0/20 = 0, 5/0 → 5/1",
          near(UnbrokenWindow.bonusMultiplier(def: 30, atk: 20), 1.5)
            && UnbrokenWindow.bonusMultiplier(def: 0, atk: 20) == 0
            && near(UnbrokenWindow.bonusMultiplier(def: 5, atk: 0), 5))
    let s = PlayerStats()
    s.baseAttack = 20
    s.defense = 30
    let atkBefore = s.displayAttack, multBefore = s.effectiveDamageMultiplier
    s.unbrokenWindow.open(duration: G.unbrokenWindow, def: s.currentDEF, atk: s.unbrokenConversionATK)
    check("UB7 the HUD ATK rises by EXACTLY the snapped DEF (20 → 50) and the gun's multiplier by DEF/ATK",
          s.displayAttack == atkBefore + 30 && near(s.effectiveDamageMultiplier - multBefore, 1.5),
          "\(atkBefore) → \(s.displayAttack)")
    let apex = PlayerStats()
    apex.baseAttack = 20
    apex.maxHP = 500
    apex.apexHpToAtkActive = true
    apex.defense = 30
    let apexBefore = apex.displayAttack
    apex.unbrokenWindow.open(duration: G.unbrokenWindow, def: apex.currentDEF, atk: apex.unbrokenConversionATK)
    check("UB7b with Apex's HP-fed ATK in play, the HUD still rises by EXACTLY DEF (the conversion reads ATK + Apex)",
          apex.apexBonusAttackFromHP > 0 && apex.displayAttack == apexBefore + 30,
          "apex=\(apex.apexBonusAttackFromHP) \(apexBefore) → \(apex.displayAttack)")
    s.defense = 90
    s.fortifyOwned = true
    standStill(s, seconds: 10)
    check("UB8 the bonus is FIXED for the window — later DEF changes don't recalculate it",
          near(s.unbrokenWindow.bonusMultiplier, 1.5) && s.unbrokenWindow.snappedDEF == 30)
    var w = UnbrokenWindow()
    w.open(duration: G.unbrokenWindow, def: 10, atk: 10)
    for _ in 0..<639 { w.tick(frame) }
    let stillOpen = w.isActive
    let closed = w.tick(frame)
    check("UB9 exactly 10s of game time (open at 9.98s, closes on the 10s frame, bonus → 0)",
          stillOpen && closed && !w.isActive && w.bonusMultiplier == 0)
    let fortified = PlayerStats()
    fortified.baseAttack = 10
    fortified.defense = 6
    fortified.fortifyOwned = true
    standStill(fortified, seconds: 5)              // +10 temp
    fortified.unbrokenWindow.open(duration: 10, def: fortified.currentDEF, atk: fortified.unbrokenConversionATK)
    check("UB10 temporary Fortify DEF present at the rescue joins the snapshot (6 + 10 = 16 → +1.6)",
          fortified.unbrokenWindow.snappedDEF == 16 && near(fortified.unbrokenWindow.bonusMultiplier, 1.6))
    s.reset()
    check("UB11 a new run clears the window, the rescue and the shield",
          !s.unbrokenWindow.isActive && s.unbrokenWindow.bonusMultiplier == 0
            && !s.unbrokenRescueAvailable && !s.projectileShield.isOwned && !s.unbrokenCoreOwned)
}

// SH — the projectile shield: one block, then 6s to rearm; invulnerability wins.
do {
    var sh = ProjectileShieldCharge(rearm: G.shieldRearm)
    check("SH1 not owned → never blocks", !sh.tryBlock(invulnerable: false) && sh.readiness == 0)
    sh.grant()
    check("SH2 granted ready; invulnerable → the block is NOT spent",
          sh.isReady && !sh.tryBlock(invulnerable: true) && sh.isReady)
    check("SH3 blocks one, then is spent", sh.tryBlock(invulnerable: false) && !sh.isReady && !sh.tryBlock(invulnerable: false))
    var rearmed = false
    for _ in 0..<383 { if sh.tick(frame) { rearmed = true } }
    let early = sh.isReady
    let edge = sh.tick(frame)
    check("SH4 rearms after exactly 6s of game time", !rearmed && !early && edge && sh.isReady && sh.readiness == 1)
}

// BO — the shared contact bounce (Harden + Aegis) and its spike.
do {
    let t = G.bounceTuning
    let d = { (h: Bool, a: Int) in ContactBounce.distance(hardenOwned: h, aegisTier: a, tuning: t) }
    check("BO1 distance: none 0 · Aegis T1 0 · Harden 40 · Aegis T2 40 · T3 70 · Harden + T3 70 (largest owned)",
          d(false, 0) == 0 && d(false, 1) == 0 && d(true, 0) == 40 && d(false, 2) == 40
            && d(false, 3) == 70 && d(true, 3) == 70 && d(true, 1) == 40)
    let spike = { (a: Int, def: Int) in ContactBounce.spikeDamage(aegisTier: a, currentDEF: def, tuning: t) }
    check("BO2 spike: T1 none · T2 50% DEF (10 → 5, min 1) · T3 75% (10 → 7)",
          spike(1, 10) == 0 && spike(2, 10) == 5 && spike(2, 0) == 1 && spike(2, 1) == 1 && spike(3, 10) == 7)
}

// IB — Iron Bloom: every 4s (game time, remainder carried), 50% current DEF.
do {
    check("IB1 50% of current DEF, at least 1 (0 → 1, 7 → 3, 30 → 15)",
          IronBloom.pulseDamage(currentDEF: 0, fraction: G.ironBloomDEFFraction) == 1
            && IronBloom.pulseDamage(currentDEF: 7, fraction: G.ironBloomDEFFraction) == 3
            && IronBloom.pulseDamage(currentDEF: 30, fraction: G.ironBloomDEFFraction) == 15)
    let stats = PlayerStats()
    stats.ironBloomActive = true
    var pulses: [Int] = []
    for f in 1...(64 * 60) where stats.updateIronBloom(frame) { pulses.append(f) }
    check("IB2 a pulse every 4s, never a continuous aura: 15 in 60s, first at 4s",
          pulses.count == 15 && pulses.first == 256 && pulses.last == 3840, "\(pulses.count)")
    stats.defense = 10
    stats.fortifyOwned = true
    standStill(stats, seconds: 5)                  // +10 temp
    check("IB3 reads CURRENT DEF — Fortify included (20 → 10)", stats.ironBloomDamage == 10)
    let sixty = PlayerStats()
    sixty.ironBloomActive = true
    var n = 0
    for _ in 0..<(60 * 600 + 2) where sixty.updateIronBloom(frame60) { n += 1 }
    check("IB4 the remainder carries: 150 pulses in 10 minutes at 60fps (a reset-to-0 cadence drifts to 149)",
          n == 150, "\(n)")
}

// RP — Repulse's T3 launch.
do {
    var f = RepulseFlight(direction: CGPoint(x: 3, y: 4), tuning: G.launchTuning)
    var total = CGPoint.zero
    var frames = 0
    while !f.isLanded {
        let step = f.advance(frame)
        total = CGPoint(x: total.x + step.x, y: total.y + step.y)
        frames += 1
    }
    let len = (total.x * total.x + total.y * total.y).squareRoot()
    check("RP1 a launch covers exactly 400pt along its direction, then lands (≈0.35s)",
          near(len, 400, 1e-6) && near(total.x / len, 0.6) && frames == 23, "len=\(len) frames=\(frames)")
    check("RP2 decelerating: half the time covers 75% of the distance", near(RepulseFlight.coverage(0.5), 0.75))
    var g = RepulseFlight(direction: CGPoint(x: 1, y: 0), tuning: G.launchTuning)
    final class Body {}
    let a = Body(), b = Body(), c = Body(), d = Body()
    check("RP3 each target at most once per launch, up to 3 strikes",
          g.strike(ObjectIdentifier(a)) && !g.strike(ObjectIdentifier(a)) && g.strike(ObjectIdentifier(b))
            && g.strike(ObjectIdentifier(c)) && !g.strike(ObjectIdentifier(d)) && !g.canStrike)
    var h = RepulseFlight(direction: CGPoint(x: 1, y: 0), tuning: G.launchTuning)
    h.land()
    check("RP4 a landed launch (wall / Carrier) moves no further", h.advance(frame) == .zero)
    var last = RepulseFlight(direction: CGPoint(x: 1, y: 0), tuning: G.launchTuning)
    while !last.isLanded { _ = last.advance(frame) }
    check("RP5 the step that lands can still strike (the scene tests it, then drops the flight)",
          last.strike(ObjectIdentifier(a)))
    let dmg = { (atk: CGFloat) in RepulseFlight.collisionDamage(effectiveAttack: atk, fraction: G.repulseCollisionATK) }
    check("RP6 collision = 25% of current ATK, integer, min 1 (10 → 2, 3 → 1, 40 → 10) — not a flat 2",
          dmg(10) == 2 && dmg(3) == 1 && dmg(40) == 10 && dmg(0) == 1)
    let z = RepulseFlight(direction: .zero, tuning: G.launchTuning)
    check("RP7 a zero direction still launches somewhere defined", z.direction == CGPoint(x: 0, y: 1))
    // Swept overlap: a 37pt first step with a pin 20pt beside its midpoint.
    let from = CGPoint.zero, to = CGPoint(x: 37, y: 0), pin = CGPoint(x: 18.5, y: 20)
    let endOnly = ((pin.x - to.x) * (pin.x - to.x) + (pin.y - to.y) * (pin.y - to.y)).squareRoot() < 24
    check("RP8 pins are tested along the whole step: a pin beside the path is struck (end-point-only would miss it)",
          RepulseFlight.sweepOverlaps(from: from, to: to, center: pin, radius: 24) && !endOnly
            && !RepulseFlight.sweepOverlaps(from: from, to: to, center: CGPoint(x: 18.5, y: 30), radius: 24))
    check("RP9 who launches: normals/elites yes; mini-bosses and snowmen never",
          RepulseFlight.isLaunchable(isMiniBoss: false, isSnowman: false)
            && !RepulseFlight.isLaunchable(isMiniBoss: true, isSnowman: false)
            && !RepulseFlight.isLaunchable(isMiniBoss: false, isSnowman: true))
    check("RP10 who is a pin: hittable ordinary enemies only — never a mini-boss (arena bosses aren't enemies) or a snowman (Q3)",
          RepulseFlight.isPin(isMiniBoss: false, isSnowman: false, isHittable: true)
            && !RepulseFlight.isPin(isMiniBoss: true, isSnowman: false, isHittable: true)
            && !RepulseFlight.isPin(isMiniBoss: false, isSnowman: true, isHittable: true)
            && !RepulseFlight.isPin(isMiniBoss: false, isSnowman: false, isHittable: false))
    // Gate rulings Q3/Q4 through the REAL card: the shove each body takes per tier.
    let rp = PlayerStats()
    let repulseCard = card("guard_2", UpgradeManager())
    var shoves: [(ordinary: CGFloat, mini: CGFloat, snowman: CGFloat)] = []
    let t1 = G.repulseShove[0]
    let tiers: [(PlayerStats) -> Void] = [repulseCard.apply] + repulseCard.higherTiers
    for apply in tiers {
        apply(rp)
        shoves.append((RepulseFlight.shoveDistance(tierShove: rp.knockbackForce, t1Shove: t1, isMiniBoss: false, isSnowman: false),
                       RepulseFlight.shoveDistance(tierShove: rp.knockbackForce, t1Shove: t1, isMiniBoss: true, isSnowman: false),
                       RepulseFlight.shoveDistance(tierShove: rp.knockbackForce, t1Shove: t1, isMiniBoss: false, isSnowman: true)))
    }
    check("RP11 Q4: ordinary enemies take the tier's shove (20, 60); mini-bosses a FIXED 20pt at every tier, never launched",
          shoves[0].ordinary == 20 && shoves[1].ordinary == 60
            && shoves.allSatisfy { $0.mini == 20 }
            && !RepulseFlight.isLaunchable(isMiniBoss: true, isSnowman: false) && rp.repulseLaunches,
          "\(shoves)")
    check("RP12 Q3: snowmen are fully knockback-immune — 0 at every tier, never launched, never a pin",
          shoves.allSatisfy { $0.snowman == 0 }
            && !RepulseFlight.isLaunchable(isMiniBoss: false, isSnowman: true)
            && !RepulseFlight.isPin(isMiniBoss: false, isSnowman: true, isHittable: true))
}

// CA — the cards, gates and copy.
do {
    let um = UpgradeManager()
    let guardCards = um.allCards.filter { $0.tag == .guardT }
    check("CA1 Guard stays 10 cards (primary tag); the pool is 80 after A6 (CL-83)",
          guardCards.count == 10 && um.allCards.count == 80, "guard=\(guardCards.count) pool=\(um.allCards.count)")
    let repulse = card("guard_2", um)
    check("CA2 Repulse is the PERMANENT Guard signature: 3 tiers, provides .guardUnlocked, no requires (CL-49)",
          repulse.isSignature && repulse.provides == [.guardUnlocked] && repulse.requires.isEmpty && repulse.maxTier == 3)
    check("CA3 still projectile-scoped by TEXT (Red Smile's sweep never carries it, CL-62)",
          repulse.description.hasPrefix("Projectiles") && (repulse.detail ?? "").hasPrefix("Projectiles"))
    check("CA4 exactly one Guard signature", guardCards.filter { $0.isSignature }.count == 1)
    let gated = ["guard_1", "guard_3", "guard_4", "v13_phase_skin", "v16_iron_bloom", "v16_aegis_pulse",
                 "v17_grounded_core", "v18_silver_skin", "cap_guard_ironmaiden"]
    check("CA5 every non-signature Guard card requires EXACTLY .guardUnlocked — Brace, Iron Maiden and Silver Skin too (CL-50)",
          gated.allSatisfy { card($0, um).requires == [.guardUnlocked] }
            && Set(guardCards.filter { !$0.isSignature }.map(\.id)) == Set(gated))
    check("CA6 Deeproot unchanged: Growth primary, Guard secondary, requires .growthUnlocked only",
          card("v20_deeproot", um).requires == [.growthUnlocked] && card("v20_deeproot", um).secondaryTag == .guardT)

    let s = PlayerStats()
    let slowBefore = s.globalEnemySlow
    card("guard_4", um).apply(s)
    check("CA7 Fortify: one tier, sets the stance, and no longer touches the global slow (CL-64)",
          card("guard_4", um).maxTier == 1 && s.fortifyOwned && s.globalEnemySlow == slowBefore)
    card("guard_3", um).apply(s)
    check("CA8 Harden: collision ×0.70 and the bounce", near(s.collisionShrink, 0.70) && s.hardenOwned)
    card("v13_phase_skin", um).apply(s)
    check("CA9 Phase Skin: 3.5s cooldown from the trigger, 1s window (CL-66)",
          s.phaseSkinCooldown == 3.5 && s.phaseSkinDuration == 1.0)
    let aegis = card("v16_aegis_pulse", um)
    let a = PlayerStats()
    aegis.apply(a); let t1 = a.aegisReduction
    aegis.higherTiers[0](a); let t2 = a.aegisReduction
    aegis.higherTiers[1](a); let t3 = a.aegisReduction
    check("CA10 Aegis (id kept, renamed): 25% / 25% / 35% by tier (CL-58)",
          aegis.name == "Aegis" && aegis.maxTier == 3 && near(t1, 0.25) && near(t2, 0.25) && near(t3, 0.35) && a.aegisTier == 3)
    let r = PlayerStats()
    repulse.apply(r); let k1 = r.knockbackForce
    repulse.higherTiers[0](r); let k2 = r.knockbackForce
    repulse.higherTiers[1](r)
    check("CA11 Repulse: T1 20pt, T2 60pt, T3 launches (CL-62/63)",
          k1 == 20 && k2 == 60 && r.repulseTier == 3 && r.repulseLaunches)
    let maiden = card("cap_guard_ironmaiden", um)
    check("CA12 Iron Maiden: T4 copy matches the config's threshold of 4 (CL-67)",
          maiden.description(forTier: 4).hasSuffix("at 4") && GameConfig.IronMaiden.kineticThreshold == 4)

    func lines(_ text: String) -> Int {
        var n = 0, cur = 0
        for w in text.split(separator: " ") {
            if cur == 0 { cur = w.count; n += 1 } else if cur + 1 + w.count <= 17 { cur += 1 + w.count } else { cur = w.count; n += 1 }
        }
        return n
    }
    var overflow: [String] = []
    for c in guardCards where c.id != "cap_guard_ironmaiden" {
        let budget = c.detail == nil ? 4 : 3
        for tier in 1...c.maxTier where lines(c.description(forTier: tier)) > budget {
            overflow.append("\(c.name) T\(tier)")
        }
    }
    check("CA13 every reworked Guard face fits its card (3×17 beside MORE, 4×17 without)", overflow.isEmpty,
          overflow.joined(separator: ", "))
    let brace = card("guard_1", um)
    check("CA14 Q5: Brace's face is \"Survive one lethal hit.\" and fits beside MORE; the full rule lives in the detail",
          brace.description == "Survive one lethal hit." && lines(brace.description) <= 3
            && (brace.detail ?? "").contains("triggers at 0 HP")
            && (brace.detail ?? "").contains("Brace saves you first, Unbroken Core second"))

    let ladder = UpgradeManager.synergyTiers(for: .guardT)
    check("CA15 ladder copy is the ruled copy (CL-69)",
          ladder.map(\.title) == ["Ironhide", "Thornwall", "Unbroken Core"]
            && ladder[0].effect == "Nearby enemies cut damage taken, up to 90%"
            && ladder[1].effect == "Enemies that touch you take 150% of the hit back"
            && ladder[2].effect == "Survive a lethal hit: 10s invulnerable, +ATK equal to DEF. A shield blocks projectiles.")

    let syn = UpgradeManager(), st = PlayerStats()
    let ids = ["guard_2", "guard_1", "guard_3", "guard_4", "v13_phase_skin", "v16_iron_bloom", "v16_aegis_pulse"]
    var at3 = false, at5 = false
    for (i, id) in ids.enumerated() {
        syn.pickCard(card(id, syn), stats: st, level: i + 1)
        _ = syn.checkSynergies(stats: st)
        if i == 2 { at3 = st.ironhideActive && st.thornsContactReflect == 0 }
        if i == 4 { at5 = st.thornsContactReflect == 1.50 && !st.unbrokenCoreOwned }
    }
    check("CA16 ×3 Ironhide switches on the % model (CL-52)", at3)
    check("CA17 ×5 Thornwall = 1.50 (CL-53)", at5)
    check("CA18 ×7 arms Unbroken's rescue AND equips the ready shield; the shrink stays (0.70 × 0.85)",
          st.unbrokenCoreOwned && st.unbrokenRescueAvailable && st.projectileShield.isReady
            && near(st.collisionShrink, 0.70 * 0.85))
    let plain = PlayerStats()
    plain.defense = 30
    let mult = plain.effectiveDamageMultiplier
    st.defense = 30
    st.baseAttack = plain.baseAttack
    check("CA19 the old always-on DEF→damage conversion is retired (×7 adds nothing outside the window)",
          near(st.effectiveDamageMultiplier, mult), "\(st.effectiveDamageMultiplier) vs \(mult)")
}

// EL — eligibility through the REAL draw: Guard opens only through Repulse.
do {
    func runWith(_ tags: [UpgradeManager.Tag]) -> UpgradeManager {
        for _ in 0..<500 {
            let run = UpgradeManager()
            if tags.allSatisfy({ run.activeFamilies.contains($0) }) { return run }
        }
        fatalError("500 palette rolls never activated \(tags)")
    }
    let run = runWith([.guardT, .fire])
    let st = PlayerStats()
    run.pickCard(card("fire_1", run), stats: st, level: 1)   // a signature, so full spreads draw
    var nonSignature = false, repulseOffered = false
    for level in 0..<200 {
        let spread = run.drawCards(count: 3, level: 2 + level % 20)
        if spread.contains(where: { $0.tag == .guardT && !$0.isSignature }) { nonSignature = true }
        if spread.contains(where: { $0.id == "guard_2" }) { repulseOffered = true }
    }
    check("EL1 before Repulse, no Guard card past the signature is offered — while Repulse itself IS (positive control)",
          !nonSignature && repulseOffered, "nonSignature=\(nonSignature) repulse=\(repulseOffered)")
    run.pickCard(card("guard_2", run), stats: st, level: 2)
    var opened = false
    for level in 0..<200 where run.drawCards(count: 3, level: 2 + level % 20)
        .contains(where: { $0.tag == .guardT && !$0.isSignature }) { opened = true; break }
    check("EL2 after Repulse, the rest of Guard opens", opened)
}

// KS — kill credit.
check("KS1 Repulse collision kills (.impact) are full credit; Iron Bloom's (.retaliation) too",
      KillSource.impact.credit == .full && KillSource.retaliation.credit == .full)

// CF — the REAL GameConfig.Guard (extracted from source and compiled here).
do {
    check("CF1 the shipped Guard numbers are the rulings",
          G.ironhidePerHostile == 0.09 && G.ironhideMaxContributors == 10 && G.thornwallReflect == 1.50
            && G.unbrokenWindow == 10 && G.shieldRearm == 6
            && G.aegisReduction == [0.25, 0.25, 0.35] && G.aegisBounce == [0, 40, 70] && G.aegisSpikeDEF == [0, 0.50, 0.75]
            && G.hardenShrink == 0.70 && G.hardenBounce == 40
            && G.ironBloomInterval == 4 && G.ironBloomDEFFraction == 0.50
            && G.repulseShove == [20, 60] && G.repulseLaunchDistance == 400 && G.repulseLaunchDuration == 0.35
            && G.repulseMaxStrikes == 3 && G.repulseCollisionATK == 0.25
            && G.fortifyStep == 0.5 && G.fortifyPerStep == 1 && G.fortifyCap == 30
            && G.groundedInterval == 7.5 && G.groundedCap == 30
            && G.phaseSkinCooldown == 3.5 && G.phaseSkinDuration == 1.0)
    check("CF2 the tuning BUILDERS carry them (not just the constants)",
          G.fortifyTuning.step == 0.5 && G.fortifyTuning.perStep == 1 && G.fortifyTuning.cap == 30
            && G.groundedTuning.interval == 7.5 && G.groundedTuning.cap == 30
            && G.ironhideTuning.perHostile == 0.09 && G.ironhideTuning.maxContributors == 10
            && G.bounceTuning.harden == 40 && G.bounceTuning.aegisByTier == [0, 40, 70]
            && G.bounceTuning.spikeByTier == [0, 0.50, 0.75]
            && G.launchTuning.distance == 400 && G.launchTuning.duration == 0.35 && G.launchTuning.maxStrikes == 3)
    check("CF3 radii (phone scale 1): Ironhide 150pt, Iron Bloom 70pt", G.ironhideRadius == 150 && G.ironBloomRadius == 70)
    // CL-68: purple means DANGER — no Guard tell may read as purple.
    func hue(_ hex: UInt32) -> (h: CGFloat, s: CGFloat) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255, g = CGFloat((hex >> 8) & 0xFF) / 255, b = CGFloat(hex & 0xFF) / 255
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        guard d > 0 else { return (0, 0) }
        var h: CGFloat
        if mx == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
        else if mx == g { h = (b - r) / d + 2 }
        else { h = (r - g) / d + 4 }
        h *= 60
        if h < 0 { h += 360 }
        return (h, mx == 0 ? 0 : d / mx)
    }
    let purple = [G.aegisBlueHex, G.steelHex, G.goldHex].filter {
        let c = hue($0); return c.s > 0.2 && c.h >= 255 && c.h <= 330
    }
    check("CF4 no Guard placeholder colour is purple (astral blue, steel, gold)", purple.isEmpty,
          purple.map { String($0, radix: 16) }.joined(separator: ","))
}

// WR — the scene WIRING. GameScene isn't compiled here, so its source is read:
// every pure rule above is only worth anything if the scene calls it.
do {
    let path = ProcessInfo.processInfo.environment["GUARD_SCENE"] ?? ""
    guard let src = try? String(contentsOfFile: path, encoding: .utf8) else {
        check("WR0 GameScene.swift is readable", false, path)
        exit(1)
    }
    /// The body of `private func name(` up to the next `    private func`.
    func body(_ name: String) -> String {
        guard let r = src.range(of: "private func \(name)(") else { return "" }
        let rest = src[r.upperBound...]
        let end = rest.range(of: "\n    private func ")?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
    }
    func order(_ text: String, _ marks: [String]) -> Bool {
        var from = text.startIndex
        for m in marks {
            guard let r = text.range(of: m, range: from..<text.endIndex) else { return false }
            from = r.upperBound
        }
        return true
    }
    let damage = body("applyPlayerDamage")
    check("WR1 the pipeline gets Ironhide AND Aegis (the stubbed-at-HEAD inputs, CL-52/58)",
          damage.contains("hit.ironhide = ironhideReduction") && damage.contains("hit.aegis = playerStats.aegisReduction"))
    check("WR2 the Unbroken rescue OPENS the window (CL-55/56)",
          order(damage, ["case .unbrokenCore:", "openUnbrokenWindow()"]))
    check("WR3 the window is its own timer ORed into isInvulnerable (CL-55)",
          src.contains("invulnerableTimer > 0 || playerStats.isPhaseSkinActive || playerStats.unbrokenWindow.isActive"))
    let bloom = body("ironBloomPulse")
    check("WR4 Iron Bloom pulses from update, only while playing; boss hit pierces the flat dial ONLY; kills full credit (CL-60/61)",
          src.contains("if playerStats.updateIronBloom(dt), gameState == .playing")
            && bloom.contains("ignoresChallengeDEF: true") && bloom.contains("source: .retaliation")
            && bloom.contains("isHittable") && bloom.contains("segmentBlockedExact"))
    let contact = body("handlePlayerEnemyContact")
    check("WR5 contact: bounce on the touch-begin BEFORE the damage guards; Thornwall only AFTER a damaging hit (CL-53/59)",
          order(contact, ["guardContactBounce(enemyBody)", "guard !isInvulnerable", "guard damageCooldownTimer <= 0",
                          "applyPlayerDamage(", "GuardRetaliation.thornwall("])
            && contact.contains("isArenaBoss: enemyBody.node is (any ArenaBossNode)"))
    check("WR6 Iron Maiden thorns and Retaliate go through the boss-class lever (CL-67)",
          contact.contains("GuardRetaliation.ironThorns(") && contact.contains("GuardRetaliation.ironRetaliate(")
            && contact.contains("let bossClass = isBossClass(enemyBody)"))
    // Gate rulings Q1/Q2 (Sep 24) — KEEP: the Aegis bounce/spike is an active
    // shield interaction that runs even under full invulnerability, and a
    // legitimate contact still resolves through the pipeline even when the
    // spike killed the toucher (no retroactive erase).
    let afterBounce: String = {
        guard let a = contact.range(of: "guardContactBounce(enemyBody)"),
              let b = contact.range(of: "applyPlayerDamage(", range: a.upperBound..<contact.endIndex) else { return "MISSING" }
        return String(contact[a.upperBound..<b.lowerBound])
    }()
    check("WR16 Q1: the bounce/spike sits BEFORE the invulnerability guard (invulnerability doesn't suppress Aegis)",
          order(contact, ["guardContactBounce(enemyBody)", "guard !isInvulnerable else { return }"]))
    check("WR17 Q2: nothing between the bounce and the damage pipeline cancels the hit when the toucher died",
          afterBounce != "MISSING" && !afterBounce.contains("isDying") && !afterBounce.contains("isDead"))
    let proj = body("handleEnemyProjectileHit")
    check("WR7 projectile shield AFTER i-frames and the cooldown, BEFORE Silver/Phase Skin (CL-57)",
          order(proj, ["guard !isInvulnerable", "guard damageCooldownTimer <= 0",
                       "projectileShield.tryBlock(invulnerable: isInvulnerable)", "consumeSilverSkin()", "triggerPhaseSkin()"]))
    let bounce = body("guardContactBounce")
    check("WR8 the bounce has no per-enemy throttle (every real touch-begin) and is path-tested (CL-59)",
          !bounce.contains("tryFire") && bounce.contains("guardShove(") && !src.contains("RetriggerGuard"))
    let enemiesBody = body("updateEnemies")
    // A6 re-wired the per-enemy branch (trap + fear join the flight): the
    // flight is still the FIRST branch, and slam/pull are gated by `pinned`,
    // which still includes `airborne`.
    check("WR9 fliers don't chase, slam or pull; Ironhide counts through the pure qualifier (CL-52/63)",
          enemiesBody.contains("let airborne = repulseFlights[ObjectIdentifier(enemy)] != nil")
            && order(enemiesBody, ["let airborne = repulseFlights[ObjectIdentifier(enemy)] != nil",
                                   "if airborne {", "} else if trapped {", "enemy.chase(target:"])
            && enemiesBody.contains("let pinned = airborne || trapped || fleeing")
            && enemiesBody.contains("if !pinned, let mote = enemy as? GravemoteNode")
            && enemiesBody.contains("if !pinned, let anvil = enemy as? AnvilbornNode")
            && enemiesBody.contains("Ironhide.qualifies("))
    let flights = body("updateRepulseFlights")
    check("WR10 launches: snowmen never fly, walls/Carrier stop them, pins tested along the path, .impact credit (CL-63)",
          flights.contains("!enemy.isSnowman") && flights.contains("segmentBlockedExact(from, to")
            && flights.contains("RepulseFlight.sweepOverlaps(") && flights.contains("RepulseFlight.isPin(")
            && flights.contains("source: .impact") && flights.contains("playerStats.effectiveAttack"))
    check("WR11 Repulse: the launch filter, the Q3/Q4 shove table and the path-tested shove (CL-62/63)",
          body("applyRepulse").contains("RepulseFlight.isLaunchable(")
            && body("applyRepulse").contains("RepulseFlight.shoveDistance(")
            && body("applyRepulse").contains("isSnowman: enemy.isSnowman")
            && body("applyRepulse").contains("guardShove("))
    let update = body("update") + src[(src.range(of: "override func update(")?.lowerBound ?? src.startIndex)...].prefix(6000)
    check("WR12 the stance runs AFTER active combat (Grounded reads this frame's combat, CL-65)",
          order(String(update), ["updateActiveCombat(dt)", "updateGuardStance(dt)"]))
    let stance = body("updateGuardStance")
    check("WR13 one input signal: Fortify and Grounded both read the stick (CL-64)",
          stance.contains("let hasInput = joystick.direction != .zero")
            && stance.contains("updateFortify(dt, hasInput: hasInput)")
            && stance.contains("updateGroundedCore(dt, still: !hasInput, inCombat: inActiveCombat)"))
    check("WR14 Unstable Core's self-damage asks the shared rescue order and honours the window (CL-54/55)",
          body("performUnstableCoreBurst").contains("PlayerDamagePipeline.lethalRescue(for: playerStats.damageDefender)")
            && body("performUnstableCoreBurst").contains("if !playerStats.unbrokenWindow.isActive"))
    let died = body("playerDied")
    check("WR15 death: the window ends, Grounded keeps earned DEF but loses progress, the stance breaks (CL-55/65)",
          died.contains("playerStats.unbrokenWindow.end()") && died.contains("playerStats.resetGroundedCoreProgress()")
            && died.contains("playerStats.resetFortify()") && died.contains("repulseFlights.removeAll()"))
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
