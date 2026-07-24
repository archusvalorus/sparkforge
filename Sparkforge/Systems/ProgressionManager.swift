// ProgressionManager.swift
// Sparkforge
//
// v1.4: Persistent progression across runs.
// - Granular kill tracking (melee, ranged, boss)
// - Arena unlock gates (kill thresholds, boss kills, survival time)
// - Forge Level meta-progression (lifetime XP → permanent bonuses)
// - Replaces simple HighScoreManager.totalKills for typed tracking
//
// Still uses HighScoreManager for best time/level/run count (those stay).

import Foundation

final class ProgressionManager {
    
    static let shared = ProgressionManager()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    
    private enum Keys {
        static let meleeKills = "sf_melee_kills"
        static let rangedKills = "sf_ranged_kills"
        static let bossKills = "sf_boss_kills"
        static let quenchKills = "sf_quench_kills"    // v1.6: kills made in Arena 2
        static let wardenKills = "sf_warden_kills"    // v1.6: Quench Warden kills
        static let coilworksKills = "sf_coilworks_kills"  // v1.7: kills made in Arena 3
        static let choirKills = "sf_choir_kills"          // v1.7: Dynamo Choir kills (arena 4 gate feed)
        static let mirrorwoundKills = "sf_mirrorwound_kills"  // v1.8: kills made in Arena 4 (feeds the Faceted Lie gate)
        static let longestSurvival = "sf_longest_survival"
        static let survived2Min = "sf_survived_2min"
        static let forgeXP = "sf_forge_xp"
        static let forgeLevel = "sf_forge_level"
        static let currentArena = "sf_current_arena"
        static let arenasUnlocked = "sf_arenas_unlocked"
        /// v2.0 Boss Mode: ids of bosses the player has actually FELLED.
        static let defeatedBosses = "sf_defeated_bosses"
    }
    
    // MARK: - v2.0: Boss defeats (Boss Mode roster gate)

    /// Ids of bosses the player has felled at least once. Boss Mode only offers
    /// what you've actually beaten — re-fighting is a victory lap, not a preview.
    private(set) var defeatedBosses: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.defeatedBosses) ?? []) }
        set { defaults.set(Array(newValue), forKey: Keys.defeatedBosses) }
    }

    func recordBossDefeat(_ id: String) {
        var set = defeatedBosses
        guard !set.contains(id) else { return }
        set.insert(id)
        defeatedBosses = set
    }

    /// True if the boss has been felled. Falls back to the legacy per-boss
    /// unlock flags so players who beat these BEFORE v2.0 keep their access
    /// instead of having to re-earn the whole roster.
    func hasDefeatedBoss(_ id: String) -> Bool {
        if defeatedBosses.contains(id) { return true }
        switch id {
        case "slag_titan":    return arena1BossUnlocked
        case "quench_warden": return quenchWardenUnlocked
        case "dynamo_choir":  return dynamoChoirUnlocked
        case "faceted_lie":   return facetedLieUnlocked
        default:              return false
        }
    }

    // MARK: - Kill Stats
    
    var meleeKills: Int {
        get { defaults.integer(forKey: Keys.meleeKills) }
        set { defaults.set(newValue, forKey: Keys.meleeKills) }
    }
    
    var rangedKills: Int {
        get { defaults.integer(forKey: Keys.rangedKills) }
        set { defaults.set(newValue, forKey: Keys.rangedKills) }
    }
    
    var bossKills: Int {
        get { defaults.integer(forKey: Keys.bossKills) }
        set { defaults.set(newValue, forKey: Keys.bossKills) }
    }
    
    var totalKills: Int { meleeKills + rangedKills + bossKills }

    /// v1.6: kills made while fighting in The Quench (feeds the Warden gate)
    var quenchKills: Int {
        get { defaults.integer(forKey: Keys.quenchKills) }
        set { defaults.set(newValue, forKey: Keys.quenchKills) }
    }

    /// v1.6: Quench Warden kills (Arena 3's gate will feed on these)
    var wardenKills: Int {
        get { defaults.integer(forKey: Keys.wardenKills) }
        set { defaults.set(newValue, forKey: Keys.wardenKills) }
    }

    /// v1.7: kills made while fighting in The Coilworks (feeds the Choir gate)
    var coilworksKills: Int {
        get { defaults.integer(forKey: Keys.coilworksKills) }
        set { defaults.set(newValue, forKey: Keys.coilworksKills) }
    }

    /// v1.7: Dynamo Choir kills (banked — Arena 4's gate will feed on these)
    var choirKills: Int {
        get { defaults.integer(forKey: Keys.choirKills) }
        set { defaults.set(newValue, forKey: Keys.choirKills) }
    }

    /// v1.8: kills made while fighting in The Mirrorwound (feeds the Faceted Lie gate)
    var mirrorwoundKills: Int {
        get { defaults.integer(forKey: Keys.mirrorwoundKills) }
        set { defaults.set(newValue, forKey: Keys.mirrorwoundKills) }
    }
    
    // MARK: - Survival
    
    var longestSurvival: TimeInterval {
        get { defaults.double(forKey: Keys.longestSurvival) }
        set { defaults.set(newValue, forKey: Keys.longestSurvival) }
    }
    
    var hasSurvived2Minutes: Bool {
        get { defaults.bool(forKey: Keys.survived2Min) }
        set { defaults.set(newValue, forKey: Keys.survived2Min) }
    }
    
    // MARK: - Forge Level (Meta Progression)
    
    var forgeXP: Int {
        get { defaults.integer(forKey: Keys.forgeXP) }
        set { defaults.set(newValue, forKey: Keys.forgeXP) }
    }
    
    var forgeLevel: Int {
        get { defaults.integer(forKey: Keys.forgeLevel) }
        set { defaults.set(newValue, forKey: Keys.forgeLevel) }
    }
    
    /// XP needed for next forge level. Starts at 100, scales 1.35× per level.
    /// v1.9 Unit 6: 1.5 → 1.35 — a gentler high-level curve so a high-volume
    /// player's Forge Level tracks their play (Forge Level stays uncapped).
    func xpForLevel(_ level: Int) -> Int {
        return Int(100.0 * pow(1.35, Double(level)))
    }
    
    /// XP progress toward next level as 0.0–1.0
    var forgeLevelProgress: CGFloat {
        let needed = xpForLevel(forgeLevel)
        guard needed > 0 else { return 0 }
        return CGFloat(forgeXP) / CGFloat(needed)
    }
    
    /// Add forge XP from a completed run. Returns true if leveled up.
    /// v1.9 Unit 6: `if` → `while` — a run now grants ALL the levels its XP
    /// earned, not just one (latent correctness bug; it self-corrected on the
    /// next run before, but was wrong). xpForLevel is always > 0, so the loop
    /// terminates.
    @discardableResult
    func addForgeXP(_ amount: Int) -> Bool {
        forgeXP += amount
        var leveled = false
        var needed = xpForLevel(forgeLevel)
        while forgeXP >= needed {
            forgeXP -= needed
            forgeLevel += 1
            leveled = true
            needed = xpForLevel(forgeLevel)
        }
        return leveled
    }
    
    /// Apply forge bonuses to PlayerStats at run start.
    /// v1.7 Forge Paths: flat per-level bonuses are gone — power now
    /// comes from the player's chosen path nodes (same budget, spent
    /// deliberately). Picks are a pure function of forge level, so
    /// existing players' history arrived banked and spendable.
    func applyForgeBonuses(to stats: PlayerStats) {
        ForgePathManager.shared.applyPathBonuses(to: stats)
    }
    
    // MARK: - Arena Unlocks
    
    /// Number of arenas unlocked (minimum 1 = Arena 1 always available)
    var arenasUnlocked: Int {
        get { max(1, defaults.integer(forKey: Keys.arenasUnlocked)) }
        set { defaults.set(newValue, forKey: Keys.arenasUnlocked) }
    }
    
    /// Currently selected arena (0-indexed)
    var currentArena: Int {
        get { defaults.integer(forKey: Keys.currentArena) }
        set { defaults.set(newValue, forKey: Keys.currentArena) }
    }
    
    // MARK: - Arena 1 Gate
    
    struct ArenaGate {
        let totalKillsRequired: Int
        let bossKillsRequired: Int
        let survivalRequired: Bool  // Must have survived 2 minutes at least once
        let arenaName: String
        let bossName: String
    }
    
    /// Arena 1 unlock requirements for the boss encounter
    /// v1.6: bossKillsRequired dropped to 0 — the old value of 3 was a deadlock
    /// (boss kills could only come from the boss this gate was locking).
    /// Kills tuned 500 → 100 (500 was a placeholder from before Arena 2
    /// existed; the Titan is now a door, not an endpoint). Survival
    /// requirement dropped — reaching the 90s boss spawn is its own test.
    static let arena1Gate = ArenaGate(
        totalKillsRequired: 100,
        bossKillsRequired: 0,
        survivalRequired: false,
        arenaName: "The Crucible",
        bossName: "The Slag Titan"
    )

    /// Check if the player meets all requirements to face the Arena 1 boss
    var arena1BossUnlocked: Bool {
        let gate = ProgressionManager.arena1Gate
        return totalKills >= gate.totalKillsRequired
            && bossKills >= gate.bossKillsRequired
            && (!gate.survivalRequired || hasSurvived2Minutes)
    }

    // MARK: - v1.6: Arena 2 Gate (The Quench Warden)

    /// The Warden's gate is fed by kills made INSIDE The Quench —
    /// the boss-kill concept lives in arena access itself (you can't
    /// stand here without having felled the Slag Titan).
    static let arena2Gate = ArenaGate(
        totalKillsRequired: 100,
        bossKillsRequired: 0,
        survivalRequired: false,
        arenaName: "The Quench",
        bossName: "The Quench Warden"
    )

    /// Check if the Quench Warden will answer the 90s bell
    var quenchWardenUnlocked: Bool {
        return quenchKills >= ProgressionManager.arena2Gate.totalKillsRequired
    }

    // MARK: - v1.7: Arena 3 Gate (The Dynamo Choir)

    /// Arena access itself proves the Warden fell (arenasUnlocked = 3 on
    /// warden kill); the Choir answers once the Coilworks has fed enough.
    static let arena3Gate = ArenaGate(
        totalKillsRequired: 100,
        bossKillsRequired: 0,
        survivalRequired: false,
        arenaName: "The Coilworks",
        bossName: "The Dynamo Choir"
    )

    /// Check if the Dynamo Choir will answer the 90s bell
    var dynamoChoirUnlocked: Bool {
        return coilworksKills >= ProgressionManager.arena3Gate.totalKillsRequired
    }

    // MARK: - v1.8: Arena 4 Gate (The Faceted Lie)

    /// Arena access itself proves the Choir fell (arenasUnlocked = 4 on choir
    /// kill); the Faceted Lie answers once the Mirrorwound has fed enough.
    static let arena4Gate = ArenaGate(
        totalKillsRequired: 100,
        bossKillsRequired: 0,
        survivalRequired: false,
        arenaName: "The Mirrorwound",
        bossName: "The Faceted Lie"
    )

    /// Check if the Faceted Lie will answer the Mirrorwound bell
    var facetedLieUnlocked: Bool {
        return mirrorwoundKills >= ProgressionManager.arena4Gate.totalKillsRequired
    }
    
    /// Progress toward Arena 1 gate as individual fractions
    struct GateProgress {
        let killProgress: CGFloat       // 0.0–1.0
        let bossKillProgress: CGFloat   // 0.0–1.0
        let survivalMet: Bool
        let allMet: Bool
        
        let currentKills: Int
        let requiredKills: Int
        let currentBossKills: Int
        let requiredBossKills: Int
    }
    
    var arena1Progress: GateProgress {
        let gate = ProgressionManager.arena1Gate
        let kp = min(1.0, CGFloat(totalKills) / CGFloat(gate.totalKillsRequired))
        let bp = gate.bossKillsRequired == 0
            ? 1.0
            : min(1.0, CGFloat(bossKills) / CGFloat(gate.bossKillsRequired))
        let sm = gate.survivalRequired ? hasSurvived2Minutes : true
        return GateProgress(
            killProgress: kp,
            bossKillProgress: bp,
            survivalMet: sm,
            allMet: kp >= 1.0 && bp >= 1.0 && sm,
            currentKills: totalKills,
            requiredKills: gate.totalKillsRequired,
            currentBossKills: bossKills,
            requiredBossKills: gate.bossKillsRequired
        )
    }
    
    // MARK: - Run Recording
    
    enum KillType {
        case melee
        case ranged
        case boss
    }
    
    /// Record a single kill during gameplay
    func recordKill(_ type: KillType) {
        switch type {
        case .melee:  meleeKills += 1
        case .ranged: rangedKills += 1
        case .boss:
            bossKills += 1
            // v2.0: Arena 2 now unlocks on the Slag Titan's DEATH (see the
            // boss's onDeath in GameScene), consistent with Arenas 3 & 4. The
            // old lifetime-total-kills gate here is what let a grind-heavy save
            // reach Arena 2 without actually felling the Titan.
        }
    }
    
    /// Record survival time at end of run
    func recordSurvival(_ time: TimeInterval) {
        if time > longestSurvival {
            longestSurvival = time
        }
        if time >= 120 && !hasSurvived2Minutes {
            hasSurvived2Minutes = true
        }
    }
    
    // MARK: - Forge XP from Run
    
    /// Calculate forge XP earned from a run
    func forgeXPForRun(kills: Int, level: Int, time: TimeInterval, bossDefeated: Bool) -> Int {
        var xp = kills * 2              // 2 XP per kill
        xp += level * 5                 // 5 XP per player level reached
        xp += Int(time / 10) * 3        // 3 XP per 10 seconds survived
        if bossDefeated { xp += 100 }   // Boss kill bonus
        return xp
    }
    
    // MARK: - Reset (for testing)
    
    func resetAll() {
        defaults.removeObject(forKey: Keys.meleeKills)
        defaults.removeObject(forKey: Keys.rangedKills)
        defaults.removeObject(forKey: Keys.bossKills)
        defaults.removeObject(forKey: Keys.longestSurvival)
        defaults.removeObject(forKey: Keys.survived2Min)
        defaults.removeObject(forKey: Keys.forgeXP)
        defaults.removeObject(forKey: Keys.forgeLevel)
        defaults.removeObject(forKey: Keys.quenchKills)
        defaults.removeObject(forKey: Keys.wardenKills)
        defaults.removeObject(forKey: Keys.coilworksKills)
        defaults.removeObject(forKey: Keys.choirKills)       // v1.9: was missing
        defaults.removeObject(forKey: Keys.mirrorwoundKills)
        defaults.removeObject(forKey: Keys.currentArena)
        defaults.removeObject(forKey: Keys.arenasUnlocked)
        ForgePathManager.shared.resetAll()
    }

    /// v1.9: the full "Erase all progress" wipe behind the Settings flow.
    /// Clears every progress domain — progression, high scores, codex
    /// discovery, daily blessing — while PRESERVING settings (SFX/BGM) and
    /// StoreKit purchases (Remove Ads), which are not "progress".
    func eraseAllProgress() {
        resetAll()
        HighScoreManager.shared.resetAll()
        CodexManager.shared.resetAll()      // relocks card/synergy/bestiary discovery
        DailyForgeManager.shared.resetAll()
    }
    
    private init() {
        // v1.7 migration: players who felled the Warden before the
        // Coilworks existed already earned Arena 3 — unlock retroactively.
        if wardenKills > 0 && arenasUnlocked < 3 {
            arenasUnlocked = 3
        }
    }
}
