// main.swift — deterministic validators for v2.1 abilities Unit A6 (the Void
// rework). Rulings: closure table §B5 (CL-4/9/10/14, CL-70…CL-88, QA–QC, the
// build readings R1–R8 — Brandon, Sep 24).
//   RD  probabilistic rounding (CL-70)      WP  Warp Shot's curve (CL-14)
//   RF  Riftline's falloff (CL-81)          VH  Void affinity / Phase T2 (CL-71/72)
//   AN  Anomaly (CL-73/74)                  FE  Void Horror's fear + flight (CL-80)
//   VC  the primary-volley counter (CL-76)  WL  black holes: cap, absorb, return,
//                                               Dead Circuit (CL-10/77/78)
//   TR  the trap + Singularity (CL-79 / CL-9)
//   CA  the cards, gates, copy and the ladder (CL-82/83/84/88)
//   EL  eligibility through the real draw   KS  kill credit
//   CF  the REAL GameConfig.VoidTree (extracted from source) = the rulings
//   WR  the scene WIRING (GameScene isn't compiled — its source is read)
// Each validator prints PASS/FAIL; exit 1 on any FAIL. Everything is seeded
// except EL1–EL3, which sample the REAL card draw (its palette roll is random).

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
/// The selection card's wrap: 17 characters a line.
func lines(_ text: String) -> Int {
    var n = 0, cur = 0
    for w in text.split(separator: " ") {
        if cur == 0 { cur = w.count; n += 1 } else if cur + 1 + w.count <= 17 { cur += 1 + w.count } else { cur = w.count; n += 1 }
    }
    return n
}
let frame: TimeInterval = 1.0 / 64      // binary-exact
let frame60: TimeInterval = 1.0 / 60    // not binary-exact
let V = GameConfig.VoidTree.self

// RD — CL-70: exact N + f deals N+1 with probability f; a landed hit deals ≥ 1.
do {
    check("RD1 whole damage stays whole, whatever the draw",
          VoidRounding.damage(2.0, unit: 0.0) == 2 && VoidRounding.damage(2.0, unit: 0.999) == 2)
    check("RD2 1.5 → 2 below the fraction, 1 at/above it (unit is [0,1))",
          VoidRounding.damage(1.5, unit: 0.4999) == 2 && VoidRounding.damage(1.5, unit: 0.5) == 1)
    check("RD3 a landed sub-1 hit still deals 1 (Riftline's 56.25% at base) — never 0",
          VoidRounding.damage(0.5625, unit: 0.99) == 1 && VoidRounding.damage(0.5625, unit: 0.0) == 1)
    check("RD4 no positive damage, no damage", VoidRounding.damage(0, unit: 0) == 0)
    // Unbiased: the mean over an even grid of draws equals the exact value.
    func mean(_ x: CGFloat) -> CGFloat {
        let n = 10_000
        var total = 0
        for i in 0..<n { total += VoidRounding.damage(x, unit: (CGFloat(i) + 0.5) / CGFloat(n)) }
        return CGFloat(total) / CGFloat(n)
    }
    check("RD5 unbiased: 1.25 averages 1.25, 1.5 averages 1.5, 2.3 averages 2.3 (Shadow Edge / Warp)",
          near(mean(1.25), 1.25, 1e-3) && near(mean(1.5), 1.5, 1e-3) && near(mean(2.3), 2.3, 1e-3),
          "\(mean(1.25)) \(mean(1.5)) \(mean(2.3))")
    check("RD6 negative control: truncation would have hidden them (Int(1.25) = Int(1.5) = 1)",
          Int(CGFloat(1.25)) == 1 && Int(CGFloat(1.5)) == 1 && mean(1.25) > 1.2)
    // The A6 fraction scales the shot's LEGACY (truncated) damage — no retrofit
    // of the older trees' fractional multiplier (internal review MED-1).
    func a6mean(_ m: CGFloat, _ f: CGFloat) -> CGFloat {
        let n = 10_000
        var total = 0
        for i in 0..<n { total += VoidRounding.a6Damage(multiplier: m, fraction: f, unit: (CGFloat(i) + 0.5) / CGFloat(n)) }
        return CGFloat(total) / CGFloat(n)
    }
    let first = CGFloat(max(1, Int(CGFloat(1.5))))
    check("RD7 Riftline never climbs: at multiplier 1.5 the bodies average 1 ≥ 1 ≥ 1 (was 1 → 1.125 → 1)",
          a6mean(1.5, 0.75) <= first && a6mean(1.5, 0.5625) <= a6mean(1.5, 0.75) + 1e-9
            && near(a6mean(2.4, 0.75), 1.5, 1e-3) && near(a6mean(2.4, 0.5625), 1.125, 1e-3))
    check("RD8 a Warp shot at full speed deals exactly a plain shot's damage (1.5 → 1, 2.7 → 2); at launch 150% of it",
          VoidRounding.a6Damage(multiplier: 1.5, fraction: 1.0, unit: 0.0) == 1
            && VoidRounding.a6Damage(multiplier: 2.7, fraction: 1.0, unit: 0.0) == 2
            && near(a6mean(1.5, 1.5), 1.5, 1e-3) && near(a6mean(2.7, 1.5), 3.0, 1e-3))
}

// WP — CL-14: 40% → 100% speed over 0.6s; 150% → 100% damage; linear.
do {
    let w = V.warpCurve
    check("WP1 at launch: 40% speed, 150% damage",
          near(w.speedFraction(age: 0), 0.40) && near(w.damageFraction(age: 0), 1.50))
    check("WP2 halfway (0.3s): 70% speed, 125% damage",
          near(w.speedFraction(age: 0.3), 0.70) && near(w.damageFraction(age: 0.3), 1.25))
    check("WP3 from 0.6s on: full speed, 100% damage",
          near(w.speedFraction(age: 0.6), 1) && near(w.damageFraction(age: 0.6), 1)
            && near(w.speedFraction(age: 5), 1) && near(w.damageFraction(age: 5), 1))
    // Distance by the time it reaches full speed: ∫ 0.4→1.0 over 0.6s = 0.42s of full speed.
    var age: TimeInterval = 0, dist: CGFloat = 0
    while age < 0.6 - 1e-9 { dist += w.speedFraction(age: age) * CGFloat(frame); age += frame }
    check("WP4 a Warp shot covers ~42% of a normal shot's distance over its ramp", near(dist / 0.6, 0.70, 0.01),
          "\(dist / 0.6)")
}

// RF — CL-81: pierce 2 = up to 3 bodies; 100%, 75%, 56.25%.
do {
    check("RF1 falloff by body: 1, 0.75, 0.5625",
          near(RiftlineFalloff.fraction(priorHits: 0, falloff: V.riftlineFalloff), 1)
            && near(RiftlineFalloff.fraction(priorHits: 1, falloff: V.riftlineFalloff), 0.75)
            && near(RiftlineFalloff.fraction(priorHits: 2, falloff: V.riftlineFalloff), 0.5625))
    let um = UpgradeManager(), s = PlayerStats()
    card("v18_riftline", um).apply(s)
    check("RF2 Riftline card: pierce +2 (3 hits), +25% range, falloff on",
          s.pierceCount == 2 && near(s.projectileRangeMultiplier, 1.25) && s.riftlineActive)
}

// VH — CL-71/72: affinity = Braceguard bypass; flat-DEF penetration is Phase T2
// and shot-class only (primary gun shots, returned shots).
do {
    check("VH1 a primary shot is Void only at Phase T2 — then it bypasses Braceguard AND the dial",
          VoidHit.primaryShot(phaseT2: false) == .none
            && VoidHit.primaryShot(phaseT2: true) == VoidHit(affinity: true, flatDEFPenetration: true))
    check("VH2 a returned shot is always Void; it penetrates with Phase T2 (CL-4)",
          VoidHit.returned(phaseT2: false) == VoidHit(affinity: true, flatDEFPenetration: false)
            && VoidHit.returned(phaseT2: true) == VoidHit(affinity: true, flatDEFPenetration: true))
    check("VH3 Red Smile and Shadow Edge: Void affinity, NEVER Phase T2's penetration (not shots)",
          VoidHit.redSmile == VoidHit(affinity: true, flatDEFPenetration: false)
            && VoidHit.shadowEdge == VoidHit(affinity: true, flatDEFPenetration: false))
}

// AN — CL-73/74: 4 stacks; normals erased; elites (mini-bosses) 20%, bosses 3%
// — FINAL values; 2s cooldown with no stacks for elites/bosses.
do {
    let t = V.anomalyTuning
    var a = AnomalyState()
    let three = (0..<3).map { _ in a.add(1, target: .normal, tuning: t) }
    let fourth = a.add(1, target: .normal, tuning: t)
    check("AN1 a normal: three stacks do nothing, the 4th erases, stacks clear",
          three == [.none, .none, .none] && fourth == .erase && a.stacks == 0)
    var b = AnomalyState()
    check("AN2 T3's two stacks per hit: the 2nd hit erases",
          b.add(2, target: .normal, tuning: t) == .none && b.add(2, target: .normal, tuning: t) == .erase)
    var c = AnomalyState()
    _ = c.add(3, target: .normal, tuning: t)
    check("AN3 overflow is discarded — 3 + 2 triggers and leaves nothing",
          c.add(2, target: .normal, tuning: t) == .erase && c.stacks == 0)
    var m = AnomalyState()
    _ = m.add(2, target: .miniBoss, tuning: t)
    let chunk = m.add(2, target: .miniBoss, tuning: t)
    let refused = m.add(2, target: .miniBoss, tuning: t)
    check("AN4 a mini-boss takes a 20% chunk, then the 2s cooldown refuses new stacks",
          chunk == .chunk(fraction: 0.20) && m.isCooling && refused == .none && m.stacks == 0)
    for _ in 0..<127 { m.tick(frame) }
    let stillCooling = m.isCooling
    m.tick(frame)
    check("AN5 the cooldown is 2s of game time (128 × 1/64s)", stillCooling && !m.isCooling)
    check("AN6 stacks build again after it", m.add(1, target: .miniBoss, tuning: t) == .none && m.stacks == 1)
    var boss = AnomalyState()
    _ = boss.add(3, target: .boss, tuning: t)
    check("AN7 an arena boss takes 3% — a FINAL value, scaled once (CL-74) — then cools",
          boss.add(1, target: .boss, tuning: t) == .chunk(fraction: 0.03) && boss.isCooling)
    check("AN8 the chunk as damage: 20% of a 28-HP mini-boss = 5; 3% of 300 = 9; never below 1",
          AnomalyState.chunkDamage(maxHealth: 28, fraction: 0.20) == 5
            && AnomalyState.chunkDamage(maxHealth: 300, fraction: 0.03) == 9
            && AnomalyState.chunkDamage(maxHealth: 10, fraction: 0.03) == 1)
    check("AN9 negative control: a second BossClass halving would have made the boss chunk 1.5%",
          AnomalyState.chunkDamage(maxHealth: 300, fraction: 0.03 * GameConfig.BossClass.damageScale) == 4)
    var normalNoCooldown = AnomalyState()
    for _ in 0..<4 { _ = normalNoCooldown.add(1, target: .normal, tuning: t) }
    check("AN10 an erase starts no cooldown (the normal is gone)", !normalNoCooldown.isCooling)
}

// FE — CL-80: 8% per eligible primary hit; 0.5s (elites 0.25s); bosses immune;
// 2s immunity once it ends; a stronger control cancels it and starts immunity.
do {
    let t = V.horrorTuning
    var f = FearState()
    check("FE1 fear starts, and never refreshes or stacks",
          f.tryFear(duration: 0.5) && f.isFeared && !f.tryFear(duration: 0.5))
    for _ in 0..<31 { f.tick(frame, immunityDuration: t.immunity) }
    let stillAfraid = f.isFeared
    f.tick(frame, immunityDuration: t.immunity)
    check("FE2 it lasts 0.5s (32 × 1/64s), then 2s of immunity begins", stillAfraid && !f.isFeared && f.isImmune)
    check("FE3 immune: no new fear", !f.tryFear(duration: 0.5))
    for _ in 0..<128 { f.tick(frame, immunityDuration: t.immunity) }
    check("FE4 after 2s it can be feared again", !f.isImmune && f.tryFear(duration: 0.5))
    var g = FearState()
    _ = g.tryFear(duration: 0.5)
    check("FE5 a stronger control mid-fear cancels it AND starts the immunity window",
          g.cancel(immunityDuration: t.immunity) && !g.isFeared && g.isImmune && !g.tryFear(duration: 0.5))
    var h = FearState()
    check("FE6 cancel with no fear running does nothing (no immunity from nowhere)",
          !h.cancel(immunityDuration: t.immunity) && !h.isImmune)
    func target(_ c: VoidTargetClass = .normal, hittable: Bool = true, snowman: Bool = false, airborne: Bool = false,
                trapped: Bool = false, hard: Bool = false) -> VoidHorror.Target {
        VoidHorror.Target(targetClass: c, hittable: hittable, snowman: snowman, airborne: airborne,
                          trapped: trapped, hardControlled: hard)
    }
    check("FE7 eligible: hittable normals and mini-bosses only",
          VoidHorror.eligible(target()) && VoidHorror.eligible(target(.miniBoss))
            && !VoidHorror.eligible(target(.boss)) && !VoidHorror.eligible(target(hittable: false))
            && !VoidHorror.eligible(target(snowman: true)) && !VoidHorror.eligible(target(airborne: true))
            && !VoidHorror.eligible(target(trapped: true)) && !VoidHorror.eligible(target(hard: true)))
    check("FE8 durations: normals 0.5s, mini-bosses 0.25s, bosses none",
          VoidHorror.duration(for: .normal, tuning: t) == 0.5 && VoidHorror.duration(for: .miniBoss, tuning: t) == 0.25
            && VoidHorror.duration(for: .boss, tuning: t) == nil)
    check("FE9 the roll is 8%", VoidHorror.rolls(unit: 0.0799, tuning: t) && !VoidHorror.rolls(unit: 0.08, tuning: t))
    // Flight: away from Spark, inside the wall; outside the wall → no move.
    let R: CGFloat = 350
    let goal = FleeRule.goal(from: CGPoint(x: 100, y: 0), awayFrom: .zero, lookahead: 120, arenaRadius: R, footprint: 14)
    check("FE10 the escape point is straight away from Spark", goal.map { near($0.x, 220) && near($0.y, 0) } ?? false,
          "\(String(describing: goal))")
    let clamped = FleeRule.goal(from: CGPoint(x: 300, y: 0), awayFrom: .zero, lookahead: 120, arenaRadius: R, footprint: 14)
    check("FE11 …clamped inside the wall (R − footprint)", clamped.map { near(hypot($0.x, $0.y), R - 14) } ?? false)
    check("FE12 an enemy still outside the wall doesn't flee (the Repulse-flight rule)",
          FleeRule.goal(from: CGPoint(x: R + 40, y: 0), awayFrom: .zero, lookahead: 120, arenaRadius: R, footprint: 14) == nil)
    let band = FleeRule.goal(from: CGPoint(x: 0, y: R - 5), awayFrom: CGPoint(x: -100, y: R - 5), lookahead: 120,
                             arenaRadius: R, footprint: 35)
    check("FE12b an enemy INSIDE the wall but within a footprint of it still flees (sideways/inward)",
          band != nil)
    // A wall of solid at x ≥ 150: the escape ray stops on the enemy's side of it.
    let cut = FleeRule.truncate(from: CGPoint(x: 100, y: 0), to: CGPoint(x: 220, y: 0)) { $0.x >= 150 }
    let stuck = FleeRule.truncate(from: CGPoint(x: 149, y: 0), to: CGPoint(x: 260, y: 0)) { $0.x >= 150 }
    check("FE12c the escape ray is cut at the last open ground before solid — never pushed to the far face (H1)",
          cut.x < 150 && cut.x > 140 && near(stuck.x, 149))
    let step = FleeRule.step(from: CGPoint(x: 100, y: 0), toward: CGPoint(x: 220, y: 0), moveSpeed: 130, slow: 0,
                             dt: 0.1, arenaRadius: R, footprint: 14)
    let slowed = FleeRule.step(from: CGPoint(x: 100, y: 0), toward: CGPoint(x: 220, y: 0), moveSpeed: 130, slow: 5,
                               dt: 0.1, arenaRadius: R, footprint: 14)
    check("FE13 one step at the chase speed (13pt in 0.1s at 130); slows cap at 80% like chase",
          near(step.x, 113) && near(slowed.x, 102.6))
    let wall = FleeRule.step(from: CGPoint(x: R - 15, y: 0), toward: CGPoint(x: R + 100, y: 0), moveSpeed: 130, slow: 0,
                             dt: 0.1, arenaRadius: R, footprint: 14)
    check("FE14 a step never carries it out past the wall", hypot(wall.x, wall.y) <= R - 14 + 1e-6 + 1)
}

// VC — CL-76: ONE counter; every 5th Blackhole, every 7th blade; volley 35 does
// both; an empty volley is no volley (ruled Sep 24).
do {
    let t = V.volleyTuning
    var vc = VolleyCounter()
    var holes = 0, blades = 0, both = 0, bothAt: [Int] = []
    for _ in 1...35 {
        let r = vc.register(emitted: true, blackholeOwned: true, bladeOwned: true, tuning: t)
        if r.blackhole { holes += 1 }
        if r.blade { blades += 1 }
        if r.blackhole && r.blade { both += 1; bothAt.append(vc.volleys) }
    }
    check("VC1 35 volleys: 7 Blackholes, 5 blades, and #35 is both (the DoD)",
          holes == 7 && blades == 5 && both == 1 && bothAt == [35])
    var e = VolleyCounter()
    for _ in 0..<4 { _ = e.register(emitted: true, blackholeOwned: true, bladeOwned: false, tuning: t) }
    let empty = e.register(emitted: false, blackholeOwned: true, bladeOwned: false, tuning: t)
    let fifth = e.register(emitted: true, blackholeOwned: true, bladeOwned: false, tuning: t)
    check("VC2 an empty volley doesn't advance the counter — the next REAL volley is the 5th",
          empty == .nothing && fifth.blackhole && e.volleys == 5)
    var o = VolleyCounter()
    for _ in 0..<5 { _ = o.register(emitted: true, blackholeOwned: false, bladeOwned: false, tuning: t) }
    let sixth = o.register(emitted: true, blackholeOwned: true, bladeOwned: false, tuning: t)
    check("VC3 the counter is run-long: it counts before the synergy is owned (volley 10 is the next hole)",
          o.volleys == 6 && !sixth.blackhole)
    // Glacial Condensation: 1 pellet a volley, one icicle per 3 → 1 qualifying volley in 3.
    var g = VolleyCounter()
    var glacialHoles = 0
    let glacialEveryN = 3   // the app's GameConfig.PolarVortex.glacialEveryN (read from source in WR27)
    for fired in 1...45 {
        let emitted = fired % glacialEveryN == 0
        if g.register(emitted: emitted, blackholeOwned: true, bladeOwned: false, tuning: t).blackhole { glacialHoles += 1 }
    }
    check("VC4 a 1-pellet Glacial build: a Blackhole every 15 volleys fired (the ruled consequence)",
          glacialHoles == 3 && g.volleys == 15)
}

// WL — CL-10/77/78: the cap, absorption, returns, Dead Circuit.
do {
    let allLive = [true, true, true, true]
    check("WL1 at four live, the oldest ordinary Gravity Well goes first…",
          VoidWellCap.evictionIndex(presets: [.blackhole, .gravityWell, .nullBloom, .gravityWell], live: allLive, cap: 4) == 1)
    check("WL2 …otherwise the oldest hole; under the cap, nothing",
          VoidWellCap.evictionIndex(presets: [.blackhole, .nullBloom, .blackhole, .nullBloom], live: allLive, cap: 4) == 0
            && VoidWellCap.evictionIndex(presets: [.blackhole, .gravityWell, .nullBloom], live: [true, true, true], cap: 4) == nil)
    check("WL1b a hole already ending (collapse pending / expired) neither counts nor is evicted — its burst survives",
          VoidWellCap.evictionIndex(presets: [.gravityWell, .blackhole, .nullBloom, .gravityWell, .blackhole],
                                    live: [false, true, true, true, true], cap: 4) == 3
            && VoidWellCap.evictionIndex(presets: [.gravityWell, .blackhole, .nullBloom, .blackhole],
                                         live: [false, true, true, true], cap: 4) == nil)
    var w = VoidWellState(id: 1, preset: .blackhole, baseRadius: 60, lifetime: 2.5, capacity: V.absorbCapacity,
                          deadCircuit: nil)
    var absorbed = 0
    for _ in 0..<12 where w.tryAbsorb(holdForReturn: true, returnDelay: V.returnDelay) { absorbed += 1 }
    check("WL3 a hole absorbs at most 8 hostile shots", absorbed == 8 && w.held.count == 8)
    let readyAtOnce = w.readyReturns
    for _ in 0..<9 { w.tick(frame60) }      // 0.15s
    check("WL4 held shots are ready 0.15s after the absorb", readyAtOnce == 0 && w.readyReturns == 8)
    check("WL5 one ready return is taken per shot fired; the rest drain when the hole ends",
          w.takeReadyReturn() && w.readyReturns == 7 && w.drainHeld() == 7 && w.held.isEmpty)
    var noHold = VoidWellState(id: 2, preset: .gravityWell, baseRadius: 30, lifetime: 1, capacity: 8, deadCircuit: nil)
    check("WL6 without Listlessness an absorbed shot is simply gone",
          noHold.tryAbsorb(holdForReturn: false, returnDelay: 0.15) && noHold.held.isEmpty && noHold.absorbed == 1)
    var dc = VoidWellState(id: 3, preset: .nullBloom, baseRadius: 36, lifetime: 1.2, capacity: 8,
                           deadCircuit: V.deadCircuitTuning)
    dc.addMatter()
    let grown = dc.radius
    dc.addMatter()
    let collapsed = dc.addMatter()
    check("WL7 Dead Circuit: +25% radius per matter; the 3rd collapses it",
          near(grown, 45) && collapsed && dc.collapsePending && near(dc.radius, 63))
    check("WL8 a collapsing hole takes no more matter or shots", !dc.isLive && !dc.addMatter()
            && !dc.tryAbsorb(holdForReturn: true, returnDelay: 0.15))
    var plain = VoidWellState(id: 4, preset: .gravityWell, baseRadius: 30, lifetime: 1, capacity: 8, deadCircuit: nil)
    check("WL9 without Dead Circuit, matter means nothing", !plain.addMatter() && plain.matter == 0 && near(plain.radius, 30))
    var life = VoidWellState(id: 5, preset: .blackhole, baseRadius: 60, lifetime: V.blackholeLifetime, capacity: 8, deadCircuit: nil)
    var ticks = 0
    while !life.tick(frame) { ticks += 1 }
    check("WL10 a Blackhole lives 2.5s of game time (160 × 1/64s)", ticks + 1 == 160 && !life.isLive)
    var dot = VoidWellState(id: 6, preset: .blackhole, baseRadius: 60, lifetime: 9, capacity: 8, deadCircuit: V.deadCircuitTuning)
    var dealt = 0
    for _ in 0..<60 { dealt += dot.damageTick(frame60, perSecond: 1.0) }
    check("WL11 Dead Circuit's damage inside is fraction-first: 1/s is exactly 1 per second", dealt == 1)
    check("WL12 contains: a body centred inside the (grown) radius",
          dc.contains(CGPoint(x: 62, y: 0), center: .zero) && !dc.contains(CGPoint(x: 64, y: 0), center: .zero))
    var ending = VoidWellState(id: 7, preset: .blackhole, baseRadius: 60, lifetime: 2.5, capacity: 8, deadCircuit: V.deadCircuitTuning)
    let firstEnd = ending.end(), secondEnd = ending.end()
    check("WL13 ending is idempotent, and an ended hole does nothing more (no absorb, no matter)",
          firstEnd && !secondEnd && !ending.isLive && !ending.tryAbsorb(holdForReturn: true, returnDelay: 0.15) && !ending.addMatter())
}

// TR — CL-79 / CL-9: the trap and Singularity.
do {
    let t = V.trapTuning
    var n = VoidTrapState()
    check("TR1 a normal caught by a live hole (×5 only) is held for the well's remaining life",
          n.capture(wellID: 7, wellRemaining: 1.5, target: .normal, singularity: false, tuning: t)
            && n.isTrapped && near(CGFloat(n.hold.remaining), 1.5))
    n.wellEnded(7)
    check("TR2 …and released when that well ends", !n.isTrapped)
    var m = VoidTrapState()
    _ = m.capture(wellID: 8, wellRemaining: 2.0, target: .miniBoss, singularity: true, tuning: t)
    check("TR3 a mini-boss: half the well's remaining life, never terminal", near(CGFloat(m.hold.remaining), 1.0) && !m.terminal)
    for _ in 0..<64 { m.tick(frame) }
    check("TR4 released after it — and that well can't take it again; another can",
          !m.isTrapped && !m.capture(wellID: 8, wellRemaining: 1, target: .miniBoss, singularity: false, tuning: t)
            && m.capture(wellID: 9, wellRemaining: 1, target: .miniBoss, singularity: false, tuning: t))
    for _ in 0..<64 { m.tick(frame) }   // released by well 9 too
    check("TR4b a mini-boss remembers EVERY hole that released it (A, then B: A still can't take it back)",
          !m.isTrapped && !m.capture(wellID: 8, wellRemaining: 1, target: .miniBoss, singularity: false, tuning: t)
            && !m.capture(wellID: 9, wellRemaining: 1, target: .miniBoss, singularity: false, tuning: t)
            && m.capture(wellID: 11, wellRemaining: 1, target: .miniBoss, singularity: false, tuning: t))
    var b = VoidTrapState()
    check("TR5 an arena boss is never trapped", !b.capture(wellID: 1, wellRemaining: 2, target: .boss, singularity: true, tuning: t))
    var s = VoidTrapState()
    _ = s.capture(wellID: 10, wellRemaining: 0.2, target: .normal, singularity: true, tuning: t)
    s.wellEnded(10)
    check("TR6 with Singularity a normal's hold is TERMINAL: 2s, and it outlives its well",
          s.terminal && s.isTrapped && near(CGFloat(s.hold.remaining), 2.0))
    // Decompose first, then the hold ticks — the scene's order. A 4-HP normal
    // must be fully decomposed within the terminal hold at 64, 60 and 30 fps.
    func decomposeToEnd(maxHealth: Int, dt: TimeInterval) -> (dealt: Int, seconds: Double) {
        var trap = VoidTrapState()
        _ = trap.capture(wellID: 1, wellRemaining: 0.1, target: .normal, singularity: true, tuning: t)
        var dealt = 0, seconds = 0.0
        while trap.isTrapped {
            dealt += trap.decompose(dt, maxHealth: maxHealth, tuning: t)
            trap.tick(dt)
            seconds += dt
        }
        return (dealt, seconds)
    }
    let d64 = decomposeToEnd(maxHealth: 4, dt: frame)
    let d60 = decomposeToEnd(maxHealth: 4, dt: frame60)
    let d30 = decomposeToEnd(maxHealth: 4, dt: 1.0 / 30)
    let d1 = decomposeToEnd(maxHealth: 1, dt: frame60)
    check("TR7 50%/s: a trapped normal decomposes to death inside the ≤2s terminal hold (64/60/30 fps)",
          d64.dealt >= 4 && d60.dealt >= 4 && d30.dealt >= 4 && d1.dealt >= 1
            && d64.seconds <= 2.0 + 1e-9 && d60.seconds <= 2.0 + frame60,
          "\(d64) \(d60) \(d30) \(d1)")
    func negativeTickFirst(maxHealth: Int, dt: TimeInterval) -> Int {
        var trap = VoidTrapState()
        _ = trap.capture(wellID: 1, wellRemaining: 0.1, target: .normal, singularity: true, tuning: t)
        var dealt = 0
        while trap.isTrapped {
            trap.tick(dt)
            dealt += trap.decompose(dt, maxHealth: maxHealth, tuning: t)
        }
        return dealt
    }
    check("TR8 negative control: ticking the hold BEFORE decomposing loses the last frame (60 fps leaves it alive)",
          negativeTickFirst(maxHealth: 4, dt: frame60) < 4)
    var mb = VoidTrapState()
    _ = mb.capture(wellID: 2, wellRemaining: 10, target: .miniBoss, singularity: true, tuning: t)
    var mbDealt = 0
    while mb.isTrapped { mbDealt += mb.decompose(frame, maxHealth: 100, tuning: t); mb.tick(frame) }
    check("TR9 a mini-boss decomposes 8%/s, capped at 20% of max HP per trap (5s hold → 20, not 40)",
          mbDealt == 20, "\(mbDealt)")
    var free = VoidTrapState()
    check("TR10 nothing decomposes while free", free.decompose(1, maxHealth: 100, tuning: t) == 0)
    var bd = BossDecompose()
    var bossDealt = 0
    for _ in 0..<64 { bossDealt += bd.tick(frame, overlapping: true, maxHealth: 300, rate: V.decomposeBoss) }
    var off = 0
    for _ in 0..<64 { off += bd.tick(frame, overlapping: false, maxHealth: 300, rate: V.decomposeBoss) }
    check("TR11 a boss: 1% max HP/s only while overlapping (300 HP → 3 per second, 0 away)", bossDealt == 3 && off == 0)
    var rel = VoidTrapState()
    _ = rel.capture(wellID: 3, wellRemaining: 5, target: .normal, singularity: true, tuning: t)
    rel.release()
    check("TR12 a forced release (death, transformation, cleanup) ends even a terminal hold", !rel.isTrapped)
}

// CA — the cards, gates, copy and the ladder.
do {
    let um = UpgradeManager()
    let voidCards = um.allCards.filter { $0.tag == .voidT }
    check("CA1 pool 80 (79 − Mass Tax + Void Horror + Shadow Edge); Void 13 by primary tag (CL-83)",
          um.allCards.count == 80 && voidCards.count == 13, "pool=\(um.allCards.count) void=\(voidCards.count)")
    check("CA2 Mass Tax is retired — its id is gone",
          !um.allCards.contains { $0.id == "v16_mass_tax" || $0.name == "Mass Tax" })
    let horror = card("v21_void_horror", um), edge = card("v21_shadow_edge", um)
    check("CA3 the new cards: Void primary, one tier each", horror.tag == .voidT && edge.tag == .voidT
            && horror.maxTier == 1 && edge.maxTier == 1)
    let phase = card("void_3", um)
    check("CA4 Phase stays THE signature (same id), provides .voidUnlocked, 3 tiers, requires nothing",
          phase.isSignature && phase.provides == [.voidUnlocked] && phase.requires.isEmpty && phase.maxTier == 3
            && voidCards.filter { $0.isSignature }.count == 1)
    let nonSig = voidCards.filter { !$0.isSignature }
    check("CA5 EVERY non-signature Void card requires .voidUnlocked — Erasure too (CL-82)",
          nonSig.allSatisfy { $0.requires.contains(.voidUnlocked) } && card("cap_void_erasure", um).requires == [.voidUnlocked],
          nonSig.filter { !$0.requires.contains(.voidUnlocked) }.map(\.id).joined(separator: ","))
    check("CA6 Dead Circuit also needs a black-hole card; Gravity Well and Null Bloom provide it",
          card("v17_dead_circuit", um).requires == [.voidUnlocked, .voidWell]
            && card("void_2", um).provides == [.voidWell] && card("v16_null_bloom", um).provides == [.voidWell]
            && um.allCards.filter { $0.provides.contains(.voidWell) }.count == 2)
    check("CA7 Silver Skin stays Guard-only (CL-50); Red Smile keeps its dual gate",
          card("v18_silver_skin", um).requires == [.guardUnlocked]
            && card("v18_red_smile", um).requires == [.bleedUnlocked, .voidUnlocked])
    // Phase tiers.
    let s1 = PlayerStats(), rangeBefore = s1.projectileRangeMultiplier
    phase.apply(s1)
    let t1 = (s1.phaseTier, s1.anomalyStacksPerHit, s1.phasePenetrates)
    phase.higherTiers[0](s1)
    let t2 = (s1.phaseTier, s1.anomalyStacksPerHit, s1.phasePenetrates)
    phase.higherTiers[1](s1)
    let t3 = (s1.phaseTier, s1.anomalyStacksPerHit, s1.phasePenetrates)
    check("CA8 Phase: T1 Anomaly · T2 penetration · T3 two stacks per hit",
          t1 == (1, 1, false) && t2 == (2, 1, true) && t3 == (3, 2, true))
    check("CA9 Phase carries no range or pierce now (CL-81)",
          s1.projectileRangeMultiplier == rangeBefore && s1.pierceCount == 0)
    let s2 = PlayerStats(), shotsBefore = s2.extraProjectiles
    card("void_1", um).apply(s2)
    check("CA10 Warp Shot warps; its +1 projectile is retired (Q-V1)", s2.warpShotActive && s2.extraProjectiles == shotsBefore)
    card("void_4", um).apply(s2)
    card("v17_dead_circuit", um).apply(s2)
    card("v16_null_bloom", um).apply(s2)
    horror.apply(s2); edge.apply(s2)
    check("CA11 Devour, Dead Circuit, Null Bloom (30%), Void Horror, Shadow Edge switch on",
          s2.devourActive && s2.deadCircuitActive && near(s2.nullBloomChance, 0.30) && s2.voidHorrorActive && s2.shadowEdgeActive)
    // CL-88 final copy — exact, and it fits.
    let faces: [(String, Int, String)] = [
        ("void_1", 1, "Slow shots that speed up. Slower = more damage."),
        ("void_2", 1, "Spent shots leave a pull zone (1s)"),
        ("void_3", 1, "Primary hits add Anomaly. Triggers at 4 stacks."),
        ("void_3", 2, "Your shots bypass Braceguard + DEF."),
        ("void_3", 3, "Each primary hit applies 2 Anomaly stacks."),
        ("void_4", 1, "XP orbs are pulled to you from 2x range."),
        ("v16_null_bloom", 1, "Kills may leave small black holes."),
        ("v17_dead_circuit", 1, "Black holes grow as they feed, then burst."),
        ("v18_riftline", 1, "Shots pierce 2 enemies (3 hits). +25% range."),
        ("v21_void_horror", 1, "Primary hits may make enemies flee."),
        ("v21_shadow_edge", 1, "Every 7th volley also fires a shadow blade."),
    ]
    let wrong = faces.filter { card($0.0, um).description(forTier: $0.1) != $0.2 }
    check("CA12 every face is the CL-88 FINAL copy, word for word", wrong.isEmpty,
          wrong.map { "\($0.0) T\($0.1)" }.joined(separator: ", "))
    let overflow = faces.filter { f in
        let c = card(f.0, um)
        return lines(c.description(forTier: f.1)) > (c.detail == nil ? 4 : 3)
    }
    check("CA13 every face fits its card (3×17 beside MORE, 4×17 without)", overflow.isEmpty,
          overflow.map { "\($0.0) T\($0.1)" }.joined(separator: ", "))
    check("CA14 the details carry the ruled numbers (Phase T2 is narrow; Riftline = 3 hits; Shadow Edge not a shot)",
          (phase.detail ?? "").contains("Braceguard shields and the Boss Mode flat DEF setting. It does not bypass other defenses.")
            && (card("v18_riftline", um).detail ?? "").contains("can hit up to 3")
            && (edge.detail ?? "").hasPrefix("Every 7th primary volley")
            && (edge.detail ?? "").hasSuffix("It is not a shot or a primary hit.")
            && (card("v17_dead_circuit", um).detail ?? "").hasSuffix("Requires Gravity Well or Null Bloom."))
    let ladder = UpgradeManager.synergyTiers(for: .voidT)
    check("CA15 the ladder: Blackhole · Listlessness · Singularity, in the CL-88 final copy",
          ladder.map(\.title) == ["Blackhole", "Listlessness", "Singularity"]
            && ladder[0].effect == "Every 5th primary volley creates a black hole. Your black holes absorb hostile projectiles and impair enemy movement."
            && ladder[1].effect == "Enemies entering your black holes become trapped (elites for half as long; bosses never). Absorbed hostile projectiles return toward enemies, infused with Void."
            && ladder[2].effect == "Trapped enemies decompose: normal enemies until they die, elites up to 20% max HP per trap. Bosses caught in a black hole take 1% max HP per second.")
    let erasure = card("cap_void_erasure", um)
    check("CA16 the naming clash is gone: no synergy is \"Event Horizon\"; Erasure T5 keeps it",
          !ladder.contains { $0.title == "Event Horizon" } && erasure.description(forTier: 5).hasPrefix("Event Horizon"))
    // Drive the real ladder through picks.
    let syn = UpgradeManager(), st = PlayerStats()
    let ids = ["void_3", "void_1", "void_2", "void_4", "v21_void_horror", "v21_shadow_edge", "v18_riftline"]
    var at3 = false, at5 = false
    for (i, id) in ids.enumerated() {
        syn.pickCard(card(id, syn), stats: st, level: i + 1)
        _ = syn.checkSynergies(stats: st)
        if i == 2 { at3 = st.voidBlackhole && !st.voidListlessness }
        if i == 4 { at5 = st.voidListlessness && !st.voidSingularity }
    }
    check("CA17 ×3 Blackhole, ×5 Listlessness, ×7 Singularity switch on in order", at3 && at5 && st.voidSingularity)
}

// EL — eligibility through the REAL draw.
do {
    func runWith(_ tags: [UpgradeManager.Tag]) -> UpgradeManager {
        for _ in 0..<500 {
            let run = UpgradeManager()
            if tags.allSatisfy({ run.activeFamilies.contains($0) }) { return run }
        }
        fatalError("500 palette rolls never activated \(tags)")
    }
    let run = runWith([.voidT, .fire])
    let st = PlayerStats()
    run.pickCard(card("fire_1", run), stats: st, level: 1)
    var nonSignature = false, phaseOffered = false
    for level in 0..<200 {
        let spread = run.drawCards(count: 3, level: 2 + level % 20)
        if spread.contains(where: { $0.tag == .voidT && !$0.isSignature }) { nonSignature = true }
        if spread.contains(where: { $0.id == "void_3" }) { phaseOffered = true }
    }
    check("EL1 before Phase, no Void card past the signature is offered — while Phase itself IS (positive control)",
          !nonSignature && phaseOffered, "nonSignature=\(nonSignature) phase=\(phaseOffered)")
    run.pickCard(card("void_3", run), stats: st, level: 2)
    var opened = false, deadCircuitEarly = false
    for level in 0..<300 {
        let spread = run.drawCards(count: 3, level: 2 + level % 20)
        if spread.contains(where: { $0.tag == .voidT && !$0.isSignature }) { opened = true }
        if spread.contains(where: { $0.id == "v17_dead_circuit" }) { deadCircuitEarly = true }
    }
    check("EL2 after Phase the tree opens — but never Dead Circuit before a black-hole card", opened && !deadCircuitEarly)
    run.pickCard(card("void_2", run), stats: st, level: 3)
    var deadCircuit = false
    for level in 0..<400 where run.drawCards(count: 3, level: 3 + level % 20)
        .contains(where: { $0.id == "v17_dead_circuit" }) { deadCircuit = true; break }
    check("EL3 after Gravity Well, Dead Circuit can be offered", deadCircuit)
}

// KS — kill credit: both new sources are full credit; the reward-only set is unchanged.
do {
    check("KS1 .returned and .shadowEdge are full-credit kills (their own sources, CL-4 / QB)",
          KillSource.returned.credit == .full && KillSource.shadowEdge.credit == .full)
    check("KS2 reward-only is still exactly .burst and .sweep",
          Set(KillSource.allCases.filter { $0.credit == .rewardOnly }) == [.burst, .sweep])
}

// CF — the REAL GameConfig.VoidTree (extracted from source) = the rulings.
do {
    check("CF1 Anomaly: 4 stacks, T3 2, elites 20%, bosses 3%, 2s (Q-V2)",
          V.anomalyThreshold == 4 && V.anomalyStacksT3 == 2 && V.anomalyMiniBossFraction == 0.20
            && V.anomalyBossFraction == 0.03 && V.anomalyCooldown == 2.0)
    check("CF2 Void Horror: 8%, 0.5s / 0.25s, 2s immunity (Q-V5, CL-80)",
          V.horrorChance == 0.08 && V.fearDuration == 0.5 && V.fearMiniBossDuration == 0.25 && V.fearImmunity == 2.0)
    check("CF3 Shadow Edge: every 7th, 125%, 3 targets (CL-75); Blackhole every 5th (CL-76)",
          V.bladeEvery == 7 && V.bladeDamage == 1.25 && V.bladeTargets == 3 && V.blackholeEvery == 5)
    check("CF4 black holes: Blackhole 60pt/2.5s, Gravity Well 30pt/1s, Null Bloom 0.6×/0.8s at 30%, 8 absorbed, 0.15s return, 4 live (CL-10)",
          V.blackholeRadius == 60 && V.blackholeLifetime == 2.5 && V.gravityWellRadius == 30
            && V.gravityWellLifetime == 1.0 && V.nullBloomRadiusFraction == 0.6 && V.nullBloomLifetime == 0.8
            && V.nullBloomChance == 0.30 && V.absorbCapacity == 8 && V.returnDelay == 0.15 && V.maxLiveWells == 4)
    check("CF5 Dead Circuit: ×1.5 linger, +25%/matter, collapse at 3, 150% ATK (CL-78)",
          V.deadCircuitLinger == 1.5 && V.deadCircuitGrowth == 0.25 && V.deadCircuitCollapseAt == 3
            && V.deadCircuitBurstATK == 1.5)
    check("CF6 Singularity: normals 50%/s in a ≤2s terminal hold; elites 8%/s capped 20%; bosses 1%/s (CL-9)",
          V.decomposeNormal == 0.50 && V.terminalHold == 2.0 && V.decomposeMiniBoss == 0.08
            && V.decomposeMiniBossCap == 0.20 && V.decomposeBoss == 0.01)
    check("CF7 Riftline pierce 2, ×0.75, +25% range; Warp 0.40 / 0.6s / 1.50; Devour 2×",
          V.riftlinePierce == 2 && V.riftlineFalloff == 0.75 && V.riftlineRange == 0.25
            && V.warpStartSpeed == 0.40 && V.warpRampTime == 0.6 && V.warpStartDamage == 1.50 && V.devourXPMagnet == 2.0)
    check("CF8 the player-Void palette is indigo — none of it the danger purples",
          [V.indigoHex, V.indigoLightHex, V.indigoDeepHex].allSatisfy { ![0x8E44FF, 0x9933CC, 0xB565D8, 0xC58BFF].contains($0) })
}

// F1 — independent review: a fear step NEVER reduces separation from Spark
// (CL-80), at the rim, near the Carrier, and in the open.
do {
    let R: CGFloat = 350, fp: CGFloat = 14
    func sep(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
    // The Reviewer's exact reproduction.
    let e = CGPoint(x: 345, y: 0), spark = CGPoint(x: 320, y: 0)
    let g = FleeRule.goal(from: e, awayFrom: spark, lookahead: 120, arenaRadius: R, footprint: fp)
    let q = FleeRule.fleeStep(from: e, spark: spark, preferred: g, moveSpeed: 130, slow: 0, dt: 1.0 / 60,
                              arenaRadius: R, footprint: fp) { _ in false }
    check("F1a the Reviewer's rim case (e (345,0), Spark (320,0), R 350, fp 14): no goal inward toward Spark; the step keeps away",
          (g == nil || FleeRule.keepsAway(from: e, toward: g!, spark: spark)) && sep(q, spark) >= sep(e, spark) - 1e-9
            && hypot(q.x, q.y) <= 345 + 1e-6, "goal=\(String(describing: g)) step=\(q)")
    func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
    check("F1a1 measured directly (not via keepsAway): the goal, if any, and its midpoint are no closer to Spark",
          g == nil || (sep(g!, spark) >= sep(e, spark) - 1e-9 && sep(midpoint(e, g!), spark) >= sep(e, spark) - 1e-9))
    check("F1a2 …and it isn't frozen: a keep-away move exists (sliding along the rim at its own radius), so it's taken",
          q != e && abs(hypot(q.x, q.y) - 345) < 0.01 && sep(q, spark) > sep(e, spark))
    // Negative control: freeze 2's rule clamped the goal to R − footprint → (336, 0),
    // and one step toward it closes on Spark.
    let oldGoal = CGPoint(x: min(345 + 120, R - fp), y: 0)
    let oldStep = CGPoint(x: e.x - 130.0 / 60, y: 0)
    check("F1b NC (documents the defect, not coverage): the freeze-2 clamp gives (336,0), and its step reduces separation",
          oldGoal == CGPoint(x: 336, y: 0) && sep(oldStep, spark) < sep(e, spark))
    // A sweep of rim and Spark positions, 30 frames of flight each.
    var cases = 0, violations: [String] = []
    for deg in stride(from: 0.0, to: 360.0, by: 15.0) {
        let a = CGFloat(deg) * .pi / 180
        let dir = CGPoint(x: cos(a), y: sin(a))
        for r in [R - fp - 5, R - fp, R - fp + 3, R - 1] {
            let start = CGPoint(x: dir.x * r, y: dir.y * r)
            let sparks = [CGPoint(x: dir.x * (r - 10), y: dir.y * (r - 10)), CGPoint(x: dir.x * (r - 25), y: dir.y * (r - 25)),
                          CGPoint(x: dir.x * (r - 60), y: dir.y * (r - 60)), .zero,
                          CGPoint(x: dir.x * (r - 30) - dir.y * 40, y: dir.y * (r - 30) + dir.x * 40),
                          CGPoint(x: dir.x * (r - 5) + dir.y * 25, y: dir.y * (r - 5) - dir.x * 25)]
            for s in sparks {
                cases += 1
                var p = start
                let cap = max(R - fp, hypot(start.x, start.y))
                for f in 0..<30 {
                    let goal = FleeRule.goal(from: p, awayFrom: s, lookahead: 120, arenaRadius: R, footprint: fp)
                    if let g = goal, sep(g, s) < sep(p, s) - 1e-6 || sep(midpoint(p, g), s) < sep(p, s) - 1e-6 {
                        violations.append("goal deg=\(deg) r=\(r) f=\(f)"); break
                    }
                    let n = FleeRule.fleeStep(from: p, spark: s, preferred: goal, moveSpeed: 130, slow: 0, dt: 1.0 / 60,
                                              arenaRadius: R, footprint: fp) { _ in false }
                    if sep(n, s) < sep(p, s) - 1e-6 || hypot(n.x, n.y) > cap + 1e-6 || hypot(n.x, n.y) > R + 1e-6 {
                        violations.append("deg=\(deg) r=\(r) f=\(f)"); break
                    }
                    p = n
                }
            }
        }
    }
    check("F1c \(cases) rim/Spark cases × 30 frames: neither the goal nor any step brings it closer; never beyond the wall or its own radius",
          violations.isEmpty && cases == 576, violations.prefix(3).joined(separator: "; "))
    // Carrier-adjacent: a solid block |x| ≤ 88, |y| ≤ 177 at the centre (the Splitworks Carrier's scale).
    func carrier(_ p: CGPoint, margin: CGFloat) -> Bool { abs(p.x) <= 88 + margin && abs(p.y) <= 177 + margin }
    var carrierViolations: [String] = [], carrierMoved = 0
    let carrierCases: [(CGPoint, CGPoint)] = [
        // Starts are resolve-legal: a footprint (14) off the block, as the resolve leaves them.
        (CGPoint(x: 102, y: 0), CGPoint(x: 160, y: 0)),      // pinned on the east face, Spark further east
        (CGPoint(x: 102, y: 150), CGPoint(x: 200, y: 120)),  // near the NE corner
        (CGPoint(x: -102, y: -170), CGPoint(x: -150, y: -260)),
        (CGPoint(x: 0, y: 192), CGPoint(x: 0, y: 260)),      // on the north tip, Spark north
        (CGPoint(x: 102, y: 0), CGPoint(x: -150, y: 0))]     // Spark on the far side of the Carrier
    for (start, s) in carrierCases {
        var p = start
        for f in 0..<30 {
            let raw = FleeRule.goal(from: p, awayFrom: s, lookahead: 120, arenaRadius: R, footprint: fp)
            let goal = raw.map { FleeRule.truncate(from: p, to: $0) { carrier($0, margin: fp) } }
            let n = FleeRule.fleeStep(from: p, spark: s, preferred: goal, moveSpeed: 130, slow: 0, dt: 1.0 / 60,
                                      arenaRadius: R, footprint: fp) { carrier($0, margin: max(0, fp - 0.5)) }
            if sep(n, s) < sep(p, s) - 1e-6 || carrier(n, margin: max(0, fp - 0.5)) {
                carrierViolations.append("\(start) f=\(f)"); break
            }
            if n != p { carrierMoved += 1 }
            p = n
        }
    }
    check("F1d Carrier-adjacent fear: never into the solid, never closer to Spark (5 placements × 30 frames)",
          carrierViolations.isEmpty && carrierMoved > 0, carrierViolations.joined(separator: "; "))
    // A route target that leads toward Spark is vetoed; a safe heading is taken instead.
    let vetoed = FleeRule.fleeStep(from: CGPoint(x: 100, y: 0), spark: .zero, preferred: CGPoint(x: 20, y: 5),
                                   moveSpeed: 130, slow: 0, dt: 0.1, arenaRadius: R, footprint: fp) { _ in false }
    check("F1e a route target toward Spark is VETOED — the body still moves, away",
          vetoed != CGPoint(x: 100, y: 0) && sep(vetoed, .zero) >= 100)
    let open = FleeRule.fleeStep(from: CGPoint(x: 100, y: 0), spark: .zero, preferred: CGPoint(x: 220, y: 0),
                                 moveSpeed: 130, slow: 0, dt: 0.1, arenaRadius: R, footprint: fp) { _ in false }
    check("F1f normal open-ground flight: straight away at the chase speed (13pt in 0.1s)", near(open.x, 113) && near(open.y, 0))
    let outside = FleeRule.fleeStep(from: CGPoint(x: R + 40, y: 0), spark: .zero, preferred: CGPoint(x: 0, y: 0),
                                    moveSpeed: 130, slow: 0, dt: 0.1, arenaRadius: R, footprint: fp) { _ in false }
    check("F1g a body outside the wall doesn't move", outside == CGPoint(x: R + 40, y: 0))
    // The route target is FOLLOWED when it keeps away (it's the route graph's
    // choice, CL-80 "obey route constraints") — not just vetoed when it doesn't.
    let routed = FleeRule.fleeStep(from: CGPoint(x: 100, y: 0), spark: .zero, preferred: CGPoint(x: 200, y: 80),
                                   moveSpeed: 130, slow: 0, dt: 0.1, arenaRadius: R, footprint: fp) { _ in false }
    let routeLen = hypot(CGFloat(100), CGFloat(80))
    let routeDir = CGPoint(x: 100 / routeLen, y: 80 / routeLen)
    check("F1h a keep-away route target is FOLLOWED (the step heads for it, 13pt, not straight away)",
          near(routed.x, 100 + routeDir.x * 13, 1e-6) && near(routed.y, routeDir.y * 13, 1e-6))
    // Pinned on a Carrier face with Spark on the open side: it slides along the
    // face (the step is geometry-valid on its own), never closer, never in.
    let pinned = CGPoint(x: 88 + fp, y: 0), sparkOpen = CGPoint(x: 150, y: 20)
    let slid = FleeRule.fleeStep(from: pinned, spark: sparkOpen, preferred: pinned, moveSpeed: 130, slow: 0, dt: 0.1,
                                 arenaRadius: R, footprint: fp) { carrier($0, margin: max(0, fp - 0.5)) }
    check("F1i pinned on the Carrier face, Spark on the open side: it slides along the face — not into it, not closer",
          slid != pinned && !carrier(slid, margin: max(0, fp - 0.5)) && sep(slid, sparkOpen) >= sep(pinned, sparkOpen))
}

// F2 — independent review: an evicted hole acts no further in its pass.
do {
    final class Field { var wells: [VoidWellState] = [] }
    func fourLive() -> Field {
        let f = Field()
        f.wells = [VoidWellState(id: 1, preset: .gravityWell, baseRadius: 30, lifetime: 1.5, capacity: 8, deadCircuit: V.deadCircuitTuning),
                   VoidWellState(id: 2, preset: .blackhole, baseRadius: 60, lifetime: 3.75, capacity: 8, deadCircuit: V.deadCircuitTuning),
                   VoidWellState(id: 3, preset: .nullBloom, baseRadius: 36, lifetime: 1.2, capacity: 8, deadCircuit: V.deadCircuitTuning),
                   VoidWellState(id: 4, preset: .blackhole, baseRadius: 60, lifetime: 3.75, capacity: 8, deadCircuit: V.deadCircuitTuning)]
        return f
    }
    // The first victim's death opens a Null Bloom; at four live holes it evicts
    // the OLDEST Gravity Well — the very hole that is ticking.
    let f = fourLive()
    var damaged: [String] = []
    VoidWellPass.forEachWhileLive(["v1", "v2", "v3"], isLive: { f.wells[0].isLive }) { victim in
        damaged.append(victim)
        if victim == "v1" {
            if let evict = VoidWellCap.evictionIndex(presets: f.wells.map(\.preset), live: f.wells.map(\.isLive), cap: 4) {
                _ = f.wells[evict].end()
            }
        }
    }
    check("F2a four live holes; v1's death opens a Null Bloom that evicts the ticking Gravity Well → v2, v3 untouched",
          damaged == ["v1"] && !f.wells[0].isLive, "\(damaged)")
    // Negative control: freeze 2's plain loop would have gone on.
    let g = fourLive()
    var plain: [String] = []
    for victim in ["v1", "v2", "v3"] where g.wells[0].isLive || true {
        plain.append(victim)
        if victim == "v1", let evict = VoidWellCap.evictionIndex(presets: g.wells.map(\.preset), live: g.wells.map(\.isLive), cap: 4) {
            _ = g.wells[evict].end()
        }
    }
    check("F2b NC (documents the defect, not coverage): the freeze-2 loop (liveness checked once) damages v2 and v3 after the eviction",
          plain == ["v1", "v2", "v3"])
    let h = fourLive()
    var all: [String] = []
    VoidWellPass.forEachWhileLive(["a", "b", "c", "d"], isLive: { h.wells[0].isLive }) { all.append($0) }
    check("F2c a hole that stays live damages every body in it", all == ["a", "b", "c", "d"])
    // Pending collapse: a victim's death is the 3rd matter → the hole stops ticking; it collapses (ends) ONCE.
    let k = fourLive()
    _ = k.wells[1].addMatter(); _ = k.wells[1].addMatter()
    var hit: [String] = []
    VoidWellPass.forEachWhileLive(["x", "y"], isLive: { k.wells[1].isLive }) { victim in
        hit.append(victim)
        if victim == "x" { _ = k.wells[1].addMatter() }
    }
    let firstEnd = k.wells[1].end(), secondEnd = k.wells[1].end()
    check("F2d a victim that tips the hole into collapse stops its tick; the collapse ends it exactly once",
          hit == ["x"] && k.wells[1].collapsePending && firstEnd && !secondEnd)
}

// F3 — independent review: ONE rounding threshold per projectile → a falling
// exact sequence never realizes a rise; each projectile stays unbiased.
do {
    let grid = (0..<1000).map { (CGFloat($0) + 0.5) / 1000 } + [0, 1e-9, 0.125, 0.5, 0.999999]
    func realize(_ m: CGFloat, _ fractions: [CGFloat], _ r: CGFloat) -> [Int] {
        fractions.map { VoidRounding.a6Damage(multiplier: m, fraction: $0, unit: r) }
    }
    func nonIncreasing(_ xs: [Int]) -> Bool { zip(xs, xs.dropFirst()).allSatisfy { $0 >= $1 } }
    let rift = [CGFloat(1), 0.75, 0.5625]
    let riftBad = grid.filter { !nonIncreasing(realize(2.0, rift, $0)) }
    check("F3a Riftline exact 2 → 1.5 → 1.125: no shared threshold (1005 incl. ~0 and ~1) realizes a rise",
          riftBad.isEmpty, "\(riftBad.prefix(3))")
    let w = V.warpCurve
    let warpRift: [CGFloat] = [w.damageFraction(age: 0.05), w.damageFraction(age: 0.2) * 0.75, w.damageFraction(age: 0.45) * 0.5625]
    let warpBad = [1.0, 1.5, 2.0, 2.7, 3.0, 4.2].flatMap { m in grid.filter { !nonIncreasing(realize(CGFloat(m), warpRift, $0)) } }
    check("F3b Warp + Riftline (falling over flight AND per body): never a later hit above an earlier one",
          warpBad.isEmpty)
    // A seeded property sweep: 3000 projectiles, random multiplier, ages and threshold.
    var seed: UInt64 = 0x5eed
    func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 11) / CGFloat(1 << 53) }
    var sweepBad = 0
    for _ in 0..<3000 {
        let m = 1 + rnd() * 4, r = rnd()
        var ages = [rnd() * 0.3, rnd() * 0.3, rnd() * 0.3].sorted()
        ages = ages.map { $0 * 2 }
        let fractions = ages.enumerated().map { w.damageFraction(age: TimeInterval($1)) * RiftlineFalloff.fraction(priorHits: $0, falloff: V.riftlineFalloff) }
        if !nonIncreasing(realize(m, fractions, r)) { sweepBad += 1 }
    }
    check("F3c 3000 random Warp+Riftline projectiles: every realized sequence non-increasing", sweepBad == 0, "\(sweepBad)")
    // Unbiased: over the threshold, each hit's mean is its exact value.
    func meanAt(_ m: CGFloat, _ f: CGFloat) -> CGFloat {
        let n = 10_000
        return CGFloat((0..<n).reduce(0) { $0 + VoidRounding.a6Damage(multiplier: m, fraction: f, unit: (CGFloat($1) + 0.5) / CGFloat(n)) }) / CGFloat(n)
    }
    check("F3d still unbiased per hit: means 2, 1.5, 1.125 (Riftline) and 1.875 (Warp 150%→ at 0.15s on a 2-base)",
          near(meanAt(2, 1), 2, 1e-3) && near(meanAt(2, 0.75), 1.5, 1e-3) && near(meanAt(2, 0.5625), 1.125, 1e-3)
            && near(meanAt(2, w.damageFraction(age: 0.15)), 2 * w.damageFraction(age: 0.15), 1e-3))
    check("F3e a Shadow Edge blade (one fraction, 1.25) deals the same on each of its 3 bodies",
          grid.allSatisfy { r in Set(realize(2, [1.25, 1.25, 1.25], r)).count == 1 })
    // Negative control: independent draws per hit CAN rise (the Reviewer's 2 → 1 → 2).
    let independent = [VoidRounding.a6Damage(multiplier: 2, fraction: 1, unit: 0.5),
                       VoidRounding.a6Damage(multiplier: 2, fraction: 0.75, unit: 0.9),
                       VoidRounding.a6Damage(multiplier: 2, fraction: 0.5625, unit: 0.1)]
    check("F3f NC (documents the defect, not coverage): per-hit draws realize 2 → 1 → 2 (a rise)",
          independent == [2, 1, 2] && !nonIncreasing(independent))
    // The production per-projectile type, EXECUTED.
    let one = A6Rounding()
    let repeated = (0..<200).map { _ in one.damage(multiplier: 2, fraction: 0.75) }
    check("F3g one A6Rounding (one projectile) is one threshold: 200 resolutions of the same fraction agree",
          Set(repeated).count == 1)
    let seqBad = grid.filter { r in
        let p = A6Rounding(unit: r)
        return !nonIncreasing([p.damage(multiplier: 2, fraction: 1), p.damage(multiplier: 2, fraction: 0.75),
                               p.damage(multiplier: 2, fraction: 0.5625)])
    }
    let meanOver = CGFloat(grid.prefix(1000).reduce(0) { $0 + A6Rounding(unit: $1).damage(multiplier: 2, fraction: 0.75) }) / 1000
    check("F3h A6Rounding: a projectile's Riftline sequence never rises; across projectiles each hit is unbiased (mean 1.5)",
          seqBad.isEmpty && near(meanOver, 1.5, 1e-3))
}

// XS — independent review F5: the production routines EXECUTED (not source tokens).
do {
    final class Shot: BlackholeSeedCarrier { var seedsBlackhole = false }
    let a = Shot(), b = Shot()
    var volley = VolleyEmission<Shot>()
    volley.begin(); volley.note(a); volley.note(b)
    let seeded = volley.finish(.init(blackhole: true, blade: false))
    check("XS1 a Blackhole volley seeds its LEAD shot (the first primary out), not the others",
          seeded === a && a.seedsBlackhole && !b.seedsBlackhole && volley.lead == nil)
    check("XS2 the seeded shot opens exactly one Blackhole where it stops (the seed is taken once)",
          BlackholeSeed.take(a) && !BlackholeSeed.take(a) && !BlackholeSeed.take(b))
    let c = Shot()
    volley.begin(); volley.note(c)
    check("XS3 a non-Blackhole volley seeds nothing", volley.finish(.init(blackhole: false, blade: true)) == nil && !c.seedsBlackhole)
    volley.begin()
    check("XS4 an empty volley has no lead and seeds nothing", !volley.emitted && volley.finish(.init(blackhole: true, blade: false)) == nil)
    // Full chain: the real counter + emission over 5 volleys.
    var counter = VolleyCounter()
    var shots: [Shot] = []
    for _ in 1...5 {
        let s = Shot(); shots.append(s)
        volley.begin(); volley.note(s)
        volley.finish(counter.register(emitted: volley.emitted, blackholeOwned: true, bladeOwned: false, tuning: V.volleyTuning))
    }
    check("XS5 counter + emission: only volley 5's lead shot carries the seed",
          shots.map(\.seedsBlackhole) == [false, false, false, false, true])

    final class Log { var calls: [String] = []; var dealt: [Int] = []; var bossFlags: [Bool] = [] }
    func enemyHit(_ kind: VoidSecondaryKind, _ hit: VoidHit, damage: Int = 3, dying: Bool = false, shielded: Bool = false,
                  kills: Bool) -> Log {
        let log = Log()
        VoidSecondaryHit.onEnemy(kind: kind, hit: hit, damage: damage, isDying: dying, shielded: shielded, shieldMultiplier: 0.5,
            effects: .init(flashShield: { log.calls.append("flash") }, consume: { log.calls.append("consume") },
                           takeDamage: { log.calls.append("damage"); log.dealt.append($0); return kills },
                           credit: { log.calls.append("credit") }, stackAnomaly: { log.calls.append("anomaly") }))
        return log
    }
    let retSurvive = enemyHit(.returned, .returned(phaseT2: false), kills: false)
    let retKill = enemyHit(.returned, .returned(phaseT2: false), kills: true)
    let bladeSurvive = enemyHit(.shadowEdge, .shadowEdge, kills: false)
    let bladeKill = enemyHit(.shadowEdge, .shadowEdge, kills: true)
    check("XS6 a returned shot DAMAGES an ordinary enemy; a survivor then stacks Anomaly; a kill is credited (no Anomaly)",
          retSurvive.calls == ["consume", "damage", "anomaly"] && retSurvive.dealt == [3]
            && retKill.calls == ["consume", "damage", "credit"])
    check("XS7 a Shadow Edge blade DAMAGES an ordinary enemy; never Anomaly; a kill is credited",
          bladeSurvive.calls == ["consume", "damage"] && bladeSurvive.dealt == [3] && bladeKill.calls == ["consume", "damage", "credit"])
    let voidShield = enemyHit(.shadowEdge, .shadowEdge, damage: 4, shielded: true, kills: false)
    let plainShield = enemyHit(.returned, .none, damage: 4, shielded: true, kills: false)
    check("XS8 Void affinity: Braceguard flashes but doesn't halve (4 → 4); without affinity it would (4 → 2)",
          voidShield.calls.first == "flash" && voidShield.dealt == [4] && plainShield.dealt == [2])
    let corpse = enemyHit(.returned, .returned(phaseT2: true), dying: true, kills: false)
    let none = enemyHit(.none, .none, kills: false)
    check("XS9 a corpse or a non-secondary shot: nothing happens (no strike spent)", corpse.calls.isEmpty && none.calls.isEmpty)
    func bossHit(_ kind: VoidSecondaryKind, _ hit: VoidHit, dead: Bool) -> Log {
        let log = Log()
        VoidSecondaryHit.onBoss(kind: kind, hit: hit, damage: 5,
            effects: .init(consume: { log.calls.append("consume") },
                           takeDamage: { log.calls.append("damage"); log.dealt.append($0); log.bossFlags.append($1) },
                           isDead: { dead }, stackAnomaly: { log.calls.append("anomaly") }))
        return log
    }
    let bRet = bossHit(.returned, .returned(phaseT2: true), dead: false)
    let bRetPlain = bossHit(.returned, .returned(phaseT2: false), dead: false)
    let bRetDead = bossHit(.returned, .returned(phaseT2: true), dead: true)
    let bBlade = bossHit(.shadowEdge, .shadowEdge, dead: false)
    check("XS10 the boss route DAMAGES the boss: returned shots penetrate the dial only with Phase T2, then stack Anomaly if alive",
          bRet.calls == ["consume", "damage", "anomaly"] && bRet.dealt == [5] && bRet.bossFlags == [true]
            && bRetPlain.bossFlags == [false] && bRetDead.calls == ["consume", "damage"])
    check("XS11 …a blade DAMAGES the boss through the dial (never penetrates) and never stacks Anomaly",
          bBlade.calls == ["consume", "damage"] && bBlade.dealt == [5] && bBlade.bossFlags == [false])
}

// WR — the scene WIRING. GameScene, EnemyNode and ProjectileNode are read, not
// compiled: every pure rule above is only worth anything if the scene calls it.
do {
    let env = ProcessInfo.processInfo.environment
    guard let src = try? String(contentsOfFile: env["VOID_SCENE"] ?? "", encoding: .utf8),
          let enemySrc = try? String(contentsOfFile: env["VOID_ENEMY"] ?? "", encoding: .utf8),
          let projSrc = try? String(contentsOfFile: env["VOID_PROJECTILE"] ?? "", encoding: .utf8) else {
        check("WR0 GameScene / EnemyNode / ProjectileNode are readable", false)
        exit(1)
    }
    func body(_ name: String, in text: String = src, prefix: String = "private func ") -> String {
        guard let r = text.range(of: "\(prefix)\(name)(") else { return "" }
        let rest = text[r.upperBound...]
        let ends = ["\n    private func ", "\n    func ", "\n    @discardableResult", "\n    override func "]
            .compactMap { rest.range(of: $0)?.lowerBound }
        let end = ends.min() ?? rest.endIndex
        // Match CODE only: a token surviving in a comment must not satisfy a check.
        return rest[..<end].split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in line.range(of: "//").map { line[..<$0.lowerBound] } ?? line }
            .joined(separator: "\n")
    }
    func order(_ text: String, _ marks: [String]) -> Bool {
        var from = text.startIndex
        for m in marks {
            guard let r = text.range(of: m, range: from..<text.endIndex) else { return false }
            from = r.upperBound
        }
        return true
    }
    let auto = body("updateAutoAttack")
    check("WR1 the volley: reset → fire → ONE counter → seed the lead / fire the blade (CL-76)",
          order(auto, ["guard !redSmile.formActive", "volley.begin()", "fireShotSpread(",
                       "volleyCounter.register(emitted: volley.emitted", "volley.finish(verdict)",
                       "if verdict.blade { fireShadowEdge(direction: baseDirection) }"]))
    let fire = body("fireProjectile")
    check("WR2 only the gun's primary pellet (allowModifiers) and the icicle that replaces it are primary shots",
          fire.contains("configurePrimaryShot(fireIcicle(")
            && fire.contains("spawnsGravityWell: allowModifiers && playerStats.gravityWellOnExpire")
            && fire.contains("if allowModifiers { configurePrimaryShot(projectile, pellet: true) }")
            && fire.contains("configurePrimaryShot(fireIcicle(direction: direction, originOffset: originOffset), pellet: false)")
            && body("fireIcicle").contains("spawnsGravityWell: false,"))
    let primary = body("configurePrimaryShot")
    check("WR3 a primary shot: Warp on the PELLET only, Phase T2's affinity + penetration, and it marks the volley emitted",
          primary.contains("if pellet, playerStats.warpShotActive { projectile.enableWarp(GameConfig.VoidTree.warpCurve) }")
            && primary.contains(".primaryShot(phaseT2: playerStats.phasePenetrates)")
            && primary.contains("volley.note(projectile)"))
    let hit = body("handleProjectileHit")
    check("WR4 the gun on an enemy: Void secondaries leave first; the base damage is shotBaseDamage; Void affinity skips the shield",
          order(hit, ["if projectileNode.voidKind != .none {", "resolveVoidSecondaryHit(projectileNode, on: enemyNode)",
                      "var damage = shotBaseDamage(projectileNode)",
                      "!projectileNode.voidHit.affinity"]))
    check("WR5 …then Anomaly and Void Horror ride a PRIMARY hit on a SURVIVOR, before the other survivor riders",
          order(hit, ["onEnemyKilled(at: deathPos", "var alive = !killed", "if alive, projectileNode.isPrimaryHit {",
                      "applyAnomaly(to: enemyNode, source: projectileNode.killSource)", "rollVoidHorror(on: enemyNode)",
                      "if alive, playerStats.bloodthirstyApplies(", "if alive, playerStats.whiteoutTier >= 1"]))
    let bossHit = body("handleProjectileHitBoss")
    check("WR6 the gun on the boss: secondaries leave first; Phase T2 skips ONLY the flat dial; primary hits stack its Anomaly",
          order(bossHit, ["resolveVoidSecondaryHitBoss(projectileNode, on: bossNode)", "var damage = shotBaseDamage(projectileNode)",
                          "bossNode.takeDamage(damage, ignoresChallengeDEF: projectileNode.voidHit.flatDEFPenetration)",
                          "if projectileNode.isPrimaryHit, !bossNode.isDead { applyBossAnomaly(bossNode) }"]))
    let sweep = body("redSmileHit")
    check("WR7 a sweep target: Anomaly on a survivor (an erase ends it), then the survivor riders and Void Horror (CL-85)",
          order(sweep, ["} else if !applyAnomaly(to: enemy, source: .melee) {", "enemy.applyBleed(", "rollVoidHorror(on: enemy)",
                        "chargeRedSmileHitMeters(.enemy)"]))
    let sweepBoss = body("redSmileHitBoss")
    let swing = body("redSmileSwing")
    check("WR8 a sweep on the boss stacks Anomaly WITHOUT Phase T2's penetration; swings never touch the volley counter",
          sweepBoss.contains("if !bossNode.isDead { applyBossAnomaly(bossNode) }")
            && !sweepBoss.contains("ignoresChallengeDEF") && !swing.contains("volley") && !sweep.contains("volley")
            && swing.contains("redSmileHit(enemy, guaranteedCrit:"))   // anchor: the body really was found
    let secondary = body("resolveVoidSecondaryHit")
    let secondaryBoss = body("resolveVoidSecondaryHitBoss")
    let forbidden = ["critMultiplier", "rollOverload", "chainLightning", "erasureRegisterHit", "apexRegisterAttack",
                     "applyBurn", "applySlow", "applyRepulse", "rollVoidHorror", "executeMultiplier", "applyForgeOffense",
                     "becomeSnowman", "applyBleed"]
    check("WR9 returned shots and Shadow Edge carry NAMED effects only: rounded damage, the shield flash, own kill source (CL-4, QB)",
          secondary.contains("projectile.a6Rounding.damage(multiplier: projectile.damageMultiplier") && secondary.contains("flashShield()")
            && secondary.contains("source: projectile.killSource")
            && forbidden.allSatisfy { !secondary.contains($0) && !secondaryBoss.contains($0) },
          forbidden.filter { secondary.contains($0) || secondaryBoss.contains($0) }.joined(separator: ","))
    check("WR10 …Anomaly is wired as the ONLY stackAnomaly effect (the rule \"returned only\" is executed in XS)",
          secondary.contains("stackAnomaly: { [weak self] in _ = self?.applyAnomaly(to: enemy, source: .returned) }")
            && secondaryBoss.contains("stackAnomaly: { [weak self] in self?.applyBossAnomaly(bossNode) }"))
    check("WR11 a seeded lead shot opens its Blackhole wherever it stops: expiry, enemy, Shatter, boss, consume",
          src.components(separatedBy: "openBlackholeIfSeeded(").count - 1 >= 6
            && body("updateProjectiles").contains("openBlackholeIfSeeded(projectile)"))
    let enemies = body("updateEnemies")
    check("WR12 the enemy branch: airborne → trapped (held) → fleeing (routes to its escape) → chase; slam/pull pinned",
          order(enemies, ["let fleeTo = fleeing ? fleeGoal(for: enemy) : nil",
                          "toward: fleeing ? (fleeTo ?? enemy.position) : player.position",
                          "if airborne {", "} else if trapped {", "} else if fleeing {",
                          "enemy.flee(from: player.position, preferred: fleeTo == nil ? nil : steerTarget", "enemy.chase(target:"])
            && enemies.contains("let pinned = airborne || trapped || fleeing"))
    check("WR13 black holes pull BEFORE the geometry resolve (no frame inside the Carrier); Undertow is gone",
          order(enemies, ["applyVoidWellPull(dt)", "resolveEnemiesAgainstGeometry()"]) && !src.contains("voidPullForce"))
    let wells = body("updateVoidWells")
    check("WR14 the hole's frame: absorb (×3) → capture + returns (×5) → Dead Circuit → decompose THEN tick → collapse → end",
          order(wells, ["if playerStats.voidBlackhole, !enemyProjectiles.isEmpty", "tryAbsorb(holdForReturn: playerStats.voidListlessness",
                        "if playerStats.voidListlessness {", "enemy.captureInVoid(", "fireReturnedShot(",
                        "if playerStats.deadCircuitActive {", "enemy.decomposeInVoid(dt", "enemy.tickVoidTrap(dt)",
                        "bossDecompose.tick(", "b.takeDamage(damage, ignoresChallengeDEF: true)",
                        "collapseVoidWell(well)", "endVoidWell(well, collapsed: false)"]))
    let collapse = body("collapseVoidWell")
    check("WR15 a collapse feeds no hole (QC) and hits the boss through ORDINARY defenses (the dial applies)",
          order(collapse, ["suppressWellMatter = true", "dealDirectDamage(damage, toEnemy: enemy, source: .ground)",
                           "b.takeDamage(damage)", "suppressWellMatter = false", "endVoidWell(well, collapsed: true)"])
            && body("feedVoidWells").contains("!suppressWellMatter")
            && !collapse.contains("ignoresChallengeDEF") && collapse.contains("segmentBlockedExact("))
    let killed = body("onEnemyKilled")
    check("WR16 matter comes only from FULL-credit kills (after the reward-only guard)",
          order(killed, ["guard source.credit == .full else {", "feedVoidWells(killAt: position)"]))
    check("WR17 the cap is enforced before a hole opens; ends release traps and return/drop held shots (R5)",
          order(body("spawnVoidWell"), ["VoidWellCap.evictionIndex(", "endVoidWell(voidWells[evict], collapsed: false)", "voidWells.append(well)"])
            && order(body("endVoidWell"), ["well.state.drainHeld()", "if held > 0, playerStats.voidListlessness", "enemy.voidWellEnded(id)"]))
    check("WR18 frame order: hostile shots move, THEN the holes (absorb what's inside)",
          order(src, ["updateEnemyProjectiles(dt)", "updateVoidWells(dt)"]))
    check("WR19 a trapped body is knockback-immune to Repulse; a launch cancels fear (CL-79/80)",
          body("applyRepulse").contains("!enemy.isVoidTrapped")
            && order(body("applyRepulse"), ["repulseFlights[id] = (enemy", "enemy.cancelFear()"]))
    let restart = body("restartGame")
    check("WR20 a new run clears the holes, the volley counter and the boss's Anomaly",
          restart.contains("voidWells.removeAll()") && restart.contains("volleyCounter.reset()")
            && restart.contains("bossAnomaly.reset()") && body("resetBossStatus").contains("bossAnomaly.reset()"))
    check("WR21 Devour widens the XP-orb pull only (health orbs untouched)",
          body("updateXPOrbs").contains("playerStats.devourActive ? GameConfig.VoidTree.devourXPMagnet : 1"))
    // EnemyNode: a stronger control cancels fear; the trap never writes stun/freeze.
    func enemyFunc(_ name: String) -> String { body(name, in: enemySrc, prefix: "func ") }
    check("WR22 stun, Overload, freeze and the snowman all cancel fear; the snowman also exits a trap (CL-79/80)",
          enemyFunc("applyStun").contains("cancelFear()") && enemyFunc("applyOverloadStun").contains("cancelFear()")
            && enemyFunc("applyFreeze").contains("cancelFear()")
            && order(enemyFunc("becomeSnowman"), ["cancelFear()", "releaseVoidTrap()"]))
    check("WR23 capture cancels fear, and the trap never touches stunTimer or freezeTimer (R2)",
          enemyFunc("captureInVoid").contains("cancelFear()")
            && !enemyFunc("captureInVoid").contains("stunTimer") && !enemyFunc("captureInVoid").contains("freezeTimer")
            && !enemyFunc("releaseVoidTrap").contains("stunTimer") && !enemyFunc("tickVoidTrap").contains("stunTimer")
            && enemyFunc("releaseVoidTrap").contains("voidTrap.release()"))
    check("WR24 the trap's hold ticks from the scene, NOT the status tick (decompose-first order, TR7/TR8)",
          !enemyFunc("updateStatusEffects").contains("voidTrap.tick(") && enemyFunc("tickVoidTrap").contains("voidTrap.tick(dt)")
            && enemyFunc("updateStatusEffects").contains("fear.tick(deltaTime"))
    // Palette (CL-86 / QA).
    check("WR25 player Void is indigo: False Opening, Unstable Core and Erasure T2's bolt lose their purples",
          !body("spawnFalseOpeningPulse").contains("0x8E44FF") && !body("performUnstableCoreBurst").contains("0x9933CC")
            && !projSrc.contains("0xB565D8") && !projSrc.contains("0xE060FF")
            && body("spawnFalseOpeningPulse").contains("GameConfig.VoidTree.indigo")
            && body("performUnstableCoreBurst").contains("GameConfig.VoidTree.indigo")
            && projSrc.contains("} else if voidStyle {"))
    check("WR26 a Warp shot reads its curve at the hit and moves by it; pierce counts bodies struck",
          projSrc.contains("let speedFraction = warp?.speedFraction(age: age) ?? 1")
            && order(projSrc, ["func onHitEnemy() -> Bool {", "bodiesStruck += 1"])
            && body("shotBaseDamage").contains("warp.damageFraction(age: projectile.age)")
            && body("shotBaseDamage").contains("RiftlineFalloff.fraction(priorHits: projectile.bodiesStruck"))
    check("WR28 a returned shot aimed at a body on the hole's centre never gets a zero heading (it would never expire)",
          body("fireReturnedShot").contains("aim.length > 1 ? aim : CGPoint(x: 0, y: 1)"))
    // ---- internal review (Sep 24): construction, gates and the corrective fixes ----
    func count(_ text: String, _ s: String) -> Int { text.components(separatedBy: s).count - 1 }
    let edgeFire = body("fireShadowEdge")
    check("PX1 the blade is built as ruled: .shadowEdge kind/hit/source, 125% of legacy damage, 3 bodies (CL-75, QB)",
          edgeFire.contains("blade.voidKind = .shadowEdge") && edgeFire.contains("blade.voidHit = .shadowEdge")
            && edgeFire.contains("blade.killSource = .shadowEdge") && edgeFire.contains("pierces: V.bladeTargets - 1")
            && edgeFire.contains("damageMultiplier: playerStats.effectiveDamageMultiplier,")
            && edgeFire.contains("blade.voidDamageFraction = V.bladeDamage"))
    check("PX2 exactly one Anomaly call per secondary path (the returned branch)",
          count(secondary, "applyAnomaly(") == 1 && count(secondaryBoss, "applyBossAnomaly(") == 1)
    let ret = body("fireReturnedShot")
    check("PX3 a returned shot: 1× damage, .returned kind/source, Phase T2 penetration read live (CL-4)",
          ret.contains("damageMultiplier: playerStats.effectiveDamageMultiplier,")
            && ret.contains("shot.voidKind = .returned") && ret.contains("shot.killSource = .returned")
            && ret.contains("shot.voidHit = .returned(phaseT2: playerStats.phasePenetrates)"))
    let codeOnly = src.split(separator: "\n", omittingEmptySubsequences: false)
        .map { l -> Substring in l.range(of: "//").map { l[..<$0.lowerBound] } ?? l }.joined(separator: "\n")
    check("PX4 only a real primary shot marks the volley emitted (an absorbed Glacial pellet is no volley)",
          count(codeOnly, "volley.note(") == 1 && primary.contains("volley.note(projectile)"))
    check("PX5 both Anomaly cooldowns tick on game time",
          body("updateBossStatus").contains("bossAnomaly.tick(dt)")
            && enemyFunc("updateStatusEffects").contains("anomaly.tick(deltaTime)"))
    let bossAnom = body("applyBossAnomaly")
    check("PX6 Anomaly needs Phase; the boss chunk takes the flat dial (R4)",
          body("applyAnomaly").contains("guard playerStats.phaseTier >= 1") && bossAnom.contains("guard playerStats.phaseTier >= 1")
            && bossAnom.contains("bossNode.takeDamage(AnomalyState.chunkDamage(maxHealth: bossNode.maxHealth, fraction: fraction))")
            && !bossAnom.contains("ignoresChallengeDEF"))
    let affects = body("voidWellAffects")
    let pull = body("applyVoidWellPull")
    check("PX7 holes skip snowmen and fliers; mini-bosses pulled at debuffScale; 70pt/s + the impair slow (CL-77)",
          affects.contains("isHittable(enemy) && !enemy.isSnowman && repulseFlights[ObjectIdentifier(enemy)] == nil")
            && pull.contains("where voidWellAffects(enemy)") && pull.contains("enemy.isMiniBoss ? GameConfig.BossClass.debuffScale : 1")
            && pull.contains("V.pullSpeed") && pull.contains("playerStats.effectiveSlow(V.impairSlow)"))
    let horror = body("rollVoidHorror")
    check("PX8 Void Horror's eligibility is fed from the live enemy (CL-80)",
          horror.contains("hittable: isHittable(enemy), snowman: enemy.isSnowman")
            && horror.contains("airborne: repulseFlights[ObjectIdentifier(enemy)] != nil")
            && horror.contains("trapped: enemy.isVoidTrapped") && horror.contains("hardControlled: enemy.isStunned || enemy.isFrozen"))
    let spread = body("fireShotSpread")
    let calls = codeOnly.components(separatedBy: "fireProjectile(direction:").dropFirst().map { chunk -> String in
        var depth = 1, out = ""
        for ch in chunk { if ch == "(" { depth += 1 } else if ch == ")" { depth -= 1; if depth == 0 { break } }; out.append(ch) }
        return out
    }
    let unflagged = calls.filter { !$0.contains("allowModifiers: false") }.count
    check("PX9 only the volley's 3 call sites (+ the declaration) fire primary shots",
          count(spread, "fireProjectile(direction:") == 3 && unflagged == 4, "unflagged=\(unflagged)")
    check("PX10 a sweep on the boss hits through the dial exactly as ruled (positive form)",
          sweepBoss.contains("        bossNode.takeDamage(damage)\n"))
    check("PXC ruled CL-77/78 numbers: pull 70pt/s, 40% impair slow, Dead Circuit 1 shot-damage/s; Gravity Well a flat 30pt",
          V.pullSpeed == 70 && V.impairSlow == 0.40 && V.deadCircuitDamage == 1.0 && V.gravityWellRadius == 30)
    check("FX1 fear routes to a TRUNCATED escape point — never pushed to the Carrier's far face (H1)",
          body("fleeGoal").contains("FleeRule.truncate(from: enemy.position, to: goal)")
            && body("fleeGoal").contains("arenaGeometry.isBlocked(p, margin: footprint)")
            && !body("fleeGoal").contains("arenaGeometry.resolve("))
    check("FX2 fear clears its committed escape node when it ENDS or is cancelled, not only at the start (M1)",
          enemyFunc("fearEnded").contains("routeNodeID = nil") && enemyFunc("cancelFear").contains("fearEnded()")
            && enemyFunc("updateStatusEffects").contains("{ fearEnded() }"))
    let clearFlag = "if enemy.voidHeldLastFrame { enemy.geometryDisplacedThisFrame = false }"
    check("FX3 a flight/trap's wall slide is not the body's own wall hit: the flag clears before BOTH resumes (ranged + chase, M2)",
          count(enemies, clearFlag) == 2
            && enemies.contains(clearFlag + "\n                enemy.chase(target:")
            && order(enemies, [clearFlag, "ranged.rangedChase(", clearFlag, "enemy.chase(target:",
                               "enemy.voidHeldLastFrame = trapped || fleeing"]))
    check("FX4 a hole's centre is kept inside the arena wall", body("spawnVoidWell").contains("let wall = GameConfig.Arena.radius"))
    let target = body("nearestVoidReturnTarget")
    check("FX5 gate ruling Q5: a returned shot targets ONLY a hittable body the hole can SEE (exact LOS) — no fallback through terrain",
          target.contains("for enemy in enemies where isHittable(enemy)") && target.contains("if let b = boss, isHittable(b)")
            && target.contains("arenaGeometry.segmentBlockedExact(") && target.contains("return best")
            && !target.contains("bestVisible") && !target.contains("??") && target.contains("        return best\n"))
    check("FX15 gate ruling Q5: a READY held shot with no valid visible target is discarded — never left waiting",
          order(wells, ["while well.state.takeReadyReturn() {", "if let target = nearestVoidReturnTarget(from: well.position) {",
                        "fireReturnedShot(from: well.position, toward: target)", "} else {", "combatLedger.returnsFizzled += 1"])
            && !wells.contains("while well.state.readyReturns > 0")
            && order(body("endVoidWell"), ["if let target = nearestVoidReturnTarget(from: well.position) {", "} else {",
                                           "combatLedger.returnsFizzled += 1"]))
    check("FX6 A6 fractions scale the LEGACY damage (Riftline never climbs; full-speed Warp = plain): shotBaseDamage + both secondaries",
          body("shotBaseDamage").contains("projectile.a6Rounding.damage(multiplier: projectile.damageMultiplier, fraction: fraction)")
            && secondary.contains("projectile.a6Rounding.damage(multiplier: projectile.damageMultiplier,")
            && secondaryBoss.contains("projectile.a6Rounding.damage(multiplier: projectile.damageMultiplier,")
            && !codeOnly.contains("VoidRounding.damage(projectile.damageMultiplier"))
    check("FX7 the boss's Anomaly lands BEFORE its Bleed (gun and sweep) — a chunk kill never 'died bleeding' from its own hit",
          order(bossHit, ["applyBossAnomaly(bossNode)", "playerStats.bloodthirstyApplies("])
            && order(sweepBoss, ["applyBossAnomaly(bossNode)", "inflictBossBleed(generation: 0)"]))
    check("FX8 ended holes stay ended: endVoidWell is once-only; collapses and Dead Circuit skip ended/non-DC holes",
          body("endVoidWell").contains("guard well.state.end() else { return }")
            && wells.contains("where well.state.collapsePending && !well.state.ended")
            && wells.contains("where well.state.isLive && well.state.deadCircuit != nil")
            && body("spawnVoidWell").contains("live: voidWells.map { $0.state.isLive }"))
    check("FX9 CL-79 detachment: a trapped body shoved out of its live hole is released",
          order(wells, ["enemy.voidTrapWellID", "well.state.radius + enemy.hitBodyRadius", "enemy.releaseVoidTrap()",
                        "enemy.decomposeInVoid(dt"]))
    check("FX10 the seeded lead shot opens its hole AFTER the hit's own kills (it never feeds itself matter)",
          order(hit, ["chainLightning(from: enemyNode", "if consumed { openBlackholeIfSeeded(projectileNode) }"])
            && order(bossHit, ["erasureRegisterHit()", "if consumed { openBlackholeIfSeeded(projectileNode) }"])
            && count(hit, "openBlackholeIfSeeded(") == 2      // the Shatter exit + the end — nothing earlier
            && count(bossHit, "openBlackholeIfSeeded(") == 1)
    check("FX11 secondary hits skip a corpse; Braceguard reads the Void affinity (CL-72) on every path (rules executed in XS)",
          secondary.contains("isDying: enemy.isDying") && secondary.contains("hit: projectile.voidHit")
            && sweep.contains("let voidHit = VoidHit.redSmile") && sweep.contains("shielded = !voidHit.affinity"))
    check("FX12 a Boss Mode stage change clears the player's black holes (they belong to that arena)",
          body("advanceGauntlet").contains("voidWells.removeAll()"))
    check("FX13 Erasure's in-world rings and pops are indigo now — no danger purple in any showRingPulse",
          !codeOnly.split(separator: "\n").contains { $0.contains("showRingPulse(") && ($0.contains("0x9B59B6") || $0.contains("0x6C3483") || $0.contains("0x8E44AD") || $0.contains("0x8E44FF")) })
    check("FX14 a blade never gets a zero heading", edgeFire.contains("direction.length > 0.5 ? direction : CGPoint(x: 0, y: 1)"))
    // ---- independent review F1–F5: the scene boundary ----
    check("RV1 (F1) the scene's flight runs FleeRule.fleeStep with Spark, the route target and the Carrier predicate",
          enemyFunc("flee").contains("FleeRule.fleeStep(from: position, spark: spark, preferred: target")
            && enemies.contains("let margin = max(0, enemy.geometryFootprintRadius - 0.5)")
            && order(enemies, ["} else if fleeing {", "arenaGeometry.hasBlockedGeometry",
                               "enemy.flee(from: player.position, preferred: fleeTo == nil ? nil : steerTarget",
                               "solid && arenaGeometry.isBlocked(q, margin: margin)"]))
    check("RV2 (F2) Dead Circuit's damage pass re-checks the hole's liveness before every body",
          wells.contains("VoidWellPass.forEachWhileLive(enemies, isLive: { well.state.isLive })")
            && order(wells, ["VoidWellPass.forEachWhileLive(enemies",
                             "guard isHittable(enemy), well.state.contains(enemy.position, center: well.position) else { return }",
                             "dealDirectDamage(damage, toEnemy: enemy, source: .ground)"]))
    let projectileCode = projSrc.split(separator: "\n", omittingEmptySubsequences: false)
        .map { l -> Substring in l.range(of: "//").map { l[..<$0.lowerBound] } ?? l }.joined(separator: "\n")
    check("RV3 (F3) one threshold per projectile, drawn at launch; every A6 rounding reads it — no per-hit draw",
          projectileCode.contains("let a6Rounding = A6Rounding()")
            && body("shotBaseDamage").contains("projectile.a6Rounding.damage(multiplier: projectile.damageMultiplier, fraction: fraction)")
            && secondary.contains("projectile.a6Rounding.damage(multiplier: projectile.damageMultiplier,")
            && secondaryBoss.contains("projectile.a6Rounding.damage(multiplier: projectile.damageMultiplier,")
            && !body("shotBaseDamage").contains("VoidRounding.")
            && !body("shotBaseDamage").contains("CGFloat.random") && !secondary.contains("CGFloat.random")
            && !secondaryBoss.contains("CGFloat.random"))
    // F4: every player-Void WORLD-space path, not selected literals. Purple =
    // red and blue both well above green, blue dominant enough to read violet
    // (catches 0x9B59B6, 0xC060FF, 0xC39BD3, 0x1A0028; spares crimson, pink,
    // indigo). The approved exception is the screen tint (flashScreen).
    func isPurple(_ hex: String) -> Bool {
        guard let v = Int(hex, radix: 16) else { return false }
        let r = CGFloat((v >> 16) & 255), g = CGFloat((v >> 8) & 255), b = CGFloat(v & 255)
        return r > g + 8 && b > g + 8 && b >= 0.75 * r && r >= 0.4 * b
    }
    func purples(in text: String) -> [String] {
        text.split(separator: "\n").filter { !$0.contains("flashScreen(") }.flatMap { line -> [String] in
            var out: [String] = []
            var rest = Substring(line)
            while let r = rest.range(of: "0x") {
                let hex = String(rest[r.upperBound...].prefix(6))
                if hex.count == 6, hex.allSatisfy(\.isHexDigit), isPurple(hex) { out.append(hex) }
                rest = rest[r.upperBound...]
            }
            return out
        }
    }
    check("RV4 (F4) the purple test itself: flags 0x9B59B6 0xC060FF 0xC39BD3 0x1A0028 0x8E44FF; spares indigo, crimson, pink, white",
          ["9B59B6", "C060FF", "C39BD3", "1A0028", "8E44FF", "6C3483", "3A1050"].allSatisfy(isPurple)
            && !["4466DD", "6688FF", "223366", "E0203A", "FF8A99", "FFAABB", "FFFFFF", "0E0B1C", "05060F"].contains(where: isPurple))
    let voidWorld = ["showRiftBeam", "erasureFracture", "showUnstablePop", "forcePlayerErased", "erasureImplosion",
                     "erasureRiftBurst", "erasurePhaseLock", "erasureDamageEcho", "erasureDisplacement", "erasureBackwash",
                     "triggerUnstable", "fireRiftCannon", "eraseArena", "spawnFalseOpeningPulse", "performUnstableCoreBurst",
                     "spawnVoidWell", "collapseVoidWell", "fireReturnedShot", "fireShadowEdge"]
    let missingBodies = voidWorld.filter { body($0).isEmpty }
    let purpleHits = voidWorld.flatMap { name in purples(in: body(name)).map { "\(name):\($0)" } }
    // …and no NAMED purple either (e.g. the Faceted Lie's hostilePurpleHex).
    let namedPurple = voidWorld.filter { name in
        body(name).split(separator: "\n").contains { !$0.contains("flashScreen(") && $0.lowercased().contains("purple") }
    }
    check("RV5 (F4) no purple — literal OR named — in ANY player-Void world-space scene path (19 functions; screen tints excepted)",
          missingBodies.isEmpty && purpleHits.isEmpty && namedPurple.isEmpty,
          (missingBodies + purpleHits + namedPurple).joined(separator: ", "))
    let wellNodeSrc = (try? String(contentsOfFile: env["VOID_WELLNODE"] ?? "", encoding: .utf8)) ?? ""
    let bossTellSrc = (try? String(contentsOfFile: env["VOID_BOSSTELL"] ?? "", encoding: .utf8)) ?? ""
    let tells = ["refreshAnomalyPips", "flashAnomalyTrigger", "showFearMark", "showTrapRing"].map { body($0, in: enemySrc) }
    check("RV6 (F4) the node-side player-Void looks: VoidWellNode, projectile Void styles, the enemy and boss tells — no purple",
          !wellNodeSrc.isEmpty && purples(in: wellNodeSrc).isEmpty && purples(in: projectileCode).isEmpty
            && tells.allSatisfy { !$0.isEmpty && purples(in: $0).isEmpty }
            && bossTellSrc.contains("func refreshAnomaly(") && purples(in: bossTellSrc).isEmpty)
    check("RV7 (F5) the scene RUNS the executed routines: the volley note, the seed take, and both secondary routes with real damage",
          primary.contains("volley.note(projectile)")
            && body("openBlackholeIfSeeded").contains("guard BlackholeSeed.take(projectile) else { return }")
            && body("openBlackholeIfSeeded").contains("spawnVoidWell(.blackhole, at: projectile.position)")
            && secondary.contains("VoidSecondaryHit.onEnemy(")
            && secondary.contains("kind: projectile.voidKind, hit: projectile.voidHit, damage: damage, isDying: enemy.isDying")
            && secondary.contains("takeDamage: { enemy.takeDamage($0) }")
            && secondary.contains("self.consumeProjectile(projectile)")
            && secondary.contains("self?.onEnemyKilled(at: enemy.position, xpValue: enemy.xpValue, enemy: enemy, source: projectile.killSource)")
            && secondaryBoss.contains("VoidSecondaryHit.onBoss(")
            && secondaryBoss.contains("takeDamage: { bossNode.takeDamage($0, ignoresChallengeDEF: $1) }")
            && secondaryBoss.contains("isDead: { bossNode.isDead }"))
    let config = (try? String(contentsOfFile: env["VOID_CONFIG"] ?? "", encoding: .utf8)) ?? ""
    check("WR27 VC4's Glacial cadence is the app's (glacialEveryN = 3)",
          config.contains("static let glacialEveryN: Int = 3") || config.contains("static let glacialEveryN = 3"))
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
