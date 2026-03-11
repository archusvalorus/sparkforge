// UpgradeManager.swift
// Sparkforge
//
// Manages the 30 upgrade cards (24 tagged + 6 neutral).
// Handles card definitions, random draw, and applying effects to PlayerStats.

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
    
    // MARK: - Init
    
    init() {
        allCards = UpgradeManager.buildCardPool()
    }
    
    // MARK: - Draw
    
    /// Draw N random cards the player hasn't picked yet
    func drawCards(count: Int = 3) -> [UpgradeCard] {
        let available = allCards.filter { card in
            !pickedCardIDs.contains(card.id)
        }
        
        guard !available.isEmpty else { return [] }
        
        var drawn: [UpgradeCard] = []
        var pool = available.shuffled()
        
        let drawCount = min(count, pool.count)
        for _ in 0..<drawCount {
            drawn.append(pool.removeFirst())
        }
        
        return drawn
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
    
    // MARK: - Reset
    
    func reset() {
        pickedCardIDs.removeAll()
        tagCounts.removeAll()
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
            
        // GUARD
        case (.guardT, 3):
            // Barrier Pulse — handled in level-up logic (push enemies back)
            return "🛡️ Barrier Pulse — Enemies pushed back on level up"
        case (.guardT, 5):
            stats.lethalSaves = max(stats.lethalSaves, 2)
            return "🛡️ Iron Skin — Survive 2 lethal hits per run"
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
            // Singularity — handled in GameScene timer logic
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
            // Stun is implemented as a strong slow (100%) for 0.5s
            // Handled in hit logic — flag-based
            stats.slowAmount += 0.15  // Repurposed as stun chance in hit logic
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
            description: "Each kill extends your run by 0.3s"
        ) { stats in
            stats.killTimeBonus = 0.3
        })
        
        // ═══════════════════════════════════
        // 🛡️ GUARD
        // ═══════════════════════════════════
        
        cards.append(UpgradeCard(
            id: "guard_1", name: "Brace", tag: .guardT,
            description: "Survive one lethal hit per run"
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
        
        return cards
    }
}
