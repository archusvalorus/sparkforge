// HighScoreManager.swift
// Sparkforge
//
// Local persistent high scores.
// Tracks: best time survived, highest level, total runs.
// Uses UserDefaults — lightweight, no backend needed for MVP.

import Foundation

final class HighScoreManager {
    
    static let shared = HighScoreManager()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    
    private enum Keys {
        static let bestTime = "sparkforge_best_time"
        static let bestLevel = "sparkforge_best_level"
        static let totalRuns = "sparkforge_total_runs"
        static let totalKills = "sparkforge_total_kills"
    }
    
    // MARK: - Accessors
    
    var bestTime: TimeInterval {
        get { defaults.double(forKey: Keys.bestTime) }
        set { defaults.set(newValue, forKey: Keys.bestTime) }
    }
    
    var bestLevel: Int {
        get { defaults.integer(forKey: Keys.bestLevel) }
        set { defaults.set(newValue, forKey: Keys.bestLevel) }
    }
    
    var totalRuns: Int {
        get { defaults.integer(forKey: Keys.totalRuns) }
        set { defaults.set(newValue, forKey: Keys.totalRuns) }
    }
    
    var totalKills: Int {
        get { defaults.integer(forKey: Keys.totalKills) }
        set { defaults.set(newValue, forKey: Keys.totalKills) }
    }
    
    // MARK: - Formatted
    
    var bestTimeFormatted: String {
        let minutes = Int(bestTime) / 60
        let seconds = Int(bestTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Record Run
    
    struct RunResult {
        let isNewBestTime: Bool
        let isNewBestLevel: Bool
    }
    
    /// Record a completed run. Returns which records were broken.
    @discardableResult
    func recordRun(time: TimeInterval, level: Int, kills: Int) -> RunResult {
        totalRuns += 1
        totalKills += kills
        
        let newBestTime = time > bestTime
        let newBestLevel = level > bestLevel
        
        if newBestTime { bestTime = time }
        if newBestLevel { bestLevel = level }
        
        return RunResult(isNewBestTime: newBestTime, isNewBestLevel: newBestLevel)
    }
    
    // MARK: - Reset (for testing)
    
    func resetAll() {
        defaults.removeObject(forKey: Keys.bestTime)
        defaults.removeObject(forKey: Keys.bestLevel)
        defaults.removeObject(forKey: Keys.totalRuns)
        defaults.removeObject(forKey: Keys.totalKills)
    }
    
    private init() {}
}
