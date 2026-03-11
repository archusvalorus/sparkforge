// TitleScene.swift
// Sparkforge
//
// Title screen.
// - "SPARKFORGE" title with ember glow
// - Ember particle drift (same aesthetic as arena)
// - High score display
// - "tap to ignite" prompt
// - Settings gear → restore purchases
// - Transitions to GameScene on tap

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
    
    // MARK: - State
    
    private var isTransitioning = false
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        
        setupEmberParticles()
        setupForgeGlow()
        setupTitle()
        setupStats()
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
        guard let view = view else { return }
        let topY = view.bounds.height / 2 - 130
        
        let glow = SKShapeNode(circleOfRadius: 120)
        glow.fillColor = SKColor(hex: 0xFF6600, alpha: 0.06)
        glow.strokeColor = .clear
        glow.glowWidth = 40
        glow.position = CGPoint(x: 0, y: topY)
        glow.zPosition = -3
        addChild(glow)
        
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.8, duration: 2.0),
            SKAction.fadeAlpha(to: 1.0, duration: 2.0)
        ])
        glow.run(SKAction.repeatForever(pulse))
    }
    
    private func setupTitle() {
        guard let view = view else { return }
        let topY = view.bounds.height / 2 - 120
        
        // Main title
        titleLabel.text = "SPARKFORGE"
        titleLabel.fontSize = 36
        titleLabel.fontColor = SKColor(hex: 0xFFAA33)
        titleLabel.position = CGPoint(x: 0, y: topY)
        titleLabel.zPosition = 10
        addChild(titleLabel)
        
        // Glow effect on title
        let titleGlow = SKLabelNode(fontNamed: "Menlo-Bold")
        titleGlow.text = "SPARKFORGE"
        titleGlow.fontSize = 36
        titleGlow.fontColor = SKColor(hex: 0xFF6600, alpha: 0.4)
        titleGlow.position = CGPoint(x: 0, y: topY)
        titleGlow.zPosition = 9
        addChild(titleGlow)
        
        // Subtitle
        subtitleLabel.text = "arena survival roguelite"
        subtitleLabel.fontSize = 11
        subtitleLabel.fontColor = SKColor(hex: 0x777777)
        subtitleLabel.position = CGPoint(x: 0, y: topY - 28)
        subtitleLabel.zPosition = 10
        addChild(subtitleLabel)
    }
    
    private func setupStats() {
        let hs = HighScoreManager.shared
        
        if hs.totalRuns > 0 {
            // Best time + level
            bestLabel.text = "Best: \(hs.bestTimeFormatted)  •  Level \(hs.bestLevel)"
            bestLabel.fontSize = 13
            bestLabel.fontColor = SKColor(hex: 0xFFAA33)
            bestLabel.position = CGPoint(x: 0, y: -10)
            bestLabel.zPosition = 10
            addChild(bestLabel)
            
            // Total stats
            statsLabel.text = "\(hs.totalRuns) runs  •  \(hs.totalKills) kills"
            statsLabel.fontSize = 10
            statsLabel.fontColor = SKColor(hex: 0x666666)
            statsLabel.position = CGPoint(x: 0, y: -30)
            statsLabel.zPosition = 10
            addChild(statsLabel)
        }
    }
    
    private func setupTapPrompt() {
        tapPrompt.text = "tap to ignite"
        tapPrompt.fontSize = 14
        tapPrompt.fontColor = SKColor(hex: 0x888888)
        tapPrompt.position = CGPoint(x: 0, y: -80)
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
        guard let view = view else { return }
        
        // Restore purchases link at bottom
        restoreLabel.text = "Restore Purchases"
        restoreLabel.fontSize = 10
        restoreLabel.fontColor = SKColor(hex: 0x555555)
        restoreLabel.position = CGPoint(x: 0, y: -view.bounds.height / 2 + 40)
        restoreLabel.zPosition = 10
        restoreLabel.name = "restoreButton"
        addChild(restoreLabel)
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        guard !isTransitioning else { return }
        
        let location = touch.location(in: self)
        
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
            } else {
                restoreLabel.text = "No purchases found"
                restoreLabel.fontColor = SKColor(hex: 0x888888)
                
                // Reset after a moment
                run(SKAction.wait(forDuration: 2.0)) { [weak self] in
                    self?.restoreLabel.text = "Restore Purchases"
                    self?.restoreLabel.fontColor = SKColor(hex: 0x555555)
                }
            }
        }
    }
}
