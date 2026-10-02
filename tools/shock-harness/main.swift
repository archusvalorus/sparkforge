// main.swift — deterministic validators for v2.1 abilities Unit A3 (Shock):
// Chain Lightning's compounded falloff (Q-S1, CL-12), Overload's linked form
// and stun immunity (Q-S2, CL-2), and the reworked Shock cards applied through
// the REAL card pool. A7b S3 adds SE: Storm Engine's spread volley = the
// normal pellet count + 2 (CL-98). A7b S5 adds SH: the snowman and the timed
// (Overload) stun are independent holds (G1.7, R2). Each validator prints
// PASS/FAIL; exit 1 on any FAIL.

import CoreGraphics
import Foundation

var passed = 0, failed = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1; print("PASS  \(name)") }
    else { failed += 1; print("FAIL  \(name)  \(detail())") }
}
func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 1e-9 }
let S = GameConfig.Shock.self
func card(_ um: UpgradeManager, _ id: String) -> UpgradeManager.UpgradeCard {
    guard let c = um.allCards.first(where: { $0.id == id }) else { fatalError("missing card \(id)") }
    return c
}

// L — Chain Lightning's ladder.
do {
    let um = UpgradeManager(), stats = PlayerStats()
    let chain = card(um, "shock_2")
    var series: [[Int]] = [], jumps: [Int] = []
    for level in 1...4 {
        um.pickCard(chain, stats: stats, level: level)
        jumps.append(stats.chainTargets)
        series.append(stats.chainDamages(primary: 1000))
    }
    check("L1 one jump per tier: 1 / 2 / 3 / 4", jumps == [1, 2, 3, 4] && chain.maxTier == 4 && chain.name == "Chain Lightning")
    check("L2 T1: a single chain at 50%", series[0] == [500])
    check("L3 T2 (CL-12): each jump keeps 75% of the hit BEFORE it — compounded", series[1] == [750, 562], "got \(series[1])")
    check("L4 T3: 85% compounded", series[2] == [850, 722, 614], "got \(series[2])")
    check("L5 T4: four jumps, no falloff", series[3] == [1000, 1000, 1000, 1000])
    stats.chainTargets += 1     // Chain Current (Shock ×3)
    check("L6 Q-S1: T4 + Chain Current = five jumps = six enemies with the original, still no falloff",
          stats.chainDamages(primary: 7) == [7, 7, 7, 7, 7])
    check("L7 a jump never deals less than 1 (integer hit scale)", {
        let s2 = PlayerStats(); s2.chainTargets = 3; s2.chainLightningTier = 2
        return s2.chainDamages(primary: 1) == [1, 1, 1] }())
    check("L8 signature: provides shockUnlocked, id unchanged", chain.isSignature && chain.provides == [.shockUnlocked])
}

// O — Overload: base, linked, boss-class, immunity.
do {
    let um = UpgradeManager(), stats = PlayerStats()
    um.pickCard(card(um, "shock_4"), stats: stats, level: 1)
    check("O1 Overload: 20% / 1s", near(stats.effectiveStunChance, 0.20) && stats.overloadStunDuration(isBossClass: false) == 1.0 && !stats.overloadLinked)
    let chain = card(um, "shock_2")
    for level in 2...4 { um.pickCard(chain, stats: stats, level: level) }
    check("O2 Chain Lightning T3 does NOT link it", !stats.overloadLinked && near(stats.effectiveStunChance, 0.20))
    um.pickCard(chain, stats: stats, level: 5)
    check("O3 Q-S2: MAXED Chain Lightning upgrades an owned Overload to 35% / 2s — no extra pick",
          stats.overloadLinked && near(stats.effectiveStunChance, 0.35) && stats.overloadStunDuration(isBossClass: false) == 2.0)
    check("O4 CL-2 boss-class: 0.5s linked…", stats.overloadStunDuration(isBossClass: true) == 0.5)
    let plain = PlayerStats(); plain.overloadOwned = true
    check("O5 …0.25s unlinked — fixed numbers, applied once (25% of 1s / of 2s)", plain.overloadStunDuration(isBossClass: true) == 0.25)
    let none = PlayerStats(); none.chainLightningTier = 4
    check("O6 a maxed chain without Overload stuns nothing", near(none.effectiveStunChance, 0) && !none.overloadLinked)

    var t = OverloadStunState()
    check("O7a first stun lands", t.tryStun(duration: 2.0) && t.isStunned)
    check("O7b can't re-stun while stunned", !t.tryStun(duration: 2.0))
    for _ in 0..<40 { t.tick(0.05, immunityDuration: S.overloadImmunity) }
    check("O7c when the stun ENDS, 3s of immunity begins", !t.isStunned && t.isImmune && !t.tryStun(duration: 2.0))
    for _ in 0..<59 { t.tick(0.05, immunityDuration: S.overloadImmunity) }
    check("O7d still immune at 2.95s", t.isImmune && !t.tryStun(duration: 1))
    t.tick(0.05, immunityDuration: S.overloadImmunity)
    check("O7e stunnable again at 3s", !t.isImmune && t.tryStun(duration: 1))
    var p = OverloadStunState(); _ = p.tryStun(duration: 1)
    check("O7f unticked (paused): the stun holds, no immunity starts", p.isStunned && !p.isImmune)
    // The loop CL-2 exists to stop: hammer a target with stun attempts for 30s.
    var loop = OverloadStunState(); var stunnedTime = 0.0
    for _ in 0..<600 { _ = loop.tryStun(duration: 2.0); loop.tick(0.05, immunityDuration: 3.0); if loop.isStunned { stunnedTime += 0.05 } }
    check("O7g under constant 2s stun attempts a target is stunned ≤ 40% of the time", stunnedTime / 30.0 <= 0.41, "\(stunnedTime / 30.0)")
}

// C — the other cards.
do {
    let um = UpgradeManager(), stats = PlayerStats()
    let st = card(um, "shock_1")
    var rates: [CGFloat] = []
    for level in 1...3 { um.pickCard(st, stats: stats, level: level); rates.append(1 / stats.fireRateMultiplier - 1) }
    check("C1 Static: REAL firing-rate totals +15% / +30% / +50%",
          zip(rates, [0.15, 0.30, 0.50]).allSatisfy { abs($0 - $1) < 1e-9 }, "got \(rates)")

    let s2 = PlayerStats()
    um.pickCard(card(um, "shock_3"), stats: s2, level: 1)
    check("C2 Surge: +10% move, +20% shot speed, +10% attack speed",
          near(s2.moveSpeedMultiplier, 1.10) && near(s2.projectileSpeedMultiplier, 1.20) && abs(1 / s2.fireRateMultiplier - 1.10) < 1e-9)

    let s3 = PlayerStats(), sentry = card(um, "v21_lightning_sentry")
    var tiers: [Int] = []
    for level in 1...4 { um.pickCard(sentry, stats: s3, level: level); tiers.append(s3.lightningSentryTier) }
    check("C3 Lightning Sentry: 4 tiers", tiers == [1, 2, 3, 4] && sentry.maxTier == 4)
    // CL-13: consolidating three coils must not LOWER the single-target ceiling.
    let three = 3 * S.sentryDamageFraction / CGFloat(S.sentryInterval)
    let network = S.networkDamageFraction / CGFloat(S.networkInterval)
    check("C4 CL-13: the T4 network's single-target rate (\(network)/s) ≥ three coils' (\(three)/s)", network >= three)
    check("C5 coil / pulse / crown damage on the hit scale never rounds to zero",
          s3.shotFractionDamage(S.sentryDamageFraction) == 1 && s3.shotFractionDamage(S.pulseDamageFraction) == 1
            && s3.shotFractionDamage(S.crownDamageFraction) == 1)
    let s4 = PlayerStats()
    um.pickCard(card(um, "v21_electro_pulse"), stats: s4, level: 1)
    um.pickCard(card(um, "v16_static_crown"), stats: s4, level: 2)
    check("C6 Electro Pulse + reworked Static Crown arm their systems", s4.electroPulseActive && s4.staticCrownActive)
    s4.reset()
    check("C7 run reset clears every Shock flag",
          !s4.electroPulseActive && !s4.staticCrownActive && s4.lightningSentryTier == 0 && s4.chainLightningTier == 0 && !s4.overloadOwned)
}

// E — eligibility, removals, copy fit.
do {
    let um = UpgradeManager()
    let shock = um.allCards.filter { $0.tag == .shock }
    let rest = shock.filter { !$0.isSignature }
    check("E1 Chain Lightning gates the tree (\(rest.count) other cards, capstone included)",
          shock.filter { $0.isSignature }.map { $0.id } == ["shock_2"] && rest.allSatisfy { $0.requires.contains(.shockUnlocked) })
    let gone = ["v16_arc_wake", "v16_live_wire", "v17_induction_step", "v17_copper_vein"]
    check("E2 four removals, two additions: Shock is 10 → 8 cards",
          gone.allSatisfy { id in !um.allCards.contains { $0.id == id } }
            && um.allCards.contains { $0.id == "v21_lightning_sentry" } && um.allCards.contains { $0.id == "v21_electro_pulse" }
            && shock.count == 8, "shock=\(shock.count)")
    var leaked: Set<String> = []
    for _ in 0..<40 {
        let run = UpgradeManager(), stats = PlayerStats()
        guard let opener = run.allCards.first(where: { $0.isSignature && $0.tag != .shock && run.activeFamilies.contains($0.tag) }) else { continue }
        run.pickCard(opener, stats: stats, level: 1)
        for level in 2...10 { for c in run.drawCards(count: 3, level: level) where c.tag == .shock && !c.isSignature { leaked.insert(c.id) } }
    }
    check("E3 without Chain Lightning, no other Shock card is ever offered", leaked.isEmpty, "leaked \(leaked)")
    func lines(_ text: String) -> Int {
        var n = 0, cur = 0
        for w in text.split(separator: " ") {
            if cur == 0 { cur = w.count; n += 1 } else if cur + 1 + w.count <= 17 { cur += 1 + w.count } else { cur = w.count; n += 1 }
        }
        return n
    }
    var tooLong: [String] = []
    for c in shock where !c.isCapstone { for t in 1...c.maxTier where lines(c.description(forTier: t)) > (c.detail == nil ? 4 : 3) { tooLong.append("\(c.id) T\(t)") } }
    check("E4 every reworked Shock card line fits the selection card", tooLong.isEmpty, "truncated: \(tooLong)")
}

// SE — Storm Engine (Shock ×7), CL-98 (A7b S3, G1.3): its every-3rd spread
// volley fires the NORMAL pellet count + 2, so Scatter never makes it fire
// fewer. Everything goes through the REAL pool: seven Shock picks fire the
// synergy exactly as GameScene does (checkSynergies after each pick), and
// Scatter's three tiers raise the normal count. The +2 is the REAL extracted
// GameConfig.Shock (A7b S3 retired the Stubs mirror). The scene line that
// feeds this count to the gun is pinned in the catalog harness (WR9).
do {
    let um = UpgradeManager(), stats = PlayerStats()
    check("SE0 a fresh run: one pellet, no spread volleys, and a spread volley would be the base 3",
          stats.volleyPelletCount(isSpreadVolley: false) == 1 && stats.volleyPelletCount(isSpreadVolley: true) == 3
            && !stats.recordShot())
    let storm = ["shock_2", "shock_1", "shock_3", "shock_4", "v21_lightning_sentry", "v21_electro_pulse", "v16_static_crown"]
    var fired: [String] = []
    for (i, id) in storm.enumerated() {
        um.pickCard(card(um, id), stats: stats, level: i + 1)
        fired += um.checkSynergies(stats: stats).map { "\($0.tag.rawValue)_\($0.tier)" }
    }
    let every3rd = (1...9).map { _ in stats.recordShot() }
    check("SE1 seven Shock picks fire Storm Engine through the real pool: every 3rd volley is a spread volley",
          fired == ["Shock_3", "Shock_5", "Shock_7"] && every3rd == [false, false, true, false, false, true, false, false, true],
          "fired \(fired) pattern \(every3rd)")
    let scatter = card(um, "neutral_6")
    var normal = [stats.volleyPelletCount(isSpreadVolley: false)]
    var spread = [stats.volleyPelletCount(isSpreadVolley: true)]
    for level in 8...10 {
        um.pickCard(scatter, stats: stats, level: level)
        normal.append(stats.volleyPelletCount(isSpreadVolley: false))
        spread.append(stats.volleyPelletCount(isSpreadVolley: true))
    }
    check("SE2 Scatter T0–T3 through the real pool: normal volleys fire 1 / 2 / 3 / 4",
          normal == [1, 2, 3, 4] && scatter.maxTier == 3, "got \(normal)")
    check("SE3 CL-98: Storm Engine's spread volley fires the normal count + 2 = 3 / 4 / 5 / 6 (never fewer than a normal volley)",
          spread == [3, 4, 5, 6] && zip(normal, spread).allSatisfy { $1 == $0 + 2 }, "got \(spread)")
    check("SE4 the +2 is the REAL GameConfig.Shock.stormEngineBonusPellets (extracted from source)",
          S.stormEngineBonusPellets == 2)
    stats.reset()
    check("SE5 run reset: back to one pellet and no spread volleys",
          stats.volleyPelletCount(isSpreadVolley: false) == 1 && stats.extraProjectiles == 0
            && (1...6).allSatisfy { _ in !stats.recordShot() })
}

// SH — the stun hold (A7b S5, G1.7; closure table R2: one control can't lengthen
// or cut short another). The snowman and the timed stun are INDEPENDENT holds:
// becoming a snowman never writes the timed stun, ending one never clears it,
// and the body is stunned while EITHER is active. `Body` composes the three
// REAL pure states in EnemyNode's order — applyOverloadStun, becomeSnowman and
// updateStatusEffects (the hold, then the form, then Overload's own timer); that
// wiring itself is pinned on EnemyNode's executable view (catalog WR11). Time
// steps are 1/64s, binary-exact, so every boundary lands on a frame.
do {
    let frame: TimeInterval = 1.0 / 64
    let C = GameConfig.Chill.self
    struct Body {
        var hold = StunHold(), form = SnowmanState(), overload = OverloadStunState()
        var isStunned: Bool { hold.isStunned(snowman: form.isSnowman) }
        mutating func overloadStun(_ d: TimeInterval) -> Bool {
            guard overload.tryStun(duration: d) else { return false }
            hold.stun(d)
            return true
        }
        mutating func becomeSnowman(_ d: TimeInterval, melts: Bool, elite: Bool = false) -> Bool {
            form.begin(duration: d, cooldown: GameConfig.Chill.snowmanCooldown, meltsOnDamage: melts,
                       isBossClass: elite, bossClassScale: GameConfig.BossClass.debuffScale) != nil
        }
        mutating func tick(_ dt: TimeInterval) {
            hold.tick(dt)
            _ = form.tick(dt)
            overload.tick(dt, immunityDuration: GameConfig.Shock.overloadImmunity)
        }
        mutating func run(_ seconds: TimeInterval, _ dt: TimeInterval) { for _ in 0..<Int((seconds / dt).rounded()) { tick(dt) } }
    }

    var h = StunHold()
    let fresh = !h.isStunned(snowman: false)
    let formOnly = h.isStunned(snowman: true)
    h.stun(2); h.stun(0.5)
    let kept = h.remaining == 2 && h.isStunned(snowman: false)
    for _ in 0..<128 { h.tick(frame) }
    check("SH1 either hold stuns: the form alone, the timed stun alone; the timed stun keeps the longer (2s, not 0.5s) and ends on game time",
          fresh && formOnly && kept && !h.isStunned(snowman: false) && h.isStunned(snowman: true))

    // Sequence A (the recon's): a 3s snowman takes a 1s Overload stun at 2.5s.
    var a = Body()
    let formed = a.becomeSnowman(3, melts: false)
    a.run(2.5, frame)
    let landed = a.overloadStun(1.0)
    a.run(0.5, frame)                                   // t = 3.0s: the form wears off
    let afterForm = !a.form.isSnowman && a.isStunned && a.overload.isStunned
    a.run(0.5 - frame, frame)                           // t = 3.5s − 1 frame
    let lastFrame = a.isStunned && !a.overload.isImmune
    a.tick(frame)                                       // t = 3.5s
    check("SH2 an Overload stun that lands on a snowman runs its full remaining second after the form ends (3.0s → 3.5s), then frees the body as its 3s immunity starts",
          formed && landed && afterForm && lastFrame && !a.isStunned && !a.overload.isStunned && a.overload.isImmune)

    // Sequence B: the gun rolls Overload BEFORE the damage; that damage melts a
    // T3 elite snowman in the same hit. The elite's fixed 0.5s stun survives the melt.
    var b = Body()
    let eliteForm = b.becomeSnowman(6, melts: true, elite: true)   // 6s → 3s at the BossClass scale
    b.run(1.0, frame)
    let procced = b.overloadStun(0.5)
    let melt = b.form.onDamage(7, isBossClass: true, maxHealth: 200, eliteFraction: C.snowmanEliteMeltFraction)
    let meltedStunned = !b.form.isSnowman && b.isStunned
    b.run(0.5 - frame, frame)
    let heldToEnd = b.isStunned
    b.tick(frame)
    check("SH3 a same-hit Overload on a melting T3 elite holds it the full 0.5s AFTER the melt; the melt itself is unchanged (+20% max HP, form consumed)",
          eliteForm && procced && melt == .elite(extraDamage: 40) && meltedStunned && heldToEnd
            && !b.isStunned && b.overload.isImmune)

    // Becoming a snowman never writes or repurposes the Overload stun's timer.
    var c = Body()
    _ = c.overloadStun(1.0)
    let formedOverStun = c.becomeSnowman(3, melts: false)
    let untouched = c.hold.remaining == 1.0
    c.run(1.0, frame)                                   // t = 1.0s: Overload ends ON TIME
    let overloadOnTime = !c.overload.isStunned && c.overload.isImmune && c.hold.remaining <= 0 && c.isStunned
    c.run(2.0 - frame, frame)
    let formHolds = c.isStunned
    c.tick(frame)                                       // t = 3.0s
    check("SH4 becoming a snowman leaves the timed stun at 1s (not the form's 3s): Overload ends and its immunity starts on time at 1s, the form alone holds the body to 3s",
          formedOverStun && untouched && overloadOnTime && formHolds && !c.isStunned && !c.form.isSnowman)

    // Unchanged: with no timed stun, the form's end (or a melt) frees the body at once.
    var d = Body()
    _ = d.becomeSnowman(3, melts: false)
    d.run(3.0 - frame, frame)
    let stillForm = d.isStunned
    d.tick(frame)
    var e = Body()
    _ = e.becomeSnowman(6, melts: true, elite: true)
    _ = e.form.onDamage(3, isBossClass: true, maxHealth: 100, eliteFraction: C.snowmanEliteMeltFraction)
    check("SH5 unchanged without a timed stun: the form holds exactly its duration, and a melted elite is free at once",
          stillForm && !d.isStunned && !e.isStunned)
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
