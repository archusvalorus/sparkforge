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
        case neutral = "Neutral"
    }
    
    // MARK: - Card Definition
    
    struct UpgradeCard {
        let id: String
        let name: String
        let tag: Tag
        let description: String
        let apply: (PlayerStats) -> Void
    }
    
    // MARK: - State
    
    /// Cards the player has picked this run (by ID)
    private(set) var pickedCardIDs: [String] = []
    
    /// Tag counts for synergy tracking
    private(set) var tagCounts: [Tag: Int] = [:]
    
    /// All available cards
    let allCards: [UpgradeCard]
    
    /// v1.4: Track which build hints have been shown this run
    private var shownBuildHints: Set<String> = []
    
    // MARK: - Init
    
    init() {
        allCards = UpgradeManager.buildCardPool()
    }
    
    // MARK: - Draw
    
    /// Draw N random cards the player hasn't picked yet.
    /// v1.6: draws are tag-diverse — each card comes from a different tree.
    /// Duplicate trees appear only when the remaining pool can't offer
    /// enough distinct ones (deep tag-devoted runs), never by bad luck.
    func drawCards(count: Int = 3) -> [UpgradeCard] {
        let available = allCards.filter { card in
            !pickedCardIDs.contains(card.id)
        }

        guard !available.isEmpty else { return [] }

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

        return drawn
    }

    /// v1.6: Draw one bonus card (Extra Card ad reward). Avoids the cards
    /// already on the table and prefers a tree that isn't represented yet.
    func drawBonusCard(excluding displayed: [UpgradeCard]) -> UpgradeCard? {
        let displayedIDs = displayed.map { $0.id }
        let displayedTags = Set(displayed.map { $0.tag })
        let available = allCards.filter {
            !pickedCardIDs.contains($0.id) && !displayedIDs.contains($0.id)
        }

        if let freshTree = available.filter({ !displayedTags.contains($0.tag) }).randomElement() {
            return freshTree
        }
        return available.randomElement()
    }
    
    /// Player picks a card — apply its effects and track it
    func pickCard(_ card: UpgradeCard, stats: PlayerStats) {
        pickedCardIDs.append(card.id)
        
        // Track tag
        if card.tag != .neutral {
            tagCounts[card.tag, default: 0] += 1
        }
        
        // Apply card effect
        card.apply(stats)
    }
    
    /// Check and apply any newly reached synergy thresholds
    /// Returns descriptions of triggered synergies
    func checkSynergies(stats: PlayerStats) -> [String] {
        var triggered: [String] = []
        
        for (tag, count) in tagCounts {
            if tag == .neutral { continue }
            
            // Check each threshold — only trigger if we JUST hit it
            if count == 3 {
                if let desc = applySynergy(tag: tag, tier: 3, stats: stats) {
                    triggered.append(desc)
                }
            } else if count == 5 {
                if let desc = applySynergy(tag: tag, tier: 5, stats: stats) {
                    triggered.append(desc)
                }
            } else if count == 7 {
                if let desc = applySynergy(tag: tag, tier: 7, stats: stats) {
                    triggered.append(desc)
                }
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
        
        switch (tag, tier) {
            
        // FIRE
        case (.fire, 3):
            stats.burnSpreads = true
            return "🔥 Spreading Flame — Burns spread to nearby enemies"
        case (.fire, 5):
            stats.burnDPS *= 2.0
            stats.burnDuration = 4.0
            return "🔥 Inferno — Burn damage doubled, duration 4s"
        case (.fire, 7):
            stats.passiveArenaDPS += 0.5
            return "🔥 Meltdown — All enemies take passive burn damage"
            
        // SHOCK
        case (.shock, 3):
            stats.chainTargets += 1  // Now chains to 2
            return "⚡ Charged — Chain lightning hits 2 targets"
        case (.shock, 5):
            stats.teslaFieldDPS = 0.3
            return "⚡ Tesla Field — Passive aura damages nearby enemies"
        case (.shock, 7):
            stats.spreadShotInterval = 3
            stats.spreadShotCount = 3
            // All spread shots also chain
            return "⚡ Lightning Storm — Every 3rd shot fires a spread, all chain"
            
        // BLEED
        case (.bleed, 3):
            stats.critAppliesBleed = true
            stats.bleedDPS = 0.5
            return "🩸 Open Wound — Crits apply bleed"
        case (.bleed, 5):
            stats.bloodlustDamagePerKill = 0.05
            return "🩸 Bloodlust — Kill streaks grant stacking damage"
        case (.bleed, 7):
            stats.executionThreshold = 0.3
            return "🩸 Exsanguinate — Low HP enemies take double damage"
            
        // GUARD — v1.4: Iron Skin now grants DEF instead of lethal saves
        case (.guardT, 3):
            // Barrier Pulse — handled in level-up logic (push enemies back)
            return "🛡️ Barrier Pulse — Enemies pushed back on level up"
        case (.guardT, 5):
            stats.defense += 15
            return "🛡️ Iron Skin — +15 DEF, shrug off weak hits"
        case (.guardT, 7):
            stats.globalEnemySlow += 0.15
            stats.collisionShrink *= 0.85
            return "🛡️ Unbreakable — Enemies slowed, hitbox shrinks further"
            
        // VOID
        case (.voidT, 3):
            stats.pierceCount += 1
            return "🕳️ Rift — Projectiles pierce an additional enemy"
        case (.voidT, 5):
            stats.gravityWellDuration = 2.0
            stats.gravityWellDPS = 0.5
            return "🕳️ Event Horizon — Gravity wells last longer and deal damage"
        case (.voidT, 7):
            stats.singularityActive = true
            return "🕳️ Singularity — Massive gravity wells spawn periodically"
            
        // CHILL
        case (.chill, 3):
            stats.slowPotencyMultiplier = 2.0
            return "❄️ Deep Freeze — All slow effects doubled"
        case (.chill, 5):
            stats.shatterChance = 0.2
            return "❄️ Shatter — Heavily slowed enemies can shatter on hit"
        case (.chill, 7):
            stats.globalEnemySlow += 0.25
            stats.shatterSlowThreshold = 0.3
            return "❄️ Absolute Zero — Permanent global slow, easier shatters"
            
        default:
            return nil
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
        
        cards.append(UpgradeCard(
            id: "fire_2", name: "Forge Breath", tag: .fire,
            description: "+15% damage"
        ) { stats in
            stats.damageMultiplier += 0.15
        })
        
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
        
        cards.append(UpgradeCard(
            id: "shock_1", name: "Static", tag: .shock,
            description: "+12% attack speed"
        ) { stats in
            stats.fireRateMultiplier *= 0.88  // Lower interval = faster
        })
        
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
        
        cards.append(UpgradeCard(
            id: "bleed_1", name: "Nick", tag: .bleed,
            description: "+8% critical hit chance"
        ) { stats in
            stats.critChance += 0.08
        })
        
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
        
        cards.append(UpgradeCard(
            id: "guard_4", name: "Fortify", tag: .guardT,
            description: "All enemies slowed 8%"
        ) { stats in
            stats.globalEnemySlow += 0.08
        })
        
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
        
        cards.append(UpgradeCard(
            id: "void_3", name: "Phase", tag: .voidT,
            description: "+25% range, projectiles pierce 1 enemy"
        ) { stats in
            stats.projectileRangeMultiplier += 0.25
            stats.pierceCount += 1
        })
        
        cards.append(UpgradeCard(
            id: "void_4", name: "Devour", tag: .voidT,
            description: "Kills pull XP orbs from 2x range"
        ) { stats in
            stats.killOrbPullMultiplier = 2.0
        })
        
        // ═══════════════════════════════════
        // ❄️ CHILL
        // ═══════════════════════════════════
        
        cards.append(UpgradeCard(
            id: "chill_1", name: "Frost Touch", tag: .chill,
            description: "Projectiles slow enemies 10% for 2s"
        ) { stats in
            stats.slowAmount += 0.10
        })
        
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
        
        cards.append(UpgradeCard(
            id: "neutral_6", name: "Scatter", tag: .neutral,
            description: "+1 projectile (wider spread)"
        ) { stats in
            stats.extraProjectiles += 1
            stats.spreadAngle += 0.15
        })
        
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

        return cards
    }
}
