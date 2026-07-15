// PauseMenuNode.swift
// Sparkforge
//
// v1.7 Pause Menu v2: RESUME / SETTINGS / MENU, a settings pane
// (SFX + BGM toggles, live), and the build viewer — every card picked
// this run as a mini tree-tinted chip, with synergy tiers hit.
// Self-contained: GameScene forwards taps to handleTap(at:).

import SpriteKit

final class PauseMenuNode: SKNode {

    // MARK: - Callbacks

    var onResume: (() -> Void)?
    var onReturnToMenu: (() -> Void)?

    // MARK: - Layout

    private static let chipSize = CGSize(width: 152, height: 22)
    private static let chipRowHeight: CGFloat = 26
    // v1.8: trimmed 8→6 so the build viewer reserves less vertical space and
    // the action buttons can sit higher, closer to PAUSED. The synergy strip
    // above still shows every tree's count; "+N more" covers the overflow.
    private static let maxChipRows = 6  // two columns → 12 chips before "+N more"

    // MARK: - Nodes

    private let mainPane = SKNode()
    private let settingsPane = SKNode()
    /// Rebuilt on every show() from the run's picked cards
    private let buildViewer = SKNode()

    /// v1.8: the card-detail modal opened by tapping a build chip. Any tap
    /// closes it. Held here so taps route to it before the pane buttons.
    private var detailNode: CardDetailNode?
    /// v1.8 Unit 7: the Synergies codex page, opened from the pause menu.
    private var codexNode: SynergyCodexNode?
    /// Captured on show() so a chip tap can resolve its card + tag counts.
    private weak var upgradeManager: UpgradeManager?

    // MARK: - Init

    override init() {
        super.init()
        zPosition = 200
        alpha = 0

        let bg = SKShapeNode(rectOf: CGSize(width: 2000, height: 2000))
        bg.fillColor = SKColor(hex: 0x000000, alpha: 0.75)
        bg.strokeColor = .clear
        addChild(bg)

        setupMainPane()
        setupSettingsPane()
        addChild(mainPane)
        addChild(settingsPane)
        settingsPane.isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Show / Hide

    func show(upgradeManager: UpgradeManager) {
        self.upgradeManager = upgradeManager
        dismissDetail()
        dismissCodex()
        rebuildBuildViewer(upgradeManager: upgradeManager)
        settingsPane.isHidden = true
        mainPane.isHidden = false
        run(SKAction.fadeIn(withDuration: 0.15))
    }

    func hide() {
        dismissDetail()
        dismissCodex()
        run(SKAction.fadeOut(withDuration: 0.15))
    }

    // MARK: - Main pane

    private func setupMainPane() {
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "PAUSED"
        title.fontSize = 28
        title.fontColor = SKColor(hex: 0xFFAA33)
        title.position = CGPoint(x: 0, y: 170)
        mainPane.addChild(title)

        buildViewer.position = .zero
        mainPane.addChild(buildViewer)

        // v1.8: uniform 240x42 stack, lifted up toward PAUSED. SYNERGY CODEX
        // (amber) → RESUME (green) → SETTINGS (blue) → MENU (purple); all with
        // white text for a consistent read.
        mainPane.addChild(Self.button(name: "synergyCodexButton", text: "⬡ SYNERGY CODEX",
                                      size: CGSize(width: 240, height: 42),
                                      position: CGPoint(x: 0, y: -70),
                                      fillHex: 0x2A1A00, strokeHex: 0xFFAA33,
                                      textHex: 0xFFFFFF, fontSize: 14, bold: true))
        mainPane.addChild(Self.button(name: "resumeButton", text: "RESUME",
                                      size: CGSize(width: 240, height: 42),
                                      position: CGPoint(x: 0, y: -124),
                                      fillHex: 0x334433, strokeHex: 0x66AA66,
                                      textHex: 0xFFFFFF, fontSize: 15, bold: true))
        mainPane.addChild(Self.button(name: "settingsButton", text: "SETTINGS",
                                      size: CGSize(width: 240, height: 42),
                                      position: CGPoint(x: 0, y: -178),
                                      fillHex: 0x18345C, strokeHex: 0x5AA0F0,
                                      textHex: 0xFFFFFF, fontSize: 14, bold: true))
        mainPane.addChild(Self.button(name: "pauseMenuButton", text: "MENU",
                                      size: CGSize(width: 240, height: 42),
                                      position: CGPoint(x: 0, y: -232),
                                      fillHex: 0x2A1140, strokeHex: 0xB566FF,
                                      textHex: 0xFFFFFF, fontSize: 14, bold: true))
    }

    // MARK: - Build viewer

    private func rebuildBuildViewer(upgradeManager: UpgradeManager) {
        buildViewer.removeAllChildren()

        let cards = upgradeManager.pickedCards
        guard !cards.isEmpty else {
            let empty = SKLabelNode(fontNamed: "Menlo")
            empty.text = "NO CARDS YET"
            empty.fontSize = 12
            empty.fontColor = SKColor(hex: 0x666666)
            empty.position = CGPoint(x: 0, y: 20)
            buildViewer.addChild(empty)
            return
        }

        // Synergy strip — one entry per tree: emoji, count, tier dots
        let strip = SKNode()
        strip.position = CGPoint(x: 0, y: 136)
        var entries: [(emoji: String, count: Int, colorHex: UInt32)] = []
        for tag in UpgradeManager.Tag.allCases {
            guard let count = upgradeManager.tagCounts[tag], count > 0 else { continue }
            entries.append((UpgradeCardNode.emoji(for: tag), count, UpgradeCardNode.color(for: tag)))
        }
        let spacing: CGFloat = 46
        let startX = -CGFloat(entries.count - 1) * spacing / 2
        for (i, entry) in entries.enumerated() {
            let x = startX + CGFloat(i) * spacing
            let emoji = SKLabelNode(text: entry.emoji)
            emoji.fontSize = 13
            emoji.verticalAlignmentMode = .center
            emoji.horizontalAlignmentMode = .right
            emoji.position = CGPoint(x: x + 2, y: 0)
            strip.addChild(emoji)

            let count = SKLabelNode(fontNamed: "Menlo-Bold")
            count.text = "\(entry.count)"
            count.fontSize = 13
            count.fontColor = SKColor(hex: entry.colorHex)
            count.verticalAlignmentMode = .center
            count.horizontalAlignmentMode = .left
            count.position = CGPoint(x: x + 5, y: 0)
            strip.addChild(count)

            // Tier dots under the count: ● per synergy tier hit (3/5/7)
            let tiersHit = entry.count >= 7 ? 3 : entry.count >= 5 ? 2 : entry.count >= 3 ? 1 : 0
            if tiersHit > 0 {
                let dots = SKLabelNode(fontNamed: "Menlo")
                dots.text = String(repeating: "●", count: tiersHit)
                dots.fontSize = 6
                dots.fontColor = SKColor(hex: entry.colorHex, alpha: 0.8)
                dots.verticalAlignmentMode = .center
                dots.position = CGPoint(x: x, y: -13)
                strip.addChild(dots)
            }
        }
        buildViewer.addChild(strip)

        // Card chips — two columns, pick order, capped with "+N more"
        let maxChips = Self.maxChipRows * 2
        let overflow = cards.count > maxChips ? cards.count - (maxChips - 1) : 0
        let shown = overflow > 0 ? Array(cards.prefix(maxChips - 1)) : cards

        for (i, card) in shown.enumerated() {
            let col = i % 2
            let row = i / 2
            let x: CGFloat = cards.count == 1 ? 0 : (col == 0 ? -80 : 80)
            let y = 105 - CGFloat(row) * Self.chipRowHeight
            buildViewer.addChild(Self.chip(for: card, index: i, at: CGPoint(x: x, y: y)))
        }

        if overflow > 0 {
            let more = SKLabelNode(fontNamed: "Menlo")
            more.text = "+\(overflow) more"
            more.fontSize = 10
            more.fontColor = SKColor(hex: 0x888888)
            more.verticalAlignmentMode = .center
            let i = shown.count
            let x: CGFloat = i % 2 == 0 ? -80 : 80
            more.position = CGPoint(x: x, y: 105 - CGFloat(i / 2) * Self.chipRowHeight)
            buildViewer.addChild(more)
        }
    }

    /// Mini tree-tinted card: dark plate, translucent tag wash, emoji + name.
    /// Tappable — carries its pick-order index so a tap opens the detail modal.
    private static func chip(for card: UpgradeManager.UpgradeCard, index: Int, at position: CGPoint) -> SKNode {
        let chip = SKNode()
        chip.name = "buildChip"
        chip.position = position
        chip.userData = NSMutableDictionary(dictionary: [
            "index": index, "w": chipSize.width, "h": chipSize.height
        ])
        let colorHex = UpgradeCardNode.color(for: card.tag)

        let plate = SKShapeNode(rectOf: chipSize, cornerRadius: 5)
        plate.fillColor = SKColor(hex: 0x161616)
        plate.strokeColor = .clear
        chip.addChild(plate)

        let wash = SKShapeNode(rectOf: chipSize, cornerRadius: 5)
        wash.fillColor = SKColor(hex: colorHex, alpha: 0.20)
        wash.strokeColor = SKColor(hex: colorHex)
        wash.lineWidth = 1
        chip.addChild(wash)

        let emoji = SKLabelNode(text: UpgradeCardNode.emoji(for: card.tag))
        emoji.fontSize = 11
        emoji.verticalAlignmentMode = .center
        emoji.position = CGPoint(x: -chipSize.width / 2 + 13, y: 0)
        chip.addChild(emoji)

        let name = SKLabelNode(fontNamed: "Menlo-Bold")
        name.text = card.name
        // Same brightness treatment as the card titles (readability canon)
        name.fontColor = UpgradeCardNode.brightColor(for: card.tag)
        name.verticalAlignmentMode = .center
        name.horizontalAlignmentMode = .left
        name.position = CGPoint(x: -chipSize.width / 2 + 26, y: 0)
        var fontSize: CGFloat = 10
        name.fontSize = fontSize
        let maxWidth = chipSize.width - 34
        while name.frame.width > maxWidth && fontSize > 6 {
            fontSize -= 0.5
            name.fontSize = fontSize
        }
        chip.addChild(name)

        return chip
    }

    // MARK: - Settings pane

    private func setupSettingsPane() {
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "SETTINGS"
        title.fontSize = 24
        title.fontColor = SKColor(hex: 0xFFAA33)
        title.position = CGPoint(x: 0, y: 80)
        settingsPane.addChild(title)

        settingsPane.addChild(Self.button(name: "sfxToggle", text: sfxText,
                                          size: CGSize(width: 240, height: 42),
                                          position: CGPoint(x: 0, y: 20),
                                          fillHex: 0x2A2A2A, strokeHex: 0x777777,
                                          textHex: 0xCCCCCC, fontSize: 15, bold: true))
        settingsPane.addChild(Self.button(name: "bgmToggle", text: bgmText,
                                          size: CGSize(width: 240, height: 42),
                                          position: CGPoint(x: 0, y: -32),
                                          fillHex: 0x2A2A2A, strokeHex: 0x777777,
                                          textHex: 0xCCCCCC, fontSize: 15, bold: true))

        let bgmNote = SKLabelNode(fontNamed: "Menlo")
        bgmNote.text = "music coming soon"
        bgmNote.fontSize = 10
        bgmNote.fontColor = SKColor(hex: 0x666666)
        bgmNote.position = CGPoint(x: 0, y: -56)
        settingsPane.addChild(bgmNote)

        settingsPane.addChild(Self.button(name: "settingsBackButton", text: "BACK",
                                          size: CGSize(width: 240, height: 42),
                                          position: CGPoint(x: 0, y: -104),
                                          fillHex: 0x333333, strokeHex: 0x888888,
                                          textHex: 0xE0E0E0, fontSize: 14, bold: false))
    }

    private var sfxText: String { SettingsManager.shared.sfxEnabled ? "SFX: ON" : "SFX: OFF" }
    private var bgmText: String { SettingsManager.shared.bgmEnabled ? "BGM: ON" : "BGM: OFF" }

    // MARK: - Touch

    /// Location is in this node's coordinate space. Buttons carry their
    /// hit size in userData so panes stay declarative.
    // v1.8 Unit 7: while the codex is open, taps scroll it and only the ✕
    // closes — so GameScene forwards began/moved/ended here (not just a tap).
    private var scrollLastY: CGFloat = 0
    private var scrollMovement: CGFloat = 0

    func handleTouchBegan(at location: CGPoint) {
        if codexNode != nil {
            scrollLastY = location.y
            scrollMovement = 0
            return
        }
        handleTap(at: location)
    }

    func handleTouchMoved(at location: CGPoint) {
        guard let codex = codexNode else { return }
        let dy = location.y - scrollLastY
        scrollLastY = location.y
        scrollMovement += abs(dy)
        codex.scroll(by: dy)
    }

    func handleTouchEnded(at location: CGPoint) {
        guard let codex = codexNode else { return }
        // A tap (not a drag) on the ✕ closes; taps elsewhere do nothing.
        if scrollMovement < 8 && codex.hitTestClose(at: location) {
            dismissCodex()
        }
    }

    func handleTap(at location: CGPoint) {
        // The detail modal is topmost and informational — any tap closes it.
        if detailNode != nil {
            dismissDetail()
            return
        }

        // Build-viewer chips (main pane only) open the card-detail modal.
        if settingsPane.isHidden, let index = Self.chipHitIndex(in: buildViewer, at: location) {
            presentDetail(forCardAt: index)
            return
        }

        let pane = settingsPane.isHidden ? mainPane : settingsPane

        guard let hit = Self.buttonHit(in: pane, at: location) else { return }

        switch hit.name {
        case "resumeButton":
            onResume?()
        case "synergyCodexButton":
            presentCodex()
        case "settingsButton":
            mainPane.isHidden = true
            settingsPane.isHidden = false
        case "pauseMenuButton":
            onReturnToMenu?()
        case "settingsBackButton":
            settingsPane.isHidden = true
            mainPane.isHidden = false
        case "sfxToggle":
            SettingsManager.shared.sfxEnabled.toggle()
            Self.setButtonText(hit, sfxText)
            AudioManager.shared.play(.cardSelect)
        case "bgmToggle":
            SettingsManager.shared.bgmEnabled.toggle()
            Self.setButtonText(hit, bgmText)
            AudioManager.shared.play(.cardSelect)
        default:
            break
        }
    }

    // MARK: - Card detail

    private static func chipHitIndex(in container: SKNode, at location: CGPoint) -> Int? {
        for child in container.children {
            guard child.name == "buildChip",
                  let index = child.userData?["index"] as? Int,
                  let w = child.userData?["w"] as? CGFloat,
                  let h = child.userData?["h"] as? CGFloat else { continue }
            let frame = CGRect(x: child.position.x - w / 2, y: child.position.y - h / 2,
                               width: w, height: h)
            if frame.contains(location) { return index }
        }
        return nil
    }

    private func presentDetail(forCardAt index: Int) {
        guard let manager = upgradeManager else { return }
        let cards = manager.pickedCards
        guard index < cards.count else { return }
        let card = cards[index]

        let count = manager.tagCounts[card.tag] ?? 0
        let tiers = UpgradeManager.synergyTiers(for: card.tag).map {
            CardDetailNode.TierLine(threshold: $0.threshold, title: $0.title,
                                    effect: $0.effect, reached: count >= $0.threshold)
        }
        let content = CardDetailNode.Content(name: card.name, tag: card.tag,
                                             secondaryTag: card.secondaryTag,
                                             effect: card.description, tiers: tiers)
        let detail = CardDetailNode(content: content)
        detail.present(in: self)
        detailNode = detail
        AudioManager.shared.play(.cardSelect)
    }

    private func dismissDetail() {
        detailNode?.dismiss()
        detailNode = nil
    }

    // MARK: - Synergy codex (Unit 7)

    private func presentCodex() {
        guard codexNode == nil else { return }
        let width = scene?.view?.bounds.width ?? 390
        let height = scene?.view?.bounds.height ?? 844
        let insets = scene?.view?.safeAreaInsets ?? UIEdgeInsets(top: 47, left: 0, bottom: 34, right: 0)
        let codex = SynergyCodexNode(width: width, height: height,
                                     topInset: insets.top, bottomInset: insets.bottom)
        codex.present(in: self)
        codexNode = codex
    }

    private func dismissCodex() {
        codexNode?.dismiss()
        codexNode = nil
    }

    // MARK: - Button helpers

    private static func button(name: String, text: String, size: CGSize,
                               position: CGPoint, fillHex: UInt32, strokeHex: UInt32,
                               textHex: UInt32, fontSize: CGFloat, bold: Bool) -> SKNode {
        let btn = SKNode()
        btn.name = name
        btn.position = position
        btn.userData = NSMutableDictionary(dictionary: ["w": size.width, "h": size.height])

        let bg = SKShapeNode(rectOf: size, cornerRadius: 6)
        bg.fillColor = SKColor(hex: fillHex)
        bg.strokeColor = SKColor(hex: strokeHex, alpha: 0.6)
        bg.lineWidth = 1
        btn.addChild(bg)

        let label = SKLabelNode(fontNamed: bold ? "Menlo-Bold" : "Menlo")
        label.name = "label"
        label.text = text
        label.fontSize = fontSize
        label.fontColor = SKColor(hex: textHex)
        label.verticalAlignmentMode = .center
        btn.addChild(label)

        return btn
    }

    private static func buttonHit(in pane: SKNode, at location: CGPoint) -> SKNode? {
        for child in pane.children {
            guard let name = child.name, !name.isEmpty,
                  let w = child.userData?["w"] as? CGFloat,
                  let h = child.userData?["h"] as? CGFloat else { continue }
            let frame = CGRect(x: child.position.x - w / 2, y: child.position.y - h / 2,
                               width: w, height: h)
            if frame.contains(location) { return child }
        }
        return nil
    }

    private static func setButtonText(_ button: SKNode, _ text: String) {
        (button.childNode(withName: "label") as? SKLabelNode)?.text = text
    }
}
