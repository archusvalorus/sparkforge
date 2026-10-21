private func spawnEnemy() {
        if channelArrivalPending { return }
        if isTwinChannels { spawnTwinChannelsEnemy(); return }
        // v1.6: The Quench runs its own spawn table
        if arenaConfig.id == 1 {
            spawnQuenchEnemy()
            return
        }
        // v1.7: so does The Coilworks
        if arenaConfig.id == 2 {
            spawnCoilworksEnemy()
            return
        }
        // v1.8: and The Mirrorwound
        if arenaConfig.id == 3 {
            spawnMirrorwoundEnemy()
            return
        }
        // v2.0: and The Star Anvil (Arena 5)
        if arenaConfig.id == 4 {
            spawnStarAnvilEnemy()
            return
        }
        // v2.1: and The Splitworks (Arena 6)
        if arenaConfig.id == 5 {
            spawnSplitworksEnemy()
            return
        }

        let elapsed = waveManager.elapsedTime

        // After 45s, chance to spawn a ranged enemy instead
        if elapsed >= GameConfig.RangedEnemy.firstSpawnTime &&
           CGFloat.random(in: 0...1) < GameConfig.RangedEnemy.spawnChance {
            spawnRangedEnemy()
            return
        }

        // v1.6 tuning: from 30s, skip ~30% of melee spawns — the crowd was
        // outpacing the fun (Brandon playtest 7/9/26)
        if elapsed >= GameConfig.Wave.meleeThinningStart &&
           CGFloat.random(in: 0...1) < GameConfig.Wave.meleeThinningChance {
            return
        }

        spawnBasicMelee(elapsed: elapsed)
    }
