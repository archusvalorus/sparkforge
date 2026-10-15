// AbilityBehaviors.swift
// Sparkforge
//
// v2.2 catalog migration (CL-113), Unit J1: the NATIVE half of the ability
// catalog. Definitions (ids, names, copy, trees, flags, gates, order) are
// authored in `Sparkforge/Catalog/ability-catalog.json`; what a card or a
// synergy tier DOES stays here, in Swift, with its numbers where they have
// always been (`GameConfig`, or written in the effect). `AbilityCatalog.load`
// joins the two by key and refuses a file whose keys or tier counts don't
// match this registry.
//
// Since J2 (the runtime cutover) this is the ONLY copy of the effects: the
// legacy `UpgradeManager.buildCardPool()` and its synergy switch are gone.
// The catalog harness proves every tier and synergy effect against the
// fixtures recorded from that legacy code (tools/v2.2-catalog/parity).
//
// Rules for this file:
//   • One entry per behaviour key. A card's entry lists its tiers in order,
//     tier 1 first; the count IS the card's native max tier.
//   • Tier closures are DELTAS (PlayerStats is additive: rungs add, never
//     re-set), exactly as in the v1.9 leveling engine.
//   • No new tuning literals. The numbers written in place below are the
//     existing ones (D3, Oct 4 2026): hoist each into `GameConfig` when its
//     card is next touched; never add another.

import CoreGraphics
import Foundation

/// A card's effects, tier 1 first.
struct CardBehavior {
    let tiers: [(PlayerStats) -> Void]
}

enum AbilityBehaviors {

    /// Everything the loader binds definitions to. A value type so the catalog
    /// harness can hand the loader an altered copy (a missing or extra key).
    struct Registry {
        /// Card behaviours, by the definition's `behavior` key.
        var cards: [String: CardBehavior] = [:]
        /// Synergy stat effects, by the definition's `behavior` key
        /// ("<tree key>.<threshold>").
        var synergies: [String: (PlayerStats) -> Void] = [:]
        /// Keys registered more than once (a programming error; the loader
        /// reports it and refuses to load).
        var duplicateKeys: [String] = []
        /// Card ids that native code names OUTSIDE the catalog, so a definition
        /// must exist for each: the scene's on-pick Growth structures and the
        /// build-identity hints. (The names themselves still live at their call
        /// sites until J2; the catalog harness checks this list against them.)
        var nativeCardIDs: [String] = []
        /// The card the secret scheduler offers. Its definition must be `secret`.
        var scheduledSecretCardID: String = ""
    }

    static let registry: Registry = build()

    private static func build() -> Registry {
        var registry = Registry()

        func add(_ key: String, _ tiers: [(PlayerStats) -> Void]) {
            if registry.cards[key] != nil { registry.duplicateKeys.append(key) }
            registry.cards[key] = CardBehavior(tiers: tiers)
        }
        func addSynergy(_ key: String, _ effect: @escaping (PlayerStats) -> Void) {
            if registry.synergies[key] != nil { registry.duplicateKeys.append(key) }
            registry.synergies[key] = effect
        }

        registry.scheduledSecretCardID = GameConfig.Panda.cardID
        registry.nativeCardIDs = [
            // GameScene: Growth structures raised on pick (both pick sites).
            "v20_wildbloom", "v20_vinewall", "v20_tree", "v20_richsoil",
            // UpgradeManager.checkBuildHint: the combo archetypes.
            "v13_overcharge", "v13_glass_engine", "v13_execution", "v13_phase_skin",
            "v16_hoarfrost", "v13_chain_reaction", "v13_magnetic_core", "v13_unstable_core",
        ]

        // Tier TOTALS read once, as in the legacy pool: the rungs add the difference.
        let gouge = GameConfig.Bleed.gougeCritTotals
        let siphon = GameConfig.Bleed.siphonHealTotals
        let siphonRungs: [(PlayerStats) -> Void] = (1..<siphon.count).map { i in
            { stats in stats.killHealAmount += siphon[i] - siphon[i - 1] }
        }
        let shove = GameConfig.Guard.repulseShove

        // ─── Cards, in catalog order ─────────────────────────────────────────

        // Kindle
        add("fire_1", [
            { stats in stats.burnDPS += 0.5 }
        ])

        // Forge Breath
        add("fire_2", [
            { stats in stats.fireDamageBonus += GameConfig.Fire.forgeBreathBonus[0] },
            { stats in stats.fireDamageBonus += GameConfig.Fire.forgeBreathBonus[1] - GameConfig.Fire.forgeBreathBonus[0] },
            { stats in stats.fireDamageBonus += GameConfig.Fire.forgeBreathBonus[2] - GameConfig.Fire.forgeBreathBonus[1] }
        ])

        // Ember Burst
        add("fire_3", [
            { stats in stats.killsExplode = true }
        ])

        // Crucible
        add("fire_4", [
            { stats in stats.burnStackCap = GameConfig.Fire.crucibleStackCap }
        ])

        // Static
        add("shock_1", [
            { stats in stats.fireRateMultiplier /= (1 + GameConfig.Shock.staticFireRate[0]) },
            { stats in stats.fireRateMultiplier *= (1 + GameConfig.Shock.staticFireRate[0]) / (1 + GameConfig.Shock.staticFireRate[1]) },
            { stats in stats.fireRateMultiplier *= (1 + GameConfig.Shock.staticFireRate[1]) / (1 + GameConfig.Shock.staticFireRate[2]) }
        ])

        // Chain Lightning
        add("shock_2", [
            { stats in stats.chainTargets += 1; stats.chainLightningTier = 1 },
            { stats in stats.chainTargets += 1; stats.chainLightningTier = 2 },
            { stats in stats.chainTargets += 1; stats.chainLightningTier = 3 },
            { stats in stats.chainTargets += 1; stats.chainLightningTier = 4 }
        ])

        // Surge
        add("shock_3", [
            { stats in
                stats.moveSpeedMultiplier += GameConfig.Shock.surgeMoveBonus
                stats.projectileSpeedMultiplier += GameConfig.Shock.surgeProjectileSpeed
                stats.fireRateMultiplier /= (1 + GameConfig.Shock.surgeFireRate)
            }
        ])

        // Overload
        add("shock_4", [
            { stats in stats.overloadOwned = true }
        ])

        // Lightning Sentry
        add("v21_lightning_sentry", [
            { stats in stats.lightningSentryTier = 1 },
            { stats in stats.lightningSentryTier = 2 },
            { stats in stats.lightningSentryTier = 3 },
            { stats in stats.lightningSentryTier = 4 }
        ])

        // Electro Pulse
        add("v21_electro_pulse", [
            { stats in stats.electroPulseActive = true }
        ])

        // Bloodthirsty
        add("v21_bloodthirsty", [
            { stats in stats.bleedApplyChance = GameConfig.Bleed.applyChance }
        ])

        // Gouge
        add("bleed_1", [
            { stats in stats.critChance += gouge[0] },
            { stats in stats.critChance += gouge[1] - gouge[0] }
        ])

        // Hemorrhage
        add("bleed_2", [
            { stats in stats.critMultiplier += GameConfig.Bleed.hemorrhageCritBonus }
        ])

        // Frenzy
        add("bleed_3", [
            { stats in stats.frenzyOwned = true }
        ])

        // Berserk
        add("v21_berserk", [
            { stats in stats.berserkOwned = true }
        ])

        // Siphon
        add("bleed_4", [
            { stats in stats.killHealAmount += siphon[0] }
        ] + siphonRungs)

        // Sanguinarian
        add("v21_sanguinarian", [
            { stats in stats.sanguinarianOwned = true }
        ])

        // Brace
        add("guard_1", [
            { stats in stats.lethalSaves = max(stats.lethalSaves, 1) }
        ])

        // Repulse
        add("guard_2", [
            { stats in
                stats.repulseTier = 1
                stats.knockbackForce += shove[0]
            },
            { stats in
                stats.repulseTier = 2
                stats.knockbackForce += shove[1] - shove[0]
            },
            { stats in stats.repulseTier = 3 }
        ])

        // Harden
        add("guard_3", [
            { stats in
                stats.collisionShrink *= GameConfig.Guard.hardenShrink
                stats.hardenOwned = true
            }
        ])

        // Fortify
        add("guard_4", [
            { stats in stats.fortifyOwned = true }
        ])

        // Warp Shot
        add("void_1", [
            { stats in stats.warpShotActive = true }
        ])

        // Gravity Well
        add("void_2", [
            { stats in stats.gravityWellOnExpire = true }
        ])

        // Phase
        add("void_3", [
            { stats in stats.phaseTier = 1 },
            { stats in stats.phaseTier = 2 },
            { stats in stats.phaseTier = 3 }
        ])

        // Devour
        add("void_4", [
            { stats in stats.devourActive = true }
        ])

        // Void Horror
        add("v21_void_horror", [
            { stats in stats.voidHorrorActive = true }
        ])

        // Shadow Edge
        add("v21_shadow_edge", [
            { stats in stats.shadowEdgeActive = true }
        ])

        // Frost Touch
        add("chill_1", [
            { stats in stats.slowAmount += GameConfig.Chill.frostTouchSlow[0] },
            { stats in stats.slowAmount += GameConfig.Chill.frostTouchSlow[1] - GameConfig.Chill.frostTouchSlow[0] },
            { stats in stats.frostTouchShards = true }
        ])

        // Ice Shard
        add("chill_2", [
            { stats in stats.projectileSpeedMultiplier += GameConfig.Chill.iceShardSpeedBonus }
        ])

        // Permafrost
        add("chill_3", [
            { stats in stats.slowedDamageBonus += GameConfig.Chill.permafrostBonus }
        ])

        // Glacial Drift
        add("chill_4", [
            { stats in stats.chillTrail = true; stats.glacialDriftTier = 1 },
            { stats in stats.glacialDriftTier = 2 },
            { stats in stats.glacialDriftTier = 3 },
            { stats in stats.glacialDriftTier = 4 },
            { stats in
                stats.glacialDriftTier = 5
                stats.globalEnemySlow += GameConfig.Chill.iceRinkEnemySlow
                stats.moveSpeedMultiplier += GameConfig.Chill.iceRinkMoveBonus
            }
        ])

        // Glacial Spikes
        add("v21_glacial_spikes", [
            { stats in stats.glacialSpikesActive = true }
        ])

        // Swift — v2.2 N1: a 3-tier ladder of TOTALS (GameConfig.Neutral); the
        // rungs add the difference, so Forge Path's and the Tree's additions stay.
        let swift = GameConfig.Neutral.swiftMoveTotals
        add("neutral_1", [
            { stats in stats.moveSpeedMultiplier += swift[0] },
            { stats in stats.moveSpeedMultiplier += swift[1] - swift[0] },
            { stats in stats.moveSpeedMultiplier += swift[2] - swift[1] }
        ])

        // Keen Eye (`neutral_2`) — RETIRED in v2.2 N1, merged into Magnetic Core.
        // The id is in the catalog's `retired` list and is never reused.

        // Rapid Fire — v2.2 N4: attack-speed TOTALS +10 / +25 / +50 / +90 %
        // (GameConfig.Neutral) as rate ratios in fireRateMultiplier (the Static
        // convention), so every other attack-speed source composes; T5 keeps the
        // +90 % and turns the auto-attack into the chaos beam (R2/R4).
        let rapidFire = GameConfig.Neutral.rapidFireSpeedTotals
        add("neutral_3", [
            { stats in stats.fireRateMultiplier /= (1 + rapidFire[0]); stats.rapidFireTier = 1 },
            { stats in stats.fireRateMultiplier *= (1 + rapidFire[0]) / (1 + rapidFire[1]); stats.rapidFireTier = 2 },
            { stats in stats.fireRateMultiplier *= (1 + rapidFire[1]) / (1 + rapidFire[2]); stats.rapidFireTier = 3 },
            { stats in stats.fireRateMultiplier *= (1 + rapidFire[2]) / (1 + rapidFire[3]); stats.rapidFireTier = 4 },
            { stats in stats.rapidFireTier = GameConfig.Neutral.chaosBeamTier }
        ])

        // Long Shot
        // Long Shot — v2.2 N3: range TOTALS 25 / 50 / 50 / 50% (the rungs add
        // the difference, so Riftline's +25% and any other contributor stay);
        // T3 removes the distance limit; T4 adds pierce-all + terrain passage
        // (both read from `longShotTier`).
        let longShot = GameConfig.Neutral.longShotRangeTotals
        add("neutral_4", [
            { stats in stats.projectileRangeMultiplier += longShot[0]; stats.longShotTier = 1 },
            { stats in stats.projectileRangeMultiplier += longShot[1] - longShot[0]; stats.longShotTier = 2 },
            { stats in stats.projectileRangeMultiplier += longShot[2] - longShot[1]; stats.longShotTier = 3 },
            { stats in stats.projectileRangeMultiplier += longShot[3] - longShot[2]; stats.longShotTier = 4 }
        ])

        // XP Boost
        // XP Boost — v2.2 N2: TOTALS 25 / 50 / 50% (GameConfig.Neutral); the
        // rungs add the difference so external XP bonuses survive. T3 raises
        // the run's level cap and owes ONE full level-up, which the scene's
        // level queue pays through the normal card/stat flow (R5).
        let xpBoost = GameConfig.Neutral.xpBoostTotals
        add("neutral_5", [
            { stats in stats.xpMultiplier += xpBoost[0] },
            { stats in stats.xpMultiplier += xpBoost[1] - xpBoost[0] },
            { stats in
                stats.xpMultiplier += xpBoost[2] - xpBoost[1]
                stats.runLevelCap = max(stats.runLevelCap, GameConfig.Neutral.xpBoostLevelCap)
                stats.grantedLevelsPending += GameConfig.Neutral.xpBoostGrantedLevels
            }
        ])

        // Scatter
        // Scatter — v2.2 N3: TOTAL lanes 2 / 3 / 5 / 9 (AttackPattern lays them
        // out from `scatterTier`); `extraProjectiles` = lanes − 1 feeds Storm
        // Engine's volley count exactly as before (CL-98).
        let scatterLanes = GameConfig.Neutral.scatterLaneCounts
        add("neutral_6", [
            { stats in stats.extraProjectiles += scatterLanes[1] - scatterLanes[0]; stats.scatterTier = 1 },
            { stats in stats.extraProjectiles += scatterLanes[2] - scatterLanes[1]; stats.scatterTier = 2 },
            { stats in stats.extraProjectiles += scatterLanes[3] - scatterLanes[2]; stats.scatterTier = 3 },
            { stats in stats.extraProjectiles += scatterLanes[4] - scatterLanes[3]; stats.scatterTier = 4 }
        ])

        // Overcharge
        add("v13_overcharge", [
            { stats in
                stats.overchargeDamagePerSecond = 0.05  // +5% per second, caps at +50%
            }
        ])

        // Magnetic Core — v2.2 N1: a 3-tier ladder of TOTALS (GameConfig.Neutral).
        // The radius bonus adds its rung (Forge Path's pickup nodes stay); the
        // burst STRENGTH is set to the tier's total (nothing else writes it), so
        // tiers never stack it; the burst's duration lives in PlayerStats.
        let magnetRadius = GameConfig.Neutral.magneticRadiusTotals
        let magnetBurst = GameConfig.Neutral.magneticBurstTotals
        add("v13_magnetic_core", [
            { stats in
                stats.pickupRadiusMultiplier += magnetRadius[0]
                stats.magneticCoreSpeedBoost = magnetBurst[0]
            },
            { stats in
                stats.pickupRadiusMultiplier += magnetRadius[1] - magnetRadius[0]
                stats.magneticCoreSpeedBoost = magnetBurst[1]
            },
            { stats in
                stats.pickupRadiusMultiplier += magnetRadius[2] - magnetRadius[1]
                stats.magneticCoreSpeedBoost = magnetBurst[2]
            }
        ])

        // Chain Reaction — v2.2 N5 (R6): three tiers. Each rung SETS the owned
        // tier's flat base and radius (GameConfig.Neutral); T3 also turns on the
        // per-generation escalation (ChainReaction.generationBonus).
        let chainBases = GameConfig.Neutral.chainReactionBases
        let chainRadii = GameConfig.Neutral.chainReactionRadii
        add("v13_chain_reaction", [
            { stats in
                stats.chainReactionExplode = true
                stats.chainReactionTier = 1
                stats.chainReactionDamage = chainBases[0]
                stats.chainReactionRadius = chainRadii[0]
            },
            { stats in stats.chainReactionTier = 2; stats.chainReactionDamage = chainBases[1]; stats.chainReactionRadius = chainRadii[1] },
            { stats in stats.chainReactionTier = 3; stats.chainReactionDamage = chainBases[2]; stats.chainReactionRadius = chainRadii[2] }
        ])

        // Glass Engine
        add("v13_glass_engine", [
            { stats in
                // v2.1 A1: a REAL +100% firing rate (the interval halves). The
                // old "+40%" line was ×0.60 on the interval — really +66.7%.
                stats.fireRateMultiplier /= (1.0 + GameConfig.Fire.glassEngineFireRateBonus)
                let hpLoss = Int(CGFloat(stats.maxHP) * GameConfig.Fire.glassEngineMaxHPLoss)
                stats.maxHP -= hpLoss
                stats.currentHP = min(stats.currentHP, stats.maxHP)
            }
        ])

        // Phase Skin
        add("v13_phase_skin", [
            { stats in
                stats.phaseSkinCooldown = GameConfig.Guard.phaseSkinCooldown
                stats.phaseSkinDuration = GameConfig.Guard.phaseSkinDuration
            }
        ])

        // Execution Protocol
        add("v13_execution", [
            { stats in stats.executionProtocolThreshold = 0.30 }
        ])

        // Unstable Core
        add("v13_unstable_core", [
            { stats in stats.unstableCoreActive = true }
        ])

        // Static Crown
        add("v16_static_crown", [
            { stats in stats.staticCrownActive = true }
        ])

        // Open Vein
        add("v16_open_vein", [
            { stats in stats.openVeinDamage = 2 }
        ])

        // Iron Bloom
        add("v16_iron_bloom", [
            { stats in stats.ironBloomActive = true }
        ])

        // Aegis
        add("v16_aegis_pulse", [
            { stats in stats.aegisTier = 1 },
            { stats in stats.aegisTier = 2 },
            { stats in stats.aegisTier = 3 }
        ])

        // Terra
        add("v20_terra", [
            { stats in stats.terraZoneRadius = GameConfig.Growth.terraRadius }
        ])

        // Thornsoil
        add("v20_thornsoil", [
            { stats in stats.thornsoilDPS = max(stats.thornsoilDPS, 6) }
        ])

        // Rich Soil
        add("v20_richsoil", [
            { stats in stats.growthRegenBonusHP += 2 }
        ])

        // Deeproot
        add("v20_deeproot", [
            { stats in stats.deeprootDEF += 6 }
        ])

        // Tree
        add("v20_tree", [
            { stats in stats.treeTier = 1 },
            { stats in stats.treeTier = 2 },
            { stats in stats.treeTier = 3 },
            { stats in stats.treeTier = 4 },
            { stats in stats.treeTier = 5 }
        ])

        // Pandas.
        add(GameConfig.Panda.cardID, [
            { stats in stats.pandaTier = 1 },
            { stats in stats.pandaTier = 2 },
            { stats in stats.pandaTier = 3 },
            { stats in stats.pandaTier = 4 },
            { stats in stats.pandaTier = 5 }
        ])

        // Vine Wall
        add("v20_vinewall", [
            { stats in stats.vineWallTier = 1 },
            { stats in stats.vineWallTier = 2 },
            { stats in stats.vineWallTier = 3 }
        ])

        // Seed Spore Shot
        add("v20_seed_spore", [
            { stats in stats.seedFragments = GameConfig.Growth.seedFragmentsT1 },
            { stats in stats.seedFragments = GameConfig.Growth.seedFragmentsT2 },
            { stats in
                stats.seedFragments = GameConfig.Growth.seedFragmentsT3
                stats.seedReembed = true          // T3: spores re-embed, once
            }
        ])

        // Wildbloom
        add("v20_wildbloom", [
            { _ in },
            { _ in },
            { _ in }
        ])

        // Null Bloom
        add("v16_null_bloom", [
            { stats in stats.nullBloomChance = GameConfig.VoidTree.nullBloomChance }
        ])

        // Hoarfrost
        add("v16_hoarfrost", [
            { stats in stats.hoarfrostInterval = GameConfig.Chill.hoarfrostInterval }
        ])

        // Whiteout
        add("v16_whiteout", [
            { stats in stats.whiteoutTier = 1 },
            { stats in stats.whiteoutTier = 2 },
            { stats in stats.whiteoutTier = 3 }
        ])

        // Cauterize
        add("v16_cauterize", [
            { stats in stats.cauterizeActive = true }
        ])

        // Relay Burn
        add("v17_relay_burn", [
            { stats in stats.relayBurnActive = true }
        ])

        // Overclock
        add("v17_overclock", [
            { stats in
                stats.overclockActive = true
            }
        ])

        // Dead Circuit
        add("v17_dead_circuit", [
            { stats in stats.deadCircuitActive = true }
        ])

        // Grounded Core
        add("v17_grounded_core", [
            { stats in stats.groundedCoreActive = true }
        ])

        // Bloodlust
        add("v18_bloodlust", [
            { stats in stats.bloodlustOwned = true }
        ])

        // Riftline
        add("v18_riftline", [
            { stats in
                stats.riftlineActive = true
                stats.pierceCount += GameConfig.VoidTree.riftlinePierce
                stats.projectileRangeMultiplier += GameConfig.VoidTree.riftlineRange
            }
        ])

        // Mirror Edge
        add("v18_mirror_edge", [
            { stats in stats.echoChance = 0.35 }
        ])

        // Glass Blood
        add("v18_glass_blood", [
            { stats in stats.glassBloodActive = true }
        ])

        // Silver Skin
        add("v18_silver_skin", [
            { stats in stats.hasSilverSkin = true }
        ])

        // Fracture Shot
        // Fracture Shot — v2.2 N3: 3 / 5 / 9 / 17 branches per shot over
        // 30 / 60 / 120 / 180° (AttackPattern); each parent's damage is divided
        // among ALL its branches.
        add("v18_fracture_shot", [
            { stats in stats.fractureTier = 1 },
            { stats in stats.fractureTier = 2 },
            { stats in stats.fractureTier = 3 },
            { stats in stats.fractureTier = 4 }
        ])

        // Red Smile
        add("v18_red_smile", [
            { stats in stats.redSmileOwned = true }
        ])

        // False Opening
        add("v18_false_opening", [
            { stats in stats.falseOpeningActive = true }
        ])

        // Everglow
        add("cap_fire_everglow", [
            { stats in                       // T1 Inner Heat
                stats.everglowTier = 1
                stats.everglowBasePulseMult = GameConfig.Everglow.basePulseMult
                stats.everglowPulseRadius = GameConfig.Everglow.baseRadius
            },
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
        ])

        // Iron Maiden
        add("cap_guard_ironmaiden", [
            { stats in                       // T1 Iron Skin
                stats.ironMaidenTier = 1
                stats.ironSkinDefToDmg = GameConfig.IronMaiden.defToDmgT1
                stats.defense += max(1, Int(CGFloat(stats.defense) * GameConfig.IronMaiden.defBonusT1))
                stats.ironThorns = GameConfig.IronMaiden.thornsT1
            },
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
        ])

        // Skybeam
        add("cap_shock_skybeam", [
            { stats in                       // T1 Lightning Lasso
                stats.skybeamTier = 1
                stats.skybeamTickMult = GameConfig.Skybeam.tickMultT1
                stats.skybeamAcquireRange = GameConfig.Skybeam.acquireRangeT1
            },
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
        ])

        // Apex
        add("cap_bleed_apex", [
            { stats in                       // T1 Blood Familiar
                stats.apexTier = 1
                stats.apexFamiliarActive = true
            },
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
        ])

        // Erasure
        add("cap_void_erasure", [
            { stats in                       // T1 Unstable
                stats.erasureTier = 1
                stats.erasureActive = true
                stats.erasureTriggerCD = GameConfig.Erasure.unstableTriggerCooldown
            },
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
        ])

        // Polar Vortex
        add("cap_chill_polarvortex", [
            { stats in                       // T1 Iceburst
                stats.polarVortexTier = 1
                stats.iceburstActive = true
                stats.iceburstShards = GameConfig.PolarVortex.iceburstShardsT1
            },
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
        ])

        // ─── Synergy tiers ───────────────────────────────────────────────────
        // Stat effects only. The once-per-run bookkeeping, the Codex discovery
        // write and the player-facing line stay in `UpgradeManager`.

        addSynergy("fire.3") { stats in
            stats.burnSpreads = true
        }
        addSynergy("fire.5") { stats in
            stats.burnDPS *= 2.0
            stats.burnDuration = 4.0
            stats.burnSpreadRadius *= 1.25   // v1.8 5b: Wildfire Heart
        }
        addSynergy("fire.7") { stats in
            stats.passiveArenaDPS += 0.5
        }
        addSynergy("shock.3") { stats in
            stats.chainTargets += 1  // Now chains to 2
        }
        addSynergy("shock.5") { stats in
            stats.teslaFieldDPS = 0.3
        }
        addSynergy("shock.7") { stats in
            stats.spreadShotInterval = 3
        }
        addSynergy("bleed.3") { stats in
            stats.bleedingEnemyDamageTaken = GameConfig.Bleed.openWoundsBonus   // Open Wounds (CL-25)
        }
        addSynergy("bleed.5") { stats in
            stats.executionThreshold = GameConfig.Bleed.exsanguinateThreshold  // Exsanguinate (CL-26)
        }
        addSynergy("bleed.7") { stats in
            stats.bleedKillHeal = 1                  // Red Harvest (start 1; test 2)
        }
        addSynergy("guard.3") { stats in
            stats.ironhideActive = true             // Ironhide: 9%/nearby hostile, ≤90% (CL-52)
        }
        addSynergy("guard.5") { stats in
            stats.thornsContactReflect = GameConfig.Guard.thornwallReflect  // Thornwall 1.50 (CL-53)
        }
        addSynergy("guard.7") { stats in
            // Unbroken Core (CL-54/57): arm the second rescue + equip the
            // projectile shield. The old DEF→damage conversion is retired; the
            // collision shrink stays.
            stats.unbrokenRescueAvailable = true
            stats.projectileShield.grant()
            stats.collisionShrink *= 0.85
        }
        addSynergy("void.3") { stats in
            stats.voidBlackhole = true              // Blackhole
        }
        addSynergy("void.5") { stats in
            stats.voidListlessness = true           // Listlessness
        }
        addSynergy("void.7") { stats in
            stats.voidSingularity = true            // Singularity
        }
        addSynergy("chill.3") { stats in
            stats.slowPotencyMultiplier = 2.0
        }
        addSynergy("chill.5") { stats in
            stats.shatterChance = GameConfig.Chill.shatterChance
        }
        addSynergy("chill.7") { stats in
            stats.globalEnemySlow += 0.25
            stats.shatterSlowThreshold = GameConfig.Chill.absoluteZeroShatterThreshold
        }
        addSynergy("growth.3") { stats in
            stats.terraSlow += 0.15                  // Rootbound
        }
        addSynergy("growth.5") { stats in
            stats.growthRegenBonusHP += 2            // Verdant Rise
        }
        addSynergy("growth.7") { stats in
            stats.thornsoilDPS = max(stats.thornsoilDPS, 8)  // Wildwood: the ground bites
        }

        return registry
    }
}
