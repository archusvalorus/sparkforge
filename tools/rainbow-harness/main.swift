import Foundation

var passed = 0
var failed = 0
func check(_ name: String, _ value: @autoclosure () -> Bool) {
    if value() { passed += 1; print("PASS \(name)") }
    else { failed += 1; print("FAIL \(name)") }
}
if case .failure(let report) = AbilityCatalog.installed {
    print("FAIL catalog load: \(report.summary)")
    exit(1)
}
func card(_ id: String, _ manager: UpgradeManager) -> UpgradeManager.UpgradeCard {
    guard let result = manager.allCards.first(where: { $0.id == id }) else {
        fatalError("Missing real catalog fixture: \(id)")
    }
    return result
}
func manager(needs: Set<UpgradeManager.Tag> = [], arenas: Int = 5,
             ban: UpgradeManager.Tag? = nil, seedStart: UInt64 = 0) -> UpgradeManager {
    ProgressionManager.shared.arenasUnlocked = arenas
    SettingsManager.shared.bannedFamily = ban
    for seed in seedStart..<(seedStart + 5000) {
        let result = UpgradeManager(seed: seed)
        if needs.isSubset(of: result.activeFamilies) { return result }
    }
    fatalError("No real palette fixture found")
}
func qualify(_ manager: UpgradeManager, _ stats: PlayerStats, firstLevel: Int = 1) {
    let signatures = manager.allCards.filter { $0.isSignature && manager.activeFamilies.contains($0.tag) }
    for (offset, signature) in signatures.enumerated() {
        guard manager.acquire(signature, stats: stats, level: firstLevel + offset) else {
            fatalError("Fixture signature acquisition failed: \(signature.id)")
        }
    }
}
func take(_ id: String, tier: Int, manager: UpgradeManager, stats: PlayerStats,
          firstLevel: Int = 30) {
    for offset in 0..<tier {
        guard manager.acquire(card(id, manager), stats: stats, level: firstLevel + offset) else {
            fatalError("Fixture acquisition failed: \(id), tier \(offset + 1)")
        }
    }
}
let ordinary = [RainbowPolicy.Seat("a"), RainbowPolicy.Seat("b"), RainbowPolicy.Seat("c")]
let allProtected = [RainbowPolicy.Seat("gateway", protectedBy: [.gateway]),
                    RainbowPolicy.Seat("panda", protectedBy: [.secret]),
                    RainbowPolicy.Seat("cap", protectedBy: [.capstone])]
func plan(_ policy: inout RainbowPolicy, _ manager: UpgradeManager, level: Int,
          seats: [RainbowPolicy.Seat] = ordinary, picks: Int = 1,
          source: RainbowPolicy.Source = .ordinaryLevelUp) -> RainbowPolicy.Offer? {
    policy.plan(level: level, source: source, owedPicks: picks, seats: seats,
                snapshot: .init(manager: manager))
}
func choose(_ policy: inout RainbowPolicy, _ manager: UpgradeManager, level: Int = 10) -> Bool {
    guard let offer = plan(&policy, manager, level: level) else { return false }
    return policy.commit(offer, source: .ordinaryLevelUp, owedPicks: 1,
                         snapshot: .init(manager: manager)) != nil
}
func applyThroughProof(_ policy: inout RainbowPolicy, _ manager: UpgradeManager,
                       _ stats: PlayerStats, id: String, level: Int) -> Bool {
    let candidate = card(id, manager)
    guard policy.permitsAcquisition(candidate, manager: manager, level: level) else { return false }
    return manager.acquire(candidate, stats: stats, level: level, additionalTierGate: {
        policy.permitsNextTier($0, manager: manager)
    })
}

// Qualification reads actual acquisitions. The raw Panda pick is deliberate
// fixture setup only; live eligibility is exercised separately by real traces.
do {
    let m = manager(needs: [.growth]); let s = PlayerStats()
    var p = RainbowPolicy(snapshot: .init(manager: m))
    check("Q01 fresh frozen palette excludes Neutral and includes Growth", !p.qualified && !p.requiredColors.contains(.neutral) && p.requiredColors.contains(.growth))
    check("Q02 Neutral acquisition succeeds", m.acquire(card("neutral_3", m), stats: s, level: 1))
    m.pickCard(card(GameConfig.Panda.cardID, m), stats: s, level: 2)
    p.refresh(.init(manager: m))
    check("Q03 Neutral and secret Panda add no coverage", p.coveredColors.isEmpty && !p.qualified)
    let signature = m.allCards.first { $0.isSignature && m.activeFamilies.contains($0.tag) && $0.maxTier > 1 }
    if let signature = signature {
        check("Q04 signature acquisition succeeds", m.acquire(signature, stats: s, level: 3))
        p.refresh(.init(manager: m)); let breadth = p.coveredColors
        check("Q05 signature counts exactly its active color", breadth == [signature.tag])
        check("Q06 repeated tier acquisition succeeds", m.acquire(signature, stats: s, level: 4))
        p.refresh(.init(manager: m))
        check("Q07 repeated tiers add no breadth", p.coveredColors == breadth && !p.qualified)
    } else { check("Q04 signature fixture exists", false) }
    for (i, c) in m.allCards.filter({ $0.isSignature && m.activeFamilies.contains($0.tag) && m.tier(of: $0.id) == 0 }).enumerated() {
        check("Q08 acquire missing active signature \(c.id)", m.acquire(c, stats: s, level: 10 + i))
    }
    p.refresh(.init(manager: m))
    check("Q09 every active color qualifies without activation", p.qualified && p.coveredColors == p.requiredColors && p.selectedLevel == nil && p.phase == .pendingOffer)
}
do {
    let m = manager(needs: [.growth, .guardT]); let s = PlayerStats()
    check("Q10 Terra fixture acquired", m.acquire(card("v20_terra", m), stats: s, level: 1))
    check("Q11 real bridge acquisition succeeds", m.acquire(card("v20_deeproot", m), stats: s, level: 2))
    let p = RainbowPolicy(snapshot: .init(manager: m))
    check("Q12 bridge covers both active tags", p.coveredColors == [.growth, .guardT])
    let dormant = Set(UpgradeManager.Tag.allCases).subtracting(m.activeFamilies)
    check("Q13 dormant colors never required or counted", p.requiredColors.isDisjoint(with: dormant) && p.coveredColors.isDisjoint(with: dormant))
}
do {
    let m = manager(arenas: 1, ban: .fire); let s = PlayerStats()
    var p = RainbowPolicy(snapshot: .init(manager: m))
    let frozen = p.requiredColors
    SettingsManager.shared.bannedFamily = .shock
    p.refresh(.init(manager: m))
    check("Q14 sticky setting change does not reshape frozen palette", p.requiredColors == frozen && !frozen.contains(.fire) && frozen.count < 5)
    qualify(m, s); p.refresh(.init(manager: m))
    check("Q15 reduced early-save palette qualifies with no unlock gate", p.qualified)
    let other = manager(needs: [.fire], seedStart: 100)
    p.refresh(.init(manager: other))
    check("Q16 mismatching palette fails closed", p.phase == .paletteMismatch && plan(&p, other, level: 9) == nil)
    p.refresh(.init(manager: m))
    check("Q17 mismatch stays closed until explicit reset", p.phase == .paletteMismatch)
    p.reset(snapshot: .init(manager: other))
    check("Q18 explicit new-run reset adopts new frozen palette", !p.qualified && p.coveredColors.isEmpty && p.requiredColors == other.activeFamilies.subtracting([.neutral]))
    let empty = manager(arenas: 0)
    check("Q19 invalid empty color palette does not qualify vacuously", !RainbowPolicy(snapshot: .init(manager: empty)).qualified)
}

// Offer timing and ordinary owed-pick budget. No method edits the real spread.
do {
    let m = manager(); let s = PlayerStats()
    var p = RainbowPolicy(snapshot: .init(manager: m))
    check("O01 unqualified ordinary spread never offers", plan(&p, m, level: 1) == nil)
    qualify(m, s, firstLevel: 2); p.refresh(.init(manager: m))
    check("O02 qualification mid-spread cannot enter a reroll", plan(&p, m, level: 1) == nil)
    check("O03 bonus cannot create entitlement", plan(&p, m, level: 2, source: .bonus) == nil)
    check("O04 random opener cannot create entitlement", plan(&p, m, level: 2, source: .randomOpener) == nil)
    let before = m.cardTiers
    let protected = [RainbowPolicy.Seat("pity", protectedBy: [.gateway]), RainbowPolicy.Seat("normal"), RainbowPolicy.Seat("cap", protectedBy: [.capstone])]
    let offer = plan(&p, m, level: 2, seats: protected)
    check("O05 next fresh spread takes only available seat", offer?.seat == 1 && offer?.level == 2 && m.cardTiers == before)
    check("O06 reroll retains reward around existing guarantees", plan(&p, m, level: 2, seats: protected) == offer)
    if let offer = offer {
        check("O07 zero owed picks rejects commitment", p.commit(offer, source: .ordinaryLevelUp, owedPicks: 0, snapshot: .init(manager: m)) == nil)
        check("O08 bonus rejects commitment", p.commit(offer, source: .bonus, owedPicks: 1, snapshot: .init(manager: m)) == nil)
        check("O09 opener rejects commitment", p.commit(offer, source: .randomOpener, owedPicks: 1, snapshot: .init(manager: m)) == nil)
        let receipt = p.commit(offer, source: .ordinaryLevelUp, owedPicks: 2, snapshot: .init(manager: m))
        check("O10 Extra Pick consumes exactly one ordinary choice", receipt?.picksConsumed == 1 && receipt?.picksRemaining == 1 && p.phase == .selected(level: 2))
        check("O11 reward cannot be taken twice", p.commit(offer, source: .ordinaryLevelUp, owedPicks: 1, snapshot: .init(manager: m)) == nil && plan(&p, m, level: 3) == nil)
    } else { check("O07 expected offer exists", false) }
    m.reset(); p.reset(snapshot: .init(manager: m))
    check("O12 manager and policy reset clear run ownership/schedule", p.selectedLevel == nil && !p.qualified && p.coveredColors.isEmpty && p.phase == .unqualified)
}
do {
    let m = manager(); let s = PlayerStats(); qualify(m, s)
    var p = RainbowPolicy(snapshot: .init(manager: m))
    check("O13 all protected seats defer without extra card", plan(&p, m, level: 6, seats: allProtected) == nil && p.phase == .deferred && allProtected.count == 3)
    check("O14 freed seat on same-level reroll cannot create entitlement", plan(&p, m, level: 6) == nil)
    let first = plan(&p, m, level: 7)
    check("O15 deferred entitlement uses next available fresh spread", first?.level == 7)
    p.decline(level: 7)
    check("O16 declining does not reoffer on same-level reroll", plan(&p, m, level: 7) == nil)
    check("O17 alternate level stays absent", plan(&p, m, level: 8) == nil)
    check("O18 due offer defers behind all guarantees", plan(&p, m, level: 9, seats: allProtected) == nil)
    let deferred = plan(&p, m, level: 10)
    check("O19 blocked due level carries entitlement forward", deferred?.level == 10)
    if let first = first {
        check("O20 old spread receipt is rejected", p.commit(first, source: .ordinaryLevelUp, owedPicks: 1, snapshot: .init(manager: m)) == nil)
    }
    p.decline(level: 10)
    check("O21 next cadence anchors actual offer level", plan(&p, m, level: 11) == nil && plan(&p, m, level: 12) != nil)
    check("O22 old-level request cannot rewind schedule", plan(&p, m, level: 8) == nil)
    for cap in [15, 20] {
        var late = RainbowPolicy(snapshot: .init(manager: m))
        check("O23 cap \(cap) with no owed choice gives no reward", plan(&late, m, level: cap, picks: 0) == nil && late.selectedLevel == nil)
        check("O24 already owed cap \(cap) choice remains legitimate", plan(&late, m, level: cap, picks: 1) != nil)
    }
    var empty = RainbowPolicy(snapshot: .init(manager: m))
    check("O25 exhausted/empty spread never appends a reward", plan(&empty, m, level: 6, seats: []) == nil)
    var reroll = RainbowPolicy(snapshot: .init(manager: m))
    let old = plan(&reroll, m, level: 6)
    check("O26 reroll with changed guarantees withdraws displayed offer", old != nil && plan(&reroll, m, level: 6, seats: allProtected) == nil)
    if let old = old {
        check("O27 no-seat reroll invalidates old selectable receipt", reroll.commit(old, source: .ordinaryLevelUp, owedPicks: 1, snapshot: .init(manager: m)) == nil)
    }
    check("O28 withdrawn guarantee carries to next fresh spread", plan(&reroll, m, level: 6) == nil && plan(&reroll, m, level: 7) != nil)
}

// Narrow form fork against real capabilities and next-tier metadata, in both
// orders. The composed seam executes real isSelectable and real acquire.
for id in ["neutral_3", "cap_chill_polarvortex"] {
    let boundary = id == "neutral_3" ? 5 : 4
    do {
        let m = manager(needs: [.chill]); let s = PlayerStats(); qualify(m, s)
        take(id, tier: boundary, manager: m, stats: s)
        var p = RainbowPolicy(snapshot: .init(manager: m))
        check("F01 \(id) transformation first closes Rainbow", p.qualified && p.phase == .conflictClosed && plan(&p, m, level: 40) == nil)
    }
    do {
        let m = manager(needs: [.chill]); let s = PlayerStats(); qualify(m, s)
        take(id, tier: boundary - 2, manager: m, stats: s)
        var p = RainbowPolicy(snapshot: .init(manager: m))
        check("F02 \(id) lower tiers leave Rainbow available", choose(&p, m, level: 40))
        let oldTier = m.tier(of: id)
        check("F03 \(id) owned lower tiers are retained", oldTier == boundary - 2)
        check("F04 \(id) lower next tier remains available", applyThroughProof(&p, m, s, id: id, level: 41) && m.tier(of: id) == boundary - 1)
        check("F05 \(id) real manager baseline would admit form", m.isSelectable(card(id, m), atLevel: 42))
        for (i, context) in ["normal", "stale Extra Pick", "bonus", "random opener", "granted level"].enumerated() {
            check("F06 \(id) Rainbow-first rejects \(context) at composed acquisition seam", !applyThroughProof(&p, m, s, id: id, level: 42 + i) && m.tier(of: id) == boundary - 1)
        }
        if id == "cap_chill_polarvortex" {
            check("F07 PV cannot skip closed T4 to sequential T5", m.tier(of: id) == 3 && !p.permitsNextTier(card(id, m), manager: m))
        }
    }
    do {
        let m = manager(needs: [.chill]); let s = PlayerStats(); qualify(m, s)
        take(id, tier: boundary - 1, manager: m, stats: s)
        var p = RainbowPolicy(snapshot: .init(manager: m))
        let offer = plan(&p, m, level: 40)
        check("F08 \(id) qualification alone reserves no form", offer != nil && p.selectedLevel == nil && applyThroughProof(&p, m, s, id: id, level: 40))
        if let offer = offer {
            check("F09 \(id) stale Rainbow offer revalidates after other pick", p.commit(offer, source: .ordinaryLevelUp, owedPicks: 1, snapshot: .init(manager: m)) == nil && p.selectedLevel == nil)
        }
    }
}
do {
    let m = manager(needs: [.chill, .fire]); let s = PlayerStats(); qualify(m, s)
    var p = RainbowPolicy(snapshot: .init(manager: m)); check("F10 Rainbow fixture selected", choose(&p, m))
    let permitted = ["v18_fracture_shot", "neutral_6", "neutral_4", "cap_fire_everglow"]
    for (i, id) in permitted.enumerated() {
        check("F11 unrelated path \(id) preserved", applyThroughProof(&p, m, s, id: id, level: 50 + i))
    }
    let activeCap = card("cap_fire_everglow", m)
    check("F12 existing in-progress capstone remains advanceable", p.permitsAcquisition(activeCap, manager: m, level: 55))
    let blockedCap = card("cap_chill_polarvortex", m)
    check("F13 policy preserves existing affinity focus restriction", !p.permitsAcquisition(blockedCap, manager: m, level: 55) && p.permitsNextTier(blockedCap, manager: m))
    let unm = manager(needs: [.growth]); var unp = RainbowPolicy(snapshot: .init(manager: unm))
    check("F14 existing prerequisites remain authoritative", !unp.permitsAcquisition(card("v20_deeproot", unm), manager: unm, level: 1))
}
do {
    let m = manager(needs: [.chill, .fire]); let s = PlayerStats(); qualify(m, s)
    take("cap_chill_polarvortex", tier: 2, manager: m, stats: s)
    var p = RainbowPolicy(snapshot: .init(manager: m)); check("F15 Rainbow selected alongside PV T2", choose(&p, m, level: 40))
    check("F16 PV T2 still focuses while T3 can advance", !p.permitsAcquisition(card("cap_fire_everglow", m), manager: m, level: 41))
    check("F17 PV T3 remains obtainable", applyThroughProof(&p, m, s, id: "cap_chill_polarvortex", level: 42))
    check("F18 real baseline still sees unfinished PV; proof gate closes T4", !m.isSelectable(card("cap_fire_everglow", m), atLevel: 43) && !p.permitsNextTier(card("cap_chill_polarvortex", m), manager: m))
    check("F19 newly stalled PV releases focus through real gated acquire", applyThroughProof(&p, m, s, id: "cap_fire_everglow", level: 43) && m.tier(of: "cap_fire_everglow") == 1)
}
do {
    let m = manager(needs: [.voidT]); let s = PlayerStats(); qualify(m, s)
    var p = RainbowPolicy(snapshot: .init(manager: m)); check("F20 Rainbow plus Void fixture selected", choose(&p, m, level: 40))
    check("F21 Warp Shot remains available and applies", applyThroughProof(&p, m, s, id: "void_1", level: 41))
    check("F22 Mirror Edge remains available and applies", applyThroughProof(&p, m, s, id: "v18_mirror_edge", level: 42))
    var erasure = true
    for level in 43...47 {
        erasure = applyThroughProof(&p, m, s, id: "cap_void_erasure", level: level) && erasure
    }
    check("F23 completed Erasure/Echo path retained with Rainbow", erasure && m.tier(of: "cap_void_erasure") == 5 && s.erasureEcho)
}
do {
    let m = manager(); let s = PlayerStats(); qualify(m, s)
    take("neutral_3", tier: 4, manager: m, stats: s)
    var p = RainbowPolicy(snapshot: .init(manager: m)); check("F24 actual-source acquisition fixture selected", choose(&p, m, level: 40))
    var sawBonus = false, sawOpener = false
    for _ in 0..<500 {
        if !sawBonus, let c = m.drawBonusCard(excluding: []), c.id == "neutral_3" {
            sawBonus = true
            check("F25 actual bonus candidate rejected by proof admission", !applyThroughProof(&p, m, s, id: c.id, level: 41))
        }
        if !sawOpener, let c = m.drawCards(level: 41, allowSecret: false).first(where: { $0.id == "neutral_3" }) {
            sawOpener = true
            check("F26 actual random-opener candidate rejected by proof admission", !applyThroughProof(&p, m, s, id: c.id, level: 41))
        }
        if sawBonus && sawOpener { break }
    }
    check("F27 both real source routes yielded boundary candidates", sawBonus && sawOpener && m.tier(of: "neutral_3") == 4)
}

// Execute actual production draws, then plan after actual protected claims.
// Prefer new colors for this deliberate breadth-seeking strategy, never inject
// a signature or change RNG. These traces prove reachability, not offer rates.
for cap in [15, 20] {
    var success = false
    var trace: [String] = []
    var exercised: Set<RainbowPolicy.Protection> = []
    for seed in UInt64(0)..<500 where !success {
        let m = manager(seedStart: seed); let s = PlayerStats()
        var p = RainbowPolicy(snapshot: .init(manager: m)); trace = []
        for level in 1...cap {
            let spread = m.drawCards(level: level)
            let seats = spread.map { RainbowPolicy.Seat($0.id, protectedBy: m.r0ProtectedIDs[$0.id] ?? []) }
            for seat in seats { exercised.formUnion(seat.protections) }
            let proposed = plan(&p, m, level: level, seats: seats)
            if let offer = proposed {
                check("T01 cap \(cap) real draw replaces no production guarantee", seats.indices.contains(offer.seat) && seats[offer.seat].protections.isEmpty)
                success = p.commit(offer, source: .ordinaryLevelUp, owedPicks: 1, snapshot: .init(manager: m)) != nil
                trace.append("L\(level):Rainbow(proof)")
                print("TRACE cap=\(cap) seed=\(seed) " + trace.joined(separator: " "))
                break
            }
            let pick = spread.first { c in
                !c.isSecret && !c.isCapstone && !p.coveredColors.contains(c.tag) && c.tag != .neutral
            } ?? spread.first { !$0.isSecret && !$0.isCapstone } ?? spread.first
            if let pick = pick {
                check("T02 cap \(cap) real drawn pick acquired", m.acquire(pick, stats: s, level: level))
                p.refresh(.init(manager: m)); trace.append("L\(level):\(pick.id)")
            }
        }
    }
    check("T03 cap \(cap) reachable via actual normal draws", success)
    check("T04 cap \(cap) trace exercised signature protection", exercised.contains(.signatureOpening))
}
do {
    // Force no cards; search actual seeded draws for guarantee claims and
    // prove the planner respects each observed protection in a qualified run.
    var found: Set<RainbowPolicy.Protection> = []
    for seed in UInt64(0)..<200 where found.count < 3 {
        let m = manager(needs: [.fire, .growth, .guardT], seedStart: seed); let s = PlayerStats()
        // Deeproot covers Guard without owning its signature, leaving its real
        // gateway pity eligible after Rainbow's breadth qualifier is met.
        for (i, signature) in m.allCards.filter({ $0.isSignature && $0.tag != .guardT && m.activeFamilies.contains($0.tag) }).enumerated() {
            _ = m.acquire(signature, stats: s, level: 20 + i)
        }
        _ = m.acquire(card("v20_deeproot", m), stats: s, level: 26)
        take("cap_fire_everglow", tier: 1, manager: m, stats: s)
        var p = RainbowPolicy(snapshot: .init(manager: m))
        for level in 2...16 {
            let spread = m.drawCards(level: level)
            let seats = spread.map { RainbowPolicy.Seat($0.id, protectedBy: m.r0ProtectedIDs[$0.id] ?? []) }
            for seat in seats { found.formUnion(seat.protections) }
            if let offer = plan(&p, m, level: level, seats: seats) {
                check("T05 real gateway/capstone/Panda claims preserved", seats[offer.seat].protections.isEmpty)
                p.decline(level: level)
            }
        }
    }
    check("T06 actual draw seam observed gateway guarantee", found.contains(.gateway))
    check("T07 actual draw seam observed capstone guarantee", found.contains(.capstone))
    check("T08 actual draw seam observed secret Panda guarantee", found.contains(.secret))
}

do {
    let m = manager()
    let normalNeutral = m.allCards.filter { $0.tag == .neutral && !$0.isSecret }
    check("I01 live catalog counts unchanged", m.allCards.count == 79 && m.allCards.filter({ !$0.isSecret }).count == 78 && normalNeutral.count == 9)
    check("I02 special reward has truthful one-rank category", RainbowPolicy.reward.ranks == 1 && RainbowPolicy.reward.category == .breadthReward)
    check("I03 proof descriptor is not a no-op live catalog card", !m.allCards.contains { $0.id == RainbowPolicy.reward.id })
    var absent = true
    for level in 1...20 {
        absent = absent && !m.drawCards(level: level).contains { $0.id == RainbowPolicy.reward.id }
        absent = absent && m.drawBonusCard(excluding: []).map { $0.id != RainbowPolicy.reward.id } != false
        absent = absent && !m.drawCards(level: level, allowSecret: false).contains { $0.id == RainbowPolicy.reward.id }
    }
    check("I04 actual ordinary/bonus/opener production draws contain no Rainbow", absent)
    let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
    let scene = try String(contentsOfFile: root + "/Sparkforge/Scenes/GameScene.swift", encoding: .utf8)
    let managerSource = try String(contentsOfFile: root + "/Sparkforge/Systems/UpgradeManager.swift", encoding: .utf8)
    check("I05 no live scene/manager policy invocation", !scene.contains("RainbowPolicy") && !managerSource.contains("RainbowPolicy"))
}
print("Rainbow R0: \(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
