private func spawnOrdinaryEnemy(elapsed: TimeInterval) {
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
private func spawnBasicMelee(elapsed: TimeInterval) {
        // HP scales with time — enemies get beefier (v1.4: softened curve)
        let baseHP: Int
        if elapsed < 30 {
            baseHP = 1
        } else if elapsed < 60 {
            baseHP = 1
        } else if elapsed < 90 {
            baseHP = 2
        } else if elapsed < 120 {
            baseHP = Int.random(in: 2...3)
        } else {
            baseHP = Int.random(in: 3...5)
        }

        let speedScale: CGFloat = 1.0 + CGFloat(elapsed / 180) * 0.15  // v1.4: slower speed ramp
        let enemySpeed = GameConfig.Enemy.baseSpeed * speedScale
        let xpValue = max(1, baseHP + 1)  // v1.4: +1 XP per kill across the board

        let enemy = EnemyNode(health: baseHP, moveSpeed: enemySpeed, xpValue: xpValue)
        enemy.position = EnemyNode.spawnPosition()

        if baseHP >= 3 {
            let sizeScale = 1.0 + CGFloat(baseHP - 2) * 0.08
            enemy.setScale(sizeScale)
        }

        enemies.append(enemy)
        worldNode.addChild(enemy)
    }
private func spawnRangedEnemy(at position: CGPoint? = nil) {
        // v1.6 tuning: shooters are glass cannons — dangerous at range,
        // dead in one hit (Brandon playtest 7/9/26). Was 2–8 HP scaling.
        let ranged = RangedEnemyNode(
            health: 1,
            moveSpeed: GameConfig.Enemy.baseSpeed * 0.75,
            xpValue: 2
        )
        ranged.position = position ?? EnemyNode.spawnPosition()

        // Wire up the fire callback
        ranged.onFireProjectile = { [weak self] position, direction in
            self?.spawnEnemyProjectile(at: position, direction: direction)
        }

        enemies.append(ranged)
        worldNode.addChild(ranged)
    }
