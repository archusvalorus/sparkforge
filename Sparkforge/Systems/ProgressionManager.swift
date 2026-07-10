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
        static let longestSurvival = "sf_longest_survival"
        static let survived2Min = "sf_survived_2min"
        static let forgeXP = "sf_forge_xp"
        static let forgeLevel = "sf_forge_level"
        static let currentArena = "sf_current_arena"
        static let arenasUnlocked = "sf_arenas_unlocked"
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
    
    /// XP needed for next forge level. Starts at 100, scales 1.5× per level.
    func xpForLevel(_ level: Int) -> Int {
        return Int(100.0 * pow(1.5, Double(level)))
    }
    
    /// XP progress toward next level as 0.0–1.0
    var forgeLevelProgress: CGFloat {
        let needed = xpForLevel(forgeLevel)
        guard needed > 0 else { return 0 }
        return CGFloat(forgeXP) / CGFloat(needed)
    }
    
    /// Add forge XP from a completed run. Returns true if leveled up.
    @discardableResult
    func addForgeXP(_ amount: Int) -> Bool {
        forgeXP += amount
        let needed = xpForLevel(forgeLevel)
        if forgeXP >= needed {
            forgeXP -= needed
            forgeLevel += 1
            return true
        }
        return false
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
            // v1.6: Arena 2 gate — Slag Titan kill + 100 total kills
            // (the kills condition is met by the time anyone faces him,
            // but it's encoded so the gate survives future retuning)
            if arenasUnlocked < 2 && totalKills >= ProgressionManager.arena1Gate.totalKillsRequired {
                arenasUnlocked = 2
            }
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
        defaults.removeObject(forKey: Keys.currentArena)
        defaults.removeObject(forKey: Keys.arenasUnlocked)
        ForgePathManager.shared.resetAll()
    }
    
    private init() {}
}
