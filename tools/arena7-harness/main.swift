import Foundation
import CoreGraphics
var passed = 0, failed = 0
func check(_ label: String, _ ok: Bool) {
    if ok { passed += 1; print("PASS \(label)") }
    else { failed += 1; print("FAIL \(label)") }
}
// The real registry must remain six arenas. The dev cycle adds a non-persisted shell.
check("A1 production registry remains six arenas with real bosses", ArenaConfig.all.count == 6 && ArenaConfig.all.allSatisfy { !$0.bossID.isEmpty })
DevSeams.arenaOverrideIndex = nil
for _ in 0...ArenaConfig.all.count { DevSeams.cycleArena() }
check("A2 dev picker reaches the extra shell", DevSeams.arenaOverrideIndex == 6)
ArenaConfig.overrideID = nil
let scene = GameScene()
let geo = scene.arenaGeometry
let r = GameConfig.Arena.radius
check("A3 live config and radius agree", scene.isTwinChannelsPreview && abs(r - 402.5) < 1e-6 && geo.blockedFootprints.count == 2)
check("A4 overlay banner announces development boss prototype", DevSeams.bannerText.contains("shell (Switchwarden prototype)"))
ArenaConfig.overrideID = 2
check("A5 explicit Boss Mode home wins over preview picker", GameScene.resolveArenaConfig().id == 2)
ArenaConfig.overrideID = 6
check("A6 registry boss lookup cannot discover a preview boss", ArenaConfig.arena(forBossID: "") == nil)
check("A7 dimensions and graph", geo.routeNodes.count == 10 && geo.routeEdges.count == 11 && geo.spawnZones.count == 4 && geo.usesRouteGraph)
check("A8 central gap is 0.36R", abs((geo.blockedFootprints[1].center.y - geo.blockedFootprints[1].halfExtents.height - geo.blockedFootprints[1].cornerRadius) - 0.18*r) < 1e-6)
check("A8b both island outer sizes and centers", zip(geo.blockedFootprints, [-1.0, 1.0]).allSatisfy { f, sign in
    abs(f.center.x) < 1e-6 && abs(f.center.y - sign*r*0.43) < 1e-6
    && abs(f.halfExtents.width + f.cornerRadius - r*0.12) < 1e-6
    && abs(f.halfExtents.height + f.cornerRadius - r*0.25) < 1e-6
})
check("A8c body too wide for every crossing has no graph route",
    geo.graphWaypoint(from: CGPoint(x: -0.6*r, y: -0.43*r), toward: CGPoint(x: 0.6*r, y: 0.43*r),
        travelRadius: r*0.30, arriveRadius: 28) == nil)
let start = geo.anchor("player_spawn") ?? .zero
check("A9 spawn anchor is valid", !geo.isBlocked(start, margin: 16) && start.length + 16 < r)
for body: CGFloat in [14, 30.8, 0.08*r] {
    check("A10 all authored edges clear body \(body)", geo.routeEdges.allSatisfy { e in
        guard let a = geo.node(e.from), let b = geo.node(e.to) else { return false }
        return !geo.segmentBlockedExact(a.position, b.position, travelRadius: body)
    })
}
// Execute the LIVE scene state transitions, not a replica of the shortest-path algorithm.
func reaches(_ scene: GameScene, from: CGPoint, goal: CGPoint, body: CGFloat, speed: CGFloat, dt: Double) -> Bool {
    let enemy = EnemyNode(health: 1, moveSpeed: speed, xpValue: 1)
    enemy.geometryFootprintRadius = body
    enemy.position = from
    for tick in 0..<3000 {
        if enemy.position.distance(to: goal) < 12 { return true }
        let target = scene.routeSteerTarget(for: enemy, toward: goal, dt: dt)
        enemy.chase(target: target, deltaTime: dt)
        enemy.position = scene.arenaGeometry.resolve(enemy.position, actorRadius: body)
        if scene.arenaGeometry.isBlocked(enemy.position, margin: body - 0.01) { return false }
        if tick == 30 { // forced off-route movement must invalidate/recover safely
            enemy.position = scene.arenaGeometry.resolve(enemy.position + CGPoint(x: 0.03*r, y: 0.03*r), actorRadius: body)
        }
    }
    return false
}
var probes: [CGPoint] = geo.routeNodes.map { $0.position }
for x: CGFloat in [-0.72, -0.2, 0.2, 0.72] {
    for y: CGFloat in [-0.5, -0.1, 0.1, 0.5] {
        let p = CGPoint(x: x*r, y: y*r)
        if p.length + 33 < r && !geo.isBlocked(p, margin: 33) { probes.append(p) }
    }
}
for (pad, short) in [(false, 390.0), (true, 834.0)] {
    DeviceScale.isIPad = pad
    DeviceScale.screenShort = short
    let base = DeviceScale.arenaRadius
    let scale = DeviceScale.gameplay
    let factor = GameConfig.Arena.radius / r
    for (body, speed, dt) in [(14.0, 80.0, 1.0/60), (30.8, 250.0, 1.0/20)] {
        var all = true
        routePairs: for a in probes { for b in probes where a != b {
            if !reaches(scene, from: a * factor, goal: b * factor, body: body*scale, speed: speed*scale, dt: dt) {
                print("route failed \(a) -> \(b) base=\(base) body=\(body)")
                all = false
                break routePairs
            }
        } }
        check("A11 live all-pairs steering base \(base), body \(body), speed \(speed)", all)
    }
}
DeviceScale.isIPad = false
DeviceScale.screenShort = 390
let enemy = EnemyNode(health: 1, moveSpeed: 130, xpValue: 1)
enemy.position = CGPoint(x: -0.43*r, y: -0.43*r)
enemy.routeNodeID = 4
_ = scene.routeSteerTarget(for: enemy, toward: CGPoint(x: -0.43*r, y: 0.43*r), dt: 0.02)
check("A12 direct line resumes without stale commitment", enemy.routeNodeID == nil)
let body: CGFloat = 14
let invalid = geo.channelSpawnPoint(candidates: [start, geo.blockedFootprints[0].center, CGPoint(x: r, y: 0), geo.routeNodes[0].position],
    player: start, actorRadius: body, arenaRadius: r, playerClearance: r*0.35, crossingClearance: r*0.10)
check("A13 all unsafe spawn candidates defer, never fallback", invalid == nil)
let safeRim = CGPoint(x: cos(CGFloat.pi*50/180), y: sin(CGFloat.pi*50/180)) * (r*0.95)
check("A13b near-player rejection independent of crossing rejection",
    geo.channelSpawnPoint(candidates: [safeRim], player: safeRim, actorRadius: body,
        arenaRadius: r, playerClearance: r*0.35, crossingClearance: r*0.10) == nil)
check("A13c safe point accepted without fallback",
    geo.channelSpawnPoint(candidates: [safeRim], player: safeRim * -1, actorRadius: body,
        arenaRadius: r, playerClearance: r*0.35, crossingClearance: r*0.10) == safeRim)
for _ in 0..<100 {
    scene.spawnTwinChannelsBody()
}
check("A14 actual preview spawner uses existing enemies", scene.enemies.count > 0)
check("A15 all emitted bodies satisfy real spawn guard", scene.enemies.allSatisfy { e in
    geo.channelSpawnPoint(candidates: [e.position], player: scene.player.position, actorRadius: body,
        arenaRadius: r, playerClearance: r*0.35, crossingClearance: r*0.10) != nil
})
check("A16 safe spawns alternate preferred lane", zip(scene.enemies, scene.enemies.dropFirst()).allSatisfy { ($0.position.x < 0) != ($1.position.x < 0) })
// Existing arenas must continue using their original steering branch.
check("A17 old arenas do not opt into graph routing", ArenaConfig.all.allSatisfy { !$0.geometry.usesRouteGraph })
var oldEqual = true
for config in ArenaConfig.all {
    let current = GameScene(), reference = GameScene()
    current.arenaConfig = config; reference.arenaConfig = config
    ArenaConfig.overrideID = config.id
    let points = config.geometry.routeNodes.map { $0.position } + [CGPoint(x: -100, y: -100), CGPoint(x: 100, y: 100)]
    for a in points { for b in points {
        let actual = EnemyNode(health: 1, moveSpeed: 130, xpValue: 1)
        let legacy = EnemyNode(health: 1, moveSpeed: 130, xpValue: 1)
        actual.position = a; legacy.position = a
        for _ in 0..<100 {
            let target = current.routeSteerTarget(for: actual, toward: b, dt: 1.0/60)
            let expected = reference.legacyRouteSteerTarget(for: legacy, toward: b, dt: 1.0/60)
            oldEqual = oldEqual && target == expected && actual.routeNodeID == legacy.routeNodeID
                && actual.routePrevNodeID == legacy.routePrevNodeID
                && actual.routeRedecideCooldown == legacy.routeRedecideCooldown
                && actual.isOccludedFromGoal == legacy.isOccludedFromGoal
            actual.chase(target: target, deltaTime: 1.0/60)
            actual.position = config.geometry.resolve(actual.position, actorRadius: 14)
            legacy.position = actual.position
        }
    } }
}
check("A18 six arenas retain exact executed baseline steering", oldEqual)
DevSeams.cycleArena()
ArenaConfig.overrideID = nil
check("A19 dev cycle returns OFF and normal selection", DevSeams.arenaOverrideIndex == nil && GameScene.resolveArenaConfig().id == 0)
print("Arena7: \(passed) passed / \(failed) failed")
exit(failed == 0 ? 0 : 1)
