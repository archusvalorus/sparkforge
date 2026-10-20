// UpgradeManager.swift
// Sparkforge
//
// Manages the card pool: 80 cards = 79 draftable + the secret Panda, across
// seven trees and Neutral (v2.1 A7a). The exact counts, and that every card
// is reachable through the real draw, are proven by tools/catalog-harness.
// Handles the random draw and applying effects to PlayerStats.
//
// v2.2 J2 (CL-113): the card DEFINITIONS are authored in
// Sparkforge/Catalog/ability-catalog.json and the EFFECTS live in
// AbilityBehaviors.swift; `AbilityCatalog` loads and joins them once at
// startup, and this class reads `AbilityCatalog.current`. The pool's order,
// copy, flags and gates are the file's; nothing here defines a card any more.
//
// v1.4: Card rebalancing for HP system:
//   - Brace: +1 lethal save (unchanged — triggers at 0 HP now)
//   - Iron Skin synergy: +15 DEF (was +2 lethal saves)
//   - Glass Engine: -30% max HP (was lose lethal save)
//   - Unstable Core: 10 HP self-damage (was lose lethal save)
// + Build identity hint detection
//
// v1.9: card-leveling engine — cards may carry a tier ladder
// (`higherTiers`); picking an owned, non-maxed card levels it instead of
// being excluded from draws. 1-tier cards (no ladder) behave exactly as
// v1.8. Tier state is per-run only.

import Foundation

final class UpgradeManager {
    
    // MARK: - Tags
    
    enum Tag: String, CaseIterable {
        case fire    = "Fire"
        case shock   = "Shock"
        case bleed   = "Bleed"
        case guardT  = "Guard"
        case voidT   = "Void"
        case chill   = "Chill"
        /// v2.0 Phase C — the 7th tagged tree. Growth modifies the ARENA rather
        /// than Spark: cultivated ground, living structures, territory.
        case growth  = "Growth"
        case neutral = "Neutral"
    }
    
    /// v2.0 Phase C: a named thing a run can possess, used to gate offers.
    /// Deliberately its own type rather than reusing Tag — a capability is not
    /// always a tree ("has a bleed source" isn't the Bleed tag), and conflating
    /// them is what would force a second gating system later.
    enum Capability: String, Hashable {
        /// The run has cultivated ground. Granted by Terra; required by every
        /// other Growth card. Picking Terra is opting into a build grammar.
        case growthUnlocked

        // v2.1 (abilities) — signature capabilities, one per tree. Granted by
        // the tree's SIGNATURE card; the v2.1 rework pass authors `requires`
        // on the rest of each tree so a tree opens the way Growth always has.
        // Growth keeps `growthUnlocked` (live-run persistence never renames).
        case fireUnlocked
        case chillUnlocked
        case shockUnlocked
        case bleedUnlocked
        case guardUnlocked
        case voidUnlocked

        // v2.1 A2 — in-tree prerequisites (NOT gateways: no pity; see drawCards).
        /// Granted by Glacial Drift; required by Glacial Spikes.
        case glacialDrift
        /// Granted by Whiteout (T1+); required by Glacial Drift's T5 Ice Rink (Q-C1).
        case whiteout
        /// v2.1 A6 (CL-82): granted by a card that creates player black holes
        /// (Gravity Well, Null Bloom); required by Dead Circuit, which only
        /// amplifies them.
        case voidWell

        // v2.1 A7a — the catalog audit's enabler edges (never an amplifier
        // before its enabler; closure table §B6).
        /// CL-91: granted by Gouge, the pool's crit source; required by
        /// Hemorrhage, which only multiplies crits (base crit chance is 0).
        case critSource
        /// CL-92: granted by Polar Vortex; required by Frost Touch's T3, whose
        /// shards and icicle fragments only exist with Polar Vortex.
        case polarVortex
        /// CL-93: granted by Polar Vortex T4 (Glacial Condensation), which
        /// replaces the primary pellet with its icicle. Pellet-only cards are
        /// `blockedBy` it: once owned they would do nothing.
        case glacialCondensation
        /// CL-93 is SYMMETRIC (Command Center correction, Sep 25): granted by
        /// every pellet-only card (Warp Shot, Gravity Well, Mirror Edge,
        /// Fracture Shot, Riftline). Polar Vortex T4 is `tierBlockedBy` it, so
        /// owning one of them stops the capstone at T3 instead of a later pick
        /// silently switching the earlier one off.
        case pelletEffect
        /// N6: Rapid Fire T5. Blocks only the two effects with no beam behavior.
        case chaosBeam
        /// N6: Warp Shot or Mirror Edge owned; closes only Rapid Fire T5.
        /// Kept separate from pelletEffect: wells, Fracture and Riftline work on beams.
        case beamIncompatible
    }

    // MARK: - Card Definition
    
    struct UpgradeCard {
        let id: String
        let name: String
        let tag: Tag
        /// v1.7 dual-tag cards (Lyra rule): counts toward BOTH tag totals,
        /// no pick popup. Rare — bridges, not soup.
        var secondaryTag: Tag? = nil
        let description: String
        /// Tier 1 effect — every card's original `apply`, unchanged.
        let apply: (PlayerStats) -> Void
        /// v1.9: tiers 2..N. Each closure is the DELTA applied on that
        /// level-up (PlayerStats is additive — rungs add, never re-set).
        /// Empty → a 1-tier card: picked once, maxed, exactly v1.8 behavior.
        var higherTiers: [(PlayerStats) -> Void] = []
        /// v1.9: per-tier copy for the selection card / Codex. Index i is
        /// tier i+1's line. nil → `description` serves every tier.
        var tierDescriptions: [String]? = nil
        /// v2.1 (abilities): expanded detail — the full approved wording plus
        /// the cooldowns, prerequisites and rules the card can't fit. Shown on
        /// the detail surfaces (pause build viewer, Card Codex) and the Card
        /// Atlas. The selection card shows `description` in 4 lines of 17
        /// characters; a card with `detail` (or an overflowing line) gives its
        /// 4th line to a MORE chip that opens this text (A1b). Keep
        /// `description` compact — 3 lines when there is a `detail`.
        var detail: String? = nil
        /// v1.9 Unit 3: the one tier-5 capstone per tree. Reaching its max tier
        /// fires the grand capstone reveal (vs a quiet flourish for signature
        /// maxes). Capstone IDENTITIES are authored from Lyra's tier riff.
        var isCapstone: Bool = false

        // MARK: v2.0 Phase C — offer eligibility
        //
        // ONE layer, three jobs. Growth's Terra gate is what forced it, but the
        // same provides/requires check is what the banked "never offer an
        // AMPLIFIER before its ENABLER" rule needs (a bleed-damage card with no
        // bleed source is a dead pick that kills tension), and what arena
        // tree-gating / element omission will need later. Do not build a second
        // gating system for those — extend this one.

        // MARK: v2.1 (abilities) — signature cards

        /// The tree's SIGNATURE: its thesis card, the mandatory first pick that
        /// modifies basic attacks and opens the rest of the tree. Exactly one
        /// per tagged tree; Neutral has none (it is the palette's constant, not
        /// a tree). A signature always `provides` its tree's capability, which
        /// is also what buys it gateway pity for free.
        var isSignature: Bool = false

        /// Capabilities this card grants the run when picked.
        var provides: Set<Capability> = []
        /// Capabilities the run must ALREADY have for this card to be offered.
        /// Unmet ⇒ hard-gated out of the draw entirely.
        var requires: Set<Capability> = []
        /// v2.1 A2: extra capabilities a specific TIER needs before its
        /// upgrade is offered (key = the tier being bought). Glacial Drift's
        /// T5 Ice Rink needs Whiteout; until then the card stops at T4.
        var tierRequires: [Int: Set<Capability>] = [:]
        /// v2.1 A7a (CL-93): extra capabilities a specific TIER grants when it
        /// is bought (key = the tier). `provides` stays the first-pick grant.
        var tierProvides: [Int: Set<Capability>] = [:]
        /// v2.1 A7a (CL-93): capabilities that switch this card's whole effect
        /// OFF. Once the run holds any of them the card is no longer offered —
        /// the negative edge `requires` can't express. A copy already owned
        /// is untouched; the player chose what silenced it.
        var blockedBy: Set<Capability> = []
        /// v2.1 A7a (CL-93, symmetric): capabilities that close a specific
        /// TIER (key = the tier being bought). Polar Vortex T4 closes once a
        /// pellet-only card is owned; its earlier tiers stay open.
        var tierBlockedBy: [Int: Set<Capability>] = [:]

        // MARK: v2.0 (C2) — outside the taxonomy

        /// A SECRET card. It is not part of the normal game: never in the random
        /// pool, never a bonus draw, never a gateway-pity candidate, no synergy
        /// contribution, and its Codex entry stays masked forever. It reaches a
        /// spread only because a scheduler put it there.
        ///
        /// Built for Panda, whose whole premise is that it is never fully
        /// legible — but the flag itself is generic, so any future "this isn't in
        /// the taxonomy" card rides it rather than growing a second path.
        var isSecret: Bool = false

        /// Per-tier NAME, index i = tier i+1. nil → `name` at every tier.
        ///
        /// Normally a card's name is fixed and only its copy changes per rung.
        /// Panda inverts that: the punctuation ladder (`Pandas.` → `Panda!` →
        /// `Panda...?` → `Panda.` → `PANDA.`) is the only information the player
        /// ever gets, and the ability text stays `???` at every tier.
        var tierNames: [String]? = nil

        var maxTier: Int { 1 + higherTiers.count }

        /// Copy for a tier (1-based); falls back to `description`.
        func description(forTier tier: Int) -> String {
            guard let lines = tierDescriptions, tier >= 1, tier <= lines.count else {
                return description
            }
            return lines[tier - 1]
        }

        /// Name for a tier (1-based); falls back to `name`.
        func name(forTier tier: Int) -> String {
            guard let names = tierNames, tier >= 1, tier <= names.count else { return name }
            return names[tier - 1]
        }
    }
    
    // MARK: - Dev tools (DEBUG only)

    #if DEBUG
    /// PERMANENT dev force-slot. Set to a card id to guarantee it appears in
    /// EVERY level-up draw until it maxes — the fast path for iterating on a new
    /// skill / tree / capstone (level it, max it, watch the flourish/reveal).
    /// Leave `nil` for natural draws so it never distorts a feel-test unless you
    /// opt in. Change this one value to point at whatever you're building.
    /// (Release builds never see this — `#if DEBUG`.)
    ///
    /// Card ids live in Sparkforge/Catalog/ability-catalog.json, e.g.: "neutral_6" (Scatter),
    /// "fire_2" (Forge Breath), "shock_1" (Static), "bleed_1" (Gouge),
    /// "guard_4" (Fortify), "void_3" (Phase), "chill_1" (Frost Touch).
    static let debugForcedCardID: String? = nil
    #endif

    // MARK: - State

    /// Cards the player has picked this run (by ID), in FIRST-pick order —
    /// leveling a card doesn't reorder it. Drives the build viewer,
    /// analytics, and build hints.
    private(set) var pickedCardIDs: [String] = []

    /// v2.0 Phase C: capabilities this RUN has unlocked. Per-run, never
    /// persisted — reset with everything else, like pickedCardIDs.
    private(set) var capabilities: Set<Capability> = []

    /// Level-ups since each GATEWAY card was last offered, driving the pity
    /// guarantee below. Keyed by card id; per-run like everything else here.
    private var levelsSinceGatewayOffer: [String: Int] = [:]
    /// The level the last draw was for, so a REROLL of the same level doesn't
    /// tick the pity counter (a reroll is one offer, not two).
    private var lastDrawLevel: Int = -1

    /// Level-ups a gateway has waited unseen. Read-only; the catalog harness
    /// uses it to prove a gateway the +1 Card shows counts as offered (CL-89).
    func gatewayWait(_ id: String) -> Int { levelsSinceGatewayOffer[id] ?? 0 }

    /// v1.9: id → current tier this run (absent = not owned). Per-run,
    /// reset with everything else — no persistence, like pickedCardIDs.
    private(set) var cardTiers: [String: Int] = [:]

    /// v2.1 A7a (CL-89): the cards taken at the level `cardsTakenLevel`. The
    /// +1 Card bonus never re-offers one of them at the same level-up (after
    /// the Extra Pick's first selection, it could otherwise hand the same card
    /// its next tier twice in one level).
    private var cardsTakenLevel: Int = -1
    private var cardsTakenThisLevel: Set<String> = []

    /// v2.1 A7a (CL-90): every random choice the draft makes — the palette,
    /// the Panda roll, the shuffles and the bonus pick — goes through this one
    /// source. Production passes no seed and gets the system generator; the
    /// catalog harness seeds it so its reachability walks reproduce exactly.
    struct DrawRandom: RandomNumberGenerator {
        private var state: UInt64?
        init(seed: UInt64?) { state = seed }
        mutating func next() -> UInt64 {
            guard var s = state else {
                var system = SystemRandomNumberGenerator()
                return system.next()
            }
            // SplitMix64: tiny, fast, and good enough for a card shuffle.
            s &+= 0x9E37_79B9_7F4A_7C15
            state = s
            var z = s
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
    private var rng: DrawRandom

    // MARK: v2.1 (abilities) — the signature opening

    /// Does the run hold at least one SIGNATURE card yet? While false, every
    /// spread offers only signatures (the deterministic first pick). The state
    /// ends the moment the first signature is taken — which, since a signature
    /// spread contains nothing else, is the first pick.
    var runHoldsSignature: Bool {
        allCards.contains { $0.isSignature && tier(of: $0.id) > 0 }
    }

    /// Signatures already SHOWN at the current level, driving the reroll rule
    /// (Lyra, locked Aug 23): a reroll of the signature spread prioritizes the
    /// UNSEEN signatures — 5 active trees means the reroll shows the 2 unseen
    /// plus 1 returning option. Reset when the level advances, like the pity
    /// counter's reroll guard.
    private var signatureIDsSeenThisLevel: Set<String> = []

    /// v1.9: current tier of a card (0 = not owned this run).
    func tier(of cardID: String) -> Int {
        cardTiers[cardID] ?? 0
    }

    /// v1.7: Picked cards in pick order, for the pause build viewer
    var pickedCards: [UpgradeCard] {
        pickedCardIDs.compactMap { id in allCards.first { $0.id == id } }
    }

    // MARK: - v2.0 (C2) — the Panda run mutation
    //
    // Panda is not a tree you can go looking for; it is something that happens
    // to a run. The rules below are LOCKED (Brandon + Lyra) and are the only
    // part of Panda that is allowed to be legible — to us, not to the player.
    //
    //   • At run start, a 9.27% roll decides whether this run is even eligible.
    //     The number is arbitrary on purpose. Not 10%. Not 9%.
    //   • If eligible, the offer appears in an EARLY window, so a player who
    //     commits can still reach T5 before the run ends.
    //   • ACTIVATION IS TAKING THE CARD, not seeing it. Passing costs nothing.
    //   • Once active, every OTHER level-up guarantees a Panda slot, climbing
    //     T2→T5 deterministically. Passing a rung isn't punished — it comes back
    //     at the next scheduled offering. Waiting. Judging.
    //   • You cannot reroll the panda: the schedule keys off the LEVEL, so a
    //     reroll of the same level re-offers it. By the same token it can never
    //     appear *because* you rerolled.

    // MARK: - v2.0 (E1) — active colour families
    //
    // THE PROBLEM (Brandon, felt in play): with seven tagged trees plus Neutral,
    // a 3-card spread spreads too thin. Terra surfaced once in a whole run, and
    // a tree you can't find is a tree that doesn't exist. Every tree we ship
    // makes it worse, so the fix has to be structural rather than a re-weighting.
    //
    // THE RULE: a run runs on `activeColorFamilies` COLOURS plus Neutral, which
    // is always in and is not a colour. Everything outside that set is absent
    // from the draw entirely — not down-weighted, absent, the same hard gate the
    // eligibility layer already uses for `requires`.
    //
    // Why one ban and not more (Brandon): one ban lets a player dodge the tree
    // they'll never play; two starts letting them ENGINEER the run, and the
    // tension being protected is the first thing optimization kills.
    //
    // This rides the existing eligibility layer on purpose. The banked guidance
    // was explicit: arena tree-gating and element omission extend that layer
    // rather than growing a second gating system.

    /// The colours this run draws from, plus Neutral. Decided once, at reset.
    private(set) var activeFamilies: Set<Tag> = []

    /// The colour this run honoured as banned, recorded when the palette rolled.
    ///
    /// Read from the sticky setting at roll time rather than pushed in by a
    /// caller — one source of truth, and nothing to forget to wire. It also
    /// means changing the ban mid-run can't reshape the run you're in: the
    /// palette is already decided, and the new ban applies from the next one.
    private(set) var bannedFamily: Tag? = nil

    /// Colours this save has earned, by arena progress (E3).
    ///
    /// Kept as its own step from the cap so the whole thing degrades gracefully:
    /// a save with fewer colours unlocked than `activeColorFamilies` simply
    /// plays with all of them, and the run is smaller rather than broken. That
    /// matters most for a brand-new save, which is exactly when a crash or an
    /// empty draft would be least forgivable.
    private var unlockedFamilies: [Tag] {
        let arenas = ProgressionManager.shared.arenasUnlocked
        return Tag.allCases.filter {
            $0 != .neutral && arenas >= GameConfig.Drafting.unlockArena(for: $0)
        }
    }

    /// Roll this run's palette: drop the banned colour, take the cap at random,
    /// and Neutral is always there.
    private func rollActiveFamilies() {
        bannedFamily = SettingsManager.shared.bannedFamily
        var candidates = unlockedFamilies
        // The ban is a PROMISE — "one tree, never offered" — so it is honoured
        // whenever the tree is unlocked at all. Quietly ignoring it when the
        // pool is small would be the worse betrayal.
        if let banned = bannedFamily { candidates.removeAll { $0 == banned } }

        // ALWAYS leave at least one colour out, so the palette can never become
        // deterministic. Without this, a new save (six trees) that bans one has
        // exactly five candidates for five slots and draws the identical palette
        // every single run until Arena 5 unlocks Growth — the variety this whole
        // system exists to protect, gone, for the players least equipped to
        // notice why. The cost is a 4-colour run in that narrow case, and it
        // self-corrects the moment another tree unlocks.
        let cap = min(GameConfig.Drafting.activeColorFamilies, max(1, candidates.count - 1))
        activeFamilies = Set(candidates.shuffled(using: &rng).prefix(cap))
        activeFamilies.insert(.neutral)   // non-negotiable, and not a colour
    }

    /// Did this run roll Panda-eligible? Decided once, at reset.
    private(set) var pandaEligible = false
    /// Has the player TAKEN the first Panda card? The commitment point.
    private(set) var pandaActive = false
    /// The level at which activation happened — anchors the every-other-level
    /// parity from then on.
    private var pandaActivationLevel = 0

    /// Tag counts for synergy tracking
    private(set) var tagCounts: [Tag: Int] = [:]
    
    /// All available cards
    let allCards: [UpgradeCard]
    
    /// v1.4: Track which build hints have been shown this run
    private var shownBuildHints: Set<String> = []
    
    // MARK: - Init
    
    /// `seed` is for the catalog harness only (CL-90); the game never passes one.
    init(seed: UInt64? = nil) {
        // v1.9 Unit 3: signature ladders now live in the release pool
        // (buildCardPool); the Unit 1 DEBUG proof ladder is retired.
        rng = DrawRandom(seed: seed)
        allCards = AbilityCatalog.current.cards
        rollRunMutations()
    }
    
    // MARK: - Draw

    /// v2.1 A7a (CL-89; corrective F2): THE offer rule — may this card appear
    /// in a spread during the level-up at `level`? Every draw path uses it (the
    /// level-up spread, reroll, the random opener and the +1 Card bonus), and
    /// acquisition checks it again (`isSelectable`), so a rule can't be added
    /// to one path and forgotten in another — which is how the bonus came to
    /// skip four rules and reroll the same-level one. Scheduled offers sit
    /// OUTSIDE it on purpose: an active capstone's every-other-level guarantee
    /// and the panda's slot.
    private func isOfferable(_ card: UpgradeCard, capstoneInProgress: Bool, level: Int,
                             additionalTierGate: (UpgradeCard) -> Bool = { _ in true }) -> Bool {
        guard tier(of: card.id) < card.maxTier else { return false }
        // Corrective F2: a card taken during THIS level-up never comes back at
        // its next tier in the same level-up — spread, reroll or bonus alike.
        guard !takenAt(level).contains(card.id) else { return false }
        // v2.0 Phase C: hard eligibility gate. A card whose requirements the
        // run hasn't met never enters the draw — not down-weighted, ABSENT.
        // Growth cards before Terra would be dead picks, and a dead pick in
        // a 3-card spread is a wasted level-up.
        guard card.requires.isSubset(of: capabilities) else { return false }
        // v2.1 A2 / A7a: …and so is a card whose NEXT TIER is closed.
        guard nextTierOpen(card, additionalTierGate: additionalTierGate) else { return false }
        // v2.1 A7a (CL-93): …and a card something the run owns has silenced.
        guard card.blockedBy.isDisjoint(with: capabilities) else { return false }
        // v2.0 (C2): a secret card is never in the random pool. It arrives
        // only when its own scheduler puts it there.
        if card.isSecret { return false }
        // v2.0 (E1): a dormant colour is ABSENT this run, not unlucky.
        // Neutral is always in `activeFamilies`, so neutral cards are
        // unaffected — including the one the panda hides behind.
        guard activeFamilies.contains(card.tag) else { return false }
        // A dual-tag BRIDGE needs BOTH colours live (Brandon). A bridge into
        // a tree that isn't in the run would hand out synergy progress in a
        // family with no other cards to pair it with. It makes bridges
        // rarer on purpose — the intended answer is MORE bridge cards in the
        // v2.1 family pass, not a looser rule here.
        if let second = card.secondaryTag, !activeFamilies.contains(second) { return false }
        // Capstones never come from the random pool once one is in progress —
        // the active one(s) are injected by parity; others are locked out.
        if card.isCapstone && capstoneInProgress { return false }
        return true
    }

    /// The next tier's own gates: its prerequisites are held (`tierRequires`,
    /// e.g. Frost Touch T3, Ice Rink) and nothing the run owns closes it
    /// (`tierBlockedBy`, e.g. Polar Vortex T4 after a pellet card).
    private func nextTierOpen(_ card: UpgradeCard,
                              additionalTierGate: (UpgradeCard) -> Bool = { _ in true }) -> Bool {
        guard additionalTierGate(card) else { return false }
        let next = tier(of: card.id) + 1
        if let need = card.tierRequires[next], !need.isSubset(of: capabilities) { return false }
        if let block = card.tierBlockedBy[next], !block.isDisjoint(with: capabilities) { return false }
        return true
    }

    /// The cards taken during the level-up at `level` (empty for any other level).
    private func takenAt(_ level: Int) -> Set<String> {
        cardsTakenLevel == level ? cardsTakenThisLevel : []
    }

    /// Capstones started, not maxed, and whose next tier is still OPEN. Only
    /// these hold the focus-and-finish lockout and get the every-other-level
    /// guarantee. A capstone whose next tier something closed (Polar Vortex T4
    /// once a pellet card is owned, CL-93) is STALLED: no guarantee — it would
    /// force-offer a tier nobody may take — and no lockout, so the run can
    /// still finish a different capstone (Brandon, Sep 25).
    private var activeCapstones: [UpgradeCard] {
        activeCapstones(additionalTierGate: { _ in true })
    }

    /// v2.3 R0: an opt-in proof seam. Existing runtime calls allow all extra
    /// tiers. A later form gate must also affect focus, so a newly stalled
    /// ladder cannot keep other capstones locked after its next tier closes.
    private func activeCapstones(additionalTierGate: (UpgradeCard) -> Bool) -> [UpgradeCard] {
        allCards.filter {
            $0.isCapstone && tier(of: $0.id) > 0 && tier(of: $0.id) < $0.maxTier
                && nextTierOpen($0, additionalTierGate: additionalTierGate)
        }
    }
    private var capstoneInProgress: Bool { !activeCapstones.isEmpty }

    /// Draw N random cards the player can still advance.
    /// v1.6: draws are tag-diverse — each card comes from a different tree.
    /// Duplicate trees appear only when the remaining pool can't offer
    /// enough distinct ones (deep tag-devoted runs), never by bad luck.
    /// v1.9: eligibility is "not maxed", not "never picked" — owned cards
    /// with rungs left re-appear and level up. Owned non-maxed cards draw
    /// with the same weight as new ones (locked Fork B).
    /// `allowSecret` exists for one caller: the gauntlet's RANDOM opener, which
    /// GRANTS whatever it draws. Panda's activation rule is that the player must
    /// TAKE the first card — being handed one is not taking it — so the secret
    /// scheduler stands down for granted draws.
    func drawCards(count: Int = 3, level: Int = 0, allowSecret: Bool = true) -> [UpgradeCard] {
        // v1.9 capstone offering rules (Brandon, Jul 20) — "focus & finish":
        //  • A committed-but-unmaxed capstone is the ONLY capstone offered, and
        //    only via the guarantee below — no OTHER capstone appears until it
        //    maxes (rule 1), so the draft stays focused enough to complete a build.
        //  • That capstone is guaranteed one slot every OTHER level (rule 2) so
        //    climbing 1→5 is deterministic, not a coin flip. Reroll can't remove
        //    it (level parity is stable across a reroll of the same level).
        //  • If two capstones are committed, both get the guarantee on offset
        //    parities. (Since A7a's acquisition-time rule — Brandon, Sep 25 — the
        //    Extra Pick can no longer start two from one spread: the second is
        //    revalidated away once the first is taken. The injection still
        //    handles two.) When NO capstone is in progress, capstones appear in
        //    the random pool normally (so you can start one, or see two at once).
        //  • A STALLED capstone (next tier closed) is not "in progress" here.
        let inProgress = activeCapstones
        let hasInProgress = !inProgress.isEmpty

        let available = allCards.filter { isOfferable($0, capstoneInProgress: hasInProgress, level: level) }

        guard !available.isEmpty || hasInProgress else { return [] }

        // A reroll re-draws the same level; a new level resets what "unseen"
        // means for the signature rule below, and (further down) is what lets
        // the pity counter treat a reroll as one offer, not two.
        let isNewLevel = (level != lastDrawLevel)
        lastDrawLevel = level
        if isNewLevel { signatureIDsSeenThisLevel.removeAll() }

        // v2.1 (abilities) — THE SIGNATURE OPENING (design locked: Lyra ×5,
        // Brandon agreed, Aug 23). While the run holds ZERO signatures, the
        // spread offers ONLY signature cards — one per tree, a random
        // `count` of the active trees. Level 1 asks "what kind of Spark are
        // you becoming?", so Neutral stands aside (it needs no signature and
        // keeps flowing from the very next spread). The Boss Mode DRAFT
        // opener draws through here too, so gauntlet builds commit the same
        // way; so does the RANDOM opener, whose first grant hands the run an
        // identity instead of a dead-end amplifier. The reroll re-shuffles
        // WHICH signatures show, prioritizing the unseen — it never escapes
        // the rule.
        let signatureSpread = !runHoldsSignature && available.contains { $0.isSignature }

        var drawn: [UpgradeCard] = []

        if signatureSpread {
            let signatures = available.filter { $0.isSignature }
            let unseen = signatures.filter { !signatureIDsSeenThisLevel.contains($0.id) }.shuffled(using: &rng)
            let returning = signatures.filter { signatureIDsSeenThisLevel.contains($0.id) }.shuffled(using: &rng)
            drawn = Array((unseen + returning).prefix(count))
            // Transition scaffolding, dead once every tree carries a flagged
            // signature: if fewer signatures are active than the spread holds,
            // fill the gap from the normal pool rather than shrink the spread.
            if drawn.count < count {
                for card in available.shuffled(using: &rng) where drawn.count < count {
                    if !drawn.contains(where: { $0.id == card.id }) { drawn.append(card) }
                }
            }
            for card in drawn where card.isSignature {
                signatureIDsSeenThisLevel.insert(card.id)
            }
        } else {
            let pool = available.shuffled(using: &rng)
            var usedTags: Set<Tag> = []

            // First pass: unique tags only (shuffled pool = tags weighted by
            // how many of their cards remain)
            for card in pool where drawn.count < count {
                if !usedTags.contains(card.tag) {
                    usedTags.insert(card.tag)
                    drawn.append(card)
                }
            }

            // Second pass: not enough distinct trees left — fill the gaps
            if drawn.count < count {
                for card in pool where drawn.count < count {
                    if !drawn.contains(where: { $0.id == card.id }) {
                        drawn.append(card)
                    }
                }
            }
        }

        // v2.0 Phase C — GATEWAY PITY.
        //
        // drawCards weights trees by how many cards they still have (a shuffled
        // flat pool means more cards ⇒ earlier first occurrence). A brand-new
        // tree with a single draftable card therefore surfaces ~5% of the time,
        // which made Terra appear about once every 20 level-ups and left the
        // whole Growth tree unreachable in practice.
        //
        // So a card that OPENS a pool gets a floor on its offer rate: if it
        // hasn't been seen for `gatewayPityLevels` level-ups, it takes a slot.
        // Deliberately narrow — this is not a general re-weighting of the draft
        // (that would change the feel of every tree in a shipped, tuned game),
        // it's a discoverability floor for cards that gate content.
        //
        // v2.1 (abilities): every signature `provides`, so all eight gateways
        // now ride this floor — which is exactly how a second tree opens
        // (locked answer 3: "pity is enough"). Two adjustments for the
        // multi-gateway world: (1) ONE claimant per draw, the LONGEST-waited —
        // with several gateways maturing together, first-come overwrites were
        // resetting the losers as if they'd been shown, and iteration order
        // let an early-pool gateway re-mature every cycle and starve a later
        // one forever (the proof harness caught exactly that); longest-waited
        // makes the matured set cascade in, one per level. (2) A signature
        // spread never gets overwritten — it IS the signature payout;
        // counters still tick and reset normally.
        var pityClaimant: UpgradeCard? = nil
        var pityLongestWait = 0
        // v2.1 A2: gateways are SIGNATURES. In-tree prerequisite cards (Glacial
        // Drift, Whiteout) also `provide`, but they open one card, not a tree —
        // no pity for them.
        for gateway in allCards where gateway.isSignature && !gateway.provides.isEmpty && !gateway.isSecret {
            // Only unowned gateways whose own requirements are met.
            // v2.0 (E1): a gateway in a DORMANT colour gets no pity — forcing
            // Terra into a slot on a run where Growth isn't playable would
            // hand the player a card whose whole pool is absent.
            guard tier(of: gateway.id) == 0,
                  activeFamilies.contains(gateway.tag),
                  gateway.requires.isSubset(of: capabilities) else {
                levelsSinceGatewayOffer[gateway.id] = 0
                continue
            }
            let waited = (levelsSinceGatewayOffer[gateway.id] ?? 0) + (isNewLevel ? 1 : 0)
            levelsSinceGatewayOffer[gateway.id] = waited
            if !drawn.contains(where: { $0.id == gateway.id }),
               waited >= GameConfig.Drafting.gatewayPityLevels, waited > pityLongestWait {
                pityClaimant = gateway
                pityLongestWait = waited
            }
        }
        if let claimant = pityClaimant, !drawn.isEmpty, !signatureSpread {
            drawn[0] = claimant              // front slot; capstones take the back
        }
        // Counters reset from the FINAL spread, at the bottom of this function
        // — a gateway only counts as offered if the player actually sees it.
        // Resetting here (as this block once did) counted a naturally-drawn
        // gateway as shown even when the claimant displaced it from slot 0,
        // silently pushing its next guaranteed offer another full pity cycle
        // out. The proof harness caught it as outright starvation.

        // Guarantee: inject each in-progress capstone whose parity matches this
        // level (offset per capstone so two never crowd the same level), taking
        // one slot each from the back and leaving the rest as normal cards.
        var forcedSlot = drawn.count - 1
        for (i, cap) in inProgress.enumerated() where (level + i) % 2 == 0 {
            if drawn.contains(where: { $0.id == cap.id }) { continue }
            // Corrective F2: taken during this level-up → not re-seated by a reroll.
            if takenAt(level).contains(cap.id) { continue }
            if forcedSlot >= 0 { drawn[forcedSlot] = cap; forcedSlot -= 1 }
            else { drawn.append(cap) }
        }

        // v2.0 (C2): the panda takes its slot LAST, so nothing can displace it —
        // not gateway pity, not a capstone guarantee. You cannot reroll the panda.
        //
        // It sits in the MIDDLE. Gateway pity claims the front (`drawn[0]`) and
        // the capstone guarantee fills from the back, so the middle is the only
        // seat nobody else has a claim on. Taking the front instead would have
        // quietly suppressed Terra's pity for the whole level 2–5 window on any
        // panda-eligible run — a gateway you can't find is a tree that doesn't
        // exist, and the panda would have been eating exactly that guarantee.
        if allowSecret, let panda = pandaOffer(atLevel: level),
           !takenAt(level).contains(panda.id),          // corrective F2: not re-seated by a reroll
           !drawn.contains(where: { $0.id == panda.id }) {
            if drawn.isEmpty {
                drawn.append(panda)
            } else {
                let capstoneIDs = Set(inProgress.map { $0.id })
                let middle = drawn.count / 2
                // If the middle happens to hold a guaranteed capstone, step to
                // any other non-front, non-capstone seat. Only a spread too
                // small to have one falls back to the front: the panda always
                // gets a seat, it just stops taking someone else's first.
                let seat = capstoneIDs.contains(drawn[middle].id)
                    ? (drawn.indices.first { $0 != 0 && !capstoneIDs.contains(drawn[$0].id) } ?? 0)
                    : middle
                drawn[seat] = panda
            }
        }

        #if DEBUG
        // Dev force-slot (see debugForcedCardID): keep the card-under-test in
        // the spread until it maxes, so the tier/max/capstone loop is quick to
        // exercise. Off (nil) by default; release builds never compile this.
        if let forcedID = Self.debugForcedCardID,
           let forced = allCards.first(where: { $0.id == forcedID }),
           tier(of: forcedID) < forced.maxTier,
           !drawn.isEmpty,
           !drawn.contains(where: { $0.id == forcedID }) {
            drawn[0] = forced
        }
        #endif

        // Gateway-pity bookkeeping, from the FINAL spread (see the pity block
        // above): whatever gateways survived every seating rule are what the
        // player actually sees, so those — and only those — reset their
        // pity clock.
        for card in drawn where !card.provides.isEmpty && !card.isSecret {
            levelsSinceGatewayOffer[card.id] = 0
        }

        return drawn
    }

    /// Should a Panda card be on the table at this level, and which rung?
    ///
    /// Returns nil for the overwhelming majority of runs — that's the point.
    private func pandaOffer(atLevel level: Int) -> UpgradeCard? {
        guard pandaEligible,
              let panda = allCards.first(where: { $0.id == GameConfig.Panda.cardID }) else { return nil }
        let owned = tier(of: panda.id)
        guard owned < panda.maxTier else { return nil }

        if !pandaActive {
            // Before the commitment point: it sits in the early window, every
            // level, until taken or the window closes. Insistent, never forced.
            // (The 9.27% gate is already the rarity; making the player also win
            // a single-offer coin-flip would make the whole tree unseeable.)
            return GameConfig.Panda.firstOfferWindow.contains(level) ? panda : nil
        }
        // After: every other level, anchored to the level it was taken.
        guard level > pandaActivationLevel,
              (level - pandaActivationLevel) % 2 == 0 else { return nil }
        return panda
    }

    /// v1.6: Draw one bonus card (Extra Card ad reward). Avoids the cards
    /// already on the table and prefers a tree that isn't represented yet.
    func drawBonusCard(excluding displayed: [UpgradeCard]) -> UpgradeCard? {
        let displayedIDs = displayed.map { $0.id }
        let displayedTags = Set(displayed.map { $0.tag })
        // v2.1 A7a (CL-89): the SAME offer rule as every other draw, at the
        // level-up this bonus belongs to (the last spread's level). The active
        // capstone is excluded by it too — its every-other-level guarantee is
        // the only way it's offered — and so is anything taken this level-up.
        let inProgress = capstoneInProgress
        let available = allCards.filter {
            !displayedIDs.contains($0.id) && isOfferable($0, capstoneInProgress: inProgress, level: lastDrawLevel)
        }

        let bonus = pickBonus(from: available, displayedTags: displayedTags)
        // A gateway the player is shown counts as offered, exactly as in a
        // spread (the pity bookkeeping at the end of drawCards).
        if let bonus, !bonus.provides.isEmpty { levelsSinceGatewayOffer[bonus.id] = 0 }
        return bonus
    }

    private func pickBonus(from available: [UpgradeCard], displayedTags: Set<Tag>) -> UpgradeCard? {
        // v2.1 (abilities): the bonus card obeys the signature opening — while
        // the run holds no signature, +1 Card widens the identity choice (an
        // unseen signature when one remains) rather than smuggling in a
        // normal card ahead of the first commitment.
        if !runHoldsSignature {
            let signatures = available.filter { $0.isSignature }
            if !signatures.isEmpty {
                let unseen = signatures.filter { !signatureIDsSeenThisLevel.contains($0.id) }
                let bonus = (unseen.isEmpty ? signatures : unseen).randomElement(using: &rng)
                if let bonus { signatureIDsSeenThisLevel.insert(bonus.id) }
                return bonus
            }
        }

        // Prefer a tree the spread doesn't show; any eligible card otherwise.
        let fresh = available.filter { !displayedTags.contains($0.tag) }
        return (fresh.isEmpty ? available : fresh).randomElement(using: &rng)
    }
    
    // MARK: - v2.1 A7a corrective (F1) — eligibility at ACQUISITION time

    /// May the player TAKE this card right now, during the level-up at `level`?
    /// A spread is drawn once, but a pick can change what is legal for the rest
    /// of it — capabilities, tiers, blocks, the capstone state, the level's
    /// taken set — so every remaining choice answers to the state NOW, never
    /// to the state when it was drawn. The two scheduled seats keep their own
    /// rules and never route through the ordinary offer rule: the panda by its
    /// schedule, an active capstone by its guarantee.
    func isSelectable(_ card: UpgradeCard, atLevel level: Int) -> Bool {
        guard !takenAt(level).contains(card.id) else { return false }
        if card.isSecret { return pandaOffer(atLevel: level)?.id == card.id }
        if activeCapstones.contains(where: { $0.id == card.id }) { return true }
        return isOfferable(card, capstoneInProgress: capstoneInProgress, level: level)
    }

    /// Off-live-path R0 admission proof. Shares ordinary prerequisites, taken
    /// set, secret scheduling and focus rules; supplies only an additional tier
    /// closure. No production draw or acquisition passes a Rainbow gate yet.
    func isSelectable(_ card: UpgradeCard, atLevel level: Int,
                      additionalTierGate: (UpgradeCard) -> Bool) -> Bool {
        guard !takenAt(level).contains(card.id), additionalTierGate(card) else { return false }
        if card.isSecret { return pandaOffer(atLevel: level)?.id == card.id }
        let inProgress = activeCapstones(additionalTierGate: additionalTierGate)
        if inProgress.contains(where: { $0.id == card.id }) { return true }
        return isOfferable(card, capstoneInProgress: !inProgress.isEmpty, level: level,
                           additionalTierGate: additionalTierGate)
    }

    /// The part of a spread that is still selectable, in order. Newly invalid
    /// cards drop out; nothing is drawn to replace them.
    func stillSelectable(_ cards: [UpgradeCard], atLevel level: Int) -> [UpgradeCard] {
        cards.filter { isSelectable($0, atLevel: level) }
    }

    /// Take a card only if it is selectable now (F1). The scene's picks and the
    /// random opener's grants come through here; `pickCard` stays the raw apply.
    @discardableResult
    func acquire(_ card: UpgradeCard, stats: PlayerStats, level: Int) -> Bool {
        guard isSelectable(card, atLevel: level) else { return false }
        pickCard(card, stats: stats, level: level)
        return true
    }

    /// Same real apply seam, opt-in only. R0's host proof uses this overload;
    /// live callers continue to use the unchanged three-argument acquisition.
    @discardableResult
    func acquire(_ card: UpgradeCard, stats: PlayerStats, level: Int,
                 additionalTierGate: (UpgradeCard) -> Bool) -> Bool {
        guard isSelectable(card, atLevel: level, additionalTierGate: additionalTierGate) else { return false }
        pickCard(card, stats: stats, level: level)
        return true
    }

    /// v1.8 Codex: a card shown in a spread, or granted by the random opener,
    /// is discovered — one production path the harness can execute.
    func recordDiscovered(_ cards: [UpgradeCard]) {
        for card in cards { CodexManager.shared.recordCardOffered(card.id) }
    }

    /// Player picks a card — first pick applies tier 1; a re-pick runs the
    /// next ladder rung (v1.9).
    ///
    /// ORTHOGONALITY GUARANTEE (locked): tag counts advance on the FIRST
    /// pick only. Leveling a card never feeds synergies — breadth (distinct
    /// cards per tree) and depth (card tiers) stay separate axes.
    func pickCard(_ card: UpgradeCard, stats: PlayerStats, level: Int = 0) {
        let current = tier(of: card.id)

        // Capabilities are granted on the FIRST pick — re-picking to level a
        // card can't re-unlock what it already opened.
        if current == 0 { capabilities.formUnion(card.provides) }
        // v2.1 A7a (CL-93): …and a specific tier can grant its own on purchase.
        if let granted = card.tierProvides[current + 1] { capabilities.formUnion(granted) }

        // v2.1 A7a (CL-89): remember what this level-up has already taken.
        if level != cardsTakenLevel { cardsTakenLevel = level; cardsTakenThisLevel.removeAll() }
        cardsTakenThisLevel.insert(card.id)

        // v2.0 (C2): the commitment point. Seeing the panda does nothing;
        // TAKING it is the first domino, and the schedule anchors here.
        if current == 0, card.id == GameConfig.Panda.cardID {
            pandaActive = true
            pandaActivationLevel = level
            // Taking it also un-masks the Panda family in the skin hub. NOT the
            // skin — that's the capstone's job below. The hub only makes a
            // revealed family tappable, so without this the family's premium
            // skin was unreachable: buyable only from inside a room you could
            // only enter by already owning something in it.
            SkinManager.shared.revealFamily("panda")
        }

        if current == 0 {
            pickedCardIDs.append(card.id)

            // Track tag
            if card.tag != .neutral {
                tagCounts[card.tag, default: 0] += 1
            }
            // v1.7: dual-tag cards count toward BOTH totals
            if let second = card.secondaryTag, second != .neutral {
                tagCounts[second, default: 0] += 1
            }

            // Apply card effect (tier 1)
            card.apply(stats)
        } else {
            // Already maxed cards never reach a draw; guard anyway.
            guard current - 1 < card.higherTiers.count else { return }
            card.higherTiers[current - 1](stats)
        }

        cardTiers[card.id] = current + 1

        // v2.0: PANDA. (T5) is the capstone, and its keepsake is the panda skin.
        // Granted at PICK time rather than run end — reaching the capstone earns
        // it whether or not the run survives what comes after.
        if card.id == GameConfig.Panda.cardID, current + 1 >= 5 {
            SkinManager.shared.unlockEarned("spark_panda")
        }
    }
    
    /// A synergy tier that JUST fired — structured so the reveal modal can
    /// render it in tree-tint card language (v1.8 Unit 6).
    struct SynergyUnlock {
        let tag: Tag
        let tier: Int
        let title: String
        let effect: String
    }

    /// Check and apply any newly reached synergy thresholds.
    /// Returns the tiers that fired this pick (may be several via Extra Pick).
    func checkSynergies(stats: PlayerStats) -> [SynergyUnlock] {
        var triggered: [SynergyUnlock] = []

        for (tag, count) in tagCounts {
            if tag == .neutral { continue }

            // Only trigger the threshold we JUST hit.
            let tier: Int
            if count == 3 { tier = 3 }
            else if count == 5 { tier = 5 }
            else if count == 7 { tier = 7 }
            else { continue }

            if applySynergy(tag: tag, tier: tier, stats: stats) != nil,
               let info = UpgradeManager.synergyTiers(for: tag).first(where: { $0.threshold == tier }) {
                triggered.append(SynergyUnlock(tag: tag, tier: tier, title: info.title, effect: info.effect))
            }
        }

        return triggered
    }
    
    // MARK: - v1.4: Build Identity Hints
    
    /// Check if a build archetype hint should display after a card pick.
    /// Returns a hint string or nil.
    func checkBuildHint() -> String? {
        // Combo-based archetypes (specific cards)
        if pickedCardIDs.contains("v13_overcharge") && pickedCardIDs.contains("v13_glass_engine") {
            return showHintOnce("skill_cannon", "⚡ Skill Cannon detected")
        }
        if pickedCardIDs.contains("v13_overcharge") && pickedCardIDs.contains("v13_execution") {
            return showHintOnce("skill_cannon_alt", "⚡ Skill Cannon forming")
        }
        if pickedCardIDs.contains("v13_phase_skin") && pickedCardIDs.contains("v16_hoarfrost") {
            return showHintOnce("survivor_loop", "🛡️ Survivor Loop forming")
        }
        if pickedCardIDs.contains("v13_chain_reaction") && pickedCardIDs.contains("v13_magnetic_core") {
            return showHintOnce("clear_engine", "💥 Clear Engine online")
        }
        if pickedCardIDs.contains("v13_unstable_core") {
            if let voidCount = tagCounts[.voidT], voidCount >= 2 {
                return showHintOnce("chaos_build", "🕳️ Chaos Build awakening")
            }
        }
        
        // Tag-count archetypes (2+ of same tag)
        for (tag, count) in tagCounts {
            if count == 2 {
                if let hint = tagHint(for: tag) {
                    return showHintOnce("tag_\(tag.rawValue)", hint)
                }
            }
        }
        
        return nil
    }
    
    private func tagHint(for tag: Tag) -> String? {
        switch tag {
        case .fire:    return "🔥 Pyromancer rising"
        case .shock:   return "⚡ Storm building"
        case .bleed:   return "🩸 Bloodseeker awakening"
        case .guardT:  return "🛡️ Fortress forming"
        case .voidT:   return "🕳️ Void touched"
        case .chill:   return "❄️ Frost spreading"
        case .growth:  return "🌱 Something is taking root"
        case .neutral: return nil
        }
    }
    
    private func showHintOnce(_ key: String, _ text: String) -> String? {
        guard !shownBuildHints.contains(key) else { return nil }
        shownBuildHints.insert(key)
        return text
    }
    
    // MARK: - Reset
    
    func reset() {
        pickedCardIDs.removeAll()
        capabilities.removeAll()
        levelsSinceGatewayOffer.removeAll()
        lastDrawLevel = -1
        cardTiers.removeAll()
        tagCounts.removeAll()
        appliedSynergies.removeAll()
        shownBuildHints.removeAll()
        signatureIDsSeenThisLevel.removeAll()
        cardsTakenLevel = -1
        cardsTakenThisLevel.removeAll()

        rollRunMutations()
    }

    /// v2.0 (C2): decide what this run IS, before a single card is drawn.
    ///
    /// Called from both `init` and `reset` on purpose: `reset()` only runs on a
    /// RESTART, so rolling solely there would mean the first run after every app
    /// launch could never be Panda-eligible — a silent, invisible bug, in the one
    /// system whose whole design makes silence look intentional.
    private func rollRunMutations() {
        rollActiveFamilies()
        pandaActive = false
        pandaActivationLevel = 0
        pandaEligible = CGFloat.random(in: 0..<1, using: &rng) < GameConfig.Panda.eligibilityChance
        #if DEBUG
        if GameConfig.Panda.debugAlwaysEligible { pandaEligible = true }
        #endif
        // App Review demonstration mode (release-compiled, unlike the seam
        // above): a reviewer has to be able to draw the panda cards without
        // winning a 9.27% roll. Announced by the run-HUD badge.
        if ReviewMode.isActive { pandaEligible = true }
    }
    
    // MARK: - Synergy Application
    
    private var appliedSynergies: Set<String> = []
    
    private func synergyKey(_ tag: Tag, _ tier: Int) -> String {
        return "\(tag.rawValue)_\(tier)"
    }
    
    private func applySynergy(tag: Tag, tier: Int, stats: PlayerStats) -> String? {
        let key = synergyKey(tag, tier)
        guard !appliedSynergies.contains(key) else { return nil }
        appliedSynergies.insert(key)

        // v1.8 Unit 5: a tier firing IS its Codex discovery (lifetime).
        CodexManager.shared.recordSynergySeen(tag: tag, tier: tier)

        // v1.8 Unit 5b: stat mutations only — the player-facing line comes
        // from the single `synergyTiers(for:)` source (copy consolidation), so
        // the notification, pause card-detail, and Codex can never drift.
        // v2.2 J2: the mutation is the catalog's native effect for this tier
        // (AbilityBehaviors, bound by AbilityCatalog); a tree without one
        // (Neutral) changes nothing, exactly as the old switch's `default`.
        guard let effect = AbilityCatalog.current.synergyEffects[key] else { return nil }
        effect(stats)

        return synergyLine(tag, tier)
    }

    /// Composes the player-facing synergy line from the single copy source.
    private func synergyLine(_ tag: Tag, _ tier: Int) -> String? {
        guard let info = UpgradeManager.synergyTiers(for: tag).first(where: { $0.threshold == tier }) else { return nil }
        return "\(UpgradeCardNode.emoji(for: tag)) \(info.title) — \(info.effect)"
    }

    // MARK: - Synergy tier copy (read-only, for detail surfaces)

    struct SynergyTier {
        let threshold: Int
        let title: String
        let effect: String
    }

    /// Pure, read-only synergy-tier copy for a tree — for detail surfaces
    /// (the pause card-detail modal, and the Card/Synergy Codex). The copy is
    /// the catalog's (v2.2 J2); Neutral has no ladder.
    static func synergyTiers(for tag: Tag) -> [SynergyTier] {
        AbilityCatalog.current.synergyTiers[tag] ?? []
    }

    // MARK: - v2.1 A7a (CL-102) — retired ids and the Codex tally

    /// Card ids that shipped in a LIVE build and were later removed, with the
    /// unit that retired each. The Codex's offered set (`sf_cards_offered`)
    /// only grows and is never pruned, so a live save can still hold these:
    /// they count as retired, never as discovered. An id listed here must
    /// never be reused for a new card — its old discovery would carry over.
    static var retiredCardIDs: [String: String] { AbilityCatalog.current.retiredCardIDs }

    /// Every card id in the live pool, Panda included (the Codex renders it).
    static var catalogIDs: [String] { AbilityCatalog.current.cards.map { $0.id } }

    /// What a save's offered set means against the live pool. Discovered only
    /// ever counts live ids, so it can never exceed the total.
    struct CodexTally: Equatable {
        let discovered: Int
        let total: Int
        let retired: [String]
        let unknown: [String]
    }

    static func codexTally(offered: [String], liveIDs: [String]) -> CodexTally {
        let live = Set(liveIDs)
        let stored = Set(offered)
        return CodexTally(
            discovered: stored.intersection(live).count,
            total: live.count,
            retired: stored.filter { retiredCardIDs[$0] != nil && !live.contains($0) }.sorted(),
            unknown: stored.filter { retiredCardIDs[$0] == nil && !live.contains($0) }.sorted())
    }
}
