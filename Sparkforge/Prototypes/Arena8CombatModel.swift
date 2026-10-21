// Isolated real-node bridge, not a campaign arena or a substitute GameScene.
#if DEBUG
import SpriteKit

final class Arena8CombatModel {
    typealias C = GameConfig.Arena8Combat
    let geometry = Arena8P0Model()
    let root = SKNode()
    private(set) var stats = PlayerStats()
    private(set) var player = PlayerNode()
    private(set) var enemy: EnemyNode?
    private(set) var projectiles: [ProjectileNode] = []
    private(set) var orbs: [XPOrbNode] = []
    private(set) var elapsed: TimeInterval = 0
    private(set) var kills = 0
    private(set) var hits = 0
    private(set) var collected = 0
    private(set) var blockedShots = 0
    private(set) var damageCooldown: TimeInterval = 0
    private(set) var shotClock: TimeInterval = 0
    var held = false {
        didSet { root.isPaused = held || player.isDead }
    }
    var firing = true
    var longShot: Bool {
        get { stats.longShotTier >= 4 }
        set { stats.longShotTier = newValue ? 4 : 0 }
    }

    init() { reset() }

    func cancel() {
        // Dying bodies/particles/actions are children too; remove the entire
        // owned tree, not just the current live arrays.
        root.enumerateChildNodes(withName: "//*") { node, _ in node.removeAllActions() }
        root.removeAllActions(); root.removeAllChildren(); root.isPaused = true
        enemy = nil; projectiles.removeAll(); orbs.removeAll(); held = true
    }

    func reset() {
        cancel(); root.isPaused = false
        stats = PlayerStats(); player = PlayerNode(); player.stats = stats
        let map = geometry
        player.debugMovementConstraint = { from, to, radius in map.move(from: from, toward: to, radius: radius) }
        player.position = C.playerStart; player.zPosition = 20
        disablePhysicsResponse(player); root.addChild(player)
        enemy = nil; projectiles.removeAll(); orbs.removeAll()
        elapsed = 0; kills = 0; hits = 0; collected = 0; blockedShots = 0
        damageCooldown = 0; shotClock = 0; held = false; firing = true
        _ = spawnEnemy()
    }

    private func disablePhysicsResponse(_ node: SKNode) {
        // Contacts are swept below, never both a physics callback and a hit.
        node.physicsBody?.isDynamic = false
        node.physicsBody?.collisionBitMask = 0
        node.physicsBody?.contactTestBitMask = 0
    }

    @discardableResult func spawnEnemy() -> Bool {
        guard !held, !player.isDead, enemy == nil else { return false }
        let actor = EnemyNode()
        guard let point = geometry.spawn(candidates: C.enemyStarts, radius: actor.geometryFootprintRadius,
                                         avoiding: player.position, clearance: C.spawnClearance) else { return false }
        actor.position = point; actor.zPosition = 15; disablePhysicsResponse(actor)
        root.addChild(actor); enemy = actor; return true
    }

    func shovePlayer(by delta: CGPoint) {
        guard !held, !player.isDead else { return }
        if let point = geometry.shove(from: player.position, toward: player.position + delta, radius: stats.effectiveCollisionRadius) {
            player.position = point
        }
    }

    // Geometry proof seam only: no Repulse or other card rider is enabled.
    func shoveEnemy(by delta: CGPoint) {
        guard !held, !player.isDead, let actor = enemy, !actor.isDying else { return }
        if let point = geometry.shove(from: actor.position, toward: actor.position + delta,
                                      radius: actor.geometryFootprintRadius) {
            actor.position = point
        }
    }

    func fire(toward target: CGPoint) {
        guard !held, !player.isDead, target != player.position else { return }
        let shot = ProjectileNode(direction: target - player.position,
            speed: stats.effectiveProjectileSpeed, range: stats.effectiveProjectileRange,
            damageMultiplier: CGFloat(stats.effectiveProjectileDamage),
            unlimitedRange: stats.projectileUnlimitedRange, piercesAll: stats.projectilePiercesAll,
            passesTerrain: stats.projectilePassesTerrain)
        shot.position = player.position; shot.zPosition = 18
        disablePhysicsResponse(shot); root.addChild(shot); projectiles.append(shot)
    }

    /// Continuous moving circle contact, in relative coordinates. Used for
    /// projectiles and enemy contact so a large permitted step cannot tunnel.
    static func contactFraction(from: CGPoint, to: CGPoint, centerFrom: CGPoint, centerTo: CGPoint, radius: CGFloat) -> CGFloat? {
        let start = from - centerFrom, delta = (to - from) - (centerTo - centerFrom)
        let c = start.x * start.x + start.y * start.y - radius * radius
        if c <= 0 { return 0 }
        let a = delta.x * delta.x + delta.y * delta.y
        guard a > 0 else { return nil }
        let b = 2 * (start.x * delta.x + start.y * delta.y)
        let disc = b * b - 4 * a * c
        guard disc >= 0 else { return nil }
        let t = (-b - sqrt(disc)) / (2 * a)
        return t >= 0 && t <= 1 ? t : nil
    }

    func step(_ raw: TimeInterval, direction: CGPoint) {
        guard !held, !player.isDead, raw.isFinite, raw > 0,
              direction.x.isFinite, direction.y.isFinite else { return }
        // Bound stalls; no catch-up volleys. Direction never exceeds joystick 1.
        let dt = min(raw, C.maximumStep)
        elapsed += dt; damageCooldown = max(0, damageCooldown - dt)
        let oldPlayer = player.position
        player.move(direction: direction.length > 1 ? direction.normalized : direction, deltaTime: dt)
        let oldEnemy = enemy?.position
        if let actor = enemy, !actor.isDying {
            _ = actor.updateStatusEffects(deltaTime: dt)
            let radius = actor.geometryFootprintRadius
            if let goal = geometry.approach(player.position, radius: radius) {
                let next: CGPoint?
                if !geometry.geometry.segmentBlockedExact(actor.position, goal, travelRadius: radius) { next = goal }
                else { next = geometry.geometry.graphWaypoint(from: actor.position, toward: goal, travelRadius: radius,
                                                               arriveRadius: GameConfig.Arena8Prototype.arrival)?.position }
                if let next {
                    let start = actor.position
                    let travel = start.distance(to: next)
                    // Real chase respects the enemy's existing speed/statuses;
                    // constrain overshoot to waypoint, then sweep the actual move.
                    actor.chase(target: next, deltaTime: min(dt, Double(travel / max(1, actor.moveSpeed))))
                    actor.position = geometry.move(from: start, toward: actor.position, radius: radius) ?? start
                }
            }
        }
        let existingShots = Set(projectiles.map { ObjectIdentifier($0) })
        shotClock += dt
        if firing, shotClock >= stats.effectiveFireInterval {
            shotClock = 0
            if let actor = enemy, !actor.isDying,
               player.position.distance(to: actor.position) <= stats.effectiveProjectileRange,
               geometry.shotClear(from: player.position, to: actor.position, longShot: longShot) {
                fire(toward: actor.position)
            }
        }
        for shot in projectiles {
            let from = shot.position
            let expired = shot.move(deltaTime: dt)
            let to = shot.position
            if expired { shot.removeFromParent(); continue }
            // Find wall point before resolving a swept enemy hit, so a hit
            // beyond a wall in the SAME frame cannot sneak through.
            let blocked = !shot.passesTerrain && geometry.geometry.segmentBlockedExact(from, to)
            var consumed = false
            if let actor = enemy, !actor.isDying, !shot.hasStruck(actor),
               let t = Self.contactFraction(from: from, to: to, centerFrom: existingShots.contains(ObjectIdentifier(shot)) ? (oldEnemy ?? actor.position) : actor.position,
                    centerTo: actor.position, radius: actor.hitBodyRadius + GameConfig.Projectile.radius) {
                let contactPoint = from + (to - from) * t
                if shot.passesTerrain || !geometry.geometry.segmentBlockedExact(from, contactPoint) {
                    // Base loadout only: no statuses, crit, Forge or extra riders.
                    let hit = DirectHitDamage.resolve(max(1, Int(shot.damageMultiplier)), .onEnemy(
                        permafrostBonus: 0, slowed: actor.isSlowed, arenaSlowed: false,
                        brittleCold: false, brittleColdFactor: 1, frozen: actor.isFrozen, stunned: actor.isStunned,
                        openWoundsBonus: 0, bleeding: actor.isBleeding), overcharge: 1,
                        vulnerability: actor.vulnerabilityMultiplier, rounding: shot.hitRounding)
                    hits += 1
                    let killed = actor.takeDirectHit(hit.targetEntry)
                    consumed = shot.onHitEnemy(actor)
                    if killed { creditKill(actor) }
                }
            }
            let cleanup = !Arena8P0Bounds.rectangle(GameConfig.Arena8Prototype.world.insetBy(
                dx: -GameConfig.Neutral.projectileCleanupMargin, dy: -GameConfig.Neutral.projectileCleanupMargin)).contains(to)
            if blocked { blockedShots += 1 }
            if expired || blocked || consumed || cleanup { shot.removeFromParent() }
        }
        projectiles.removeAll { $0.parent == nil }
        if let actor = enemy, !actor.isDying, damageCooldown <= 0,
           Self.contactFraction(from: oldPlayer, to: player.position, centerFrom: oldEnemy ?? actor.position,
                                centerTo: actor.position, radius: stats.effectiveCollisionRadius + actor.hitBodyRadius) != nil,
           !geometry.geometry.segmentBlockedExact(player.position, actor.position) {
            var hit = PlayerDamagePipeline.Hit(raw: GameConfig.Enemy.baseMeleeDamage)
            hit.flatDEF = stats.effectiveFlatDEF
            let outcome = PlayerDamagePipeline.resolve(hit, against: stats.damageDefender, tuning: GameConfig.DamagePipeline.tuning)
            stats.commit(outcome); damageCooldown = GameConfig.Player.damageCooldown
            if outcome.died { player.die(); root.isPaused = true; return }
        }
        for orb in orbs {
            let from = orb.position
            orb.updateMagnet(playerPosition: player.position, pickupRadius: stats.effectivePickupRadius, deltaTime: dt)
            // XP uses actual magnet movement, clamped without wall tunneling.
            orb.position = geometry.move(from: from, toward: orb.position, radius: C.xpRadius) ?? from
            if Self.contactFraction(from: from, to: orb.position, centerFrom: oldPlayer, centerTo: player.position,
                                    radius: stats.effectiveCollisionRadius + C.xpRadius) != nil,
               !geometry.geometry.segmentBlockedExact(orb.position, player.position) {
                orb.collect(); _ = player.addXP(orb.xpValue); collected += orb.xpValue
            }
        }
        orbs.removeAll { $0.physicsBody?.categoryBitMask == 0 }
    }

    private func creditKill(_ actor: EnemyNode) {
        guard !actor.killCredited else { return }
        actor.killCredited = true; kills += 1; enemy = nil
        let orb = XPOrbNode(xpValue: actor.xpValue)
        // Visual enemy radius exceeds the XP radius, so a legal death position
        // always fits; validate nevertheless instead of unsafe fallback.
        guard geometry.valid(actor.position, radius: C.xpRadius) else { return }
        orb.position = actor.position; disablePhysicsResponse(orb)
        root.addChild(orb); orbs.append(orb)
    }
}
#endif
