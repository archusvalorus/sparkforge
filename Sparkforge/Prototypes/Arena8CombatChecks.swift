// Executed by --arena8-combat --arena8-combat-checks on a disposable device.
#if DEBUG
import SpriteKit
import UIKit

@MainActor enum Arena8CombatChecks {
    static func run(scene: Arena8CombatScene) {
        var checks: [[String: Any]] = []
        var circleDiagnostics: [[String: Any]] = []
        func check(_ id: String, _ value: @autoclosure () -> Bool) { checks.append(["id": id, "pass": value()]) }
        let oldOverride = ArenaConfig.overrideID
        defer { ArenaConfig.overrideID = oldOverride }
        ArenaConfig.overrideID = 0 // No save-selected arena access, no writes.
        let saved = UserDefaults.standard.dictionaryRepresentation().filter { $0.key.hasPrefix("sf_") || $0.key.hasPrefix("sparkforge_") }
        let map = Arena8P0Model()
        let model = Arena8CombatModel(); model.firing = false
        for (id, passed) in scene.verifyLifecycle() { check(id, passed) }
        check("real-player-stats", model.player.stats === model.stats)
        check("actual-node-types", model.enemy != nil && model.player.debugMovementConstraint != nil)
        check("safe-player", map.valid(model.player.position, radius: model.stats.effectiveCollisionRadius))
        check("safe-enemy", map.valid(model.enemy!.position, radius: model.enemy!.geometryFootprintRadius))
        check("no-duplicate-spawn", !model.spawnEnemy())
        model.player.position = CGPoint(x: -110, y: 150)
        for _ in 0..<180 { model.step(1.0 / 60, direction: CGPoint(x: 1, y: 0)) }
        check("real-walk-no-wall-tunnel", model.player.position.x <= -110 && map.valid(model.player.position, radius: 10))
        let y = model.player.position.y
        for _ in 0..<30 { model.step(1.0 / 60, direction: CGPoint(x: 1, y: -1)) }
        check("real-wall-slide", model.player.position.y < y - 50)
        model.reset(); model.firing = false; model.player.position = CGPoint(x: -280, y: 0)
        for _ in 0..<130 { model.step(1.0 / 60, direction: CGPoint(x: 1, y: 0)) }
        check("doorway-real-movement", model.player.position.x > 200)
        model.reset(); model.firing = false
        // Real chase must route from the opposite room rather than stick to wall.
        var chaseSafe = true
        for _ in 0..<900 {
            model.step(1.0 / 60, direction: .zero)
            if let e = model.enemy { chaseSafe = chaseSafe && map.valid(e.position, radius: e.geometryFootprintRadius) }
            if model.player.isDead { break }
        }
        check("enemy-enters-left-room", (model.enemy?.position.x ?? 999) < -150)
        check("all-chase-positions-safe", chaseSafe)
        check("contact-damages-real-hp", model.stats.currentHP < model.stats.maxHP)
        model.reset(); model.firing = false
        model.player.position = CGPoint(x: -200, y: 150)
        model.shovePlayer(by: CGPoint(x: 600, y: 0))
        check("straight-shove-stops-wall", model.player.position.x < -109 && model.player.position.y == 150)
        model.player.position = CGPoint(x: -200, y: 0); model.shovePlayer(by: CGPoint(x: 600, y: 0))
        check("straight-shove-through-door", model.player.position.x > 300)
        model.reset(); model.firing = false
        model.enemy!.position = CGPoint(x: -200, y: 150)
        model.shoveEnemy(by: CGPoint(x: 600, y: 0))
        check("real-enemy-straight-shove-wall", model.enemy!.position.x < -113 && model.enemy!.position.y == 150 && map.valid(model.enemy!.position, radius: model.enemy!.geometryFootprintRadius))
        model.enemy!.position = CGPoint(x: -200, y: 0); model.shoveEnemy(by: CGPoint(x: 600, y: 0))
        check("real-enemy-straight-shove-door", model.enemy!.position.x > 300 && map.valid(model.enemy!.position, radius: model.enemy!.geometryFootprintRadius))
        let heldEnemy = model.enemy!.position; model.held = true
        model.shoveEnemy(by: CGPoint(x: -600, y: 0))
        check("held-enemy-shove-blocked", model.enemy!.position == heldEnemy)
        model.reset(); model.firing = false; let hp = model.enemy!.health
        model.enemy!.position = CGPoint(x: 280, y: 150)
        model.fire(toward: model.enemy!.position)
        for _ in 0..<150 { model.step(1.0 / 60, direction: .zero) }
        check("ordinary-shot-stopped", model.blockedShots == 1 && model.hits == 0 && model.enemy?.health == hp)
        check("ordinary-cleanup", model.projectiles.isEmpty)
        model.reset(); model.firing = false; model.longShot = true
        model.fire(toward: model.enemy!.position)
        // Freeze enemy for a precise terrain passage test using real status.
        model.enemy!.applyStun(10)
        for _ in 0..<90 { model.step(1.0 / 60, direction: .zero) }
        check("longshot-cross-wall-hit", model.hits == 1 && (model.enemy?.health ?? 0) < hp)
        for _ in 0..<120 { model.step(1.0 / 60, direction: .zero) }
        check("longshot-single-hit-and-outer-cleanup", model.hits == 1 && model.projectiles.isEmpty)
        model.reset(); model.firing = false; model.player.position = CGPoint(x: -280, y: 0)
        model.enemy!.position = CGPoint(x: -240, y: 0)
        model.enemy!.applyStun(10)
        for _ in 0..<20 {
            if let e = model.enemy { model.fire(toward: e.position) }
            for _ in 0..<10 { model.step(1.0 / 60, direction: .zero) }
        }
        check("real-kill-once", model.kills == 1 && model.enemy == nil)
        check("actual-xp-collected-once", model.collected == GameConfig.Leveling.baseEnemyXP && model.player.currentXP > 0)
        check("collected-orb-pruned", model.orbs.isEmpty)
        check("explicit-respawn", model.spawnEnemy())
        model.fire(toward: CGPoint(x: 420, y: 0))
        let position = model.player.position, enemyPosition = model.enemy!.position
        let projectilePosition = model.projectiles.first!.position, time = model.elapsed, xp = model.player.currentXP
        model.held = true
        model.step(10, direction: CGPoint(x: 1, y: 1)); model.shovePlayer(by: CGPoint(x: 600, y: 0))
        model.fire(toward: CGPoint(x: 420, y: 0))
        check("hold-freezes-all-clocks", model.elapsed == time && model.root.isPaused)
        check("hold-freezes-actors-projectiles", model.player.position == position && model.enemy!.position == enemyPosition && model.projectiles.first!.position == projectilePosition)
        check("hold-keeps-xp", model.player.currentXP == xp)
        model.held = false; model.step(10, direction: .zero)
        check("resume-no-catchup", abs(model.elapsed - time - GameConfig.Arena8Combat.maximumStep) < 0.000001)
        model.reset()
        check("reset-clears-all-runtime-state", model.elapsed == 0 && model.hits == 0 && model.kills == 0 && model.collected == 0 && model.projectiles.isEmpty && model.orbs.isEmpty && !model.longShot && model.player.currentXP == 0 && !model.player.isDead && model.stats.currentHP == model.stats.maxHP)
        check("reset-removes-old-bodies", model.root.children.count == 2)
        // Outstanding real XP orb freezes, then all transient trees clear.
        model.reset(); model.firing = false; model.longShot = true
        model.enemy!.position = CGPoint(x: -180, y: 150); model.enemy!.applyStun(10)
        for _ in 0..<20 {
            if let e = model.enemy { model.fire(toward: e.position) }
            for _ in 0..<10 { model.step(1.0 / 60, direction: .zero) }
        }
        check("outstanding-xp-orb", model.orbs.count == 1)
        let orbPosition = model.orbs.first?.position
        model.held = true; model.step(20, direction: CGPoint(x: 1, y: 0))
        check("pause-outstanding-xp", model.orbs.count == 1 && model.orbs.first?.position == orbPosition && model.player.currentXP == 0)
        model.reset(); model.firing = false
        model.stats.currentHP = 1; model.enemy!.position = model.player.position
        model.fire(toward: CGPoint(x: 280, y: 0))
        model.projectiles.first!.position = model.player.position + CGPoint(x: 40, y: 0)
        model.step(1.0 / 60, direction: .zero)
        check("death-real-node-and-hold", model.player.isDead && model.stats.currentHP == 0 && model.root.isPaused)
        let deathAge = model.elapsed, deathShot = model.projectiles.first?.position
        model.step(30, direction: CGPoint(x: 1, y: 0)); model.fire(toward: .zero)
        check("death-cancels-further-play", model.elapsed == deathAge && model.projectiles.first?.position == deathShot)
        model.reset()
        check("death-reset-clears-projectiles", !model.player.isDead && model.projectiles.isEmpty && model.orbs.isEmpty && model.root.children.count == 2)
        // One frame crosses wall and target: wall must win, actual projectile.
        model.firing = false; model.player.position = CGPoint(x: -111, y: 100)
        model.enemy!.position = CGPoint(x: 111, y: 100); model.enemy!.applyStun(10)
        model.fire(toward: model.enemy!.position)
        model.projectiles.first!.position = CGPoint(x: 94, y: 100)
        let wallHP = model.enemy!.health
        model.step(GameConfig.Arena8Combat.maximumStep, direction: .zero)
        check("wall-before-target-same-frame", model.enemy!.health == wallHP && model.hits == 0 && model.projectiles.isEmpty)
        // Actual moving enemy crossing a real projectile's segment.
        model.reset(); model.firing = false; model.player.position = CGPoint(x: -280, y: 0)
        model.enemy!.position = CGPoint(x: -210, y: 0)
        model.fire(toward: model.enemy!.position)
        let movingHP = model.enemy!.health
        for _ in 0..<15 { model.step(1.0 / 60, direction: .zero) }
        check("moving-enemy-real-shot-hit", model.hits == 1 && (model.enemy?.health ?? 0) < movingHP)
        // Expired ordinary shot and unlimited Long Shot outer bounds.
        model.reset(); model.firing = false
        model.fire(toward: CGPoint(x: -280, y: -200))
        for _ in 0..<100 { model.step(1.0 / 60, direction: .zero) }
        check("ordinary-range-cleanup", model.projectiles.isEmpty)
        model.reset()
        model.fire(toward: .zero); model.cancel(); model.cancel()
        check("exit-cancel-idempotent", model.root.children.isEmpty && model.enemy == nil && model.projectiles.isEmpty && model.orbs.isEmpty && model.held)
        model.reset()
        // Native body sizes, fixed literal P0 map, on actual phone/iPad runtime.
        let radius = model.enemy!.geometryFootprintRadius
        check("native-device-door-clearance", radius < GameConfig.Arena8Prototype.doorwayHalfHeight && map.valid(.zero, radius: radius))
        for body: CGFloat in [10, 14, 26, 40] {
            var p = CGPoint(x: -280, y: 0), safe = true
            for _ in 0..<180 { p = map.move(from: p, toward: p + CGPoint(x: 4, y: 0), radius: body) ?? p; safe = safe && map.valid(p, radius: body) }
            check("clearance-\(Int(body))", safe && p.x > 200)
        }
        check("unsafe-spawn-rejected", map.spawn(candidates: [.zero, CGPoint(x: 0, y: 180)], radius: 70, avoiding: .zero, clearance: 0) == nil)
        // Execute actual normal PlayerNode.move across every existing arena.
        for config in ArenaConfig.all {
            ArenaConfig.overrideID = config.id
            let p = PlayerNode(), s = PlayerStats(); p.stats = s
            p.position = CGPoint(x: GameConfig.Arena.radius - s.effectiveCollisionRadius - 1, y: 0)
            p.move(direction: CGPoint(x: 1, y: 0), deltaTime: 1)
            check("circle-\(config.id)-default-hook-nil", p.debugMovementConstraint == nil)
            let expected = GameConfig.Arena.radius - s.effectiveCollisionRadius
            // SKNode stores native positions at Float32 precision. Phone
            // integer radii can compare exact; iPad device-scaled radii cannot.
            // Two storage ULPs remain far below a pixel, not gameplay leeway.
            let tolerance = CGFloat(Float(expected).ulp) * 2
            circleDiagnostics.append(["arena": config.id, "actual": p.position.x, "expected": expected,
                                      "delta": abs(p.position.x - expected), "tolerance": tolerance])
            check("circle-\(config.id)-real-clamp", abs(p.position.x - expected) <= tolerance && p.position.y == 0)
            p.position = .zero; p.move(direction: CGPoint(x: 0, y: 1), deltaTime: 0.1)
            check("circle-\(config.id)-real-speed", abs(p.position.y - s.effectiveMoveSpeed * 0.1) < 0.00001)
        }
        let ledgerEnemy = EnemyNode(health: 100)
        let ledgerShot = ProjectileNode(direction: CGPoint(x: 1, y: 0), piercesAll: true)
        check("real-projectile-ledger-fresh", !ledgerShot.hasStruck(ledgerEnemy))
        check("real-piercing-shot-retained", !ledgerShot.onHitEnemy(ledgerEnemy))
        check("real-projectile-ledger-recorded", ledgerShot.hasStruck(ledgerEnemy))
        check("swept-moving-contact", Arena8CombatModel.contactFraction(from: CGPoint(x: -10, y: 0), to: CGPoint(x: 10, y: 0), centerFrom: CGPoint(x: 0, y: -10), centerTo: CGPoint(x: 0, y: 10), radius: 1) != nil)
        check("swept-miss", Arena8CombatModel.contactFraction(from: CGPoint(x: -10, y: 0), to: CGPoint(x: 10, y: 0), centerFrom: CGPoint(x: 0, y: 10), centerTo: CGPoint(x: 0, y: 10), radius: 1) == nil)
        let after = UserDefaults.standard.dictionaryRepresentation().filter { $0.key.hasPrefix("sf_") || $0.key.hasPrefix("sparkforge_") }
        check("no-save-keys-changed", NSDictionary(dictionary: saved).isEqual(to: after))
        let report: [String: Any] = ["checks": checks, "passed": checks.filter { $0["pass"] as? Bool == true }.count,
            "failed": checks.filter { $0["pass"] as? Bool == false }.count,
            "circleDiagnostics": circleDiagnostics, "device": UIDevice.current.model, "idiom": DeviceScale.isIPad ? "iPad" : "iPhone", "enemyRadius": radius,
            "scope": "actual native nodes and controller, no input/feel or performance acceptance"]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("arena8-combat-checks.json")
            try? data.write(to: url); NSLog("Arena8 combat checks: %@", String(data: data, encoding: .utf8) ?? "")
        }
    }
}
#endif
