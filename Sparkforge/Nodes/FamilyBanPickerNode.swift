// FamilyBanPickerNode.swift
// Sparkforge
//
// v2.0 (E2) — pick the one tree you never want offered.
//
// WHY A PICKER AND NOT A TOGGLE (Brandon): the first pass cycled through the
// trees on a single button. It worked, but it made the player tap blind through
// seven states of uncoloured text to reach the one they wanted — and this game
// has spent five versions teaching people to read TREES BY COLOUR. Throwing
// that away at the exact moment they're choosing a tree is the wrong trade.
//
// So: every option on screen at once, each wearing its own colour, one tap to
// choose. Same tree chip the card detail and the pause strip use, so a tree
// looks like itself here too.

import SpriteKit

final class FamilyBanPickerNode: SKNode {

    /// RANDOM leads: it is the DEFAULT and it is not a punishment. A player who
    /// never opens this screen is playing the intended game.
    private static let options: [UpgradeManager.Tag?] =
        [nil] + UpgradeManager.Tag.allCases.filter { $0 != .neutral }

    private static let panelW: CGFloat = 300
    /// Sized to the content: title + subtitle + four chip rows + the footer.
    /// Eight options in two columns is always four rows, so this is exact rather
    /// than generous — a modal with a third of itself empty reads as unfinished.
    private static let panelH: CGFloat = 252

    private var hitFrames: [(index: Int, frame: CGRect)] = []
    /// Fires with the chosen ban (nil = RANDOM) once the player commits.
    var onPick: ((UpgradeManager.Tag?) -> Void)?

    override init() {
        super.init()
        zPosition = 520          // above the settings panel that opened it

        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.8)
        dim.strokeColor = .clear
        addChild(dim)

        let panel = SKShapeNode(rectOf: CGSize(width: Self.panelW, height: Self.panelH),
                                cornerRadius: 14)
        panel.fillColor = SKColor(hex: 0x141018)
        panel.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.6)
        panel.lineWidth = 1.5
        panel.glowWidth = 4
        addChild(panel)

        let title = UITheme.label("BAN A TREE", size: UITheme.Size.title,
                                  color: UITheme.Color.accent, bold: true)
        title.position = CGPoint(x: 0, y: Self.panelH / 2 - 30)
        addChild(title)

        let sub = UITheme.label("one tree, never offered", size: UITheme.Size.caption,
                                color: UITheme.Color.hint)
        sub.position = CGPoint(x: 0, y: Self.panelH / 2 - 50)
        addChild(sub)

        let current = SettingsManager.shared.bannedFamily
        let chipW: CGFloat = 124, chipH: CGFloat = 26
        let colGap: CGFloat = 12, rowGap: CGFloat = 9
        let top = Self.panelH / 2 - 82

        for (i, option) in Self.options.enumerated() {
            let col = i % 2, row = i / 2
            let x = (col == 0 ? -1 : 1) * (chipW + colGap) / 2
            let y = top - CGFloat(row) * (chipH + rowGap)

            let chip: SKNode
            if let tag = option {
                chip = CardDetailNode.tagChip(tag: tag, at: CGPoint(x: x, y: y),
                                              size: CGSize(width: chipW, height: chipH))
            } else {
                chip = Self.randomChip(at: CGPoint(x: x, y: y),
                                       size: CGSize(width: chipW, height: chipH))
            }

            // The current choice wears a bright ring. Selection has to be legible
            // at a glance or the screen is just a menu of identical buttons.
            if option == current {
                let ring = SKShapeNode(rectOf: CGSize(width: chipW + 6, height: chipH + 6),
                                       cornerRadius: 7)
                ring.fillColor = .clear
                ring.strokeColor = SKColor(hex: 0xFFFFFF, alpha: 0.9)
                ring.lineWidth = 2
                ring.glowWidth = 2
                ring.position = CGPoint(x: x, y: y)
                addChild(ring)
            }

            addChild(chip)
            hitFrames.append((i, CGRect(x: x - chipW / 2, y: y - chipH / 2,
                                        width: chipW, height: chipH)))
        }

        let note = UITheme.label("applies from your next run", size: UITheme.Size.caption,
                                 color: UITheme.Color.hint)
        note.position = CGPoint(x: 0, y: -Self.panelH / 2 + 26)
        addChild(note)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// The no-ban option, in deliberately neutral grey — it must not look like a
    /// tree, because it isn't one.
    private static func randomChip(at position: CGPoint, size: CGSize) -> SKNode {
        let chip = SKNode()
        chip.position = position

        let wash = SKShapeNode(rectOf: size, cornerRadius: 5)
        wash.fillColor = SKColor(hex: 0x8A8A8A, alpha: 0.18)
        wash.strokeColor = SKColor(hex: 0x8A8A8A, alpha: 0.8)
        wash.lineWidth = 1
        chip.addChild(wash)

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = "🎲 RANDOM"
        label.fontSize = 11
        label.fontColor = SKColor(hex: 0xDDDDDD)
        label.verticalAlignmentMode = .center
        chip.addChild(label)
        return chip
    }

    /// Returns true if the tap was consumed (a pick, or a dismiss).
    @discardableResult
    func handleTap(at location: CGPoint) -> Bool {
        if let hit = hitFrames.first(where: { $0.frame.contains(location) }) {
            let choice = Self.options[hit.index]
            SettingsManager.shared.bannedFamily = choice
            AudioManager.shared.play(.cardSelect)
            onPick?(choice)
            dismiss()
            return true
        }
        // A tap anywhere off the panel closes without changing anything.
        let panel = CGRect(x: -Self.panelW / 2, y: -Self.panelH / 2,
                           width: Self.panelW, height: Self.panelH)
        if !panel.contains(location) {
            onPick?(SettingsManager.shared.bannedFamily)
            dismiss()
        }
        return true
    }

    func present(in parent: SKNode) {
        parent.addChild(self)
        alpha = 0
        run(SKAction.fadeIn(withDuration: 0.15))
    }

    func dismiss() {
        run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.12),
                               SKAction.removeFromParent()]))
    }
}
