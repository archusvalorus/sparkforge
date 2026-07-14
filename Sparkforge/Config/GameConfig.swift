// GameConfig.swift
// Sparkforge
//
// Single source of truth for all game tuning values.
// Tweak here, not scattered across files.
//
// v1.4: Arena resize (device-aware), HP/ATK/DEF system,
// enemy damage values, health orbs, magnet orbs, boss config.

import CoreGraphics
import Foundation

enum GameConfig {
    
    // MARK: - Arena
    enum Arena {
        /// Radius of the circular arena in points — device-aware
        static var radius: CGFloat { DeviceScale.arenaRadius }
        /// Color of the arena floor
        static let floorColorHex: UInt32 = 0x1A1A1A
        /// Color of the arena boundary ring
        static let boundaryColorHex: UInt32 = 0x3A1A0A
        /// Boundary ring line width
        static let boundaryLineWidth: CGFloat = 3.0
        /// How much beyond the boundary the player is pushed back
        static let boundaryPushback: CGFloat = 2.0
    }
    
    // MARK: - Player
    enum Player {
        /// Player movement speed in points per second
        static let speed: CGFloat = 250
        /// Visual radius of the player spark
        static let visualRadius: CGFloat = 16
        /// Collision radius — smaller than visual for forgiving hitbox
        static let collisionRadius: CGFloat = 10
        /// Base glow intensity (scales with level)
        static let baseGlowWidth: CGFloat = 8
        /// Core color
        static let coreColorHex: UInt32 = 0xFFAA33
        /// Glow color
        static let glowColorHex: UInt32 = 0xFF6600
        
        // v1.4: HP System
        /// Starting max HP
        static let baseMaxHP: Int = 100
        /// Starting ATK (base projectile damage)
        static let baseAttack: Int = 10
        /// Starting DEF (flat damage reduction)
        static let baseDefense: Int = 0
        /// Invulnerability frames after taking damage (seconds)
        static let damageCooldown: TimeInterval = 0.5
    }
    
    // MARK: - Enemy
    enum Enemy {
        /// Base enemy speed — must be slower than player
        static let baseSpeed: CGFloat = 130
        /// Base enemy visual radius
        static let visualRadius: CGFloat = 14
        /// Base enemy collision radius
        static let collisionRadius: CGFloat = 12
        /// Base enemy health
        static let baseHealth: Int = 1
        /// Body color (darker for menacing look)
        static let bodyColorHex: UInt32 = 0x1A1A1A
        /// Rim glow color (subtle red)
        static let rimGlowColorHex: UInt32 = 0x661111
        
        // v1.4: Enemy damage to player
        /// Base melee contact damage
        static let baseMeleeDamage: Int = 25
        /// Additional melee damage per 30s elapsed
        static let meleeDamageScaling: Int = 5
        /// Base ranged projectile damage
        static let baseRangedDamage: Int = 15
        /// Additional ranged damage per 30s elapsed
        static let rangedDamageScaling: Int = 3
        /// Mini-boss contact damage
        static let baseMiniBossDamage: Int = 40
        /// Additional mini-boss damage per 30s elapsed
        static let miniBossDamageScaling: Int = 8
    }
    
    // MARK: - Projectile
    enum Projectile {
        /// Auto-attack fire rate (seconds between shots)
        static let fireInterval: TimeInterval = 0.5
        /// Projectile speed
        static let speed: CGFloat = 400
        /// Projectile radius
        static let radius: CGFloat = 4
        /// Projectile color
        static let colorHex: UInt32 = 0xFFCC44
        /// Max range before despawn (in points) — bumped for larger arena
        static let maxRange: CGFloat = 400
    }
    
    // MARK: - Joystick
    enum Joystick {
        /// Radius of the joystick base (touch zone)
        static let baseRadius: CGFloat = 60
        /// Radius of the joystick knob (thumb indicator)
        static let knobRadius: CGFloat = 25
        /// Dead zone — input below this normalized magnitude is ignored
        static let deadZone: CGFloat = 0.1
        /// Opacity of the joystick when active
        static let activeAlpha: CGFloat = 0.5
        /// Opacity when idle (hidden — appears on touch)
        static let idleAlpha: CGFloat = 0.0
        /// Base color
        static let baseColorHex: UInt32 = 0x444444
        /// Knob color
        static let knobColorHex: UInt32 = 0xAAAAAA
    }
    
    // MARK: - Wave / Pacing
    enum Wave {
        /// Time between enemy spawns at start (seconds)
        static let initialSpawnInterval: TimeInterval = 1.2
        /// Minimum spawn interval before late game kicks in
        /// v1.6 tuning: 0.4 → 0.55 — old floor arrived at ~66s, turning the
        /// 70–75s window into a wall of bodies (Brandon playtest 7/9/26)
        static let minimumSpawnInterval: TimeInterval = 0.55
        /// How fast spawn interval decreases per second of game time
        /// v1.6 tuning: 0.012 → 0.010 — gentler ramp into the floor
        static let spawnAcceleration: TimeInterval = 0.010
        /// Late game (90s+): faster acceleration
        static let lateGameAcceleration: TimeInterval = 0.02
        /// Late game minimum spawn interval (v1.6 tuning: 0.2 → 0.25)
        static let lateGameMinInterval: TimeInterval = 0.25
        /// v1.6 tuning: from this mark, some Crucible melee spawns are
        /// skipped to thin the crowd
        static let meleeThinningStart: TimeInterval = 30
        /// Chance a melee spawn is skipped after the thinning mark
        /// v1.8 (B1): 0.30 → 0.22 — Arena 1 played "stand still and machine
        /// gun"; thin fewer spawns for a slightly denser Crucible crowd
        static let meleeThinningChance: CGFloat = 0.22
        /// Mini-boss spawn time
        static let miniBossSpawnTime: TimeInterval = 90.0
        /// Spawn distance from arena center (just outside boundary)
        static let spawnDistance: CGFloat = Arena.radius + 40
    }

    // MARK: - Ashling splitter (v1.6; v1.8 B2 shard protection)
    enum Ashling {
        /// v1.8 (B2): beat between an Ashling parent's death and its shards
        /// gaining physics, so the parent's death-AoE (Open Vein / Whiteout
        /// bursts, splash) can't insta-kill the trio at spawn. The pause IS
        /// the protection — shards pop up vulnerable once visible. Tune 0.4–0.6.
        static let shardSpawnDelay: TimeInterval = 0.5
        /// Telegraph ring at the split point during the delay — reads as the
        /// parent bursting, then shards appear. Neon yellow = shard tell.
        static let splitTelegraphRadius: CGFloat = 20
        static let splitTelegraphColorHex: UInt32 = 0xE6FF33
    }

    // MARK: - Chain Lightning VFX (Shock)
    enum ChainLightning {
        /// v1.8: bigger, bolder, longer-lived arc between chained enemies
        /// (Brandon playtest 7/13 — was 1.5 / 3 / 0.8α / 0.15s: too faint & brief)
        static let colorHex: UInt32 = 0x44BBFF
        static let alpha: CGFloat = 0.95
        static let lineWidth: CGFloat = 3.0
        static let glowWidth: CGFloat = 7.0
        static let fadeDuration: TimeInterval = 0.30
    }

    // MARK: - XP & Leveling
    enum Leveling {
        /// XP required for level 2
        static let baseXPRequired: Int = 5
        /// XP scaling per level (multiplied by level)
        static let xpScalingFactor: Double = 1.3
        /// XP dropped by base enemy
        static let baseEnemyXP: Int = 1
        /// Number of upgrade choices presented
        static let upgradeChoiceCount: Int = 3
    }
    
    // MARK: - Physics Categories (bitmask)
    enum Physics {
        static let player:          UInt32 = 0x1 << 0  // 1
        static let enemy:           UInt32 = 0x1 << 1  // 2
        static let projectile:      UInt32 = 0x1 << 2  // 4
        static let boundary:        UInt32 = 0x1 << 3  // 8
        static let xpOrb:           UInt32 = 0x1 << 4  // 16
        static let enemyProjectile: UInt32 = 0x1 << 5  // 32
        static let healthOrb:       UInt32 = 0x1 << 6  // 64   — v1.4
        static let magnetOrb:       UInt32 = 0x1 << 7  // 128  — v1.4
        static let forgeCoin:       UInt32 = 0x1 << 8  // 256  — v1.8 (Unit 2)
        // Next free bit: 0x1 << 9 — update the Notion App Portfolio Registry
    }
    
    // MARK: - Ranged Enemy
    enum RangedEnemy {
        /// Distance at which ranged enemy stops and fires — bumped for larger arena
        static var engageRange: CGFloat { 250 * DeviceScale.gameplay }
        /// Seconds between shots
        static let fireInterval: TimeInterval = 2.0
        /// Projectile speed
        static let projectileSpeed: CGFloat = 180
        /// Projectile radius
        static var projectileRadius: CGFloat { 5 * DeviceScale.gameplay }
        /// Projectile max range
        static var projectileRange: CGFloat { 450 * DeviceScale.gameplay }
        /// Body color — distinct from melee enemies
        static let bodyColorHex: UInt32 = 0x1A0A1A
        /// Rim glow — purple tint
        static let rimGlowColorHex: UInt32 = 0x551166
        /// Eye color — purple
        static let eyeColorHex: UInt32 = 0xBB44FF
        /// Projectile color
        static let projectileColorHex: UInt32 = 0x9933CC
        /// First spawn time — ranged enemies appear after this many seconds
        /// v1.8 (B1): 45 → 40 — earlier purple pressure so Arena 1 can't be
        /// camped in one spot (Crucible-only path; Quench/Coilworks gate their
        /// own ranged spawns and are unaffected)
        static let firstSpawnTime: TimeInterval = 40
        /// Chance a spawn is ranged (vs melee) after firstSpawnTime
        /// v1.8 (B1): 0.25 → 0.30 — a touch more ranged to keep the player moving
        static let spawnChance: CGFloat = 0.30
    }
    
    // MARK: - Health Orb (v1.4)
    enum HealthOrb {
        /// Min time between spawns (seconds)
        static let minSpawnInterval: TimeInterval = 20
        /// Max time between spawns (seconds)
        static let maxSpawnInterval: TimeInterval = 30
        /// HP restored on pickup
        static let healAmount: Int = 20
        /// Visual radius — v1.8: 10 → 14 for legibility (bigger, easier to
        /// read). Pickup is pinned separately below, so a larger visual does
        /// NOT make the orb easier to grab.
        static let visualRadius: CGFloat = 14
        /// Interactible/pickup radius — decoupled from the visual so the art
        /// can grow without changing how easy the orb is to collect (was
        /// visualRadius + 20 = 30 when the visual was 10; pinned here).
        static let pickupRadius: CGFloat = 30
        /// Despawn timer (seconds)
        static let despawnTime: TimeInterval = 10
        /// Color
        static let colorHex: UInt32 = 0x44DD66
        /// Glow color
        static let glowColorHex: UInt32 = 0x22BB44
    }
    
    // MARK: - Coilworks Enemies (v1.7)
    enum CoilworksEnemies {
        // Relay Imp — danger arcs between nearby imps
        /// Max distance between two imps for an arc to form
        static let relayArcRange: CGFloat = 140
        /// Seconds the arc charges (faint, harmless tell)
        static let relayArcChargeTime: TimeInterval = 1.1
        /// Seconds the arc is live (bright, damaging)
        static let relayArcFireTime: TimeInterval = 0.45
        /// Damage on crossing a live arc
        static let relayArcDamage: Int = 8
        /// Distance from the arc line that counts as crossing
        static let relayArcHitDistance: CGFloat = 16

        // Grounder — plants itself, periodic danger pulses
        /// Distance from the player at which it roots
        static let grounderPlantRange: CGFloat = 170
        /// Seconds the expanding tell ring shows before the pulse fires
        static let grounderPulseTell: TimeInterval = 0.9
        /// Pulse damage radius
        static let grounderPulseRadius: CGFloat = 85
        /// Damage inside the pulse
        static let grounderPulseDamage: Int = 10
        /// Rest between pulses
        static let grounderPulseRest: TimeInterval = 2.2

        // Circuit Wasp — angular snap-orbiter
        /// Orbit distance from the player
        static let waspOrbitRadius: CGFloat = 120
        /// Seconds drifting toward the current angle slot
        static let waspDriftTime: TimeInterval = 0.7
        /// Seconds paused between moves (the metronome's rest)
        static let waspPauseTime: TimeInterval = 0.35
        /// Speed multiplier during the snap to the next slot
        static let waspSnapMultiplier: CGFloat = 4.5
    }

    // MARK: - Spark Visuals (v1.7)
    enum Spark {
        /// White-hot inner core color
        static let innerCoreColorHex: UInt32 = 0xFFF6E0
        /// Inner core radius as a fraction of the player's visualRadius
        static let innerCoreRadiusFactor: CGFloat = 0.55
        /// Ember trail: particles per second at full stick deflection
        static let trailMaxBirthRate: CGFloat = 40
        /// Ember trail: fleck lifetime (seconds)
        static let trailLifetime: CGFloat = 0.38
        /// Ember trail: fleck drift speed opposite movement (points/sec)
        static let trailSpeed: CGFloat = 26
        /// Level-up flare ring color
        static let flareRingColorHex: UInt32 = 0xFFCC66
        /// Outer glow level scaling cap (never implies a larger hitbox)
        static let maxGlowScale: CGFloat = 2.2
    }

    // MARK: - Analytics (v1.7)
    enum Analytics {
        /// Max runs kept in the on-disk ring buffer
        static let maxStoredRuns = 200
    }

    // MARK: - Magnet Orb (v1.4)
    enum MagnetOrb {
        /// Min time between spawns (seconds)
        static let minSpawnInterval: TimeInterval = 25
        /// Max time between spawns (seconds)
        static let maxSpawnInterval: TimeInterval = 35
        /// Visual radius — v1.8: 10 → 14 for legibility (see HealthOrb).
        static let visualRadius: CGFloat = 14
        /// Interactible/pickup radius — decoupled from the visual (was
        /// visualRadius + 20 = 30). Pinned so bigger art ≠ easier pickup.
        static let pickupRadius: CGFloat = 30
        /// Despawn timer (seconds)
        static let despawnTime: TimeInterval = 8
        /// Color
        static let colorHex: UInt32 = 0x44AAFF
        /// Glow color
        static let glowColorHex: UInt32 = 0x2288DD
    }

    // MARK: - Forge XP Coin (v1.8 Unit 2)
    enum ForgeCoin {
        /// FLAT forge XP per coin — intentionally NOT routed through
        /// pendingForgeXP (which the XP Boost ad doubles), so coins bank
        /// immediately and are never boosted (decided at kickoff).
        static let forgeXPValue: Int = 5
        /// Coins that erupt and scatter arena-wide on a boss's death (tune).
        static let scatterCount: Int = 12
        /// Seconds before an uncollected coin despawns.
        static let despawnTime: TimeInterval = 12
        /// Visual radius — a large disc (medallion), clearly bigger than the
        /// small XP pebbles.
        static let visualRadius: CGFloat = 15
        /// Pickup radius — NO magnet; a forgiving contact body so walking over
        /// the coin collects it. Walking to them is the point (health-orb canon).
        static let pickupRadius: CGFloat = 22
        /// Seconds for one xScale spin oscillation (narrow → wide).
        static let spinPeriod: TimeInterval = 1.1
        /// Ember burst radius shown at pickup.
        static let pickupBurstRadius: CGFloat = 16
        // Lyra palette (Ask 4a) — spark-stamped forge token:
        static let coreColorHex: UInt32 = 0xFFAA33
        static let rimColorHex: UInt32 = 0xFF6600
        static let stampColorHex: UInt32 = 0xFFD27A
        static let shadowColorHex: UInt32 = 0x7A2F00
    }
}
