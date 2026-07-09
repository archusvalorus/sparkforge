// WaveManager.swift
// Sparkforge
//
// Controls enemy spawn pacing.
// Spawn interval decreases over time → escalating pressure.
// Mini-boss spawn at configured time.

import SpriteKit

final class WaveManager {
    
    // MARK: - State
    
    private(set) var elapsedTime: TimeInterval = 0
    private var timeSinceLastSpawn: TimeInterval = 0
    private(set) var miniBossSpawned: Bool = false
    
    // MARK: - Computed
    
    /// Current spawn interval — gets shorter over time, ramps hard after 90s
    var currentSpawnInterval: TimeInterval {
        let config = GameConfig.Wave.self
        
        if elapsedTime < 90 {
            // Phase 1: Gradual ramp (0–90s)
            let reduced = config.initialSpawnInterval - (elapsedTime * config.spawnAcceleration)
            return max(reduced, config.minimumSpawnInterval)
        } else {
            // Phase 2: Aggressive density (90s+)
            // Faster acceleration, lower floor
            let phase2Time = elapsedTime - 90
            let phase1Floor = config.initialSpawnInterval - (90 * config.spawnAcceleration)
            let reduced = phase1Floor - (phase2Time * config.lateGameAcceleration)
            return max(reduced, config.lateGameMinInterval)
        }
    }
    
    // MARK: - Update
    
    struct SpawnEvent {
        let shouldSpawnEnemy: Bool
        let shouldSpawnMiniBoss: Bool
    }
    
    /// Call each frame. Returns what should be spawned.
    func update(deltaTime: TimeInterval) -> SpawnEvent {
        elapsedTime += deltaTime
        timeSinceLastSpawn += deltaTime
        
        var spawnEnemy = false
        var spawnMiniBoss = false
        
        // Regular enemy spawn check
        if timeSinceLastSpawn >= currentSpawnInterval {
            timeSinceLastSpawn = 0
            spawnEnemy = true
        }
        
        // Mini-boss check
        if !miniBossSpawned && elapsedTime >= GameConfig.Wave.miniBossSpawnTime {
            miniBossSpawned = true
            spawnMiniBoss = true
        }
        
        return SpawnEvent(
            shouldSpawnEnemy: spawnEnemy,
            shouldSpawnMiniBoss: spawnMiniBoss
        )
    }
    
    // MARK: - Reset
    
    func reset() {
        elapsedTime = 0
        timeSinceLastSpawn = 0
        miniBossSpawned = false
    }
}
