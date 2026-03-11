// XPBarNode.swift
// Sparkforge
//
// Thin horizontal XP progress bar.
// Fills left-to-right as XP accumulates.
// Flashes on level up.

import SpriteKit

final class XPBarNode: SKNode {
    
    // MARK: - Config
    
    private let barWidth: CGFloat
    private let barHeight: CGFloat = 4
    
    // MARK: - Nodes
    
    private let backgroundBar: SKShapeNode
    private let fillBar: SKShapeNode
    
    // MARK: - Init
    
    init(width: CGFloat = 120) {
        self.barWidth = width
        
        // Background (dark track)
        backgroundBar = SKShapeNode(rectOf: CGSize(width: width, height: barHeight), cornerRadius: 2)
        backgroundBar.fillColor = SKColor(hex: 0x333333)
        backgroundBar.strokeColor = .clear
        
        // Fill (amber, starts empty)
        fillBar = SKShapeNode(rectOf: CGSize(width: 1, height: barHeight), cornerRadius: 2)
        fillBar.fillColor = SKColor(hex: 0xFFAA33)
        fillBar.strokeColor = .clear
        
        super.init()
        
        addChild(backgroundBar)
        addChild(fillBar)
        
        updateFill(0)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Update
    
    /// Set progress from 0.0 to 1.0
    func updateFill(_ progress: CGFloat) {
        let clamped = max(0, min(progress, 1.0))
        let fillWidth = max(1, barWidth * clamped)
        
        fillBar.path = CGPath(
            roundedRect: CGRect(
                x: -barWidth / 2,
                y: -barHeight / 2,
                width: fillWidth,
                height: barHeight
            ),
            cornerWidth: 2,
            cornerHeight: 2,
            transform: nil
        )
    }
    
    // MARK: - Level Up Flash
    
    func flashLevelUp() {
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in self?.fillBar.fillColor = SKColor(hex: 0xFFFFFF) },
            SKAction.wait(forDuration: 0.15),
            SKAction.run { [weak self] in self?.fillBar.fillColor = SKColor(hex: 0xFFAA33) }
        ])
        run(flash)
        updateFill(0)
    }
}
