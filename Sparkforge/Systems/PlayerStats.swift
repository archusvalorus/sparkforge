// PlayerStats.swift
// Sparkforge
//
// Runtime stat block for the current run.
// Cards modify these values. Systems read them.
// Reset each run.
//
// v1.4: HP/ATK/DEF system. Damage is no longer binary.
// - maxHP / currentHP: player health pool
// - baseAttack: flat damage per projectile (replaces old damageMultiplier=1.0 baseline)
// - defense: flat damage reduction per hit
// - damageMultiplier remains as a % multiplier ON baseAttack

import CoreGraphics
import Foundation

final class PlayerStats {
    
    // MARK: - HP / ATK / DEF (v1.4)
    
    /// Maximum health — cards and forge bonuses can increase this
    var maxHP: Int = GameConfig.Player.baseMaxHP
    /// Current health — depletes on damage, restored by health orbs
    var currentHP: Int = GameConfig.Player.baseMaxHP
    /// Base attack damage per projectile
    var baseAttack: Int = GameConfig.Player.baseAttack
    /// Flat damage reduction per hit
    var defense: Int = GameConfig.Player.baseDefense

    // MARK: - Everglow (Fire capstone, v1.9). Per-run; reset each run.
    var everglowTier: Int = 0                 // 0 = inactive; 1..5
    var everglowBasePulseMult: CGFloat = 0     // fraction of ATK per pulse
    var everglowPulseRadius: CGFloat = 0
    var everglowRageScaling = false            // T3: hits grow pulse damage
    var everglowFurnaceScaling = false         // T4: hits also grow ATK
    var everglowEruption = false               // T5: periodic arena eruption
    var everglowPulseGrowth: CGFloat = 0       // accumulated +% pulse (capped)
    var everglowAtkGrowth: CGFloat = 0         // accumulated +% ATK (capped)

    // MARK: - Iron Maiden (Guard capstone, v1.9). Per-run; reset each run.
    var ironMaidenTier: Int = 0               // 0 = inactive; 1..5
    var ironSkinDefToDmg: CGFloat = 0         // DEF→damage conversion (see IronMaiden note)
    var ironThorns: Int = 0                   // flat damage to enemies on damaging contact
    var ironRetaliate: CGFloat = 0            // fraction of pre-mitigation incoming countered (T3)
    var ironKineticActive = false             // T4: damaging hits build Kinetic stacks
    var ironKineticStacks: Int = 0
    var ironMaidenProjectile = false          // T5: timed compressed projectile

    /// Iron Maiden Kinetic burst / projectile payload: 200% of current DEF.
    var ironKineticBurstDamage: Int {
        max(1, Int(CGFloat(defense) * GameConfig.IronMaiden.kineticBurstDefMult))
    }

    // MARK: - Skybeam (Shock capstone, v1.9). Per-run; reset each run.
    var skybeamTier: Int = 0                  // 0 = inactive; 1..5
    var skybeamTickMult: CGFloat = 0          // fraction of ATK per lasso tick
    var skybeamAcquireRange: CGFloat = 0      // lasso acquisition radius
    var skybeamHoming = false                 // T3: auto-aim prefers the lassoed prey
    var skybeamCalled = false                 // T4: continuous lasso → vulnerability
    var skybeamStrike = false                 // T5: repeating sky-strikes

    // MARK: - Apex (Bleed capstone, v1.9). Per-run; reset each run.
    var apexTier: Int = 0                     // 0 = inactive; 1..5
    var apexFamiliarActive = false            // T1: bat summoned
    var apexBloodhound = false                // T3: prioritize bleeding + execute low normals
    var apexHpToAtkActive = false             // T2: 1% max HP → bonus ATK
    var apexMarked = false                    // T4: lingering enemies become vulnerable
    var apexHunter = false                    // T5: fused — pounce replaces bites
    var apexFamiliarKills: Int = 0            // drives the bat's damage growth
    var apexBloodfedBonusHP: Int = 0          // Bloodfed accumulated max-HP (capped)

    /// The familiar's current damage as a fraction of ATK: 10% → 50%, +1% per 5 kills.
    var apexFamiliarDamageFrac: CGFloat {
        let steps = CGFloat(apexFamiliarKills / GameConfig.Apex.familiarKillsPerStep)
        let frac = GameConfig.Apex.familiarBaseFrac + steps * GameConfig.Apex.familiarFracPerStep
        return min(frac, GameConfig.Apex.familiarMaxFrac)
    }

    /// T2: bonus flat ATK from 1% of max HP. Feeds ATK-scaled Apex abilities (bat,
    /// pounce) — projectiles use the multiplier, not baseAttack, so this stays a
    /// familiar/pounce buff (thematically "your vitality feeds the hunt").
    var apexBonusAttackFromHP: CGFloat {
        apexHpToAtkActive ? CGFloat(maxHP) * GameConfig.Apex.hpToAtkFrac : 0
    }

    /// Effective per-hit ATK (base × all damage multipliers) — the scale for
    /// "%ATK" capstone abilities (Skybeam ticks/strikes, Apex bat/pounce, etc.).
    var effectiveAttack: CGFloat { (CGFloat(baseAttack) + apexBonusAttackFromHP) * effectiveDamageMultiplier }

    /// The "effective ATK" figure for the HUD: (base + HP-fed ATK) × the stable
    /// build multiplier (excludes volatile combat buffs so it doesn't flicker).
    var displayAttack: Int {
        max(0, Int(((CGFloat(baseAttack) + apexBonusAttackFromHP) * displayDamageMultiplier).rounded()))
    }

    // MARK: - Erasure (Void capstone, v1.9). Per-run; reset each run.
    var erasureTier: Int = 0                  // 0 = inactive; 1..5
    var erasureActive = false                 // T1: hits stack Unstable
    var erasureVoidTouched = false            // T2: armor bypass + 2-stack trigger
    var erasureRiftCannon = false             // T3: rift cannon every Nth activation
    var erasureEcho = false                   // T4: projectiles echo from elsewhere
    var erasureEventHorizon = false           // T5: the run-ending void
    var erasureTriggerCD: TimeInterval = GameConfig.Erasure.unstableTriggerCooldown
    var erasureActivations: Int = 0           // counts triggers (drives the rift cannon)
    var erasureEventHorizonAcquireTime: TimeInterval = -1  // elapsed time when T5 was taken

    // MARK: - Polar Vortex (Chill capstone, v1.9). Per-run; reset each run.
    var polarVortexTier: Int = 0              // 0 = inactive; 1..5
    var iceburstActive = false                // T1: frozen deaths burst into shards
    var iceburstShards: Int = GameConfig.PolarVortex.iceburstShardsT1
    var brittleCold = false                   // T2: +damage vs impaired
    var windchillActive = false               // T3: cold storm stacks Chill
    var windchillRadius: CGFloat = 0
    var glacialActive = false                 // T4: shots condense into icicles
    var polarVortexFreeze = false             // T5: Chill → freeze → frostbite
    var glacialShotCounter: Int = 0           // T4 condensation counter

    /// Add a Kinetic stack on a damaging hit (T4+). Returns true when the reserve
    /// hits its threshold and releases — the caller fires the radial burst.
    func addKineticStack() -> Bool {
        guard ironKineticActive else { return false }
        ironKineticStacks += 1
        if ironKineticStacks >= GameConfig.IronMaiden.kineticThreshold {
            ironKineticStacks = 0
            return true
        }
        return false
    }

    /// Damage of one Everglow pulse: effective ATK × base mult × (1 + rage).
    /// (effectiveDamageMultiplier already folds in everglowAtkGrowth.)
    var everglowPulseDamage: Int {
        guard everglowTier >= 1 else { return 0 }
        let atk = CGFloat(baseAttack) * effectiveDamageMultiplier
        return max(1, Int(atk * everglowBasePulseMult * (1 + everglowPulseGrowth)))
    }

    /// Damage of one Everglow eruption: effective ATK × eruption multiplier.
    var everglowEruptionDamage: Int {
        let atk = CGFloat(baseAttack) * effectiveDamageMultiplier
        return max(1, Int(atk * GameConfig.Everglow.eruptionMult))
    }
    
    /// HP as 0.0–1.0 fraction for HUD bar
    var hpPercent: CGFloat {
        guard maxHP > 0 else { return 0 }
        return CGFloat(currentHP) / CGFloat(maxHP)
    }
    
    // v1.9 Unit 4: the three level-up stat lanes.
    enum StatKind: String, CaseIterable {
        case hp, attack, defense
        var label: String { self == .hp ? "MAX HP" : self == .attack ? "ATK" : "DEF" }
        var emoji: String { self == .hp ? "❤️" : self == .attack ? "⚔️" : "🛡️" }
        var colorHex: UInt32 { self == .hp ? 0xE05555 : self == .attack ? 0xFF8833 : 0x4C90D0 }
        var bonus: Int {
            switch self {
            case .hp: return GameConfig.LevelUp.hpBonus
            case .attack: return GameConfig.LevelUp.attackBonus
            case .defense: return GameConfig.LevelUp.defenseBonus
            }
        }
    }

    /// v1.9 Unit 4: apply one level-up stat award (chosen or random).
    /// HP raises the pool AND heals for the same, so it's felt immediately.
    func applyStatBonus(_ kind: StatKind) {
        switch kind {
        case .hp:
            maxHP += kind.bonus
            currentHP = min(currentHP + kind.bonus, maxHP)
        case .attack:
            baseAttack += kind.bonus
        case .defense:
            defense += kind.bonus
        }
    }

    /// Take damage after DEF reduction. Returns true if player died (HP <= 0).
    @discardableResult
    func takeDamage(_ rawDamage: Int) -> Bool {
        // v1.7 Grounded Core: the brace adds DEF while standing still
        // v1.8 Ironhide: pressure-DEF while crowded (set per-frame by GameScene)
        let effectiveDefense = defense
            + (groundedCoreBraced ? groundedCoreBonusDEF : 0)
            + (pressureDefActive ? pressureDefBonus : 0)
        let reduced = max(1, rawDamage - effectiveDefense)
        currentHP -= reduced
        if currentHP < 0 { currentHP = 0 }

        // v1.9 Everglow: rage — taking damage permanently grows the pulse (T3)
        // and ATK (T4), each capped per run.
        if everglowRageScaling {
            everglowPulseGrowth = min(everglowPulseGrowth + GameConfig.Everglow.rageGainPerHit,
                                      GameConfig.Everglow.pulseGrowthCap)
        }
        if everglowFurnaceScaling {
            everglowAtkGrowth = min(everglowAtkGrowth + GameConfig.Everglow.furnaceAtkGainPerHit,
                                    GameConfig.Everglow.atkGrowthCap)
        }

        return currentHP <= 0
    }
    
    // MARK: - Forge Path — Vitality survival nodes (rework Unit 2a)
    var forgeVitalSurplusDR: CGFloat = 0     // 10A: above 75% HP
    var forgeLastStandDR: CGFloat = 0        // 10B: below 35% HP
    var forgeHoldLineDR: CGFloat = 0         // 15A: while crowded
    var forgeGiantkillerDR: CGFloat = 0      // 15B: vs boss-class
    var forgeBracedImpact = false            // 5B: first hit every 12s -25%
    var forgeSecondBreath = false            // 20A
    var forgeUnyielding = false              // 20B
    var forgeRegenerator = false             // 5A
    var forgeSteadyPulse = false             // 14
    var forgeRestorationBonus: CGFloat = 0   // 13: +5% healing received
    var forgeDefiant = false                 // 18: node owned
    var forgeDefiantActive = false           // 18: temp window (set by GameScene)

    // MARK: - Forge Path — Ferocity offensive + Opportunist (rework Unit 2b)
    var forgeBerserker = false               // Fer 5A: <50% HP +5% dmg
    var forgeHeadsman = false                // Fer 10B: +10% vs boss-class
    var forgeCleaver = false                 // Fer 10A: 4+ enemies +8% dmg
    var forgeOpeningBlow = false             // Fer 14: +10% vs enemies >90% HP
    var forgeOpportunist = false             // Cun 13: +5% vs impaired foes
    var forgeRisingHeat = false              // Fer 13: kill → +1% dmg 3s (stacks 5)
    var forgeBloodrush = false               // Fer 15A: kill → +5% atk speed 4s (stacks 3)
    var forgeColdFury = false                // Fer 15B: 8s no kill → +10% next hit
    var forgeKillingStroke = false           // Fer 20B: every 12s next attack +75%
    var forgeWarpath = false                 // Fer 20A: 6s continuous damage → +10%
    var forgeRelentless = false              // Fer 18: same-target +1%/stack to +5%
    var forgeOverkill = false                // Fer 19: excess damage bursts to nearby
    var forgeBloodrushBonus: CGFloat = 0     // current Bloodrush atk-speed bonus (set by GameScene)

    // MARK: - Forge Path — Cunning utility (rework Unit 2c)
    var forgeCalculatedStrike = false        // Cun 15A: every 5th attack a guaranteed crit
    var forgeLuckyBreak = false              // Cun 15B: crit → 10% chance +50% crit dmg
    var forgeReadRoom = false                // Cun 18: elite/boss enters → +8% move 4s
    var forgeSlipstream = false              // Cun 10B: evasive → +8% move 2s (fallback rule)
    var forgeForesight = false               // Cun 20A: +1 reroll per run
    var forgeSalvager = false                // Cun 19: coin attraction (no coin-magnet system yet)
    var forgeSecondLook = false              // Cun 20B: pass-offer free re-draw (needs UI)
    var forgeMoveBonus: CGFloat = 0          // temp move-speed buff (Read the Room / Slipstream)

    /// Heal HP, clamped to maxHP — scaled by Forge Path healing-received bonuses
    /// (Restoration + Defiant Recovery's temp window).
    func heal(_ amount: Int) {
        let mult = 1.0 + forgeRestorationBonus + (forgeDefiantActive ? GameConfig.ForgePath.defiantBonus : 0)
        currentHP = min(currentHP + Int(CGFloat(amount) * mult), maxHP)
    }
    
    // MARK: - Damage
    
    /// Projectile damage multiplier (base: 1.0) — multiplies baseAttack
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

    // MARK: - v1.8 Unit 5b: reworked synergy tree fields
    // Starting values live in UpgradeManager.applySynergy; the balance pass
    // tunes them. All default to inert (0 / false).

    // Bleed
    /// Open Wounds: bleeding enemies take this much MORE damage (0.15 = +15%)
    var bleedingEnemyDamageTaken: CGFloat = 0.0
    /// Red Harvest: HP restored when a BLEEDING enemy dies
    var bleedKillHeal: Int = 0

    // Guard
    /// Ironhide: DEF gained while crowded (applied via pressureDefActive)
    var pressureDefBonus: Int = 0
    var pressureDefRadius: CGFloat = 90.0
    var pressureDefEnemyCount: Int = 3
    /// Set per-frame by GameScene when the crowd condition is met
    var pressureDefActive: Bool = false
    /// Thornwall: fraction of contact damage reflected to the toucher
    var thornsContactReflect: CGFloat = 0.0
    /// Unbroken Core: added to the damage multiplier per point of DEF
    /// (spec: +1% dmg per 3 DEF → 0.01/3 per DEF)
    var defAsDamageMult: CGFloat = 0.0

    // Void
    /// Undertow: passive per-second pull of nearby enemies toward the player
    var voidPullForce: CGFloat = 0.0
    var voidPullRadius: CGFloat = 0.0
    /// Event Horizon: extra slow applied to enemies inside a gravity well
    var inWellSlow: CGFloat = 0.0

    // MARK: - Knockback
    
    /// Knockback distance on projectile hit (base: 0)
    var knockbackForce: CGFloat = 0.0
    
    // MARK: - Survival
    
    /// Number of lethal hits that can be survived (base: 0)
    /// v1.4: Now triggers when HP reaches 0 — prevents death, restores 1 HP
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
    /// v1.7 Copper Vein: extra chain target search radius
    var shockChainRadiusBonus: CGFloat = 0

    // MARK: - v1.7: Coilworks Cards

    /// Induction Step — distance traveled charges the next attack
    var inductionStepActive: Bool = false
    /// Points of travel for a full charge
    var inductionChargeDistance: CGFloat = 380
    private(set) var inductionCharge: CGFloat = 0  // 0.0–1.0

    func addInductionCharge(distance: CGFloat) {
        guard inductionStepActive else { return }
        inductionCharge = min(1.0, inductionCharge + distance / inductionChargeDistance)
    }

    /// Consume a full charge. Returns the bonus Shock damage (0 if not charged).
    func consumeInductionCharge() -> Int {
        guard inductionStepActive, inductionCharge >= 1.0 else { return 0 }
        inductionCharge = 0
        return max(3, Int(CGFloat(baseAttack) * 1.5))
    }

    /// Relay Burn (Fire/Shock) — burning foes can arc Shock
    var relayBurnActive: Bool = false
    /// Expected arcs per burning enemy per second (dt-scaled roll)
    var relayBurnRate: CGFloat = 0.9
    var relayBurnDamage: Int = 4
    var relayBurnRadius: CGFloat = 90

    /// Overclock — level-ups grant speed briefly
    var overclockActive: Bool = false
    var overclockBoost: CGFloat = 0.35
    var overclockDuration: TimeInterval = 3.0
    private(set) var overclockTimer: TimeInterval = 0

    func triggerOverclock() {
        guard overclockActive else { return }
        overclockTimer = overclockDuration
    }

    /// Dead Circuit — player-created void zones linger longer
    var voidZoneDurationMultiplier: CGFloat = 1.0

    /// Grounded Core — standing still builds DEF
    var groundedCoreActive: Bool = false
    var groundedCoreBonusDEF: Int = 8
    /// Seconds of stillness before the brace engages
    var groundedCoreWindow: TimeInterval = 0.7
    private(set) var groundedCoreBraced: Bool = false
    private var stationaryTime: TimeInterval = 0

    /// Micro-adjustments don't break the brace — the caller treats tiny
    /// stick deflection as stillness (Lyra tuning guardrail)
    func updateGroundedCore(isMoving: Bool, dt: TimeInterval) {
        guard groundedCoreActive else {
            groundedCoreBraced = false
            return
        }
        if isMoving {
            stationaryTime = 0
            groundedCoreBraced = false
        } else {
            stationaryTime += dt
            groundedCoreBraced = stationaryTime >= groundedCoreWindow
        }
    }

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
    
    /// HP restored per kill (Siphon — v1.6 redesign from the dead "time bonus" concept)
    var killHealAmount: Int = 0

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

    /// v1.6: Stun chance on projectile hit (Overload — was a mislabeled slow)
    var stunChance: CGFloat = 0.0
    /// Stun duration in seconds
    var stunDuration: TimeInterval = 0.5

    /// v1.6: Singularity (Void tier-7) — periodic massive gravity wells
    var singularityActive: Bool = false
    var singularityInterval: TimeInterval = 8.0
    var singularityRadius: CGFloat = 90.0
    var singularityDuration: TimeInterval = 3.0
    var singularityDPS: CGFloat = 1.0

    // MARK: - v1.6: Quench Cards (Lyra)

    /// Arc Wake: damage per spark node dropped while moving (0 = off)
    var arcWakeDamage: Int = 0
    var arcWakeDropInterval: TimeInterval = 0.25
    var arcWakeLifetime: TimeInterval = 1.0

    /// Static Crown: shock burst on level-up (0 = off)
    var staticCrownDamage: Int = 0
    var staticCrownRadius: CGFloat = 90.0

    /// Blood Price: bonus damage while HP ≤ 50%
    var bloodPriceBonus: CGFloat = 0.0

    /// Open Vein: bleeding enemies burst on death (0 = off)
    var openVeinDamage: Int = 0
    var openVeinRadius: CGFloat = 40.0

    /// Iron Bloom: contact attackers take DEF-scaled thorns damage
    var ironBloomActive: Bool = false
    var ironBloomDamage: Int { max(1, defense / 3) }

    /// Aegis Pulse: periodic pulse around player, damage scales with DEF
    var aegisPulseActive: Bool = false
    var aegisPulseInterval: TimeInterval = 4.0
    var aegisPulseRadius: CGFloat = 70.0
    var aegisPulseDamage: Int { max(1, defense / 5) }
    private var aegisPulseTimer: TimeInterval = 0.0

    /// Null Bloom: chance on kill to leave a slowing zone
    var nullBloomChance: CGFloat = 0.0
    var nullBloomRadius: CGFloat = 35.0
    var nullBloomSlow: CGFloat = 0.4
    var nullBloomDuration: TimeInterval = 1.5

    /// Hoarfrost: flat regen — 1 HP per interval (0 = off)
    var hoarfrostInterval: TimeInterval = 0.0
    private var hoarfrostTimer: TimeInterval = 0.0

    /// Cauterize: regen 1 HP per interval while below HP threshold
    var cauterizeActive: Bool = false
    var cauterizeThreshold: CGFloat = 0.3
    var cauterizeInterval: TimeInterval = 3.0
    private var cauterizeTimer: TimeInterval = 0.0

    /// Whiteout: slowed enemies release a slow burst on death
    var whiteoutActive: Bool = false
    var whiteoutRadius: CGFloat = 50.0
    var whiteoutSlow: CGFloat = 0.3
    var whiteoutDuration: TimeInterval = 2.0

    // MARK: - v1.8 Mirrorwound Cards (Unit 14)

    /// Mirror Edge (Void): a shot can echo once at reduced damage after a delay.
    var echoChance: CGFloat = 0.0            // 0 = off
    var echoDamageMultiplier: CGFloat = 0.5
    var echoDelay: TimeInterval = 0.15

    /// Glass Blood (Bleed/Chill): bleed deals more vs chilled/slowed foes.
    var bleedVsSlowedMultiplier: CGFloat = 1.0   // 1.0 = no bonus

    /// Red Smile (Bleed): below the HP threshold, bleed deals more.
    var bleedLowHpBonus: CGFloat = 1.0           // 1.0 = no bonus
    var bleedLowHpThreshold: CGFloat = 0.5

    /// Silver Skin (Guard/Void): a level-up arms a one-hit block.
    var hasSilverSkin: Bool = false
    var silverSkinArmed: Bool = false

    /// Fracture Shot (Neutral): each shot launches split fragments at reduced damage.
    var splitCount: Int = 0                       // 0 = off
    var splitDamageMultiplier: CGFloat = 0.5
    var splitAngle: CGFloat = 0.22

    /// False Opening (Void): a hard direction-change while moving leaves a
    /// short-delayed one-shot Void pulse (NOT a lingering field).
    var falseOpeningActive: Bool = false
    var falseOpeningDelay: TimeInterval = 0.3
    var falseOpeningRadius: CGFloat = 72.0
    var falseOpeningDamage: Int = 12
    var falseOpeningSlow: CGFloat = 0.3
    var falseOpeningSlowDuration: TimeInterval = 1.2
    var falseOpeningCooldown: TimeInterval = 1.1

    // MARK: - v1.3 Card Properties
    
    /// Overcharge: damage bonus that builds while unhit, resets on hit
    var overchargeDamagePerSecond: CGFloat = 0.0
    var overchargeMaxBonus: CGFloat = 0.5
    private(set) var overchargeCurrentBonus: CGFloat = 0.0
    
    /// Glass Engine: attack speed boost with max HP penalty (v1.4: was lethal save penalty)
    var glassEngineActive: Bool = false
    
    /// Phase Skin: brief invulnerability on taking damage
    var phaseSkinCooldown: TimeInterval = 0.0
    var phaseSkinDuration: TimeInterval = 1.0
    private(set) var phaseSkinTimer: TimeInterval = 0.0
    private(set) var phaseSkinCooldownTimer: TimeInterval = 0.0
    
    /// Magnetic Core: XP pickup grants speed boost
    var magneticCoreSpeedBoost: CGFloat = 0.0
    var magneticCoreBoostDuration: TimeInterval = 1.5
    private(set) var magneticCoreBoostTimer: TimeInterval = 0.0
    
    /// Chain Reaction: enemies explode on death (separate from Ember Burst)
    var chainReactionExplode: Bool = false
    var chainReactionRadius: CGFloat = 35.0
    var chainReactionDamage: Int = 1
    
    /// Static Field: proximity slow aura around player
    var staticFieldRange: CGFloat = 0.0
    var staticFieldSlow: CGFloat = 0.15
    
    /// Execution Protocol: bonus damage to low HP enemies
    var executionProtocolThreshold: CGFloat = 0.0
    var executionProtocolMultiplier: CGFloat = 2.0
    
    /// Unstable Core: periodic burst damage + self damage
    /// v1.4: self-damage is now 10 HP instead of losing a lethal save
    var unstableCoreActive: Bool = false
    var unstableCoreDamage: Int = 2
    var unstableCoreRadius: CGFloat = 60.0
    var unstableCoreInterval: TimeInterval = 4.0
    var unstableCoreSelfDamage: Int = 10
    private(set) var unstableCoreTimer: TimeInterval = 0.0
    
    // MARK: - Computed Properties
    
    /// Effective fire interval after multipliers
    var effectiveFireInterval: TimeInterval {
        // Forge Path Bloodrush (Fer 15A): temp attack-speed bonus shortens it.
        return GameConfig.Projectile.fireInterval * TimeInterval(fireRateMultiplier)
            / TimeInterval(1 + forgeBloodrushBonus)
    }
    
    /// Effective move speed (+ Forge Path temp buffs: Read the Room / Slipstream)
    var effectiveMoveSpeed: CGFloat {
        return GameConfig.Player.speed * (moveSpeedMultiplier + forgeMoveBonus)
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
    
    /// v1.4: Effective projectile damage (baseAttack × multipliers + overcharge + bloodlust)
    var effectiveProjectileDamage: Int {
        let multiplied = CGFloat(baseAttack) * effectiveDamageMultiplier
        return max(1, Int(multiplied))
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
    
    // MARK: - Overcharge
    
    /// Call each frame while not hit — builds damage bonus
    func updateOvercharge(_ dt: TimeInterval) {
        guard overchargeDamagePerSecond > 0 else { return }
        overchargeCurrentBonus = min(overchargeCurrentBonus + overchargeDamagePerSecond * CGFloat(dt), overchargeMaxBonus)
    }
    
    /// Call when player takes damage — resets overcharge
    func resetOvercharge() {
        overchargeCurrentBonus = 0
    }
    
    /// Total damage multiplier including overcharge
    var effectiveDamageMultiplier: CGFloat {
        var total = damageMultiplier + overchargeCurrentBonus + bloodlustBonus
        // v1.6: Blood Price — bonus while at or below half HP
        if bloodPriceBonus > 0 && currentHP * 2 <= maxHP {
            total += bloodPriceBonus
        }
        // v1.8 Unbroken Core: DEF fuels damage (+1% per 3 DEF)
        if defAsDamageMult > 0 {
            total += CGFloat(defense) * defAsDamageMult
        }
        // v1.9 Iron Skin (Guard capstone): DEF fuels damage — "weaponize defense".
        if ironSkinDefToDmg > 0 {
            total += CGFloat(defense) * ironSkinDefToDmg
        }
        // v1.9 Everglow Living Furnace: damage taken permanently grows ATK.
        total += everglowAtkGrowth
        return total
    }

    /// Multiplier for the HUD's "effective ATK" readout: the persistent build
    /// multiplier PLUS the permanent DEF-fueled conversions (Unbroken Core, Iron
    /// Skin) and per-run ATK growth. Excludes volatile combat buffs
    /// (overcharge/bloodlust/blood price) so the number reflects build power and
    /// updates the moment DEF changes — without flickering frame to frame.
    var displayDamageMultiplier: CGFloat {
        var total = damageMultiplier
        if defAsDamageMult > 0 { total += CGFloat(defense) * defAsDamageMult }
        if ironSkinDefToDmg > 0 { total += CGFloat(defense) * ironSkinDefToDmg }
        total += everglowAtkGrowth
        return total
    }

    // MARK: - v1.6: Aegis Pulse

    /// Tick the pulse timer. Returns true when a pulse should fire.
    func updateAegisPulse(_ dt: TimeInterval) -> Bool {
        guard aegisPulseActive else { return false }
        aegisPulseTimer += dt
        if aegisPulseTimer >= aegisPulseInterval {
            aegisPulseTimer = 0
            return true
        }
        return false
    }

    // MARK: - v1.6: Regen (Hoarfrost + Cauterize)

    /// Tick regen timers. Returns HP to restore this frame (usually 0).
    func updateRegen(_ dt: TimeInterval) -> Int {
        var heal = 0
        if hoarfrostInterval > 0 {
            hoarfrostTimer += dt
            if hoarfrostTimer >= hoarfrostInterval {
                hoarfrostTimer = 0
                heal += 1
            }
        }
        if cauterizeActive {
            if hpPercent < cauterizeThreshold {
                cauterizeTimer += dt
                if cauterizeTimer >= cauterizeInterval {
                    cauterizeTimer = 0
                    heal += 1
                }
            } else {
                cauterizeTimer = 0
            }
        }
        return heal
    }
    
    // MARK: - Phase Skin
    
    /// Call each frame to tick down phase skin timers
    func updatePhaseSkin(_ dt: TimeInterval) {
        if phaseSkinTimer > 0 { phaseSkinTimer -= dt }
        if phaseSkinCooldownTimer > 0 { phaseSkinCooldownTimer -= dt }
    }
    
    /// Try to trigger phase skin. Returns true if activated.
    func triggerPhaseSkin() -> Bool {
        guard phaseSkinCooldown > 0 else { return false }
        guard phaseSkinCooldownTimer <= 0 else { return false }
        phaseSkinTimer = phaseSkinDuration
        phaseSkinCooldownTimer = phaseSkinCooldown
        return true
    }
    
    /// Whether phase skin invulnerability is active
    var isPhaseSkinActive: Bool { phaseSkinTimer > 0 }
    
    // MARK: - Magnetic Core
    
    /// Trigger speed boost on XP pickup
    func triggerMagneticCoreBoost() {
        guard magneticCoreSpeedBoost > 0 else { return }
        magneticCoreBoostTimer = magneticCoreBoostDuration
    }
    
    /// Update boost timers (magnetic core + v1.7 overclock)
    func updateMagneticCore(_ dt: TimeInterval) {
        if magneticCoreBoostTimer > 0 { magneticCoreBoostTimer -= dt }
        if overclockTimer > 0 { overclockTimer -= dt }
    }

    /// Effective move speed including boosts
    var effectiveMoveSpeedWithBoosts: CGFloat {
        var speed = GameConfig.Player.speed * moveSpeedMultiplier
        if magneticCoreBoostTimer > 0 {
            speed *= (1.0 + magneticCoreSpeedBoost)
        }
        if overclockTimer > 0 {
            speed *= (1.0 + overclockBoost)
        }
        return speed
    }
    
    // MARK: - Unstable Core
    
    /// Update unstable core timer. Returns true when it should burst.
    func updateUnstableCore(_ dt: TimeInterval) -> Bool {
        guard unstableCoreActive else { return false }
        unstableCoreTimer += dt
        if unstableCoreTimer >= unstableCoreInterval {
            unstableCoreTimer = 0
            return true
        }
        return false
    }
    
    // MARK: - Reset
    
    func reset() {
        // v1.4: HP system
        maxHP = GameConfig.Player.baseMaxHP
        currentHP = GameConfig.Player.baseMaxHP
        baseAttack = GameConfig.Player.baseAttack
        defense = GameConfig.Player.baseDefense

        // v1.9 Everglow (Fire capstone) — per-run state
        everglowTier = 0
        everglowBasePulseMult = 0
        everglowPulseRadius = 0
        everglowRageScaling = false
        everglowFurnaceScaling = false
        everglowEruption = false
        everglowPulseGrowth = 0
        everglowAtkGrowth = 0
        ironMaidenTier = 0
        ironSkinDefToDmg = 0
        ironThorns = 0
        ironRetaliate = 0
        ironKineticActive = false
        ironKineticStacks = 0
        ironMaidenProjectile = false
        skybeamTier = 0
        skybeamTickMult = 0
        skybeamAcquireRange = 0
        skybeamHoming = false
        skybeamCalled = false
        skybeamStrike = false
        apexTier = 0
        apexFamiliarActive = false
        apexBloodhound = false
        apexHpToAtkActive = false
        apexMarked = false
        apexHunter = false
        apexFamiliarKills = 0
        apexBloodfedBonusHP = 0
        erasureTier = 0
        erasureActive = false
        erasureVoidTouched = false
        erasureRiftCannon = false
        erasureEcho = false
        erasureEventHorizon = false
        erasureTriggerCD = GameConfig.Erasure.unstableTriggerCooldown
        erasureActivations = 0
        erasureEventHorizonAcquireTime = -1
        polarVortexTier = 0
        iceburstActive = false
        iceburstShards = GameConfig.PolarVortex.iceburstShardsT1
        brittleCold = false
        windchillActive = false
        windchillRadius = 0
        glacialActive = false
        polarVortexFreeze = false
        glacialShotCounter = 0
        forgeVitalSurplusDR = 0
        forgeLastStandDR = 0
        forgeHoldLineDR = 0
        forgeGiantkillerDR = 0
        forgeBracedImpact = false
        forgeSecondBreath = false
        forgeUnyielding = false
        forgeRegenerator = false
        forgeSteadyPulse = false
        forgeRestorationBonus = 0
        forgeDefiant = false
        forgeDefiantActive = false
        forgeBerserker = false
        forgeHeadsman = false
        forgeCleaver = false
        forgeOpeningBlow = false
        forgeOpportunist = false
        forgeRisingHeat = false
        forgeBloodrush = false
        forgeColdFury = false
        forgeKillingStroke = false
        forgeWarpath = false
        forgeRelentless = false
        forgeOverkill = false
        forgeBloodrushBonus = 0
        forgeCalculatedStrike = false
        forgeLuckyBreak = false
        forgeReadRoom = false
        forgeSlipstream = false
        forgeForesight = false
        forgeSalvager = false
        forgeSecondLook = false
        forgeMoveBonus = 0

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
        // v1.8 Unit 5b reworked-tree fields
        bleedingEnemyDamageTaken = 0.0
        bleedKillHeal = 0
        pressureDefBonus = 0
        pressureDefRadius = 90.0
        pressureDefEnemyCount = 3
        pressureDefActive = false
        thornsContactReflect = 0.0
        defAsDamageMult = 0.0
        voidPullForce = 0.0
        voidPullRadius = 0.0
        inWellSlow = 0.0
        knockbackForce = 0.0
        lethalSaves = 0
        collisionShrink = 1.0
        globalEnemySlow = 0.0
        chainTargets = 0
        chainDamageMultiplier = 0.5
        shockChainRadiusBonus = 0
        inductionStepActive = false
        inductionCharge = 0
        relayBurnActive = false
        overclockActive = false
        overclockTimer = 0
        voidZoneDurationMultiplier = 1.0
        groundedCoreActive = false
        groundedCoreBraced = false
        stationaryTime = 0
        killsExplode = false
        explosionRadius = 40.0
        explosionDamagePercent = 0.3
        killStreakFireRateBonus = 0.0
        killStreakThreshold = 3
        killStreakWindow = 3.0
        killHealAmount = 0
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
        stunChance = 0.0
        stunDuration = 0.5
        singularityActive = false
        singularityInterval = 8.0
        singularityRadius = 90.0
        singularityDuration = 3.0
        singularityDPS = 1.0

        // v1.6 Quench cards
        arcWakeDamage = 0
        arcWakeDropInterval = 0.25
        arcWakeLifetime = 1.0
        staticCrownDamage = 0
        staticCrownRadius = 90.0
        bloodPriceBonus = 0.0
        openVeinDamage = 0
        openVeinRadius = 40.0
        ironBloomActive = false
        aegisPulseActive = false
        aegisPulseInterval = 4.0
        aegisPulseRadius = 70.0
        aegisPulseTimer = 0.0
        nullBloomChance = 0.0
        nullBloomRadius = 35.0
        nullBloomSlow = 0.4
        nullBloomDuration = 1.5
        hoarfrostInterval = 0.0
        hoarfrostTimer = 0.0
        cauterizeActive = false
        cauterizeThreshold = 0.3
        cauterizeInterval = 3.0
        cauterizeTimer = 0.0
        whiteoutActive = false
        whiteoutRadius = 50.0
        whiteoutSlow = 0.3
        whiteoutDuration = 2.0

        // v1.8 Mirrorwound cards
        echoChance = 0.0
        echoDamageMultiplier = 0.5
        echoDelay = 0.15
        bleedVsSlowedMultiplier = 1.0
        bleedLowHpBonus = 1.0
        bleedLowHpThreshold = 0.5
        hasSilverSkin = false
        silverSkinArmed = false
        splitCount = 0
        splitDamageMultiplier = 0.5
        splitAngle = 0.22
        falseOpeningActive = false
        falseOpeningDelay = 0.3
        falseOpeningRadius = 72.0
        falseOpeningDamage = 12
        falseOpeningSlow = 0.3
        falseOpeningSlowDuration = 1.2
        falseOpeningCooldown = 1.1

        currentKillStreak = 0
        lastKillTime = 0
        bloodlustStacks = 0
        bloodlustLastKillTime = 0
        shotsFired = 0
        
        // v1.3 cards
        overchargeDamagePerSecond = 0
        overchargeMaxBonus = 0.5
        overchargeCurrentBonus = 0
        glassEngineActive = false
        phaseSkinCooldown = 0
        phaseSkinDuration = 1.0
        phaseSkinTimer = 0
        phaseSkinCooldownTimer = 0
        magneticCoreSpeedBoost = 0
        magneticCoreBoostDuration = 1.5
        magneticCoreBoostTimer = 0
        chainReactionExplode = false
        chainReactionRadius = 35.0
        chainReactionDamage = 1
        staticFieldRange = 0
        staticFieldSlow = 0.15
        executionProtocolThreshold = 0
        executionProtocolMultiplier = 2.0
        unstableCoreActive = false
        unstableCoreDamage = 2
        unstableCoreRadius = 60.0
        unstableCoreInterval = 4.0
        unstableCoreSelfDamage = 10
        unstableCoreTimer = 0
    }
}
