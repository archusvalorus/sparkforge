// UpgradeCardNode.swift
// Sparkforge
//
// Visual representation of an upgrade card during level-up selection.
// Styled as a glowing metal plate with tag color accent.
//
// v1.4: Fixed text overflow — card names auto-shrink to fit,
// wider cards (100pt), better word wrap, description fits cleanly.

import SpriteKit

final class UpgradeCardNode: SKNode {
    
    // MARK: - Config

    /// v1.4: 90 → 100. v1.6: 100 → 118 — legibility pass (Brandon 7/9/26);
    /// still fits 3-across on iPhone SE at 124pt spacing
    static let cardWidth: CGFloat = 118
    static let cardHeight: CGFloat = 156
    
    // MARK: - State

    let card: UpgradeManager.UpgradeCard
    /// v1.9: the card's tier when this spread was drawn (0 = not owned).
    /// Owned cards render as a LEVEL UP offer for tier `currentTier + 1`.
    let currentTier: Int
    private let basePlate: SKShapeNode      // v1.6: dark plate keeps text readable
    private let backgroundNode: SKShapeNode // v1.6: translucent tag-color wash
    private let accentBar: SKShapeNode
    private let tagColorHex: UInt32
    
    // MARK: - Tag Colors
    
    static func color(for tag: UpgradeManager.Tag) -> UInt32 {
        switch tag {
        case .fire:    return 0xFF6633
        case .shock:   return 0x44BBFF
        case .bleed:   return 0xCC3333
        case .guardT:  return 0x88AA44
        case .voidT:   return 0x9944CC
        case .chill:   return 0x66DDFF
        case .neutral: return 0x999999
        }
    }
    
    /// v1.7 readability canon: the tree color pushed toward white, for
    /// text that must be READ — keeps the tint, kills the squint.
    static func brightColor(for tag: UpgradeManager.Tag) -> SKColor {
        return brightColor(hex: color(for: tag))
    }

    /// Same brightening, from a raw tree-color hex.
    static func brightColor(hex: UInt32) -> SKColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        let blend: CGFloat = 0.55
        return SKColor(red: r + (1 - r) * blend,
                       green: g + (1 - g) * blend,
                       blue: b + (1 - b) * blend,
                       alpha: 1.0)
    }

    static func emoji(for tag: UpgradeManager.Tag) -> String {
        switch tag {
        case .fire:    return "🔥"
        case .shock:   return "⚡"
        case .bleed:   return "🩸"
        case .guardT:  return "🛡️"
        case .voidT:   return "🕳️"
        case .chill:   return "❄️"
        case .neutral: return "⚪"
        }
    }
    
    // MARK: - Init
    
    init(card: UpgradeManager.UpgradeCard, currentTier: Int = 0) {
        self.card = card
        self.currentTier = currentTier
        self.tagColorHex = UpgradeCardNode.color(for: card.tag)

        let w = UpgradeCardNode.cardWidth
        let h = UpgradeCardNode.cardHeight
        let tagColor = SKColor(hex: tagColorHex)

        // v1.6: the whole card wears its tree's color — a dark plate for
        // text contrast, washed with a translucent tag tint
        basePlate = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 8)
        basePlate.fillColor = SKColor(hex: 0x161616)
        basePlate.strokeColor = .clear

        backgroundNode = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 8)
        backgroundNode.fillColor = SKColor(hex: tagColorHex, alpha: 0.20)
        backgroundNode.strokeColor = tagColor
        backgroundNode.lineWidth = 1.5
        backgroundNode.glowWidth = 2

        // Tag color accent bar at top
        accentBar = SKShapeNode(rectOf: CGSize(width: w - 10, height: 5), cornerRadius: 2.5)
        accentBar.fillColor = tagColor
        accentBar.strokeColor = .clear
        accentBar.position = CGPoint(x: 0, y: h / 2 - 14)

        super.init()

        isUserInteractionEnabled = false  // Scene handles taps

        addChild(basePlate)
        addChild(backgroundNode)
        addChild(accentBar)
        
        setupLabels(tagColor: tagColor)
        startIdleAnimation()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Labels
    
    private func setupLabels(tagColor: SKColor) {
        let w = UpgradeCardNode.cardWidth
        let h = UpgradeCardNode.cardHeight
        
        // Tag emoji — dual-tag cards show both
        var emojiText = UpgradeCardNode.emoji(for: card.tag)
        if let second = card.secondaryTag {
            emojiText += UpgradeCardNode.emoji(for: second)
        }
        let tagLabel = SKLabelNode(text: emojiText)
        tagLabel.fontSize = 24
        tagLabel.position = CGPoint(x: 0, y: h / 2 - 44)
        tagLabel.verticalAlignmentMode = .center
        addChild(tagLabel)

        // v1.7 dual-tag: the accent bar splits — right half wears the second tree
        if let second = card.secondaryTag {
            let half = SKShapeNode(rectOf: CGSize(width: (w - 10) / 2, height: 5), cornerRadius: 2.5)
            half.fillColor = SKColor(hex: UpgradeCardNode.color(for: second))
            half.strokeColor = .clear
            half.position = CGPoint(x: (w - 10) / 4, y: h / 2 - 14)
            half.zPosition = 0.1
            addChild(half)
        }

        // Card name — auto-shrink to fit within card width
        let nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = card.name
        nameLabel.fontColor = UpgradeCardNode.brightColor(for: card.tag)
        nameLabel.verticalAlignmentMode = .center
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: 10)

        // v1.4: Auto-shrink font size to fit card width with padding
        // v1.6 legibility: base size 12 → 14
        let maxNameWidth = w - 12  // 6pt padding each side
        var nameFontSize: CGFloat = 14
        nameLabel.fontSize = nameFontSize
        while nameLabel.frame.width > maxNameWidth && nameFontSize > 8 {
            nameFontSize -= 0.5
            nameLabel.fontSize = nameFontSize
        }

        addChild(nameLabel)

        // v1.9: an owned card is a LEVEL UP offer — a tier badge rides the
        // accent bar and the copy below describes the NEXT rung.
        if currentTier >= 1 {
            let badgeLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            badgeLabel.text = "▲ LEVEL UP \(currentTier)→\(currentTier + 1)"
            badgeLabel.fontSize = 9
            badgeLabel.fontColor = UpgradeCardNode.brightColor(for: card.tag)
            badgeLabel.verticalAlignmentMode = .center
            badgeLabel.horizontalAlignmentMode = .center

            let badge = SKShapeNode(rectOf: CGSize(width: badgeLabel.frame.width + 14,
                                                   height: 15),
                                    cornerRadius: 7.5)
            badge.fillColor = SKColor(hex: 0x161616)
            badge.strokeColor = tagColor
            badge.lineWidth = 1
            badge.position = CGPoint(x: 0, y: h / 2 - 14)
            badge.zPosition = 0.2  // above the accent bar + dual-tag half
            badge.addChild(badgeLabel)
            addChild(badge)

            // Subtle breathe so owned cards read distinct at a glance
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.7, duration: 0.7),
                SKAction.fadeAlpha(to: 1.0, duration: 0.7)
            ])
            badge.run(SKAction.repeatForever(pulse))
        }

        // Description (wrapped manually for small card)
        // v1.6 legibility: 8pt → 10pt, wider card fits 17 chars/line
        // v1.9: owned cards show the NEXT tier's copy
        let descText = currentTier >= 1
            ? card.description(forTier: currentTier + 1)
            : card.description
        let descLines = wrapText(descText, maxChars: 17)
        for (i, line) in descLines.enumerated() {
            let descLabel = SKLabelNode(fontNamed: "Menlo")
            descLabel.text = line
            descLabel.fontSize = 10
            // v1.7 playtest: fluorescent white — 0xBBBBBB gray washed out
            // at low screen brightness (reading problems, not vibes)
            descLabel.fontColor = SKColor(hex: 0xFFFFFF)
            descLabel.position = CGPoint(x: 0, y: -12 - CGFloat(i) * 13)
            descLabel.verticalAlignmentMode = .center
            descLabel.horizontalAlignmentMode = .center
            addChild(descLabel)
        }

        // Tag name at bottom — dual-tag cards show both trees
        let tagNameLabel = SKLabelNode(fontNamed: "Menlo")
        tagNameLabel.text = card.secondaryTag.map {
            "\(card.tag.rawValue.uppercased()) / \($0.rawValue.uppercased())"
        } ?? card.tag.rawValue.uppercased()
        tagNameLabel.fontSize = 9
        tagNameLabel.fontColor = SKColor(hex: 0x999999)
        tagNameLabel.position = CGPoint(x: 0, y: -h / 2 + 14)
        tagNameLabel.verticalAlignmentMode = .center
        addChild(tagNameLabel)
    }
    
    // MARK: - Text Wrapping
    
    private func wrapText(_ text: String, maxChars: Int) -> [String] {
        let words = text.split(separator: " ")
        var lines: [String] = []
        var currentLine = ""
        
        for word in words {
            if currentLine.isEmpty {
                currentLine = String(word)
            } else if currentLine.count + 1 + word.count <= maxChars {
                currentLine += " " + word
            } else {
                lines.append(currentLine)
                currentLine = String(word)
            }
        }
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        // Cap at 4 lines for card space
        return Array(lines.prefix(4))
    }
    
    // MARK: - Animation
    
    private func startIdleAnimation() {
        let hover = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 3, duration: 0.8),
            SKAction.moveBy(x: 0, y: -3, duration: 0.8)
        ])
        run(SKAction.repeatForever(hover))
    }
    
    /// Flash when selected
    func animateSelection(completion: @escaping () -> Void) {
        let flash = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.1),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                // v1.6: selection flash brightens the tree's own color
                self.backgroundNode.fillColor = SKColor(hex: self.tagColorHex, alpha: 0.55)
            },
            SKAction.wait(forDuration: 0.15),
            SKAction.group([
                SKAction.scale(to: 0.0, duration: 0.2),
                SKAction.fadeOut(withDuration: 0.2)
            ]),
            SKAction.run(completion)
        ])
        run(flash)
    }
    
    /// Fade out when not selected
    func animateDismiss() {
        let dismiss = SKAction.group([
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.scale(to: 0.8, duration: 0.15)
        ])
        run(SKAction.sequence([dismiss, SKAction.removeFromParent()]))
    }
}
