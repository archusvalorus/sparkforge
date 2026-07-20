// DynamoChoirNode.swift
// Sparkforge
//
// v1.7 Arena 3 boss (Lyra canon): The Dynamo Choir.
// The Warden was pressure and containment; the Choir is rhythm and
// conduction. It does not get angry — it finds tempo.
//
// Three patterns, all on the beat:
//   Circuit Litany — nodes preview, conduits connect, the pulse fires.
//     The arena becomes a diagram; the chain never closes (escape gaps).
//   Polarity Hymn — pull, push, then SNAP nearby enemies toward the
//     player's path (never onto the player). A conductor changing
//     polarity, not the Warden's field.
//   Broken Measure — four singers fire on the beat; one stutters and
//     misfires. The player learns to trust the broken beat.
// Enrage (Full Current, <30% HP): faster sequencing, shorter rests,
// tighter patterns. "More precise, not merely louder."

import SpriteKit

final class DynamoChoirNode: SKNode, ArenaBossNode {

    // MARK: - Tuning

    static let baseHP = 85
    static let idleSpeed: CGFloat = 38
    static let bodyRadius: CGFloat = 32
    static let xpReward = 70
    static let attackCooldown: TimeInterval = 3.0

    // Circuit Litany — three-beat tell
    private var litanyPreviewTime: TimeInterval { isEnraged ? 0.55 : 0.85 }
    private var litanyConnectTime: TimeInterval { isEnraged ? 0.40 : 0.60 }
    private var litanyPulseTime: TimeInterval { isEnraged ? 0.45 : 0.55 }
    static let litanyNodeCount = 5
    static let litanyRadius: CGFloat = 135
    static let litanyDamage = 20
    static let litanyHitDistance: CGFloat = 14

    // Polarity Hymn — (time, strength, duration); snap fires separately
    private var hymnPulses: [(time: TimeInterval, strength: CGFloat, duration: TimeInterval)] {
        let lead: TimeInterval = isEnraged ? 0.35 : 0.5
        return [
            (lead,       300, 0.35),   // pull in
            (lead + 0.8, -380, 0.35)   // push out
        ]
    }
    private var hymnSnapTime: TimeInterval { isEnraged ? 1.75 : 2.1 }
    static let hymnDuration: TimeInterval = 2.9
    static let hymnSnapRadius: CGFloat = 260

    // Broken Measure — four singers, twelve beats, one liar per measure
    private var beatInterval: TimeInterval { isEnraged ? 0.40 : 0.55 }
    static let measureBeats = 12
    static let beatFanCount = 3
    static let beatFanSpread: CGFloat = 0.35

    // MARK: - State

    private(set) var health: Int
    var vulnerabilityMultiplier: CGFloat = 1.0   // v1.9: capstone-debuff vulnerability
    private(set) var maxHealth: Int
    private(set) var isDead: Bool = false

    var healthPercent: CGFloat {
        guard maxHealth > 0 else { return 0 }
        return CGFloat(health) / CGFloat(maxHealth)
    }

    let contactDamage: Int = 35
    var isEnraged: Bool { healthPercent < 0.3 && !isDead }
    private var enrageTriggered = false

    // MARK: - Callbacks (GameScene wires these)

    var onFireProjectile: ((_ position: CGPoint, _ direction: CGPoint) -> Void)?
    var onLineDamage: ((_ damage: Int) -> Void)?
    /// strength: points/sec toward the boss when positive; away when negative
    var onFieldPulse: ((_ strength: CGFloat, _ duration: TimeInterval) -> Void)?
    /// Pulse 3: snap enemies within the radius toward the player's path
    var onEnemySnap: ((_ radius: CGFloat) -> Void)?
    var onDeath: ((_ position: CGPoint, _ xpReward: Int) -> Void)?

    // MARK: - Phase Machine

    enum Phase {
        case idle
        case windingUp
        case circuitLitany
        case polarityHymn
        case brokenMeasure
        case recovering
    }

    private(set) var phase: Phase = .idle
    private var attackTimer: TimeInterval = 3.0
    private var phaseTimer: TimeInterval = 0
    private var attackIndex: Int = 0

    // Litany working state (world-space)
    private var litanyPoints: [CGPoint] = []
    private var litanyDots: [SKShapeNode] = []
    private var litanyLines: [SKShapeNode] = []
    private var litanyBeat = 0  // 0 preview, 1 connect, 2 pulse

    // Hymn working state
    private var firedHymnPulses = 0
    private var hymnSnapFired = false

    // Measure working state
    private var beatTimer: TimeInterval = 0
    private var beatsPlayed = 0
    private var brokenSinger = Int.random(in: 0...3)

    // MARK: - Visual Nodes

    private let bodyNode: SKShapeNode
    private let needleNode: SKShapeNode  // the metronome — ticks, never sweeps
    private let seamNode: SKShapeNode    // vertical seam eye
    private var singers: [SKShapeNode] = []
    private var singerOrbits: [SKNode] = []
    private let hpBarBG: SKShapeNode
    private let hpBarFill: SKShapeNode
    private let nameLabel: SKLabelNode

    // MARK: - Init

    init(hpScaling: Int = 0) {
        self.health = DynamoChoirNode.baseHP + hpScaling
        self.maxHealth = DynamoChoirNode.baseHP + hpScaling

        let r = DynamoChoirNode.bodyRadius

        // Brass machine core
        bodyNode = SKShapeNode(circleOfRadius: r)
        bodyNode.fillColor = SKColor(hex: 0x16171A)
        bodyNode.strokeColor = SKColor(hex: 0x5B4A22, alpha: 0.8)
        bodyNode.lineWidth = 2
        bodyNode.zPosition = 5

        // The metronome needle — a thin brass pointer that TICKS
        needleNode = SKShapeNode(rectOf: CGSize(width: 2.5, height: r * 0.85), cornerRadius: 1)
        needleNode.fillColor = SKColor(hex: 0xF6D36B)
        needleNode.strokeColor = .clear
        needleNode.glowWidth = 1.5
        needleNode.position = CGPoint(x: 0, y: r * 0.28)
        needleNode.zPosition = 6

        // Vertical seam — the Choir's mouth, glows when it sings
        seamNode = SKShapeNode(rectOf: CGSize(width: 2, height: r * 0.7), cornerRadius: 1)
        seamNode.fillColor = SKColor(hex: 0xF6D36B, alpha: 0.5)
        seamNode.strokeColor = .clear
        seamNode.position = CGPoint(x: 0, y: -r * 0.35)
        seamNode.zPosition = 6

        // HP bar + name (boss styling, static-gold palette)
        let barW: CGFloat = r * 2
        let barH: CGFloat = 5

        hpBarBG = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 2)
        hpBarBG.fillColor = SKColor(hex: 0x1A1A14)
        hpBarBG.strokeColor = SKColor(hex: 0x44402E, alpha: 0.5)
        hpBarBG.lineWidth = 0.5
        hpBarBG.position = CGPoint(x: 0, y: r + 18)
        hpBarBG.zPosition = 7

        hpBarFill = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 2)
        hpBarFill.fillColor = SKColor(hex: 0xF6D36B)
        hpBarFill.strokeColor = .clear
        hpBarFill.position = CGPoint(x: 0, y: r + 18)
        hpBarFill.zPosition = 8

        nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = "The Dynamo Choir"
        nameLabel.fontSize = 9
        nameLabel.fontColor = SKColor(hex: 0xF6D36B)
        nameLabel.position = CGPoint(x: 0, y: r + 27)
        nameLabel.zPosition = 7

        super.init()

        addChild(bodyNode)
        addChild(needleNode)
        addChild(seamNode)
        addChild(hpBarBG)
        addChild(hpBarFill)
        addChild(nameLabel)

        // Four singers — they hold quarters and STEP, never glide.
        // The whole boss keeps time.
        for i in 0..<4 {
            let orbit = SKNode()
            orbit.zRotation = CGFloat(i) * (.pi / 2) + .pi / 4
            orbit.zPosition = 5

            let singer = SKShapeNode(circleOfRadius: 5)
            singer.fillColor = SKColor(hex: 0x24262B)
            singer.strokeColor = SKColor(hex: 0xF6D36B, alpha: 0.7)
            singer.lineWidth = 1.2
            singer.glowWidth = 2
            singer.position = CGPoint(x: r + 24, y: 0)
            orbit.addChild(singer)

            addChild(orbit)
            singers.append(singer)
            singerOrbits.append(orbit)
        }
        startSingerSteps(interval: 0.8)
        startNeedleTicks(interval: 0.8)

        setupPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Physics

    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: DynamoChoirNode.bodyRadius)
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

    /// Singers advance in stepped eighth-turns — tick, hold, tick
    private func startSingerSteps(interval: TimeInterval) {
        for orbit in singerOrbits {
            orbit.removeAction(forKey: "steps")
            let step = SKAction.sequence([
                SKAction.wait(forDuration: interval),
                SKAction.rotate(byAngle: .pi / 4, duration: 0.12)
            ])
            orbit.run(SKAction.repeatForever(step), withKey: "steps")
        }
    }

    /// The needle ticks left-right like a metronome arm
    private func startNeedleTicks(interval: TimeInterval) {
        needleNode.removeAction(forKey: "ticks")
        let tick = SKAction.sequence([
            SKAction.rotate(toAngle: 0.5, duration: 0.1, shortestUnitArc: true),
            SKAction.wait(forDuration: interval),
            SKAction.rotate(toAngle: -0.5, duration: 0.1, shortestUnitArc: true),
            SKAction.wait(forDuration: interval)
        ])
        needleNode.run(SKAction.repeatForever(tick), withKey: "ticks")
    }

    // MARK: - Update

    func update(deltaTime dt: TimeInterval, playerPosition: CGPoint) {
        guard !isDead else { return }

        updateHPBar()
        checkEnrage()

        switch phase {
        case .idle:
            updateIdle(dt: dt, target: playerPosition)
        case .windingUp:
            break  // holds position; transition is action-driven
        case .circuitLitany:
            updateCircuitLitany(dt: dt, playerPosition: playerPosition)
        case .polarityHymn:
            updatePolarityHymn(dt: dt)
        case .brokenMeasure:
            updateBrokenMeasure(dt: dt)
        case .recovering:
            phaseTimer -= dt
            if phaseTimer <= 0 {
                phase = .idle
                attackTimer = DynamoChoirNode.attackCooldown * (isEnraged ? 0.6 : 1.0)
            }
        }
    }

    private func updateIdle(dt: TimeInterval, target: CGPoint) {
        let dir = (target - position).normalized
        position += dir * DynamoChoirNode.idleSpeed * CGFloat(dt)

        attackTimer -= dt
        if attackTimer <= 0 {
            beginNextAttack()
        }
    }

    // MARK: - Attack Dispatch

    private func beginNextAttack() {
        let patterns: [Phase] = [.circuitLitany, .brokenMeasure, .polarityHymn]
        let next = patterns[attackIndex % patterns.count]
        attackIndex += 1

        phase = .windingUp
        openSeam()

        let windup: TimeInterval = isEnraged ? 0.45 : 0.75
        switch next {
        case .circuitLitany: showTell("⌁", colorHex: 0xF6D36B)
        case .polarityHymn:  showTell("◎", colorHex: 0xF6D36B)
        case .brokenMeasure: showTell("♩", colorHex: 0xF6D36B)
        default: break
        }

        run(SKAction.wait(forDuration: windup)) { [weak self] in
            guard let self = self, !self.isDead else { return }
            self.phaseTimer = 0
            switch next {
            case .circuitLitany: self.startCircuitLitany()
            case .polarityHymn:  self.startPolarityHymn()
            case .brokenMeasure: self.startBrokenMeasure()
            default: break
            }
            self.phase = next
        }
    }

    private func endAttack() {
        closeSeam()
        phase = .recovering
        phaseTimer = isEnraged ? 0.6 : 1.1
    }

    private func showTell(_ text: String, colorHex: UInt32) {
        let warn = SKLabelNode(fontNamed: "Menlo-Bold")
        warn.text = text
        warn.fontSize = 22
        warn.fontColor = SKColor(hex: colorHex)
        warn.position = CGPoint(x: 0, y: DynamoChoirNode.bodyRadius + 40)
        warn.zPosition = 10
        addChild(warn)

        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.12),
            SKAction.fadeAlpha(to: 1.0, duration: 0.12)
        ])
        warn.run(SKAction.sequence([
            SKAction.repeat(blink, count: 3),
            SKAction.removeFromParent()
        ]))
    }

    private func openSeam() {
        seamNode.run(SKAction.group([
            SKAction.scaleX(to: 2.2, duration: 0.2),
            SKAction.fadeAlpha(to: 1.0, duration: 0.2)
        ]))
    }

    private func closeSeam() {
        seamNode.run(SKAction.group([
            SKAction.scaleX(to: 1.0, duration: 0.3),
            SKAction.fadeAlpha(to: 0.5, duration: 0.3)
        ]))
    }

    // MARK: - Pattern 1: Circuit Litany

    /// Nodes preview → conduits connect → the pulse fires. The chain is
    /// OPEN — a quarter of the circle never closes, and that gap is the
    /// lesson. The diagram is centered where the player stood at the
    /// first beat; standing still is what gets graded.
    private func startCircuitLitany() {
        litanyBeat = 0
        litanyPoints = []
        litanyDots = []
        litanyLines = []
    }

    private func updateCircuitLitany(dt: TimeInterval, playerPosition: CGPoint) {
        phaseTimer += dt

        // Beat 1: preview the nodes
        if litanyBeat == 0 {
            litanyBeat = 1
            guard let world = parent else { return }

            let radius = DynamoChoirNode.litanyRadius * DeviceScale.gameplay
            let gapStart = CGFloat.random(in: 0...(2 * .pi))
            let arcSpan = 2 * CGFloat.pi * 0.72  // open chain — 28% escape gap
            let count = DynamoChoirNode.litanyNodeCount

            for i in 0..<count {
                let angle = gapStart + arcSpan * CGFloat(i) / CGFloat(count - 1)
                let point = playerPosition + CGPoint(x: cos(angle) * radius,
                                                     y: sin(angle) * radius)
                litanyPoints.append(point)

                let dot = SKShapeNode(circleOfRadius: 4)
                dot.fillColor = SKColor(hex: 0xF6D36B, alpha: 0.0)
                dot.strokeColor = .clear
                dot.glowWidth = 2
                dot.position = point
                dot.zPosition = 3
                world.addChild(dot)
                litanyDots.append(dot)

                dot.run(SKAction.fadeAlpha(to: 0.7, duration: 0.25))
                dot.run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.25),
                    SKAction.repeatForever(SKAction.sequence([
                        SKAction.fadeAlpha(to: 0.4, duration: 0.15),
                        SKAction.fadeAlpha(to: 0.8, duration: 0.15)
                    ]))
                ]))
            }
            return
        }

        // Beat 2: conduits connect node to node
        if litanyBeat == 1 && phaseTimer >= litanyPreviewTime {
            litanyBeat = 2
            guard let world = parent else { return }

            for i in 0..<(litanyPoints.count - 1) {
                let path = CGMutablePath()
                path.move(to: litanyPoints[i])
                path.addLine(to: litanyPoints[i + 1])

                let line = SKShapeNode(path: path)
                line.strokeColor = SKColor(hex: 0xF6D36B, alpha: 0.3)
                line.lineWidth = 1.5
                line.zPosition = 3
                line.alpha = 0
                world.addChild(line)
                litanyLines.append(line)

                line.run(SKAction.sequence([
                    SKAction.wait(forDuration: Double(i) * 0.08),  // catches node to node
                    SKAction.fadeIn(withDuration: 0.12)
                ]))
            }
            return
        }

        // Beat 3: the circuit fires
        if litanyBeat == 2 && phaseTimer >= litanyPreviewTime + litanyConnectTime {
            litanyBeat = 3
            for line in litanyLines {
                line.strokeColor = SKColor(hex: 0xF6D36B, alpha: 0.95)
                line.lineWidth = 3
                line.glowWidth = 5
            }
            for dot in litanyDots {
                dot.removeAllActions()
                dot.alpha = 1.0
            }
            return
        }

        // Live window — crossing a lit conduit hurts
        if litanyBeat == 3 {
            let hitReach = DynamoChoirNode.litanyHitDistance + GameConfig.Player.collisionRadius
            for i in 0..<(litanyPoints.count - 1) {
                if Self.distance(from: playerPosition,
                                 toSegment: litanyPoints[i], litanyPoints[i + 1]) < hitReach {
                    onLineDamage?(DynamoChoirNode.litanyDamage)
                    break
                }
            }

            if phaseTimer >= litanyPreviewTime + litanyConnectTime + litanyPulseTime {
                clearLitany()
                endAttack()
            }
        }
    }

    private func clearLitany() {
        for node in litanyDots + litanyLines {
            node.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.25),
                SKAction.removeFromParent()
            ]))
        }
        litanyDots = []
        litanyLines = []
        litanyPoints = []
        litanyBeat = 0
    }

    private static func distance(from point: CGPoint,
                                 toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let ab = b - a
        let lengthSq = ab.x * ab.x + ab.y * ab.y
        guard lengthSq > 0 else { return (point - a).length }
        let ap = point - a
        let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / lengthSq))
        return (point - (a + ab * t)).length
    }

    // MARK: - Pattern 2: Polarity Hymn

    private func startPolarityHymn() {
        firedHymnPulses = 0
        hymnSnapFired = false
    }

    private func updatePolarityHymn(dt: TimeInterval) {
        phaseTimer += dt

        let pulses = hymnPulses
        if firedHymnPulses < pulses.count && phaseTimer >= pulses[firedHymnPulses].time {
            let pulse = pulses[firedHymnPulses]
            firedHymnPulses += 1
            onFieldPulse?(pulse.strength, pulse.duration)
            showPolarityRing(inward: pulse.strength > 0)
        }

        // Pulse 3: the enemy snap — GameScene projects the player's path
        if !hymnSnapFired && phaseTimer >= hymnSnapTime {
            hymnSnapFired = true
            showPolarityRing(inward: true)
            onEnemySnap?(DynamoChoirNode.hymnSnapRadius * DeviceScale.gameplay)
        }

        if phaseTimer >= DynamoChoirNode.hymnDuration {
            endAttack()
        }
    }

    private func showPolarityRing(inward: Bool) {
        let startRadius: CGFloat = inward ? 180 : 40
        let endScale: CGFloat = inward ? 0.25 : 4.5

        let ring = SKShapeNode(circleOfRadius: startRadius)
        ring.strokeColor = SKColor(hex: 0xF6D36B, alpha: 0.6)
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.glowWidth = 3
        ring.zPosition = 3
        addChild(ring)

        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: endScale, duration: 0.4),
                SKAction.fadeOut(withDuration: 0.4)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Pattern 3: Broken Measure

    private func startBrokenMeasure() {
        beatTimer = 0
        beatsPlayed = 0
        brokenSinger = Int.random(in: 0...3)

        // Singers lock to the cardinals and hold for the measure
        for (i, orbit) in singerOrbits.enumerated() {
            orbit.removeAction(forKey: "steps")
            let target = CGFloat(i) * (.pi / 2)
            orbit.run(SKAction.rotate(toAngle: target, duration: 0.25, shortestUnitArc: true))
        }
    }

    private func updateBrokenMeasure(dt: TimeInterval) {
        phaseTimer += dt
        beatTimer += dt

        if beatTimer >= beatInterval && beatsPlayed < DynamoChoirNode.measureBeats {
            beatTimer = 0
            let singerIndex = beatsPlayed % 4
            beatsPlayed += 1

            // New measure, new liar
            if beatsPlayed % 4 == 1 && beatsPlayed > 1 {
                brokenSinger = Int.random(in: 0...3)
            }

            if singerIndex == brokenSinger {
                stutterSinger(singerIndex)  // the safe beat — no fire
            } else {
                fireSinger(singerIndex)
            }
        }

        if beatsPlayed >= DynamoChoirNode.measureBeats {
            for orbit in singerOrbits {
                orbit.removeAction(forKey: "steps")
            }
            startSingerSteps(interval: isEnraged ? 0.5 : 0.8)
            endAttack()
        }
    }

    private func fireSinger(_ index: Int) {
        guard let world = parent else { return }
        let singer = singers[index]
        let worldPos = singer.parent?.convert(singer.position, to: world) ?? position

        // The beat: singer brightens and fires a fan outward
        singer.run(SKAction.sequence([
            SKAction.run { singer.fillColor = SKColor(hex: 0xF6D36B) },
            SKAction.scale(to: 1.5, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.15),
            SKAction.run { singer.fillColor = SKColor(hex: 0x24262B) }
        ]))

        let baseAngle = CGFloat(index) * (.pi / 2)
        let spread = DynamoChoirNode.beatFanSpread
        for k in 0..<DynamoChoirNode.beatFanCount {
            let offset = spread * (CGFloat(k) - CGFloat(DynamoChoirNode.beatFanCount - 1) / 2)
            let dir = CGPoint(x: cos(baseAngle + offset), y: sin(baseAngle + offset))
            onFireProjectile?(worldPos, dir)
        }
    }

    /// The misfire — flickers, stutters, fails. The gap in the song.
    private func stutterSinger(_ index: Int) {
        let singer = singers[index]
        let stutter = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 0.05),
            SKAction.fadeAlpha(to: 0.9, duration: 0.05),
            SKAction.fadeAlpha(to: 0.15, duration: 0.05),
            SKAction.fadeAlpha(to: 0.6, duration: 0.05),
            SKAction.fadeAlpha(to: 1.0, duration: 0.15)
        ])
        singer.run(stutter)
    }

    // MARK: - Enrage: Full Current

    private func checkEnrage() {
        guard isEnraged, !enrageTriggered else { return }
        enrageTriggered = true

        // The Choir does not get angry. It finds tempo.
        startSingerSteps(interval: 0.5)
        startNeedleTicks(interval: 0.4)
        bodyNode.strokeColor = SKColor(hex: 0xF6D36B, alpha: 0.9)
        seamNode.fillColor = SKColor(hex: 0xFFFFFF, alpha: 0.8)
        for singer in singers {
            singer.strokeColor = SKColor(hex: 0xF6D36B)
            singer.glowWidth = 3
        }
    }

    // MARK: - HP Bar

    private func updateHPBar() {
        let pct = healthPercent
        let barW = DynamoChoirNode.bodyRadius * 2
        let barH: CGFloat = 5
        let fillW = max(1, barW * pct)

        hpBarFill.path = CGPath(
            roundedRect: CGRect(x: -barW / 2, y: -barH / 2, width: fillW, height: barH),
            cornerWidth: 2, cornerHeight: 2, transform: nil
        )

        if pct < 0.3 {
            hpBarFill.fillColor = SKColor(hex: 0xFFFFFF)  // Full Current white-hot
        }
    }

    // MARK: - Damage

    @discardableResult
    func takeDamage(_ amount: Int) -> Bool {
        guard !isDead else { return false }
        let scaled = vulnerabilityMultiplier == 1.0
            ? amount
            : Int((CGFloat(amount) * vulnerabilityMultiplier).rounded())
        health -= scaled

        let flash = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.bodyNode.fillColor = SKColor(hex: 0x3A3B30)
                self?.needleNode.fillColor = .white
            },
            SKAction.wait(forDuration: 0.06),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.bodyNode.fillColor = SKColor(hex: 0x16171A)
                self.needleNode.fillColor = SKColor(hex: 0xF6D36B)
            }
        ])
        run(flash)

        if health <= 0 {
            health = 0
            die()
            return true
        }
        return false
    }

    // MARK: - Death

    private func die() {
        isDead = true
        physicsBody?.categoryBitMask = 0
        phase = .idle
        clearLitany()

        // The needle stops mid-tick. The singers scatter. The song ends.
        let deathSequence = SKAction.sequence([
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.needleNode.removeAction(forKey: "ticks")
                self.seamNode.run(SKAction.group([
                    SKAction.scaleX(to: 4.0, duration: 0.35),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.1)
                ]))
                for (i, orbit) in self.singerOrbits.enumerated() {
                    orbit.removeAction(forKey: "steps")
                    orbit.run(SKAction.sequence([
                        SKAction.wait(forDuration: Double(i) * 0.08),  // they fall silent in order
                        SKAction.group([
                            SKAction.scale(to: 2.0, duration: 0.4),
                            SKAction.fadeOut(withDuration: 0.4)
                        ])
                    ]))
                }
            },
            SKAction.wait(forDuration: 0.55),
            SKAction.group([
                SKAction.scale(to: 0.0, duration: 0.35),
                SKAction.fadeOut(withDuration: 0.35)
            ]),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.onDeath?(self.position, DynamoChoirNode.xpReward)
            },
            SKAction.removeFromParent()
        ])

        hpBarBG.run(SKAction.fadeOut(withDuration: 0.2))
        hpBarFill.run(SKAction.fadeOut(withDuration: 0.2))
        nameLabel.run(SKAction.fadeOut(withDuration: 0.2))

        run(deathSequence)
    }

    /// Clean up world-space litany nodes if the run ends mid-pattern.
    func cleanupWorldEffects() {
        clearLitany()
    }

    // MARK: - Spawn

    static func spawnPosition() -> CGPoint {
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance = GameConfig.Arena.radius + 80
        return CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
    }
}
