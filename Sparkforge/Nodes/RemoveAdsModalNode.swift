// RemoveAdsModalNode.swift
// Sparkforge
//
// v1.8 (E3/E4): the shared "Remove All Ads" value-prop modal.
//
// The rewarded placements are invisible until players hit them, so this
// modal makes the value legible: removing ads keeps every earned reward,
// now as a free tap. Shown BEFORE the StoreKit sheet.
//
// One source of truth for both surfaces that present it:
//   • TitleScene — the title-screen Remove Ads button (E3)
//   • GameScene  — the in-run upper-left Remove Ads button (E4 non-owner)
// so the two never drift. The host scene owns the purchase call and the
// button's own state; this node owns only the modal UI + its hit-testing.

import SpriteKit

final class RemoveAdsModalNode: SKNode {

    /// Buy-button hit rect, in this node's own coordinate space. The node is
    /// presented at its parent's origin, so a location in the parent's space
    /// maps 1:1 to this space.
    private static let buyFrame = CGRect(x: -120, y: -74 - 22, width: 240, height: 44)

    private let panel: SKShapeNode
    private let buyLabel: SKLabelNode

    /// Localized price string from StoreKit. `nil` → the button shows no
    /// number rather than a wrong one.
    var priceText: String? {
        didSet { buyLabel.text = Self.buyText(price: priceText) }
    }

    override init() {
        panel = SKShapeNode(rectOf: CGSize(width: 300, height: 300), cornerRadius: 14)
        buyLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        super.init()

        zPosition = 300

        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.75)
        dim.strokeColor = .clear
        addChild(dim)

        panel.fillColor = SKColor(hex: 0x1A1208)
        panel.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.7)
        panel.lineWidth = 1.5
        panel.glowWidth = 5
        addChild(panel)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "REMOVE ALL ADS"
        title.fontSize = 18
        title.fontColor = SKColor(hex: 0xFFAA33)
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 122)
        addChild(title)

        let sub = SKLabelNode(fontNamed: "Menlo")
        sub.text = "keep every reward"
        sub.fontSize = 13
        sub.fontColor = SKColor(hex: 0xCCCCCC)
        sub.verticalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: 98)
        addChild(sub)

        let explain = SKLabelNode(fontNamed: "Menlo")
        explain.text = "every rewarded moment becomes a free tap:"
        explain.fontSize = 10
        explain.fontColor = SKColor(hex: 0x999999)
        explain.verticalAlignmentMode = .center
        explain.position = CGPoint(x: 0, y: 70)
        addChild(explain)

        let rewards = ["Revive", "Extra Pick", "Reroll", "Blessing Choice", "Extra Card", "XP Boost"]
        for (i, r) in rewards.enumerated() {
            let item = SKLabelNode(fontNamed: "Menlo-Bold")
            item.text = "✓ \(r)"
            item.fontSize = 12
            item.fontColor = SKColor(hex: 0x88CC88)
            item.verticalAlignmentMode = .center
            item.horizontalAlignmentMode = .left
            item.position = CGPoint(x: i % 2 == 0 ? -124 : 8, y: 42 - CGFloat(i / 2) * 24)
            addChild(item)
        }

        let buyBtn = SKShapeNode(rectOf: CGSize(width: 240, height: 44), cornerRadius: 9)
        buyBtn.fillColor = SKColor(hex: 0x332200)
        buyBtn.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.7)
        buyBtn.lineWidth = 1.5
        buyBtn.position = CGPoint(x: 0, y: -74)
        addChild(buyBtn)

        buyLabel.text = Self.buyText(price: nil)
        buyLabel.fontSize = 15
        buyLabel.fontColor = SKColor(hex: 0xFFAA33)
        buyLabel.verticalAlignmentMode = .center
        buyLabel.position = CGPoint(x: 0, y: -74)
        addChild(buyLabel)

        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "tap outside to cancel"
        hint.fontSize = 11
        hint.fontColor = SKColor(hex: 0x666666)
        hint.verticalAlignmentMode = .center
        hint.position = CGPoint(x: 0, y: -118)
        addChild(hint)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Copy

    static func buyText(price: String?) -> String {
        if let price = price {
            return "Remove Ads — \(price)"
        }
        // No price known yet — show no number rather than a wrong one.
        return "Remove Ads"
    }

    // MARK: - Interaction

    /// `true` if the buy button was tapped. The caller dismisses the modal in
    /// either case (a tap outside cancels).
    /// - Parameter location: touch location in this node's parent coordinate
    ///   space (the node sits at the parent's origin).
    func hitTestBuy(at location: CGPoint) -> Bool {
        return Self.buyFrame.contains(location)
    }

    // MARK: - Presentation

    func present(in parent: SKNode) {
        parent.addChild(self)
        alpha = 0
        panel.setScale(0.85)
        run(SKAction.fadeIn(withDuration: 0.2))
        let pop = SKAction.scale(to: 1.0, duration: 0.2)
        pop.timingMode = .easeOut
        panel.run(pop)
    }

    func dismiss() {
        run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))
    }
}
