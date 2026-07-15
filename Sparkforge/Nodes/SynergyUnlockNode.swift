// SynergyUnlockNode.swift
// Sparkforge
//
// v1.8 Unit 6 (A1): the synergy-unlock reveal modal. Replaces the old bottom
// floating line — a tier earned now presents a card-style plate that HOLDS the
// game until tapped (card-selection behavior). Multi-tier picks (Extra Pick
// chains) queue these one after another; GameScene owns the queue.
//
// Card language, tree-tinted: dark plate + colored stroke/glow, tag emoji,
// brightColor() title, white effect text — reads as the same family as the
// upgrade cards and the pause card-detail.

import SpriteKit

final class SynergyUnlockNode: SKNode {

    private static let panelWidth: CGFloat = 300
    private static let padX: CGFloat = 22
    private static let padTop: CGFloat = 20
    private static let padBottom: CGFloat = 18

    private let panel: SKShapeNode

    init(unlock: UpgradeManager.SynergyUnlock) {
        panel = SKShapeNode()
        super.init()
        zPosition = 400

        let colorHex = UpgradeCardNode.color(for: unlock.tag)

        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.72)
        dim.strokeColor = .clear
        addChild(dim)

        let body = SKNode()
        var y: CGFloat = 0

        let header = SKLabelNode(fontNamed: "Menlo-Bold")
        header.text = "SYNERGY UNLOCKED"
        header.fontSize = UITheme.Size.label            // v1.8: theme, ≥10pt
        header.fontColor = UpgradeCardNode.brightColor(hex: colorHex)  // info, not dimmed
        header.verticalAlignmentMode = .top
        header.horizontalAlignmentMode = .center
        header.position = CGPoint(x: 0, y: y)
        body.addChild(header)
        y -= 26

        let emoji = SKLabelNode(text: UpgradeCardNode.emoji(for: unlock.tag))
        emoji.fontSize = 34
        emoji.verticalAlignmentMode = .top
        emoji.horizontalAlignmentMode = .center
        emoji.position = CGPoint(x: 0, y: y)
        body.addChild(emoji)
        y -= 46

        let sub = SKLabelNode(fontNamed: "Menlo-Bold")
        sub.text = "\(unlock.tag.rawValue.uppercased()) · TIER \(unlock.tier)"
        sub.fontSize = UITheme.Size.label               // v1.8: theme, ≥10pt
        sub.fontColor = UpgradeCardNode.brightColor(hex: colorHex)  // info, not dimmed
        sub.verticalAlignmentMode = .top
        sub.horizontalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: y)
        body.addChild(sub)
        y -= 24

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = unlock.title
        title.fontSize = 22
        title.fontColor = UpgradeCardNode.brightColor(for: unlock.tag)
        title.verticalAlignmentMode = .top
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: y)
        body.addChild(title)
        y -= 34

        for line in Self.wrap(unlock.effect, maxChars: 34) {
            let l = SKLabelNode(fontNamed: "Menlo")
            l.text = line
            l.fontSize = UITheme.Size.body              // v1.8: theme (13pt)
            l.fontColor = UITheme.Color.info            // bright info
            l.verticalAlignmentMode = .top
            l.horizontalAlignmentMode = .center
            l.position = CGPoint(x: 0, y: y)
            body.addChild(l)
            y -= 18
        }

        y -= 8
        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "tap to continue"
        hint.fontSize = UITheme.Size.hint               // v1.8: theme (10pt)
        hint.fontColor = UITheme.Color.hint             // decoration only
        hint.verticalAlignmentMode = .top
        hint.horizontalAlignmentMode = .center
        hint.position = CGPoint(x: 0, y: y)
        body.addChild(hint)
        y -= 12

        let contentHeight = -y
        let panelH = contentHeight + Self.padTop + Self.padBottom
        panel.path = CGPath(roundedRect: CGRect(x: -Self.panelWidth / 2, y: -panelH / 2,
                                                 width: Self.panelWidth, height: panelH),
                            cornerWidth: 14, cornerHeight: 14, transform: nil)
        panel.fillColor = SKColor(hex: 0x121212)
        panel.strokeColor = SKColor(hex: colorHex, alpha: 0.85)
        panel.lineWidth = 2
        panel.glowWidth = 6
        addChild(panel)

        body.position = CGPoint(x: 0, y: panelH / 2 - Self.padTop)
        addChild(body)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Presentation

    func present(in parent: SKNode) {
        parent.addChild(self)
        alpha = 0
        panel.setScale(0.85)
        run(SKAction.fadeIn(withDuration: 0.18))
        // A little celebratory overshoot — this is an unlock, not a tooltip.
        let pop = SKAction.sequence([
            SKAction.scale(to: 1.06, duration: 0.16),
            SKAction.scale(to: 1.0, duration: 0.10)
        ])
        pop.timingMode = .easeOut
        panel.run(pop)
    }

    func dismiss() {
        run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.12),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Text wrap (matches the other card-family nodes)

    private static func wrap(_ text: String, maxChars: Int) -> [String] {
        let words = text.split(separator: " ")
        var lines: [String] = []
        var current = ""
        for word in words {
            if current.isEmpty {
                current = String(word)
            } else if current.count + 1 + word.count <= maxChars {
                current += " " + word
            } else {
                lines.append(current)
                current = String(word)
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }
}
