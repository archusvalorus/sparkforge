// UpgradeManager.swift
// Sparkforge
//
// Manages the 50-card pool (24 tagged + 6 neutral + 8 v1.3 Lyra cards
// + 12 v1.6 Quench cards). Every tag has exactly 7 cards, so every
// tier-7 synergy is reachable through full tag devotion.
// Handles card definitions, random draw, and applying effects to PlayerStats.
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
    /// Card ids live in `buildCardPool()`, e.g.: "neutral_6" (Scatter),
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

    /// v1.9: id → current tier this run (absent = not owned). Per-run,
    /// reset with everything else — no persistence, like pickedCardIDs.
    private(set) var cardTiers: [String: Int] = [:]

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
        activeFamilies = Set(candidates.shuffled().prefix(cap))
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
    
    init() {
        // v1.9 Unit 3: signature ladders now live in the release pool
        // (buildCardPool); the Unit 1 DEBUG proof ladder is retired.
        allCards = UpgradeManager.buildCardPool()
        rollRunMutations()
    }
    
    // MARK: - Draw
    
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
        //  • If two capstones are committed (both taken via the once-per-run +1
        //    pick before either locked the other out), both get the guarantee on
        //    offset parities. When NO capstone is in progress, capstones appear in
        //    the random pool normally (so you can start one, or see two at once).
        let inProgress = allCards.filter {
            $0.isCapstone && tier(of: $0.id) > 0 && tier(of: $0.id) < $0.maxTier
        }
        let hasInProgress = !inProgress.isEmpty

        let available = allCards.filter { card in
            guard tier(of: card.id) < card.maxTier else { return false }
            // v2.0 Phase C: hard eligibility gate. A card whose requirements the
            // run hasn't met never enters the draw — not down-weighted, ABSENT.
            // Growth cards before Terra would be dead picks, and a dead pick in
            // a 3-card spread is a wasted level-up.
            guard card.requires.isSubset(of: capabilities) else { return false }
            // v2.1 A2: …and so is the NEXT TIER's own prerequisite, if it has one.
            if let need = card.tierRequires[tier(of: card.id) + 1],
               !need.isSubset(of: capabilities) { return false }
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
            // the in-progress one(s) are injected by parity; others are locked out.
            if card.isCapstone && hasInProgress { return false }
            return true
        }

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
            let unseen = signatures.filter { !signatureIDsSeenThisLevel.contains($0.id) }.shuffled()
            let returning = signatures.filter { signatureIDsSeenThisLevel.contains($0.id) }.shuffled()
            drawn = Array((unseen + returning).prefix(count))
            // Transition scaffolding, dead once every tree carries a flagged
            // signature: if fewer signatures are active than the spread holds,
            // fill the gap from the normal pool rather than shrink the spread.
            if drawn.count < count {
                for card in available.shuffled() where drawn.count < count {
                    if !drawn.contains(where: { $0.id == card.id }) { drawn.append(card) }
                }
            }
            for card in drawn where card.isSignature {
                signatureIDsSeenThisLevel.insert(card.id)
            }
        } else {
            let pool = available.shuffled()
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
        let available = allCards.filter {
            tier(of: $0.id) < $0.maxTier && !displayedIDs.contains($0.id) && !$0.isSecret
                && activeFamilies.contains($0.tag)
                && $0.requires.isSubset(of: capabilities)
        }

        // v2.1 (abilities): the bonus card obeys the signature opening — while
        // the run holds no signature, +1 Card widens the identity choice (an
        // unseen signature when one remains) rather than smuggling in a
        // normal card ahead of the first commitment.
        if !runHoldsSignature {
            let signatures = available.filter { $0.isSignature }
            if !signatures.isEmpty {
                let unseen = signatures.filter { !signatureIDsSeenThisLevel.contains($0.id) }
                let bonus = (unseen.isEmpty ? signatures : unseen).randomElement()
                if let bonus { signatureIDsSeenThisLevel.insert(bonus.id) }
                return bonus
            }
        }

        if let freshTree = available.filter({ !displayedTags.contains($0.tag) }).randomElement() {
            return freshTree
        }
        return available.randomElement()
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
        pandaEligible = CGFloat.random(in: 0..<1) < GameConfig.Panda.eligibilityChance
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
        switch (tag, tier) {

        // FIRE
        case (.fire, 3):
            stats.burnSpreads = true
        case (.fire, 5):
            stats.burnDPS *= 2.0
            stats.burnDuration = 4.0
            stats.burnSpreadRadius *= 1.25   // v1.8 5b: Wildfire Heart
        case (.fire, 7):
            stats.passiveArenaDPS += 0.5

        // SHOCK
        case (.shock, 3):
            stats.chainTargets += 1  // Now chains to 2
        case (.shock, 5):
            stats.teslaFieldDPS = 0.3
        case (.shock, 7):
            stats.spreadShotInterval = 3
            stats.spreadShotCount = 3

        // BLEED — vulnerability → execution → sustain (v1.8 5b)
        case (.bleed, 3):
            stats.bleedingEnemyDamageTaken = GameConfig.Bleed.openWoundsBonus   // Open Wounds (CL-25)
        case (.bleed, 5):
            stats.executionThreshold = GameConfig.Bleed.exsanguinateThreshold  // Exsanguinate (CL-26)
        case (.bleed, 7):
            stats.bleedKillHeal = 1                  // Red Harvest (start 1; test 2)

        // GUARD — endure → punish contact → survive and strike back
        // (v2.1 A5 ladder, closure table §B4)
        case (.guardT, 3):
            stats.ironhideActive = true             // Ironhide: 9%/nearby hostile, ≤90% (CL-52)
        case (.guardT, 5):
            stats.thornsContactReflect = GameConfig.Guard.thornwallReflect  // Thornwall 1.50 (CL-53)
        case (.guardT, 7):
            // Unbroken Core (CL-54/57): arm the second rescue + equip the
            // projectile shield. The old DEF→damage conversion is retired; the
            // collision shrink stays.
            stats.unbrokenCoreOwned = true
            stats.unbrokenRescueAvailable = true
            stats.projectileShield.grant()
            stats.collisionShrink *= 0.85

        // VOID — v2.1 A6: one black-hole primitive, upgraded tier by tier on
        // EVERY player black hole (CL-77). Undertow's pull toward Spark and the
        // old Singularity's random wells are retired.
        case (.voidT, 3):
            stats.voidBlackhole = true              // Blackhole
        case (.voidT, 5):
            stats.voidListlessness = true           // Listlessness
        case (.voidT, 7):
            stats.voidSingularity = true            // Singularity

        // CHILL
        case (.chill, 3):
            stats.slowPotencyMultiplier = 2.0
        case (.chill, 5):
            stats.shatterChance = 0.2
        case (.chill, 7):
            stats.globalEnemySlow += 0.25
            stats.shatterSlowThreshold = 0.3

        // GROWTH (C1.7) — the garden deepens: control → sustain → territory.
        // All three are universal to any Growth build (every Growth build has
        // Terra's cultivated ground), so the synergy pays off regardless of
        // which specific Growth cards were taken.
        case (.growth, 3):
            stats.terraSlow += 0.15                  // Rootbound
        case (.growth, 5):
            stats.growthRegenBonusHP += 2            // Verdant Rise
        case (.growth, 7):
            stats.thornsoilDPS = max(stats.thornsoilDPS, 8)  // Wildwood: the ground bites

        default:
            return nil
        }

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
    /// (the pause card-detail modal, and the Card/Synergy Codex in Units 7–8).
    /// Mirrors the copy returned by `applySynergy(tag:tier:)`; keep the two in
    /// sync. Unit 5b reworks these titles/mechanics and should fold both into
    /// a single source of truth at that point.
    static func synergyTiers(for tag: Tag) -> [SynergyTier] {
        switch tag {
        case .fire:
            return [SynergyTier(threshold: 3, title: "Spreading Flame", effect: "Burns leap to nearby enemies"),
                    SynergyTier(threshold: 5, title: "Wildfire Heart", effect: "Burns spread farther and hit harder"),
                    SynergyTier(threshold: 7, title: "Inferno Crown", effect: "Every enemy in the arena is burning")]
        case .shock:
            return [SynergyTier(threshold: 3, title: "Chain Current", effect: "Lightning chains to one more enemy"),
                    SynergyTier(threshold: 5, title: "Tesla Field", effect: "A charged aura damages nearby enemies"),
                    SynergyTier(threshold: 7, title: "Storm Engine", effect: "Every 3rd shot fires a chaining spread")]
        case .bleed:
            return [SynergyTier(threshold: 3, title: "Open Wounds", effect: "Bleeding enemies take 25% more damage"),
                    SynergyTier(threshold: 5, title: "Exsanguinate", effect: "Enemies below 25% HP take 2× damage"),
                    SynergyTier(threshold: 7, title: "Red Harvest", effect: "Killing a bleeding enemy restores 1 HP")]
        case .guardT:
            return [SynergyTier(threshold: 3, title: "Ironhide", effect: "Nearby enemies cut damage taken, up to 90%"),
                    SynergyTier(threshold: 5, title: "Thornwall", effect: "Enemies that touch you take 150% of the hit back"),
                    SynergyTier(threshold: 7, title: "Unbroken Core", effect: "Survive a lethal hit: 10s invulnerable, +ATK equal to DEF. A shield blocks projectiles.")]
        case .voidT:
            return [SynergyTier(threshold: 3, title: "Blackhole", effect: "Every 5th primary volley creates a black hole. Your black holes absorb hostile projectiles and impair enemy movement."),
                    SynergyTier(threshold: 5, title: "Listlessness", effect: "Enemies entering your black holes become trapped (elites for half as long; bosses never). Absorbed hostile projectiles return toward enemies, infused with Void."),
                    SynergyTier(threshold: 7, title: "Singularity", effect: "Trapped enemies decompose: normal enemies until they die, elites up to 20% max HP per trap. Bosses caught in a black hole take 1% max HP per second.")]
        case .chill:
            return [SynergyTier(threshold: 3, title: "Frostbite", effect: "Chilled enemies move even slower"),
                    SynergyTier(threshold: 5, title: "Shatter", effect: "Frozen enemies burst when struck"),
                    SynergyTier(threshold: 7, title: "Absolute Zero", effect: "The arena slows; shatters come easy")]
        case .growth:
            return [SynergyTier(threshold: 3, title: "Rootbound", effect: "Cultivated ground grips harder — enemies on it are slower"),
                    SynergyTier(threshold: 5, title: "Verdant Rise", effect: "Your ground mends you faster"),
                    SynergyTier(threshold: 7, title: "Wildwood", effect: "The whole garden bites what stands on it")]
        case .neutral:
            return []
        }
    }

    // MARK: - Card Pool Builder
    
    private static func buildCardPool() -> [UpgradeCard] {
        var cards: [UpgradeCard] = []
        
        // ═══════════════════════════════════
        // 🔥 FIRE
        // ═══════════════════════════════════

        // v2.1 (abilities) — SIGNATURE FLAGS. One per tree, per the signature
        // spec: Kindle / Frost Touch / Arc (→ Chain Lightning in the rework) /
        // Terra are Brandon's confirmed entry points; Bleed's is Bloodthirsty
        // (v2.1 A4a — the interim Needlepoint is retired). Guard's is Repulse,
        // made PERMANENT by the v2.1 A5 rework (CL-49: battlefield control —
        // keeping threats away from Spark). Void's is Phase, the rework's named
        // entry point.
        // The rest of each tree stays UNGATED for now — the `requires`
        // authoring rides the rework pass, one pass over the pool, not two.

        cards.append(UpgradeCard(
            id: "fire_1", name: "Kindle", tag: .fire,
            description: "Projectiles ignite enemies: +0.5 burn DPS, 2s",
            apply: { stats in stats.burnDPS += 0.5 },
            // v2.1 A4a (CL-17): Burn now reaches bosses — at half.
            detail: "Projectiles ignite enemies (+0.5 burn DPS, 2s). Bosses and mini-bosses take 50% less Burn damage.",
            isSignature: true,
            provides: [.fireUnlocked]
        ))
        
        // v2.1 A1 (Fire rework): every Fire card past Kindle `requires` the
        // signature — prerequisites ship with the tree (A7 is the audit).

        // v2.1 A1 (Q-F1): all-damage → FIRE-owned damage only. Tier numbers
        // are TOTALS (25 / 50 / 100), so the rungs add 25 / 25 / 50.
        cards.append(UpgradeCard(
            id: "fire_2", name: "Forge Breath", tag: .fire,
            description: "+25% Fire damage.",
            apply: { stats in stats.fireDamageBonus += GameConfig.Fire.forgeBreathBonus[0] },
            higherTiers: [
                { stats in stats.fireDamageBonus += GameConfig.Fire.forgeBreathBonus[1] - GameConfig.Fire.forgeBreathBonus[0] },
                { stats in stats.fireDamageBonus += GameConfig.Fire.forgeBreathBonus[2] - GameConfig.Fire.forgeBreathBonus[1] }
            ],
            tierDescriptions: [
                "+25% Fire damage.",
                "+50% Fire damage.",
                "+100% Fire damage."
            ],
            detail: "Boosts Burn, Ember Burst, Everglow, and Inferno Crown damage.",
            requires: [.fireUnlocked]
        ))
        
        // v2.1 A1: 30% → 25%, radius +50% (values in GameConfig.Fire, read by
        // PlayerStats' explosion defaults).
        cards.append(UpgradeCard(
            id: "fire_3", name: "Ember Burst", tag: .fire,
            description: "Kills explode for 25% damage in a medium radius",
            apply: { stats in stats.killsExplode = true },
            requires: [.fireUnlocked]
        ))
        
        // v2.1 A1 (Q-F2, CL-16): burns STACK per enemy. Drops the old +25%
        // damage / +0.3 burn DPS — the stacks are the card.
        cards.append(UpgradeCard(
            id: "fire_4", name: "Crucible", tag: .fire,
            description: "Kindle hits stack Burn on an enemy, up to 5x",
            apply: { stats in stats.burnStackCap = GameConfig.Fire.crucibleStackCap },
            detail: "Kindle hits build Burn to 5 stacks, adding at most 1 stack every 3s per enemy. Each stack deals full Burn damage. When Burn ends, its damage stops and stacks fade one every 2s. Reignite the enemy to preserve its remaining stacks.",
            requires: [.fireUnlocked]
        ))
        
        // ═══════════════════════════════════
        // ⚡ SHOCK
        // ═══════════════════════════════════
        
        // v2.1 A3 (Shock rework): every Shock card past Chain Lightning
        // `requires` the signature. Tier numbers are TOTALS; attack-speed %
        // is a REAL firing-rate increase (the interval divides).

        // 15 / 30 / 50% — each rung re-bases the interval onto the new total.
        cards.append(UpgradeCard(
            id: "shock_1", name: "Static", tag: .shock,
            description: "+15% attack speed",
            apply: { stats in stats.fireRateMultiplier /= (1 + GameConfig.Shock.staticFireRate[0]) },
            higherTiers: [
                { stats in stats.fireRateMultiplier *= (1 + GameConfig.Shock.staticFireRate[0]) / (1 + GameConfig.Shock.staticFireRate[1]) },
                { stats in stats.fireRateMultiplier *= (1 + GameConfig.Shock.staticFireRate[1]) / (1 + GameConfig.Shock.staticFireRate[2]) }
            ],
            tierDescriptions: [
                "+15% attack speed",
                "+30% attack speed",
                "+50% attack speed"
            ],
            requires: [.shockUnlocked]
        ))
        
        // Signature. Arc → CHAIN LIGHTNING, 4 tiers (Q-S1, CL-12). The id stays
        // `shock_2` (persistence canon); one jump per tier, distinct targets.
        cards.append(UpgradeCard(
            id: "shock_2", name: "Chain Lightning", tag: .shock,
            description: "Hits chain to 1 nearby enemy at 50% damage",
            apply: { stats in stats.chainTargets += 1; stats.chainLightningTier = 1 },
            higherTiers: [
                { stats in stats.chainTargets += 1; stats.chainLightningTier = 2 },
                { stats in stats.chainTargets += 1; stats.chainLightningTier = 3 },
                { stats in stats.chainTargets += 1; stats.chainLightningTier = 4 }
            ],
            tierDescriptions: [
                "Hits chain to 1 nearby enemy at 50% damage",
                "Chains to 2; each jump keeps 75%",
                "Chains to 3; each jump keeps 85%",
                "Chains to 4 with no damage falloff"
            ],
            detail: "Each jump strikes a different enemy. T2 and T3 lose damage per jump, compounding (75% / 85% of the hit before). T4: hits chain to 4 additional enemies with no damage falloff. Chain Current adds one more jump.",
            isSignature: true,
            provides: [.shockUnlocked]
        ))
        
        cards.append(UpgradeCard(
            id: "shock_3", name: "Surge", tag: .shock,
            description: "+10% move, +20% shot speed, +10% attack speed",
            apply: { stats in
                stats.moveSpeedMultiplier += GameConfig.Shock.surgeMoveBonus
                stats.projectileSpeedMultiplier += GameConfig.Shock.surgeProjectileSpeed
                stats.fireRateMultiplier /= (1 + GameConfig.Shock.surgeFireRate)
            },
            requires: [.shockUnlocked]
        ))
        
        // Q-S2: LINKED to Chain Lightning — while that is maxed, an owned
        // Overload is 35% / 2s with no extra pick (PlayerStats.overloadLinked).
        cards.append(UpgradeCard(
            id: "shock_4", name: "Overload", tag: .shock,
            description: "Hits have a 20% chance to stun for 1s",
            apply: { stats in stats.overloadOwned = true },
            detail: "Hits have a 20% chance to stun enemies for 1s. Chain Lightning hits can also trigger this effect. With maxed Chain Lightning: 35% stun chance and 2s stun duration. An enemy can't be stunned again for 3s after a stun ends. Elites and mini-bosses are stunned for 0.25s, or 0.5s with maxed Chain Lightning. Arena bosses are immune.",
            requires: [.shockUnlocked]
        ))

        // NEW (Q-S3, CL-13) — 4 tiers. Coils deploy near Spark at pick time.
        cards.append(UpgradeCard(
            id: "v21_lightning_sentry", name: "Lightning Sentry", tag: .shock,
            description: "Deploy a Tesla coil that shocks enemies",
            apply: { stats in stats.lightningSentryTier = 1 },
            higherTiers: [
                { stats in stats.lightningSentryTier = 2 },
                { stats in stats.lightningSentryTier = 3 },
                { stats in stats.lightningSentryTier = 4 }
            ],
            tierDescriptions: [
                "Deploy a Tesla coil that shocks enemies",
                "Deploy a second Tesla coil",
                "Deploy a third Tesla coil",
                "Network: one arena-wide coil, 75% damage"
            ],
            detail: "Deploy a Tesla coil near you that shocks enemies in range for 50% of your attack damage. T4 Lightning Network: merge your coils into one central coil with arena-wide coverage. Each shock deals 75% of your attack damage.",
            requires: [.shockUnlocked]
        ))

        // NEW — moving charges a pulse.
        cards.append(UpgradeCard(
            id: "v21_electro_pulse", name: "Electro Pulse", tag: .shock,
            description: "Moving: every 3s, shock the nearest enemy",
            apply: { stats in stats.electroPulseActive = true },
            detail: "While moving, pulse every 3s: a static shock arcs to the nearest enemy for 40% damage. It can trigger Chain Lightning.",
            requires: [.shockUnlocked]
        ))
        
        // ═══════════════════════════════════
        // 🩸 BLEED
        // ═══════════════════════════════════

        // v2.1 A4a — the Bleed SIGNATURE (CL-1 Option B, approved copy verbatim
        // in `detail`). The ticking Bleed lives in BleedState; Needlepoint,
        // the interim crit-bleed signature, is retired. Boss-class takes half
        // (CL-17). The rest of the tree gains its `requires` in A4b.
        cards.append(UpgradeCard(
            id: "v21_bloodthirsty", name: "Bloodthirsty", tag: .bleed,
            description: "Primary hits: 50% chance to Bleed: 10% ATK/0.5s, 3s",
            apply: { stats in stats.bleedApplyChance = GameConfig.Bleed.applyChance },
            detail: "Primary hits have a 50% chance to inflict Bleed, dealing 10% ATK every 0.5s for 3s. Reapplying Bleed refreshes its duration without stacking damage or delaying the next tick. Bosses and mini-bosses take 50% less Bleed damage.",
            isSignature: true,
            provides: [.bleedUnlocked]
        ))

        // v2.1 A4b — the rest of the Bleed tree (spec Q-B1…Q-B6, closure table
        // CL-19…CL-32). Prerequisites ship with the tree: every card past
        // Bloodthirsty `requires` it, the capstone included. Tier numbers are
        // TOTALS; the rungs add the difference (never re-set a stat).

        // Nick → Gouge (id kept): crit chance totals 10 / 20%.
        let gouge = GameConfig.Bleed.gougeCritTotals
        cards.append(UpgradeCard(
            id: "bleed_1", name: "Gouge", tag: .bleed,
            description: "+10% critical hit chance",
            apply: { stats in stats.critChance += gouge[0] },
            higherTiers: [
                { stats in stats.critChance += gouge[1] - gouge[0] }
            ],
            tierDescriptions: [
                "+10% critical hit chance",
                "+20% critical hit chance"
            ],
            requires: [.bleedUnlocked]
        ))

        // CL-31: ADDS to the crit-damage multiplier (it used to re-set it to 3,
        // erasing Forge Path Deadeye's +0.10).
        cards.append(UpgradeCard(
            id: "bleed_2", name: "Hemorrhage", tag: .bleed,
            description: "Critical hits deal 3x damage instead of 2x",
            apply: { stats in stats.critMultiplier += GameConfig.Bleed.hemorrhageCritBonus },
            requires: [.bleedUnlocked]
        ))

        // Q-B1: a kill of an enemy that was ALREADY bleeding → +15% for 4s;
        // further qualifying kills reset the window (was: any 3-kill streak).
        cards.append(UpgradeCard(
            id: "bleed_3", name: "Frenzy", tag: .bleed,
            description: "Kill a bleeding foe: +15% attack speed for 4s",
            apply: { stats in stats.frenzyOwned = true },
            detail: "Killing a bleeding enemy grants +15% attack speed for 4s. Further qualifying kills reset the duration. An enemy counts as bleeding only if it was already bleeding before the killing hit.",
            requires: [.bleedUnlocked]
        ))

        // Q-B2: NEW — attack speed = 50% × missing-HP fraction (live).
        cards.append(UpgradeCard(
            id: "v21_berserk", name: "Berserk", tag: .bleed,
            description: "+0.5% attack speed per 1% HP missing",
            apply: { stats in stats.berserkOwned = true },
            detail: "Gain attack speed as health falls: +0.5% for every 1% of max HP missing.",
            requires: [.bleedUnlocked]
        ))

        // Q-B5: four tiers, 1 / 2 / 4 / 5 HP per kill (totals).
        let siphon = GameConfig.Bleed.siphonHealTotals
        let siphonRungs: [(PlayerStats) -> Void] = (1..<siphon.count).map { i in
            { stats in stats.killHealAmount += siphon[i] - siphon[i - 1] }
        }
        cards.append(UpgradeCard(
            id: "bleed_4", name: "Siphon", tag: .bleed,
            description: "Kills restore 1 HP.",
            apply: { stats in stats.killHealAmount += siphon[0] },
            higherTiers: siphonRungs,
            tierDescriptions: [
                "Kills restore 1 HP.",
                "Kills restore 2 HP.",
                "Kills restore 4 HP.",
                "Kills restore 5 HP."
            ],
            requires: [.bleedUnlocked]
        ))

        // Q-B3 / CL-19 / CL-20: NEW — kills grant Blood Barrier; with Siphon,
        // Siphon's overheal converts too.
        cards.append(UpgradeCard(
            id: "v21_sanguinarian", name: "Sanguinarian", tag: .bleed,
            description: "Kills grant Blood Barrier: 20% of the finishing hit",
            apply: { stats in stats.sanguinarianOwned = true },
            detail: "Kills grant Blood Barrier equal to 20% of the finishing hit's damage (at least 1), excluding overkill. Barrier absorbs damage before health, up to 50% of max HP. It expires 4s after the last positive gain. With Siphon: Siphon's overhealing becomes Blood Barrier.",
            requires: [.bleedUnlocked]
        ))
        
        // ═══════════════════════════════════
        // 🛡️ GUARD
        // ═══════════════════════════════════
        
        // v2.1 A5 (Guard rework, closure table §B4): prerequisites ship with
        // the tree — every card past Repulse `requires` it, Brace and the
        // capstone included (CL-50). Numbers live in `GameConfig.Guard`.

        cards.append(UpgradeCard(
            id: "guard_1", name: "Brace", tag: .guardT,
            description: "Survive one lethal hit.",   // A5 gate ruling Q5: the rest lives in MORE
            apply: { stats in stats.lethalSaves = max(stats.lethalSaves, 1) },
            detail: "Survive one lethal hit (triggers at 0 HP). Brace saves you first, Unbroken Core second — never both on one hit.",
            requires: [.guardUnlocked]
        ))

        // The Guard SIGNATURE (CL-49, permanent): battlefield control — keeping
        // threats away from Spark. Still projectile-scoped ("Projectiles…"), so
        // Red Smile's sweeps never carry it (CL-39 / CL-62). T1/T2 shove; T3
        // launches (CL-63).
        let shove = GameConfig.Guard.repulseShove
        cards.append(UpgradeCard(
            id: "guard_2", name: "Repulse", tag: .guardT,
            description: "Projectiles knock enemies back",
            apply: { stats in
                stats.repulseTier = 1
                stats.knockbackForce += shove[0]
            },
            higherTiers: [
                { stats in
                    stats.repulseTier = 2
                    stats.knockbackForce += shove[1] - shove[0]
                },
                { stats in stats.repulseTier = 3 }
            ],
            tierDescriptions: [
                "Projectiles knock enemies back",
                "Knockback goes farther",
                "Knocked enemies fly and bowl others over"
            ],
            detail: "Projectiles knock enemies back 20pt (T2: 60pt). T3: they are launched up to 400pt instead, and each one damages up to 3 enemies it crashes into for 25% ATK. Walls stop them. Mini-bosses are only knocked back 20pt; bosses and snowmen can't be moved.",
            isSignature: true,
            provides: [.guardUnlocked]
        ))

        cards.append(UpgradeCard(
            id: "guard_3", name: "Harden", tag: .guardT,
            description: "Collision radius −30%. Enemies bounce off you",
            apply: { stats in
                stats.collisionShrink *= GameConfig.Guard.hardenShrink
                stats.hardenOwned = true
            },
            detail: "Your collision radius shrinks 30%. Enemies that touch you are shoved 40pt away. The bounce never hurts you, but a bounced enemy can come back.",
            requires: [.guardUnlocked]
        ))

        // v2.1 A5 (CL-64): the old 2-tier global slow is gone — Fortify is one
        // tier of temporary DEF for standing still.
        cards.append(UpgradeCard(
            id: "guard_4", name: "Fortify", tag: .guardT,
            description: "Stand still: +2 DEF per second (max 30)",
            apply: { stats in stats.fortifyOwned = true },
            detail: "Standing still grants +1 temporary DEF every 0.5s, up to +30. Any movement resets it.",
            requires: [.guardUnlocked]
        ))
        
        // ═══════════════════════════════════
        // 🕳️ VOID
        // ═══════════════════════════════════
        
        // v2.1 A6 (CL-14): Warp's +1 projectile is retired (Q-V1) — the shot
        // itself warps. Same id, so Codex discovery carries over.
        cards.append(UpgradeCard(
            id: "void_1", name: "Warp Shot", tag: .voidT,
            description: "Slow shots that speed up. Slower = more damage.",
            apply: { stats in stats.warpShotActive = true },
            detail: "Your primary shots launch at 40% speed and reach full speed after 0.6s. They deal 150% damage at launch, falling to 100% at full speed. Damage between whole numbers rounds up by chance.",
            requires: [.voidUnlocked]
        ))

        // v2.1 A6: primary-shot scoped (CL-87); its pull zone is a black hole
        // for the synergies (CL-77) and a Dead Circuit enabler (CL-82).
        cards.append(UpgradeCard(
            id: "void_2", name: "Gravity Well", tag: .voidT,
            description: "Spent shots leave a pull zone (1s)",
            apply: { stats in stats.gravityWellOnExpire = true },
            detail: "Primary shots that reach max range or hit a wall leave a pull zone for 1s. Pull zones count as black holes for your Void synergies.",
            provides: [.voidWell],
            requires: [.voidUnlocked]
        ))

        // v2.1 A6: the Void signature, reworked (Q-V2, CL-71…74). Its old
        // reach and pierce moved to Riftline; Phase carries no range now.
        cards.append(UpgradeCard(
            id: "void_3", name: "Phase", tag: .voidT,
            description: "Primary hits add Anomaly. Triggers at 4 stacks.",
            apply: { stats in stats.phaseTier = 1 },
            higherTiers: [
                { stats in stats.phaseTier = 2 },
                { stats in stats.phaseTier = 3 }
            ],
            tierDescriptions: [
                "Primary hits add Anomaly. Triggers at 4 stacks.",
                "Your shots bypass Braceguard + DEF.",
                "Each primary hit applies 2 Anomaly stacks."
            ],
            detail: "Primary hits apply Anomaly. At 4 stacks, normal enemies are erased; elites take 20% max HP damage and bosses take 3%. Triggering Anomaly clears its stacks. Elites and bosses cannot gain new stacks for 2s afterward. Elites are mini-bosses. T2: your shots ignore Braceguard shields and the Boss Mode flat DEF setting. It does not bypass other defenses.",
            isSignature: true,
            provides: [.voidUnlocked]
        ))

        // v2.1 A6 (CL-84): functional at last — it set a field nothing read
        // since v1.0. XP orbs only; collection is unchanged.
        cards.append(UpgradeCard(
            id: "void_4", name: "Devour", tag: .voidT,
            description: "XP orbs are pulled to you from 2x range.",
            apply: { stats in stats.devourActive = true },
            requires: [.voidUnlocked]
        ))

        // v2.1 A6 NEW (Q-V5, CL-80): Void Horror.
        cards.append(UpgradeCard(
            id: "v21_void_horror", name: "Void Horror", tag: .voidT,
            description: "Primary hits may make enemies flee.",
            apply: { stats in stats.voidHorrorActive = true },
            detail: "Primary hits have an 8% chance to make enemies flee for 0.5s (elites 0.25s). Afterward, they resist fear for 2s. Bosses are immune.",
            requires: [.voidUnlocked]
        ))

        // v2.1 A6 NEW (Q-V3, CL-75/QB): Shadow Edge.
        cards.append(UpgradeCard(
            id: "v21_shadow_edge", name: "Shadow Edge", tag: .voidT,
            description: "Every 7th volley also fires a shadow blade.",
            apply: { stats in stats.shadowEdgeActive = true },
            detail: "Every 7th primary volley also fires a wide shadow blade. It deals 125% damage, strikes up to 3 enemies, and carries Void affinity, so Braceguard shields can't halve it. It is not a shot or a primary hit.",
            requires: [.voidUnlocked]
        ))
        
        // ═══════════════════════════════════
        // ❄️ CHILL
        // ═══════════════════════════════════
        
        // v2.1 A2 (Chill rework): every Chill card past Frost Touch `requires`
        // the signature. Tier numbers are TOTALS.

        // Signature. T1 25% / T2 50% slow; T3 (CL-3): the two real shard
        // sources — Iceburst shards and icicle fragments — carry Frost Touch.
        cards.append(UpgradeCard(
            id: "chill_1", name: "Frost Touch", tag: .chill,
            description: "Projectiles slow enemies 25% for 2s",
            apply: { stats in stats.slowAmount += GameConfig.Chill.frostTouchSlow[0] },
            higherTiers: [
                { stats in stats.slowAmount += GameConfig.Chill.frostTouchSlow[1] - GameConfig.Chill.frostTouchSlow[0] },
                { stats in stats.frostTouchShards = true }
            ],
            tierDescriptions: [
                "Projectiles slow enemies 25%",
                "Projectiles slow enemies 50%",
                "Shards and icicle fragments apply it too"
            ],
            detail: "T3: Iceburst shards and icicle fragments apply Frost Touch on hit.",
            isSignature: true,
            provides: [.chillUnlocked]
        ))
        
        cards.append(UpgradeCard(
            id: "chill_2", name: "Ice Shard", tag: .chill,
            description: "+30% projectile speed",
            apply: { stats in stats.projectileSpeedMultiplier += GameConfig.Chill.iceShardSpeedBonus },
            requires: [.chillUnlocked]
        ))
        
        cards.append(UpgradeCard(
            id: "chill_3", name: "Permafrost", tag: .chill,
            description: "Slowed enemies take +25% damage",
            apply: { stats in stats.slowedDamageBonus += GameConfig.Chill.permafrostBonus },
            detail: "Slowed enemies take 25% more damage, regardless of the slow's source.",
            requires: [.chillUnlocked]
        ))
        
        // 1 → 5 tiers (canon amended Sep 15; CL-11 Sep 17). T5 needs Whiteout (Q-C1).
        cards.append(UpgradeCard(
            id: "chill_4", name: "Glacial Drift", tag: .chill,
            description: "Leave a chill trail that slows enemies",
            apply: { stats in stats.chillTrail = true; stats.glacialDriftTier = 1 },
            higherTiers: [
                { stats in stats.glacialDriftTier = 2 },
                { stats in stats.glacialDriftTier = 3 },
                { stats in stats.glacialDriftTier = 4 },
                { stats in
                    stats.glacialDriftTier = 5
                    stats.globalEnemySlow += GameConfig.Chill.iceRinkEnemySlow
                    stats.moveSpeedMultiplier += GameConfig.Chill.iceRinkMoveBonus
                }
            ],
            tierDescriptions: [
                "Leave a chill trail that slows enemies (2s)",
                "Trail lingers 3.5s",
                "Trail lingers 5s and is 30% wider",
                "Trail is permanent",
                "Ice Rink: enemies -50% speed, you +25%"
            ],
            detail: "Trail time is per patch of ground. T4's frozen ground lasts for the arena. T5 Ice Rink: freeze the arena, slowing enemies by 50% and increasing your movement speed by 25%. Replaces your chill trail. Requires Whiteout.",
            provides: [.glacialDrift],
            requires: [.chillUnlocked],
            tierRequires: [5: [.whiteout]]
        ))

        // NEW (Q-C2) — takes Static Field's slot.
        cards.append(UpgradeCard(
            id: "v21_glacial_spikes", name: "Glacial Spikes", tag: .chill,
            description: "Chilled ground can impale enemies (4%/s)",
            apply: { stats in stats.glacialSpikesActive = true },
            detail: "Enemies on chilled ground have a 4% chance each second to be impaled. Executes normal enemies; deals 20% max HP to elites or 3% to bosses. At most one spike triggers every 0.75s across the arena.",
            requires: [.glacialDrift]
        ))
        
        // ═══════════════════════════════════
        // ⚪ NEUTRAL
        // ═══════════════════════════════════
        
        cards.append(UpgradeCard(
            id: "neutral_1", name: "Swift", tag: .neutral,
            description: "+12% movement speed"
        ) { stats in
            stats.moveSpeedMultiplier += 0.12
        })
        
        cards.append(UpgradeCard(
            id: "neutral_2", name: "Keen Eye", tag: .neutral,
            description: "+20% XP pickup radius"
        ) { stats in
            stats.pickupRadiusMultiplier += 0.20
        })
        
        cards.append(UpgradeCard(
            id: "neutral_3", name: "Rapid Fire", tag: .neutral,
            description: "+10% attack speed"
        ) { stats in
            stats.fireRateMultiplier *= 0.90
        })
        
        cards.append(UpgradeCard(
            id: "neutral_4", name: "Long Shot", tag: .neutral,
            description: "+20% projectile range"
        ) { stats in
            stats.projectileRangeMultiplier += 0.20
        })
        
        cards.append(UpgradeCard(
            id: "neutral_5", name: "XP Boost", tag: .neutral,
            description: "+25% XP gain"
        ) { stats in
            stats.xpMultiplier += 0.25
        })
        
        // v1.9 Unit 3: the canonical multishot ladder (3-tier). Each rung adds
        // a pellet; 2 fire as parallel columns, 3+ break into the static-cone
        // fan (see GameConfig.Projectile.multishotFanWidthFactor).
        cards.append(UpgradeCard(
            id: "neutral_6", name: "Scatter", tag: .neutral,
            description: "+1 projectile (wider spread)",
            apply: { stats in
                stats.extraProjectiles += 1
                stats.spreadAngle += 0.15
            },
            higherTiers: [
                { stats in stats.extraProjectiles += 1 },
                { stats in stats.extraProjectiles += 1 }
            ],
            tierDescriptions: [
                "+1 projectile (wider spread)",
                "+1 more projectile (fans out)",
                "+1 more projectile (denser fan)"
            ]
        ))
        
        // ═══════════════════════════════════
        // 🔥 v1.3 — LYRA'S CARDS
        // ═══════════════════════════════════
        
        // 1. Overcharge — damage scales while unhit
        cards.append(UpgradeCard(
            id: "v13_overcharge", name: "Overcharge", tag: .fire,
            description: "+5% damage/s unhit, max +50%. Resets on hit",
            apply: { stats in
                stats.overchargeDamagePerSecond = 0.05  // +5% per second, caps at +50%
            },
            detail: "Gain +5% damage each second without taking a hit, up to +50%. Taking a hit resets the bonus.",
            requires: [.fireUnlocked]
        ))
        
        // 2. Magnetic Core — bigger pickup + speed on collect
        cards.append(UpgradeCard(
            id: "v13_magnetic_core", name: "Magnetic Core", tag: .neutral,
            description: "+50% pickup radius, XP gives speed burst"
        ) { stats in
            stats.pickupRadiusMultiplier += 0.50
            stats.magneticCoreSpeedBoost = 0.30  // +30% speed for 1.5s on pickup
        })
        
        // 3. Chain Reaction — enemies explode on death
        cards.append(UpgradeCard(
            id: "v13_chain_reaction", name: "Chain Reaction", tag: .neutral,
            description: "Enemies explode on death"
        ) { stats in
            stats.chainReactionExplode = true
        })
        
        // 4. Glass Engine — massive attack speed, reduced max HP
        // v1.4: Was "lose a lethal save" — now reduces max HP by 30%
        cards.append(UpgradeCard(
            id: "v13_glass_engine", name: "Glass Engine", tag: .fire,
            description: "+100% attack speed, -50% max HP",
            apply: { stats in
                // v2.1 A1: a REAL +100% firing rate (the interval halves). The
                // old "+40%" line was ×0.60 on the interval — really +66.7%.
                stats.fireRateMultiplier /= (1.0 + GameConfig.Fire.glassEngineFireRateBonus)
                stats.glassEngineActive = true
                let hpLoss = Int(CGFloat(stats.maxHP) * GameConfig.Fire.glassEngineMaxHPLoss)
                stats.maxHP -= hpLoss
                stats.currentHP = min(stats.currentHP, stats.maxHP)
            },
            requires: [.fireUnlocked]
        ))
        
        // 5. Phase Skin — brief invulnerability on hit (v2.1 A5, CL-66: 3.5s cd)
        cards.append(UpgradeCard(
            id: "v13_phase_skin", name: "Phase Skin", tag: .guardT,
            description: "Taking damage grants 1s invulnerability (3.5s cd)",
            apply: { stats in
                stats.phaseSkinCooldown = GameConfig.Guard.phaseSkinCooldown
                stats.phaseSkinDuration = GameConfig.Guard.phaseSkinDuration
            },
            requires: [.guardUnlocked]
        ))
        
        // v2.1 A2: Static Field (`v13_static_field`) REMOVED — Glacial Spikes took
        // its slot. The id is retired, never reused; old Codex records simply stop
        // rendering.
        
        // 7. Execution Protocol — bonus damage to low HP
        cards.append(UpgradeCard(
            id: "v13_execution", name: "Execution Protocol", tag: .bleed,
            description: "2x damage to enemies below 30% HP",
            apply: { stats in stats.executionProtocolThreshold = 0.30 },
            requires: [.bleedUnlocked]   // v2.1 A4b
        ))
        
        // 8. Unstable Core — periodic burst + self damage
        // v1.4: Self-damage is now 10 HP instead of losing a lethal save
        cards.append(UpgradeCard(
            id: "v13_unstable_core", name: "Unstable Core", tag: .voidT,
            description: "Burst every 4s damages nearby enemies (costs 10 HP)",
            apply: { stats in stats.unstableCoreActive = true },
            requires: [.voidUnlocked]   // v2.1 A6 (CL-82)
        ))

        // ═══════════════════════════════════
        // ⚒️ v1.6 — LYRA'S QUENCH CARDS
        // Brings every tag to 7 cards; tier-7 synergies become reachable.
        // ═══════════════════════════════════

        // v2.1 A3: Arc Wake (`v16_arc_wake`) REMOVED — id retired, never reused.

        cards.append(UpgradeCard(
            id: "v16_static_crown", name: "Static Crown", tag: .shock,
            description: "Level-ups release an expanding electro pulse",
            apply: { stats in stats.staticCrownActive = true },
            detail: "Level-ups release an electro pulse that expands from you for 4s, dealing 150% damage to each enemy the ring passes.",
            requires: [.shockUnlocked]
        ))

        // v2.1 A3: Live Wire (`v16_live_wire`) REMOVED — folded into Chain Lightning.

        // v16_blood_price (Blood Price) — retired in v2.1 A4b.

        cards.append(UpgradeCard(
            id: "v16_open_vein", name: "Open Vein", tag: .bleed,
            description: "Bleeding enemies burst on death",
            apply: { stats in stats.openVeinDamage = 2 },
            detail: "Enemies that were already bleeding when they die burst, dealing 2 damage to nearby enemies.",
            requires: [.bleedUnlocked]   // v2.1 A4b
        ))

        // v2.1 A5 (CL-60/61): the 4s pulse moves here from Aegis; the contact
        // thorns retire. Piercing = ignores flat enemy DEF only.
        cards.append(UpgradeCard(
            id: "v16_iron_bloom", name: "Iron Bloom", tag: .guardT,
            description: "Every 4s, iron spikes deal 50% DEF around you",
            apply: { stats in stats.ironBloomActive = true },
            detail: "Every 4s, iron spikes strike every enemy within 70pt for 50% of your current DEF (at least 1). Piercing: ignores flat enemy DEF. Walls block the spikes.",
            requires: [.guardUnlocked]
        ))

        // v2.1 A5 (CL-58): Aegis Pulse → the Aegis shield (id kept, so Codex
        // discovery carries over). The % rides the pipeline's `aegis` slot
        // inside the 90% ceiling; T2+ bounce and spike (shared with Harden).
        cards.append(UpgradeCard(
            id: "v16_aegis_pulse", name: "Aegis", tag: .guardT,
            description: "Astral shield: take 25% less damage",
            apply: { stats in stats.aegisTier = 1 },
            higherTiers: [
                { stats in stats.aegisTier = 2 },
                { stats in stats.aegisTier = 3 }
            ],
            tierDescriptions: [
                "Astral shield: take 25% less damage",
                "Melee attackers bounce off and take spikes",
                "Bigger shield: 35% less damage, harder spikes"
            ],
            detail: "T1: take 25% less damage. T2: enemies that touch you bounce 40pt and take spikes for 50% of your current DEF. T3: 35% less damage; they bounce 70pt and the spikes deal 75% DEF. Shares the 90% damage-reduction cap.",
            requires: [.guardUnlocked]
        ))

        // ═══════════════════════════════════
        // 🌱 GROWTH  (v2.0 Phase C)
        //
        // Terra is the ENTRY card and the only Growth card offered before it is
        // owned. Picking it is opting into a build grammar, not taking a stat —
        // which is exactly why it carries `provides` and every other Growth card
        // carries `requires`.
        // ═══════════════════════════════════

        cards.append(UpgradeCard(
            id: "v20_terra", name: "Terra", tag: .growth,
            description: "Cultivate the arena. Your ground mends you. Unlock Growth cards.",
            // ONE TIER, by design (Brandon): Terra opens the options that grant
            // the effects rather than being prescriptive itself.
            apply: { stats in stats.terraZoneRadius = GameConfig.Growth.terraRadius },
            // v2.1 (abilities): Growth was the signature pilot in everything
            // but name — now it carries the name too.
            isSignature: true,
            provides: [.growthUnlocked]
        ))

        cards.append(UpgradeCard(
            id: "v20_thornsoil", name: "Thornsoil", tag: .growth,
            description: "Cultivated ground wounds what walks on it",
            apply: { stats in stats.thornsoilDPS = 6 },
            requires: [.growthUnlocked]
        ))

        // Defensive Flowers — a 3-tier ladder that maps onto the 3-flower cap:
        // each pick grows one more bloom on your ground. The stat closures are
        // empty; the flower itself is a scene structure the scene grows on pick.
        // Rich Soil — the Terra+ modifier. Exercises the modify-all-zones path.
        cards.append(UpgradeCard(
            id: "v20_richsoil", name: "Rich Soil", tag: .growth,
            description: "Your cultivated ground spreads wider and mends you harder",
            apply: { stats in stats.growthRegenBonusHP += 2 },
            requires: [.growthUnlocked]
        ))

        // Deeproot — the dual-tag bridge (Growth + Guard). Rooted = sturdy: you
        // gain DEF while standing on your own ground. Counts toward BOTH totals.
        cards.append(UpgradeCard(
            id: "v20_deeproot", name: "Deeproot", tag: .growth, secondaryTag: .guardT,
            description: "Rooted and sturdy: gain DEF while standing on cultivated ground",
            apply: { stats in stats.deeprootDEF += 6 },
            requires: [.growthUnlocked]
        ))

        // THE TREE — Growth's one capstone. Plant a sapling; help it become a
        // problem. Five tiers: sapling → sanctuary → territory → awakened habitat.
        cards.append(UpgradeCard(
            id: "v20_tree", name: "Tree", tag: .growth,
            description: "Plant a sapling. Help it become a problem.",
            apply: { stats in stats.treeTier = 1 },
            higherTiers: [
                { stats in stats.treeTier = 2 },   // Rootreach: move speed on ground
                { stats in stats.treeTier = 3 },   // Shelter: regen on ground
                { stats in stats.treeTier = 4 },   // Wild Domain: the garden swells
                { stats in stats.treeTier = 5 }    // The Forest Wakes: it launches animals
            ],
            tierDescriptions: [
                "Sapling — a tree takes root in your garden, and the ground grows",
                "Rootreach — you move faster while standing on cultivated ground",
                "Shelter — you slowly heal while standing on cultivated ground",
                "Wild Domain — the Tree matures; your territory swells",
                "The Forest Wakes — the NATURE CANON fires woodland animals at your enemies"
            ],
            isCapstone: true,
            requires: [.growthUnlocked]
        ))

        // MARK: v2.0 (C2) — Panda.
        //
        // Everything about this card is deliberate. The name ladder is the ONLY
        // information the player ever receives, and it is punctuation. The
        // ability text is `???` at every rung, forever, including the capstone
        // reveal. It carries the neutral tag so it can never feed a synergy, and
        // `isSecret` keeps it out of every pool, so the scheduler is the only
        // thing that can put it in front of you.
        //
        // Do not "improve" this by writing real descriptions. The moment we
        // explain why the panda samurai selects a target, we have wounded the
        // panda.
        cards.append(UpgradeCard(
            id: GameConfig.Panda.cardID, name: "Pandas.", tag: .neutral,
            description: "???",
            apply: { stats in stats.pandaTier = 1 },
            higherTiers: [
                { stats in stats.pandaTier = 2 },
                { stats in stats.pandaTier = 3 },
                { stats in stats.pandaTier = 4 },
                { stats in stats.pandaTier = 5 }
            ],
            tierDescriptions: ["???", "???", "???", "???", "???"],
            isSecret: true,
            tierNames: ["Pandas.", "Panda!", "Panda...?", "Panda.", "PANDA."]
        ))

        cards.append(UpgradeCard(
            id: "v20_vinewall", name: "Vine Wall", tag: .growth,
            description: "A thorny hedge rings your cultivated ground, repelling the swarm",
            apply: { stats in stats.vineWallTier = 1 },
            higherTiers: [
                { stats in stats.vineWallTier = 2 },
                { stats in stats.vineWallTier = 3 }
            ],
            tierDescriptions: [
                "A thorny hedge rings your cultivated ground, repelling the swarm",
                "The bramble shoves harder — the swarm barely gets a foot in",
                "The hedge thickens, catching enemy shots that cross it"
            ],
            requires: [.growthUnlocked]
        ))

        cards.append(UpgradeCard(
            id: "v20_seed_spore", name: "Seed Spore Shot", tag: .growth,
            description: "Your shots seed enemies; a seeded enemy bursts into spores when it dies",
            apply: { stats in stats.seedFragments = GameConfig.Growth.seedFragmentsT1 },
            higherTiers: [
                { stats in stats.seedFragments = GameConfig.Growth.seedFragmentsT2 },
                { stats in
                    stats.seedFragments = GameConfig.Growth.seedFragmentsT3
                    stats.seedReembed = true          // T3: spores re-embed, once
                }
            ],
            tierDescriptions: [
                "Your shots seed enemies; a seeded enemy bursts into spores when it dies",
                "More spores, flung farther",
                "Spores can re-seed the enemies they strike — the bloom spreads"
            ],
            requires: [.growthUnlocked]
        ))

        cards.append(UpgradeCard(
            id: "v20_wildbloom", name: "Wildbloom", tag: .growth,
            description: "Grow a defensive flower on your cultivated ground",
            apply: { _ in },
            higherTiers: [ { _ in }, { _ in } ],
            tierDescriptions: [
                "Grow a defensive flower on your cultivated ground",
                "Grow a second flower — the garden bares its thorns",
                "Grow a third flower — the whole bed is watching"
            ],
            requires: [.growthUnlocked]
        ))

        // v2.1 A6 (CL-10/77): the black-hole primitive, small.
        cards.append(UpgradeCard(
            id: "v16_null_bloom", name: "Null Bloom", tag: .voidT,
            description: "Kills may leave small black holes.",
            apply: { stats in stats.nullBloomChance = GameConfig.VoidTree.nullBloomChance },
            detail: "30% of kills leave a small black hole for 0.8s. It pulls enemies in, and your Void synergies upgrade it like any black hole.",
            provides: [.voidWell],
            requires: [.voidUnlocked]
        ))

        // `v16_mass_tax` (Mass Tax) — REMOVED in v2.1 A6 (spec Void table,
        // CL-83). The id is retired, never reused: old Codex records simply
        // stop rendering.

        cards.append(UpgradeCard(
            id: "v16_hoarfrost", name: "Hoarfrost", tag: .chill,
            description: "Regenerate 5 HP every 7s",
            apply: { stats in stats.hoarfrostInterval = GameConfig.Chill.hoarfrostInterval },
            requires: [.chillUnlocked]
        ))

        cards.append(UpgradeCard(
            // v2.1 A2 (Q-C3, CL-7): full rework — SNOWMEN.
            id: "v16_whiteout", name: "Whiteout", tag: .chill,
            description: "Hits have a 12% chance to make a snowman (3s)",
            apply: { stats in stats.whiteoutTier = 1 },
            higherTiers: [
                { stats in stats.whiteoutTier = 2 },
                { stats in stats.whiteoutTier = 3 }
            ],
            tierDescriptions: [
                "Hits have a 12% chance to make a snowman (3s)",
                "Snowmen last 6s",
                "Damaging a snowman melts it: it dies"
            ],
            detail: "Hits have a 12% chance to turn an enemy into a snowman for 3s. Each enemy can transform once every 10s. T3: damaging a snowman melts it. Normal enemies die instantly; elites take an additional 20% of max HP as damage. Bosses cannot become snowmen.",
            provides: [.whiteout],
            requires: [.chillUnlocked]
        ))

        cards.append(UpgradeCard(
            id: "v16_cauterize", name: "Cauterize", tag: .fire,
            description: "Below 25% HP: heal 5 HP every 3s",
            apply: { stats in stats.cauterizeActive = true },
            detail: "While below 25% max HP, recover 5 HP every 3s. Leaving this threshold resets the timer.",
            requires: [.fireUnlocked]
        ))

        // ═══════════════════════════════════
        // ⚙️ v1.7 COILWORKS (Lyra's six — lyra-response-v1.7.md)
        // ═══════════════════════════════════

        // v2.1 A3: Induction Step (`v17_induction_step`) REMOVED — id retired.

        // v2.1 A3: Copper Vein (`v17_copper_vein`) REMOVED — id retired.

        // The first bridge card — counts toward Fire AND Shock
        cards.append(UpgradeCard(
            id: "v17_relay_burn", name: "Relay Burn", tag: .fire, secondaryTag: .shock,
            description: "Burning foes can arc Shock",
            apply: { stats in stats.relayBurnActive = true },
            requires: [.fireUnlocked]
        ))

        cards.append(UpgradeCard(
            id: "v17_overclock", name: "Overclock", tag: .neutral,
            description: "Level-ups grant speed briefly"
        ) { stats in
            stats.overclockActive = true
        })

        // v2.1 A6 (CL-78): black holes linger, damage, grow, collapse. An
        // amplifier only — offered once you own a black-hole source (CL-82).
        cards.append(UpgradeCard(
            id: "v17_dead_circuit", name: "Dead Circuit", tag: .voidT,
            description: "Black holes grow as they feed, then burst.",
            apply: { stats in stats.deadCircuitActive = true },
            detail: "Your black holes last 50% longer and damage enemies inside. Each enemy killed inside one, or hostile projectile it absorbs, makes it grow. At 3, it collapses in a void burst for 150% ATK. Requires Gravity Well or Null Bloom.",
            requires: [.voidUnlocked, .voidWell]
        ))

        // v2.1 A5 (CL-65): permanent DEF for holding ground in combat.
        cards.append(UpgradeCard(
            id: "v17_grounded_core", name: "Grounded Core", tag: .guardT,
            description: "In combat, stand still: +1 DEF per 7.5s (max 30)",
            apply: { stats in stats.groundedCoreActive = true },
            detail: "Each uninterrupted 7.5s standing still in combat grants +1 DEF, permanent for the run (up to +30). Moving or leaving combat resets progress toward the next point.",
            requires: [.guardUnlocked]
        ))

        // ═══════════════════════════════════
        // v1.8 Unit 5b — rehome cards: preserve mechanics the synergy rework
        // moves off the tiers (crit-bleed, capped killstreak, pierce). Numbers
        // are starting values; balance pass tunes them. (Crit-bleed's card,
        // Needlepoint, was retired in v2.1 A4a — Bloodthirsty is the Bleed source.)
        // ═══════════════════════════════════

        // v18_needlepoint (Needlepoint) — retired in v2.1 A4a; Bloodthirsty is the Bleed signature.

        // Q-B6: +0.1% attack speed per kill of an enemy that was ALREADY
        // bleeding, permanent this run, capped at +30% (was a damage stack
        // counted twice that never decayed).
        cards.append(UpgradeCard(
            id: "v18_bloodlust", name: "Bloodlust", tag: .bleed,
            description: "Kill a bleeding foe: +0.1% attack speed, max +30%",
            apply: { stats in stats.bloodlustOwned = true },
            detail: "Killing a bleeding enemy permanently grants +0.1% attack speed this run, up to +30%.",
            requires: [.bleedUnlocked]
        ))

        // v2.1 A6 (CL-81): Phase's old reach and pierce live here now.
        cards.append(UpgradeCard(
            id: "v18_riftline", name: "Riftline", tag: .voidT,
            description: "Shots pierce 2 enemies (3 hits). +25% range.",
            apply: { stats in
                stats.riftlineActive = true
                stats.pierceCount += GameConfig.VoidTree.riftlinePierce
                stats.projectileRangeMultiplier += GameConfig.VoidTree.riftlineRange
            },
            detail: "Shots pass through up to 2 enemies, so each shot can hit up to 3. Each enemy after the first takes 75% of the previous hit's damage (100% → 75% → 56%). +25% projectile range.",
            requires: [.voidUnlocked]
        ))

        // ═══════════════════════════════════
        // v1.8 Unit 14 — Mirrorwound cards (Lyra set): reflection, delayed
        // echoes, perception, status exploitation. Numbers are starting values;
        // Brandon's device gate tunes. Dual-tag cards count toward BOTH trees.
        // ═══════════════════════════════════

        cards.append(UpgradeCard(
            id: "v18_mirror_edge", name: "Mirror Edge", tag: .voidT,
            description: "Attacks can echo once for less damage.",
            apply: { stats in stats.echoChance = 0.35 },
            requires: [.voidUnlocked]   // v2.1 A6 (CL-82)
        ))

        // v2.1 A4b rework (CL-27/28): enemies whose finishing blow is a Bleed
        // tick burst into Bleed-carrying fragments. No longer a Chill bridge.
        cards.append(UpgradeCard(
            id: "v18_glass_blood", name: "Glass Blood", tag: .bleed,
            description: "Bleed-killed foes burst: fragments hurt + Bleed",
            apply: { stats in stats.glassBloodActive = true },
            detail: "Enemies killed by Bleed burst into fragments that damage and inflict Bleed on nearby enemies. Each outbreak spreads at most two hops.",
            requires: [.bleedUnlocked]
        ))

        // v2.1 A5 (CL-50): the Guard → Void bridge sits behind Guard only.
        cards.append(UpgradeCard(
            id: "v18_silver_skin", name: "Silver Skin", tag: .guardT, secondaryTag: .voidT,
            description: "After a level-up, block the next hit.",
            apply: { stats in stats.hasSilverSkin = true },
            requires: [.guardUnlocked]
        ))

        cards.append(UpgradeCard(
            id: "v18_fracture_shot", name: "Fracture Shot", tag: .neutral,
            description: "Shots split into weaker fragments."
        ) { stats in
            stats.splitCount = 2
        })

        // v2.1 A4c: the Bleed/Void BRIDGE (Q-B4, closure table §B3). Every 10s
        // of active combat Spark becomes the Thing From Below for 3s: melee
        // sweeps (primary hits, not shots or projectiles) at 2× shot damage,
        // Void (ignores the Braceguard shield), guaranteed Bleed. Counts toward
        // both ladders (CL-45); needs BOTH signatures. The id is kept, so Codex
        // discovery carries over. The legacy low-HP Bleed bonus is gone.
        cards.append(UpgradeCard(
            id: "v18_red_smile", name: "Red Smile", tag: .bleed, secondaryTag: .voidT,
            description: "Every 10s: 3s of Void melee. 2× damage + Bleed.",
            apply: { stats in stats.redSmileOwned = true },
            detail: "Every 10s in combat, become the Thing From Below for 3s. Replace projectile attacks with sweeping melee attacks that deal 200% of projectile damage as Void damage and always inflict Bleed. Requires both Bleed and Void signatures. Existing projectiles remain active during transformation. Sweeps strike in your last move direction. They count as primary hits, not shots or projectiles.",
            requires: [.bleedUnlocked, .voidUnlocked]
        ))

        cards.append(UpgradeCard(
            id: "v18_false_opening", name: "False Opening", tag: .voidT,
            description: "A sharp turn leaves a delayed Void pulse.",
            apply: { stats in stats.falseOpeningActive = true },
            requires: [.voidUnlocked]   // v2.1 A6 (CL-82)
        ))

        // ═══════════════════════════════════
        // v1.9 CAPSTONES (Brandon + Lyra) — one tier-5 capstone per tree.
        // Design: docs/capstones-v1.9-design-packet.md.
        // ═══════════════════════════════════

        // 🔥 Everglow — the player becomes a volcano.
        cards.append(UpgradeCard(
            id: "cap_fire_everglow", name: "Everglow", tag: .fire,
            description: "Become the fire at the center of the arena.",
            apply: { stats in                       // T1 Inner Heat
                stats.everglowTier = 1
                stats.everglowBasePulseMult = GameConfig.Everglow.basePulseMult
                stats.everglowPulseRadius = GameConfig.Everglow.baseRadius
            },
            higherTiers: [
                { stats in                           // T2 Burning Reach
                    stats.everglowTier = 2
                    stats.everglowPulseRadius *= 2
                },
                { stats in                           // T3 Ragekindled
                    stats.everglowTier = 3
                    stats.everglowRageScaling = true
                },
                { stats in                           // T4 Living Furnace
                    stats.everglowTier = 4
                    stats.everglowBasePulseMult *= 2
                    stats.everglowFurnaceScaling = true
                },
                { stats in                           // T5 Everglow
                    stats.everglowTier = 5
                    stats.everglowEruption = true
                }
            ],
            tierDescriptions: [
                "Inner Heat: pulse every 2s for 50% ATK nearby",
                "Burning Reach: pulse radius doubled",
                "Ragekindled: damage taken grows the pulse (to +100%)",
                "Living Furnace: pulse doubled; hits also grow ATK",
                "Everglow: erupt for 500% ATK arena-wide every 15s"
            ],
            isCapstone: true,
            requires: [.fireUnlocked]   // v2.1 A1: the capstone sits behind Kindle too
        ))

        // 🛡️ Iron Maiden — incoming force becomes stored retaliation.
        cards.append(UpgradeCard(
            id: "cap_guard_ironmaiden", name: "Iron Maiden", tag: .guardT,
            description: "Turn every impact into stored punishment.",
            apply: { stats in                       // T1 Iron Skin
                stats.ironMaidenTier = 1
                stats.ironSkinDefToDmg = GameConfig.IronMaiden.defToDmgT1
                stats.defense += max(1, Int(CGFloat(stats.defense) * GameConfig.IronMaiden.defBonusT1))
                stats.ironThorns = GameConfig.IronMaiden.thornsT1
            },
            higherTiers: [
                { stats in                           // T2 Barbed Armor
                    stats.ironMaidenTier = 2
                    stats.ironThorns = GameConfig.IronMaiden.thornsT2
                    stats.ironSkinDefToDmg = GameConfig.IronMaiden.defToDmgT2
                },
                { stats in                           // T3 Retaliate
                    stats.ironMaidenTier = 3
                    stats.ironRetaliate = GameConfig.IronMaiden.retaliateMult
                },
                { stats in                           // T4 Kinetic Reserve
                    stats.ironMaidenTier = 4
                    stats.ironKineticActive = true
                },
                { stats in                           // T5 Iron Maiden
                    stats.ironMaidenTier = 5
                    stats.ironMaidenProjectile = true
                    stats.defense += max(1, Int(CGFloat(stats.defense) * GameConfig.IronMaiden.defBonusT5))
                }
            ],
            tierDescriptions: [
                "Iron Skin: DEF fuels damage; +5% DEF; Thorns bite touchers",
                "Barbed Armor: Thorns +250%; more DEF→damage",
                "Retaliate: counter attackers for 150% of the hit",
                "Kinetic Reserve: hits store energy; release a 200% DEF burst at 4",
                "Iron Maiden: +15% DEF; every 20s fire stored energy at a priority foe"
            ],
            // v2.1 A5: the T4/T5 faces overflow the card; the full ladder lives
            // here. T4's threshold corrected to the config's 4 (CL-67).
            detail: "T1 Iron Skin: DEF fuels damage, +5% DEF, and thorns bite enemies that touch you. T2 Barbed Armor: thorns +250%, more DEF→damage. T3 Retaliate: counter attackers for 150% of the hit (1s cooldown). T4 Kinetic Reserve: damaging hits store energy; release a 200% DEF burst at 4. T5 Iron Maiden: +15% DEF; every 20s fire the stored energy at a priority foe. Bosses and mini-bosses take 50% less thorn and Retaliate damage.",
            isCapstone: true,
            requires: [.guardUnlocked]   // v2.1 A5 (CL-50)
        ))

        // ⚡ Skybeam — designate prey; call judgment from above.
        cards.append(UpgradeCard(
            id: "cap_shock_skybeam", name: "Skybeam", tag: .shock,
            description: "Lasso your prey. Call judgment from above.",
            apply: { stats in                       // T1 Lightning Lasso
                stats.skybeamTier = 1
                stats.skybeamTickMult = GameConfig.Skybeam.tickMultT1
                stats.skybeamAcquireRange = GameConfig.Skybeam.acquireRangeT1
            },
            higherTiers: [
                { stats in                           // T2 Extended Circuit
                    stats.skybeamTier = 2
                    stats.skybeamTickMult = GameConfig.Skybeam.tickMultT2
                    stats.skybeamAcquireRange = GameConfig.Skybeam.acquireRangeT2
                },
                { stats in                           // T3 Homing Beacon
                    stats.skybeamTier = 3
                    stats.skybeamHoming = true
                },
                { stats in                           // T4 Heaven's Call
                    stats.skybeamTier = 4
                    stats.skybeamCalled = true
                },
                { stats in                           // T5 Skybeam
                    stats.skybeamTier = 5
                    stats.skybeamStrike = true
                }
            ],
            tierDescriptions: [
                "Lightning Lasso: tether the nearest foe for 15% ATK Shock/s",
                "Extended Circuit: lasso damage doubled; range doubled",
                "Homing Beacon: your fire prioritizes the lassoed prey",
                "Heaven's Call: 2s lassoed → prey takes +35% from all sources",
                "Skybeam: every 5s a 300% ATK strike from above, with splash"
            ],
            isCapstone: true,
            requires: [.shockUnlocked]   // v2.1 A3
        ))

        // 🩸 Apex — feed the familiar; become the hunt.
        cards.append(UpgradeCard(
            id: "cap_bleed_apex", name: "Apex", tag: .bleed,
            description: "Feed the familiar. Become the hunt.",
            apply: { stats in                       // T1 Blood Familiar
                stats.apexTier = 1
                stats.apexFamiliarActive = true
            },
            higherTiers: [
                { stats in                           // T2 Bloodfed
                    stats.apexTier = 2
                    stats.apexHpToAtkActive = true
                },
                { stats in                           // T3 Bloodhound
                    stats.apexTier = 3
                    stats.apexBloodhound = true
                },
                { stats in                           // T4 Marked for Death
                    stats.apexTier = 4
                    stats.apexMarked = true
                },
                { stats in                           // T5 The Hunter
                    stats.apexTier = 5
                    stats.apexHunter = true
                }
            ],
            tierDescriptions: [
                "Blood Familiar: an invulnerable bat hunts; kills grow its bite",
                "Bloodfed: every 10 kills +5 max HP; 1% of max HP → ATK",
                "Bloodhound: bat favors bleeders; executes weak normals",
                "Marked: enemies alive 10s take +35% from all sources",
                "The Hunter: hits on injured foes charge a gauge; full → the bat executes a weakened enemy"
            ],
            isCapstone: true,
            requires: [.bleedUnlocked]   // v2.1 A4b: prerequisites ship with the tree
        ))

        // 🕳️ Erasure — destabilize reality; accept the final cost.
        cards.append(UpgradeCard(
            id: "cap_void_erasure", name: "Erasure", tag: .voidT,
            description: "Destabilize reality. Accept the final cost.",
            apply: { stats in                       // T1 Unstable
                stats.erasureTier = 1
                stats.erasureActive = true
                stats.erasureTriggerCD = GameConfig.Erasure.unstableTriggerCooldown
            },
            higherTiers: [
                { stats in                           // T2 Void-Touched
                    stats.erasureTier = 2
                    stats.erasureVoidTouched = true
                    stats.erasureTriggerCD = GameConfig.Erasure.unstableTriggerCooldownT2
                },
                { stats in                           // T3 Rift Cannon
                    stats.erasureTier = 3
                    stats.erasureRiftCannon = true
                },
                { stats in                           // T4 Echo
                    stats.erasureTier = 4
                    stats.erasureEcho = true
                },
                { stats in                           // T5 Event Horizon
                    stats.erasureTier = 5
                    stats.erasureEventHorizon = true
                }
            ],
            tierDescriptions: [
                "Unstable: your hits charge the void; full meter → reality lurches",
                "Void-Touched: shots pierce armor; the void charges faster",
                "Rift Cannon: every 3rd lurch, an arena rift fires a 300% ATK beam",
                "Echo: your shots echo 1.5s later from elsewhere (50% damage)",
                "Event Horizon: at 75s the arena is erased; at 105s, so are you"
            ],
            isCapstone: true,
            requires: [.voidUnlocked]   // v2.1 A6 (CL-82): gated like every capstone
        ))

        // ❄️ Polar Vortex — carry the storm; freeze enemies to the soul.
        cards.append(UpgradeCard(
            id: "cap_chill_polarvortex", name: "Polar Vortex", tag: .chill,
            description: "Carry the storm. Freeze enemies to the soul.",
            apply: { stats in                       // T1 Iceburst
                stats.polarVortexTier = 1
                stats.iceburstActive = true
                stats.iceburstShards = GameConfig.PolarVortex.iceburstShardsT1
            },
            higherTiers: [
                { stats in                           // T2 Brittle Cold
                    stats.polarVortexTier = 2
                    stats.iceburstShards = GameConfig.PolarVortex.iceburstShardsT2
                    stats.brittleCold = true
                },
                { stats in                           // T3 Windchill
                    stats.polarVortexTier = 3
                    stats.windchillActive = true
                    stats.windchillRadius = GameConfig.PolarVortex.windchillRadius
                },
                { stats in                           // T4 Glacial Condensation
                    stats.polarVortexTier = 4
                    stats.glacialActive = true
                },
                { stats in                           // T5 Polar Vortex
                    stats.polarVortexTier = 5
                    stats.polarVortexFreeze = true
                    stats.iceburstShards = GameConfig.PolarVortex.iceburstShardsT5
                    stats.windchillRadius = GameConfig.PolarVortex.windchillRadius
                        * GameConfig.PolarVortex.windchillRadiusT5Mult
                }
            ],
            tierDescriptions: [
                "Iceburst: chilled foes that die burst into 3 ice shards",
                "Brittle Cold: 5 shards; +40% damage to chilled/frozen foes",
                "Windchill: a cold storm follows you, stacking Chill",
                "Glacial Condensation: every 3 shots fire one shattering icicle",
                "Polar Vortex: storm ×3; 5 Chill → freeze → Frostbite (+100% dmg)"
            ],
            isCapstone: true,
            requires: [.chillUnlocked]   // v2.1 A2
        ))

        return cards
    }
}
