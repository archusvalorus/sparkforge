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
        ("cap_bleed_apex T4", tierLine("cap_bleed_apex", 4), "Marked: foes alive 10s take +35% damage"),
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
        ("v13_unstable_core detail", card("v13_unstable_core").detail, "Every 4s, deal 2 damage to enemies within 60pt. Each burst also costs you 10 HP minus your DEF (at least 1)."),
        ("neutral_3 face", card("neutral_3").description, "+11% attack speed"),
        ("neutral_6 face", card("neutral_6").description, "+1 projectile (two parallel shots)"),
        ("neutral_6 T1 rung", tierLine("neutral_6", 1), "+1 projectile (two parallel shots)"),
    ]
    let wrong = approved.filter { $0.1 != $0.2 }.map { $0.0 }
    check("CP1 the approved faces and short details are in place, exactly (\(approved.count) strings)", wrong.isEmpty, "\(wrong)")
    let longDetails: [(String, String)] = [
        ("cap_fire_everglow", "Mini-bosses take half pulse damage. Bosses and mini-bosses take half eruption damage."),
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
    check("CP4 deferred copy untouched: Permafrost (CL-94), Shatter (CL-99), Rootbound (CL-96)",
          card("chill_3").description == "Slowed enemies take +25% damage"
              && card("chill_3").detail == "Slowed enemies take 25% more damage, regardless of the slow's source."
              && UpgradeManager.synergyTiers(for: .chill).first { $0.threshold == 5 }?.effect == "Frozen enemies burst when struck"
              && UpgradeManager.synergyTiers(for: .growth).first { $0.threshold == 3 }?.effect == "Cultivated ground grips harder — enemies on it are slower")

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

// MARK: - WR · scene wiring the harness can't execute (exact lines, comments stripped)

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
func code(_ rel: String) -> String {
    let text = (try? String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8)) ?? ""
    return text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
        if let r = line.range(of: "//") { return String(line[..<r.lowerBound]) }
        return String(line)
    }.joined(separator: "\n")
}
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
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
