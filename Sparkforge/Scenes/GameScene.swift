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
        case removeAdsPrompt  // v1.8 (E4): in-run value-prop modal is up
        case synergyReveal    // v1.8 (Unit 6): synergy-unlock modal is up
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

    /// v1.8 Unit 14: False Opening — a lagging reference heading; when the live
    /// heading cuts sharply away from it, the pivot drops a delayed Void pulse.
    private var falseOpeningRefDir = CGPoint(x: 0, y: 1)
    private var falseOpeningCooldownTimer: TimeInterval = 0
    
    // MARK: - New Additions for health orbs + magnet orbs
    
    private let hpBar = HPBarNode(width: 210)  // v1.7 legibility pass
    private var healthOrbs: [HealthOrbNode] = []
    private var magnetOrbs: [MagnetOrbNode] = []
    private var forgeCoins: [ForgeCoinNode] = []  // v1.8 Unit 2: boss-death forge XP
    private var healthOrbTimer: TimeInterval = 0
    private var magnetOrbTimer: TimeInterval = 0
    private var nextHealthOrbSpawn: TimeInterval = 20  // randomize later
    private var nextMagnetOrbSpawn: TimeInterval = 25
    private var damageCooldownTimer: TimeInterval = 0  // i-frames after hit
    private var pendingForgeXP: Int = 0  // v1.5: Stored for XP boost ad doubling

    // MARK: - v1.6: Gravity Wells + Chill Trail (True Cards)

    private var gravityWells: [GravityWellNode] = []
    private var singularityTimer: TimeInterval = 0
    // v1.9: Everglow capstone — close-range heat pulse + periodic arena eruption.
    private var everglowPulseTimer: TimeInterval = 0
    private var everglowEruptionTimer: TimeInterval = 0
    // v1.9: Iron Maiden capstone — retaliation cooldown + timed punishment projectile.
    private var ironRetaliateCooldown: TimeInterval = 0
    private var ironMaidenProjectileTimer: TimeInterval = 0
    // v1.9: Skybeam capstone — persistent lasso tether + continuous-attachment state.
    private var skybeamTickTimer: TimeInterval = 0
    private var skybeamAttachTime: TimeInterval = 0
    private var skybeamStrikeCooldown: TimeInterval = 0
    private weak var lassoTargetNode: SKNode?
    private weak var calledEnemy: EnemyNode?
    private weak var calledBoss: (any ArenaBossNode)?
    private var lassoLine: SKShapeNode?
    // v1.9: Apex capstone — the Blood Familiar + T5 pounce-gauge state.
    private var apexFamiliar: FamiliarNode?
    private var apexAttackTimer: TimeInterval = 0
    private var apexOrbitPhase: CGFloat = 0
    private var apexBloodfedKills: Int = 0
    private var apexPounceStacks: Int = 0
    private var apexStackTimer: TimeInterval = 0
    private var apexPounceCooldown: TimeInterval = 0
    private let apexGauge = StackGaugeNode()  // T5 pounce charge (reuses the rage meter)
    private var apexTargetMarker: SKShapeNode?
    private var apexFamiliarTier: Int = 0     // last-applied tier (drives bat growth + Spark's features)
    // v1.9: Erasure capstone — the global Unstable charge meter.
    private var erasureStacks: Int = 0
    private var erasureStackTimer: TimeInterval = 0
    private var erasureTriggerCooldown: TimeInterval = 0
    private let erasureGauge = StackGaugeNode()  // Unstable charge (reuses the rage meter)
    // v1.9: Event Horizon (Erasure T5) — one-per-run scripted run-ender.
    private var eventHorizonErased = false        // arena wiped
    private var eventHorizonEnded = false         // player erased
    private var eventHorizonVoided = false        // spawning halted (silent arena)
    private var eventHorizonCountdown: SKNode?    // "VOID COLLAPSE" doom timer
    // v1.9: Polar Vortex capstone — the Windchill storm.
    private var windchillTimer: TimeInterval = 0
    private var windchillWispTimer: TimeInterval = 0
    private var windchillStorm: SKShapeNode?
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
    private let statHUD = StatHUDNode()  // v1.9 Unit 5: right-side combat modifiers
    private let kineticGauge = StackGaugeNode()  // v1.9: Iron Maiden reserve meter (reusable)
    private let deathOverlay = SKNode()
    private let levelUpOverlay = SKNode()
    private let synergyLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let pauseMenu = PauseMenuNode()  // v1.7: Pause Menu v2
    private let pauseButton = SKLabelNode(fontNamed: "Menlo-Bold")  // v1.4

    // v1.8 (E4): the upper-left ad affordance. Non-owners get a "Remove Ads"
    // button that opens the value-prop → purchase flow; owners get the
    // static "AD-FREE" status badge. Both live in the same spot.
    private var removeAdsButton: SKNode?          // non-owner state
    private var removeAdsModal: RemoveAdsModalNode?  // shared value-prop modal
    private var removeAdsPriceText: String?
    /// The gameState to restore to when the in-run modal dismisses.
    private var stateBeforeRemoveAdsPrompt: GameState = .playing
    
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
    // v1.7: Extra Pick — an ad banks a SECOND selection from the same spread
    private var extraPickUsedThisRun: Bool = false
    private var extraPicksRemaining: Int = 0
    private var pendingSynergies: [UpgradeManager.SynergyUnlock] = []

    // v1.8 Unit 6: synergy-unlock reveal queue. Tiers earned this pick present
    // one card-style modal at a time, holding the game between taps.
    private var synergyQueue: [UpgradeManager.SynergyUnlock] = []
    private var synergyModal: SynergyUnlockNode?
    // v1.9 Unit 3: card capstone reveals ride the same reveal sequence, shown
    // after any synergy tiers. pendingCapstones collects during the pick.
    private var pendingCapstones: [CardMaxReveal] = []
    private var capstoneQueue: [CardMaxReveal] = []
    // v1.9 Unit 4b: combined level-up screen — a stat pick and a skill card on
    // ONE screen (even levels), chosen in either order, auto-committing once
    // both are selected. levelNeedsStat is false on odd levels (random stat is
    // auto-awarded and shown as a badge; only the card is picked).
    private var levelStatPick: PlayerStats.StatKind?
    private var levelNeedsStat = false
    private var pendingLevelCard: UpgradeCardNode?
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        backgroundColor = .black

        #if DEBUG
        // v1.8 Unit 5: lifetime Codex snapshot at run start — lets persistence
        // be validated across app restarts before any Codex page exists.
        print(CodexManager.shared.debugSummary())
        #endif

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

        // v1.8 (Unit 11): the arena sets when its bell rings (Mirrorwound rings
        // later than the standard mark for a longer escalation).
        waveManager.bellTime = arenaConfig.bellTime

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
        case 3:
            buildMirrorwoundMotif(radius: radius)
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

    /// v1.8 Arena 4 motif (Lyra canon): fractured mirror geometry — irregular
    /// triangular shard plates paired across center in slightly-off symmetry,
    /// broken ring fragments, and thin crack paths that never fully connect.
    /// Reflection is punctuation, not constant copying: an occasional silver
    /// glint travels a shard edge, then is gone. All linework is pale glass
    /// (detailLineHex) — thin, sharp, environmental. Purple stays reserved for
    /// hostile tells (Units 12–13); nothing here may read as a pickup.
    /// "The arena remembers your shape incorrectly." See lyra-response-v1.8.md.
    private func buildMirrorwoundMotif(radius: CGFloat) {
        let glass = arenaConfig.detailLineHex   // #D6CCC2 pale glass highlight
        let shadow = arenaConfig.dangerGlowHex  // #0B0A0D deep fracture shadow

        // Broken circular ring fragments — a few short arcs at irregular radii
        // and phases, deliberately never closing (the mirror's frame, cracked).
        let arcSpecs: [(r: CGFloat, start: CGFloat, sweep: CGFloat)] = [
            (radius * 0.38, 0.6, 1.1),
            (radius * 0.63, 2.5, 0.8),
            (radius * 0.63, 4.3, 0.5),
            (radius * 0.86, 3.4, 1.3)
        ]
        for spec in arcSpecs {
            let path = CGMutablePath()
            path.addArc(center: .zero, radius: spec.r,
                        startAngle: spec.start, endAngle: spec.start + spec.sweep,
                        clockwise: false)
            let arc = SKShapeNode(path: path)
            arc.fillColor = .clear
            arc.strokeColor = SKColor(hex: glass, alpha: 0.16)
            arc.lineWidth = 1
            arc.zPosition = -9.5
            worldNode.addChild(arc)
        }

        // Irregular triangular shard plates, each paired with a partner
        // reflected across center at a slight angular offset — symmetry that
        // is almost, but not quite, right. Faint shadow fill under a pale edge.
        // (base angle, distance from center, size, rotation, offset applied to
        //  the mirrored twin so the reflection sits "incorrectly").
        let shardSpecs: [(angle: CGFloat, dist: CGFloat, size: CGFloat, rot: CGFloat, twinSkew: CGFloat)] = [
            (0.7,  radius * 0.34, radius * 0.20, 0.3,  0.14),
            (2.1,  radius * 0.52, radius * 0.16, 1.1, -0.10),
            (3.9,  radius * 0.30, radius * 0.24, 2.2,  0.18),
            (5.2,  radius * 0.58, radius * 0.18, 0.7, -0.16)
        ]
        // A glint-carrying edge is collected per shard for the ambient pass.
        var glintEdges: [SKShapeNode] = []

        func addShard(center c: CGPoint, size: CGFloat, rot: CGFloat) {
            // An irregular triangle — three uneven vertices around the center.
            let verts: [CGFloat] = [0.0, 2.3, 4.1]  // uneven angular spread
            let radii: [CGFloat] = [1.0, 0.78, 0.92] // uneven vertex distances
            let path = CGMutablePath()
            var edgePts: [CGPoint] = []
            for (i, v) in verts.enumerated() {
                let a = v + rot
                let p = CGPoint(x: c.x + cos(a) * size * radii[i],
                                y: c.y + sin(a) * size * radii[i])
                edgePts.append(p)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()

            let plate = SKShapeNode(path: path)
            plate.fillColor = SKColor(hex: shadow, alpha: 0.35)
            plate.strokeColor = SKColor(hex: glass, alpha: 0.22)
            plate.lineWidth = 1
            plate.zPosition = -9.6
            worldNode.addChild(plate)

            // One bright edge of the plate carries the traveling glint.
            let edge = CGMutablePath()
            edge.move(to: edgePts[0])
            edge.addLine(to: edgePts[1])
            let glint = SKShapeNode(path: edge)
            glint.strokeColor = SKColor(hex: glass)
            glint.lineWidth = 1.5
            glint.alpha = 0
            glint.zPosition = -9.4
            worldNode.addChild(glint)
            glintEdges.append(glint)
        }

        for spec in shardSpecs {
            let c = CGPoint(x: cos(spec.angle) * spec.dist,
                            y: sin(spec.angle) * spec.dist)
            addShard(center: c, size: spec.size, rot: spec.rot)
            // Mirrored twin across center, rotation nudged so it reflects wrong.
            let twin = CGPoint(x: -c.x, y: -c.y)
            addShard(center: twin, size: spec.size * 0.92, rot: spec.rot + spec.twinSkew)
        }

        // Thin crack paths — jagged two-segment lines that stop short of both
        // the center and the boundary, so nothing fully connects.
        let crackAngles: [CGFloat] = [0.3, 1.4, 2.8, 3.7, 5.0]
        for (i, angle) in crackAngles.enumerated() {
            let innerR = radius * (0.22 + CGFloat(i % 3) * 0.08)
            let breakR = radius * 0.55
            let outerR = radius * 0.80  // stops short of the boundary
            let bend = angle - 0.12

            let path = CGMutablePath()
            path.move(to: CGPoint(x: cos(angle) * innerR, y: sin(angle) * innerR))
            path.addLine(to: CGPoint(x: cos(angle) * breakR, y: sin(angle) * breakR))
            path.addLine(to: CGPoint(x: cos(bend) * outerR, y: sin(bend) * outerR))

            let crack = SKShapeNode(path: path)
            crack.strokeColor = SKColor(hex: glass, alpha: 0.12)
            crack.lineWidth = 0.8
            crack.zPosition = -9.5
            worldNode.addChild(crack)
        }

        // Ambient reflection as punctuation: every few seconds one shard edge
        // glints — a quick silver flash that fades — then silence. Never a
        // steady shimmer; the arena reflects in glimpses, not constantly.
        guard !glintEdges.isEmpty else { return }
        var glintIndex = 0
        let pulse = SKAction.sequence([
            SKAction.run {
                let edge = glintEdges[glintIndex % glintEdges.count]
                // Step by a prime-ish stride so the glint doesn't march in order.
                glintIndex += 3
                edge.run(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.6, duration: 0.10),
                    SKAction.fadeAlpha(to: 0.0, duration: 0.35)
                ]))
            },
            // v1.8 (Unit 11): glints fire a little more often (Brandon's device
            // pass) — 0.9–2.1s between flashes, was 1.7–4.4s.
            SKAction.wait(forDuration: 1.5, withRange: 1.2)
        ])
        arenaFloor.run(SKAction.repeatForever(pulse))
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

        // v1.8 (E4): the upper-left ad affordance — above the buff badges, out
        // of the field of play, clear of the pause target (top-right). Two
        // states in the same spot:
        //   owner     → a static "AD-FREE" status badge (they're covered)
        //   non-owner → a player-initiated "Remove Ads" button that opens the
        //               value-prop modal → purchase (optional, never a
        //               forced/interstitial prompt — studio monetization ethos)
        // DEBUG can force either state so placement is validated without a
        // sandbox purchase; release is owner-driven.
        #if DEBUG
        // Flip to preview the owner badge without a sandbox purchase.
        let debugForceAdFree = false
        let isAdFreeOwner = debugForceAdFree || IAPManager.shared.hasRemovedAds
        #else
        let isAdFreeOwner = IAPManager.shared.hasRemovedAds
        #endif
        setupRemoveAdsAffordance(isOwner: isAdFreeOwner, safeLeft: safeLeft, safeTop: safeTop)

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

        // v1.9 Unit 5: playfield stat HUD — right edge, clearly BELOW the
        // centered XP/HP bars (which end at safeTop-64) so nothing collides.
        // z above the level-up/stat-choice dim (190/192) so it stays legible
        // while the player is choosing a stat or card.
        statHUD.position = CGPoint(x: safeRight + 8, y: safeTop - 92)
        statHUD.zPosition = 200
        camera.addChild(statHUD)
        statHUD.update(from: playerStats)

        // v1.9 Iron Maiden: Kinetic reserve gauge — centered just below the HP
        // bar, like a rage meter. Hidden until Kinetic Reserve (T4) is active.
        kineticGauge.position = CGPoint(x: 0, y: safeTop - 86)
        kineticGauge.zPosition = 101
        camera.addChild(kineticGauge)
        refreshKineticGauge()

        // v1.9 Apex: pounce charge gauge — same slot (only one capstone gauge
        // is normally active at once).
        apexGauge.position = CGPoint(x: 0, y: safeTop - 86)
        apexGauge.zPosition = 101
        camera.addChild(apexGauge)
        refreshApexGauge()

        // v1.9 Erasure: Unstable charge meter — same slot as the other capstone gauges.
        erasureGauge.position = CGPoint(x: 0, y: safeTop - 86)
        erasureGauge.zPosition = 101
        camera.addChild(erasureGauge)
        refreshErasureGauge()
    }

    /// Sync the Kinetic gauge to current stats — shown/hidden with Kinetic
    /// Reserve, filled to the live stack count. Call after picks + on restart.
    private func refreshKineticGauge() {
        if playerStats.ironKineticActive {
            // Per-capstone gauge color — the defense (Iron Maiden) reserve is neon blue.
            kineticGauge.configure(capacity: GameConfig.IronMaiden.kineticThreshold,
                                   filledColor: 0x1FB6FF)
            kineticGauge.setFilled(playerStats.ironKineticStacks)
        } else {
            kineticGauge.configure(capacity: 0, filledColor: 0x1FB6FF)
        }
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
        deathText.fontSize = 28
        deathText.fontColor = SKColor(hex: 0xFF4444)
        deathText.text = "SPARK EXTINGUISHED"
        deathText.position = CGPoint(x: 0, y: 90)
        deathOverlay.addChild(deathText)
        
        // Run stats
        let scoreText = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreText.fontSize = 18
        scoreText.fontColor = SKColor(hex: 0xFFAA33)
        scoreText.name = "deathScore"
        scoreText.position = CGPoint(x: 0, y: 55)
        deathOverlay.addChild(scoreText)
        
        // New record badge (hidden by default)
        let recordBadge = SKLabelNode(fontNamed: "Menlo-Bold")
        recordBadge.fontSize = 16
        recordBadge.fontColor = SKColor(hex: 0xFFDD55)
        recordBadge.name = "recordBadge"
        recordBadge.position = CGPoint(x: 0, y: 30)
        recordBadge.alpha = 0
        deathOverlay.addChild(recordBadge)
        
        // Best time display
        let bestLabel = SKLabelNode(fontNamed: "Menlo-Bold")  // v1.8: bold Best/Runs
        bestLabel.fontSize = 18  // v1.8: +4 — bigger Best/Runs
        bestLabel.fontColor = SKColor(hex: 0xE0E0E0)  // v1.8: whiter + brighter
        bestLabel.name = "bestLabel"
        bestLabel.position = CGPoint(x: 0, y: 10)
        deathOverlay.addChild(bestLabel)
        
        // Revive button
        let reviveBtn = SKNode()
        reviveBtn.name = "reviveButton"
        reviveBtn.position = CGPoint(x: 0, y: -30)
        
        let reviveBg = SKShapeNode(rectOf: CGSize(width: 240, height: 42), cornerRadius: 6)
        reviveBg.fillColor = SKColor(hex: 0x334433)
        reviveBg.strokeColor = SKColor(hex: 0x66AA66, alpha: 0.6)
        reviveBg.lineWidth = 1
        reviveBtn.addChild(reviveBg)
        
        let reviveText = SKLabelNode(fontNamed: "Menlo-Bold")
        reviveText.fontSize = 15
        reviveText.fontColor = SKColor(hex: 0xFFFFFF)  // v1.8: white on the green button
        reviveText.text = "REIGNITE THE FORGE"
        reviveText.verticalAlignmentMode = .center
        reviveText.name = "reviveLabel"
        reviveBtn.addChild(reviveText)
        
        deathOverlay.addChild(reviveBtn)
        
        // v1.5: XP Boost button
        let xpBoostBtn = SKNode()
        xpBoostBtn.name = "xpBoostButton"
        xpBoostBtn.position = CGPoint(x: 0, y: -84)
        
        let xpBoostBg = SKShapeNode(rectOf: CGSize(width: 240, height: 42), cornerRadius: 6)
        xpBoostBg.fillColor = SKColor(hex: 0x332211)
        xpBoostBg.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.6)
        xpBoostBg.lineWidth = 1
        xpBoostBg.name = "xpBoostBg"
        xpBoostBtn.addChild(xpBoostBg)
        
        let xpBoostText = SKLabelNode(fontNamed: "Menlo-Bold")
        xpBoostText.fontSize = 14
        xpBoostText.fontColor = SKColor(hex: 0xFFFFFF)  // v1.8: white on the amber button
        xpBoostText.text = "2x FORGE XP"
        xpBoostText.verticalAlignmentMode = .center
        xpBoostText.name = "xpBoostLabel"
        xpBoostBtn.addChild(xpBoostText)
        
        let xpBoostAdIcon = SKLabelNode(fontNamed: "Menlo-Bold")
        xpBoostAdIcon.fontSize = 12                     // v1.8: bigger
        xpBoostAdIcon.fontColor = SKColor(hex: 0xFFFFFF) // v1.8: white
        xpBoostAdIcon.text = "▶ AD"
        xpBoostAdIcon.verticalAlignmentMode = .center
        xpBoostAdIcon.position = CGPoint(x: 62, y: 0)
        xpBoostAdIcon.name = "xpBoostAdIcon"
        xpBoostBtn.addChild(xpBoostAdIcon)
        
        deathOverlay.addChild(xpBoostBtn)
        
        // Restart button
        let restartBtn = SKNode()
        restartBtn.name = "restartButton"
        restartBtn.position = CGPoint(x: 0, y: -138)
        
        // v1.8: blue button, bright white bold lettering, uniform size
        let restartBg = SKShapeNode(rectOf: CGSize(width: 240, height: 42), cornerRadius: 6)
        restartBg.fillColor = SKColor(hex: 0x18345C)
        restartBg.strokeColor = SKColor(hex: 0x5AA0F0, alpha: 0.85)
        restartBg.lineWidth = 1.5
        restartBtn.addChild(restartBg)

        let restartText = SKLabelNode(fontNamed: "Menlo-Bold")
        restartText.fontSize = 14
        restartText.fontColor = .white
        restartText.text = "RESTART"
        restartText.verticalAlignmentMode = .center
        restartBtn.addChild(restartText)
        
        deathOverlay.addChild(restartBtn)
        
        // Menu button — v1.8: neon dark purple pill, white bold letters,
        // uniform size. (Purple is the in-game danger color, but this lives on
        // the death screen, outside the gameplay field.)
        let menuBtn = SKNode()
        menuBtn.name = "menuButton"
        menuBtn.position = CGPoint(x: 0, y: -192)

        let menuBg = SKShapeNode(rectOf: CGSize(width: 240, height: 42), cornerRadius: 6)
        menuBg.fillColor = SKColor(hex: 0x2A1140)
        menuBg.strokeColor = SKColor(hex: 0xB566FF, alpha: 0.85)
        menuBg.lineWidth = 1.5
        menuBtn.addChild(menuBg)

        let menuLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        menuLabel.fontSize = 14
        menuLabel.fontColor = .white
        menuLabel.text = "MENU"
        menuLabel.verticalAlignmentMode = .center
        menuBtn.addChild(menuLabel)

        deathOverlay.addChild(menuBtn)
        
        guard let camera = camera else { return }
        camera.addChild(deathOverlay)
    }

    /// v1.8: lay out the XP-boost button so the label + "▶ AD" tag never
    /// collide — wraps them as a centered group and sizes the pill to fit.
    /// Survives any forge-XP amount and font size (call after setting text).
    private func layoutXPBoostButton(_ btn: SKNode) {
        guard let label = btn.childNode(withName: "xpBoostLabel") as? SKLabelNode else { return }
        let adIcon = btn.childNode(withName: "xpBoostAdIcon") as? SKLabelNode
        let showAd = (adIcon?.alpha ?? 0) > 0
        let gap: CGFloat = 12
        let labelW = label.frame.width

        // Center the [label][gap][AD] group inside the fixed uniform pill.
        if showAd, let adIcon = adIcon {
            let adW = adIcon.frame.width
            label.position = CGPoint(x: -(gap + adW) / 2, y: 0)
            adIcon.position = CGPoint(x: (labelW + gap) / 2, y: 0)
        } else {
            label.position = .zero
        }
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
        label.position = CGPoint(x: 0, y: 188)  // v1.9 4b: raised for the stat cards
        levelUpOverlay.addChild(label)

        // v1.8: match the title CTA convention — bold, bright neon-white
        // (minus the italics)
        let hint = SKLabelNode(fontNamed: "Menlo-Bold")
        hint.fontSize = 18
        hint.fontColor = SKColor(hex: 0xF2FBFF)
        hint.text = "choose an upgrade"
        hint.position = CGPoint(x: 0, y: 12)  // v1.9 4b: below the stat cards
        levelUpOverlay.addChild(hint)
        
        // v1.6: Reroll + Extra Card sit side by side below the cards.
        // Both are once per run; both free with Remove Ads.
        let adText = IAPManager.shared.hasRemovedAds ? "FREE" : "▶ AD"

        // Reroll button (left)
        let rerollBtn = SKNode()
        rerollBtn.name = "rerollButton"
        rerollBtn.position = CGPoint(x: -80, y: -144)  // v1.6: below taller cards

        let rerollBg = SKShapeNode(rectOf: CGSize(width: 156, height: 32), cornerRadius: 5)
        rerollBg.fillColor = SKColor(hex: 0x332233)
        rerollBg.strokeColor = SKColor(hex: 0x9966AA, alpha: 0.5)
        rerollBg.lineWidth = 1
        rerollBtn.addChild(rerollBg)

        let rerollText = SKLabelNode(fontNamed: "Menlo-Bold")
        rerollText.fontSize = 13                       // v1.8: bigger
        rerollText.fontColor = SKColor(hex: 0xFFFFFF)  // v1.8: white
        rerollText.text = "⟳ REFORGE"
        rerollText.verticalAlignmentMode = .center
        rerollText.position = CGPoint(x: -22, y: 0)
        rerollText.name = "rerollLabel"
        rerollBtn.addChild(rerollText)

        let adIcon = SKLabelNode(fontNamed: "Menlo-Bold")
        adIcon.fontSize = 12                           // v1.8: bigger
        adIcon.fontColor = SKColor(hex: 0xFFFFFF)      // v1.8: white
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

        let extraBg = SKShapeNode(rectOf: CGSize(width: 156, height: 32), cornerRadius: 5)
        extraBg.fillColor = SKColor(hex: 0x223333)
        extraBg.strokeColor = SKColor(hex: 0x66AAAA, alpha: 0.5)
        extraBg.lineWidth = 1
        extraBtn.addChild(extraBg)

        let extraText = SKLabelNode(fontNamed: "Menlo-Bold")
        extraText.fontSize = 13                        // v1.8: bigger
        extraText.fontColor = SKColor(hex: 0xFFFFFF)   // v1.8: white
        extraText.text = "✦ +1 CARD"
        extraText.verticalAlignmentMode = .center
        extraText.position = CGPoint(x: -22, y: 0)
        extraText.name = "extraCardLabel"
        extraBtn.addChild(extraText)

        let extraAdIcon = SKLabelNode(fontNamed: "Menlo-Bold")
        extraAdIcon.fontSize = 12                      // v1.8: bigger
        extraAdIcon.fontColor = SKColor(hex: 0xFFFFFF) // v1.8: white
        extraAdIcon.text = adText
        extraAdIcon.verticalAlignmentMode = .center
        extraAdIcon.position = CGPoint(x: 50, y: 0)
        extraAdIcon.name = "extraCardAdIcon"
        extraBtn.addChild(extraAdIcon)

        levelUpOverlay.addChild(extraBtn)

        // v1.7: Extra Pick button (centered below the pair) — the ad banks
        // a second selection from the same spread. Stacks with both above.
        let pickBtn = SKNode()
        pickBtn.name = "extraPickButton"
        pickBtn.position = CGPoint(x: 0, y: -182)

        let pickBg = SKShapeNode(rectOf: CGSize(width: 156, height: 32), cornerRadius: 5)
        pickBg.fillColor = SKColor(hex: 0x2A2418)
        pickBg.strokeColor = SKColor(hex: 0xCCAA44, alpha: 0.5)
        pickBg.lineWidth = 1
        pickBtn.addChild(pickBg)

        let pickText = SKLabelNode(fontNamed: "Menlo-Bold")
        pickText.fontSize = 13                         // v1.8: bigger
        pickText.fontColor = SKColor(hex: 0xFFFFFF)    // v1.8: white
        pickText.text = "★ +1 PICK"
        pickText.verticalAlignmentMode = .center
        pickText.position = CGPoint(x: -22, y: 0)
        pickText.name = "extraPickLabel"
        pickBtn.addChild(pickText)

        let pickAdIcon = SKLabelNode(fontNamed: "Menlo-Bold")
        pickAdIcon.fontSize = 12                        // v1.8: bigger
        pickAdIcon.fontColor = SKColor(hex: 0xFFFFFF)   // v1.8: white
        pickAdIcon.text = adText
        pickAdIcon.verticalAlignmentMode = .center
        pickAdIcon.position = CGPoint(x: 50, y: 0)
        pickAdIcon.name = "extraPickAdIcon"
        pickBtn.addChild(pickAdIcon)

        levelUpOverlay.addChild(pickBtn)

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

        // v1.8: The Mirrorwound drifts — sparse pale glass motes, no ember.
        // Ember/orange is player+forge language (color-discipline canon), so
        // the mirror arena gets a cold, occasional silver drift instead.
        if arenaConfig.id == 3 {
            setupMirrorwoundDrift(texture: dotTexture)
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

    /// v1.8 Arena 4 ambient (Lyra canon): "occasional mirrored particle drift."
    /// Sparse, slow, low-alpha pale-glass motes — silver/white, never ember,
    /// never a pickup read. Alpha blend (no additive glow) keeps it cold and
    /// environmental, sitting well below combat priority.
    private func setupMirrorwoundDrift(texture: SKTexture) {
        let drift = SKEmitterNode()
        drift.particleBirthRate = 5
        drift.particleLifetime = 7
        drift.particleLifetimeRange = 3
        drift.particlePositionRange = CGVector(dx: GameConfig.Arena.radius * 2.2,
                                               dy: GameConfig.Arena.radius * 2.2)
        drift.particleSpeed = 9
        drift.particleSpeedRange = 6
        drift.emissionAngleRange = 2 * .pi        // no single fall direction
        drift.particleAlpha = 0.22
        drift.particleAlphaRange = 0.12
        drift.particleAlphaSpeed = -0.03
        drift.particleScale = 0.045
        drift.particleScaleRange = 0.025
        drift.particleColor = SKColor(hex: arenaConfig.detailLineHex)  // pale glass
        drift.particleColorBlendFactor = 1.0
        drift.particleBlendMode = .alpha          // cold, not glowing
        drift.zPosition = -5
        drift.particleTexture = texture
        worldNode.addChild(drift)
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
            // v1.8 (E4): the upper-left "Remove Ads" button (non-owners only)
            if handleRemoveAdsButtonTap(touch) {
                return
            }
            _ = joystick.handleTouchBegan(touch, in: self)

        case .removeAdsPrompt:
            handleRemoveAdsModalTap(touch)

        case .synergyReveal:
            advanceSynergy()

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
        // v1.8 Unit 7: drag scrolls the synergy codex while paused
        if gameState == .paused {
            if let touch = touches.first {
                pauseMenu.handleTouchMoved(at: touch.location(in: pauseMenu))
            }
            return
        }
        guard gameState == .playing else { return }
        for touch in touches {
            joystick.handleTouchMoved(touch, in: self)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState == .paused {
            if let touch = touches.first {
                pauseMenu.handleTouchEnded(at: touch.location(in: pauseMenu))
            }
            return
        }
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
            let btnFrame = CGRect(x: reviveBtn.position.x - 120, y: reviveBtn.position.y - 21,
                                  width: 240, height: 42)
            if btnFrame.contains(location) {
                performRevive()
                return
            }
        }
        
        // v1.5: XP Boost button
        if let xpBoostBtn = deathOverlay.childNode(withName: "xpBoostButton"),
           xpBoostBtn.alpha > 0 {
            let btnFrame = CGRect(x: xpBoostBtn.position.x - 120, y: xpBoostBtn.position.y - 21,
                                  width: 240, height: 42)
            if btnFrame.contains(location) {
                performXPBoost()
                return
            }
        }
        
        // Restart button
        if let restartBtn = deathOverlay.childNode(withName: "restartButton") {
            let btnFrame = CGRect(x: restartBtn.position.x - 120, y: restartBtn.position.y - 21,
                                  width: 240, height: 42)
            if btnFrame.contains(location) {
                restartGame()
                return
            }
        }
        
        // Menu button
        if let menuBtn = deathOverlay.childNode(withName: "menuButton") {
            let btnFrame = CGRect(x: menuBtn.position.x - 120, y: menuBtn.position.y - 21,
                                  width: 240, height: 42)
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
        pauseMenu.handleTouchBegan(at: touch.location(in: pauseMenu))
    }

    // MARK: - v1.8 (E4): in-run Remove Ads affordance

    /// Builds the upper-left affordance in its owner/non-owner state. Both
    /// occupy the same spot; only one is present at a time.
    private func setupRemoveAdsAffordance(isOwner: Bool, safeLeft: CGFloat, safeTop: CGFloat) {
        guard let camera = camera else { return }
        removeAdsButton?.removeFromParent()
        removeAdsButton = nil
        camera.childNode(withName: "adFreeBadge")?.removeFromParent()

        let anchor = CGPoint(x: safeLeft + 30, y: safeTop)

        if isOwner {
            let badge = SKNode()
            badge.name = "adFreeBadge"
            badge.position = anchor
            badge.zPosition = 101
            let pill = SKShapeNode(rectOf: CGSize(width: 62, height: 18), cornerRadius: 5)
            pill.fillColor = SKColor(hex: 0x141414, alpha: 0.55)
            pill.strokeColor = SKColor(hex: 0x8A7A55, alpha: 0.45)
            pill.lineWidth = 1
            badge.addChild(pill)
            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.text = "AD-FREE"
            label.fontSize = 9
            label.fontColor = SKColor(hex: 0xC8B488)
            label.verticalAlignmentMode = .center
            badge.addChild(label)
            camera.addChild(badge)
        } else {
            let button = SKNode()
            button.name = "removeAdsButton"
            button.position = anchor
            button.zPosition = 101
            let pill = SKShapeNode(rectOf: CGSize(width: 62, height: 18), cornerRadius: 5)
            pill.name = "removeAdsPill"
            pill.fillColor = SKColor(hex: 0x1A1208, alpha: 0.65)
            pill.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.5)
            pill.lineWidth = 1
            button.addChild(pill)
            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.name = "removeAdsButtonLabel"
            label.text = "REMOVE ADS"
            label.fontSize = 8
            label.fontColor = SKColor(hex: 0xFFAA33)
            label.verticalAlignmentMode = .center
            button.addChild(label)
            camera.addChild(button)
            removeAdsButton = button
            loadRemoveAdsPrice()
        }
    }

    private func loadRemoveAdsPrice() {
        Task { @MainActor in
            guard let price = await IAPManager.shared.removeAdsDisplayPrice() else { return }
            removeAdsPriceText = price
            removeAdsModal?.priceText = price
        }
    }

    /// `true` if the touch hit the non-owner button (and the modal was opened).
    private func handleRemoveAdsButtonTap(_ touch: UITouch) -> Bool {
        guard gameState == .playing,
              let camera = camera,
              let button = removeAdsButton else { return false }
        // Thumb-sized hit zone anchored to the small pill.
        let hitZone = button.calculateAccumulatedFrame().insetBy(dx: -22, dy: -22)
        if hitZone.contains(touch.location(in: camera)) {
            presentRemoveAdsModal()
            return true
        }
        return false
    }

    private func presentRemoveAdsModal() {
        guard let camera = camera, removeAdsModal == nil else { return }
        stateBeforeRemoveAdsPrompt = gameState
        gameState = .removeAdsPrompt
        joystick.forceRelease()

        let modal = RemoveAdsModalNode()
        modal.priceText = removeAdsPriceText
        modal.present(in: camera)
        removeAdsModal = modal
    }

    private func handleRemoveAdsModalTap(_ touch: UITouch) {
        guard let camera = camera, let modal = removeAdsModal else { return }
        let buy = modal.hitTestBuy(at: touch.location(in: camera))
        if buy {
            dismissRemoveAdsModal(resume: false)  // hold the run behind the sheet
            handleInRunRemoveAdsPurchase()
        } else {
            dismissRemoveAdsModal(resume: true)   // tap outside cancels
        }
    }

    private func dismissRemoveAdsModal(resume: Bool) {
        removeAdsModal?.dismiss()
        removeAdsModal = nil
        if resume {
            gameState = stateBeforeRemoveAdsPrompt
            invulnerableTimer = 1.0  // brief reorient window, mirrors unpause
        }
    }

    private func handleInRunRemoveAdsPurchase() {
        Task { @MainActor in
            let success = await IAPManager.shared.purchaseRemoveAds()
            if success {
                // Swap the button for the AD-FREE badge in place.
                let anchor = removeAdsButton?.position ?? .zero
                setupRemoveAdsAffordance(isOwner: true,
                                         safeLeft: anchor.x - 30,
                                         safeTop: anchor.y)
            }
            // Purchase sheet dismissed either way — resume the run.
            if gameState == .removeAdsPrompt {
                gameState = stateBeforeRemoveAdsPrompt
                invulnerableTimer = 1.0
            }
        }
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

        // v1.7: Extra pick button
        if let pickBtn = levelUpOverlay.childNode(withName: "extraPickButton"),
           pickBtn.alpha > 0 {
            let btnFrame = CGRect(x: pickBtn.position.x - 75, y: pickBtn.position.y - 14,
                                  width: 150, height: 28)
            if btnFrame.contains(location) {
                performExtraPick()
                return
            }
        }

        // v1.9 4b: stat chips (even levels) — tapping one selects it. Chip
        // frames are computed in overlay space (statRow offset + chip offset).
        if levelNeedsStat, let statRow = levelUpOverlay.childNode(withName: "statRow") {
            for kind in PlayerStats.StatKind.allCases {
                guard let chip = statRow.childNode(withName: "statChip_\(kind.rawValue)") else { continue }
                let cx = statRow.position.x + chip.position.x
                let cy = statRow.position.y + chip.position.y
                let f = CGRect(x: cx - Self.statCardSize.width / 2 - 4,
                               y: cy - Self.statCardSize.height / 2 - 4,
                               width: Self.statCardSize.width + 8,
                               height: Self.statCardSize.height + 8)
                if f.contains(location) {
                    selectStat(kind)
                    return
                }
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
                selectLevelCard(cardNode)
                return
            }
        }
    }

    // MARK: - v1.9 4b: combined stat + card selection (either order, auto-commit)

    /// A stat chip was tapped — select it (highlight), then try to commit.
    private func selectStat(_ kind: PlayerStats.StatKind) {
        AudioManager.shared.play(.cardSelect)
        levelStatPick = kind
        highlightSelectedChip(kind)
        tryCommitLevelUp()
    }

    /// A card was tapped — mark it pending (highlight), then try to commit.
    private func selectLevelCard(_ node: UpgradeCardNode) {
        if pendingLevelCard !== node {
            pendingLevelCard?.setScale(node.xScale)   // reset the previous pick
            pendingLevelCard = node
            node.run(SKAction.scale(to: node.xScale * 1.08, duration: 0.1))
            AudioManager.shared.play(.cardSelect)
        }
        tryCommitLevelUp()
    }

    /// Commit once both picks are in — the stat (even) is applied, then the
    /// card is selected. Odd levels need only a card (stat already awarded).
    private func tryCommitLevelUp() {
        guard let card = pendingLevelCard else { return }
        if levelNeedsStat, levelStatPick == nil { return }

        if let stat = levelStatPick {
            playerStats.applyStatBonus(stat)
            statHUD.update(from: playerStats)
            levelStatPick = nil
            levelNeedsStat = false   // a 2nd (extra-pick) card won't re-require a stat
        }
        levelUpOverlay.childNode(withName: "statRow")?.run(SKAction.fadeOut(withDuration: 0.15))
        pendingLevelCard = nil
        commitCard(card)
    }

    /// Highlight the chosen stat chip; dim the others.
    private func highlightSelectedChip(_ kind: PlayerStats.StatKind) {
        guard let statRow = levelUpOverlay.childNode(withName: "statRow") else { return }
        for k in PlayerStats.StatKind.allCases {
            guard let chip = statRow.childNode(withName: "statChip_\(k.rawValue)"),
                  let plate = chip.childNode(withName: "chipPlate") as? SKShapeNode else { continue }
            let selected = (k == kind)
            plate.fillColor = SKColor(hex: k.colorHex, alpha: selected ? 0.5 : 0.20)
            plate.lineWidth = selected ? 2.5 : 1.5
            plate.glowWidth = selected ? 6 : 2
            chip.setScale(selected ? 1.08 : 1.0)
        }
    }

    private func commitCard(_ selectedNode: UpgradeCardNode) {
        AudioManager.shared.play(.cardSelect)
        let card = selectedNode.card
        let tierBefore = upgradeManager.tier(of: card.id)
        upgradeManager.pickCard(card, stats: playerStats)

        // Refresh the stat HUD + capstone gauges immediately — a DEF/ATK card
        // should move the readout on pick, not wait for the next hit.
        statHUD.update(from: playerStats)
        refreshKineticGauge()
        refreshApexGauge()
        refreshErasureGauge()

        // v1.9 Unit 3: this pick just maxed a laddered card. Capstones get the
        // grand reveal (after synergies); other maxed ladders a quiet flourish.
        if card.maxTier > 1, tierBefore < card.maxTier,
           upgradeManager.tier(of: card.id) >= card.maxTier {
            if card.isCapstone {
                pendingCapstones.append(CardMaxReveal(
                    tag: card.tag, cardName: card.name,
                    effect: card.description(forTier: card.maxTier), isCapstone: true))
            } else {
                showBuildHint("★ \(card.name) maxed")
            }
        }

        pendingSynergies.append(contentsOf: upgradeManager.checkSynergies(stats: playerStats))
        player.updateCollisionRadius()

        // Update buff tracker
        buffTracker.update(tagCounts: upgradeManager.tagCounts)

        // v1.4: Build identity hint
        if let buildHint = upgradeManager.checkBuildHint() {
            showBuildHint(buildHint)
        }

        // v1.7 Extra Pick: a banked pick keeps the rest of the spread on
        // the table — consume this card with the usual flourish and wait
        // for the second selection
        if extraPicksRemaining > 0, displayedCards.count > 1 {
            extraPicksRemaining -= 1
            if let index = displayedCards.firstIndex(where: { $0 === selectedNode }) {
                displayedCards.remove(at: index)
            }
            selectedNode.animateSelection { }
            if let pickBtn = levelUpOverlay.childNode(withName: "extraPickButton"),
               let label = pickBtn.childNode(withName: "extraPickLabel") as? SKLabelNode {
                label.text = "★ PICK AGAIN"
            }
            return
        }

        let synergies = pendingSynergies
        pendingSynergies = []
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

        // v1.7 fix: a reforge preserves the spread SIZE — if +1 Card
        // already bought a fourth card, rerolling keeps four (the chain
        // melted it back to three)
        let spreadSize = max(3, displayedCards.count)

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
            let newCards = self.upgradeManager.drawCards(count: spreadSize, level: self.player.currentLevel)
            self.showCardSelection(newCards)
        }
    }
    
    // MARK: - v1.7: Extra Pick

    /// The ad banks a SECOND selection from whatever the spread holds —
    /// pick 2 of 3, or 2 of 4 with +1 Card stacked. Once per run; the
    /// chain with Reforge and +1 Card is intentional (rewards cleverness).
    private func performExtraPick() {
        guard !extraPickUsedThisRun else { return }
        guard extraPicksRemaining == 0 else { return }
        guard displayedCards.count > 1 else { return }

        if IAPManager.shared.hasRemovedAds {
            executeExtraPick()
            return
        }

        let vc = view?.window?.rootViewController
        adReviveManager.requestExtraPickAd(from: vc) { [weak self] success in
            guard success else { return }
            self?.executeExtraPick()
        }
    }

    private func executeExtraPick() {
        extraPickUsedThisRun = true
        extraPicksRemaining = 1

        if let pickBtn = levelUpOverlay.childNode(withName: "extraPickButton") {
            if let label = pickBtn.childNode(withName: "extraPickLabel") as? SKLabelNode {
                label.text = "✓ PICK 2"
                label.fontColor = SKColor(hex: 0x88DD88)
            }
            if let adIcon = pickBtn.childNode(withName: "extraPickAdIcon") as? SKLabelNode {
                adIcon.alpha = 0
            }
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

    private func finishLevelUp(synergies: [UpgradeManager.SynergyUnlock]) {
        extraPicksRemaining = 0  // v1.7: safety — banked picks never outlive the spread

        // v1.8 Unit 5b: Barrier Pulse dropped from Guard (Repulse card owns
        // knockback). Guard 3 is now Ironhide — no level-up effect.

        // v1.6: Static Crown — level-ups release a shock burst
        if playerStats.staticCrownDamage > 0 {
            damageEnemiesInRadius(playerStats.staticCrownRadius,
                                  around: player.position,
                                  damage: playerStats.staticCrownDamage)
            showRingPulse(at: player.position,
                          radius: playerStats.staticCrownRadius,
                          colorHex: 0xFFE066)
        }

        // v1.8 Unit 14: Silver Skin (Guard/Void) — a level-up arms a one-hit block.
        if playerStats.hasSilverSkin {
            playerStats.silverSkinArmed = true
        }

        // v1.8 Unit 6 / v1.9 Unit 3: earned synergy tiers then card capstones
        // reveal one card-style modal at a time (holds the game). Both empty →
        // resume straight away.
        levelUpOverlay.run(SKAction.fadeOut(withDuration: 0.15))
        synergyQueue = synergies
        capstoneQueue = pendingCapstones
        pendingCapstones = []
        if synergyQueue.isEmpty && capstoneQueue.isEmpty {
            completeLevelUp()
        } else {
            gameState = .synergyReveal
            presentNextReveal()
        }
    }

    /// Resume play after the pick (and any synergy reveals) — the post-pick
    /// invulnerability buffer so the player can reorient.
    private func completeLevelUp() {
        invulnerableTimer = 2.5
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.2),
            SKAction.fadeAlpha(to: 1.0, duration: 0.2)
        ])
        player.run(SKAction.repeat(blink, count: 4), withKey: "invulnBlink")
        gameState = .playing
    }

    // MARK: - v1.8 Unit 6 / v1.9 Unit 3: reveal sequence (synergies → capstones)

    /// Present the next reveal — synergy tiers first, then card capstones.
    /// When both queues are drained, resume play.
    private func presentNextReveal() {
        if let next = synergyQueue.first {
            synergyQueue.removeFirst()
            AudioManager.shared.play(.buildHint)
            let modal = SynergyUnlockNode(unlock: next)
            modal.present(in: camera ?? self)
            synergyModal = modal
            return
        }
        if let cap = capstoneQueue.first {
            capstoneQueue.removeFirst()
            AudioManager.shared.play(.buildHint)
            let modal = SynergyUnlockNode(capstone: cap)
            modal.present(in: camera ?? self)
            synergyModal = modal
            return
        }
        completeLevelUp()  // both drained
    }

    /// Called on a tap while a reveal modal is up — dismiss it and advance.
    private func advanceSynergy() {
        guard let modal = synergyModal else { return }
        modal.dismiss()
        synergyModal = nil
        presentNextReveal()  // presents the next, or resumes if both drained
    }
    
    // MARK: - Game Loop
    
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        // Clamp dt so a pause, app-background, or frame hitch can't leap the
        // game-clock forward in a single frame — that used to jump every
        // dt-driven timer at once (Event Horizon, spawns, the boss bell).
        let dt = min(currentTime - lastUpdateTime, 0.1)
        lastUpdateTime = currentTime

        guard gameState == .playing else { return }

        // v1.9 fix: prune enemies that have died (their nodes self-remove via a
        // short death animation) so the auto-aim never locks onto a phantom
        // position. Some AoE death paths — Inferno Crown DOT, Unstable Core —
        // discard the death result and don't prune themselves, which used to
        // leave dead entries in `enemies` that pellets chased over the boss.
        // A kill is a kill: award its XP orb here (players shouldn't be robbed),
        // matching the burst-kill helpers — XP only, no on-kill cascade.
        enemies.removeAll { enemy in
            guard enemy.isDying else { return false }
            spawnXPOrb(at: enemy.position, value: enemy.xpValue)
            return true
        }

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
        updateFalseOpening(dt)

        let spawnEvent = waveManager.update(deltaTime: dt)
        // v1.6 tuning: wave spawns pause while a boss holds the arena —
        // the stage belongs to him. Boss-summoned minions (Titan's spawn
        // pattern) still arrive; waves resume the moment he falls.
        // v1.9 Erasure Event Horizon: the void has halted all spawning.
        if !eventHorizonVoided {
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
            } else if arenaConfig.id == 3 && ProgressionManager.shared.facetedLieUnlocked && boss == nil {
                spawnFacetedLie()
            } else {
                spawnMiniBoss()
            }
        }
        }  // end Event Horizon spawn guard

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

        // v1.8 Unit 2: forge XP coins (boss-death) — despawn when aged out
        forgeCoins.removeAll { coin in
            if coin.update(deltaTime: dt) { coin.removeFromParent(); return true }
            return false
        }

        updateHUD()
        
        // Camera follows player
        camera?.position = player.position
    }
    
    // MARK: - Enemy Updates
    
    private func updateEnemies(_ dt: TimeInterval) {
        var diedFromDOT: [Int] = []
        var crowdCount = 0  // v1.8 Ironhide: enemies pressing the player

        for (index, enemy) in enemies.enumerated() {
            // Use ranged AI for ranged enemies
            if let ranged = enemy as? RangedEnemyNode {
                ranged.rangedChase(target: player.position, deltaTime: dt, globalSlow: playerStats.globalEnemySlow)
            } else {
                enemy.chase(target: player.position, deltaTime: dt, globalSlow: playerStats.globalEnemySlow)
            }

            // v1.8 Undertow (Void 3): a subtle passive pull toward the player
            if playerStats.voidPullForce > 0 {
                let dist = enemy.position.distance(to: player.position)
                if dist < playerStats.voidPullRadius && dist > 1 {
                    let dir = (player.position - enemy.position).normalized
                    enemy.position += dir * (playerStats.voidPullForce * CGFloat(dt))
                }
            }

            // v1.8 Ironhide (Guard 3): tally the crowd pressing the player
            if playerStats.pressureDefBonus > 0
                && enemy.position.distance(to: player.position) < playerStats.pressureDefRadius {
                crowdCount += 1
            }

            // v1.8 (Unit 14): situational bleed scaling — Glass Blood (vs
            // chilled/slowed) and Red Smile (player below the HP threshold).
            // Defaults are 1.0, so this is a no-op unless a card is owned.
            var bleedMult: CGFloat = 1.0
            if enemy.isSlowed { bleedMult *= playerStats.bleedVsSlowedMultiplier }
            if playerStats.hpPercent < playerStats.bleedLowHpThreshold {
                bleedMult *= playerStats.bleedLowHpBonus
            }
            enemy.bleedDamageMultiplier = bleedMult

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

        // v1.8 Ironhide: pressure-DEF holds while the crowd condition is met
        playerStats.pressureDefActive = playerStats.pressureDefBonus > 0
            && crowdCount >= playerStats.pressureDefEnemyCount

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

        // v1.9: ONE true source for multishot/spread shape. Regular fire and
        // the Storm Engine spread-shot differ only in pellet COUNT — shape is
        // shared here so future spread content wires into one place instead of
        // its own branch that would need separate tuning later.
        fireShotSpread(count: shotCount, baseDirection: baseDirection)
    }

    /// The canonical multishot/spread pattern (v1.9). Shape scales by count,
    /// not by which system asked for the shot:
    /// - 1 pellet  → straight ahead.
    /// - 2 pellets → parallel columns (:), the v1.7 field-report look.
    /// - 3+ pellets → a V fan with a STATIC cone (spreadAngle × the GameConfig
    ///   factor); adding pellets packs them denser into the same fan rather
    ///   than widening it — so higher spread counts can't balloon the cone.
    private func fireShotSpread(count: Int, baseDirection: CGPoint) {
        guard count > 1 else {
            fireProjectile(direction: baseDirection)
            return
        }

        if count == 2 {
            let perp = CGPoint(x: -baseDirection.y, y: baseDirection.x)
            let spacing: CGFloat = 12
            let startOffset = -spacing * CGFloat(count - 1) / 2
            for i in 0..<count {
                let offset = perp * (startOffset + spacing * CGFloat(i))
                fireProjectile(direction: baseDirection, originOffset: offset)
            }
            return
        }

        let totalSpread = playerStats.spreadAngle * GameConfig.Projectile.multishotFanWidthFactor
        let startAngle = atan2(baseDirection.y, baseDirection.x) - totalSpread / 2
        let step = totalSpread / CGFloat(count - 1)
        for i in 0..<count {
            let angle = startAngle + step * CGFloat(i)
            let dir = CGPoint(x: cos(angle), y: sin(angle))
            fireProjectile(direction: dir)
        }
    }
    
    /// v1.6: Auto-aim considers regular enemies AND the boss.
    private func findNearestTargetPosition() -> CGPoint? {
        let range = playerStats.effectiveProjectileRange

        // v1.9 Skybeam Homing Beacon (T3): your fire prioritizes the lassoed prey.
        // The lasso target is the reusable priority hook other target-selecting
        // effects can read (lassoTargetNode) too.
        if playerStats.skybeamHoming, let node = lassoTargetNode,
           player.position.distance(to: node.position) <= range {
            return node.position
        }

        var closestPosition: CGPoint?
        var closestDist: CGFloat = .greatestFiniteMagnitude

        for enemy in enemies where !enemy.isDying {
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
    
    private func fireProjectile(direction: CGPoint, originOffset: CGPoint = .zero,
                                damageScale: CGFloat = 1.0, allowModifiers: Bool = true) {
        // v1.9 Polar Vortex Glacial Condensation (T4): primary shots don't fire
        // immediately — every Nth condenses into one icicle; the rest are absorbed.
        if playerStats.glacialActive && allowModifiers {
            playerStats.glacialShotCounter += 1
            if playerStats.glacialShotCounter % GameConfig.PolarVortex.glacialEveryN == 0 {
                fireIcicle(direction: direction, originOffset: originOffset)
            }
            return
        }

        let isCrit = CGFloat.random(in: 0...1) < playerStats.critChance

        let projectile = ProjectileNode(
            direction: direction,
            speed: playerStats.effectiveProjectileSpeed,
            range: playerStats.effectiveProjectileRange,
            pierces: playerStats.pierceCount,
            damageMultiplier: playerStats.effectiveDamageMultiplier * damageScale,
            isCrit: isCrit,
            spawnsGravityWell: playerStats.gravityWellOnExpire,
            voidStyle: playerStats.erasureVoidTouched,
            frostStyle: playerStats.polarVortexTier >= 1
        )
        projectile.position = player.position + originOffset
        projectile.zPosition = 8
        projectiles.append(projectile)
        worldNode.addChild(projectile)

        // Modifiers fire only from primary shots — fragments/echoes don't
        // themselves split or echo (no runaway multiplication).
        guard allowModifiers else { return }

        // v1.9 Erasure Echo (T4): a real shot re-fires 1.5s later from a random
        // arena-edge position, same heading, at reduced damage (no re-echo).
        if playerStats.erasureEcho {
            let echoDir = direction
            run(SKAction.sequence([
                SKAction.wait(forDuration: GameConfig.Erasure.echoDelay),
                SKAction.run { [weak self] in
                    guard let self = self, self.gameState == .playing else { return }
                    let ang = CGFloat.random(in: 0..<(2 * .pi))
                    let edge = CGPoint(x: cos(ang), y: sin(ang)) * (GameConfig.Arena.radius * 0.85)
                    self.fireProjectile(direction: echoDir,
                                        originOffset: edge - self.player.position,
                                        damageScale: GameConfig.Erasure.echoFraction,
                                        allowModifiers: false)
                }
            ]))
        }

        // Fracture Shot (Neutral): each shot launches split fragments at
        // reduced damage, angled off the main line.
        if playerStats.splitCount > 0 {
            let baseAngle = atan2(direction.y, direction.x)
            for k in 0..<playerStats.splitCount {
                // Fan the fragments symmetrically: -a, +a, -2a, +2a, …
                let step = CGFloat(k / 2 + 1) * playerStats.splitAngle
                let sign: CGFloat = (k % 2 == 0) ? -1 : 1
                let angle = baseAngle + sign * step
                let dir = CGPoint(x: cos(angle), y: sin(angle))
                fireProjectile(direction: dir, originOffset: originOffset,
                               damageScale: damageScale * playerStats.splitDamageMultiplier,
                               allowModifiers: false)
            }
        }

        // Mirror Edge (Void): a shot can echo once, later, for less damage.
        if playerStats.echoChance > 0 && CGFloat.random(in: 0...1) < playerStats.echoChance {
            run(SKAction.sequence([
                SKAction.wait(forDuration: playerStats.echoDelay),
                SKAction.run { [weak self] in
                    guard let self = self, self.gameState == .playing, !self.player.isDead else { return }
                    self.fireProjectile(direction: direction, originOffset: originOffset,
                                        damageScale: damageScale * self.playerStats.echoDamageMultiplier,
                                        allowModifiers: false)
                }
            ]))
        }
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

        // v1.9: Everglow (Fire capstone) — the player becomes a heat source.
        updateEverglow(dt)

        // v1.9: Iron Maiden (Guard capstone) — retaliation cooldown + T5 projectile.
        updateIronMaiden(dt)

        // v1.9: Skybeam (Shock capstone) — lasso the prey, call the strike.
        updateSkybeam(dt)

        // v1.9: Apex (Bleed capstone) — the Blood Familiar hunts.
        updateApex(dt)

        // v1.9: Erasure (Void capstone) — the Unstable meter lurches reality.
        updateErasure(dt)

        // v1.9: Polar Vortex (Chill capstone) — the cold storm stacks Chill.
        if playerStats.windchillActive { updateWindchill(dt) }

        // v1.6: Hoarfrost + Cauterize regen
        let regen = playerStats.updateRegen(dt)
        if regen > 0 {
            playerStats.heal(regen)
            hpBar.flashHeal()
        }
    }

    // MARK: - Everglow (Fire capstone)

    private func updateEverglow(_ dt: TimeInterval) {
        guard playerStats.everglowTier >= 1 else { return }

        // T1+ : close-range damage pulse on a fixed cadence.
        everglowPulseTimer += dt
        if everglowPulseTimer >= GameConfig.Everglow.pulseInterval {
            everglowPulseTimer -= GameConfig.Everglow.pulseInterval
            let dmg = playerStats.everglowPulseDamage
            if dmg > 0 {
                damageEnemiesInRadius(playerStats.everglowPulseRadius,
                                      around: player.position,
                                      damage: dmg, bossClassScaled: true)
                showRingPulse(at: player.position,
                              radius: playerStats.everglowPulseRadius,
                              colorHex: 0xFF6633)
            }
        }

        // T5 : periodic arena-wide eruption with a brief telegraph.
        if playerStats.everglowEruption {
            everglowEruptionTimer += dt
            if everglowEruptionTimer >= GameConfig.Everglow.eruptionInterval {
                everglowEruptionTimer -= GameConfig.Everglow.eruptionInterval
                triggerEverglowEruption()
            }
        }
    }

    /// Telegraph a swelling core at the player, then detonate arena-wide.
    private func triggerEverglowEruption() {
        let telegraph = SKShapeNode(circleOfRadius: 40)
        telegraph.strokeColor = SKColor(hex: 0xFF3300, alpha: 0.85)
        telegraph.fillColor = SKColor(hex: 0xFF6600, alpha: 0.15)
        telegraph.lineWidth = 4
        telegraph.glowWidth = 8
        telegraph.position = player.position
        telegraph.zPosition = 6
        worldNode.addChild(telegraph)
        let swell = SKAction.group([
            SKAction.scale(to: 6, duration: GameConfig.Everglow.eruptionTelegraph),
            SKAction.fadeAlpha(to: 0.4, duration: GameConfig.Everglow.eruptionTelegraph)
        ])
        swell.timingMode = .easeIn
        telegraph.run(SKAction.sequence([swell, SKAction.removeFromParent()]))

        run(SKAction.sequence([
            SKAction.wait(forDuration: GameConfig.Everglow.eruptionTelegraph),
            SKAction.run { [weak self] in self?.everglowEruptionDetonate() }
        ]))
    }

    /// Arena-wide burst: every enemy + the boss takes the eruption damage.
    private func everglowEruptionDetonate() {
        guard gameState == .playing else { return }
        let dmg = playerStats.everglowEruptionDamage
        guard dmg > 0 else { return }

        // Capstone damage: full vs the horde, halved on boss-class (BossClass canon).
        var killed: [EnemyNode] = []
        for enemy in enemies where !enemy.isDying {
            if enemy.takeDamage(GameConfig.BossClass.scaledDamage(dmg, isBossClass: enemy.isMiniBoss)) {
                killed.append(enemy)
            }
        }
        for enemy in killed {
            if let index = enemies.firstIndex(where: { $0 === enemy }) {
                spawnXPOrb(at: enemy.position, value: enemy.xpValue)
                enemies.remove(at: index)
            }
        }

        // Boss death flow (XP, bossKills, shake) runs via the boss's onDeath callback.
        if let bossNode = boss, !bossNode.isDead {
            bossNode.takeDamage(GameConfig.BossClass.scaledDamage(dmg, isBossClass: true))
        }

        // Big eruption visual — a bright expanding blast covering the arena.
        worldNode.shake(intensity: 10, duration: 0.3)
        let blast = SKShapeNode(circleOfRadius: 1)
        blast.fillColor = SKColor(hex: 0xFF6633, alpha: 0.45)
        blast.strokeColor = SKColor(hex: 0xFFCC33, alpha: 0.9)
        blast.lineWidth = 6
        blast.glowWidth = 20
        blast.position = player.position
        blast.zPosition = 7
        worldNode.addChild(blast)
        blast.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: GameConfig.Arena.radius * 1.2, duration: 0.4),
                SKAction.fadeOut(withDuration: 0.5)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Iron Maiden (Guard capstone)

    private func updateIronMaiden(_ dt: TimeInterval) {
        if ironRetaliateCooldown > 0 { ironRetaliateCooldown -= dt }
        guard playerStats.ironMaidenProjectile else { return }

        // T5 : release stored Kinetic energy at a priority foe on a fixed cadence.
        ironMaidenProjectileTimer += dt
        if ironMaidenProjectileTimer >= GameConfig.IronMaiden.projectileInterval {
            ironMaidenProjectileTimer = 0
            fireIronMaidenProjectile()
        }
    }

    /// T4 radial burst around the player: 200% DEF, consuming the Kinetic reserve.
    private func fireKineticBurst() {
        let dmg = playerStats.ironKineticBurstDamage
        damageEnemiesInRadius(GameConfig.IronMaiden.kineticBurstRadius,
                              around: player.position,
                              damage: dmg, bossClassScaled: true)
        showRingPulse(at: player.position,
                      radius: GameConfig.IronMaiden.kineticBurstRadius,
                      colorHex: 0x1FB6FF)
        worldNode.shake(intensity: 5, duration: 0.18)
    }

    /// A single combat target — a normal enemy or the arena boss. Shared by the
    /// capstones that acquire/track one specific foe (Iron Maiden priority strike,
    /// Skybeam lasso, later Apex prey). Reusable target abstraction.
    enum CombatTarget {
        case boss(any ArenaBossNode)
        case enemy(EnemyNode)
        var position: CGPoint {
            switch self {
            case .boss(let b): return b.position
            case .enemy(let e): return e.position
            }
        }
        /// Underlying node — for identity comparison across frames.
        var node: SKNode {
            switch self {
            case .boss(let b): return b
            case .enemy(let e): return e
            }
        }
    }

    private func findIronMaidenTarget() -> CombatTarget? {
        if let boss = boss, !boss.isDead { return .boss(boss) }
        var miniboss: EnemyNode?
        var nearest: EnemyNode?
        var nearestDist = CGFloat.greatestFiniteMagnitude
        for enemy in enemies where !enemy.isDying {
            if enemy.isMiniBoss, miniboss == nil { miniboss = enemy }
            let dist = player.position.distance(to: enemy.position)
            if dist < nearestDist { nearestDist = dist; nearest = enemy }
        }
        if let mb = miniboss { return .enemy(mb) }
        if let n = nearest { return .enemy(n) }
        return nil
    }

    private func fireIronMaidenProjectile() {
        guard let target = findIronMaidenTarget() else { return }
        // Release all stored Kinetic energy: the burst value if any is stored,
        // plus current Thorns. With nothing stored, the shot still carries Thorns.
        let kinetic = playerStats.ironKineticStacks > 0 ? playerStats.ironKineticBurstDamage : 0
        if playerStats.ironKineticStacks > 0 { kineticGauge.flashRelease() }
        playerStats.ironKineticStacks = 0
        let dmg = kinetic + playerStats.ironThorns
        guard dmg > 0 else { return }

        // Cannot miss, ignores collision: apply the payload directly, animate a
        // tracer. Capstone damage is halved on boss-class (BossClass canon).
        switch target {
        case .boss(let b):
            b.takeDamage(GameConfig.BossClass.scaledDamage(dmg, isBossClass: true))
        case .enemy(let e):
            dealDirectDamage(GameConfig.BossClass.scaledDamage(dmg, isBossClass: e.isMiniBoss), toEnemy: e)
        }
        showIronMaidenTracer(from: player.position, to: target.position)
    }

    private func showIronMaidenTracer(from: CGPoint, to: CGPoint) {
        let orb = SKShapeNode(circleOfRadius: 8)
        orb.fillColor = SKColor(hex: 0x1FB6FF, alpha: 0.9)
        orb.strokeColor = SKColor(hex: 0xEDEFF2, alpha: 1.0)
        orb.lineWidth = 2
        orb.glowWidth = 6
        orb.position = from
        orb.zPosition = 9
        worldNode.addChild(orb)
        orb.run(SKAction.sequence([
            SKAction.move(to: to, duration: 0.12),
            SKAction.run { [weak self] in self?.showRingPulse(at: to, radius: 40, colorHex: 0x1FB6FF) },
            SKAction.removeFromParent()
        ]))
        worldNode.shake(intensity: 4, duration: 0.12)
    }

    /// Deal flat damage to whatever an enemy body is (boss or normal), with kill
    /// bookkeeping. Mirrors the Iron Bloom / Thornwall retaliation pattern.
    private func dealRetaliationDamage(_ amount: Int, to enemyBody: SKPhysicsBody) {
        guard amount > 0 else { return }
        if let bossNode = enemyBody.node as? (any ArenaBossNode) {
            bossNode.takeDamage(amount)
        } else if let enemy = enemyBody.node as? EnemyNode {
            dealDirectDamage(amount, toEnemy: enemy)
        }
    }

    /// Deal flat damage to a specific normal enemy, handling kill bookkeeping.
    private func dealDirectDamage(_ amount: Int, toEnemy enemy: EnemyNode) {
        guard amount > 0 else { return }
        if enemy.takeDamage(amount) {
            if let index = enemies.firstIndex(where: { $0 === enemy }) {
                enemies.remove(at: index)
            }
            onEnemyKilled(at: enemy.position, xpValue: enemy.xpValue, enemy: enemy)
        }
    }

    // MARK: - Skybeam (Shock capstone)

    private func updateSkybeam(_ dt: TimeInterval) {
        guard playerStats.skybeamTier >= 1 else { return }
        if skybeamStrikeCooldown > 0 { skybeamStrikeCooldown -= dt }

        // Resolve/maintain the lasso target — retargets when it dies or leaves range.
        guard let target = currentLassoTarget() else { clearLasso(); return }

        // Continuous-attachment timer: same target accumulates; a change resets it
        // (and drops Called from the previous prey).
        if target.node === lassoTargetNode {
            skybeamAttachTime += dt
        } else {
            clearCalled()
            lassoTargetNode = target.node
            skybeamAttachTime = 0
            skybeamTickTimer = 0
        }

        // T1/T2 : Shock tick every second. If it kills the prey, drop the lasso.
        skybeamTickTimer += dt
        if skybeamTickTimer >= GameConfig.Skybeam.tickInterval {
            skybeamTickTimer -= GameConfig.Skybeam.tickInterval
            let dmg = max(1, Int(playerStats.effectiveAttack * playerStats.skybeamTickMult))
            if strikeCombatTarget(target, damage: dmg) { clearLasso(); return }
        }

        // T4 : Heaven's Call — the prey takes +35% from all sources after 2s.
        // Boss-class (miniboss + boss) gets it at reduced strength via the global
        // debuff factor (Called +35% → +17.5% on boss-class).
        if playerStats.skybeamCalled, skybeamAttachTime >= GameConfig.Skybeam.calledThreshold {
            switch target {
            case .enemy(let e):
                e.vulnerabilityMultiplier = GameConfig.BossClass.scaledDebuff(
                    GameConfig.Skybeam.calledVulnerability, isBossClass: e.isMiniBoss)
                calledEnemy = e
            case .boss(let b):
                b.vulnerabilityMultiplier = GameConfig.BossClass.scaledDebuff(
                    GameConfig.Skybeam.calledVulnerability, isBossClass: true)
                calledBoss = b
            }
        }

        // T5 : Skybeam — strike from above after 2s continuous, repeating on cooldown.
        if playerStats.skybeamStrike, skybeamAttachTime >= GameConfig.Skybeam.calledThreshold,
           skybeamStrikeCooldown <= 0 {
            beginSkyStrike(at: target)
            skybeamStrikeCooldown = GameConfig.Skybeam.strikeCooldown
        }

        drawLasso(to: target.position)
    }

    /// The current lasso target: keep the existing one while it's alive and within
    /// retention range, otherwise acquire the nearest valid foe within reach.
    private func currentLassoTarget() -> CombatTarget? {
        let acquire = playerStats.skybeamAcquireRange
        let retention = acquire * GameConfig.Skybeam.retentionFactor

        // 1) Hold the existing target if still valid and within retention range.
        if let node = lassoTargetNode {
            if let e = node as? EnemyNode, !e.isDying, enemies.contains(where: { $0 === e }),
               player.position.distance(to: e.position) <= retention {
                return .enemy(e)
            }
            if let boss = boss, !boss.isDead, node === (boss as SKNode),
               player.position.distance(to: boss.position) <= retention {
                return .boss(boss)
            }
        }

        // 2) Acquire the nearest valid target within acquisition range.
        var nearest: CombatTarget?
        var nearestDist = CGFloat.greatestFiniteMagnitude
        for enemy in enemies where !enemy.isDying {
            let d = player.position.distance(to: enemy.position)
            if d <= acquire && d < nearestDist { nearestDist = d; nearest = .enemy(enemy) }
        }
        if let boss = boss, !boss.isDead {
            let d = player.position.distance(to: boss.position)
            if d <= acquire && d < nearestDist { nearestDist = d; nearest = .boss(boss) }
        }
        return nearest
    }

    /// Deal capstone ability damage to a combat target (boss or enemy) with kill
    /// bookkeeping. Damage is halved on boss-class (miniboss + boss) via the
    /// global BossClass factor — capstones stay strong vs the horde, fair vs the
    /// big targets. Returns true if the hit killed a normal enemy.
    @discardableResult
    private func strikeCombatTarget(_ target: CombatTarget, damage: Int) -> Bool {
        switch target {
        case .boss(let b):
            b.takeDamage(GameConfig.BossClass.scaledDamage(damage, isBossClass: true))
            return false
        case .enemy(let e):
            let dmg = GameConfig.BossClass.scaledDamage(damage, isBossClass: e.isMiniBoss)
            let killed = e.takeDamage(dmg)
            if killed {
                if let index = enemies.firstIndex(where: { $0 === e }) { enemies.remove(at: index) }
                onEnemyKilled(at: e.position, xpValue: e.xpValue, enemy: e)
            }
            return killed
        }
    }

    /// Begin a sky-strike: a ~1s channel/telegraph, then the thunderbolt lands.
    private func beginSkyStrike(at target: CombatTarget) {
        let pos = target.position
        let windup = GameConfig.Skybeam.strikeWindup
        showSkyStrikeWindup(at: pos, duration: windup)
        run(SKAction.sequence([
            SKAction.wait(forDuration: windup),
            SKAction.run { [weak self] in self?.doSkyStrike(windupPos: pos, target: target) }
        ]))
    }

    /// The channel: a contracting warning ring, a charge descending from the sky,
    /// crackling arcs, and a bright "tell" flash near the end.
    private func showSkyStrikeWindup(at pos: CGPoint, duration: TimeInterval) {
        // Contracting warning ring — the "incoming" telegraph. Bold and bright.
        let warn = SKShapeNode(circleOfRadius: 85)
        warn.strokeColor = SKColor(hex: 0x88EEFF, alpha: 1.0)
        warn.fillColor = SKColor(hex: 0x66DDFF, alpha: 0.10)
        warn.lineWidth = 4
        warn.glowWidth = 7
        warn.position = pos
        warn.zPosition = 6
        worldNode.addChild(warn)
        warn.run(SKAction.sequence([
            SKAction.scale(to: 0.25, duration: duration * 0.85),
            SKAction.removeFromParent()
        ]))

        // Charge point descending from high above, swelling as it nears.
        let charge = SKShapeNode(circleOfRadius: 6)
        charge.fillColor = SKColor(hex: 0xCFF3FF, alpha: 0.9)
        charge.strokeColor = SKColor(hex: 0x66DDFF, alpha: 1.0)
        charge.glowWidth = 8
        charge.position = CGPoint(x: pos.x, y: pos.y + 260)
        charge.zPosition = 8
        worldNode.addChild(charge)
        charge.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveTo(y: pos.y + 40, duration: duration * 0.85),
                SKAction.scale(to: 2.2, duration: duration * 0.85)
            ]),
            SKAction.removeFromParent()
        ]))

        // Crackle arcs flickering above the target during the channel.
        let crackle = SKAction.run { [weak self] in
            guard let self = self else { return }
            let top = CGPoint(x: pos.x + CGFloat.random(in: -30...30),
                              y: pos.y + CGFloat.random(in: 90...200))
            let arc = SKShapeNode(path: self.jaggedBoltPath(from: top,
                                                            to: CGPoint(x: pos.x, y: pos.y + 30),
                                                            jitter: 12, segments: 4))
            arc.strokeColor = SKColor(hex: 0x99EEFF, alpha: 0.8)
            arc.lineWidth = 1.5
            arc.glowWidth = 3
            arc.zPosition = 7
            self.worldNode.addChild(arc)
            arc.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.12), SKAction.removeFromParent()]))
        }
        let flickers = max(1, Int(duration / 0.09))
        run(SKAction.repeat(SKAction.sequence([crackle, SKAction.wait(forDuration: 0.09)]),
                            count: flickers))

        // The "tell": a loud double-ring flash + bright flare + screen flash near
        // the end of the channel — unmistakably "it's coming."
        run(SKAction.sequence([
            SKAction.wait(forDuration: duration * 0.8),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.showRingPulse(at: pos, radius: 75, colorHex: 0xFFFFFF)
                self.showRingPulse(at: pos, radius: 55, colorHex: 0x66DDFF)
                self.flashScreen(colorHex: 0x88DDFF, alpha: 0.22, duration: 0.16)
                let flare = SKShapeNode(circleOfRadius: 10)
                flare.fillColor = SKColor(hex: 0xFFFFFF, alpha: 0.9)
                flare.strokeColor = .clear
                flare.glowWidth = 10
                flare.position = pos
                flare.zPosition = 8
                self.worldNode.addChild(flare)
                flare.run(SKAction.sequence([
                    SKAction.group([SKAction.scale(to: 2.2, duration: 0.18),
                                    SKAction.fadeOut(withDuration: 0.2)]),
                    SKAction.removeFromParent()
                ]))
            }
        ]))
    }

    /// The payoff: a thick multi-bolt thunderclap, screen flash, shockwaves, and
    /// heavy shake — then the damage lands on the (still-lassoed) prey.
    private func doSkyStrike(windupPos: CGPoint, target: CombatTarget) {
        guard gameState == .playing else { return }
        let alive = isTargetAlive(target)
        let pos = alive ? target.position : windupPos

        // Thick multi-bolt slamming from the top of the view onto the target.
        for k in 0..<4 {
            let spread = CGFloat(k) * 5 - 7
            let top = CGPoint(x: pos.x + spread, y: pos.y + 900)
            let bolt = SKShapeNode(path: jaggedBoltPath(from: top, to: pos, jitter: 22))
            bolt.strokeColor = SKColor(hex: k == 0 ? 0xFFFFFF : 0x66DDFF, alpha: 1.0)
            bolt.lineWidth = k == 0 ? 5 : 3
            bolt.glowWidth = k == 0 ? 14 : 8
            bolt.zPosition = 9
            worldNode.addChild(bolt)
            bolt.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.28), SKAction.removeFromParent()]))
        }

        // Blinding core burst at the impact.
        let core = SKShapeNode(circleOfRadius: 12)
        core.fillColor = SKColor(hex: 0xFFFFFF, alpha: 0.95)
        core.strokeColor = .clear
        core.glowWidth = 12
        core.position = pos
        core.zPosition = 9
        worldNode.addChild(core)
        core.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 3, duration: 0.2), SKAction.fadeOut(withDuration: 0.25)]),
            SKAction.removeFromParent()
        ]))

        // Double shockwave.
        for delay in [0.0, 0.09] {
            run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run { [weak self] in self?.showRingPulse(at: pos, radius: 90, colorHex: 0x66DDFF) }
            ]))
        }

        // Radiating ground arcs jumping outward from the impact.
        for _ in 0..<6 {
            let ang = CGFloat.random(in: 0..<(2 * .pi))
            let end = CGPoint(x: pos.x + cos(ang) * CGFloat.random(in: 40...80),
                              y: pos.y + sin(ang) * CGFloat.random(in: 40...80))
            let node = SKShapeNode(path: jaggedBoltPath(from: pos, to: end, jitter: 10, segments: 4))
            node.strokeColor = SKColor(hex: 0x99EEFF, alpha: 0.9)
            node.lineWidth = 2
            node.glowWidth = 4
            node.zPosition = 8
            worldNode.addChild(node)
            node.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.22), SKAction.removeFromParent()]))
        }

        // Screen flash + heavy shake + the thunderclap.
        flashScreen(colorHex: 0x88DDFF, alpha: 0.35, duration: 0.22)
        worldNode.shake(intensity: 14, duration: 0.35)
        AudioManager.shared.play(.skyStrike)

        if alive {
            let dmg = max(1, Int(playerStats.effectiveAttack * GameConfig.Skybeam.strikeMult))
            strikeCombatTarget(target, damage: dmg)
        }
    }

    /// Is a captured target still a live, valid strike target?
    private func isTargetAlive(_ target: CombatTarget) -> Bool {
        switch target {
        case .boss(let b): return !b.isDead
        case .enemy(let e): return !e.isDying && enemies.contains(where: { $0 === e })
        }
    }

    /// A jagged lightning path between two points (x-jitter per segment).
    private func jaggedBoltPath(from: CGPoint, to: CGPoint, jitter: CGFloat, segments: Int = 6) -> CGPath {
        let path = CGMutablePath()
        path.move(to: from)
        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let base = CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
            let off = (i == segments) ? 0 : CGFloat.random(in: -jitter...jitter)
            path.addLine(to: CGPoint(x: base.x + off, y: base.y))
        }
        return path
    }

    /// A brief additive full-screen flash (camera-anchored). Reusable juice.
    private func flashScreen(colorHex: UInt32, alpha: CGFloat, duration: TimeInterval) {
        guard let camera = camera else { return }
        let flash = SKSpriteNode(color: SKColor(hex: colorHex, alpha: alpha),
                                 size: CGSize(width: size.width * 1.6, height: size.height * 1.6))
        flash.blendMode = .add
        flash.zPosition = 300
        camera.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: duration),
            SKAction.removeFromParent()
        ]))
    }

    /// The persistent lightning tether from the player to the lassoed prey.
    private func drawLasso(to targetPos: CGPoint) {
        let mid = CGPoint(x: (player.position.x + targetPos.x) / 2 + CGFloat.random(in: -8...8),
                          y: (player.position.y + targetPos.y) / 2 + CGFloat.random(in: -8...8))
        let path = CGMutablePath()
        path.move(to: player.position)
        path.addLine(to: mid)
        path.addLine(to: targetPos)
        if lassoLine == nil {
            let line = SKShapeNode()
            line.strokeColor = SKColor(hex: 0x66DDFF, alpha: 0.8)
            line.lineWidth = 2
            line.glowWidth = 4
            line.zPosition = 7
            worldNode.addChild(line)
            lassoLine = line
        }
        lassoLine?.path = path
    }

    /// Drop the tether and all attachment state (target left range / died / capstone off).
    private func clearLasso() {
        lassoLine?.removeFromParent()
        lassoLine = nil
        lassoTargetNode = nil
        skybeamAttachTime = 0
        skybeamTickTimer = 0
        clearCalled()
    }

    /// Remove the Called vulnerability from the previously-marked prey.
    private func clearCalled() {
        calledEnemy?.vulnerabilityMultiplier = 1.0
        calledEnemy = nil
        calledBoss?.vulnerabilityMultiplier = 1.0
        calledBoss = nil
    }

    // MARK: - Apex (Bleed capstone)

    private func updateApex(_ dt: TimeInterval) {
        guard playerStats.apexFamiliarActive else {
            apexFamiliar?.removeFromParent(); apexFamiliar = nil
            apexTargetMarker?.removeFromParent(); apexTargetMarker = nil
            player.setApexFeatures(false)
            apexFamiliarTier = 0
            return
        }
        // Summon the familiar on first activation.
        if apexFamiliar == nil {
            let fam = FamiliarNode()
            fam.position = player.position
            worldNode.addChild(fam)
            apexFamiliar = fam
        }
        // On each tier-up: the bat grows, and at T5 Spark sprouts bat features.
        if apexFamiliarTier != playerStats.apexTier {
            apexFamiliarTier = playerStats.apexTier
            apexFamiliar?.setBodyScale(1.0 + CGFloat(max(0, playerStats.apexTier - 1)) * 0.12)
            player.setApexFeatures(playerStats.apexHunter)
        }
        // Orbit a home point near the player.
        apexOrbitPhase += CGFloat(dt) * 1.2
        let off = GameConfig.Apex.familiarHomeOffset
        let home = CGPoint(x: player.position.x + cos(apexOrbitPhase) * off,
                           y: player.position.y + sin(apexOrbitPhase) * off + off * 0.4)
        apexFamiliar?.follow(to: home, dt: dt)

        // T4 Marked: lingering enemies (and the boss) become vulnerable — boss-class
        // at reduced strength via the global factor. Persists until death.
        if playerStats.apexMarked {
            for e in enemies where !e.isDying {
                if e.timeAlive >= GameConfig.Apex.markLifetime && e.vulnerabilityMultiplier == 1.0 {
                    e.vulnerabilityMultiplier = GameConfig.BossClass.scaledDebuff(
                        GameConfig.Apex.markVulnerability, isBossClass: e.isMiniBoss)
                    showRingPulse(at: e.position, radius: 26, colorHex: 0x99304D)
                }
            }
            if let b = boss, !b.isDead, b.vulnerabilityMultiplier == 1.0 {
                b.vulnerabilityMultiplier = GameConfig.BossClass.scaledDebuff(
                    GameConfig.Apex.markVulnerability, isBossClass: true)
            }
        }

        // The bat hunts + bites at EVERY tier — mark the current target, then bite.
        let target = findBatTarget()
        updateApexTargetMarker(target)
        apexAttackTimer += dt
        if apexAttackTimer >= GameConfig.Apex.familiarAttackInterval {
            if let target = target {
                apexAttackTimer = 0
                batBite(target)
            } else {
                apexAttackTimer = GameConfig.Apex.familiarAttackInterval  // stay primed
            }
        }

        // T5 The Hunter: charge the pounce gauge; when full AND off cooldown, leap
        // + execute. The gauge can sit full through the cooldown — the CD paces
        // the pounces even when the bar fills fast.
        if playerStats.apexHunter {
            if apexStackTimer > 0 { apexStackTimer -= dt }
            if apexPounceCooldown > 0 { apexPounceCooldown -= dt }
            if apexPounceStacks >= GameConfig.Apex.pounceGaugeCapacity && apexPounceCooldown <= 0 {
                apexTryPounceExecute()
            }
        }
    }

    /// Prey selection: T3 Bloodhound favours the nearest bleeding foe; otherwise
    /// the nearest enemy (then the boss) within the familiar's reach.
    private func findBatTarget() -> CombatTarget? {
        let range = GameConfig.Apex.familiarRange
        var nearest: EnemyNode?; var nearestD = CGFloat.greatestFiniteMagnitude
        var nearestBleed: EnemyNode?; var nearestBleedD = CGFloat.greatestFiniteMagnitude
        for e in enemies where !e.isDying {
            let d = player.position.distance(to: e.position)
            guard d <= range else { continue }
            if d < nearestD { nearestD = d; nearest = e }
            if e.isBleeding && d < nearestBleedD { nearestBleedD = d; nearestBleed = e }
        }
        if playerStats.apexBloodhound, let b = nearestBleed { return .enemy(b) }
        if let n = nearest { return .enemy(n) }
        if let boss = boss, !boss.isDead, player.position.distance(to: boss.position) <= range {
            return .boss(boss)
        }
        return nil
    }

    private func batBite(_ target: CombatTarget) {
        apexFamiliar?.lunge(at: target.position)
        let base = max(1, Int(playerStats.effectiveAttack * playerStats.apexFamiliarDamageFrac))
        switch target {
        case .enemy(let e):
            let bossClass = e.isMiniBoss
            // T3 execute: weak NORMAL enemies die outright on a bite (never boss-class).
            if playerStats.apexBloodhound && !bossClass
                && e.healthPercent < GameConfig.Apex.executeThreshold {
                executeMob(e)
            } else if e.takeDamage(GameConfig.BossClass.scaledDamage(base, isBossClass: bossClass)) {
                recordBatKill(e)
            }
        case .boss(let b):
            b.takeDamage(GameConfig.BossClass.scaledDamage(base, isBossClass: true))
        }
        apexRegisterAttack()   // T5: every bite charges the pounce gauge
        showBiteSpark(at: target.position)
    }

    /// A familiar kill: remove + bookkeeping, and feed the bat's damage growth.
    private func recordBatKill(_ e: EnemyNode) {
        if let i = enemies.firstIndex(where: { $0 === e }) { enemies.remove(at: i) }
        playerStats.apexFamiliarKills += 1
        onEnemyKilled(at: e.position, xpValue: e.xpValue, enemy: e)
    }

    /// Execute a normal enemy outright — lethal hit + a pixelated blood-mist
    /// flourish. Only the familiar's execute paths (Bloodhound bite, pounce
    /// finisher) use this, so the mist reads as "the hunter finished it."
    private func executeMob(_ e: EnemyNode) {
        let pos = e.position
        if e.takeDamage(e.health) {
            showBloodMist(at: pos)
            recordBatKill(e)
        }
    }

    /// A pixelated blood-mist burst — a bright pop, a soft haze, and a spray of
    /// crimson squares (with a few big chunks). Over-the-top on purpose.
    private func showBloodMist(at pos: CGPoint) {
        // Bright pop flash.
        let pop = SKShapeNode(circleOfRadius: 14)
        pop.fillColor = SKColor(hex: 0xFF3050, alpha: 0.8)
        pop.strokeColor = .clear
        pop.glowWidth = 8
        pop.position = pos
        pop.zPosition = 9
        worldNode.addChild(pop)
        pop.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 2.4, duration: 0.12), SKAction.fadeOut(withDuration: 0.16)]),
            SKAction.removeFromParent()
        ]))
        // Soft haze.
        let haze = SKShapeNode(circleOfRadius: 14)
        haze.fillColor = SKColor(hex: 0x8B0018, alpha: 0.5)
        haze.strokeColor = .clear
        haze.position = pos
        haze.zPosition = 8
        worldNode.addChild(haze)
        haze.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 4.0, duration: 0.3), SKAction.fadeOut(withDuration: 0.36)]),
            SKAction.removeFromParent()
        ]))
        // Pixel spray — more, bigger, with occasional chunks.
        let s = DeviceScale.gameplay
        let colors: [UInt32] = [0xC01030, 0xE0304D, 0x8B0018, 0xFF5070, 0x600018, 0xFF7090]
        for i in 0..<20 {
            let big = i % 5 == 0
            let size = (big ? CGFloat.random(in: 7...10) : CGFloat.random(in: 3...6)) * s
            let px = SKShapeNode(rectOf: CGSize(width: size, height: size))
            px.fillColor = SKColor(hex: colors[i % colors.count], alpha: 1.0)
            px.strokeColor = .clear
            px.position = pos
            px.zPosition = 9
            px.zRotation = CGFloat.random(in: 0..<(.pi / 2))
            worldNode.addChild(px)
            let ang = CGFloat.random(in: 0..<(2 * .pi))
            let dist = CGFloat.random(in: 24...72) * s
            let dest = CGPoint(x: pos.x + cos(ang) * dist, y: pos.y + sin(ang) * dist)
            let fly = SKAction.move(to: dest, duration: Double.random(in: 0.24...0.42))
            fly.timingMode = .easeOut
            px.run(SKAction.sequence([
                SKAction.group([fly,
                                SKAction.fadeOut(withDuration: 0.4),
                                SKAction.scale(to: 0.2, duration: 0.4)]),
                SKAction.removeFromParent()
            ]))
        }
        worldNode.shake(intensity: 3, duration: 0.1)
    }

    /// T5: EVERY attack charges the pounce gauge (rate-limited). Called from the
    /// bat's bites and the player's projectiles.
    private func apexRegisterAttack() {
        guard playerStats.apexHunter, apexStackTimer <= 0,
              apexPounceStacks < GameConfig.Apex.pounceGaugeCapacity else { return }
        apexPounceStacks += 1
        apexStackTimer = GameConfig.Apex.pounceStackCooldown
        apexGauge.setFilled(apexPounceStacks)
    }

    /// Gauge full: the bat leaps to the nearest weakened enemy and executes it.
    /// Normals below the execute threshold; boss-class only below the 10% floor.
    /// If nothing is executable yet, the full charge is held until something is.
    private func apexTryPounceExecute() {
        var best: CombatTarget?
        var bestD = CGFloat.greatestFiniteMagnitude
        for e in enemies where !e.isDying {
            let executable = e.isMiniBoss
                ? e.healthPercent <= GameConfig.BossClass.executeThreshold
                : e.healthPercent < GameConfig.Apex.pounceExecuteThreshold
            guard executable else { continue }
            let d = player.position.distance(to: e.position)
            if d < bestD { bestD = d; best = .enemy(e) }
        }
        if let b = boss, !b.isDead, b.healthPercent <= GameConfig.BossClass.executeThreshold {
            let d = player.position.distance(to: b.position)
            if d < bestD { bestD = d; best = .boss(b) }
        }
        guard let target = best else { return }   // hold the charge until a target is weak enough

        apexPounceStacks = 0
        apexGauge.flashRelease()
        apexPounceCooldown = GameConfig.Apex.pounceCooldown
        apexFamiliar?.pounce(at: target.position)
        showPounceImpact(at: target.position)
        switch target {
        case .enemy(let e):
            executeMob(e)                          // instant kill + blood mist
        case .boss(let b):
            showBossExecuteEvent(at: b.position)   // screen-wide finish
            b.takeDamage(b.health)
        }
    }

    /// A pulsing colored ring under the mob the bat is currently hunting.
    private func updateApexTargetMarker(_ target: CombatTarget?) {
        if apexTargetMarker == nil {
            let m = SKShapeNode(circleOfRadius: 16 * DeviceScale.gameplay)
            m.strokeColor = SKColor(hex: 0xE0304D, alpha: 0.9)
            m.fillColor = SKColor(hex: 0xE0304D, alpha: 0.14)
            m.lineWidth = 2
            m.glowWidth = 3
            m.zPosition = 4
            m.alpha = 0
            worldNode.addChild(m)
            m.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: 1.18, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5)
            ])))
            apexTargetMarker = m
        }
        if let t = target {
            apexTargetMarker?.position = t.position
            apexTargetMarker?.alpha = 1
        } else {
            apexTargetMarker?.alpha = 0
        }
    }

    /// Show/hide + sync the pounce gauge with T5 state.
    private func refreshApexGauge() {
        if playerStats.apexHunter {
            apexGauge.configure(capacity: GameConfig.Apex.pounceGaugeCapacity, filledColor: 0xE0304D)
            apexGauge.setFilled(apexPounceStacks)
        } else {
            apexGauge.configure(capacity: 0, filledColor: 0xE0304D)
        }
    }

    /// A screen-wide finish when the pounce executes a boss at ≤10% HP — LOUD.
    private func showBossExecuteEvent(at pos: CGPoint) {
        AudioManager.shared.play(.bossExecute)
        flashScreen(colorHex: 0xE01030, alpha: 0.55, duration: 0.4)
        worldNode.shake(intensity: 22, duration: 0.6)
        showBloodMist(at: pos)
        showBloodMist(at: pos)   // double gore
        for r in [CGFloat(140), 210, 290] {
            showRingPulse(at: pos, radius: r, colorHex: 0xE0304D)
        }
        let core = SKShapeNode(circleOfRadius: 24)
        core.fillColor = SKColor(hex: 0xFF2040, alpha: 0.95)
        core.strokeColor = SKColor(hex: 0xFFFFFF, alpha: 0.95)
        core.glowWidth = 26
        core.position = pos
        core.zPosition = 10
        worldNode.addChild(core)
        core.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 9, duration: 0.4), SKAction.fadeOut(withDuration: 0.5)]),
            SKAction.removeFromParent()
        ]))
    }

    private func showBiteSpark(at pos: CGPoint) {
        let spark = SKShapeNode(circleOfRadius: 6)
        spark.fillColor = SKColor(hex: 0xE03050, alpha: 0.7)
        spark.strokeColor = SKColor(hex: 0xFF6080, alpha: 0.9)
        spark.glowWidth = 4
        spark.position = pos
        spark.zPosition = 8
        worldNode.addChild(spark)
        spark.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 1.8, duration: 0.14), SKAction.fadeOut(withDuration: 0.16)]),
            SKAction.removeFromParent()
        ]))
    }

    private func showPounceImpact(at pos: CGPoint) {
        worldNode.shake(intensity: 8, duration: 0.22)
        let core = SKShapeNode(circleOfRadius: 10)
        core.fillColor = SKColor(hex: 0xE01030, alpha: 0.85)
        core.strokeColor = SKColor(hex: 0xFF7090, alpha: 1.0)
        core.glowWidth = 10
        core.position = pos
        core.zPosition = 9
        worldNode.addChild(core)
        core.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 3.2, duration: 0.2), SKAction.fadeOut(withDuration: 0.25)]),
            SKAction.removeFromParent()
        ]))
        showRingPulse(at: pos, radius: 70, colorHex: 0xE0304D)
        // Two crossing fang slashes.
        for a in [CGFloat(-0.5), 0.5] {
            let slash = SKShapeNode()
            let p = CGMutablePath()
            p.move(to: CGPoint(x: pos.x - 20, y: pos.y + a * 18))
            p.addLine(to: CGPoint(x: pos.x + 20, y: pos.y - a * 18))
            slash.path = p
            slash.strokeColor = SKColor(hex: 0xFFAABB, alpha: 0.9)
            slash.lineWidth = 3
            slash.glowWidth = 4
            slash.zPosition = 9
            worldNode.addChild(slash)
            slash.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.2), SKAction.removeFromParent()]))
        }
    }

    // MARK: - Erasure (Void capstone) — the Unstable chaos table

    /// The Unstable meter is full + off cooldown: charge a hit toward it.
    private func erasureRegisterHit() {
        guard playerStats.erasureActive, erasureStackTimer <= 0,
              erasureStacks < GameConfig.Erasure.unstableGaugeCapacity else { return }
        erasureStacks += 1
        erasureStackTimer = GameConfig.Erasure.unstableStackCooldown
        erasureGauge.setFilled(erasureStacks)
    }

    /// Per-frame: tick the meter timers; when full + off the internal CD, fire one
    /// random effect at the nearest foe (holds the full charge if the arena's empty).
    private func updateErasure(_ dt: TimeInterval) {
        guard playerStats.erasureActive else { return }
        if erasureStackTimer > 0 { erasureStackTimer -= dt }
        if erasureTriggerCooldown > 0 { erasureTriggerCooldown -= dt }

        if erasureStacks >= GameConfig.Erasure.unstableGaugeCapacity, erasureTriggerCooldown <= 0,
           let target = nearestEnemyToPlayer() {
            erasureStacks = 0
            erasureGauge.flashRelease()
            erasureTriggerCooldown = playerStats.erasureTriggerCD
            triggerUnstable(on: target)
        }

        // T5: the run-ending void.
        if playerStats.erasureEventHorizon { updateEventHorizon() }
    }

    /// T5 Event Horizon — a one-per-run scripted countdown from ACQUISITION,
    /// arena-scaled: at the erase time the arena is wiped + spawning halts; at the
    /// end time the player is erased, bypassing all death-prevention.
    private func updateEventHorizon() {
        // Stamp the acquisition time on the first frame after T5 is taken.
        if playerStats.erasureEventHorizonAcquireTime < 0 {
            playerStats.erasureEventHorizonAcquireTime = waveManager.elapsedTime
            showBuildHint("⌛ EVENT HORIZON — the void awakens")
        }
        let scale = TimeInterval(GameConfig.Erasure.eventHorizonScale(arena: arenaConfig.id))
        let since = waveManager.elapsedTime - playerStats.erasureEventHorizonAcquireTime

        if since >= GameConfig.Erasure.eventHorizonEraseTime * scale && !eventHorizonErased {
            eventHorizonErased = true
            eraseArena()
        }
        if since >= GameConfig.Erasure.eventHorizonEndTime * scale && !eventHorizonEnded {
            eventHorizonEnded = true
            forcePlayerErased()
        }

        // Once the arena's erased (point of no return), count down your own doom.
        if eventHorizonErased && !eventHorizonEnded {
            updateEventHorizonCountdown(remaining: GameConfig.Erasure.eventHorizonEndTime * scale - since)
        }
    }

    /// The "VOID COLLAPSE" doom timer — Void-purple, pulses each tick, intensifies
    /// in the final 5s. Impending, self-chosen dread.
    private func updateEventHorizonCountdown(remaining: TimeInterval) {
        if eventHorizonCountdown == nil {
            guard let camera = camera else { return }
            let container = SKNode()
            container.position = CGPoint(x: 0, y: 74)
            container.zPosition = 250
            let title = SKLabelNode(fontNamed: "Menlo-Bold")
            title.text = "VOID COLLAPSE"
            title.fontSize = 15
            title.fontColor = SKColor(hex: 0xC060FF)
            title.position = CGPoint(x: 0, y: 44)
            title.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.4, duration: 0.6),
                SKAction.fadeAlpha(to: 1.0, duration: 0.6)
            ])))
            container.addChild(title)
            let num = SKLabelNode(fontNamed: "Menlo-Bold")
            num.name = "ehNum"
            num.fontSize = 60
            num.fontColor = SKColor(hex: 0xB565D8)
            num.verticalAlignmentMode = .center
            container.addChild(num)
            camera.addChild(container)
            eventHorizonCountdown = container
        }
        guard let num = eventHorizonCountdown?.childNode(withName: "ehNum") as? SKLabelNode else { return }
        let secs = max(0, Int(ceil(remaining)))
        if num.text != "\(secs)" {
            num.text = "\(secs)"
            let finalStretch = secs <= 5
            num.fontColor = SKColor(hex: finalStretch ? 0xE85CFF : 0xB565D8)
            num.removeAllActions()
            num.setScale(finalStretch ? 1.6 : 1.25)
            num.run(SKAction.scale(to: 1.0, duration: 0.35))
            if finalStretch { worldNode.shake(intensity: 2, duration: 0.1) }
        }
    }

    private func hideEventHorizonCountdown() {
        eventHorizonCountdown?.removeFromParent()
        eventHorizonCountdown = nil
    }

    /// Phase 1: erase every enemy, the boss (normal mode: outright), hostile
    /// projectiles + gravity wells, and halt spawning — the arena goes silent.
    private func eraseArena() {
        for e in enemies {
            showUnstablePop(at: e.position)
            e.removeFromParent()
        }
        enemies.removeAll()
        // Normal mode: the boss is erased outright. (Boss Mode's catastrophic-
        // damage variant is v2.0 — see the Event-Horizon spec memory.)
        if let b = boss, !b.isDead { b.takeDamage(b.health) }
        for p in enemyProjectiles { p.removeFromParent() }
        enemyProjectiles.removeAll()
        for well in gravityWells { well.removeFromParent() }
        gravityWells.removeAll()

        // Halt spawns for a brief breather, then let the arena refill — the void
        // gives a clear board + a breath, then takes it back while the clock ticks.
        eventHorizonVoided = true
        run(SKAction.sequence([
            SKAction.wait(forDuration: GameConfig.Erasure.eventHorizonPeaceDuration),
            SKAction.run { [weak self] in self?.eventHorizonVoided = false }
        ]), withKey: "eventHorizonPeace")
        flashScreen(colorHex: 0x6C3483, alpha: 0.55, duration: 0.6)
        worldNode.shake(intensity: 16, duration: 0.6)
        showBuildHint("the arena is erased")
    }

    /// Phase 2: the player is erased. A scripted run-end that bypasses ALL
    /// death-prevention — called directly, so lethal-save / ad-revive never run.
    private func forcePlayerErased() {
        hideEventHorizonCountdown()
        flashScreen(colorHex: 0x3A1050, alpha: 0.7, duration: 0.6)
        worldNode.shake(intensity: 20, duration: 0.7)
        showRingPulse(at: player.position, radius: 220, colorHex: 0x6C3483)
        let collapse = SKShapeNode(circleOfRadius: 30)
        collapse.fillColor = SKColor(hex: 0x1A0028, alpha: 0.9)
        collapse.strokeColor = SKColor(hex: 0xC060FF, alpha: 0.95)
        collapse.glowWidth = 22
        collapse.position = player.position
        collapse.zPosition = 20
        worldNode.addChild(collapse)
        collapse.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 8, duration: 0.5), SKAction.fadeOut(withDuration: 0.6)]),
            SKAction.removeFromParent()
        ]))
        playerDied()   // direct — bypasses tryLethalSave / ad-revive
    }

    private func nearestEnemyToPlayer() -> EnemyNode? {
        var nearest: EnemyNode?
        var best = CGFloat.greatestFiniteMagnitude
        for e in enemies where !e.isDying {
            let d = player.position.distance(to: e.position)
            if d < best { best = d; nearest = e }
        }
        return nearest
    }

    /// Show/hide + sync the Unstable meter with T1 state.
    private func refreshErasureGauge() {
        if playerStats.erasureActive {
            erasureGauge.configure(capacity: GameConfig.Erasure.unstableGaugeCapacity, filledColor: 0x9B59B6)
            erasureGauge.setFilled(erasureStacks)
        } else {
            erasureGauge.configure(capacity: 0, filledColor: 0x9B59B6)
        }
    }

    /// Fire one random effect from the 7-entry table at a foe (uniform for now;
    /// weights are tunable). Counts the activation (drives the T3 rift cannon).
    private func triggerUnstable(on enemy: EnemyNode) {
        playerStats.erasureActivations += 1
        let pos = enemy.position
        showUnstablePop(at: pos)
        switch Int.random(in: 0..<7) {
        case 0: erasureImplosion(at: pos)
        case 1: erasureRiftBurst(at: pos)
        case 2: erasurePhaseLock(at: pos)
        case 3: erasureDamageEcho(on: enemy)
        case 4: erasureDisplacement(enemy)
        case 5: erasureFracture(enemy)
        default: erasureBackwash(at: pos)
        }

        // T3 Rift Cannon — every Nth activation, a rift fires a beam across the arena.
        if playerStats.erasureRiftCannon
            && playerStats.erasureActivations % GameConfig.Erasure.riftCannonEveryN == 0 {
            fireRiftCannon()
        }
    }

    /// T3: a rift opens at a random arena point and fires a beam along a random
    /// vector, hitting every enemy (and the boss) within the beam's width.
    private func fireRiftCannon() {
        let arenaR = GameConfig.Arena.radius
        let oAng = CGFloat.random(in: 0..<(2 * .pi))
        let origin = CGPoint(x: cos(oAng), y: sin(oAng)) * CGFloat.random(in: 0...(arenaR * 0.6))
        let vAng = CGFloat.random(in: 0..<(2 * .pi))
        let dir = CGPoint(x: cos(vAng), y: sin(vAng))
        let dmg = max(1, Int(playerStats.effectiveAttack * GameConfig.Erasure.riftCannonMult))
        let width = GameConfig.Erasure.riftCannonWidth

        var killed: [EnemyNode] = []
        for e in enemies where !e.isDying {
            let rel = e.position - origin
            if abs(rel.x * dir.y - rel.y * dir.x) < width {   // perpendicular distance to the beam line
                if e.takeDamage(GameConfig.BossClass.scaledDamage(dmg, isBossClass: e.isMiniBoss)) {
                    killed.append(e)
                }
            }
        }
        for e in killed {
            if let i = enemies.firstIndex(where: { $0 === e }) { enemies.remove(at: i) }
            onEnemyKilled(at: e.position, xpValue: e.xpValue, enemy: e)
        }
        if let b = boss, !b.isDead {
            let rel = b.position - origin
            if abs(rel.x * dir.y - rel.y * dir.x) < width {
                b.takeDamage(GameConfig.BossClass.scaledDamage(dmg, isBossClass: true))
            }
        }
        showRiftBeam(origin: origin, dir: dir)
    }

    private func showRiftBeam(origin: CGPoint, dir: CGPoint) {
        let span = GameConfig.Arena.radius * 2.2
        let path = CGMutablePath()
        path.move(to: origin - dir * span)
        path.addLine(to: origin + dir * span)
        let beam = SKShapeNode(path: path)
        beam.strokeColor = SKColor(hex: 0xC060FF, alpha: 0.95)
        beam.lineWidth = 5
        beam.glowWidth = 14
        beam.zPosition = 9
        worldNode.addChild(beam)
        beam.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.35), SKAction.removeFromParent()]))
        showRingPulse(at: origin, radius: 52, colorHex: 0x9B59B6)
        worldNode.shake(intensity: 6, duration: 0.2)
    }

    /// 1. Implosion — pull nearby enemies toward the point.
    private func erasureImplosion(at pos: CGPoint) {
        let r = GameConfig.Erasure.effectRadius
        for e in enemies where e.position.distance(to: pos) < r {
            let dir = (pos - e.position).normalized
            e.position += dir * GameConfig.Erasure.implosionPull
        }
        showRingPulse(at: pos, radius: r, colorHex: 0x9B59B6)
    }

    /// 2. Rift Burst — Void damage in a small radius.
    private func erasureRiftBurst(at pos: CGPoint) {
        let dmg = max(1, Int(playerStats.effectiveAttack * GameConfig.Erasure.riftBurstMult))
        damageEnemiesInRadius(GameConfig.Erasure.effectRadius, around: pos,
                              damage: dmg, bossClassScaled: true)
        showRingPulse(at: pos, radius: GameConfig.Erasure.effectRadius, colorHex: 0x8E44AD)
    }

    /// 3. Phase Lock — immobilize normals, slow boss-class, in a radius.
    private func erasurePhaseLock(at pos: CGPoint) {
        let r = GameConfig.Erasure.effectRadius
        for e in enemies where e.position.distance(to: pos) < r {
            if e.isMiniBoss {
                e.applySlow(GameConfig.BossClass.scaledMagnitude(GameConfig.Erasure.phaseLockBossSlow, isBossClass: true),
                            duration: GameConfig.Erasure.phaseLockDuration)
            } else {
                e.applyStun(GameConfig.Erasure.phaseLockDuration)
            }
        }
        showRingPulse(at: pos, radius: r, colorHex: 0x6C3483)
    }

    /// 4. Damage Echo — a delayed Void detonation on the target (ATK-scaled).
    private func erasureDamageEcho(on enemy: EnemyNode) {
        let dmg = max(1, Int(playerStats.effectiveAttack * GameConfig.Erasure.damageEchoFraction))
        run(SKAction.sequence([
            SKAction.wait(forDuration: GameConfig.Erasure.damageEchoDelay),
            SKAction.run { [weak self, weak enemy] in
                guard let self = self, let enemy = enemy, !enemy.isDying,
                      self.enemies.contains(where: { $0 === enemy }) else { return }
                self.showRingPulse(at: enemy.position, radius: 28, colorHex: 0x8E44AD)
                if enemy.takeDamage(GameConfig.BossClass.scaledDamage(dmg, isBossClass: enemy.isMiniBoss)) {
                    if let i = self.enemies.firstIndex(where: { $0 === enemy }) { self.enemies.remove(at: i) }
                    self.onEnemyKilled(at: enemy.position, xpValue: enemy.xpValue, enemy: enemy)
                }
            }
        ]))
    }

    /// 5. Displacement — shove the target a random short distance.
    private func erasureDisplacement(_ enemy: EnemyNode) {
        let ang = CGFloat.random(in: 0..<(2 * .pi))
        enemy.position += CGPoint(x: cos(ang), y: sin(ang)) * GameConfig.Erasure.displacementDistance
        showRingPulse(at: enemy.position, radius: 24, colorHex: 0x9B59B6)
    }

    /// 6. Fracture — the target briefly takes more damage (timed vulnerability).
    private func erasureFracture(_ enemy: EnemyNode) {
        enemy.vulnerabilityMultiplier = GameConfig.BossClass.scaledDebuff(
            GameConfig.Erasure.fractureVulnerability, isBossClass: enemy.isMiniBoss)
        enemy.run(SKAction.sequence([
            SKAction.wait(forDuration: GameConfig.Erasure.fractureDuration),
            SKAction.run { [weak enemy] in enemy?.vulnerabilityMultiplier = 1.0 }
        ]), withKey: "erasureFracture")
        showRingPulse(at: enemy.position, radius: 26, colorHex: 0xC39BD3)
    }

    /// 7. Backwash — a Void-shard burst radiates from the target (reuses the
    /// player projectile system, at reduced damage, no further modifiers).
    private func erasureBackwash(at pos: CGPoint) {
        let n = GameConfig.Erasure.backwashCount
        let offset = pos - player.position
        for i in 0..<n {
            let ang = CGFloat(i) / CGFloat(n) * 2 * .pi
            fireProjectile(direction: CGPoint(x: cos(ang), y: sin(ang)),
                           originOffset: offset,
                           damageScale: GameConfig.Erasure.backwashMult,
                           allowModifiers: false)
        }
    }

    /// The Void implosion pop at an Unstable trigger.
    private func showUnstablePop(at pos: CGPoint) {
        showRingPulse(at: pos, radius: 42, colorHex: 0x9B59B6)
        let core = SKShapeNode(circleOfRadius: 8)
        core.fillColor = SKColor(hex: 0x6C3483, alpha: 0.8)
        core.strokeColor = SKColor(hex: 0xC39BD3, alpha: 0.9)
        core.glowWidth = 8
        core.position = pos
        core.zPosition = 8
        worldNode.addChild(core)
        core.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 2.4, duration: 0.18), SKAction.fadeOut(withDuration: 0.2)]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Polar Vortex (Chill capstone)

    /// T4: fire one condensed icicle (200% ATK) that shatters into shards on impact.
    private func fireIcicle(direction: CGPoint, originOffset: CGPoint) {
        let icicle = ProjectileNode(
            direction: direction,
            speed: playerStats.effectiveProjectileSpeed,
            range: playerStats.effectiveProjectileRange,
            pierces: 0,
            damageMultiplier: playerStats.effectiveDamageMultiplier * GameConfig.PolarVortex.icicleMult,
            isCrit: false,
            spawnsGravityWell: false,
            voidStyle: false,
            isIcicle: true
        )
        icicle.position = player.position + originOffset
        icicle.zPosition = 8
        projectiles.append(icicle)
        worldNode.addChild(icicle)
    }

    /// T1: a burst of ice shards from a chilled foe's death (reuses the projectile
    /// system at reduced damage, no further modifiers).
    private func iceburst(at pos: CGPoint) {
        let n = playerStats.iceburstShards
        let offset = pos - player.position
        for i in 0..<n {
            let ang = CGFloat(i) / CGFloat(n) * 2 * .pi + CGFloat.random(in: -0.3...0.3)
            fireProjectile(direction: CGPoint(x: cos(ang), y: sin(ang)),
                           originOffset: offset,
                           damageScale: GameConfig.PolarVortex.shardMult,
                           allowModifiers: false)
        }
        showRingPulse(at: pos, radius: 28, colorHex: 0x99E6FF)
    }

    /// T4: an icicle shatters on impact into shards (double a normal shard).
    private func iceShatter(at pos: CGPoint) {
        let n = GameConfig.PolarVortex.icicleShards
        let offset = pos - player.position
        for i in 0..<n {
            let ang = CGFloat(i) / CGFloat(n) * 2 * .pi
            fireProjectile(direction: CGPoint(x: cos(ang), y: sin(ang)),
                           originOffset: offset,
                           damageScale: GameConfig.PolarVortex.icicleShardMult,
                           allowModifiers: false)
        }
        showRingPulse(at: pos, radius: 34, colorHex: 0xCCF2FF)
    }

    /// T3/T5: the cold storm follows the player, stacking Chill each interval; at
    /// T5, foes at the freeze threshold freeze, then become Frostbitten.
    private func updateWindchill(_ dt: TimeInterval) {
        let r = playerStats.windchillRadius
        if windchillStorm == nil {
            let storm = SKShapeNode()
            storm.strokeColor = SKColor(hex: 0x99E6FF, alpha: 0.35)
            storm.fillColor = SKColor(hex: 0x66CCFF, alpha: 0.06)
            storm.lineWidth = 2
            storm.zPosition = 3
            worldNode.addChild(storm)
            windchillStorm = storm
        }
        windchillStorm?.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
        windchillStorm?.position = player.position

        // Wispy arctic air swirling inside the vortex.
        windchillWispTimer += dt
        if windchillWispTimer >= 0.11 {
            windchillWispTimer = 0
            spawnFrostWisp(radius: r)
        }

        // T5: Spark dons the seasonal aesthetic. 🎅
        player.setPolarVortexFeatures(playerStats.polarVortexFreeze)

        windchillTimer += dt
        if windchillTimer >= GameConfig.PolarVortex.windchillInterval {
            windchillTimer -= GameConfig.PolarVortex.windchillInterval
            for e in enemies where !e.isDying && player.position.distance(to: e.position) < r {
                e.chillStacks += 1
                if playerStats.polarVortexFreeze
                    && e.chillStacks >= GameConfig.PolarVortex.freezeStacks && !e.isFrozen {
                    freezeEnemy(e)
                }
            }
        }
    }

    /// A drifting frost wisp inside the storm — arctic air swirling on the wind.
    private func spawnFrostWisp(radius r: CGFloat) {
        let ang = CGFloat.random(in: 0..<(2 * .pi))
        let dist = CGFloat.random(in: 0...r)
        let wisp = SKShapeNode(ellipseOf: CGSize(width: CGFloat.random(in: 10...20) * DeviceScale.gameplay,
                                                 height: 2.5 * DeviceScale.gameplay))
        wisp.fillColor = SKColor(hex: 0xCCF2FF, alpha: 0.5)
        wisp.strokeColor = .clear
        wisp.position = player.position + CGPoint(x: cos(ang) * dist, y: sin(ang) * dist)
        wisp.zRotation = ang + .pi / 2   // aligned tangentially — reads as swirl
        wisp.zPosition = 4
        wisp.alpha = 0
        worldNode.addChild(wisp)
        let tangent = CGPoint(x: -sin(ang), y: cos(ang)) * CGFloat.random(in: 28...52)
        wisp.run(SKAction.sequence([
            SKAction.group([
                SKAction.sequence([SKAction.fadeAlpha(to: 0.5, duration: 0.3),
                                   SKAction.fadeOut(withDuration: 0.7)]),
                SKAction.move(by: CGVector(dx: tangent.x, dy: tangent.y), duration: 1.0)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    /// T5: freeze a foe (boss-class → heavy slow instead), then Frostbite it —
    /// +100% damage taken (boss-class reduced), reusing the vulnerability primitive.
    private func freezeEnemy(_ e: EnemyNode) {
        let bossClass = e.isMiniBoss
        let freezeDur = bossClass
            ? GameConfig.PolarVortex.freezeDuration * TimeInterval(GameConfig.BossClass.debuffScale)
            : GameConfig.PolarVortex.freezeDuration
        if bossClass {
            e.applySlow(0.85, duration: freezeDur)   // boss-class: heavy slow, not a full lock
        } else {
            e.applyFreeze(freezeDur)
        }
        e.chillStacks = 0
        showRingPulse(at: e.position, radius: 30, colorHex: 0x99E6FF)

        let vuln = GameConfig.BossClass.scaledDebuff(GameConfig.PolarVortex.frostbiteVuln, isBossClass: bossClass)
        e.run(SKAction.sequence([
            SKAction.wait(forDuration: freezeDur),
            SKAction.run { [weak e] in e?.vulnerabilityMultiplier = vuln },
            SKAction.wait(forDuration: GameConfig.PolarVortex.frostbiteDuration),
            SKAction.run { [weak e] in e?.vulnerabilityMultiplier = 1.0 }
        ]), withKey: "frostbite")
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
                    // v1.8 Event Horizon (Void 5): enemies inside struggle to escape
                    if playerStats.inWellSlow > 0 {
                        enemy.applySlow(playerStats.effectiveSlow(playerStats.inWellSlow), duration: 0.5)
                    }
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
    /// `bossClassScaled` halves damage on miniboss targets via the BossClass canon
    /// — set it for capstone AoEs (Everglow pulse, Iron Maiden burst), leave it
    /// off for non-capstone pulses (Aegis, Static Crown, etc.).
    private func damageEnemiesInRadius(_ radius: CGFloat, around position: CGPoint,
                                       damage: Int, bossClassScaled: Bool = false) {
        var killed: [EnemyNode] = []
        for enemy in enemies where enemy.position.distance(to: position) < radius {
            let dmg = bossClassScaled
                ? GameConfig.BossClass.scaledDamage(damage, isBossClass: enemy.isMiniBoss)
                : damage
            if enemy.takeDamage(dmg) {
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

    /// v1.8: a loud, unmistakable "it split!" telegraph at an Ashling's death —
    /// a bright core flash plus a bold double shockwave in shard-yellow, so
    /// players read the split and don't path into the incoming shards. Louder
    /// than showRingPulse on purpose (the thin single ring wasn't landing).
    private func showAshlingSplitTelegraph(at position: CGPoint) {
        let color = GameConfig.Ashling.splitTelegraphColorHex
        let r = GameConfig.Ashling.splitTelegraphRadius

        // Bright filled core flash — grabs the eye the instant the parent dies.
        let flash = SKShapeNode(circleOfRadius: r * 0.5)
        flash.fillColor = SKColor(hex: color, alpha: 0.9)
        flash.strokeColor = .clear
        flash.glowWidth = 6
        flash.position = position
        flash.zPosition = 7
        worldNode.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.8, duration: 0.18),
                SKAction.fadeOut(withDuration: 0.22)
            ]),
            SKAction.removeFromParent()
        ]))

        // Bold expanding shockwave — two staggered rings, thicker + brighter
        // + glowing vs the plain pulse.
        for delay in [0.0, 0.08] {
            let ring = SKShapeNode(circleOfRadius: 1)
            ring.strokeColor = SKColor(hex: color, alpha: 0.95)
            ring.fillColor = .clear
            ring.lineWidth = 3
            ring.glowWidth = 3
            ring.position = position
            ring.zPosition = 7
            ring.alpha = 0
            worldNode.addChild(ring)
            ring.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.fadeIn(withDuration: 0.02),
                SKAction.group([
                    SKAction.scale(to: r * 1.6, duration: 0.3),
                    SKAction.fadeOut(withDuration: 0.32)
                ]),
                SKAction.removeFromParent()
            ]))
        }
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

    // MARK: - v1.8 Unit 14: False Opening (Void card)

    /// A hard direction-change while moving — a dodge — drops a short-delayed
    /// Void pulse at the pivot. A lagging reference heading distinguishes a
    /// sharp cut (wide gap) from a gradual arc (stays close). One-shot, not a
    /// lingering field; a cooldown keeps it from carpeting the floor.
    private func updateFalseOpening(_ dt: TimeInterval) {
        guard playerStats.falseOpeningActive else { return }
        if falseOpeningCooldownTimer > 0 { falseOpeningCooldownTimer -= dt }

        let dir = joystick.direction
        guard dir.length > 0.3 else { return }
        let norm = dir.normalized

        let dot = max(-1, min(1, norm.x * falseOpeningRefDir.x + norm.y * falseOpeningRefDir.y))
        let angleDelta = acos(dot)

        // The reference lags the live heading, so a sharp reversal opens a gap.
        let blended = falseOpeningRefDir + (norm - falseOpeningRefDir) * min(1.0, CGFloat(dt) * 5.0)
        if blended.length > 0.01 { falseOpeningRefDir = blended.normalized }

        if angleDelta > (CGFloat.pi * 0.5) && falseOpeningCooldownTimer <= 0 {
            falseOpeningCooldownTimer = playerStats.falseOpeningCooldown
            spawnFalseOpeningPulse(at: player.position)
        }
    }

    private func spawnFalseOpeningPulse(at position: CGPoint) {
        // A faint purple mark blooms into the pulse after the delay — readable,
        // and the delay is what makes it a trap you lay behind you.
        let tell = SKShapeNode(circleOfRadius: playerStats.falseOpeningRadius * 0.5)
        tell.strokeColor = SKColor(hex: 0x8E44FF, alpha: 0.5)
        tell.fillColor = SKColor(hex: 0x8E44FF, alpha: 0.08)
        tell.lineWidth = 1.5
        tell.position = position
        tell.zPosition = 4
        worldNode.addChild(tell)
        tell.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: playerStats.falseOpeningDelay),
            SKAction.removeFromParent()
        ]))

        run(SKAction.sequence([
            SKAction.wait(forDuration: playerStats.falseOpeningDelay),
            SKAction.run { [weak self] in
                guard let self = self, self.gameState == .playing else { return }
                let r = self.playerStats.falseOpeningRadius
                self.showRingPulse(at: position, radius: r, colorHex: 0x8E44FF)
                self.damageEnemiesInRadius(r, around: position, damage: self.playerStats.falseOpeningDamage)
                for enemy in self.enemies where enemy.position.distance(to: position) < r {
                    enemy.applySlow(self.playerStats.falseOpeningSlow,
                                    duration: self.playerStats.falseOpeningSlowDuration)
                }
            }
        ]))
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
        // v1.8: and The Mirrorwound
        if arenaConfig.id == 3 {
            spawnMirrorwoundEnemy()
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

    // MARK: - v1.8: Mirrorwound Spawning (Unit 12)

    /// Arena 4 spawn table — Lyra's curriculum: perception pressure in layers,
    /// never every enemy a trick. The first 20s teach the Shard Twin's
    /// false/real read alongside familiar bodies; the Pane Stalker's phase
    /// shift joins at 45s; the Echo Leech (elite) arrives at 80s. Ranged and
    /// basic melee keep the floor honest. The larger arena + 120s bell give
    /// this vocabulary room to breathe.
    private func spawnMirrorwoundEnemy() {
        let elapsed = waveManager.elapsedTime
        let roll = CGFloat.random(in: 0...1)

        // Opening: the Shard Twin teaches "check the face" beside known shapes.
        if elapsed < 20 {
            if roll < 0.5 {
                spawnShardTwin(elapsed: elapsed)
            } else {
                spawnBasicMelee(elapsed: elapsed)
            }
            return
        }

        if elapsed >= 80 && roll < 0.14 {
            spawnEchoLeech(elapsed: elapsed)
        } else if elapsed >= 45 && roll < 0.34 {
            spawnPaneStalker(elapsed: elapsed)
        } else if roll < 0.58 {
            spawnShardTwin(elapsed: elapsed)
        } else if elapsed >= 55 && roll < 0.72 {
            spawnRangedEnemy()
        } else {
            spawnBasicMelee(elapsed: elapsed)
        }
    }

    private func spawnShardTwin(elapsed: TimeInterval) {
        let twin = ShardTwinNode(elapsed: elapsed)
        twin.position = EnemyNode.spawnPosition()
        enemies.append(twin)
        worldNode.addChild(twin)
    }

    private func spawnPaneStalker(elapsed: TimeInterval) {
        let stalker = PaneStalkerNode(elapsed: elapsed)
        stalker.position = EnemyNode.spawnPosition()
        enemies.append(stalker)
        worldNode.addChild(stalker)
    }

    private func spawnEchoLeech(elapsed: TimeInterval) {
        let leech = EchoLeechNode(elapsed: elapsed)
        leech.position = EnemyNode.spawnPosition()
        leech.onEchoShot = { [weak self] position, direction in
            self?.spawnMirrorProjectile(at: position, direction: direction)
        }
        enemies.append(leech)
        worldNode.addChild(leech)
    }

    /// A mirror-purple enemy bullet — the Echo Leech's reflected shot and the
    /// Faceted Lie's Reflection Volley both fire through this. The boss passes a
    /// faster speed; the Leech uses the default.
    private func spawnMirrorProjectile(at position: CGPoint, direction: CGPoint,
                                       speed: CGFloat = GameConfig.RangedEnemy.projectileSpeed) {
        let elapsed = waveManager.elapsedTime
        let scalingTicks = Int(elapsed / 30)
        let damage = GameConfig.Enemy.baseRangedDamage + (scalingTicks * GameConfig.Enemy.rangedDamageScaling)
        let proj = EnemyProjectileNode(direction: direction,
                                       damage: damage,
                                       speed: speed,
                                       colorHex: GameConfig.MirrorwoundEnemies.hostilePurpleHex)
        proj.position = position
        proj.zPosition = 7
        enemyProjectiles.append(proj)
        worldNode.addChild(proj)
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
            CodexManager.shared.recordDefeat(.slagTitan)  // v1.8 Unit 5
            // Spawn massive XP shower
            for _ in 0..<10 {
                let offset = CGPoint(
                    x: CGFloat.random(in: -40...40),
                    y: CGFloat.random(in: -40...40)
                )
                self.spawnXPOrb(at: pos + offset, value: xp / 10)
            }
            // v1.8 (Unit 2): forge XP coins erupt and scatter arena-wide, on
            // top of the XP shower — bonus forge XP for pushing the post-boss swarm.
            self.spawnForgeCoins(at: pos)
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
            CodexManager.shared.recordDefeat(.quenchWarden)  // v1.8 Unit 5
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
            // v1.8 (Unit 2): forge XP coins erupt and scatter arena-wide, on
            // top of the XP shower — bonus forge XP for pushing the post-boss swarm.
            self.spawnForgeCoins(at: pos)
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
            CodexManager.shared.recordDefeat(.dynamoChoir)  // v1.8 Unit 5
            ProgressionManager.shared.choirKills += 1  // banked for Arena 4's gate
            // v1.8 (Unit 11): felling the Choir opens The Mirrorwound
            if ProgressionManager.shared.arenasUnlocked < 4 {
                ProgressionManager.shared.arenasUnlocked = 4
            }
            for _ in 0..<10 {
                let offset = CGPoint(
                    x: CGFloat.random(in: -40...40),
                    y: CGFloat.random(in: -40...40)
                )
                self.spawnXPOrb(at: pos + offset, value: xp / 10)
            }
            // v1.8 (Unit 2): forge XP coins erupt and scatter arena-wide, on
            // top of the XP shower — bonus forge XP for pushing the post-boss swarm.
            self.spawnForgeCoins(at: pos)
            self.boss = nil
            self.worldNode.shake(intensity: 15, duration: 0.5)
        }

        boss = choir
        worldNode.addChild(choir)

        showBossEntrance(name: "THE DYNAMO CHOIR", colorHex: 0xF6D36B)
    }

    // MARK: - v1.8: The Faceted Lie (Arena 4 boss, Unit 13)

    private func spawnFacetedLie() {
        let elapsed = waveManager.elapsedTime
        let hpScaling = Int(elapsed / 30) * 5

        let lie = FacetedLieNode(hpScaling: hpScaling)
        lie.position = FacetedLieNode.spawnPosition()
        lie.zPosition = 6

        // Reflection Volley — mirrored purple shots ride the projectile pipeline
        lie.onFireProjectile = { [weak self] position, direction, speed in
            self?.spawnMirrorProjectile(at: position, direction: direction, speed: speed)
        }

        // False Safe (purple shards) + Pane Shift (re-entry burst) hazards.
        // Silver shards never call this — the node only fires it for real danger.
        lie.onHazardDamage = { [weak self] damage in
            self?.applyBossHazardDamage(damage, shakeIntensity: 6)
        }

        lie.onDeath = { [weak self] pos, xp in
            guard let self = self else { return }
            self.bossDefeatedThisRun = true
            ProgressionManager.shared.recordKill(.boss)
            CodexManager.shared.recordDefeat(.facetedLie)
            for _ in 0..<10 {
                let offset = CGPoint(
                    x: CGFloat.random(in: -40...40),
                    y: CGFloat.random(in: -40...40)
                )
                self.spawnXPOrb(at: pos + offset, value: xp / 10)
            }
            self.spawnForgeCoins(at: pos)
            self.boss = nil
            self.worldNode.shake(intensity: 15, duration: 0.5)
        }

        boss = lie
        worldNode.addChild(lie)

        showBossEntrance(name: "THE FACETED LIE", colorHex: 0x8E44FF)
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
        if consumeSilverSkin() { return }

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
        // v1.8 fix: vacuum every XP orb toward the player's LIVE position —
        // updateXPOrbs homes them each frame, so they track a moving player
        // instead of flying to a stale snapshot of player.position. The old
        // one-shot SKAction.move missed the player if they moved and read as
        // a bug (Brandon 7/13).
        for xpOrb in xpOrbs {
            xpOrb.startVacuum()
        }
    }

    // MARK: - v1.8 Unit 2: Forge XP Coins

    /// A boss's death erupts forge XP coins that scatter arena-wide (on top of
    /// the XP shower). Tossed outward from the corpse to random arena spots,
    /// then collected by walking over them — no magnet.
    private func spawnForgeCoins(at bossPos: CGPoint) {
        for _ in 0..<GameConfig.ForgeCoin.scatterCount {
            let coin = ForgeCoinNode()
            coin.position = bossPos
            coin.zPosition = 4
            forgeCoins.append(coin)
            worldNode.addChild(coin)

            let toss = SKAction.move(to: ForgeCoinNode.randomArenaPosition(),
                                     duration: TimeInterval.random(in: 0.35...0.6))
            toss.timingMode = .easeOut
            coin.run(toss)
        }
    }

    private func handleForgeCoinCollection(coinBody: SKPhysicsBody) {
        guard let coin = coinBody.node as? ForgeCoinNode else { return }
        guard let idx = forgeCoins.firstIndex(where: { $0 === coin }) else { return }
        forgeCoins.remove(at: idx)
        let pos = coin.position
        coin.collect()
        AudioManager.shared.play(.orbPickup)  // TODO(v1.8 polish): distinct metallic spark tick (Lyra)
        // FLAT forge XP — intentionally NOT via pendingForgeXP (the XP Boost ad
        // doubles that pool); coins bank immediately and are never boosted.
        ProgressionManager.shared.addForgeXP(coin.forgeXPValue)
        // Small ember burst — ember-orange, never green/blue.
        showRingPulse(at: pos, radius: GameConfig.ForgeCoin.pickupBurstRadius,
                      colorHex: GameConfig.ForgeCoin.rimColorHex)
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

        // v1.9 Polar Vortex Iceburst (T1): a chilled foe's death bursts into shards.
        if playerStats.iceburstActive, let e = enemy, e.isFrozen || e.isSlowed {
            iceburst(at: position)
        }

        // v1.9 Apex Bloodfed (T2): every N kills, grow max HP (capped) + heal.
        if playerStats.apexTier >= 2 {
            apexBloodfedKills += 1
            if apexBloodfedKills >= GameConfig.Apex.bloodfedKills {
                apexBloodfedKills = 0
                if playerStats.apexBloodfedBonusHP < GameConfig.Apex.bloodfedMaxHPCap {
                    playerStats.apexBloodfedBonusHP += GameConfig.Apex.bloodfedHP
                    playerStats.maxHP += GameConfig.Apex.bloodfedHP
                    playerStats.heal(GameConfig.Apex.bloodfedHP)
                    hpBar.updateFill(playerStats.hpPercent,
                                     currentHP: playerStats.currentHP, maxHP: playerStats.maxHP)
                    statHUD.update(from: playerStats)
                }
            }
        }

        // v1.6: kills made in The Quench feed the Warden's gate
        if arenaConfig.id == 1 {
            ProgressionManager.shared.quenchKills += 1
        }
        // v1.7: kills made in The Coilworks feed the Choir's gate
        if arenaConfig.id == 2 {
            ProgressionManager.shared.coilworksKills += 1
        }
        // v1.8: kills made in The Mirrorwound feed the Faceted Lie's gate
        if arenaConfig.id == 3 {
            ProgressionManager.shared.mirrorwoundKills += 1
        }
        
        // v1.4: Track kill type for progression
        if let enemy = enemy {
            if enemy is RangedEnemyNode {
                ProgressionManager.shared.recordKill(.ranged)
            } else {
                ProgressionManager.shared.recordKill(.melee)
            }
            // v1.8 Unit 5: lifetime bestiary — defeat marks the family
            // encountered and increments its kill count. (Bosses are recorded
            // at their own death handlers.)
            CodexManager.shared.recordDefeat(bestiaryFamily(for: enemy))
        } else {
            ProgressionManager.shared.recordKill(.melee)
        }
        
        run(SKAction.wait(forDuration: 0.05)) { [weak self] in
            self?.spawnXPOrb(at: position, value: xpValue)
        }
        
        _ = playerStats.recordKill(atTime: waveManager.elapsedTime)
        playerStats.recordBloodlustKill(atTime: waveManager.elapsedTime)

        // v1.6: Ashlings split into two shards on death.
        // v1.8 (B2): the parent's death-AoE (the Open Vein / Whiteout bursts
        // below, plus any splash that landed this frame) was insta-killing the
        // shards the instant they spawned. Telegraph the split, then let the
        // shards gain physics a beat later — the pause IS the protection; they
        // pop up vulnerable only once visible.
        if let ashling = enemy as? AshlingNode, !ashling.isShard {
            showAshlingSplitTelegraph(at: position)
            run(SKAction.wait(forDuration: GameConfig.Ashling.shardSpawnDelay)) { [weak self] in
                self?.spawnAshlingShards(at: position)
            }
        }

        // v1.6: Siphon — kills restore HP
        if playerStats.killHealAmount > 0 {
            playerStats.heal(playerStats.killHealAmount)
        }

        // v1.8 Red Harvest (Bleed 7) — killing a BLEEDING enemy restores HP
        if playerStats.bleedKillHeal > 0, let enemy = enemy, enemy.isBleeding {
            playerStats.heal(playerStats.bleedKillHeal)
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

    /// v1.8 Unit 5: map a live enemy node onto its bestiary family. Mirrors the
    /// type ladder the rest of GameScene uses (isMiniBoss, then subclass).
    /// Arena bosses aren't in the `enemies` array — they record at their own
    /// death handlers — so they don't appear here.
    private func bestiaryFamily(for enemy: EnemyNode) -> BestiaryFamily {
        if enemy.isMiniBoss { return .miniBoss }
        switch enemy {
        case is AshlingNode:     return .ashling
        case is RangedEnemyNode: return .ranged
        case is BraceguardNode:  return .braceguard
        case is RelayImpNode:    return .relayImp
        case is GrounderNode:    return .grounder
        case is StaticHaloNode:  return .staticHalo
        case is CircuitWaspNode: return .circuitWasp
        case is ShardTwinNode:   return .shardTwin
        case is PaneStalkerNode: return .paneStalker
        case is EchoLeechNode:   return .echoLeech
        default:                 return .melee
        }
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
        statHUD.update(from: playerStats)  // v1.9 Unit 5: live combat modifiers

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

        // v1.8 Unit 2: Player ↔ Forge XP Coin
        if (masks == (GameConfig.Physics.player, GameConfig.Physics.forgeCoin)) ||
           (masks == (GameConfig.Physics.forgeCoin, GameConfig.Physics.player)) {
            let coinBody = bodyA.categoryBitMask == GameConfig.Physics.forgeCoin ? bodyA : bodyB
            handleForgeCoinCollection(coinBody: coinBody)
            return
        }
    }
    
    // MARK: - Player ↔ Enemy
    
    /// v1.8 Unit 14: Silver Skin (Guard/Void) — if a level-up armed a block,
    /// spend it here to fully negate this hit (silver flash + brief i-frames).
    /// Consumed at all three player-damage entry points.
    private func consumeSilverSkin() -> Bool {
        guard playerStats.silverSkinArmed else { return false }
        playerStats.silverSkinArmed = false
        invulnerableTimer = 0.3
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.08),
            SKAction.fadeAlpha(to: 1.0, duration: 0.08)
        ])
        player.run(SKAction.repeat(blink, count: 3), withKey: "invulnBlink")
        showRingPulse(at: player.position, radius: 42, colorHex: 0xD6CCC2)
        worldNode.shake(intensity: 3, duration: 0.12)
        return true
    }

    private func handlePlayerEnemyContact(enemyBody: SKPhysicsBody) {
        guard gameState == .playing else { return }
        guard !isInvulnerable else { return }
        guard damageCooldownTimer <= 0 else { return }
        if consumeSilverSkin() { return }

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

        // v1.8 Thornwall (Guard 5): reflect a fraction of the contact damage
        // back to whatever touched you (mirrors the Iron Bloom thorns pattern).
        if playerStats.thornsContactReflect > 0 {
            let reflect = max(1, Int(CGFloat(damage) * playerStats.thornsContactReflect))
            dealRetaliationDamage(reflect, to: enemyBody)
        }

        // v1.9 Iron Maiden (Guard capstone): incoming force → stored punishment.
        if playerStats.ironMaidenTier >= 1 {
            // Thorns — flat bite to the toucher (T1+).
            dealRetaliationDamage(playerStats.ironThorns, to: enemyBody)
            // Retaliate — counter for a fraction of pre-mitigation damage (T3+),
            // on a global (not per-enemy) cooldown.
            if playerStats.ironRetaliate > 0 && ironRetaliateCooldown <= 0 {
                dealRetaliationDamage(Int(CGFloat(damage) * playerStats.ironRetaliate), to: enemyBody)
                ironRetaliateCooldown = GameConfig.IronMaiden.retaliateCooldown
            }
            // Kinetic — build a stack; release the radial burst at threshold (T4+).
            if playerStats.addKineticStack() {
                fireKineticBurst()
                kineticGauge.flashRelease()
            } else {
                kineticGauge.setFilled(playerStats.ironKineticStacks)
            }
        }

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
        if consumeSilverSkin() { return }

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

        // v1.9 Iron Maiden: a ranged hit is still a damaging hit — build a stack.
        // (Thorns/Retaliate are contact-only; the source enemy may be gone here.)
        if playerStats.addKineticStack() {
            fireKineticBurst()
            kineticGauge.flashRelease()
        } else {
            kineticGauge.setFilled(playerStats.ironKineticStacks)
        }

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

        // v1.9 Polar Vortex Brittle Cold (T2): +40% vs chilled/frozen/stunned foes.
        if playerStats.brittleCold && (enemyNode.isSlowed || enemyNode.isFrozen || enemyNode.isStunned) {
            damage = Int(CGFloat(damage) * GameConfig.PolarVortex.brittleColdVuln)
        }

        // v1.8 Open Wounds (Bleed 3): bleeding enemies take more damage
        if playerStats.bleedingEnemyDamageTaken > 0 && enemyNode.isBleeding {
            damage = Int(CGFloat(damage) * (1.0 + playerStats.bleedingEnemyDamageTaken))
        }

        if playerStats.isBloodlustActive(atTime: waveManager.elapsedTime) {
            damage = Int(CGFloat(damage) * (1.0 + playerStats.bloodlustBonus))
        }

        // v1.6: shield reduction applies after all bonuses — flanking doubles output.
        // v1.9 Erasure Void-Touched (T2): shots pierce the shield entirely.
        if braceguardShielded && !playerStats.erasureVoidTouched {
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
        apexRegisterAttack()   // T5 Apex: every player hit charges the pounce gauge

        erasureRegisterHit()   // T1 Erasure: every player hit charges the Unstable meter

        // v1.9 Polar Vortex (T4): the icicle shatters into shards on first impact.
        if projectileNode.isIcicle { iceShatter(at: enemyNode.position) }

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
        erasureRegisterHit()   // T1 Erasure: hits on the boss charge the meter too
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
        line.strokeColor = SKColor(hex: GameConfig.ChainLightning.colorHex,
                                   alpha: GameConfig.ChainLightning.alpha)
        line.lineWidth = GameConfig.ChainLightning.lineWidth
        line.glowWidth = GameConfig.ChainLightning.glowWidth
        line.zPosition = 8
        worldNode.addChild(line)
        line.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: GameConfig.ChainLightning.fadeDuration),
            SKAction.removeFromParent()
        ]))
        
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
    
    /// y of the stat card row within the level-up overlay (above the skill
    /// cards). Card-sized rows crowd the screen — accepted (Brandon).
    private let statRowY: CGFloat = 92

    private func triggerLevelUp() {
        AudioManager.shared.play(.levelUp)
        playerStats.triggerOverclock()  // v1.7: level-ups grant speed briefly
        xpBar.flashLevelUp()
        levelLabel.text = "LV \(player.currentLevel)"

        // v1.9 Unit 4b: ONE combined level-up screen. EVEN levels show a stat
        // picker alongside the cards (pick either order, auto-commit once both
        // are chosen); ODD levels auto-award a random stat (shown as a badge)
        // and just pick a card.
        levelStatPick = nil
        pendingLevelCard = nil
        levelNeedsStat = (player.currentLevel % 2 == 0)

        var awarded: PlayerStats.StatKind? = nil
        if !levelNeedsStat {
            let stat = PlayerStats.StatKind.allCases.randomElement() ?? .hp
            playerStats.applyStatBonus(stat)
            statHUD.update(from: playerStats)
            awarded = stat
        }

        gameState = .levelUp
        if let label = levelUpOverlay.childNode(withName: "levelUpLabel") as? SKLabelNode {
            label.text = "LEVEL \(player.currentLevel)"
        }
        presentStatRow(needsPick: levelNeedsStat, awarded: awarded)
        showCardSelection(upgradeManager.drawCards(count: 3, level: player.currentLevel))
        refreshLevelUpButtons()

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

    private func refreshLevelUpButtons() {
        if let rerollBtn = levelUpOverlay.childNode(withName: "rerollButton") {
            rerollBtn.alpha = rerollUsedThisRun ? 0.0 : 1.0
        }
        if let extraBtn = levelUpOverlay.childNode(withName: "extraCardButton") {
            extraBtn.alpha = extraCardUsedThisRun ? 0.0 : 1.0
        }
        if let pickBtn = levelUpOverlay.childNode(withName: "extraPickButton") {
            pickBtn.alpha = extraPickUsedThisRun ? 0.0 : 1.0
            if !extraPickUsedThisRun {
                if let label = pickBtn.childNode(withName: "extraPickLabel") as? SKLabelNode {
                    label.text = "★ +1 PICK"
                    label.fontColor = SKColor(hex: 0xEEDDAA)
                }
                if let adIcon = pickBtn.childNode(withName: "extraPickAdIcon") as? SKLabelNode {
                    adIcon.alpha = 1.0
                }
            }
        }
    }

    /// v1.9 Unit 4b: build the stat row atop the cards — three selectable chips
    /// (even) or a single awarded badge (odd). Chips are named "statChip_<key>".
    private func presentStatRow(needsPick: Bool, awarded: PlayerStats.StatKind?) {
        levelUpOverlay.childNode(withName: "statRow")?.removeFromParent()
        let row = SKNode()
        row.name = "statRow"
        row.position = CGPoint(x: 0, y: statRowY)
        levelUpOverlay.addChild(row)

        if needsPick {
            let title = SKLabelNode(fontNamed: "Menlo-Bold")
            title.text = "CHOOSE A STAT"
            title.fontSize = 12
            title.fontColor = SKColor(hex: 0xCCCCCC)
            title.verticalAlignmentMode = .center
            title.position = CGPoint(x: 0, y: 72)
            row.addChild(title)

            let kinds = PlayerStats.StatKind.allCases
            let spacing: CGFloat = 108
            let startX = -spacing * CGFloat(kinds.count - 1) / 2
            for (i, kind) in kinds.enumerated() {
                let chip = Self.statCard(for: kind)
                chip.position = CGPoint(x: startX + spacing * CGFloat(i), y: 0)
                chip.name = "statChip_\(kind.rawValue)"
                row.addChild(chip)
            }
        } else if let awarded = awarded {
            let badge = SKLabelNode(fontNamed: "Menlo-Bold")
            badge.text = "\(awarded.emoji)  +\(awarded.bonus) \(awarded.label) awarded"
            badge.fontSize = 13
            badge.fontColor = UpgradeCardNode.brightColor(hex: awarded.colorHex)
            badge.verticalAlignmentMode = .center
            badge.position = .zero
            row.addChild(badge)
        }
    }

    /// A stat card that mirrors the skill-card language (dark plate, tinted
    /// wash + stroke, emoji, value, label) so both selections read as the same
    /// kind of button — just a different result. Named plate = "chipPlate".
    static let statCardSize = CGSize(width: 96, height: 116)
    private static func statCard(for kind: PlayerStats.StatKind) -> SKNode {
        let node = SKNode()
        let tag = SKColor(hex: kind.colorHex)
        let h = statCardSize.height

        let plate = SKShapeNode(rectOf: statCardSize, cornerRadius: 8)
        plate.fillColor = SKColor(hex: 0x161616)
        plate.strokeColor = .clear
        node.addChild(plate)

        let wash = SKShapeNode(rectOf: statCardSize, cornerRadius: 8)
        wash.fillColor = SKColor(hex: kind.colorHex, alpha: 0.20)
        wash.strokeColor = tag
        wash.lineWidth = 1.5
        wash.glowWidth = 2
        wash.name = "chipPlate"
        node.addChild(wash)

        let emoji = SKLabelNode(text: kind.emoji)
        emoji.fontSize = 26
        emoji.verticalAlignmentMode = .center
        emoji.position = CGPoint(x: 0, y: h / 2 - 28)
        node.addChild(emoji)

        let value = SKLabelNode(fontNamed: "Menlo-Bold")
        value.text = "+\(kind.bonus)"
        value.fontSize = 24
        value.fontColor = UpgradeCardNode.brightColor(hex: kind.colorHex)
        value.verticalAlignmentMode = .center
        value.position = CGPoint(x: 0, y: -2)
        node.addChild(value)

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = kind.label
        label.fontSize = 11
        label.fontColor = SKColor(hex: 0xFFFFFF)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -h / 2 + 18)
        node.addChild(label)

        return node
    }
    
    private func showCardSelection(_ cards: [UpgradeManager.UpgradeCard]) {
        for card in displayedCards { card.removeFromParent() }
        displayedCards.removeAll()

        // v1.8: 4+ cards stack into TWO rows instead of one cramped row — 2
        // (or 3) per row, roomier than the old 4-across squeeze.
        let count = cards.count
        let twoRow = count >= 4
        let perRow = twoRow ? Int(ceil(Double(count) / 2.0)) : count
        let cardScale: CGFloat = twoRow ? 0.74 : 1.0
        let colSpacing: CGFloat = twoRow ? 108 : 124
        let rowSpacing: CGFloat = 126
        // v1.9 4b: dropped to clear the stat card row above.
        let topRowY: CGFloat = twoRow ? -60 : -86

        // Drop the ad buttons down when cards take two rows.
        repositionLevelUpButtons(twoRow: twoRow)

        for (i, card) in cards.enumerated() {
            // v1.8 Unit 5: a card shown in a spread IS discovered (offered,
            // whether or not it's picked).
            CodexManager.shared.recordCardOffered(card.id)

            let row = (twoRow && i >= perRow) ? 1 : 0
            let idxInRow = row == 0 ? i : i - perRow
            let countInRow = row == 0 ? perRow : (count - perRow)
            let startX = -colSpacing * CGFloat(countInRow - 1) / 2
            let x = startX + colSpacing * CGFloat(idxInRow)
            let y = topRowY - CGFloat(row) * rowSpacing

            // v1.9: owned cards render as a LEVEL UP offer for their next tier
            let cardNode = UpgradeCardNode(card: card, currentTier: upgradeManager.tier(of: card.id))
            cardNode.position = CGPoint(x: x, y: y)
            cardNode.setScale(0.0)
            levelUpOverlay.addChild(cardNode)
            displayedCards.append(cardNode)

            let delay = SKAction.wait(forDuration: 0.05 * Double(i))
            let popIn = SKAction.scale(to: cardScale, duration: 0.2)
            popIn.timingMode = .easeOut
            cardNode.run(SKAction.sequence([delay, popIn]))
        }
    }

    /// v1.8: the reroll / +1 card / +1 pick buttons drop lower when the card
    /// spread uses two rows, so they clear the taller layout.
    private func repositionLevelUpButtons(twoRow: Bool) {
        // v1.9 4b: dropped to follow the lower card rows.
        let pairY: CGFloat = twoRow ? -250 : -188
        let pickY: CGFloat = twoRow ? -284 : -224
        levelUpOverlay.childNode(withName: "rerollButton")?.position.y = pairY
        levelUpOverlay.childNode(withName: "extraCardButton")?.position.y = pairY
        levelUpOverlay.childNode(withName: "extraPickButton")?.position.y = pickY
    }
    
    // MARK: - Death
    
    private func playerDied() {
        guard gameState == .playing else { return }
        gameState = .dead

        // v1.9: the killing blow zeroed currentHP, but updateHUD only runs while
        // .playing — so push the bar to 0 here or it freezes on its last value.
        hpBar.updateFill(playerStats.hpPercent,
                         currentHP: playerStats.currentHP,
                         maxHP: playerStats.maxHP)

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
            // v1.8: bound to the screen — the stats line was spilling off both edges.
            scoreLabel.fontSize = 18
            let maxScoreWidth = size.width - 32
            while scoreLabel.frame.width > maxScoreWidth && scoreLabel.fontSize > 11 {
                scoreLabel.fontSize -= 0.5
            }
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
            layoutXPBoostButton(xpBoostBtn)
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
                self.layoutXPBoostButton(xpBoostBtn)
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
        forgeCoins.forEach { $0.removeFromParent() }
        forgeCoins.removeAll()
        (boss as? QuenchWardenNode)?.cleanupWorldEffects()
        (boss as? DynamoChoirNode)?.cleanupWorldEffects()
        (boss as? FacetedLieNode)?.cleanupWorldEffects()
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
        // Purge the on-field run UI — the synergy/tag chips are data-driven but
        // only refresh on a pick, so restart must clear them explicitly.
        buffTracker.update(tagCounts: upgradeManager.tagCounts)
        waveManager.reset()
        adReviveManager.reset()
        timeSinceLastShot = 0
        lastUpdateTime = 0
        passiveDOTAccumulator = 0
        everglowPulseTimer = 0
        everglowEruptionTimer = 0
        ironRetaliateCooldown = 0
        ironMaidenProjectileTimer = 0
        skybeamStrikeCooldown = 0
        clearLasso()
        apexFamiliar?.removeFromParent(); apexFamiliar = nil
        apexTargetMarker?.removeFromParent(); apexTargetMarker = nil
        apexAttackTimer = 0
        apexOrbitPhase = 0
        apexBloodfedKills = 0
        apexPounceStacks = 0
        apexStackTimer = 0
        apexPounceCooldown = 0
        apexFamiliarTier = 0
        refreshApexGauge()
        erasureStacks = 0
        erasureStackTimer = 0
        erasureTriggerCooldown = 0
        eventHorizonErased = false
        eventHorizonEnded = false
        eventHorizonVoided = false
        removeAction(forKey: "eventHorizonPeace")
        hideEventHorizonCountdown()
        refreshErasureGauge()
        windchillStorm?.removeFromParent(); windchillStorm = nil
        windchillTimer = 0
        invulnerableTimer = 0
        killCount = 0
        rerollUsedThisRun = false
        extraCardUsedThisRun = false
        extraPickUsedThisRun = false
        extraPicksRemaining = 0
        pendingSynergies = []
        pendingCapstones = []
        capstoneQueue = []
        levelStatPick = nil
        pendingLevelCard = nil
        levelNeedsStat = false
        levelUpOverlay.childNode(withName: "statRow")?.removeFromParent()
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
        statHUD.update(from: playerStats)
        refreshKineticGauge()  // hide the gauge again for a fresh run

        deathOverlay.run(SKAction.fadeOut(withDuration: 0.2))
        levelUpOverlay.alpha = 0
        camera?.position = .zero

        gameState = .playing
    }
}
