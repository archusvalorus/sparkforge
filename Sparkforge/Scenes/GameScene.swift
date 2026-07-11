// GameScene.swift
// Sparkforge
//
// Phase 4: Ship-ready.
// - Ad revive system (one per run)
// - High score tracking + new record badges
// - Screen shake on player hit / enemy death
// - Enhanced death screen with stats
// - Pause on app background
// - All Phase 1-3 systems intact

import SpriteKit

final class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Game State
    
    enum GameState {
        case playing
        case dead
        case levelUp
        case reviving  // Brief state during ad revive
        case paused    // v1.4: Pause menu
    }
    
    private(set) var gameState: GameState = .playing
    
    // MARK: - Core Systems

    private let playerStats = PlayerStats()
    private let upgradeManager = UpgradeManager()
    private let adReviveManager = AdReviveManager()

    // v1.6: Selected arena's visual identity (resolved at scene creation)
    private let arenaConfig = ArenaConfig.current
    
    // MARK: - Boss Mechanics

    // v1.6: any arena's boss lives here (Slag Titan or Quench Warden)
    private var boss: (any ArenaBossNode)? = nil
    private var bossDefeatedThisRun: Bool = false

    // v1.6: Quench Field momentum pulses (points/sec toward boss when positive)
    private var fieldImpulseStrength: CGFloat = 0
    private var fieldImpulseRemaining: TimeInterval = 0
    /// v1.7: the player's last real heading — Polarity Hymn's snap
    /// projects enemies onto this path, never onto the player
    private var lastMoveDirection = CGPoint(x: 0, y: 1)
    
    // MARK: - New Additions for health orbs + magnet orbs
    
    private let hpBar = HPBarNode(width: 210)  // v1.7 legibility pass
    private var healthOrbs: [HealthOrbNode] = []
    private var magnetOrbs: [MagnetOrbNode] = []
    private var healthOrbTimer: TimeInterval = 0
    private var magnetOrbTimer: TimeInterval = 0
    private var nextHealthOrbSpawn: TimeInterval = 20  // randomize later
    private var nextMagnetOrbSpawn: TimeInterval = 25
    private var damageCooldownTimer: TimeInterval = 0  // i-frames after hit
    private var pendingForgeXP: Int = 0  // v1.5: Stored for XP boost ad doubling

    // MARK: - v1.6: Gravity Wells + Chill Trail (True Cards)

    private var gravityWells: [GravityWellNode] = []
    private var singularityTimer: TimeInterval = 0
    private var chillTrailPoints: [(position: CGPoint, expiry: TimeInterval)] = []
    private var chillTrailDropTimer: TimeInterval = 0

    // MARK: - v1.6: Quench Card State (Unit 3)

    private var arcWakeSparks: [(position: CGPoint, expiry: TimeInterval)] = []
    private var arcWakeDropTimer: TimeInterval = 0
    private var nullBloomZones: [(position: CGPoint, expiry: TimeInterval)] = []
    
    // MARK: - Nodes
    
    private let player = PlayerNode()
    private let joystick = VirtualJoystick()
    private var enemies: [EnemyNode] = []
    private var projectiles: [ProjectileNode] = []
    private var enemyProjectiles: [EnemyProjectileNode] = []
    private var xpOrbs: [XPOrbNode] = []
    
    // MARK: - Card Selection
    
    private var displayedCards: [UpgradeCardNode] = []
    
    // MARK: - Systems
    
    private let waveManager = WaveManager()
    
    // MARK: - World Node (for screen shake)
    
    private let worldNode = SKNode()
    
    // MARK: - Arena Visuals
    
    private let arenaFloor = SKShapeNode()
    private let arenaBoundary = SKShapeNode()
    
    // MARK: - UI (attached to scene, not worldNode)
    
    private let timerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let levelLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let xpBar = XPBarNode(width: 210)  // v1.7 legibility pass
    private let buffTracker = BuffTrackerNode()
    private let deathOverlay = SKNode()
    private let levelUpOverlay = SKNode()
    private let synergyLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let pauseMenu = PauseMenuNode()  // v1.7: Pause Menu v2
    private let pauseButton = SKLabelNode(fontNamed: "Menlo-Bold")  // v1.4
    
    // MARK: - Stats Tracking
    
    private var killCount: Int = 0
    
    // MARK: - Timing
    
    private var lastUpdateTime: TimeInterval = 0
    private var timeSinceLastShot: TimeInterval = 0
    
    // MARK: - Invulnerability (post-revive)
    
    private var invulnerableTimer: TimeInterval = 0
    private var isInvulnerable: Bool { invulnerableTimer > 0 || playerStats.isPhaseSkinActive }
    
    // MARK: - Reroll

    private var rerollUsedThisRun: Bool = false

    // MARK: - v1.6: Extra Card (ad reward)

    private var extraCardUsedThisRun: Bool = false
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        player.stats = playerStats
        
        // Camera follows player
        let cam = SKCameraNode()
        camera = cam
        addChild(cam)
        
        // World node holds all gameplay objects (for screen shake)
        worldNode.position = .zero
        addChild(worldNode)
        
        setupArena()
        setupPlayer()
        setupJoystick()
        setupHUD()
        setupDeathOverlay()
        setupLevelUpOverlay()
        setupPauseOverlay()
        setupEmberParticles()
        
        // Preload rewarded ad
        adReviveManager.preloadAd()
        
        // Show tutorial hint on first run
        showTutorialHintIfNeeded()
        
        // Listen for app backgrounding
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appDidEnterBackground() {
        if gameState == .playing {
            isPaused = true
        }
    }
    
    @objc private func appWillEnterForeground() {
        if gameState == .playing {
            isPaused = false
        }
    }
    
    // MARK: - Setup (gameplay objects go into worldNode)
    
    private func setupArena() {
        // v1.6: colors + motif come from the selected arena's config
        let radius = GameConfig.Arena.radius

        let floorPath = CGPath(ellipseIn: CGRect(
            x: -radius, y: -radius,
            width: radius * 2, height: radius * 2
        ), transform: nil)
        arenaFloor.path = floorPath
        arenaFloor.fillColor = SKColor(hex: arenaConfig.floorColorHex)
        arenaFloor.strokeColor = .clear
        arenaFloor.zPosition = -10
        worldNode.addChild(arenaFloor)

        // Per-arena floor motif
        switch arenaConfig.id {
        case 1:
            buildQuenchMotif(radius: radius)
        case 2:
            buildCoilworksMotif(radius: radius)
        default:
            buildCrucibleMotif(radius: radius)
        }

        // Outer boundary ring — main edge
        arenaBoundary.path = floorPath
        arenaBoundary.fillColor = .clear
        arenaBoundary.strokeColor = SKColor(hex: arenaConfig.boundaryColorHex, alpha: 0.6)
        arenaBoundary.lineWidth = GameConfig.Arena.boundaryLineWidth
        arenaBoundary.glowWidth = 6
        arenaBoundary.zPosition = -9
        worldNode.addChild(arenaBoundary)

        // Outer danger glow — pulsing warning ring just outside boundary
        let dangerRing = SKShapeNode(circleOfRadius: radius + 4)
        dangerRing.fillColor = .clear
        dangerRing.strokeColor = SKColor(hex: arenaConfig.dangerGlowHex, alpha: 0.3)
        dangerRing.lineWidth = 8
        dangerRing.glowWidth = 10
        dangerRing.zPosition = -8
        worldNode.addChild(dangerRing)

        let dangerPulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.15, duration: 1.5),
            SKAction.fadeAlpha(to: 0.4, duration: 1.5)
        ])
        dangerRing.run(SKAction.repeatForever(dangerPulse))
    }

    /// Arena 1 motif: concentric forge rings + cross-hair grid (original v1.0 look)
    private func buildCrucibleMotif(radius: CGFloat) {
        let ringRadii: [CGFloat] = [radius * 0.3, radius * 0.6, radius * 0.85]
        for (i, ringR) in ringRadii.enumerated() {
            let ring = SKShapeNode(circleOfRadius: ringR)
            ring.fillColor = .clear
            ring.strokeColor = SKColor(hex: arenaConfig.detailLineHex, alpha: 0.4 - CGFloat(i) * 0.1)
            ring.lineWidth = 1
            ring.zPosition = -9.5
            worldNode.addChild(ring)
        }

        for angle in stride(from: 0.0, to: CGFloat.pi, by: CGFloat.pi / 4) {
            let line = SKShapeNode()
            let linePath = CGMutablePath()
            linePath.move(to: CGPoint(x: cos(angle) * radius * 0.9,
                                       y: sin(angle) * radius * 0.9))
            linePath.addLine(to: CGPoint(x: -cos(angle) * radius * 0.9,
                                          y: -sin(angle) * radius * 0.9))
            line.path = linePath
            line.strokeColor = SKColor(hex: 0x222222, alpha: 0.2)
            line.lineWidth = 0.5
            line.zPosition = -9.5
            worldNode.addChild(line)
        }
    }

    /// v1.6 Arena 2 motif (Lyra canon): quench rings and stress fractures —
    /// uneven offset rings, radial fracture lines, four diagonal cooling channels.
    /// "This place has cooled too quickly, and something beneath it remembers the heat."
    private func buildQuenchMotif(radius: CGFloat) {
        // Three faint uneven concentric rings, slightly offset from center
        let ringSpecs: [(r: CGFloat, offset: CGPoint)] = [
            (radius * 0.32, CGPoint(x: 6, y: -4)),
            (radius * 0.57, CGPoint(x: -8, y: 5)),
            (radius * 0.84, CGPoint(x: 4, y: 7))
        ]
        for (i, spec) in ringSpecs.enumerated() {
            let ring = SKShapeNode(circleOfRadius: spec.r)
            ring.fillColor = .clear
            ring.strokeColor = SKColor(hex: arenaConfig.detailLineHex, alpha: 0.38 - CGFloat(i) * 0.08)
            ring.lineWidth = 1
            ring.position = spec.offset
            ring.zPosition = -9.5
            worldNode.addChild(ring)
        }

        // Radial stress fractures — jagged two-segment lines at irregular angles
        let fractureAngles: [CGFloat] = [0.4, 1.1, 1.9, 2.7, 3.6, 4.5, 5.4]
        for (i, angle) in fractureAngles.enumerated() {
            let innerR = radius * 0.12
            let breakR = radius * (0.45 + CGFloat(i % 3) * 0.12)
            let outerR = radius * 0.92
            let bentAngle = angle + 0.09

            let path = CGMutablePath()
            path.move(to: CGPoint(x: cos(angle) * innerR, y: sin(angle) * innerR))
            path.addLine(to: CGPoint(x: cos(angle) * breakR, y: sin(angle) * breakR))
            path.addLine(to: CGPoint(x: cos(bentAngle) * outerR, y: sin(bentAngle) * outerR))

            let fracture = SKShapeNode()
            fracture.path = path
            fracture.strokeColor = SKColor(hex: arenaConfig.boundaryColorHex, alpha: 0.14)
            fracture.lineWidth = 0.8
            fracture.zPosition = -9.5
            worldNode.addChild(fracture)
        }

        // Four shallow diagonal cooling channels crossing the floor
        let channelAngles: [CGFloat] = [0.6, 0.6 + .pi / 2, 2.3, 2.3 + .pi / 2]
        for (i, angle) in channelAngles.enumerated() {
            let perpOffset: CGFloat = (i % 2 == 0 ? 1 : -1) * radius * 0.28
            let dx = cos(angle), dy = sin(angle)
            let px = -dy * perpOffset, py = dx * perpOffset
            let span = radius * 0.75

            let path = CGMutablePath()
            path.move(to: CGPoint(x: px - dx * span, y: py - dy * span))
            path.addLine(to: CGPoint(x: px + dx * span, y: py + dy * span))

            let channel = SKShapeNode()
            channel.path = path
            channel.strokeColor = SKColor(hex: 0x0B0E12, alpha: 0.55)
            channel.lineWidth = 3
            channel.zPosition = -9.6
            worldNode.addChild(channel)
        }
    }
    
    /// v1.7 Arena 3 motif: a brass circuit. Gapped trace rings, radial
    /// conduits, junction nodes — and sequenced pulses: one node flickers,
    /// a conduit catches, connected nodes answer, and the pulse dies
    /// before the circuit completes. "An old machine trying to solve the
    /// player." Idle linework stays very faint; pulses sit below combat.
    private func buildCoilworksMotif(radius: CGFloat) {
        // Gapped trace rings — arcs with deliberate breaks, not full circles
        let ringSpecs: [(r: CGFloat, gaps: Int, phase: CGFloat)] = [
            (radius * 0.30, 3, 0.3),
            (radius * 0.55, 4, 1.2),
            (radius * 0.82, 5, 2.4)
        ]
        for (i, spec) in ringSpecs.enumerated() {
            let segmentSweep = (2 * CGFloat.pi / CGFloat(spec.gaps)) * 0.78  // 22% gap
            for s in 0..<spec.gaps {
                let start = spec.phase + CGFloat(s) * (2 * .pi / CGFloat(spec.gaps))
                let path = CGMutablePath()
                path.addArc(center: .zero, radius: spec.r,
                            startAngle: start, endAngle: start + segmentSweep,
                            clockwise: false)
                let arc = SKShapeNode(path: path)
                arc.fillColor = .clear
                arc.strokeColor = SKColor(hex: arenaConfig.detailLineHex, alpha: 0.42 - CGFloat(i) * 0.08)
                arc.lineWidth = 1
                arc.zPosition = -9.5
                worldNode.addChild(arc)
            }
        }

        // Conduits + junction nodes, grouped into pulse chains.
        // Each chain: an inner node, a conduit out to an outer node, and
        // a short branch to a third — the family a pulse travels through.
        let chainAngles: [CGFloat] = [0.5, 1.55, 2.6, 3.65, 4.7, 5.75]
        var chains: [(nodes: [SKShapeNode], conduits: [SKShapeNode])] = []

        for (i, angle) in chainAngles.enumerated() {
            let innerR = radius * 0.30
            let outerR = radius * (i % 2 == 0 ? 0.55 : 0.82)
            let branchAngle = angle + 0.35

            let p1 = CGPoint(x: cos(angle) * innerR, y: sin(angle) * innerR)
            let p2 = CGPoint(x: cos(angle) * outerR, y: sin(angle) * outerR)
            let p3 = CGPoint(x: cos(branchAngle) * outerR, y: sin(branchAngle) * outerR)

            var nodes: [SKShapeNode] = []
            var conduits: [SKShapeNode] = []

            // Static linework (very faint, always visible)
            for (a, b) in [(p1, p2), (p2, p3)] {
                let path = CGMutablePath()
                path.move(to: a)
                path.addLine(to: b)
                let line = SKShapeNode(path: path)
                line.strokeColor = SKColor(hex: arenaConfig.detailLineHex, alpha: 0.35)
                line.lineWidth = 1
                line.zPosition = -9.5
                worldNode.addChild(line)

                // Pulse overlay for the same segment (lights up briefly)
                let pulse = SKShapeNode(path: path)
                pulse.strokeColor = SKColor(hex: 0xF6D36B)
                pulse.lineWidth = 1
                pulse.alpha = 0
                pulse.zPosition = -9.4
                worldNode.addChild(pulse)
                conduits.append(pulse)
            }

            for point in [p1, p2, p3] {
                let dot = SKShapeNode(circleOfRadius: 2.5)
                dot.fillColor = SKColor(hex: arenaConfig.detailLineHex)
                dot.strokeColor = .clear
                dot.position = point
                dot.zPosition = -9.5
                worldNode.addChild(dot)

                let glow = SKShapeNode(circleOfRadius: 2.5)
                glow.fillColor = SKColor(hex: 0xF6D36B)
                glow.strokeColor = .clear
                glow.position = point
                glow.alpha = 0
                glow.zPosition = -9.4
                worldNode.addChild(glow)
                nodes.append(glow)
            }

            chains.append((nodes, conduits))
        }

        // The calculation: every few seconds the next chain tries to
        // complete — origin flickers, conduit catches, neighbors answer
        // weaker, and it dies before the circuit closes.
        var chainIndex = 0
        let step = SKAction.sequence([
            SKAction.run { [weak self] in
                guard self != nil else { return }
                let chain = chains[chainIndex % chains.count]
                chainIndex += 1

                let flicker = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.5, duration: 0.10),
                    SKAction.fadeAlpha(to: 0.25, duration: 0.08),
                    SKAction.fadeAlpha(to: 0.5, duration: 0.08)
                ])
                chain.nodes[0].run(SKAction.sequence([
                    flicker,
                    SKAction.wait(forDuration: 0.5),
                    SKAction.fadeOut(withDuration: 0.35)
                ]))
                chain.conduits[0].run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.24),
                    SKAction.fadeAlpha(to: 0.30, duration: 0.12),
                    SKAction.wait(forDuration: 0.25),
                    SKAction.fadeOut(withDuration: 0.30)
                ]))
                chain.nodes[1].run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.42),
                    SKAction.fadeAlpha(to: 0.40, duration: 0.10),
                    SKAction.wait(forDuration: 0.2),
                    SKAction.fadeOut(withDuration: 0.30)
                ]))
                // The answer fades before the last leg — never a closed loop
                chain.nodes[2].run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.58),
                    SKAction.fadeAlpha(to: 0.18, duration: 0.10),
                    SKAction.fadeOut(withDuration: 0.22)
                ]))
                chain.conduits[1].run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.52),
                    SKAction.fadeAlpha(to: 0.12, duration: 0.10),
                    SKAction.fadeOut(withDuration: 0.18)
                ]))
            },
            SKAction.wait(forDuration: 3.2, withRange: 1.6)
        ])
        arenaFloor.run(SKAction.repeatForever(step))
    }

    private func setupPlayer() {
        player.position = .zero
        worldNode.addChild(player)
    }
    
    private func setupJoystick() {
        guard let camera = camera else { return }
        joystick.zPosition = 100
        camera.addChild(joystick)  // Attached to camera, stays on screen
    }
    
    private func setupHUD() {
        guard let view = view, let camera = camera else { return }
        // Account for Dynamic Island / notch — push further down
        let safeTop = view.bounds.height / 2 - 80
        let safeLeft = -view.bounds.width / 2 + 20
        
        // Timer — top center, most prominent
        timerLabel.fontSize = 20
        timerLabel.fontColor = SKColor(hex: 0xAAAAAA)
        timerLabel.position = CGPoint(x: 0, y: safeTop)
        timerLabel.zPosition = 101
        timerLabel.text = "0:00"
        camera.addChild(timerLabel)
        
        // Level — below timer
        levelLabel.fontSize = 13
        levelLabel.fontColor = SKColor(hex: 0xFFAA33)
        levelLabel.position = CGPoint(x: 0, y: safeTop - 22)
        levelLabel.zPosition = 101
        levelLabel.text = "LV 1"
        camera.addChild(levelLabel)
        
        // XP Bar — below level (v1.7: taller bars need more breathing room)
        xpBar.position = CGPoint(x: 0, y: safeTop - 42)
        xpBar.zPosition = 101
        camera.addChild(xpBar)

        // HP Bar - below XP Bar
        hpBar.position = CGPoint(x: 0, y: safeTop - 64)
        hpBar.zPosition = 101
        camera.addChild(hpBar)
        
        // Buff tracker — top left
        // v1.7: badges start below the (now much larger) HP bar so the
        // stack never collides with the bar span on narrow screens
        buffTracker.position = CGPoint(x: safeLeft, y: safeTop - 96)
        buffTracker.zPosition = 101
        camera.addChild(buffTracker)
        
        // Synergy notification — bottom center
        synergyLabel.fontSize = 12
        synergyLabel.fontColor = SKColor(hex: 0xFFDD55)
        synergyLabel.position = CGPoint(x: 0, y: -view.bounds.height / 2 + 80)
        synergyLabel.zPosition = 150
        synergyLabel.alpha = 0
        camera.addChild(synergyLabel)
        
        // v1.4: Pause button — top right
        let safeRight = view.bounds.width / 2 - 30
        pauseButton.text = "⏸"
        pauseButton.fontSize = 20
        pauseButton.fontColor = SKColor(hex: 0xAAAAAA)
        pauseButton.position = CGPoint(x: safeRight, y: safeTop)
        pauseButton.zPosition = 101
        pauseButton.name = "pauseButton"
        camera.addChild(pauseButton)
    }
    
    private func setupDeathOverlay() {
        deathOverlay.zPosition = 200
        deathOverlay.alpha = 0
        
        let bg = SKShapeNode(rectOf: CGSize(width: 2000, height: 2000))
        bg.fillColor = SKColor(hex: 0x000000, alpha: 0.75)
        bg.strokeColor = .clear
        deathOverlay.addChild(bg)
        
        // Title
        let deathText = SKLabelNode(fontNamed: "Menlo-Bold")
        deathText.fontSize = 26
        deathText.fontColor = SKColor(hex: 0xFF4444)
        deathText.text = "SPARK EXTINGUISHED"
        deathText.position = CGPoint(x: 0, y: 90)
        deathOverlay.addChild(deathText)
        
        // Run stats
        let scoreText = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreText.fontSize = 16
        scoreText.fontColor = SKColor(hex: 0xFFAA33)
        scoreText.name = "deathScore"
        scoreText.position = CGPoint(x: 0, y: 55)
        deathOverlay.addChild(scoreText)
        
        // New record badge (hidden by default)
        let recordBadge = SKLabelNode(fontNamed: "Menlo-Bold")
        recordBadge.fontSize = 14
        recordBadge.fontColor = SKColor(hex: 0xFFDD55)
        recordBadge.name = "recordBadge"
        recordBadge.position = CGPoint(x: 0, y: 30)
        recordBadge.alpha = 0
        deathOverlay.addChild(recordBadge)
        
        // Best time display
        let bestLabel = SKLabelNode(fontNamed: "Menlo")
        bestLabel.fontSize = 11
        bestLabel.fontColor = SKColor(hex: 0x666666)
        bestLabel.name = "bestLabel"
        bestLabel.position = CGPoint(x: 0, y: 10)
        deathOverlay.addChild(bestLabel)
        
        // Revive button
        let reviveBtn = SKNode()
        reviveBtn.name = "reviveButton"
        reviveBtn.position = CGPoint(x: 0, y: -30)
        
        let reviveBg = SKShapeNode(rectOf: CGSize(width: 180, height: 36), cornerRadius: 6)
        reviveBg.fillColor = SKColor(hex: 0x334433)
        reviveBg.strokeColor = SKColor(hex: 0x66AA66, alpha: 0.6)
        reviveBg.lineWidth = 1
        reviveBtn.addChild(reviveBg)
        
        let reviveText = SKLabelNode(fontNamed: "Menlo-Bold")
        reviveText.fontSize = 13
        reviveText.fontColor = SKColor(hex: 0x88DD88)
        reviveText.text = "REIGNITE THE FORGE"
        reviveText.verticalAlignmentMode = .center
        reviveText.name = "reviveLabel"
        reviveBtn.addChild(reviveText)
        
        deathOverlay.addChild(reviveBtn)
        
        // v1.5: XP Boost button
        let xpBoostBtn = SKNode()
        xpBoostBtn.name = "xpBoostButton"
        xpBoostBtn.position = CGPoint(x: 0, y: -72)
        
        let xpBoostBg = SKShapeNode(rectOf: CGSize(width: 160, height: 32), cornerRadius: 6)
        xpBoostBg.fillColor = SKColor(hex: 0x332211)
        xpBoostBg.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.6)
        xpBoostBg.lineWidth = 1
        xpBoostBtn.addChild(xpBoostBg)
        
        let xpBoostText = SKLabelNode(fontNamed: "Menlo-Bold")
        xpBoostText.fontSize = 12
        xpBoostText.fontColor = SKColor(hex: 0xFFAA33)
        xpBoostText.text = "2x FORGE XP"
        xpBoostText.verticalAlignmentMode = .center
        xpBoostText.name = "xpBoostLabel"
        xpBoostBtn.addChild(xpBoostText)
        
        let xpBoostAdIcon = SKLabelNode(fontNamed: "Menlo")
        xpBoostAdIcon.fontSize = 9
        xpBoostAdIcon.fontColor = SKColor(hex: 0xCCCCCC)
        xpBoostAdIcon.text = "▶ AD"
        xpBoostAdIcon.verticalAlignmentMode = .center
        xpBoostAdIcon.position = CGPoint(x: 62, y: 0)
        xpBoostAdIcon.name = "xpBoostAdIcon"
        xpBoostBtn.addChild(xpBoostAdIcon)
        
        deathOverlay.addChild(xpBoostBtn)
        
        // Restart button
        let restartBtn = SKNode()
        restartBtn.name = "restartButton"
        restartBtn.position = CGPoint(x: 0, y: -115)
        
        let restartBg = SKShapeNode(rectOf: CGSize(width: 140, height: 32), cornerRadius: 6)
        restartBg.fillColor = SKColor(hex: 0x333333)
        restartBg.strokeColor = SKColor(hex: 0x888888, alpha: 0.4)
        restartBg.lineWidth = 1
        restartBtn.addChild(restartBg)
        
        let restartText = SKLabelNode(fontNamed: "Menlo")
        restartText.fontSize = 12
        restartText.fontColor = SKColor(hex: 0xAAAAAA)
        restartText.text = "RESTART"
        restartText.verticalAlignmentMode = .center
        restartBtn.addChild(restartText)
        
        deathOverlay.addChild(restartBtn)
        
        // Menu button
        let menuLabel = SKLabelNode(fontNamed: "Menlo")
        menuLabel.fontSize = 10
        menuLabel.fontColor = SKColor(hex: 0x666666)
        menuLabel.text = "MENU"
        menuLabel.name = "menuButton"
        menuLabel.position = CGPoint(x: 0, y: -155)
        deathOverlay.addChild(menuLabel)
        
        guard let camera = camera else { return }
        camera.addChild(deathOverlay)
    }
    
    private func setupLevelUpOverlay() {
        levelUpOverlay.zPosition = 190
        levelUpOverlay.alpha = 0
        
        let bg = SKShapeNode(rectOf: CGSize(width: 2000, height: 2000))
        bg.fillColor = SKColor(hex: 0x000000, alpha: 0.5)
        bg.strokeColor = .clear
        levelUpOverlay.addChild(bg)
        
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 24
        label.fontColor = SKColor(hex: 0xFFAA33)
        label.text = "LEVEL UP"
        label.name = "levelUpLabel"
        label.position = CGPoint(x: 0, y: 90)  // v1.6: cleared for taller cards
        levelUpOverlay.addChild(label)

        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.fontSize = 12
        hint.fontColor = SKColor(hex: 0x777777)
        hint.text = "choose an upgrade"
        hint.position = CGPoint(x: 0, y: 66)  // v1.6: cleared for taller cards
        levelUpOverlay.addChild(hint)
        
        // v1.6: Reroll + Extra Card sit side by side below the cards.
        // Both are once per run; both free with Remove Ads.
        let adText = IAPManager.shared.hasRemovedAds ? "FREE" : "▶ AD"

        // Reroll button (left)
        let rerollBtn = SKNode()
        rerollBtn.name = "rerollButton"
        rerollBtn.position = CGPoint(x: -80, y: -144)  // v1.6: below taller cards

        let rerollBg = SKShapeNode(rectOf: CGSize(width: 150, height: 28), cornerRadius: 5)
        rerollBg.fillColor = SKColor(hex: 0x332233)
        rerollBg.strokeColor = SKColor(hex: 0x9966AA, alpha: 0.5)
        rerollBg.lineWidth = 1
        rerollBtn.addChild(rerollBg)

        let rerollText = SKLabelNode(fontNamed: "Menlo-Bold")
        rerollText.fontSize = 11
        // v1.7 readability canon: tinted-toward-white, bold
        rerollText.fontColor = SKColor(hex: 0xE2CCEA)
        rerollText.text = "⟳ REFORGE"
        rerollText.verticalAlignmentMode = .center
        rerollText.position = CGPoint(x: -14, y: 0)
        rerollText.name = "rerollLabel"
        rerollBtn.addChild(rerollText)

        let adIcon = SKLabelNode(fontNamed: "Menlo")
        adIcon.fontSize = 9
        // Cost info is a decision input — it pops too
        adIcon.fontColor = SKColor(hex: 0xCCCCCC)
        adIcon.text = adText
        adIcon.verticalAlignmentMode = .center
        adIcon.position = CGPoint(x: 50, y: 0)
        adIcon.name = "rerollAdIcon"
        rerollBtn.addChild(adIcon)

        levelUpOverlay.addChild(rerollBtn)

        // Extra Card button (right)
        let extraBtn = SKNode()
        extraBtn.name = "extraCardButton"
        extraBtn.position = CGPoint(x: 80, y: -144)  // v1.6: below taller cards

        let extraBg = SKShapeNode(rectOf: CGSize(width: 150, height: 28), cornerRadius: 5)
        extraBg.fillColor = SKColor(hex: 0x223333)
        extraBg.strokeColor = SKColor(hex: 0x66AAAA, alpha: 0.5)
        extraBg.lineWidth = 1
        extraBtn.addChild(extraBg)

        let extraText = SKLabelNode(fontNamed: "Menlo-Bold")
        extraText.fontSize = 11
        // v1.7 readability canon: tinted-toward-white, bold
        extraText.fontColor = SKColor(hex: 0xC9E8E8)
        extraText.text = "✦ +1 CARD"
        extraText.verticalAlignmentMode = .center
        extraText.position = CGPoint(x: -14, y: 0)
        extraText.name = "extraCardLabel"
        extraBtn.addChild(extraText)

        let extraAdIcon = SKLabelNode(fontNamed: "Menlo")
        extraAdIcon.fontSize = 9
        extraAdIcon.fontColor = SKColor(hex: 0xCCCCCC)
        extraAdIcon.text = adText
        extraAdIcon.verticalAlignmentMode = .center
        extraAdIcon.position = CGPoint(x: 50, y: 0)
        extraAdIcon.name = "extraCardAdIcon"
        extraBtn.addChild(extraAdIcon)

        levelUpOverlay.addChild(extraBtn)
        
        guard let camera = camera else { return }
        camera.addChild(levelUpOverlay)
    }
    
    // v1.7: Pause Menu v2 — panes and build viewer live in PauseMenuNode
    private func setupPauseOverlay() {
        pauseMenu.onResume = { [weak self] in self?.resumeGame() }
        pauseMenu.onReturnToMenu = { [weak self] in self?.returnToTitle() }
        guard let camera = camera else { return }
        camera.addChild(pauseMenu)
    }
    
    private func setupEmberParticles() {
        // Small ember texture
        let dotSize = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: dotSize)
        let dotImage = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: dotSize))
        }
        let dotTexture = SKTexture(image: dotImage)

        // v1.6: per-arena ambience — Crucible rises, The Quench falls
        if arenaConfig.id == 1 {
            setupQuenchAsh(texture: dotTexture)
            if let view = view {
                let vignette = VignetteNode(size: view.bounds.size)
                camera?.addChild(vignette)
            }
            return
        }

        // v1.7: The Coilworks crackles — static motes jitter and hop
        if arenaConfig.id == 2 {
            setupCoilworksStatic(texture: dotTexture)
            if let view = view {
                let vignette = VignetteNode(size: view.bounds.size)
                camera?.addChild(vignette)
            }
            return
        }

        // Primary embers — small, frequent, drifting up
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 12
        emitter.particleLifetime = 4
        emitter.particleLifetimeRange = 2
        emitter.particlePositionRange = CGVector(dx: GameConfig.Arena.radius * 2, dy: GameConfig.Arena.radius * 2)
        emitter.particleSpeed = 12
        emitter.particleSpeedRange = 8
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = 0.4
        emitter.particleAlpha = 0.4
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -0.08
        emitter.particleScale = 0.06
        emitter.particleScaleRange = 0.03
        emitter.particleColor = SKColor(hex: 0xFF6600)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        emitter.zPosition = -5
        emitter.particleTexture = dotTexture
        worldNode.addChild(emitter)
        
        // Larger sparks — rare, brighter, slower
        let sparkEmitter = SKEmitterNode()
        sparkEmitter.particleBirthRate = 2
        sparkEmitter.particleLifetime = 3
        sparkEmitter.particleLifetimeRange = 1.5
        sparkEmitter.particlePositionRange = CGVector(dx: GameConfig.Arena.radius * 1.5, dy: GameConfig.Arena.radius * 1.5)
        sparkEmitter.particleSpeed = 8
        sparkEmitter.particleSpeedRange = 5
        sparkEmitter.emissionAngle = .pi / 2
        sparkEmitter.emissionAngleRange = 0.6
        sparkEmitter.particleAlpha = 0.6
        sparkEmitter.particleAlphaRange = 0.2
        sparkEmitter.particleAlphaSpeed = -0.15
        sparkEmitter.particleScale = 0.15
        sparkEmitter.particleScaleRange = 0.08
        sparkEmitter.particleScaleSpeed = -0.02
        sparkEmitter.particleColor = SKColor(hex: 0xFFAA33)
        sparkEmitter.particleColorBlendFactor = 1.0
        sparkEmitter.particleBlendMode = .add
        sparkEmitter.zPosition = -4
        sparkEmitter.particleTexture = dotTexture
        worldNode.addChild(sparkEmitter)
        
        // Faint ash — very dim, slow, gray
        let ashEmitter = SKEmitterNode()
        ashEmitter.particleBirthRate = 5
        ashEmitter.particleLifetime = 6
        ashEmitter.particleLifetimeRange = 3
        ashEmitter.particlePositionRange = CGVector(dx: GameConfig.Arena.radius * 2.2, dy: GameConfig.Arena.radius * 2.2)
        ashEmitter.particleSpeed = 5
        ashEmitter.particleSpeedRange = 3
        ashEmitter.emissionAngle = .pi / 2
        ashEmitter.emissionAngleRange = 1.0
        ashEmitter.particleAlpha = 0.15
        ashEmitter.particleAlphaRange = 0.08
        ashEmitter.particleAlphaSpeed = -0.02
        ashEmitter.particleScale = 0.04
        ashEmitter.particleScaleRange = 0.02
        ashEmitter.particleColor = SKColor(hex: 0x666666)
        ashEmitter.particleColorBlendFactor = 1.0
        ashEmitter.particleBlendMode = .alpha
        ashEmitter.zPosition = -6
        ashEmitter.particleTexture = dotTexture
        worldNode.addChild(ashEmitter)
        
        // Vignette overlay
        if let view = view {
            let vignette = VignetteNode(size: view.bounds.size)
            camera?.addChild(vignette)
        }
    }

    /// v1.6 Arena 2 ambience (Lyra canon): soft ash falling like verdicts —
    /// slow downward drift with lateral sway; rare pale-amber sparks stay
    /// reserved for player progression moments.
    /// v1.7: Coilworks static — precise, not cozy. Short-lived motes pop
    /// in, jitter, and vanish; sharp little sparks, never drifting rewards.
    private func setupCoilworksStatic(texture: SKTexture) {
        // Jittering motes — brief, tiny, all directions, no drift language
        let motes = SKEmitterNode()
        motes.particleBirthRate = 14
        motes.particleLifetime = 0.55
        motes.particleLifetimeRange = 0.35
        motes.particlePositionRange = CGVector(dx: GameConfig.Arena.radius * 2.1, dy: GameConfig.Arena.radius * 2.1)
        motes.particleSpeed = 10
        motes.particleSpeedRange = 14
        motes.emissionAngleRange = 2 * .pi
        motes.particleAlpha = 0.5
        motes.particleAlphaRange = 0.2
        motes.particleAlphaSpeed = -1.0    // sharp pop-out, not a fade-drift
        motes.particleScale = 0.045
        motes.particleScaleRange = 0.02
        motes.particleColor = SKColor(hex: 0xF6D36B)
        motes.particleColorBlendFactor = 1.0
        motes.particleBlendMode = .add
        motes.zPosition = -5
        motes.particleTexture = texture
        worldNode.addChild(motes)

        // Rare longer hop-sparks — a mote that jumps before dying
        let sparks = SKEmitterNode()
        sparks.particleBirthRate = 2.5
        sparks.particleLifetime = 0.35
        sparks.particleLifetimeRange = 0.15
        sparks.particlePositionRange = CGVector(dx: GameConfig.Arena.radius * 1.9, dy: GameConfig.Arena.radius * 1.9)
        sparks.particleSpeed = 55
        sparks.particleSpeedRange = 25
        sparks.emissionAngleRange = 2 * .pi
        sparks.particleAlpha = 0.6
        sparks.particleAlphaSpeed = -1.7
        sparks.particleScale = 0.035
        sparks.particleColor = SKColor(hex: 0xF6D36B)
        sparks.particleColorBlendFactor = 1.0
        sparks.particleBlendMode = .add
        sparks.zPosition = -5
        sparks.particleTexture = texture
        worldNode.addChild(sparks)
    }

    private func setupQuenchAsh(texture: SKTexture) {
        // Main ash fall — slow, dim, drifting down
        let ash = SKEmitterNode()
        ash.particleBirthRate = 10
        ash.particleLifetime = 6
        ash.particleLifetimeRange = 2.5
        ash.particlePositionRange = CGVector(dx: GameConfig.Arena.radius * 2.2, dy: GameConfig.Arena.radius * 2.2)
        ash.particleSpeed = 16
        ash.particleSpeedRange = 8
        ash.emissionAngle = -.pi / 2
        ash.emissionAngleRange = 0.25
        ash.xAcceleration = 3          // gentle lateral sway
        ash.particleAlpha = 0.3
        ash.particleAlphaRange = 0.15
        ash.particleAlphaSpeed = -0.04
        ash.particleScale = 0.05
        ash.particleScaleRange = 0.03
        ash.particleColor = SKColor(hex: 0xD8D0C4)
        ash.particleColorBlendFactor = 1.0
        ash.particleBlendMode = .alpha
        ash.zPosition = -5
        ash.particleTexture = texture
        worldNode.addChild(ash)

        // Sparse heavier flakes swaying the other way
        let flakes = SKEmitterNode()
        flakes.particleBirthRate = 3
        flakes.particleLifetime = 5
        flakes.particleLifetimeRange = 2
        flakes.particlePositionRange = CGVector(dx: GameConfig.Arena.radius * 1.8, dy: GameConfig.Arena.radius * 1.8)
        flakes.particleSpeed = 22
        flakes.particleSpeedRange = 10
        flakes.emissionAngle = -.pi / 2
        flakes.emissionAngleRange = 0.35
        flakes.xAcceleration = -4
        flakes.particleAlpha = 0.45
        flakes.particleAlphaRange = 0.15
        flakes.particleAlphaSpeed = -0.08
        flakes.particleScale = 0.09
        flakes.particleScaleRange = 0.04
        flakes.particleColor = SKColor(hex: 0xB8B0A4)
        flakes.particleColorBlendFactor = 1.0
        flakes.particleBlendMode = .alpha
        flakes.zPosition = -4
        flakes.particleTexture = texture
        worldNode.addChild(flakes)

        // Near-floor haze — very dim, almost still
        let haze = SKEmitterNode()
        haze.particleBirthRate = 4
        haze.particleLifetime = 8
        haze.particleLifetimeRange = 3
        haze.particlePositionRange = CGVector(dx: GameConfig.Arena.radius * 2.4, dy: GameConfig.Arena.radius * 2.4)
        haze.particleSpeed = 4
        haze.particleSpeedRange = 3
        haze.emissionAngle = -.pi / 2
        haze.emissionAngleRange = 0.8
        haze.particleAlpha = 0.1
        haze.particleAlphaRange = 0.05
        haze.particleAlphaSpeed = -0.012
        haze.particleScale = 0.04
        haze.particleScaleRange = 0.02
        haze.particleColor = SKColor(hex: 0x6A6256)
        haze.particleColorBlendFactor = 1.0
        haze.particleBlendMode = .alpha
        haze.zPosition = -6
        haze.particleTexture = texture
        worldNode.addChild(haze)
    }

    // MARK: - Tutorial Hint
    
    private func showTutorialHintIfNeeded() {
        guard let camera = camera, let view = view else { return }
        
        // Only show on first ever run
        let hasSeenTutorial = UserDefaults.standard.bool(forKey: "sparkforge_tutorial_seen")
        guard !hasSeenTutorial else { return }
        UserDefaults.standard.set(true, forKey: "sparkforge_tutorial_seen")
        
        let s = DeviceScale.ui
        let tutorialNode = SKNode()
        tutorialNode.zPosition = 180
        tutorialNode.name = "tutorialHint"
        
        // Semi-transparent backdrop
        let bg = SKShapeNode(rectOf: CGSize(width: 2000, height: 2000))
        bg.fillColor = SKColor(hex: 0x000000, alpha: 0.6)
        bg.strokeColor = .clear
        tutorialNode.addChild(bg)
        
        // Left side hint — joystick area
        let moveHint = SKLabelNode(fontNamed: "Menlo-Bold")
        moveHint.text = "◀ TOUCH LEFT SIDE TO MOVE"
        moveHint.fontSize = 14 * s
        moveHint.fontColor = SKColor(hex: 0xFFAA33)
        moveHint.position = CGPoint(x: -view.bounds.width / 6, y: 0)
        moveHint.zPosition = 1
        tutorialNode.addChild(moveHint)
        
        // Left arrow indicator
        let leftArrow = SKLabelNode(fontNamed: "Menlo-Bold")
        leftArrow.text = "👆"
        leftArrow.fontSize = 30 * s
        leftArrow.position = CGPoint(x: -view.bounds.width / 6, y: -40 * s)
        tutorialNode.addChild(leftArrow)
        
        // Auto-attack hint
        let attackHint = SKLabelNode(fontNamed: "Menlo")
        attackHint.text = "you attack automatically"
        attackHint.fontSize = 11 * s
        attackHint.fontColor = SKColor(hex: 0x888888)
        attackHint.position = CGPoint(x: 0, y: -80 * s)
        tutorialNode.addChild(attackHint)
        
        // Tap to dismiss
        let dismissHint = SKLabelNode(fontNamed: "Menlo")
        dismissHint.text = "tap anywhere to start"
        dismissHint.fontSize = 12 * s
        dismissHint.fontColor = SKColor(hex: 0x666666)
        dismissHint.position = CGPoint(x: 0, y: -120 * s)
        tutorialNode.addChild(dismissHint)
        
        // Breathing pulse on dismiss hint
        let breathe = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 1.0),
            SKAction.fadeAlpha(to: 1.0, duration: 1.0)
        ])
        dismissHint.run(SKAction.repeatForever(breathe))
        
        camera.addChild(tutorialNode)
        
        // Pause game state until dismissed
        gameState = .levelUp  // Reuse paused state — touches will dismiss
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        switch gameState {
        case .playing:
            // v1.7: Pause hit zone is anchored to the drawn button, expanded to thumb size
            if let cam = camera {
                let camLoc = touch.location(in: cam)
                let hitZone = pauseButton.frame.insetBy(dx: -28, dy: -28)
                if hitZone.contains(camLoc) {
                    pauseGame()
                    return
                }
            }
            _ = joystick.handleTouchBegan(touch, in: self)
            
        case .dead:
            handleDeathScreenTap(touch)
            
        case .levelUp:
            // Check if tutorial hint is showing — dismiss it first
            if let tutorial = camera?.childNode(withName: "tutorialHint") {
                tutorial.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.2),
                    SKAction.removeFromParent()
                ]))
                gameState = .playing
                return
            }
            handleCardSelection(touch)
            
        case .paused:
            handlePauseScreenTap(touch)
            
        case .reviving:
            // v1.7: the post-ad hold — resume only on the player's tap
            if reviveHoldOverlay != nil {
                resumeFromRevive()
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing else { return }
        for touch in touches {
            joystick.handleTouchMoved(touch, in: self)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            joystick.handleTouchEnded(touch)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Force release on cancellation — don't rely on touch identity matching
        joystick.forceRelease()
    }
    
    // MARK: - Death Screen Interaction
    
    private func handleDeathScreenTap(_ touch: UITouch) {
        let location = touch.location(in: deathOverlay)
        
        // Revive button
        if let reviveBtn = deathOverlay.childNode(withName: "reviveButton"),
           reviveBtn.alpha > 0 {
            let btnFrame = CGRect(x: reviveBtn.position.x - 90, y: reviveBtn.position.y - 18,
                                  width: 180, height: 36)
            if btnFrame.contains(location) {
                performRevive()
                return
            }
        }
        
        // v1.5: XP Boost button
        if let xpBoostBtn = deathOverlay.childNode(withName: "xpBoostButton"),
           xpBoostBtn.alpha > 0 {
            let btnFrame = CGRect(x: xpBoostBtn.position.x - 80, y: xpBoostBtn.position.y - 16,
                                  width: 160, height: 32)
            if btnFrame.contains(location) {
                performXPBoost()
                return
            }
        }
        
        // Restart button
        if let restartBtn = deathOverlay.childNode(withName: "restartButton") {
            let btnFrame = CGRect(x: restartBtn.position.x - 70, y: restartBtn.position.y - 16,
                                  width: 140, height: 32)
            if btnFrame.contains(location) {
                restartGame()
                return
            }
        }
        
        // Menu button
        if let menuBtn = deathOverlay.childNode(withName: "menuButton") {
            let btnFrame = CGRect(x: menuBtn.position.x - 40, y: menuBtn.position.y - 12,
                                  width: 80, height: 24)
            if btnFrame.contains(location) {
                returnToTitle()
                return
            }
        }
    }
    
    // MARK: - Return to Title
    
    private func returnToTitle() {
        guard let view = view else { return }
        
        let titleScene = TitleScene(size: view.bounds.size)
        titleScene.scaleMode = .resizeFill
        titleScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        let transition = SKTransition.fade(with: .black, duration: 0.4)
        view.presentScene(titleScene, transition: transition)
    }
    
    // MARK: - v1.4: Pause (v1.7: Pause Menu v2)

    private func pauseGame() {
        guard gameState == .playing else { return }
        gameState = .paused
        joystick.forceRelease()
        pauseMenu.show(upgradeManager: upgradeManager)
    }

    private func resumeGame() {
        guard gameState == .paused else { return }
        gameState = .playing
        // Brief invulnerability after unpause so player can reorient
        invulnerableTimer = 1.0
        pauseMenu.hide()
    }

    private func handlePauseScreenTap(_ touch: UITouch) {
        pauseMenu.handleTap(at: touch.location(in: pauseMenu))
    }
    
    // MARK: - Card Selection
    
    private func handleCardSelection(_ touch: UITouch) {
        let location = touch.location(in: levelUpOverlay)
        
        // Check reroll button first
        if let rerollBtn = levelUpOverlay.childNode(withName: "rerollButton"),
           rerollBtn.alpha > 0 {
            let btnFrame = CGRect(x: rerollBtn.position.x - 75, y: rerollBtn.position.y - 14,
                                  width: 150, height: 28)
            if btnFrame.contains(location) {
                performReroll()
                return
            }
        }

        // v1.6: Extra card button
        if let extraBtn = levelUpOverlay.childNode(withName: "extraCardButton"),
           extraBtn.alpha > 0 {
            let btnFrame = CGRect(x: extraBtn.position.x - 75, y: extraBtn.position.y - 14,
                                  width: 150, height: 28)
            if btnFrame.contains(location) {
                performExtraCard()
                return
            }
        }

        // Check card taps (frames scale down when 4 cards are shown)
        for cardNode in displayedCards {
            let w = UpgradeCardNode.cardWidth * cardNode.xScale
            let h = UpgradeCardNode.cardHeight * cardNode.yScale
            let cardFrame = CGRect(
                x: cardNode.position.x - w / 2,
                y: cardNode.position.y - h / 2,
                width: w,
                height: h
            )

            if cardFrame.contains(location) {
                selectCard(cardNode)
                return
            }
        }
    }
    
    private func selectCard(_ selectedNode: UpgradeCardNode) {
        AudioManager.shared.play(.cardSelect)
        upgradeManager.pickCard(selectedNode.card, stats: playerStats)
        let synergies = upgradeManager.checkSynergies(stats: playerStats)
        player.updateCollisionRadius()
        
        // Update buff tracker
        buffTracker.update(tagCounts: upgradeManager.tagCounts)
        
        // v1.4: Build identity hint
        if let buildHint = upgradeManager.checkBuildHint() {
            showBuildHint(buildHint)
        }
        
        for cardNode in displayedCards {
            if cardNode === selectedNode {
                cardNode.animateSelection { [weak self] in
                    self?.finishLevelUp(synergies: synergies)
                }
            } else {
                cardNode.animateDismiss()
            }
        }
        displayedCards.removeAll()
    }
    
    // MARK: - Reroll
    
    private func performReroll() {
        guard !rerollUsedThisRun else { return }
        
        if IAPManager.shared.hasRemovedAds {
            executeReroll()
            return
        }
        
        let vc = view?.window?.rootViewController
        adReviveManager.requestRerollAd(from: vc) { [weak self] success in
            guard success else { return }
            self?.executeReroll()
        }
    }
    
    private func executeReroll() {
        rerollUsedThisRun = true
        
        // Dismiss current cards
        for card in displayedCards {
            card.animateDismiss()
        }
        displayedCards.removeAll()
        
        // Hide reroll button
        if let rerollBtn = levelUpOverlay.childNode(withName: "rerollButton") {
            rerollBtn.run(SKAction.fadeOut(withDuration: 0.15))
        }
        
        // Draw new cards after brief delay
        run(SKAction.wait(forDuration: 0.25)) { [weak self] in
            guard let self = self else { return }
            let newCards = self.upgradeManager.drawCards(count: 3)
            self.showCardSelection(newCards)
        }
    }
    
    // MARK: - v1.6: Extra Card

    private func performExtraCard() {
        guard !extraCardUsedThisRun else { return }
        guard displayedCards.count < 4 else { return }

        if IAPManager.shared.hasRemovedAds {
            executeExtraCard()
            return
        }

        let vc = view?.window?.rootViewController
        adReviveManager.requestExtraCardAd(from: vc) { [weak self] success in
            guard success else { return }
            self?.executeExtraCard()
        }
    }

    private func executeExtraCard() {
        extraCardUsedThisRun = true

        guard let bonus = upgradeManager.drawBonusCard(excluding: displayedCards.map { $0.card }) else { return }

        // Rebuild the spread with the bonus card — four cards render smaller
        let cards = displayedCards.map { $0.card } + [bonus]
        showCardSelection(cards)

        if let extraBtn = levelUpOverlay.childNode(withName: "extraCardButton") {
            extraBtn.run(SKAction.fadeOut(withDuration: 0.15))
        }
    }

    private func finishLevelUp(synergies: [String]) {
        if let firstSynergy = synergies.first {
            showSynergyNotification(firstSynergy)
        }
        
        if synergies.contains(where: { $0.contains("Barrier Pulse") }) {
            barrierPulse()
        }

        // v1.6: Static Crown — level-ups release a shock burst
        if playerStats.staticCrownDamage > 0 {
            damageEnemiesInRadius(playerStats.staticCrownRadius,
                                  around: player.position,
                                  damage: playerStats.staticCrownDamage)
            showRingPulse(at: player.position,
                          radius: playerStats.staticCrownRadius,
                          colorHex: 0xFFE066)
        }
        
        // v1.4: Post-pick buffer — brief invulnerability so the player can reorient
        invulnerableTimer = 2.5
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.2),
            SKAction.fadeAlpha(to: 1.0, duration: 0.2)
        ])
        player.run(SKAction.repeat(blink, count: 4), withKey: "invulnBlink")
        
        gameState = .playing
        levelUpOverlay.run(SKAction.fadeOut(withDuration: 0.15))
    }
    
    private func showSynergyNotification(_ text: String) {
        AudioManager.shared.play(.buildHint)
        synergyLabel.text = text
        synergyLabel.alpha = 0
        
        let show = SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.2),
            SKAction.wait(forDuration: 2.0),
            SKAction.fadeOut(withDuration: 0.5)
        ])
        synergyLabel.run(show)
    }
    
    private func barrierPulse() {
        for enemy in enemies {
            let direction = (enemy.position - player.position).normalized
            enemy.position += direction * 60
        }
    }
    
    // MARK: - Game Loop
    
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        guard gameState == .playing else { return }
        
        // Invulnerability timer
        if invulnerableTimer > 0 {
            invulnerableTimer -= dt
        }
        
        // v1.4: Damage cooldown (i-frames after taking a hit)
        if damageCooldownTimer > 0 {
            damageCooldownTimer -= dt
        }
        
        let preMovePosition = player.position
        player.move(direction: joystick.direction, deltaTime: dt)
        if joystick.direction != .zero {
            lastMoveDirection = joystick.direction.normalized
        }
        // v1.7 Coilworks cards: movement charges Induction Step;
        // stillness (micro-adjustments included) braces Grounded Core
        playerStats.addInductionCharge(distance: player.position.distance(to: preMovePosition))
        playerStats.updateGroundedCore(isMoving: joystick.direction.length > 0.15, dt: dt)
        updateGroundedCoreRing()
        updateEnemies(dt)
        updateAutoAttack(dt)
        updateProjectiles(dt)
        updateEnemyProjectiles(dt)
        updateXPOrbs(dt)
        updatePassiveEffects(dt)
        updateGravityWells(dt)
        updateChillTrail(dt)
        updateArcWake(dt)
        updateNullBlooms(dt)
        
        let spawnEvent = waveManager.update(deltaTime: dt)
        // v1.6 tuning: wave spawns pause while a boss holds the arena —
        // the stage belongs to him. Boss-summoned minions (Titan's spawn
        // pattern) still arrive; waves resume the moment he falls.
        if spawnEvent.shouldSpawnEnemy && boss == nil { spawnEnemy() }
        if spawnEvent.shouldSpawnMiniBoss {
            // v1.4: Spawn real boss if gate is met, otherwise mini-boss
            // v1.6: each arena summons its own warden at the 90s bell
            if arenaConfig.id == 0 && ProgressionManager.shared.arena1BossUnlocked && boss == nil {
                spawnBoss()
            } else if arenaConfig.id == 1 && ProgressionManager.shared.quenchWardenUnlocked && boss == nil {
                spawnQuenchWarden()
            } else if arenaConfig.id == 2 && ProgressionManager.shared.dynamoChoirUnlocked && boss == nil {
                spawnDynamoChoir()
            } else {
                spawnMiniBoss()
            }
        }

        // v1.4: Update boss AI
        boss?.update(deltaTime: dt, playerPosition: player.position)

        // v1.7: Relay Imp danger arcs (Coilworks only)
        if arenaConfig.id == 2 {
            updateRelayArcs(dt)
        }

        // v1.6: Quench Field — momentum pressure on the player
        if fieldImpulseRemaining > 0 {
            fieldImpulseRemaining -= dt
            if let boss = boss, !boss.isDead {
                let dir = (boss.position - player.position).normalized
                player.position += dir * fieldImpulseStrength * CGFloat(dt)
                // Keep the shove inside the arena
                let maxDist = GameConfig.Arena.radius - GameConfig.Player.collisionRadius
                if player.position.length > maxDist {
                    player.position = player.position.normalized * maxDist
                }
            }
        }
        
        // v1.4: Health orb spawning + updating
        healthOrbTimer += dt
        if healthOrbTimer >= nextHealthOrbSpawn {
            healthOrbTimer = 0
            nextHealthOrbSpawn = TimeInterval.random(in: GameConfig.HealthOrb.minSpawnInterval...GameConfig.HealthOrb.maxSpawnInterval)
            let orb = HealthOrbNode()
            orb.position = HealthOrbNode.randomArenaPosition()
            orb.zPosition = 4
            healthOrbs.append(orb)
            worldNode.addChild(orb)
        }
        healthOrbs.removeAll { orb in
            if orb.update(deltaTime: dt) { orb.removeFromParent(); return true }
            return false
        }
        
        // v1.4: Magnet orb spawning + updating
        magnetOrbTimer += dt
        if magnetOrbTimer >= nextMagnetOrbSpawn {
            magnetOrbTimer = 0
            nextMagnetOrbSpawn = TimeInterval.random(in: GameConfig.MagnetOrb.minSpawnInterval...GameConfig.MagnetOrb.maxSpawnInterval)
            let orb = MagnetOrbNode()
            orb.position = MagnetOrbNode.randomArenaPosition()
            orb.zPosition = 4
            magnetOrbs.append(orb)
            worldNode.addChild(orb)
        }
        magnetOrbs.removeAll { orb in
            if orb.update(deltaTime: dt) { orb.removeFromParent(); return true }
            return false
        }
        
        updateHUD()
        
        // Camera follows player
        camera?.position = player.position
    }
    
    // MARK: - Enemy Updates
    
    private func updateEnemies(_ dt: TimeInterval) {
        var diedFromDOT: [Int] = []
        
        for (index, enemy) in enemies.enumerated() {
            // Use ranged AI for ranged enemies
            if let ranged = enemy as? RangedEnemyNode {
                ranged.rangedChase(target: player.position, deltaTime: dt, globalSlow: playerStats.globalEnemySlow)
            } else {
                enemy.chase(target: player.position, deltaTime: dt, globalSlow: playerStats.globalEnemySlow)
            }
            
            let diedDOT = enemy.updateStatusEffects(deltaTime: dt)
            if diedDOT {
                diedFromDOT.append(index)
            }
            
            if playerStats.burnSpreads && enemy.isBurning {
                spreadBurn(from: enemy)
            }

            // v1.7 Relay Burn: burning foes can arc Shock (dt-scaled roll)
            if playerStats.relayBurnActive && enemy.isBurning
               && CGFloat.random(in: 0...1) < playerStats.relayBurnRate * CGFloat(dt) {
                relayArcSources.append(enemy)
            }
        }

        for index in diedFromDOT.reversed() {
            let enemy = enemies[index]
            let pos = enemy.position
            let xp = enemy.xpValue
            enemies.remove(at: index)
            onEnemyKilled(at: pos, xpValue: xp, enemy: enemy)
        }

        // Fire queued Relay Burn arcs after the removal pass (safe mutation)
        if !relayArcSources.isEmpty {
            for source in relayArcSources where source.parent != nil {
                fireRelayBurnArc(from: source)
            }
            relayArcSources.removeAll()
        }
    }

    // MARK: - v1.7: Relay Burn (Fire/Shock bridge card)

    private var relayArcSources: [EnemyNode] = []

    /// A small Shock arc jumps from a burning enemy to one nearby enemy.
    /// One hop, no recursion — a bridge, not free chain lightning.
    private func fireRelayBurnArc(from source: EnemyNode) {
        var closest: EnemyNode?
        var closestDist = playerStats.relayBurnRadius
        for enemy in enemies where enemy !== source {
            let dist = source.position.distance(to: enemy.position)
            if dist < closestDist {
                closestDist = dist
                closest = enemy
            }
        }
        guard let target = closest else { return }

        let line = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: source.position)
        path.addLine(to: target.position)
        line.path = path
        line.strokeColor = SKColor(hex: 0x44BBFF, alpha: 0.8)
        line.lineWidth = 1.5
        line.glowWidth = 3
        line.zPosition = 8
        worldNode.addChild(line)
        line.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))

        if target.takeDamage(playerStats.relayBurnDamage) {
            if let index = enemies.firstIndex(where: { $0 === target }) {
                enemies.remove(at: index)
            }
            onEnemyKilled(at: target.position, xpValue: target.xpValue, enemy: target)
        }
    }

    // MARK: - v1.7: Grounded Core brace indicator

    private var groundedCoreRing: SKShapeNode?

    /// A quiet guard-green ring at the spark's feet while braced
    private func updateGroundedCoreRing() {
        if playerStats.groundedCoreBraced {
            if groundedCoreRing == nil {
                let ring = SKShapeNode(circleOfRadius: GameConfig.Player.visualRadius + 7)
                ring.strokeColor = SKColor(hex: 0x88AA44, alpha: 0.65)
                ring.fillColor = .clear
                ring.lineWidth = 1.5
                ring.glowWidth = 2
                ring.zPosition = 9
                ring.setScale(1.3)
                player.addChild(ring)
                ring.run(SKAction.scale(to: 1.0, duration: 0.15))
                groundedCoreRing = ring
            }
        } else if let ring = groundedCoreRing {
            groundedCoreRing = nil
            ring.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.12),
                SKAction.removeFromParent()
            ]))
        }
    }
    
    private func spreadBurn(from source: EnemyNode) {
        let radius = playerStats.burnSpreadRadius
        for enemy in enemies {
            guard enemy !== source, !enemy.isBurning else { continue }
            if source.position.distance(to: enemy.position) < radius {
                enemy.applyBurn(playerStats.burnDPS * 0.5, duration: playerStats.burnDuration)
            }
        }
    }
    
    // MARK: - Auto-Attack System
    
    private func updateAutoAttack(_ dt: TimeInterval) {
        timeSinceLastShot += dt
        
        var effectiveInterval = playerStats.effectiveFireInterval
        if playerStats.isKillStreakActive(atTime: waveManager.elapsedTime) {
            effectiveInterval *= TimeInterval(1.0 - playerStats.killStreakFireRateBonus)
        }
        
        guard timeSinceLastShot >= effectiveInterval else { return }
        guard let targetPosition = findNearestTargetPosition() else { return }

        timeSinceLastShot = 0

        let totalProjectiles = 1 + playerStats.extraProjectiles
        let baseDirection = (targetPosition - player.position).normalized
        let isSpreadShot = playerStats.recordShot()
        let shotCount = isSpreadShot ? playerStats.spreadShotCount : totalProjectiles
        
        if shotCount == 1 {
            fireProjectile(direction: baseDirection)
        } else {
            let totalSpread = playerStats.spreadAngle * CGFloat(shotCount - 1)
            let startAngle = atan2(baseDirection.y, baseDirection.x) - totalSpread / 2
            
            for i in 0..<shotCount {
                let angle = startAngle + playerStats.spreadAngle * CGFloat(i)
                let dir = CGPoint(x: cos(angle), y: sin(angle))
                fireProjectile(direction: dir)
            }
        }
    }
    
    /// v1.6: Auto-aim considers regular enemies AND the boss.
    private func findNearestTargetPosition() -> CGPoint? {
        let range = playerStats.effectiveProjectileRange
        var closestPosition: CGPoint?
        var closestDist: CGFloat = .greatestFiniteMagnitude

        for enemy in enemies {
            let dist = player.position.distance(to: enemy.position)
            if dist < range && dist < closestDist {
                closestDist = dist
                closestPosition = enemy.position
            }
        }

        if let boss = boss, !boss.isDead {
            let dist = player.position.distance(to: boss.position)
            if dist < range && dist < closestDist {
                closestDist = dist
                closestPosition = boss.position
            }
        }

        return closestPosition
    }
    
    private func fireProjectile(direction: CGPoint) {
        let isCrit = CGFloat.random(in: 0...1) < playerStats.critChance
        
        let projectile = ProjectileNode(
            direction: direction,
            speed: playerStats.effectiveProjectileSpeed,
            range: playerStats.effectiveProjectileRange,
            pierces: playerStats.pierceCount,
            damageMultiplier: playerStats.effectiveDamageMultiplier,
            isCrit: isCrit,
            spawnsGravityWell: playerStats.gravityWellOnExpire
        )
        projectile.position = player.position
        projectile.zPosition = 8
        projectiles.append(projectile)
        worldNode.addChild(projectile)
    }
    
    // MARK: - Projectile Updates
    
    private func updateProjectiles(_ dt: TimeInterval) {
        var toRemove: [Int] = []
        
        for (index, projectile) in projectiles.enumerated() {
            if projectile.move(deltaTime: dt) {
                toRemove.append(index)
            }
        }
        
        for index in toRemove.reversed() {
            let projectile = projectiles[index]
            // v1.6: Gravity Well — projectiles that expire at max range leave a pull zone
            if projectile.spawnsGravityWell {
                // v1.7 Dead Circuit: void zones linger longer
                spawnGravityWell(at: projectile.position,
                                 radius: playerStats.gravityWellRadius,
                                 duration: playerStats.gravityWellDuration * playerStats.voidZoneDurationMultiplier,
                                 dps: playerStats.gravityWellDPS)
            }
            projectile.removeFromParent()
            projectiles.remove(at: index)
        }
    }
    
    // MARK: - Enemy Projectile Updates
    
    private func updateEnemyProjectiles(_ dt: TimeInterval) {
        var toRemove: [Int] = []
        
        for (index, proj) in enemyProjectiles.enumerated() {
            if proj.move(deltaTime: dt) {
                toRemove.append(index)
            }
        }
        
        for index in toRemove.reversed() {
            enemyProjectiles[index].removeFromParent()
            enemyProjectiles.remove(at: index)
        }
    }
    
    // MARK: - XP Orb Updates
    
    private func updateXPOrbs(_ dt: TimeInterval) {
        let pickupRadius = playerStats.effectivePickupRadius
        for orb in xpOrbs {
            orb.updateMagnet(playerPosition: player.position, pickupRadius: pickupRadius, deltaTime: dt)
        }
    }
    
    // MARK: - Passive Effects
    
    private var passiveDOTAccumulator: CGFloat = 0.0
    
    private func updatePassiveEffects(_ dt: TimeInterval) {
        // Tesla field
        if playerStats.teslaFieldDPS > 0 {
            for enemy in enemies {
                if player.position.distance(to: enemy.position) < playerStats.teslaFieldRadius {
                    enemy.applyBurn(playerStats.teslaFieldDPS, duration: 0.5)
                }
            }
        }
        
        // Arena-wide DOT
        if playerStats.passiveArenaDPS > 0 {
            passiveDOTAccumulator += playerStats.passiveArenaDPS * CGFloat(dt)
            if passiveDOTAccumulator >= 1.0 {
                let dmg = Int(passiveDOTAccumulator)
                passiveDOTAccumulator -= CGFloat(dmg)
                for enemy in enemies {
                    enemy.takeDamage(dmg)
                }
            }
        }
        
        // v1.3: Overcharge — builds while unhit
        playerStats.updateOvercharge(dt)
        
        // v1.3: Phase Skin — tick timers
        playerStats.updatePhaseSkin(dt)
        
        // v1.3: Magnetic Core — tick speed boost timer
        playerStats.updateMagneticCore(dt)
        
        // v1.3: Static Field — slow enemies near player
        if playerStats.staticFieldRange > 0 {
            for enemy in enemies {
                if player.position.distance(to: enemy.position) < playerStats.staticFieldRange {
                    enemy.applySlow(playerStats.staticFieldSlow, duration: 0.5)
                }
            }
        }
        
        // v1.3: Unstable Core — periodic burst
        if playerStats.updateUnstableCore(dt) {
            performUnstableCoreBurst()
        }

        // v1.6: Singularity (Void tier-7) — periodic massive gravity wells
        if playerStats.singularityActive {
            singularityTimer += dt
            if singularityTimer >= playerStats.singularityInterval {
                singularityTimer = 0
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let dist = CGFloat.random(in: 0...(GameConfig.Arena.radius * 0.6))
                let pos = CGPoint(x: cos(angle) * dist, y: sin(angle) * dist)
                spawnGravityWell(at: pos,
                                 radius: playerStats.singularityRadius,
                                 duration: playerStats.singularityDuration,
                                 dps: playerStats.singularityDPS)
            }
        }

        // v1.6: Aegis Pulse — periodic DEF-scaled pulse around the player
        if playerStats.updateAegisPulse(dt) {
            damageEnemiesInRadius(playerStats.aegisPulseRadius,
                                  around: player.position,
                                  damage: playerStats.aegisPulseDamage)
            showRingPulse(at: player.position,
                          radius: playerStats.aegisPulseRadius,
                          colorHex: 0xCCC8AA)
        }

        // v1.6: Hoarfrost + Cauterize regen
        let regen = playerStats.updateRegen(dt)
        if regen > 0 {
            playerStats.heal(regen)
            hpBar.flashHeal()
        }
    }

    // MARK: - v1.6: Gravity Wells

    private func spawnGravityWell(at position: CGPoint, radius: CGFloat, duration: TimeInterval, dps: CGFloat) {
        let well = GravityWellNode(radius: radius, duration: duration, dps: dps)
        well.position = position
        well.zPosition = 3
        gravityWells.append(well)
        worldNode.addChild(well)
    }

    private func updateGravityWells(_ dt: TimeInterval) {
        guard !gravityWells.isEmpty else { return }

        var expired: [Int] = []
        for (index, well) in gravityWells.enumerated() {
            let result = well.update(deltaTime: dt, enemies: enemies)

            // Event Horizon / Singularity: DOT on enemies inside the well
            // (reference-based removal — onEnemyKilled side effects can mutate the array)
            if result.dotDamage > 0 {
                var killed: [EnemyNode] = []
                for enemy in enemies
                where enemy.position.distance(to: well.position) < well.radius {
                    if enemy.takeDamage(result.dotDamage) {
                        killed.append(enemy)
                    }
                }
                for enemy in killed {
                    if let i = enemies.firstIndex(where: { $0 === enemy }) {
                        enemies.remove(at: i)
                        onEnemyKilled(at: enemy.position, xpValue: enemy.xpValue, enemy: enemy)
                    }
                }
            }

            if result.expired { expired.append(index) }
        }

        for index in expired.reversed() {
            gravityWells[index].collapseAndRemove()
            gravityWells.remove(at: index)
        }
    }

    // MARK: - v1.6: Chill Trail (Glacial Drift)

    private func updateChillTrail(_ dt: TimeInterval) {
        let now = waveManager.elapsedTime

        // Drop trail points while moving
        if playerStats.chillTrail && joystick.direction != .zero {
            chillTrailDropTimer += dt
            if chillTrailDropTimer >= 0.15 {
                chillTrailDropTimer = 0
                chillTrailPoints.append((position: player.position,
                                         expiry: now + playerStats.chillTrailDuration))
                spawnChillTrailVisual(at: player.position)
            }
        }

        chillTrailPoints.removeAll { $0.expiry <= now }
        guard !chillTrailPoints.isEmpty else { return }

        // Slow enemies standing on the trail
        for enemy in enemies {
            for point in chillTrailPoints
            where enemy.position.distance(to: point.position) < 22 {
                enemy.applySlow(playerStats.effectiveSlow(playerStats.chillTrailSlow), duration: 0.5)
                break
            }
        }
    }

    private func spawnChillTrailVisual(at position: CGPoint) {
        let frost = SKShapeNode(circleOfRadius: 9)
        frost.fillColor = SKColor(hex: 0x88CCFF, alpha: 0.12)
        frost.strokeColor = SKColor(hex: 0xAADDFF, alpha: 0.25)
        frost.lineWidth = 1
        frost.position = position
        frost.zPosition = 2
        worldNode.addChild(frost)
        frost.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: playerStats.chillTrailDuration),
            SKAction.removeFromParent()
        ]))
    }
    
    // MARK: - v1.6: Shared Burst Helpers (Unit 3)

    /// Damage all enemies within radius of a point. Kills spawn XP orbs
    /// directly (Ember Burst precedent — burst kills don't re-trigger bursts).
    private func damageEnemiesInRadius(_ radius: CGFloat, around position: CGPoint, damage: Int) {
        var killed: [EnemyNode] = []
        for enemy in enemies where enemy.position.distance(to: position) < radius {
            if enemy.takeDamage(damage) {
                killed.append(enemy)
            }
        }
        for enemy in killed {
            if let index = enemies.firstIndex(where: { $0 === enemy }) {
                spawnXPOrb(at: enemy.position, value: enemy.xpValue)
                enemies.remove(at: index)
            }
        }
    }

    /// Expanding ring visual for pulses and bursts.
    private func showRingPulse(at position: CGPoint, radius: CGFloat, colorHex: UInt32) {
        let ring = SKShapeNode(circleOfRadius: 1)
        ring.strokeColor = SKColor(hex: colorHex, alpha: 0.6)
        ring.fillColor = SKColor(hex: colorHex, alpha: 0.1)
        ring.lineWidth = 2
        ring.position = position
        ring.zPosition = 6
        worldNode.addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: radius, duration: 0.25),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - v1.6: Arc Wake (Unit 3)

    private func updateArcWake(_ dt: TimeInterval) {
        guard playerStats.arcWakeDamage > 0 else { return }
        let now = waveManager.elapsedTime

        // Drop sparks while moving
        if joystick.direction != .zero {
            arcWakeDropTimer += dt
            if arcWakeDropTimer >= playerStats.arcWakeDropInterval {
                arcWakeDropTimer = 0
                arcWakeSparks.append((position: player.position,
                                      expiry: now + playerStats.arcWakeLifetime))
                spawnArcWakeVisual(at: player.position)
            }
        }

        arcWakeSparks.removeAll { $0.expiry <= now }
        guard !arcWakeSparks.isEmpty else { return }

        // Each spark zaps the first enemy that touches it, then is consumed
        var consumedSparks: [Int] = []
        var killed: [EnemyNode] = []
        for (sIndex, spark) in arcWakeSparks.enumerated() {
            for enemy in enemies where !killed.contains(where: { $0 === enemy }) {
                if enemy.position.distance(to: spark.position) < 16 {
                    if enemy.takeDamage(playerStats.arcWakeDamage) {
                        killed.append(enemy)
                    }
                    consumedSparks.append(sIndex)
                    break
                }
            }
        }
        for index in consumedSparks.reversed() {
            arcWakeSparks.remove(at: index)
        }
        for enemy in killed {
            if let index = enemies.firstIndex(where: { $0 === enemy }) {
                enemies.remove(at: index)
                onEnemyKilled(at: enemy.position, xpValue: enemy.xpValue, enemy: enemy)
            }
        }
    }

    private func spawnArcWakeVisual(at position: CGPoint) {
        let spark = SKShapeNode(circleOfRadius: 4)
        spark.fillColor = SKColor(hex: 0xFFE066, alpha: 0.5)
        spark.strokeColor = SKColor(hex: 0xFFF2AA, alpha: 0.7)
        spark.lineWidth = 1
        spark.glowWidth = 3
        spark.position = position
        spark.zPosition = 2
        worldNode.addChild(spark)
        spark.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: playerStats.arcWakeLifetime),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - v1.6: Null Bloom (Unit 3)

    private func updateNullBlooms(_ dt: TimeInterval) {
        guard !nullBloomZones.isEmpty else { return }
        let now = waveManager.elapsedTime

        nullBloomZones.removeAll { $0.expiry <= now }

        for zone in nullBloomZones {
            for enemy in enemies
            where enemy.position.distance(to: zone.position) < playerStats.nullBloomRadius {
                enemy.applySlow(playerStats.effectiveSlow(playerStats.nullBloomSlow), duration: 0.3)
            }
        }
    }

    private func spawnNullBloom(at position: CGPoint) {
        nullBloomZones.append((position: position,
                               expiry: waveManager.elapsedTime + playerStats.nullBloomDuration))

        let zone = SKShapeNode(circleOfRadius: playerStats.nullBloomRadius)
        zone.fillColor = SKColor(hex: 0x223366, alpha: 0.18)
        zone.strokeColor = SKColor(hex: 0x4466DD, alpha: 0.35)
        zone.lineWidth = 1
        zone.position = position
        zone.zPosition = 2
        worldNode.addChild(zone)
        zone.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: playerStats.nullBloomDuration),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Unstable Core Burst
    
    private func performUnstableCoreBurst() {
        let radius = playerStats.unstableCoreRadius
        let damage = playerStats.unstableCoreDamage
        
        // Damage nearby enemies
        for enemy in enemies {
            if player.position.distance(to: enemy.position) < radius {
                enemy.takeDamage(damage)
            }
        }
        
        // v1.4: Self-damage is HP-based instead of losing a lethal save
        let died = playerStats.takeDamage(playerStats.unstableCoreSelfDamage)
        hpBar.flashDamage()
        AudioManager.shared.play(.playerDamage)
        if died {
            if player.tryLethalSave() {
                // Survived — continue
            } else {
                playerDied()
                return
            }
        }
        
        // Visual: red-purple pulse ring
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.strokeColor = SKColor(hex: 0x9933CC, alpha: 0.6)
        ring.fillColor = SKColor(hex: 0x9933CC, alpha: 0.15)
        ring.lineWidth = 2
        ring.position = player.position
        ring.zPosition = 7
        worldNode.addChild(ring)
        
        let expand = SKAction.group([
            SKAction.scale(to: 1.3, duration: 0.3),
            SKAction.fadeOut(withDuration: 0.3)
        ])
        ring.run(SKAction.sequence([expand, SKAction.removeFromParent()]))
        
        // Small screen shake
        worldNode.shake(intensity: 4, duration: 0.15)
    }
    
    // MARK: - Spawning
    
    private func spawnEnemy() {
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

    // MARK: - v1.6: Quench Spawning (Unit 5)

    /// Arena 2 spawn table — v1.6 tuning: staggered vocabulary. The first
    /// 20s are familiar bodies + self-teaching Ashlings; ranged joins at
    /// 55s, Braceguards at 65s. Cinder Halos are BANKED for a later arena
    /// (Brandon playtest 7/9/26: the rotating halo reads as a spinning
    /// shield mid-swarm — perception is reality).
    private func spawnQuenchEnemy() {
        let elapsed = waveManager.elapsedTime
        let roll = CGFloat.random(in: 0...1)

        // Opening: ease in with known shapes while Ashlings teach splitting
        if elapsed < 20 {
            if roll < 0.5 {
                spawnBasicMelee(elapsed: elapsed)
            } else {
                spawnAshling(elapsed: elapsed)
            }
            return
        }

        if elapsed >= 65 && roll < 0.10 {
            spawnBraceguard(elapsed: elapsed)
        } else if elapsed >= 55 && roll < 0.28 {
            spawnRangedEnemy()
        } else if roll < 0.72 {
            spawnAshling(elapsed: elapsed)
        } else {
            spawnBasicMelee(elapsed: elapsed)
        }
    }

    private func spawnAshling(elapsed: TimeInterval) {
        let ashling = AshlingNode(elapsed: elapsed, isShard: false)
        ashling.position = EnemyNode.spawnPosition()
        ashling.setMoteTarget(worldNode)
        enemies.append(ashling)
        worldNode.addChild(ashling)
    }

    /// Two shards erupt where an Ashling died.
    private func spawnAshlingShards(at position: CGPoint) {
        for i in 0..<2 {
            let shard = AshlingNode(elapsed: waveManager.elapsedTime, isShard: true)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let side: CGFloat = i == 0 ? 1 : -1
            shard.position = position + CGPoint(x: cos(angle) * 14 * side,
                                                y: sin(angle) * 14 * side)
            enemies.append(shard)
            worldNode.addChild(shard)
        }
    }

    // MARK: - v1.7: Coilworks Spawning (Unit 8)

    /// Arena 3 spawn table — Lyra's curriculum: the first 20s teach the
    /// Relay Imp's arc language alongside familiar bodies and the smooth
    /// Static Halo orbit; Grounders join at 45s (routing pressure), the
    /// Circuit Wasp's snap rhythm arrives at 80s. Imps sometimes arrive
    /// in pairs mid-run — arcs need partners.
    private func spawnCoilworksEnemy() {
        let elapsed = waveManager.elapsedTime
        let roll = CGFloat.random(in: 0...1)

        if elapsed < 20 {
            if roll < 0.40 {
                spawnBasicMelee(elapsed: elapsed)
            } else if roll < 0.75 {
                spawnRelayImp(elapsed: elapsed)
            } else {
                spawnStaticHalo(elapsed: elapsed)
            }
            return
        }

        if elapsed >= 80 && roll < 0.12 {
            spawnCircuitWasp(elapsed: elapsed)
        } else if elapsed >= 45 && roll < 0.26 {
            spawnGrounder(elapsed: elapsed)
        } else if roll < 0.48 {
            spawnRelayImp(elapsed: elapsed)
            if elapsed >= 45 && CGFloat.random(in: 0...1) < 0.35 {
                spawnRelayImp(elapsed: elapsed)
            }
        } else if roll < 0.66 {
            spawnStaticHalo(elapsed: elapsed)
        } else if elapsed >= 55 && roll < 0.78 {
            spawnRangedEnemy()
        } else {
            spawnBasicMelee(elapsed: elapsed)
        }
    }

    private func spawnStaticHalo(elapsed: TimeInterval) {
        let halo = StaticHaloNode(elapsed: elapsed)
        halo.position = EnemyNode.spawnPosition()
        enemies.append(halo)
        worldNode.addChild(halo)
    }

    private func spawnRelayImp(elapsed: TimeInterval) {
        let imp = RelayImpNode(elapsed: elapsed)
        imp.position = EnemyNode.spawnPosition()
        enemies.append(imp)
        worldNode.addChild(imp)
    }

    private func spawnGrounder(elapsed: TimeInterval) {
        let grounder = GrounderNode(elapsed: elapsed)
        grounder.position = EnemyNode.spawnPosition()
        grounder.onDangerPulse = { [weak self] center, radius, damage in
            guard let self = self else { return }
            let reach = radius + self.playerStats.effectiveCollisionRadius
            if self.player.position.distance(to: center) <= reach {
                self.applyBossHazardDamage(damage, shakeIntensity: 8)
            }
        }
        enemies.append(grounder)
        worldNode.addChild(grounder)
    }

    private func spawnCircuitWasp(elapsed: TimeInterval) {
        let wasp = CircuitWaspNode(elapsed: elapsed)
        wasp.position = EnemyNode.spawnPosition()
        enemies.append(wasp)
        worldNode.addChild(wasp)
    }

    private func spawnBraceguard(elapsed: TimeInterval) {
        let braceguard = BraceguardNode(elapsed: elapsed)
        braceguard.position = EnemyNode.spawnPosition()
        // v1.6 tuning: shield direction is set (randomly, cardinal) in init
        enemies.append(braceguard)
        worldNode.addChild(braceguard)
    }
    
    private func spawnRangedEnemy() {
        // v1.6 tuning: shooters are glass cannons — dangerous at range,
        // dead in one hit (Brandon playtest 7/9/26). Was 2–8 HP scaling.
        let ranged = RangedEnemyNode(
            health: 1,
            moveSpeed: GameConfig.Enemy.baseSpeed * 0.75,
            xpValue: 2
        )
        ranged.position = EnemyNode.spawnPosition()

        // Wire up the fire callback
        ranged.onFireProjectile = { [weak self] position, direction in
            self?.spawnEnemyProjectile(at: position, direction: direction)
        }

        enemies.append(ranged)
        worldNode.addChild(ranged)
    }
    
    private func spawnEnemyProjectile(at position: CGPoint, direction: CGPoint) {
        // v1.4: Projectile carries scaled damage
        let elapsed = waveManager.elapsedTime
        let scalingTicks = Int(elapsed / 30)
        let damage = GameConfig.Enemy.baseRangedDamage + (scalingTicks * GameConfig.Enemy.rangedDamageScaling)
        let proj = EnemyProjectileNode(direction: direction, damage: damage)
        proj.position = position
        proj.zPosition = 7
        enemyProjectiles.append(proj)
        worldNode.addChild(proj)
    }
    
    private func spawnMiniBoss() {
        let elapsed = waveManager.elapsedTime
        
        // Mini-boss scales with time too
        let bossHP = 10 + Int(elapsed / 30) * 3
        let bossXP = bossHP
        
        let boss = EnemyNode(
            health: bossHP,
            moveSpeed: GameConfig.Enemy.baseSpeed * 0.65,
            xpValue: bossXP
        )
        boss.isMiniBoss = true
        boss.position = EnemyNode.spawnPosition()
        boss.setScale(2.2)
        enemies.append(boss)
        worldNode.addChild(boss)
    }
    
    // MARK: - v1.4: Boss Spawn
    
    private func spawnBoss() {
        let elapsed = waveManager.elapsedTime
        let hpScaling = Int(elapsed / 30) * 5
        
        let bossNode = BossNode(config: BossNode.slagTitan, hpScaling: hpScaling)
        bossNode.position = BossNode.spawnPosition()
        bossNode.zPosition = 6
        
        // Wire callbacks
        bossNode.onSpawnMinions = { [weak self] pos, count in
            for _ in 0..<count {
                self?.spawnEnemy()
            }
        }
        bossNode.onSlamHit = { [weak self] pos, radius, damage in
            guard let self = self else { return }
            if self.player.position.distance(to: pos) < radius {
                guard self.damageCooldownTimer <= 0 else { return }
                let died = self.player.applyDamage(damage)
                self.damageCooldownTimer = GameConfig.Player.damageCooldown
                self.hpBar.flashDamage()
                AudioManager.shared.play(.playerDamage)
                self.worldNode.shake(intensity: 10, duration: 0.3)
                if died {
                    if self.player.tryLethalSave() { return }
                    self.playerDied()
                }
            }
        }
        bossNode.onDeath = { [weak self] pos, xp in
            guard let self = self else { return }
            self.bossDefeatedThisRun = true
            ProgressionManager.shared.recordKill(.boss)
            // Spawn massive XP shower
            for _ in 0..<10 {
                let offset = CGPoint(
                    x: CGFloat.random(in: -40...40),
                    y: CGFloat.random(in: -40...40)
                )
                self.spawnXPOrb(at: pos + offset, value: xp / 10)
            }
            self.boss = nil
            self.worldNode.shake(intensity: 15, duration: 0.5)
        }
        
        boss = bossNode
        worldNode.addChild(bossNode)

        // Dramatic entrance
        showBossEntrance(name: "THE SLAG TITAN", colorHex: 0xFF6611)
    }

    // MARK: - v1.6: Quench Warden Spawn

    private func spawnQuenchWarden() {
        let elapsed = waveManager.elapsedTime
        let hpScaling = Int(elapsed / 30) * 5

        let warden = QuenchWardenNode(hpScaling: hpScaling)
        warden.position = QuenchWardenNode.spawnPosition()
        warden.zPosition = 6

        // Cinder Aperture volleys ride the existing enemy projectile pipeline
        warden.onFireProjectile = { [weak self] position, direction in
            self?.spawnEnemyProjectile(at: position, direction: direction)
        }

        // Pressure Lanes — standing in an armed lane hurts
        warden.onLaneDamage = { [weak self] damage in
            self?.applyBossHazardDamage(damage, shakeIntensity: 6)
        }

        // Quench Field — momentum pulses
        warden.onFieldPulse = { [weak self] strength, duration in
            self?.fieldImpulseStrength = strength
            self?.fieldImpulseRemaining = duration
        }

        warden.onDeath = { [weak self] pos, xp in
            guard let self = self else { return }
            self.bossDefeatedThisRun = true
            ProgressionManager.shared.recordKill(.boss)
            ProgressionManager.shared.wardenKills += 1
            // v1.7: felling the Warden opens The Coilworks
            if ProgressionManager.shared.arenasUnlocked < 3 {
                ProgressionManager.shared.arenasUnlocked = 3
            }
            for _ in 0..<10 {
                let offset = CGPoint(
                    x: CGFloat.random(in: -40...40),
                    y: CGFloat.random(in: -40...40)
                )
                self.spawnXPOrb(at: pos + offset, value: xp / 10)
            }
            self.boss = nil
            self.worldNode.shake(intensity: 15, duration: 0.5)
        }

        boss = warden
        worldNode.addChild(warden)

        showBossEntrance(name: "THE QUENCH WARDEN", colorHex: 0xB8B0A4)
    }

    // MARK: - v1.7: Dynamo Choir Spawn

    private func spawnDynamoChoir() {
        let elapsed = waveManager.elapsedTime
        let hpScaling = Int(elapsed / 30) * 5

        let choir = DynamoChoirNode(hpScaling: hpScaling)
        choir.position = DynamoChoirNode.spawnPosition()
        choir.zPosition = 6

        // Broken Measure beats ride the enemy projectile pipeline
        choir.onFireProjectile = { [weak self] position, direction in
            self?.spawnEnemyProjectile(at: position, direction: direction)
        }

        // Circuit Litany — crossing a lit conduit hurts
        choir.onLineDamage = { [weak self] damage in
            self?.applyBossHazardDamage(damage, shakeIntensity: 6)
        }

        // Polarity Hymn pulses 1+2 reuse the Quench Field plumbing
        choir.onFieldPulse = { [weak self] strength, duration in
            self?.fieldImpulseStrength = strength
            self?.fieldImpulseRemaining = duration
        }

        // Pulse 3: snap enemies toward the player's PATH, never onto the
        // player — electrical tell first, then the lurch (Lyra guardrail)
        choir.onEnemySnap = { [weak self] radius in
            guard let self = self else { return }
            let projected = self.player.position + self.lastMoveDirection * 90

            for enemy in self.enemies
            where enemy.position.distance(to: self.player.position) < radius {
                let toward = projected - enemy.position
                let lurch = toward.normalized * min(toward.length * 0.7, 120)

                // Tell: a static spark above the enemy about to be conducted
                let spark = SKLabelNode(text: "⌁")
                spark.fontSize = 12
                spark.fontColor = SKColor(hex: 0xF6D36B)
                spark.position = CGPoint(x: 0, y: 16)
                spark.zPosition = 8
                enemy.addChild(spark)
                spark.run(SKAction.sequence([
                    SKAction.repeat(SKAction.sequence([
                        SKAction.fadeAlpha(to: 0.2, duration: 0.06),
                        SKAction.fadeAlpha(to: 1.0, duration: 0.06)
                    ]), count: 2),
                    SKAction.removeFromParent()
                ]))

                enemy.run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.28),
                    SKAction.move(by: CGVector(dx: lurch.x, dy: lurch.y), duration: 0.12)
                ]))
            }
        }

        choir.onDeath = { [weak self] pos, xp in
            guard let self = self else { return }
            self.bossDefeatedThisRun = true
            ProgressionManager.shared.recordKill(.boss)
            ProgressionManager.shared.choirKills += 1  // banked for Arena 4's gate
            for _ in 0..<10 {
                let offset = CGPoint(
                    x: CGFloat.random(in: -40...40),
                    y: CGFloat.random(in: -40...40)
                )
                self.spawnXPOrb(at: pos + offset, value: xp / 10)
            }
            self.boss = nil
            self.worldNode.shake(intensity: 15, duration: 0.5)
        }

        boss = choir
        worldNode.addChild(choir)

        showBossEntrance(name: "THE DYNAMO CHOIR", colorHex: 0xF6D36B)
    }

    // MARK: - v1.7: Relay Imp Arcs

    /// A charge/fire arc between a live imp pair. Keyed by imp IDs;
    /// pairs rebuild every frame, so death or separation kills the arc.
    private struct RelayArcKey: Hashable {
        let a: Int
        let b: Int
    }

    private struct RelayArcState {
        let line: SKShapeNode
        var phase: TimeInterval
    }

    private var relayArcs: [RelayArcKey: RelayArcState] = [:]

    /// Chain pressure: each imp pairs with its nearest unpaired partner
    /// in range. The arc charges faint (harmless tell), then fires
    /// bright — crossing a live arc hurts. "Every step completes or
    /// breaks the circuit."
    private func updateRelayArcs(_ dt: TimeInterval) {
        let cfg = GameConfig.CoilworksEnemies.self
        let range = cfg.relayArcRange * DeviceScale.gameplay

        // Greedy nearest-partner pairing
        let imps = enemies.compactMap { $0 as? RelayImpNode }
        var paired = Set<Int>()
        var activePairs: [(RelayImpNode, RelayImpNode)] = []
        for imp in imps where !paired.contains(imp.impID) {
            var best: RelayImpNode?
            var bestDist = range
            for other in imps
            where other.impID != imp.impID && !paired.contains(other.impID) {
                let d = imp.position.distance(to: other.position)
                if d < bestDist {
                    best = other
                    bestDist = d
                }
            }
            if let partner = best {
                paired.insert(imp.impID)
                paired.insert(partner.impID)
                activePairs.append((imp, partner))
            }
        }

        var liveKeys = Set<RelayArcKey>()
        for (impA, impB) in activePairs {
            let key = RelayArcKey(a: min(impA.impID, impB.impID),
                                  b: max(impA.impID, impB.impID))
            liveKeys.insert(key)

            var state: RelayArcState
            if let existing = relayArcs[key] {
                state = existing
            } else {
                let line = SKShapeNode()
                line.fillColor = .clear
                line.zPosition = 4
                worldNode.addChild(line)
                state = RelayArcState(line: line, phase: 0)
            }
            state.phase += dt
            let cycle = cfg.relayArcChargeTime + cfg.relayArcFireTime
            if state.phase >= cycle {
                state.phase -= cycle
            }

            let path = CGMutablePath()
            path.move(to: impA.position)
            path.addLine(to: impB.position)
            state.line.path = path

            if state.phase >= cfg.relayArcChargeTime {
                // Live — bright, damaging
                state.line.strokeColor = SKColor(hex: 0xF6D36B, alpha: 0.9)
                state.line.lineWidth = 2.5
                state.line.glowWidth = 4

                let dist = distanceFromPoint(player.position,
                                             toSegment: impA.position, impB.position)
                if dist < cfg.relayArcHitDistance + playerStats.effectiveCollisionRadius {
                    applyBossHazardDamage(cfg.relayArcDamage, shakeIntensity: 6)
                }
            } else {
                // Charging — a faint tell that brightens toward the fire
                let charge = state.phase / cfg.relayArcChargeTime
                state.line.strokeColor = SKColor(hex: 0xF6D36B, alpha: 0.12 + 0.20 * charge)
                state.line.lineWidth = 1.2
                state.line.glowWidth = 0
            }
            relayArcs[key] = state
        }

        // Broken pairs (death, separation) lose their arc immediately
        for (key, state) in relayArcs where !liveKeys.contains(key) {
            state.line.removeFromParent()
            relayArcs.removeValue(forKey: key)
        }
    }

    private func distanceFromPoint(_ point: CGPoint,
                                   toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let ab = b - a
        let lengthSq = ab.x * ab.x + ab.y * ab.y
        guard lengthSq > 0 else { return (point - a).length }
        let ap = point - a
        let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / lengthSq))
        let projection = a + ab * t
        return (point - projection).length
    }

    /// Shared damage path for boss arena hazards (lanes, future patterns).
    /// Respects i-frames, Phase Skin, and lethal saves like any other hit.
    private func applyBossHazardDamage(_ damage: Int, shakeIntensity: CGFloat) {
        guard gameState == .playing else { return }
        guard !isInvulnerable else { return }
        guard damageCooldownTimer <= 0 else { return }

        if playerStats.triggerPhaseSkin() {
            playerStats.resetOvercharge()
            invulnerableTimer = playerStats.phaseSkinDuration
            let blink = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.1),
                SKAction.fadeAlpha(to: 1.0, duration: 0.1)
            ])
            player.run(SKAction.repeat(blink, count: 5), withKey: "invulnBlink")
            worldNode.shake(intensity: 4, duration: 0.15)
            return
        }

        playerStats.resetOvercharge()
        let died = player.applyDamage(damage)
        damageCooldownTimer = GameConfig.Player.damageCooldown
        hpBar.flashDamage()
        AudioManager.shared.play(.playerDamage)
        worldNode.shake(intensity: shakeIntensity, duration: 0.2)

        if died {
            if player.tryLethalSave() {
                damageCooldownTimer = 1.0
                return
            }
            playerDied()
        }
    }

    private func showBossEntrance(name: String, colorHex: UInt32) {
        AudioManager.shared.play(.bossEntrance)
        let dim = SKShapeNode(rectOf: CGSize(width: 2000, height: 2000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.5)
        dim.strokeColor = .clear
        dim.zPosition = 150
        dim.alpha = 0
        camera?.addChild(dim)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = name
        title.fontSize = 18
        title.fontColor = SKColor(hex: colorHex)
        title.position = CGPoint(x: 0, y: 0)
        title.zPosition = 151
        title.alpha = 0
        camera?.addChild(title)

        let sequence = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.3),
            SKAction.wait(forDuration: 1.2),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ])
        dim.run(sequence)
        title.run(sequence)
    }
    
    private func spawnXPOrb(at position: CGPoint, value: Int) {
        let orb = XPOrbNode(xpValue: value)
        orb.position = position
        xpOrbs.append(orb)
        worldNode.addChild(orb)
    }
    
    // MARK: - v1.4: Health Orb Collection
    
    private func handleHealthOrbCollection(orbBody: SKPhysicsBody) {
        guard let orb = orbBody.node as? HealthOrbNode else { return }
        guard let idx = healthOrbs.firstIndex(where: { $0 === orb }) else { return }
        playerStats.heal(orb.healAmount)
        hpBar.flashHeal()
        healthOrbs.remove(at: idx)
        orb.collect()
        AudioManager.shared.play(.orbPickup)
    }
    
    // MARK: - v1.4: Magnet Orb Collection
    
    private func handleMagnetOrbCollection(orbBody: SKPhysicsBody) {
        guard let orb = orbBody.node as? MagnetOrbNode else { return }
        guard let idx = magnetOrbs.firstIndex(where: { $0 === orb }) else { return }
        magnetOrbs.remove(at: idx)
        orb.collect()
        AudioManager.shared.play(.orbPickup)
        // Vacuum ALL XP orbs to player
        for xpOrb in xpOrbs {
            let flyTo = SKAction.move(to: player.position, duration: 0.3)
            flyTo.timingMode = .easeIn
            xpOrb.run(flyTo)
        }
    }
    
    // MARK: - v1.4: Build Identity Hints
    
    private func showBuildHint(_ text: String) {
        AudioManager.shared.play(.buildHint)
        let hint = SKLabelNode(fontNamed: "Menlo-Bold")
        hint.text = text
        hint.fontSize = 14
        hint.fontColor = SKColor(hex: 0xFFDD55)
        hint.position = CGPoint(x: 0, y: -40)
        hint.alpha = 0
        hint.zPosition = 160
        camera?.addChild(hint)
        
        let anim = SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.3),
            SKAction.wait(forDuration: 1.5),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ])
        hint.run(anim)
    }
    
    // MARK: - Enemy Killed
    
    private func onEnemyKilled(at position: CGPoint, xpValue: Int, enemy: EnemyNode? = nil) {
        killCount += 1

        // v1.6: kills made in The Quench feed the Warden's gate
        if arenaConfig.id == 1 {
            ProgressionManager.shared.quenchKills += 1
        }
        // v1.7: kills made in The Coilworks feed the Choir's gate
        if arenaConfig.id == 2 {
            ProgressionManager.shared.coilworksKills += 1
        }
        
        // v1.4: Track kill type for progression
        if let enemy = enemy {
            if enemy is RangedEnemyNode {
                ProgressionManager.shared.recordKill(.ranged)
            } else {
                ProgressionManager.shared.recordKill(.melee)
            }
        } else {
            ProgressionManager.shared.recordKill(.melee)
        }
        
        run(SKAction.wait(forDuration: 0.05)) { [weak self] in
            self?.spawnXPOrb(at: position, value: xpValue)
        }
        
        _ = playerStats.recordKill(atTime: waveManager.elapsedTime)
        playerStats.recordBloodlustKill(atTime: waveManager.elapsedTime)

        // v1.6: Ashlings split into two shards on death
        if let ashling = enemy as? AshlingNode, !ashling.isShard {
            spawnAshlingShards(at: position)
        }

        // v1.6: Siphon — kills restore HP
        if playerStats.killHealAmount > 0 {
            playerStats.heal(playerStats.killHealAmount)
        }

        // v1.6: Open Vein — bleeding enemies burst on death
        if playerStats.openVeinDamage > 0, let enemy = enemy, enemy.isBleeding {
            damageEnemiesInRadius(playerStats.openVeinRadius, around: position,
                                  damage: playerStats.openVeinDamage)
            showRingPulse(at: position, radius: playerStats.openVeinRadius, colorHex: 0xCC2233)
        }

        // v1.6: Whiteout — slowed enemies chill others on death
        if playerStats.whiteoutActive, let enemy = enemy, enemy.isSlowed {
            for other in enemies
            where other.position.distance(to: position) < playerStats.whiteoutRadius {
                other.applySlow(playerStats.effectiveSlow(playerStats.whiteoutSlow),
                                duration: playerStats.whiteoutDuration)
            }
            showRingPulse(at: position, radius: playerStats.whiteoutRadius, colorHex: 0xAADDFF)
        }

        // v1.6: Null Bloom — chance to leave a slowing zone
        if playerStats.nullBloomChance > 0 && CGFloat.random(in: 0...1) < playerStats.nullBloomChance {
            spawnNullBloom(at: position)
        }

        if playerStats.killsExplode {
            explosionAt(position)
        }
        
        // v1.3: Chain Reaction — separate from Ember Burst
        if playerStats.chainReactionExplode {
            chainReactionAt(position)
        }
        
        worldNode.shake(intensity: 2, duration: 0.08)
    }
    
    private func chainReactionAt(_ position: CGPoint) {
        let radius = playerStats.chainReactionRadius
        let damage = playerStats.chainReactionDamage
        
        for enemy in enemies {
            if enemy.position.distance(to: position) < radius && enemy.position != position {
                enemy.takeDamage(damage)
            }
        }
        
        // Visual: orange-white flash ring
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.strokeColor = SKColor(hex: 0xFFCC44, alpha: 0.7)
        ring.fillColor = SKColor(hex: 0xFF8800, alpha: 0.2)
        ring.lineWidth = 1.5
        ring.position = position
        ring.zPosition = 6
        worldNode.addChild(ring)
        
        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.4, duration: 0.2),
                SKAction.fadeOut(withDuration: 0.2)
            ]),
            SKAction.removeFromParent()
        ]))
    }
    
    private func explosionAt(_ position: CGPoint) {
        let radius = playerStats.explosionRadius
        let damage = max(1, Int(playerStats.damageMultiplier * playerStats.explosionDamagePercent))
        
        var killedInExplosion: [Int] = []
        
        for (index, enemy) in enemies.enumerated() {
            if enemy.position.distance(to: position) < radius {
                if enemy.takeDamage(damage) {
                    killedInExplosion.append(index)
                }
            }
        }
        
        for index in killedInExplosion.reversed() {
            let enemy = enemies[index]
            spawnXPOrb(at: enemy.position, value: enemy.xpValue)
            enemies.remove(at: index)
        }
        
        let blast = SKShapeNode(circleOfRadius: 1)
        blast.fillColor = SKColor(hex: 0xFF6633, alpha: 0.6)
        blast.strokeColor = .clear
        blast.glowWidth = 5
        blast.position = position
        blast.zPosition = 7
        worldNode.addChild(blast)
        
        let expand = SKAction.group([
            SKAction.scale(to: radius, duration: 0.15),
            SKAction.fadeOut(withDuration: 0.2)
        ])
        blast.run(SKAction.sequence([expand, SKAction.removeFromParent()]))
    }
    
    // MARK: - HUD
    
    private func updateHUD() {
        let elapsed = waveManager.elapsedTime
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        timerLabel.text = String(format: "%d:%02d", minutes, seconds)
        
        // Timer color shifts as danger ramps
        if elapsed >= 120 {
            timerLabel.fontColor = SKColor(hex: 0xFF4444)  // Red — danger zone
        } else if elapsed >= 90 {
            timerLabel.fontColor = SKColor(hex: 0xFFAA33)  // Amber — boss incoming
        } else if elapsed >= 60 {
            timerLabel.fontColor = SKColor(hex: 0xCCCCCC)  // Bright — heating up
        } else {
            timerLabel.fontColor = SKColor(hex: 0xAAAAAA)  // Default
        }
        // HP Bar Update
        
        hpBar.updateFill(playerStats.hpPercent,
                         currentHP: playerStats.currentHP,
                         maxHP: playerStats.maxHP)
        
        levelLabel.text = "LV \(player.currentLevel)"
        xpBar.updateFill(player.xpProgress,
                         currentXP: player.currentXP,
                         requiredXP: player.xpRequired(forLevel: player.currentLevel + 1))
    }
    
    // MARK: - Collision Detection
    
    func didBegin(_ contact: SKPhysicsContact) {
        let (bodyA, bodyB) = (contact.bodyA, contact.bodyB)
        let masks = (bodyA.categoryBitMask, bodyB.categoryBitMask)
        
        if (masks == (GameConfig.Physics.player, GameConfig.Physics.enemy)) ||
           (masks == (GameConfig.Physics.enemy, GameConfig.Physics.player)) {
            let enemyBody = bodyA.categoryBitMask == GameConfig.Physics.enemy ? bodyA : bodyB
            handlePlayerEnemyContact(enemyBody: enemyBody)
            return
        }
        
        if masks == (GameConfig.Physics.projectile, GameConfig.Physics.enemy) {
            handleProjectileHit(projectileBody: bodyA, enemyBody: bodyB)
            return
        }
        if masks == (GameConfig.Physics.enemy, GameConfig.Physics.projectile) {
            handleProjectileHit(projectileBody: bodyB, enemyBody: bodyA)
            return
        }
        
        if masks == (GameConfig.Physics.player, GameConfig.Physics.xpOrb) {
            handleXPCollection(orbBody: bodyB)
            return
        }
        if masks == (GameConfig.Physics.xpOrb, GameConfig.Physics.player) {
            handleXPCollection(orbBody: bodyA)
            return
        }
        
        // Player ↔ Enemy Projectile = damage
        if (masks == (GameConfig.Physics.player, GameConfig.Physics.enemyProjectile)) ||
           (masks == (GameConfig.Physics.enemyProjectile, GameConfig.Physics.player)) {
            let projBody = bodyA.categoryBitMask == GameConfig.Physics.enemyProjectile ? bodyA : bodyB
            handleEnemyProjectileHit(projectileBody: projBody)
            return
        }
        
        // v1.4: Player ↔ Health Orb
        if (masks == (GameConfig.Physics.player, GameConfig.Physics.healthOrb)) ||
           (masks == (GameConfig.Physics.healthOrb, GameConfig.Physics.player)) {
            let orbBody = bodyA.categoryBitMask == GameConfig.Physics.healthOrb ? bodyA : bodyB
            handleHealthOrbCollection(orbBody: orbBody)
            return
        }
        
        // v1.4: Player ↔ Magnet Orb
        if (masks == (GameConfig.Physics.player, GameConfig.Physics.magnetOrb)) ||
           (masks == (GameConfig.Physics.magnetOrb, GameConfig.Physics.player)) {
            let orbBody = bodyA.categoryBitMask == GameConfig.Physics.magnetOrb ? bodyA : bodyB
            handleMagnetOrbCollection(orbBody: orbBody)
            return
        }
    }
    
    // MARK: - Player ↔ Enemy
    
    private func handlePlayerEnemyContact(enemyBody: SKPhysicsBody) {
        guard gameState == .playing else { return }
        guard !isInvulnerable else { return }
        guard damageCooldownTimer <= 0 else { return }

        // v1.6: Iron Bloom — attackers take DEF-scaled thorns damage.
        // Fires before Phase Skin so absorbed hits still bite back.
        if playerStats.ironBloomActive {
            if let bossNode = enemyBody.node as? (any ArenaBossNode) {
                bossNode.takeDamage(playerStats.ironBloomDamage)
            } else if let enemy = enemyBody.node as? EnemyNode {
                if enemy.takeDamage(playerStats.ironBloomDamage) {
                    if let index = enemies.firstIndex(where: { $0 === enemy }) {
                        enemies.remove(at: index)
                    }
                    onEnemyKilled(at: enemy.position, xpValue: enemy.xpValue, enemy: enemy)
                }
            }
        }
        
        // v1.3: Phase Skin — absorb hit with brief invulnerability
        if playerStats.triggerPhaseSkin() {
            playerStats.resetOvercharge()
            invulnerableTimer = playerStats.phaseSkinDuration
            let blink = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.1),
                SKAction.fadeAlpha(to: 1.0, duration: 0.1)
            ])
            player.run(SKAction.repeat(blink, count: 5), withKey: "invulnBlink")
            worldNode.shake(intensity: 4, duration: 0.15)
            return
        }
        
        // v1.3: Overcharge resets on hit
        playerStats.resetOvercharge()
        
        // v1.4: Calculate damage based on elapsed time
        // v1.6: Boss and mini-boss hit with their configured damage, not generic melee
        let elapsed = waveManager.elapsedTime
        let scalingTicks = Int(elapsed / 30)
        let damage: Int
        if let bossNode = enemyBody.node as? (any ArenaBossNode) {
            damage = bossNode.contactDamage
        } else if let enemy = enemyBody.node as? EnemyNode, enemy.isMiniBoss {
            damage = GameConfig.Enemy.baseMiniBossDamage + (scalingTicks * GameConfig.Enemy.miniBossDamageScaling)
        } else {
            damage = GameConfig.Enemy.baseMeleeDamage + (scalingTicks * GameConfig.Enemy.meleeDamageScaling)
        }

        let died = player.applyDamage(damage)
        damageCooldownTimer = GameConfig.Player.damageCooldown
        hpBar.flashDamage()
        AudioManager.shared.play(.playerDamage)
        worldNode.shake(intensity: 6, duration: 0.2)
        
        if died {
            if player.tryLethalSave() {
                for enemy in enemies {
                    if player.position.distance(to: enemy.position) < 50 {
                        let dir = (enemy.position - player.position).normalized
                        enemy.position += dir * 40
                    }
                }
                worldNode.shake(intensity: 8, duration: 0.25)
                damageCooldownTimer = 1.0  // Generous i-frames after lethal save
                return
            }
            playerDied()
        }
    }
    
    // MARK: - Enemy Projectile ↔ Player
    
    private func handleEnemyProjectileHit(projectileBody: SKPhysicsBody) {
        guard let projNode = projectileBody.node as? EnemyProjectileNode else { return }
        guard gameState == .playing else { return }
        guard !isInvulnerable else {
            // Still destroy the projectile even if invulnerable
            if let index = enemyProjectiles.firstIndex(where: { $0 === projNode }) {
                enemyProjectiles.remove(at: index)
            }
            projNode.removeFromParent()
            return
        }
        
        // Remove the projectile
        if let index = enemyProjectiles.firstIndex(where: { $0 === projNode }) {
            enemyProjectiles.remove(at: index)
        }
        projNode.removeFromParent()
        
        guard damageCooldownTimer <= 0 else { return }
        
        // v1.3: Phase Skin — absorb the hit
        if playerStats.triggerPhaseSkin() {
            playerStats.resetOvercharge()
            invulnerableTimer = playerStats.phaseSkinDuration
            let blink = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.1),
                SKAction.fadeAlpha(to: 1.0, duration: 0.1)
            ])
            player.run(SKAction.repeat(blink, count: 5), withKey: "invulnBlink")
            worldNode.shake(intensity: 4, duration: 0.15)
            return
        }
        
        // v1.3: Overcharge resets on hit
        playerStats.resetOvercharge()
        
        // v1.4: Use projectile's damage value instead of instant kill
        let died = player.applyDamage(projNode.damage)
        damageCooldownTimer = GameConfig.Player.damageCooldown
        hpBar.flashDamage()
        AudioManager.shared.play(.playerDamage)
        worldNode.shake(intensity: 4, duration: 0.15)
        
        if died {
            if player.tryLethalSave() {
                for enemy in enemies {
                    if player.position.distance(to: enemy.position) < 50 {
                        let dir = (enemy.position - player.position).normalized
                        enemy.position += dir * 40
                    }
                }
                worldNode.shake(intensity: 8, duration: 0.25)
                damageCooldownTimer = 1.0
                return
            }
            playerDied()
        }
    }
    
    // MARK: - Projectile ↔ Enemy
    
    private func handleProjectileHit(projectileBody: SKPhysicsBody, enemyBody: SKPhysicsBody) {
        // v1.6: Bosses share the enemy physics category but are not EnemyNodes —
        // route boss hits to the dedicated handler (this was the "invincible Titan" bug)
        if enemyBody.node is (any ArenaBossNode) {
            handleProjectileHitBoss(projectileBody: projectileBody)
            return
        }

        guard let projectileNode = projectileBody.node as? ProjectileNode,
              let enemyNode = enemyBody.node as? EnemyNode else { return }

        // v1.6 tuning: Braceguard's fixed shield halves damage from its arc
        // (was a full block — too punishing with auto-aim mid-chaos)
        var braceguardShielded = false
        if let braceguard = enemyNode as? BraceguardNode,
           braceguard.blocksHit(from: player.position) {
            braceguardShielded = true
            braceguard.flashShield()
        }

        var damage = max(1, Int(projectileNode.damageMultiplier))

        // v1.7 Induction Step: a fully charged attack discharges as bonus Shock
        let inductionBonus = playerStats.consumeInductionCharge()
        if inductionBonus > 0 {
            damage += inductionBonus
            let burst = SKShapeNode(circleOfRadius: 14)
            burst.strokeColor = SKColor(hex: 0x44BBFF, alpha: 0.9)
            burst.fillColor = SKColor(hex: 0x44BBFF, alpha: 0.2)
            burst.lineWidth = 1.5
            burst.glowWidth = 4
            burst.position = enemyNode.position
            burst.zPosition = 8
            worldNode.addChild(burst)
            burst.run(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.8, duration: 0.18),
                    SKAction.fadeOut(withDuration: 0.18)
                ]),
                SKAction.removeFromParent()
            ]))
        }

        if projectileNode.isCrit {
            damage = max(2, Int(CGFloat(damage) * playerStats.critMultiplier))
        }

        if playerStats.executionThreshold > 0 && enemyNode.healthPercent < playerStats.executionThreshold {
            damage *= 2
        }
        
        // Execution Protocol: bonus damage to low HP enemies
        if playerStats.executionProtocolThreshold > 0 && enemyNode.healthPercent < playerStats.executionProtocolThreshold {
            damage = Int(CGFloat(damage) * playerStats.executionProtocolMultiplier)
        }
        
        if playerStats.slowedDamageBonus > 0 && enemyNode.isSlowed {
            damage = Int(CGFloat(damage) * (1.0 + playerStats.slowedDamageBonus))
        }
        
        if playerStats.isBloodlustActive(atTime: waveManager.elapsedTime) {
            damage = Int(CGFloat(damage) * (1.0 + playerStats.bloodlustBonus))
        }

        // v1.6: shield reduction applies after all bonuses — flanking doubles output
        if braceguardShielded {
            damage = max(1, Int(CGFloat(damage) * BraceguardNode.shieldDamageMultiplier))
        }

        if playerStats.burnDPS > 0 {
            enemyNode.applyBurn(playerStats.burnDPS, duration: playerStats.burnDuration)
        }
        if playerStats.slowAmount > 0 {
            enemyNode.applySlow(playerStats.effectiveSlow(playerStats.slowAmount), duration: playerStats.slowDuration)
        }
        if playerStats.critAppliesBleed && projectileNode.isCrit {
            enemyNode.applyBleed(playerStats.bleedDPS, duration: playerStats.bleedDuration)
        }
        if playerStats.knockbackForce > 0 {
            enemyNode.applyKnockback(from: player.position, force: playerStats.knockbackForce)
        }
        // v1.6: Overload — real stun (was a mislabeled slow)
        if playerStats.stunChance > 0 && CGFloat.random(in: 0...1) < playerStats.stunChance {
            enemyNode.applyStun(playerStats.stunDuration)
        }

        // Shatter check
        if playerStats.shatterChance > 0 && enemyNode.isSlowed {
            let totalSlow = enemyNode.currentSlow + playerStats.globalEnemySlow
            if totalSlow >= playerStats.shatterSlowThreshold &&
               CGFloat.random(in: 0...1) < playerStats.shatterChance {
                let killed = enemyNode.takeDamage(enemyNode.health)
                if killed {
                    if let index = enemies.firstIndex(where: { $0 === enemyNode }) {
                        enemies.remove(at: index)
                    }
                    onEnemyKilled(at: enemyNode.position, xpValue: enemyNode.xpValue, enemy: enemyNode)
                }
                if let index = projectiles.firstIndex(where: { $0 === projectileNode }) {
                    projectiles.remove(at: index)
                }
                projectileNode.removeFromParent()
                return
            }
        }
        
        let consumed = projectileNode.onHitEnemy()
        if consumed {
            if let index = projectiles.firstIndex(where: { $0 === projectileNode }) {
                projectiles.remove(at: index)
            }
            projectileNode.removeFromParent()
        }
        
        let killed = enemyNode.takeDamage(damage)
        
        if killed {
            let deathPos = enemyNode.position
            let xpValue = enemyNode.xpValue
            if let index = enemies.firstIndex(where: { $0 === enemyNode }) {
                enemies.remove(at: index)
            }
            onEnemyKilled(at: deathPos, xpValue: xpValue, enemy: enemyNode)
        }
        
        if playerStats.chainTargets > 0 && !killed {
            chainLightning(from: enemyNode.position,
                          damage: max(1, Int(CGFloat(damage) * playerStats.chainDamageMultiplier)),
                          remaining: playerStats.chainTargets,
                          excludeEnemy: enemyNode)
        }
    }
    
    // MARK: - v1.6: Projectile ↔ Boss

    /// Boss damage pipeline. Crits, execution effects, and bloodlust apply;
    /// status effects (burn/slow/bleed/knockback) do not — the boss resists them.
    private func handleProjectileHitBoss(projectileBody: SKPhysicsBody) {
        guard let projectileNode = projectileBody.node as? ProjectileNode,
              let bossNode = boss, !bossNode.isDead else { return }

        var damage = max(1, Int(projectileNode.damageMultiplier))

        if projectileNode.isCrit {
            damage = max(2, Int(CGFloat(damage) * playerStats.critMultiplier))
        }

        if playerStats.executionThreshold > 0 && bossNode.healthPercent < playerStats.executionThreshold {
            damage *= 2
        }

        if playerStats.executionProtocolThreshold > 0 && bossNode.healthPercent < playerStats.executionProtocolThreshold {
            damage = Int(CGFloat(damage) * playerStats.executionProtocolMultiplier)
        }

        if playerStats.isBloodlustActive(atTime: waveManager.elapsedTime) {
            damage = Int(CGFloat(damage) * (1.0 + playerStats.bloodlustBonus))
        }

        let consumed = projectileNode.onHitEnemy()
        if consumed {
            if let index = projectiles.firstIndex(where: { $0 === projectileNode }) {
                projectiles.remove(at: index)
            }
            projectileNode.removeFromParent()
        }

        // Death flow (XP shower, bossKills, shake) runs via the boss's onDeath callback
        bossNode.takeDamage(damage)
    }

    // MARK: - Chain Lightning
    
    private func chainLightning(from position: CGPoint, damage: Int, remaining: Int, excludeEnemy: EnemyNode) {
        guard remaining > 0 else { return }
        
        var closest: EnemyNode?
        // v1.7 Copper Vein: chains reach farther
        var closestDist: CGFloat = 80 + playerStats.shockChainRadiusBonus

        for enemy in enemies where enemy !== excludeEnemy {
            let dist = position.distance(to: enemy.position)
            if dist < closestDist {
                closestDist = dist
                closest = enemy
            }
        }
        
        guard let target = closest else { return }
        
        let line = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: position)
        path.addLine(to: target.position)
        line.path = path
        line.strokeColor = SKColor(hex: 0x44BBFF, alpha: 0.8)
        line.lineWidth = 1.5
        line.glowWidth = 3
        line.zPosition = 8
        worldNode.addChild(line)
        line.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.15), SKAction.removeFromParent()]))
        
        if target.takeDamage(damage) {
            let pos = target.position
            let xp = target.xpValue
            if let index = enemies.firstIndex(where: { $0 === target }) {
                enemies.remove(at: index)
            }
            onEnemyKilled(at: pos, xpValue: xp, enemy: target)
        }
    }
    
    // MARK: - XP Collection
    
    private func handleXPCollection(orbBody: SKPhysicsBody) {
        guard let orbNode = orbBody.node as? XPOrbNode else { return }
        
        if let index = xpOrbs.firstIndex(where: { $0 === orbNode }) {
            xpOrbs.remove(at: index)
        }
        orbNode.collect()
        AudioManager.shared.play(.orbPickup)
        
        // v1.3: Magnetic Core — speed boost on XP pickup
        playerStats.triggerMagneticCoreBoost()
        
        if player.addXP(orbNode.xpValue) {
            triggerLevelUp()
        }
    }
    
    // MARK: - Level Up
    
    private func triggerLevelUp() {
        gameState = .levelUp
        AudioManager.shared.play(.levelUp)
        playerStats.triggerOverclock()  // v1.7: level-ups grant speed briefly
        xpBar.flashLevelUp()
        levelLabel.text = "LV \(player.currentLevel)"
        
        if let label = levelUpOverlay.childNode(withName: "levelUpLabel") as? SKLabelNode {
            label.text = "LEVEL \(player.currentLevel)"
        }
        
        showCardSelection(upgradeManager.drawCards(count: 3))
        
        // Show/hide reroll + extra card buttons
        if let rerollBtn = levelUpOverlay.childNode(withName: "rerollButton") {
            rerollBtn.alpha = rerollUsedThisRun ? 0.0 : 1.0
        }
        if let extraBtn = levelUpOverlay.childNode(withName: "extraCardButton") {
            extraBtn.alpha = extraCardUsedThisRun ? 0.0 : 1.0
        }
        
        levelUpOverlay.alpha = 0
        levelUpOverlay.run(SKAction.fadeIn(withDuration: 0.2))
        
        // Brief screen flash on level up
        let flash = SKShapeNode(rectOf: CGSize(width: 2000, height: 2000))
        flash.fillColor = SKColor(hex: 0xFFAA33, alpha: 0.15)
        flash.strokeColor = .clear
        flash.zPosition = 180
        camera?.addChild(flash) ?? addChild(flash)
        flash.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.3), SKAction.removeFromParent()]))
    }
    
    private func showCardSelection(_ cards: [UpgradeManager.UpgradeCard]) {
        for card in displayedCards { card.removeFromParent() }
        displayedCards.removeAll()

        // v1.6: four cards (Extra Card reward) render tighter and smaller
        // (spacings sized for the 118pt legibility-pass cards; fits iPhone SE)
        let spacing: CGFloat = cards.count >= 4 ? 92 : 124
        let cardScale: CGFloat = cards.count >= 4 ? 0.75 : 1.0
        let startX = -spacing * CGFloat(cards.count - 1) / 2
        let cardY: CGFloat = -40  // v1.4: lower on screen, closer to joystick area

        for (i, card) in cards.enumerated() {
            let cardNode = UpgradeCardNode(card: card)
            cardNode.position = CGPoint(x: startX + spacing * CGFloat(i), y: cardY)
            cardNode.setScale(0.0)
            levelUpOverlay.addChild(cardNode)
            displayedCards.append(cardNode)

            let delay = SKAction.wait(forDuration: 0.05 * Double(i))
            let popIn = SKAction.scale(to: cardScale, duration: 0.2)
            popIn.timingMode = .easeOut
            cardNode.run(SKAction.sequence([delay, popIn]))
        }
    }
    
    // MARK: - Death
    
    private func playerDied() {
        guard gameState == .playing else { return }
        gameState = .dead
        
        player.die()
        
        // Big screen shake on death
        worldNode.shake(intensity: 12, duration: 0.35)
        
        // Record high scores
        let result = HighScoreManager.shared.recordRun(
            time: waveManager.elapsedTime,
            level: player.currentLevel,
            kills: killCount
        )
        
        // v1.4: Record to ProgressionManager
        ProgressionManager.shared.recordSurvival(waveManager.elapsedTime)
        let forgeXP = ProgressionManager.shared.forgeXPForRun(
            kills: killCount,
            level: player.currentLevel,
            time: waveManager.elapsedTime,
            bossDefeated: bossDefeatedThisRun
        )
        pendingForgeXP = forgeXP
        ProgressionManager.shared.addForgeXP(forgeXP)
        
        // Analytics
        AnalyticsTracker.shared.recordRun(AnalyticsTracker.RunData(
            sessionLength: waveManager.elapsedTime,
            timeOfDeath: waveManager.elapsedTime,
            levelReached: player.currentLevel,
            pickedUpgrades: upgradeManager.pickedCardIDs,
            usedRevive: false,
            timestamp: Date()
        ))
        
        // Update death overlay
        let elapsed = waveManager.elapsedTime
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        
        if let scoreLabel = deathOverlay.childNode(withName: "deathScore") as? SKLabelNode {
            scoreLabel.text = String(format: "Survived %d:%02d  •  Level %d  •  %d kills", minutes, seconds, player.currentLevel, killCount)
        }
        
        // New record badge
        if let badge = deathOverlay.childNode(withName: "recordBadge") as? SKLabelNode {
            if result.isNewBestTime && result.isNewBestLevel {
                badge.text = "★ NEW BEST TIME & LEVEL ★"
                badge.alpha = 1
            } else if result.isNewBestTime {
                badge.text = "★ NEW BEST TIME ★"
                badge.alpha = 1
            } else if result.isNewBestLevel {
                badge.text = "★ NEW BEST LEVEL ★"
                badge.alpha = 1
            } else {
                badge.alpha = 0
            }
        }
        
        // Best time display
        if let bestLabel = deathOverlay.childNode(withName: "bestLabel") as? SKLabelNode {
            bestLabel.text = "Best: \(HighScoreManager.shared.bestTimeFormatted)  •  Runs: \(HighScoreManager.shared.totalRuns)"
        }
        
        // Show/hide revive button
        if let reviveBtn = deathOverlay.childNode(withName: "reviveButton") {
            reviveBtn.alpha = adReviveManager.canRevive ? 1.0 : 0.0
            
            // Update label for IAP users
            if adReviveManager.adsRemoved {
                if let label = reviveBtn.childNode(withName: "reviveLabel") as? SKLabelNode {
                    label.text = "REIGNITE (FREE)"
                }
            }
        }
        
        // v1.5: Show/hide XP boost button
        if let xpBoostBtn = deathOverlay.childNode(withName: "xpBoostButton") {
            xpBoostBtn.alpha = adReviveManager.canBoostXP && pendingForgeXP > 0 ? 1.0 : 0.0
            
            if let label = xpBoostBtn.childNode(withName: "xpBoostLabel") as? SKLabelNode {
                label.text = "2x FORGE XP (+\(pendingForgeXP))"
            }
            if adReviveManager.adsRemoved {
                if let adIcon = xpBoostBtn.childNode(withName: "xpBoostAdIcon") as? SKLabelNode {
                    adIcon.text = "FREE"
                }
            }
        }
        
        deathOverlay.run(SKAction.fadeIn(withDuration: 0.3))
    }
    
    // MARK: - Revive
    
    private func performRevive() {
        gameState = .reviving
        
        let vc = view?.window?.rootViewController
        adReviveManager.requestRevive(from: vc) { [weak self] success in
            guard let self = self, success else {
                self?.gameState = .dead
                return
            }
            self.executeRevive()
        }
    }
    
    private func executeRevive() {
        // Revive player
        player.isDead = false
        player.alpha = 1.0
        player.physicsBody?.categoryBitMask = GameConfig.Physics.player
        
        // v1.4: Restore HP to full on revive
        playerStats.currentHP = playerStats.maxHP
        
        // Clear enemies near player
        var toClear: [Int] = []
        for (index, enemy) in enemies.enumerated() {
            if player.position.distance(to: enemy.position) < 100 {
                toClear.append(index)
            }
        }
        for index in toClear.reversed() {
            enemies[index].removeFromParent()
            enemies.remove(at: index)
        }
        
        // Hide death overlay
        deathOverlay.run(SKAction.fadeOut(withDuration: 0.2))

        // v1.7 fix: the reward callback fires while the ad still covers the
        // screen — flipping to .playing here ran the game (and burned the
        // i-frames) under the ad, so players returned mid-swarm and died.
        // Hold the run frozen until the player taps; the pause is the
        // mental-snapshot moment. gameState stays .reviving.
        showReviveHold()
    }

    // MARK: - v1.7: Revive Hold ("breathe, then dive back in")

    private var reviveHoldOverlay: SKNode?

    private func showReviveHold() {
        let overlay = SKNode()
        overlay.zPosition = 250

        let dim = SKShapeNode(rectOf: CGSize(width: 2000, height: 2000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.55)
        dim.strokeColor = .clear
        overlay.addChild(dim)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "REFORGED"
        title.fontSize = 26
        title.fontColor = SKColor(hex: 0xFFAA33)
        title.position = CGPoint(x: 0, y: 30)
        overlay.addChild(title)

        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "tap when ready"
        hint.fontSize = 14
        hint.fontColor = SKColor(hex: 0xFFFFFF)
        hint.position = CGPoint(x: 0, y: -8)
        overlay.addChild(hint)
        hint.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.35, duration: 0.9),
            SKAction.fadeAlpha(to: 1.0, duration: 0.9)
        ])))

        camera?.addChild(overlay)
        overlay.alpha = 0
        overlay.run(SKAction.fadeIn(withDuration: 0.25))
        reviveHoldOverlay = overlay
    }

    /// The player taps: NOW the run resumes and the full 5s of
    /// invulnerability starts counting — none of it burns under the ad.
    private func resumeFromRevive() {
        guard let overlay = reviveHoldOverlay else { return }
        reviveHoldOverlay = nil
        overlay.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))

        invulnerableTimer = 5.0
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        player.run(SKAction.repeat(blink, count: 25), withKey: "invulnBlink")

        gameState = .playing
        lastUpdateTime = 0  // Reset delta time to avoid jump
    }
    
    // MARK: - v1.5: XP Boost
    
    private func performXPBoost() {
        let vc = view?.window?.rootViewController
        adReviveManager.requestXPBoost(from: vc) { [weak self] success in
            guard let self = self, success else { return }
            
            // Double the forge XP — add another copy of what was already awarded
            let bonusXP = self.pendingForgeXP
            ProgressionManager.shared.addForgeXP(bonusXP)
            
            // Update button to show it's been used
            if let xpBoostBtn = self.deathOverlay.childNode(withName: "xpBoostButton") {
                if let label = xpBoostBtn.childNode(withName: "xpBoostLabel") as? SKLabelNode {
                    label.text = "✓ +\(bonusXP) BONUS XP"
                    label.fontColor = SKColor(hex: 0x66AA66)
                }
                if let adIcon = xpBoostBtn.childNode(withName: "xpBoostAdIcon") as? SKLabelNode {
                    adIcon.alpha = 0
                }
            }
            
            self.pendingForgeXP = 0
        }
    }
    
    // MARK: - Restart
    
    private func restartGame() {
        for enemy in enemies { enemy.removeFromParent() }
        enemies.removeAll()
        
        for proj in projectiles { proj.removeFromParent() }
        projectiles.removeAll()
        
        for eProj in enemyProjectiles { eProj.removeFromParent() }
        enemyProjectiles.removeAll()
        
        for orb in xpOrbs { orb.removeFromParent() }
        xpOrbs.removeAll()
        
        for card in displayedCards { card.removeFromParent() }
        displayedCards.removeAll()
        
        // v1.4: Clean up health orbs, magnet orbs, boss
        healthOrbs.forEach { $0.removeFromParent() }
        healthOrbs.removeAll()
        magnetOrbs.forEach { $0.removeFromParent() }
        magnetOrbs.removeAll()
        (boss as? QuenchWardenNode)?.cleanupWorldEffects()
        (boss as? DynamoChoirNode)?.cleanupWorldEffects()
        boss?.removeFromParent()
        boss = nil
        fieldImpulseStrength = 0
        fieldImpulseRemaining = 0

        // v1.6: Clean up gravity wells + chill trail + Quench card state
        gravityWells.forEach { $0.removeFromParent() }
        gravityWells.removeAll()
        chillTrailPoints.removeAll()
        singularityTimer = 0
        chillTrailDropTimer = 0
        arcWakeSparks.removeAll()
        arcWakeDropTimer = 0
        nullBloomZones.removeAll()

        player.reset()
        player.stats = playerStats
        playerStats.reset()
        upgradeManager.reset()
        waveManager.reset()
        adReviveManager.reset()
        timeSinceLastShot = 0
        lastUpdateTime = 0
        passiveDOTAccumulator = 0
        invulnerableTimer = 0
        killCount = 0
        rerollUsedThisRun = false
        extraCardUsedThisRun = false
        bossDefeatedThisRun = false
        pendingForgeXP = 0
        
        // v1.4: Reset orb timers
        healthOrbTimer = 0
        magnetOrbTimer = 0
        damageCooldownTimer = 0
        nextHealthOrbSpawn = TimeInterval.random(in: 20...30)
        nextMagnetOrbSpawn = TimeInterval.random(in: 25...35)
        
        // v1.4: Apply Forge Level bonuses
        ProgressionManager.shared.applyForgeBonuses(to: playerStats)
        
        // v1.4: Apply Daily Forge Blessing if active
        DailyForgeManager.shared.applyBlessingIfActive(to: playerStats)
        
        xpBar.updateFill(0)
        
        deathOverlay.run(SKAction.fadeOut(withDuration: 0.2))
        levelUpOverlay.alpha = 0
        camera?.position = .zero
        
        gameState = .playing
    }
}
