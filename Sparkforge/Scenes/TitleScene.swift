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
import StoreKit

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
    // v1.8 (Unit 3): default row Ys, captured at setup. The locked branch
    // swaps these two so the prominent LOCKED sits above its requirement.
    private var arenaFlavorRowY: CGFloat = 0
    private var arenaReadyRowY: CGFloat = 0
    // v1.8 (Unit 3): lock glyph as its own node so the icon + "LOCKED" center
    // as a clean group (an inline emoji renders low and off-center).
    private let arenaLockIcon = SKLabelNode(fontNamed: "Menlo-Bold")

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
    private var respecConfirmModal: SKNode?  // v1.9 Unit 7: respec confirmation
    // v1.9 Unit 3: two-level nav state. detailBranch == nil → hub (3 chips);
    // non-nil → that branch's zoomed ladder. forkPending → A/B picker overlay.
    private var forgePathDetailBranch: ForgePathManager.Branch?
    private var forgePathForkPending: ForgePathManager.Branch?  // fork picker open for this branch
    private var removeAdsValueModal: RemoveAdsModalNode?  // v1.8 (E3): value-prop before purchase
    private var skinPickerModal: SKNode?                  // v2.0 Unit 1: skins wardrobe
    private var skinPickerFamily: String?                 // nil = family hub; else drilled into this family
    private var bossModeModal: SKNode?                    // v2.0 B1: boss-mode roster

    // v1.8 Unit 10: the CODEX hub + the scrollable page it opens.
    private var codexHub: CodexHubNode?
    private var codexPage: CodexPage?
    private var codexScrollLastY: CGFloat = 0
    private var codexScrollMovement: CGFloat = 0
    /// v1.9 Unit 2: true only when the current touch BEGAN on an open codex
    /// page. Stops the tap that opens a page (began on the hub) from bleeding
    /// through into a card-detail tap on the freshly-presented page.
    private var codexTouchBeganOnPage = false

    // v2.0 Unit 1.5: home-menu scroll (tap-vs-drag). The stacked home content
    // outgrew one screen (arena selector → capstone pills → skins/ads/footer),
    // so it pans vertically. Nodes move by `menuScrollOffset`; hit-tests read
    // live positions, so they need no offset math. Fixed nodes (background FX,
    // the gear) stay out of `menuScrollNodes`.
    private var menuScrollNodes: [(node: SKNode, baseY: CGFloat)] = []
    private var menuScrollOffset: CGFloat = 0
    private var menuScrollLastY: CGFloat = 0
    private var menuScrollMovement: CGFloat = 0
    private var menuTouchTracking = false
    private var menuContentTopY: CGFloat = 0
    private var menuContentBottomY: CGFloat = 0

    /// v1.9: the shared Settings modal (with Erase on the title surface) + the
    /// multi-step erase confirmation flow it can launch.
    private var settingsMenu: SettingsMenuNode?
    private var eraseModal: SKNode?
    private var eraseTextField: UITextField?
    private weak var eraseConfirmButton: SKNode?
    private var forgePathRowY: CGFloat = 0

    // v1.7: arena browser can show the next LOCKED arena (with its
    // requirement); pm.currentArena only follows unlocked selections
    private var displayedArenaIndex = 0
    /// Widest a box text row may be before it auto-shrinks clear of the arrows
    private var arenaTextMaxWidth: CGFloat = 240
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        backgroundColor = .black

        // v1.6: stretch the stack to fill the screen — the old fixed 120
        // start crammed everything into the middle third.
        // Belt & suspenders: if the scene somehow arrives unsized (the
        // zero-bounds-at-launch trap), fall back to a sane phone height.
        let screenHeight = size.height > 100 ? size.height : 667
        layoutY = min(screenHeight * 0.30, 280)
        
        #if DEBUG
        // v2.0 Unit 2a dev aid: unlock Arena 5 (Star Anvil) so it's selectable
        // for testing. Its live "clear Arena 4 → unlock" wiring lands when Unit 2
        // is complete; release builds are unaffected (Arena 5 stays a teaser).
        if ProgressionManager.shared.arenasUnlocked < ArenaConfig.all.count {
            ProgressionManager.shared.arenasUnlocked = ArenaConfig.all.count
        }
        #endif

        displayedArenaIndex = ArenaConfig.current.id

        setupEmberParticles()
        setupForgeGlow()
        setupTitle()
        setupForgeLevel()
        setupStats()
        setupArenaProgress()
        setupDailyForge()
        setupTapPrompt()
        setupSettings()
        setupSettingsGear(topInset: view.safeAreaInsets.top)

        // v2.0 Unit 1.5: snapshot the scrollable home stack (after all content
        // exists) so the menu can pan to reach every element.
        buildMenuScrollSet(topInset: view.safeAreaInsets.top, bottomInset: view.safeAreaInsets.bottom)

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
        titleLabel.fontColor = SKColor(hex: 0x1589C4)  // v1.8: ocean blue
        titleLabel.position = CGPoint(x: 0, y: layoutY)
        titleLabel.zPosition = 10
        addChild(titleLabel)

        // Glow effect on title
        let titleGlow = SKLabelNode(fontNamed: "Menlo-Bold")
        titleGlow.text = "SPARKFORGE"
        titleGlow.fontSize = 36
        titleGlow.fontColor = SKColor(hex: 0x0E6BA6, alpha: 0.5)  // v1.8: deep ocean glow
        titleGlow.position = CGPoint(x: 0, y: layoutY)
        titleGlow.zPosition = 9
        addChild(titleGlow)

        // v1.8: star-spark glints at BOTH ends of the title (four-point spark,
        // echoing the forge-coin motif). Offset in phase so they alternate.
        let glintX = titleLabel.frame.width / 2 + 8
        for sign: CGFloat in [-1, 1] {
            let glint = SKLabelNode(text: "✦")
            glint.fontSize = 18
            glint.fontColor = SKColor(hex: 0xEAF6FF)
            glint.verticalAlignmentMode = .center
            glint.position = CGPoint(x: sign * glintX, y: layoutY + 13)
            glint.zPosition = 11
            glint.alpha = 0.6
            addChild(glint)
            let twinkle = SKAction.repeatForever(SKAction.sequence([
                SKAction.group([SKAction.scale(to: 1.5, duration: 0.3),
                                SKAction.fadeAlpha(to: 1.0, duration: 0.3)]),
                SKAction.group([SKAction.scale(to: 0.85, duration: 0.4),
                                SKAction.fadeAlpha(to: 0.55, duration: 0.4)]),
                SKAction.wait(forDuration: 2.0)
            ]))
            glint.run(SKAction.sequence([SKAction.wait(forDuration: sign < 0 ? 0 : 1.35), twinkle]))
        }

        layoutY -= 34

        // Subtitle
        subtitleLabel.text = "arena survival roguelite"
        subtitleLabel.fontSize = 14
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
        forgeLevelLabel.fontSize = 16
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

        // v1.9 Unit 7: the entry is always the full-size (312×42) button now,
        // so it always needs clearance from the Forge XP bar above.
        layoutY -= 36
        forgePathRowY = layoutY
        drawForgePathRow()
        layoutY -= 16
    }

    /// Draws (or redraws after spending picks) the path row at its slot
    private func drawForgePathRow() {
        while let stale = childNode(withName: "forgePathButton") { stale.removeFromParent() }
        while let stale = childNode(withName: "forgePathRowLabel") { stale.removeFromParent() }

        let fpm = ForgePathManager.shared
        let n = fpm.picksAvailable

        // v1.9 Unit 7: ALWAYS a tappable button (312×42, standard footprint)
        // that opens the management screen — prominent + pulsing when there are
        // mastery points to spend, a quiet branch summary otherwise.
        let bg = SKShapeNode(rectOf: CGSize(width: 312, height: 42), cornerRadius: 9)
        bg.fillColor = SKColor(hex: 0x2A1A00)
        bg.strokeColor = SKColor(hex: 0xFFCC66, alpha: n > 0 ? 0.7 : 0.4)
        bg.lineWidth = 1.5
        bg.position = CGPoint(x: 0, y: forgePathRowY)
        bg.zPosition = 10
        bg.name = "forgePathButton"
        addChild(bg)

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 15
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: forgePathRowY)
        label.zPosition = 11
        label.name = "forgePathRowLabel"
        if n > 0 {
            label.text = "⚒ FORGE PATH — \(n) MASTERY POINT\(n == 1 ? "" : "S")"
            label.fontColor = SKColor(hex: 0xFFCC66)
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.65, duration: 1.0),
                SKAction.fadeAlpha(to: 1.0, duration: 1.0)
            ])
            bg.run(SKAction.repeatForever(pulse))
        } else if !fpm.summary.isEmpty {
            let parts = fpm.summary.map { "\($0.branch.icon)\($0.count)" }
            label.text = "⚒ FORGE PATH   \(parts.joined(separator: " "))"
            label.fontColor = SKColor(hex: 0xCCAA66)
        } else {
            label.text = "⚒ FORGE PATH"
            label.fontColor = SKColor(hex: 0xCCAA66)
        }
        addChild(label)
    }
    
    private func setupStats() {
        let hs = HighScoreManager.shared
        
        if hs.totalRuns > 0 {
            // Best time + level
            bestLabel.text = "Best: \(hs.bestTimeFormatted)  •  Level \(hs.bestLevel)"
            bestLabel.fontSize = 17
            bestLabel.fontColor = SKColor(hex: 0xFFAA33)
            bestLabel.position = CGPoint(x: 0, y: layoutY)
            bestLabel.zPosition = 10
            addChild(bestLabel)

            layoutY -= 24

            // Total stats — now shows typed kills
            let pm = ProgressionManager.shared
            statsLabel.text = "\(hs.totalRuns) runs  •  \(pm.totalKills) kills"
            statsLabel.fontSize = 14
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

        // v1.7 polish: rows sit 8pt lower so the content centers in the
        // box instead of crowding its top edge
        arenaHeader.fontSize = 17
        arenaHeader.position = CGPoint(x: 0, y: layoutY - 8)
        arenaHeader.zPosition = 10
        addChild(arenaHeader)

        // v1.7 playtest (Brandon): genre-standard BIG chevrons — the arena
        // choice is a headline decision, the arrows should look like one.
        // Device-aware: outside the box on modern widths, tucked in on SE;
        // the box text auto-shrinks clear of the arrow lanes either way.
        let arrowX = min(size.width / 2 - 26, arenaBox.frame.width / 2 + 26)
        arenaTextMaxWidth = 2 * (arrowX - 30)
        arenaPrevArrow.text = "◀"
        arenaNextArrow.text = "▶"
        for (arrow, x) in [(arenaPrevArrow, -arrowX), (arenaNextArrow, arrowX)] {
            arrow.fontSize = 44
            arrow.fontColor = SKColor(hex: 0xFFAA33)
            arrow.verticalAlignmentMode = .center
            arrow.position = CGPoint(x: x, y: layoutY - 42)
            arrow.zPosition = 10
            addChild(arrow)

            let breathe = SKAction.sequence([
                SKAction.group([
                    SKAction.fadeAlpha(to: 0.7, duration: 1.0),
                    SKAction.scale(to: 0.94, duration: 1.0)
                ]),
                SKAction.group([
                    SKAction.fadeAlpha(to: 1.0, duration: 1.0),
                    SKAction.scale(to: 1.0, duration: 1.0)
                ])
            ])
            arrow.run(SKAction.repeatForever(breathe))
        }

        layoutY -= 34

        // Row 1: kill progress (both arenas track their own gate kills)
        killProgressLabel.fontSize = 14
        killProgressLabel.position = CGPoint(x: 0, y: layoutY)
        killProgressLabel.zPosition = 10
        addChild(killProgressLabel)

        layoutY -= 22

        // Row 2: survival check (Crucible, when required) / flavor line (Quench)
        survivalCheckLabel.fontSize = 14
        survivalCheckLabel.position = CGPoint(x: 0, y: layoutY)
        survivalCheckLabel.zPosition = 10
        addChild(survivalCheckLabel)

        arenaFlavorLabel.fontSize = 13
        arenaFlavorLabel.fontColor = SKColor(hex: 0x8A8478)
        arenaFlavorLabel.position = CGPoint(x: 0, y: layoutY)
        arenaFlavorLabel.zPosition = 10
        arenaFlavorRowY = layoutY
        addChild(arenaFlavorLabel)

        layoutY -= 26

        // Row 3: "boss unlocked" pulse / locked-arena teaser
        arenaReadyLabel.fontSize = 15
        arenaReadyLabel.position = CGPoint(x: 0, y: layoutY)
        arenaReadyLabel.zPosition = 10
        arenaReadyRowY = layoutY
        addChild(arenaReadyLabel)
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ])
        arenaReadyLabel.run(SKAction.repeatForever(pulse))

        // v1.8 (Unit 3): lock glyph, vertically centered; shown only when a
        // locked arena is browsed. Same pulse (started now) keeps it in sync
        // with the LOCKED label.
        arenaLockIcon.fontSize = 18
        arenaLockIcon.verticalAlignmentMode = .center
        arenaLockIcon.zPosition = 10
        arenaLockIcon.isHidden = true
        addChild(arenaLockIcon)
        arenaLockIcon.run(SKAction.repeatForever(pulse))

        layoutY -= 24  // total row spend unchanged — layout below the box holds

        refreshArenaSection()
    }

    /// v1.7: every box text row re-fits inside the arrow lanes after each
    /// refresh (base size first, shrink only if the row would collide)
    private func fitArenaRows() {
        let rows: [(SKLabelNode, CGFloat)] = [
            (killProgressLabel, 14),   // v1.8 (Unit 4a): +2 across the opening screen
            (survivalCheckLabel, 14),
            (arenaFlavorLabel, 13),
            (arenaReadyLabel, arenaReadyLabel.fontSize)
        ]
        for (label, baseSize) in rows where !label.isHidden {
            label.fontSize = baseSize
            while label.frame.width > arenaTextMaxWidth && label.fontSize > 8 {
                label.fontSize -= 0.5
            }
        }
    }

    private func refreshArenaSection() {
        defer { fitArenaRows() }
        let pm = ProgressionManager.shared
        let browsableCount = min(pm.arenasUnlocked + 1, ArenaConfig.all.count)
        displayedArenaIndex = min(displayedArenaIndex, browsableCount - 1)
        let arena = ArenaConfig.all[displayedArenaIndex]
        let isLocked = displayedArenaIndex >= pm.arenasUnlocked
        let selectorVisible = browsableCount >= 2

        // v1.8 (Unit 3): no lock on the header — the single lock lives on the
        // prominent LOCKED line below, keeping the icon hierarchy tidy.
        arenaHeader.text = arena.displayName
        arenaHeader.fontColor = isLocked
            ? SKColor(hex: 0x777777)
            : (arena.id == 0 ? SKColor(hex: 0xCCCCCC) : SKColor(hex: arena.accentColorHex))

        // v1.8 (Unit 3): restore defaults; the locked branch overrides these.
        arenaFlavorLabel.position.y = arenaFlavorRowY
        arenaReadyLabel.position.y = arenaReadyRowY
        arenaReadyLabel.position.x = 0
        arenaReadyLabel.verticalAlignmentMode = .baseline
        arenaLockIcon.isHidden = true
        arenaPrevArrow.isHidden = !selectorVisible
        arenaNextArrow.isHidden = !selectorVisible

        // v1.6: the box wears the arena's vibe — same treatment as skill cards
        // v1.7: locked arenas wear it dimmed, through frosted glass
        arenaBox.fillColor = SKColor(hex: arena.accentColorHex, alpha: isLocked ? 0.05 : 0.12)
        arenaBox.strokeColor = SKColor(hex: arena.accentColorHex, alpha: isLocked ? 0.25 : 0.5)

        // v1.7/v1.8: a locked arena shows what opens it, nothing else.
        // v1.8 (Unit 3): clear hierarchy — a big, all-caps, pulsing "🔒 LOCKED"
        // above a small requirement line (was one dim "🔒 fell X to unlock").
        if isLocked {
            killProgressLabel.isHidden = true
            survivalCheckLabel.isHidden = true

            // Each locked arena names the boss whose fall opens it.
            let requirement: String
            switch displayedArenaIndex {
            case 1:  requirement = "fell \(ProgressionManager.arena1Gate.bossName) to unlock"
            case 2:  requirement = "fell \(ProgressionManager.arena2Gate.bossName) to unlock"
            default: requirement = "fell \(ProgressionManager.arena3Gate.bossName) to unlock"
            }

            // Requirement (small) drops to the lower row…
            arenaFlavorLabel.position.y = arenaReadyRowY
            arenaFlavorLabel.text = requirement
            arenaFlavorLabel.fontColor = SKColor(hex: 0x8A8478)
            arenaFlavorLabel.isHidden = false

            // …and the prominent LOCKED takes the upper row (it already pulses).
            // Icon + text are separate nodes, both vertically centered, offset
            // so the pair reads centered as a group.
            arenaReadyLabel.text = "LOCKED"
            arenaReadyLabel.fontSize = 20
            arenaReadyLabel.fontColor = SKColor(hex: 0xB0B0B0)
            arenaReadyLabel.verticalAlignmentMode = .center
            arenaReadyLabel.position.y = arenaFlavorRowY
            arenaReadyLabel.isHidden = false

            let gap: CGFloat = 8
            let textW = arenaReadyLabel.frame.width
            arenaLockIcon.text = "🔒"
            arenaLockIcon.position.y = arenaFlavorRowY
            let iconW = arenaLockIcon.frame.width
            arenaReadyLabel.position.x = (iconW + gap) / 2
            arenaLockIcon.position.x = -(textW + gap) / 2
            arenaLockIcon.isHidden = false
            return
        }

        if arena.id == 0 {
            let progress = pm.arena1Progress

            // Cap the display at the gate like arenas 2–4 — lifetime kills keep
            // accumulating for stats, but the arena gate reads N/100, not 5007/100.
            let shownKills = min(progress.currentKills, progress.requiredKills)
            let killText = "\(shownKills)/\(progress.requiredKills) kills"
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
                arenaReadyLabel.fontSize = 15
                arenaReadyLabel.fontColor = SKColor(hex: 0xFFAA33)
                arenaReadyLabel.isHidden = false
            } else {
                arenaReadyLabel.text = "🔒 THE QUENCH lies beyond the Titan"
                arenaReadyLabel.fontSize = 13
                arenaReadyLabel.fontColor = SKColor(hex: 0x777777)
                arenaReadyLabel.isHidden = false
            }
        } else if arena.id == 1 {
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

            if met && pm.arenasUnlocked < 3 {
                arenaReadyLabel.text = "★ THE WARDEN STIRS ★"
                arenaReadyLabel.fontSize = 15
                arenaReadyLabel.fontColor = SKColor(hex: 0xD8A94A)
                arenaReadyLabel.isHidden = false
            } else if pm.arenasUnlocked < 3 {
                arenaReadyLabel.text = "🔒 THE COILWORKS hums beyond the Warden"
                arenaReadyLabel.fontSize = 13
                arenaReadyLabel.fontColor = SKColor(hex: 0x777777)
                arenaReadyLabel.isHidden = false
            } else {
                arenaReadyLabel.isHidden = true
            }
        } else if arena.id == 2 {
            // v1.7 Unit 7: The Coilworks shows the Choir's gate
            let gate = ProgressionManager.arena3Gate
            let kills = pm.coilworksKills
            let met = pm.dynamoChoirUnlocked

            let killText = "\(min(kills, gate.totalKillsRequired))/\(gate.totalKillsRequired) kills in the Coilworks"
            killProgressLabel.text = met ? "✓ \(killText)" : "○ \(killText)"
            killProgressLabel.fontColor = met
                ? SKColor(hex: 0x66AA66) : SKColor(hex: 0xCCCCCC)
            killProgressLabel.isHidden = false

            survivalCheckLabel.isHidden = true
            arenaFlavorLabel.text = arena.flavorLine
            arenaFlavorLabel.isHidden = false

            if met {
                arenaReadyLabel.text = "★ THE CHOIR FINDS TEMPO ★"
                arenaReadyLabel.fontSize = 15
                arenaReadyLabel.fontColor = SKColor(hex: 0xF6D36B)
                arenaReadyLabel.isHidden = false
            } else {
                arenaReadyLabel.isHidden = true
            }
        } else {
            // v1.8 Unit 13: The Mirrorwound shows the Faceted Lie's gate.
            let gate = ProgressionManager.arena4Gate
            let kills = pm.mirrorwoundKills
            let met = pm.facetedLieUnlocked

            let killText = "\(min(kills, gate.totalKillsRequired))/\(gate.totalKillsRequired) kills in the Mirrorwound"
            killProgressLabel.text = met ? "✓ \(killText)" : "○ \(killText)"
            killProgressLabel.fontColor = met
                ? SKColor(hex: 0x66AA66) : SKColor(hex: 0xCCCCCC)
            killProgressLabel.isHidden = false

            survivalCheckLabel.isHidden = true
            arenaFlavorLabel.text = arena.flavorLine
            arenaFlavorLabel.isHidden = false

            if met {
                arenaReadyLabel.text = "★ THE LIE TAKES SHAPE ★"
                arenaReadyLabel.fontSize = 15
                arenaReadyLabel.fontColor = SKColor(hex: 0x9C748C)
                arenaReadyLabel.isHidden = false
            } else {
                arenaReadyLabel.isHidden = true
            }
        }
    }
    
    // MARK: - v1.4: Daily Forge
    
    private func setupDailyForge() {
        let dfm = DailyForgeManager.shared

        // v1.8 (Unit 4a): 22 → 46 — Daily Forge sat ~5px under the arena box's
        // bottom edge; give it real clearance so the two buttons don't crowd.
        layoutY -= 46
        dailyForgeRowY = layoutY  // v1.6: remembered so the post-claim indicator lands here

        if !dfm.hasClaimedToday {
            // Show claimable button
            let bg = SKShapeNode(rectOf: CGSize(width: 312, height: 42), cornerRadius: 10)  // v1.8: match arena box width
            bg.fillColor = SKColor(hex: 0x332200)
            bg.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.6)
            bg.lineWidth = 1.5
            bg.position = CGPoint(x: 0, y: layoutY)
            bg.zPosition = 10
            bg.name = "dailyForgeBG"
            dailyForgeButton.addChild(bg)

            dailyForgeLabel.text = "🔥 DAILY FORGE"
            dailyForgeLabel.fontSize = 16
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

            layoutY -= 20  // v1.8: + tap-prompt's -34 = 54 to the ignite button (equidistant)

        } else if let blessing = dfm.activeBlessing {
            // Show active blessing indicator
            blessingActiveLabel.text = "\(blessing.icon) \(blessing.name) ready"
            blessingActiveLabel.fontSize = 14
            blessingActiveLabel.fontColor = SKColor(hex: 0x66AA66)
            blessingActiveLabel.position = CGPoint(x: 0, y: layoutY)
            blessingActiveLabel.zPosition = 10
            addChild(blessingActiveLabel)

            layoutY -= 32
        }
    }
    
    private func setupTapPrompt() {
        layoutY -= 34  // v1.8: extra room above the taller "tap to ignite" CTA

        // v1.8: "tap to ignite" is the CTA — restyled as a blue button
        // (Restart style) for a splash of color + contrast. Font stays Menlo
        // (that courier vibe) but italic and larger; 312-wide to match the home
        // column. v2.0 Unit 1.5: this box is now the ONLY start-a-run hit target
        // (named "ignitePromptBox") — empty-space taps no longer ignite.
        let igniteBox = SKShapeNode(rectOf: CGSize(width: 312, height: 42), cornerRadius: 9)
        igniteBox.fillColor = SKColor(hex: 0x18345C)
        igniteBox.strokeColor = SKColor(hex: 0x5AA0F0, alpha: 0.85)
        igniteBox.lineWidth = 1.5
        igniteBox.position = CGPoint(x: 0, y: layoutY)
        igniteBox.zPosition = 9
        igniteBox.name = "ignitePromptBox"
        addChild(igniteBox)

        tapPrompt.fontName = "Menlo-BoldItalic"  // v1.8: bold + italic, courier vibe kept
        tapPrompt.text = "tap to ignite"
        tapPrompt.fontSize = 22
        tapPrompt.fontColor = SKColor(hex: 0xF2FBFF)  // v1.8: neon-white (crisp, cool-white)
        tapPrompt.verticalAlignmentMode = .center
        tapPrompt.position = CGPoint(x: 0, y: layoutY)
        tapPrompt.zPosition = 10
        addChild(tapPrompt)

        // Gentle breathing pulse on the whole CTA (box + text together).
        let breathe = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.65, duration: 1.2),
            SKAction.fadeAlpha(to: 1.0, duration: 1.2)
        ])
        igniteBox.run(SKAction.repeatForever(breathe))
        // Text stays solid (no dim) so the neon-white reads bright and constant.
    }
    
    private func setupSettings() {
        let s = DeviceScale.ui

        layoutY -= 54  // v1.8: 54 to match the DF→ignite gap (buttons equidistant)

        // v1.8 Unit 10: the CODEX hub entry — a distinct violet-bordered pill,
        // deliberately a different color from the amber Remove Ads box below so
        // the two never get confused (and Remove Ads keeps its clear gap).
        let codexBtn = SKNode()
        codexBtn.position = CGPoint(x: 0, y: layoutY)
        codexBtn.zPosition = 10
        codexBtn.name = "codexHubButton"
        let codexBox = SKShapeNode(rectOf: CGSize(width: 312, height: 42), cornerRadius: 9)
        codexBox.fillColor = SKColor(hex: 0x1A1420)
        codexBox.strokeColor = SKColor(hex: 0xB98AE0, alpha: 0.55)
        codexBox.lineWidth = 1.5
        codexBtn.addChild(codexBox)
        let codexLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        codexLabel.text = "📖  CODEX"
        codexLabel.fontSize = 15 * s
        codexLabel.fontColor = UITheme.Color.info
        codexLabel.verticalAlignmentMode = .center
        codexBtn.addChild(codexLabel)
        addChild(codexBtn)

        layoutY -= 54

        // v2.0 Unit 1: SKINS entry — a warm-gold pill (cosmetic wardrobe), its
        // own color lane so it never confuses with CODEX (violet) or Remove Ads.
        let skinsBtn = SKNode()
        skinsBtn.position = CGPoint(x: 0, y: layoutY)
        skinsBtn.zPosition = 10
        skinsBtn.name = "skinsButton"
        let skinsBox = SKShapeNode(rectOf: CGSize(width: 312, height: 42), cornerRadius: 9)
        skinsBox.fillColor = SKColor(hex: 0x1E1815)
        skinsBox.strokeColor = SKColor(hex: 0xE8B04C, alpha: 0.55)
        skinsBox.lineWidth = 1.5
        skinsBtn.addChild(skinsBox)
        let skinsLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        skinsLabel.text = "✦  SKINS"
        skinsLabel.fontSize = 15 * s
        skinsLabel.fontColor = SKColor(hex: 0xF0C070)
        skinsLabel.verticalAlignmentMode = .center
        skinsBtn.addChild(skinsLabel)
        addChild(skinsBtn)

        // v2.0 (B1): BOSS MODE — a permanent slot, shown once the player has
        // actually felled something. Crimson lane, distinct from CODEX/SKINS.
        if BossRegistry.shared.isAvailable {
            layoutY -= 54
            let bossBtn = SKNode()
            bossBtn.position = CGPoint(x: 0, y: layoutY)
            bossBtn.zPosition = 10
            bossBtn.name = "bossModeButton"
            let bossBox = SKShapeNode(rectOf: CGSize(width: 312, height: 42), cornerRadius: 9)
            bossBox.fillColor = SKColor(hex: 0x1F1214)
            bossBox.strokeColor = SKColor(hex: 0xE0554C, alpha: 0.55)
            bossBox.lineWidth = 1.5
            bossBtn.addChild(bossBox)
            let bossLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            bossLabel.text = "☠  BOSS MODE"
            bossLabel.fontSize = 15 * s
            bossLabel.fontColor = SKColor(hex: 0xF08078)
            bossLabel.verticalAlignmentMode = .center
            bossBtn.addChild(bossLabel)
            addChild(bossBtn)
        }

        layoutY -= 54  // clear gap before the Remove Ads box (anti-mistap)

        // Remove Ads button — v1.8 (E2): a distinct bordered pill so it reads
        // as a deliberate button, low-emphasis vs Daily Forge (softer border,
        // no pulse). The container node is the tap target; the label lives
        // inside (named for price/purchase text updates).
        if !IAPManager.shared.hasRemovedAds {
            let removeAdsBtn = SKNode()
            removeAdsBtn.position = CGPoint(x: 0, y: layoutY)
            removeAdsBtn.zPosition = 10
            removeAdsBtn.name = "removeAdsButton"

            let box = SKShapeNode(rectOf: CGSize(width: 312, height: 42), cornerRadius: 9)  // v1.8: match arena box width
            box.fillColor = SKColor(hex: 0x1E1710)
            box.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.4)
            box.lineWidth = 1.5
            removeAdsBtn.addChild(box)

            let removeAdsLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            removeAdsLabel.text = removeAdsButtonText()
            removeAdsLabel.fontSize = 15 * s
            removeAdsLabel.fontColor = SKColor(hex: 0xFFAA33)
            removeAdsLabel.verticalAlignmentMode = .center
            removeAdsLabel.name = "removeAdsLabel"
            removeAdsBtn.addChild(removeAdsLabel)

            addChild(removeAdsBtn)
            loadRemoveAdsPrice()

            layoutY -= 48
        }

        // Restore purchases link
        restoreLabel.text = "Restore Purchases"
        restoreLabel.fontSize = 13 * s
        restoreLabel.fontColor = SKColor(hex: 0x999999)
        restoreLabel.position = CGPoint(x: 0, y: layoutY)
        restoreLabel.zPosition = 10
        restoreLabel.name = "restoreButton"
        addChild(restoreLabel)

        // v1.9: Forgebound Labs cross-promo — a quiet "hallway" to a sibling
        // title. Low-emphasis footer link, clear of Remove Ads (anti-mistap).
        layoutY -= 32
        let forgePlug = SKLabelNode(fontNamed: "Menlo-Bold")
        forgePlug.text = "✦ More from the Forge ✦"
        forgePlug.fontSize = 13 * s
        forgePlug.fontColor = SKColor(hex: 0xC79A4E)  // muted forge-gold, tappable but soft
        forgePlug.verticalAlignmentMode = .center
        forgePlug.position = CGPoint(x: 0, y: layoutY)
        forgePlug.zPosition = 10
        forgePlug.name = "forgePromoButton"
        addChild(forgePlug)

        // v1.8 Unit 10: a direct line to the devs at the very bottom — tap the
        // address to open Mail. Small studio, real humans.
        layoutY -= 34
        let contactPrompt = SKLabelNode(fontNamed: "Menlo")
        contactPrompt.text = "Want to connect with the devs?"
        contactPrompt.fontSize = 11 * s
        contactPrompt.fontColor = SKColor(hex: 0x888888)
        contactPrompt.verticalAlignmentMode = .center
        contactPrompt.position = CGPoint(x: 0, y: layoutY)
        contactPrompt.zPosition = 10
        addChild(contactPrompt)

        layoutY -= 20
        let contactEmail = SKLabelNode(fontNamed: "Menlo-Bold")
        contactEmail.text = "games@hearthandhammer.ai"
        contactEmail.fontSize = 12 * s
        contactEmail.fontColor = SKColor(hex: 0xB98AE0)  // tappable-accent (matches CODEX)
        contactEmail.verticalAlignmentMode = .center
        contactEmail.position = CGPoint(x: 0, y: layoutY)
        contactEmail.zPosition = 10
        contactEmail.name = "contactEmailButton"
        addChild(contactEmail)
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        guard !isTransitioning else { return }
        
        let location = touch.location(in: self)

        // v1.8 Unit 10: codex overlays capture taps first. A page drags to
        // scroll (began just records the start; close is decided on touch-up),
        // the hub resolves taps to open/close.
        if codexPage != nil {
            codexScrollLastY = location.y
            codexScrollMovement = 0
            codexTouchBeganOnPage = true
            return
        }
        codexTouchBeganOnPage = false
        if let hub = codexHub {
            handleHubAction(hub.action(at: location))  // may present a page
            return
        }

        // v1.9: the erase flow is the most modal thing on screen — it captures
        // every tap until dismissed. Settings sits behind it.
        if eraseModal != nil {
            handleEraseModalTap(at: location)
            return
        }
        if let settings = settingsMenu {
            handleSettingsAction(settings.action(at: location))
            return
        }

        // v1.7: choice + picker modals capture taps first
        if blessingChoiceModal != nil {
            handleBlessingChoiceTap(location)
            return
        }
        if blessingPickerModal != nil {
            handleBlessingPickerTap(location)
            return
        }
        if respecConfirmModal != nil {   // v1.9 Unit 7: on top of the path modal
            handleRespecConfirmTap(location)
            return
        }
        if forgePathModal != nil {
            handleForgePathModalTap(location)
            return
        }
        if removeAdsValueModal != nil {
            handleRemoveAdsValueTap(location)
            return
        }
        if skinPickerModal != nil {                // v2.0 Unit 1: skins picker
            handleSkinPickerTap(location)
            return
        }
        if bossModeModal != nil {                  // v2.0 B1: boss mode roster
            handleBossModeTap(location)
            return
        }

        // v1.6: blessing modal eats every tap until dismissed
        if blessingModal != nil {
            dismissBlessingModal()
            return
        }

        // v2.0 Unit 1.5: the home menu scrolls, so it uses tap-vs-drag. Record
        // the touch here; the button hit-tests fire on touch-UP (handleHomeTapUp)
        // and ONLY if the touch didn't drag past the threshold (a drag scrolls).
        menuScrollLastY = location.y
        menuScrollMovement = 0
        menuTouchTracking = true
    }

    /// The home-screen button hit-tests, run on touch-UP for a non-drag tap.
    /// Menu node positions already carry the live scroll offset, so these frames
    /// stay correct while scrolled (the gear is fixed, tested in scene space).
    private func handleHomeTapUp(_ location: CGPoint) {
        // v1.7: arrows cycle every unlocked arena PLUS the next locked one
        // (shown with its unlock requirement); thumb-size hit zones
        for arrow in [arenaPrevArrow, arenaNextArrow] where !arrow.isHidden {
            let frame = CGRect(x: arrow.position.x - 55, y: arrow.position.y - 65,
                               width: 110, height: 130)
            if frame.contains(location) {
                let pm = ProgressionManager.shared
                let count = min(pm.arenasUnlocked + 1, ArenaConfig.all.count)
                let delta = arrow === arenaNextArrow ? 1 : -1
                displayedArenaIndex = (displayedArenaIndex + delta + count) % count
                if displayedArenaIndex < pm.arenasUnlocked {
                    pm.currentArena = displayedArenaIndex
                }
                refreshArenaSection()
                applyMenuScroll()   // keep arena nodes at the current scroll offset
                return
            }
        }

        // Check Daily Forge tap — bg.position is LOCAL to dailyForgeButton (which
        // sits at origin but now moves with menu scroll), so convert to scene
        // space for a hit-test that stays correct while scrolled.
        if dailyForgeButton.parent != nil,
           let bg = dailyForgeButton.childNode(withName: "dailyForgeBG") {
            let bgScene = convert(bg.position, from: dailyForgeButton)
            let forgeFrame = CGRect(
                x: bgScene.x - 156,
                y: bgScene.y - 25,
                width: 312, height: 50
            )
            if forgeFrame.contains(location) {
                handleDailyForge()
                return
            }
        }
        
        // v1.7: Forge Path picks button
        if let pathBtn = childNode(withName: "forgePathButton") {
            let frame = CGRect(x: pathBtn.position.x - 156, y: pathBtn.position.y - 21,
                               width: 312, height: 42)
            if frame.contains(location) {
                showForgePathModal()
                return
            }
        }

        // Check Remove Ads tap
        if let removeBtn = childNode(withName: "removeAdsButton") {
            let btnFrame = CGRect(
                x: removeBtn.position.x - 156,
                y: removeBtn.position.y - 21,
                width: 312, height: 42
            )
            if btnFrame.contains(location) {
                showRemoveAdsValueModal()  // v1.8 (E3): value prop before the sheet
                return
            }
        }

        // v1.8 Unit 10: CODEX hub entry
        if let codexBtn = childNode(withName: "codexHubButton") {
            let frame = CGRect(x: codexBtn.position.x - 156, y: codexBtn.position.y - 21,
                               width: 312, height: 42)
            if frame.contains(location) {
                presentCodexHub()
                return
            }
        }

        // v2.0 B1: BOSS MODE entry
        if let bossBtn = childNode(withName: "bossModeButton") {
            let frame = CGRect(x: bossBtn.position.x - 156, y: bossBtn.position.y - 21,
                               width: 312, height: 42)
            if frame.contains(location) {
                showBossModeModal()
                return
            }
        }

        // v2.0 Unit 1: SKINS entry
        if let skinsBtn = childNode(withName: "skinsButton") {
            let frame = CGRect(x: skinsBtn.position.x - 156, y: skinsBtn.position.y - 21,
                               width: 312, height: 42)
            if frame.contains(location) {
                showSkinPickerModal()
                return
            }
        }

        // v1.9: Settings gear (top-right) → shared Settings modal
        if settingsGearHit(location) {
            presentSettingsMenu()
            return
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

        // v1.9: Forgebound Labs cross-promo plug
        if let plug = childNode(withName: "forgePromoButton") {
            let plugFrame = CGRect(x: plug.position.x - 130, y: plug.position.y - 16,
                                   width: 260, height: 32)
            if plugFrame.contains(location) {
                presentCrossPromo()
                return
            }
        }

        // v1.8 Unit 10: tap the dev email to open Mail
        if let email = childNode(withName: "contactEmailButton") {
            let emailFrame = CGRect(x: email.position.x - 120, y: email.position.y - 16,
                                    width: 240, height: 32)
            if emailFrame.contains(location) {
                if let url = URL(string: "mailto:games@hearthandhammer.ai") {
                    UIApplication.shared.open(url)
                }
                return
            }
        }

        // v2.0 Unit 1.5: ONLY the ignite CTA starts a run. The old "any other
        // tap → startGame()" catch-all caused accidental launches during the
        // playtest loop — empty-space taps now do nothing.
        if let ignite = childNode(withName: "ignitePromptBox") {
            let frame = CGRect(x: ignite.position.x - 160, y: ignite.position.y - 26,
                               width: 320, height: 52)
            if frame.contains(location) {
                startGame()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        // Codex page scroll (unchanged).
        if let page = codexPage {
            let dy = loc.y - codexScrollLastY
            codexScrollLastY = loc.y
            codexScrollMovement += abs(dy)
            page.scroll(by: dy)
            return
        }

        // v2.0 Unit 1.5: home menu drag-scroll.
        if menuTouchTracking {
            let dy = loc.y - menuScrollLastY
            menuScrollLastY = loc.y
            menuScrollMovement += abs(dy)
            menuScrollOffset = clampedMenuOffset(menuScrollOffset + dy)
            applyMenuScroll()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        // Codex page tap-up (unchanged).
        if let page = codexPage {
            // Ignore the tap that opened this page (it began on the hub, not the
            // page) so it can't bleed through into a card-detail tap.
            guard codexTouchBeganOnPage else { return }
            guard codexScrollMovement < 8 else { return }   // a drag, not a tap
            if page.handleTapUp(at: loc) { return }
            if page.hitTestClose(at: loc) { dismissCodexPage() }
            return
        }

        // v2.0 Unit 1.5: home menu — fire button hit-tests only on a real tap
        // (a drag was a scroll, not a click).
        if menuTouchTracking {
            menuTouchTracking = false
            if menuScrollMovement < 10 { handleHomeTapUp(loc) }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        menuTouchTracking = false
    }

    // MARK: - v2.0 Unit 1.5: Home menu scroll

    /// Snapshot the scrollable home nodes + their resting Y. Fixed nodes stay
    /// out: background particle emitters, negative-z glow, and the gear/overlays.
    private func buildMenuScrollSet(topInset: CGFloat, bottomInset: CGFloat) {
        menuScrollNodes = children.compactMap { node in
            if node is SKEmitterNode { return nil }                 // background embers
            if node.zPosition < 0 { return nil }                    // forge glow
            if node.zPosition >= 20 { return nil }                  // gear + future overlays
            if node.name == "settingsGearButton" { return nil }     // belt & suspenders
            return (node, node.position.y)
        }
        menuContentTopY = menuScrollNodes.map { $0.baseY }.max() ?? 0
        menuContentBottomY = menuScrollNodes.map { $0.baseY }.min() ?? 0
    }

    /// Clamp an offset so the stack can't be dragged past emptiness: positive
    /// offset scrolls UP (reveals the bottom), negative scrolls DOWN (reveals
    /// the top). If content already fits, the clamp collapses to 0.
    private func clampedMenuOffset(_ value: CGFloat) -> CGFloat {
        let insets = view?.safeAreaInsets ?? .zero
        let topLimit = size.height / 2 - insets.top - 30
        let botLimit = -size.height / 2 + insets.bottom + 30
        let maxOff = Swift.max(0, botLimit - menuContentBottomY)
        let minOff = Swift.min(0, topLimit - menuContentTopY)
        return Swift.max(minOff, Swift.min(maxOff, value))
    }

    /// Reposition every scrollable node to its base Y plus the live offset.
    private func applyMenuScroll() {
        for entry in menuScrollNodes {
            entry.node.position = CGPoint(x: entry.node.position.x, y: entry.baseY + menuScrollOffset)
        }
    }

    // MARK: - v1.8 Unit 10: Codex hub

    private func presentCodexHub() {
        guard codexHub == nil, codexPage == nil else { return }
        let hub = CodexHubNode()
        hub.present(in: self)
        codexHub = hub
    }

    private func handleHubAction(_ action: CodexHubNode.Action?) {
        guard let action = action else { return }  // disabled / inside-panel tap
        codexHub?.dismiss()
        codexHub = nil
        switch action {
        case .close:
            break
        case .open(let face):
            presentCodexPage(face)
        }
    }

    private func presentCodexPage(_ face: CodexHubNode.Face) {
        let w = view?.bounds.width ?? size.width
        let h = view?.bounds.height ?? size.height
        let insets = view?.safeAreaInsets ?? UIEdgeInsets(top: 47, left: 0, bottom: 34, right: 0)
        let page: CodexPage
        switch face {
        case .synergies:
            page = SynergyCodexNode(width: w, height: h, topInset: insets.top, bottomInset: insets.bottom)
        case .bestiary:
            page = BestiaryCodexNode(width: w, height: h, topInset: insets.top, bottomInset: insets.bottom)
        case .cards:
            page = CardCodexNode(width: w, height: h, topInset: insets.top, bottomInset: insets.bottom)
        }
        addChild(page)
        page.alpha = 0
        page.run(SKAction.fadeIn(withDuration: 0.15))
        codexPage = page
    }

    private func dismissCodexPage() {
        codexPage?.dismiss()
        codexPage = nil
        presentCodexHub()  // back to the picker so you can browse another face
    }

    // MARK: - v1.9: Forgebound Labs cross-promo

    /// Open a random live sibling's App Store card in-app (no Safari kick-out).
    private func presentCrossPromo() {
        guard let sibling = CrossPromo.randomSibling(),
              let rootVC = view?.window?.rootViewController else { return }
        AudioManager.shared.play(.cardSelect)

        let storeVC = SKStoreProductViewController()
        storeVC.delegate = self
        let params = [SKStoreProductParameterITunesItemIdentifier: NSNumber(value: sibling.appStoreID)]
        storeVC.loadProduct(withParameters: params) { [weak rootVC, weak storeVC] loaded, _ in
            guard loaded, let rootVC = rootVC, let storeVC = storeVC else { return }
            rootVC.present(storeVC, animated: true)
        }
    }

    // MARK: - v1.9: Settings gear + shared Settings modal

    private func setupSettingsGear(topInset: CGFloat) {
        let gear = SKNode()
        gear.name = "settingsGearButton"
        gear.zPosition = 20
        let top = max(topInset, 20)
        gear.position = CGPoint(x: size.width / 2 - 34, y: size.height / 2 - top - 26)
        let bg = SKShapeNode(circleOfRadius: 18)
        bg.fillColor = SKColor(hex: 0x1A1420)
        bg.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.5)
        bg.lineWidth = 1.5
        gear.addChild(bg)
        let icon = SKLabelNode(text: "⚙︎")
        icon.fontSize = 20
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        gear.addChild(icon)
        addChild(gear)
    }

    private func settingsGearHit(_ location: CGPoint) -> Bool {
        guard let gear = childNode(withName: "settingsGearButton") else { return false }
        return gear.calculateAccumulatedFrame().insetBy(dx: -10, dy: -10).contains(location)
    }

    private func presentSettingsMenu() {
        guard settingsMenu == nil, codexHub == nil, codexPage == nil, eraseModal == nil else { return }
        let menu = SettingsMenuNode(showErase: true)
        menu.present(in: self)
        settingsMenu = menu
    }

    private func dismissSettingsMenu() {
        settingsMenu?.dismiss()
        settingsMenu = nil
    }

    private func handleSettingsAction(_ action: SettingsMenuNode.Action?) {
        guard let action = action else { return }
        switch action {
        case .close:
            dismissSettingsMenu()
        case .erase:
            dismissSettingsMenu()
            startEraseFlow()
        }
    }

    // MARK: - v1.9: Erase-all-progress flow (title-only, three gates)

    private func startEraseFlow() {
        let msg = "Erasing all progress means you start at Arena 1 with no arenas unlocked, and Forge level progress resets. Purchased skins will remain, but earned skins will need to be re-earned. Continue?"
        presentEraseModal(makeConfirmModal(
            title: "⛔  ERASE PROGRESS", titleHex: 0xE74C3C, message: msg,
            confirm: ("CONTINUE", "eraseContinue1", 0xC0392B), cancel: "eraseCancel"))
    }

    private func eraseStep2() {
        presentEraseModal(makeConfirmModal(
            title: "⚠︎  ARE YOU SURE?", titleHex: 0xE74C3C,
            message: "Are you sure you want to reset progress? This cannot be undone.",
            confirm: ("YES, RESET", "eraseContinue2", 0xC0392B), cancel: "eraseCancel"))
    }

    private func eraseStep3() {
        let node = SKNode()
        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.82)
        dim.strokeColor = .clear
        node.addChild(dim)

        // Roomier than the two text confirms — it holds five stacked elements,
        // so it needs real vertical space (was 250, felt cramped at the bottom).
        let panelH: CGFloat = 290
        let panel = SKShapeNode(rectOf: CGSize(width: 300, height: panelH), cornerRadius: 14)
        panel.fillColor = SKColor(hex: 0x141018)
        panel.strokeColor = SKColor(hex: 0xC0392B, alpha: 0.85)
        panel.lineWidth = 1.5
        panel.glowWidth = 4
        node.addChild(panel)

        let title = UITheme.label("FINAL CONFIRMATION", size: UITheme.Size.heading,
                                  color: SKColor(hex: 0xE74C3C), bold: true)
        title.position = CGPoint(x: 0, y: 109)
        node.addChild(title)

        for (i, line) in ["Type ERASE below to", "permanently wipe your save."].enumerated() {
            let l = UITheme.label(line, size: UITheme.Size.body, color: UITheme.Color.infoSoft)
            l.position = CGPoint(x: 0, y: 77 - CGFloat(i) * 18)
            node.addChild(l)
        }

        // The UITextField overlays this outline; both sit at scene y = 13 (see
        // addEraseTextField), leaving the buttons a comfortable bottom margin.
        let inputOutline = SKShapeNode(rectOf: CGSize(width: 184, height: 40), cornerRadius: 6)
        inputOutline.fillColor = SKColor(hex: 0x000000, alpha: 0.35)
        inputOutline.strokeColor = SKColor(hex: 0xC0392B, alpha: 0.5)
        inputOutline.position = CGPoint(x: 0, y: 13)
        node.addChild(inputOutline)

        let eraseBtn = modalButton(name: "eraseFinal", text: "ERASE", y: -44,
                                   fill: 0x3A2422, stroke: 0xC0392B, textHex: 0x886666)
        node.addChild(eraseBtn)
        eraseConfirmButton = eraseBtn

        node.addChild(modalButton(name: "eraseCancel", text: "CANCEL", y: -98,
                                  fill: 0x333333, stroke: 0x888888, textHex: 0xE0E0E0))

        presentEraseModal(node)
        addEraseTextField()
    }

    private func performErase() {
        ProgressionManager.shared.eraseAllProgress()
        dismissEraseFlow()
        // Rebuild the whole title from the now-wiped save — every surface
        // (arena lock, Forge level, stats, forge path) reflects the reset.
        // Match the canonical presentation (GameViewController): view-sized,
        // resizeFill, center origin — else the fresh scene lays out shifted.
        if let view = view {
            let fresh = TitleScene(size: view.bounds.size)
            fresh.scaleMode = .resizeFill
            fresh.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            view.presentScene(fresh, transition: .fade(with: .black, duration: 0.4))
        }
    }

    // MARK: Erase-flow plumbing

    private func presentEraseModal(_ node: SKNode) {
        eraseModal?.removeFromParent()
        removeEraseTextField()
        node.zPosition = 490
        addChild(node)
        node.alpha = 0
        node.run(SKAction.fadeIn(withDuration: 0.12))
        eraseModal = node
    }

    private func dismissEraseFlow() {
        eraseModal?.removeFromParent()
        eraseModal = nil
        eraseConfirmButton = nil
        removeEraseTextField()
    }

    func handleEraseModalTap(at location: CGPoint) {
        guard let modal = eraseModal else { return }
        let hit = modal.children.first { node in
            guard let w = node.userData?["w"] as? CGFloat,
                  let h = node.userData?["h"] as? CGFloat else { return false }
            return CGRect(x: node.position.x - w / 2, y: node.position.y - h / 2,
                          width: w, height: h).contains(location)
        }
        switch hit?.name {
        case "eraseCancel":
            dismissEraseFlow()
        case "eraseContinue1":
            eraseStep2()
        case "eraseContinue2":
            eraseStep3()
        case "eraseFinal":
            if (eraseTextField?.text ?? "").uppercased() == "ERASE" { performErase() }
        default:
            break
        }
    }

    // MARK: - v2.0 (B1): Boss Mode roster

    /// B1 surfaces the ARENA-AWARE registry: every boss listed with the arena it
    /// belongs to and its grammar, because Boss Mode loads that arena to fight it
    /// (monuments are unreadable anywhere else). Sequential/Mixup + the challenge
    /// dials land in B2/B3.
    private func showBossModeModal() {
        dismissBossModeModal(animated: false)
        AudioManager.shared.play(.cardSelect)
        let roster = BossRegistry.shared.unlocked

        let modal = SKNode()
        modal.zPosition = 300
        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.8)
        dim.strokeColor = .clear
        modal.addChild(dim)

        let rowH: CGFloat = 56, gap: CGFloat = 8
        let panelW: CGFloat = 336
        // Bottom padding carries the roster clear of the gauntlet button + hint.
        let panelH = 92 + CGFloat(roster.count) * (rowH + gap) + 100
        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 14)
        panel.fillColor = SKColor(hex: 0x140C0D)
        panel.strokeColor = SKColor(hex: 0xE0554C, alpha: 0.7)
        panel.lineWidth = 1.5
        panel.glowWidth = 5
        panel.name = "bossPanel"
        modal.addChild(panel)
        let top = panelH / 2

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "☠ BOSS MODE"
        title.fontSize = 18
        title.fontColor = SKColor(hex: 0xF08078)
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: top - 26)
        modal.addChild(title)

        let sub = SKLabelNode(fontNamed: "Menlo")
        sub.text = "\(roster.count) felled — fight them again, your way"
        sub.fontSize = 10.5
        sub.fontColor = SKColor(hex: 0x999999)
        sub.verticalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: top - 48)

        #if DEBUG
        // A dev seam left switched on is indistinguishable from a bug — the
        // gauntlet just behaves wrongly and says nothing about why. So when a
        // seam is active, the mode announces it in the one place you can't
        // miss on the way in. (Release builds never compile this.)
        var seams: [String] = []
        if GameConfig.BossMode.debugForceFullRoster { seams.append("full roster") }
        if GameConfig.BossMode.debugStartStage > 1 {
            seams.append("start @ stage \(GameConfig.BossMode.debugStartStage)")
        }
        if !seams.isEmpty {
            sub.text = "⚠︎ DEBUG — " + seams.joined(separator: " · ")
            sub.fontColor = SKColor(hex: 0xFFCC44)
        }
        #endif

        modal.addChild(sub)

        for (i, e) in roster.enumerated() {
            let cy = top - 92 - rowH / 2 - CGFloat(i) * (rowH + gap)
            let row = SKShapeNode(rectOf: CGSize(width: panelW - 32, height: rowH), cornerRadius: 10)
            row.fillColor = SKColor(hex: 0x1A1012)
            row.strokeColor = SKColor(hex: e.accentHex, alpha: 0.5)
            row.lineWidth = 1.3
            row.position = CGPoint(x: 0, y: cy)
            modal.addChild(row)

            let name = SKLabelNode(fontNamed: "Menlo-Bold")
            name.text = e.name
            name.fontSize = 14
            name.fontColor = SKColor(hex: e.accentHex)
            name.verticalAlignmentMode = .center
            name.horizontalAlignmentMode = .left
            name.position = CGPoint(x: -panelW / 2 + 22, y: cy + 10)
            modal.addChild(name)

            let meta = SKLabelNode(fontNamed: "Menlo")
            let grammar = e.grammar == .monument ? "MONUMENT" : "ARENA"
            meta.text = "Arena \(e.arenaID + 1)  ·  \(grammar)"
            meta.fontSize = 9.5
            meta.fontColor = SKColor(hex: e.grammar == .monument ? 0xFFD98A : 0x9A8E88)
            meta.verticalAlignmentMode = .center
            meta.horizontalAlignmentMode = .left
            meta.position = CGPoint(x: -panelW / 2 + 22, y: cy - 12)
            modal.addChild(meta)
        }

        // v2.0 (B2a): the mode's actual proposition — one button, straight in,
        // all of them back-to-back. The roster above stays as context.
        let enter = SKShapeNode(rectOf: CGSize(width: panelW - 32, height: 46), cornerRadius: 10)
        enter.fillColor = SKColor(hex: 0x2A1114)
        enter.strokeColor = SKColor(hex: 0xE0554C, alpha: 0.9)
        enter.lineWidth = 1.6
        enter.glowWidth = 3
        enter.position = CGPoint(x: 0, y: -top + 62)
        enter.name = "gauntletButton"
        modal.addChild(enter)

        let enterLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        enterLabel.text = "ENTER THE GAUNTLET"
        enterLabel.fontSize = 15
        enterLabel.fontColor = SKColor(hex: 0xF08078)
        enterLabel.verticalAlignmentMode = .center
        enterLabel.position = CGPoint(x: 0, y: -top + 62)
        enterLabel.name = "gauntletButtonLabel"
        modal.addChild(enterLabel)

        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "all \(roster.count), back-to-back — no revives"
        hint.fontSize = 10
        hint.fontColor = SKColor(hex: 0x6A5A58)
        hint.verticalAlignmentMode = .center
        hint.position = CGPoint(x: 0, y: -top + 20)
        modal.addChild(hint)

        addChild(modal)
        bossModeModal = modal
        modal.alpha = 0
        panel.setScale(0.9)
        modal.run(SKAction.fadeIn(withDuration: 0.18))
        let pop = SKAction.scale(to: 1.0, duration: 0.18); pop.timingMode = .easeOut
        panel.run(pop)
    }

    private func handleBossModeTap(_ location: CGPoint) {
        guard bossModeModal != nil else { return }
        let hits = nodes(at: location)

        // v2.0 (B2a): one button straight into the gauntlet — no mode menu, no
        // loadout screen. The friction belongs in the fight, not in front of it.
        if hits.contains(where: { $0.name == "gauntletButton" || $0.name == "gauntletButtonLabel" }) {
            dismissBossModeModal(animated: false)
            startGauntlet()
            return
        }

        if !hits.contains(where: { $0.name == "bossPanel" }) {
            dismissBossModeModal(animated: true)
        }
    }

    /// Launch a Boss Mode run. B2a ships SEQUENTIAL order; Mixup lands in B2b.
    private func startGauntlet() {
        guard let view = view else { return }
        AudioManager.shared.play(.bossEntrance)

        let gameScene = GameScene(size: view.bounds.size)
        gameScene.scaleMode = .resizeFill
        gameScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // If the registry can't produce a lineup there is nothing to enter —
        // stay on the title rather than presenting an empty run.
        guard gameScene.configureAsGauntlet(order: .sequential) else { return }

        let transition = SKTransition.fade(with: .black, duration: 0.35)
        view.presentScene(gameScene, transition: transition)
    }

    private func dismissBossModeModal(animated: Bool) {
        guard let modal = bossModeModal else { return }
        bossModeModal = nil
        if animated {
            modal.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.15), SKAction.removeFromParent()]))
        } else {
            modal.removeFromParent()
        }
    }

    // MARK: - v2.0 Unit 1: Skins wardrobe

    private static let skinPanelW: CGFloat = 336
    private static let skinCardH: CGFloat = 84
    private static let skinCardGap: CGFloat = 8

    /// Y-center of skin card `i`, given the panel's top edge.
    private func skinCardCenterY(_ i: Int, panelTop: CGFloat) -> CGFloat {
        let firstTop = panelTop - 86          // below title + subtitle
        return firstTop - Self.skinCardH / 2 - CGFloat(i) * (Self.skinCardH + Self.skinCardGap)
    }

    /// A tiny static Spark, drawn from a skin palette — the wardrobe preview.
    /// Same layered look as PlayerNode, no physics/trail (cheap + self-contained).
    private func makeSkinPreview(_ a: SkinAppearance) -> SKNode {
        let node = SKNode()
        let R: CGFloat = 13
        let glow = SKShapeNode(circleOfRadius: R + 7)
        glow.fillColor = SKColor(hex: a.glowColorHex, alpha: min(0.3 * a.glowBoost, 0.6))
        glow.strokeColor = .clear
        glow.glowWidth = 6
        node.addChild(glow)
        let core = SKShapeNode(circleOfRadius: R)
        core.fillColor = SKColor(hex: a.coreColorHex)
        core.strokeColor = .clear
        node.addChild(core)
        let inner = SKShapeNode(circleOfRadius: R * 0.55)
        inner.fillColor = SKColor(hex: a.innerCoreColorHex)
        inner.strokeColor = .clear
        inner.blendMode = .add
        node.addChild(inner)
        for side in [CGFloat(-1), 1] {
            let eye = SKShapeNode(circleOfRadius: R * 0.17)
            eye.fillColor = SKColor(hex: a.eyeColorHex)
            eye.strokeColor = .clear
            eye.position = CGPoint(x: side * R * 0.26, y: R * 0.14)
            node.addChild(eye)
        }
        return node
    }

    /// Dispatcher: family HUB (skinPickerFamily == nil) or a family's DETAIL.
    /// Mirrors the Forge Path hub→detail nav (consistent interaction language).
    private func showSkinPickerModal() {
        dismissSkinPickerModal(animated: false)   // never stack on refresh
        AudioManager.shared.play(.cardSelect)

        let modal = SKNode()
        modal.zPosition = 300
        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.8)
        dim.strokeColor = .clear
        modal.addChild(dim)

        if let fid = skinPickerFamily {
            renderSkinFamilyDetail(fid, into: modal)
        } else {
            renderSkinHub(into: modal)
        }

        addChild(modal)
        skinPickerModal = modal
        modal.alpha = 0
        modal.run(SKAction.fadeIn(withDuration: 0.18))
        if let panel = modal.childNode(withName: "skinPanel") {
            panel.setScale(0.9)
            let pop = SKAction.scale(to: 1.0, duration: 0.18); pop.timingMode = .easeOut
            panel.run(pop)
        }
        if skinPickerFamily != nil { loadSkinPremiumPrices() }   // detail-only
    }

    private func makeSkinPanel(h: CGFloat) -> SKShapeNode {
        let panel = SKShapeNode(rectOf: CGSize(width: Self.skinPanelW, height: h), cornerRadius: 14)
        panel.fillColor = SKColor(hex: 0x161009)
        panel.strokeColor = SKColor(hex: 0xE8B04C, alpha: 0.7)
        panel.lineWidth = 1.5
        panel.glowWidth = 5
        panel.name = "skinPanel"
        return panel
    }

    private func addSkinHeader(to modal: SKNode, top: CGFloat, title: String, sub: String) {
        let t = SKLabelNode(fontNamed: "Menlo-Bold")
        t.text = title; t.fontSize = 18; t.fontColor = SKColor(hex: 0xF0C070)
        t.verticalAlignmentMode = .center; t.position = CGPoint(x: 0, y: top - 26)
        modal.addChild(t)
        let s = SKLabelNode(fontNamed: "Menlo")
        s.text = sub; s.fontSize = 10.5; s.fontColor = SKColor(hex: 0x999999)
        s.verticalAlignmentMode = .center; s.position = CGPoint(x: 0, y: top - 48)
        modal.addChild(s)
    }

    private func addSkinFooter(to modal: SKNode, top: CGFloat) {
        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "tap outside to close"; hint.fontSize = 10; hint.fontColor = SKColor(hex: 0x666666)
        hint.verticalAlignmentMode = .center; hint.position = CGPoint(x: 0, y: -top + 22)
        modal.addChild(hint)
        #if DEBUG
        let sm = SkinManager.shared
        let dbg = SKLabelNode(fontNamed: "Menlo-Bold")
        dbg.text = sm.debugUnlockAll ? "[debug] unlock-all: ON" : "[debug] unlock-all: off"
        dbg.fontSize = 10
        dbg.fontColor = SKColor(hex: sm.debugUnlockAll ? 0x8FE08F : 0x775544)
        dbg.verticalAlignmentMode = .center; dbg.position = CGPoint(x: 0, y: -top + 44)
        dbg.name = "skinDebugToggle"
        modal.addChild(dbg)
        #endif
    }

    /// HUB — a chip per skin family; secret families masked as ???.
    private func renderSkinHub(into modal: SKNode) {
        let sm = SkinManager.shared
        let fams = sm.families
        let panelW = Self.skinPanelW
        let chipH: CGFloat = 74, gap: CGFloat = 10
        let panelH = 86 + CGFloat(fams.count) * (chipH + gap) + 66
        modal.addChild(makeSkinPanel(h: panelH))
        let top = panelH / 2
        addSkinHeader(to: modal, top: top, title: "✦ SKINS", sub: "cosmetic only — never changes gameplay")

        for (i, fam) in fams.enumerated() {
            let cy = top - 86 - chipH / 2 - CGFloat(i) * (chipH + gap)
            let revealed = sm.isFamilyRevealed(fam)

            let chip = SKShapeNode(rectOf: CGSize(width: panelW - 32, height: chipH), cornerRadius: 10)
            chip.fillColor = SKColor(hex: 0x140E06)
            chip.strokeColor = SKColor(hex: 0xE8B04C, alpha: revealed ? 0.55 : 0.3)
            chip.lineWidth = 1.4
            chip.position = CGPoint(x: 0, y: cy)
            if revealed { chip.name = "skinFamily_\(fam.id)" }
            modal.addChild(chip)

            if revealed, let flagship = sm.skins(in: fam.id).first(where: { sm.isUnlocked($0) }) ?? sm.skins(in: fam.id).first {
                let pv = makeSkinPreview(flagship.appearance)
                pv.position = CGPoint(x: -panelW / 2 + 46, y: cy)
                modal.addChild(pv)
            } else if !revealed {
                let q = SKLabelNode(fontNamed: "Menlo-Bold")
                q.text = "?"; q.fontSize = 28; q.fontColor = SKColor(hex: 0x6A5A3A)
                q.verticalAlignmentMode = .center; q.horizontalAlignmentMode = .center
                q.position = CGPoint(x: -panelW / 2 + 46, y: cy)
                modal.addChild(q)
            }

            let name = SKLabelNode(fontNamed: "Menlo-Bold")
            name.text = revealed ? fam.name : "???"
            name.fontSize = 15
            name.fontColor = revealed ? SKColor(hex: 0xF2E4C8) : SKColor(hex: 0x8A8070)
            name.verticalAlignmentMode = .center; name.horizontalAlignmentMode = .left
            name.position = CGPoint(x: -panelW / 2 + 78, y: cy + 12)
            modal.addChild(name)

            let sub = SKLabelNode(fontNamed: "Menlo")
            sub.text = revealed ? "\(sm.ownedCount(in: fam.id)) / \(sm.skins(in: fam.id).count) owned   ›" : "locked"
            sub.fontSize = 10; sub.fontColor = SKColor(hex: 0x9A8E78)
            sub.verticalAlignmentMode = .center; sub.horizontalAlignmentMode = .left
            sub.position = CGPoint(x: -panelW / 2 + 78, y: cy - 12)
            modal.addChild(sub)
        }
        addSkinFooter(to: modal, top: top)
    }

    /// DETAIL — the skins within one family, with a back button.
    private func renderSkinFamilyDetail(_ familyID: String, into modal: SKNode) {
        let sm = SkinManager.shared
        let skins = sm.skins(in: familyID)
        let panelH = 86 + CGFloat(skins.count) * (Self.skinCardH + Self.skinCardGap) + 66
        modal.addChild(makeSkinPanel(h: panelH))
        let top = panelH / 2
        addSkinHeader(to: modal, top: top, title: sm.family(familyID)?.name ?? "Skins",
                      sub: "cosmetic only — never changes gameplay")

        let back = SKLabelNode(fontNamed: "Menlo-Bold")
        back.text = "‹ back"; back.fontSize = 12; back.fontColor = SKColor(hex: 0xE8B04C)
        back.horizontalAlignmentMode = .left; back.verticalAlignmentMode = .center
        back.position = CGPoint(x: -Self.skinPanelW / 2 + 16, y: top - 26)
        back.name = "skinBack"
        modal.addChild(back)

        for (i, def) in skins.enumerated() {
            renderSkinCard(def, index: i, panelTop: top, into: modal)
        }
        addSkinFooter(to: modal, top: top)
    }

    private func renderSkinCard(_ def: SkinDefinition, index i: Int, panelTop top: CGFloat, into modal: SKNode) {
        let sm = SkinManager.shared
        let panelW = Self.skinPanelW
        let cy = skinCardCenterY(i, panelTop: top)
        let owned = sm.isUnlocked(def)
        let selected = owned && sm.selectedID == def.id
        let masked = (sm.family(def.familyID)?.secret ?? false) && !owned

        let card = SKShapeNode(rectOf: CGSize(width: panelW - 32, height: Self.skinCardH), cornerRadius: 10)
        card.fillColor = SKColor(hex: selected ? 0x241B0E : 0x120D08)
        card.strokeColor = selected ? SKColor(hex: 0xF0C070, alpha: 0.9)
                                    : SKColor(hex: def.tier == .premium ? 0x6AA0E0 : 0x5A4A2E,
                                              alpha: owned ? 0.6 : 0.35)
        card.lineWidth = selected ? 2 : 1.2
        card.position = CGPoint(x: 0, y: cy)
        card.name = "skinCard_\(def.id)"
        modal.addChild(card)

        if masked {
            let q = SKLabelNode(fontNamed: "Menlo-Bold")
            q.text = "?"; q.fontSize = 26; q.fontColor = SKColor(hex: 0x6A5A3A)
            q.verticalAlignmentMode = .center; q.horizontalAlignmentMode = .center
            q.position = CGPoint(x: -panelW / 2 + 46, y: cy)
            modal.addChild(q)
        } else {
            let pv = makeSkinPreview(def.appearance)
            pv.position = CGPoint(x: -panelW / 2 + 46, y: cy)
            if !owned { pv.alpha = 0.4 }
            modal.addChild(pv)
        }

        let name = SKLabelNode(fontNamed: "Menlo-Bold")
        name.text = masked ? "???" : def.name + (def.tier == .premium ? "  ◆" : "")
        name.fontSize = 14
        name.fontColor = owned ? SKColor(hex: 0xF2E4C8) : SKColor(hex: 0x8A8070)
        name.verticalAlignmentMode = .center; name.horizontalAlignmentMode = .left
        name.position = CGPoint(x: -panelW / 2 + 78, y: cy + 18)
        modal.addChild(name)

        let blurb = SKLabelNode(fontNamed: "Menlo")
        blurb.text = masked ? "???" : def.blurb
        blurb.fontSize = 8.5; blurb.fontColor = SKColor(hex: 0x8A8478)
        blurb.verticalAlignmentMode = .center; blurb.horizontalAlignmentMode = .left
        blurb.position = CGPoint(x: -panelW / 2 + 78, y: cy - 1)
        modal.addChild(blurb)

        let status = SKLabelNode(fontNamed: "Menlo-Bold")
        status.fontSize = 10.5
        status.verticalAlignmentMode = .center; status.horizontalAlignmentMode = .left
        status.position = CGPoint(x: -panelW / 2 + 78, y: cy - 22)
        status.name = "skinStatus_\(def.id)"
        if selected {
            status.text = "✓ EQUIPPED";  status.fontColor = SKColor(hex: 0x8FE08F)
        } else if owned {
            status.text = "tap to equip"; status.fontColor = SKColor(hex: 0xF0C070)
        } else if masked {
            status.text = "🔒 ???";       status.fontColor = SKColor(hex: 0x8A8070)
        } else if def.tier == .earned {
            status.text = "🔒 locked";    status.fontColor = SKColor(hex: 0x8A8070)
        } else {
            status.text = "◆ premium";    status.fontColor = SKColor(hex: 0x6AA0E0)
        }
        modal.addChild(status)
    }

    /// Async-load StoreKit prices for premium skins and update their chips
    /// (mirrors loadRemoveAdsPrice — StoreKit is the source of truth).
    private func loadSkinPremiumPrices() {
        for def in SkinManager.shared.catalog where def.tier == .premium {
            guard let pid = def.iapProductID, !SkinManager.shared.isUnlocked(def) else { continue }
            Task { @MainActor in
                guard let price = await IAPManager.shared.displayPrice(for: pid),
                      let chip = skinPickerModal?.childNode(withName: "skinStatus_\(def.id)") as? SKLabelNode
                else { return }
                chip.text = "◆ \(price) · tap to buy"
                chip.fontColor = SKColor(hex: 0x6AA0E0)
            }
        }
    }

    private func handleSkinPickerTap(_ location: CGPoint) {
        let sm = SkinManager.shared
        guard skinPickerModal != nil else { return }
        // Named-node hit-testing (nodes-at-point) — no geometry to keep in sync
        // with the renderers, and it works for both hub + detail layouts.
        let hit = nodes(at: location)

        #if DEBUG
        if hit.contains(where: { $0.name == "skinDebugToggle" }) {
            sm.debugUnlockAll.toggle(); showSkinPickerModal(); return
        }
        #endif

        // Detail → hub.
        if hit.contains(where: { $0.name == "skinBack" }) {
            skinPickerFamily = nil; showSkinPickerModal(); return
        }

        // Hub → family detail.
        if let chip = hit.first(where: { ($0.name ?? "").hasPrefix("skinFamily_") }) {
            skinPickerFamily = String((chip.name ?? "").dropFirst("skinFamily_".count))
            showSkinPickerModal(); return
        }

        // Detail: a skin card — equip (owned), buy (premium), or soft-nudge (locked).
        if let card = hit.first(where: { ($0.name ?? "").hasPrefix("skinCard_") }),
           let def = sm.definition(String((card.name ?? "").dropFirst("skinCard_".count))) {
            if sm.isUnlocked(def) {
                if sm.selectedID != def.id { sm.select(def.id); showSkinPickerModal() }
            } else if def.tier == .premium {
                purchaseSkin(def)
            } else {
                AudioManager.shared.play(.orbPickup)   // locked earned — soft nudge
            }
            return
        }

        // Tap off the panel closes the whole modal.
        if !hit.contains(where: { $0.name == "skinPanel" }) {
            dismissSkinPickerModal(animated: true)
        }
    }

    private func purchaseSkin(_ def: SkinDefinition) {
        guard let pid = def.iapProductID else { return }
        if let chip = skinPickerModal?.childNode(withName: "skinStatus_\(def.id)") as? SKLabelNode {
            chip.text = "purchasing…"; chip.fontColor = SKColor(hex: 0xCCCCCC)
        }
        Task { @MainActor in
            let ok = await IAPManager.shared.purchase(pid)
            if ok { SkinManager.shared.select(def.id) }
            if skinPickerModal != nil { showSkinPickerModal() }   // reflect owned/equipped
        }
    }

    private func dismissSkinPickerModal(animated: Bool) {
        guard let modal = skinPickerModal else { return }
        skinPickerModal = nil
        if animated {
            skinPickerFamily = nil   // real close (not a refresh) → reopen at the hub
            modal.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.15), SKAction.removeFromParent()]))
        } else {
            modal.removeFromParent()
        }
    }

    private func makeConfirmModal(title: String, titleHex: UInt32, message: String,
                                  confirm: (text: String, name: String, fill: UInt32),
                                  cancel cancelName: String) -> SKNode {
        let node = SKNode()
        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.8)
        dim.strokeColor = .clear
        node.addChild(dim)

        let lines = wrapPlain(message, maxChars: 30)
        let panelH: CGFloat = 190 + CGFloat(lines.count) * 20
        let panel = SKShapeNode(rectOf: CGSize(width: 316, height: panelH), cornerRadius: 14)
        panel.fillColor = SKColor(hex: 0x141018)
        panel.strokeColor = SKColor(hex: 0xC0392B, alpha: 0.75)
        panel.lineWidth = 1.5
        panel.glowWidth = 4
        node.addChild(panel)

        let titleLabel = UITheme.label(title, size: UITheme.Size.heading, color: SKColor(hex: titleHex), bold: true)
        titleLabel.position = CGPoint(x: 0, y: panelH / 2 - 34)
        node.addChild(titleLabel)

        var y = panelH / 2 - 68
        for line in lines {
            let l = UITheme.label(line, size: UITheme.Size.body, color: UITheme.Color.infoSoft)
            l.position = CGPoint(x: 0, y: y)
            node.addChild(l)
            y -= 20
        }

        node.addChild(modalButton(name: confirm.name, text: confirm.text, y: -panelH / 2 + 94,
                                  fill: confirm.fill, stroke: 0xE74C3C, textHex: 0xFFFFFF))
        node.addChild(modalButton(name: cancelName, text: "CANCEL", y: -panelH / 2 + 38,
                                  fill: 0x333333, stroke: 0x888888, textHex: 0xE0E0E0))
        return node
    }

    private func modalButton(name: String, text: String, y: CGFloat,
                             fill: UInt32, stroke: UInt32, textHex: UInt32) -> SKNode {
        let size = CGSize(width: 240, height: 42)
        let btn = SKNode()
        btn.name = name
        btn.position = CGPoint(x: 0, y: y)
        btn.userData = NSMutableDictionary(dictionary: ["w": size.width, "h": size.height])
        let bg = SKShapeNode(rectOf: size, cornerRadius: 6)
        bg.fillColor = SKColor(hex: fill)
        bg.strokeColor = SKColor(hex: stroke, alpha: 0.7)
        bg.lineWidth = 1
        btn.addChild(bg)
        let label = UITheme.label(text, size: UITheme.Size.body, color: SKColor(hex: textHex), bold: true)
        label.name = "label"
        label.verticalAlignmentMode = .center
        btn.addChild(label)
        return btn
    }

    private func addEraseTextField() {
        guard let view = view else { return }
        // Center on the input outline at scene y = 13: view.midY - 13 (center),
        // minus half the 36pt height for the frame origin.
        let tf = UITextField(frame: CGRect(x: view.bounds.midX - 90, y: view.bounds.midY - 31,
                                           width: 180, height: 36))
        tf.backgroundColor = UIColor(white: 0.06, alpha: 1)
        tf.textColor = .white
        tf.tintColor = UIColor(red: 0.9, green: 0.3, blue: 0.24, alpha: 1)
        tf.textAlignment = .center
        tf.font = UIFont(name: "Menlo-Bold", size: 18)
        tf.autocapitalizationType = .allCharacters
        tf.autocorrectionType = .no
        tf.attributedPlaceholder = NSAttributedString(
            string: "type ERASE",
            attributes: [.foregroundColor: UIColor(white: 0.4, alpha: 1)])
        tf.layer.cornerRadius = 6
        tf.addTarget(self, action: #selector(eraseTextChanged), for: .editingChanged)
        view.addSubview(tf)
        tf.becomeFirstResponder()
        eraseTextField = tf
    }

    private func removeEraseTextField() {
        eraseTextField?.resignFirstResponder()
        eraseTextField?.removeFromSuperview()
        eraseTextField = nil
    }

    @objc private func eraseTextChanged() {
        let matches = (eraseTextField?.text ?? "").uppercased() == "ERASE"
        guard let btn = eraseConfirmButton,
              let bg = btn.children.compactMap({ $0 as? SKShapeNode }).first else { return }
        bg.fillColor = SKColor(hex: matches ? 0xC0392B : 0x3A2422)
        (btn.childNode(withName: "label") as? SKLabelNode)?.fontColor = SKColor(hex: matches ? 0xFFFFFF : 0x886666)
    }

    /// Char-count word wrap (matches the codex/detail wrap style).
    private func wrapPlain(_ text: String, maxChars: Int) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            if current.isEmpty { current = String(word) }
            else if current.count + 1 + word.count <= maxChars { current += " " + word }
            else { lines.append(current); current = String(word) }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
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
        title.fontSize = 18
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
        randomLabel.fontSize = 15
        randomLabel.fontColor = SKColor(hex: 0xFFAA33)
        randomLabel.verticalAlignmentMode = .center
        randomLabel.position = CGPoint(x: 0, y: 36)
        modal.addChild(randomLabel)

        let randomSub = SKLabelNode(fontNamed: "Menlo")
        randomSub.text = "free"
        randomSub.fontSize = 11
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
        chooseLabel.fontSize = 14
        chooseLabel.fontColor = SKColor(hex: 0x44BBFF)
        chooseLabel.verticalAlignmentMode = .center
        chooseLabel.position = CGPoint(x: 0, y: -26)
        modal.addChild(chooseLabel)

        let chooseSub = SKLabelNode(fontNamed: "Menlo")
        chooseSub.name = "chooseSubLabel"
        chooseSub.text = adsRemoved ? "ad-free — you own the forge" : "watch a short ad"
        chooseSub.fontSize = 11
        chooseSub.fontColor = SKColor(hex: 0x888888)
        chooseSub.verticalAlignmentMode = .center
        chooseSub.position = CGPoint(x: 0, y: -42)
        modal.addChild(chooseSub)

        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "tap outside to cancel"
        hint.fontSize = 11
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
        title.fontSize = 16
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
            name.fontSize = 15
            name.fontColor = SKColor(hex: 0xFFAA33)
            name.verticalAlignmentMode = .center
            name.horizontalAlignmentMode = .left
            name.position = CGPoint(x: -88, y: y + 8)
            modal.addChild(name)

            let desc = SKLabelNode(fontNamed: "Menlo")
            desc.text = blessing.description
            desc.fontSize = 11
            // v1.7: choice-driving text pops (readability canon, July 10)
            desc.fontColor = SKColor(hex: 0xFFFFFF)
            desc.verticalAlignmentMode = .center
            desc.horizontalAlignmentMode = .left
            desc.position = CGPoint(x: -88, y: y - 9)
            modal.addChild(desc)
        }

        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "your forge, your choice"
        hint.fontSize = 11
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

    // v1.9 Unit 3: two-level nav layout.
    // Hub — three stacked mastery chips.
    private static let forgeHubPanelW: CGFloat = 322
    private static let forgeHubPanelH: CGFloat = 476
    private static let forgeHubChipYs: [CGFloat] = [108, 8, -92]
    private static let forgeHubChipW: CGFloat = 288
    private static let forgeHubChipH: CGFloat = 92
    private static let forgeHubRespecY: CGFloat = -186
    // Detail — one branch's zoomed ladder of node-chips.
    private static let forgeDetailPanelW: CGFloat = 344
    private static let forgeDetailPanelH: CGFloat = 566
    private static let forgeDetailRowTop: CGFloat = 208
    private static let forgeDetailRowStep: CGFloat = 24
    private static let forgeDetailChipW: CGFloat = 300
    private static let forgeDetailChipH: CGFloat = 21
    private static let forgeDetailChipCX: CGFloat = 14        // chip center x
    private static let forgeDetailRailX: CGFloat = -150       // pip rail / trunk x
    private static let forgeDetailBackY: CGFloat = 250

    private func forgeDetailRowY(_ level: Int) -> CGFloat {
        Self.forgeDetailRowTop - CGFloat(level - 1) * Self.forgeDetailRowStep
    }

    /// A compact "accumulated stats" string for a branch's owned nodes.
    private func forgeBranchAccrued(_ branch: ForgePathManager.Branch) -> String {
        let fpm = ForgePathManager.shared
        let count = fpm.countInBranch(branch)
        guard count > 0 else { return "no nodes yet — tap ＋ to invest" }
        var parts: [String] = []
        for lvl in 1...count {
            guard let node = fpm.ladderNode(branch, level: lvl) else { continue }
            if let fork = node.fork {
                parts.append((fpm.forkChoiceIsB(branch, level: lvl) ? fork.b : fork.a).effectText)
            } else {
                parts.append(node.effectText)
            }
        }
        return parts.joined(separator: "  ·  ")
    }

    // MARK: Forge Path — entry + render dispatch

    /// Entry point (from the title row): always opens fresh at the hub.
    private func showForgePathModal() {
        forgePathDetailBranch = nil
        forgePathForkPending = nil
        renderForgePath(animateIn: true)
    }

    /// Re-render the current view (hub or detail). animateIn only on first open —
    /// internal refreshes skip the pop so taps don't glitch.
    private func renderForgePath(animateIn: Bool) {
        dismissForgePathModal(animated: false)

        let modal = SKNode()
        modal.zPosition = 300

        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.78)
        dim.strokeColor = .clear
        modal.addChild(dim)

        let panel: SKShapeNode = forgePathDetailBranch == nil
            ? buildForgeHub(into: modal)
            : buildForgeDetail(forgePathDetailBranch!, into: modal)

        // Fork picker overlay sits above whichever view is showing.
        if let branch = forgePathForkPending,
           let node = ForgePathManager.shared.nextNode(for: branch), node.fork != nil {
            renderForkPicker(branch, node: node, into: modal)
        }

        addChild(modal)
        forgePathModal = modal

        if animateIn {
            modal.alpha = 0
            panel.setScale(0.9)
            modal.run(SKAction.fadeIn(withDuration: 0.2))
            let pop = SKAction.scale(to: 1.0, duration: 0.2)
            pop.timingMode = .easeOut
            panel.run(pop)
        }
    }

    // MARK: Forge Path — hub (3 stacked mastery chips)

    private func buildForgeHub(into modal: SKNode) -> SKShapeNode {
        let fpm = ForgePathManager.shared
        let panelW = Self.forgeHubPanelW, panelH = Self.forgeHubPanelH
        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 14)
        panel.fillColor = SKColor(hex: 0x140E06)
        panel.strokeColor = SKColor(hex: 0xFFCC66, alpha: 0.7)
        panel.lineWidth = 1.5
        panel.glowWidth = 5
        modal.addChild(panel)

        let top = panelH / 2
        let n = fpm.picksAvailable

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "⚒ FORGE PATH"
        title.fontSize = 18
        title.fontColor = SKColor(hex: 0xFFCC66)
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: top - 24)
        modal.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "Menlo")
        subtitle.text = n > 0 ? "\(n) mastery point\(n == 1 ? "" : "s") to spend"
                              : "earn mastery points by leveling the Forge"
        subtitle.fontSize = 11
        subtitle.fontColor = n > 0 ? SKColor(hex: 0xFFCC66) : SKColor(hex: 0x999999)
        subtitle.verticalAlignmentMode = .center
        subtitle.position = CGPoint(x: 0, y: top - 44)
        modal.addChild(subtitle)

        for (i, branch) in ForgePathManager.Branch.allCases.enumerated() {
            buildForgeHubChip(branch, y: Self.forgeHubChipYs[i], spendable: n > 0, into: modal)
        }

        // Free respec.
        if !fpm.picks.isEmpty {
            let count = fpm.picks.count
            let respec = SKShapeNode(rectOf: CGSize(width: 288, height: 36), cornerRadius: 8)
            respec.fillColor = SKColor(hex: 0x3A2018)
            respec.strokeColor = SKColor(hex: 0xE0884C, alpha: 0.8)
            respec.lineWidth = 1.5
            respec.position = CGPoint(x: 0, y: Self.forgeHubRespecY)
            respec.name = "respecButton"
            modal.addChild(respec)

            let respecLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            respecLabel.text = "↺ RESPEC \(count) POINT\(count == 1 ? "" : "S")  ·  FREE"
            respecLabel.fontSize = 12
            respecLabel.fontColor = SKColor(hex: 0xF0B080)
            respecLabel.verticalAlignmentMode = .center
            respecLabel.position = CGPoint(x: 0, y: Self.forgeHubRespecY)
            modal.addChild(respecLabel)
        }

        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "tap a mastery to expand  ·  tap outside to close"
        hint.fontSize = 9.5
        hint.fontColor = SKColor(hex: 0x666666)
        hint.verticalAlignmentMode = .center
        hint.position = CGPoint(x: 0, y: -top + 16)
        modal.addChild(hint)

        return panel
    }

    private func buildForgeHubChip(_ branch: ForgePathManager.Branch, y: CGFloat,
                                   spendable: Bool, into modal: SKNode) {
        let fpm = ForgePathManager.shared
        let color = SKColor(hex: branch.colorHex)
        let count = fpm.countInBranch(branch)
        let maxed = count >= ForgePathManager.ladderLength
        let w = Self.forgeHubChipW, h = Self.forgeHubChipH

        let chip = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 10)
        chip.fillColor = SKColor(hex: 0x161616)
        chip.strokeColor = color.withAlphaComponent(0.7)
        chip.lineWidth = 1.5
        chip.position = CGPoint(x: 0, y: y)
        modal.addChild(chip)

        let wash = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 10)
        wash.fillColor = color.withAlphaComponent(0.10)
        wash.strokeColor = .clear
        wash.position = CGPoint(x: 0, y: y)
        modal.addChild(wash)

        let icon = SKLabelNode(text: branch.icon)
        icon.fontSize = 24
        icon.verticalAlignmentMode = .center
        icon.position = CGPoint(x: -w / 2 + 26, y: y + 18)
        modal.addChild(icon)

        let name = SKLabelNode(fontNamed: "Menlo-Bold")
        name.text = "\(branch.rawValue.uppercased())   ×\(count)"
        name.fontSize = 14
        name.fontColor = color
        name.verticalAlignmentMode = .center
        name.horizontalAlignmentMode = .left
        name.position = CGPoint(x: -w / 2 + 50, y: y + 26)
        modal.addChild(name)

        // Accumulated stats — wraps to a couple lines inside the chip.
        let accrued = SKLabelNode(fontNamed: "Menlo")
        accrued.text = forgeBranchAccrued(branch)
        accrued.fontSize = 9
        accrued.fontColor = SKColor(hex: 0xBBBBBB)
        accrued.horizontalAlignmentMode = .left
        accrued.verticalAlignmentMode = .top
        accrued.numberOfLines = 3
        accrued.lineBreakMode = .byTruncatingTail
        accrued.preferredMaxLayoutWidth = w - 74
        accrued.position = CGPoint(x: -w / 2 + 14, y: y + 12)
        modal.addChild(accrued)

        // ＋ add-points button (quick invest without leaving the hub).
        if spendable && !maxed {
            let plusBg = SKShapeNode(circleOfRadius: 15)
            plusBg.fillColor = color.withAlphaComponent(0.18)
            plusBg.strokeColor = color
            plusBg.lineWidth = 1.5
            plusBg.position = CGPoint(x: w / 2 - 24, y: y)
            plusBg.name = "hubPlus_\(branch.rawValue)"
            modal.addChild(plusBg)
            let plus = SKLabelNode(fontNamed: "Menlo-Bold")
            plus.text = "＋"
            plus.fontSize = 18
            plus.fontColor = color
            plus.verticalAlignmentMode = .center
            plus.position = CGPoint(x: w / 2 - 24, y: y)
            modal.addChild(plus)
        } else if maxed {
            let done = SKLabelNode(fontNamed: "Menlo-Bold")
            done.text = "MAX"
            done.fontSize = 10
            done.fontColor = color
            done.verticalAlignmentMode = .center
            done.position = CGPoint(x: w / 2 - 26, y: y)
            modal.addChild(done)
        }
    }

    // MARK: Forge Path — detail (one branch, zoomed ladder of node-chips)

    private func buildForgeDetail(_ branch: ForgePathManager.Branch, into modal: SKNode) -> SKShapeNode {
        let fpm = ForgePathManager.shared
        let color = SKColor(hex: branch.colorHex)
        let count = fpm.countInBranch(branch)
        let nextLevel = count + 1
        let n = fpm.picksAvailable
        let panelW = Self.forgeDetailPanelW, panelH = Self.forgeDetailPanelH

        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 14)
        panel.fillColor = SKColor(hex: 0x120C05)
        panel.strokeColor = color.withAlphaComponent(0.75)
        panel.lineWidth = 1.5
        panel.glowWidth = 5
        modal.addChild(panel)

        let top = panelH / 2

        // Back button.
        let back = SKLabelNode(fontNamed: "Menlo-Bold")
        back.text = "‹ BACK"
        back.fontSize = 13
        back.fontColor = SKColor(hex: 0xFFCC66)
        back.horizontalAlignmentMode = .left
        back.verticalAlignmentMode = .center
        back.position = CGPoint(x: -panelW / 2 + 18, y: Self.forgeDetailBackY)
        back.name = "forgeBack"
        modal.addChild(back)

        let icon = SKLabelNode(text: branch.icon)
        icon.fontSize = 18
        icon.verticalAlignmentMode = .center
        icon.position = CGPoint(x: -18, y: top - 24)
        modal.addChild(icon)
        let hdr = SKLabelNode(fontNamed: "Menlo-Bold")
        hdr.text = "\(branch.rawValue.uppercased())  ×\(count)"
        hdr.fontSize = 15
        hdr.fontColor = color
        hdr.horizontalAlignmentMode = .left
        hdr.verticalAlignmentMode = .center
        hdr.position = CGPoint(x: 0, y: top - 24)
        modal.addChild(hdr)

        let sub = SKLabelNode(fontNamed: "Menlo")
        sub.text = n > 0 ? "\(n) point\(n == 1 ? "" : "s") available — tap the next node to invest"
                         : "no points to spend"
        sub.fontSize = 9.5
        sub.fontColor = n > 0 ? color : SKColor(hex: 0x888888)
        sub.verticalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: top - 44)
        modal.addChild(sub)

        // Trunk line behind the chips.
        let trunk = SKShapeNode()
        let tp = CGMutablePath()
        tp.move(to: CGPoint(x: Self.forgeDetailRailX, y: forgeDetailRowY(1)))
        tp.addLine(to: CGPoint(x: Self.forgeDetailRailX, y: forgeDetailRowY(ForgePathManager.ladderLength)))
        trunk.path = tp
        trunk.strokeColor = color.withAlphaComponent(0.3)
        trunk.lineWidth = 2
        modal.addChild(trunk)

        for level in 1...ForgePathManager.ladderLength {
            buildForgeDetailRow(branch, level: level, owned: level <= count,
                                isNext: level == nextLevel, spendable: n > 0, into: modal)
        }

        return panel
    }

    private func buildForgeDetailRow(_ branch: ForgePathManager.Branch, level: Int, owned: Bool,
                                     isNext: Bool, spendable: Bool, into modal: SKNode) {
        let fpm = ForgePathManager.shared
        let color = SKColor(hex: branch.colorHex)
        guard let node = fpm.ladderNode(branch, level: level) else { return }
        let ry = forgeDetailRowY(level)
        let railX = Self.forgeDetailRailX

        // Rail pip.
        let pip = SKShapeNode(circleOfRadius: 4)
        pip.position = CGPoint(x: railX, y: ry)
        if owned {
            pip.fillColor = color; pip.strokeColor = color; pip.glowWidth = 2
        } else {
            pip.fillColor = SKColor(hex: 0x0A0A0A); pip.strokeColor = color.withAlphaComponent(0.4); pip.lineWidth = 1
        }
        modal.addChild(pip)
        if isNext {
            let ring = SKShapeNode(circleOfRadius: 7)
            ring.strokeColor = color; ring.fillColor = .clear; ring.lineWidth = 1.5; ring.glowWidth = 3
            ring.position = CGPoint(x: railX, y: ry)
            ring.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: 1.3, duration: 0.6), SKAction.scale(to: 1.0, duration: 0.6)])))
            modal.addChild(ring)
        }

        // Node chip.
        let w = Self.forgeDetailChipW, h = Self.forgeDetailChipH, cx = Self.forgeDetailChipCX
        let isFork = node.fork != nil
        let chip = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 6)
        chip.position = CGPoint(x: cx, y: ry)
        chip.fillColor = owned ? color.withAlphaComponent(0.16)
                               : (isNext ? SKColor(hex: 0x1C1508) : SKColor(hex: 0x111111))
        chip.strokeColor = owned ? color.withAlphaComponent(0.8)
                                 : (isNext ? color : color.withAlphaComponent(0.22))
        chip.lineWidth = isNext ? 1.5 : 1
        chip.name = "forgeRow_\(branch.rawValue)_\(level)"
        modal.addChild(chip)

        // Content: forks show the chosen option + a swap tag; normal nodes show name+effect.
        let displayName: String
        let displayEffect: String
        if let fork = node.fork {
            let chosen = fpm.forkChoiceIsB(branch, level: level) ? fork.b : fork.a
            displayName = "⑂ \(chosen.name)"
            displayEffect = owned ? chosen.effectText : "choose A / B"
        } else {
            displayName = node.name
            displayEffect = node.effectText
        }

        let lvlTag = SKLabelNode(fontNamed: "Menlo-Bold")
        lvlTag.text = "\(level)"
        lvlTag.fontSize = 8.5
        lvlTag.fontColor = owned ? color : color.withAlphaComponent(0.5)
        lvlTag.horizontalAlignmentMode = .left
        lvlTag.verticalAlignmentMode = .center
        lvlTag.position = CGPoint(x: cx - w / 2 + 7, y: ry)
        modal.addChild(lvlTag)

        let nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = displayName
        nameLabel.fontSize = 9.5
        nameLabel.fontColor = owned ? SKColor(hex: 0xFFFFFF) : (isFork ? color : SKColor(hex: 0xCCCCCC))
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: cx - w / 2 + 24, y: ry)
        modal.addChild(nameLabel)

        let effLabel = SKLabelNode(fontNamed: "Menlo")
        effLabel.text = displayEffect
        effLabel.fontSize = 8.5
        effLabel.fontColor = SKColor(hex: owned ? 0xCCCCCC : 0x888888)
        effLabel.horizontalAlignmentMode = .right
        effLabel.verticalAlignmentMode = .center
        effLabel.position = CGPoint(x: cx + w / 2 - 8, y: ry)
        modal.addChild(effLabel)

        if isNext && spendable {
            let plus = SKLabelNode(fontNamed: "Menlo-Bold")
            plus.text = "＋"
            plus.fontSize = 14
            plus.fontColor = color
            plus.verticalAlignmentMode = .center
            plus.horizontalAlignmentMode = .center
            plus.position = CGPoint(x: cx + w / 2 - 8, y: ry)
            effLabel.horizontalAlignmentMode = .right
            effLabel.position = CGPoint(x: cx + w / 2 - 22, y: ry)
            modal.addChild(plus)
        }
    }

    /// The A/B fork picker overlay (shown when a spend reaches a fork).
    private func renderForkPicker(_ branch: ForgePathManager.Branch, node: ForgePathManager.Node,
                                  into modal: SKNode) {
        guard let fork = node.fork else { return }
        let color = SKColor(hex: branch.colorHex)
        let bg = SKShapeNode(rectOf: CGSize(width: 306, height: 168), cornerRadius: 12)
        bg.fillColor = SKColor(hex: 0x0C0C0C, alpha: 0.98)
        bg.strokeColor = color
        bg.lineWidth = 2
        bg.glowWidth = 6
        bg.position = CGPoint(x: 0, y: 20)
        bg.zPosition = 10
        modal.addChild(bg)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "\(branch.icon) \(node.name) — choose one"
        title.fontSize = 12
        title.fontColor = color
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 86)
        title.zPosition = 11
        modal.addChild(title)

        for (idx, opt) in [(0, fork.a), (1, fork.b)].enumerated() {
            let oy: CGFloat = idx == 0 ? 40 : -20
            let btn = SKShapeNode(rectOf: CGSize(width: 286, height: 50), cornerRadius: 8)
            btn.fillColor = SKColor(hex: 0x161616)
            btn.strokeColor = color.withAlphaComponent(0.8)
            btn.lineWidth = 1.5
            btn.position = CGPoint(x: 0, y: oy)
            btn.zPosition = 11
            btn.name = idx == 0 ? "forkA" : "forkB"
            modal.addChild(btn)
            let name = SKLabelNode(fontNamed: "Menlo-Bold")
            name.text = "\(idx == 0 ? "A" : "B") · \(opt.1.name)"
            name.fontSize = 12
            name.fontColor = color
            name.verticalAlignmentMode = .center
            name.horizontalAlignmentMode = .left
            name.position = CGPoint(x: -131, y: oy + 11)
            name.zPosition = 11
            modal.addChild(name)
            let eff = SKLabelNode(fontNamed: "Menlo")
            eff.text = opt.1.effectText
            eff.fontSize = 9.5
            eff.fontColor = SKColor(hex: 0xCCCCCC)
            eff.verticalAlignmentMode = .center
            eff.horizontalAlignmentMode = .left
            eff.numberOfLines = 2
            eff.lineBreakMode = .byTruncatingTail
            eff.preferredMaxLayoutWidth = 258
            eff.position = CGPoint(x: -131, y: oy - 9)
            eff.zPosition = 11
            modal.addChild(eff)
        }
    }

    // MARK: Forge Path — tap routing

    private func handleForgePathModalTap(_ location: CGPoint) {
        let fpm = ForgePathManager.shared

        // 1) Fork picker open — resolve A/B first (overlay wins).
        if let branch = forgePathForkPending {
            let aFrame = CGRect(x: -143, y: 40 - 25, width: 286, height: 50)
            let bFrame = CGRect(x: -143, y: -20 - 25, width: 286, height: 50)
            if aFrame.contains(location) || bFrame.contains(location) {
                fpm.choose(branch)   // advance onto the fork (defaults A)
                let level = fpm.countInBranch(branch)
                fpm.setForkChoice(branch, level: level, chooseB: bFrame.contains(location))
                forgePathForkPending = nil
                AudioManager.shared.play(.cardSelect)
                statHUDNeedsRefresh()
                renderForgePath(animateIn: false)
            } else {
                forgePathForkPending = nil   // tap elsewhere cancels the picker
                renderForgePath(animateIn: false)
            }
            return
        }

        // 2) Detail view vs hub view.
        if let branch = forgePathDetailBranch {
            handleForgeDetailTap(location, branch: branch)
        } else {
            handleForgeHubTap(location)
        }
    }

    private func handleForgeHubTap(_ location: CGPoint) {
        let fpm = ForgePathManager.shared

        // Respec (free) — behind a confirm.
        if !fpm.picks.isEmpty {
            let f = CGRect(x: -144, y: Self.forgeHubRespecY - 18, width: 288, height: 36)
            if f.contains(location) {
                AudioManager.shared.play(.cardSelect)
                presentRespecConfirm()
                return
            }
        }

        let w = Self.forgeHubChipW, h = Self.forgeHubChipH
        for (i, branch) in ForgePathManager.Branch.allCases.enumerated() {
            let y = Self.forgeHubChipYs[i]
            // ＋ add-points button (right edge).
            if fpm.picksAvailable > 0 && fpm.countInBranch(branch) < ForgePathManager.ladderLength {
                let plusF = CGRect(x: w / 2 - 24 - 18, y: y - 18, width: 36, height: 36)
                if plusF.contains(location) {
                    spendForgePoint(on: branch)
                    return
                }
            }
            // Chip body → drill into the detail view.
            let chipF = CGRect(x: -w / 2, y: y - h / 2, width: w, height: h)
            if chipF.contains(location) {
                forgePathDetailBranch = branch
                AudioManager.shared.play(.cardSelect)
                renderForgePath(animateIn: true)
                return
            }
        }

        // Tap outside the panel closes.
        let panelFrame = CGRect(x: -Self.forgeHubPanelW / 2, y: -Self.forgeHubPanelH / 2,
                                width: Self.forgeHubPanelW, height: Self.forgeHubPanelH)
        if !panelFrame.contains(location) {
            forgePathDetailBranch = nil
            forgePathForkPending = nil
            dismissForgePathModal(animated: true)
            drawForgePathRow()
        }
    }

    private func handleForgeDetailTap(_ location: CGPoint, branch: ForgePathManager.Branch) {
        let fpm = ForgePathManager.shared

        // Back → hub.
        let backF = CGRect(x: -Self.forgeDetailPanelW / 2 + 6, y: Self.forgeDetailBackY - 16, width: 84, height: 32)
        if backF.contains(location) {
            forgePathDetailBranch = nil
            AudioManager.shared.play(.cardSelect)
            renderForgePath(animateIn: true)
            return
        }

        // Tap the next node's chip to invest.
        if fpm.picksAvailable > 0 {
            let count = fpm.countInBranch(branch)
            if count < ForgePathManager.ladderLength {
                let nextLevel = count + 1
                let ry = forgeDetailRowY(nextLevel)
                let w = Self.forgeDetailChipW, h = Self.forgeDetailChipH, cx = Self.forgeDetailChipCX
                let rowF = CGRect(x: cx - w / 2, y: ry - h / 2 - 2, width: w, height: h + 4)
                if rowF.contains(location) {
                    spendForgePoint(on: branch)
                    return
                }
            }
        }

        // Tap outside the panel closes.
        let panelFrame = CGRect(x: -Self.forgeDetailPanelW / 2, y: -Self.forgeDetailPanelH / 2,
                                width: Self.forgeDetailPanelW, height: Self.forgeDetailPanelH)
        if !panelFrame.contains(location) {
            forgePathDetailBranch = nil
            forgePathForkPending = nil
            dismissForgePathModal(animated: true)
            drawForgePathRow()
        }
    }

    /// Spend one mastery point on a branch — opens the fork picker if the next
    /// node is a fork, otherwise commits immediately. Stays in the current view.
    private func spendForgePoint(on branch: ForgePathManager.Branch) {
        let fpm = ForgePathManager.shared
        guard fpm.picksAvailable > 0, fpm.countInBranch(branch) < ForgePathManager.ladderLength else { return }
        if let next = fpm.nextNode(for: branch), next.fork != nil {
            forgePathForkPending = branch
            AudioManager.shared.play(.cardSelect)
            renderForgePath(animateIn: false)
        } else {
            fpm.choose(branch)
            AudioManager.shared.play(.cardSelect)
            statHUDNeedsRefresh()
            renderForgePath(animateIn: false)
        }
    }

    /// Forge picks alter persisted stats; nudge any live stat readout. No-op hook
    /// on the title screen (kept for parity with the in-run HUD path).
    private func statHUDNeedsRefresh() {}

    // v1.9 Unit 7: free respec, behind a confirm (reuses the confirm modal).
    private func presentRespecConfirm() {
        let n = ForgePathManager.shared.picks.count
        let node = makeConfirmModal(
            title: "↺  RESPEC", titleHex: 0xF0B080,
            message: "Refund all \(n) mastery point\(n == 1 ? "" : "s") to re-spend? This is free.",
            confirm: ("RESPEC", "respecConfirmBtn", 0xC0392B), cancel: "respecCancelBtn")
        node.zPosition = 320
        addChild(node)
        node.alpha = 0
        node.run(SKAction.fadeIn(withDuration: 0.12))
        respecConfirmModal = node
    }

    private func handleRespecConfirmTap(_ location: CGPoint) {
        guard let modal = respecConfirmModal else { return }
        let hit = modal.children.first { node in
            guard let w = node.userData?["w"] as? CGFloat,
                  let h = node.userData?["h"] as? CGFloat else { return false }
            return CGRect(x: node.position.x - w / 2, y: node.position.y - h / 2,
                          width: w, height: h).contains(location)
        }
        switch hit?.name {
        case "respecConfirmBtn":
            ForgePathManager.shared.respec()
            AudioManager.shared.play(.cardSelect)
            dismissRespecConfirm()
            showForgePathModal()   // refresh — all mastery points now available
        case "respecCancelBtn":
            dismissRespecConfirm()
        default:
            break
        }
    }

    private func dismissRespecConfirm() {
        respecConfirmModal?.removeFromParent()
        respecConfirmModal = nil
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
        name.fontSize = 20
        name.fontColor = SKColor(hex: 0xFFAA33)
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: 8)
        modal.addChild(name)

        let desc = SKLabelNode(fontNamed: "Menlo")
        desc.text = blessing.description
        desc.fontSize = 14
        desc.fontColor = SKColor(hex: 0x66AA66)
        desc.verticalAlignmentMode = .center
        desc.position = CGPoint(x: 0, y: -20)
        modal.addChild(desc)

        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "tap to continue"
        hint.fontSize = 12
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
            blessingActiveLabel.fontSize = 14
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
        // v1.7: browsing a locked arena — the forge won't ignite here.
        // Nudge the requirement line instead of starting.
        if displayedArenaIndex >= ProgressionManager.shared.arenasUnlocked {
            let nudge = SKAction.sequence([
                SKAction.moveBy(x: 6, y: 0, duration: 0.05),
                SKAction.moveBy(x: -12, y: 0, duration: 0.08),
                SKAction.moveBy(x: 6, y: 0, duration: 0.05)
            ])
            arenaReadyLabel.run(nudge)
            return
        }

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
    
    // Localized Remove Ads price from StoreKit (e.g. "$3.99"); nil until the
    // product loads. Never hardcode the price — StoreKit is the source of
    // truth, so the label stays correct in every storefront's currency.
    private var removeAdsPriceText: String?

    private func removeAdsButtonText() -> String {
        if let price = removeAdsPriceText {
            return "Remove Ads — \(price)"
        }
        // No price known yet — show no number rather than a wrong one.
        return "Remove Ads"
    }

    private func loadRemoveAdsPrice() {
        Task { @MainActor in
            guard let product = await IAPManager.shared.getRemoveAdsProduct() else { return }
            removeAdsPriceText = product.displayPrice
            if let label = childNode(withName: "removeAdsButton")?
                .childNode(withName: "removeAdsLabel") as? SKLabelNode {
                label.text = removeAdsButtonText()
            }
        }
    }

    // MARK: - v1.8 (E3): Remove Ads value-prop modal

    /// Shown BEFORE the purchase sheet — the rewarded placements are invisible
    /// until players hit them, so this makes the value legible: removing ads
    /// keeps every earned reward, now as a free tap. Rendered via the shared
    /// `RemoveAdsModalNode` (same modal the in-run E4 button presents).
    private func showRemoveAdsValueModal() {
        let modal = RemoveAdsModalNode()
        modal.priceText = removeAdsPriceText
        modal.present(in: self)
        removeAdsValueModal = modal
    }

    private func handleRemoveAdsValueTap(_ location: CGPoint) {
        guard let modal = removeAdsValueModal else { return }
        let buy = modal.hitTestBuy(at: location)
        dismissRemoveAdsValueModal()
        if buy {
            handleRemoveAdsPurchase()  // → StoreKit sheet
        }
    }

    private func dismissRemoveAdsValueModal() {
        guard let modal = removeAdsValueModal else { return }
        removeAdsValueModal = nil
        modal.dismiss()
    }

    private func handleRemoveAdsPurchase() {
        guard let removeBtn = childNode(withName: "removeAdsButton"),
              let label = removeBtn.childNode(withName: "removeAdsLabel") as? SKLabelNode else { return }

        label.text = "Purchasing..."
        label.fontColor = SKColor(hex: 0xCCCCCC)

        Task { @MainActor in
            let success = await IAPManager.shared.purchaseRemoveAds()

            if success {
                label.text = "Ads Removed ✓"
                label.fontColor = SKColor(hex: 0x66AA66)

                run(SKAction.wait(forDuration: 1.5)) {
                    removeBtn.removeFromParent()  // remove the whole pill
                }
            } else {
                label.text = removeAdsButtonText()
                label.fontColor = SKColor(hex: 0xFFAA33)
            }
        }
    }
}

// MARK: - Cross-promo store card

extension TitleScene: SKStoreProductViewControllerDelegate {
    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        viewController.dismiss(animated: true)
    }
}
