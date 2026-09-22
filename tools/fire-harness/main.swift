// main.swift — deterministic validators for v2.1 abilities Unit A1 (Fire):
// Crucible's per-enemy Burn stacks (Q-F2), dormant-stack decay (CL-16), and
// the reworked Fire cards applied through the REAL card pool. Each validator
// prints PASS/FAIL; exit 1 on any FAIL.

import CoreGraphics
import Foundation

var passed = 0, failed = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1; print("PASS  \(name)") }
    else { failed += 1; print("FAIL  \(name)  \(detail())") }
}
func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 1e-9 }

let kindle: CGFloat = 0.5          // Kindle's burn DPS
let dur: TimeInterval = 2.0        // PlayerStats.burnDuration
let cap = GameConfig.Fire.crucibleStackCap
let gate = GameConfig.Fire.crucibleStackInterval
let decay = GameConfig.Fire.burnStackDecayInterval
let frame: TimeInterval = 0.05

extension BurnState {
    @discardableResult
    mutating func hit(_ source: Source = .kindleHit, dps: CGFloat = kindle, cap stackCap: Int = cap) -> Bool {
        ignite(dps: dps, duration: dur, source: source, stackCap: stackCap, stackInterval: gate)
    }
    /// Advance `seconds` in harness frames; returns total damage burned.
    @discardableResult
    mutating func run(_ seconds: TimeInterval) -> CGFloat {
        var total: CGFloat = 0
        let steps = Int((seconds / frame).rounded())
        for _ in 0..<steps { total += tick(frame, decayInterval: decay) * CGFloat(frame) }
        return total
    }
}

// B1 — stacking (Q-F2).
do {
    var b = BurnState()
    check("B1a the first Burn application is stack 1, burning at Kindle DPS",
          !b.hit() && b.stacks == 1 && b.isBurning && near(b.dps, kindle))
    b.run(1.0)
    check("B1b a second Kindle hit inside 3s adds nothing", !b.hit() && b.stacks == 1)
    b.run(2.0)
    check("B1c at 3s a Kindle hit adds one stack; each stack deals full Burn DPS",
          b.hit() && b.stacks == 2 && near(b.dps, kindle * 2))

    // Hammer it: a hit every 0.5s for 30s. Additions ≥ 3s apart, cap 5.
    var c = BurnState()
    var addTimes: [TimeInterval] = []
    var t: TimeInterval = 0
    var maxSeen = 0
    while t < 30 {
        if c.hit() { addTimes.append(t) }
        maxSeen = max(maxSeen, c.stacks)
        c.run(0.5); t += 0.5
    }
    let gaps = zip(addTimes.dropFirst(), addTimes).map { $0 - $1 }
    check("B1d sustained Kindle fire reaches exactly 5 stacks and never more",
          c.stacks == cap && maxSeen == cap, "stacks=\(c.stacks) max=\(maxSeen)")
    check("B1e stack additions are never closer than 3s (first one 3s after ignition)",
          addTimes.count == cap - 1 && (addTimes.first ?? 0) >= gate - 1e-9 && gaps.allSatisfy { $0 >= gate - 1e-9 },
          "adds at \(addTimes)")
    check("B1f five stacks burn for 5× Kindle DPS", near(c.dps, kindle * CGFloat(cap)))

    var lone = BurnState()
    lone.hit()
    lone.run(1.9)
    check("B1g a burning enemy never stacks on its own", lone.stacks == 1)

    var spread = BurnState()
    spread.hit(.kindleSpread, dps: kindle * 0.5)
    spread.run(1.5); spread.hit(.kindleSpread, dps: kindle * 0.5)
    spread.run(1.9); spread.hit(.kindleSpread, dps: kindle * 0.5)
    spread.run(1.9); spread.hit(.other, dps: 0.3)
    check("B1h Spreading Flame and other sources ignite but never add a stack", spread.stacks == 1)
}

// B2 — without Crucible the stack cap is 1 and Burn is exactly the pre-A1 model.
do {
    // Legacy transcription (EnemyNode @ a893457): dps = max, timer = max,
    // the expiring frame still burns, dps zeroes on expiry.
    var legacyDPS: CGFloat = 0, legacyTimer: TimeInterval = 0
    var b = BurnState()
    var legacyTotal: CGFloat = 0, newTotal: CGFloat = 0
    var never2 = true
    // (time, dps) applications: Kindle hits, a half-strength spread, a long lull, re-ignite.
    let script: [(TimeInterval, CGFloat, BurnState.Source)] = [
        (0.0, 0.5, .kindleHit), (0.5, 0.5, .kindleHit), (1.0, 0.25, .kindleSpread),
        (3.2, 0.5, .kindleHit), (4.0, 1.0, .kindleHit), (9.0, 0.5, .kindleHit), (9.5, 0.5, .kindleHit)]
    var next = 0
    var t: TimeInterval = 0
    while t < 14 {
        while next < script.count, script[next].0 <= t + 1e-9 {
            let (_, dps, source) = script[next]
            legacyDPS = max(legacyDPS, dps); legacyTimer = max(legacyTimer, dur)
            b.hit(source, dps: dps, cap: 1)
            next += 1
        }
        if legacyTimer > 0 {
            legacyTimer -= frame
            legacyTotal += legacyDPS * CGFloat(frame)
            if legacyTimer <= 0 { legacyDPS = 0 }
        }
        newTotal += b.tick(frame, decayInterval: decay) * CGFloat(frame)
        if b.stacks > 1 { never2 = false }
        t += frame
    }
    check("B2a cap 1 (no Crucible): never more than one stack", never2)
    check("B2b cap 1: total Burn damage matches the pre-A1 single-instance model",
          abs(legacyTotal - newTotal) < 1e-6, "legacy=\(legacyTotal) new=\(newTotal)")
}

// B3 — CL-16 dormant stacks.
do {
    var b = BurnState()
    var t: TimeInterval = 0
    while b.stacks < cap { b.hit(); b.run(0.5); t += 0.5 }
    b.hit()                       // last application: Burn ends 2s from here
    let burned = b.run(2.0)
    check("B3a when Burn ends its damage stops and the stacks stay, dormant",
          !b.isBurning && b.isDormant && b.stacks == cap && near(b.dps, 0) && burned > 0)
    check("B3b no damage while dormant", near(b.run(1.95), 0) && b.stacks == cap)
    b.run(0.05)
    check("B3c one stack fades at 2s", b.stacks == cap - 1)
    b.run(2.0)
    check("B3d …and another every 2s", b.stacks == cap - 2)

    b.run(1.0)                    // halfway to losing the next stack
    let added = b.hit()
    check("B3e reignite reactivates the SURVIVING stacks at full Burn DPS",
          b.isBurning && b.stacks == cap - 2 + (added ? 1 : 0) && near(b.dps, kindle * CGFloat(b.stacks)))
    let kept = b.stacks
    b.run(2.0)                    // Burn ends again
    b.run(1.95)
    check("B3f reignite reset decay progress (a full 2s before the next fade)", b.stacks == kept)
    b.run(0.05)
    check("B3g …then fading resumes", b.stacks == kept - 1)

    var gone = BurnState()
    gone.hit(); gone.run(2.0); gone.run(2.0)
    check("B3h all stacks faded → not dormant, nothing left", gone.stacks == 0 && !gone.isDormant)
    check("B3i no stacks left → the next application starts at one",
          !gone.hit() && gone.stacks == 1 && near(gone.dps, kindle))
}

// B4 — the 3s stack-addition limit survives dormancy and reignition.
do {
    var b = BurnState()
    b.hit()                       // t=0   stack 1, limit until t=3
    b.run(3.0); _ = b.hit()       // t=3   stack 2, limit until t=6, Burn until t=5
    check("B4a setup: two stacks", b.stacks == 2)
    b.run(2.5)                    // t=5.5 dormant 0.5s
    check("B4b reignite at 5.5s: stacks reactivate, but the limit (until 6s) blocks a new one",
          b.isDormant && !b.hit() && b.stacks == 2 && b.isBurning)
    b.run(0.6)                    // t=6.1
    check("B4c once the limit lapses a Kindle hit adds the third stack", b.hit() && b.stacks == 3)
}

// B5 — non-Kindle sources are flat; paused = frozen.
do {
    var b = BurnState()
    while b.stacks < cap { b.hit(); b.run(0.5) }
    b.hit(.other, dps: 0.3)
    check("B5a a flat source under five Kindle stacks changes nothing (max, not sum)",
          near(b.dps, kindle * CGFloat(cap)))
    b.run(2.0)
    b.hit(.other, dps: 0.3)
    check("B5b a flat source re-igniting dormant stacks burns at ITS dps, not × stacks",
          b.stacks == cap && b.isBurning && near(b.dps, 0.3), "dps=\(b.dps)")
    b.hit()
    check("B5c a Kindle hit on top restores the full stacked Burn", near(b.dps, kindle * CGFloat(b.stacks)))

    var paused = BurnState()
    paused.hit()
    let before = (paused.stacks, paused.active.remaining)
    // No ticks while the run is paused / on the level-up screen.
    check("B5d unticked (paused) Burn neither expires nor decays",
          paused.stacks == before.0 && paused.active.remaining == before.1 && paused.isBurning)
}

// B5e–g — v2.1 A4a (Brandon, Sep 21): the tesla field keeps its OWN timer.
// Re-applied every frame on Kindle's shared timer, it kept a stacked Kindle
// Burn alive for as long as Spark stood close — Burn never ended (CL-16).
do {
    var b = BurnState()
    while b.stacks < cap { b.hit(); b.run(0.5) }
    b.hit()                                    // the last Kindle hit: its Burn ends 2s from here
    var total: CGFloat = 0
    for _ in 0..<Int((6.0 / frame).rounded()) {     // tesla every frame for 6s, no Kindle
        // exactly as GameScene applies it: flat 0.3 DPS for 0.5s
        b.ignite(dps: 0.3, duration: 0.5, source: .other, stackCap: cap, stackInterval: gate)
        total += b.tick(frame, decayInterval: decay) * CGFloat(frame)
    }
    check("B5e a flat source re-applied every frame never prolongs Kindle's stacked Burn",
          near(b.dps, 0.3) && b.stacks == cap && b.isBurning, "dps=\(b.dps) stacks=\(b.stacks)")
    let expected = CGFloat(dur) * kindle * CGFloat(cap) + CGFloat(6.0 - dur) * 0.3
    check("B5f …it burned 2s of stacked Kindle, then only the flat DPS",
          abs(total - expected) < 1e-6, "total=\(total) expected=\(expected)")
    b.run(0.5)
    check("B5g …and once the flat source stops, Burn ends and the stacks go dormant",
          !b.isBurning && b.isDormant && b.stacks == cap)
}

// C — the reworked cards, through the real pool.
func card(_ um: UpgradeManager, _ id: String) -> UpgradeManager.UpgradeCard {
    guard let c = um.allCards.first(where: { $0.id == id }) else { fatalError("missing card \(id)") }
    return c
}

do {
    let um = UpgradeManager(), stats = PlayerStats()
    um.pickCard(card(um, "fire_1"), stats: stats, level: 1)
    let forge = card(um, "fire_2")
    var totals: [CGFloat] = []
    for level in 2...4 { um.pickCard(forge, stats: stats, level: level); totals.append(stats.fireDamageBonus) }
    check("C1a Forge Breath tiers are TOTALS: +25% / +50% / +100% Fire damage",
          zip(totals, [0.25, 0.50, 1.00]).allSatisfy { near($0, $1) }, "got \(totals)")
    check("C1b Forge Breath no longer touches all-damage", near(stats.damageMultiplier, 1.0))
    check("C1c Burn carries the Fire bonus (Kindle 0.5 → 1.0 per stack at T3)", near(stats.effectiveBurnDPS, 1.0))
    check("C1d tier copy matches the approved Atlas text",
          (1...3).map { forge.description(forTier: $0) } == ["+25% Fire damage.", "+50% Fire damage.", "+100% Fire damage."]
            && forge.detail == "Boosts Burn, Ember Burst, Everglow, and Inferno Crown damage.")

    stats.everglowTier = 1
    stats.everglowBasePulseMult = GameConfig.Everglow.basePulseMult
    let boosted = stats.everglowPulseDamage
    stats.fireDamageBonus = 0
    check("C1e Everglow is Fire-owned: pulse doubles at T3 (5 → 10), eruption too",
          stats.everglowPulseDamage == 5 && boosted == 10, "base=\(stats.everglowPulseDamage) boosted=\(boosted)")
}

do {
    let um = UpgradeManager(), stats = PlayerStats()
    um.pickCard(card(um, "fire_1"), stats: stats, level: 1)
    um.pickCard(card(um, "fire_4"), stats: stats, level: 2)
    check("C2a Crucible sets the per-enemy stack cap to 5", stats.burnStackCap == 5)
    check("C2b Crucible dropped its +25% damage and +0.3 burn DPS",
          near(stats.damageMultiplier, 1.0) && near(stats.burnDPS, 0.5))
    check("C2c Crucible's detail carries the approved sentence and the CL-16 tooltip",
          card(um, "fire_4").detail == "Kindle hits build Burn to 5 stacks, adding at most 1 stack every 3s per enemy. Each stack deals full Burn damage. When Burn ends, its damage stops and stacks fade one every 2s. Reignite the enemy to preserve its remaining stacks.")
    stats.reset()
    check("C2d run reset clears the stack cap and the Fire bonus", stats.burnStackCap == 1 && near(stats.fireDamageBonus, 0))
}

do {
    let um = UpgradeManager(), stats = PlayerStats()
    um.pickCard(card(um, "fire_3"), stats: stats, level: 1)
    check("C3 Ember Burst: 25% in a +50% radius (40 → 60)",
          stats.killsExplode && near(stats.explosionDamagePercent, 0.25) && near(stats.explosionRadius, 60))
}

do {
    let um = UpgradeManager(), stats = PlayerStats()
    stats.maxHP = 100; stats.currentHP = 80
    um.pickCard(card(um, "v13_glass_engine"), stats: stats, level: 1)
    check("C4a Glass Engine: a real +100% firing rate (interval halves)", near(stats.fireRateMultiplier, 0.5))
    check("C4b Glass Engine: −50% max HP, current HP clamped", stats.maxHP == 50 && stats.currentHP == 50)
}

do {
    let um = UpgradeManager(), stats = PlayerStats()
    um.pickCard(card(um, "v16_cauterize"), stats: stats, level: 1)
    stats.maxHP = 100
    func run(_ seconds: TimeInterval) -> Int {
        var healed = 0
        for _ in 0..<Int((seconds / frame).rounded()) { healed += stats.updateRegen(frame) }
        return healed
    }
    stats.currentHP = 25
    check("C5a exactly 25% is not below the threshold — no heal", run(6.0) == 0)
    // (Cauterize's timer is the legacy accumulate-up kind, so step across the
    // 3s boundary rather than landing on it.)
    stats.currentHP = 20
    check("C5b no heal on entry, none before 3 continuous seconds", run(2.9) == 0)
    check("C5c +5 HP at 3 continuous seconds", run(0.2) == 5)
    _ = run(2.0)
    stats.currentHP = 60; _ = run(0.05)      // left the threshold
    stats.currentHP = 20
    check("C5d leaving the threshold resets the timer", run(2.9) == 0 && run(0.2) == 5)
    stats.currentHP = 24
    let tick = run(3.0)
    stats.heal(tick)
    check("C5e a tick may carry HP above the threshold (24 → 29)", stats.currentHP == 29)
    check("C5f approved copy lives in the detail",
          card(um, "v16_cauterize").detail == "While below 25% max HP, recover 5 HP every 3s. Leaving this threshold resets the timer.")
}

do {
    let um = UpgradeManager(), stats = PlayerStats()
    um.pickCard(card(um, "v13_overcharge"), stats: stats, level: 1)
    stats.updateOvercharge(20)
    let capped = stats.effectiveDamageMultiplier
    stats.resetOvercharge()
    check("C6 Overcharge unchanged: +5%/s, cap +50%, reset on hit (Q-F4)",
          near(stats.overchargeDamagePerSecond, 0.05) && near(capped, 1.5) && near(stats.effectiveDamageMultiplier, 1.0))
}

// D — the selection card truncates at 4 lines × 17 chars (UpgradeCardNode.wrapText).
do {
    func cardLines(_ text: String) -> Int {
        var lines = 0, current = 0
        for word in text.split(separator: " ") {
            if current == 0 { current = word.count; lines += 1 }
            else if current + 1 + word.count <= 17 { current += 1 + word.count }
            else { current = word.count; lines += 1 }
        }
        return lines
    }
    let um = UpgradeManager()
    var tooLong: [String] = []
    for c in um.allCards where c.tag == .fire {
        // A card with a `detail` gives its 4th line to the MORE chip (A1b).
        let budget = c.detail == nil ? 4 : 3
        for tier in 1...c.maxTier where cardLines(c.description(forTier: tier)) > budget || c.description(forTier: tier).split(separator: " ").contains(where: { $0.count > 17 }) {
            tooLong.append("\(c.id) T\(tier)")
        }
    }
    check("D1 every Fire card line fits the selection card untruncated (3 lines beside a MORE chip)", tooLong.isEmpty, "truncated: \(tooLong)")
}

// E — prerequisites ship with the tree: every Fire card past Kindle needs it.
do {
    let um = UpgradeManager()
    let fire = um.allCards.filter { $0.tag == .fire }
    let gated = fire.filter { !$0.isSignature }
    check("E1 Kindle is the Fire signature and provides the capability",
          fire.filter { $0.isSignature }.map { $0.id } == ["fire_1"] && card(um, "fire_1").provides.contains(.fireUnlocked))
    check("E2 every other Fire card (capstone included) requires it (\(gated.count) cards)",
          gated.count == 8 && gated.allSatisfy { $0.requires.contains(.fireUnlocked) },
          "ungated: \(gated.filter { !$0.requires.contains(.fireUnlocked) }.map { $0.id })")

    // A run that opened with a non-Fire signature never sees a Fire card
    // other than Kindle until Kindle is owned.
    var leaked: Set<String> = []
    var offeredAfter = false
    for _ in 0..<60 {
        let run = UpgradeManager(), stats = PlayerStats()
        guard run.activeFamilies.contains(.fire) else { continue }
        guard let opener = run.allCards.first(where: { $0.isSignature && $0.tag != .fire && run.activeFamilies.contains($0.tag) })
        else { continue }
        run.pickCard(opener, stats: stats, level: 1)
        for level in 2...12 {
            for c in run.drawCards(count: 3, level: level) where c.tag == .fire && !c.isSignature { leaked.insert(c.id) }
        }
        run.pickCard(card(run, "fire_1"), stats: stats, level: 13)
        for level in 14...30 where !offeredAfter {
            if run.drawCards(count: 3, level: level).contains(where: { $0.tag == .fire && !$0.isSignature }) { offeredAfter = true }
        }
    }
    check("E3 without Kindle, no other Fire card is ever offered", leaked.isEmpty, "leaked \(leaked)")
    check("E4 with Kindle, the rest of the tree opens up", offeredAfter)
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
