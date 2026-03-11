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
    }
    
    private(set) var gameState: GameState = .playing
    
    // MARK: - Core Systems
    
    private let playerStats = PlayerStats()
    private let upgradeManager = UpgradeManager()
    private let adReviveManager = AdReviveManager()
    
    // MARK: - Nodes
    
    private let player = PlayerNode()
    private let joystick = VirtualJoystick()
    private var enemies: [EnemyNode] = []
    private var projectiles: [ProjectileNode] = []
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
    private let xpBar = XPBarNode(width: 120)
    private let buffTracker = BuffTrackerNode()
    private let deathOverlay = SKNode()
    private let levelUpOverlay = SKNode()
    private let synergyLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    
    // MARK: - Stats Tracking
    
    private var killCount: Int = 0
    
    // MARK: - Timing
    
    private var lastUpdateTime: TimeInterval = 0
    private var timeSinceLastShot: TimeInterval = 0
    
    // MARK: - Invulnerability (post-revive)
    
    private var invulnerableTimer: TimeInterval = 0
    private var isInvulnerable: Bool { invulnerableTimer > 0 }
    
    // MARK: - Reroll
    
    private var rerollUsedThisRun: Bool = false
    
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
        setupEmberParticles()
        
        // Preload rewarded ad
        adReviveManager.preloadAd()
        
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
        let config = GameConfig.Arena.self
        
        let floorPath = CGPath(ellipseIn: CGRect(
            x: -config.radius, y: -config.radius,
            width: config.radius * 2, height: config.radius * 2
        ), transform: nil)
        arenaFloor.path = floorPath
        arenaFloor.fillColor = SKColor(hex: config.floorColorHex)
        arenaFloor.strokeColor = .clear
        arenaFloor.zPosition = -10
        worldNode.addChild(arenaFloor)
        
        // Inner ring details — concentric forge markings
        let ringRadii: [CGFloat] = [config.radius * 0.3, config.radius * 0.6, config.radius * 0.85]
        for (i, ringR) in ringRadii.enumerated() {
            let ringPath = CGPath(ellipseIn: CGRect(
                x: -ringR, y: -ringR,
                width: ringR * 2, height: ringR * 2
            ), transform: nil)
            let ring = SKShapeNode()
            ring.path = ringPath
            ring.fillColor = .clear
            ring.strokeColor = SKColor(hex: 0x252525, alpha: 0.4 - CGFloat(i) * 0.1)
            ring.lineWidth = 1
            ring.zPosition = -9.5
            worldNode.addChild(ring)
        }
        
        // Cross-hair lines through center (subtle forge grid)
        for angle in stride(from: 0.0, to: CGFloat.pi, by: CGFloat.pi / 4) {
            let line = SKShapeNode()
            let linePath = CGMutablePath()
            linePath.move(to: CGPoint(x: cos(angle) * config.radius * 0.9,
                                       y: sin(angle) * config.radius * 0.9))
            linePath.addLine(to: CGPoint(x: -cos(angle) * config.radius * 0.9,
                                          y: -sin(angle) * config.radius * 0.9))
            line.path = linePath
            line.strokeColor = SKColor(hex: 0x222222, alpha: 0.2)
            line.lineWidth = 0.5
            line.zPosition = -9.5
            worldNode.addChild(line)
        }
        
        // Outer boundary ring — main edge
        arenaBoundary.path = floorPath
        arenaBoundary.fillColor = .clear
        arenaBoundary.strokeColor = SKColor(hex: config.boundaryColorHex, alpha: 0.6)
        arenaBoundary.lineWidth = config.boundaryLineWidth
        arenaBoundary.glowWidth = 6
        arenaBoundary.zPosition = -9
        worldNode.addChild(arenaBoundary)
        
        // Outer danger glow — pulsing warning ring just outside boundary
        let dangerRing = SKShapeNode(circleOfRadius: config.radius + 4)
        dangerRing.fillColor = .clear
        dangerRing.strokeColor = SKColor(hex: 0x441100, alpha: 0.3)
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
        
        // XP Bar — below level
        xpBar.position = CGPoint(x: 0, y: safeTop - 38)
        xpBar.zPosition = 101
        camera.addChild(xpBar)
        
        // Buff tracker — top left
        buffTracker.position = CGPoint(x: safeLeft, y: safeTop)
        buffTracker.zPosition = 101
        camera.addChild(buffTracker)
        
        // Synergy notification — bottom center
        synergyLabel.fontSize = 12
        synergyLabel.fontColor = SKColor(hex: 0xFFDD55)
        synergyLabel.position = CGPoint(x: 0, y: -view.bounds.height / 2 + 80)
        synergyLabel.zPosition = 150
        synergyLabel.alpha = 0
        camera.addChild(synergyLabel)
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
        
        // Restart button
        let restartBtn = SKNode()
        restartBtn.name = "restartButton"
        restartBtn.position = CGPoint(x: 0, y: -75)
        
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
        menuLabel.position = CGPoint(x: 0, y: -110)
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
        label.fontSize = 22
        label.fontColor = SKColor(hex: 0xFFAA33)
        label.text = "LEVEL UP"
        label.name = "levelUpLabel"
        label.position = CGPoint(x: 0, y: 110)
        levelUpOverlay.addChild(label)
        
        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.fontSize = 11
        hint.fontColor = SKColor(hex: 0x666666)
        hint.text = "choose an upgrade"
        hint.position = CGPoint(x: 0, y: 85)
        levelUpOverlay.addChild(hint)
        
        // Reroll button
        let rerollBtn = SKNode()
        rerollBtn.name = "rerollButton"
        rerollBtn.position = CGPoint(x: 0, y: -90)
        
        let rerollBg = SKShapeNode(rectOf: CGSize(width: 170, height: 28), cornerRadius: 5)
        rerollBg.fillColor = SKColor(hex: 0x332233)
        rerollBg.strokeColor = SKColor(hex: 0x9966AA, alpha: 0.5)
        rerollBg.lineWidth = 1
        rerollBtn.addChild(rerollBg)
        
        let rerollText = SKLabelNode(fontNamed: "Menlo")
        rerollText.fontSize = 10
        rerollText.fontColor = SKColor(hex: 0xBB88CC)
        rerollText.text = "⟳ REFORGE CARDS"
        rerollText.verticalAlignmentMode = .center
        rerollText.name = "rerollLabel"
        rerollBtn.addChild(rerollText)
        
        // Small ad indicator (hidden if ads removed)
        let adIcon = SKLabelNode(fontNamed: "Menlo")
        adIcon.fontSize = 8
        adIcon.fontColor = SKColor(hex: 0x777777)
        adIcon.text = IAPManager.shared.hasRemovedAds ? "FREE" : "▶ AD"
        adIcon.verticalAlignmentMode = .center
        adIcon.position = CGPoint(x: 72, y: 0)
        adIcon.name = "rerollAdIcon"
        rerollBtn.addChild(adIcon)
        
        levelUpOverlay.addChild(rerollBtn)
        
        guard let camera = camera else { return }
        camera.addChild(levelUpOverlay)
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
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        switch gameState {
        case .playing:
            _ = joystick.handleTouchBegan(touch, in: self)
            
        case .dead:
            handleDeathScreenTap(touch)
            
        case .levelUp:
            handleCardSelection(touch)
            
        case .reviving:
            break
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
    
    // MARK: - Card Selection
    
    private func handleCardSelection(_ touch: UITouch) {
        let location = touch.location(in: levelUpOverlay)
        
        // Check reroll button first
        if let rerollBtn = levelUpOverlay.childNode(withName: "rerollButton"),
           rerollBtn.alpha > 0 {
            let btnFrame = CGRect(x: rerollBtn.position.x - 85, y: rerollBtn.position.y - 14,
                                  width: 170, height: 28)
            if btnFrame.contains(location) {
                performReroll()
                return
            }
        }
        
        // Check card taps
        for cardNode in displayedCards {
            let cardFrame = CGRect(
                x: cardNode.position.x - UpgradeCardNode.cardWidth / 2,
                y: cardNode.position.y - UpgradeCardNode.cardHeight / 2,
                width: UpgradeCardNode.cardWidth,
                height: UpgradeCardNode.cardHeight
            )
            
            if cardFrame.contains(location) {
                selectCard(cardNode)
                return
            }
        }
    }
    
    private func selectCard(_ selectedNode: UpgradeCardNode) {
        upgradeManager.pickCard(selectedNode.card, stats: playerStats)
        let synergies = upgradeManager.checkSynergies(stats: playerStats)
        player.updateCollisionRadius()
        
        // Update buff tracker
        buffTracker.update(tagCounts: upgradeManager.tagCounts)
        
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
    
    private func finishLevelUp(synergies: [String]) {
        if let firstSynergy = synergies.first {
            showSynergyNotification(firstSynergy)
        }
        
        if synergies.contains(where: { $0.contains("Barrier Pulse") }) {
            barrierPulse()
        }
        
        gameState = .playing
        levelUpOverlay.run(SKAction.fadeOut(withDuration: 0.15))
    }
    
    private func showSynergyNotification(_ text: String) {
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
        
        player.move(direction: joystick.direction, deltaTime: dt)
        updateEnemies(dt)
        updateAutoAttack(dt)
        updateProjectiles(dt)
        updateXPOrbs(dt)
        updatePassiveEffects(dt)
        
        let spawnEvent = waveManager.update(deltaTime: dt)
        if spawnEvent.shouldSpawnEnemy { spawnEnemy() }
        if spawnEvent.shouldSpawnMiniBoss { spawnMiniBoss() }
        
        updateHUD()
        
        // Camera follows player
        camera?.position = player.position
    }
    
    // MARK: - Enemy Updates
    
    private func updateEnemies(_ dt: TimeInterval) {
        var diedFromDOT: [Int] = []
        
        for (index, enemy) in enemies.enumerated() {
            enemy.chase(target: player.position, deltaTime: dt, globalSlow: playerStats.globalEnemySlow)
            
            let diedDOT = enemy.updateStatusEffects(deltaTime: dt)
            if diedDOT {
                diedFromDOT.append(index)
            }
            
            if playerStats.burnSpreads && enemy.isBurning {
                spreadBurn(from: enemy)
            }
        }
        
        for index in diedFromDOT.reversed() {
            let enemy = enemies[index]
            let pos = enemy.position
            let xp = enemy.xpValue
            enemies.remove(at: index)
            onEnemyKilled(at: pos, xpValue: xp)
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
        guard let nearestEnemy = findNearestEnemy() else { return }
        
        timeSinceLastShot = 0
        
        let totalProjectiles = 1 + playerStats.extraProjectiles
        let baseDirection = (nearestEnemy.position - player.position).normalized
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
    
    private func findNearestEnemy() -> EnemyNode? {
        let range = playerStats.effectiveProjectileRange
        var closest: EnemyNode?
        var closestDist: CGFloat = .greatestFiniteMagnitude
        
        for enemy in enemies {
            let dist = player.position.distance(to: enemy.position)
            if dist < range && dist < closestDist {
                closestDist = dist
                closest = enemy
            }
        }
        return closest
    }
    
    private func fireProjectile(direction: CGPoint) {
        let isCrit = CGFloat.random(in: 0...1) < playerStats.critChance
        
        let projectile = ProjectileNode(
            direction: direction,
            speed: playerStats.effectiveProjectileSpeed,
            range: playerStats.effectiveProjectileRange,
            pierces: playerStats.pierceCount,
            damageMultiplier: playerStats.damageMultiplier,
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
            projectiles[index].removeFromParent()
            projectiles.remove(at: index)
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
        if playerStats.teslaFieldDPS > 0 {
            for enemy in enemies {
                if player.position.distance(to: enemy.position) < playerStats.teslaFieldRadius {
                    enemy.applyBurn(playerStats.teslaFieldDPS, duration: 0.5)
                }
            }
        }
        
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
    }
    
    // MARK: - Spawning
    
    private func spawnEnemy() {
        let elapsed = waveManager.elapsedTime
        
        // HP scales with time — enemies get beefier
        // 0-30s: 1HP, 30-60s: 2HP, 60-90s: 3HP, 90-120s: 4-5HP, 120s+: 5-7HP
        let baseHP: Int
        if elapsed < 30 {
            baseHP = 1
        } else if elapsed < 60 {
            baseHP = 2
        } else if elapsed < 90 {
            baseHP = 3
        } else if elapsed < 120 {
            baseHP = Int.random(in: 4...5)
        } else {
            baseHP = Int.random(in: 5...7)
        }
        
        // Speed scales slightly — late game enemies are a bit faster
        let speedScale: CGFloat = 1.0 + CGFloat(elapsed / 180) * 0.25  // Up to +25% at 3min
        let enemySpeed = GameConfig.Enemy.baseSpeed * speedScale
        
        // XP scales with HP so beefier enemies are worth more
        let xpValue = max(1, baseHP)
        
        let enemy = EnemyNode(health: baseHP, moveSpeed: enemySpeed, xpValue: xpValue)
        enemy.position = EnemyNode.spawnPosition()
        
        // Subtle size scale with HP — beefier enemies are slightly larger
        if baseHP >= 3 {
            let sizeScale = 1.0 + CGFloat(baseHP - 2) * 0.08
            enemy.setScale(sizeScale)
        }
        
        enemies.append(enemy)
        worldNode.addChild(enemy)
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
        boss.position = EnemyNode.spawnPosition()
        boss.setScale(2.2)
        enemies.append(boss)
        worldNode.addChild(boss)
    }
    
    private func spawnXPOrb(at position: CGPoint, value: Int) {
        let orb = XPOrbNode(xpValue: value)
        orb.position = position
        xpOrbs.append(orb)
        worldNode.addChild(orb)
    }
    
    // MARK: - Enemy Killed
    
    private func onEnemyKilled(at position: CGPoint, xpValue: Int) {
        killCount += 1
        
        run(SKAction.wait(forDuration: 0.05)) { [weak self] in
            self?.spawnXPOrb(at: position, value: xpValue)
        }
        
        _ = playerStats.recordKill(atTime: waveManager.elapsedTime)
        playerStats.recordBloodlustKill(atTime: waveManager.elapsedTime)
        
        if playerStats.killsExplode {
            explosionAt(position)
        }
        
        // Subtle screen shake on kill
        worldNode.shake(intensity: 2, duration: 0.08)
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
        
        levelLabel.text = "LV \(player.currentLevel)"
        xpBar.updateFill(player.xpProgress)
    }
    
    // MARK: - Collision Detection
    
    func didBegin(_ contact: SKPhysicsContact) {
        let (bodyA, bodyB) = (contact.bodyA, contact.bodyB)
        let masks = (bodyA.categoryBitMask, bodyB.categoryBitMask)
        
        if (masks == (GameConfig.Physics.player, GameConfig.Physics.enemy)) ||
           (masks == (GameConfig.Physics.enemy, GameConfig.Physics.player)) {
            handlePlayerEnemyContact()
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
    }
    
    // MARK: - Player ↔ Enemy
    
    private func handlePlayerEnemyContact() {
        guard gameState == .playing else { return }
        guard !isInvulnerable else { return }
        
        if player.tryLethalSave() {
            for enemy in enemies {
                if player.position.distance(to: enemy.position) < 50 {
                    let dir = (enemy.position - player.position).normalized
                    enemy.position += dir * 40
                }
            }
            worldNode.shake(intensity: 8, duration: 0.25)
            return
        }
        
        playerDied()
    }
    
    // MARK: - Projectile ↔ Enemy
    
    private func handleProjectileHit(projectileBody: SKPhysicsBody, enemyBody: SKPhysicsBody) {
        guard let projectileNode = projectileBody.node as? ProjectileNode,
              let enemyNode = enemyBody.node as? EnemyNode else { return }
        
        var damage = max(1, Int(projectileNode.damageMultiplier))
        
        if projectileNode.isCrit {
            damage = max(2, Int(CGFloat(damage) * playerStats.critMultiplier))
        }
        
        if playerStats.executionThreshold > 0 && enemyNode.healthPercent < playerStats.executionThreshold {
            damage *= 2
        }
        
        if playerStats.slowedDamageBonus > 0 && enemyNode.isSlowed {
            damage = Int(CGFloat(damage) * (1.0 + playerStats.slowedDamageBonus))
        }
        
        if playerStats.isBloodlustActive(atTime: waveManager.elapsedTime) {
            damage = Int(CGFloat(damage) * (1.0 + playerStats.bloodlustBonus))
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
                    onEnemyKilled(at: enemyNode.position, xpValue: enemyNode.xpValue)
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
            onEnemyKilled(at: deathPos, xpValue: xpValue)
        }
        
        if playerStats.chainTargets > 0 && !killed {
            chainLightning(from: enemyNode.position,
                          damage: max(1, Int(CGFloat(damage) * playerStats.chainDamageMultiplier)),
                          remaining: playerStats.chainTargets,
                          excludeEnemy: enemyNode)
        }
    }
    
    // MARK: - Chain Lightning
    
    private func chainLightning(from position: CGPoint, damage: Int, remaining: Int, excludeEnemy: EnemyNode) {
        guard remaining > 0 else { return }
        
        var closest: EnemyNode?
        var closestDist: CGFloat = 80
        
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
            onEnemyKilled(at: pos, xpValue: xp)
        }
    }
    
    // MARK: - XP Collection
    
    private func handleXPCollection(orbBody: SKPhysicsBody) {
        guard let orbNode = orbBody.node as? XPOrbNode else { return }
        
        if let index = xpOrbs.firstIndex(where: { $0 === orbNode }) {
            xpOrbs.remove(at: index)
        }
        orbNode.collect()
        
        if player.addXP(orbNode.xpValue) {
            triggerLevelUp()
        }
    }
    
    // MARK: - Level Up
    
    private func triggerLevelUp() {
        gameState = .levelUp
        xpBar.flashLevelUp()
        levelLabel.text = "LV \(player.currentLevel)"
        
        if let label = levelUpOverlay.childNode(withName: "levelUpLabel") as? SKLabelNode {
            label.text = "LEVEL \(player.currentLevel)"
        }
        
        showCardSelection(upgradeManager.drawCards(count: 3))
        
        // Show/hide reroll button
        if let rerollBtn = levelUpOverlay.childNode(withName: "rerollButton") {
            rerollBtn.alpha = rerollUsedThisRun ? 0.0 : 1.0
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
        
        let spacing: CGFloat = 105
        let startX = -spacing * CGFloat(cards.count - 1) / 2
        
        for (i, card) in cards.enumerated() {
            let cardNode = UpgradeCardNode(card: card)
            cardNode.position = CGPoint(x: startX + spacing * CGFloat(i), y: 0)
            cardNode.setScale(0.0)
            levelUpOverlay.addChild(cardNode)
            displayedCards.append(cardNode)
            
            let delay = SKAction.wait(forDuration: 0.05 * Double(i))
            let popIn = SKAction.scale(to: 1.0, duration: 0.2)
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
        
        // Brief invulnerability
        invulnerableTimer = 2.0
        
        // Invulnerability visual (blinking)
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        player.run(SKAction.repeat(blink, count: 10), withKey: "invulnBlink")
        
        // Hide death overlay
        deathOverlay.run(SKAction.fadeOut(withDuration: 0.2))
        
        gameState = .playing
        lastUpdateTime = 0  // Reset delta time to avoid jump
    }
    
    // MARK: - Restart
    
    private func restartGame() {
        for enemy in enemies { enemy.removeFromParent() }
        enemies.removeAll()
        
        for proj in projectiles { proj.removeFromParent() }
        projectiles.removeAll()
        
        for orb in xpOrbs { orb.removeFromParent() }
        xpOrbs.removeAll()
        
        for card in displayedCards { card.removeFromParent() }
        displayedCards.removeAll()
        
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
        
        xpBar.updateFill(0)
        
        deathOverlay.run(SKAction.fadeOut(withDuration: 0.2))
        levelUpOverlay.alpha = 0
        camera?.position = .zero
        
        gameState = .playing
    }
}
