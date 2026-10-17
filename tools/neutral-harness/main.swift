// Neutral harness — v2.2 Neutral rework, Unit N2 (R1/R5 rulings, Oct 11).
// Proves the PURE rules: XPLedger (cap 15/20, the bank, the carried fraction,
// the granted level, the gauntlet opener's clearing grant, the queue's one-
// at-a-time contract) and PlayerStats' Overclock (values, the acquisition
// trigger, refresh-not-stack, active-time expiry, the bonuses entering once
// beside external contributors, reset), plus XP Boost through its real
// catalog effect with external XP bonuses present.
// v2.2 N4: BX (the chaos beam's pure rules: lane tick, exact prefix, the
// exact block, contacts, termini, grouping, the maximum geometry, BeamClock's
// C1 cadence) and BH (the beam's exact parent hits extracted verbatim and
// executed; the Forge refactor against its pre-N4 reference). EX (Echo ruling,
// Oct 13): Erasure T4's ordinary Echo per virtual parent lane, executed.
// CX (v2.2 N5): Chain Reaction — the ladder, the one rounding, and the kill/burst seam
// (onEnemyKilled + the frame-end drain + one burst + EnemyNode's real damage body), executed.
import Foundation

var passed = 0, failed = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1; print("PASS  \(name)") } else { failed += 1; print("FAIL  \(name)  \(detail())") }
}
func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 1e-9 }
typealias N = GameConfig.Neutral
let CAP = N.runLevelCap, CAP20 = N.xpBoostLevelCap

// ── XL · the ledger ──────────────────────────────────────────────────────────
do {
    // XL1 the XP curve is the v1 curve, unchanged.
    let curve = (2...21).map { XPLedger.xpRequired(forLevel: $0) }
    let expected = (2...21).map { Int(Double(GameConfig.Leveling.baseXPRequired) * pow(GameConfig.Leveling.xpScalingFactor, Double($0 - 2))) }
    check("XL1 the XP curve is unchanged: level 2 costs 5, then ×1.3 per level, truncated (2…21: \(curve.prefix(6)) …)", curve == expected && curve[0] == 5 && curve[1] == 6)

    // XL2 fractional carry at ×1.25: four 1-XP orbs are exactly 5 XP, never 4, never 6.
    var l = XPLedger()
    var trail: [(Int, CGFloat)] = []
    for _ in 1...4 { l.collect(1, multiplier: 1.25); trail.append((l.xp, l.carry)) }
    check("XL2 1 XP at ×1.25, four times: 1 (carry .25) → 2 (.5) → 3 (.75) → 5 (0): the +25% is exact over time and no XP is manufactured",
          trail.map { $0.0 } == [1, 2, 3, 5] && near(trail[0].1, 0.25) && near(trail[1].1, 0.5) && near(trail[2].1, 0.75) && near(trail[3].1, 0), "\(trail)")

    // XL3 ×1.5: two orbs are 3 XP; a thousand orbs are exactly floor(1000 × 1.5) and floor(1000 × 1.25).
    var a = XPLedger(), b = XPLedger()
    for _ in 1...1000 { a.collect(1, multiplier: 1.5); b.collect(1, multiplier: 1.25) }
    var two = XPLedger(); two.collect(1, multiplier: 1.5); let afterOne = (two.xp, two.carry); two.collect(1, multiplier: 1.5)
    check("XL3 1 XP at ×1.5: 1 (carry .5) → 3 (0); a thousand 1-XP orbs total exactly 1500 at ×1.5 and 1250 at ×1.25 (carry 0 at the end of each)",
          afterOne.0 == 1 && near(afterOne.1, 0.5) && two.xp == 3 && a.xp == 1500 && near(a.carry, 0) && b.xp == 1250 && near(b.carry, 0), "\(a.xp) \(b.xp)")

    // XL4 ×1.0 is the legacy integer path exactly; Boss Mode's 5×–9× orbs are integral BEFORE the ledger.
    var c = XPLedger(); var sum = 0
    for v in [1, 3, 7, 260 * 5, 260 * 9, 2] { c.collect(v, multiplier: 1.0); sum += v }
    check("XL4 at ×1.0 every pickup credits exactly its value (1, 3, 7, a 5× boss orb, a 9× boss orb, 2 → \(sum)) with no carry: the legacy path is reproduced", c.xp == sum && near(c.carry, 0))

    // XL5 Boss Mode multipliers × XP Boost: 7-XP orbs at ×1.25 give 8.75 each — exact over time.
    var d = XPLedger(); for _ in 1...4 { d.collect(7, multiplier: 1.25) }
    var e = XPLedger(); for _ in 1...3 { e.collect(9 * 260, multiplier: 1.5) }
    check("XL5 representative Boss Mode orbs under XP Boost: four 7-XP orbs at ×1.25 = 35 (8.75 each, carried); three 9× boss orbs (2340) at ×1.5 = 10530 exactly",
          d.xp == 35 && near(d.carry, 0) && e.xp == 10530 && near(e.carry, 0), "\(d.xp) \(e.xp)")

    // XL6 external XP bonuses ride the same multiplier (1.25 + 0.10 = 1.35).
    var f = XPLedger(); for _ in 1...20 { f.collect(1, multiplier: 1.35) }
    check("XL6 an external XP bonus adds to the multiplier (×1.35): twenty 1-XP orbs = 27 exactly", f.xp == 27 && near(f.carry, 0), "\(f.xp)")

    // XL7 a zero or negative multiplier never manufactures XP; a zero pickup is nothing.
    var g = XPLedger(); g.collect(5, multiplier: 0); g.collect(0, multiplier: 1.25); g.collect(5, multiplier: -1)
    check("XL7 a zero pickup, a zero multiplier or a negative multiplier credits nothing", g.xp == 0 && near(g.carry, 0))

    // XL8 the cap: levels stop at 15; XP keeps banking; the bar reads full.
    var h = XPLedger(); h.collect(100_000, multiplier: 1.0)
    var taken = 0; while h.takeDueLevel(cap: CAP) { taken += 1 }
    let bankedAt15 = h.xp
    h.collect(50, multiplier: 1.25)
    // The bar must read full BECAUSE of the cap, not because the bank happens to
    // exceed the next threshold: reach 15 with exactly 0 XP banked.
    var z = XPLedger(); z.collect((2...15).reduce(0) { $0 + XPLedger.xpRequired(forLevel: $1) }, multiplier: 1.0)
    while z.takeDueLevel(cap: CAP) {}
    let fullAtCapWithEmptyBank = z.level == 15 && z.xp == 0 && z.progress(cap: CAP) == 1
    check("XL8 at cap 15 the ledger stops taking levels (14 taken from level 1), keeps banking XP (bank \(bankedAt15) → \(h.xp)), reports no level due, and the bar reads full — also with an EMPTY bank at the cap (full because of the cap, not the bank)",
          taken == 14 && h.level == 15 && !h.isLevelDue(cap: CAP) && h.xp == bankedAt15 + 62 && near(h.carry, 0.5) && h.progress(cap: CAP) == 1 && fullAtCapWithEmptyBank, "taken \(taken) level \(h.level) emptyBankFull \(fullAtCapWithEmptyBank)")

    // XL9 raising the cap to 20 lets the BANK level the player, one level at a time, and stops at 20.
    var steps: [Int] = []; while h.takeDueLevel(cap: CAP20) { steps.append(h.level) }
    check("XL9 when the cap rises to 20 the banked XP levels the player ONE level per call — 16, 17, 18, 19, 20 — then stops at 20 with the remainder still banked",
          steps == [16, 17, 18, 19, 20] && h.level == 20 && !h.isLevelDue(cap: CAP20) && h.xp > 0, "\(steps) \(h.xp)")

    // XL10 the granted level keeps XP as an ABSOLUTE amount; T3 at 15 → 16, at 19 → 20, at 20 → nothing.
    var i = XPLedger(); i.collect(100_000, multiplier: 1.0); while i.takeDueLevel(cap: CAP) {}
    i.collect(1, multiplier: 1.25)                                   // some carry too
    let xpBefore = i.xp, carryBefore = i.carry
    let atCap15 = i.grantLevel(cap: CAP, keepingXP: true)            // the cap is still 15: nowhere to go
    let granted16 = i.grantLevel(cap: CAP20, keepingXP: true)        // T3 raised the cap: 15 → 16
    check("XL10 XP Boost's grant keeps the XP (and its carry) as an absolute amount: at 15 under cap 15 it is refused; under cap 20 it goes 15 → 16 with xp \(xpBefore) unchanged and the next threshold the new level's",
          !atCap15 && granted16 && i.level == 16 && i.xp == xpBefore && near(i.carry, carryBefore) && i.requiredForNext == XPLedger.xpRequired(forLevel: 17))
    var j = XPLedger(); j.collect(100_000, multiplier: 1.0); while j.takeDueLevel(cap: 19) {}
    let at19 = j.grantLevel(cap: CAP20, keepingXP: true), at20 = j.grantLevel(cap: CAP20, keepingXP: true)
    check("XL11 T3 at 19 advances to 20 and stops: a grant at 20 is refused", at19 && j.level == 20 && !at20 && j.level == 20)

    // XL12 the gauntlet opener's grant clears XP and carry (its empty-XP initialization) — explicitly distinct.
    var k = XPLedger(); k.collect(7, multiplier: 1.25)
    let opener = k.grantLevel(cap: CAP, keepingXP: false)
    check("XL12 the opener's grant (keepingXP: false) clears the XP and the carry and steps one level; eight of them from level 1 reach 9, never past the cap",
          opener && k.level == 2 && k.xp == 0 && near(k.carry, 0) && { var o = XPLedger(); for _ in 1...8 { o.grantLevel(cap: CAP, keepingXP: false) }; return o.level == 9 }()
            && { var o = XPLedger(); for _ in 1...30 { o.grantLevel(cap: CAP, keepingXP: false) }; return o.level == CAP }())

    // XL13 one pickup worth several levels: every threshold is honoured, one level per call, remainder exact.
    var m = XPLedger(); m.collect(5 + 6 + 8 + 3, multiplier: 1.0)   // levels 2, 3, 4 cost 5, 6, 8; 3 left
    var due: [Int] = []; while m.takeDueLevel(cap: CAP) { due.append(m.level) }
    check("XL13 a 22-XP pickup from level 1 makes three levels due (2, 3, 4 cost 5 + 6 + 8), taken one per call, leaving exactly 3 XP toward level 5",
          due == [2, 3, 4] && m.xp == 3 && !m.isLevelDue(cap: CAP), "\(due) \(m.xp)")

    // XL14 near-cap overflow: a big pickup at 14 takes 15 and banks the rest (never past the cap).
    var n = XPLedger(); n.collect(100_000, multiplier: 1.0); while n.takeDueLevel(cap: 14) {}
    let bank = n.xp; n.collect(100_000, multiplier: 1.0)
    let took15 = n.takeDueLevel(cap: CAP), tookMore = n.takeDueLevel(cap: CAP)
    check("XL14 near-cap overflow at 14: the next pickup takes 15 and banks the rest; nothing past the cap", took15 && !tookMore && n.level == 15 && n.xp == bank + 100_000 - XPLedger.xpRequired(forLevel: 15))

    // XL15 progress below the cap is the fraction of the next threshold, clamped.
    var q = XPLedger(); q.collect(3, multiplier: 1.0)
    let p1 = q.progress(cap: CAP); q.collect(10, multiplier: 1.0)
    check("XL15 the bar below the cap is xp / next threshold (3 of 5 = 0.6), clamped at 1 while a level is due but not yet taken", near(p1, 0.6) && q.progress(cap: CAP) == 1 && q.isLevelDue(cap: CAP))

    // XL16 reset.
    var r = XPLedger(); r.collect(100, multiplier: 1.25); _ = r.takeDueLevel(cap: CAP); r.reset()
    check("XL16 reset returns the ledger to level 1, 0 XP, 0 carry", r.level == 1 && r.xp == 0 && near(r.carry, 0))
}

// ── XO · Overclock on PlayerStats ─────────────────────────────────────────────
do {
    let s = PlayerStats()
    check("XO1 Overclock's values come from GameConfig.Neutral: +35% move, +35% attack speed, +15% damage, 3 s; the trio is inert until the card is owned and a level-up triggers it",
          near(s.overclockBoost, 0.35) && s.overclockDuration == 3.0 && N.overclockAttackSpeed == 0.35 && N.overclockDamageBonus == 0.15
            && !s.overclockActive && !s.isOverclockRunning && s.overclockAttackSpeed == 0 && s.overclockDamageBonus == 0)
    // external contributors present
    s.forgeBloodrushBonus = 0.10
    s.damageMultiplier = 1.20
    s.forgeMoveBonus = 0.05
    let baseInterval = s.effectiveFireInterval, baseDamage = s.effectiveDamageMultiplier, baseSpeed = s.effectiveMoveSpeed
    s.triggerOverclock()
    let unownedNoop = !s.isOverclockRunning && s.effectiveFireInterval == baseInterval
    s.overclockActive = true                       // the card's effect (NX2 proves it through the real acquire path)
    s.triggerOverclock()
    let started = s.overclockTimer == 3.0
    let intervalOnce = near(CGFloat(s.effectiveFireInterval), CGFloat(baseInterval) / 1.35)       // once, beside Bloodrush's +10%
    let damageOnce = near(s.effectiveDamageMultiplier, baseDamage + 0.15)                      // once, on top of ×1.20
    let speedOnce = near(s.effectiveMoveSpeed, baseSpeed * 1.35)                               // once, over the whole movement sum
    let freeMirrors = near(s.overchargeFreeDamageMultiplier, s.effectiveDamageMultiplier - s.overchargeCurrentBonus)
    check("XO2 not owned → a trigger does nothing; owned → a trigger starts 3 s and, while it runs, attack speed is ×1.35 ONCE beside Bloodrush's +10%, damage is +0.15 ONCE on top of ×1.20 and Overcharge, movement is ×1.35 once over the whole sum; the Overcharge-free multiplier mirrors it",
          unownedNoop && started && intervalOnce && damageOnce && speedOnce && freeMirrors,
          "noop \(unownedNoop) started \(started) interval \(intervalOnce) damage \(damageOnce) speed \(speedOnce) free \(freeMirrors)")
    s.updateMagneticCore(1.0)
    let ticking = near(CGFloat(s.overclockTimer), 2.0) && near(s.effectiveDamageMultiplier, baseDamage + 0.15)
    s.triggerOverclock()
    let refreshed = s.overclockTimer == 3.0 && near(CGFloat(s.effectiveFireInterval), CGFloat(baseInterval) / 1.35)   // 3 s again, not 5, not ×1.35²
    s.updateMagneticCore(2.5); let stillOn = s.isOverclockRunning
    s.updateMagneticCore(0.6); let expired = !s.isOverclockRunning && s.effectiveFireInterval == baseInterval && near(s.effectiveDamageMultiplier, baseDamage) && near(s.effectiveMoveSpeed, baseSpeed)
    check("XO3 the clock: after 1 s of active play 2 s remain and the bonuses hold; a chained level-up REFRESHES to 3 s (never 5 s, never a stacked strength); it runs out after 3 s of active play and every bonus returns to its external baseline",
          ticking && refreshed && stillOn && expired, "ticking \(ticking) refreshed \(refreshed) stillOn \(stillOn) expired \(expired)")
    s.triggerOverclock(); s.reset()
    check("XO4 reset clears Overclock (not owned, no timer) and N2's run fields (cap 15, no granted level owed)",
          !s.overclockActive && !s.isOverclockRunning && s.runLevelCap == N.runLevelCap && s.grantedLevelsPending == 0)
}

// ── XB · XP Boost through its real effect ─────────────────────────────────────
do {
    guard let behavior = AbilityBehaviors.registry.cards["neutral_5"] else { check("XB0 XP Boost's behaviour is registered", false); exit(1) }
    let s = PlayerStats()
    s.xpMultiplier += 0.10                          // an external XP bonus
    s.runLevelCap = 25                              // a higher cap set elsewhere must not be LOWERED by T3 (max())
    var mult: [CGFloat] = [], caps: [Int] = [], owed: [Int] = []
    for tier in behavior.tiers { tier(s); mult.append(s.xpMultiplier); caps.append(s.runLevelCap); owed.append(s.grantedLevelsPending) }
    check("XB1 XP Boost's three rungs on top of an external +10%: 1.35, 1.60, 1.60 (T3 adds +0 XP); T3 raises the cap by max() (a higher cap is never lowered) and owes exactly one level",
          behavior.tiers.count == 3 && near(mult[0], 1.35) && near(mult[1], 1.60) && near(mult[2], 1.60) && caps == [25, 25, 25] && owed == [0, 0, 1], "\(mult) \(caps) \(owed)")
    let t = PlayerStats(); for tier in behavior.tiers { tier(t) }
    check("XB2 from a plain run: 1.25 → 1.50 → 1.50, cap 15 → 15 → 20, one level owed at T3", near(t.xpMultiplier, 1.5) && t.runLevelCap == 20 && t.grantedLevelsPending == 1)
    // The ledger under XP Boost: T2 pickups and the T3 grant with the bank preserved.
    var l = XPLedger(); for _ in 1...10 { l.collect(1, multiplier: t.xpMultiplier) }
    check("XB3 ten 1-XP orbs under XP Boost T2/T3 (×1.5) credit exactly 15 XP", l.xp == 15 && near(l.carry, 0))
}

// ── QX · the level queue, EXECUTED (v2.2 N2 corrective, Oct 12) ───────────────
// QueueScene/QueuePlayer are generated at build time from the LIVE
// GameScene.swift / PlayerNode.swift (extract-queue.py): the control flow run
// here IS the production control flow, over the real XPLedger and PlayerStats.
// Stubbed: the level-up screen itself (recorded), SpriteKit actions, the stage
// start (recorded). Not covered here: the screen's stat cadence (triggerLevelUp,
// unchanged), XP collection's `.playing` guard (NX3, source-only).
do {
    func xpBoostT3(_ s: PlayerStats) { for tier in AbilityBehaviors.registry.cards["neutral_5"]?.tiers ?? [] { tier(s) } }   // the real effect: cap 20, one owed level
    func levelTo(_ scene: QueueScene, _ level: Int) { for _ in 1..<level { _ = scene.player.grantLevel() } }                  // the opener's own grant (clears XP)

    // QX1 — campaign (the reviewer's normal-mode case): T3 just picked at level 4
    // with 22 XP banked at ×1.25 (27 → levels 5 and 6 are both due afterwards).
    do {
        let sc = QueueScene(); levelTo(sc, 4); xpBoostT3(sc.playerStats)
        _ = sc.player.addXP(22)                                                   // ×1.5 under T2/T3 → 33 XP, carry 0
        let xp0 = sc.player.currentXP, carry0 = sc.player.ledgerCarry
        sc.resumeAfterLevelUp()                                                   // the pick's screen closed → the queue
        let grantScreen = sc.screens.count == 1 && sc.screens[0].level == 5 && sc.screens[0].pendingAfter == 0 && sc.player.currentXP == xp0 && sc.player.ledgerCarry == carry0
            && sc.playerStats.grantedLevelsPending == 0 && sc.gameState == .levelUp && sc.playResumes == 0
        sc.resumeAfterLevelUp()
        let bank1 = sc.screens.count == 2 && sc.screens[1].level == 6 && sc.player.currentXP == xp0 - XPLedger.xpRequired(forLevel: 6) && sc.gameState == .levelUp && sc.playResumes == 0
        sc.resumeAfterLevelUp()
        let bank2 = sc.screens.count == 3 && sc.screens[2].level == 7 && sc.gameState == .levelUp
        sc.playerStats.overclockActive = true
        sc.resumeAfterLevelUp()
        let resumed = sc.screens.count == 3 && sc.gameState == .playing && sc.playResumes == 1 && sc.stageStarts == 0 && sc.playerStats.isOverclockRunning && sc.invulnerableTimer == 2.5
        check("QX1 [executed] campaign, T3 picked at level 4 with banked XP: resume → the GRANTED level's screen (5) first, XP and carry kept as an absolute amount, pending 0, no play; resume → banked level 6 (XP minus its threshold); resume → banked level 7; resume → no screen, play resumes ONCE, Overclock's window starts, no stage start",
              grantScreen && bank1 && bank2 && resumed, "grant \(grantScreen) bank1 \(bank1) bank2 \(bank2) resumed \(resumed) screens \(sc.screens.map { $0.level })")
    }

    // QX2 — the reviewer's reproducer: T3 picked on opener level 4, five rounds remaining.
    do {
        let sc = QueueScene(); levelTo(sc, 4); xpBoostT3(sc.playerStats)
        sc.openerDraftRunning = true; sc.openerDraftRemaining = 5; sc.openerDraftTotal = 8
        _ = sc.player.addXP(3)                                                    // a little XP the grant must keep
        let xp0 = sc.player.currentXP
        sc.resumeAfterLevelUp()
        let first = sc.screens.first
        let grantFirst = sc.screens.count == 1 && first?.level == 5 && first?.pendingAfter == 0 && first?.openerRemaining == 5 && first?.openerRunning == true
            && sc.player.currentXP == xp0 && sc.openerDraftRemaining == 5 && sc.stageStarts == 0 && sc.gameState == .levelUp
        check("QX2 [executed] the reviewer's reproducer — T3 picked on opener level 4 with five rounds remaining: the next screen is the GRANTED level (5) with the XP kept, pending 0, and the opener's remaining rounds UNCHANGED (5); no stage start",
              grantFirst, "screens \(sc.screens.map { ($0.level, $0.openerRemaining) }) pending \(sc.playerStats.grantedLevelsPending) remaining \(sc.openerDraftRemaining)")
        // Then the five opener rounds, one per resume, each its own clearing grant; then the handoff.
        var rounds: [(Int, Int, Int)] = []
        for _ in 1...5 { sc.resumeAfterLevelUp(); rounds.append((sc.screens.last?.level ?? -1, sc.openerDraftRemaining, sc.player.currentXP)) }
        let openerRounds = rounds.map { $0.0 } == [6, 7, 8, 9, 10] && rounds.map { $0.1 } == [4, 3, 2, 1, 0] && rounds.allSatisfy { $0.2 == 0 }
            && sc.screens.count == 6 && sc.stageStarts == 0 && sc.gameState == .levelUp
        sc.resumeAfterLevelUp()                                                   // the last round's pick → terminal → queue (empty) → stage 1
        let handoff = sc.screens.count == 6 && sc.stageStarts == 1 && sc.stageStartedWhilePending == 0 && !sc.openerDraftRunning && sc.gameState == .playing && sc.playResumes == 1 && !sc.gauntletStageStartPending
        check("QX2b [executed] after the granted screen the five opener rounds run unchanged (levels 6–10, remaining 4→0, each round's own grant clearing XP), then stage 1 starts exactly once with nothing pending and play resumes once — six screens in all for 1 grant + 5 rounds",
              openerRounds && handoff, "rounds \(rounds) screens \(sc.screens.count) stage \(sc.stageStarts) resumes \(sc.playResumes)")
    }

    // QX3 — grant before bank, with pending 2 (two owed levels → two screens, no double-apply).
    do {
        let sc = QueueScene(); levelTo(sc, 10); xpBoostT3(sc.playerStats); sc.playerStats.grantedLevelsPending = 2
        _ = sc.player.addXP(1000)                                                 // several banked levels
        let xp0 = sc.player.currentXP
        var seq: [Int] = []
        for _ in 1...2 { sc.resumeAfterLevelUp(); seq.append(sc.screens.last?.level ?? -1) }
        let grants = seq == [11, 12] && sc.player.currentXP == xp0 && sc.playerStats.grantedLevelsPending == 0
        sc.resumeAfterLevelUp(); let bankLevel = sc.screens.last?.level ?? -1
        check("QX3 [executed] two owed grants resolve first (11, 12), each exactly once, XP untouched; only then the first banked level (13) takes its threshold",
              grants && bankLevel == 13 && sc.player.currentXP == xp0 - XPLedger.xpRequired(forLevel: 13) && sc.screens.count == 3, "\(seq) bank \(bankLevel)")
    }

    // QX4 — the exact drop the reviewer injected: a grant must be CONSUMED, never discarded; and a resume with nothing pending opens no screen.
    do {
        let sc = QueueScene(); levelTo(sc, 7); xpBoostT3(sc.playerStats)
        sc.resumeAfterLevelUp()
        let consumed = sc.screens.map { $0.level } == [8] && sc.playerStats.grantedLevelsPending == 0
        sc.resumeAfterLevelUp()                                                   // the granted screen closed: nothing banked → play
        let quiet = sc.screens.count == 1 && sc.gameState == .playing && sc.playResumes == 1
        sc.resumeAfterLevelUp()                                                   // a duplicate/early resume with nothing pending: no screen, no second grant
        let duplicate = sc.screens.count == 1 && sc.player.currentLevel == 8 && sc.playResumes == 2
        check("QX4 [executed] an owed grant is CONSUMED into exactly one screen (level 8) and never re-applied; a resume with nothing pending resumes play without a screen; a duplicate resume grants nothing and opens nothing",
              consumed && quiet && duplicate, "consumed \(consumed) quiet \(quiet) duplicate \(duplicate)")
    }

    // QX5 — at the cap the grant has nowhere to go: dropped, play resumes, no screen.
    do {
        let sc = QueueScene(); xpBoostT3(sc.playerStats); levelTo(sc, 20)
        sc.playerStats.grantedLevelsPending = 1
        sc.resumeAfterLevelUp()
        check("QX5 [executed] an owed grant at the cap (20) opens no screen, is consumed (pending 0), and play resumes",
              sc.screens.isEmpty && sc.player.currentLevel == 20 && sc.playerStats.grantedLevelsPending == 0 && sc.gameState == .playing)
    }

    // QX6 — the draft opener's terminal handoff waits for the queue.
    do {
        let sc = QueueScene(); levelTo(sc, 9); xpBoostT3(sc.playerStats)          // T3 picked on the LAST opener round
        sc.openerDraftRunning = true; sc.openerDraftRemaining = 0; sc.openerDraftTotal = 8
        sc.resumeAfterLevelUp()
        let grantBeforeStage = sc.screens.map { $0.level } == [10] && sc.stageStarts == 0 && sc.openerDraftRunning
        sc.resumeAfterLevelUp()
        let stageAfter = sc.screens.count == 1 && sc.stageStarts == 1 && sc.stageStartedWhilePending == 0 && !sc.openerDraftRunning && sc.gameState == .playing && sc.playResumes == 1
        check("QX6 [executed] T3 on the last opener round: the granted screen (10) comes before stage 1; stage 1 starts exactly once, only after the queue is empty, and play resumes once",
              grantBeforeStage && stageAfter, "grantBeforeStage \(grantBeforeStage) stageAfter \(stageAfter)")
    }

    // QX7 — banked XP taken in the draft (a big boss orb is impossible there, but the rule is the same): banked levels come before the next opener round too.
    do {
        let sc = QueueScene(); levelTo(sc, 5)
        sc.openerDraftRunning = true; sc.openerDraftRemaining = 2; sc.openerDraftTotal = 8
        _ = sc.player.addXP(XPLedger.xpRequired(forLevel: 6))
        sc.resumeAfterLevelUp(); let bank = sc.screens.last?.level ?? -1
        sc.resumeAfterLevelUp(); let round = sc.screens.last?.level ?? -1
        check("QX7 [executed] a banked level due during the draft is taken (6) before the next opener round (7); the round count is untouched by the banked screen",
              bank == 6 && round == 7 && sc.openerDraftRemaining == 1 && sc.screens.count == 2, "bank \(bank) round \(round) remaining \(sc.openerDraftRemaining)")
    }

    // QX8 — takeNextLevel (XP collection's seam): one level per call.
    do {
        let sc = QueueScene(); sc.gameState = .playing
        _ = sc.player.addXP(5 + 6 + 8)
        sc.takeNextLevel()
        check("QX8 [executed] takeNextLevel opens exactly one screen for a pickup worth three levels (2); the rest wait for the queue at resume",
              sc.screens.map { $0.level } == [2] && sc.player.isLevelDue && sc.gameState == .levelUp)
    }
}

// ── PX · AttackPattern, pure (v2.2 N3, R3 ruling) ─────────────────────────────
do {
    typealias AP = AttackPattern
    func deg(_ r: CGFloat) -> CGFloat { AP.degrees(r) }
    func same(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 1e-9 }
    func sameDeg(_ list: [CGFloat], _ want: [CGFloat]) -> Bool { list.count == want.count && zip(list, want).allSatisfy { same(deg($0), $1) } }

    // PX1 Scatter's lanes by tier.
    let t0 = AP.scatterLanes(tier: 0), t1 = AP.scatterLanes(tier: 1), t2 = AP.scatterLanes(tier: 2), t3 = AP.scatterLanes(tier: 3), t4 = AP.scatterLanes(tier: 4)
    check("PX1 Scatter lanes: T0 one straight lane; T1 two PARALLEL lanes 12 pt apart (headings 0, origins ∓6); T2 0/±15°; T3 0/±15°/±30°; T4 nine lanes 0/±14.75°…±59° (118° total) — totals 1/2/3/5/9",
          t0.count == 1 && t0[0] == AP.Lane(heading: 0, originOffset: 0)
            && t1.count == 2 && t1.allSatisfy { $0.heading == 0 } && same(t1[0].originOffset, -6) && same(t1[1].originOffset, 6)
            && sameDeg(t2.map { $0.heading }, [-15, 0, 15]) && t2.allSatisfy { $0.originOffset == 0 }
            && sameDeg(t3.map { $0.heading }, [-30, -15, 0, 15, 30])
            && sameDeg(t4.map { $0.heading }, [-59, -44.25, -29.5, -14.75, 0, 14.75, 29.5, 44.25, 59]) && same(deg(t4.last!.heading - t4.first!.heading), 118),
          "t2 \(t2.map { deg($0.heading) }) t4 \(t4.map { deg($0.heading) })")

    // PX2 Fracture's fans by tier.
    let f1 = AP.fractureOffsets(tier: 1), f2 = AP.fractureOffsets(tier: 2), f3 = AP.fractureOffsets(tier: 3), f4 = AP.fractureOffsets(tier: 4)
    check("PX2 Fracture fans: T0 the shot itself; T1 3 over 30° (−15/0/15); T2 5 over 60° (step 15); T3 9 over 120° (step 15, ±60); T4 17 over 180° (step 11.25, ±90) — every fan centred, evenly spaced, centre included",
          AP.fractureOffsets(tier: 0) == [0] && sameDeg(f1, [-15, 0, 15]) && sameDeg(f2, [-30, -15, 0, 15, 30])
            && f3.count == 9 && same(deg(f3.first!), -60) && same(deg(f3[1] - f3[0]), 15) && f3[4] == 0
            && f4.count == 17 && same(deg(f4.first!), -90) && same(deg(f4.last!), 90) && same(deg(f4[1] - f4[0]), 11.25) && f4[8] == 0)

    // PX3 Composition: counts and shares for every tier pair; lane-major; one centre per lane; share = 1/n; shares sum to 1 per lane.
    var countsOK = true, sharesOK = true
    for st in 0...4 { for ft in 0...4 {
        let lanes = AP.scatterLanes(tier: st), fan = AP.fractureOffsets(tier: ft)
        let b = AP.compose(lanes: lanes, fracture: fan)
        if b.count != lanes.count * fan.count { countsOK = false }
        for li in 0..<lanes.count {
            let mine = b.filter { $0.lane == li }
            if mine.count != fan.count || mine.filter({ $0.isCenter }).count != 1 || !same(mine.reduce(0) { $0 + $1.share }, 1) || !mine.allSatisfy({ same($0.share, 1 / CGFloat(fan.count)) && same($0.originOffset, lanes[li].originOffset) }) { sharesOK = false }
        }
    } }
    check("PX3 every Scatter × Fracture pair composes lanes × branches (1…153), lane-major, exactly one centre per lane, each branch 1/n of its parent and each lane's shares summing to 1, origins carried from the lane", countsOK && sharesOK)

    // PX4 The forward-spread rule: T4 + T4 → 153 branches, maxAbs 149° → scale 90/149, outermost exactly ±90°, every heading scaled by the same factor, all 153 distinct; T2 + T2 (±45°) untouched.
    let full = AP.compose(lanes: t4, fracture: f4)
    let scale = AP.forwardScale(lanes: t4, fracture: f4)
    let outer = full.map { abs($0.heading) }.max() ?? 0
    let unscaled = zip(t4.flatMap { lane in f4.map { lane.heading + $0 } }, full).allSatisfy { same($0.0 * scale, $0.1.heading) }
    let distinct = Set(full.map { "\($0.originOffset)|\(($0.heading * 1e9).rounded())" }).count
    let t2f2 = AP.compose(lanes: t2, fracture: f2)
    let lane4Fan = full.filter { $0.lane == 8 }.map { deg($0.heading) }
    check("PX4 Scatter T4 + Fracture T4: 153 branches; the outermost would be ±149°, so every angle is scaled by 90/149 (\(String(format: "%.4f", 90.0 / 149.0))) and the outermost lands at exactly ±90°; all 153 headings distinct; lane +59°'s fan spans 35.6°–90°; Scatter T2 + Fracture T2 (±45°) is not scaled",
          full.count == 153 && same(scale, 90.0 / 149.0) && same(deg(outer), 90) && unscaled && distinct == 153
            && same(lane4Fan.first ?? 0, (59 - 90) * 90 / 149) && same(lane4Fan.last ?? 0, 90)
            && AP.forwardScale(lanes: t2, fracture: f2) == 1 && same(deg(t2f2.map { abs($0.heading) }.max() ?? 0), 45),
          "count \(full.count) scale \(scale) outer \(deg(outer)) distinct \(distinct)")

    // PX5 Coincident branches are kept, both, as different parents' shares (Scatter T3 15° step + Fracture T1 ±15°).
    let coincident = AP.compose(lanes: t3, fracture: f1)
    let keyed = Dictionary(grouping: coincident) { "\(($0.heading * 1e9).rounded())" }
    let overlaps = keyed.values.filter { $0.count > 1 }
    let groupSizes = keyed.values.map { $0.count }.sorted()
    check("PX5 Scatter T3 (15°) + Fracture T1 (±15°): 15 branches on only 7 distinct headings (−45…45 by 15°) — the five inner headings are coincident across neighbouring lanes (group sizes 2/3/3/3/2, every group from different parents); all 15 are kept as separate shares, nothing dropped or merged",
          coincident.count == 15 && keyed.count == 7 && overlaps.count == 5 && groupSizes == [1, 1, 2, 2, 3, 3, 3]
            && overlaps.allSatisfy { Set($0.map { $0.lane }).count == $0.count },
          "overlaps \(overlaps.count) distinct \(keyed.count) sizes \(groupSizes)")

    // PX6 Storm Engine's +2 lanes ride the tier's own step; without Scatter the v1.9 count fan stands.
    let s2 = AP.lanes(count: 5, scatterTier: 2, legacyCone: 0), s1 = AP.lanes(count: 4, scatterTier: 1, legacyCone: 0), s4 = AP.lanes(count: 11, scatterTier: 4, legacyCone: 0)
    let cone = 0.25 * 1.5
    let l3 = AP.lanes(count: 3, scatterTier: 0, legacyCone: cone), l2 = AP.lanes(count: 2, scatterTier: 0, legacyCone: cone), l1 = AP.lanes(count: 1, scatterTier: 0, legacyCone: cone)
    check("PX6 Storm Engine's +2 pellets: Scatter T2 + 2 → 5 lanes 0/±15/±30 (the next outward step); T1 + 2 → four parallel lanes ∓18/∓6; T4 + 2 → 11 lanes out to ±73.75°; without Scatter the legacy count fan is unchanged (1 straight, 2 parallel ∓6, 3 across the static cone spreadAngle × 1.5 = ±10.74°)",
          sameDeg(s2.map { $0.heading }, [-30, -15, 0, 15, 30]) && s1.count == 4 && s1.allSatisfy { $0.heading == 0 } && same(s1[0].originOffset, -18) && same(s1[3].originOffset, 18)
            && s4.count == 11 && same(deg(s4.last!.heading), 73.75)
            && l1 == [AP.Lane(heading: 0, originOffset: 0)] && l2.map { $0.originOffset } == [-6, 6] && l3.count == 3 && same(l3[0].heading, -cone / 2) && l3[1].heading == 0 && same(l3[2].heading, cone / 2))

    // PX7 chanceRounded: expectation preserved, no floor, monotone in the unit.
    var sum = 0; let grid = 1000
    for i in 0..<grid { sum += AP.chanceRounded(1.0 / 3.0, unit: (CGFloat(i) + 0.5) / CGFloat(grid)) }
    var sum2 = 0; for i in 0..<grid { sum2 += AP.chanceRounded(3.4, unit: (CGFloat(i) + 0.5) / CGFloat(grid)) }
    check("PX7 chanceRounded(1/3): 0 or 1 with expectation 1/3 over a uniform threshold grid (\(sum)/\(grid)); 3.4 → 3 or 4 with expectation 3.4 (\(sum2)/\(grid)); 0 → 0; a whole number is itself; never floored to 1",
          sum == 333 && sum2 == 3400 && AP.chanceRounded(0, unit: 0.1) == 0 && AP.chanceRounded(2, unit: 0.99) == 2 && AP.chanceRounded(0.2, unit: 0.9) == 0 && AP.chanceRounded(0.2, unit: 0.1) == 1)

    // PX8 Stress: 153 branches × 60 enemies, segment–circle hit tests (the per-tick cost a beam consumer would pay); optimisation never changes a hit verdict.
    struct Enemy { let p: CGPoint; let r: CGFloat }
    var rng = UInt64(12345)
    func next() -> CGFloat { rng = rng &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((rng >> 11) % 1_000_000) / 1_000_000 }
    let enemies = (0..<60).map { _ in Enemy(p: CGPoint(x: (next() - 0.5) * 800, y: (next() - 0.5) * 800), r: 12 + next() * 20) }
    func hits(_ b: AP.Branch, _ e: Enemy) -> Bool {
        let d = CGPoint(x: cos(b.heading), y: sin(b.heading)), o = CGPoint(x: -d.y * b.originOffset, y: d.x * b.originOffset)
        let rel = CGPoint(x: e.p.x - o.x, y: e.p.y - o.y); let t = max(0, min(600, rel.x * d.x + rel.y * d.y))
        let c = CGPoint(x: o.x + d.x * t, y: o.y + d.y * t); return (c.x - e.p.x) * (c.x - e.p.x) + (c.y - e.p.y) * (c.y - e.p.y) <= e.r * e.r
    }
    let clock = DispatchTime.now()
    var total = 0
    for _ in 0..<10 { for b in full { for e in enemies where hits(b, e) { total += 1 } } }
    let ms = Double(DispatchTime.now().uptimeNanoseconds - clock.uptimeNanoseconds) / 1e6 / 10
    print("      PX8 cost: 153 branches × 60 enemies = 9,180 segment–circle tests per tick, \(String(format: "%.3f", ms)) ms per tick (10 ticks averaged), \(total / 10) hits per tick")
    check("PX8 the 153-branch tick costs under 5 ms for 60 enemies (pure geometry; several branches may hit one enemy, each a separate share — \(total / 10) hits for 60 enemies)", ms < 5 && total / 10 > 60)
}

// ── FX · the fire seam, EXECUTED (fireShotSpread / shotBaseDamage / ProjectileNode rules, extracted verbatim) ──
do {
    typealias AP = AttackPattern
    func same(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 1e-9 }
    // FX1 Scatter T4 + Fracture T4 through the real fireShotSpread: 153 fireProjectile calls, 9 centres with modifiers at share 1/17, headings = compose.
    do {
        let sc = FireScene()
        for tier in AbilityBehaviors.registry.cards["neutral_6"]?.tiers ?? [] { tier(sc.playerStats) }          // the REAL Scatter effect, T1→T4
        for tier in AbilityBehaviors.registry.cards["v18_fracture_shot"]?.tiers ?? [] { tier(sc.playerStats) } // the REAL Fracture effect, T1→T4
        let count = sc.playerStats.volleyPelletCount(isSpreadVolley: false)
        sc.fireShotSpread(count: count, baseDirection: CGPoint(x: 0, y: 1))
        let expected = AP.compose(lanes: AP.scatterLanes(tier: 4), fracture: AP.fractureOffsets(tier: 4))
        let headingsMatch = zip(sc.shots, expected).allSatisfy { shot, b in same(atan2(shot.direction.y, shot.direction.x), .pi / 2 + b.heading) && same(shot.fractureShare, b.share) && shot.allowModifiers == b.isCenter && shot.damageScale == 1 }
        check("FX1 [executed] Scatter T4 + Fracture T4 applied through their REAL registry effects, then the real fireShotSpread (volleyPelletCount \(count), scatterTier \(sc.playerStats.scatterTier), fractureTier \(sc.playerStats.fractureTier)): 153 shots, 9 centre branches with modifiers (the parent's primary at share 1/17), 144 fragments at 1/17, every heading and origin exactly AttackPattern.compose's, no damageScale (the share rides the projectile)",
              count == 9 && sc.shots.count == 153 && sc.shots.filter { $0.allowModifiers }.count == 9 && headingsMatch && sc.shots.allSatisfy { same($0.fractureShare, 1.0 / 17.0) },
              "count \(count) shots \(sc.shots.count) centres \(sc.shots.filter { $0.allowModifiers }.count) headings \(headingsMatch)")
    }
    // FX2 No Scatter / no Fracture: one whole shot; Scatter T1: two parallel shots ∓6 pt; Storm volley with T2: 5 lanes.
    do {
        let a = FireScene(); a.fireShotSpread(count: 1, baseDirection: CGPoint(x: 1, y: 0))
        let b = FireScene(); b.playerStats.scatterTier = 1; b.playerStats.extraProjectiles = 1; b.fireShotSpread(count: 2, baseDirection: CGPoint(x: 1, y: 0))
        let c = FireScene(); c.playerStats.scatterTier = 2; c.playerStats.extraProjectiles = 2; c.fireShotSpread(count: c.playerStats.volleyPelletCount(isSpreadVolley: true), baseDirection: CGPoint(x: 1, y: 0))
        check("FX2 [executed] no Scatter: one whole primary shot (share 1, modifiers on); Scatter T1: two parallel full shots at origins ∓6 pt along the left normal, both primary; Scatter T2 on a Storm volley: 5 lanes (3 + 2), all primary, headings 0/±15/±30°",
              a.shots.count == 1 && a.shots[0].allowModifiers && a.shots[0].fractureShare == 1 && a.shots[0].originOffset == .zero
                && b.shots.count == 2 && b.shots.allSatisfy { $0.allowModifiers && $0.fractureShare == 1 } && same(b.shots[0].originOffset.y, -6) && same(b.shots[1].originOffset.y, 6)
                && c.shots.count == 5 && c.shots.allSatisfy { $0.allowModifiers } && same(atan2(c.shots[0].direction.y, c.shots[0].direction.x), AP.radians(-30)))
    }
    // FX3 shotBaseDamage is the WHOLE-SHOT base (N3 corrective): a branch's share is not applied here (it is the chain's last step, DX), so the function is the legacy one bit for bit.
    do {
        let sc = FireScene()
        let whole = ProjectileNode(direction: CGPoint(x: 1, y: 0), damageMultiplier: 10, unit: 0.5)
        let branch = ProjectileNode(direction: CGPoint(x: 1, y: 0), damageMultiplier: 10, unit: 0.5); branch.fractureShare = 1.0 / 3.0
        let tiny = ProjectileNode(direction: CGPoint(x: 1, y: 0), damageMultiplier: 1, unit: 0.5); tiny.fractureShare = 1.0 / 17.0
        sc.playerStats.riftlineActive = true
        var riftSum = 0; for i in 0..<200 { let p = ProjectileNode(direction: CGPoint(x: 1, y: 0), damageMultiplier: 10, unit: (CGFloat(i) + 0.5) / 200); _ = p.onHitEnemy(SKNode()); riftSum += sc.shotBaseDamage(p) }
        check("FX3 [executed] shotBaseDamage ignores the share: a whole shot of 10 is 10 and so is a 1/3 branch's base (the share is applied at the end of the chain, DX1–DX7); a 1/17 branch of base 1 has base 1 (never 0 here, never a free 1 later); with Riftline the A6 falloff (7.5 → 7 or 8 on the A6 threshold) still rounds here, mean 7.5 (\(riftSum)/200)",
              sc.shotBaseDamage(whole) == 10 && sc.shotBaseDamage(branch) == 10 && sc.shotBaseDamage(tiny) == 1 && riftSum == 1500, "rift \(riftSum)")
    }
    // FX4 ProjectileNode.move: unlimited range never expires; finite range expires at maxRange; speed unchanged.
    do {
        let far = ProjectileNode(direction: CGPoint(x: 1, y: 0), range: 400, unlimitedRange: true)
        var expired = false; for _ in 0..<100_000 { if far.move(deltaTime: 0.1) { expired = true; break } }
        let near = ProjectileNode(direction: CGPoint(x: 1, y: 0), range: 400)
        var steps = 0; while !near.move(deltaTime: 0.1) { steps += 1 }
        check("FX4 [executed] an unlimited-range shot travels 4,000,000 pt without expiring; a 400-pt shot expires on the step that reaches 400 (speed 400 → the 10th 0.1 s step)", !expired && far.distanceTraveled >= 4_000_000 - 1 && steps == 9 && near.distanceTraveled >= 400)
    }
    // FX5 one hit per body; pierce-all never consumes; Riftline's 2 pierces consume on the third body.
    do {
        let e1 = SKNode(), e2 = SKNode(), e3 = SKNode(), e4 = SKNode(), e5 = SKNode()
        let p = ProjectileNode(direction: CGPoint(x: 1, y: 0), piercesAll: true)
        let r1 = p.onHitEnemy(e1), r2 = p.onHitEnemy(e2), r3 = p.onHitEnemy(e3)
        let r4 = p.onHitEnemy(e4), r5 = p.onHitEnemy(e5)                   // a hidden finite count would consume here
        let rift = ProjectileNode(direction: CGPoint(x: 1, y: 0), pierces: 2)
        let s1 = rift.onHitEnemy(e1), s2 = rift.onHitEnemy(e2), s3 = rift.onHitEnemy(e3)
        let plain = ProjectileNode(direction: CGPoint(x: 1, y: 0))
        check("FX5 [executed] pierce-all: five bodies, never consumed (no hidden count), each recorded (hasStruck) and bodiesStruck 5 (Riftline's falloff still counts them); Riftline's 2 pierces: consumed on the third body; a plain shot is consumed on its first; a body is never 'not struck' once hit",
              !r1 && !r2 && !r3 && !r4 && !r5 && p.hasStruck(e1) && p.hasStruck(e2) && p.hasStruck(e3) && p.hasStruck(e5) && p.bodiesStruck == 5
                && !s1 && !s2 && s3 && plain.onHitEnemy(e1) && plain.hasStruck(e1) && !plain.hasStruck(e2))
    }
}

// ── DX · the gun's damage chains, EXECUTED (v2.2 N3 corrective, Oct 13: R1 + R2) ──
// HitScene runs the handlers' chains VERBATIM (extracted at build time) over the
// real DirectHitDamage / PlayerStats and the shell projectile; the boss dial is
// ArenaBossNode's verbatim `challengedDamage`. Thresholds: `u` = the A6 (Warp /
// Riftline) one, `h` = the block's, `v` = the share's — three independent draws
// in production, three independent grid axes here.
do {
    func mk(_ base: CGFloat, share: CGFloat = 1, crit: Bool = false, u: CGFloat = 0.5, h: CGFloat = 0.5, v: CGFloat = 0.5, pierces: Int = 0, warp: Bool = false) -> ProjectileNode {
        let p = ProjectileNode(direction: CGPoint(x: 1, y: 0), pierces: pierces, damageMultiplier: base, unit: u, hitUnit: h, shareUnit: v)
        p.fractureShare = share; p.isCrit = crit
        if warp { p.enableWarp(GameConfig.VoidTree.warpCurve) }
        return p
    }
    func grid(_ n: Int) -> [CGFloat] { (0..<n).map { (CGFloat($0) + 0.5) / CGFloat(n) } }
    func near(_ a: CGFloat, _ b: CGFloat, _ rel: CGFloat) -> Bool { abs(a - b) <= max(rel * abs(b), 1e-9) }
    let braceSrc = (try? String(contentsOfFile: "Sparkforge/Nodes/BraceguardNode.swift", encoding: .utf8)) ?? ""
    let cfgSrc = (try? String(contentsOfFile: "Sparkforge/Config/GameConfig.swift", encoding: .utf8)) ?? ""
    check("DX0 the seam's mirrored constants are the sources' (Braceguard shield ×0.5; Brittle Cold ×1.4) — the chains themselves are extracted verbatim (enemy: base → crit → execute → Forge → block → shield → share → basis; boss: base → block, then the dial + share helper)",
          braceSrc.contains("static let shieldDamageMultiplier: CGFloat = 0.5") && cfgSrc.contains("static let brittleColdVuln: CGFloat = 1.4"), "sources read: \(!braceSrc.isEmpty) \(!cfgSrc.isEmpty)")

    // DX1 — IR1: a critical parent of base 1 (×2) deals 2; its 1/17 branches conserve that 2 in aggregate, and some branches deal 0.
    do {
        let sc = HitScene(); let e = EnemyNode()
        let parent = sc.resolveGunHit(projectileNode: mk(1, crit: true), enemyNode: e, braceguardShielded: false)
        var sum = 0, zeros = 0, n = 0
        for h in grid(10) { for v in grid(1700) {                        // 1700 = 17 × 100: the share's expectation is exactly representable
            let b = sc.resolveGunHit(projectileNode: mk(1, share: 1.0 / 17.0, crit: true, h: h, v: v), enemyNode: e, braceguardShielded: false)
            sum += b.dealt; if b.dealt == 0 { zeros += 1 }; n += 1
        } }
        let branchMean = CGFloat(sum) / CGFloat(n)
        check("DX1 [executed, IR1] crit parent base 1 → 2 (the legacy floor stays the parent's); each 1/17 critical branch averages 2/17 = \(String(format: "%.4f", 2.0 / 17.0)) (got \(String(format: "%.4f", branchMean))), zero-damage branches occur (\(zeros) of \(n)), and 17 branches conserve 2 in aggregate — not 34",
              parent.dealt == 2 && parent.basis == 2 && near(branchMean * 17, 2, 1e-9) && zeros > 0, "parent \(parent) branchMean \(branchMean)")
    }
    // DX2 — IR2: Riftline (one prior body) base 10 → the accepted parent mean 7.5; 1/17 branches average 7.5/17 — no correlated second rounding.
    do {
        let sc = HitScene(); sc.playerStats.riftlineActive = true; let e = EnemyNode()
        var psum = 0, pn = 0
        for u in grid(200) { let p = mk(10, u: u); _ = p.onHitEnemy(SKNode()); psum += sc.resolveGunHit(projectileNode: p, enemyNode: e, braceguardShielded: false).dealt; pn += 1 }
        var bsum = 0, bn = 0
        for u in grid(200) { for v in grid(170) {                        // the same A6 grid as the parent; 170 = 17 × 10 for the share
            let b = mk(10, share: 1.0 / 17.0, u: u, v: v); _ = b.onHitEnemy(SKNode())
            bsum += sc.resolveGunHit(projectileNode: b, enemyNode: e, braceguardShielded: false).dealt; bn += 1
        } }
        let pm = CGFloat(psum) / CGFloat(pn), bm = CGFloat(bsum) / CGFloat(bn)
        check("DX2 [executed, IR2] Riftline base 10 after one body: parent mean 7.5 (got \(String(format: "%.4f", pm))); each 1/17 branch averages 7.5/17 = \(String(format: "%.4f", 7.5 / 17.0)) (got \(String(format: "%.4f", bm))) — the share's rounding is on its OWN threshold, so the aggregate is 7.5, not 8",
              near(pm, 7.5, 1e-9) && near(bm * 17, pm, 1e-9), "pm \(pm) bm \(bm) ×17 \(bm * 17)")
    }
    // DX3 — IR3: the shield preserves zero and keeps the legacy floor for positive hits; a shielded branch conserves the shielded parent.
    do {
        var z = DirectHit(basis: 0, dealt: 0); z.shield(by: 0.5)
        var one = DirectHit(basis: 1, dealt: 1); one.shield(by: 0.5)
        var three = DirectHit(basis: 3, dealt: 3); three.shield(by: 0.5)
        let sc = HitScene(); let e = EnemyNode()
        let parent = sc.resolveGunHit(projectileNode: mk(1), enemyNode: e, braceguardShielded: true)
        var sum = 0, zeros = 0, n = 0
        for v in grid(1700) { let b = sc.resolveGunHit(projectileNode: mk(1, share: 1.0 / 17.0, v: v), enemyNode: e, braceguardShielded: true); sum += b.dealt; if b.dealt == 0 { zeros += 1 }; n += 1 }
        check("DX3 [executed, IR3] DirectHit.shield: 0 stays 0 (basis and dealt); 1 → 1 and 3 → 1 (the legacy floor, unchanged); through the chain a shielded parent of 1 deals 1 and its 1/17 branches average 1/17 (\(sum)/\(n)) with \(zeros) zeros — the share is taken AFTER the shield, never resurrected by it",
              z == DirectHit(basis: 0, dealt: 0) && one == DirectHit(basis: 1, dealt: 1) && three == DirectHit(basis: 1, dealt: 1)
                && parent.dealt == 1 && sum == 100 && zeros == 1600)
    }
    // DX4 — IR4: the Boss Mode DEF dial: applied to the parent, then the share; a zero share is never resurrected; the execute rule stays the parent's.
    do {
        let sc = HitScene(); let boss = ArenaBossStub(health: 100, def: 3)
        let p = mk(10)
        let parent = sc.resolveGunHitBoss(projectileNode: p, bossNode: boss)
        let whole = sc.fractureBranchOnBoss(parent, projectile: p, boss: boss)
        let wholeFinal = whole.ignoresChallengeDEF ? whole.hit.dealt : boss.challengedDamage(whole.hit.dealt, raw: whole.hit.basis, ignoresChallengeDEF: false)
        var sum = 0, zeros = 0, n = 0, allIgnore = true
        for v in grid(1700) {
            let b = mk(10, share: 1.0 / 17.0, v: v)
            let hit = sc.resolveGunHitBoss(projectileNode: b, bossNode: boss)
            let branch = sc.fractureBranchOnBoss(hit, projectile: b, boss: boss)
            allIgnore = allIgnore && branch.ignoresChallengeDEF
            let final = branch.ignoresChallengeDEF ? branch.hit.dealt : boss.challengedDamage(branch.hit.dealt, raw: branch.hit.basis, ignoresChallengeDEF: false)
            sum += final; if final == 0 { zeros += 1 }; n += 1
        }
        let exec = ArenaBossStub(health: 5, def: 3)
        check("DX4 [executed, IR4] boss, DEF 3: a whole shot of 10 enters with the dial still the node's (→ 7); a 1/17 branch takes the dial on the PARENT (7) then its share — mean 7/17 (\(sum)/\(n)), \(zeros) zeros — and enters with the dial bypassed; challengedDamage(0) stays 0; an execute (raw ≥ health) still lands the parent's full 10",
              parent.dealt == 10 && !whole.ignoresChallengeDEF && wholeFinal == 7 && allIgnore && sum == 700 && zeros == 1000
                && boss.challengedDamage(0, raw: 0, ignoresChallengeDEF: false) == 0 && exec.challengedDamage(10, raw: 10, ignoresChallengeDEF: false) == 10,
              "parent \(parent) wholeFinal \(wholeFinal) sum \(sum) zeros \(zeros)")
    }
    // DX5 — expectation across branch counts and modifiers: the aggregate of n branches equals the parent's expectation (both chains).
    do {
        struct Case { let base: CGFloat; let crit: Bool; let rift: Bool; let warp: Bool; let slowed: Bool; let vuln: CGFloat; let shield: Bool; let def: Int }
        var cases: [Case] = []
        for base: CGFloat in [1, 37] { for crit in [false, true] { for (rift, warp) in [(false, false), (true, false), (false, true)] { for shield in [false, true] {
            cases.append(Case(base: base, crit: crit, rift: rift, warp: warp, slowed: true, vuln: 1.5, shield: shield, def: 3))
        } } } }
        var worst: CGFloat = 0, worstCase = "", checked = 0
        for c in cases { for n in [3, 5, 9, 17] {
            let sc = HitScene(); sc.playerStats.riftlineActive = c.rift; sc.playerStats.critMultiplier = 2.1; sc.playerStats.slowedDamageBonus = 0.25
            let e = EnemyNode(); e.isSlowed = c.slowed; e.vulnerabilityMultiplier = c.vuln
            let boss = ArenaBossStub(health: 1000, def: c.def); boss.vulnerabilityMultiplier = c.vuln
            let G = 12
            var pE = 0, pB = 0, pn = 0
            for u in grid(G) { for h in grid(G) {
                let p = mk(c.base, crit: c.crit, u: u, h: h, warp: c.warp); if c.rift { _ = p.onHitEnemy(SKNode()) }
                pE += sc.resolveGunHit(projectileNode: p, enemyNode: e, braceguardShielded: c.shield).dealt
                let pb = mk(c.base, crit: c.crit, u: u, h: h, warp: c.warp); if c.rift { _ = pb.onHitEnemy(SKNode()) }
                let hb = sc.resolveGunHitBoss(projectileNode: pb, bossNode: boss); let wb = sc.fractureBranchOnBoss(hb, projectile: pb, boss: boss)
                pB += wb.ignoresChallengeDEF ? wb.hit.dealt : boss.challengedDamage(wb.hit.dealt, raw: wb.hit.basis, ignoresChallengeDEF: false)
                pn += 1
            } }
            var bE = 0, bB = 0, bn = 0
            for u in grid(G) { for h in grid(G) { for v in grid(n * 10) {     // n × 10: every k/n share expectation is exact on this axis
                let b = mk(c.base, share: 1 / CGFloat(n), crit: c.crit, u: u, h: h, v: v, warp: c.warp); if c.rift { _ = b.onHitEnemy(SKNode()) }
                bE += sc.resolveGunHit(projectileNode: b, enemyNode: e, braceguardShielded: c.shield).dealt
                let bb = mk(c.base, share: 1 / CGFloat(n), crit: c.crit, u: u, h: h, v: v, warp: c.warp); if c.rift { _ = bb.onHitEnemy(SKNode()) }
                let hb = sc.resolveGunHitBoss(projectileNode: bb, bossNode: boss); let wb = sc.fractureBranchOnBoss(hb, projectile: bb, boss: boss)
                bB += wb.ignoresChallengeDEF ? wb.hit.dealt : boss.challengedDamage(wb.hit.dealt, raw: wb.hit.basis, ignoresChallengeDEF: false)
                bn += 1
            } } }
            let parentE = CGFloat(pE) / CGFloat(pn), branchE = CGFloat(bE) / CGFloat(bn) * CGFloat(n)
            let parentB = CGFloat(pB) / CGFloat(pn), branchB = CGFloat(bB) / CGFloat(bn) * CGFloat(n)
            let dev = max(abs(branchE - parentE) / max(parentE, 1e-9), abs(branchB - parentB) / max(parentB, 1e-9))
            if dev > worst { worst = dev; worstCase = "base \(c.base) crit \(c.crit) rift \(c.rift) warp \(c.warp) shield \(c.shield) n \(n): enemy \(branchE) vs \(parentE), boss \(branchB) vs \(parentB)" }
            checked += 1
        } }
        check("DX5 [executed] \(checked) configurations (base 1 / 37; crit ×2.1; Warp ×1.5 at launch / Riftline ×0.75 after a body; Permafrost ×1.25 on a slowed target; vulnerability ×1.5; Braceguard shield; boss DEF 3) × branch counts 3 / 5 / 9 / 17, enemy AND boss chains: the n branches' aggregate expectation equals the parent's EXACTLY (the parent and its branches on the same A6/block grid; the share axis sized n × 10 so every k/n expectation is exact; worst relative deviation \(String(format: "%.2e", worst)) at \(worstCase))",
              worst < 1e-9, worstCase)
    }
    // DX6 — the legacy whole shot (share 1) is untouched: the chain equals the pre-N3 composition, and fractureBranch is the identity.
    do {
        let sc = HitScene(); sc.playerStats.critMultiplier = 2; sc.playerStats.slowedDamageBonus = 0.25
        let e = EnemyNode(); e.isSlowed = true; e.vulnerabilityMultiplier = 1.5
        var same = true
        for base: CGFloat in [1, 2, 7, 37] { for crit in [false, true] { for h in grid(7) { for shield in [false, true] {
            let p = mk(base, crit: crit, h: h)
            let got = sc.resolveGunHit(projectileNode: p, enemyNode: e, braceguardShielded: shield)
            var d = max(1, Int(base)); if crit { d = max(2, Int(CGFloat(d) * 2)) }
            var ref = DirectHitDamage.resolve(d, .onEnemy(permafrostBonus: 0.25, slowed: true, arenaSlowed: false, brittleCold: false, brittleColdFactor: 1.4, frozen: false, stunned: false, openWoundsBonus: 0, bleeding: false),
                                              overcharge: 1, vulnerability: 1.5, rounding: DirectHitRounding(unit: h))
            if shield { ref.shield(by: 0.5) }
            if got != ref || sc.fractureBranch(got, projectile: p) != got { same = false }
        } } } }
        check("DX6 [executed] a whole shot (share 1) runs the legacy composition exactly — base, crit floor 2, the block on its own threshold, the shield — and fractureBranch is the identity for it (56 cases)", same)
    }
    // DX7 — the share's threshold is per projectile: Riftline's falling sequence over bodies never rises for a branch.
    do {
        let sc = HitScene(); sc.playerStats.riftlineActive = true; let e = EnemyNode()
        var monotone = true
        for u in grid(40) { for v in grid(40) {
            let b = mk(10, share: 1.0 / 3.0, u: u, v: v)
            var last = Int.max
            for _ in 0..<4 { let d = sc.resolveGunHit(projectileNode: b, enemyNode: e, braceguardShielded: false).dealt; if d > last { monotone = false }; last = d; _ = b.onHitEnemy(SKNode()) }
        } }
        check("DX7 [executed] one share threshold per projectile: a Riftline branch's damage over successive bodies (100 → 75 → 56 → 42%, thirds) never rises for any threshold pair — the A6 monotonicity policy carries to the share", monotone)
    }
}

// ── BX · the chaos beam's pure rules (v2.2 N4: BeamTick + BeamClock over the real FireClock) ──
do {
    func close(_ a: CGFloat, _ b: CGFloat, _ tol: CGFloat = 1e-9) -> Bool { abs(a - b) <= tol * max(1, abs(b)) }
    // BX1 — the lane tick 0.75 × D × (0.5 ÷ I), with D and I read from the REAL PlayerStats: Rapid Fire T4 via its registry
    // effects and Overclock running — its +35% speed in I ONCE, its +15% damage in D ONCE (the gun's Int(), as N0 §5 rules).
    do {
        let stats = PlayerStats()
        for tier in (AbilityBehaviors.registry.cards["neutral_3"]?.tiers ?? []).prefix(4) { tier(stats) }   // the REAL Rapid Fire effect, T1→T4
        stats.damageMultiplier = 9.86
        let i0 = stats.effectiveFireInterval
        let d0 = OverchargeSplit(stats.overchargeParts(scale: 1)).base
        for tier in AbilityBehaviors.registry.cards["v17_overclock"]?.tiers ?? [] { tier(stats) }   // the REAL Overclock effect (ownership)
        stats.triggerOverclock()
        let i1 = stats.effectiveFireInterval
        let d1 = OverchargeSplit(stats.overchargeParts(scale: 1)).base
        stats.damageMultiplier = 9.72
        let d2 = OverchargeSplit(stats.overchargeParts(scale: 1)).base   // once: 9.87 → 9; twice would be 10.02 → 10
        let tick = BeamTick.laneTick(basis: d1, interval: i1)
        let t5Alone = BeamTick.laneTick(basis: 10, interval: GameConfig.Projectile.fireInterval / 1.9)
        check("BX1 the lane tick = 0.75 × D × (0.5 s ÷ I) from the real stats: Rapid Fire T4 → I = 0.5/1.9 (\(String(format: "%.5f", i0))); Overclock → I = 0.5/1.9/1.35 (speed ONCE) and D 9 → 10 at 9.86 but 9 at 9.72 (damage ONCE, the gun's Int()); tick = \(String(format: "%.4f", tick)); T5 alone at D 10 = 14.25 (N0 §5's 1.425 D); 0 for D 0 or I 0",
              close(CGFloat(i0), CGFloat(0.5 / 1.9)) && close(CGFloat(i1), CGFloat(0.5 / 1.9 / 1.35)) && d0 == 9 && d1 == 10 && d2 == 9
                && close(tick, 0.75 * 10 * 1.9 * 1.35) && close(t5Alone, 14.25) && BeamTick.laneTick(basis: 0, interval: 0.5) == 0 && BeamTick.laneTick(basis: 5, interval: 0) == 0,
              "i0 \(i0) i1 \(i1) d \(d0) \(d1) \(d2) tick \(tick)")
    }
    // BX2 — the exact prefix multiplies every factor once, with no integer step.
    do {
        let base: CGFloat = 0.375
        let plain = BeamTick.exactPrefix(laneTick: base, riftlineRank: 2, riftlineActive: false, riftlineFalloff: 0.75, crit: .none, critMultiplier: 2.1, luckyBreakFactor: 1.5, execute: 1, forge: 1)
        let rift = BeamTick.exactPrefix(laneTick: base, riftlineRank: 2, riftlineActive: true, riftlineFalloff: 0.75, crit: .none, critMultiplier: 2.1, luckyBreakFactor: 1.5, execute: 1, forge: 1)
        let all = BeamTick.exactPrefix(laneTick: base, riftlineRank: 1, riftlineActive: true, riftlineFalloff: 0.75,
                                       crit: BeamTick.LaneCrit(isCrit: true, luckyBreak: true), critMultiplier: 2.1, luckyBreakFactor: 1.5, execute: 2, forge: 1.1)
        let luckyNoCrit = BeamTick.exactPrefix(laneTick: base, riftlineRank: 0, riftlineActive: false, riftlineFalloff: 0.75,
                                               crit: BeamTick.LaneCrit(isCrit: false, luckyBreak: true), critMultiplier: 2.1, luckyBreakFactor: 1.5, execute: 1, forge: 1)
        check("BX2 the exact prefix: 0.375 stays 0.375 (no crit floor 2, no Int); Riftline rank 2 → ×0.5625 only while Riftline is owned; crit ×2.1 × Lucky Break ×1.5 × execute ×2 × Forge ×1.1 × rank 1 (×0.75) = \(all) exactly; Lucky Break never applies without the crit",
              plain == base && close(rift, base * 0.5625) && close(all, base * 0.75 * 2.1 * 1.5 * 2 * 1.1) && luckyNoCrit == base)
    }
    // BX3 — resolveExact: one unbiased rounding with NO floor (basis and dealt), on a deterministic threshold grid.
    do {
        let G = 20000
        let units = (0..<G).map { (CGFloat($0) + 0.5) / CGFloat(G) }
        let amps = DirectHitAmplifiers.onEnemy(permafrostBonus: 0.25, slowed: true, arenaSlowed: false, brittleCold: false, brittleColdFactor: 1.4,
                                               frozen: false, stunned: false, openWoundsBonus: 0, bleeding: false)
        var worst: CGFloat = 0, zeroOK = true, smallZeros = 0
        for prefix: CGFloat in [0, 0.01, 0.2, 0.375, 1, 2.85, 7.3] {
            var b = 0, d = 0
            for u in units {
                let hit = DirectHitDamage.resolveExact(prefix, amps, overcharge: 1.2, vulnerability: 1.5, extra: 0.5, rounding: DirectHitRounding(unit: u))
                b += hit.basis; d += hit.dealt
                if prefix == 0 && (hit.basis != 0 || hit.dealt != 0) { zeroOK = false }
                if prefix == 0.01 && hit.dealt == 0 { smallZeros += 1 }
            }
            let exact = prefix * 1.25 * 1.2 * 0.5
            worst = max(worst, abs(CGFloat(b) / CGFloat(G) - exact), abs(CGFloat(d) / CGFloat(G) - exact * 1.5))
        }
        check("BX3 DirectHitDamage.resolveExact rounds the exact product ONCE, unbiased, with NO floor: over a 20,000-point threshold grid the mean basis and dealt equal prefix × 1.25 × 1.2 × 0.5 (× 1.5 vulnerability for dealt) within 1/G (worst \(String(format: "%.2e", worst))); 0 stays 0 everywhere; a 0.01 prefix deals 0 on \(smallZeros) of \(G) thresholds (never resurrected to 1)",
              worst <= 1.0 / CGFloat(G) && zeroOK && smallZeros > G * 98 / 100)
    }
    // BX4 — contacts: the body circle within the half-width of the segment; sorted along; past the end measured to the end.
    do {
        let ts = [BeamTick.Target(index: 0, position: CGPoint(x: 50, y: 0), radius: 10),
                  BeamTick.Target(index: 1, position: CGPoint(x: 30, y: 13), radius: 10),     // 13 ≤ 10 + 4: touched
                  BeamTick.Target(index: 2, position: CGPoint(x: 70, y: 15), radius: 10),     // 15 > 14: missed
                  BeamTick.Target(index: 3, position: CGPoint(x: 108, y: 0), radius: 10),     // 8 past the end: touched at the end
                  BeamTick.Target(index: 4, position: CGPoint(x: 120, y: 0), radius: 10)]     // 20 past: missed
        let c = BeamTick.contacts(origin: .zero, direction: CGPoint(x: 1, y: 0), length: 100, halfWidth: 4, targets: ts)
        check("BX4 contacts: a target counts when its body comes within the beam's half-width (4) of the segment — touched 1 (30, off 13), 0 (50), 3 (8 past the end, at 100); missed 2 (off 15) and 4 (20 past); sorted by distance along; a zero-length line touches nothing",
              c.map { $0.target } == [1, 0, 3] && c.map { $0.along } == [30, 50, 100]
                && BeamTick.contacts(origin: .zero, direction: CGPoint(x: 1, y: 0), length: 0, halfWidth: 4, targets: ts).isEmpty, "\(c)")
    }
    // BX5 — termini: range / first terrain (bisection) / arena boundary; Long Shot T4 (blocked == nil) passes terrain.
    do {
        let wall: (CGPoint, CGPoint) -> Bool = { a, b in max(a.x, b.x) >= 300 }    // a wall across x = 300
        let R: CGFloat = 1000, steps = GameConfig.Neutral.beamTerrainBisectionSteps
        let ranged = BeamTick.length(origin: .zero, direction: CGPoint(x: 1, y: 0), maxLength: 250, arenaRadius: R, blocked: wall, steps: steps)
        let t3 = BeamTick.length(origin: .zero, direction: CGPoint(x: 1, y: 0), maxLength: .infinity, arenaRadius: R, blocked: wall, steps: steps)
        let t4 = BeamTick.length(origin: .zero, direction: CGPoint(x: 1, y: 0), maxLength: .infinity, arenaRadius: R, blocked: nil, steps: steps)
        let offCentre = BeamTick.length(origin: CGPoint(x: 0, y: 600), direction: CGPoint(x: 0, y: 1), maxLength: .infinity, arenaRadius: R, blocked: nil, steps: steps)
        let diag = BeamTick.length(origin: CGPoint(x: 600, y: 0), direction: CGPoint(x: 0, y: 1), maxLength: .infinity, arenaRadius: R, blocked: nil, steps: steps)
        check("BX5 termini (where a Gravity Well / the Blackhole opens): range 250 short of the wall → 250; Long Shot T3 (no range) → the FIRST wall (\(String(format: "%.3f", t3)), within 1000/2^14); T4 (terrain passed) → the arena boundary 1000; off-centre origins reach the circle (400; 800)",
              ranged == 250 && t3 <= 300 && t3 > 300 - R / CGFloat(1 << steps) && t4 == R && close(offCentre, 400) && close(diag, 800))
    }
    // BX6 — one hit per (parent lane, target, tick): branch contacts grouped, shares summed (k/n), centre → primary, rank along the lane.
    do {
        let lanes = AttackPattern.lanes(count: 2, scatterTier: 1, legacyCone: 0)            // two parallel lanes
        let branches = AttackPattern.compose(lanes: lanes, fracture: AttackPattern.fractureOffsets(tier: 4))   // 2 × 17
        var contacts = Array(repeating: [BeamTick.Contact](), count: branches.count)
        func touch(_ lane: Int, _ idx: [Int], target: Int, along: CGFloat) {
            for (i, b) in branches.enumerated() where b.lane == lane && idx.contains(b.index) { contacts[i].append(BeamTick.Contact(target: target, along: along, point: .zero)) }
        }
        touch(0, [6, 7, 8, 9, 10], target: 0, along: 80)      // lane 0: five branches incl. the centre (8) on target 0
        touch(0, [0, 1, 2], target: 1, along: 40)            // lane 0: three side branches on target 1 (nearer)
        touch(1, [8], target: 0, along: 90)                  // lane 1: the centre on the same target 0 — a SEPARATE hit
        let hits = BeamTick.group(branches: branches, contacts: contacts)
        let l0t0 = hits.first { $0.lane == 0 && $0.target == 0 }, l0t1 = hits.first { $0.lane == 0 && $0.target == 1 }, l1t0 = hits.first { $0.lane == 1 && $0.target == 0 }
        check("BX6 grouping: lane 0's five branches on target 0 are ONE primary hit carrying 5/17 (rank 1, behind target 1); its three side branches on target 1 are ONE fragment hit of 3/17 (rank 0); lane 1's centre on target 0 is a separate primary hit of 1/17 — 3 hits, shares conserved (k × 1/n), never merged across lanes",
              hits.count == 3 && l0t0?.branches == 5 && l0t0?.centre == true && l0t0?.rank == 1 && close(l0t0?.share ?? 0, 5.0 / 17.0)
                && l0t1?.branches == 3 && l0t1?.centre == false && l0t1?.rank == 0 && close(l0t1?.share ?? 0, 3.0 / 17.0)
                && l1t0?.branches == 1 && l1t0?.centre == true && l1t0?.rank == 0 && l1t0?.fanSize == 17, "\(hits)")
    }
    // BX7 — the geometry at the maximum: Scatter T4 × Fracture T4 = 153 lines, a Storm window 11 lanes × 17 = 187; Gravity Wells = parent lanes; cost.
    do {
        let stats = PlayerStats()
        for id in ["neutral_6", "v18_fracture_shot"] { for tier in AbilityBehaviors.registry.cards[id]?.tiers ?? [] { tier(stats) } }
        func lines(_ storm: Bool) -> [AttackPattern.Branch] {
            AttackPattern.compose(lanes: AttackPattern.lanes(count: stats.volleyPelletCount(isSpreadVolley: storm), scatterTier: stats.scatterTier,
                                                             legacyCone: stats.spreadAngle * GameConfig.Projectile.multishotFanWidthFactor),
                                  fracture: AttackPattern.fractureOffsets(tier: stats.fractureTier))
        }
        let normal = lines(false), storm = lines(true)
        let maxHeading = storm.map { abs($0.heading) }.max() ?? 0
        var targets: [BeamTick.Target] = []
        var rng = SystemRandomNumberGenerator()
        for i in 0..<60 { targets.append(BeamTick.Target(index: i, position: CGPoint(x: CGFloat.random(in: -500...500, using: &rng), y: CGFloat.random(in: -500...500, using: &rng)), radius: 14)) }
        let t0 = Date()
        var total = 0
        for _ in 0..<20 {
            let cs = storm.map { b in BeamTick.contacts(origin: .zero, direction: CGPoint(x: cos(b.heading), y: sin(b.heading)), length: 1000, halfWidth: 4, targets: targets) }
            total += BeamTick.group(branches: storm, contacts: cs).count
        }
        let ms = Date().timeIntervalSince(t0) * 1000 / 20
        check("BX7 the maximum: Scatter T4 × Fracture T4 = \(normal.count) lines (9 parent lanes → 9 Gravity Wells), a Storm window \(storm.count) (11 × 17; 11 wells); every heading within ±90°; nothing merged or capped; one 187-line tick over 60 enemies costs \(String(format: "%.2f", ms)) ms (pure geometry + grouping; under 5 ms here — device performance is the deferred human gate)",
              normal.count == 153 && storm.count == 187 && Set(normal.filter { $0.isCenter }.map { $0.lane }).count == 9 && storm.filter { $0.isCenter }.count == 11
                && maxHeading <= .pi / 2 + 1e-9 && ms < 5 && total >= 0)
    }
    // BX8 — C1: the virtual volley compares ACTIVE time with the CURRENT interval; ticks every 0.5 s; idle holds ready; bounded catch-up.
    do {
        var c = BeamClock()
        let a = c.advance(0.6, volleyInterval: 1.0, firing: true)          // 0.6 of 1.0: nothing (tick at 0.5: yes)
        let b = c.advance(0.0, volleyInterval: 0.5, firing: true)          // I drops to 0.5: the 0.6 s already made is kept → volley now
        let carry = c.volleyClock.elapsed
        let d = c.advance(0.3, volleyInterval: 2.0, firing: true)          // I rises: 0.4 of 2.0, no volley; the tick clock 0.1 + 0.3 = 0.4: none
        var idle = BeamClock()
        let e = idle.advance(5.0, volleyInterval: 0.5, firing: false)      // no target for 5 s: nothing fires, nothing banked
        let held = (idle.volleyClock.elapsed, idle.tickClock.elapsed)
        let f = idle.advance(0.0, volleyInterval: 0.5, firing: true)       // a target appears: the due volley + tick fire at once, no catch-up
        let g = idle.advance(0.0, volleyInterval: 0.5, firing: true)
        var hitch = BeamClock()
        let h1 = hitch.advance(10.0, volleyInterval: 0.5, firing: true), h2 = hitch.advance(0.0, volleyInterval: 0.5, firing: true), h3 = hitch.advance(0.0, volleyInterval: 0.5, firing: true)
        var r = BeamClock(); _ = r.advance(0.4, volleyInterval: 1, firing: true); r.reset()
        check("BX8 [C1] BeamClock: 0.6 s at I 1.0 → no volley, one tick; I drops to 0.5 → the volley fires on the next comparison with 0.1 s carried (progress in seconds kept, never rescaled); I rises to 2.0 → nothing; 5 s with no target → nothing, both clocks held READY (no banked time) and the due volley + tick fire together once a target appears, then wait; a 10 s hitch → at most one per frame and one interval of credit; reset → zero",
              a == (false, true) && b == (true, false) && close(CGFloat(carry), 0.1) && d == (false, false) && e == (false, false)
                && held == (0.5, GameConfig.Neutral.beamTickInterval) && f == (true, true) && g == (false, false)
                && h1 == (true, true) && h2 == (true, true) && h3 == (false, false) && r.volleyClock.elapsed == 0 && r.tickClock.elapsed == 0,
              "a \(a) b \(b) carry \(carry) d \(d) e \(e) held \(held) f \(f) g \(g) hitch \(h1) \(h2) \(h3)")
    }
}

// ── BH · the beam's exact parent hits, EXECUTED (v2.2 N4: beamParentHit / beamParentHitBoss + forgeOffense, extracted verbatim) ──
// The block's threshold is drawn fresh per hit in production (`DirectHitRounding()`), so expectations here are
// STATISTICAL (labeled): every sample is checked to be ⌊exact⌋ or ⌊exact⌋ + 1, and the mean within 6σ of the exact value.
extension HitScene {
    /// The PRE-N4 applyForgeOffense, verbatim from the accepted source (evidence n4/original/…/GameScene.swift) — BH0's reference.
    func legacyApplyForgeOffense(_ base: Int, healthPercent: CGFloat, bossClass: Bool,
                                 impaired: Bool, relentlessTarget: EnemyNode?) -> Int {
        var mult: CGFloat = 1.0
        if playerStats.forgeBerserker, playerStats.hpPercent < 0.5 { mult += 0.05 }
        if playerStats.forgeHeadsman, bossClass { mult += 0.10 }
        if playerStats.forgeCleaver, nearbyEnemyCount(GameConfig.ForgePath.holdLineRadius) >= 4 { mult += 0.08 }
        if playerStats.forgeOpeningBlow, healthPercent > 0.9 { mult += 0.10 }
        if playerStats.forgeOpportunist, impaired { mult += 0.05 }
        if playerStats.forgeRisingHeat, forgeRisingHeatStacks > 0 { mult += CGFloat(forgeRisingHeatStacks) * 0.01 }
        if playerStats.forgeWarpath, forgeWarpathDamageTime >= 6.0 { mult += 0.10 }
        if playerStats.forgeRelentless, let t = relentlessTarget {
            if forgeRelentlessTarget === t {
                mult += CGFloat(forgeRelentlessStacks) * 0.01
                if forgeRelentlessStackCD <= 0 {
                    forgeRelentlessStacks = min(forgeRelentlessStacks + 1, 5)
                    forgeRelentlessStackCD = 0.5
                }
            } else {
                forgeRelentlessTarget = t
                forgeRelentlessStacks = 0
            }
            forgeRelentlessTimer = 2.0
        }
        var dmg = Int(CGFloat(base) * mult)
        if playerStats.forgeColdFury, forgeColdFuryArmed {
            dmg = Int(CGFloat(dmg) * 1.10); forgeColdFuryArmed = false; forgeTimeSinceKill = 0
        }
        if playerStats.forgeKillingStroke, forgeKillingStrokeArmed {
            dmg = Int(CGFloat(dmg) * 1.75); forgeKillingStrokeArmed = false; forgeKillingStrokeCooldown = 12.0
        }
        forgeWarpathIdleTime = 0   // this hit counts toward Warpath's continuous window
        return dmg
    }
    var forgeState: [String] {
        ["\(forgeColdFuryArmed)", "\(forgeTimeSinceKill)", "\(forgeKillingStrokeArmed)", "\(forgeKillingStrokeCooldown)", "\(forgeWarpathIdleTime)",
         "\(forgeRelentlessStacks)", "\(forgeRelentlessStackCD)", "\(forgeRelentlessTimer)", "\(forgeRelentlessTarget.map { ObjectIdentifier($0).hashValue } ?? 0)"]
    }
}
do {
    func lane(_ rank: Int = 0, branches: Int = 1, fan: Int = 1, centre: Bool = true) -> BeamTick.LaneHit {
        BeamTick.LaneHit(lane: 0, target: 0, branches: branches, fanSize: fan, centre: centre, rank: rank)
    }
    struct Stat { var n = 0, sum = 0.0, sq = 0.0; var bounded = true
        mutating func add(_ x: Int, exact: CGFloat) { n += 1; sum += Double(x); sq += Double(x * x); let f = Int(exact.rounded(.down)); if x != f && x != f + 1 { bounded = false } }
        var mean: Double { sum / Double(max(1, n)) }
        var sigma: Double { (max(0, sq / Double(max(1, n)) - mean * mean) / Double(max(1, n))).squareRoot() }
        func near(_ e: CGFloat) -> Bool { abs(mean - Double(e)) <= 6 * max(sigma, 1e-12) + 1e-12 }
    }
    // BH0 — the forgeOffense refactor: the gun's integer composition equals the pre-N4 function in value AND side effects.
    do {
        var same = true, cases = 0
        let target = EnemyNode()
        for mask in 0..<(1 << 9) { for base in [1, 7, 37] { for hp: CGFloat in [0.2, 0.95] {
            func configure(_ s: HitScene) {
                let p = s.playerStats
                p.forgeBerserker = mask & 1 != 0; p.forgeHeadsman = mask & 2 != 0; p.forgeOpeningBlow = mask & 4 != 0; p.forgeOpportunist = mask & 8 != 0
                p.forgeRisingHeat = mask & 16 != 0; p.forgeWarpath = mask & 32 != 0; p.forgeRelentless = mask & 64 != 0
                p.forgeColdFury = mask & 128 != 0; p.forgeKillingStroke = mask & 256 != 0
                p.currentHP = p.maxHP / 3
                s.forgeRisingHeatStacks = 3; s.forgeWarpathDamageTime = 7; s.forgeColdFuryArmed = true; s.forgeKillingStrokeArmed = true
                s.forgeRelentlessTarget = target; s.forgeRelentlessStacks = 2; s.forgeWarpathIdleTime = 4
            }
            let a = HitScene(), b = HitScene(); configure(a); configure(b)
            for _ in 0..<2 {    // twice: the consumed charges and the Relentless stack step must match on the second hit too
                let x = a.applyForgeOffense(base, healthPercent: hp, bossClass: mask & 2 != 0, impaired: true, relentlessTarget: target)
                let y = b.legacyApplyForgeOffense(base, healthPercent: hp, bossClass: mask & 2 != 0, impaired: true, relentlessTarget: target)
                if x != y || a.forgeState != b.forgeState { same = false }
                cases += 1
            }
        } } }
        check("BH0 [executed] the forgeOffense refactor is behaviour-neutral for the gun: applyForgeOffense equals the pre-N4 function (verbatim reference) in value and in every side effect (Cold Fury / Killing Stroke consumed, Warpath idle reset, Relentless stacks) across all 512 Forge flag sets × bases 1/7/37 × health 20/95%, hit twice (\(cases) hits)", same)
    }
    // BH1 — the enemy parent: every factor exactly once, one rounding, no floor (statistical: fresh thresholds).
    do {
        let sc = HitScene(); let p = sc.playerStats
        p.riftlineActive = true; p.critMultiplier = 2.1; p.forgeLuckyBreak = true; p.slowedDamageBonus = 0.25; p.forgeOpportunist = true
        let e = BraceguardNode(); e.isSlowed = true; e.vulnerabilityMultiplier = 1.5; e.healthPercent = 0.5; e.arcBlocks = true
        let shot = ProjectileNode(direction: CGPoint(x: 1, y: 0))      // a fragment carrier: no Void affinity, so the shield applies
        let laneTick = BeamTick.laneTick(basis: 3, interval: 0.5 / 1.9)
        let crit = BeamTick.LaneCrit(isCrit: true, luckyBreak: true)
        let forge = 1.05                                               // Opportunist on a slowed (impaired) target
        let exact = laneTick * 0.75 * 2.1 * 1.5 * forge * 1.25 * 1.2 * 0.5   // rank 1, crit, Lucky, Forge, Permafrost, Overcharge 1.2, shield
        var basis = Stat(), dealt = Stat()
        for _ in 0..<200_000 {
            let h = sc.beamParentHit(laneTick: laneTick, hit: lane(1), crit: crit, overcharge: 1.2, projectileNode: shot, enemyNode: e)
            basis.add(h.basis, exact: exact); dealt.add(h.dealt, exact: exact * 1.5)
        }
        check("BH1 [executed, statistical] the beam's enemy parent: lane tick 0.75 × 3 × 1.9 = \(String(format: "%.4f", laneTick)) × Riftline rank 1 (0.75) × crit 2.1 × Lucky Break 1.5 × Forge 1.05 × Permafrost 1.25 × Overcharge 1.2 × Braceguard 0.5 = \(String(format: "%.4f", exact)) (× vulnerability 1.5 for dealt): every one of 200,000 samples is ⌊exact⌋ or ⌊exact⌋+1 and both means sit within 6σ (basis \(String(format: "%.4f", basis.mean)), dealt \(String(format: "%.4f", dealt.mean))); the shield flashed each hit",
              basis.bounded && dealt.bounded && basis.near(exact) && dealt.near(exact * 1.5) && e.flashes == 200_000,
              "basis \(basis.mean)±\(basis.sigma) dealt \(dealt.mean)±\(dealt.sigma) exact \(exact)")
    }
    // BH2 — zero and fractions survive: a small tick deals 0 most of the time (no min 1); a primary (Void affinity) ignores the shield.
    do {
        let sc = HitScene(); let e = EnemyNode()
        var zeros = 0, s = Stat()
        let tiny: CGFloat = 0.02
        for _ in 0..<100_000 { let h = sc.beamParentHit(laneTick: tiny, hit: lane(), crit: .none, overcharge: 1, projectileNode: ProjectileNode(direction: CGPoint(x: 1, y: 0)), enemyNode: e); s.add(h.dealt, exact: tiny); if h.dealt == 0 { zeros += 1 } }
        let zero = sc.beamParentHit(laneTick: 0, hit: lane(), crit: BeamTick.LaneCrit(isCrit: true, luckyBreak: true), overcharge: 1.5, projectileNode: ProjectileNode(direction: CGPoint(x: 1, y: 0)), enemyNode: e)
        let bg = BraceguardNode(); bg.arcBlocks = true
        let primary = ProjectileNode(direction: CGPoint(x: 1, y: 0)); primary.voidHit = .primaryShot(phaseT2: true)
        var ps = Stat()
        for _ in 0..<100_000 { ps.add(sc.beamParentHit(laneTick: 0.6, hit: lane(), crit: .none, overcharge: 1, projectileNode: primary, enemyNode: bg).dealt, exact: 0.6) }
        check("BH2 [executed, statistical] zero is preserved: a 0.02 tick deals 0 on \(zeros) of 100,000 hits (mean \(String(format: "%.4f", s.mean)) ≈ 0.02 — never floored to 1); a 0 prefix deals 0 even critical with Overcharge; a Void-affinity primary ignores the Braceguard shield (mean \(String(format: "%.3f", ps.mean)) ≈ 0.6)",
              zeros > 97_000 && s.bounded && s.near(tiny) && zero == DirectHit(basis: 0, dealt: 0) && ps.bounded && ps.near(0.6), "zeros \(zeros) mean \(s.mean) ps \(ps.mean)")
    }
    // BH3 — conservation through the share (N3's fractureBranch / fractureBranchOnBoss): n × (1/n) and k × (1/n) carry the parent's expectation, enemy and boss (DEF 3 dial on the parent, then the share).
    do {
        var worst = 0.0, report = "", ok = true
        for n in [3, 5, 9, 17] { for k in [1, n / 2 + 1] {
            let sc = HitScene(); sc.playerStats.critMultiplier = 2.1
            let e = EnemyNode(); e.vulnerabilityMultiplier = 1.5
            let boss = ArenaBossStub(health: 100_000, def: 3); boss.vulnerabilityMultiplier = 1.2
            let laneTick = BeamTick.laneTick(basis: 10, interval: 0.5 / 1.9 / 1.35)     // 19.24 — big enough for the dial to bite
            let crit = BeamTick.LaneCrit(isCrit: true, luckyBreak: false)
            let M = 60_000
            var whole = Stat(), part = Stat(), wholeB = Stat(), partB = Stat()
            for _ in 0..<M {
                let shot = ProjectileNode(direction: CGPoint(x: 1, y: 0), shareUnit: CGFloat.random(in: 0..<1))
                let parent = sc.beamParentHit(laneTick: laneTick, hit: lane(), crit: crit, overcharge: 1, projectileNode: shot, enemyNode: e)
                whole.add(parent.dealt, exact: CGFloat(parent.dealt))
                shot.fractureShare = CGFloat(k) / CGFloat(n)
                let b = sc.fractureBranch(parent, projectile: shot)
                part.add(b.dealt, exact: CGFloat(parent.dealt) * CGFloat(k) / CGFloat(n))
                let ps = ProjectileNode(direction: CGPoint(x: 1, y: 0), shareUnit: CGFloat.random(in: 0..<1))
                let pb = sc.beamParentHitBoss(laneTick: laneTick, hit: lane(), crit: crit, overcharge: 1, bossNode: boss)
                ps.fractureShare = 1
                let w = sc.fractureBranchOnBoss(pb, projectile: ps, boss: boss)
                let wf = w.ignoresChallengeDEF ? w.hit.dealt : boss.challengedDamage(w.hit.dealt, raw: w.hit.basis, ignoresChallengeDEF: false)
                wholeB.add(wf, exact: CGFloat(wf))
                ps.fractureShare = CGFloat(k) / CGFloat(n)
                let s = sc.fractureBranchOnBoss(pb, projectile: ps, boss: boss)
                let sf = s.ignoresChallengeDEF ? s.hit.dealt : boss.challengedDamage(s.hit.dealt, raw: s.hit.basis, ignoresChallengeDEF: false)
                partB.add(sf, exact: CGFloat(wf) * CGFloat(k) / CGFloat(n))
            }
            let scale = Double(n) / Double(k)
            let devE = abs(part.mean * scale - whole.mean) / whole.mean, devB = abs(partB.mean * scale - wholeB.mean) / wholeB.mean
            let tolE = 6 * (part.sigma * scale + whole.sigma) / whole.mean, tolB = 6 * (partB.sigma * scale + wholeB.sigma) / wholeB.mean
            if devE > tolE || devB > tolB || !part.bounded || !partB.bounded { ok = false }
            if max(devE, devB) > worst { worst = max(devE, devB); report = "n \(n) k \(k): enemy \(part.mean * scale) vs \(whole.mean); boss \(partB.mean * scale) vs \(wholeB.mean)" }
        } }
        check("BH3 [executed, statistical] conservation through the share for fans of 3 / 5 / 9 / 17 and a hit carrying k of n branches: (n ÷ k) × the share hit's mean equals the parent's (enemy: crit 2.1, vulnerability 1.5; boss: the DEF-3 dial on the PARENT, then the share, entering with the dial bypassed) within 6σ; every share hit is ⌊parent × k/n⌋ or +1 (no resurrection, no floor); worst relative deviation \(String(format: "%.2e", worst)) at \(report)",
              ok, report)
    }
}

// ── EX · Erasure T4's ordinary Echo on the chaos beam (v2.2 N4 Echo ruling, Oct 13) ──
// EchoScene runs `updateChaosBeam`, `beamLines`, `beamVolleyEffects`, `scheduleErasureEcho` and
// fireProjectile's modifier tail VERBATIM over the real PlayerStats / BeamClock / VolleyCounter /
// AttackPattern; the scene's action clock is a MODEL of SpriteKit (labeled), the target finder,
// wells, Shadow Edge, the tick and the edge sampler are stubs.
do {
    let dt: TimeInterval = 1.0 / 60.0
    func close(_ a: Double, _ b: Double, _ tol: Double) -> Bool { abs(a - b) <= tol }
    func apply(_ id: String, _ s: PlayerStats, upTo n: Int = 99) { for t in (AbilityBehaviors.registry.cards[id]?.tiers ?? []).prefix(n) { t(s) } }
    func makeScene(scatter: Bool = false, fracture: Bool = false, storm: Bool = false, echo: Bool = true) -> EchoScene {
        let sc = EchoScene()
        apply("neutral_3", sc.playerStats)                                   // Rapid Fire T1–T5: the beam
        if echo { apply("cap_void_erasure", sc.playerStats, upTo: 4) }      // Erasure T1–T4: the Echo
        if scatter { apply("neutral_6", sc.playerStats) }
        if fracture { apply("v18_fracture_shot", sc.playerStats) }
        if storm { AbilityBehaviors.registry.synergies["shock.7"]?(sc.playerStats) }
        return sc
    }
    let cfgSrc = (try? String(contentsOfFile: "Sparkforge/Config/GameConfig.swift", encoding: .utf8)) ?? ""
    check("EX0 the seam's mirrored constant is the source's (projectileTravelRadius 3); the Echo's own numbers are the real config (delay \(GameConfig.Erasure.echoDelay) s, fraction \(GameConfig.Erasure.echoFraction)); the beam is on (Rapid Fire T5) and Erasure T4 sets erasureEcho",
          cfgSrc.contains("static let projectileTravelRadius: CGFloat = 3") && GameConfig.Erasure.echoDelay == 1.5 && GameConfig.Erasure.echoFraction == 0.5
            && makeScene().playerStats.chaosBeamActive && makeScene().playerStats.erasureEcho && !makeScene(echo: false).playerStats.erasureEcho)

    // EX1 — cadence: one Echo per parent lane per VIRTUAL volley, at the live interval I; a speed change applies at once.
    do {
        let sc = makeScene()
        let i0 = sc.playerStats.effectiveFireInterval
        for _ in 0..<600 { sc.frame(dt) }                                   // 10 s at I = 0.5 / 1.9
        let v0 = sc.volleyCounter.volleys, s0 = sc.scheduled.count
        let gaps0 = zip(sc.scheduled.dropFirst(), sc.scheduled).map { $0.at - $1.at }
        apply("v17_overclock", sc.playerStats); sc.playerStats.triggerOverclock()   // +35% attack speed, live
        let i1 = sc.playerStats.effectiveFireInterval
        let mark = sc.scheduled.count
        for _ in 0..<120 { sc.frame(dt) }                                   // 2 s under Overclock (its timer is not ticked here)
        let after = Array(sc.scheduled[mark...])
        let gaps1 = zip(after.dropFirst(), after).map { $0.at - $1.at }
        check("EX1 [executed] cadence: 10 s of beam at I = \(String(format: "%.4f", i0)) s → \(v0) virtual volleys and exactly \(s0) Echo schedules (one per volley, one lane), every gap within one frame of I; Overclock (+35% speed) → from the next comparison the gaps track I = \(String(format: "%.4f", i1)) s (\(after.count) in 2 s; the first gap carries the seconds already banked, C1) — the Echo follows the virtual-volley cadence, never the 0.5 s tick",
              s0 == v0 && abs(Double(v0) - 10 / i0) <= 1 && gaps0.allSatisfy { close($0, i0, dt + 1e-9) }
                && close(i1, i0 / 1.35, 1e-12) && gaps1.count >= 2 && gaps1.dropFirst().allSatisfy { close($0, i1, dt + 1e-9) }
                // C1: the seconds banked before the change carry over (the first gap may be SHORTER, never longer)
                && (gaps1.first ?? 99) <= i1 + dt + 1e-9 && abs(Double(after.count) - 2 / i1) <= 1.5,
              "v0 \(v0) s0 \(s0) i0 \(i0) i1 \(i1) after \(after.count) dev0 \(gaps0.map { abs($0 - i0) }.max() ?? -1) dev1 \(gaps1.map { abs($0 - i1) }.max() ?? -1)")
    }
    // EX2 — delay and the ordinary secondary shot: 1.5 s later, the lane's heading SAMPLED AT SCHEDULING, the edge origin
    // sampled at firing, 50% damageScale, no modifiers (fragment credit by fireProjectile's rule), crit rolled as an ordinary shot.
    do {
        let sc = makeScene()
        var firstAt: TimeInterval = -1
        var steps = 0
        while sc.scheduled.isEmpty && steps < 200 { sc.frame(dt); steps += 1 }
        firstAt = sc.scheduled.first?.at ?? -1
        let headingThen = (CGPoint(x: 0, y: 300) - sc.player.position).normalized
        sc.target = CGPoint(x: 300, y: 0)                                    // the aim moves right after scheduling
        PlacementSampler.next = CGPoint(x: -850, y: 10)
        var guardSteps = 0
        while sc.fired.isEmpty && guardSteps < 200 { sc.frame(dt); guardSteps += 1 }
        let e = sc.fired.first
        check("EX2 [executed] the first Echo is scheduled at the first virtual volley (t \(String(format: "%.3f", firstAt))) and due exactly 1.5 s later; it fires on the frame it comes due as an ORDINARY secondary shot — heading sampled when scheduled (still up after the aim moved right), origin = the edge point sampled when it fires, damageScale 0.5, allowModifiers false (→ .fragment credit), rollsCrit true, share 1",
              sc.scheduled.allSatisfy { close($0.due - $0.at, 1.5, 1e-9) } && e != nil
                && close(e?.at ?? 0, firstAt + 1.5, dt + 1e-9) && ((e?.direction ?? .zero) - headingThen).length < 1e-12
                && (e?.originOffset ?? .zero) == CGPoint(x: -850, y: 10) - sc.player.position
                && e?.damageScale == GameConfig.Erasure.echoFraction && e?.allowModifiers == false && e?.source == nil && e?.rollsCrit == true && e?.fractureShare == 1,
              "\(String(describing: e))")
    }
    // EX3 — multiplicity: per PARENT lane; Storm's +2 lanes once each on its every-3rd volley; Fracture adds none.
    do {
        let sc = makeScene(scatter: true, fracture: true, storm: true)
        var perVolley: [Int] = []
        var lastV = 0, lastS = 0
        for _ in 0..<360 {                                                   // 6 s
            sc.frame(dt)
            if sc.volleyCounter.volleys != lastV { perVolley.append(sc.scheduled.count - lastS); lastV = sc.volleyCounter.volleys; lastS = sc.scheduled.count }
        }
        let pattern = perVolley.enumerated().allSatisfy { $0.element == (($0.offset + 1) % 3 == 0 ? 11 : 9) }
        let plain = makeScene(fracture: true); for _ in 0..<360 { plain.frame(dt) }
        check("EX3 [executed] Scatter T4 × Fracture T4 (153 beam lines) with Storm Engine: Echo schedules per virtual volley = \(perVolley.prefix(9))… — 9 parent lanes, 11 on every 3rd (Storm's +2 lanes once each); never 153 / 187 (branches) and never per contact (scheduling happens in the volley, before and without the tick); Fracture alone keeps ONE per volley (\(plain.scheduled.count) for \(plain.volleyCounter.volleys))",
              perVolley.count >= 6 && pattern && sc.scheduled.count == perVolley.reduce(0, +) && plain.scheduled.count == plain.volleyCounter.volleys,
              "\(perVolley)")
    }
    // EX4 — the basis is the existing secondary-shot basis (50% of a shot via damageScale), never the converted beam tick;
    // the beam's Echo and the gun's Echo produce the SAME ordinary call.
    do {
        let sc = makeScene()
        for _ in 0..<200 { sc.frame(dt) }
        let beamEcho = sc.fired.first
        let gun = makeScene(); gun.target = nil                             // nothing in reach: the beam stays out of this comparison
        gun.fireProjectile(direction: CGPoint(x: 0, y: 1))                  // the gun's primary through the extracted tail
        let gunScheduled = gun.scheduled.count
        for _ in 0..<95 { gun.frame(dt) }
        let gunEcho = gun.fired.last
        let stats = sc.playerStats; stats.damageMultiplier = 7.6
        let echoBase = OverchargeSplit(stats.overchargeParts(scale: beamEcho?.damageScale ?? 0)).base
        let laneTick = BeamTick.laneTick(basis: OverchargeSplit(stats.overchargeParts(scale: 1)).base, interval: stats.effectiveFireInterval)
        check("EX4 [executed] basis: the beam's Echo carries damageScale \(beamEcho?.damageScale ?? -1) = Erasure.echoFraction — the existing secondary-shot basis fireProjectile resolves through overchargeParts(scale: 0.5) (base \(echoBase) at ATK ×7.6), NOT the converted lane tick (\(String(format: "%.3f", laneTick))); the gun's primary schedules exactly one Echo through the same function and both Echo calls are identical apart from heading/time (scale, modifiers, credit, crit)",
              beamEcho?.damageScale == GameConfig.Erasure.echoFraction && gunScheduled == 1 && gunEcho != nil
                && gunEcho?.damageScale == beamEcho?.damageScale && gunEcho?.allowModifiers == false && gunEcho?.source == nil && gunEcho?.rollsCrit == beamEcho?.rollsCrit
                && echoBase == 3 && abs(laneTick - CGFloat(echoBase)) > 1,
              "beam \(String(describing: beamEcho)) gun \(String(describing: gunEcho))")
    }
    // EX5 — pause / resume, exactly as the ordinary Echo behaves today (no new rule):
    do {
        // (a) level-up for 1.0 s inside the 1.5 s wait, back to play before it is due → it fires on time; no volley (and so
        //     no new Echo) is scheduled while not playing, and the beam's clocks are frozen meanwhile.
        let a = makeScene()
        while a.scheduled.isEmpty && a.now < 5 { a.frame(dt) }          // bounded: a missing Echo fails, never hangs
        let t0 = a.scheduled.first?.at ?? -100, s0 = a.scheduled.count, v0 = a.volleyCounter.volleys, clock0 = a.beamClock.volleyClock.elapsed
        a.gameState = .levelUp
        for _ in 0..<60 { a.frame(dt) }
        let frozen = a.beamClock.volleyClock.elapsed == clock0 && a.volleyCounter.volleys == v0 && a.scheduled.count == s0
        a.gameState = .playing
        while a.fired.isEmpty && a.now < t0 + 3 { a.frame(dt) }
        let aOK = t0 >= 0 && frozen && close(a.fired.first?.at ?? 0, t0 + 1.5, dt + 1e-9)
        // (b) still in level-up when it comes due → DROPPED (the `.playing` guard), never fired later, nothing left pending.
        let b = makeScene()
        while b.scheduled.isEmpty && b.now < 5 { b.frame(dt) }          // bounded: a missing Echo fails, never hangs
        let tb = b.scheduled.first?.at ?? -100
        b.gameState = .levelUp
        while b.now < tb + 2.0 { b.frame(dt) }
        let droppedNow = b.fired.isEmpty && b.pendingCount == 0
        b.gameState = .playing; b.target = nil
        for _ in 0..<300 { b.frame(dt) }
        let bOK = tb >= 0 && droppedNow && b.fired.isEmpty
        // (c) the scene itself paused (app background) for 5 s inside the wait → the wait freezes; it fires 1.5 s of
        //     unpaused time after scheduling.
        let c = makeScene()
        while c.scheduled.isEmpty && c.now < 5 { c.frame(dt) }          // bounded: a missing Echo fails, never hangs
        let tc = c.scheduled.first?.at ?? -100
        for _ in 0..<30 { c.frame(dt) }                                      // 0.5 s
        c.isPaused = true; for _ in 0..<300 { c.frame(dt) }; c.isPaused = false
        c.target = nil
        while c.fired.isEmpty && c.now < tc + 3 { c.frame(dt) }
        let cOK = tc >= 0 && close(c.fired.first?.at ?? 0, tc + 1.5, dt + 1e-9)
        check("EX5 [executed; the action clock models SpriteKit] pause/resume = today's ordinary Echo: (a) a level-up inside the wait: the wait keeps running, the Echo fires at +1.5 s once play has resumed, and no volley/Echo is scheduled while not playing (the beam's clocks frozen); (b) still not playing when due → dropped, never fired later, nothing left pending; (c) the scene paused (background) → the wait freezes and it fires after 1.5 s of unpaused time",
              aOK && bOK && cOK, "a \(aOK) b \(bOK) c \(cOK)")
    }
    // EX6 — no recursion: an Echo is fired without modifiers, and fireProjectile's own tail never schedules from it.
    do {
        let sc = makeScene(scatter: true, storm: true)
        for _ in 0..<900 { sc.frame(dt) }                                    // 15 s
        let fromVolleys = sc.scheduled.count
        let echoesFired = sc.fired.count
        let allPlain = sc.fired.allSatisfy { !$0.allowModifiers && $0.damageScale == GameConfig.Erasure.echoFraction }
        // Drain: stop the beam (no target) and let every pending Echo fire; nothing new may be scheduled by them.
        sc.target = nil
        let before = sc.scheduled.count
        for _ in 0..<200 { sc.frame(dt) }
        let gun = makeScene(); gun.target = nil
        gun.fireProjectile(direction: CGPoint(x: 1, y: 0))
        for _ in 0..<400 { gun.frame(dt) }
        check("EX6 [executed] no recursion: over 15 s (\(fromVolleys) schedules, \(echoesFired) fired) every Echo is a plain shot (no modifiers, 50%), and once the beam stops the \(sc.fired.count - echoesFired) still-pending Echoes fire without scheduling any more; the gun's primary → exactly one Echo → none after it",
              allPlain && sc.scheduled.count == before && sc.fired.count > echoesFired && sc.fired.allSatisfy { !$0.allowModifiers }
                && gun.scheduled.count == 1 && gun.fired.count == 2 && gun.fired[1].allowModifiers == false,
              "scheduled \(sc.scheduled.count) before \(before) gun \(gun.scheduled.count)/\(gun.fired.count)")
    }
    // EX7 — negative controls: no Erasure T4 → no Echo (gun or beam); no target → no volley → no Echo (the clocks hold ready).
    do {
        let off = makeScene(scatter: true, storm: true, echo: false)
        for _ in 0..<600 { off.frame(dt) }
        off.fireProjectile(direction: CGPoint(x: 0, y: 1))
        let idle = makeScene(); idle.target = nil
        for _ in 0..<600 { idle.frame(dt) }
        check("EX7 [executed] controls: without Erasure T4 a 10 s Scatter + Storm beam (\(off.volleyCounter.volleys) volleys, \(off.wells) wells) and a gun primary schedule NO Echo; with nothing in reach for 10 s the beam takes no volley and schedules no Echo",
              off.volleyCounter.volleys > 0 && off.scheduled.isEmpty && idle.volleyCounter.volleys == 0 && idle.scheduled.isEmpty)
    }
}

// ── EXP · the Echo model's frame phase (N4-R1, independent review Oct 13) ──
// SpriteKit runs a scene's update BEFORE it evaluates actions (SKScene.h, the
// documented per-frame order: update → actions → didEvaluateActions → physics).
// An Echo whose wait comes due on a frame in which update-phase code leaves
// `.playing` must therefore meet the `.playing` guard AFTER that transition and
// be dropped. The transition is the TEST-ONLY `updateTransition` hook in the tick
// stub (a model of update-phase code; not a real XP pickup or modal callback).
do {
    let dt: TimeInterval = 1.0 / 60.0
    let sc = EchoScene()
    for tier in AbilityBehaviors.registry.cards["neutral_3"]?.tiers ?? [] { tier(sc.playerStats) }   // the REAL Rapid Fire T1–T5
    sc.playerStats.erasureEcho = true
    sc.fireProjectile(direction: CGPoint(x: 1, y: 0))           // one ordinary primary → its Echo due at 1.5 s
    sc.target = nil                                             // no beam: nothing ticks, nothing else is scheduled
    for _ in 0..<89 { sc.frame(dt) }                            // 89 normal 60 Hz frames: t ≈ 1.4833 s
    let beforeDeadline = sc.fired.count == 1 && sc.pendingDues.contains { abs($0 - 1.5) < 1e-6 } && sc.ticks == 0
    sc.target = CGPoint(x: 0, y: 300)
    sc.updateTransition = { sc.gameState = .levelUp }           // update-phase code leaves .playing on the deadline frame
    sc.frame(dt)                                                // frame 90: t ≈ 1.5 s — the Echo is due THIS frame
    let deadline = sc.ticks == 1 && sc.fired.count == 1 && sc.gameState == .levelUp
        && !sc.pendingDues.contains { abs($0 - 1.5) < 1e-6 }    // the due Echo is gone, not re-queued
    sc.updateTransition = nil
    sc.gameState = .playing; sc.target = nil
    var guardFrames = 0
    while sc.now < 2.9 && guardFrames < 200 { sc.frame(dt); guardFrames += 1 }   // bounded; before the frame-90 beam Echo's own 3.0 s due
    let permanent = sc.fired.count == 1
    check("EXP1 [executed; model] same-frame deadline: an ordinary gun Echo comes due on the frame in which update-phase code (the test-only hook in the tick stub) leaves .playing — with update modelled BEFORE action evaluation, the .playing guard drops it: one tick, exactly one recorded shot (the primary), the due Echo removed and never fired later",
          beforeDeadline && deadline && permanent,
          "before \(beforeDeadline) deadline \(deadline) (ticks \(sc.ticks) fired \(sc.fired.count)) permanent \(permanent)")
}

// ── CX · Chain Reaction (v2.2 N5, R6): the pure rules and the EXECUTED kill/burst seam ──
// ChainScene runs `onEnemyKilled`, `didFinishUpdate`, `drainChainReactions` and `chainReactionBurst`
// VERBATIM; the targets' damage entries and body are EnemyNode's real ones; rewards, death bursts,
// Iceburst/Seed/Dead Circuit, the XP orb, the Codex record and the progression counters are
// RECORDERS. Statistical checks are labeled (production draws each victim's threshold fresh).
do {
    func applyTiers(_ s: PlayerStats, _ n: Int) { for t in (AbilityBehaviors.registry.cards["v13_chain_reaction"]?.tiers ?? []).prefix(n) { t(s) } }
    func scene(tier: Int) -> ChainScene {
        ChainRecord.quench = 0; ChainRecord.coilworks = 0; ChainRecord.mirrorwound = 0; ChainRecord.progressionKills = 0; ChainRecord.codex = []
        let sc = ChainScene(); applyTiers(sc.playerStats, tier); return sc
    }
    @discardableResult func add(_ sc: ChainScene, _ x: CGFloat, _ y: CGFloat, hp: Int = 1, mini: Bool = false, vuln: CGFloat = 1) -> EnemyNode {
        let e = EnemyNode(health: hp, position: CGPoint(x: x, y: y)); e.isMiniBoss = mini; e.vulnerabilityMultiplier = vuln
        sc.enemies.append(e); return e
    }
    func close(_ a: Double, _ b: Double, _ tol: Double) -> Bool { abs(a - b) <= tol }
    /// A root dies the way production kills it: through its REAL damage body, then the chokepoint.
    func slay(_ sc: ChainScene, _ e: EnemyNode, _ source: KillSource) { e.takeDamage(max(1, e.health)); sc.kill(e, source: source) }
    let cfg = (try? String(contentsOfFile: "Sparkforge/Config/GameConfig.swift", encoding: .utf8)) ?? ""

    // CX0 — the ladder through the REAL registry effects, and the config.
    do {
        let s = PlayerStats()
        var rows: [String] = []
        for n in 1...3 { applyTiers(s, 0); let t = PlayerStats(); applyTiers(t, n); rows.append("\(t.chainReactionExplode)/\(t.chainReactionTier)/\(t.chainReactionDamage)/\(t.chainReactionRadius)") }
        let fourth = (AbilityBehaviors.registry.cards["v13_chain_reaction"]?.tiers.count ?? 0)
        applyTiers(s, 3); s.reset()
        check("CX0 the ladder through the real registry: T1 true/1/1/35, T2 true/2/2/50, T3 true/3/3/70 (\(rows)); exactly 3 tiers; reset → off / tier 0 / 1 / 35; GameConfig.Neutral bases [1,2,3], radii [35,50,70], escalation from T3 at +10% per generation capped at 10; the seam's Ashling delay mirrors the source",
              rows == ["true/1/1/35.0", "true/2/2/50.0", "true/3/3/70.0"] && fourth == 3
                && !s.chainReactionExplode && s.chainReactionTier == 0 && s.chainReactionDamage == 1 && s.chainReactionRadius == 35
                && N.chainReactionBases == [1, 2, 3] && N.chainReactionRadii == [35, 50, 70] && N.chainEscalationTier == 3
                && N.chainGenerationStep == 0.10 && N.chainGenerationCap == 10 && cfg.contains("static let shardSpawnDelay: TimeInterval = 0.15"))
    }
    // CX1 — the amount and the one rounding (pure).
    do {
        let ex = { (t: Int, g: Int, b: Bool) in ChainReaction.exactDamage(base: ChainReaction.base(tier: t), tier: t, generation: g, bossClass: b) }
        let ladder = [ex(3, 0, false), ex(3, 1, false), ex(3, 2, false), ex(3, 10, false), ex(3, 11, false), ex(3, 50, false)]
        let G = 10000
        func mean(_ exact: CGFloat, _ v: CGFloat) -> (Double, Double, Int) {
            var b = 0, d = 0, zeros = 0
            for i in 0..<G { let h = ChainReaction.hit(exact: exact, vulnerability: v, rounding: DirectHitRounding(unit: (CGFloat(i) + 0.5) / CGFloat(G))); b += h.basis; d += h.dealt; if h.dealt == 0 { zeros += 1 } }
            return (Double(b) / Double(G), Double(d) / Double(G), zeros)
        }
        let m33 = mean(3.3, 1), m36 = mean(3.6, 1), mHalf = mean(0.5, 1), mVuln = mean(3.3, 1.5), mZero = mean(0, 2)
        check("CX1 the amount: T3 generation 0/1/2/10/11/50 = 3, 3.3, 3.6, 6, 6, 6 (additive, capped); T1/T2 never escalate (generation 5 → 1, 2); a mini-boss takes half (T1 0.5, T3 g1 1.65). The one rounding on a 10,000-point threshold grid: 3.3 → mean 3.3, 3.6 → 3.6, 0.5 → 0.5 with half the hits zero, 3.3 under ×1.5 vulnerability → basis 3.3 / dealt 4.95 on the same threshold; 0 stays 0 (never a free 1)",
              zip(ladder, [3, 3.3, 3.6, 6, 6, 6] as [CGFloat]).allSatisfy { abs($0 - $1) < 1e-12 } && ex(1, 5, false) == 1 && ex(2, 5, false) == 2
                && ex(1, 0, true) == 0.5 && abs(ex(3, 1, true) - 1.65) < 1e-12
                && close(m33.0, 3.3, 1e-4) && close(m36.0, 3.6, 1e-4) && close(mHalf.1, 0.5, 1e-4) && mHalf.2 == G / 2
                && close(mVuln.0, 3.3, 1e-4) && close(mVuln.1, 4.95, 1e-4) && mZero.0 == 0 && mZero.1 == 0,
              "\(ladder) \(m33) \(m36) \(mHalf) \(mVuln) \(mZero)")
    }
    // CX2 — multi-hop ancestry through the real seam: a line of chain enemies 60 pt apart (T3 radius 70), a probe
    // 65 pt beside each that ONLY that link's burst reaches. Probe k's damage is generation k's amount.
    do {
        let runs = 3000
        var sums = [Double](repeating: 0, count: 5)
        var bounded = true, creditOK = true, rootOK = true, firstBad = ""
        for _ in 0..<runs {
            let sc = scene(tier: 3)
            var links: [EnemyNode] = [], probes: [EnemyNode] = []
            for k in 0..<5 { links.append(add(sc, CGFloat(60 * k), 0)); probes.append(add(sc, CGFloat(60 * k), 65, hp: 1_000_000)) }
            slay(sc, links[0], .primary)                           // a full-credit root (generation 0)
            sc.didFinishUpdate()
            for k in 0..<5 {
                let dealt = 1_000_000 - probes[k].health
                let exact = 3 * (1 + 0.1 * Double(k))
                if dealt != Int(exact) && dealt != Int(exact) + 1 { bounded = false }
                sums[k] += Double(dealt)
            }
            let thisOK = links.allSatisfy { $0.killCredited && $0.isDying } && sc.orbs.count == 5 && ChainRecord.codex.count == 5
                && sc.pendingBursts == 0 && probes.allSatisfy { !$0.isDying }
            if !thisOK && firstBad.isEmpty { firstBad = "links \(links.map { $0.killCredited }) orbs \(sc.orbs.count) codex \(ChainRecord.codex.count) pending \(sc.pendingBursts)" }
            creditOK = creditOK && thisOK
            rootOK = rootOK && sc.rewards.count == 1 && sc.deathBursts.count == 1 && sc.killCount == 1 && ChainRecord.progressionKills == 1
                && sc.delayed == 1 && sc.wellFeeds == 1
        }
        let means = sums.map { $0 / Double(runs) }
        check("CX2 [executed, statistical] multi-hop: one full-credit root on a 5-link line at T3 → every link dies, each credited once (5 XP orbs, 5 Codex/bestiary records), the queue drains empty; probe k (reached ONLY by link k's burst) takes generation k's amount: means \(means.map { String(format: "%.3f", $0) }) ≈ 3.0 / 3.3 / 3.6 / 3.9 / 4.2, every sample ⌊exact⌋ or ⌊exact⌋+1; ONLY the root pays full credit (one reward set, one death-burst set, one kill count, one progression kill, one Dead Circuit feed, one delayed orb)",
              bounded && creditOK && rootOK && zip(means, [3.0, 3.3, 3.6, 3.9, 4.2]).allSatisfy { close($0, $1, 0.05) },
              "means \(means) bounded \(bounded) credit \(creditOK) root \(rootOK) \(firstBad)")
    }
    // CX3 — competing roots, first lethal hit wins, duplicates and an already-dying body (T1: integer 1, deterministic).
    do {
        let sc = scene(tier: 1)
        let a = add(sc, 0, 0), b = add(sc, 40, 0), v = add(sc, 20, 0)          // V is inside BOTH roots' 35 pt
        let probe = add(sc, 20, 30, hp: 1000)                                  // 36 pt from A and B, 30 from V: V's burst only
        let dying = add(sc, -20, 0, hp: 1); dying.takeDamage(5)                // died uncredited (a discarded result)
        let dyingFlashes = dying.hitFlashes
        slay(sc, a, .primary); slay(sc, b, .fragment)
        let pendingBeforeDrain = sc.pendingBursts, vHealthBeforeDrain = v.health
        sc.didFinishUpdate()
        let afterFirst = (orbs: sc.orbs.count, codex: ChainRecord.codex.count, probe: probe.health)
        sc.kill(v, source: .sweep); sc.kill(v, source: .chainReaction)        // duplicate callbacks
        sc.didFinishUpdate()
        let dupOK = sc.orbs.count == afterFirst.orbs && ChainRecord.codex.count == afterFirst.codex && probe.health == afterFirst.probe
        slay(sc, dying, .sweep); sc.didFinishUpdate()                 // the frame-top sweep credits it → its own burst
        check("CX3 [executed] two roots killed in one frame both reach V: their bursts are QUEUED (2 pending, V untouched until the frame's drain), A's burst (first in FIFO) kills V, B's finds V dying and skips it; V is credited ONCE (3 orbs, 3 Codex records: A, B, V) and bursts ONCE (its probe took exactly 1); a second and third kill callback for V pay and queue nothing; an already-dying uncredited body is never hit (no flash) and bursts only when the sweep credits it",
              pendingBeforeDrain == 2 && vHealthBeforeDrain == 1 && v.killCredited && afterFirst.orbs == 3 && afterFirst.codex == 3 && afterFirst.probe == 999
                && dupOK && dying.hitFlashes == dyingFlashes && probe.health == 999 && sc.orbs.count == 4 && sc.pendingBursts == 0,
              "pending \(pendingBeforeDrain) orbs \(afterFirst.orbs) codex \(afterFirst.codex) probe \(probe.health) dup \(dupOK)")
    }
    // CX4 — branching: one burst kills three siblings; each sibling's burst carries the SAME next generation.
    do {
        let runs = 3000
        var sums = [Double](repeating: 0, count: 3)
        var allDie = true
        for _ in 0..<runs {
            let sc = scene(tier: 3)
            let root = add(sc, 0, 0)
            var probes: [EnemyNode] = []
            for k in 0..<3 {
                let ang = CGFloat(k) * 2 * .pi / 3
                let s = add(sc, 50 * cos(ang), 50 * sin(ang))
                probes.append(add(sc, 115 * cos(ang), 115 * sin(ang), hp: 1_000_000))   // 65 pt beyond its sibling; >70 from the root and the others
                _ = s
            }
            slay(sc, root, .primary); sc.didFinishUpdate()
            allDie = allDie && sc.orbs.count == 4
            for k in 0..<3 { sums[k] += Double(1_000_000 - probes[k].health) }
        }
        let means = sums.map { $0 / Double(runs) }
        check("CX4 [executed, statistical] branching: a root's burst kills three siblings at once; each sibling's own burst deals generation 1's amount (probe means \(means.map { String(format: "%.3f", $0) }) ≈ 3.3 each) — siblings share the next generation",
              allDie && means.allSatisfy { close($0, 3.3, 0.05) }, "\(means)")
    }
    // CX5 — mini-boss half, the vulnerability folded in ONCE, zero preserved, Whiteout's melt only on a real hit.
    do {
        let runs = 4000
        var mini = 0.0, miniZeros = 0, vulnSum = 0.0, flashOK = true
        var snowStays = 0, snowMelts = 0
        for _ in 0..<runs {
            let sc = scene(tier: 1)
            let root = add(sc, 0, 0)
            let m = add(sc, 10, 0, hp: 1000, mini: true)
            let flashes0 = m.hitFlashes
            slay(sc, root, .primary); sc.didFinishUpdate()
            let d = 1000 - m.health; mini += Double(d); if d == 0 { miniZeros += 1; if m.hitFlashes != flashes0 { flashOK = false } }
            if m.snowman.isSnowman { snowStays += 0 }
            let sv = scene(tier: 3)
            let r2 = add(sv, 0, 0); let vic = add(sv, 10, 0, hp: 1000, vuln: 1.5)
            slay(sv, r2, .primary); sv.didFinishUpdate()
            vulnSum += Double(1000 - vic.health)
            // a mini-boss snowman: a zero hit leaves it a snowman; a real hit melts it (its elite extra lands too)
            let ss = scene(tier: 1)
            let r3 = add(ss, 0, 0); let sm = add(ss, 10, 0, hp: 1000, mini: true)
            _ = sm.snowman.begin(duration: 5, cooldown: 5, meltsOnDamage: true, isBossClass: true, bossClassScale: 0.5)
            slay(ss, r3, .primary); ss.didFinishUpdate()
            if sm.health == 1000 { if sm.snowman.isSnowman { snowStays += 1 } } else if !sm.snowman.isSnowman { snowMelts += 1 }
        }
        let mm = mini / Double(runs), vm = vulnSum / Double(runs)
        check("CX5 [executed, statistical] a mini-boss takes half (T1: mean \(String(format: "%.3f", mm)) ≈ 0.5; \(miniZeros) of \(runs) zero hits — no flash, nothing resurrected); a ×1.5-vulnerable normal at T3 g0 loses mean \(String(format: "%.3f", vm)) ≈ 4.5 (the vulnerability ONCE, inside the one rounding — not 6.75); a mini-boss snowman stays a snowman on every zero hit (\(snowStays)) and melts on every real one (\(snowMelts))",
              close(mm, 0.5, 0.03) && miniZeros > runs * 4 / 10 && miniZeros < runs * 6 / 10 && flashOK && close(vm, 4.5, 0.05)
                && snowStays + snowMelts == runs && snowStays > 0 && snowMelts > 0,
              "mini \(mm) zeros \(miniZeros) vuln \(vm) snow \(snowStays)/\(snowMelts)")
    }
    // CX6 — geometry: the strict boundary, a distinct body ON the death position, the emitter excluded by identity.
    do {
        let sc = scene(tier: 1)
        let root = add(sc, 0, 0)
        let onEdge = add(sc, 35, 0, hp: 10), inside = add(sc, 34.999, 0.001, hp: 10)
        let coincident = add(sc, 0, 0, hp: 10)
        slay(sc, root, .primary); sc.didFinishUpdate()
        check("CX6 [executed] geometry: a centre exactly ON the 35 pt radius is not hit (strict, today's boundary); just inside is; a DISTINCT enemy standing exactly on the death position IS hit (the emitter is excluded by identity, not by position — the legacy position test is gone); the emitter itself is never hit",
              onEdge.health == 10 && inside.health == 9 && coincident.health == 9 && root.hitFlashes == 0)
    }
    // CX7 — stress and bounds: 60 bodies in one cluster, and a 300-link line; every hit lands, the visual alone is capped.
    do {
        let sc = scene(tier: 3)
        var cluster: [EnemyNode] = []
        for i in 0..<60 { let a = CGFloat(i) * 0.7; cluster.append(add(sc, 12 * cos(a), 12 * sin(a))) }
        let root = add(sc, 0, 0)
        let t0 = Date()
        slay(sc, root, .primary); sc.didFinishUpdate()
        let ms = Date().timeIntervalSince(t0) * 1000
        let clusterCodex = ChainRecord.codex.count                     // read BEFORE the next scene resets the recorder
        let line = scene(tier: 1)
        var links: [EnemyNode] = []
        for k in 0..<300 { links.append(add(line, CGFloat(30 * k), 0)) }
        slay(line, links[0], .primary); line.didFinishUpdate()
        check("CX7 [executed] stress: a root in a 60-body cluster → all 60 die, each credited ONCE (61 orbs, 61 Codex records), the queue drains empty, \(sc.worldNode.rings) rings drawn (the per-drain VISUAL cap of \(N.chainReactionRingsPerDrain); every one of the 61 bursts still hit) in \(String(format: "%.1f", ms)) ms; a 300-link line resolves fully in one iterative drain (300 credited, nothing pending)",
              cluster.allSatisfy { $0.killCredited } && sc.orbs.count == 61 && clusterCodex == 61 && sc.pendingBursts == 0
                && sc.worldNode.rings == N.chainReactionRingsPerDrain && links.allSatisfy { $0.killCredited } && line.orbs.count == 300 && line.pendingBursts == 0,
              "orbs \(sc.orbs.count) rings \(sc.worldNode.rings) line \(line.orbs.count)")
    }
    // CX9 — FIFO decides ancestry: a root (generation 0) killed BEFORE a generation-5 chain victim in the same frame
    // reaches V first, so V is generation 1 (3.3 at T3), not 6 (4.8); in the opposite death order V is generation 6.
    do {
        let runs = 3000
        var aFirst = 0.0, bFirst = 0.0
        for order in 0..<2 { for _ in 0..<runs {
            let sc = scene(tier: 3)
            let a = add(sc, 0, 0), b = add(sc, 40, 0), v = add(sc, 20, 0)
            let probe = add(sc, 20, 69.5, hp: 1_000_000)                      // 72.3 pt from A and B, 69.5 from V: V's burst only (T3 radius 70)
            func killA() { slay(sc, a, .primary) }
            func killB() { b.takeDamage(1); sc.onEnemyKilled(at: b.position, xpValue: 1, enemy: b, source: .chainReaction, chainGeneration: 5) }
            if order == 0 { killA(); killB() } else { killB(); killA() }
            sc.didFinishUpdate()
            let d = Double(1_000_000 - probe.health)
            if order == 0 { aFirst += d } else { bFirst += d }
            _ = v
        } }
        let mA = aFirst / Double(runs), mB = bFirst / Double(runs)
        check("CX9 [executed, statistical] FIFO decides ancestry: when the root dies first its burst (generation 0) kills V, whose own burst is generation 1 (probe mean \(String(format: "%.3f", mA)) ≈ 3.3); when a generation-5 chain victim dies first ITS burst kills V, whose burst is generation 6 (mean \(String(format: "%.3f", mB)) ≈ 4.8) — the queue is first-in, first-out, deterministic in death order",
              close(mA, 3.3, 0.05) && close(mB, 4.8, 0.05), "\(mA) \(mB)")
    }
    // CX10 — N5-R1 (independent review, Oct 14): Whiteout's melt on a positive blast whose pre-vulnerability basis is 0.
    // REAL mini-boss half (ChainReaction.exactDamage), REAL Fracture vulnerability on a boss-class body
    // (BossClass.scaledDebuff(Erasure.fractureVulnerability) = 1.2), REAL SnowmanState, and EnemyNode's extracted damage body.
    let fractureVuln = GameConfig.BossClass.scaledDebuff(GameConfig.Erasure.fractureVulnerability, isBossClass: true)
    let halfT1 = ChainReaction.exactDamage(base: 1, tier: 1, generation: 0, bossClass: true)
    do {
        func strike(_ unit: CGFloat) -> (raw: DirectHit, sent: DirectHit, health: Int, snow: Bool, flashes: Int, after: Int, snowAfter: Bool) {
            let t = EnemyNode(health: 1000); t.isMiniBoss = true; t.vulnerabilityMultiplier = fractureVuln
            _ = t.snowman.begin(duration: 5, cooldown: 5, meltsOnDamage: true, isBossClass: true, bossClassScale: 0.5)
            let raw = ChainReaction.hit(exact: halfT1, vulnerability: fractureVuln, rounding: DirectHitRounding(unit: unit))
            let sent = ChainReaction.entry(raw)
            if sent.basis > 0 || sent.dealt > 0 { t.takeDirectHit(sent) }        // the scene's own zero-skip rule
            let (h, sn, fl) = (t.health, t.snowman.isSnowman, t.hitFlashes)
            if sent.dealt > 0 { t.takeDirectHit(sent) }                           // a second blast: no second melt
            return (raw, sent, h, sn, fl, t.health, t.snowman.isSnowman)
        }
        let posBasis = strike(0.25), zeroBasis = strike(0.55), trueZero = strike(0.75)
        // the elite melt's extra = max(1, Int(1000 × 0.2)) = 200 through the plain entry at ×1.2 → 240; plus the blast's 1.
        check("CX10 [executed: real target chain] N5-R1 — a mini-boss snowman under real Fracture (×\(fractureVuln)) takes T1's half blast (exact \(halfT1)): threshold 0.25 resolves basis 1 / dealt 1 and melts (HP 1000 → 759); threshold 0.55 resolves basis 0 / dealt 1 — delivered as basis 1 / dealt 1 by the entry contract — and ALSO melts once (759; the defect left it at 999, still a snowman); threshold 0.75 is a true zero (0 / 0): no hit, no flash, no melt, HP 1000. A second blast on a melted body costs only its 1 (758), never a second melt",
              posBasis.raw == DirectHit(basis: 1, dealt: 1) && posBasis.health == 759 && !posBasis.snow && posBasis.after == 758 && !posBasis.snowAfter
                && zeroBasis.raw == DirectHit(basis: 0, dealt: 1) && zeroBasis.sent == DirectHit(basis: 1, dealt: 1) && zeroBasis.health == 759 && !zeroBasis.snow && zeroBasis.after == 758
                && trueZero.raw == DirectHit(basis: 0, dealt: 0) && trueZero.sent == trueZero.raw && trueZero.health == 1000 && trueZero.snow && trueZero.flashes == 0
                && abs(fractureVuln - 1.2) < 1e-12 && halfT1 == 0.5,
              "pos \(posBasis) zeroBasis \(zeroBasis) zero \(trueZero)")
        // The entry contract never moves the budget: over a 10,000-point grid the delivered dealt is the resolved dealt.
        let G = 10000
        var rawSum = 0, sentSum = 0, zeros = 0, raised = 0, bad = false
        for i in 0..<G {
            let raw = ChainReaction.hit(exact: halfT1, vulnerability: fractureVuln, rounding: DirectHitRounding(unit: (CGFloat(i) + 0.5) / CGFloat(G)))
            let sent = ChainReaction.entry(raw)
            rawSum += raw.dealt; sentSum += sent.dealt
            if sent.dealt == 0 { zeros += 1; if sent.basis != 0 { bad = true } }
            if sent.basis != raw.basis { raised += 1; if !(raw.basis == 0 && sent.basis == 1 && raw.dealt > 0) { bad = true } }
        }
        check("CX10b [pure] the entry contract changes ONLY the melt basis: the delivered dealt equals the resolved dealt on every one of 10,000 thresholds (mean \(Double(sentSum) / Double(G)) = 0.6 = 0.5 × 1.2), zero hits stay 0 / 0 (\(zeros)), and the basis is raised 0 → 1 only where the resolved dealt is positive (\(raised) thresholds, ≈ 10%)",
              !bad && rawSum == sentSum && abs(Double(sentSum) / Double(G) - 0.6) < 1e-4 && zeros == 4000 && raised == 1000, "raw \(rawSum) sent \(sentSum) zeros \(zeros) raised \(raised)")
    }
    // CX11 — N5-R1 through the REAL burst seam (fresh per-victim thresholds): every outcome is either a melt-once or a true zero.
    do {
        let runs = 4000
        var melted = 0, untouched = 0, other: [String] = []
        for _ in 0..<runs {
            let sc = scene(tier: 1)
            let root = add(sc, 0, 0)
            let m = add(sc, 10, 0, hp: 1000, mini: true, vuln: fractureVuln)
            _ = m.snowman.begin(duration: 5, cooldown: 5, meltsOnDamage: true, isBossClass: true, bossClassScale: 0.5)
            slay(sc, root, .primary); sc.didFinishUpdate()
            if m.health == 759 && !m.snowman.isSnowman { melted += 1 }
            else if m.health == 1000 && m.snowman.isSnowman && m.hitFlashes == 0 { untouched += 1 }
            else if other.count < 3 { other.append("hp \(m.health) snowman \(m.snowman.isSnowman)") }
        }
        check("CX11 [executed, statistical] N5-R1 through the real burst: \(runs) T1 blasts on a mini-boss snowman under real Fracture — every one either melts it exactly once (HP 759: \(melted), ≈ 60% = 0.6 expected damage) or is a true zero (HP 1000, still a snowman, no flash: \(untouched)); NEVER the defect's damaged-but-unmelted body (HP 999, snowman)",
              melted + untouched == runs && other.isEmpty && abs(Double(melted) / Double(runs) - 0.6) < 0.03, "\(other)")
    }
    // CX8 — cascade eligibility is separate from credit: reward-only roots burst; chain victims are reward-RECORDED only.
    do {
        var ok = true, detail = ""
        for src in [KillSource.burst, .sweep, .statusTick, .summon] {
            let sc = scene(tier: 1)
            let root = add(sc, 0, 0); let v = add(sc, 20, 0)
            slay(sc, root, src); sc.didFinishUpdate()
            let full = src.credit == .full
            let good = v.killCredited && sc.orbs.count == 2 && ChainRecord.codex.count == (full ? 2 : 1)
                && sc.rewards.count == (full ? 1 : 0) && sc.killCount == (full ? 1 : 0) && sc.iceburstCalls == 0 && sc.seedCalls == 0
            if !good { ok = false; detail += "\(src) " }
        }
        let off = scene(tier: 0)
        let r = add(off, 0, 0); let v = add(off, 20, 0)
        slay(off, r, .primary); off.didFinishUpdate()
        check("CX8 [executed] cascade eligibility ≠ credit: roots killed by .burst / .sweep (XP-only) and .statusTick / .summon (full) ALL burst and kill their neighbour; the victim is paid an XP orb + one Codex/bestiary record and nothing else (no reward set, kill count, Iceburst or Seed); KillSource.chainReaction alone is .rewardRecorded, .burst/.sweep stay .rewardOnly and every other source stays .full; without the card nothing is queued",
              ok && KillSource.allCases.filter { $0.credit == .rewardRecorded } == [.chainReaction]
                && Set(KillSource.allCases.filter { $0.credit == .rewardOnly }) == [.burst, .sweep]
                && KillSource.allCases.filter { $0.credit == .full }.count == KillSource.allCases.count - 3
                && off.pendingBursts == 0 && !v.isDying, detail)
    }
}

// ── WX · Whiteout × Fracture share / beam (Oct 14, owner-approved bounded correction) ──
// The REAL gun chain (resolveGunHit: block → shield → fractureBranch → `damage = hit.basis`), the REAL beam parent
// (beamParentHit) and the two REAL final enemy entries (deliverGunHit / deliverBeamHit, extracted verbatim) over
// EnemyNode's extracted damage body, real SnowmanState and real config. Node visuals / onDeath are modelled.
do {
    let fracVuln = GameConfig.BossClass.scaledDebuff(GameConfig.Erasure.fractureVulnerability, isBossClass: true)   // 1.2 on boss-class
    let normalVuln = GameConfig.BossClass.scaledDebuff(GameConfig.Erasure.fractureVulnerability, isBossClass: false) // 1.4 on a normal
    func snowTarget(mini: Bool, vuln: CGFloat, hp: Int = 1000) -> EnemyNode {
        let t = EnemyNode(health: hp); t.isMiniBoss = mini; t.vulnerabilityMultiplier = vuln
        _ = t.snowman.begin(duration: 5, cooldown: 5, meltsOnDamage: true, isBossClass: mini, bossClassScale: 0.5)
        return t
    }
    func shot(_ base: CGFloat, share: CGFloat, h: CGFloat, v: CGFloat) -> ProjectileNode {
        let p = ProjectileNode(direction: CGPoint(x: 1, y: 0), damageMultiplier: base, unit: 0.5, hitUnit: h, shareUnit: v)
        p.fractureShare = share; return p
    }
    // WX1 — the reviewer's Fracture counterexample and its companions, through the real gun chain and delivery.
    do {
        let sc = HitScene()
        struct Case { let label: String; let share: CGFloat; let v: CGFloat; let resolved: DirectHit; let hp: Int; let snow: Bool }
        // parent: base 2 at block threshold 0.1 on ×1.2 → basis 2 / dealt 3 (the reviewer's parent).
        let cases = [Case(label: "T1 1/3, share threshold 0.8 (the counterexample)", share: 1.0 / 3.0, v: 0.8, resolved: DirectHit(basis: 0, dealt: 1), hp: 759, snow: false),
                     Case(label: "T2 1/5, 0.3 (positive basis)", share: 0.2, v: 0.3, resolved: DirectHit(basis: 1, dealt: 1), hp: 759, snow: false),
                     Case(label: "T2 1/5, 0.5 (zero basis, positive dealt)", share: 0.2, v: 0.5, resolved: DirectHit(basis: 0, dealt: 1), hp: 759, snow: false),
                     Case(label: "T2 1/5, 0.8 (true zero)", share: 0.2, v: 0.8, resolved: DirectHit(basis: 0, dealt: 0), hp: 1000, snow: true)]
        var ok = true, detail = ""
        for c in cases {
            let t = snowTarget(mini: true, vuln: fracVuln)
            let p = shot(2, share: c.share, h: 0.1, v: c.v)
            let hit = sc.resolveGunHit(projectileNode: p, enemyNode: t, braceguardShielded: false)   // the riders read hit.basis from here
            _ = sc.deliverGunHit(hit, enemyNode: t)
            let afterFirst = (t.health, t.snowman.isSnowman)
            if hit.dealt > 0 { _ = sc.deliverGunHit(hit, enemyNode: t) }                              // a second branch: never a second melt
            let good = hit == c.resolved && afterFirst.0 == c.hp && afterFirst.1 == c.snow && (hit.dealt == 0 || t.health == c.hp - hit.dealt)
            if !good { ok = false; detail += "[\(c.label): resolved \(hit) hp \(afterFirst.0) snow \(afterFirst.1) after2 \(t.health)] " }
        }
        // A NORMAL snowman (×1.4 real Fracture) on a zero-basis / positive branch dies outright — killed reported once.
        let n = snowTarget(mini: false, vuln: normalVuln, hp: 50)
        let nh = sc.resolveGunHit(projectileNode: shot(2, share: 0.2, h: 0.1, v: 0.5), enemyNode: n, braceguardShielded: false)
        let k1 = sc.deliverGunHit(nh, enemyNode: n), k2 = sc.deliverGunHit(nh, enemyNode: n)
        let normalOK = nh.basis == 0 && nh.dealt == 1 && k1 && !k2 && n.isDying && n.health == 0
        check("WX1 [executed: real gun chain + real final entry] Fracture branches on a mini-boss snowman under real Fracture (×\(fracVuln)), parent basis 2 / dealt 3: the RESOLVED branch (the riders' basis) is exactly what the share made — T1 1/3 @0.8 → 0/1 (the counterexample), T2 1/5 @0.3 → 1/1, @0.5 → 0/1, @0.8 → 0/0 — and every positive branch melts the snowman ONCE (HP 1000 → 759 = 1 + the elite 200 × 1.2), a second branch costs only its dealt, the true zero leaves HP 1000 and the snowman; a NORMAL snowman (×\(normalVuln)) on a 0/1 branch dies outright, killed reported once",
              ok && normalOK, detail + " normal \(nh) \(k1) \(k2) \(n.health)")
    }
    // WX3 — the entry rule changes ONLY the melt basis: a deterministic grid over the real gun chain, every Fracture fan.
    do {
        let sc = HitScene()
        var cells = 0, raised = 0, bad = 0, sumResolved = 0, sumDelivered = 0, zerosKept = 0
        for n in [3, 5, 9, 17] { for base: CGFloat in [1, 2, 3] { for hi in 0..<10 { for vi in 0..<(n * 10) {
            let t = EnemyNode(health: 1000); t.isMiniBoss = true; t.vulnerabilityMultiplier = fracVuln
            let p = shot(base, share: 1 / CGFloat(n), h: (CGFloat(hi) + 0.5) / 10, v: (CGFloat(vi) + 0.5) / CGFloat(n * 10))
            let resolved = sc.resolveGunHit(projectileNode: p, enemyNode: t, braceguardShielded: false)
            let delivered = resolved.targetEntry
            cells += 1; sumResolved += resolved.dealt; sumDelivered += delivered.dealt
            if delivered.dealt != resolved.dealt { bad += 1 }
            if resolved.dealt == 0 { if delivered != DirectHit(basis: 0, dealt: 0) { bad += 1 } else { zerosKept += 1 } }
            else if resolved.basis == 0 { if delivered.basis == 1 { raised += 1 } else { bad += 1 } }
            else if delivered != resolved { bad += 1 }
        } } } }
        check("WX3 [executed: real gun chain, deterministic grid] over \(cells) (fan 3 / 5 / 9 / 17 × parent 1 / 2 / 3 × block × share thresholds) on ×\(fracVuln): the delivered dealt equals the resolved dealt in EVERY cell (sum \(sumDelivered) = \(sumResolved)); every true zero stays 0 / 0 (\(zerosKept)); the basis is raised 0 → 1 only where dealt is positive (\(raised) cells); every other hit is delivered unchanged — the resolved hit (the riders' basis) is never touched",
              bad == 0 && sumDelivered == sumResolved && raised > 0 && zerosKept > 0, "bad \(bad)")
    }
    // WX2 — the reviewer's beam counterexample: all five REAL Rapid Fire tiers, base 1, Riftline rank 3 → a sub-1 prefix.
    do {
        let sc = HitScene()
        for t in AbilityBehaviors.registry.cards["neutral_3"]?.tiers ?? [] { t(sc.playerStats) }
        sc.playerStats.riftlineActive = true
        let I = sc.playerStats.effectiveFireInterval
        let tick = BeamTick.laneTick(basis: 1, interval: I)
        let lane = BeamTick.LaneHit(lane: 0, target: 0, branches: 1, fanSize: 1, centre: true, rank: 3)
        let runs = 10000
        var melted = 0, untouched = 0, zeroBasisPositive = 0, missing = 0, other = 0, dealtSum = 0
        for _ in 0..<runs {
            let t = snowTarget(mini: true, vuln: fracVuln)
            let shotNode = ProjectileNode(direction: CGPoint(x: 1, y: 0))
            let parent = sc.beamParentHit(laneTick: tick, hit: lane, crit: .none, overcharge: 1, projectileNode: shotNode, enemyNode: t)
            let branch = sc.fractureBranch(parent, projectile: shotNode)                                // share 1: the identity
            dealtSum += branch.dealt
            if branch.basis == 0 && branch.dealt > 0 { zeroBasisPositive += 1 }
            _ = sc.deliverBeamHit(branch, enemyNode: t)
            if t.health == 999 && t.snowman.isSnowman { missing += 1 }
            else if t.health == 1000 - branch.dealt - 240 && !t.snowman.isSnowman && branch.dealt > 0 { melted += 1 }
            else if t.health == 1000 && t.snowman.isSnowman && branch.dealt == 0 { untouched += 1 }
            else { other += 1 }
        }
        let exact = tick * pow(GameConfig.VoidTree.riftlineFalloff, 3)
        check("WX2 [executed: real beam parent + real final entry, statistical — production thresholds] five real Rapid Fire tiers (I \(String(format: "%.5f", I)), tick \(String(format: "%.4f", tick))), Riftline rank 3 → exact \(String(format: "%.4f", exact)) on a mini-boss snowman under real Fracture: of \(runs) hits \(zeroBasisPositive) resolve basis 0 / positive dealt; NONE leaves a damaged, unmelted snowman (missing melts \(missing)); every positive hit melts once (\(melted)), every true zero leaves it whole (\(untouched)); mean dealt \(String(format: "%.4f", Double(dealtSum) / Double(runs))) ≈ exact × 1.2 = \(String(format: "%.4f", exact * 1.2))",
              missing == 0 && other == 0 && melted + untouched == runs && zeroBasisPositive > runs / 20
                && abs(Double(dealtSum) / Double(runs) - Double(exact * 1.2)) < 0.02, "missing \(missing) other \(other) melted \(melted) untouched \(untouched)")
    }
}

// A7-2: execute the new handoffs through the real kill/frame seams. These are
// recorders; attack timing, collision and cancellation policy run in tollkeeper-harness.
do {
    let scene = ChainScene()
    for effect in (AbilityBehaviors.registry.cards["v13_chain_reaction"]?.tiers ?? []).prefix(1) {
        effect(scene.playerStats)
    }
    let keeper = TollkeeperNode(health: 1)
    scene.enemies.append(keeper)
    _ = keeper.takeDamage(1)
    scene.kill(keeper, source: .primary)
    scene.kill(keeper, source: .primary)
    check("TX1 real kill chokepoint cancels Tollkeeper once before removal/duplicate credit",
          keeper.cancellations == 1 && keeper.killCredited && scene.enemies.isEmpty && scene.pendingBursts == 1)
    scene.didFinishUpdate()
    check("TX2 real end-of-frame drains cascades before hostile-pulse dispatch",
          scene.pendingBursts == 0 && scene.tollkeeperDispatchPending == [0])
}

// A7-3: actual kill/frame seams cancel the queued launcher before dispatch.
do {
    let scene = ChainScene()
    let rail = RailspikeNode(health: 1)
    scene.enemies.append(rail)
    _ = rail.takeDamage(1)
    scene.kill(rail, source: .primary)
    scene.kill(rail, source: .primary)
    scene.didFinishUpdate()
    check("RX1 real Railspike kill cancels once", rail.cancellations == 1 && rail.killCredited)
    check("RX2 real frame dispatch follows the cascade drain", scene.railspikeDispatchPending == [0])
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
