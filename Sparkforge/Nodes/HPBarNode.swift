// HPBarNode.swift
// Sparkforge
//
// v1.4: Horizontal HP progress bar.
// Fills left-to-right. Red-orange gradient feel.
// Pulses red at low HP. Shows numeric HP when damaged.

import SpriteKit

final class HPBarNode: SKNode {
    
    // MARK: - Config
    
    private let barWidth: CGFloat
    private let barHeight: CGFloat = 5
    
    // MARK: - Nodes
    
    private let backgroundBar: SKShapeNode
    private let fillBar: SKShapeNode
    private let hpLabel: SKLabelNode
    
    // MARK: - State
    
    private var lastHP: Int = -1
    private var isLowHP: Bool = false
    
    // MARK: - Init
    
    init(width: CGFloat = 120) {
        self.barWidth = width
        
        // Background (dark track)
        backgroundBar = SKShapeNode(rectOf: CGSize(width: width, height: barHeight), cornerRadius: 2.5)
        backgroundBar.fillColor = SKColor(hex: 0x331111)
        backgroundBar.strokeColor = SKColor(hex: 0x441111, alpha: 0.5)
        backgroundBar.lineWidth = 0.5
        
        // Fill (red-orange)
        fillBar = SKShapeNode(rectOf: CGSize(width: 1, height: barHeight), cornerRadius: 2.5)
        fillBar.fillColor = SKColor(hex: 0xDD4422)
        fillBar.strokeColor = .clear
        
        // HP number label — only visible when damaged
        hpLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        hpLabel.fontSize = 8
        hpLabel.fontColor = SKColor(hex: 0xFF6644)
        hpLabel.verticalAlignmentMode = .center
        hpLabel.horizontalAlignmentMode = .center
        hpLabel.position = CGPoint(x: 0, y: -12)
        hpLabel.alpha = 0
        
        super.init()
        
        addChild(backgroundBar)
        addChild(fillBar)
        addChild(hpLabel)
        
        updateFill(1.0, currentHP: GameConfig.Player.baseMaxHP, maxHP: GameConfig.Player.baseMaxHP)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Update
    
    /// Update HP bar. Shows numeric HP when not at full health.
    func updateFill(_ progress: CGFloat, currentHP: Int, maxHP: Int) {
        let clamped = max(0, min(progress, 1.0))
        let fillWidth = max(1, barWidth * clamped)
        
        fillBar.path = CGPath(
            roundedRect: CGRect(
                x: -barWidth / 2,
                y: -barHeight / 2,
                width: fillWidth,
                height: barHeight
            ),
            cornerWidth: 2.5,
            cornerHeight: 2.5,
            transform: nil
        )
        
        // Color shifts: green-ish at full → orange at half → red at low
        if clamped > 0.6 {
            fillBar.fillColor = SKColor(hex: 0xDD4422)  // Standard red-orange
        } else if clamped > 0.25 {
            fillBar.fillColor = SKColor(hex: 0xFF3311)  // Deeper red
        } else {
            fillBar.fillColor = SKColor(hex: 0xFF1111)  // Danger red
        }
        
        // Show/hide HP label
        if currentHP < maxHP && currentHP > 0 {
            hpLabel.text = "\(currentHP)/\(maxHP)"
            if hpLabel.alpha < 1 {
                hpLabel.run(SKAction.fadeAlpha(to: 1.0, duration: 0.15))
            }
        } else {
            if hpLabel.alpha > 0 {
                hpLabel.run(SKAction.fadeAlpha(to: 0, duration: 0.3))
            }
        }
        
        // Low HP pulse
        let newLowHP = clamped <= 0.25 && currentHP > 0
        if newLowHP && !isLowHP {
            startLowHPPulse()
        } else if !newLowHP && isLowHP {
            stopLowHPPulse()
        }
        isLowHP = newLowHP
        
        lastHP = currentHP
    }
    
    // MARK: - Damage Flash
    
    /// Brief white flash on taking damage
    func flashDamage() {
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in self?.fillBar.fillColor = SKColor(hex: 0xFFFFFF) },
            SKAction.wait(forDuration: 0.08),
            SKAction.run { [weak self] in self?.fillBar.fillColor = SKColor(hex: 0xDD4422) }
        ])
        run(flash, withKey: "hpFlash")
    }
    
    // MARK: - Heal Flash
    
    /// Brief green flash on healing
    func flashHeal() {
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in self?.fillBar.fillColor = SKColor(hex: 0x44DD66) },
            SKAction.wait(forDuration: 0.12),
            SKAction.run { [weak self] in self?.fillBar.fillColor = SKColor(hex: 0xDD4422) }
        ])
        run(flash, withKey: "hpFlash")
    }
    
    // MARK: - Low HP Pulse
    
    private func startLowHPPulse() {
        let pulse = SKAction.sequence([
            SKAction.run { [weak self] in self?.fillBar.alpha = 0.5 },
            SKAction.wait(forDuration: 0.3),
            SKAction.run { [weak self] in self?.fillBar.alpha = 1.0 },
            SKAction.wait(forDuration: 0.3)
        ])
        fillBar.run(SKAction.repeatForever(pulse), withKey: "lowHPPulse")
    }
    
    private func stopLowHPPulse() {
        fillBar.removeAction(forKey: "lowHPPulse")
        fillBar.alpha = 1.0
    }
}
