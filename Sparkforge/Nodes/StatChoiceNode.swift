// StatChoiceNode.swift
// Sparkforge
//
// v1.9 Unit 4: the even-level stat choice. Before the skill card, the player
// picks one of three stat lanes (+MAX HP / +ATK / +DEF) — agency over their
// run's foundation, independent of card RNG. Card-family styling; the scene
// forwards a tap to statAt(_:) and advances to the skill card on selection.

import SpriteKit

final class StatChoiceNode: SKNode {

    static let cardWidth: CGFloat = 96
    static let cardHeight: CGFloat = 122

    /// Hit frames in this node's space → stat lane.
    private var hits: [(kind: PlayerStats.StatKind, frame: CGRect)] = []
    private var cardNodes: [PlayerStats.StatKind: SKNode] = [:]

    override init() {
        super.init()
        zPosition = 192   // just above the level-up overlay (190)

        let bg = SKShapeNode(rectOf: CGSize(width: 2000, height: 2000))
        bg.fillColor = SKColor(hex: 0x000000, alpha: 0.78)
        bg.strokeColor = .clear
        addChild(bg)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "CHOOSE A STAT"
        title.fontSize = 20
        title.fontColor = SKColor(hex: 0xFFAA33)
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 96)
        addChild(title)

        let sub = SKLabelNode(fontNamed: "Menlo")
        sub.text = "strengthen your foundation"
        sub.fontSize = 11
        sub.fontColor = SKColor(hex: 0xBBBBBB)
        sub.verticalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: 72)
        addChild(sub)

        let kinds = PlayerStats.StatKind.allCases
        let spacing: CGFloat = 108
        let startX = -spacing * CGFloat(kinds.count - 1) / 2
        for (i, kind) in kinds.enumerated() {
            let x = startX + spacing * CGFloat(i)
            let card = Self.card(for: kind)
            card.position = CGPoint(x: x, y: -6)
            addChild(card)
            cardNodes[kind] = card
            hits.append((kind, CGRect(x: x - Self.cardWidth / 2, y: -6 - Self.cardHeight / 2,
                                      width: Self.cardWidth, height: Self.cardHeight)))
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func card(for kind: PlayerStats.StatKind) -> SKNode {
        let node = SKNode()
        let tag = SKColor(hex: kind.colorHex)

        let plate = SKShapeNode(rectOf: CGSize(width: cardWidth, height: cardHeight), cornerRadius: 8)
        plate.fillColor = SKColor(hex: 0x161616)
        plate.strokeColor = .clear
        node.addChild(plate)

        let wash = SKShapeNode(rectOf: CGSize(width: cardWidth, height: cardHeight), cornerRadius: 8)
        wash.fillColor = SKColor(hex: kind.colorHex, alpha: 0.20)
        wash.strokeColor = tag
        wash.lineWidth = 1.5
        wash.glowWidth = 2
        node.addChild(wash)

        let emoji = SKLabelNode(text: kind.emoji)
        emoji.fontSize = 30
        emoji.verticalAlignmentMode = .center
        emoji.position = CGPoint(x: 0, y: 30)
        node.addChild(emoji)

        let value = SKLabelNode(fontNamed: "Menlo-Bold")
        value.text = "+\(kind.bonus)"
        value.fontSize = 26
        value.fontColor = UpgradeCardNode.brightColor(hex: kind.colorHex)
        value.verticalAlignmentMode = .center
        value.position = CGPoint(x: 0, y: -8)
        node.addChild(value)

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = kind.label
        label.fontSize = 12
        label.fontColor = SKColor(hex: 0xFFFFFF)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -38)
        node.addChild(label)

        return node
    }

    /// Which stat lane (if any) a tap in this node's space hit.
    func statAt(_ location: CGPoint) -> PlayerStats.StatKind? {
        hits.first(where: { $0.frame.contains(location) })?.kind
    }

    func present(in parent: SKNode) {
        parent.addChild(self)
        alpha = 0
        run(SKAction.fadeIn(withDuration: 0.18))
    }

    /// Flash the chosen card, dismiss the rest, then run completion.
    func animateSelection(_ kind: PlayerStats.StatKind, completion: @escaping () -> Void) {
        for (k, node) in cardNodes where k != kind {
            node.run(SKAction.group([SKAction.fadeOut(withDuration: 0.15),
                                     SKAction.scale(to: 0.85, duration: 0.15)]))
        }
        let chosen = cardNodes[kind]
        chosen?.run(SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.1),
            SKAction.wait(forDuration: 0.12),
            SKAction.group([SKAction.scale(to: 0.0, duration: 0.18),
                            SKAction.fadeOut(withDuration: 0.18)])
        ]))
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.42),
            SKAction.fadeOut(withDuration: 0.12),
            SKAction.removeFromParent(),
            SKAction.run(completion)
        ]))
    }

    func dismiss() {
        run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.12), SKAction.removeFromParent()]))
    }
}
