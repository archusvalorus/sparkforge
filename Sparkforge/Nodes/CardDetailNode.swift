// CardDetailNode.swift
// Sparkforge
//
// v1.8 playtest punch list: a reusable, card-style detail modal.
//
// ONE detail view shared across every surface that needs "know as you go"
// card info — the pause build viewer (tap a chip) and the Card Codex
// (Unit 8). Content-driven and purely presentational: the host builds a
// `Content` from its data and calls present(in:); this node owns only the
// layout, the tree-tint canon, and its own dismissal. Any tap closes it,
// so hosts just forward one tap → dismiss().

import SpriteKit

final class CardDetailNode: SKNode {

    // MARK: - Content

    struct TierLine {
        let threshold: Int
        let title: String
        let effect: String
        let reached: Bool
    }

    struct Content {
        let name: String
        let tag: UpgradeManager.Tag
        let secondaryTag: UpgradeManager.Tag?
        let effect: String
        /// Synergy tiers for the card's tree, in threshold order. May be empty
        /// (e.g. Neutral cards have no tree synergy).
        let tiers: [TierLine]
        /// v1.9: card-tier line for multi-tier cards (e.g. "TIER 2 / 3").
        /// nil for 1-tier cards — nothing renders. Full ladder view is Unit 2.
        var cardTierLine: String? = nil
    }

    // MARK: - Layout constants

    private static let panelWidth: CGFloat = 300
    private static let padX: CGFloat = 22
    private static let padTop: CGFloat = 22
    private static let padBottom: CGFloat = 18

    private let panel: SKShapeNode

    // MARK: - Init

    init(content: Content) {
        panel = SKShapeNode()
        super.init()
        zPosition = 350

        let colorHex = UpgradeCardNode.color(for: content.tag)

        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.75)
        dim.strokeColor = .clear
        addChild(dim)

        // Content is laid out top-down into this container (y starts at 0 and
        // descends); once measured, the container is shifted so the whole card
        // sits centered in a panel sized to fit.
        let body = SKNode()
        var y: CGFloat = 0

        // Card name — tree-bright, the readability canon for titles.
        let name = SKLabelNode(fontNamed: "Menlo-Bold")
        name.text = content.name
        name.fontSize = 19
        name.fontColor = UpgradeCardNode.brightColor(for: content.tag)
        name.verticalAlignmentMode = .top
        name.horizontalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: y)
        body.addChild(name)
        y -= 30

        // Tag chip(s) — primary, plus secondary for dual-tag bridge cards.
        var tags: [UpgradeManager.Tag] = [content.tag]
        if let second = content.secondaryTag { tags.append(second) }
        let chipW: CGFloat = 78
        let chipH: CGFloat = 20
        let gap: CGFloat = 8
        let totalW = CGFloat(tags.count) * chipW + CGFloat(tags.count - 1) * gap
        var chipX = -totalW / 2 + chipW / 2
        for tag in tags {
            body.addChild(Self.tagChip(tag: tag, at: CGPoint(x: chipX, y: y - chipH / 2), size: CGSize(width: chipW, height: chipH)))
            chipX += chipW + gap
        }
        y -= chipH + 14

        // v1.9: card tier for multi-tier cards ("TIER 2 / 3").
        if let tierLine = content.cardTierLine {
            let l = SKLabelNode(fontNamed: "Menlo-Bold")
            l.text = tierLine
            l.fontSize = 10
            l.fontColor = SKColor(hex: colorHex, alpha: 0.9)
            l.verticalAlignmentMode = .top
            l.horizontalAlignmentMode = .center
            l.position = CGPoint(x: 0, y: y)
            body.addChild(l)
            y -= 18
        }

        // Effect — the card's own line, wrapped.
        for line in Self.wrap(content.effect, maxChars: 34) {
            let l = SKLabelNode(fontNamed: "Menlo")
            l.text = line
            l.fontSize = 12
            l.fontColor = SKColor(hex: 0xDDDDDD)
            l.verticalAlignmentMode = .top
            l.horizontalAlignmentMode = .center
            l.position = CGPoint(x: 0, y: y)
            body.addChild(l)
            y -= 16
        }

        // Synergy tiers for the tree (skipped for Neutral / no-synergy cards).
        if !content.tiers.isEmpty {
            y -= 8
            let divider = SKShapeNode(rectOf: CGSize(width: Self.panelWidth - Self.padX * 2, height: 1))
            divider.fillColor = SKColor(hex: colorHex, alpha: 0.35)
            divider.strokeColor = .clear
            divider.position = CGPoint(x: 0, y: y)
            body.addChild(divider)
            y -= 16

            let header = SKLabelNode(fontNamed: "Menlo-Bold")
            header.text = "\(content.tag.rawValue.uppercased()) SYNERGIES"
            header.fontSize = 10
            header.fontColor = SKColor(hex: colorHex, alpha: 0.9)
            header.verticalAlignmentMode = .top
            header.horizontalAlignmentMode = .center
            header.position = CGPoint(x: 0, y: y)
            body.addChild(header)
            y -= 20

            let left = -(Self.panelWidth / 2) + Self.padX
            for tier in content.tiers {
                let bright = tier.reached
                // "③ Title  ✓"
                let title = SKLabelNode(fontNamed: "Menlo-Bold")
                title.text = "\(tier.threshold)  \(tier.title)\(tier.reached ? "   ✓" : "")"
                title.fontSize = 12
                title.fontColor = bright ? UpgradeCardNode.brightColor(for: content.tag)
                                          : SKColor(hex: 0x777777)
                title.verticalAlignmentMode = .top
                title.horizontalAlignmentMode = .left
                title.position = CGPoint(x: left, y: y)
                body.addChild(title)
                y -= 15

                for line in Self.wrap(tier.effect, maxChars: 40) {
                    let l = SKLabelNode(fontNamed: "Menlo")
                    l.text = line
                    l.fontSize = 10
                    l.fontColor = bright ? SKColor(hex: 0xBBBBBB) : SKColor(hex: 0x595959)
                    l.verticalAlignmentMode = .top
                    l.horizontalAlignmentMode = .left
                    l.position = CGPoint(x: left + 14, y: y)
                    body.addChild(l)
                    y -= 13
                }
                y -= 6
            }
        }

        // Close hint.
        y -= 8
        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "tap to close"
        hint.fontSize = 10
        hint.fontColor = SKColor(hex: 0x666666)
        hint.verticalAlignmentMode = .top
        hint.horizontalAlignmentMode = .center
        hint.position = CGPoint(x: 0, y: y)
        body.addChild(hint)
        y -= 12

        // Size the panel to the measured content and center everything.
        let contentHeight = -y
        let panelH = contentHeight + Self.padTop + Self.padBottom
        panel.path = CGPath(roundedRect: CGRect(x: -Self.panelWidth / 2, y: -panelH / 2,
                                                 width: Self.panelWidth, height: panelH),
                            cornerWidth: 14, cornerHeight: 14, transform: nil)
        panel.fillColor = SKColor(hex: 0x121212)
        panel.strokeColor = SKColor(hex: colorHex, alpha: 0.75)
        panel.lineWidth = 1.5
        panel.glowWidth = 4
        addChild(panel)

        body.position = CGPoint(x: 0, y: panelH / 2 - Self.padTop)
        addChild(body)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Tag chip

    private static func tagChip(tag: UpgradeManager.Tag, at position: CGPoint, size: CGSize) -> SKNode {
        let chip = SKNode()
        chip.position = position
        let colorHex = UpgradeCardNode.color(for: tag)

        let wash = SKShapeNode(rectOf: size, cornerRadius: 5)
        wash.fillColor = SKColor(hex: colorHex, alpha: 0.20)
        wash.strokeColor = SKColor(hex: colorHex)
        wash.lineWidth = 1
        chip.addChild(wash)

        let emoji = SKLabelNode(text: UpgradeCardNode.emoji(for: tag))
        emoji.fontSize = 11
        emoji.verticalAlignmentMode = .center
        emoji.horizontalAlignmentMode = .left
        emoji.position = CGPoint(x: -size.width / 2 + 8, y: 0)
        chip.addChild(emoji)

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = tag.rawValue.uppercased()
        label.fontSize = 10
        label.fontColor = UpgradeCardNode.brightColor(for: tag)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .left
        label.position = CGPoint(x: -size.width / 2 + 24, y: 0)
        chip.addChild(label)

        return chip
    }

    // MARK: - Presentation

    func present(in parent: SKNode) {
        parent.addChild(self)
        alpha = 0
        panel.setScale(0.9)
        run(SKAction.fadeIn(withDuration: 0.15))
        let pop = SKAction.scale(to: 1.0, duration: 0.15)
        pop.timingMode = .easeOut
        panel.run(pop)
    }

    func dismiss() {
        run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.12),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Text wrap (matches UpgradeCardNode's char-count word wrap)

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
