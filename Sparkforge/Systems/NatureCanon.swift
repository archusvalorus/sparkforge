// NatureCanon.swift
// Sparkforge
//
// v2.0 Phase C, part 2 — the roster behind the Tree capstone's T5, "The Forest
// Wakes". The NATURE CANON: the double pun on canon/cannon is intentional.
//
// WHY THIS FILE EXISTS
// C1.6 shipped the launcher with a placeholder roster in which an animal was a
// data TUPLE — damage × radius × a lone `leavesThorns` flag. The locked roster
// (docs/nature-canon-roster-design.md) cannot be said that way: homing, timed
// turrets, devour and propagating poison aren't numbers, they're ACTIONS. So an
// animal now carries a BEHAVIOUR, and the scene dispatches on it. That one
// change is what turns ten flavour entries into ten small reusable mechanics —
// the reuse map (Fox→homing→Panda samurai, Skunk→Decay, Hedgehog→timed
// structures) only exists because behaviour is a first-class field.
//
// THE SPLIT (the same one the flowers and the Tree already use)
//   • this file  — WHO the animals are: identity, tier, which behaviour they run
//   • GameScene  — WHAT a behaviour does: it owns the enemies, the targeting
//                  brain (`findPriorityTarget`) and the effects
//   • GameConfig — every number, per the studio rule
//
// Launch flow (Brandon, locked): roll a TIER by weight → pick uniformly inside
// that tier → run that animal's behaviour. The mountain lion is its own 5% tier
// rather than a separate coin-flip, so the jackpot sits in one table with
// everything else.

import CoreGraphics

enum NatureCanon {

    // MARK: - Tiers

    /// Rarity bands. Order matters only for legibility here — the roll walks
    /// them by weight, not by position.
    enum Tier: CaseIterable {
        case common, uncommon, rare, lion

        var weight: CGFloat {
            switch self {
            case .common:   return GameConfig.NatureCanon.weightCommon
            case .uncommon: return GameConfig.NatureCanon.weightUncommon
            case .rare:     return GameConfig.NatureCanon.weightRare
            case .lion:     return GameConfig.NatureCanon.weightLion
            }
        }
    }

    // MARK: - Behaviour

    /// What an animal DOES on its launch. The scene owns the implementations;
    /// this is the vocabulary they share.
    ///
    /// Deliberately caseless-payload: every knob lives in GameConfig, so a
    /// behaviour is pure identity and the roster stays readable as a roster.
    enum Behaviour {
        case ninjaKick      // 🐰 Rabbit    — forced auto-crit, one enormous hit
        case scatter        // 🐿️ Squirrel  — impact, then acorn fragments outward
        case homingBurst    // 🦊 Fox       — tracks its mark, then a fur AoE
        case trample        // 🦌 Deer      — antlers-first, heavy single + knockback
        case gore           // 🦫 Boar      — pierces a line, shoves everything aside
        case needleTurret   // 🦔 Hedgehog  — posts up, needle machine-gun for 3s
        case eruption       // 🐦 Bluebird  — tiny body, enormous boom
        case poisonCloud    // 🦨 Skunk     — a cloud that PROPAGATES off its kills
        case devour         // 🦡 Badger    — eats up to 3 foes, heals off their HP
        case prowl          // 🦁 Lion      — the jackpot pet, roams and mauls
    }

    // MARK: - The animals

    struct Animal {
        let id: String
        let emoji: String
        /// The move's name — for reveal copy, the codex, and the Boar's shout.
        let move: String
        let tier: Tier
        let behaviour: Behaviour
        /// Is this animal's behaviour BUILT yet? The roster is declared whole
        /// (it's the locked design, and reading it as a set is the point) while
        /// the tiers land one unit at a time. `roll` skips anything not live and
        /// renormalizes, so a half-built roster still rolls a coherent mix
        /// instead of a bogus distribution. Flip a flag as its unit lands; when
        /// all ten are true this field has done its job and can go.
        let isLive: Bool
    }

    /// The locked roster (docs/nature-canon-roster-design.md).
    static let roster: [Animal] = [
        // --- Common (50%) ---
        Animal(id: "rabbit",   emoji: "🐰", move: "Ninja Kick",
               tier: .common,   behaviour: .ninjaKick,    isLive: true),
        Animal(id: "squirrel", emoji: "🐿️", move: "Scatter",
               tier: .common,   behaviour: .scatter,      isLive: true),
        Animal(id: "fox",      emoji: "🦊", move: "Homing Fur-Missile",
               tier: .common,   behaviour: .homingBurst,  isLive: true),

        // --- Uncommon (25%) ---
        Animal(id: "deer",     emoji: "🦌", move: "Trample",
               tier: .uncommon, behaviour: .trample,      isLive: true),
        Animal(id: "boar",     emoji: "🦫", move: "BOAR GORE!",
               tier: .uncommon, behaviour: .gore,         isLive: true),
        Animal(id: "hedgehog", emoji: "🦔", move: "Needle Barrage",
               tier: .uncommon, behaviour: .needleTurret, isLive: true),

        // --- Rare (15%) — the Skunk gets its own unit (N4) ---
        Animal(id: "bluebird", emoji: "🐦", move: "WTFROFLSTOMP",
               tier: .rare,     behaviour: .eruption,     isLive: true),
        Animal(id: "skunk",    emoji: "🦨", move: "Persist",
               tier: .rare,     behaviour: .poisonCloud,  isLive: true),
        Animal(id: "badger",   emoji: "🦡", move: "Thief",
               tier: .rare,     behaviour: .devour,       isLive: true),

        // --- Lion (5%) ---
        Animal(id: "lion",     emoji: "🦁", move: "Prowl",
               tier: .lion,     behaviour: .prowl,        isLive: true),
    ]

    // MARK: - The roll

    /// Roll one launch: a tier by weight, then uniformly inside it.
    ///
    /// `allowLion` is how the scene enforces "only one may prowl at a time" —
    /// while a lion is out its tier drops from the table entirely and the rest
    /// renormalize, rather than the launch being wasted on a re-roll.
    ///
    /// Normalizing by the live total also quietly handles the locked weights
    /// summing to 0.95 rather than 1.0: what's locked is the RATIO between the
    /// bands, and that ratio survives normalization exactly.
    static func roll(allowLion: Bool) -> Animal? {
        let pool = roster.filter { $0.isLive && (allowLion || $0.tier != .lion) }
        guard !pool.isEmpty else { return nil }

        let tiers = Tier.allCases.filter { tier in pool.contains { $0.tier == tier } }
        let total = tiers.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }

        var roll = CGFloat.random(in: 0..<total)
        for tier in tiers {
            roll -= tier.weight
            if roll < 0 { return pool.filter { $0.tier == tier }.randomElement() }
        }
        return pool.last   // float-rounding fallback; never reached in practice
    }
}
