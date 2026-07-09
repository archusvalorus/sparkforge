// DailyForgeManager.swift
// Sparkforge
//
// v1.4: Daily Forge Blessing — once per calendar day, the player can
// watch a rewarded ad (or claim free if Remove Ads purchased) to
// receive a random temporary buff for their next run.
// Drives daily opens.

import Foundation

final class DailyForgeManager {
    
    static let shared = DailyForgeManager()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    
    private enum Keys {
        static let lastBlessingDate = "sf_last_blessing_date"
        static let activeBlessingID = "sf_active_blessing"
    }
    
    // MARK: - Blessing Definitions
    
    struct Blessing {
        let id: String
        let name: String
        let icon: String
        let description: String
        let apply: (PlayerStats) -> Void
    }
    
    static let blessings: [Blessing] = [
        Blessing(id: "ember_heart", name: "Ember Heart", icon: "🔥",
                 description: "+15% ATK this run") { stats in
            stats.damageMultiplier += 0.15
        },
        Blessing(id: "iron_skin", name: "Iron Skin", icon: "🛡️",
                 description: "+10 DEF this run") { stats in
            stats.defense += 10
        },
        Blessing(id: "vital_forge", name: "Vital Forge", icon: "💚",
                 description: "+25 max HP this run") { stats in
            stats.maxHP += 25
            stats.currentHP += 25
        },
        Blessing(id: "swift_spark", name: "Swift Spark", icon: "⚡",
                 description: "+10% move speed this run") { stats in
            stats.moveSpeedMultiplier += 0.10
        },
        Blessing(id: "lucky_strike", name: "Lucky Strike", icon: "🎯",
                 description: "+8% crit chance this run") { stats in
            stats.critChance += 0.08
        }
    ]
    
    // MARK: - State
    
    /// Whether the daily blessing has been claimed today
    var hasClaimedToday: Bool {
        guard let lastDate = defaults.object(forKey: Keys.lastBlessingDate) as? Date else {
            return false
        }
        return Calendar.current.isDateInToday(lastDate)
    }
    
    /// Whether there is a blessing waiting to be applied to the next run
    var activeBlessingID: String? {
        get { defaults.string(forKey: Keys.activeBlessingID) }
        set { defaults.set(newValue, forKey: Keys.activeBlessingID) }
    }
    
    /// The active blessing object, if any
    var activeBlessing: Blessing? {
        guard let id = activeBlessingID else { return nil }
        return DailyForgeManager.blessings.first { $0.id == id }
    }
    
    // MARK: - Claim
    
    /// Claim the daily blessing. Returns the blessing that was granted.
    /// Call this after the rewarded ad completes (or immediately if Remove Ads).
    func claimBlessing() -> Blessing {
        defaults.set(Date(), forKey: Keys.lastBlessingDate)
        
        let blessing = DailyForgeManager.blessings.randomElement()!
        activeBlessingID = blessing.id
        
        return blessing
    }
    
    // MARK: - Apply
    
    /// Apply the active blessing to PlayerStats at run start, then clear it.
    /// Returns the blessing that was applied, or nil if none.
    @discardableResult
    func applyBlessingIfActive(to stats: PlayerStats) -> Blessing? {
        guard let blessing = activeBlessing else { return nil }
        blessing.apply(stats)
        activeBlessingID = nil  // Consumed — one use
        return blessing
    }
    
    // MARK: - Reset (testing)
    
    func resetAll() {
        defaults.removeObject(forKey: Keys.lastBlessingDate)
        defaults.removeObject(forKey: Keys.activeBlessingID)
    }
    
    private init() {}
}
