// AnalyticsTracker.swift
// Sparkforge
//
// Lightweight analytics for tracking run metrics.
// Phase 1: Local tracking only. Phase 4: Hook into backend/Firebase.

import Foundation

final class AnalyticsTracker {
    
    static let shared = AnalyticsTracker()
    
    private init() {}
    
    // MARK: - Run Data
    
    struct RunData {
        let sessionLength: TimeInterval
        let timeOfDeath: TimeInterval
        let levelReached: Int
        let pickedUpgrades: [String]  // Card IDs
        let usedRevive: Bool
        let timestamp: Date
    }
    
    private var runs: [RunData] = []
    
    // MARK: - Recording
    
    func recordRun(_ data: RunData) {
        runs.append(data)
        
        // Phase 4: Send to Firebase/backend
        #if DEBUG
        print("[Analytics] Run recorded — Level: \(data.levelReached), Time: \(String(format: "%.1f", data.timeOfDeath))s")
        #endif
    }
    
    // MARK: - Quick Access
    
    var totalRuns: Int { runs.count }
    var averageSessionLength: TimeInterval {
        guard !runs.isEmpty else { return 0 }
        return runs.map(\.sessionLength).reduce(0, +) / Double(runs.count)
    }
}
