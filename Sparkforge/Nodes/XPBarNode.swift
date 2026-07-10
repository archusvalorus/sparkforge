// XPBarNode.swift
// Sparkforge
//
// Horizontal XP progress bar. Fills left-to-right as XP accumulates.
// Flashes on level up.
// v1.7 legibility pass: larger, bolder, XP numbers live on the bar.

import SpriteKit

final class XPBarNode: SKNode {

    // MARK: - Config

    private let barWidth: CGFloat
    private let barHeight: CGFloat = 14

    // MARK: - Nodes

    private let backgroundBar: SKShapeNode
    private let fillBar: SKShapeNode
    private let valueLabel: SKLabelNode

    // MARK: - Init

    init(width: CGFloat = 120) {
        self.barWidth = width

        // Background (dark track)
        backgroundBar = SKShapeNode(rectOf: CGSize(width: width, height: barHeight), cornerRadius: 4)
        backgroundBar.fillColor = SKColor(hex: 0x2A2215)
        backgroundBar.strokeColor = SKColor(hex: 0x554422, alpha: 0.6)
        backgroundBar.lineWidth = 1

        // Fill (amber, starts empty)
        fillBar = SKShapeNode(rectOf: CGSize(width: 1, height: barHeight), cornerRadius: 4)
        fillBar.fillColor = SKColor(hex: 0xFFAA33)
        fillBar.strokeColor = .clear

        // v1.7: XP numbers on the bar
        valueLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        valueLabel.fontSize = 10
        valueLabel.fontColor = SKColor(hex: 0xFFFFFF)
        valueLabel.verticalAlignmentMode = .center
        valueLabel.horizontalAlignmentMode = .center
        valueLabel.position = .zero
        valueLabel.zPosition = 2

        super.init()

        addChild(backgroundBar)
        addChild(fillBar)
        addChild(valueLabel)

        // "XP" tag left of the bar (pairs with the HP tag below it)
        let tagLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        tagLabel.text = "XP"
        tagLabel.fontSize = 11
        tagLabel.fontColor = SKColor(hex: 0xFFAA33, alpha: 0.8)
        tagLabel.verticalAlignmentMode = .center
        tagLabel.horizontalAlignmentMode = .right
        tagLabel.position = CGPoint(x: -width / 2 - 7, y: 0)
        addChild(tagLabel)

        updateFill(0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Update

    /// Set progress from 0.0 to 1.0. Pass XP numbers to show them on the bar.
    func updateFill(_ progress: CGFloat, currentXP: Int? = nil, requiredXP: Int? = nil) {
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

        if let current = currentXP, let required = requiredXP {
            valueLabel.text = "\(current)/\(required)"
        }
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
