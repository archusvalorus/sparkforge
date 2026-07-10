// BuffTrackerNode.swift
// Sparkforge
//
// HUD element showing upgrade tag counts, anchored to the left edge.
// v1.7 Buff Badges: the tiny pips grew up — one card-style badge per
// tree (translucent tree-tinted plate, colored stroke, emoji + count),
// legible at arm's length. Synergy tiers hit (3/5/7) brighten the
// stroke. Only shows trees the player has picked at least 1 card from.

import SpriteKit

final class BuffTrackerNode: SKNode {

    // MARK: - Config

    /// Display order on the HUD — matches the pre-v1.7 pip order
    private static let tagOrder: [UpgradeManager.Tag] = [
        .fire, .shock, .bleed, .guardT, .voidT, .chill
    ]

    private static let badgeSize = CGSize(width: 58, height: 26)
    private static let rowHeight: CGFloat = 32

    // MARK: - State

    /// Previous counts, so a freshly increased badge can pop
    private var lastCounts: [UpgradeManager.Tag: Int] = [:]

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
        removeAllChildren()

        var yOffset: CGFloat = 0
        for tag in Self.tagOrder {
            let count = tagCounts[tag] ?? 0
            guard count > 0 else { continue }

            let badge = Self.badge(tag: tag, count: count)
            badge.position = CGPoint(x: 0, y: yOffset)
            addChild(badge)

            // Pop the badge whose count just grew
            if count > (lastCounts[tag] ?? 0) {
                badge.setScale(1.25)
                badge.run(SKAction.scale(to: 1.0, duration: 0.18))
            }

            yOffset -= Self.rowHeight
        }

        lastCounts = tagCounts
    }

    // MARK: - Badge

    private static func badge(tag: UpgradeManager.Tag, count: Int) -> SKNode {
        let badge = SKNode()
        let colorHex = UpgradeCardNode.color(for: tag)
        let size = badgeSize
        // Plate leading edge sits on x=0 so badges hug the safe-area edge
        let center = CGPoint(x: size.width / 2, y: 0)

        let plate = SKShapeNode(rectOf: size, cornerRadius: 6)
        plate.fillColor = SKColor(hex: 0x161616, alpha: 0.55)
        plate.strokeColor = .clear
        plate.position = center
        badge.addChild(plate)

        // Stroke brightens as synergy tiers land (3/5/7)
        let wash = SKShapeNode(rectOf: size, cornerRadius: 6)
        wash.fillColor = SKColor(hex: colorHex, alpha: 0.25)
        wash.position = center
        switch count {
        case ..<3:
            wash.strokeColor = SKColor(hex: colorHex, alpha: 0.45)
            wash.lineWidth = 1
        case 3..<5:
            wash.strokeColor = SKColor(hex: colorHex, alpha: 0.75)
            wash.lineWidth = 1.5
            wash.glowWidth = 1
        case 5..<7:
            wash.strokeColor = SKColor(hex: colorHex, alpha: 0.95)
            wash.lineWidth = 1.5
            wash.glowWidth = 2
        default:
            wash.strokeColor = SKColor(hex: colorHex)
            wash.lineWidth = 2
            wash.glowWidth = 3
        }
        badge.addChild(wash)

        let emoji = SKLabelNode(text: UpgradeCardNode.emoji(for: tag))
        emoji.fontSize = 14
        emoji.verticalAlignmentMode = .center
        emoji.position = CGPoint(x: 15, y: 0)
        badge.addChild(emoji)

        let countLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        countLabel.text = "\(count)"
        countLabel.fontSize = 15
        countLabel.fontColor = SKColor(hex: colorHex)
        countLabel.horizontalAlignmentMode = .left
        countLabel.verticalAlignmentMode = .center
        countLabel.position = CGPoint(x: 29, y: 0)
        badge.addChild(countLabel)

        return badge
    }
}
