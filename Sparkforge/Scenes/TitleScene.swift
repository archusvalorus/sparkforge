// TitleScene.swift
// Sparkforge
//
// Title screen.
// - "SPARKFORGE" title with ember glow
// - Ember particle drift (same aesthetic as arena)
// - High score + Forge Level display
// - Arena gate progress bars
// - Daily Forge Blessing button
// - "tap to ignite" prompt
// - Settings gear → restore purchases
// - Transitions to GameScene on tap
//
// v1.4: Added Forge Level, arena progression, Daily Forge blessing button.
// v1.4b: Fixed layout — proper top-to-bottom spacing via layoutY cursor.

import SpriteKit

final class TitleScene: SKScene {
    
    // MARK: - Nodes
    
    private let titleLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let subtitleLabel = SKLabelNode(fontNamed: "Menlo")
    private let tapPrompt = SKLabelNode(fontNamed: "Menlo")
    private let statsLabel = SKLabelNode(fontNamed: "Menlo")
    private let bestLabel = SKLabelNode(fontNamed: "Menlo")
    private let settingsButton = SKNode()
    private let restoreLabel = SKLabelNode(fontNamed: "Menlo")
    
    // v1.4
    private let forgeLevelLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let forgeXPBar = SKShapeNode()
    private let forgeXPBarBG = SKShapeNode()
    private let killProgressLabel = SKLabelNode(fontNamed: "Menlo")
    private let bossProgressLabel = SKLabelNode(fontNamed: "Menlo")
    private let survivalCheckLabel = SKLabelNode(fontNamed: "Menlo")
    private let dailyForgeButton = SKNode()
    private let dailyForgeLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let blessingActiveLabel = SKLabelNode(fontNamed: "Menlo")

    // v1.6: Arena selector
    private let arenaHeader = SKLabelNode(fontNamed: "Menlo-Bold")
    private let arenaPrevArrow = SKLabelNode(fontNamed: "Menlo-Bold")
    private let arenaNextArrow = SKLabelNode(fontNamed: "Menlo-Bold")
    private let arenaFlavorLabel = SKLabelNode(fontNamed: "Menlo")
    private let arenaReadyLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    
    // MARK: - State
    
    private var isTransitioning = false
    
    /// Tracks the current Y cursor for sequential layout
    private var layoutY: CGFloat = 0
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        
        // Start layout from center
        layoutY = 120
        
        setupEmberParticles()
        setupForgeGlow()
        setupTitle()
        setupForgeLevel()
        setupStats()
        setupArenaProgress()
        setupDailyForge()
        setupTapPrompt()
        setupSettings()
    }
    
    // MARK: - Setup
    
    private func setupEmberParticles() {
        let dotSize = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: dotSize)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: dotSize))
        }
        let dotTexture = SKTexture(image: image)
        
        // Bottom embers — rise from below
        let bottomEmitter = SKEmitterNode()
        bottomEmitter.particleBirthRate = 6
        bottomEmitter.particleLifetime = 5
        bottomEmitter.particleLifetimeRange = 2
        bottomEmitter.particlePositionRange = CGVector(dx: size.width * 0.8, dy: 0)
        bottomEmitter.position = CGPoint(x: 0, y: -size.height / 2 + 40)
        bottomEmitter.particleSpeed = 15
        bottomEmitter.particleSpeedRange = 8
        bottomEmitter.emissionAngle = .pi / 2
        bottomEmitter.emissionAngleRange = 0.3
        bottomEmitter.particleAlpha = 0.3
        bottomEmitter.particleAlphaRange = 0.15
        bottomEmitter.particleAlphaSpeed = -0.05
        bottomEmitter.particleScale = 0.05
        bottomEmitter.particleScaleRange = 0.03
        bottomEmitter.particleColor = SKColor(hex: 0xFF6600)
        bottomEmitter.particleColorBlendFactor = 1.0
        bottomEmitter.particleBlendMode = .add
        bottomEmitter.zPosition = -5
        bottomEmitter.particleTexture = dotTexture
        addChild(bottomEmitter)
        
        // Side embers — sparse, edges only
        let sideEmitter = SKEmitterNode()
        sideEmitter.particleBirthRate = 3
        sideEmitter.particleLifetime = 4
        sideEmitter.particleLifetimeRange = 2
        sideEmitter.particlePositionRange = CGVector(dx: size.width, dy: size.height * 0.6)
        sideEmitter.position = CGPoint(x: 0, y: -60)
        sideEmitter.particleSpeed = 8
        sideEmitter.particleSpeedRange = 5
        sideEmitter.emissionAngle = .pi / 2
        sideEmitter.emissionAngleRange = 0.8
        sideEmitter.particleAlpha = 0.15
        sideEmitter.particleAlphaRange = 0.1
        sideEmitter.particleAlphaSpeed = -0.03
        sideEmitter.particleScale = 0.04
        sideEmitter.particleScaleRange = 0.02
        sideEmitter.particleColor = SKColor(hex: 0xFF4400)
        sideEmitter.particleColorBlendFactor = 1.0
        sideEmitter.particleBlendMode = .add
        sideEmitter.zPosition = -5
        sideEmitter.particleTexture = dotTexture
        addChild(sideEmitter)
    }
    
    private func setupForgeGlow() {
        // Subtle glow behind title area
        let glow = SKShapeNode(circleOfRadius: 100)
        glow.fillColor = SKColor(hex: 0xFF6600, alpha: 0.04)
        glow.strokeColor = .clear
        glow.glowWidth = 30
        glow.position = CGPoint(x: 0, y: layoutY - 20)
        glow.zPosition = -3
        addChild(glow)
        
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.8, duration: 2.0),
            SKAction.fadeAlpha(to: 1.0, duration: 2.0)
        ])
        glow.run(SKAction.repeatForever(pulse))
    }
    
    private func setupTitle() {
        // Main title
        titleLabel.text = "SPARKFORGE"
        titleLabel.fontSize = 36
        titleLabel.fontColor = SKColor(hex: 0xFFAA33)
        titleLabel.position = CGPoint(x: 0, y: layoutY)
        titleLabel.zPosition = 10
        addChild(titleLabel)
        
        // Glow effect on title
        let titleGlow = SKLabelNode(fontNamed: "Menlo-Bold")
        titleGlow.text = "SPARKFORGE"
        titleGlow.fontSize = 36
        titleGlow.fontColor = SKColor(hex: 0xFF6600, alpha: 0.4)
        titleGlow.position = CGPoint(x: 0, y: layoutY)
        titleGlow.zPosition = 9
        addChild(titleGlow)
        
        layoutY -= 28
        
        // Subtitle
        subtitleLabel.text = "arena survival roguelite"
        subtitleLabel.fontSize = 11
        subtitleLabel.fontColor = SKColor(hex: 0xCCCCCC)
        subtitleLabel.position = CGPoint(x: 0, y: layoutY)
        subtitleLabel.zPosition = 10
        addChild(subtitleLabel)
        
        layoutY -= 30
    }
    
    // MARK: - v1.4: Forge Level
    
    private func setupForgeLevel() {
        let pm = ProgressionManager.shared
        
        // Forge Level badge
        let level = pm.forgeLevel
        forgeLevelLabel.text = level > 0 ? "FORGE LV \(level)" : "FORGE LV 0"
        forgeLevelLabel.fontSize = 12
        forgeLevelLabel.fontColor = SKColor(hex: 0xFFAA33)
        forgeLevelLabel.position = CGPoint(x: 0, y: layoutY)
        forgeLevelLabel.zPosition = 10
        addChild(forgeLevelLabel)
        
        layoutY -= 14
        
        // XP progress bar
        let barW: CGFloat = 100
        let barH: CGFloat = 3
        
        let bg = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 1.5)
        bg.fillColor = SKColor(hex: 0x332211)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: 0, y: layoutY)
        bg.zPosition = 10
        addChild(bg)
        
        let fillW = max(1, barW * pm.forgeLevelProgress)
        let fill = SKShapeNode()
        fill.path = CGPath(
            roundedRect: CGRect(x: -barW / 2, y: -barH / 2, width: fillW, height: barH),
            cornerWidth: 1.5, cornerHeight: 1.5, transform: nil
        )
        fill.fillColor = SKColor(hex: 0xFF6600)
        fill.strokeColor = .clear
        fill.position = CGPoint(x: 0, y: layoutY)
        fill.zPosition = 11
        addChild(fill)
        
        layoutY -= 25
    }
    
    private func setupStats() {
        let hs = HighScoreManager.shared
        
        if hs.totalRuns > 0 {
            // Best time + level
            bestLabel.text = "Best: \(hs.bestTimeFormatted)  •  Level \(hs.bestLevel)"
            bestLabel.fontSize = 13
            bestLabel.fontColor = SKColor(hex: 0xFFAA33)
            bestLabel.position = CGPoint(x: 0, y: layoutY)
            bestLabel.zPosition = 10
            addChild(bestLabel)
            
            layoutY -= 18
            
            // Total stats — now shows typed kills
            let pm = ProgressionManager.shared
            statsLabel.text = "\(hs.totalRuns) runs  •  \(pm.totalKills) kills"
            statsLabel.fontSize = 10
            statsLabel.fontColor = SKColor(hex: 0xBBBBBB)
            statsLabel.position = CGPoint(x: 0, y: layoutY)
            statsLabel.zPosition = 10
            addChild(statsLabel)
            
            layoutY -= 25
        }
    }
    
    // MARK: - v1.4: Arena Progress
    
    // v1.6: Arena section — header doubles as a selector once Arena 2 unlocks.
    // Fixed four-row layout; refreshArenaSection() fills it per selected arena.
    private func setupArenaProgress() {
        arenaHeader.fontSize = 9
        arenaHeader.position = CGPoint(x: 0, y: layoutY)
        arenaHeader.zPosition = 10
        addChild(arenaHeader)

        arenaPrevArrow.text = "◀"
        arenaNextArrow.text = "▶"
        for (arrow, x) in [(arenaPrevArrow, CGFloat(-100)), (arenaNextArrow, CGFloat(100))] {
            arrow.fontSize = 12
            arrow.fontColor = SKColor(hex: 0xFFAA33)
            arrow.position = CGPoint(x: x, y: layoutY - 1)
            arrow.zPosition = 10
            addChild(arrow)
        }

        layoutY -= 16

        // Row 1: kill progress (Crucible) / flavor line (Quench)
        killProgressLabel.fontSize = 10
        killProgressLabel.position = CGPoint(x: 0, y: layoutY)
        killProgressLabel.zPosition = 10
        addChild(killProgressLabel)

        arenaFlavorLabel.fontSize = 9
        arenaFlavorLabel.fontColor = SKColor(hex: 0x8A8478)
        arenaFlavorLabel.position = CGPoint(x: 0, y: layoutY)
        arenaFlavorLabel.zPosition = 10
        addChild(arenaFlavorLabel)

        layoutY -= 15

        // Row 2: survival check (Crucible only)
        survivalCheckLabel.fontSize = 10
        survivalCheckLabel.position = CGPoint(x: 0, y: layoutY)
        survivalCheckLabel.zPosition = 10
        addChild(survivalCheckLabel)

        layoutY -= 18

        // Row 3: "boss unlocked" pulse / locked-arena teaser
        arenaReadyLabel.fontSize = 11
        arenaReadyLabel.position = CGPoint(x: 0, y: layoutY)
        arenaReadyLabel.zPosition = 10
        addChild(arenaReadyLabel)
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ])
        arenaReadyLabel.run(SKAction.repeatForever(pulse))

        layoutY -= 20

        refreshArenaSection()
    }

    private func refreshArenaSection() {
        let pm = ProgressionManager.shared
        let arena = ArenaConfig.current
        let selectorVisible = pm.arenasUnlocked >= 2

        arenaHeader.text = arena.displayName
        arenaHeader.fontColor = arena.id == 1 ? SKColor(hex: 0xB8B0A4) : SKColor(hex: 0xCCCCCC)
        arenaPrevArrow.isHidden = !selectorVisible
        arenaNextArrow.isHidden = !selectorVisible

        if arena.id == 0 {
            let progress = pm.arena1Progress

            let killText = "\(progress.currentKills)/\(progress.requiredKills) kills"
            killProgressLabel.text = progress.killProgress >= 1.0 ? "✓ \(killText)" : "○ \(killText)"
            killProgressLabel.fontColor = progress.killProgress >= 1.0
                ? SKColor(hex: 0x66AA66) : SKColor(hex: 0xCCCCCC)
            killProgressLabel.isHidden = false

            // v1.6: survival row only appears when the gate requires it
            if ProgressionManager.arena1Gate.survivalRequired {
                survivalCheckLabel.text = progress.survivalMet ? "✓ Survived 2 minutes" : "○ Survive 2 minutes"
                survivalCheckLabel.fontColor = progress.survivalMet
                    ? SKColor(hex: 0x66AA66) : SKColor(hex: 0xCCCCCC)
                survivalCheckLabel.isHidden = false
            } else {
                survivalCheckLabel.isHidden = true
            }

            arenaFlavorLabel.isHidden = true

            if pm.arenasUnlocked >= 2 {
                arenaReadyLabel.isHidden = true
            } else if progress.allMet {
                arenaReadyLabel.text = "★ BOSS UNLOCKED ★"
                arenaReadyLabel.fontColor = SKColor(hex: 0xFFAA33)
                arenaReadyLabel.isHidden = false
            } else {
                arenaReadyLabel.text = "🔒 THE QUENCH lies beyond the Titan"
                arenaReadyLabel.fontSize = 9
                arenaReadyLabel.fontColor = SKColor(hex: 0x777777)
                arenaReadyLabel.isHidden = false
            }
        } else {
            killProgressLabel.isHidden = true
            survivalCheckLabel.isHidden = true

            arenaFlavorLabel.text = arena.flavorLine
            arenaFlavorLabel.isHidden = false

            arenaReadyLabel.isHidden = true
        }
    }
    
    // MARK: - v1.4: Daily Forge
    
    private func setupDailyForge() {
        let dfm = DailyForgeManager.shared
        
        layoutY -= 8  // Extra breathing room
        
        if !dfm.hasClaimedToday {
            // Show claimable button
            let bg = SKShapeNode(rectOf: CGSize(width: 160, height: 32), cornerRadius: 8)
            bg.fillColor = SKColor(hex: 0x332200)
            bg.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.6)
            bg.lineWidth = 1.5
            bg.position = CGPoint(x: 0, y: layoutY)
            bg.zPosition = 10
            bg.name = "dailyForgeBG"
            dailyForgeButton.addChild(bg)
            
            dailyForgeLabel.text = "🔥 DAILY FORGE"
            dailyForgeLabel.fontSize = 12
            dailyForgeLabel.fontColor = SKColor(hex: 0xFFAA33)
            dailyForgeLabel.verticalAlignmentMode = .center
            dailyForgeLabel.position = CGPoint(x: 0, y: layoutY)
            dailyForgeLabel.zPosition = 11
            dailyForgeLabel.name = "dailyForgeLabel"
            dailyForgeButton.addChild(dailyForgeLabel)
            
            dailyForgeButton.name = "dailyForgeButton"
            addChild(dailyForgeButton)
            
            // Gentle pulse on the button
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.7, duration: 1.0),
                SKAction.fadeAlpha(to: 1.0, duration: 1.0)
            ])
            bg.run(SKAction.repeatForever(pulse))
            
            layoutY -= 30
            
        } else if let blessing = dfm.activeBlessing {
            // Show active blessing indicator
            blessingActiveLabel.text = "\(blessing.icon) \(blessing.name) ready"
            blessingActiveLabel.fontSize = 10
            blessingActiveLabel.fontColor = SKColor(hex: 0x66AA66)
            blessingActiveLabel.position = CGPoint(x: 0, y: layoutY)
            blessingActiveLabel.zPosition = 10
            addChild(blessingActiveLabel)
            
            layoutY -= 22
        }
    }
    
    private func setupTapPrompt() {
        layoutY -= 10  // Breathing room
        
        tapPrompt.text = "tap to ignite"
        tapPrompt.fontSize = 14
        tapPrompt.fontColor = SKColor(hex: 0xCCCCCC)
        tapPrompt.position = CGPoint(x: 0, y: layoutY)
        tapPrompt.zPosition = 10
        addChild(tapPrompt)
        
        // Breathing pulse
        let breathe = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 1.2),
            SKAction.fadeAlpha(to: 1.0, duration: 1.2)
        ])
        tapPrompt.run(SKAction.repeatForever(breathe))
    }
    
    private func setupSettings() {
        let s = DeviceScale.ui
        
        layoutY -= 15  // Breathing room before settings
        
        // Remove Ads button (hidden if already purchased)
        if !IAPManager.shared.hasRemovedAds {
            let removeAdsLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            removeAdsLabel.text = "Remove Ads - $2.99"
            removeAdsLabel.fontSize = 11 * s
            removeAdsLabel.fontColor = SKColor(hex: 0xFFAA33)
            removeAdsLabel.position = CGPoint(x: 0, y: layoutY)
            removeAdsLabel.zPosition = 10
            removeAdsLabel.name = "removeAdsButton"
            addChild(removeAdsLabel)
            
            layoutY -= 20
        }
        
        // Restore purchases link
        restoreLabel.text = "Restore Purchases"
        restoreLabel.fontSize = 10 * s
        restoreLabel.fontColor = SKColor(hex: 0x999999)
        restoreLabel.position = CGPoint(x: 0, y: layoutY)
        restoreLabel.zPosition = 10
        restoreLabel.name = "restoreButton"
        addChild(restoreLabel)
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        guard !isTransitioning else { return }
        
        let location = touch.location(in: self)

        // v1.6: Arena selector arrows (visible once Arena 2 is unlocked)
        if ProgressionManager.shared.arenasUnlocked >= 2 {
            for arrow in [arenaPrevArrow, arenaNextArrow] where !arrow.isHidden {
                let frame = CGRect(x: arrow.position.x - 28, y: arrow.position.y - 22,
                                   width: 56, height: 44)
                if frame.contains(location) {
                    let pm = ProgressionManager.shared
                    pm.currentArena = pm.currentArena == 0 ? 1 : 0
                    refreshArenaSection()
                    return
                }
            }
        }

        // Check Daily Forge tap — use the BG node's position for hit testing
        if dailyForgeButton.parent != nil,
           let bg = dailyForgeButton.childNode(withName: "dailyForgeBG") {
            let forgeFrame = CGRect(
                x: bg.position.x - 90,
                y: bg.position.y - 20,
                width: 180, height: 40
            )
            if forgeFrame.contains(location) {
                handleDailyForge()
                return
            }
        }
        
        // Check Remove Ads tap
        if let removeBtn = childNode(withName: "removeAdsButton") {
            let btnFrame = CGRect(
                x: removeBtn.position.x - 100,
                y: removeBtn.position.y - 15,
                width: 200, height: 30
            )
            if btnFrame.contains(location) {
                handleRemoveAdsPurchase()
                return
            }
        }
        
        // Check restore purchases tap
        if let restore = childNode(withName: "restoreButton") {
            let restoreFrame = CGRect(
                x: restore.position.x - 80,
                y: restore.position.y - 15,
                width: 160, height: 30
            )
            if restoreFrame.contains(location) {
                handleRestorePurchases()
                return
            }
        }
        
        // Any other tap → start game
        startGame()
    }
    
    // MARK: - Daily Forge
    
    private func handleDailyForge() {
        let dfm = DailyForgeManager.shared
        
        // If ads are removed, claim directly
        if IAPManager.shared.hasRemovedAds {
            let blessing = dfm.claimBlessing()
            showBlessingGranted(blessing)
            return
        }
        
        // Otherwise, show rewarded ad then claim
        // TODO: Wire AdReviveManager for Daily Forge ad placement
        let blessing = dfm.claimBlessing()
        showBlessingGranted(blessing)
    }
    
    private func showBlessingGranted(_ blessing: DailyForgeManager.Blessing) {
        // Replace button with blessing display
        dailyForgeButton.removeAllChildren()
        dailyForgeButton.removeFromParent()
        
        let grantedY = layoutY + 50  // Roughly where the button was
        
        let granted = SKLabelNode(fontNamed: "Menlo-Bold")
        granted.text = "\(blessing.icon) \(blessing.name)"
        granted.fontSize = 14
        granted.fontColor = SKColor(hex: 0xFFAA33)
        granted.position = CGPoint(x: 0, y: grantedY + 5)
        granted.zPosition = 11
        granted.alpha = 0
        addChild(granted)
        
        let desc = SKLabelNode(fontNamed: "Menlo")
        desc.text = blessing.description
        desc.fontSize = 10
        desc.fontColor = SKColor(hex: 0x66AA66)
        desc.position = CGPoint(x: 0, y: grantedY - 12)
        desc.zPosition = 11
        desc.alpha = 0
        addChild(desc)
        
        // Pop-in animation
        granted.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.3),
                SKAction.scale(to: 1.2, duration: 0.2)
            ]),
            SKAction.scale(to: 1.0, duration: 0.1)
        ]))
        desc.run(SKAction.fadeIn(withDuration: 0.4))
    }
    
    // MARK: - Transitions
    
    private func startGame() {
        isTransitioning = true
        
        // Flash effect
        let flash = SKShapeNode(rectOf: CGSize(width: 2000, height: 2000))
        flash.fillColor = SKColor(hex: 0xFFAA33, alpha: 0.0)
        flash.strokeColor = .clear
        flash.zPosition = 100
        addChild(flash)
        
        let transition = SKAction.sequence([
            // Title pulses bright
            SKAction.run { [weak self] in
                self?.titleLabel.run(SKAction.scale(to: 1.1, duration: 0.15))
            },
            SKAction.wait(forDuration: 0.15),
            // Flash to white-orange
            SKAction.run {
                flash.fillColor = SKColor(hex: 0xFFAA33, alpha: 0.3)
            },
            SKAction.wait(forDuration: 0.1),
            // Fade everything out
            SKAction.run { [weak self] in
                self?.run(SKAction.fadeOut(withDuration: 0.3))
            },
            SKAction.wait(forDuration: 0.35),
            // Present game scene
            SKAction.run { [weak self] in
                self?.transitionToGame()
            }
        ])
        
        run(transition)
    }
    
    private func transitionToGame() {
        guard let view = view else { return }
        
        let gameScene = GameScene(size: view.bounds.size)
        gameScene.scaleMode = .resizeFill
        gameScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        let transition = SKTransition.fade(with: .black, duration: 0.3)
        view.presentScene(gameScene, transition: transition)
    }
    
    // MARK: - Restore Purchases
    
    private func handleRestorePurchases() {
        restoreLabel.text = "Restoring..."
        restoreLabel.fontColor = SKColor(hex: 0xFFAA33)
        
        Task { @MainActor in
            await IAPManager.shared.restorePurchases()
            
            if IAPManager.shared.hasRemovedAds {
                restoreLabel.text = "Ads Removed ✓"
                restoreLabel.fontColor = SKColor(hex: 0x66AA66)
                childNode(withName: "removeAdsButton")?.removeFromParent()
            } else {
                restoreLabel.text = "No purchases found"
                restoreLabel.fontColor = SKColor(hex: 0xCCCCCC)
                
                run(SKAction.wait(forDuration: 2.0)) { [weak self] in
                    self?.restoreLabel.text = "Restore Purchases"
                    self?.restoreLabel.fontColor = SKColor(hex: 0x999999)
                }
            }
        }
    }
    
    private func handleRemoveAdsPurchase() {
        guard let removeBtn = childNode(withName: "removeAdsButton") as? SKLabelNode else { return }
        
        removeBtn.text = "Purchasing..."
        removeBtn.fontColor = SKColor(hex: 0xCCCCCC)
        
        Task { @MainActor in
            let success = await IAPManager.shared.purchaseRemoveAds()
            
            if success {
                removeBtn.text = "Ads Removed ✓"
                removeBtn.fontColor = SKColor(hex: 0x66AA66)
                
                run(SKAction.wait(forDuration: 1.5)) {
                    removeBtn.removeFromParent()
                }
            } else {
                removeBtn.text = "Remove Ads — $2.99"
                removeBtn.fontColor = SKColor(hex: 0xFFAA33)
            }
        }
    }
}
