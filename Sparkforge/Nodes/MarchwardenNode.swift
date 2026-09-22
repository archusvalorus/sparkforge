// MarchwardenNode.swift
// Sparkforge
//
// v2.1 (Geometry Unit 3) — Arena 6 boss: The Marchwarden.
// Built to keep war columns moving through the Splitworks. The column is
// gone. The road is broken. It keeps clearing the route, and now categorizes
// the player as an obstruction. Thesis (lock §6): "The boss does not change
// the arena. It demonstrates mastery over the arena that already exists."
//
// Three verbs, cycled:
//   Right of Way  — DECLARES one route (lane floor lights, high contrast),
//                   runs to its near end, then COMMITS to a passage charge it
//                   cannot steer; stops at the far end, the wall, or the
//                   Carrier; recovers visibly.
//   Standardfall  — arcing standards land on the player's side of the
//                   Carrier (the canonized sky-strike exemption — it crosses
//                   the obstacle so cover can't be camped); each landing zone
//                   is individually telegraphed and resolved onto VALID ground.
//   Muster Signal — lights the gate opposite the boss, then a small bounded
//                   packet enters there (scene-spawned through the authored
//                   spawn zones). Bounded, never a flood.
// Escalation — The Column Advances (< 35% HP): faster cadence; chains
// Standardfall → Right of Way; the Carrier ignites in sequence (visual only).
// Fairness: one verb resolves at a time; a charge, a muster entrance and a
// standard impact never land together.
// Tunables in GameConfig.Marchwarden.

import SpriteKit

final class MarchwardenNode: SKNode, ArenaBossNode {

    // MARK: - State

    private(set) var health: Int
    private(set) var maxHealth: Int
    private(set) var isDead = false
    var vulnerabilityMultiplier: CGFloat = 1.0
    var challengeFlatReduction: Int = 0
    var healthPercent: CGFloat { maxHealth > 0 ? CGFloat(health) / CGFloat(maxHealth) : 0 }
    let contactDamage: Int = GameConfig.Marchwarden.contactDamage
    var geometryFootprintRadius: CGFloat { GameConfig.Marchwarden.bodyRadius }

    var isAdvancing: Bool { healthPercent < GameConfig.Marchwarden.advanceThreshold && !isDead }
    private var advanceTriggered = false

    // MARK: - Scene wiring

    /// The authored routes as (south, north) pairs.
    var lanes: (() -> [(CGPoint, CGPoint)])?
    /// Mid-angles of the authored gate zones.
    var gateAngles: (() -> [CGFloat])?
    /// Resolve a landing point onto valid ground.
    var resolveGround: ((CGPoint) -> CGPoint)?
    var onHazardDamage: ((Int) -> Void)?
    var onChargeShove: ((CGPoint) -> Void)?
    var onMuster: ((Int) -> Void)?
    var onColumnAdvances: (() -> Void)?
    var onCharge: (() -> Void)?
    var onStandardLanded: (() -> Void)?
    var onDeath: ((CGPoint, Int) -> Void)?
    /// v2.1 A4b: fires once, synchronously, on the killing blow — before the
    /// death plays out — with the damage it dealt to remaining HP.
    var onLethalHit: ((Int) -> Void)?

    // MARK: - Phase machine

    enum Phase { case idle, declare, charge, standardfall, muster, recover }
    private(set) var phase: Phase = .idle
    private var attackTimer: TimeInterval = 3.0
    private var phaseTimer: TimeInterval = 0
    private var verbIndex = 0
    private var chainNext: Phase? = nil

    // Right of Way working state
    private var laneStart: CGPoint = .zero
    private var laneEnd: CGPoint = .zero
    private var chargeDir: CGPoint = .zero
    private var laneMark: SKShapeNode? = nil
    private var lastPosition: CGPoint = .zero

    // Standardfall working state
    private struct PendingStandard { let worldPos: CGPoint; var remaining: TimeInterval; let marker: SKShapeNode }
    private var pending: [PendingStandard] = []
    private var standardsRemaining = 0
    private var standardSpawnTimer: TimeInterval = 0
    private var standardTarget: CGPoint = .zero
    private var standardBaseAngle: CGFloat = 0

    // Muster working state
    private var musterGate = 0
    private var musterMark: SKShapeNode? = nil

    // MARK: - Visuals

    private let core: SKShapeNode
    private let rim: SKShapeNode
    private let plow: SKShapeNode
    private let mast: SKShapeNode
    private let banner: SKShapeNode
    private let chassis = SKNode()
    private var seams: [SKShapeNode] = []
    private let hpBarBG: SKShapeNode
    private let hpBarFill: SKShapeNode
    private let nameLabel: SKLabelNode

    // MARK: - Init

    init(hpScaling: Int = 0) {
        let C = GameConfig.Marchwarden.self
        health = C.baseHealth + hpScaling
        maxHealth = C.baseHealth + hpScaling
        let r = C.bodyRadius

        core = SKShapeNode(circleOfRadius: r)
        core.fillColor = SKColor(hex: 0x1A1816)
        core.strokeColor = .clear
        core.zPosition = 5

        rim = SKShapeNode(circleOfRadius: r + 3)
        rim.fillColor = .clear
        rim.strokeColor = SKColor(hex: 0x3F8F8A, alpha: 0.85)
        rim.lineWidth = 3
        rim.glowWidth = 8
        rim.zPosition = 4

        // Plow face ahead (+x = facing) — a gate segment that learned to march.
        plow = SKShapeNode(path: CGPath(roundedRect: CGRect(x: r * 0.7, y: -r * 1.35, width: r * 0.7, height: r * 2.7),
                                        cornerWidth: r * 0.12, cornerHeight: r * 0.12, transform: nil))
        plow.fillColor = SKColor(hex: 0x2A2622)
        plow.strokeColor = SKColor(hex: 0xD9D2C4, alpha: 0.8)
        plow.lineWidth = 1.5
        plow.zPosition = 6

        // Signal standard: a mast behind the core with a kiln-orange banner.
        mast = SKShapeNode(rect: CGRect(x: -r * 0.9, y: -r * 0.12, width: r * 0.24, height: r * 2.2))
        mast.fillColor = SKColor(hex: 0x24211E)
        mast.strokeColor = SKColor(hex: 0x3F8F8A, alpha: 0.8)
        mast.lineWidth = 1
        mast.zPosition = 7

        let bp = CGMutablePath()
        bp.move(to: CGPoint(x: -r * 0.66, y: r * 2.05))
        bp.addLine(to: CGPoint(x: r * 0.35, y: r * 1.75))
        bp.addLine(to: CGPoint(x: -r * 0.66, y: r * 1.45))
        bp.closeSubpath()
        banner = SKShapeNode(path: bp)
        banner.fillColor = SKColor(hex: 0xFF7722)
        banner.strokeColor = SKColor(hex: 0xFFB84D, alpha: 0.9)
        banner.lineWidth = 1
        banner.glowWidth = 3
        banner.zPosition = 8

        let barW = r * 2.4, barH: CGFloat = 5
        hpBarBG = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 2)
        hpBarBG.fillColor = SKColor(hex: 0x1A1A1E)
        hpBarBG.strokeColor = SKColor(hex: 0x3F8F8A, alpha: 0.5)
        hpBarBG.lineWidth = 0.5
        hpBarBG.position = CGPoint(x: 0, y: r + 22)
        hpBarBG.zPosition = 9
        hpBarFill = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 2)
        hpBarFill.fillColor = SKColor(hex: 0x3F8F8A)
        hpBarFill.strokeColor = .clear
        hpBarFill.position = CGPoint(x: 0, y: r + 22)
        hpBarFill.zPosition = 10
        nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = "The Marchwarden"
        nameLabel.fontSize = 9
        nameLabel.fontColor = SKColor(hex: 0x9FE0DB)
        nameLabel.position = CGPoint(x: 0, y: r + 31)
        nameLabel.zPosition = 9

        super.init()

        addChild(rim); addChild(core)
        chassis.zPosition = 6
        addChild(chassis)
        chassis.addChild(plow); chassis.addChild(mast); chassis.addChild(banner)
        for dy: CGFloat in [-0.8, 0, 0.8] {
            let seam = SKShapeNode()
            let sp = CGMutablePath()
            sp.move(to: CGPoint(x: r * 0.78, y: r * dy)); sp.addLine(to: CGPoint(x: r * 1.32, y: r * dy))
            seam.path = sp
            seam.strokeColor = SKColor(hex: 0xFF7722, alpha: 0.45)
            seam.lineWidth = 1.5; seam.glowWidth = 2; seam.zPosition = 7
            chassis.addChild(seam); seams.append(seam)
        }
        // Two kiln-orange eyes on the core.
        for dx: CGFloat in [-0.32, 0.32] {
            let eye = SKShapeNode(circleOfRadius: 3.5)
            eye.fillColor = SKColor(hex: 0xFF7722); eye.strokeColor = .clear; eye.glowWidth = 3
            eye.position = CGPoint(x: r * dx, y: r * 0.18); eye.zPosition = 6
            addChild(eye)
        }
        addChild(hpBarBG); addChild(hpBarFill); addChild(nameLabel)
        setupPhysics()
        rim.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.run { [weak self] in self?.rim.glowWidth = 12 }, SKAction.wait(forDuration: 0.9),
            SKAction.run { [weak self] in self?.rim.glowWidth = 6 },  SKAction.wait(forDuration: 0.9)
        ])))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: GameConfig.Marchwarden.bodyRadius * 0.85)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = GameConfig.Physics.enemy
        body.contactTestBitMask = GameConfig.Physics.player | GameConfig.Physics.projectile
        body.collisionBitMask = 0
        body.linearDamping = 0
        body.friction = 0
        physicsBody = body
    }

    // MARK: - Update

    func update(deltaTime dt: TimeInterval, playerPosition: CGPoint) {
        guard !isDead else { return }
        updateHPBar()
        checkAdvance()
        tickStandards(dt: dt, playerPosition: playerPosition)

        switch phase {
        case .idle:
            let dir = (playerPosition - position).normalized
            position += dir * GameConfig.Marchwarden.idleSpeed * CGFloat(dt)
            face(dir)
            attackTimer -= dt
            if attackTimer <= 0 { beginNextVerb(playerPosition: playerPosition) }

        case .declare:
            // Run to the lane's near end while the floor lights; then commit.
            phaseTimer -= dt
            let toStart = laneStart - position
            if toStart.length > 10 {
                position += toStart.normalized * GameConfig.Marchwarden.declareRunSpeed * CGFloat(dt)
            }
            face(chargeDir)
            if phaseTimer <= 0 { beginCharge() }

        case .charge:
            let C = GameConfig.Marchwarden.self
            // The scene's resolve pass displaces us off the Carrier: a stalled
            // position IS the wall. Same for the arena rim.
            let step = C.chargeSpeed * CGFloat(dt)
            let before = position   // post-resolve position from last frame
            // Stalled on iron: last frame we asked for `lastPosition`; if the
            // scene's resolve pass pushed us back along the lane by most of a
            // step, the Carrier has ended the charge.
            if lastPosition != .zero, (lastPosition - before).dot(chargeDir) > step * 0.5 {
                endCharge(); return
            }
            position += chargeDir * step
            lastPosition = position
            let limit = GameConfig.Arena.radius - C.bodyRadius
            if position.length > limit { position = position.normalized * limit; endCharge(); return }
            if (position - laneEnd).dot(chargeDir) >= 0 { endCharge(); return }   // passed the far end

        case .standardfall:
            standardSpawnTimer -= dt
            if standardsRemaining > 0, standardSpawnTimer <= 0 {
                dropStandard(index: GameConfig.Marchwarden.standardCount - standardsRemaining)
                standardsRemaining -= 1
                standardSpawnTimer = GameConfig.Marchwarden.standardStagger
            }
            if standardsRemaining == 0, pending.isEmpty { enterRecover(GameConfig.Marchwarden.recoverAfterVerb) }

        case .muster:
            phaseTimer -= dt
            if phaseTimer <= 0 {
                onMuster?(musterGate)
                musterMark?.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.3), SKAction.removeFromParent()]))
                musterMark = nil
                enterRecover(GameConfig.Marchwarden.recoverAfterVerb)
            }

        case .recover:
            phaseTimer -= dt
            if phaseTimer <= 0 {
                if let next = chainNext {
                    chainNext = nil
                    start(next, playerPosition: playerPosition)
                } else {
                    phase = .idle
                    attackTimer = GameConfig.Marchwarden.attackCooldown * (isAdvancing ? GameConfig.Marchwarden.advanceCadenceScale : 1.0)
                }
            }
        }
    }

    private func face(_ dir: CGPoint) {
        guard dir.x != 0 || dir.y != 0 else { return }
        chassis.zRotation = atan2(dir.y, dir.x)
    }

    // MARK: - Verb dispatch

    private func beginNextVerb(playerPosition: CGPoint) {
        let cycle: [Phase] = [.declare, .standardfall, .muster]
        let next = cycle[verbIndex % cycle.count]
        verbIndex += 1
        // The Column Advances: Standardfall chains straight into Right of Way.
        if isAdvancing && next == .standardfall { chainNext = .declare }
        start(next, playerPosition: playerPosition)
    }

    private func start(_ verb: Phase, playerPosition: CGPoint) {
        switch verb {
        case .declare: beginDeclare(playerPosition: playerPosition)
        case .standardfall: beginStandardfall(playerPosition: playerPosition)
        case .muster: beginMuster()
        default: break
        }
    }

    private func enterRecover(_ t: TimeInterval) {
        phase = .recover
        phaseTimer = t
        for s in seams { s.removeAllActions(); s.strokeColor = SKColor(hex: 0xFF7722, alpha: 0.45) }
    }

    // MARK: - Right of Way

    private func beginDeclare(playerPosition: CGPoint) {
        let C = GameConfig.Marchwarden.self
        let all = lanes?() ?? []
        // Declare the lane on the PLAYER's side of the yard (x sign), so the
        // charge is pressure, not theatre. No lanes (open arena) → straight at Spark.
        let chosen: (CGPoint, CGPoint)
        if let lane = all.min(by: { abs($0.0.x - playerPosition.x) < abs($1.0.x - playerPosition.x) }) {
            // Enter from whichever end is nearer the warden; charge to the other.
            let dS = position.distance(to: lane.0), dN = position.distance(to: lane.1)
            chosen = dS <= dN ? lane : (lane.1, lane.0)
        } else {
            let dir = (playerPosition - position).normalized
            chosen = (position, position + dir * GameConfig.Arena.radius * 1.2)
        }
        laneStart = chosen.0; laneEnd = chosen.1
        chargeDir = (laneEnd - laneStart).normalized
        lastPosition = .zero
        phase = .declare
        phaseTimer = C.declareDuration

        // High-contrast floor signal along the whole lane (world space).
        guard let field = parent else { return }
        let len = laneStart.distance(to: laneEnd)
        let mark = SKShapeNode(rect: CGRect(x: 0, y: -C.laneWidth / 2, width: len, height: C.laneWidth), cornerRadius: 8)
        mark.position = laneStart
        mark.zRotation = atan2(chargeDir.y, chargeDir.x)
        mark.fillColor = SKColor(hex: 0xFF7722, alpha: 0.05)
        mark.strokeColor = SKColor(hex: 0xD9D2C4, alpha: 0.2)
        mark.lineWidth = 2
        mark.glowWidth = 3
        mark.zPosition = 1.5
        field.addChild(mark)
        laneMark = mark
        mark.run(SKAction.customAction(withDuration: C.declareDuration) { node, t in
            let f = CGFloat(t / C.declareDuration)
            (node as? SKShapeNode)?.fillColor = SKColor(hex: 0xFF7722, alpha: 0.05 + 0.2 * f)
            (node as? SKShapeNode)?.strokeColor = SKColor(hex: 0xD9D2C4, alpha: 0.2 + 0.75 * f)
        })
        for s in seams { s.run(SKAction.customAction(withDuration: C.declareDuration) { node, t in
            (node as? SKShapeNode)?.strokeColor = SKColor(hex: 0xFF7722, alpha: 0.45 + 0.55 * CGFloat(t / C.declareDuration))
        }) }
        banner.run(SKAction.sequence([SKAction.scale(to: 1.3, duration: 0.2), SKAction.scale(to: 1.0, duration: 0.2)]))
    }

    private func beginCharge() {
        phase = .charge
        onCharge?()
        laneMark?.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.5), SKAction.removeFromParent()]))
        laneMark = nil
    }

    private func endCharge() {
        let C = GameConfig.Marchwarden.self
        // Visible recovery after the strongest commitment (lock fairness).
        chassis.run(SKAction.sequence([
            SKAction.moveBy(x: -chargeDir.x * 8, y: -chargeDir.y * 8, duration: 0.06),
            SKAction.moveBy(x: chargeDir.x * 8, y: chargeDir.y * 8, duration: 0.25)
        ]))
        enterRecover(C.recoverAfterCharge)
    }

    /// The scene reports a body contact during the charge: shove along the line.
    func chargeConnected() {
        guard phase == .charge else { return }
        onChargeShove?(chargeDir)
        endCharge()
    }

    // MARK: - Standardfall

    private func beginStandardfall(playerPosition: CGPoint) {
        phase = .standardfall
        standardTarget = playerPosition
        standardBaseAngle = CGFloat.random(in: 0...(2 * .pi))
        standardsRemaining = GameConfig.Marchwarden.standardCount
        standardSpawnTimer = 0
        banner.run(SKAction.sequence([SKAction.scale(to: 1.4, duration: 0.15), SKAction.scale(to: 1.0, duration: 0.25)]))
    }

    private func dropStandard(index: Int) {
        let C = GameConfig.Marchwarden.self
        guard let field = parent else { return }
        // Around where Spark WAS when the verb began — an ordered arc, never a
        // shotgun; landing zones resolved onto valid ground (never inside the
        // Carrier), so the exemption crosses geometry but leaves no bad state.
        let a = standardBaseAngle + CGFloat(index) * (2 * .pi / CGFloat(C.standardCount))
        let raw = CGPoint(x: standardTarget.x + cos(a) * C.standardReach, y: standardTarget.y + sin(a) * C.standardReach)
        let p = resolveGround?(raw) ?? raw

        let ring = SKShapeNode(circleOfRadius: C.standardRadius)
        ring.position = p
        ring.fillColor = SKColor(hex: 0xFF7722, alpha: 0.06)
        ring.strokeColor = SKColor(hex: 0xD9D2C4, alpha: 0.85)
        ring.lineWidth = 2
        ring.glowWidth = 3
        ring.zPosition = 1.5
        field.addChild(ring)
        // A falling standard: the inner marker contracts toward impact.
        let inner = SKShapeNode(circleOfRadius: C.standardRadius)
        inner.fillColor = .clear
        inner.strokeColor = SKColor(hex: 0xFF7722, alpha: 0.9)
        inner.lineWidth = 1.5
        inner.position = p
        inner.zPosition = 1.6
        field.addChild(inner)
        let contract = SKAction.scale(to: 0.1, duration: C.standardDelay)
        contract.timingMode = .easeIn
        inner.run(SKAction.sequence([contract, SKAction.removeFromParent()]))

        pending.append(PendingStandard(worldPos: p, remaining: C.standardDelay, marker: ring))
    }

    private func tickStandards(dt: TimeInterval, playerPosition: CGPoint) {
        guard !pending.isEmpty else { return }
        let C = GameConfig.Marchwarden.self
        var landed: [Int] = []
        for i in pending.indices {
            pending[i].remaining -= dt
            if pending[i].remaining <= 0 { landed.append(i) }
        }
        for i in landed.reversed() {
            let s = pending.remove(at: i)
            s.marker.removeFromParent()
            impactFlash(at: s.worldPos)
            onStandardLanded?()
            if playerPosition.distance(to: s.worldPos) <= C.standardRadius {
                onHazardDamage?(C.standardDamage)
            }
        }
    }

    private func impactFlash(at p: CGPoint) {
        guard let field = parent else { return }
        let C = GameConfig.Marchwarden.self
        // The standard plants: a spike silhouette + a burst ring.
        let spike = SKShapeNode(rect: CGRect(x: -3, y: 0, width: 6, height: C.standardRadius * 0.9))
        spike.fillColor = SKColor(hex: 0xD9D2C4); spike.strokeColor = .clear; spike.glowWidth = 2
        spike.position = p; spike.zPosition = 3
        field.addChild(spike)
        spike.run(SKAction.sequence([SKAction.wait(forDuration: 0.7), SKAction.fadeOut(withDuration: 0.4), SKAction.removeFromParent()]))
        let flash = SKShapeNode(circleOfRadius: C.standardRadius)
        flash.position = p
        flash.fillColor = SKColor(hex: 0xFF7722, alpha: 0.45)
        flash.strokeColor = SKColor(hex: 0xFFFFFF, alpha: 0.9)
        flash.lineWidth = 3; flash.glowWidth = 8; flash.zPosition = 5
        field.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 1.3, duration: 0.2), SKAction.fadeOut(withDuration: 0.2)]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Muster Signal

    private func beginMuster() {
        let C = GameConfig.Marchwarden.self
        phase = .muster
        phaseTimer = C.musterSignalDuration
        let angles = gateAngles?() ?? []
        // The gate OPPOSITE the warden (largest angular distance).
        let mine = atan2(position.y, position.x)
        func gap(_ a: CGFloat) -> CGFloat { let d = abs(atan2(sin(a - mine), cos(a - mine))); return d }
        musterGate = angles.indices.max(by: { gap(angles[$0]) < gap(angles[$1]) }) ?? 0

        // Signal: the banner flares and the chosen gate arc lights at the rim.
        banner.run(SKAction.repeat(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.12), SKAction.fadeAlpha(to: 1.0, duration: 0.12)
        ]), count: 3))
        guard let field = parent, angles.indices.contains(musterGate) else { return }
        let a = angles[musterGate]
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: GameConfig.Arena.radius + 8, startAngle: a - 0.16, endAngle: a + 0.16, clockwise: false)
        let arc = SKShapeNode(path: path)
        arc.strokeColor = SKColor(hex: 0xFF7722, alpha: 0.95)
        arc.lineWidth = 6; arc.glowWidth = 10; arc.zPosition = 2
        field.addChild(arc)
        arc.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.35, duration: 0.15), SKAction.fadeAlpha(to: 1.0, duration: 0.15)
        ])))
        musterMark = arc
    }

    // MARK: - Escalation

    private func checkAdvance() {
        guard isAdvancing, !advanceTriggered else { return }
        advanceTriggered = true
        onColumnAdvances?()
        rim.strokeColor = SKColor(hex: 0xFF7722, alpha: 0.9)
        hpBarFill.fillColor = SKColor(hex: 0xFF7722)
        nameLabel.text = "The Marchwarden — the column advances"
    }

    // MARK: - HP / damage / death

    private func updateHPBar() {
        let barW = GameConfig.Marchwarden.bodyRadius * 2.4, barH: CGFloat = 5
        let fillW = max(1, barW * healthPercent)
        hpBarFill.path = CGPath(roundedRect: CGRect(x: -barW / 2, y: -barH / 2, width: fillW, height: barH),
                                cornerWidth: 2, cornerHeight: 2, transform: nil)
    }

    func applyChallengeHealthScale(_ factor: CGFloat) {
        guard factor != 1.0 else { return }
        maxHealth = max(1, Int((CGFloat(maxHealth) * factor).rounded()))
        health = maxHealth
    }

    /// v2.1 A4a: status row pinned just right of the HP bar.
    var statusTellAnchor: CGPoint { CGPoint(x: GameConfig.Marchwarden.bodyRadius * 1.2 + 6, y: GameConfig.Marchwarden.bodyRadius + 22) }

    @discardableResult
    func takeDamage(_ amount: Int, ignoresChallengeDEF: Bool) -> Bool {
        guard !isDead else { return false }
        let scaled = vulnerabilityMultiplier == 1.0 ? amount : Int((CGFloat(amount) * vulnerabilityMultiplier).rounded())
        let healthBefore = health
        let dealt = challengedDamage(scaled, raw: amount, ignoresChallengeDEF: ignoresChallengeDEF)
        health -= dealt
        core.removeAction(forKey: "hit")
        core.run(SKAction.sequence([
            SKAction.run { [weak self] in self?.core.fillColor = SKColor(hex: 0x3F8F8A, alpha: 0.6) },
            SKAction.wait(forDuration: 0.06),
            SKAction.run { [weak self] in self?.core.fillColor = SKColor(hex: 0x1A1816) }
        ]), withKey: "hit")
        if health <= 0 { health = 0; die(); onLethalHit?(min(dealt, healthBefore)); return true }
        return false
    }

    private func die() {
        isDead = true
        physicsBody?.categoryBitMask = 0
        phase = .idle
        cleanupWorldEffects()
        hpBarBG.run(SKAction.fadeOut(withDuration: 0.2))
        hpBarFill.run(SKAction.fadeOut(withDuration: 0.2))
        nameLabel.run(SKAction.fadeOut(withDuration: 0.2))
        // The march ends: the banner falls, the plow drops, the core goes dark.
        banner.run(SKAction.group([SKAction.rotate(byAngle: -1.2, duration: 0.5), SKAction.fadeOut(withDuration: 0.6)]))
        plow.run(SKAction.group([SKAction.moveBy(x: 10, y: -14, duration: 0.5), SKAction.fadeOut(withDuration: 0.6)]))
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.6),
            SKAction.group([SKAction.scale(to: 0.0, duration: 0.4), SKAction.fadeOut(withDuration: 0.4)]),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.onDeath?(self.position, GameConfig.Marchwarden.xpReward)
            },
            SKAction.removeFromParent()
        ]))
    }

    /// Clean up world-space marks if the run ends mid-verb.
    func cleanupWorldEffects() {
        laneMark?.removeFromParent(); laneMark = nil
        musterMark?.removeFromParent(); musterMark = nil
        for s in pending { s.marker.removeFromParent() }
        pending.removeAll()
    }
}
