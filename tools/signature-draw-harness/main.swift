// main.swift — deterministic validators for the v2.1 signature draw
// mechanics (signature spec §5 build-shape validators, adapted to this
// unit's scope: draw-side only, per-tree `requires` authoring rides the
// rework pass). Each validator prints PASS/FAIL; exit 1 on any FAIL.

import Foundation

var passed = 0, failed = 0
func check(_ name: String, _ cond: Bool, _ detail: String = "") {
    if cond { passed += 1; print("PASS  \(name)") }
    else { failed += 1; print("FAIL  \(name)  \(detail)") }
}

func signatureIDs(_ um: UpgradeManager) -> Set<String> {
    Set(um.allCards.filter { $0.isSignature }.map { $0.id })
}

// The seven flags, by contract.
do {
    let um = UpgradeManager()
    let sigs = um.allCards.filter { $0.isSignature }
    check("V0a seven signatures flagged, one per tagged tree",
          sigs.count == 7 && Set(sigs.map { $0.tag }).count == 7 && !sigs.contains { $0.tag == .neutral },
          "got \(sigs.map { "\($0.tag):\($0.id)" })")
    check("V0b every signature provides a capability (inherits gateway pity)",
          sigs.allSatisfy { !$0.provides.isEmpty })
    check("V0c no signature is secret or a capstone",
          sigs.allSatisfy { !$0.isSecret && !$0.isCapstone })
}

// V1 — fresh run: the level-1 spread is signatures only, distinct trees,
// Neutral excluded. (Also the Boss Mode DRAFT round 1 — same call.)
do {
    var allSpreadsClean = true, allDistinct = true, neverNeutral = true
    for _ in 0..<200 {
        let um = UpgradeManager()
        let spread = um.drawCards(count: 3, level: 1)
        if spread.count != 3 || !spread.allSatisfy({ $0.isSignature }) { allSpreadsClean = false }
        if Set(spread.map { $0.tag }).count != spread.count { allDistinct = false }
        if spread.contains(where: { $0.tag == .neutral }) { neverNeutral = false }
    }
    check("V1a level-1 spread = 3 signatures, 200/200 fresh runs", allSpreadsClean)
    check("V1b spread trees are distinct", allDistinct)
    check("V1c Neutral excluded from the first spread", neverNeutral)
}

// V2 — the Lyra reroll rule: 5 active trees → reroll shows the 2 unseen
// signatures + 1 returning option; two spreads together cover all 5.
do {
    var exact = true, covered = true, stillSignaturesOnly = true
    for _ in 0..<200 {
        let um = UpgradeManager()
        guard um.activeFamilies.count == 6 else { continue }  // 5 colours + neutral
        let first = um.drawCards(count: 3, level: 1)
        let reroll = um.drawCards(count: 3, level: 1)         // same level = reroll
        if !reroll.allSatisfy({ $0.isSignature }) { stillSignaturesOnly = false }
        let firstIDs = Set(first.map { $0.id }), rerollIDs = Set(reroll.map { $0.id })
        let unseenShown = rerollIDs.subtracting(firstIDs)
        if unseenShown.count != 2 || rerollIDs.intersection(firstIDs).count != 1 { exact = false }
        if firstIDs.union(rerollIDs).count != 5 { covered = false }
    }
    check("V2a reroll = 2 unseen + 1 returning (5 active trees)", exact)
    check("V2b spread + reroll together cover all 5 active signatures", covered)
    check("V2c a reroll never escapes the rule", stillSignaturesOnly)
}

// V3 — taking a signature ends the opening and grants its capability;
// normal drafting (incl. Neutral) resumes at the next level.
do {
    let um = UpgradeManager()
    let stats = PlayerStats()
    let spread = um.drawCards(count: 3, level: 1)
    let taken = spread[0]
    um.pickCard(taken, stats: stats, level: 1)
    check("V3a picking the signature grants its capability",
          um.capabilities.isSuperset(of: taken.provides) && um.runHoldsSignature)
    var sawNonSignature = false, sawNeutral = false
    for level in 2...40 {
        let spread = um.drawCards(count: 3, level: level)
        if spread.contains(where: { !$0.isSignature }) { sawNonSignature = true }
        if spread.contains(where: { $0.tag == .neutral }) { sawNeutral = true }
    }
    check("V3b normal drafting resumes after the first pick", sawNonSignature)
    check("V3c Neutral flows again from the next spread on", sawNeutral)
}

// V4 — a second tree opens via gateway pity: with one signature taken,
// every other active tree's signature surfaces within a few levels
// (the one-claimant fix means maturing together no longer starves any).
do {
    var allSurfaced = true
    for _ in 0..<100 {
        let um = UpgradeManager()
        let stats = PlayerStats()
        let spread = um.drawCards(count: 3, level: 1)
        um.pickCard(spread[0], stats: stats, level: 1)
        var unseenSigs = Set(um.allCards
            .filter { $0.isSignature && um.activeFamilies.contains($0.tag) && um.tier(of: $0.id) == 0 }
            .map { $0.id })
        for level in 2...14 {
            for card in um.drawCards(count: 3, level: level) { unseenSigs.remove(card.id) }
            if unseenSigs.isEmpty { break }
        }
        if !unseenSigs.isEmpty { allSurfaced = false }
    }
    check("V4 every other active signature surfaces by level 14, 100/100 runs", allSurfaced)
}

// V5 — random opener path (chaos gauntlet): a 1-card draw during the
// opening hands the run a signature, not a dead-end amplifier.
do {
    var alwaysSignature = true
    for _ in 0..<200 {
        let um = UpgradeManager()
        let card = um.drawCards(count: 1, level: 1, allowSecret: false).first
        if card == nil || card?.isSignature != true { alwaysSignature = false }
    }
    check("V5 random-opener first grant is a signature (200/200)", alwaysSignature)
}

// V6 — pandas remain pandas: an eligible run's panda keeps its seat in the
// early window even during the signature opening; the rest of the spread
// stays signatures.
do {
    ReviewMode.isActive = true          // forces eligibility, as in App Review
    var pandaSeated = false, restClean = true
    for _ in 0..<50 {
        let um = UpgradeManager()
        let spread = um.drawCards(count: 3, level: 2)   // in firstOfferWindow
        if let panda = spread.first(where: { $0.isSecret }) {
            pandaSeated = true
            if spread.contains(where: { $0.id != panda.id && !$0.isSignature }) { restClean = false }
        }
    }
    ReviewMode.isActive = false
    check("V6a panda takes its seat during the signature opening", pandaSeated)
    check("V6b the non-panda seats stay signatures", restClean)
}

// V7 — palette + ban unaffected: a banned family's signature is never
// offered, and only active families' signatures appear.
do {
    SettingsManager.shared.bannedFamily = .fire
    var neverBanned = true, alwaysActive = true
    for _ in 0..<200 {
        let um = UpgradeManager()
        let spread = um.drawCards(count: 3, level: 1) + um.drawCards(count: 3, level: 1)
        if spread.contains(where: { $0.tag == .fire }) { neverBanned = false }
        if spread.contains(where: { !um.activeFamilies.contains($0.tag) }) { alwaysActive = false }
    }
    SettingsManager.shared.bannedFamily = nil
    check("V7a banned family's signature never offered (200 runs)", neverBanned)
    check("V7b only active families' signatures appear", alwaysActive)
}

// V8 — +1 Card during the opening widens the identity choice: the bonus is
// an unseen signature, never a normal card.
do {
    var alwaysUnseenSignature = true
    for _ in 0..<200 {
        let um = UpgradeManager()
        guard um.activeFamilies.count == 6 else { continue }  // 5 colours: 2 unseen remain
        let spread = um.drawCards(count: 3, level: 1)
        guard let bonus = um.drawBonusCard(excluding: spread) else { alwaysUnseenSignature = false; continue }
        if !bonus.isSignature || spread.contains(where: { $0.id == bonus.id }) {
            alwaysUnseenSignature = false
        }
    }
    check("V8 bonus card during the opening = an unseen signature (200 runs)", alwaysUnseenSignature)
}

// V9 — Growth save: with arenas ≥ 5 unlocked, Terra competes as one of the
// seven signatures and behaves exactly as before (pilot preserved).
do {
    ProgressionManager.shared.arenasUnlocked = 5
    var terraSeen = false, cleanSpreads = true
    for _ in 0..<300 {
        let um = UpgradeManager()
        let spread = um.drawCards(count: 3, level: 1)
        if !spread.allSatisfy({ $0.isSignature }) { cleanSpreads = false }
        if spread.contains(where: { $0.id == "v20_terra" }) { terraSeen = true }
    }
    ProgressionManager.shared.arenasUnlocked = 1
    check("V9a Terra rotates through the opening on a Growth save", terraSeen)
    check("V9b Growth-save openings stay signatures-only", cleanSpreads)
}

// V10 — pity one-claimant regression guard: when several gateways mature on
// the same level, exactly one takes the slot per draw and none is reset
// unseen (already implied by V4; this pins the per-level cascade).
do {
    var cascadeHolds = true
    for _ in 0..<100 {
        let um = UpgradeManager()
        let stats = PlayerStats()
        let spread = um.drawCards(count: 3, level: 1)
        um.pickCard(spread[0], stats: stats, level: 1)
        // Draw a 1-card spread so pity is the ONLY way in (slot 0 is the
        // whole spread). All unowned signatures mature at level 4 together.
        // allowSecret: false, matching the game's only 1-card caller (the
        // random opener) — with a secret allowed, a panda-eligible run's
        // panda displaces slot 0 of a 1-card spread by design ("nothing can
        // displace the panda"), a configuration no production path draws.
        var seen = Set<String>()
        for level in 2...9 {
            let cards = um.drawCards(count: 1, level: level, allowSecret: false)
            for c in cards where c.isSignature { seen.insert(c.id) }
        }
        let unowned = um.allCards.filter {
            $0.isSignature && um.activeFamilies.contains($0.tag) && um.tier(of: $0.id) == 0
        }
        // 4 unowned gateways, 6 pity-capable levels (4..9): all must cascade in.
        if !unowned.allSatisfy({ seen.contains($0.id) }) { cascadeHolds = false }
    }
    check("V10 matured gateways cascade one per level, none starved (100 runs)", cascadeHolds)
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
