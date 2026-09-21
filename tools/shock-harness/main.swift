// main.swift — deterministic validators for v2.1 abilities Unit A3 (Shock):
// Chain Lightning's compounded falloff (Q-S1, CL-12), Overload's linked form
// and stun immunity (Q-S2, CL-2), and the reworked Shock cards applied through
// the REAL card pool. Each validator prints PASS/FAIL; exit 1 on any FAIL.

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

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
