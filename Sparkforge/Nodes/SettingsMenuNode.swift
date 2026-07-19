// SettingsMenuNode.swift
// Sparkforge
//
// v1.9: one shared Settings surface, reused by the title screen and the pause
// menu (same reuse move as the codex hub). SFX / BGM toggles are self-contained
// (SettingsManager + a click sound); the host wires only .erase and .close.
//
// The destructive "Erase all progress" entry appears only when the host opts in
// (showErase) — title-only by design, so it can't be reached mid-run.

import SpriteKit

final class SettingsMenuNode: SKNode {

    enum Action { case erase, close }

    private static let panelW: CGFloat = 280
    private let showErase: Bool

    /// Button hit frames in this node's space (name → rect).
    private var buttons: [(name: String, frame: CGRect)] = []

    init(showErase: Bool) {
        self.showErase = showErase
        super.init()
        zPosition = 480

        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.75)
        dim.strokeColor = .clear
        addChild(dim)

        let panelH: CGFloat = showErase ? 320 : 250
        let panel = SKShapeNode(rectOf: CGSize(width: Self.panelW, height: panelH), cornerRadius: 14)
        panel.fillColor = SKColor(hex: 0x141018)
        panel.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.6)
        panel.lineWidth = 1.5
        panel.glowWidth = 4
        addChild(panel)

        let title = UITheme.label("⚙︎  SETTINGS", size: UITheme.Size.title,
                                  color: UITheme.Color.accent, bold: true)
        title.position = CGPoint(x: 0, y: panelH / 2 - 34)
        addChild(title)

        // Toggle rows + optional erase, laid top-down.
        var y: CGFloat = panelH / 2 - 82
        addButton(name: "sfxToggle", text: sfxText, y: y,
                  fill: 0x2A2A2A, stroke: 0x777777, textHex: 0xCCCCCC)
        y -= 52
        addButton(name: "bgmToggle", text: bgmText, y: y,
                  fill: 0x2A2A2A, stroke: 0x777777, textHex: 0xCCCCCC)
        let note = UITheme.label("music coming soon", size: UITheme.Size.caption, color: UITheme.Color.hint)
        note.position = CGPoint(x: 0, y: y - 24)
        addChild(note)
        y -= 76

        if showErase {
            // "Important notice" red — deliberately distinct from the Bleed
            // tree tint; white text so it reads as a warning, not a skill.
            addButton(name: "eraseButton", text: "⛔  ERASE ALL PROGRESS", y: y,
                      fill: 0xC0392B, stroke: 0xE74C3C, textHex: 0xFFFFFF, fontSize: 13)
            y -= 52
        }

        addButton(name: "closeButton", text: "CLOSE", y: y,
                  fill: 0x333333, stroke: 0x888888, textHex: 0xE0E0E0, bold: false)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var sfxText: String { SettingsManager.shared.sfxEnabled ? "SFX: ON" : "SFX: OFF" }
    private var bgmText: String { SettingsManager.shared.bgmEnabled ? "BGM: ON" : "BGM: OFF" }

    private func addButton(name: String, text: String, y: CGFloat,
                           fill: UInt32, stroke: UInt32, textHex: UInt32,
                           fontSize: CGFloat = 15, bold: Bool = true) {
        let size = CGSize(width: 240, height: 42)
        let btn = SKNode()
        btn.name = name
        btn.position = CGPoint(x: 0, y: y)

        let bg = SKShapeNode(rectOf: size, cornerRadius: 6)
        bg.fillColor = SKColor(hex: fill)
        bg.strokeColor = SKColor(hex: stroke, alpha: 0.7)
        bg.lineWidth = 1
        btn.addChild(bg)

        let label = SKLabelNode(fontNamed: bold ? "Menlo-Bold" : "Menlo")
        label.name = "label"
        label.text = text
        label.fontSize = fontSize
        label.fontColor = SKColor(hex: textHex)
        label.verticalAlignmentMode = .center
        btn.addChild(label)

        addChild(btn)
        buttons.append((name, CGRect(x: -size.width / 2, y: y - size.height / 2,
                                     width: size.width, height: size.height)))
    }

    private func setText(_ name: String, _ text: String) {
        (childNode(withName: name)?.childNode(withName: "label") as? SKLabelNode)?.text = text
    }

    /// Resolve a tap. SFX/BGM toggles are handled internally (label + sound);
    /// erase/close bubble to the host. A tap outside the panel closes.
    func action(at location: CGPoint) -> Action? {
        guard let hit = buttons.first(where: { $0.frame.contains(location) })?.name else {
            let panelH: CGFloat = showErase ? 320 : 250
            let panel = CGRect(x: -Self.panelW / 2, y: -panelH / 2, width: Self.panelW, height: panelH)
            return panel.contains(location) ? nil : .close
        }
        switch hit {
        case "sfxToggle":
            SettingsManager.shared.sfxEnabled.toggle()
            setText("sfxToggle", sfxText)
            AudioManager.shared.play(.cardSelect)
            return nil
        case "bgmToggle":
            SettingsManager.shared.bgmEnabled.toggle()
            setText("bgmToggle", bgmText)
            AudioManager.shared.play(.cardSelect)
            return nil
        case "eraseButton":
            return .erase
        case "closeButton":
            return .close
        default:
            return nil
        }
    }

    func present(in parent: SKNode) {
        parent.addChild(self)
        alpha = 0
        run(SKAction.fadeIn(withDuration: 0.15))
    }

    func dismiss() {
        run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.12), SKAction.removeFromParent()]))
    }
}
