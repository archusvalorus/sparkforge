// HPBarNode.swift
// Sparkforge
//
// v1.4: Horizontal HP progress bar.
// v1.6: Health-green fill (matches health-orb language — green = health,
// per color canon) shifting amber → red as it drains. "HP" tag on the left.
// Pulses red at low HP. Shows numeric HP when damaged.

import SpriteKit

final class HPBarNode: SKNode {
    
    // MARK: - Config
    
    private let barWidth: CGFloat
    private let barHeight: CGFloat = 16  // v1.7 legibility pass: 5 → 16
    
    // MARK: - Nodes
    
    private let backgroundBar: SKShapeNode
    private let fillBar: SKShapeNode
    private let hpLabel: SKLabelNode
    private let tagLabel: SKLabelNode  // v1.6: "HP" tag

    // MARK: - State

    private var lastHP: Int = -1
    private var isLowHP: Bool = false
    /// v1.6: current tier color — flashes restore to this, not a hardcoded hex
    private var baseColor = SKColor(hex: 0x44DD66)

    // MARK: - Init

    init(width: CGFloat = 120) {
        self.barWidth = width

        // Background (dark track, green-tinted)
        backgroundBar = SKShapeNode(rectOf: CGSize(width: width, height: barHeight), cornerRadius: 4)
        backgroundBar.fillColor = SKColor(hex: 0x112211)
        backgroundBar.strokeColor = SKColor(hex: 0x224422, alpha: 0.6)
        backgroundBar.lineWidth = 1

        // Fill (health green — same family as health orbs)
        fillBar = SKShapeNode(rectOf: CGSize(width: 1, height: barHeight), cornerRadius: 4)
        fillBar.fillColor = SKColor(hex: 0x44DD66)
        fillBar.strokeColor = .clear

        // v1.7: HP numbers live ON the bar, always visible
        hpLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        hpLabel.fontSize = 11
        hpLabel.fontColor = SKColor(hex: 0xFFFFFF)
        hpLabel.verticalAlignmentMode = .center
        hpLabel.horizontalAlignmentMode = .center
        hpLabel.position = .zero
        hpLabel.zPosition = 2

        // v1.6: "HP" tag left of the bar
        tagLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        tagLabel.text = "HP"
        tagLabel.fontSize = 11
        tagLabel.fontColor = SKColor(hex: 0x44DD66, alpha: 0.8)
        tagLabel.verticalAlignmentMode = .center
        tagLabel.horizontalAlignmentMode = .right
        tagLabel.position = CGPoint(x: -width / 2 - 7, y: 0)

        super.init()

        addChild(backgroundBar)
        addChild(fillBar)
        addChild(hpLabel)
        addChild(tagLabel)

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
            cornerWidth: 4,
            cornerHeight: 4,
            transform: nil
        )
        
        // v1.6: health green → warning amber → danger red as it drains
        if clamped > 0.6 {
            baseColor = SKColor(hex: 0x44DD66)  // Health green (orb language)
        } else if clamped > 0.25 {
            baseColor = SKColor(hex: 0xEE8833)  // Warning amber-orange
        } else {
            baseColor = SKColor(hex: 0xFF1111)  // Danger red
        }
        fillBar.fillColor = baseColor
        
        // v1.7: numbers always on the bar
        hpLabel.text = "\(max(currentHP, 0))/\(maxHP)"
        
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
    
    /// Brief red flash on taking damage (v1.6: restores to tier color)
    func flashDamage() {
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in self?.fillBar.fillColor = SKColor(hex: 0xFF5544) },
            SKAction.wait(forDuration: 0.08),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.fillBar.fillColor = self.baseColor
            }
        ])
        run(flash, withKey: "hpFlash")
    }

    // MARK: - Heal Flash

    /// Brief bright-mint flash on healing (v1.6: reads against the green bar)
    func flashHeal() {
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in self?.fillBar.fillColor = SKColor(hex: 0xBBFFCC) },
            SKAction.wait(forDuration: 0.12),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.fillBar.fillColor = self.baseColor
            }
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
