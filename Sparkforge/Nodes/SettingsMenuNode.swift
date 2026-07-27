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

        let panelH = panelHeight
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

        // v2.0 (E2): the one tree you never want to see. Cycles rather than
        // opening a picker — it's a set-once preference, and the cycling toggle
        // is the grammar this panel already speaks.
        addButton(name: "banToggle", text: banText, y: y,
                  fill: 0x2A2A2A, stroke: 0x777777, textHex: 0xCCCCCC)
        let banNote = UITheme.label("one tree, never offered", size: UITheme.Size.caption,
                                    color: UITheme.Color.hint)
        banNote.position = CGPoint(x: 0, y: y - 24)
        addChild(banNote)
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

    /// RANDOM is the no-ban state and the default — nothing excluded by hand.
    private var banText: String {
        guard let tag = SettingsManager.shared.bannedFamily else { return "BAN: RANDOM" }
        return "BAN: \(UpgradeCardNode.emoji(for: tag)) \(tag.rawValue.uppercased())"
    }

    /// The ban picker, while it's open. Owned here rather than by the hosts:
    /// both the title screen and the pause menu present this panel, and routing
    /// a sub-modal through both of them would duplicate the wiring twice over.
    private var banPicker: FamilyBanPickerNode?

    /// Single source of truth for the panel's height — the hit-test needs the
    /// same number the panel was drawn with, and two copies of that ternary
    /// were one edit away from disagreeing.
    private var panelHeight: CGFloat { showErase ? 396 : 326 }

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

    private func presentBanPicker() {
        guard banPicker == nil else { return }
        let picker = FamilyBanPickerNode()
        // Note: the reference is NOT cleared here. The picker fades for a beat
        // after a pick, and clearing it now would open a ~120ms window where a
        // tap falls through to the settings buttons behind the still-visible
        // panel — one of which erases the save. It's released in `action(at:)`
        // once the node has actually left the tree.
        picker.onPick = { [weak self] _ in
            guard let self = self else { return }
            self.setText("banToggle", self.banText)
        }
        picker.present(in: self)
        banPicker = picker
        AudioManager.shared.play(.cardSelect)
    }

    /// Resolve a tap. SFX/BGM toggles are handled internally (label + sound);
    /// erase/close bubble to the host. A tap outside the panel closes.
    ///
    /// While the ban picker is open it swallows every tap — otherwise a tap
    /// meant for a tree chip would fall through to whatever settings button sits
    /// behind it, which is how you accidentally erase your save.
    func action(at location: CGPoint) -> Action? {
        if let picker = banPicker {
            if picker.parent == nil {
                banPicker = nil          // fully gone — taps belong to us again
            } else {
                picker.handleTap(at: location)
                return nil
            }
        }
        guard let hit = buttons.first(where: { $0.frame.contains(location) })?.name else {
            let panel = CGRect(x: -Self.panelW / 2, y: -panelHeight / 2,
                               width: Self.panelW, height: panelHeight)
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
        case "banToggle":
            presentBanPicker()
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
