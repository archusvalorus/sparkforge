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
    private let arenaBox = SKShapeNode(rectOf: CGSize(width: 312, height: 118), cornerRadius: 12)
    private let arenaHeader = SKLabelNode(fontNamed: "Menlo-Bold")
    private let arenaPrevArrow = SKLabelNode(fontNamed: "Menlo-Bold")
    private let arenaNextArrow = SKLabelNode(fontNamed: "Menlo-Bold")
    private let arenaFlavorLabel = SKLabelNode(fontNamed: "Menlo")
    private let arenaReadyLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    
    // MARK: - State

    private var isTransitioning = false

    /// Tracks the current Y cursor for sequential layout
    private var layoutY: CGFloat = 0

    // v1.6: blessing claim is a modal now (the old inline text stamped
    // itself over whatever the layout had moved into its spot)
    private var blessingModal: SKNode?
    private var dailyForgeRowY: CGFloat = 0

    // v1.7: Daily Forge choose-your-blessing
    private var blessingChoiceModal: SKNode?
    private var blessingPickerModal: SKNode?
    private let adManager = AdReviveManager()

    // v1.7: Forge Paths
    private var forgePathModal: SKNode?
    private var forgePathRowY: CGFloat = 0
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        backgroundColor = .black

        // v1.6: stretch the stack to fill the screen — the old fixed 120
        // start crammed everything into the middle third.
        // Belt & suspenders: if the scene somehow arrives unsized (the
        // zero-bounds-at-launch trap), fall back to a sane phone height.
        let screenHeight = size.height > 100 ? size.height : 667
        layoutY = min(screenHeight * 0.30, 280)
        
        setupEmberParticles()
        setupForgeGlow()
        setupTitle()
        setupForgeLevel()
        setupStats()
        setupArenaProgress()
        setupDailyForge()
        setupTapPrompt()
        setupSettings()

        // v1.7: warm up the blessing-choice ad while the forge is unclaimed
        if !DailyForgeManager.shared.hasClaimedToday && !IAPManager.shared.hasRemovedAds {
            adManager.preloadBlessingChoiceAd()
        }
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
        
        layoutY -= 34

        // Subtitle
        subtitleLabel.text = "arena survival roguelite"
        subtitleLabel.fontSize = 12
        subtitleLabel.fontColor = SKColor(hex: 0xCCCCCC)
        subtitleLabel.position = CGPoint(x: 0, y: layoutY)
        subtitleLabel.zPosition = 10
        addChild(subtitleLabel)

        layoutY -= 44
    }
    
    // MARK: - v1.4: Forge Level
    
    private func setupForgeLevel() {
        let pm = ProgressionManager.shared
        
        // Forge Level badge
        let level = pm.forgeLevel
        forgeLevelLabel.text = level > 0 ? "FORGE LV \(level)" : "FORGE LV 0"
        forgeLevelLabel.fontSize = 14
        forgeLevelLabel.fontColor = SKColor(hex: 0xFFAA33)
        forgeLevelLabel.position = CGPoint(x: 0, y: layoutY)
        forgeLevelLabel.zPosition = 10
        addChild(forgeLevelLabel)

        layoutY -= 18

        // XP progress bar
        let barW: CGFloat = 130
        let barH: CGFloat = 4
        
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

        setupForgePathRow()

        layoutY -= 34
    }

    // MARK: - v1.7: Forge Paths

    /// Under the forge XP bar: a picks-ready button when there's a choice
    /// to make, otherwise a quiet one-line path summary.
    private func setupForgePathRow() {
        let fpm = ForgePathManager.shared
        guard fpm.picksAvailable > 0 || !fpm.summary.isEmpty else { return }

        layoutY -= 24
        forgePathRowY = layoutY
        drawForgePathRow()
        layoutY -= 10
    }

    /// Draws (or redraws after spending picks) the path row at its slot
    private func drawForgePathRow() {
        while let stale = childNode(withName: "forgePathButton") { stale.removeFromParent() }
        while let stale = childNode(withName: "forgePathRowLabel") { stale.removeFromParent() }

        let fpm = ForgePathManager.shared

        if fpm.picksAvailable > 0 {
            let bg = SKShapeNode(rectOf: CGSize(width: 220, height: 32), cornerRadius: 8)
            bg.fillColor = SKColor(hex: 0x2A1A00)
            bg.strokeColor = SKColor(hex: 0xFFCC66, alpha: 0.7)
            bg.lineWidth = 1.5
            bg.position = CGPoint(x: 0, y: forgePathRowY)
            bg.zPosition = 10
            bg.name = "forgePathButton"
            addChild(bg)

            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            let n = fpm.picksAvailable
            label.text = "⚒ FORGE PATH — \(n) PICK\(n == 1 ? "" : "S") READY"
            label.fontSize = 11
            label.fontColor = SKColor(hex: 0xFFCC66)
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: forgePathRowY)
            label.zPosition = 11
            label.name = "forgePathRowLabel"
            addChild(label)

            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.65, duration: 1.0),
                SKAction.fadeAlpha(to: 1.0, duration: 1.0)
            ])
            bg.run(SKAction.repeatForever(pulse))
        } else if !fpm.summary.isEmpty {
            let parts = fpm.summary.map { "\($0.branch.icon)\($0.count)" }
            let summaryLabel = SKLabelNode(fontNamed: "Menlo")
            summaryLabel.text = parts.joined(separator: "  ")
            summaryLabel.fontSize = 11
            summaryLabel.fontColor = SKColor(hex: 0x999999)
            summaryLabel.verticalAlignmentMode = .center
            summaryLabel.position = CGPoint(x: 0, y: forgePathRowY)
            summaryLabel.zPosition = 10
            summaryLabel.name = "forgePathRowLabel"
            addChild(summaryLabel)
        }
    }
    
    private func setupStats() {
        let hs = HighScoreManager.shared
        
        if hs.totalRuns > 0 {
            // Best time + level
            bestLabel.text = "Best: \(hs.bestTimeFormatted)  •  Level \(hs.bestLevel)"
            bestLabel.fontSize = 15
            bestLabel.fontColor = SKColor(hex: 0xFFAA33)
            bestLabel.position = CGPoint(x: 0, y: layoutY)
            bestLabel.zPosition = 10
            addChild(bestLabel)

            layoutY -= 24

            // Total stats — now shows typed kills
            let pm = ProgressionManager.shared
            statsLabel.text = "\(hs.totalRuns) runs  •  \(pm.totalKills) kills"
            statsLabel.fontSize = 12
            statsLabel.fontColor = SKColor(hex: 0xBBBBBB)
            statsLabel.position = CGPoint(x: 0, y: layoutY)
            statsLabel.zPosition = 10
            addChild(statsLabel)

            layoutY -= 36
        }
    }
    
    // MARK: - v1.4: Arena Progress
    
    // v1.6: Arena section — header doubles as a selector once Arena 2 unlocks.
    // Fixed four-row layout; refreshArenaSection() fills it per selected arena.
    private func setupArenaProgress() {
        // v1.6 polish: the arena selector is the most important choice on
        // this screen — it now reads like one, boxed like a skill card
        // (dark plate + arena-tinted wash; tint set in refreshArenaSection)
        arenaBox.position = CGPoint(x: 0, y: layoutY - 42)
        arenaBox.lineWidth = 1.5
        arenaBox.glowWidth = 2
        arenaBox.zPosition = 9
        addChild(arenaBox)

        arenaHeader.fontSize = 15
        arenaHeader.position = CGPoint(x: 0, y: layoutY)
        arenaHeader.zPosition = 10
        addChild(arenaHeader)

        arenaPrevArrow.text = "◀"
        arenaNextArrow.text = "▶"
        for (arrow, x) in [(arenaPrevArrow, CGFloat(-125)), (arenaNextArrow, CGFloat(125))] {
            arrow.fontSize = 20
            arrow.fontColor = SKColor(hex: 0xFFAA33)
            arrow.position = CGPoint(x: x, y: layoutY - 2)
            arrow.zPosition = 10
            addChild(arrow)
        }

        layoutY -= 26

        // Row 1: kill progress (both arenas track their own gate kills)
        killProgressLabel.fontSize = 12
        killProgressLabel.position = CGPoint(x: 0, y: layoutY)
        killProgressLabel.zPosition = 10
        addChild(killProgressLabel)

        layoutY -= 22

        // Row 2: survival check (Crucible, when required) / flavor line (Quench)
        survivalCheckLabel.fontSize = 12
        survivalCheckLabel.position = CGPoint(x: 0, y: layoutY)
        survivalCheckLabel.zPosition = 10
        addChild(survivalCheckLabel)

        arenaFlavorLabel.fontSize = 11
        arenaFlavorLabel.fontColor = SKColor(hex: 0x8A8478)
        arenaFlavorLabel.position = CGPoint(x: 0, y: layoutY)
        arenaFlavorLabel.zPosition = 10
        addChild(arenaFlavorLabel)

        layoutY -= 26

        // Row 3: "boss unlocked" pulse / locked-arena teaser
        arenaReadyLabel.fontSize = 13
        arenaReadyLabel.position = CGPoint(x: 0, y: layoutY)
        arenaReadyLabel.zPosition = 10
        addChild(arenaReadyLabel)
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ])
        arenaReadyLabel.run(SKAction.repeatForever(pulse))

        layoutY -= 32

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

        // v1.6: the box wears the arena's vibe — same treatment as skill cards
        arenaBox.fillColor = SKColor(hex: arena.accentColorHex, alpha: 0.12)
        arenaBox.strokeColor = SKColor(hex: arena.accentColorHex, alpha: 0.5)

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
                arenaReadyLabel.fontSize = 13
                arenaReadyLabel.fontColor = SKColor(hex: 0xFFAA33)
                arenaReadyLabel.isHidden = false
            } else {
                arenaReadyLabel.text = "🔒 THE QUENCH lies beyond the Titan"
                arenaReadyLabel.fontSize = 11
                arenaReadyLabel.fontColor = SKColor(hex: 0x777777)
                arenaReadyLabel.isHidden = false
            }
        } else {
            // v1.6 Unit 6: The Quench shows the Warden's gate
            let gate = ProgressionManager.arena2Gate
            let kills = pm.quenchKills
            let met = pm.quenchWardenUnlocked

            let killText = "\(min(kills, gate.totalKillsRequired))/\(gate.totalKillsRequired) kills in the Quench"
            killProgressLabel.text = met ? "✓ \(killText)" : "○ \(killText)"
            killProgressLabel.fontColor = met
                ? SKColor(hex: 0x66AA66) : SKColor(hex: 0xCCCCCC)
            killProgressLabel.isHidden = false

            survivalCheckLabel.isHidden = true
            arenaFlavorLabel.text = arena.flavorLine
            arenaFlavorLabel.isHidden = false

            if met {
                arenaReadyLabel.text = "★ THE WARDEN STIRS ★"
                arenaReadyLabel.fontSize = 13
                arenaReadyLabel.fontColor = SKColor(hex: 0xD8A94A)
                arenaReadyLabel.isHidden = false
            } else {
                arenaReadyLabel.isHidden = true
            }
        }
    }
    
    // MARK: - v1.4: Daily Forge
    
    private func setupDailyForge() {
        let dfm = DailyForgeManager.shared

        layoutY -= 22  // Extra breathing room (clears the arena box's bottom edge)
        dailyForgeRowY = layoutY  // v1.6: remembered so the post-claim indicator lands here

        if !dfm.hasClaimedToday {
            // Show claimable button
            let bg = SKShapeNode(rectOf: CGSize(width: 200, height: 42), cornerRadius: 10)
            bg.fillColor = SKColor(hex: 0x332200)
            bg.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.6)
            bg.lineWidth = 1.5
            bg.position = CGPoint(x: 0, y: layoutY)
            bg.zPosition = 10
            bg.name = "dailyForgeBG"
            dailyForgeButton.addChild(bg)

            dailyForgeLabel.text = "🔥 DAILY FORGE"
            dailyForgeLabel.fontSize = 14
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

            layoutY -= 50

        } else if let blessing = dfm.activeBlessing {
            // Show active blessing indicator
            blessingActiveLabel.text = "\(blessing.icon) \(blessing.name) ready"
            blessingActiveLabel.fontSize = 12
            blessingActiveLabel.fontColor = SKColor(hex: 0x66AA66)
            blessingActiveLabel.position = CGPoint(x: 0, y: layoutY)
            blessingActiveLabel.zPosition = 10
            addChild(blessingActiveLabel)

            layoutY -= 32
        }
    }
    
    private func setupTapPrompt() {
        layoutY -= 14  // Breathing room

        tapPrompt.text = "tap to ignite"
        tapPrompt.fontSize = 17
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

        layoutY -= 34  // Breathing room before settings

        // Remove Ads button (hidden if already purchased)
        if !IAPManager.shared.hasRemovedAds {
            let removeAdsLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            removeAdsLabel.text = "Remove Ads - $2.99"
            removeAdsLabel.fontSize = 13 * s
            removeAdsLabel.fontColor = SKColor(hex: 0xFFAA33)
            removeAdsLabel.position = CGPoint(x: 0, y: layoutY)
            removeAdsLabel.zPosition = 10
            removeAdsLabel.name = "removeAdsButton"
            addChild(removeAdsLabel)

            layoutY -= 26
        }

        // Restore purchases link
        restoreLabel.text = "Restore Purchases"
        restoreLabel.fontSize = 11 * s
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

        // v1.7: choice + picker modals capture taps first
        if blessingChoiceModal != nil {
            handleBlessingChoiceTap(location)
            return
        }
        if blessingPickerModal != nil {
            handleBlessingPickerTap(location)
            return
        }
        if forgePathModal != nil {
            handleForgePathModalTap(location)
            return
        }

        // v1.6: blessing modal eats every tap until dismissed
        if blessingModal != nil {
            dismissBlessingModal()
            return
        }

        // v1.6: Arena selector arrows (visible once Arena 2 is unlocked)
        if ProgressionManager.shared.arenasUnlocked >= 2 {
            for arrow in [arenaPrevArrow, arenaNextArrow] where !arrow.isHidden {
                let frame = CGRect(x: arrow.position.x - 32, y: arrow.position.y - 26,
                                   width: 64, height: 52)
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
                x: bg.position.x - 105,
                y: bg.position.y - 25,
                width: 210, height: 50
            )
            if forgeFrame.contains(location) {
                handleDailyForge()
                return
            }
        }
        
        // v1.7: Forge Path picks button
        if let pathBtn = childNode(withName: "forgePathButton") {
            let frame = CGRect(x: pathBtn.position.x - 110, y: pathBtn.position.y - 16,
                               width: 220, height: 32)
            if frame.contains(location) {
                showForgePathModal()
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
    
    // v1.7: the forge tap opens a choice — free random stays whole,
    // the rewarded ad buys agency (Remove Ads owners choose free).
    // Nothing is claimed until a path completes; cancel costs nothing.
    private func handleDailyForge() {
        showBlessingChoiceModal()
    }

    private func showBlessingChoiceModal() {
        let adsRemoved = IAPManager.shared.hasRemovedAds

        let modal = SKNode()
        modal.zPosition = 300

        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.75)
        dim.strokeColor = .clear
        modal.addChild(dim)

        let panel = SKShapeNode(rectOf: CGSize(width: 280, height: 224), cornerRadius: 14)
        panel.fillColor = SKColor(hex: 0x1A1208)
        panel.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.7)
        panel.lineWidth = 1.5
        panel.glowWidth = 5
        modal.addChild(panel)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "🔥 DAILY FORGE"
        title.fontSize = 16
        title.fontColor = SKColor(hex: 0xFFAA33)
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 82)
        modal.addChild(title)

        // Random path — free, unchanged
        let randomBtn = SKShapeNode(rectOf: CGSize(width: 232, height: 46), cornerRadius: 8)
        randomBtn.fillColor = SKColor(hex: 0x332200)
        randomBtn.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.6)
        randomBtn.lineWidth = 1.5
        randomBtn.position = CGPoint(x: 0, y: 30)
        modal.addChild(randomBtn)

        let randomLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        randomLabel.text = "🎲 RANDOM BLESSING"
        randomLabel.fontSize = 13
        randomLabel.fontColor = SKColor(hex: 0xFFAA33)
        randomLabel.verticalAlignmentMode = .center
        randomLabel.position = CGPoint(x: 0, y: 36)
        modal.addChild(randomLabel)

        let randomSub = SKLabelNode(fontNamed: "Menlo")
        randomSub.text = "free"
        randomSub.fontSize = 9
        randomSub.fontColor = SKColor(hex: 0x888888)
        randomSub.verticalAlignmentMode = .center
        randomSub.position = CGPoint(x: 0, y: 20)
        modal.addChild(randomSub)

        // Choose path — the ad buys agency
        let chooseBtn = SKShapeNode(rectOf: CGSize(width: 232, height: 46), cornerRadius: 8)
        chooseBtn.fillColor = SKColor(hex: 0x11222E)
        chooseBtn.strokeColor = SKColor(hex: 0x44BBFF, alpha: 0.6)
        chooseBtn.lineWidth = 1.5
        chooseBtn.position = CGPoint(x: 0, y: -32)
        modal.addChild(chooseBtn)

        let chooseLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        chooseLabel.text = adsRemoved ? "✨ CHOOSE YOUR BLESSING" : "📺 CHOOSE YOUR BLESSING"
        chooseLabel.fontSize = 12
        chooseLabel.fontColor = SKColor(hex: 0x44BBFF)
        chooseLabel.verticalAlignmentMode = .center
        chooseLabel.position = CGPoint(x: 0, y: -26)
        modal.addChild(chooseLabel)

        let chooseSub = SKLabelNode(fontNamed: "Menlo")
        chooseSub.name = "chooseSubLabel"
        chooseSub.text = adsRemoved ? "ad-free — you own the forge" : "watch a short ad"
        chooseSub.fontSize = 9
        chooseSub.fontColor = SKColor(hex: 0x888888)
        chooseSub.verticalAlignmentMode = .center
        chooseSub.position = CGPoint(x: 0, y: -42)
        modal.addChild(chooseSub)

        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "tap outside to cancel"
        hint.fontSize = 9
        hint.fontColor = SKColor(hex: 0x666666)
        hint.verticalAlignmentMode = .center
        hint.position = CGPoint(x: 0, y: -92)
        modal.addChild(hint)

        addChild(modal)
        blessingChoiceModal = modal

        modal.alpha = 0
        panel.setScale(0.85)
        modal.run(SKAction.fadeIn(withDuration: 0.2))
        let pop = SKAction.scale(to: 1.0, duration: 0.2)
        pop.timingMode = .easeOut
        panel.run(pop)
    }

    private func handleBlessingChoiceTap(_ location: CGPoint) {
        let randomFrame = CGRect(x: -116, y: 30 - 23, width: 232, height: 46)
        let chooseFrame = CGRect(x: -116, y: -32 - 23, width: 232, height: 46)

        if randomFrame.contains(location) {
            dismissBlessingChoiceModal()
            let blessing = DailyForgeManager.shared.claimBlessing()
            AudioManager.shared.play(.cardSelect)
            showBlessingModal(blessing)
            return
        }

        if chooseFrame.contains(location) {
            let vc = view?.window?.rootViewController
            adManager.requestBlessingChoiceAd(from: vc) { [weak self] granted in
                guard let self = self else { return }
                if granted {
                    self.dismissBlessingChoiceModal()
                    self.showBlessingPickerModal()
                } else if let sub = self.blessingChoiceModal?.childNode(withName: "chooseSubLabel") as? SKLabelNode {
                    sub.text = "ad not ready — try again soon"
                    sub.fontColor = SKColor(hex: 0xCC6644)
                }
            }
            return
        }

        // Anywhere else cancels — the claim is untouched
        dismissBlessingChoiceModal()
    }

    private func dismissBlessingChoiceModal() {
        guard let modal = blessingChoiceModal else { return }
        blessingChoiceModal = nil
        modal.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))
    }

    // v1.7: post-ad picker — all five blessings, tap one to claim
    private func showBlessingPickerModal() {
        let modal = SKNode()
        modal.zPosition = 300

        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.75)
        dim.strokeColor = .clear
        modal.addChild(dim)

        let panel = SKShapeNode(rectOf: CGSize(width: 292, height: 296), cornerRadius: 14)
        panel.fillColor = SKColor(hex: 0x1A1208)
        panel.strokeColor = SKColor(hex: 0x44BBFF, alpha: 0.7)
        panel.lineWidth = 1.5
        panel.glowWidth = 5
        modal.addChild(panel)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "CHOOSE YOUR BLESSING"
        title.fontSize = 14
        title.fontColor = SKColor(hex: 0x44BBFF)
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 122)
        modal.addChild(title)

        for (i, blessing) in DailyForgeManager.blessings.enumerated() {
            let y = 76 - CGFloat(i) * 42

            let row = SKShapeNode(rectOf: CGSize(width: 256, height: 38), cornerRadius: 7)
            row.fillColor = SKColor(hex: 0x332200, alpha: 0.85)
            row.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.45)
            row.lineWidth = 1
            row.position = CGPoint(x: 0, y: y)
            modal.addChild(row)

            let icon = SKLabelNode(text: blessing.icon)
            icon.fontSize = 18
            icon.verticalAlignmentMode = .center
            icon.position = CGPoint(x: -108, y: y)
            modal.addChild(icon)

            let name = SKLabelNode(fontNamed: "Menlo-Bold")
            name.text = blessing.name
            name.fontSize = 13
            name.fontColor = SKColor(hex: 0xFFAA33)
            name.verticalAlignmentMode = .center
            name.horizontalAlignmentMode = .left
            name.position = CGPoint(x: -88, y: y + 8)
            modal.addChild(name)

            let desc = SKLabelNode(fontNamed: "Menlo")
            desc.text = blessing.description
            desc.fontSize = 9
            desc.fontColor = SKColor(hex: 0x66AA66)
            desc.verticalAlignmentMode = .center
            desc.horizontalAlignmentMode = .left
            desc.position = CGPoint(x: -88, y: y - 9)
            modal.addChild(desc)
        }

        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "your forge, your choice"
        hint.fontSize = 9
        hint.fontColor = SKColor(hex: 0x666666)
        hint.verticalAlignmentMode = .center
        hint.position = CGPoint(x: 0, y: -132)
        modal.addChild(hint)

        addChild(modal)
        blessingPickerModal = modal

        modal.alpha = 0
        panel.setScale(0.85)
        modal.run(SKAction.fadeIn(withDuration: 0.2))
        let pop = SKAction.scale(to: 1.0, duration: 0.2)
        pop.timingMode = .easeOut
        panel.run(pop)
    }

    // MARK: - v1.7: Forge Path Modal

    private func showForgePathModal() {
        let fpm = ForgePathManager.shared
        guard fpm.picksAvailable > 0 else { return }

        let modal = SKNode()
        modal.zPosition = 300

        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.75)
        dim.strokeColor = .clear
        modal.addChild(dim)

        let panel = SKShapeNode(rectOf: CGSize(width: 292, height: 276), cornerRadius: 14)
        panel.fillColor = SKColor(hex: 0x1A1208)
        panel.strokeColor = SKColor(hex: 0xFFCC66, alpha: 0.7)
        panel.lineWidth = 1.5
        panel.glowWidth = 5
        modal.addChild(panel)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "⚒ FORGE PATH"
        title.fontSize = 16
        title.fontColor = SKColor(hex: 0xFFCC66)
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 108)
        modal.addChild(title)

        let n = fpm.picksAvailable
        let subtitle = SKLabelNode(fontNamed: "Menlo")
        subtitle.text = "choose a permanent node — \(n) pick\(n == 1 ? "" : "s") left"
        subtitle.fontSize = 10
        subtitle.fontColor = SKColor(hex: 0x999999)
        subtitle.verticalAlignmentMode = .center
        subtitle.position = CGPoint(x: 0, y: 86)
        modal.addChild(subtitle)

        let rowYs: [CGFloat] = [44, -14, -72]
        for (i, branch) in ForgePathManager.Branch.allCases.enumerated() {
            guard let node = fpm.nextNode(for: branch) else { continue }
            let y = rowYs[i]
            let color = SKColor(hex: branch.colorHex)

            let row = SKShapeNode(rectOf: CGSize(width: 256, height: 50), cornerRadius: 8)
            row.fillColor = SKColor(hex: 0x161616)
            row.strokeColor = SKColor(hex: branch.colorHex, alpha: 0.7)
            row.lineWidth = 1.5
            row.position = CGPoint(x: 0, y: y)
            modal.addChild(row)

            let wash = SKShapeNode(rectOf: CGSize(width: 256, height: 50), cornerRadius: 8)
            wash.fillColor = SKColor(hex: branch.colorHex, alpha: 0.12)
            wash.strokeColor = .clear
            wash.position = CGPoint(x: 0, y: y)
            modal.addChild(wash)

            let icon = SKLabelNode(text: branch.icon)
            icon.fontSize = 20
            icon.verticalAlignmentMode = .center
            icon.position = CGPoint(x: -106, y: y)
            modal.addChild(icon)

            let branchName = SKLabelNode(fontNamed: "Menlo-Bold")
            branchName.text = branch.rawValue.uppercased()
            branchName.fontSize = 12
            branchName.fontColor = color
            branchName.verticalAlignmentMode = .center
            branchName.horizontalAlignmentMode = .left
            branchName.position = CGPoint(x: -84, y: y + 11)
            modal.addChild(branchName)

            let nodeLabel = SKLabelNode(fontNamed: "Menlo")
            nodeLabel.text = "\(node.name) — \(node.effectText)"
            nodeLabel.fontSize = 10
            nodeLabel.fontColor = SKColor(hex: 0xBBBBBB)
            nodeLabel.verticalAlignmentMode = .center
            nodeLabel.horizontalAlignmentMode = .left
            nodeLabel.position = CGPoint(x: -84, y: y - 10)
            modal.addChild(nodeLabel)
        }

        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "tap outside to bank picks for later"
        hint.fontSize = 9
        hint.fontColor = SKColor(hex: 0x666666)
        hint.verticalAlignmentMode = .center
        hint.position = CGPoint(x: 0, y: -122)
        modal.addChild(hint)

        addChild(modal)
        forgePathModal = modal

        modal.alpha = 0
        panel.setScale(0.85)
        modal.run(SKAction.fadeIn(withDuration: 0.2))
        let pop = SKAction.scale(to: 1.0, duration: 0.2)
        pop.timingMode = .easeOut
        panel.run(pop)
    }

    private func handleForgePathModalTap(_ location: CGPoint) {
        let fpm = ForgePathManager.shared
        let rowYs: [CGFloat] = [44, -14, -72]

        for (i, branch) in ForgePathManager.Branch.allCases.enumerated() {
            let rowFrame = CGRect(x: -128, y: rowYs[i] - 25, width: 256, height: 50)
            if rowFrame.contains(location) {
                fpm.choose(branch)
                AudioManager.shared.play(.cardSelect)
                dismissForgePathModal(animated: false)
                if fpm.picksAvailable > 0 {
                    showForgePathModal()  // fresh counts + next nodes in each cycle
                } else {
                    drawForgePathRow()
                }
                return
            }
        }

        // Outside: picks are banked, nothing lost
        dismissForgePathModal(animated: true)
        drawForgePathRow()
    }

    private func dismissForgePathModal(animated: Bool) {
        guard let modal = forgePathModal else { return }
        forgePathModal = nil
        if animated {
            modal.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.15),
                SKAction.removeFromParent()
            ]))
        } else {
            modal.removeFromParent()
        }
    }

    private func handleBlessingPickerTap(_ location: CGPoint) {
        for (i, blessing) in DailyForgeManager.blessings.enumerated() {
            let y = 76 - CGFloat(i) * 42
            let rowFrame = CGRect(x: -128, y: y - 19, width: 256, height: 38)
            if rowFrame.contains(location) {
                DailyForgeManager.shared.claimChosenBlessing(blessing)
                AudioManager.shared.play(.cardSelect)
                if let modal = blessingPickerModal {
                    blessingPickerModal = nil
                    modal.run(SKAction.sequence([
                        SKAction.fadeOut(withDuration: 0.15),
                        SKAction.removeFromParent()
                    ]))
                }
                showBlessingModal(blessing)
                return
            }
        }
        // The reward is already earned — taps outside the rows do nothing
    }

    // v1.6: blessing claim is a modal — the old inline text was positioned
    // off a stale layout cursor and stamped itself over "tap to ignite"
    private func showBlessingModal(_ blessing: DailyForgeManager.Blessing) {
        dailyForgeButton.removeAllChildren()
        dailyForgeButton.removeFromParent()

        let modal = SKNode()
        modal.zPosition = 300

        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.75)
        dim.strokeColor = .clear
        modal.addChild(dim)

        let panel = SKShapeNode(rectOf: CGSize(width: 280, height: 190), cornerRadius: 14)
        panel.fillColor = SKColor(hex: 0x1A1208)
        panel.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.7)
        panel.lineWidth = 1.5
        panel.glowWidth = 5
        modal.addChild(panel)

        let icon = SKLabelNode(text: blessing.icon)
        icon.fontSize = 38
        icon.verticalAlignmentMode = .center
        icon.position = CGPoint(x: 0, y: 48)
        modal.addChild(icon)

        let name = SKLabelNode(fontNamed: "Menlo-Bold")
        name.text = blessing.name
        name.fontSize = 18
        name.fontColor = SKColor(hex: 0xFFAA33)
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: 8)
        modal.addChild(name)

        let desc = SKLabelNode(fontNamed: "Menlo")
        desc.text = blessing.description
        desc.fontSize = 12
        desc.fontColor = SKColor(hex: 0x66AA66)
        desc.verticalAlignmentMode = .center
        desc.position = CGPoint(x: 0, y: -20)
        modal.addChild(desc)

        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "tap to continue"
        hint.fontSize = 10
        hint.fontColor = SKColor(hex: 0x888888)
        hint.verticalAlignmentMode = .center
        hint.position = CGPoint(x: 0, y: -62)
        modal.addChild(hint)
        hint.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 1.0),
            SKAction.fadeAlpha(to: 1.0, duration: 1.0)
        ])))

        addChild(modal)
        blessingModal = modal

        modal.alpha = 0
        panel.setScale(0.85)
        modal.run(SKAction.fadeIn(withDuration: 0.2))
        let pop = SKAction.scale(to: 1.0, duration: 0.2)
        pop.timingMode = .easeOut
        panel.run(pop)
    }

    private func dismissBlessingModal() {
        guard let modal = blessingModal else { return }
        blessingModal = nil

        modal.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))

        // Leave the "ready" indicator where the Daily Forge button lived
        if let blessing = DailyForgeManager.shared.activeBlessing,
           blessingActiveLabel.parent == nil {
            blessingActiveLabel.text = "\(blessing.icon) \(blessing.name) ready"
            blessingActiveLabel.fontSize = 12
            blessingActiveLabel.fontColor = SKColor(hex: 0x66AA66)
            blessingActiveLabel.position = CGPoint(x: 0, y: dailyForgeRowY)
            blessingActiveLabel.zPosition = 10
            blessingActiveLabel.alpha = 0
            addChild(blessingActiveLabel)
            blessingActiveLabel.run(SKAction.fadeIn(withDuration: 0.3))
        }
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
