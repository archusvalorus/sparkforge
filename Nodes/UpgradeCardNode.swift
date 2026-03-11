// UpgradeCardNode.swift
// Sparkforge
//
// Visual representation of an upgrade card during level-up selection.
// Styled as a glowing metal plate with tag color accent.

import SpriteKit

final class UpgradeCardNode: SKNode {
    
    // MARK: - Config
    
    static let cardWidth: CGFloat = 90
    static let cardHeight: CGFloat = 130
    
    // MARK: - State
    
    let card: UpgradeManager.UpgradeCard
    private let backgroundNode: SKShapeNode
    private let accentBar: SKShapeNode
    
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
    
    init(card: UpgradeManager.UpgradeCard) {
        self.card = card
        
        let w = UpgradeCardNode.cardWidth
        let h = UpgradeCardNode.cardHeight
        let tagColor = SKColor(hex: UpgradeCardNode.color(for: card.tag))
        
        // Card background — dark metal plate
        backgroundNode = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 8)
        backgroundNode.fillColor = SKColor(hex: 0x222222)
        backgroundNode.strokeColor = tagColor
        backgroundNode.lineWidth = 1.5
        backgroundNode.glowWidth = 2
        
        // Tag color accent bar at top
        accentBar = SKShapeNode(rectOf: CGSize(width: w - 8, height: 4), cornerRadius: 2)
        accentBar.fillColor = tagColor
        accentBar.strokeColor = .clear
        accentBar.position = CGPoint(x: 0, y: h / 2 - 12)
        
        super.init()
        
        isUserInteractionEnabled = false  // Scene handles taps
        
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
        let h = UpgradeCardNode.cardHeight
        
        // Tag emoji
        let tagLabel = SKLabelNode(text: UpgradeCardNode.emoji(for: card.tag))
        tagLabel.fontSize = 20
        tagLabel.position = CGPoint(x: 0, y: h / 2 - 35)
        tagLabel.verticalAlignmentMode = .center
        addChild(tagLabel)
        
        // Card name
        let nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = card.name
        nameLabel.fontSize = 12
        nameLabel.fontColor = tagColor
        nameLabel.position = CGPoint(x: 0, y: 5)
        nameLabel.verticalAlignmentMode = .center
        nameLabel.horizontalAlignmentMode = .center
        addChild(nameLabel)
        
        // Description (wrapped manually for small card)
        let descLines = wrapText(card.description, maxChars: 14)
        for (i, line) in descLines.enumerated() {
            let descLabel = SKLabelNode(fontNamed: "Menlo")
            descLabel.text = line
            descLabel.fontSize = 8
            descLabel.fontColor = SKColor(hex: 0xAAAAAA)
            descLabel.position = CGPoint(x: 0, y: -12 - CGFloat(i) * 11)
            descLabel.verticalAlignmentMode = .center
            descLabel.horizontalAlignmentMode = .center
            addChild(descLabel)
        }
        
        // Tag name at bottom
        let tagNameLabel = SKLabelNode(fontNamed: "Menlo")
        tagNameLabel.text = card.tag.rawValue.uppercased()
        tagNameLabel.fontSize = 7
        tagNameLabel.fontColor = SKColor(hex: 0x666666)
        tagNameLabel.position = CGPoint(x: 0, y: -h / 2 + 12)
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
                self?.backgroundNode.fillColor = SKColor(hex: 0x444444)
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
