// PlayerStats.swift
// Sparkforge
//
// Runtime stat block for the current run.
// Cards modify these values. Systems read them.
// Reset each run.

import CoreGraphics
import Foundation

final class PlayerStats {
    
    // MARK: - Damage
    
    /// Projectile damage multiplier (base: 1.0)
    var damageMultiplier: CGFloat = 1.0
    /// Crit chance 0.0–1.0 (base: 0)
    var critChance: CGFloat = 0.0
    /// Crit damage multiplier (base: 2.0)
    var critMultiplier: CGFloat = 2.0
    
    // MARK: - Projectiles
    
    /// Fire interval multiplier (lower = faster, base: 1.0)
    var fireRateMultiplier: CGFloat = 1.0
    /// Extra projectiles per shot (base: 0, so total = 1 + this)
    var extraProjectiles: Int = 0
    /// Projectile speed multiplier (base: 1.0)
    var projectileSpeedMultiplier: CGFloat = 1.0
    /// Projectile range multiplier (base: 1.0)
    var projectileRangeMultiplier: CGFloat = 1.0
    /// Number of enemies a projectile can pierce through (base: 0)
    var pierceCount: Int = 0
    /// Spread angle in radians for multi-projectile shots
    var spreadAngle: CGFloat = 0.25
    
    // MARK: - Movement
    
    /// Move speed multiplier (base: 1.0)
    var moveSpeedMultiplier: CGFloat = 1.0
    
    // MARK: - Pickup
    
    /// XP orb magnet radius multiplier (base: 1.0)
    var pickupRadiusMultiplier: CGFloat = 1.0
    /// XP gain multiplier (base: 1.0)
    var xpMultiplier: CGFloat = 1.0
    
    // MARK: - Status Effects (applied to enemies)
    
    /// Burn DPS applied on projectile hit (base: 0)
    var burnDPS: CGFloat = 0.0
    /// Burn duration in seconds (base: 2.0 when active)
    var burnDuration: TimeInterval = 2.0
    /// Whether burns spread to nearby enemies
    var burnSpreads: Bool = false
    /// Burn spread radius
    var burnSpreadRadius: CGFloat = 30.0
    
    /// Slow % applied on projectile hit (0.0–1.0, base: 0)
    var slowAmount: CGFloat = 0.0
    /// Slow duration in seconds
    var slowDuration: TimeInterval = 2.0
    /// Global slow multiplier on all slows (base: 1.0)
    var slowPotencyMultiplier: CGFloat = 1.0
    /// Bonus damage dealt to slowed enemies (base: 0)
    var slowedDamageBonus: CGFloat = 0.0
    /// Shatter chance on heavily slowed enemies (base: 0)
    var shatterChance: CGFloat = 0.0
    /// Slow threshold for shatter eligibility
    var shatterSlowThreshold: CGFloat = 0.4
    
    /// Whether crits apply bleed
    var critAppliesBleed: Bool = false
    /// Bleed DPS from crits (base: 0)
    var bleedDPS: CGFloat = 0.0
    /// Bleed duration
    var bleedDuration: TimeInterval = 3.0
    
    // MARK: - Knockback
    
    /// Knockback distance on projectile hit (base: 0)
    var knockbackForce: CGFloat = 0.0
    
    // MARK: - Survival
    
    /// Number of lethal hits that can be survived (base: 0)
    var lethalSaves: Int = 0
    /// Collision radius shrink multiplier (base: 1.0, lower = smaller)
    var collisionShrink: CGFloat = 1.0
    /// Global enemy speed reduction (base: 0, additive %)
    var globalEnemySlow: CGFloat = 0.0
    
    // MARK: - Chain Lightning (Shock)
    
    /// Number of chain targets on hit (base: 0)
    var chainTargets: Int = 0
    /// Chain damage multiplier relative to original hit
    var chainDamageMultiplier: CGFloat = 0.5
    
    // MARK: - Special Mechanics
    
    /// Whether kills explode (Ember Burst)
    var killsExplode: Bool = false
    /// Explosion radius
    var explosionRadius: CGFloat = 40.0
    /// Explosion damage as % of kill damage
    var explosionDamagePercent: CGFloat = 0.3
    
    /// Kill streak fire rate bonus
    var killStreakFireRateBonus: CGFloat = 0.0
    /// Kill streak required count
    var killStreakThreshold: Int = 3
    /// Kill streak duration window
    var killStreakWindow: TimeInterval = 3.0
    
    /// Time added per kill (Siphon)
    var killTimeBonus: TimeInterval = 0.0
    
    /// XP orb pull range multiplier on kill (Devour)
    var killOrbPullMultiplier: CGFloat = 1.0
    
    /// Whether player leaves chill trail
    var chillTrail: Bool = false
    /// Chill trail slow amount
    var chillTrailSlow: CGFloat = 0.08
    /// Chill trail slow duration
    var chillTrailDuration: TimeInterval = 1.5
    
    /// Tesla field DPS (passive aura around player)
    var teslaFieldDPS: CGFloat = 0.0
    /// Tesla field radius
    var teslaFieldRadius: CGFloat = 50.0
    
    /// Passive arena-wide DPS (Meltdown)
    var passiveArenaDPS: CGFloat = 0.0
    
    /// Gravity well on projectile expire
    var gravityWellOnExpire: Bool = false
    /// Gravity well radius
    var gravityWellRadius: CGFloat = 30.0
    /// Gravity well duration
    var gravityWellDuration: TimeInterval = 1.0
    /// Gravity well DPS (if upgraded)
    var gravityWellDPS: CGFloat = 0.0
    
    /// Bloodlust: stacking damage bonus per kill within window
    var bloodlustDamagePerKill: CGFloat = 0.0
    var bloodlustMaxBonus: CGFloat = 0.25
    var bloodlustWindow: TimeInterval = 2.0
    
    /// Whether enemies below HP threshold take double damage (Exsanguinate)
    var executionThreshold: CGFloat = 0.0
    
    /// Every Nth shot fires spread (Lightning Storm)
    var spreadShotInterval: Int = 0
    var spreadShotCount: Int = 3
    
    // MARK: - Computed Properties
    
    /// Effective fire interval after multipliers
    var effectiveFireInterval: TimeInterval {
        return GameConfig.Projectile.fireInterval * TimeInterval(fireRateMultiplier)
    }
    
    /// Effective move speed
    var effectiveMoveSpeed: CGFloat {
        return GameConfig.Player.speed * moveSpeedMultiplier
    }
    
    /// Effective projectile speed
    var effectiveProjectileSpeed: CGFloat {
        return GameConfig.Projectile.speed * projectileSpeedMultiplier
    }
    
    /// Effective projectile range
    var effectiveProjectileRange: CGFloat {
        return GameConfig.Projectile.maxRange * projectileRangeMultiplier
    }
    
    /// Effective pickup radius
    var effectivePickupRadius: CGFloat {
        return 80.0 * pickupRadiusMultiplier  // XPOrbNode.magnetRadius base
    }
    
    /// Effective collision radius
    var effectiveCollisionRadius: CGFloat {
        return GameConfig.Player.collisionRadius * collisionShrink
    }
    
    /// Calculate effective slow on an enemy (with potency multiplier)
    func effectiveSlow(_ baseAmount: CGFloat) -> CGFloat {
        return min(baseAmount * slowPotencyMultiplier, 0.8)  // Cap at 80% slow
    }
    
    // MARK: - Kill Streak Tracking
    
    private(set) var currentKillStreak: Int = 0
    private var lastKillTime: TimeInterval = 0
    
    /// Record a kill. Returns true if streak is active.
    func recordKill(atTime time: TimeInterval) -> Bool {
        if time - lastKillTime <= killStreakWindow {
            currentKillStreak += 1
        } else {
            currentKillStreak = 1
        }
        lastKillTime = time
        return currentKillStreak >= killStreakThreshold
    }
    
    /// Check if kill streak is currently active
    func isKillStreakActive(atTime time: TimeInterval) -> Bool {
        guard killStreakFireRateBonus > 0 else { return false }
        return currentKillStreak >= killStreakThreshold && (time - lastKillTime) <= killStreakWindow
    }
    
    // MARK: - Bloodlust Tracking
    
    private(set) var bloodlustStacks: Int = 0
    private var bloodlustLastKillTime: TimeInterval = 0
    
    func recordBloodlustKill(atTime time: TimeInterval) {
        guard bloodlustDamagePerKill > 0 else { return }
        if time - bloodlustLastKillTime <= bloodlustWindow {
            bloodlustStacks += 1
        } else {
            bloodlustStacks = 1
        }
        bloodlustLastKillTime = time
    }
    
    var bloodlustBonus: CGFloat {
        let bonus = CGFloat(bloodlustStacks) * bloodlustDamagePerKill
        return min(bonus, bloodlustMaxBonus)
    }
    
    func isBloodlustActive(atTime time: TimeInterval) -> Bool {
        return bloodlustStacks > 0 && (time - bloodlustLastKillTime) <= bloodlustWindow + 3.0
    }
    
    // MARK: - Shot Counter (for Lightning Storm)
    
    private(set) var shotsFired: Int = 0
    
    func recordShot() -> Bool {
        guard spreadShotInterval > 0 else { return false }
        shotsFired += 1
        return shotsFired % spreadShotInterval == 0
    }
    
    // MARK: - Reset
    
    func reset() {
        damageMultiplier = 1.0
        critChance = 0.0
        critMultiplier = 2.0
        fireRateMultiplier = 1.0
        extraProjectiles = 0
        projectileSpeedMultiplier = 1.0
        projectileRangeMultiplier = 1.0
        pierceCount = 0
        spreadAngle = 0.25
        moveSpeedMultiplier = 1.0
        pickupRadiusMultiplier = 1.0
        xpMultiplier = 1.0
        burnDPS = 0.0
        burnDuration = 2.0
        burnSpreads = false
        burnSpreadRadius = 30.0
        slowAmount = 0.0
        slowDuration = 2.0
        slowPotencyMultiplier = 1.0
        slowedDamageBonus = 0.0
        shatterChance = 0.0
        shatterSlowThreshold = 0.4
        critAppliesBleed = false
        bleedDPS = 0.0
        bleedDuration = 3.0
        knockbackForce = 0.0
        lethalSaves = 0
        collisionShrink = 1.0
        globalEnemySlow = 0.0
        chainTargets = 0
        chainDamageMultiplier = 0.5
        killsExplode = false
        explosionRadius = 40.0
        explosionDamagePercent = 0.3
        killStreakFireRateBonus = 0.0
        killStreakThreshold = 3
        killStreakWindow = 3.0
        killTimeBonus = 0.0
        killOrbPullMultiplier = 1.0
        chillTrail = false
        chillTrailSlow = 0.08
        chillTrailDuration = 1.5
        teslaFieldDPS = 0.0
        teslaFieldRadius = 50.0
        passiveArenaDPS = 0.0
        gravityWellOnExpire = false
        gravityWellRadius = 30.0
        gravityWellDuration = 1.0
        gravityWellDPS = 0.0
        bloodlustDamagePerKill = 0.0
        bloodlustMaxBonus = 0.25
        bloodlustWindow = 2.0
        executionThreshold = 0.0
        spreadShotInterval = 0
        spreadShotCount = 3
        currentKillStreak = 0
        lastKillTime = 0
        bloodlustStacks = 0
        bloodlustLastKillTime = 0
        shotsFired = 0
    }
}
