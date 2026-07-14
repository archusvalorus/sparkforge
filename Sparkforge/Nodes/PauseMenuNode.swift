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
    private static let maxChipRows = 8  // two columns → 16 chips before "+N more"

    // MARK: - Nodes

    private let mainPane = SKNode()
    private let settingsPane = SKNode()
    /// Rebuilt on every show() from the run's picked cards
    private let buildViewer = SKNode()

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
        rebuildBuildViewer(upgradeManager: upgradeManager)
        settingsPane.isHidden = true
        mainPane.isHidden = false
        run(SKAction.fadeIn(withDuration: 0.15))
    }

    func hide() {
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

        // v1.8: uniform 224x36; RESUME green (unchanged), SETTINGS blue/white,
        // MENU purple/white — matches the death-overlay button treatment.
        mainPane.addChild(Self.button(name: "resumeButton", text: "RESUME",
                                      size: CGSize(width: 240, height: 42),
                                      position: CGPoint(x: 0, y: -160),
                                      fillHex: 0x334433, strokeHex: 0x66AA66,
                                      textHex: 0x88DD88, fontSize: 15, bold: true))
        mainPane.addChild(Self.button(name: "settingsButton", text: "SETTINGS",
                                      size: CGSize(width: 240, height: 42),
                                      position: CGPoint(x: 0, y: -214),
                                      fillHex: 0x18345C, strokeHex: 0x5AA0F0,
                                      textHex: 0xFFFFFF, fontSize: 14, bold: true))
        mainPane.addChild(Self.button(name: "pauseMenuButton", text: "MENU",
                                      size: CGSize(width: 240, height: 42),
                                      position: CGPoint(x: 0, y: -268),
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
            buildViewer.addChild(Self.chip(for: card, at: CGPoint(x: x, y: y)))
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

    /// Mini tree-tinted card: dark plate, translucent tag wash, emoji + name
    private static func chip(for card: UpgradeManager.UpgradeCard, at position: CGPoint) -> SKNode {
        let chip = SKNode()
        chip.position = position
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
    func handleTap(at location: CGPoint) {
        let pane = settingsPane.isHidden ? mainPane : settingsPane

        guard let hit = Self.buttonHit(in: pane, at: location) else { return }

        switch hit.name {
        case "resumeButton":
            onResume?()
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
