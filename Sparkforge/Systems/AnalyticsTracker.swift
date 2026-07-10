// AnalyticsTracker.swift
// Sparkforge
//
// Lightweight analytics for tracking run metrics.
// Phase 1: Local tracking only. Phase 4: Hook into backend/Firebase.
// v1.7: Runs persist to disk as JSON, capped ring buffer.

import Foundation

final class AnalyticsTracker {

    static let shared = AnalyticsTracker()

    // MARK: - Run Data

    struct RunData: Codable {
        let sessionLength: TimeInterval
        let timeOfDeath: TimeInterval
        let levelReached: Int
        let pickedUpgrades: [String]  // Card IDs
        let usedRevive: Bool
        let timestamp: Date
    }

    private var runs: [RunData] = []

    private let saveQueue = DispatchQueue(label: "com.brandon.Sparkforge.analytics", qos: .utility)

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("sparkforge_runs.json")
    }

    private init() {
        runs = Self.loadFromDisk()
    }

    // MARK: - Recording

    func recordRun(_ data: RunData) {
        runs.append(data)
        if runs.count > GameConfig.Analytics.maxStoredRuns {
            runs.removeFirst(runs.count - GameConfig.Analytics.maxStoredRuns)
        }
        saveToDisk()

        // Phase 4: Send to Firebase/backend
        #if DEBUG
        print("[Analytics] Run recorded — Level: \(data.levelReached), Time: \(String(format: "%.1f", data.timeOfDeath))s, stored: \(runs.count)")
        #endif
    }

    // MARK: - Persistence (v1.7)

    private func saveToDisk() {
        let snapshot = runs
        saveQueue.async {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try FileManager.default.createDirectory(
                    at: Self.fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: Self.fileURL, options: .atomic)
            } catch {
                #if DEBUG
                print("[Analytics] Save failed: \(error)")
                #endif
            }
        }
    }

    private static func loadFromDisk() -> [RunData] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([RunData].self, from: data)) ?? []
    }

    // MARK: - Quick Access

    var totalRuns: Int { runs.count }
    var averageSessionLength: TimeInterval {
        guard !runs.isEmpty else { return 0 }
        return runs.map(\.sessionLength).reduce(0, +) / Double(runs.count)
    }
}
