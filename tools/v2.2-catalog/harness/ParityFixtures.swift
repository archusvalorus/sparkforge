// ParityFixtures.swift — v2.2 catalog migration (J1). Test support only;
// compiled by tools/catalog-harness/run.sh, never part of the app target.
//
// The parity fixtures and how they are made. Two kinds:
//
//   effect deltas     what every card tier and every synergy tier does to a
//                     `PlayerStats`, from three starting states, plus named
//                     scenarios for the effects that read the state they
//                     change, tier ladders, and both orders of interacting
//                     effects
//   run transcripts   seeded runs through the REAL draw and acquisition:
//                     every spread, reroll, bonus card and pick, the synergy
//                     tiers that fired, the Codex writes, and the final state
//
// Everything is produced through an `EffectSource`. The fixtures on disk were
// recorded in J1 from the LEGACY implementation (the compiled
// `UpgradeManager.buildCardPool()` pool and its private synergy switch),
// before the JSON catalog existed; they are the only record of it. Since J2
// the game's only source is `EffectSource.runtime()` (the installed catalog),
// and the run transcripts are reproduced by the real, catalog-backed
// `UpgradeManager` through `ParityRuns.document()`.

import CoreGraphics
import Foundation

// MARK: - Effect source

struct EffectSource {
    let label: String
    /// Card ids in catalog order.
    let cardIDs: [String]
    let tierCount: [String: Int]
    /// id → the tree names it counts toward (primary, then secondary), as `Tag.rawValue`.
    let trees: [String: [String]]
    /// Apply one tier of one card (1-based). False when the source has no such tier.
    let applyTier: (_ id: String, _ tier: Int, _ stats: PlayerStats) -> Bool
    /// Apply one synergy tier's stat effect only. Key = "<Tag.rawValue>_<threshold>",
    /// the Codex's persistence id. False when the source has no such effect.
    let applySynergy: (_ key: String, _ stats: PlayerStats) -> Bool
}

let parityColours: [UpgradeManager.Tag] = [.fire, .shock, .bleed, .guardT, .voidT, .chill, .growth]
let paritySynergyKeys: [String] = parityColours.flatMap { tag in [3, 5, 7].map { "\(tag.rawValue)_\($0)" } }

// MARK: - Steps and scenarios

enum ParityStep {
    case set(String, Int)        // one of the fields `ParityStep.assign` knows
    case card(String, Int)       // id, tier (1-based)
    case synergy(String)         // "<Tag.rawValue>_<threshold>"

    var label: String {
        switch self {
        case .set(let field, let value): return "set \(field)=\(value)"
        case .card(let id, let tier):    return "\(id) T\(tier)"
        case .synergy(let key):          return "synergy \(key)"
        }
    }

    /// Direct assignments used to reach states the cards alone would take long
    /// to reach. Only these fields; an unknown name is an error, not a no-op.
    static func assign(_ field: String, _ value: Int, to stats: PlayerStats) -> Bool {
        switch field {
        case "maxHP":        stats.maxHP = value
        case "currentHP":    stats.currentHP = value
        case "defense":      stats.defense = value
        case "lethalSaves":  stats.lethalSaves = value
        case "thornsoilDPS": stats.thornsoilDPS = value
        default: return false
        }
        return true
    }
}

struct ParityFailure: Error, CustomStringConvertible {
    let description: String
    init(_ text: String) { description = text }
}

/// SplitMix64, the picker's own generator (independent of the manager's).
struct ParityRandom {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func below(_ n: Int) -> Int { n <= 0 ? 0 : Int(next() % UInt64(n)) }
}

enum ParityScenarios {

    private static func ladder(_ id: String, _ tiers: Int) -> [ParityStep] { (1...tiers).map { .card(id, $0) } }

    /// The three starting states. "default" is a new `PlayerStats`; the two
    /// mid-run states are direct assignments followed by a seeded selection of
    /// card tiers and synergy tiers.
    /// `legacy` (v2.2 N1): the card order and tier counts the LEGACY fixtures
    /// were recorded with, so the seeded selection is the same as the record's
    /// even after a card is retired or its ladder grows; nil = the source's own.
    static func startStates(_ source: EffectSource, legacy: (ids: [String], tiers: [String: Int])? = nil) -> [(name: String, steps: [ParityStep])] {
        let order = legacy?.ids ?? source.cardIDs
        let tiers = legacy?.tiers ?? source.tierCount
        func midRun(seed: UInt64, sets: [ParityStep], synergies: [String]) -> [ParityStep] {
            var rng = ParityRandom(seed)
            var ids = order
            for i in stride(from: ids.count - 1, to: 0, by: -1) { ids.swapAt(i, rng.below(i + 1)) }
            var steps = sets
            for id in ids.prefix(30) {
                let upTo = 1 + rng.below(tiers[id] ?? 1)
                steps += (1...upTo).map { .card(id, $0) }
            }
            return steps + synergies.map { .synergy($0) }
        }
        return [
            ("default", []),
            ("midrun-A", midRun(seed: 0xA11CE, sets: [.set("maxHP", 137), .set("currentHP", 121), .set("defense", 23)],
                                synergies: ["Fire_3", "Guard_5", "Chill_7"])),
            ("midrun-B", midRun(seed: 0xB0B, sets: [.set("maxHP", 61), .set("currentHP", 61), .set("defense", 0), .set("lethalSaves", 2)],
                                synergies: ["Bleed_3", "Void_5", "Growth_7", "Fire_5"])),
        ]
    }

    /// Named scenarios: effects that read the state they change, whole tier
    /// ladders, and interacting effects in both orders.
    static let targeted: [(name: String, steps: [ParityStep])] = {
        var out: [(String, [ParityStep])] = []

        // Glass Engine: the HP loss truncates, and current HP is clamped only when above the new max.
        for (maxHP, hp) in [(100, 100), (101, 101), (137, 20), (1, 1), (3, 2)] {
            out.append(("glass-engine maxHP=\(maxHP) hp=\(hp)",
                        [.set("maxHP", maxHP), .set("currentHP", hp), .card("v13_glass_engine", 1)]))
        }
        // Iron Maiden: T1 and T5 grant a share of CURRENT DEF, at least 1.
        for def in [0, 10, 19, 37] {
            out.append(("iron-maiden ladder defense=\(def)", [.set("defense", def)] + ladder("cap_guard_ironmaiden", 5)))
        }
        out.append(("iron-maiden T5 after Deeproot-free DEF gain", ladder("cap_guard_ironmaiden", 4) + [.set("defense", 50), .card("cap_guard_ironmaiden", 5)]))
        // Thornsoil and Wildwood never lower the ground's bite (CL-97), in either order.
        out.append(("thornsoil then wildwood", [.card("v20_thornsoil", 1), .synergy("Growth_7")]))
        out.append(("wildwood then thornsoil", [.synergy("Growth_7"), .card("v20_thornsoil", 1)]))
        out.append(("thornsoil over a higher bite", [.set("thornsoilDPS", 9), .card("v20_thornsoil", 1), .synergy("Growth_7")]))
        // Brace keeps the larger number of saves.
        out.append(("brace from 0", [.card("guard_1", 1)]))
        out.append(("brace from 2", [.set("lethalSaves", 2), .card("guard_1", 1)]))
        // Fire rate: multiplicative steps, both orders.
        let rate: [ParityStep] = ladder("shock_1", 3) + [.card("neutral_3", 1), .card("shock_3", 1), .card("v13_glass_engine", 1)]
        out.append(("fire-rate chain", rate))
        out.append(("fire-rate chain reversed", [.card("v13_glass_engine", 1), .card("shock_3", 1), .card("neutral_3", 1)] + ladder("shock_1", 3)))
        // Fire: Wildfire Heart multiplies what Kindle added; Everglow's ladder doubles in place.
        out.append(("kindle then wildfire heart", [.card("fire_1", 1), .card("fire_4", 1), .synergy("Fire_3"), .synergy("Fire_5"), .synergy("Fire_7")]))
        out.append(("wildfire heart then kindle", [.synergy("Fire_5"), .card("fire_1", 1), .card("fire_4", 1)]))
        out.append(("forge breath then everglow", ladder("fire_2", 3) + ladder("cap_fire_everglow", 5)))
        out.append(("everglow then forge breath", ladder("cap_fire_everglow", 5) + ladder("fire_2", 3)))
        out.append(("overcharge, ember burst, cauterize, relay burn", [.card("v13_overcharge", 1), .card("fire_3", 1), .card("v16_cauterize", 1), .card("v17_relay_burn", 1)]))
        // Guard: both collision-radius multipliers, both orders; the knockback ladder.
        out.append(("harden then unbroken core", [.card("guard_3", 1), .synergy("Guard_3"), .synergy("Guard_5"), .synergy("Guard_7")]))
        out.append(("unbroken core then harden", [.synergy("Guard_7"), .card("guard_3", 1)]))
        out.append(("repulse ladder", ladder("guard_2", 3)))
        out.append(("aegis, fortify, grounded core, phase skin, iron bloom, silver skin",
                    ladder("v16_aegis_pulse", 3) + [.card("guard_4", 1), .card("v17_grounded_core", 1), .card("v13_phase_skin", 1), .card("v16_iron_bloom", 1), .card("v18_silver_skin", 1)]))
        // Chill: slows add; Ice Rink and Absolute Zero both add a global slow.
        out.append(("frost touch, polar vortex, chill synergies",
                    ladder("chill_1", 3) + ladder("cap_chill_polarvortex", 5) + [.synergy("Chill_3"), .synergy("Chill_5"), .synergy("Chill_7")]))
        out.append(("chill synergies, polar vortex, frost touch",
                    [.synergy("Chill_7"), .synergy("Chill_5"), .synergy("Chill_3")] + ladder("cap_chill_polarvortex", 5) + ladder("chill_1", 3)))
        out.append(("glacial drift ladder then absolute zero", ladder("chill_4", 5) + [.synergy("Chill_7")]))
        out.append(("absolute zero then glacial drift ladder", [.synergy("Chill_7")] + ladder("chill_4", 5)))
        out.append(("whiteout, spikes, ice shard, permafrost, hoarfrost",
                    ladder("v16_whiteout", 3) + [.card("v21_glacial_spikes", 1), .card("chill_2", 1), .card("chill_3", 1), .card("v16_hoarfrost", 1)]))
        // Shock: chain targets add from the card and from Chain Current.
        out.append(("chain lightning then chain current", ladder("shock_2", 4) + [.synergy("Shock_3"), .synergy("Shock_5"), .synergy("Shock_7")]))
        out.append(("chain current then chain lightning", [.synergy("Shock_3")] + ladder("shock_2", 4)))
        out.append(("skybeam, sentry, overload, pulse, crown",
                    ladder("cap_shock_skybeam", 5) + ladder("v21_lightning_sentry", 4) + [.card("shock_4", 1), .card("v21_electro_pulse", 1), .card("v16_static_crown", 1)]))
        // Bleed: crit chance and crit multiplier add; kill heal adds to Red Harvest's field's neighbours.
        out.append(("gouge then hemorrhage", ladder("bleed_1", 2) + [.card("bleed_2", 1)]))
        out.append(("hemorrhage then gouge", [.card("bleed_2", 1)] + ladder("bleed_1", 2)))
        out.append(("siphon ladder and bleed synergies", [.card("v21_bloodthirsty", 1)] + ladder("bleed_4", 4) + [.synergy("Bleed_3"), .synergy("Bleed_5"), .synergy("Bleed_7")]))
        out.append(("apex ladder with the bleed kit",
                    ladder("cap_bleed_apex", 5) + [.card("bleed_3", 1), .card("v21_berserk", 1), .card("v21_sanguinarian", 1), .card("v13_execution", 1),
                                                    .card("v16_open_vein", 1), .card("v18_bloodlust", 1), .card("v18_glass_blood", 1), .card("v18_red_smile", 1)]))
        // Void: range adds from two cards; the ladders.
        out.append(("riftline then long shot", [.card("v18_riftline", 1), .card("neutral_4", 1)]))
        out.append(("long shot then riftline", [.card("neutral_4", 1), .card("v18_riftline", 1)]))
        out.append(("phase and erasure ladders, void synergies",
                    ladder("void_3", 3) + ladder("cap_void_erasure", 5) + [.synergy("Void_3"), .synergy("Void_5"), .synergy("Void_7")]))
        out.append(("the void kit",
                    [.card("void_1", 1), .card("void_2", 1), .card("void_4", 1), .card("v21_void_horror", 1), .card("v21_shadow_edge", 1), .card("v13_unstable_core", 1),
                     .card("v16_null_bloom", 1), .card("v17_dead_circuit", 1), .card("v18_mirror_edge", 1), .card("v18_false_opening", 1)]))
        // Growth: regen bonus adds from the card and from Verdant Rise, both orders.
        out.append(("rich soil then verdant rise", [.card("v20_terra", 1), .card("v20_richsoil", 1), .synergy("Growth_3"), .synergy("Growth_5")]))
        out.append(("verdant rise then rich soil", [.synergy("Growth_5"), .synergy("Growth_3"), .card("v20_richsoil", 1), .card("v20_terra", 1)]))
        out.append(("the growth ladders",
                    ladder("v20_tree", 5) + ladder("v20_vinewall", 3) + ladder("v20_seed_spore", 3) + ladder("v20_wildbloom", 3) + [.card("v20_deeproot", 1)]))
        // Neutral: pellets and pickup radius add across cards; the secret ladder.
        out.append(("scatter, fracture shot, storm engine", ladder("neutral_6", 3) + [.card("v18_fracture_shot", 1), .synergy("Shock_7")]))
        out.append(("keen eye then magnetic core", [.card("neutral_2", 1), .card("v13_magnetic_core", 1)]))
        out.append(("magnetic core then keen eye", [.card("v13_magnetic_core", 1), .card("neutral_2", 1)]))
        out.append(("swift, surge, ice rink movement", [.card("neutral_1", 1), .card("shock_3", 1)] + ladder("chill_4", 5)))
        out.append(("xp boost, chain reaction, overclock", [.card("neutral_5", 1), .card("v13_chain_reaction", 1), .card("v17_overclock", 1)]))
        out.append(("panda ladder", ladder("v20_panda", 5)))
        return out
    }()
}

// MARK: - Effect deltas

enum ParityEffects {

    /// `skip`: card ids whose steps are left out (a retired card, v2.2 N1).
    static func apply(_ step: ParityStep, to stats: PlayerStats, with source: EffectSource, skip: Set<String> = []) throws {
        switch step {
        case .set(let field, let value):
            guard ParityStep.assign(field, value, to: stats) else { throw ParityFailure("no rule to set `\(field)`") }
        case .card(let id, let tier):
            if skip.contains(id) { return }
            guard source.applyTier(id, tier, stats) else { throw ParityFailure("\(source.label): no tier \(tier) for card `\(id)`") }
        case .synergy(let key):
            guard source.applySynergy(key, stats) else { throw ParityFailure("\(source.label): no synergy effect `\(key)`") }
        }
    }

    private static func excluding(_ id: String, _ steps: [ParityStep]) -> [ParityStep] {
        steps.filter { if case .card(let other, _) = $0 { return other != id } else { return true } }
    }

    /// The effect-delta document for a source. With `legacy`, the states are
    /// built on the legacy record's card order and tier counts and the steps of
    /// `skip` ids are left out, so the document is comparable to the legacy
    /// fixture everywhere a reviewed overlay does not name a difference.
    static func document(_ source: EffectSource, legacy: (ids: [String], tiers: [String: Int])? = nil, skip: Set<String> = []) throws -> [String: Any] {
        let base = try ParitySnapshot.take(PlayerStats())
        let states = ParityScenarios.startStates(source, legacy: legacy)

        var stateDocs: [String: Any] = [:]
        var cardDocs: [String: Any] = [:]
        var synergyDocs: [String: Any] = [:]
        for state in states {
            let full = PlayerStats()
            for step in state.steps { try apply(step, to: full, with: source, skip: skip) }
            stateDocs[state.name] = ["steps": state.steps.map { $0.label },
                                     "changedFromDefault": ParitySnapshot.diff(base, try ParitySnapshot.take(full))]

            // Each card from this state built WITHOUT that card, tier by tier.
            for id in source.cardIDs {
                let stats = PlayerStats()
                for step in excluding(id, state.steps) { try apply(step, to: stats, with: source, skip: skip) }
                var before = try ParitySnapshot.take(stats)
                var tiers: [Any] = []
                for tier in 1...(source.tierCount[id] ?? 1) {
                    try apply(.card(id, tier), to: stats, with: source, skip: skip)
                    let after = try ParitySnapshot.take(stats)
                    tiers.append(ParitySnapshot.diff(before, after))
                    before = after
                }
                var perState = cardDocs[id] as? [String: Any] ?? [:]
                perState[state.name] = tiers
                cardDocs[id] = perState
            }
            // Each synergy tier on top of the full state.
            for key in paritySynergyKeys {
                let stats = PlayerStats()
                for step in state.steps { try apply(step, to: stats, with: source, skip: skip) }
                let before = try ParitySnapshot.take(stats)
                try apply(.synergy(key), to: stats, with: source, skip: skip)
                var perState = synergyDocs[key] as? [String: Any] ?? [:]
                perState[state.name] = ParitySnapshot.diff(before, try ParitySnapshot.take(stats))
                synergyDocs[key] = perState
            }
        }

        var targeted: [Any] = []
        for scenario in ParityScenarios.targeted {
            let stats = PlayerStats()
            var before = base
            var steps: [Any] = []
            for step in scenario.steps {
                if case .card(let id, _) = step, skip.contains(id) { continue }
                try apply(step, to: stats, with: source, skip: skip)
                let after = try ParitySnapshot.take(stats)
                steps.append(["step": step.label, "changed": ParitySnapshot.diff(before, after)])
                before = after
            }
            targeted.append(["name": scenario.name, "steps": steps])
        }

        return [
            "fieldPaths": base.keys.sorted(),
            "defaultState": base,
            "startStates": stateDocs,
            "cards": cardDocs,
            "synergies": synergyDocs,
            "targeted": targeted,
        ]
    }
}

// MARK: - Run transcripts (the real draw and acquisition)

struct ParityRunSpec {
    let seed: UInt64
    let arenas: Int
    let levels: Int
    /// Take the secret card whenever it is on the table.
    let takeSecret: Bool
    /// After the run, `reset()` the same manager and play this many more levels.
    let levelsAfterReset: Int
}

enum ParityRuns {

    /// The fixed run list. Panda-eligible seeds are found by scanning (the
    /// eligibility roll is the manager's own, seeded); the list is then fixed
    /// in the fixture, and a recapture must reproduce it.
    static func specs() -> [ParityRunSpec] {
        var out: [ParityRunSpec] = []
        for seed in 1...12 { out.append(ParityRunSpec(seed: UInt64(seed), arenas: 6, levels: 100, takeSecret: false, levelsAfterReset: seed <= 3 ? 40 : 0)) }
        for seed in 101...104 { out.append(ParityRunSpec(seed: UInt64(seed), arenas: 1, levels: 100, takeSecret: false, levelsAfterReset: 0)) }
        for seed in 201...202 { out.append(ParityRunSpec(seed: UInt64(seed), arenas: 3, levels: 100, takeSecret: false, levelsAfterReset: 0)) }
        ProgressionManager.shared.arenasUnlocked = 6
        SettingsManager.shared.bannedFamily = nil
        var found = 0, seed: UInt64 = 1_000
        while found < 4, seed < 3_000 {
            if UpgradeManager(seed: seed).pandaEligible {
                out.append(ParityRunSpec(seed: seed, arenas: 6, levels: 100, takeSecret: true, levelsAfterReset: found == 0 ? 40 : 0))
                found += 1
            }
            seed += 1
        }
        return out
    }

    private static func codexState(_ ids: [String]) -> [String: Any] {
        let codex = CodexManager.shared
        let seen = parityColours.flatMap { tag in [3, 5, 7].filter { codex.hasSeenSynergy(tag: tag, tier: $0) }.map { "\(tag.rawValue)_\($0)" } }
        return ["synergiesSeen": seen.sorted(), "cardsOffered": ids.filter { codex.hasOfferedCard($0) }.sorted()]
    }

    private static func managerState(_ um: UpgradeManager) -> [String: Any] {
        var tiers: [String: Int] = [:]
        for card in um.allCards where um.tier(of: card.id) > 0 { tiers[card.id] = um.tier(of: card.id) }
        var counts: [String: Int] = [:]
        for (tag, count) in um.tagCounts { counts[tag.rawValue] = count }
        return [
            "pickedCardIDs": um.pickedCardIDs,
            "cardTiers": tiers,
            "tagCounts": counts,
            "capabilities": um.capabilities.map { $0.rawValue }.sorted(),
            "activeFamilies": um.activeFamilies.map { $0.rawValue }.sorted(),
            "bannedFamily": um.bannedFamily?.rawValue ?? "",
            "pandaEligible": um.pandaEligible,
            "pandaActive": um.pandaActive,
        ]
    }

    /// One segment of play on a manager: `levels` level-ups from level 1.
    private static func play(_ um: UpgradeManager, levels: Int, rng: inout ParityRandom, takeSecret: Bool,
                             base: ParitySnapshot.Fields) throws -> [String: Any] {
        let stats = PlayerStats()
        var rows: [Any] = []
        guard levels > 0 else { return ["levels": rows] }
        for level in 1...levels {
            var shown = um.drawCards(count: 3, level: level)
            um.recordDiscovered(shown)
            var row: [String: Any] = ["level": level, "spread": shown.map { $0.id }]
            if rng.below(5) == 0 {
                shown = um.drawCards(count: 3, level: level)
                um.recordDiscovered(shown)
                row["reroll"] = shown.map { $0.id }
            }
            if rng.below(4) == 0, let bonus = um.drawBonusCard(excluding: shown) {
                shown.append(bonus)
                um.recordDiscovered([bonus])
                row["bonus"] = bonus.id
            }
            var picks: [Any] = []
            for _ in 0..<(rng.below(6) == 0 ? 2 : 1) {
                let legal = um.stillSelectable(shown, atLevel: level)
                guard !legal.isEmpty else { break }
                let secret = takeSecret ? legal.first(where: { $0.isSecret }) : nil
                let choice = secret ?? legal[rng.below(legal.count)]
                let took = um.acquire(choice, stats: stats, level: level)
                let fired = um.checkSynergies(stats: stats).map { "\($0.tag.rawValue)_\($0.tier)|\($0.title)|\($0.effect)" }.sorted()
                picks.append(["id": choice.id, "acquired": took, "tier": um.tier(of: choice.id), "synergies": fired])
            }
            row["picks"] = picks
            rows.append(row)
        }
        return [
            "levels": rows,
            "finalStatsChangedFromDefault": ParitySnapshot.diff(base, try ParitySnapshot.take(stats)),
            "manager": managerState(um),
            "codex": codexState(um.allCards.map { $0.id }),
        ]
    }

    /// The run-transcript document, from the real `UpgradeManager` (since J2,
    /// catalog-backed): the same seeds, picker and bookkeeping as the J1
    /// recording, so the output must equal the recorded fixture exactly.
    static func document() throws -> [String: Any] {
        let base = try ParitySnapshot.take(PlayerStats())
        var runs: [Any] = []
        for spec in specs() {
            CodexManager.shared.resetAll()
            ProgressionManager.shared.arenasUnlocked = spec.arenas
            SettingsManager.shared.bannedFamily = nil
            let um = UpgradeManager(seed: spec.seed)
            var rng = ParityRandom(spec.seed ^ 0x5EED_CA7A_106)
            var run: [String: Any] = [
                "seed": Int(spec.seed), "arenas": spec.arenas, "takeSecret": spec.takeSecret,
                "start": managerState(um),
                "play": try play(um, levels: spec.levels, rng: &rng, takeSecret: spec.takeSecret, base: base),
            ]
            if spec.levelsAfterReset > 0 {
                um.reset()
                run["afterResetStart"] = managerState(um)
                run["afterReset"] = try play(um, levels: spec.levelsAfterReset, rng: &rng, takeSecret: spec.takeSecret, base: base)
            }
            runs.append(run)
        }
        CodexManager.shared.resetAll()
        return ["runs": runs]
    }

    /// Replay a recorded segment's picks through a source: the same tiers in
    /// the same order, synergy tiers applied when a tree's count of distinct
    /// cards reaches 3, 5 or 7 (counted from the source's own trees). Returns
    /// the problems found; empty means the final state matches the record and
    /// the same synergy tiers fired at the same picks.
    static func replay(_ segment: [String: Any], with source: EffectSource, base: ParitySnapshot.Fields,
                       skip: Set<String> = [], finalDiff: UnsafeMutablePointer<[String: [String]]>? = nil) throws -> [String] {
        var problems: [String] = []
        let stats = PlayerStats()
        var counts: [String: Int] = [:]
        for case let row as [String: Any] in segment["levels"] as? [Any] ?? [] {
            for case let pick as [String: Any] in row["picks"] as? [Any] ?? [] {
                guard let id = pick["id"] as? String, let tier = pick["tier"] as? Int, pick["acquired"] as? Bool == true else {
                    problems.append("level \(row["level"] ?? "?"): a recorded pick was not acquired or is malformed")
                    continue
                }
                if skip.contains(id) { continue }          // a retired card's recorded pick (v2.2 N1)
                guard source.applyTier(id, tier, stats) else { problems.append("\(id) T\(tier): the source has no such tier"); continue }
                var due: [String] = []
                if tier == 1 {
                    for tree in source.trees[id] ?? [] where tree != UpgradeManager.Tag.neutral.rawValue {
                        counts[tree, default: 0] += 1
                        if [3, 5, 7].contains(counts[tree] ?? 0) { due.append("\(tree)_\(counts[tree] ?? 0)") }
                    }
                }
                due.sort()
                let recorded = (pick["synergies"] as? [String] ?? []).map { String($0.split(separator: "|")[0]) }
                if due != recorded { problems.append("level \(row["level"] ?? "?") \(id): synergy tiers \(due) ≠ recorded \(recorded)") }
                for key in due where !source.applySynergy(key, stats) { problems.append("no synergy effect `\(key)`") }
            }
        }
        let final = ParitySnapshot.diff(base, try ParitySnapshot.take(stats))
        if let out = finalDiff { out.pointee = final }
        else if let recorded = segment["finalStatsChangedFromDefault"] as? NSDictionary, final as NSDictionary != recorded {
            problems.append("final stats differ from the record")
        }
        return problems
    }
}

// MARK: - Comparing documents

enum ParityCompare {
    /// Where two JSON-shaped values first differ ("" when equal), for a useful failure line.
    static func firstDifference(_ a: Any?, _ b: Any?, path: String = "") -> String {
        switch (a, b) {
        case (let x as [String: Any], let y as [String: Any]):
            for key in Set(x.keys).union(y.keys).sorted() {
                let d = firstDifference(x[key], y[key], path: path.isEmpty ? key : path + "." + key)
                if !d.isEmpty { return d }
            }
            return ""
        case (let x as [Any], let y as [Any]):
            if x.count != y.count { return "\(path): \(x.count) items ≠ \(y.count)" }
            for i in x.indices {
                let d = firstDifference(x[i], y[i], path: "\(path)[\(i)]")
                if !d.isEmpty { return d }
            }
            return ""
        case (let x as NSObject, let y as NSObject):
            return x == y ? "" : "\(path): \(x) ≠ \(y)"
        case (nil, nil):
            return ""
        default:
            return "\(path): present on one side only"
        }
    }
}
