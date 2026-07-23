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

        /// Capabilities this card grants the run when picked.
        var provides: Set<Capability> = []
        /// Capabilities the run must ALREADY have for this card to be offered.
        /// Unmet ⇒ hard-gated out of the draw entirely.
        var requires: Set<Capability> = []

        var maxTier: Int { 1 + higherTiers.count }

        /// Copy for a tier (1-based); falls back to `description`.
        func description(forTier tier: Int) -> String {
            guard let lines = tierDescriptions, tier >= 1, tier <= lines.count else {
                return description
            }
            return lines[tier - 1]
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
    /// "fire_2" (Forge Breath), "shock_1" (Static), "bleed_1" (Nick),
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

    /// v1.9: current tier of a card (0 = not owned this run).
    func tier(of cardID: String) -> Int {
        cardTiers[cardID] ?? 0
    }

    /// v1.7: Picked cards in pick order, for the pause build viewer
    var pickedCards: [UpgradeCard] {
        pickedCardIDs.compactMap { id in allCards.first { $0.id == id } }
    }

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
    }
    
    // MARK: - Draw
    
    /// Draw N random cards the player can still advance.
    /// v1.6: draws are tag-diverse — each card comes from a different tree.
    /// Duplicate trees appear only when the remaining pool can't offer
    /// enough distinct ones (deep tag-devoted runs), never by bad luck.
    /// v1.9: eligibility is "not maxed", not "never picked" — owned cards
    /// with rungs left re-appear and level up. Owned non-maxed cards draw
    /// with the same weight as new ones (locked Fork B).
    func drawCards(count: Int = 3, level: Int = 0) -> [UpgradeCard] {
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
            // Capstones never come from the random pool once one is in progress —
            // the in-progress one(s) are injected by parity; others are locked out.
            if card.isCapstone && hasInProgress { return false }
            return true
        }

        guard !available.isEmpty || hasInProgress else { return [] }

        let pool = available.shuffled()
        var drawn: [UpgradeCard] = []
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
        let isNewLevel = (level != lastDrawLevel)
        lastDrawLevel = level
        for gateway in allCards where !gateway.provides.isEmpty {
            // Only unowned gateways whose own requirements are met.
            guard tier(of: gateway.id) == 0,
                  gateway.requires.isSubset(of: capabilities) else {
                levelsSinceGatewayOffer[gateway.id] = 0
                continue
            }
            if drawn.contains(where: { $0.id == gateway.id }) {
                levelsSinceGatewayOffer[gateway.id] = 0
                continue
            }
            let waited = (levelsSinceGatewayOffer[gateway.id] ?? 0) + (isNewLevel ? 1 : 0)
            if waited >= GameConfig.Drafting.gatewayPityLevels, !drawn.isEmpty {
                drawn[0] = gateway               // front slot; capstones take the back
                levelsSinceGatewayOffer[gateway.id] = 0
            } else {
                levelsSinceGatewayOffer[gateway.id] = waited
            }
        }

        // Guarantee: inject each in-progress capstone whose parity matches this
        // level (offset per capstone so two never crowd the same level), taking
        // one slot each from the back and leaving the rest as normal cards.
        var forcedSlot = drawn.count - 1
        for (i, cap) in inProgress.enumerated() where (level + i) % 2 == 0 {
            if drawn.contains(where: { $0.id == cap.id }) { continue }
            if forcedSlot >= 0 { drawn[forcedSlot] = cap; forcedSlot -= 1 }
            else { drawn.append(cap) }
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

        return drawn
    }

    /// v1.6: Draw one bonus card (Extra Card ad reward). Avoids the cards
    /// already on the table and prefers a tree that isn't represented yet.
    func drawBonusCard(excluding displayed: [UpgradeCard]) -> UpgradeCard? {
        let displayedIDs = displayed.map { $0.id }
        let displayedTags = Set(displayed.map { $0.tag })
        let available = allCards.filter {
            tier(of: $0.id) < $0.maxTier && !displayedIDs.contains($0.id)
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
    func pickCard(_ card: UpgradeCard, stats: PlayerStats) {
        let current = tier(of: card.id)

        // Capabilities are granted on the FIRST pick — re-picking to level a
        // card can't re-unlock what it already opened.
        if current == 0 { capabilities.formUnion(card.provides) }

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
        if pickedCardIDs.contains("v13_phase_skin") && pickedCardIDs.contains("v13_static_field") {
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
            stats.bleedingEnemyDamageTaken = 0.15   // Open Wounds
        case (.bleed, 5):
            stats.executionThreshold = 0.3          // Exsanguinate (remap from old B7)
        case (.bleed, 7):
            stats.bleedKillHeal = 1                  // Red Harvest (start 1; test 2)

        // GUARD — endure → punish contact → weaponize defense (defensive-first)
        case (.guardT, 3):
            stats.pressureDefBonus = 10             // Ironhide — pressure-DEF ONLY
        case (.guardT, 5):
            stats.thornsContactReflect = 0.30       // Thornwall (start 0.30)
        case (.guardT, 7):
            stats.defAsDamageMult = 0.01 / 3.0      // Unbroken Core: +1% dmg / 3 DEF
            stats.collisionShrink *= 0.85           // keep the defensive shrink

        // VOID — pull → contain → collapse (v1.8 5b)
        case (.voidT, 3):
            stats.voidPullForce = 30                // Undertow — subtle gather
            stats.voidPullRadius = 120
        case (.voidT, 5):
            stats.gravityWellDuration = 2.0         // Event Horizon
            stats.gravityWellDPS = 0.5
            stats.inWellSlow = 0.4
        case (.voidT, 7):
            stats.singularityActive = true          // Singularity

        // CHILL
        case (.chill, 3):
            stats.slowPotencyMultiplier = 2.0
        case (.chill, 5):
            stats.shatterChance = 0.2
        case (.chill, 7):
            stats.globalEnemySlow += 0.25
            stats.shatterSlowThreshold = 0.3

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
            return [SynergyTier(threshold: 3, title: "Open Wounds", effect: "Bleeding enemies take more damage"),
                    SynergyTier(threshold: 5, title: "Exsanguinate", effect: "Low-HP enemies take double damage"),
                    SynergyTier(threshold: 7, title: "Red Harvest", effect: "Bleed kills restore HP")]
        case .guardT:
            return [SynergyTier(threshold: 3, title: "Ironhide", effect: "Gain DEF while enemies crowd you"),
                    SynergyTier(threshold: 5, title: "Thornwall", effect: "Enemies that touch you take damage back"),
                    SynergyTier(threshold: 7, title: "Unbroken Core", effect: "Your DEF fuels damage and steadies your core")]
        case .voidT:
            return [SynergyTier(threshold: 3, title: "Undertow", effect: "Void pulls nearby enemies inward"),
                    SynergyTier(threshold: 5, title: "Event Horizon", effect: "Enemies caught in Void struggle to escape"),
                    SynergyTier(threshold: 7, title: "Singularity", effect: "Void collapses enemies into ruin")]
        case .chill:
            return [SynergyTier(threshold: 3, title: "Frostbite", effect: "Chilled enemies move even slower"),
                    SynergyTier(threshold: 5, title: "Shatter", effect: "Frozen enemies burst when struck"),
                    SynergyTier(threshold: 7, title: "Absolute Zero", effect: "The arena slows; shatters come easy")]
        case .growth:
            // C1.7 authors these. Empty is correct until then — Growth ships
            // its cards first and its synergy tiers with the balance pass, so
            // nothing claims a tier that doesn't fire yet.
            return []
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
        
        cards.append(UpgradeCard(
            id: "fire_1", name: "Kindle", tag: .fire,
            description: "Projectiles ignite enemies (+0.5 burn DPS, 2s)"
        ) { stats in
            stats.burnDPS += 0.5
        })
        
        // v1.9 Unit 3: signature damage ladder (3-tier).
        cards.append(UpgradeCard(
            id: "fire_2", name: "Forge Breath", tag: .fire,
            description: "+15% damage",
            apply: { stats in stats.damageMultiplier += 0.15 },
            higherTiers: [
                { stats in stats.damageMultiplier += 0.15 },
                { stats in stats.damageMultiplier += 0.20 }
            ],
            tierDescriptions: [
                "+15% damage",
                "+15% more damage",
                "+20% more damage"
            ]
        ))
        
        cards.append(UpgradeCard(
            id: "fire_3", name: "Ember Burst", tag: .fire,
            description: "Kills explode for 30% damage in a small radius"
        ) { stats in
            stats.killsExplode = true
        })
        
        cards.append(UpgradeCard(
            id: "fire_4", name: "Crucible", tag: .fire,
            description: "+25% damage, +0.3 burn DPS"
        ) { stats in
            stats.damageMultiplier += 0.25
            stats.burnDPS += 0.3
        })
        
        // ═══════════════════════════════════
        // ⚡ SHOCK
        // ═══════════════════════════════════
        
        // v1.9 Unit 3: signature attack-speed ladder (3-tier). Lower interval
        // = faster; each rung stacks another ×0.88.
        cards.append(UpgradeCard(
            id: "shock_1", name: "Static", tag: .shock,
            description: "+12% attack speed",
            apply: { stats in stats.fireRateMultiplier *= 0.88 },
            higherTiers: [
                { stats in stats.fireRateMultiplier *= 0.88 },
                { stats in stats.fireRateMultiplier *= 0.88 }
            ],
            tierDescriptions: [
                "+12% attack speed",
                "+12% more attack speed",
                "+12% more attack speed"
            ]
        ))
        
        cards.append(UpgradeCard(
            id: "shock_2", name: "Arc", tag: .shock,
            description: "Hits chain to 1 nearby enemy at 50% damage"
        ) { stats in
            stats.chainTargets += 1
        })
        
        cards.append(UpgradeCard(
            id: "shock_3", name: "Surge", tag: .shock,
            description: "+15% attack speed, +10% projectile speed"
        ) { stats in
            stats.fireRateMultiplier *= 0.85
            stats.projectileSpeedMultiplier += 0.10
        })
        
        cards.append(UpgradeCard(
            id: "shock_4", name: "Overload", tag: .shock,
            description: "15% chance to stun enemies for 0.5s on hit"
        ) { stats in
            // v1.6: real stun — previous version added a slow by mistake
            stats.stunChance += 0.15
        })
        
        // ═══════════════════════════════════
        // 🩸 BLEED
        // ═══════════════════════════════════
        
        // v1.9 Unit 3: signature crit ladder (2-tier).
        cards.append(UpgradeCard(
            id: "bleed_1", name: "Nick", tag: .bleed,
            description: "+8% critical hit chance",
            apply: { stats in stats.critChance += 0.08 },
            higherTiers: [
                { stats in stats.critChance += 0.08 }
            ],
            tierDescriptions: [
                "+8% critical hit chance",
                "+8% more crit chance"
            ]
        ))
        
        cards.append(UpgradeCard(
            id: "bleed_2", name: "Hemorrhage", tag: .bleed,
            description: "Critical hits deal 3x damage instead of 2x"
        ) { stats in
            stats.critMultiplier = 3.0
        })
        
        cards.append(UpgradeCard(
            id: "bleed_3", name: "Frenzy", tag: .bleed,
            description: "Kill streak (3+) grants +20% attack speed for 3s"
        ) { stats in
            stats.killStreakFireRateBonus = 0.20
        })
        
        cards.append(UpgradeCard(
            id: "bleed_4", name: "Siphon", tag: .bleed,
            description: "Kills restore 1 HP"
        ) { stats in
            // v1.6: redesigned — old "extends your run" effect predated the
            // HP system and was never implemented
            stats.killHealAmount += 1
        })
        
        // ═══════════════════════════════════
        // 🛡️ GUARD
        // ═══════════════════════════════════
        
        cards.append(UpgradeCard(
            id: "guard_1", name: "Brace", tag: .guardT,
            description: "Survive one lethal hit (triggers at 0 HP)"
        ) { stats in
            stats.lethalSaves = max(stats.lethalSaves, 1)
        })
        
        cards.append(UpgradeCard(
            id: "guard_2", name: "Repulse", tag: .guardT,
            description: "Projectiles knock enemies back"
        ) { stats in
            stats.knockbackForce = 20.0
        })
        
        cards.append(UpgradeCard(
            id: "guard_3", name: "Harden", tag: .guardT,
            description: "Collision radius shrinks 20%"
        ) { stats in
            stats.collisionShrink *= 0.80
        })
        
        // v1.9 Unit 3: signature slow ladder (2-tier).
        cards.append(UpgradeCard(
            id: "guard_4", name: "Fortify", tag: .guardT,
            description: "All enemies slowed 8%",
            apply: { stats in stats.globalEnemySlow += 0.08 },
            higherTiers: [
                { stats in stats.globalEnemySlow += 0.08 }
            ],
            tierDescriptions: [
                "All enemies slowed 8%",
                "Enemies slowed a further 8%"
            ]
        ))
        
        // ═══════════════════════════════════
        // 🕳️ VOID
        // ═══════════════════════════════════
        
        cards.append(UpgradeCard(
            id: "void_1", name: "Warp Shot", tag: .voidT,
            description: "+1 projectile (fires in spread)"
        ) { stats in
            stats.extraProjectiles += 1
        })
        
        cards.append(UpgradeCard(
            id: "void_2", name: "Gravity Well", tag: .voidT,
            description: "Expired projectiles leave a pull zone (1s)"
        ) { stats in
            stats.gravityWellOnExpire = true
        })
        
        // v1.9 Unit 3: signature reach/pierce ladder (2-tier).
        cards.append(UpgradeCard(
            id: "void_3", name: "Phase", tag: .voidT,
            description: "+25% range, projectiles pierce 1 enemy",
            apply: { stats in
                stats.projectileRangeMultiplier += 0.25
                stats.pierceCount += 1
            },
            higherTiers: [
                { stats in
                    stats.projectileRangeMultiplier += 0.20
                    stats.pierceCount += 1
                }
            ],
            tierDescriptions: [
                "+25% range, pierce 1 enemy",
                "+20% range, pierce 1 more enemy"
            ]
        ))
        
        cards.append(UpgradeCard(
            id: "void_4", name: "Devour", tag: .voidT,
            description: "Kills pull XP orbs from 2x range"
        ) { stats in
            stats.killOrbPullMultiplier = 2.0
        })
        
        // ═══════════════════════════════════
        // ❄️ CHILL
        // ═══════════════════════════════════
        
        // v1.9 Unit 3: signature chill ladder (2-tier).
        cards.append(UpgradeCard(
            id: "chill_1", name: "Frost Touch", tag: .chill,
            description: "Projectiles slow enemies 10% for 2s",
            apply: { stats in stats.slowAmount += 0.10 },
            higherTiers: [
                { stats in stats.slowAmount += 0.10 }
            ],
            tierDescriptions: [
                "Projectiles slow enemies 10%",
                "Slow enemies a further 10%"
            ]
        ))
        
        cards.append(UpgradeCard(
            id: "chill_2", name: "Ice Shard", tag: .chill,
            description: "+15% projectile speed, +10% range"
        ) { stats in
            stats.projectileSpeedMultiplier += 0.15
            stats.projectileRangeMultiplier += 0.10
        })
        
        cards.append(UpgradeCard(
            id: "chill_3", name: "Permafrost", tag: .chill,
            description: "Slowed enemies take +15% damage"
        ) { stats in
            stats.slowedDamageBonus += 0.15
        })
        
        cards.append(UpgradeCard(
            id: "chill_4", name: "Glacial Drift", tag: .chill,
            description: "Leave a chill trail that slows enemies"
        ) { stats in
            stats.chillTrail = true
        })
        
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
            description: "Damage grows while unhit, resets on hit"
        ) { stats in
            stats.overchargeDamagePerSecond = 0.05  // +5% per second, caps at +50%
        })
        
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
            description: "+40% attack speed, -30% max HP"
        ) { stats in
            stats.fireRateMultiplier *= 0.60  // 40% faster
            stats.glassEngineActive = true
            let hpLoss = Int(Double(stats.maxHP) * 0.30)
            stats.maxHP -= hpLoss
            stats.currentHP = min(stats.currentHP, stats.maxHP)
        })
        
        // 5. Phase Skin — brief invulnerability on hit
        cards.append(UpgradeCard(
            id: "v13_phase_skin", name: "Phase Skin", tag: .guardT,
            description: "Taking damage grants 1s invulnerability (5s cd)"
        ) { stats in
            stats.phaseSkinCooldown = 5.0
            stats.phaseSkinDuration = 1.0
        })
        
        // 6. Static Field — proximity slow aura
        cards.append(UpgradeCard(
            id: "v13_static_field", name: "Static Field", tag: .chill,
            description: "Nearby enemies are slowed 15%"
        ) { stats in
            stats.staticFieldRange = 80.0
        })
        
        // 7. Execution Protocol — bonus damage to low HP
        cards.append(UpgradeCard(
            id: "v13_execution", name: "Execution Protocol", tag: .bleed,
            description: "2x damage to enemies below 30% HP"
        ) { stats in
            stats.executionProtocolThreshold = 0.30
        })
        
        // 8. Unstable Core — periodic burst + self damage
        // v1.4: Self-damage is now 10 HP instead of losing a lethal save
        cards.append(UpgradeCard(
            id: "v13_unstable_core", name: "Unstable Core", tag: .voidT,
            description: "Burst every 4s damages nearby enemies (costs 10 HP)"
        ) { stats in
            stats.unstableCoreActive = true
        })

        // ═══════════════════════════════════
        // ⚒️ v1.6 — LYRA'S QUENCH CARDS
        // Brings every tag to 7 cards; tier-7 synergies become reachable.
        // ═══════════════════════════════════

        cards.append(UpgradeCard(
            id: "v16_arc_wake", name: "Arc Wake", tag: .shock,
            description: "Movement leaves brief damaging sparks"
        ) { stats in
            stats.arcWakeDamage = 1
        })

        cards.append(UpgradeCard(
            id: "v16_static_crown", name: "Static Crown", tag: .shock,
            description: "Level-ups release a shock burst"
        ) { stats in
            stats.staticCrownDamage = 2
        })

        cards.append(UpgradeCard(
            id: "v16_live_wire", name: "Live Wire", tag: .shock,
            description: "Attacks chain to 1 more nearby foe"
        ) { stats in
            // Stacks with Arc and the Charged synergy
            stats.chainTargets += 1
        })

        cards.append(UpgradeCard(
            id: "v16_blood_price", name: "Blood Price", tag: .bleed,
            description: "+30% damage while below half HP"
        ) { stats in
            stats.bloodPriceBonus = 0.30
        })

        cards.append(UpgradeCard(
            id: "v16_open_vein", name: "Open Vein", tag: .bleed,
            description: "Bleeding enemies burst on death"
        ) { stats in
            stats.openVeinDamage = 2
        })

        cards.append(UpgradeCard(
            id: "v16_iron_bloom", name: "Iron Bloom", tag: .guardT,
            description: "Attackers take damage scaling with DEF"
        ) { stats in
            stats.ironBloomActive = true
        })

        cards.append(UpgradeCard(
            id: "v16_aegis_pulse", name: "Aegis Pulse", tag: .guardT,
            description: "Pulse every 4s, damage scales with DEF"
        ) { stats in
            stats.aegisPulseActive = true
        })

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
            description: "Cultivate the arena. Unlock Growth cards.",
            // ONE TIER, by design (Brandon): Terra opens the options that grant
            // the effects rather than being prescriptive itself.
            apply: { stats in stats.terraZoneRadius = GameConfig.Growth.terraRadius },
            provides: [.growthUnlocked]
        ))

        cards.append(UpgradeCard(
            id: "v20_thornsoil", name: "Thornsoil", tag: .growth,
            description: "Cultivated ground wounds what walks on it",
            apply: { stats in stats.thornsoilDPS = 6 },
            requires: [.growthUnlocked]
        ))

        cards.append(UpgradeCard(
            id: "v16_null_bloom", name: "Null Bloom", tag: .voidT,
            description: "Kills may leave brief slowing zones"
        ) { stats in
            stats.nullBloomChance = 0.30
        })

        cards.append(UpgradeCard(
            id: "v16_mass_tax", name: "Mass Tax", tag: .voidT,
            description: "-20% max HP, +30% damage"
        ) { stats in
            let hpLoss = Int(Double(stats.maxHP) * 0.20)
            stats.maxHP -= hpLoss
            stats.currentHP = min(stats.currentHP, stats.maxHP)
            stats.damageMultiplier += 0.30
        })

        cards.append(UpgradeCard(
            id: "v16_hoarfrost", name: "Hoarfrost", tag: .chill,
            description: "Regenerate 1 HP every 12s"
        ) { stats in
            stats.hoarfrostInterval = 12.0
        })

        cards.append(UpgradeCard(
            id: "v16_whiteout", name: "Whiteout", tag: .chill,
            description: "Slowed enemies chill others on death"
        ) { stats in
            stats.whiteoutActive = true
        })

        cards.append(UpgradeCard(
            id: "v16_cauterize", name: "Cauterize", tag: .fire,
            description: "Slowly regenerate while at low HP"
        ) { stats in
            stats.cauterizeActive = true
        })

        // ═══════════════════════════════════
        // ⚙️ v1.7 COILWORKS (Lyra's six — lyra-response-v1.7.md)
        // ═══════════════════════════════════

        cards.append(UpgradeCard(
            id: "v17_induction_step", name: "Induction Step", tag: .shock,
            description: "Moving charges your next attack"
        ) { stats in
            stats.inductionStepActive = true
        })

        cards.append(UpgradeCard(
            id: "v17_copper_vein", name: "Copper Vein", tag: .shock,
            description: "Shock chains reach farther"
        ) { stats in
            stats.shockChainRadiusBonus += 50
        })

        // The first bridge card — counts toward Fire AND Shock
        cards.append(UpgradeCard(
            id: "v17_relay_burn", name: "Relay Burn", tag: .fire, secondaryTag: .shock,
            description: "Burning foes can arc Shock"
        ) { stats in
            stats.relayBurnActive = true
        })

        cards.append(UpgradeCard(
            id: "v17_overclock", name: "Overclock", tag: .neutral,
            description: "Level-ups grant speed briefly"
        ) { stats in
            stats.overclockActive = true
        })

        cards.append(UpgradeCard(
            id: "v17_dead_circuit", name: "Dead Circuit", tag: .voidT,
            description: "Void zones linger longer"
        ) { stats in
            stats.voidZoneDurationMultiplier += 0.5
        })

        cards.append(UpgradeCard(
            id: "v17_grounded_core", name: "Grounded Core", tag: .guardT,
            description: "Standing still builds DEF"
        ) { stats in
            stats.groundedCoreActive = true
        })

        // ═══════════════════════════════════
        // v1.8 Unit 5b — rehome cards: preserve mechanics the synergy rework
        // moves off the tiers (crit-bleed, capped killstreak, pierce). Numbers
        // are starting values; balance pass tunes them.
        // ═══════════════════════════════════

        cards.append(UpgradeCard(
            id: "v18_needlepoint", name: "Needlepoint", tag: .bleed,
            description: "Crits apply Bleed."
        ) { stats in
            stats.critAppliesBleed = true
            stats.bleedDPS += 0.5
        })

        cards.append(UpgradeCard(
            id: "v18_bloodlust", name: "Bloodlust", tag: .bleed,
            description: "Bleed kills briefly boost damage."
        ) { stats in
            // Capped killstreak (spec: ~3 stacks, refreshable 4–6s) — reuses
            // the existing bloodlust machinery (stacks × per-kill, min-capped).
            stats.bloodlustDamagePerKill = 0.06
            stats.bloodlustMaxBonus = 0.18   // 3 stacks × 0.06
            stats.bloodlustWindow = 5.0
        })

        cards.append(UpgradeCard(
            id: "v18_riftline", name: "Riftline", tag: .voidT,
            description: "Shots pierce one extra enemy."
        ) { stats in
            stats.pierceCount += 1
        })

        // ═══════════════════════════════════
        // v1.8 Unit 14 — Mirrorwound cards (Lyra set): reflection, delayed
        // echoes, perception, status exploitation. Numbers are starting values;
        // Brandon's device gate tunes. Dual-tag cards count toward BOTH trees.
        // ═══════════════════════════════════

        cards.append(UpgradeCard(
            id: "v18_mirror_edge", name: "Mirror Edge", tag: .voidT,
            description: "Attacks can echo once for less damage."
        ) { stats in
            stats.echoChance = 0.35
        })

        cards.append(UpgradeCard(
            id: "v18_glass_blood", name: "Glass Blood", tag: .bleed, secondaryTag: .chill,
            description: "Bleed bites harder on slowed foes."
        ) { stats in
            stats.bleedVsSlowedMultiplier = 1.5
        })

        cards.append(UpgradeCard(
            id: "v18_silver_skin", name: "Silver Skin", tag: .guardT, secondaryTag: .voidT,
            description: "After a level-up, block the next hit."
        ) { stats in
            stats.hasSilverSkin = true
        })

        cards.append(UpgradeCard(
            id: "v18_fracture_shot", name: "Fracture Shot", tag: .neutral,
            description: "Shots split into weaker fragments."
        ) { stats in
            stats.splitCount = 2
        })

        cards.append(UpgradeCard(
            id: "v18_red_smile", name: "Red Smile", tag: .bleed,
            description: "Low HP increases Bleed damage."
        ) { stats in
            stats.bleedLowHpBonus = 1.5
        })

        cards.append(UpgradeCard(
            id: "v18_false_opening", name: "False Opening", tag: .voidT,
            description: "A sharp turn leaves a delayed Void pulse."
        ) { stats in
            stats.falseOpeningActive = true
        })

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
            isCapstone: true
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
                "Kinetic Reserve: hits store energy; release a 200% DEF burst at 5",
                "Iron Maiden: +15% DEF; every 20s fire stored energy at a priority foe"
            ],
            isCapstone: true
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
                "Skybeam: 2s lassoed → 200% ATK strike from above, every 3s"
            ],
            isCapstone: true
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
            isCapstone: true
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
            isCapstone: true
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
            isCapstone: true
        ))

        return cards
    }
}
