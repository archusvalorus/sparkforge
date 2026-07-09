// BuffTrackerNode.swift
// Sparkforge
//
// Compact HUD element showing upgrade tag counts.
// Displays colored pips with counts for each active tag.
// Only shows tags the player has picked at least 1 card from.
// Highlights synergy thresholds (3/5/7) with a glow.

import SpriteKit

final class BuffTrackerNode: SKNode {
    
    // MARK: - Config
    
    private struct TagDisplay {
        let tag: UpgradeManager.Tag
        let colorHex: UInt32
        let emoji: String
    }
    
    private let tagDisplays: [TagDisplay] = [
        TagDisplay(tag: .fire,   colorHex: 0xFF6633, emoji: "🔥"),
        TagDisplay(tag: .shock,  colorHex: 0x44BBFF, emoji: "⚡"),
        TagDisplay(tag: .bleed,  colorHex: 0xCC3333, emoji: "🩸"),
        TagDisplay(tag: .guardT, colorHex: 0x88AA44, emoji: "🛡️"),
        TagDisplay(tag: .voidT,  colorHex: 0x9944CC, emoji: "🕳️"),
        TagDisplay(tag: .chill,  colorHex: 0x66DDFF, emoji: "❄️"),
    ]
    
    // MARK: - Nodes
    
    /// Container for the pip rows
    private var pipRows: [SKNode] = []
    
    // MARK: - Init
    
    override init() {
        super.init()
        zPosition = 100
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Update
    
    /// Rebuild the display based on current tag counts.
    /// Call after each card pick.
    func update(tagCounts: [UpgradeManager.Tag: Int]) {
        // Clear existing
        removeAllChildren()
        pipRows.removeAll()
        
        var yOffset: CGFloat = 0
        let rowHeight: CGFloat = 16
        
        for display in tagDisplays {
            let count = tagCounts[display.tag] ?? 0
            guard count > 0 else { continue }
            
            let row = SKNode()
            row.position = CGPoint(x: 0, y: yOffset)
            
            // Tag color pip
            let pip = SKShapeNode(circleOfRadius: 4)
            pip.fillColor = SKColor(hex: display.colorHex)
            pip.strokeColor = .clear
            pip.position = CGPoint(x: 0, y: 0)
            
            // Glow at synergy thresholds
            if count >= 7 {
                pip.glowWidth = 6
            } else if count >= 5 {
                pip.glowWidth = 4
            } else if count >= 3 {
                pip.glowWidth = 2
            }
            
            row.addChild(pip)
            
            // Count label
            let countLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            countLabel.text = "\(count)"
            countLabel.fontSize = 9
            countLabel.fontColor = SKColor(hex: display.colorHex)
            countLabel.horizontalAlignmentMode = .left
            countLabel.verticalAlignmentMode = .center
            countLabel.position = CGPoint(x: 8, y: 0)
            row.addChild(countLabel)
            
            // Synergy tier indicator
            if count >= 3 {
                let tierDots = count >= 7 ? "●●●" : count >= 5 ? "●●" : "●"
                let tierLabel = SKLabelNode(fontNamed: "Menlo")
                tierLabel.text = tierDots
                tierLabel.fontSize = 6
                tierLabel.fontColor = SKColor(hex: display.colorHex, alpha: 0.6)
                tierLabel.horizontalAlignmentMode = .left
                tierLabel.verticalAlignmentMode = .center
                tierLabel.position = CGPoint(x: 20, y: 0)
                row.addChild(tierLabel)
            }
            
            addChild(row)
            pipRows.append(row)
            
            yOffset -= rowHeight
        }
    }
}
