// main.swift — the catalog harness (v2.1 abilities Unit A7a, CL-90).
//
// Compiles the REAL UpgradeManager + PlayerStats (and what they need) against
// the shared stubs and the REAL extracted config, then proves the catalog:
//   CA  exact expectations (counts, one signature + one capstone per tree,
//       every prerequisite provided in its own trees, the A7a edges as ruled)
//   RW  every draftable card is OFFERED and MAXED through the real normal-
//       campaign draw, from a fresh run, on a full save and on a new save
//   IS  the one offer rule holds across BOTH draws (spread/reroll/opener and
//       the +1 Card bonus), checked by an independent oracle
//   PA  Panda through its own scheduler, never through any draw
//   BR  the +1 Card regressions (each with a positive anchor)
//   EG  the ruled enabler edges (CL-91/92/93) through the real draw
//   CT  the Codex tally and the retired-id registry (CL-102)
//   WR  the scene wiring the harness can't execute (exact lines)
// Every run is SEEDED (UpgradeManager(seed:)), so every result reproduces.
//
// `--dump <path>` skips the checks and writes the catalog as JSON for
// tools/generate-card-atlas.py and tools/generate-ability-canon.py (CL-103/104).

import CoreGraphics
import Foundation

typealias Card = UpgradeManager.UpgradeCard
typealias Cap = UpgradeManager.Capability
typealias Tag = UpgradeManager.Tag

let colours: [Tag] = [.fire, .chill, .shock, .bleed, .guardT, .voidT, .growth]

// MARK: - Dump mode

func caps(_ s: Set<Cap>) -> [String] { s.map { $0.rawValue }.sorted() }
func tierCaps(_ d: [Int: Set<Cap>]) -> [String: [String]] {
    Dictionary(uniqueKeysWithValues: d.map { (String($0.key), caps($0.value)) })
}

if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--dump" {
    let um = UpgradeManager(seed: 1)
    var cards: [[String: Any]] = []
    for c in um.allCards {
        var e: [String: Any] = [
            "id": c.id, "name": c.name,
            "tag": c.tag.rawValue, "tagKey": String(describing: c.tag),
            "isSignature": c.isSignature, "isCapstone": c.isCapstone, "isSecret": c.isSecret,
            "maxTier": c.maxTier, "description": c.description,
            "provides": caps(c.provides), "requires": caps(c.requires),
            "tierRequires": tierCaps(c.tierRequires), "tierProvides": tierCaps(c.tierProvides),
            "blockedBy": caps(c.blockedBy), "tierBlockedBy": tierCaps(c.tierBlockedBy),
        ]
        if let s = c.secondaryTag { e["secondaryTag"] = s.rawValue; e["secondaryTagKey"] = String(describing: s) }
        if let d = c.tierDescriptions { e["tierDescriptions"] = d }
        if let n = c.tierNames { e["tierNames"] = n }
        if let d = c.detail { e["detail"] = d }
        cards.append(e)
    }
    var synergies: [String: [[String: Any]]] = [:]
    for t in colours {
        synergies[String(describing: t)] = UpgradeManager.synergyTiers(for: t).map {
            ["threshold": $0.threshold, "title": $0.title, "effect": $0.effect]
        }
    }
    let out: [String: Any] = [
        "cards": cards,
        "synergies": synergies,
        "retired": UpgradeManager.retiredCardIDs,
        "tags": Tag.allCases.map { ["key": String(describing: $0), "name": $0.rawValue] },
        "panda": ["chance": Double(GameConfig.Panda.eligibilityChance),
                  "window": [GameConfig.Panda.firstOfferWindow.lowerBound, GameConfig.Panda.firstOfferWindow.upperBound]],
    ]
    let data = try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    print("dumped \(cards.count) cards → \(CommandLine.arguments[2])")
    exit(0)
}

// MARK: - Check plumbing

var passed = 0, failed = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1; print("PASS  \(name)") }
    else { failed += 1; print("FAIL  \(name)  \(detail())") }
}

let proto = UpgradeManager(seed: 0)
let pool = proto.allCards
let draftable = pool.filter { !$0.isSecret }
func card(_ id: String) -> Card {
    guard let c = pool.first(where: { $0.id == id }) else { fatalError("missing card \(id)") }
    return c
}
func tags(_ c: Card) -> Set<Tag> { Set([c.tag] + (c.secondaryTag.map { [$0] } ?? [])) }
func allNeeds(_ c: Card) -> Set<Cap> { c.tierRequires.values.reduce(c.requires) { $0.union($1) } }
func providers(of cap: Cap) -> [Card] {
    pool.filter { $0.provides.contains(cap) || $0.tierProvides.values.contains { $0.contains(cap) } }
}

/// A seeded run whose palette holds `needs`. Rejection over seeds is the only
/// palette control, exactly as a real run rolls it (no seam forces a palette).
func run(_ seed: inout UInt64, arenas: Int, needs: Set<Tag> = [], ban: Tag? = nil) -> UpgradeManager {
    ProgressionManager.shared.arenasUnlocked = arenas
    SettingsManager.shared.bannedFamily = ban
    for _ in 0..<5_000 {
        let um = UpgradeManager(seed: seed)
        seed &+= 1
        if needs.isSubset(of: um.activeFamilies) { return um }
    }
    // A palette that never comes up in 5,000 seeds means the seeded generator
    // is broken (constant, or ignored): fail loudly rather than spin forever.
    print("FAIL  RS0 no seed in 5,000 rolled a palette holding \(needs.map { $0.rawValue }.sorted())")
    exit(1)
}
/// The next tier's gates, independently: its tierRequires held, its
/// tierBlockedBy clear (CL-92 Frost Touch T3; CL-93 Polar Vortex T4).
func nextTierOpen(_ c: Card, _ um: UpgradeManager) -> Bool {
    let t = um.tier(of: c.id) + 1
    if let need = c.tierRequires[t], !need.isSubset(of: um.capabilities) { return false }
    if let block = c.tierBlockedBy[t], !block.isDisjoint(with: um.capabilities) { return false }
    return true
}
/// Capstones that hold the lockout and get the guarantee: started, not maxed,
/// next tier open. A STALLED capstone releases both (Brandon, Sep 25).
func inProgressCapstones(_ um: UpgradeManager) -> [Card] {
    um.allCards.filter { $0.isCapstone && um.tier(of: $0.id) > 0 && um.tier(of: $0.id) < $0.maxTier && nextTierOpen($0, um) }
}

/// The INDEPENDENT oracle for the offer rule (it never calls UpgradeManager's
/// private predicate). nil = offerable. `scheduledCapstoneOK` admits an active
/// capstone's own guarantee seat (spreads only, never the bonus); `taken` is
/// what this level-up has already acquired (F2).
func violation(_ c: Card, _ um: UpgradeManager, scheduledCapstoneOK: Bool, taken: Set<String> = []) -> String? {
    let t = um.tier(of: c.id)
    if c.isSecret { return "secret" }
    if taken.contains(c.id) { return "taken this level-up" }
    if t >= c.maxTier { return "maxed" }
    if !c.requires.isSubset(of: um.capabilities) { return "requires" }
    if let need = c.tierRequires[t + 1], !need.isSubset(of: um.capabilities) { return "tierRequires" }
    if let block = c.tierBlockedBy[t + 1], !block.isDisjoint(with: um.capabilities) { return "tierBlockedBy" }
    if !c.blockedBy.isDisjoint(with: um.capabilities) { return "blockedBy" }
    if !um.activeFamilies.contains(c.tag) { return "dormant colour" }
    if let s = c.secondaryTag, !um.activeFamilies.contains(s) { return "half-dormant bridge" }
    let running = inProgressCapstones(um)
    if c.isCapstone && !running.isEmpty {
        let isRunning = running.contains { $0.id == c.id }
        if !(scheduledCapstoneOK && isRunning) { return isRunning ? "in-progress capstone" : "capstone lockout" }
    }
    return nil
}

/// A throwaway stats sink per pick: the harness never reads stats, and one
/// shared sink would compound tier effects (Iron Maiden's DEF) across runs.
var S: PlayerStats { PlayerStats() }

// MARK: - RS · the seed really drives every random choice (so every result reproduces)

do {
    func trace(_ seed: UInt64) -> [String] {
        ProgressionManager.shared.arenasUnlocked = 5
        SettingsManager.shared.bannedFamily = nil
        let um = UpgradeManager(seed: seed)
        var out = [um.activeFamilies.map { $0.rawValue }.sorted().joined(separator: ","), "\(um.pandaEligible)"]
        for level in 2...40 {
            let spread = um.drawCards(count: 3, level: level)
            let bonus = um.drawBonusCard(excluding: spread)
            out.append(spread.map { $0.id }.joined(separator: ",") + "|" + (bonus?.id ?? "-"))
            if let p = spread.first { um.pickCard(p, stats: PlayerStats(), level: level) }
        }
        return out
    }
    let a = trace(424_242), b = trace(424_242)
    let palettes = Set((0..<40).map { trace(UInt64($0))[0] })
    let pandaRolls = Set((0..<200).map { trace(UInt64(1_000 + $0))[1] })
    let spreads = Set((0..<40).map { trace(UInt64($0))[5] })
    check("RS1 the same seed reproduces the palette, the Panda roll, every spread and every bonus (40 levels)", a == b)
    var pandaStable = true, paletteStable = true, openingBonusStable = true
    for s in 0..<300 {
        let one = UpgradeManager(seed: UInt64(7_000 + s)), two = UpgradeManager(seed: UInt64(7_000 + s))
        if one.pandaEligible != two.pandaEligible { pandaStable = false }
        if one.activeFamilies != two.activeFamilies { paletteStable = false }
        // The +1 Card during the signature opening picks among the UNSEEN
        // signatures — usually two, so a single seed can't tell a seeded pick
        // from a free one (a coin flip matches half the time). 300 seeds can.
        let shownOne = one.drawCards(count: 3, level: 2), shownTwo = two.drawCards(count: 3, level: 2)
        if one.drawBonusCard(excluding: shownOne)?.id != two.drawBonusCard(excluding: shownTwo)?.id { openingBonusStable = false }
    }
    check("RS1b across 300 seeds, each seed rolls the same Panda eligibility, palette and opening +1 Card twice",
          pandaStable && paletteStable && openingBonusStable)
    var raw = UpgradeManager.DrawRandom(seed: 99)
    let draws = Set((0..<64).map { _ in raw.next() })
    check("RS1c the seeded generator varies (64 draws, all distinct)", draws.count == 64)
    check("RS2 different seeds vary the palette, the Panda roll, the spreads and the bonus",
          palettes.count > 5 && pandaRolls.count == 2 && spreads.count > 20,
          "palettes=\(palettes.count) panda=\(pandaRolls) spreads=\(spreads.count)")
}

// MARK: - CA · catalog expectations

do {
    let expected: [Tag: Int] = [.fire: 9, .chill: 8, .shock: 8, .bleed: 13, .guardT: 10, .voidT: 13, .growth: 8, .neutral: 10]
    var byTag: [Tag: Int] = [:]
    for c in draftable { byTag[c.tag, default: 0] += 1 }
    check("CA1 pool 80 = 79 draftable + 1 secret (Panda) (CL-106)",
          pool.count == 80 && draftable.count == 79 && pool.filter { $0.isSecret }.map { $0.id } == ["v20_panda"],
          "pool=\(pool.count) draftable=\(draftable.count)")
    check("CA2 draftable by primary tree: Fire 9 · Chill 8 · Shock 8 · Bleed 13 · Guard 10 · Void 13 · Growth 8 · Neutral 10",
          byTag == expected, "\(byTag)")
    let perTree = colours.allSatisfy { t in
        pool.filter { $0.tag == t && $0.isSignature }.count == 1 && pool.filter { $0.tag == t && $0.isCapstone }.count == 1
    }
    let neutralBare = !pool.contains { $0.tag == .neutral && ($0.isSignature || $0.isCapstone) }
    check("CA3 one signature and one capstone per coloured tree; Neutral has neither", perTree && neutralBare)
    let ids = pool.map { $0.id }
    check("CA4 no duplicate ids", Set(ids).count == ids.count)
    let copyFits = pool.allSatisfy { c in
        (c.tierDescriptions.map { $0.count == c.maxTier } ?? true) && (c.tierNames.map { $0.count == c.maxTier } ?? true)
            && c.tierRequires.keys.allSatisfy { (2...c.maxTier).contains($0) }
            && c.tierProvides.keys.allSatisfy { (1...c.maxTier).contains($0) }
            && c.tierBlockedBy.keys.allSatisfy { (2...c.maxTier).contains($0) }
    }
    check("CA5 tier copy and tier names match maxTier; tierRequires/tierProvides keys are real tiers", copyFits)

    // Every prerequisite has a provider inside the consumer's own trees, so it
    // can never be required on a palette where its provider is absent.
    var orphan: [String] = []
    for c in pool {
        for cap in allNeeds(c) where !providers(of: cap).contains(where: { tags(c).contains($0.tag) }) {
            orphan.append("\(c.id)←\(cap.rawValue)")
        }
    }
    check("CA6 every required/tier-required capability has a provider in the consumer's own trees", orphan.isEmpty, "\(orphan)")
    let blockOrphans = pool.flatMap { c in
        c.tierBlockedBy.values.reduce(c.blockedBy) { $0.union($1) }.filter { providers(of: $0).isEmpty }.map { "\(c.id)←\($0.rawValue)" }
    }
    check("CA7 every blockedBy / tierBlockedBy capability is granted by some card", blockOrphans.isEmpty, "\(blockOrphans)")
    let selfLoops = pool.filter { c in
        let grants = c.tierProvides.values.reduce(c.provides) { $0.union($1) }
        let closers = c.tierBlockedBy.values.reduce(c.blockedBy) { $0.union($1) }
        return !grants.isDisjoint(with: allNeeds(c)) || !grants.isDisjoint(with: closers)
    }.map { $0.id }
    check("CA8 no card requires or is blocked by what it grants", selfLoops.isEmpty, "\(selfLoops)")
    let ungated = pool.filter { $0.tag != .neutral && !$0.isSignature && !$0.isSecret && $0.requires.isEmpty }.map { $0.id }
    check("CA9 every non-signature coloured card has a prerequisite", ungated.isEmpty, "\(ungated)")
    let sigsOpen = pool.filter { $0.isSignature }.allSatisfy { $0.requires.isEmpty && !$0.provides.isEmpty }
    check("CA10 signatures require nothing and provide their tree", sigsOpen)

    // The A7a edges exactly as ruled (closure table §B6).
    check("CA11 CL-91 Gouge provides critSource; Hemorrhage requires bleedUnlocked + critSource",
          card("bleed_1").provides == [.critSource] && card("bleed_2").requires == [.bleedUnlocked, .critSource])
    check("CA12 CL-92 Polar Vortex provides polarVortex; Frost Touch's T3 (and only T3) needs it",
          card("cap_chill_polarvortex").provides == [.polarVortex] && card("chill_1").tierRequires == [3: [.polarVortex]])
    let blocked = Set(pool.filter { $0.blockedBy.contains(.glacialCondensation) }.map { $0.id })
    check("CA13 CL-93 Polar Vortex T4 grants glacialCondensation (nothing else does), and T4 — only T4 — closes on pelletEffect",
          card("cap_chill_polarvortex").tierProvides == [4: [.glacialCondensation]]
              && providers(of: .glacialCondensation).map { $0.id } == ["cap_chill_polarvortex"]
              && card("cap_chill_polarvortex").tierBlockedBy == [4: [.pelletEffect]])
    let pellet: Set<String> = ["void_1", "void_2", "v18_mirror_edge", "v18_fracture_shot", "v18_riftline"]
    check("CA14 CL-93 (symmetric) exactly Warp Shot, Gravity Well, Mirror Edge, Fracture Shot and Riftline are blocked by it AND grant pelletEffect (Erasure neither)",
          blocked == pellet && Set(providers(of: .pelletEffect).map { $0.id }) == pellet
              && card("cap_void_erasure").blockedBy.isEmpty && !card("cap_void_erasure").provides.contains(.pelletEffect),
          "\(blocked.sorted())")
}

// MARK: - RW · reachability through the real normal-campaign draw

/// The capabilities a target transitively needs, and the cards that grant them.
func neededCaps(_ target: Card) -> Set<Cap> {
    var need = allNeeds(target), frontier = need
    while let cap = frontier.popFirst() {
        for p in providers(of: cap) {
            for more in p.requires where !need.contains(more) { need.insert(more); frontier.insert(more) }
        }
    }
    return need
}
func neededTrees(_ target: Card) -> Set<Tag> {
    var trees = tags(target)
    for cap in neededCaps(target) { if let p = providers(of: cap).first { trees.insert(p.tag) } }
    return trees
}

/// Goal-directed play: take the target whenever offered; else a card that
/// grants a capability it still needs; else anything that can't hurt it —
/// never a card whose next tier would silence it, and never another
/// capstone when the target is one.
func choose(_ spread: [Card], for target: Card, _ um: UpgradeManager, needs: Set<Cap>) -> Card? {
    if let t = spread.first(where: { $0.id == target.id }) { return t }
    let missing = needs.subtracting(um.capabilities)
    let closers = target.tierBlockedBy.values.reduce(target.blockedBy) { $0.union($1) }
    func harmless(_ c: Card) -> Bool {
        let next = (c.tierProvides[um.tier(of: c.id) + 1] ?? []).union(um.tier(of: c.id) == 0 ? c.provides : [])
        if !next.isDisjoint(with: closers) { return false }
        if target.isCapstone && c.isCapstone { return false }
        return true
    }
    if let p = spread.first(where: { harmless($0) && !$0.provides.isDisjoint(with: missing) }) { return p }
    let safe = spread.filter(harmless)
    return safe.first(where: { $0.tag == target.tag && !$0.isCapstone })
        ?? safe.first(where: { !$0.isCapstone }) ?? safe.first
}

struct Reach { var offered = 0, maxed = 0, runs = 0, refused = 0, firstOffers: [Int] = [], maxedAt: [Int] = [] }

func walk(_ target: Card, arenas: Int, runs: Int, levels: Int, seed: inout UInt64) -> Reach {
    var r = Reach()
    let needs = neededCaps(target), trees = neededTrees(target)
    for _ in 0..<runs {
        let um = run(&seed, arenas: arenas, needs: trees)
        var firstOffer: Int? = nil
        for level in 2...(levels + 1) {
            let spread = um.drawCards(count: 3, level: level)
            if firstOffer == nil, spread.contains(where: { $0.id == target.id }) { firstOffer = level }
            guard let pick = choose(spread, for: target, um, needs: needs) else { continue }
            if !um.acquire(pick, stats: S, level: level) { r.refused += 1 }   // a drawn card is always selectable
            if um.tier(of: target.id) >= target.maxTier { r.maxedAt.append(level); break }
        }
        r.runs += 1
        if let f = firstOffer { r.offered += 1; r.firstOffers.append(f) }
        if um.tier(of: target.id) >= target.maxTier { r.maxed += 1 }
    }
    return r
}
func median(_ a: [Int]) -> Int { a.isEmpty ? -1 : a.sorted()[a.count / 2] }

do {
    let runs = 60, levels = 120
    var seed: UInt64 = 1_000
    var fullMisses: [String] = [], newMisses: [String] = []
    var slowest = ("", 0)
    for c in draftable {
        let r = walk(c, arenas: 5, runs: runs, levels: levels, seed: &seed)
        if r.offered != runs || r.maxed != runs || r.refused > 0 { fullMisses.append("\(c.id) \(r.offered)/\(r.maxed) refused=\(r.refused)") }
        let m = median(r.maxedAt)
        if m > slowest.1 { slowest = (c.id, m) }
    }
    check("RW1 full save (all trees): all 79 draftable cards OFFERED and MAXED (through acquire) in \(runs)/\(runs) seeded runs within \(levels) level-ups",
          fullMisses.isEmpty, "\(fullMisses)")
    print("      slowest median to max: \(slowest.0) at level \(slowest.1)")

    let nonGrowth = draftable.filter { $0.tag != .growth }
    for c in nonGrowth {
        let r = walk(c, arenas: 1, runs: runs / 2, levels: levels, seed: &seed)
        if r.offered != runs / 2 || r.maxed != runs / 2 || r.refused > 0 { newMisses.append("\(c.id) \(r.offered)/\(r.maxed) refused=\(r.refused)") }
    }
    check("RW2 new save (arena 1): all \(nonGrowth.count) non-Growth draftable cards offered and maxed in every run",
          nonGrowth.count == 71 && newMisses.isEmpty, "count=\(nonGrowth.count) \(newMisses)")

    // Growth stays absent on a new save (its colour unlocks at arena 5).
    var growthSeen = false
    for _ in 0..<100 {
        let um = run(&seed, arenas: 1)
        for level in 2...40 {
            let spread = um.drawCards(count: 3, level: level)
            if spread.contains(where: { $0.tag == .growth }) { growthSeen = true }
            if let p = spread.first { um.pickCard(p, stats: S, level: level) }
        }
    }
    check("RW3 a new save never offers a Growth card (100 runs × 40 levels)", !growthSeen)
}

// MARK: - IS · the offer rule across every draw AND at acquisition (independent oracle)
//
// Each level-up is a SESSION, modelled on the real UI: a spread, then — in a
// random order — a reroll, a +1 Card and the Extra Pick's first selection
// (after which the rest of the table is revalidated, F1); then the final pick
// through `acquire`. Every draw is checked against the oracle with the
// session's taken set (F2), and production's `isSelectable` must agree with
// the oracle on every card still on the table.

do {
    var seed: UInt64 = 50_000
    var spreads = 0, rerolls = 0, bonuses = 0, grants = 0, extraFirsts = 0
    var spreadBad: [String: Int] = [:], bonusBad: [String: Int] = [:], grantBad: [String: Int] = [:]
    var openingBreaks = 0, dupes = 0, pandaOutside = 0, refused = 0, disagree = 0, dropped = 0
    var bonusWhileCapstone = 0, bonusWhileBridgeDormant = 0, rerollAfterTake = 0, bonusAfterTake = 0
    let bans: [Tag?] = [nil] + colours
    let bridges = pool.filter { $0.secondaryTag != nil }

    for r in 0..<3_000 {
        ReviewMode.isActive = (r % 4 == 0)
        let um = run(&seed, arenas: r % 2 == 0 ? 5 : 1, ban: bans[r % bans.count])
        var rng = UpgradeManager.DrawRandom(seed: seed &* 31)
        func roll(_ p: Double) -> Bool { Double.random(in: 0..<1, using: &rng) < p }

        if r % 6 == 0 {                                   // the Boss Mode random opener
            for level in 1...8 {
                guard let g = um.drawCards(count: 1, level: level, allowSecret: false).first else { break }
                grants += 1
                if let v = violation(g, um, scheduledCapstoneOK: true) { grantBad[v, default: 0] += 1 }
                if !um.acquire(g, stats: S, level: level) { refused += 1 }
            }
        }
        let start = r % 6 == 0 ? 9 : 2
        for level in start...(start + 59) {
            let heldSignature = um.runHoldsSignature
            var taken: Set<String> = []
            func checkDraw(_ cards: [Card]) {
                if Set(cards.map { $0.id }).count != cards.count { dupes += 1 }
                for c in cards {
                    if c.isSecret {
                        if !um.pandaEligible { pandaOutside += 1 }
                        if taken.contains(c.id) { spreadBad["panda re-seated this level-up", default: 0] += 1 }
                        continue
                    }
                    if let v = violation(c, um, scheduledCapstoneOK: true, taken: taken) { spreadBad[v, default: 0] += 1 }
                }
            }
            func agree(_ table: [Card]) {                 // production vs the oracle, card by card
                for c in table where !c.isSecret {
                    let oracleOK = violation(c, um, scheduledCapstoneOK: true, taken: taken) == nil
                    if um.isSelectable(c, atLevel: level) != oracleOK { disagree += 1 }
                }
            }
            var shown = um.drawCards(count: 3, level: level)
            spreads += 1
            checkDraw(shown)
            if !heldSignature && shown.contains(where: { !$0.isSignature && !$0.isSecret }) { openingBreaks += 1 }
            guard !shown.isEmpty else { continue }

            var events = ["reroll", "bonus", "extra"].filter { _ in roll(0.3) }
            events.shuffle(using: &rng)
            for e in events where !shown.isEmpty {
                switch e {
                case "reroll":
                    if !taken.isEmpty { rerollAfterTake += 1 }
                    shown = um.drawCards(count: max(3, shown.count), level: level)
                    rerolls += 1
                    checkDraw(shown)
                case "bonus":
                    if !inProgressCapstones(um).isEmpty { bonusWhileCapstone += 1 }
                    if bridges.contains(where: { $0.secondaryTag.map { !um.activeFamilies.contains($0) } ?? false }) {
                        bonusWhileBridgeDormant += 1
                    }
                    if !taken.isEmpty { bonusAfterTake += 1 }
                    if let b = um.drawBonusCard(excluding: shown) {
                        bonuses += 1
                        if let v = violation(b, um, scheduledCapstoneOK: false, taken: taken) { bonusBad[v, default: 0] += 1 }
                        if shown.contains(where: { $0.id == b.id }) { bonusBad["duplicates the spread", default: 0] += 1 }
                        shown.append(b)
                    }
                default:                                   // the Extra Pick's first selection
                    guard shown.count > 1 else { continue }
                    agree(shown)
                    let first = shown.remove(at: Int.random(in: 0..<shown.count, using: &rng))
                    if um.acquire(first, stats: S, level: level) { taken.insert(first.id) } else { refused += 1 }
                    extraFirsts += 1
                    let kept = um.stillSelectable(shown, atLevel: level)
                    dropped += shown.count - kept.count
                    // Everything kept passes the oracle; everything dropped fails it.
                    for c in shown where !c.isSecret {
                        let oracleOK = violation(c, um, scheduledCapstoneOK: true, taken: taken) == nil
                        if kept.contains(where: { $0.id == c.id }) != oracleOK { disagree += 1 }
                    }
                    shown = kept
                }
            }
            if !shown.isEmpty {
                agree(shown)
                let pick = shown[Int.random(in: 0..<shown.count, using: &rng)]
                if !um.acquire(pick, stats: S, level: level) { refused += 1 }
            }
        }
    }
    ReviewMode.isActive = false
    check("IS1 spreads + rerolls (incl. after a pick this level-up): zero offer-rule violations (\(spreads) spreads, \(rerolls) rerolls)",
          spreadBad.isEmpty, "\(spreadBad)")
    check("IS2 random-opener grants: zero violations, never secret, every grant acquired (\(grants) grants)",
          grantBad.isEmpty && grants > 1_000, "\(grantBad) n=\(grants)")
    check("IS3 +1 Card bonus: zero offer-rule violations (incl. this level-up's taken set), never an active capstone, never duplicates the spread (\(bonuses) bonus draws)",
          bonusBad.isEmpty, "\(bonusBad)")
    check("IS4 acquisition: every card still on the table is taken successfully, and production's isSelectable agrees with the oracle on every card (F1)",
          refused == 0 && disagree == 0, "refused=\(refused) disagree=\(disagree)")
    check("IS5 no duplicate cards in a spread; the opening stays signatures-only; Panda only on eligible runs",
          dupes == 0 && openingBreaks == 0 && pandaOutside == 0, "dupes=\(dupes) opening=\(openingBreaks) panda=\(pandaOutside)")
    // Positive anchors: the sweep really exercised the risky states.
    check("IS6 the sweep exercised the risky states (bonus with a capstone running / a bridge half-dormant; reroll and bonus after a take; Extra Pick drops)",
          bonusWhileCapstone > 1_000 && bonusWhileBridgeDormant > 5_000 && rerollAfterTake > 1_000 && bonusAfterTake > 1_000
              && extraFirsts > 5_000 && dropped > 100,
          "capstone=\(bonusWhileCapstone) bridge=\(bonusWhileBridgeDormant) rerollAfter=\(rerollAfterTake) bonusAfter=\(bonusAfterTake) extra=\(extraFirsts) dropped=\(dropped)")
}

// MARK: - BR · +1 Card regressions (each paired with its positive anchor)

/// Draw the bonus `n` times from the same state; count how often it returns `id`.
/// drawBonusCard doesn't change which cards are eligible, so repeats are fair.
func bonusCount(_ um: UpgradeManager, _ id: String, excluding shown: [Card] = [], n: Int = 600) -> Int {
    (0..<n).reduce(0) { acc, _ in acc + (um.drawBonusCard(excluding: shown)?.id == id ? 1 : 0) }
}
func bonusAny(_ um: UpgradeManager, n: Int = 600, _ pred: (Card) -> Bool) -> Int {
    (0..<n).reduce(0) { acc, _ in acc + ((um.drawBonusCard(excluding: []).map(pred) ?? false) ? 1 : 0) }
}

do {
    var seed: UInt64 = 90_000
    // BR1 tierRequires: Glacial Drift at T4 without Whiteout.
    let um1 = run(&seed, arenas: 5, needs: [.chill])
    um1.pickCard(card("chill_1"), stats: S, level: 2)
    for l in 3...6 { um1.pickCard(card("chill_4"), stats: S, level: l) }
    _ = um1.drawCards(count: 3, level: 7)
    let without = bonusCount(um1, "chill_4")
    um1.pickCard(card("v16_whiteout"), stats: S, level: 7)
    _ = um1.drawCards(count: 3, level: 8)
    let with = bonusCount(um1, "chill_4")
    check("BR1 bonus never offers Ice Rink (Glacial Drift T5) without Whiteout; with Whiteout it can",
          without == 0 && with > 0, "without=\(without) with=\(with)")

    // BR2 the bridge rule: each bridge with its second colour dormant, then live.
    var bridgeLeaks: [String] = [], bridgeAnchors: [String] = []
    for b in pool where b.secondaryTag != nil {
        guard let second = b.secondaryTag else { continue }
        func setup(_ um: UpgradeManager) {
            for sig in pool where sig.isSignature && tags(b).contains(sig.tag) && um.activeFamilies.contains(sig.tag) {
                um.pickCard(sig, stats: S, level: 2)
            }
            _ = um.drawCards(count: 3, level: 3)
        }
        var dormant: UpgradeManager
        repeat { dormant = run(&seed, arenas: 5, needs: [b.tag]) } while dormant.activeFamilies.contains(second)
        setup(dormant)
        if bonusCount(dormant, b.id) > 0 { bridgeLeaks.append(b.id) }
        let live = run(&seed, arenas: 5, needs: tags(b))
        setup(live)
        if bonusCount(live, b.id, n: 2_000) == 0 { bridgeAnchors.append(b.id) }
    }
    check("BR2 bonus never offers a bridge whose second colour is dormant; with both live each bridge can appear",
          bridgeLeaks.isEmpty && bridgeAnchors.isEmpty, "leaks=\(bridgeLeaks) never-anchored=\(bridgeAnchors)")

    // BR3 capstone lockout: Everglow in progress → no capstone at all from the bonus.
    let um3 = run(&seed, arenas: 5, needs: [.fire, .shock, .chill])
    for sig in ["fire_1", "shock_2", "chill_1"] { um3.pickCard(card(sig), stats: S, level: 2) }
    _ = um3.drawCards(count: 3, level: 3)
    let freeCapstones = bonusAny(um3, n: 2_000) { $0.isCapstone }
    um3.pickCard(card("cap_fire_everglow"), stats: S, level: 3)
    _ = um3.drawCards(count: 3, level: 4)
    let lockedCapstones = bonusAny(um3, n: 2_000) { $0.isCapstone }
    check("BR3 with a capstone in progress the bonus offers NO capstone (not another, not the running one); with none running it can",
          lockedCapstones == 0 && freeCapstones > 0, "locked=\(lockedCapstones) free=\(freeCapstones)")

    // BR4 same-level repeat: the Extra Pick's first selection never comes back this level.
    let um4 = run(&seed, arenas: 5, needs: [.shock])
    um4.pickCard(card("shock_2"), stats: S, level: 2)
    _ = um4.drawCards(count: 3, level: 5)
    um4.pickCard(card("shock_1"), stats: S, level: 5)          // Static T1, taken at level 5
    let sameLevel = bonusCount(um4, "shock_1", n: 2_000)
    _ = um4.drawCards(count: 3, level: 6)
    let nextLevel = bonusCount(um4, "shock_1", n: 2_000)
    check("BR4 a card taken at this level-up is never the bonus at the same level; at the next level it can be",
          sameLevel == 0 && nextLevel > 0, "same=\(sameLevel) next=\(nextLevel)")
    // …and taking ANOTHER card at the next level doesn't drag the old one back
    // into the exclusion: only this level-up's picks are excluded.
    // Chain Lightning T2, taken at level 6 (it still has tiers left, so its
    // exclusion is real, not a maxed card that could never be offered anyway).
    um4.pickCard(card("shock_2"), stats: S, level: 6)
    let olderStillOffered = bonusCount(um4, "shock_1", n: 2_000)
    let newestExcluded = bonusCount(um4, "shock_2", n: 2_000)
    check("BR4b after a pick at the next level, only that level's pick is excluded (the earlier card can still be the bonus)",
          olderStillOffered > 0 && newestExcluded == 0 && um4.tier(of: "shock_2") < card("shock_2").maxTier,
          "older=\(olderStillOffered) newest=\(newestExcluded)")

    // BR5 pity bookkeeping: a gateway the bonus shows counts as offered.
    var resetOK = true, sawWait = false
    for _ in 0..<200 {
        let um = run(&seed, arenas: 5)
        guard let first = um.drawCards(count: 3, level: 2).first(where: { $0.isSignature }) else { continue }
        um.pickCard(first, stats: S, level: 2)
        for l in 3...4 { _ = um.drawCards(count: 3, level: l) }
        guard let b = um.drawBonusCard(excluding: []), b.isSignature else { continue }
        _ = b
        let waits = pool.filter { $0.isSignature && $0.id != b.id && um.tier(of: $0.id) == 0 && um.activeFamilies.contains($0.tag) }
            .map { um.gatewayWait($0.id) }
        if waits.contains(where: { $0 > 0 }) { sawWait = true }
        if um.gatewayWait(b.id) != 0 { resetOK = false }
    }
    check("BR5 a signature shown by the +1 Card resets its gateway-pity wait (others keep waiting)", resetOK && sawWait)
}

// MARK: - EG · the ruled enabler edges through the real draw

/// Is `id` ever offered — by a spread or by the bonus — across `n` levels from this state?
func offered(_ um: UpgradeManager, _ id: String, from level: Int, levels n: Int) -> Bool {
    var seen = false
    for l in level..<(level + n) {
        let spread = um.drawCards(count: 3, level: l)
        if spread.contains(where: { $0.id == id }) { seen = true }
        if um.drawBonusCard(excluding: spread)?.id == id { seen = true }
    }
    return seen
}

do {
    var seed: UInt64 = 120_000
    // EG1 CL-91: Hemorrhage waits for Gouge.
    var before = false, after = 0
    for _ in 0..<20 {
        let um = run(&seed, arenas: 5, needs: [.bleed])
        um.pickCard(card("v21_bloodthirsty"), stats: S, level: 2)
        if offered(um, "bleed_2", from: 3, levels: 60) { before = true }
        um.pickCard(card("bleed_1"), stats: S, level: 63)
        if offered(um, "bleed_2", from: 64, levels: 60) { after += 1 }
    }
    check("EG1 CL-91 Hemorrhage is never offered before Gouge; after Gouge it is (20 runs)", !before && after == 20, "before=\(before) after=\(after)")

    // EG2 CL-92: Frost Touch stops at T2 until Polar Vortex is owned.
    var t3Early = false, t3After = 0
    for _ in 0..<20 {
        let um = run(&seed, arenas: 5, needs: [.chill])
        um.pickCard(card("chill_1"), stats: S, level: 2); um.pickCard(card("chill_1"), stats: S, level: 3)
        if offered(um, "chill_1", from: 4, levels: 60) { t3Early = true }
        um.pickCard(card("cap_chill_polarvortex"), stats: S, level: 64)
        if offered(um, "chill_1", from: 65, levels: 60) { t3After += 1 }
    }
    check("EG2 CL-92 Frost Touch T3 is never offered without Polar Vortex; with it, it is (20 runs)",
          !t3Early && t3After == 20, "early=\(t3Early) after=\(t3After)")

    // EG3 CL-93: Polar Vortex T4 silences the pellet cards; T1–T3 don't; Erasure T4 stays.
    let pellet = ["void_1", "void_2", "v18_mirror_edge", "v18_fracture_shot", "v18_riftline"]
    var grantedEarly = false, grantedAt4 = true, leaks: Set<String> = [], anchors: Set<String> = []
    var erasureT4Offered = 0
    for _ in 0..<20 {
        let um = run(&seed, arenas: 5, needs: [.chill, .voidT])
        um.pickCard(card("chill_1"), stats: S, level: 2); um.pickCard(card("void_3"), stats: S, level: 2)
        for l in 3...5 { um.pickCard(card("cap_chill_polarvortex"), stats: S, level: l) }
        if um.capabilities.contains(.glacialCondensation) { grantedEarly = true }
        for id in pellet where offered(um, id, from: 6, levels: 60) { anchors.insert(id) }
        um.pickCard(card("cap_chill_polarvortex"), stats: S, level: 66)
        if !um.capabilities.contains(.glacialCondensation) { grantedAt4 = false }
        for id in pellet where offered(um, id, from: 67, levels: 60) { leaks.insert(id) }
        um.pickCard(card("cap_chill_polarvortex"), stats: S, level: 127)   // T5: capstones unlock again
        for l in 128...130 { um.pickCard(card("cap_void_erasure"), stats: S, level: l) }   // Erasure T1–T3
        if offered(um, "cap_void_erasure", from: 131, levels: 30) { erasureT4Offered += 1 }
    }
    check("EG3a CL-93 glacialCondensation arrives with Polar Vortex T4, not before", !grantedEarly && grantedAt4)
    check("EG3b CL-93 after T4 no pellet card is offered by either draw; before T4 each one is",
          leaks.isEmpty && anchors == Set(pellet), "leaks=\(leaks.sorted()) anchors=\(anchors.sorted())")
    check("EG3c CL-93 Erasure T4 is still offered with Polar Vortex T4 owned (not blocked)", erasureT4Offered == 20, "\(erasureT4Offered)")
}

// MARK: - PA · Panda through its own scheduler

do {
    var seed: UInt64 = 150_000
    let panda = card("v20_panda")
    check("PA1 Panda is secret, Neutral-tagged, 5 tiers with 5 names", panda.isSecret && panda.tag == .neutral
          && panda.maxTier == 5 && panda.tierNames?.count == 5)

    // Ineligible runs never see it.
    var seenIneligible = false, ineligibleRuns = 0
    for _ in 0..<400 {
        let um = run(&seed, arenas: 5)
        guard !um.pandaEligible else { continue }
        ineligibleRuns += 1
        for l in 2...30 {
            let spread = um.drawCards(count: 3, level: l)
            if spread.contains(where: { $0.isSecret }) || um.drawBonusCard(excluding: spread)?.isSecret == true { seenIneligible = true }
            if let p = spread.first { um.pickCard(p, stats: S, level: l) }
        }
    }
    check("PA2 an ineligible run never sees Panda in a spread or a bonus (\(ineligibleRuns) runs)", !seenIneligible && ineligibleRuns > 300)

    // Eligible: offered every level of the first window until taken, and only there.
    ReviewMode.isActive = true
    let window = GameConfig.Panda.firstOfferWindow
    var windowOK = true, outsideOK = true, bonusNever = true, openerNever = true
    for _ in 0..<50 {
        let um = run(&seed, arenas: 5)
        for l in 2...12 {
            let spread = um.drawCards(count: 3, level: l)
            let has = spread.contains { $0.id == panda.id }
            if window.contains(l) && !has { windowOK = false }
            if !window.contains(l) && has { outsideOK = false }
            if um.drawBonusCard(excluding: spread)?.isSecret == true { bonusNever = false }
            if um.drawCards(count: 1, level: l, allowSecret: false).first?.isSecret == true { openerNever = false }
            if let p = spread.first(where: { !$0.isSecret }) { um.pickCard(p, stats: S, level: l) }
        }
    }
    check("PA3 an eligible run is offered Panda at every level of its first window \(window) and never after, untaken",
          windowOK && outsideOK)
    check("PA4 Panda never comes from the +1 Card or the random opener", bonusNever && openerNever)

    // Taken at level 3: every other level from there, climbing to T5, then gone.
    var scheduleOK = true, reachedT5 = true
    for _ in 0..<50 {
        let um = run(&seed, arenas: 5)
        for l in 2...30 {
            let spread = um.drawCards(count: 3, level: l)
            let has = spread.contains { $0.id == panda.id }
            let tier = um.tier(of: panda.id)
            let due: Bool
            if tier == 0 { due = window.contains(l) }
            else if tier < 5 { due = l > 3 && (l - 3) % 2 == 0 }
            else { due = false }
            if has != due { scheduleOK = false }
            if has && (l == 3 || tier > 0) { um.pickCard(panda, stats: S, level: l) }
            else if let p = spread.first(where: { !$0.isSecret }) { um.pickCard(p, stats: S, level: l) }
        }
        if um.tier(of: panda.id) != 5 { reachedT5 = false }
    }
    ReviewMode.isActive = false
    check("PA5 taken at level 3, Panda returns every other level (5, 7, 9, 11) and only then", scheduleOK)
    check("PA6 the schedule climbs Panda to T5 (50/50 runs)", reachedT5)
}

// MARK: - CT · the Codex tally and the retired registry (CL-102)

do {
    // The v2.0 LIVE pool (tag v2.0-build7): 79 literal ids + Panda.
    let v20: [String] = ["bleed_1","bleed_2","bleed_3","bleed_4","cap_bleed_apex","cap_chill_polarvortex","cap_fire_everglow",
        "cap_guard_ironmaiden","cap_shock_skybeam","cap_void_erasure","chill_1","chill_2","chill_3","chill_4","fire_1","fire_2",
        "fire_3","fire_4","guard_1","guard_2","guard_3","guard_4","neutral_1","neutral_2","neutral_3","neutral_4","neutral_5",
        "neutral_6","shock_1","shock_2","shock_3","shock_4","v13_chain_reaction","v13_execution","v13_glass_engine",
        "v13_magnetic_core","v13_overcharge","v13_phase_skin","v13_static_field","v13_unstable_core","v16_aegis_pulse",
        "v16_arc_wake","v16_blood_price","v16_cauterize","v16_hoarfrost","v16_iron_bloom","v16_live_wire","v16_mass_tax",
        "v16_null_bloom","v16_open_vein","v16_static_crown","v16_whiteout","v17_copper_vein","v17_dead_circuit",
        "v17_grounded_core","v17_induction_step","v17_overclock","v17_relay_burn","v18_bloodlust","v18_false_opening",
        "v18_fracture_shot","v18_glass_blood","v18_mirror_edge","v18_needlepoint","v18_red_smile","v18_riftline",
        "v18_silver_skin","v20_deeproot","v20_richsoil","v20_seed_spore","v20_terra","v20_thornsoil","v20_tree",
        "v20_vinewall","v20_wildbloom","void_1","void_2","void_3","void_4","v20_panda"]
    let live = UpgradeManager.catalogIDs
    let retired = Set(UpgradeManager.retiredCardIDs.keys)
    check("CT1 catalogIDs is the live pool, in pool order", live == pool.map { $0.id })
    check("CT2 8 retired ids, none of them live", retired.count == 8 && retired.isDisjoint(with: live))
    check("CT3 every v2.0-shipped id is live or registered as retired (an unregistered deletion fails here)",
          v20.count == 80 && Set(v20).isSubset(of: Set(live).union(retired)),
          "\(Set(v20).subtracting(Set(live).union(retired)).sorted())")
    let newIDs = Set(live).subtracting(v20)
    let veteran = UpgradeManager.codexTally(offered: v20 + Array(newIDs), liveIDs: live)
    check("CT4 a veteran who saw all 80 v2.0 cards + the 8 new: 80/80 discovered, 8 retired, 0 unknown",
          newIDs.count == 8 && veteran == .init(discovered: 80, total: 80, retired: retired.sorted(), unknown: []), "\(veteran)")
    let v20Only = UpgradeManager.codexTally(offered: v20, liveIDs: live)
    check("CT5 the v2.0 set alone: 72/80, 8 retired", v20Only.discovered == 72 && v20Only.total == 80 && v20Only.retired.count == 8)
    let empty = UpgradeManager.codexTally(offered: [], liveIDs: live)
    check("CT6 a fresh save: 0/80", empty == .init(discovered: 0, total: 80, retired: [], unknown: []))
    let junk = UpgradeManager.codexTally(offered: ["fire_1", "not_a_card", "fire_1"], liveIDs: live)
    check("CT7 an unknown id counts as unknown, never discovered; repeats count once",
          junk == .init(discovered: 1, total: 80, retired: [], unknown: ["not_a_card"]), "\(junk)")
    var rng = UpgradeManager.DrawRandom(seed: 7)
    var bounded = true
    for _ in 0..<500 {
        let sample = (v20 + Array(newIDs) + ["x", "y"]).filter { _ in Bool.random(using: &rng) }
        let t = UpgradeManager.codexTally(offered: sample, liveIDs: live)
        if t.discovered > t.total || t.discovered + t.retired.count + t.unknown.count != Set(sample).count { bounded = false }
    }
    check("CT8 discovered never exceeds the total; every stored id is exactly one of discovered/retired/unknown", bounded)
    // v2.1 geometry Unit 4 (design lock §8): the Splitworks bestiary set — four
    // entries with stable persistence ids, the Marchwarden a boss, Lyra's
    // provisional lines verbatim — and EVERY bestiary line fits the live row
    // wrapper (≤ 3 lines; BestiaryCodexNode wraps at Int((width − 32 − 82) / 6.6),
    // 39 characters on the narrowest 375pt phone).
    func bestiaryLines(_ text: String, _ cap: Int) -> Int {
        var n = 0, cur = 0
        for w in text.split(separator: " ") {
            if cur == 0 { cur = w.count; n += 1 } else if cur + 1 + w.count <= cap { cur += 1 + w.count } else { cur = w.count; n += 1 }
        }
        return n
    }
    let splitworksSet: [(BestiaryFamily, String, Bool, String)] = [
        (.spurhound, "spurhound", false, "It learned the shortest distance between two points. Then it learned to hunt around corners."),
        (.linekeeper, "linekeeper", false, "A firing line given legs. It mistakes patience for permission."),
        (.ramplate, "ramplate", false, "A barricade with forward momentum. The forge forgot that walls should stay put."),
        (.marchwarden, "marchwarden", true, "The march ended long ago. Its warden still clears the road for an army that will never come."),
    ]
    let narrowCap = Int((375.0 - 32 - 82) / 6.6)
    // (Read directly: this group runs before the WR section declares `root`, and
    // top-level globals initialize in source order — the SX15 precedent.)
    let bestiaryNode = SwiftSource.code((try? String(contentsOf: URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
        .appendingPathComponent("Sparkforge/Nodes/BestiaryCodexNode.swift"), encoding: .utf8)) ?? "")
    let wrapperPinned = bestiaryNode.contains("private static let sideMargin: CGFloat = 16")
        && bestiaryNode.contains("let textW = width - 66 - 16")
        && bestiaryNode.contains("for (li, line) in Self.wrap(family.flavor, maxChars: Int(textW / 6.6)).prefix(3).enumerated() {")
    check("CT9 v2.1 geometry Unit 4: the Splitworks bestiary set (Spurhound, Linekeeper, Ramplate, the Marchwarden) with stable ids and the design lock's lines, and every bestiary line fits the live wrapper on the narrowest phone",
          splitworksSet.allSatisfy { $0.0.rawValue == $0.1 && $0.0.isBoss == $0.2 && $0.0.flavor == $0.3 && !$0.0.hiddenUntilFutureVersion }
            && BestiaryFamily.allCases.filter { !$0.hiddenUntilFutureVersion }.allSatisfy { bestiaryLines($0.flavor, narrowCap) <= 3 }
            && narrowCap == 39 && wrapperPinned,
          "cap=\(narrowCap) wrapper=\(wrapperPinned)")
}

// MARK: - AQ · eligibility at ACQUISITION time (Reviewer F1) + CL-93 symmetric (CC-1)
//
// A spread is drawn once; a pick can make the rest of it illegal. The scene's
// Extra Pick path takes the first card through `acquire`, then keeps only
// `stillSelectable` — these checks run that exact production sequence.

let pelletIDs = ["void_1", "void_2", "v18_mirror_edge", "v18_fracture_shot", "v18_riftline"]

/// A full-save run holding the Chill/Guard/Void signatures and Polar Vortex at
/// `pvTier` (so T4 is due at 3), plus `extra` cards already owned.
func acqState(_ um: UpgradeManager, pvTier: Int, extra: [String] = []) -> UpgradeManager {
    for sig in ["chill_1", "guard_2", "void_3"] where um.activeFamilies.contains(card(sig).tag) { um.pickCard(card(sig), stats: S, level: 2) }
    for l in 0..<pvTier { um.pickCard(card("cap_chill_polarvortex"), stats: S, level: 3 + l) }
    for (i, id) in extra.enumerated() { um.pickCard(card(id), stats: S, level: 10 + i) }
    return um
}
func fullSave(seed: UInt64) -> UpgradeManager {
    ProgressionManager.shared.arenasUnlocked = 5
    SettingsManager.shared.bannedFamily = nil
    return UpgradeManager(seed: seed)
}
/// The Extra Pick sequence exactly as the scene runs it: acquire the first,
/// then revalidate the rest. Returns (acquired?, what is still on the table).
func extraPick(_ um: UpgradeManager, first: String, table: [String], level: Int) -> (Bool, [String]) {
    let ok = um.acquire(card(first), stats: S, level: level)
    let rest = table.filter { $0 != first }.map(card)
    return (ok, um.stillSelectable(rest, atLevel: level).map { $0.id })
}

do {
    // AQ1 — the Reviewer's reproduction: seed 1, level 18, full save; the spread
    // holds Fracture Shot, Phase Skin and Polar Vortex T4. (The Reviewer's own
    // pick path to that level-up wasn't in the report, so the run's state is
    // built directly: seed 1's palette holds Chill, Guard and Void, and Polar
    // Vortex sits at T3.)
    let spread = ["v18_fracture_shot", "v13_phase_skin", "cap_chill_polarvortex"]
    let um1 = acqState(fullSave(seed: 1), pvTier: 3)
    let palette = [.chill, .guardT, .voidT].allSatisfy { um1.activeFamilies.contains($0) }
    let allLegal = spread.allSatisfy { um1.isSelectable(card($0), atLevel: 18) }
    let (took, rest) = extraPick(um1, first: "cap_chill_polarvortex", table: spread, level: 18)
    let fractureRefused = !um1.acquire(card("v18_fracture_shot"), stats: S, level: 18) && um1.tier(of: "v18_fracture_shot") == 0
    check("AQ1 Reviewer F1 (seed 1, level 18): take Polar Vortex T4 first → Fracture Shot leaves the table and can't be acquired; Phase Skin stays",
          palette && allLegal && took && um1.tier(of: "cap_chill_polarvortex") == 4 && rest == ["v13_phase_skin"] && fractureRefused,
          "palette=\(palette) legal=\(allLegal) took=\(took) rest=\(rest) refused=\(fractureRefused)")

    // AQ2 — the reverse order: the pellet card first → Polar Vortex T4 goes.
    let um2 = acqState(fullSave(seed: 1), pvTier: 3)
    let (took2, rest2) = extraPick(um2, first: "v18_fracture_shot", table: spread, level: 18)
    let pvRefused = !um2.acquire(card("cap_chill_polarvortex"), stats: S, level: 18) && um2.tier(of: "cap_chill_polarvortex") == 3
    check("AQ2 reverse order (seed 1, level 18): take Fracture Shot first → Polar Vortex T4 leaves the table and can't be acquired (CL-93 symmetric)",
          took2 && rest2 == ["v13_phase_skin"] && pvRefused, "took=\(took2) rest=\(rest2) refused=\(pvRefused)")

    // AQ3 — every pellet card, both orders, same-spread transitions.
    var seed: UInt64 = 200_000
    var bad: [String] = []
    for p in pelletIDs {
        for pvFirst in [true, false] {
            let um = acqState(run(&seed, arenas: 5, needs: [.chill, .guardT, .voidT]), pvTier: 3)
            let table = [p, "v13_phase_skin", "cap_chill_polarvortex"]
            guard table.allSatisfy({ um.isSelectable(card($0), atLevel: 20) }) else { bad.append("\(p) not all legal"); continue }
            let (ok, left) = extraPick(um, first: pvFirst ? "cap_chill_polarvortex" : p, table: table, level: 20)
            if !ok || left != ["v13_phase_skin"] { bad.append("\(p) pvFirst=\(pvFirst) left=\(left)") }
        }
    }
    check("AQ3 all five pellet cards × both orders: whichever is taken first, the other side leaves the table", bad.isEmpty, "\(bad)")

    // AQ4 — a refused acquisition changes nothing.
    let um4 = acqState(fullSave(seed: 1), pvTier: 3, extra: ["v18_riftline"])
    let before = (um4.capabilities, um4.cardTiers, um4.pickedCardIDs)
    let refused4 = !um4.acquire(card("cap_chill_polarvortex"), stats: S, level: 18)
    check("AQ4 a refused acquisition leaves capabilities, tiers and the build untouched",
          refused4 && um4.capabilities == before.0 && um4.cardTiers == before.1 && um4.pickedCardIDs == before.2)

    // AQ5 — nothing legal left → the Extra Pick resolves (the scene finishes the level-up).
    let um5 = acqState(fullSave(seed: 1), pvTier: 3)
    let (took5, rest5) = extraPick(um5, first: "cap_chill_polarvortex", table: ["cap_chill_polarvortex", "v18_fracture_shot", "void_1"], level: 18)
    check("AQ5 when the first pick leaves nothing legal, nothing remains to choose (no dead choice)", took5 && rest5.isEmpty, "\(rest5)")

    // AQ6 — the scheduled seats keep their own rules, never the ordinary one.
    let um6 = fullSave(seed: 1)
    for sig in ["chill_1", "void_3"] { um6.pickCard(card(sig), stats: S, level: 2) }
    um6.pickCard(card("cap_chill_polarvortex"), stats: S, level: 3)            // active at T1
    let seatOK = um6.isSelectable(card("cap_chill_polarvortex"), atLevel: 4)
    let otherLocked = !um6.allCards.filter { $0.isCapstone && $0.id != "cap_chill_polarvortex" }
        .contains { um6.isSelectable($0, atLevel: 4) }
    ReviewMode.isActive = true
    let umP = fullSave(seed: 3)
    let pandaAt = (2...9).filter { umP.isSelectable(card("v20_panda"), atLevel: $0) }
    ReviewMode.isActive = false
    check("AQ6 scheduled seats: the active capstone stays selectable (others locked out); Panda only in its window 2...5",
          seatOK && otherLocked && pandaAt == [2, 3, 4, 5], "seat=\(seatOK) locked=\(otherLocked) panda=\(pandaAt)")

    // AQ7 — Brandon, Sep 25: two capstones on one table; taking one removes the other.
    var seed7: UInt64 = 210_000
    let um7 = run(&seed7, arenas: 5, needs: [.fire, .shock])
    for sig in ["fire_1", "shock_2"] { um7.pickCard(card(sig), stats: S, level: 2) }
    let (took7, rest7) = extraPick(um7, first: "cap_fire_everglow", table: ["cap_fire_everglow", "cap_shock_skybeam", "shock_1"], level: 8)
    check("AQ7 two capstones in one spread: taking Everglow removes Skybeam (lockout), the ordinary card stays", took7 && rest7 == ["shock_1"], "\(rest7)")

    // AQ8 — Brandon, Sep 25: a STALLED capstone releases the lockout and loses the guarantee.
    var seed8: UInt64 = 220_000
    var pvSeen = false, pvSelectable = false, otherCapstoneSeen = 0, everglowLevels: [Int] = []
    for _ in 0..<20 {
        let um = acqState(run(&seed8, arenas: 5, needs: [.chill, .voidT, .fire]), pvTier: 3, extra: ["void_1"])   // Warp owned → PV stalls at T3
        um.pickCard(card("fire_1"), stats: S, level: 2)
        var everglowAt: Int? = nil
        for level in 20...59 {
            let spread = um.drawCards(count: 3, level: level)
            if spread.contains(where: { $0.id == "cap_chill_polarvortex" }) || um.drawBonusCard(excluding: spread)?.id == "cap_chill_polarvortex" { pvSeen = true }
            if um.isSelectable(card("cap_chill_polarvortex"), atLevel: level) { pvSelectable = true }
            if spread.contains(where: { $0.isCapstone && $0.id != "cap_chill_polarvortex" }) { otherCapstoneSeen += 1 }
            if everglowAt == nil, spread.contains(where: { $0.id == "cap_fire_everglow" }) {
                _ = um.acquire(card("cap_fire_everglow"), stats: S, level: level); everglowAt = level; continue
            }
            if let at = everglowAt, level > at, spread.contains(where: { $0.id == "cap_fire_everglow" }), everglowLevels.count < 6 { everglowLevels.append(level % 2) }
            if let p = spread.first(where: { !$0.isCapstone }) { _ = um.acquire(p, stats: S, level: level) }
        }
    }
    check("AQ8 stalled Polar Vortex (Warp owned, T3): never offered or selectable again; other capstones appear and the next one gets its every-other-level guarantee",
          !pvSeen && !pvSelectable && otherCapstoneSeen > 20 && !everglowLevels.isEmpty && everglowLevels.allSatisfy { $0 == 0 },
          "pvSeen=\(pvSeen) pvSel=\(pvSelectable) others=\(otherCapstoneSeen) everglowParities=\(everglowLevels)")

    // SY1 — CC-1 through the real draws: owning a pellet card leaves Polar Vortex T1–T3 open and closes T4.
    var seedS: UInt64 = 230_000
    var earlyOpen: [String] = [], t4Leaks: [String] = []
    for p in pelletIDs {
        let um = acqState(run(&seedS, arenas: 5, needs: [.chill, .voidT, .guardT]), pvTier: 0, extra: [p])
        if !offered(um, "cap_chill_polarvortex", from: 30, levels: 60) { earlyOpen.append(p) }
        for l in 0..<3 { um.pickCard(card("cap_chill_polarvortex"), stats: S, level: 100 + l) }
        if offered(um, "cap_chill_polarvortex", from: 110, levels: 60)
            || (110..<170).contains(where: { um.isSelectable(card("cap_chill_polarvortex"), atLevel: $0) }) { t4Leaks.append(p) }
    }
    check("SY1 CL-93 symmetric: with each pellet card owned, Polar Vortex T1 is still offered, and its T4 is never offered or selectable (60 levels, both draws)",
          earlyOpen.isEmpty && t4Leaks.isEmpty, "notOfferedEarly=\(earlyOpen) t4Leaks=\(t4Leaks)")
}

// MARK: - SL · the same-level exclusion on every draw path (Reviewer F2)

do {
    // SL1 — the Reviewer's reproduction: seed 5, level 2.
    let um = fullSave(seed: 5)
    let spread = um.drawCards(count: 3, level: 2).map { $0.id }
    let exact = spread == ["guard_2", "fire_1", "void_3"]
    let (took, _) = extraPick(um, first: "guard_2", table: spread, level: 2)
    var rerollLeak = 0, bonusLeak = 0, others: Set<String> = []
    for _ in 0..<300 {
        let rr = um.drawCards(count: 3, level: 2)
        if rr.contains(where: { $0.id == "guard_2" }) { rerollLeak += 1 }
        if um.drawBonusCard(excluding: rr)?.id == "guard_2" { bonusLeak += 1 }
        others.formUnion(rr.map { $0.id })
    }
    check("SL1 Reviewer F2 (seed 5, level 2): after Repulse is taken via Extra Pick, 300 rerolls and bonuses never offer it again this level-up",
          exact && took && rerollLeak == 0 && bonusLeak == 0, "spread=\(spread) took=\(took) reroll=\(rerollLeak) bonus=\(bonusLeak)")
    check("SL2 …while other cards stay eligible (the rerolls still vary)", others.count > 10, "\(others.count)")
    var nextLevel = 0
    for _ in 0..<300 where um.drawCards(count: 3, level: 3).contains(where: { $0.id == "guard_2" }) { nextLevel += 1 }
    check("SL3 the exclusion resets for the next level-up (Repulse can come back at level 3)", nextLevel > 0, "\(nextLevel)")

    // SL4 — ordinary pick → reroll, and bonus pick → reroll, over many seeded runs.
    var seed: UInt64 = 240_000
    var ordinaryLeak = 0, bonusPickLeak = 0, bonusTaken = 0
    for _ in 0..<300 {
        let u = run(&seed, arenas: 5)
        for level in 2...25 {
            let sp = u.drawCards(count: 3, level: level)
            guard let first = sp.first else { continue }
            _ = u.acquire(first, stats: S, level: level)
            for _ in 0..<3 where u.drawCards(count: 3, level: level).contains(where: { $0.id == first.id }) { ordinaryLeak += 1 }
            if let b = u.drawBonusCard(excluding: sp), u.acquire(b, stats: S, level: level) {
                bonusTaken += 1
                for _ in 0..<3 where u.drawCards(count: 3, level: level).contains(where: { $0.id == b.id }) { bonusPickLeak += 1 }
            }
        }
    }
    check("SL4 ordinary pick → reroll and bonus pick → reroll never re-offer the taken card that level-up (\(bonusTaken) bonus picks)",
          ordinaryLeak == 0 && bonusPickLeak == 0 && bonusTaken > 1_000, "ordinary=\(ordinaryLeak) bonus=\(bonusPickLeak)")

    // SL5 — the scheduled seats obey it too: a guaranteed capstone or Panda taken this level-up is not re-seated by a reroll.
    var seed5: UInt64 = 250_000
    let uc = run(&seed5, arenas: 5, needs: [.fire])
    uc.pickCard(card("fire_1"), stats: S, level: 2)
    uc.pickCard(card("cap_fire_everglow"), stats: S, level: 9)             // active; due at even levels
    let seated = uc.drawCards(count: 3, level: 10).contains { $0.id == "cap_fire_everglow" }
    _ = uc.acquire(card("cap_fire_everglow"), stats: S, level: 10)
    let reseated = (0..<50).contains { _ in uc.drawCards(count: 3, level: 10).contains { $0.id == "cap_fire_everglow" } }
    // …and acquisition refuses it too (the seat's own rule answers to the taken set).
    let capRetake = uc.isSelectable(card("cap_fire_everglow"), atLevel: 10) || uc.acquire(card("cap_fire_everglow"), stats: S, level: 10)
    let capTier = uc.tier(of: "cap_fire_everglow")
    // Panda: activated at 3, its next seat is level 5 — take it there, then reroll level 5.
    ReviewMode.isActive = true
    let up = fullSave(seed: 3)
    _ = up.drawCards(count: 3, level: 3)
    _ = up.acquire(card("v20_panda"), stats: S, level: 3)
    _ = up.drawCards(count: 3, level: 4)
    let pandaSeated = up.drawCards(count: 3, level: 5).contains { $0.id == "v20_panda" }
    _ = up.acquire(card("v20_panda"), stats: S, level: 5)
    let pandaReseated = (0..<50).contains { _ in up.drawCards(count: 3, level: 5).contains { $0.id == "v20_panda" } }
    let pandaRetake = up.isSelectable(card("v20_panda"), atLevel: 5) || up.acquire(card("v20_panda"), stats: S, level: 5)
    let pandaTier = up.tier(of: "v20_panda")
    ReviewMode.isActive = false
    check("SL5 the capstone guarantee and the Panda seat are not re-seated by a reroll after being taken that level-up",
          seated && !reseated && pandaSeated && !pandaReseated, "cap=\(seated)/\(reseated) panda=\(pandaSeated)/\(pandaReseated)")
    check("SL6 …nor selectable or acquirable again that level-up (a scheduled seat answers to the taken set too)",
          !capRetake && capTier == 2 && !pandaRetake && pandaTier == 2, "cap=\(capRetake) T\(capTier) panda=\(pandaRetake) T\(pandaTier)")
}

// MARK: - PB · production boundaries the Reviewer's mutations slipped past (F3)

do {
    // PB-A — the capstone guarantee cadence, as an explicit level sequence.
    var seed: UInt64 = 260_000
    let ua = run(&seed, arenas: 5, needs: [.fire, .shock])
    for sig in ["fire_1", "shock_2"] { ua.pickCard(card(sig), stats: S, level: 2) }
    ua.pickCard(card("cap_fire_everglow"), stats: S, level: 10)
    var seen: [Int] = []
    for level in 11...30 {
        let sp = ua.drawCards(count: 3, level: level)
        if sp.contains(where: { $0.id == "cap_fire_everglow" }) { seen.append(level) }
        if let p = sp.first(where: { !$0.isCapstone }) { _ = ua.acquire(p, stats: S, level: level) }
    }
    check("PB-A1 one active capstone is offered at exactly the even levels 12, 14 … 30 (every other level)",
          seen == Array(stride(from: 12, through: 30, by: 2)), "\(seen)")
    let ub = run(&seed, arenas: 5, needs: [.fire, .shock])
    for sig in ["fire_1", "shock_2"] { ub.pickCard(card(sig), stats: S, level: 2) }
    for c in ["cap_fire_everglow", "cap_shock_skybeam"] { ub.pickCard(card(c), stats: S, level: 10) }
    let order = ub.allCards.filter { ["cap_fire_everglow", "cap_shock_skybeam"].contains($0.id) }.map { $0.id }
    var first: [Int] = [], second: [Int] = []
    for level in 11...30 {
        let sp = ub.drawCards(count: 3, level: level)
        if sp.contains(where: { $0.id == order[0] }) { first.append(level) }
        if sp.contains(where: { $0.id == order[1] }) { second.append(level) }
        if let p = sp.first(where: { !$0.isCapstone }) { _ = ub.acquire(p, stats: S, level: level) }
    }
    check("PB-A2 two active capstones take offset parities: the first at 12, 14 … 30, the second at 11, 13 … 29",
          first == Array(stride(from: 12, through: 30, by: 2)) && second == Array(stride(from: 11, through: 29, by: 2)),
          "first=\(first) second=\(second)")

    // PB-B — Panda's schedule, both parities, explicit sequences.
    ReviewMode.isActive = true
    let expected: [Int: [Int]] = [2: [4, 6, 8, 10], 3: [5, 7, 9, 11], 4: [6, 8, 10, 12], 5: [7, 9, 11, 13]]
    var pandaBad: [String] = []
    for (activation, want) in expected.sorted(by: { $0.key < $1.key }) {
        let u = fullSave(seed: 7)
        var got: [Int] = []
        for level in 2...16 {
            let sp = u.drawCards(count: 3, level: level)
            let has = sp.contains { $0.id == "v20_panda" }
            if level == activation, has { _ = u.acquire(card("v20_panda"), stats: S, level: level); continue }
            if level > activation, has { got.append(level); _ = u.acquire(card("v20_panda"), stats: S, level: level); continue }
            if let p = sp.first(where: { !$0.isSecret }) { _ = u.acquire(p, stats: S, level: level) }
        }
        if got != want || u.tier(of: "v20_panda") != 5 { pandaBad.append("taken at \(activation): got \(got) (T\(u.tier(of: "v20_panda")))") }
    }
    ReviewMode.isActive = false
    check("PB-B Panda taken at 2 / 3 / 4 / 5 returns at exactly [4,6,8,10] / [5,7,9,11] / [6,8,10,12] / [7,9,11,13] and reaches T5",
          pandaBad.isEmpty, "\(pandaBad)")

    // PB-C — a new run clears every run-scoped prerequisite, and nothing lifetime.
    CodexManager.shared.resetAll()
    CodexManager.shared.recordCardOffered("fire_1")
    var seedC: UInt64 = 270_000
    let uc = run(&seedC, arenas: 5, needs: [.chill, .voidT, .bleed])
    for sig in ["chill_1", "void_3", "v21_bloodthirsty"] { uc.pickCard(card(sig), stats: S, level: 2) }
    for id in ["bleed_1", "chill_4", "v16_whiteout", "void_2"] { uc.pickCard(card(id), stats: S, level: 5) }
    for l in 6...9 { uc.pickCard(card("cap_chill_polarvortex"), stats: S, level: l) }   // polarVortex + glacialCondensation
    let hadCaps = uc.capabilities.count, arenas = ProgressionManager.shared.arenasUnlocked
    let ban = SettingsManager.shared.bannedFamily
    if let c = uc.drawCards(count: 3, level: 10).first { _ = uc.acquire(c, stats: S, level: 10) }
    uc.reset()
    let openingOK = uc.drawCards(count: 3, level: 2).allSatisfy { $0.isSignature || $0.isSecret }
    check("PB-C reset(): every run-scoped capability, tier and pick is cleared (the next spread is the signature opening); lifetime state is kept",
          hadCaps >= 10 && uc.capabilities.isEmpty && uc.cardTiers.isEmpty && uc.pickedCardIDs.isEmpty && !uc.runHoldsSignature && openingOK
              && ProgressionManager.shared.arenasUnlocked == arenas && SettingsManager.shared.bannedFamily == ban
              && CodexManager.shared.hasOfferedCard("fire_1"),
          "had=\(hadCaps) caps=\(uc.capabilities) tiers=\(uc.cardTiers.count)")

    // PB-D — the REAL Codex records a real offer (the production path the scene calls).
    CodexManager.shared.resetAll()
    let ud = fullSave(seed: 13)
    let shown = ud.drawCards(count: 3, level: 2)
    let unshown = ud.allCards.first { c in !shown.contains { $0.id == c.id } }?.id ?? "none"
    let before = shown.map { CodexManager.shared.hasOfferedCard($0.id) }
    ud.recordDiscovered(shown)
    ud.recordDiscovered([card("cap_fire_everglow")])      // the random opener's grant path
    let after = shown.allSatisfy { CodexManager.shared.hasOfferedCard($0.id) }
    check("PB-D a spread passed to recordDiscovered is recorded in the real Codex (and a granted card too); an unshown card is not",
          !before.contains(true) && after && CodexManager.shared.hasOfferedCard("cap_fire_everglow") && !CodexManager.shared.hasOfferedCard(unshown))
    CodexManager.shared.resetAll()                          // leave no discovery behind on the host
}

// MARK: - CP · the approved copy (CL-100/101, Brandon Sep 25) — exact, and it fits

/// The selection card's wrap: 17 characters a line, greedy by word.
func faceLines(_ text: String) -> Int {
    var n = 0, cur = 0
    for w in text.split(separator: " ") {
        if cur == 0 { cur = w.count; n += 1 } else if cur + 1 + w.count <= 17 { cur += 1 + w.count } else { cur = w.count; n += 1 }
    }
    return n
}
/// Every face a player can see: the description, then the NEXT tier's line
/// once owned (the T1 rung is modal-only, never a face).
func faces(_ c: Card) -> [(String, String)] {
    [("desc", c.description)] + (c.tierDescriptions ?? []).enumerated().dropFirst().map { ("T\($0.offset + 1)", $0.element) }
}

do {
    func tierLine(_ id: String, _ t: Int) -> String? { card(id).tierDescriptions.map { $0[t - 1] } }
    let approved: [(String, String?, String)] = [
        ("cap_fire_everglow T3", tierLine("cap_fire_everglow", 3), "Ragekindled: getting hit grows the pulse"),
        ("cap_fire_everglow T4", tierLine("cap_fire_everglow", 4), "Living Furnace: pulse ×2; getting hit grows ATK"),
        ("cap_fire_everglow T5", tierLine("cap_fire_everglow", 5), "Everglow: erupt for 500% ATK every 20s"),
        ("cap_bleed_apex T2", tierLine("cap_bleed_apex", 2), "Bloodfed: +5 max HP per 10 kills; HP feeds ATK"),
        ("cap_bleed_apex T3", tierLine("cap_bleed_apex", 3), "Bloodhound: bat favors bleeders, executes the weak"),
        ("cap_bleed_apex T4", tierLine("cap_bleed_apex", 4), "Marked: bosses at once, foes after 10s: +35%"),   // A7b S6 G2-5
        ("cap_bleed_apex T5", tierLine("cap_bleed_apex", 5), "The Hunter: hits charge an execute pounce"),
        ("cap_void_erasure T2", tierLine("cap_void_erasure", 2), "Void-Touched: ignore shields; lurch more often"),
        ("cap_void_erasure T3", tierLine("cap_void_erasure", 3), "Rift Cannon: every 3rd lurch, a 300% ATK beam"),
        ("cap_void_erasure T4", tierLine("cap_void_erasure", 4), "Echo: shots echo 1.5s later from afar (50% damage)"),
        ("cap_void_erasure T5", tierLine("cap_void_erasure", 5), "Event Horizon: a timer erases the arena, then you"),
        ("cap_void_erasure detail", card("cap_void_erasure").detail, "Lurch cooldown: 2s, or 1.2s from T2. T5 in Arenas 1-10: 37.5s, then 52.5s."),
        // CL-93 symmetric, Brandon's wording (Sep 25), in the full Polar Vortex detail.
        ("cap_chill_polarvortex detail", card("cap_chill_polarvortex").detail, "Impaired: slowed, frozen or stunned. T3: the storm follows you and adds 1 Chill a second. T4: the icicle (200% damage) replaces your shot; Erasure's Echo stops. T4 is mutually exclusive with Warp Shot, Gravity Well, Mirror Edge, Fracture Shot and Riftline: whichever side you own first blocks the other. T5: 5 Chill freezes an enemy for 3s; then it takes +100% damage for 4s. Mini-bosses are slowed 85% instead of frozen, then take +50%. The storm ignores bosses."),
        ("cap_chill_polarvortex T2", tierLine("cap_chill_polarvortex", 2), "Brittle Cold: 5 shards; +40% vs impaired foes"),
        ("cap_chill_polarvortex T3", tierLine("cap_chill_polarvortex", 3), "Windchill: storm slows 30%, adds Chill"),
        ("cap_chill_polarvortex T4", tierLine("cap_chill_polarvortex", 4), "Glacial Condensation: 3 shots → 1 icicle"),
        ("cap_chill_polarvortex T5", tierLine("cap_chill_polarvortex", 5), "Polar Vortex: storm ×2.1; 5 Chill freezes"),
        ("cap_shock_skybeam T2", tierLine("cap_shock_skybeam", 2), "Extended Circuit: lasso damage and range doubled"),
        ("cap_shock_skybeam T3", tierLine("cap_shock_skybeam", 3), "Homing Beacon: your shots favor the lassoed prey"),
        ("cap_shock_skybeam T4", tierLine("cap_shock_skybeam", 4), "Heaven's Call: prey lassoed 2s takes +35% damage"),
        ("cap_shock_skybeam T5", tierLine("cap_shock_skybeam", 5), "Skybeam: every 5s a 300% ATK strike with splash"),
        ("cap_guard_ironmaiden T2", tierLine("cap_guard_ironmaiden", 2), "Barbed Armor: Thorns +240%; more DEF→damage"),
        ("cap_guard_ironmaiden T3", tierLine("cap_guard_ironmaiden", 3), "Retaliate: return 150% of the hit"),
        ("cap_guard_ironmaiden T4", tierLine("cap_guard_ironmaiden", 4), "Kinetic Reserve: 200% DEF burst at 4"),
        ("cap_guard_ironmaiden T5", tierLine("cap_guard_ironmaiden", 5), "Iron Maiden: +15% DEF; energy fires every 20s"),
        ("v16_whiteout T3", tierLine("v16_whiteout", 3), "Damaging a snowman melts it: normals die"),
        ("chill_1 T3", tierLine("chill_1", 3), "Shards apply it too (with Polar Vortex)"),
        ("chill_1 detail", card("chill_1").detail, "T3: Iceburst shards and icicle fragments apply Frost Touch on hit. T3 requires Polar Vortex."),
        ("v13_phase_skin face", card("v13_phase_skin").description, "Ignore the next hit and gain 1s invulnerability (3.5s cd)"),
        ("v18_mirror_edge face", card("v18_mirror_edge").description, "Shots have a 35% chance to echo for 50% damage."),
        ("v13_unstable_core face", card("v13_unstable_core").description, "Every 4s, a burst hurts nearby enemies and you"),
        // A7b S11 (CL-120 B1′, its copy approved Sep 28): the burst can't hurt you when it struck nothing.
        ("v13_unstable_core detail", card("v13_unstable_core").detail, "Every 4s, deal 2 damage to enemies within 60pt. Each burst also costs you 10 HP minus your DEF (at least 1). With nothing in range, it can't hurt you."),
        ("neutral_3 face", card("neutral_3").description, "+11% attack speed"),
        ("neutral_6 face", card("neutral_6").description, "+1 projectile (two parallel shots)"),
        ("neutral_6 T1 rung", tierLine("neutral_6", 1), "+1 projectile (two parallel shots)"),
    ]
    let wrong = approved.filter { $0.1 != $0.2 }.map { $0.0 }
    check("CP1 the approved faces and short details are in place, exactly (\(approved.count) strings)", wrong.isEmpty, "\(wrong)")
    let longDetails: [(String, String)] = [
        // A7b S11 (CL-121 C2 copy gate; Brandon's pick E1, Oct 1): the pulse's boss exclusion, said outright.
        ("cap_fire_everglow", "The pulse skips bosses; mini-bosses take half. Bosses and mini-bosses take half eruption damage."),
        ("cap_bleed_apex", "Bosses and mini-bosses take half bat damage and half the Marked bonus."),
        ("cap_chill_polarvortex", "Mini-bosses are slowed 85% instead of frozen, then take +50%. The storm ignores bosses."),
        ("cap_shock_skybeam", "Bosses and mini-bosses take half Skybeam damage and half the +35%."),
        ("cap_guard_ironmaiden", "The +5% and +15% DEF are one-time grants of at least +1. Retaliate has a 1s cooldown. Bosses and mini-bosses take 50% less thorn and Retaliate damage."),
        ("shock_2", "Hits on bosses never chain, and jumps never strike bosses."),
        ("shock_4", "Mini-bosses are stunned for 0.25s, or 0.5s with maxed Chain Lightning. Arena bosses are immune."),
        ("v17_relay_burn", "within 90pt, dealing 4 damage. Arcs don't chain."),
        ("v18_mirror_edge", "Echoes don't echo, split or leave pull zones, and aren't primary hits."),
        ("v18_false_opening", "slowing them 30% for 1.2s. 1.1s cooldown."),
    ]
    let badDetail = longDetails.filter { !(card($0.0).detail ?? "").hasSuffix($0.1) }.map { $0.0 }
    check("CP2 the approved long details are in place (each checked by its closing sentence)", badDetail.isEmpty, "\(badDetail)")

    let synergy: [(Tag, Int, String)] = [
        (.fire, 5, "Burns last 4s, spread farther and hit harder"),
        (.fire, 7, "Non-boss enemies take fire damage over time"),
        (.shock, 3, "Lightning chains to 1 additional enemy"),
        (.guardT, 5, "Reflect 150% of contact damage; bosses take half"),
        (.growth, 5, "Your ground heals 3 HP per tick"),
    ]
    let synWrong = synergy.filter { s in
        UpgradeManager.synergyTiers(for: s.0).first { $0.threshold == s.1 }?.effect != s.2 || faceLines(s.2) > 3
    }.map { "\($0.0.rawValue) ×\($0.1)" }
    check("CP3 the approved synergy lines are in place and fit the Codex chip (3 × 17)", synWrong.isEmpty, "\(synWrong)")

    // Deferred copy must NOT have moved (it waits for its A7b behaviour).
    // A7b S7 (authorized re-pin, Sep 30): Permafrost's behaviour has landed
    // (CL-94 94a), so it now carries its approved G2-1 copy; the Shatter (CL-99)
    // and Rootbound (CL-96) assertions below are unchanged.
    // A7b S10 (re-pin with Brandon's S9+S10 go, Oct 1): Shatter's behaviour has
    // landed (CL-99/CL-118), so it now carries its approved G2-2 copy (CP7 holds
    // the whole Chill batch); Rootbound's assertion is unchanged.
    check("CP4 Permafrost carries its approved G2-1 copy (A7b S7, CL-94) and Shatter its G2-2 copy (A7b S10, CL-99); Rootbound's (CL-96) is untouched",
          card("chill_3").description == "Hits deal +25% to slowed enemies"
              && card("chill_3").detail == "Your projectiles and Red Smile sweeps deal 25% more damage to slowed enemies, whatever slowed them. Damage between whole numbers rounds up by chance."
              && UpgradeManager.synergyTiers(for: .chill).first { $0.threshold == 5 }?.effect == "Slowed foes may shatter (elites: 20% HP)"
              && UpgradeManager.synergyTiers(for: .growth).first { $0.threshold == 3 }?.effect == "Cultivated ground grips harder — enemies on it are slower")
    // A7b S10 (Group 2, approved Sep 28; each string lands with its behaviour):
    // the Chill copy batch — G2-2 Shatter and G2-3 Absolute Zero (each one Codex
    // chip of 3 × 17 AND one modal line of 40, so Polar Vortex stays at 665pt,
    // MD2), G2-4 Glacial Drift's detail, G2-6 Whiteout's detail — exactly as
    // approved. The faces don't change (boss rules live in details).
    // A7b S11 (the ruled copy gates; Brandon's picks, Oct 1): Erasure's T1 rung
    // states the lone-boss fallback and its reduction (CL-119 A1, never "bosses
    // too"), and Unstable Core's approved CL-120 sentence closes its detail (CP1);
    // Everglow's C2 wording is CP2's. Both capstone modals keep their heights
    // (MD1: Erasure 665pt, Everglow 652pt).
    check("CP8 A7b S11 Erasure's T1 rung says the boss lurch is a lone-boss fallback at 50% (CL-119 A1), as approved",
          card("cap_void_erasure").tierDescriptions?.first == "Unstable: hits charge the void; full meter → a lurch (a lone boss: 50%)"
              && !(card("cap_void_erasure").tierDescriptions ?? []).joined().contains("bosses too"))
    let chillLines = UpgradeManager.synergyTiers(for: .chill)
    let chillBatch = [chillLines.first { $0.threshold == 5 }?.effect, chillLines.first { $0.threshold == 7 }?.effect]
    check("CP7 A7b S10 the Chill copy batch G2-2/3/4/6 is exactly the approved text, each synergy line one chip (3 × 17) and one modal line (≤ 40); the faces are untouched",
          chillBatch == ["Slowed foes may shatter (elites: 20% HP)", "Non-boss foes slow; shatters come easy"]
              && chillBatch.allSatisfy { ($0 ?? "").count <= 40 && faceLines($0 ?? "") <= 3 }
              && card("chill_4").detail == "Trail time is per patch of ground. T4's frozen ground lasts for the arena. T5 Ice Rink: freeze the arena, slowing non-boss enemies by 50% and increasing your movement speed by 25%. Replaces your chill trail. Requires Whiteout."
              && card("v16_whiteout").detail == "Hits have a 12% chance to turn an enemy into a snowman for 3s (elites for half as long). Each enemy can transform once every 10s. T3: damaging a snowman melts it. Normal enemies die instantly; elites take an additional 20% of max HP as damage. Bosses cannot become snowmen."
              && card("chill_4").tierDescriptions?.last == "Ice Rink: enemies -50% speed, you +25%"
              && card("v16_whiteout").tierDescriptions?.first == "Hits have a 12% chance to make a snowman (3s)",
          "\(chillBatch)")

    // Fit, catalog-wide: every face fits its budget (3 beside a MORE detail, 4
    // without), except the known pre-existing Growth overflows (untouched by
    // design). A NEW overflow — or a fixed one — changes this set and fails here.
    var overflow: Set<String> = []
    for c in draftable {
        let budget = c.detail == nil ? 4 : 3
        for (label, text) in faces(c) where faceLines(text) > budget { overflow.insert("\(c.id) \(label)") }
    }
    let knownGrowth: Set<String> = ["v20_terra desc", "v20_tree T5", "v20_vinewall desc", "v20_vinewall T3",
                                    "v20_seed_spore desc", "v20_seed_spore T3"]
    check("CP5 every face in the catalog fits its budget, except the 6 known pre-existing Growth overflows",
          overflow == knownGrowth, "unexpected=\(overflow.subtracting(knownGrowth).sorted()) fixed=\(knownGrowth.subtracting(overflow).sorted())")
    var synOver: Set<String> = []
    for t in colours { for s in UpgradeManager.synergyTiers(for: t) where faceLines(s.effect) > 3 { synOver.insert("\(t.rawValue)_\(s.threshold)") } }
    check("CP6 every synergy line fits the Codex chip, except the known A9 set (CL-111: Growth ×3, Guard ×7, Void ×3/×5/×7)",
          synOver == ["Growth_3", "Guard_7", "Void_3", "Void_5", "Void_7"], "\(synOver.sorted())")
}

// MARK: - SX · the shared source sanitizer, executed (v2.1 A7b corrective 2)
//
// tools/signature-draw-harness/SwiftSource.swift is what every source-reading
// harness (catalog, guard, redsmile, void) matches against, so it is proven
// here on fixtures: comments of every kind go, string literals of every kind
// stay, the shape view is aligned, and Block measures structure.
do {
    // Comments are BLANKED, one space per character, newlines kept (corrective 4).
    func blanks(_ n: Int) -> String { String(repeating: " ", count: n) }
    let comments: [(String, String)] = [
        ("a() // line", "a() " + blanks(7)),
        ("b() /* block */ c()", "b() " + blanks(11) + " c()"),
        ("/* outer /* nested */ still comment */ d()", blanks(38) + " d()"),
        ("/* a\n   multi-line\n   block */ e()", blanks(4) + "\n" + blanks(13) + "\n" + blanks(11) + " e()"),
    ]
    let badComments = comments.filter { SwiftSource.code($0.0) != $0.1 }.map { $0.0 }
    check("SX1 line, block, NESTED block and multi-line block comments are blanked character for character (newlines kept)", badComments.isEmpty, "\(badComments)")
    let strings = [
        "let s = \"keep // this /* and this */\"",
        "let t = \"esc \\\" // still string\"",
        "let u = \"interp \\(f(\"x // y\")) done\"",
        "let m = \"\"\"\n    multi // kept\n    /* kept */\n    \"\"\"",
        "let r = #\"raw \"// kept\" \"#",
    ]
    let badStrings = strings.filter { SwiftSource.code($0) != $0 }
    let trailing = SwiftSource.code("let u = \"interp \\(f(\"x // y\")) done\" // gone")
    check("SX2 comment markers inside string literals are NOT comments: plain, escaped, interpolated, multi-line and raw strings survive intact",
          badStrings.isEmpty && trailing == "let u = \"interp \\(f(\"x // y\")) done\" " + blanks(7), "\(badStrings) \(trailing)")
    let text = "x = \"{ } }\" { y } // z {"
    check("SX3 the shape view is the code view with string contents blanked, character for character",
          SwiftSource.shape(text) == "x = \"     \" { y } " + blanks(6) && SwiftSource.code(text).count == SwiftSource.shape(text).count
            && SwiftSource.code(text).count == text.count)
    let fn = "func f() {\n  guard ok else { return }\n  if c {\n    g()\n  }\n  h() /* { */\n  _ = \"}\"\n}\nfunc k() {}"
    let b = SwiftSource.block(in: fn, after: "func f(")
    let g = b?.offsets(of: "g()").first, h = b?.offsets(of: "h()").first
    check("SX4 Block: body bounds, brace depth, the enclosing block and the returns before a point (braces in comments and strings ignored)",
          b != nil && g != nil && h != nil
            && b.map { $0.depth(at: g ?? 0) == 2 && $0.depth(at: h ?? 0) == 1 && $0.returns(before: h ?? 0) == 1 } == true
            && b.map { String($0.code[($0.enclosingOpen(of: g ?? 0) ?? 0)...]).hasPrefix("{\n    g()") } == true
            && b.map { $0.text.hasSuffix("_ = \"}\"\n}") } == true)

    // Corrective 3: the EXECUTABLE view — what the structural checks search.
    func calls(_ source: String, _ needle: String = "apexRegisterAttack()") -> Int {
        SwiftSource.block(in: "func f() {\n" + source + "\n}", after: "func f(")?.executableOffsets(of: needle).count ?? -1
    }
    check("SX5 call-looking text in strings is not executable (plain, escaped, interpolated, multi-line, raw); a live call is",
          calls("let s = \"apexRegisterAttack()\"") == 0 && calls("let s = \"x \\\" apexRegisterAttack()\"") == 0
            && calls("let s = \"\\(x) apexRegisterAttack()\"") == 0
            && calls("_ = \"\"\"\n    apexRegisterAttack()\n    \"\"\"") == 0 && calls("let r = #\"apexRegisterAttack()\"#") == 0
            && calls("    apexRegisterAttack()") == 1 && calls("    let s = \"x\"; apexRegisterAttack()") == 1)
    let pp = "#if false\n a()\n#endif\n#if DEBUG\n b()\n#else\n c()\n#endif\n#if !DEBUG\n d()\n#elseif true\n e()\n#endif\n"
        + "#if DEBUG\n#if false\n g()\n#endif\n h()\n#endif\n#if !false\n i()\n#elseif DEBUG\n j()\n#endif"
    let visible = ["a()", "b()", "c()", "d()", "e()", "g()", "h()", "i()", "j()"].filter { calls(pp, $0) == 1 }
    check("SX6 inactive conditional-compilation content is not executable; active DEBUG content is (nesting, #else, #elseif, negation)",
          visible == ["b()", "e()", "h()", "i()"], "\(visible)")
    let braces = SwiftSource.block(in: "func f() {\n  let s = \"{ /* } // {\"\n  let m = \"\"\"\n}\n{\n\"\"\"\n  x()\n}", after: "func f(")
    check("SX7 braces and comment markers inside strings never corrupt depth (plain and multi-line)",
          braces.map { b in b.executableOffsets(of: "x()").first.map { b.depth(at: $0) == 1 } == true } == true)
    let path = SwiftSource.block(in: "func f() {\n  if flag {\n    guard false else { return }\n    banner()\n  }\n  if other {\n    let a = 1\n    banner2()\n  }\n  if third {\n    guard ok else { crash() }\n    banner3()\n  }\n}", after: "func f(")
    let clear = path.map { b -> [Bool] in
        [("if flag {", "banner()"), ("if other {", "banner2()"), ("if third {", "banner3()")].map { branch, target in
            let o = b.executableOffsets(of: branch).first ?? 0, t = b.executableOffsets(of: target).first ?? 0
            return b.exitFree(from: o + branch.count, to: t)
        }
    }
    check("SX8 the in-branch path check: an exit or a guard (even one whose else ends in an unlisted Never call) before the target breaks the path; a straight path holds",
          clear == [false, true, false], "\(String(describing: clear))")

    // Corrective 4: token boundaries survive comment removal, and directives are
    // parsed as TOKENS (any spaces/tabs, comments between them), never as text.
    let separated = SwiftSource.code("a/**/b") == "a" + blanks(4) + "b"
        && SwiftSource.code("a/* x /* y */ z */b") == "a" + blanks(17) + "b"
        && SwiftSource.code("a// c\nb") == "a" + blanks(4) + "\nb"
        && SwiftSource.code("x = 1 /* one */ + /* two */ 2").split(separator: " ") == ["x", "=", "1", "+", "2"]
    let guardTok = SwiftSource.block(in: "func f() {\n  guard/**/ok else { return }\n  g()\n}", after: "func f(")
    check("SX9 comments never fuse tokens: blanks across block, nested block and line comments (newline kept); executable tokens stay separate",
          separated && guardTok.map { b in b.executableOffsets(of: "g()").first.map { b.skeleton(before: $0) == ["guard", "else", "{"] } == true } == true)
    let forms: [(String, Int)] = [("#if/**/false", 0), ("#if\tfalse", 0), ("#if  false", 0), ("\t#if false", 0), ("#if /* a */ false", 0),
                                  ("#if !/**/DEBUG", 0), ("#if\ttrue", 1), ("#if/*x*/DEBUG", 1), ("#if !false", 1), ("#if !!DEBUG", 1)]
    let wrong = forms.filter { calls("\($0.0)\n    apexRegisterAttack()\n#endif") != $0.1 }.map { $0.0 }
    let nested = calls("#if DEBUG\n#if/**/false\n    apexRegisterAttack()\n#endif\n#endif") == 0
        && calls("#if\tDEBUG\n#if true\n    apexRegisterAttack()\n#endif\n#endif") == 1
    check("SX10 directives are parsed as tokens: comments, spaces and tabs between them change nothing; false/true/DEBUG, negation and nesting evaluate as the build does",
          wrong.isEmpty && nested, "\(wrong) nested=\(nested)")
    let unsupported = SwiftSource.unsupportedDirectives("#if os(iOS)\nx()\n#endif\n#if DEBUG && false\ny()\n#endif")
    check("SX11 a condition form outside the supported set is flagged, and a block containing one is refused (it fails loudly, never guessed)",
          unsupported.count == 2 && SwiftSource.block(in: "func f() {\n#if os(iOS)\n x()\n#endif\n}", after: "func f(") == nil
            && SwiftSource.unsupportedDirectives("#if DEBUG\nx()\n#endif").isEmpty, "\(unsupported)")
    let sk = { (body: String) in SwiftSource.block(in: "func f() {\n" + body + "\n  call()\n}", after: "func f(").map { b in b.skeleton(before: b.executableOffsets(of: "call()").first ?? 0) } }
    let base = sk("  if a { }\n  guard b else { return }\n  let c = { 1 }()")
    let extras = ["  guard x else { fatalError(\"no\") }", "  guard x else { preconditionFailure() }", "  guard x else { throw E.x }",
                  "  if x { }", "  for i in s { }", "  while w { }", "  switch v { default: break }", "  run { }"]
        .map { sk("  if a { }\n  guard b else { return }\n  let c = { 1 }()\n" + $0) }
    check("SX12 the direct control-flow skeleton: keywords and blocks written directly in the body, in order; any added guard (whatever its terminator), if, loop, switch or closure changes it",
          base == ["if", "{", "guard", "else", "{", "{"] && extras.allSatisfy { $0 != base && $0 != nil }, "\(String(describing: base))")

    // Corrective 5: a required call must be a STANDALONE statement — alone on its
    // line, not joined to a neighbour by an operator or opener (ternaries,
    // assignments, chaining, trailing closures), whatever comments or tabs sit between.
    let standalone = { (body: String) -> Bool? in
        SwiftSource.block(in: "func f() {\n  z()\n" + body + "\n  y()\n}", after: "func f(").flatMap { b in
            b.executableOffsets(of: "call()").first.map { b.isStandaloneStatement(at: $0, length: "call()".count) }
        }
    }
    let accepted = ["  call()", "  call()   // a trailing comment", "  x = 1\n  call()", "  if a { }\n  call()"].map { standalone($0) }
    let rejected: [(String, String)] = [
        ("same-line ternary", "  false ? call() : ()"),
        ("multi-line ternary (the Reviewer's form)", "  false ?\n  call()\n  : ()"),
        ("previous line ends in ?", "  false ?\n  call()"),
        ("previous line ends in ? after a comment", "  false /* c */ ?   // why\n  call()"),
        ("next line begins with :", "  call()\n  : ()"),
        ("next line begins with : after a tab", "  call()\n\t:\t()"),
        ("next line chains with .", "  call()\n  .foo()"),
        ("next line opens a trailing closure", "  call()\n  { }"),
        ("assignment on the line", "  let v = call()"),
        ("assignment across lines", "  let v =\n  call()"),
        ("argument of another call", "  f(a,\n  call())"),
        ("operand of an operator", "  a +\n  call()"),
    ]
    let wrongly = rejected.filter { standalone($0.1) != false }.map { $0.0 }
    check("SX13 a required call must be a standalone statement: alone on its line, never joined into a ternary, assignment, argument, operator, chain or trailing closure (comments/tabs between change nothing)",
          accepted.allSatisfy { $0 == true } && wrongly.isEmpty, "accepted=\(accepted) wronglyAccepted=\(wrongly)")

    // Corrective 6: the exact active token sequence (the tripwire's input).
    let toks = { (body: String) -> [String] in
        SwiftSource.block(in: "func f() {\n" + body + "\n}", after: "func f(").map { $0.tokens(from: $0.open + 1, to: $0.close) } ?? ["<no block>"]
    }
    let lexemes = toks("  let a = \"x // y /* z */\" /* c */ + b.c(1_000, 0x1F, 2.5) ?? #\"r \"q\"\"# // t")
    let tokenOK = lexemes == ["let", "a", "=", "\"x // y /* z */\"", "+", "b", ".", "c", "(", "1_000", ",", "0x1F", ",", "2.5", ")", "??", "#\"r \"q\"\"#"]
        && toks("  a  +\n\t\tb") == toks("  a + b")
        && toks("  s = \"a b\"") != toks("  s = \"a  b\"")
        && toks("  s = \"n: \\(x + 1)\"") == ["s", "=", "\"n: \\(x + 1)\""]
        && toks("  s = \"\"\"\n  one\n  \"\"\"") == ["s", "=", "\"\"\"\n  one\n  \"\"\""]
        && toks("#if false\n  x()\n#endif\n  y()") == ["y", "(", ")"]
        && toks("  a == b") != toks("  a = b") && toks("  try f() as Void") == ["try", "f", "(", ")", "as", "Void"]
        && SwiftSource.digest(["ab", "c"]) != SwiftSource.digest(["a", "bc"]) && SwiftSource.digest(["x"]).count == 64
    check("SX14 the exact token sequence: whitespace and comments ignored, inactive regions excluded, every lexeme verbatim (string literals whole, internal whitespace kept; numbers, operators, punctuation, keywords)",
          tokenOK, "\(lexemes)")
    // SX15, on the REAL scene: harmless whitespace/comment edits leave both
    // tripwires unchanged; the Reviewer's `assert(… try … as Void)` wrapper changes them.
    // (Read directly: this group runs before the WR section declares `root`, and
    // top-level globals initialize in source order.)
    let sceneRaw = (try? String(contentsOf: URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
        .appendingPathComponent("Sparkforge/Scenes/GameScene.swift"), encoding: .utf8)) ?? ""
    let apexLine = "        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge\n"
    let moteAdd = "+ 78)\n            seam.zPosition = 300\n            camera.addChild(seam)\n"
    func apexPrefix(_ src: String) -> String? {
        // A7b S10: the DIRECT-BODY registration MW7/MW8 protect (the Shatter
        // exit's nested one precedes it).
        guard let b = SwiftSource.block(in: src, after: "private func handleProjectileHit("),
              let at = b.executableOffsets(of: "apexRegisterAttack()").first(where: { b.depth(at: $0) == 1 }) else { return nil }
        return SwiftSource.digest(b.tokens(from: b.open, to: at + "apexRegisterAttack()".count))
    }
    func moteBranch(_ src: String) -> [String]? {
        guard let b = SwiftSource.block(in: src, after: "private func setupHUD("),
              let at = b.executableOffsets(of: "if GameConfig.Mote.debugForceEntrance {").first,
              let add = b.executableOffsets(of: "camera.addChild(seam)").first(where: { $0 > at }) else { return nil }
        return b.tokens(from: at, to: add + "camera.addChild(seam)".count)
    }
    let harmlessApex = sceneRaw.replacingOccurrences(of: apexLine,
        with: "\n        // a harmless comment\n        /* and a block one */\n\n\tapexRegisterAttack()      /* trailing */\n")
    let wrappedApex = sceneRaw.replacingOccurrences(of: apexLine,
        with: "        assert(true, String(describing:\n            try\n            apexRegisterAttack()\n            as Void\n        ))\n")
    let harmlessMote = sceneRaw.replacingOccurrences(of: moteAdd,
        with: "+ 78)\n            seam.zPosition   =   300   // spaced out\n\n            /* a note */ camera.addChild(seam)\n")
    let wrappedMote = sceneRaw.replacingOccurrences(of: moteAdd,
        with: "+ 78)\n            seam.zPosition = 300\n            assert(true, String(describing:\n                try\n                camera.addChild(seam)\n                as Void\n            ))\n")
    let edited = sceneRaw.components(separatedBy: apexLine).count == 2 && sceneRaw.components(separatedBy: moteAdd).count == 2
    check("SX15 on the real scene: harmless whitespace/comment edits leave the MW7 and WR8 tripwires unchanged; the lazy assert(… try … as Void) wrapper changes both",
          edited && apexPrefix(sceneRaw) != nil && apexPrefix(harmlessApex) == apexPrefix(sceneRaw) && apexPrefix(wrappedApex) != apexPrefix(sceneRaw)
            && moteBranch(sceneRaw) != nil && moteBranch(harmlessMote) == moteBranch(sceneRaw) && moteBranch(wrappedMote) != moteBranch(sceneRaw))
}

// MARK: - WR · scene wiring the harness can't execute (exact lines, comments stripped)

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
func raw(_ rel: String) -> String {
    (try? String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8)) ?? ""
}
/// The file as CODE: the shared lexical sanitizer removes line, block and
/// nested block comments and keeps string literals intact (A7b corrective 2).
func code(_ rel: String) -> String { SwiftSource.code(raw(rel)) }
/// The body of `func name(` up to the next `func ` at the same indent.
func body(_ src: String, _ signature: String) -> String {
    guard let start = src.range(of: signature) else { return "" }
    let rest = src[start.upperBound...]
    let end = rest.range(of: "\n    private func ") ?? rest.range(of: "\n    func ")
    return String(rest[..<(end?.lowerBound ?? rest.endIndex)])
}
do {
    let scene = code("Sparkforge/Scenes/GameScene.swift")
    let opener = body(scene, "private func runRandomOpener(")
    let grant = opener.range(of: "guard upgradeManager.acquire(card, stats: playerStats, level: player.currentLevel) else { break }")
    let record = opener.range(of: "upgradeManager.recordDiscovered([card])")
    check("WR1 CL-102 the random opener acquires each grant (F1) and records it as discovered, right after granting it",
          !opener.isEmpty && grant != nil && record != nil && (grant?.upperBound ?? scene.endIndex) <= (record?.lowerBound ?? scene.startIndex))
    let selection = body(scene, "private func showCardSelection(")
    check("WR4 every spread shown is recorded through upgradeManager.recordDiscovered (the executed Codex path, PB-D); no direct Codex write remains in the scene",
          selection.contains("upgradeManager.recordDiscovered(cards)") && !scene.contains("CodexManager.shared.recordCardOffered("))
    let commit = body(scene, "private func commitCard(")
    let acquireAt = commit.range(of: "guard upgradeManager.acquire(card, stats: playerStats, level: player.currentLevel) else { return }")
    let effectsAt = commit.range(of: "if card.tag == .growth {")
    check("WR5 F1 a chosen card is taken through acquire (refused if stale) before any of its effects; the scene never calls pickCard",
          acquireAt != nil && effectsAt != nil && (acquireAt?.upperBound ?? commit.endIndex) <= (effectsAt?.lowerBound ?? commit.startIndex)
              && !scene.contains("upgradeManager.pickCard("))
    let revalidate = commit.range(of: "let legal = Set(upgradeManager.stillSelectable(displayedCards.map { $0.card },")
    let drop = commit.range(of: "displayedCards.removeAll { !legal.contains($0.card.id) }")
    let resolve = commit.range(of: "if displayedCards.isEmpty {")
    let again = commit.range(of: "label.text = \"★ PICK AGAIN\"")
    check("WR6 F1 after the Extra Pick's first card, the rest is revalidated, stale cards are dropped, and an empty table resolves the level-up before \"PICK AGAIN\"",
          revalidate != nil && drop != nil && resolve != nil && again != nil
              && commit.contains("atLevel: player.currentLevel).map { $0.id })")
              && (resolve?.upperBound ?? commit.endIndex) <= (again?.lowerBound ?? commit.startIndex)
              && body(commit, "if displayedCards.isEmpty {").contains("finishLevelUp(synergies: synergies)"))

    // PB-E — the level the scene passes into card selection drives the same-level
    // exclusion and Panda's schedule, so every call must pass the player's level.
    let calls = ["drawCards(", "acquire(", "stillSelectable(", "isSelectable("]
    var sites: [String] = []
    for name in calls {
        var rest = scene[...]
        while let r = rest.range(of: "upgradeManager." + name) {
            var depth = 1, i = r.upperBound
            while i < rest.endIndex, depth > 0 {
                if rest[i] == "(" { depth += 1 } else if rest[i] == ")" { depth -= 1 }
                i = rest.index(after: i)
            }
            sites.append(String(rest[r.lowerBound..<i]).replacingOccurrences(of: "\n", with: " "))
            rest = rest[i...]
        }
    }
    let wrongLevel = sites.filter { site in
        !(site.contains(" level: player.currentLevel") || site.contains(" level: self.player.currentLevel")
            || site.contains("atLevel: player.currentLevel"))
    }
    check("PB-E every card-selection call in the scene passes the player's current level (6 sites: 3 draws, 2 acquires, 1 revalidation)",
          sites.count == 6 && wrongLevel.isEmpty, "sites=\(sites.count) wrong=\(wrongLevel)")
    let codex = code("Sparkforge/Systems/CodexManager.swift")
    let summary = body(codex, "func debugSummary(")
    check("WR2 CL-102 the DEBUG Codex line counts through codexTally against the live catalog",
          summary.contains("UpgradeManager.codexTally(") && summary.contains("liveIDs: UpgradeManager.catalogIDs")
              && !summary.contains(".count\n") && summary.contains("tally.discovered"))
    let extra = body(scene, "private func executeExtraCard(")
    check("WR3 the +1 Card still draws through drawBonusCard (the one caller)",
          extra.contains("upgradeManager.drawBonusCard(excluding: displayedCards.map { $0.card })")
              && scene.components(separatedBy: "drawBonusCard(").count == 2)
    // v2.1 A7b S1: the dormant runtime is deleted (A4c/A7a lists; CL-127b). None
    // of it may come back in CODE (comments stripped); the retired ids stay in
    // `retiredCardIDs` for the Codex, which this doesn't read.
    let stats = code("Sparkforge/Systems/PlayerStats.swift")
    let dormant = ["arcWake", "ArcWake", "inductionStep", "InductionStep", "InductionCharge", "inductionCharge", "shockChainRadiusBonus",
                   "stunChance", "stunDuration", "bloodPriceBonus", "staticCrownDamage", "staticCrownRadius",
                   "glassEngineActive", "unbrokenCoreOwned"]
    let survivors = dormant.filter { scene.contains($0) || stats.contains($0) || code("Sparkforge/Systems/UpgradeManager.swift").contains($0) }
    check("WR7 A7b S1 the dormant runtime stays deleted (Arc Wake, Induction Step, Copper Vein radius, the legacy stun, Blood Price, Static Crown stats, the Glass Engine and Unbroken flags)",
          survivors.isEmpty && scene.contains("private func chainLightning(") && scene.contains("private func rollOverload(on enemy: EnemyNode) {")
            && stats.contains("guard overloadOwned else { return 0 }") && stats.contains("var effectiveDamageMultiplier: CGFloat {")
            && !body(scene, "private func rollOverload(").contains("applyStun(") && body(scene, "private func rollOverload(").contains("applyOverloadStun("),
          "\(survivors)")
    // v2.1 A7b S2 (debug-seams rule; CL-127c): a hot dev flag announces itself.
    let hud = body(scene, "private func setupHUD(")
    let mote = body(scene, "private func tryMoteEntrance(")
    let config = code("Sparkforge/Config/GameConfig.swift")
    var moteFlag = ""
    if let a = config.range(of: "    enum Mote {"),
       let b = config.range(of: "static let debugForceEntrance: Bool = false\n        #endif", range: a.upperBound..<config.endIndex) {
        moteFlag = String(config[a.lowerBound..<b.upperBound])
    }
    // Corrective 6: the EXACT accepted active token sequence of each banner branch,
    // from the hot-flag `if` through and including `camera.addChild(seam)`
    // (SwiftSource.tokens; the freeze-5 production shape). An intentional change
    // to either branch must update these arrays, as a reviewed contract change.
    func bannerTokens(forced: Bool) -> [String] {
        let head = forced
            ? ["if", "let", "forced", "=", "UpgradeManager", ".", "debugForcedCardID", "{"]
            : ["if", "GameConfig", ".", "Mote", ".", "debugForceEntrance", "{"]
        let text = forced ? "\"⚠︎ DEBUG — forced card: \\(forced)\"" : "\"⚠︎ DEBUG — Mote entrance forced\""
        return head + ["let", "seam", "=", "SKLabelNode", "(", "fontNamed", ":", "\"Menlo-Bold\"", ")",
                       "seam", ".", "text", "=", text,
                       "seam", ".", "fontSize", "=", "9",
                       "seam", ".", "fontColor", "=", "SKColor", "(", "hex", ":", "0xFFCC44", ")",
                       "seam", ".", "horizontalAlignmentMode", "=", ".", "left",
                       "seam", ".", "verticalAlignmentMode", "=", ".", "center",
                       "seam", ".", "position", "=", "CGPoint", "(", "x", ":", "safeLeft", ",", "y", ":", "-", "view", ".", "bounds", ".", "height", "/", "2", "+", forced ? "66" : "78", ")",
                       "seam", ".", "zPosition", "=", "300",
                       "camera", ".", "addChild", "(", "seam", ")"]
    }
    /// `needle` sits inside an open `#if DEBUG` block of `text` (internal review LOW-5).
    func insideDebug(_ text: String, _ needle: String) -> Bool {
        guard let at = text.range(of: needle) else { return false }
        let before = text[..<at.lowerBound]
        guard let open = before.range(of: "#if DEBUG", options: .backwards) else { return false }
        let close = before.range(of: "#endif", options: .backwards)
        return close.map { $0.lowerBound < open.lowerBound } ?? true
    }
    // Corrective 2/3: each banner is REACHABLE from its hot flag, on the
    // EXECUTABLE view (no comments, string contents or inactive `#if`
    // regions). The flag's `if` is itself executable and sits directly in
    // setupHUD's body after only the opening guard; the banner's text and its
    // addChild are executable and sit directly inside THAT branch (its own
    // block, depth 2); and the path inside the branch, from its `{` to the
    // addChild, holds no exit and no guard at all.
    func reachable(_ condition: String, _ text: String, accepted: [String]) -> Bool {
        guard let b = SwiftSource.block(in: raw("Sparkforge/Scenes/GameScene.swift"), after: "private func setupHUD("),
              b.executableOffsets(of: condition).count == 1, let at = b.executableOffsets(of: condition).first else { return false }
        let brace = at + condition.count - 1
        guard b.exec[brace] == "{", let end = b.matchingClose(of: brace),
              b.depth(at: at) == 1, b.returns(before: at) == 1 else { return false }
        let label = b.executableOffsets(of: text), adds = b.executableOffsets(of: "camera.addChild(seam)").filter { $0 > at && $0 < end }
        return label.count == 1 && label[0] > at && label[0] < end && b.enclosingOpen(of: label[0]) == brace
            && adds.count == 1 && adds[0] > label[0] && b.enclosingOpen(of: adds[0]) == brace
            && b.exitFree(from: brace + 1, to: adds[0])
            && b.isStandaloneStatement(at: adds[0], length: "camera.addChild(seam)".count)   // corrective 5: not inside an expression
            && b.tokens(from: at, to: adds[0] + "camera.addChild(seam)".count) == accepted       // corrective 6: the exact accepted tokens
    }
    check("WR8 A7b S2 the draft force-slot and the Mote entrance override are badged on the HUD (DEBUG only; each banner reachable straight from its hot flag), and the Mote flag no longer compiles into release",
          reachable("if let forced = UpgradeManager.debugForcedCardID {", "seam.text = \"⚠︎ DEBUG — forced card: \\(forced)\"", accepted: bannerTokens(forced: true))
            && reachable("if GameConfig.Mote.debugForceEntrance {", "seam.text = \"⚠︎ DEBUG — Mote entrance forced\"", accepted: bannerTokens(forced: false))
            && insideDebug(hud, "if let forced = UpgradeManager.debugForcedCardID {") && insideDebug(hud, "if GameConfig.Mote.debugForceEntrance {")
            && insideDebug(mote, "let eligible = earned || GameConfig.Mote.debugForceEntrance")
            && hud.contains("if let forced = UpgradeManager.debugForcedCardID {") && hud.contains("seam.text = \"⚠︎ DEBUG — forced card: \\(forced)\"")
            && hud.contains("if GameConfig.Mote.debugForceEntrance {") && hud.contains("seam.text = \"⚠︎ DEBUG — Mote entrance forced\"")
            && moteFlag.contains("#if DEBUG") && mote.contains("#if DEBUG\n        let eligible = earned || GameConfig.Mote.debugForceEntrance")
            && mote.contains("#else\n        let eligible = earned\n        #endif"))
    // v2.1 A7b S3 (G1.3, CL-98): the gun takes its volley's pellet count from
    // PlayerStats.volleyPelletCount, the one source the shock harness executes
    // (SE). On the EXECUTABLE view: the spread verdict and the fire call sit
    // directly in updateAutoAttack's body, the EXACT accepted active tokens from
    // the verdict through the fire call leave no room for another count, the
    // scene never reads Scatter's `extraProjectiles` itself, and the retired
    // fixed `spreadShotCount` is gone from code everywhere.
    let fireCall = "fireShotSpread(count: shotCount, baseDirection: baseDirection)"
    let volleyTokens = ["let", "isSpreadShot", "=", "playerStats", ".", "recordShot", "(", ")",
                        "let", "shotCount", "=", "playerStats", ".", "volleyPelletCount", "(", "isSpreadVolley", ":", "isSpreadShot", ")",
                        "volley", ".", "begin", "(", ")",
                        "fireShotSpread", "(", "count", ":", "shotCount", ",", "baseDirection", ":", "baseDirection", ")"]
    func volleyWired() -> Bool {
        guard let b = SwiftSource.block(in: raw("Sparkforge/Scenes/GameScene.swift"), after: "private func updateAutoAttack(") else { return false }
        let verdict = b.executableOffsets(of: "let isSpreadShot = playerStats.recordShot()"), fire = b.executableOffsets(of: fireCall)
        guard verdict.count == 1, fire.count == 1 else { return false }
        return b.depth(at: verdict[0]) == 1 && b.depth(at: fire[0]) == 1
            && b.tokens(from: verdict[0], to: fire[0] + fireCall.count) == volleyTokens
    }
    let retired = ["spreadShotCount"].filter { scene.contains($0) || stats.contains($0) || code("Sparkforge/Systems/UpgradeManager.swift").contains($0) }
    check("WR9 A7b S3 Storm Engine: the gun fires PlayerStats.volleyPelletCount's count (normal + 2 on a spread volley, CL-98), and nothing else sets it",
          volleyWired() && !scene.contains("extraProjectiles") && retired.isEmpty
            && stats.contains("func volleyPelletCount(isSpreadVolley: Bool) -> Int {"),
          "wired=\(volleyWired()) sceneReadsExtra=\(scene.contains("extraProjectiles")) retired=\(retired)")
    // v2.1 A7b S4 (G1.5, CL-96 Rootbound): the cultivated ground slows by the
    // run's `playerStats.terraSlow`, the value Growth ×3 raises (executed in the
    // chill harness, GW). On the EXECUTABLE view: the enemies loop sits directly
    // in updateCultivatedGround's body, and the EXACT accepted active tokens from
    // it through the slow leave no room for another value or a condition. The
    // scene never reads the Growth constant itself, and PlayerStats seeds and
    // resets terraSlow from it (the config stays the one source).
    let slowCall = "enemy.applySlow(playerStats.effectiveSlow(playerStats.terraSlow), duration: 0.3)"
    let groundTokens = ["for", "enemy", "in", "enemies", "where", "!", "enemy", ".", "isDying", "{",
                        "guard", "cultivatedZones", ".", "contains", "(", "where", ":", "{", "$0", ".", "covers", "(", "enemy", ".", "position", ")", "}", ")",
                        "else", "{", "continue", "}",
                        "enemy", ".", "applySlow", "(", "playerStats", ".", "effectiveSlow", "(", "playerStats", ".", "terraSlow", ")", ",", "duration", ":", "0.3", ")"]
    func groundWired() -> Bool {
        guard let b = SwiftSource.block(in: raw("Sparkforge/Scenes/GameScene.swift"), after: "private func updateCultivatedGround(") else { return false }
        let loop = b.executableOffsets(of: "for enemy in enemies where !enemy.isDying {"), slow = b.executableOffsets(of: slowCall)
        guard loop.count == 1, slow.count == 1 else { return false }
        return b.depth(at: loop[0]) == 1 && b.tokens(from: loop[0], to: slow[0] + slowCall.count) == groundTokens
    }
    check("WR10 A7b S4 Rootbound: the cultivated ground slows by playerStats.terraSlow (CL-96), seeded and reset from GameConfig.Growth.enemySlow",
          groundWired() && !scene.contains("GameConfig.Growth.enemySlow")
            && stats.contains("var terraSlow: CGFloat = GameConfig.Growth.enemySlow\n")
            && stats.components(separatedBy: "        terraSlow = GameConfig.Growth.enemySlow\n").count == 2,
          "wired=\(groundWired()) sceneReadsConstant=\(scene.contains("GameConfig.Growth.enemySlow"))")
    // v2.1 A7b S5 (G1.7, closure table R2): EnemyNode wires the executed
    // StunHold (shock SH) so the snowman and the timed stun are INDEPENDENT
    // holds. On the EXECUTABLE view (no comments, string contents or inactive
    // `#if` regions): no `stunTimer` is left; `isStunned` is either hold;
    // `stunHold` appears at exactly five sites (its declaration, `isStunned`, the
    // two stun calls and the status tick), each stun call and the tick a
    // standalone direct-body statement, Overload's hold written right after its
    // immunity guard; and becoming or ending a snowman never touches the hold.
    let enemyRaw = raw("Sparkforge/Nodes/EnemyNode.swift")
    let enemyExec = SwiftSource.executable(enemyRaw)
    let flatEnemy = enemyExec.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    func holdSite(_ fn: String, _ statement: String) -> Bool {
        guard let b = SwiftSource.block(in: enemyRaw, after: fn) else { return false }
        let at = b.executableOffsets(of: statement)
        return at.count == 1 && b.executableOffsets(of: "stunHold").count == 1
            && b.depth(at: at[0]) == 1 && b.isStandaloneStatement(at: at[0], length: statement.count)
    }
    func holdFree(_ fn: String) -> Bool {
        guard let b = SwiftSource.block(in: enemyRaw, after: fn) else { return false }
        return b.executableOffsets(of: "stunHold").isEmpty && b.executableOffsets(of: "stunTimer").isEmpty
    }
    let overloadGuard = "guard !isDying, overloadStun.tryStun(duration: duration) else { return false }"
    let overloadHold = SwiftSource.block(in: enemyRaw, after: "func applyOverloadStun(").map { b -> Bool in
        let g = b.executableOffsets(of: overloadGuard), w = b.executableOffsets(of: "stunHold.stun(duration)")
        guard g.count == 1, w.count == 1 else { return false }
        return b.tokens(from: g[0], to: w[0] + "stunHold.stun(duration)".count)
            == ["guard", "!", "isDying", ",", "overloadStun", ".", "tryStun", "(", "duration", ":", "duration", ")",
                "else", "{", "return", "false", "}", "stunHold", ".", "stun", "(", "duration", ")"]
    } ?? false
    let holdCount = enemyExec.components(separatedBy: "stunHold").count - 1
    check("WR11 A7b S5 the snowman and the timed (Overload) stun are independent holds in EnemyNode: either stuns, becoming or ending a snowman never writes or clears the timed stun (R2)",
          !enemyExec.contains("stunTimer") && holdCount == 5
            && flatEnemy.contains("private var stunHold = StunHold()")
            && flatEnemy.contains("var isStunned: Bool { stunHold.isStunned(snowman: snowman.isSnowman) }")
            && holdSite("func applyStun(", "stunHold.stun(duration)")
            && holdSite("func applyOverloadStun(", "stunHold.stun(duration)") && overloadHold
            && holdSite("func updateStatusEffects(", "stunHold.tick(deltaTime)")
            && holdFree("func becomeSnowman(") && holdFree("private func endSnowman("),
          "stunHold sites=\(holdCount) overloadHold=\(overloadHold) become=\(holdFree("func becomeSnowman(")) end=\(holdFree("private func endSnowman("))")
    // v2.1 A7b S6 (G1.8, CL-107/116): four independent vulnerability channels
    // (damage-pipeline VC executes the rule). On the EXECUTABLE view of EVERY
    // app source file (whitespace-flattened), with nothing left to chance:
    //  • ONE resolution — `vulnerability.multiplier` is read only by the shared
    //    VulnerabilityCarrier accessor, no raw channel is read anywhere else, and
    //    only that accessor declares `vulnerabilityMultiplier`;
    //  • the SAME model everywhere — EnemyNode and ArenaBossNode adopt
    //    VulnerabilityCarrier, and exactly the seven bodies (EnemyNode + the six
    //    boss conformers) declare a fresh `var vulnerability = VulnerabilityChannels()`;
    //  • each body's takeDamage applies the resolved value EXACTLY ONCE, in its
    //    accepted statement (EnemyNode's third read is `isVulnerable`);
    //  • every channel write is one of ten exact statements: EnemyNode's Fracture
    //    set/clear and Frostbite set/clear; the scene's Called set and clear and
    //    Marked set, enemy and boss, Marked behind its own not-yet-Marked gate.
    //    CONTRACT CHANGE, A7b S11 (CL-119 A1, a CL-116 channel; Oct 1): plus the
    //    scene's Erasure Fracture on a lone arena boss — its set, at the boss-class
    //    scale, and the clear when its game-time window ends: twelve writes.
    let appRoot = root.appendingPathComponent("Sparkforge")
    let appFiles = (FileManager.default.enumerator(atPath: appRoot.path)?.allObjects as? [String] ?? [])
        .filter { $0.hasSuffix(".swift") }.sorted()
    let flatApp: [String: String] = Dictionary(uniqueKeysWithValues: appFiles.map { rel in
        (rel, SwiftSource.executable(raw("Sparkforge/" + rel)).split(whereSeparator: { $0.isWhitespace }).joined(separator: " "))
    })
    func hits(_ needle: String) -> [String: Int] {
        flatApp.compactMapValues { text in let n = text.components(separatedBy: needle).count - 1; return n > 0 ? n : nil }
    }
    let channelsFile = "Systems/VulnerabilityChannels.swift"
    let bodies = ["Nodes/EnemyNode.swift", "Nodes/BossNode.swift", "Nodes/QuenchWardenNode.swift", "Nodes/DynamoChoirNode.swift",
                  "Nodes/FacetedLieNode.swift", "Nodes/MonumentBossNode.swift", "Nodes/MarchwardenNode.swift"]
    // CONTRACT CHANGE, A7b S8 (CL-114c; authorized): each body takes a DIRECT hit's
    // post-vulnerability amount as is (`resolved`), else applies the in-node rounding.
    let consume = "let scaled = resolved ?? (vulnerabilityMultiplier == 1.0 ? amount : Int((CGFloat(amount) * vulnerabilityMultiplier).rounded()))"
    let rawReads = [".frostbite", ".marked", ".called", ".fracture", "["].flatMap { ch in
        hits("vulnerability" + ch).keys.filter { $0 != channelsFile }.map { "\($0): vulnerability\(ch)" } }
    let oneModel = hits("vulnerability.multiplier") == [channelsFile: 1]
        && hits("var vulnerabilityMultiplier") == [channelsFile: 1] && rawReads.isEmpty
        && (flatApp[channelsFile] ?? "").contains("var vulnerabilityMultiplier: CGFloat { vulnerability.multiplier }")
        && (flatApp["Nodes/EnemyNode.swift"] ?? "").contains("class EnemyNode: SKNode, VulnerabilityCarrier {")
        && (flatApp["Nodes/ArenaBossNode.swift"] ?? "").contains("protocol ArenaBossNode: SKNode, VulnerabilityCarrier {")
        && hits("var vulnerability = VulnerabilityChannels()") == Dictionary(uniqueKeysWithValues: bodies.map { ($0, 1) })
        && hits("vulnerability = ") == Dictionary(uniqueKeysWithValues: bodies.map { ($0, 1) })
    let consumers = hits("vulnerabilityMultiplier").filter { $0.key != channelsFile && $0.key != "Nodes/ArenaBossNode.swift" }
    // CONTRACT CHANGE, A7b S8 (CL-114b; authorized): the scene's four direct-hit
    // chains read their target's resolved value into the block — exactly these four
    // arguments, and no other scene read.
    let chainReads = ["vulnerability: enemyNode.vulnerabilityMultiplier": 1, "vulnerability: enemy.vulnerabilityMultiplier": 1,
                      "vulnerability: bossNode.vulnerabilityMultiplier": 2]
    let sceneReadsOK = consumers["Scenes/GameScene.swift"] == 4
        && chainReads.allSatisfy { (flatApp["Scenes/GameScene.swift"] ?? "").components(separatedBy: $0.key).count - 1 == $0.value }
    let consumedOnce = bodies.allSatisfy { b in
        (flatApp[b] ?? "").components(separatedBy: consume).count == 2 && consumers[b] == (b == "Nodes/EnemyNode.swift" ? 3 : 2)
    } && Set(consumers.keys) == Set(bodies + ["Scenes/GameScene.swift"]) && sceneReadsOK
        && (flatApp["Nodes/EnemyNode.swift"] ?? "").contains("var isVulnerable: Bool { vulnerabilityMultiplier > 1.0 }")
    let writes: [String: [String]] = [
        "Nodes/EnemyNode.swift": ["vulnerability.set(.fracture, multiplier)", "vulnerability.clear(.fracture)",
                                  "vulnerability.set(.frostbite, frostbiteMultiplier)", "vulnerability.clear(.frostbite)"],
        "Scenes/GameScene.swift": [
            "e.vulnerability.set(.called, GameConfig.BossClass.scaledDebuff( GameConfig.Skybeam.calledVulnerability, isBossClass: e.isMiniBoss))",
            "b.vulnerability.set(.called, GameConfig.BossClass.scaledDebuff( GameConfig.Skybeam.calledVulnerability, isBossClass: true))",
            "calledEnemy?.vulnerability.clear(.called)", "calledBoss?.vulnerability.clear(.called)",
            "if e.timeAlive >= GameConfig.Apex.markLifetime && !e.vulnerability.isActive(.marked) { e.vulnerability.set(.marked, GameConfig.BossClass.scaledDebuff( GameConfig.Apex.markVulnerability, isBossClass: e.isMiniBoss))",
            "if let b = boss, !b.isDead, !b.vulnerability.isActive(.marked) { b.vulnerability.set(.marked, GameConfig.BossClass.scaledDebuff( GameConfig.Apex.markVulnerability, isBossClass: true))",
            "bossNode.vulnerability.set(.fracture, GameConfig.BossClass.scaledDebuff( GameConfig.Erasure.fractureVulnerability, isBossClass: true)) bossFractureWindow.start(GameConfig.Erasure.fractureDuration)",
            "if bossFractureWindow.tick(dt) { b.vulnerability.clear(.fracture) }"],
    ]
    let writeCensus = hits("vulnerability.set(").merging(hits("vulnerability.clear(")) { $0 + $1 }.filter { $0.key != channelsFile }
    let missing = writes.flatMap { file, statements in
        statements.filter { (flatApp[file] ?? "").components(separatedBy: $0).count != 2 }.map { "\(file): \($0)" } }
    let censusOK = writeCensus == writes.mapValues { $0.count } && missing.isEmpty
    check("WR12 A7b S6 four independent vulnerability channels (CL-107/116): one shared resolution, the same model on EnemyNode and all six bosses, each takeDamage applies it once, and exactly the twelve accepted channel writes (ten, plus Erasure's boss Fracture since A7b S11)",
          oneModel && consumedOnce && censusOK,
          "oneModel=\(oneModel) rawReads=\(rawReads) consumers=\(consumers) census=\(writeCensus) missing=\(missing)")
    // v2.1 A7b S7 (G1.9 94a; CL-94 / CL-114 / CL-115): all four direct-hit chains
    // call the ONE DirectHitDamage routine (executed in damage-pipeline DH) and
    // hand its result to the target. On the EXECUTABLE view, per chain: the Forge
    // offense call and the routine call each appear exactly once, directly in the
    // body, and their tokens run back to back EXACTLY as accepted (Forge ends the
    // integer prefix; the routine takes the ruled amplifiers and its threshold —
    // the shot's own `hitRounding`, or a fresh per-target draw on a sweep); no
    // truncating amplifier step remains outside that call; the consumption is
    // once, directly in the body; and the exact active token prefix from the
    // body's `{` through the consumption is pinned (SHA-256 + count, as MW8) — so
    // the integer prefix, the block, the suffix and every exit on the way are the
    // accepted shape. The projectile carries its OWN block threshold beside the A6
    // one (both drawn at launch).
    // CONTRACT CHANGE, A7b S8 (G1.9 94b/94c; authorized, Oct 1): the block now also
    // takes Overcharge's factor and the target's resolved vulnerability and yields
    // a DirectHit (`hit`); the enemy chains' Braceguard halving is `hit.shield(by:
    // BraceguardNode.shieldDamageMultiplier)` on both values, then the ONLY write to
    // `damage` is `damage = hit.basis` (the pre-vulnerability basis, CL-114d); the
    // boss chains write neither; and the consumption is the target's DIRECT entry,
    // `takeDirectHit(hit…)` (CL-114c). Token deltas: a7b/s8/mw8-token-diff.txt.
    // CONTRACT CHANGE, A7b S10 (G1.11 CL-99/CL-118; Brandon's go, Oct 1): the two
    // ENEMY prefixes run through the reworked Shatter (WR16), which sits between
    // the block and the consumption; every other token is identical and both boss
    // prefixes are unchanged (a7b/s9/prefix-token-diff.txt).
    //   gun → enemy    661 `052750f1…` → 706 `e409a68a…`
    //   sweep → enemy  426 `25af33fc…` → 463 `d33cbd51…`
    struct S7Chain {
        let name: String, signature: String, routineEnd: String, consumption: String, shielded: Bool
        let forgeThenBlock: [String]
        let prefixCount: Int, prefixDigest: String
    }
    // The accepted suffix: Braceguard's halving on the DirectHit, then the basis.
    let shieldTokens = ["hit", ".", "shield", "(", "by", ":", "BraceguardNode", ".", "shieldDamageMultiplier", ")"]
    let basisWrite = ["damage", "=", "hit", ".", "basis"]
    let s7Chains: [S7Chain] = [
        S7Chain(name: "gun → enemy", signature: "private func handleProjectileHit(",
                routineEnd: "rounding: projectileNode.hitRounding)",
                consumption: "let killed = enemyNode.takeDirectHit(hit)",
                shielded: true,
                forgeThenBlock: ["damage", "=", "applyForgeOffense", "(", "damage", ",", "healthPercent", ":", "enemyNode", ".",
                                "healthPercent", ",", "bossClass", ":", "enemyNode", ".", "isMiniBoss", ",", "impaired", ":",
                                "enemyNode", ".", "isSlowed", "||", "enemyNode", ".", "isFrozen", "||", "enemyNode", ".",
                                "isStunned", ",", "relentlessTarget", ":", "enemyNode", ")", "var", "hit", "=", "DirectHitDamage",
                                ".", "resolve", "(", "damage", ",", ".", "onEnemy", "(", "permafrostBonus", ":",
                                "playerStats", ".", "slowedDamageBonus", ",", "slowed", ":", "enemyNode", ".", "isSlowed", ",",
                                "arenaSlowed", ":", "playerStats", ".", "globalEnemySlow", ">", "0", ",", "brittleCold", ":",
                                "playerStats", ".", "brittleCold", ",", "brittleColdFactor", ":", "GameConfig", ".", "PolarVortex", ".",
                                "brittleColdVuln", ",", "frozen", ":", "enemyNode", ".", "isFrozen", ",", "stunned", ":",
                                "enemyNode", ".", "isStunned", ",", "openWoundsBonus", ":", "playerStats", ".", "bleedingEnemyDamageTaken", ",",
                                "bleeding", ":", "enemyNode", ".", "isBleeding", ")", ",", "overcharge", ":", "projectileNode",
                                ".", "overchargeFactor", ",", "vulnerability", ":", "enemyNode", ".", "vulnerabilityMultiplier", ",", "rounding",
                                ":", "projectileNode", ".", "hitRounding", ")"],
                prefixCount: 706, prefixDigest: "e409a68a8d0f9b548a855e2f854aedaec81e5ec9e7e163cc9dd58a68b4c68ba4"),
        S7Chain(name: "gun → boss", signature: "private func handleProjectileHitBoss(",
                routineEnd: "rounding: projectileNode.hitRounding)",
                consumption: "bossNode.takeDirectHit(hit, ignoresChallengeDEF: projectileNode.voidHit.flatDEFPenetration)",
                shielded: false,
                forgeThenBlock: ["damage", "=", "applyForgeOffense", "(", "damage", ",", "healthPercent", ":", "bossNode", ".",
                                "healthPercent", ",", "bossClass", ":", "true", ",", "impaired", ":", "false", ",",
                                "relentlessTarget", ":", "nil", ")", "let", "hit", "=", "DirectHitDamage", ".", "resolve",
                                "(", "damage", ",", ".", "onBoss", "(", "openWoundsBonus", ":", "playerStats", ".",
                                "bleedingEnemyDamageTaken", ",", "bleeding", ":", "bossStatus", ".", "bleed", ".", "isBleeding", ")",
                                ",", "overcharge", ":", "projectileNode", ".", "overchargeFactor", ",", "vulnerability", ":", "bossNode",
                                ".", "vulnerabilityMultiplier", ",", "rounding", ":", "projectileNode", ".", "hitRounding", ")"],
                prefixCount: 342, prefixDigest: "cc3d754994b1e797d319a1a0967cd83a8f58e03dcca62fab1f0d3cd32d3951e2"),
        S7Chain(name: "sweep → enemy", signature: "private func redSmileHit(",
                routineEnd: "rounding: DirectHitRounding())",
                consumption: "let killed = enemy.takeDirectHit(hit)",
                shielded: true,
                forgeThenBlock: ["damage", "=", "applyForgeOffense", "(", "damage", ",", "healthPercent", ":", "enemy", ".",
                                "healthPercent", ",", "bossClass", ":", "enemy", ".", "isMiniBoss", ",", "impaired", ":",
                                "enemy", ".", "isSlowed", "||", "enemy", ".", "isFrozen", "||", "enemy", ".",
                                "isStunned", ",", "relentlessTarget", ":", "enemy", ")", "var", "hit", "=", "DirectHitDamage",
                                ".", "resolve", "(", "damage", ",", ".", "onEnemy", "(", "permafrostBonus", ":",
                                "playerStats", ".", "slowedDamageBonus", ",", "slowed", ":", "enemy", ".", "isSlowed", ",",
                                "arenaSlowed", ":", "playerStats", ".", "globalEnemySlow", ">", "0", ",", "brittleCold", ":",
                                "playerStats", ".", "brittleCold", ",", "brittleColdFactor", ":", "GameConfig", ".", "PolarVortex", ".",
                                "brittleColdVuln", ",", "frozen", ":", "enemy", ".", "isFrozen", ",", "stunned", ":",
                                "enemy", ".", "isStunned", ",", "openWoundsBonus", ":", "playerStats", ".", "bleedingEnemyDamageTaken", ",",
                                "bleeding", ":", "enemy", ".", "isBleeding", ")", ",", "overcharge", ":", "overcharge",
                                ".", "factor", ",", "vulnerability", ":", "enemy", ".", "vulnerabilityMultiplier", ",", "rounding",
                                ":", "DirectHitRounding", "(", ")", ")"],
                prefixCount: 463, prefixDigest: "d33cbd51284aa48dba57f9e5d12fa475acf5d6dd96d0263d2a7e50811c8d49e1"),
        S7Chain(name: "sweep → boss", signature: "private func redSmileHitBoss(",
                routineEnd: "rounding: DirectHitRounding())",
                consumption: "bossNode.takeDirectHit(hit)",
                shielded: false,
                forgeThenBlock: ["damage", "=", "applyForgeOffense", "(", "damage", ",", "healthPercent", ":", "bossNode", ".",
                                "healthPercent", ",", "bossClass", ":", "true", ",", "impaired", ":", "false", ",",
                                "relentlessTarget", ":", "nil", ")", "let", "hit", "=", "DirectHitDamage", ".", "resolve",
                                "(", "damage", ",", ".", "onBoss", "(", "openWoundsBonus", ":", "playerStats", ".",
                                "bleedingEnemyDamageTaken", ",", "bleeding", ":", "bossStatus", ".", "bleed", ".", "isBleeding", ")",
                                ",", "overcharge", ":", "overcharge", ".", "factor", ",", "vulnerability", ":", "bossNode",
                                ".", "vulnerabilityMultiplier", ",", "rounding", ":", "DirectHitRounding", "(", ")", ")"],
                prefixCount: 197, prefixDigest: "35816a8b98f99fc963bc2d13321b5a9fe4adefaba90a2ddb1e9244ac695e100e")
    ]
    let sceneRawS7 = raw("Sparkforge/Scenes/GameScene.swift")
    let s7Drift = s7Chains.compactMap { c -> String? in
        guard let b = SwiftSource.block(in: sceneRawS7, after: c.signature) else { return "\(c.name): no body" }
        let forge = b.executableOffsets(of: "damage = applyForgeOffense("), start = b.executableOffsets(of: "hit = DirectHitDamage.resolve(")
        let end = b.executableOffsets(of: c.routineEnd), take = b.executableOffsets(of: c.consumption)
        guard forge.count == 1, start.count == 1, end.count == 1, take.count == 1 else {
            return "\(c.name): forge \(forge.count) routine \(start.count) end \(end.count) consumption \(take.count)"
        }
        guard [forge[0], start[0], take[0]].allSatisfy({ b.depth(at: $0) == 1 }), forge[0] < start[0], end[0] < take[0] else {
            return "\(c.name): not direct-body statements in order"
        }
        let routineStop = end[0] + c.routineEnd.count
        if b.tokens(from: forge[0], to: routineStop) != c.forgeThenBlock { return "\(c.name): Forge + block tokens differ" }
        let amplifierTokens = ["slowedDamageBonus", "brittleColdVuln", "bleedingEnemyDamageTaken"]
        let body = b.tokens(from: b.open, to: b.close + 1), block = b.tokens(from: start[0], to: routineStop)
        for a in amplifierTokens where body.filter({ $0 == a }).count != block.filter({ $0 == a }).count {
            return "\(c.name): \(a) outside the routine call"
        }
        // The hit's own value never reaches the in-node entry (other sources in the
        // chain — Shatter's execute, the Glass Blood exit, Overkill — keep it).
        if body.indices.contains(where: { $0 + 2 < body.count && body[$0] == "takeDamage" && body[$0 + 1] == "(" && body[$0 + 2] == "damage" }) {
            return "\(c.name): the hit's damage reaches takeDamage (the direct entry only)"
        }
        let flow = b.tokens(from: routineStop, to: take[0] + c.consumption.count)
        let writes = flow.indices.filter { $0 + 1 < flow.count && flow[$0] == "damage" && flow[$0 + 1] == "=" }
        let shields = flow.indices.filter { $0 + shieldTokens.count <= flow.count && Array(flow[$0..<($0 + shieldTokens.count)]) == shieldTokens }
        let hitMutations = flow.indices.filter { $0 + 2 < flow.count && flow[$0] == "hit" && flow[$0 + 1] == "." && flow[$0 + 2] != "basis" }
        if c.shielded {
            guard writes.count == 1, writes[0] + basisWrite.count <= flow.count, Array(flow[writes[0]..<(writes[0] + basisWrite.count)]) == basisWrite,
                  shields.count == 1, hitMutations == shields, shields[0] < writes[0] else {
                return "\(c.name): after the block, exactly Braceguard's hit.shield(by:) then damage = hit.basis (\(writes.count) writes, \(shields.count) shields)"
            }
        } else if !writes.isEmpty || !hitMutations.isEmpty { return "\(c.name): \(writes.count) writes / \(hitMutations.count) hit mutations after the block" }
        let prefix = b.tokens(from: b.open, to: take[0] + c.consumption.count)
        let digest = SwiftSource.digest(prefix)
        return prefix.count == c.prefixCount && digest == c.prefixDigest ? nil : "\(c.name): prefix \(prefix.count) tokens \(digest.prefix(16))"
    }
    // Corrective 8: each declaration must be the WHOLE executable line (a substring
    // match let `let hitRounding = DirectHitRounding().unit >= 0 ? … : …` through).
    // The draw itself is executed on real projectiles (vulnerability RP1–RP4).
    let projectileLines = SwiftSource.executable(raw("Sparkforge/Nodes/ProjectileNode.swift"))
        .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    let ownThreshold = projectileLines.filter { $0 == "let hitRounding = DirectHitRounding()" }.count == 1
        && projectileLines.filter { $0 == "let a6Rounding = A6Rounding()" }.count == 1
        && projectileLines.filter { $0.contains("hitRounding") }.count == 1
    check("WR13 A7b S7/S8 all four direct-hit chains (gun/sweep → enemy/boss): Forge then ONE DirectHitDamage block with the ruled amplifiers, Overcharge, the resolved vulnerability and its own threshold; Braceguard then the basis; the target's direct entry; the accepted token prefix through the consumption",
          s7Drift.isEmpty && ownThreshold, "\(s7Drift) ownThreshold=\(ownThreshold)")
    // v2.1 A7b S8 (G1.9 94b/94c; CL-114a/c): the static wiring the executed
    // checks (damage-pipeline DH9–DH11, vulnerability RN4/RN5) can't reach, on the
    // EXECUTABLE view, whitespace-flattened:
    //  • the Overcharge split rides exactly the ruled shots — fireProjectile and
    //    fireIcicle store the Overcharge-free multiplier and the split's factor —
    //    and the two sweeps start from the split's base; the five excluded
    //    constructions (acorn, seed fragment, Glass Blood, returned shot, Shadow
    //    Edge) keep today's whole multiplier; shotFractionDamage's other users stay;
    //  • the four chains are the only direct-entry callers; EnemyNode's and the
    //    bosses' direct entries skip only the in-node vulnerability;
    //  • the Spurhound / Ramplate punish window applies on both entries with
    //    today's arithmetic, token for token;
    //  • PlayerStats' Overcharge-free multiplier is today's sum without Overcharge.
    let sceneS8 = raw("Sparkforge/Scenes/GameScene.swift")
    func flatExec(_ text: String) -> String { SwiftSource.executable(text).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
    func flatBody(_ src: String, _ sig: String) -> String {
        guard let b = SwiftSource.block(in: src, after: sig) else { return "" }
        return String(b.exec[b.open...b.close]).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
    func n(_ text: String, _ needle: String) -> Int { text.components(separatedBy: needle).count - 1 }
    let fp = flatBody(sceneS8, "private func fireProjectile("), fi = flatBody(sceneS8, "private func fireIcicle(")
    let fireSplit = n(fp, "let overcharge = OverchargeSplit(playerStats.overchargeParts(scale: damageScale))") == 1
        && n(fp, "damageMultiplier: overcharge.overchargeFree,") == 1 && n(fp, "projectile.overchargeFactor = overcharge.factor") == 1
        && n(fi, "let overcharge = OverchargeSplit(playerStats.overchargeParts(scale: GameConfig.PolarVortex.icicleMult))") == 1
        && n(fi, "damageMultiplier: overcharge.overchargeFree,") == 1 && n(fi, "icicle.overchargeFactor = overcharge.factor") == 1
    let excluded = ["private func fireAcorn(", "private func fireSeedFragment(", "private func glassBloodBurst(",
                    "private func fireReturnedShot(", "private func fireShadowEdge("]
    let excludedKeep = excluded.allSatisfy { sig in
        let body = flatBody(sceneS8, sig)
        return n(body, "damageMultiplier: playerStats.effectiveDamageMultiplier") == 1 && !body.contains("overcharge")
    }
    let sceneFlat = flatExec(sceneS8)
    let sweepSplit = ["private func redSmileHit(", "private func redSmileHitBoss("].allSatisfy { sig in
        let body = flatBody(sceneS8, sig)
        return n(body, "let overcharge = OverchargeSplit(playerStats.overchargeParts(scale: GameConfig.RedSmile.damageFraction))") == 1
            && n(body, "var damage = overcharge.base") == 1 && !body.contains("shotFractionDamage")
    }
    let census = n(sceneFlat, "overchargeFactor =") == 2 && n(sceneFlat, "overchargeParts(scale:") == 4
        && n(sceneFlat, "damageMultiplier: playerStats.effectiveDamageMultiplier") == 5 && n(sceneFlat, "takeDirectHit(") == 4
    let enemyFlat = flatExec(raw("Sparkforge/Nodes/EnemyNode.swift")), bossProto = flatExec(raw("Sparkforge/Nodes/ArenaBossNode.swift"))
    let entries = enemyFlat.contains("func takeDamage(_ amount: Int) -> Bool { takeDamage(amount, resolved: nil) }")
        && enemyFlat.contains("func takeDirectHit(_ hit: DirectHit) -> Bool { takeDamage(hit.basis, resolved: hit.dealt) }")
        && bossProto.contains("func takeDamage(_ amount: Int, ignoresChallengeDEF: Bool) -> Bool { takeDamage(amount, ignoresChallengeDEF: ignoresChallengeDEF, resolved: nil) }")
        && bossProto.contains("func takeDirectHit(_ hit: DirectHit, ignoresChallengeDEF: Bool = false) -> Bool { takeDamage(hit.basis, ignoresChallengeDEF: ignoresChallengeDEF, resolved: hit.dealt) }")
    let punish = [("SpurhoundNode", "Spurhound"), ("RamplateNode", "Ramplate")].allSatisfy { node, cfg in
        let f = flatExec(raw("Sparkforge/Nodes/\(node).swift"))
        return f.contains("override func takeDamage(_ amount: Int) -> Bool { super.takeDamage(punished(amount)) }")
            && f.contains("override func takeDirectHit(_ hit: DirectHit) -> Bool { super.takeDirectHit(DirectHit(basis: hit.basis, dealt: punished(hit.dealt))) }")
            && f.contains("private func punished(_ amount: Int) -> Int { punishActive ? Int((CGFloat(amount) * GameConfig.\(cfg).punishVulnerability).rounded()) : amount }")
            && n(f, "punishVulnerability") == 1 && n(f, "punished(") == 3
    }
    let statsRaw = raw("Sparkforge/Systems/PlayerStats.swift")
    let effectiveTokens = SwiftSource.block(in: statsRaw, after: "var effectiveDamageMultiplier: CGFloat")
        .map { $0.tokens(from: $0.open, to: $0.close + 1) } ?? []
    let freeTokens = SwiftSource.block(in: statsRaw, after: "var overchargeFreeDamageMultiplier: CGFloat")
        .map { $0.tokens(from: $0.open, to: $0.close + 1) } ?? []
    var withoutOvercharge = effectiveTokens
    if let k = (0..<max(0, withoutOvercharge.count - 1)).first(where: { withoutOvercharge[$0] == "+" && withoutOvercharge[$0 + 1] == "overchargeCurrentBonus" }) {
        withoutOvercharge.removeSubrange(k...(k + 1))
    }
    let freeSum = !freeTokens.isEmpty && freeTokens == withoutOvercharge && effectiveTokens.filter { $0 == "overchargeCurrentBonus" }.count == 1
    check("WR14 A7b S8 the Overcharge split rides exactly the ruled hits (fireProjectile, fireIcicle, the two sweeps; never the five excluded shots), the four chains are the only direct-entry callers, the entries skip only the in-node vulnerability, the punish window applies on both entries unchanged, and the Overcharge-free multiplier is today's sum without Overcharge",
          fireSplit && excludedKeep && sweepSplit && census && entries && punish && freeSum,
          "fire \(fireSplit) excluded \(excludedKeep) sweep \(sweepSplit) census \(census) entries \(entries) punish \(punish) freeSum \(freeSum)")

    // v2.1 A7b S9 (G1.10, CL-117; Brandon's go, Oct 1), on the EXECUTABLE view:
    //  • ONE crit roll for a shot, `rollShotCrit(directAttack:)`; only a direct
    //    attack advances Calculated Strike (every 5th crits);
    //  • the replacement icicle rolls it as a direct attack — it crits and counts
    //    once — while Glacial Condensation's absorbed pellets return before any roll;
    //  • the icicle's own shatter shards never roll (`rollsCrit: false`); Iceburst's
    //    shards and every other shot keep today's roll.
    let glacialBranch = "if playerStats.glacialActive && allowModifiers { playerStats.glacialShotCounter += 1 if playerStats.glacialShotCounter % GameConfig.PolarVortex.glacialEveryN == 0 { configurePrimaryShot(fireIcicle(direction: direction, originOffset: originOffset), pellet: false) } return }"
    let rollShot = "let isCrit = rollsCrit && rollShotCrit(directAttack: allowModifiers)"
    let fpGlacial = fp.range(of: glacialBranch), fpRoll = fp.range(of: rollShot)
    let s9Fire = n(fp, glacialBranch) == 1 && n(fp, rollShot) == 1 && n(fp, "rollShotCrit(") == 1 && n(fp, "isCrit: isCrit,") == 1
        && fpGlacial != nil && fpRoll != nil && (fpGlacial?.upperBound ?? fp.endIndex) <= (fpRoll?.lowerBound ?? fp.startIndex)
        && n(sceneFlat, "private func fireProjectile(direction: CGPoint, originOffset: CGPoint = .zero, damageScale: CGFloat = 1.0, allowModifiers: Bool = true, rollsCrit: Bool = true,") == 1
    let s9Icicle = n(fi, "let isCrit = rollShotCrit(directAttack: true)") == 1 && n(fi, "isCrit: isCrit,") == 1
        && n(fi, "rollShotCrit(") == 1 && !fi.contains("isCrit: false") && n(fi, "isIcicle: true") == 1
    let shatterShards = flatBody(sceneS8, "private func iceShatter("), iceburstShards = flatBody(sceneS8, "private func iceburst(")
    let s9Shards = n(shatterShards, "allowModifiers: false, rollsCrit: false,") == 1
        && !iceburstShards.isEmpty && !iceburstShards.contains("rollsCrit")
        && n(sceneFlat, "rollsCrit: false") == 1 && n(sceneFlat, "rollShotCrit(") == 3
    let s9Roll = flatBody(sceneS8, "private func rollShotCrit(directAttack: Bool) -> Bool")
        == "{ var isCrit = CGFloat.random(in: 0...1) < playerStats.critChance if playerStats.forgeCalculatedStrike && directAttack { forgeCalcStrikeCount += 1 if forgeCalcStrikeCount % 5 == 0 { isCrit = true } } return isCrit }"
        && n(sceneFlat, "forgeCalcStrikeCount += 1") == 2
    check("WR15 A7b S9 the replacement icicle rolls the shot's crit and counts once toward Calculated Strike; the absorbed pellets never roll; the icicle's own shards never crit; Iceburst's shards and every other shot keep today's roll",
          s9Fire && s9Icicle && s9Shards && s9Roll, "fire \(s9Fire) icicle \(s9Icicle) shards \(s9Shards) roll \(s9Roll)")

    // v2.1 A7b S10 (G1.11, CL-99/CL-118): both Shatter sites ask the ONE rule
    // (executed in chill SR1–SR6) with the live stats — the arena's slow counted —
    // and land its damage through the PLAIN entry (the vulnerability scales the
    // chunk); a kill, or an execute, ends the hit, and an elite that survives its
    // chunk takes the rest of the hit; the gun's Shatter kill keeps the shot's
    // Iceburst generation and its exit charges the meters (redsmile MW9); the
    // tuning is GameConfig's (CL-118d). Nothing else reads Shatter's stats.
    func shatterAsk(_ t: String) -> String {
        "if let shatter = ShatterRule.outcome(chance: playerStats.shatterChance, threshold: playerStats.shatterSlowThreshold, slowed: \(t).isSlowed, totalSlow: \(t).currentSlow + playerStats.globalEnemySlow, elite: \(t).isMiniBoss, maxHealth: \(t).maxHealth, roll: CGFloat.random(in: 0...1)) { let killed = \(t).takeDamage(shatter.damage(health: \(t).health)) if killed {"
    }
    let gunHit = flatBody(sceneS8, "private func handleProjectileHit("), sweepHit = flatBody(sceneS8, "private func redSmileHit(")
    let gunExit = "if killed || shatter.endsHit { apexRegisterAttack() erasureRegisterHit() if let index = projectiles.firstIndex(where: { $0 === projectileNode }) { projectiles.remove(at: index) } openBlackholeIfSeeded(projectileNode) projectileNode.removeFromParent() return } }"
    let sweepExit = "if killed || shatter.endsHit { chargeRedSmileHitMeters(.shatter) return nil } }"
    let s10Sites = n(gunHit, shatterAsk("enemyNode")) == 1 && n(sweepHit, shatterAsk("enemy")) == 1
        && n(gunHit, gunExit) == 1 && n(sweepHit, sweepExit) == 1
        && n(gunHit, "onEnemyKilled(at: enemyNode.position, xpValue: enemyNode.xpValue, enemy: enemyNode, source: projectileNode.killSource, iceburstGeneration: projectileNode.iceburstGeneration) }") == 1
        && n(sweepHit, "onEnemyKilled(at: enemy.position, xpValue: enemy.xpValue, enemy: enemy, source: .melee) }") == 2
    let s10Census = n(sceneFlat, "ShatterRule.") == 2 && n(sceneFlat, "playerStats.shatterChance") == 2
        && n(sceneFlat, "playerStats.shatterSlowThreshold") == 2 && n(sceneFlat, "shatter.endsHit") == 2
    let statsFlatS10 = flatExec(statsRaw), umFlatS10 = flatExec(raw("Sparkforge/Systems/UpgradeManager.swift"))
    let s10Tuning = n(statsFlatS10, "var shatterSlowThreshold: CGFloat = GameConfig.Chill.shatterSlowThreshold") == 1
        && n(statsFlatS10, "shatterSlowThreshold = GameConfig.Chill.shatterSlowThreshold") == 1
        && n(statsFlatS10, "shatterSlowThreshold") == 4 && n(statsFlatS10, "shatterChance = 0.0") == 1   // 2 sites + their 2 config reads
        && n(umFlatS10, "stats.shatterChance = GameConfig.Chill.shatterChance") == 1
        && n(umFlatS10, "stats.shatterSlowThreshold = GameConfig.Chill.absoluteZeroShatterThreshold") == 1
        && n(umFlatS10, "stats.shatterChance") == 1 && n(umFlatS10, "stats.shatterSlowThreshold") == 1
    check("WR16 A7b S10 both Shatter sites ask the one rule with the live stats, land it through the plain entry, end the hit only on a kill or an execute (a surviving elite takes the rest), keep the gun kill's Iceburst generation and charge its meters on the exit; the tuning is GameConfig's",
          s10Sites && s10Census && s10Tuning, "sites \(s10Sites) census \(s10Census) tuning \(s10Tuning)")

    // v2.1 A7b S11 (CL-119 A1, CL-120 B1′), on the EXECUTABLE view:
    //  • Erasure's full meter lurches at the nearest foe; with none alive, at the
    //    arena boss only if it can be hit (else the charge holds), rolling only
    //    the boss-reachable effects — Rift Burst (boss included), Damage Echo,
    //    Fracture — each at the boss-class 50%; a boss lurch is an activation;
    //  • the boss's Fracture runs on the scene's game-time window, cleared when
    //    it ends and reset for every new boss (its writes: WR12);
    //  • Unstable Core keeps its cadence and ring but costs you only when the
    //    burst struck a live body (Unbroken still covers it).
    let erasureFlat = flatBody(sceneS8, "private func updateErasure(")
    let s11Fallback = n(erasureFlat, "if erasureStacks >= GameConfig.Erasure.unstableGaugeCapacity, erasureTriggerCooldown <= 0 { if let target = nearestEnemyToPlayer() { releaseUnstableCharge() triggerUnstable(on: target) } else if let b = boss, isHittable(b) { releaseUnstableCharge() triggerUnstable(onBoss: b) } }") == 1
        && flatBody(sceneS8, "private func releaseUnstableCharge()") == "{ erasureStacks = 0 erasureGauge.flashRelease() erasureTriggerCooldown = playerStats.erasureTriggerCD }"
    let s11BossLurch = flatBody(sceneS8, "private func triggerUnstable(onBoss bossNode: any ArenaBossNode)")
        == "{ playerStats.erasureActivations += 1 let pos = bossNode.position showUnstablePop(at: pos) switch Int.random(in: 0..<3) { case 0: erasureRiftBurst(at: pos, includeBoss: true) case 1: erasureDamageEcho(onBoss: bossNode) default: erasureFracture(onBoss: bossNode) } fireRiftCannonIfDue() }"
        && flatBody(sceneS8, "private func triggerUnstable(on enemy: EnemyNode)").hasSuffix("default: erasureBackwash(at: pos) } fireRiftCannonIfDue() }")
        && n(sceneFlat, "fireRiftCannonIfDue()") == 3 && n(sceneFlat, "fireRiftCannon()") == 2
        && n(sceneFlat, "private func erasureRiftBurst(at pos: CGPoint, includeBoss: Bool = false) {") == 1
        && n(flatBody(sceneS8, "private func erasureRiftBurst("), "damage: dmg, bossClassScaled: true, includeBoss: includeBoss)") == 1
    let echoBoss = flatBody(sceneS8, "private func erasureDamageEcho(onBoss bossNode: any ArenaBossNode)")
    let s11Effects = n(echoBoss, "guard let self = self, let b = self.boss, ObjectIdentifier(b) == target, self.isHittable(b) else { return }") == 1
        && n(echoBoss, "b.takeDamage(GameConfig.BossClass.scaledDamage(dmg, isBossClass: true))") == 1
        && n(echoBoss, "GameConfig.Erasure.damageEchoFraction") == 1
        && n(sceneFlat, "bossFractureWindow = GameTimer()") == 3 && n(sceneFlat, "bossFractureWindow.start(") == 1   // the declaration + 2 resets
        && n(sceneFlat, "bossFractureWindow.tick(") == 1 && n(sceneFlat, "private var bossFractureWindow = GameTimer()") == 1
        && n(flatBody(sceneS8, "private func resetBossStatus()"), "bossFractureWindow = GameTimer()") == 1
    let coreFlat = flatBody(sceneS8, "private func performUnstableCoreBurst()")
    let s11Core = n(coreFlat, "var struck = false for enemy in enemies { if player.position.distance(to: enemy.position) < radius { if !enemy.isDying { struck = true } enemy.takeDamage(damage) } }") == 1
        && n(coreFlat, "if !playerStats.unbrokenWindow.isActive && struck {") == 1 && n(coreFlat, "struck") == 3
        && n(coreFlat, "let ring = SKShapeNode(circleOfRadius: radius)") == 1
    check("WR17 A7b S11 Erasure's lurch falls back to a lone, hittable arena boss with only the boss-reachable effects at 50% (an activation; the boss Fracture on its own reset window); Unstable Core costs you only when its burst struck something",
          s11Fallback && s11BossLurch && s11Effects && s11Core,
          "fallback \(s11Fallback) bossLurch \(s11BossLurch) effects \(s11Effects) core \(s11Core)")

    // v2.1 A7b S12 (CL-127a, CL-126): every targeter picks only what can be hit —
    // Chain Lightning's jumps, the Electro Pulse, Sentry coils and their boss
    // fallback, Relay Burn arcs (which skipped nothing before), and the gun's
    // auto-aim, the lassoed prey included: the next visible hittable target,
    // else hold fire. None of them filters on `isDying` / `isDead` alone any more.
    let chainFlat = flatBody(sceneS8, "private func chainLightning("), pulseFlat = flatBody(sceneS8, "private func updateElectroPulse(")
    let coilFlat = flatBody(sceneS8, "private func updateSentryCoils("), relayFlat = flatBody(sceneS8, "private func fireRelayBurnArc(")
    let aimFlat = flatBody(sceneS8, "private func findNearestTargetPosition()")
    // CONTRACT CHANGE, A7b S13 (CL-123a; Oct 1): the four arc/hop candidate loops
    // became `nearestVisible(…)` calls (WR19); their candidate filters keep the
    // same hittability terms, pinned here in their new form.
    let s12Sites = n(chainFlat, "among: enemies.filter { e in isHittable(e) && !visited.contains(where: { $0 === e }) },") == 1
        && n(pulseFlat, "among: enemies.filter { isHittable($0) },") == 1
        && n(coilFlat, "among: enemies.filter { isHittable($0) },") == 1
        && n(coilFlat, "} else if let b = boss, isHittable(b), origin.distance(to: b.position) - b.targetingRadius < range,") == 1
        && n(relayFlat, "among: enemies.filter { $0 !== source && isHittable($0) },") == 1
        && n(aimFlat, "if playerStats.skybeamHoming, let node = lassoTargetNode, isHittableTarget(node), player.position.distance(to: node.position) <= range {") == 1
        && n(aimFlat, "for enemy in enemies where isHittable(enemy) {") == 1 && n(aimFlat, "if let boss = boss, isHittable(boss) {") == 1
    let s12Stale = [chainFlat, pulseFlat, coilFlat, relayFlat, aimFlat].allSatisfy {
        !$0.isEmpty && !$0.contains("!enemy.isDying") && !$0.contains("!b.isDead") && !$0.contains("!boss.isDead")
    }
    let s12Helper = flatBody(sceneS8, "private func isHittableTarget(_ node: SKNode) -> Bool")
        == "{ if let enemy = node as? EnemyNode { return isHittable(enemy) } if let boss = node as? (any ArenaBossNode) { return isHittable(boss) } return true }"
    check("WR18 A7b S12 every targeter picks only hittable bodies — Chain Lightning, Electro Pulse, Sentry coils and their boss fallback, Relay Burn arcs, and the gun's auto-aim (lassoed prey included)",
          s12Sites && s12Stale && s12Helper, "sites \(s12Sites) stale-free \(s12Stale) helper \(s12Helper)")

    // v2.1 A7b S13 (CL-109; CL-123a/b): arcs and hops — Chain Lightning, Relay
    // Burn, the Electro Pulse, Sentry T1–T3 and the coils' boss fallback — take
    // the nearest candidate they can SEE (ArenaGeometry.nearestVisible, executed
    // in geometry G6) on the exact segment at the arc travel radius, else none;
    // the T4 Lightning Network is exempt (arena-wide by ruling and copy); and the
    // gun's Skybeam homing takes the same line-of-sight predicate as every other
    // auto-aim target, falling through when the prey is occluded.
    let arcTail = "position: { $0.position }, within: "
    let s13Arcs = n(chainFlat, "guard let target = arenaGeometry.nearestVisible( from: from, among:") == 1
        && n(chainFlat, arcTail + "GameConfig.Shock.chainRange, travelRadius: GameConfig.Geometry.arcTravelRadius) else { break }") == 1
        && n(relayFlat, "guard let target = arenaGeometry.nearestVisible( from: source.position, among:") == 1
        && n(relayFlat, arcTail + "playerStats.relayBurnRadius, travelRadius: GameConfig.Geometry.arcTravelRadius) else { return }") == 1
        && n(pulseFlat, "guard let target = arenaGeometry.nearestVisible( from: player.position, among:") == 1
        && n(pulseFlat, arcTail + "GameConfig.Shock.pulseRange, travelRadius: GameConfig.Geometry.arcTravelRadius) else { return }") == 1
        && n(coilFlat, "let sight = network ? ArenaGeometry.open : arenaGeometry if let target = sight.nearestVisible( from: origin, among:") == 1
        && n(coilFlat, arcTail + "range, travelRadius: GameConfig.Geometry.arcTravelRadius) {") == 1
        && n(coilFlat, "!sight.segmentBlockedExact(origin, b.position, travelRadius: GameConfig.Geometry.arcTravelRadius) {") == 1
        && n(sceneFlat, "nearestVisible(") == 4 && n(sceneFlat, "GameConfig.Geometry.arcTravelRadius") == 5
        && [chainFlat, relayFlat, pulseFlat, coilFlat].allSatisfy { !$0.contains(".distance(to: enemy.position)") }
    let s13Homing = n(aimFlat, "if playerStats.skybeamHoming, let node = lassoTargetNode, isHittableTarget(node), player.position.distance(to: node.position) <= range { if !(solid && arenaGeometry.segmentBlocked( player.position, node.position, travelRadius: GameConfig.Geometry.projectileTravelRadius)) { return node.position } geometryDebug.losSuppressedTargets += 1 }") == 1
        && (aimFlat.range(of: "let solid = arenaGeometry.hasBlockedGeometry")?.lowerBound ?? aimFlat.endIndex)
            < (aimFlat.range(of: "if playerStats.skybeamHoming")?.lowerBound ?? aimFlat.startIndex)
    let geoFlat = flatExec(raw("Sparkforge/Config/ArenaGeometry.swift"))
    let s13Helper = n(geoFlat, "func nearestVisible<S: Sequence>(from origin: CGPoint, among candidates: S, position: (S.Element) -> CGPoint, within range: CGFloat, travelRadius: CGFloat) -> S.Element? {") == 1
    check("WR19 A7b S13 arcs and hops take the nearest target they can see (else none), the T4 network is exempt, the coils' boss fallback needs sight, and Skybeam homing uses the gun's line-of-sight predicate",
          s13Arcs && s13Homing && s13Helper, "arcs \(s13Arcs) homing \(s13Homing) helper \(s13Helper)")

    // v2.1 A7b S14 (CL-109; CL-124a–d), on the EXECUTABLE view:
    //  • ONE path-tested shove (ArenaGeometry.pathShove, executed in geometry G7)
    //    for every instant knock — Guard's (still `guardShove`), the deer, the
    //    Brace rescue (both sites), the boar's sideways shove, Implosion's pull,
    //    the Panda body check and roll, the kaiju swipe — and the Repulse flight's
    //    bisection; the legacy `applyKnockback` is gone from the app;
    //  • the Vine Wall's edge push runs beside the void-well pull, BEFORE the
    //    frame's geometry resolve (the CL-77 precedent);
    //  • the Tree T5 lion resolves after each step; Wildbloom flowers root off
    //    the Carrier and inside the wall (executed in G8; the zone centre is the
    //    fallback); Rich Soil widens within the garden cap.
    let appText = flatApp.values.joined(separator: "\n")
    let shoveBody = flatBody(sceneS8, "private func shove(_ enemy: EnemyNode, along direction: CGPoint, by distance: CGFloat)")
    let s14Shove = shoveBody == "{ guard distance > 0 else { return } let from = enemy.position enemy.position = arenaGeometry.pathShove(from: from, to: from + direction.normalized * distance, radius: enemy.hitBodyRadius) }"
        && flatBody(sceneS8, "private func guardShove(") == "{ shove(enemy, along: enemy.position - player.position, by: distance) }"
        && n(sceneFlat, "shove(target, along: target.position - panda.node.position, by: GameConfig.Panda.bodyCheckKnockback)") == 1
        && n(sceneFlat, "shove(e, along: e.position - player.position, by: GameConfig.Panda.kaijuKnockback)") == 1
        && n(sceneFlat, "shove(e, along: e.position - panda.node.position, by: 30 * DeviceScale.gameplay)") == 1
        && n(sceneFlat, "self.shove(e, along: e.position - origin, by: GameConfig.NatureCanon.deerKnockback)") == 1
        && n(sceneFlat, "shove(e, along: side * sign, by: missile.shoveForce)") == 1
        && n(sceneFlat, "shove(enemy, along: enemy.position - player.position, by: 40)") == 2
        && n(sceneFlat, "shove(e, along: pos - e.position, by: GameConfig.Erasure.implosionPull)") == 1
        && n(sceneFlat, "to = arenaGeometry.pathShove(from: from, to: to, radius: r)") == 1
        && !appText.contains("applyKnockback") && !appText.contains("lastFreePoint")
        && !sceneFlat.contains("enemy.position += dir * 40") && !sceneFlat.contains("e.position += side * sign")
        && !sceneFlat.contains("e.position += dir * GameConfig.Erasure.implosionPull")
    let enemiesFlat = flatBody(sceneS8, "private func updateEnemies(")
    let wellAt = enemiesFlat.range(of: "applyVoidWellPull(dt) applyVineWallEdge(dt) resolveEnemiesAgainstGeometry() }")
    let s14Order = wellAt != nil && enemiesFlat.hasSuffix("applyVoidWellPull(dt) applyVineWallEdge(dt) resolveEnemiesAgainstGeometry() }")
        && n(sceneFlat, "applyVineWallEdge(dt)") == 1
        && n(flatBody(sceneS8, "private func applyVineWallEdge("), "e.position += out * repel * CGFloat(dt)") == 1
        && !flatBody(sceneS8, "private func updateVineWall(").contains("repel")
    let s14Places = n(sceneFlat, "lion.position += dir * GameConfig.Tree.lionSpeed * CGFloat(dt) lion.position = arenaGeometry.resolve(lion.position, actorRadius: GameConfig.Tree.lionFootprintRadius)") == 1
        && flatBody(sceneS8, "private func randomPointOnCultivatedGround()") == "{ guard let zone = cultivatedZones.randomElement() else { return nil } return PlacementSampler.randomPoint(inDiscAt: zone.position, radius: zone.radius * 0.85, in: arenaGeometry, arenaRadius: GameConfig.Arena.radius, margin: GameConfig.Growth.flowerRootMargin, fallback: zone.position) }"
        && flatBody(sceneS8, "private func modifyAllCultivatedZones(") == "{ let cap = GameConfig.Arena.radius * GameConfig.Growth.maxZoneRadiusFactor for zone in cultivatedZones { zone.setRadius(min(cap, zone.radius * radiusScale)) } }"
        && n(sceneFlat, "modifyAllCultivatedZones(radiusScale: GameConfig.Growth.richSoilRadiusScale)") == 2 && !sceneFlat.contains("radiusScale: 1.22")
    check("WR20 A7b S14 one path-tested shove for every instant knock (applyKnockback gone), the Vine Wall pushes before the frame's resolve, the lion resolves each step, flowers root on valid ground, and Rich Soil grows within the garden cap",
          s14Shove && s14Order && s14Places, "shove \(s14Shove) order \(s14Order) places \(s14Places)")

    // v2.1 A7b S15 (CL-59, CL-127d): boss hazards reach Spark's LIVE (Harden-
    // shrunk) body — Quench Warden lanes, the Dynamo Choir litany, the Faceted
    // Lie's plates and Pane burst read the scene-written `playerHitRadius`, and
    // the Quench Field's wall clamp reads the live radius; centre-point hazards
    // are untouched (the Titan/Anvilborn slams, the Star, Standardfall).
    let hazardNodes = ["QuenchWardenNode", "DynamoChoirNode", "FacetedLieNode"].map { flatExec(raw("Sparkforge/Nodes/\($0).swift")) }
    let s15Nodes = hazardNodes.allSatisfy { $0.contains(", ArenaBossNode, PlayerReachHazards {") && $0.contains("var playerHitRadius: CGFloat = GameConfig.Player.collisionRadius")
            && $0.components(separatedBy: "GameConfig.Player.collisionRadius").count - 1 == 1 }
        && hazardNodes[0].contains("QuenchWardenNode.laneHalfWidth + playerHitRadius")
        && hazardNodes[1].contains("DynamoChoirNode.litanyHitDistance + playerHitRadius")
        && hazardNodes[2].contains("FacetedLieNode.falseSafePlateReach + playerHitRadius") && hazardNodes[2].contains("FacetedLieNode.paneBurstRadius + playerHitRadius")
        && flatExec(raw("Sparkforge/Nodes/ArenaBossNode.swift")).contains("protocol PlayerReachHazards: AnyObject { var playerHitRadius: CGFloat { get set } }")
    let s15Scene = n(sceneFlat, "(boss as? PlayerReachHazards)?.playerHitRadius = playerStats.effectiveCollisionRadius boss?.update(deltaTime: dt, playerPosition: player.position)") == 1
        && n(sceneFlat, "let maxDist = GameConfig.Arena.radius - playerStats.effectiveCollisionRadius") == 2
        && !sceneFlat.contains("GameConfig.Arena.radius - GameConfig.Player.collisionRadius")
    check("WR21 A7b S15 the three bosses' hazards and the Quench Field's wall clamp reach Spark's live (Harden-shrunk) body, written before every boss update",
          s15Nodes && s15Scene, "nodes \(s15Nodes) scene \(s15Scene)")

    // v2.1 A7b S16 (CL-125, accepted and deferred to the Arena 10 monument): the
    // monument is not solid for enemies, which is safe only while no enemy and a
    // live monument share the field. The INVARIANT, retained here: the Unmade
    // Star's one spawn path (campaign and gauntlet alike) wipes the board before
    // the monument arrives, and the wave spawn and the mini-boss bell both require
    // that no boss is on the field. Deleting the wipe, or a gate, must fail.
    let starFlat = flatBody(sceneS8, "private func spawnUnmadeStar()")
    let wipeAt = starFlat.range(of: "for e in enemies { e.removeFromParent() } enemies.removeAll()")
    let starAt = starFlat.range(of: "let star = UnmadeStarNode(")
    let s16Invariant = wipeAt != nil && starAt != nil && (wipeAt?.upperBound ?? starFlat.endIndex) <= (starAt?.lowerBound ?? starFlat.startIndex)
        && n(sceneFlat, "UnmadeStarNode(") == 1 && n(sceneFlat, "spawnUnmadeStar()") == 3
        && n(sceneFlat, "if spawnEvent.shouldSpawnEnemy && boss == nil { spawnEnemy() }") == 1
        && n(sceneFlat, "if spawnEvent.shouldSpawnMiniBoss, boss == nil, !arenaBossSpawnedThisRun { spawnMiniBoss()") == 1
    check("WR22 A7b S16 (CL-125) the monument invariant: the Unmade Star's one spawn path wipes the board before it arrives, and wave spawns and the mini-boss bell require no boss on the field",
          s16Invariant, "wipe \(wipeAt != nil) star \(starAt != nil)")

    // v2.1 geometry Unit 4 — Arena 6 registered and presented (design lock §8–§9,
    // reconciliation §5 Unit 4), on the EXECUTABLE view:
    //  • the Splitworks is arena 6 of ArenaConfig.all (the unlock registry then
    //    opens it on the Unmade Star's defeat) and the DEBUG shell seam is gone;
    //  • Boss Mode: the Marchwarden is registered (home arena 5) and the gauntlet
    //    has its spawner; its defeat records the bestiary, the registry and
    //    Marchworn; the three Splitworks enemies map onto their bestiary families
    //    and every family has a live portrait;
    //  • Marchworn is an earned re-tint in The Broken March family;
    //  • the Arena 6 cues fire on their tells; the horn opens an Arena 6 run;
    //  • the BGM deck (BGMDeck, executed in tools/bgm-harness): MusicManager draws
    //    from ONE deck, never changes the song on a context change, resumes on
    //    toggle / interruption / foreground, and drops a track that won't start.
    // String-bearing needles read the CODE view (comments out, literals intact);
    // the executable view blanks string literals.
    func flatCode(_ text: String) -> String { SwiftSource.code(text).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
    let sceneCode = flatCode(sceneS8)
    let arenaFlat = flatCode(raw("Sparkforge/Config/ArenaConfig.swift"))
    let u4Arena = arenaFlat.contains("static let all: [ArenaConfig] = [crucible, quench, coilworks, mirrorwound, starAnvil, splitworks]")
        && arenaFlat.contains("static let splitworks = ArenaConfig( id: 5,") && arenaFlat.contains("bossID: \"marchwarden\",")
        && !appText.contains("splitworksShell") && !appText.contains("shellIndex") && !appText.contains("forceSplitworksShell")
    let u4Boss = flatCode(raw("Sparkforge/Systems/BossRegistry.swift")).contains("BossEntry(id: \"marchwarden\", name: \"The Marchwarden\", arenaID: 5, grammar: .arena, accentHex: 0x3F8F8A, make: { _, hp in MarchwardenNode(hpScaling: hp) }),")
        && n(sceneCode, "case \"marchwarden\": spawnMarchwarden()") == 1
        && n(sceneCode, "CodexManager.shared.recordDefeat(.marchwarden) ProgressionManager.shared.registerArenaBossDefeat(\"marchwarden\") SkinManager.shared.unlockEarned(\"spark_marchworn\")") == 1
        && n(sceneFlat, "case is SpurhoundNode: return .spurhound case is LinekeeperNode: return .linekeeper case is RamplateNode: return .ramplate") == 1
    let portraitFlat = flatExec(raw("Sparkforge/Nodes/BestiaryCodexNode.swift"))
    let u4Portraits = ["case .spurhound: node = SpurhoundNode(health: 1, xpValue: 0)", "case .linekeeper: node = LinekeeperNode(health: 1, xpValue: 0)",
                       "case .ramplate: node = RamplateNode(health: 1, xpValue: 0)", "case .marchwarden: node = MarchwardenNode()"].allSatisfy { portraitFlat.contains($0) }
    let skinFlat = flatCode(raw("Sparkforge/Systems/SkinManager.swift"))
    let marchwornAt = skinFlat.range(of: "id: \"spark_marchworn\", familyID: \"broken_march\", name: \"Marchworn\",")
    let u4Skin = skinFlat.contains("SkinFamily(id: \"broken_march\", name: \"The Broken March\", secret: false),")
        && marchwornAt != nil && skinFlat.components(separatedBy: "id: \"spark_marchworn\"").count == 2
        && (marchwornAt.map { r in skinFlat[r.upperBound...].prefix(700).contains("tier: .earned,") && skinFlat[r.upperBound...].prefix(900).contains("iapProductID: nil),") } ?? false)
    let u4Cues = n(sceneFlat, "AudioManager.shared.play(.spurhoundWhine)") == 2 && n(sceneFlat, "keeper.onAimStart = { AudioManager.shared.play(.linekeeperAim) }") == 1
        && n(sceneFlat, "AudioManager.shared.play(.ramplateBrace)") == 1 && n(sceneFlat, "warden.onMusterCalled = { AudioManager.shared.play(.wardenMuster) }") == 1
        && n(sceneFlat, "if arenaConfig.id == ArenaConfig.splitworks.id { run(SKAction.sequence([SKAction.wait(forDuration: 1.0), SKAction.run { AudioManager.shared.play(.splitworksHorn) }])) }") == 1
        && flatExec(raw("Sparkforge/Nodes/LinekeeperNode.swift")).contains("phase = .aim phaseTimer = C.aimDuration onAimStart?()")
        && flatExec(raw("Sparkforge/Nodes/MarchwardenNode.swift")).contains("phase = .muster phaseTimer = C.musterSignalDuration onMusterCalled?()")
    let musicRaw = raw("Sparkforge/Systems/MusicManager.swift"), music = flatExec(musicRaw)
    // Re-pinned after the independent review (m2/m3/N1): every transport entry
    // routes through `perform`, whose actions come from BGMPolicy (executed in
    // bgm BP1–BP6); only `.startDeck` and `.playNext` draw; a refused start
    // restores the track; the user-audio check is a first-start rule.
    let u4Music = music.contains("private var deck = BGMDeck<URL>([])") && !music.contains("pools") && !music.contains("lastTrack")
        && flatBody(musicRaw, "func setContext(_ new: Context)") == "{ context = new perform(.contextChanged, fadeIn: true) }"
        && flatBody(musicRaw, "func refresh()") == "{ guard hasTracks else { return } perform(SettingsManager.shared.bgmEnabled ? .toggledOn : .toggledOff, fadeIn: true) }"
        && flatBody(musicRaw, "@objc private func handleDidBecomeActive(") == "{ holds.remove(.background) perform(.becameActive, fadeIn: true) }"
        && flatBody(musicRaw, "@objc private func handleInterruption(").hasSuffix("perform(.interruptionEnded, fadeIn: false) }")
        && flatBody(musicRaw, "func audioPlayerDidFinishPlaying(").hasSuffix("player = nil perform(.trackFinished, fadeIn: false) }")
        && music.contains("switch BGMPolicy.action(for: event, enabled: SettingsManager.shared.bgmEnabled, deferring: deferringToUserAudio, held: !holds.isEmpty, hasPlayer: player != nil) {")
        && music.contains("case .startDeck: playNext(fadeIn: true) case .resume: if let current = player { resume(current, fadeIn: fadeIn) }")
        && music.contains("case .playNext: playNext(fadeIn: false)")
        && music.components(separatedBy: "playNext(fadeIn: true)").count == 2 && music.components(separatedBy: "playNext(fadeIn: false)").count == 2
        && music.contains("if !everStarted, AVAudioSession.sharedInstance().isOtherAudioPlaying {")
        && music.contains("guard let url = deck.draw(using: &rng) else { return } guard let next = try? AVAudioPlayer(contentsOf: url) else { deck.failed(url)")
        && music.contains("guard next.play() else { let dropped = deck.refused(url)") && music.contains("if dropped { continue } return }")
        && music.contains("deck.started(url) everStarted = true")
        // (re-review pins) BGM OFF fades then pauses; only an ENDED interruption
        // resumes; a decode error drops the track and routes as `.trackBroken`.
        // (Oct 1 playtest fix, WR24) the delayed pause asks shouldBeSilent (OFF or
        // held), and a background hold stops the song at once.
        && music.contains("case .pause: player?.setVolume(0, fadeDuration: TimeInterval(GameConfig.BGM.crossfade)) if holds.contains(.background) { player?.pause() } else { DispatchQueue.main.asyncAfter(deadline: .now() + Double(GameConfig.BGM.crossfade)) { [weak self] in if self?.shouldBeSilent == true { self?.player?.pause() } } }")
        && music.contains("AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return } perform(.interruptionEnded, fadeIn: false) }")
        && flatBody(musicRaw, "func audioPlayerDecodeErrorDidOccur(").hasPrefix("{ guard p === player, let url = p.url else { return } deck.failed(url) player = nil")
        && flatBody(musicRaw, "func audioPlayerDecodeErrorDidOccur(").hasSuffix("perform(.trackBroken, fadeIn: false) }")
        && music.contains("name: UIApplication.didBecomeActiveNotification")
        && music.components(separatedBy: "deck.draw(").count == 2
    // The independent review's fixes (Oct 1): the last arena's title card reads
    // that arena's own line; a Boss Mode swap re-validates Growth's persistent
    // placements; the Column Advances finds the Carrier's bodies (arenaLayer).
    let titleCode = flatCode(raw("Sparkforge/Scenes/TitleScene.swift"))
    let u4Review = titleCode.contains("arenaReadyLabel.text = arena.finalFelledLine.isEmpty ? \"★ \\(g.boss.uppercased()) HAS FALLEN ★\" : arena.finalFelledLine")
        && !titleCode.contains("\"★ THE STAR IS UNMADE ★\"")
        && arenaFlat.contains("finalFelledLine: \"★ THE STAR IS UNMADE ★\"") && arenaFlat.contains("finalFelledLine: \"★ THE MARCH IS BROKEN ★\",")
        && flatBody(sceneS8, "private func clampLooseNodesToArena()").hasSuffix("xpOrbs.forEach(clamp) cultivatedZones.forEach(clamp) flowers.forEach(clamp) if let tree = treeNode { clamp(tree) } }")
        && n(sceneFlat, "let solids = self.arenaLayer.children.filter") == 1 && !sceneFlat.contains("worldNode.children.filter { ($0.name")
        && titleCode.contains("let insets = view?.safeAreaInsets ?? .zero let fit = min(1, (size.height - insets.top - insets.bottom - 16) / panelH) if fit < 1 { modal.setScale(fit) }")
    check("WR23 v2.1 geometry Unit 4: the Splitworks is arena 6 (shell seam gone); the Marchwarden is in Boss Mode, the bestiary and Marchworn's unlock; Arena 6's cues fire on their tells; MusicManager plays ONE continuous deck that resumes and drops a failed track",
          u4Arena && u4Boss && u4Portraits && u4Skin && u4Cues && u4Music && u4Review,
          "arena \(u4Arena) boss \(u4Boss) portraits \(u4Portraits) skin \(u4Skin) cues \(u4Cues) music \(u4Music) review \(u4Review)")

    // WR24 — Brandon's release playtest (Oct 1): the song played on under the
    // pause menu and with the app minimized. MusicManager now keeps HOLDS
    // (background, pause menu); a hold pauses the song in place and BGMPolicy
    // (bgm BP7) refuses every resume, start and draw while one stands. The
    // background hold comes from the app's own notification; the pause-menu
    // hold is set by pauseGame and lifted by resumeGame and by quitting to the
    // title (the scene's only exit, so a hold can't outlive its run).
    let holdMusic = music.contains("private enum Hold { case background, pauseMenu } private var holds = Set<Hold>()")
        && music.contains("private var shouldBeSilent: Bool { !SettingsManager.shared.bgmEnabled || !holds.isEmpty }")
        && musicRaw.contains("name: UIApplication.didEnterBackgroundNotification, object: nil)")
        && flatBody(musicRaw, "@objc private func handleDidEnterBackground(") == "{ holds.insert(.background) perform(.held, fadeIn: false) }"
        && flatBody(musicRaw, "func setGamePaused(_ paused: Bool)") == "{ if paused { guard holds.insert(.pauseMenu).inserted else { return } perform(.held, fadeIn: false) } else { guard holds.remove(.pauseMenu) != nil else { return } perform(.released, fadeIn: true) } }"
        && n(music, "holds.insert(") == 2 && n(music, "holds.remove(") == 2
    let holdScene = flatBody(sceneS8, "private func pauseGame()").hasSuffix("pauseMenu.show(upgradeManager: upgradeManager) MusicManager.shared.setGamePaused(true) }")
        && flatBody(sceneS8, "private func resumeGame()").hasSuffix("pauseMenu.hide() MusicManager.shared.setGamePaused(false) }")
        && flatBody(sceneS8, "private func returnToTitle()").contains("BossModeDials.shared.reset() MusicManager.shared.setGamePaused(false) let titleScene")
        && n(sceneFlat, "MusicManager.shared.setGamePaused(") == 3 && n(sceneFlat, "view.presentScene(") == 1
    check("WR24 v2.1 BGM holds (release playtest): the song pauses in place in the background and under the pause menu, and resumes when the hold lifts (Resume, quit to title, back to the foreground)",
          holdMusic && holdScene, "music \(holdMusic) scene \(holdScene)")
}

// MARK: - MD · the card-detail modal fits the smallest iPhone (v2.1 A7b, S0b)
//
// CardDetailNode is SpriteKit and isn't compiled here, so its vertical layout is
// MODELLED below, and MD0 pins every constant the model uses to the node's own
// code lines: change the layout and MD0 fails until the model follows. The
// ceiling is the iPhone SE 2/3 scene, 667pt tall (portrait). A7a's copy passes
// held every card to 665pt; the one pre-existing card above that is Phase
// (666pt, CL-88). Every tree's synergy lines are part of every card's modal, so
// a synergy line that grows is caught here through its tree's tallest card.
func wrappedLines(_ text: String, _ maxChars: Int) -> Int {
    var n = 0, cur = 0
    for w in text.split(separator: " ") {
        if cur == 0 { cur = w.count; n += 1 } else if cur + 1 + w.count <= maxChars { cur += 1 + w.count } else { cur = w.count; n += 1 }
    }
    return n
}
/// The panel height CardDetailNode draws for `c`; `owned` adds the in-run
/// "TIER n / m" line a multi-tier card shows once taken (the taller case).
func modalHeight(_ c: Card, owned: Bool) -> Int {
    var y = 30 + (20 + 14)                                         // name; tag chip + gap
    if c.maxTier > 1 {
        if owned { y += 18 }                                       // TIER n / m
        for t in 1...c.maxTier { y += 14 + 13 * wrappedLines(c.description(forTier: t), 38) + 5 }
        y += 3
    } else {
        y += 16 * wrappedLines(c.description, 34)
    }
    if let d = c.detail, !d.isEmpty, !c.isSecret { y += 4 + 13 * wrappedLines(d, 40) + 2 }
    let tiers = UpgradeManager.synergyTiers(for: c.tag)
    if !tiers.isEmpty {
        y += 8 + 16 + 20                                           // divider, header
        for s in tiers { y += 15 + 13 * wrappedLines(s.effect, 40) + 6 }
    }
    y += 8 + 12                                                    // "tap to close"
    return y + 22 + 18                                             // padTop + padBottom
}
do {
    let node = code("Sparkforge/Nodes/CardDetailNode.swift")
    let layout: String = {
        guard let a = node.range(of: "init(content: Content) {"),
              let b = node.range(of: "@available(*, unavailable)", range: a.upperBound..<node.endIndex) else { return "" }
        return String(node[a.upperBound..<b.lowerBound])
    }()
    let pattern = try! NSRegularExpression(pattern: #"y -= [^\n]+|maxChars: [0-9]+|chipH: CGFloat = [0-9]+"#)
    let tokens = pattern.matches(in: layout, range: NSRange(layout.startIndex..., in: layout))
        .compactMap { Range($0.range, in: layout).map { String(layout[$0]).trimmingCharacters(in: .whitespaces) } }
    let expected = ["y -= 30", "chipH: CGFloat = 20", "y -= chipH + 14", "y -= 18",
                    "y -= 14", "maxChars: 38", "y -= 13", "y -= 5", "y -= 3",
                    "maxChars: 34", "y -= 16",
                    "y -= 4", "maxChars: 40", "y -= 13", "y -= 2",
                    "y -= 8", "y -= 16", "y -= 20", "y -= 15", "maxChars: 40", "y -= 13", "y -= 6",
                    "y -= 8", "y -= 12"]
    let builder = body(node, "static func content(for card: UpgradeManager.UpgradeCard, tagCount: Int, ownedTier: Int) -> Content {")
    // The layout's STRUCTURE too (internal review MED-2): where each spacing sits
    // (inside which loop or branch), the starting y, and the panel formula. A
    // spacing moved into a loop keeps the token order but changes the height.
    let skeleton = layout.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { $0.hasPrefix("for ") || $0.hasPrefix("if ") || $0.hasPrefix("} else") || $0 == "}" || $0.hasPrefix("y -= ")
            || $0.hasPrefix("var y") || $0.hasPrefix("let contentHeight") || $0.hasPrefix("let panelH") }
    let skeletonExpected = [
        "var y: CGFloat = 0", "y -= 30", "if let second = content.secondaryTag { tags.append(second) }", "for tag in tags {",
        "if content.masked {", "}", "}", "y -= chipH + 14", "if let tierLine = content.cardTierLine {", "y -= 18", "}",
        "if let ladder = content.cardLadder, !ladder.isEmpty {", "for rung in ladder {", "y -= 14",
        "for line in Self.wrap(rung.effect, maxChars: 38) {", "y -= 13", "}", "y -= 5", "}", "y -= 3", "} else {",
        "for line in Self.wrap(content.effect, maxChars: 34) {", "y -= 16", "}", "}",
        "if let detail = content.detail, !detail.isEmpty, !content.masked {", "y -= 4", "for line in Self.wrap(detail, maxChars: 40) {",
        "y -= 13", "}", "y -= 2", "}", "if !content.tiers.isEmpty {", "y -= 8", "y -= 16", "y -= 20", "for tier in content.tiers {",
        "y -= 15", "for line in Self.wrap(tier.effect, maxChars: 40) {", "y -= 13", "}", "y -= 6", "}", "}", "y -= 8", "y -= 12",
        "let contentHeight = -y", "let panelH = contentHeight + Self.padTop + Self.padBottom", "}"]
    check("MD0 the modelled layout is the node's own: every spacing and wrap width in order and in place (the layout's skeleton), the start, the panel formula, the pads, the wrap rule and the content builder",
          tokens == expected
            && node.contains("private static let padTop: CGFloat = 22") && node.contains("private static let padBottom: CGFloat = 18")
            && node.contains("} else if current.count + 1 + word.count <= maxChars {")
            && layout.contains("if let detail = content.detail, !detail.isEmpty, !content.masked {")
            && builder.contains("UpgradeManager.synergyTiers(for: card.tag)")
            && builder.contains("CardTierLine(tier: $0, effect: card.description(forTier: $0), reached: $0 <= ownedTier)")
            && builder.contains("cardTierLine: card.maxTier > 1 && ownedTier > 0 ?")
            && builder.contains("effect: card.description, tiers: tiers,")
            && skeleton == skeletonExpected,
          "tokens=\(tokens) skeleton=\(skeleton.count)")
    let heights = pool.map { ($0.id, modalHeight($0, owned: true)) }
    let over = heights.filter { $0.1 > 667 }
    check("MD1 every card's detail modal fits the iPhone SE scene (≤ 667pt, in-run, the taller case)",
          heights.count == pool.count && over.isEmpty, "\(over)")
    let aboveTarget = Set(heights.filter { $0.1 > 665 }.map { "\($0.0) \($0.1)" })
    check("MD2 the cards above A7a's 665pt copy target are exactly the known set: Phase at 666pt",
          aboveTarget == ["void_3 666"] && heights.first { $0.0 == "cap_chill_polarvortex" }?.1 == 665
            // A7b S11: the copy gates kept both capstone modals where they were.
            && heights.first { $0.0 == "cap_void_erasure" }?.1 == 665 && heights.first { $0.0 == "cap_fire_everglow" }?.1 == 652,
          "\(aboveTarget.sorted())")
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
