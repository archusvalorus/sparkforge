// CodexHubNode.swift
// Sparkforge
//
// v1.8 Unit 10: the CODEX hub — one title-screen entry point that opens a
// small selector for the three codex faces (Synergies / Cards / Bestiary).
// Cards waits on Unit 8, so it shows disabled ("soon") until then. Tapping a
// live face opens its scrollable page; tapping outside closes the hub.

import SpriteKit

final class CodexHubNode: SKNode {

    enum Face { case synergies, cards, bestiary }
    enum Action { case open(Face), close }

    private static let panelW: CGFloat = 280
    private static let panelH: CGFloat = 250

    private let synergiesFrame: CGRect
    private let cardsFrame: CGRect
    private let bestiaryFrame: CGRect

    override init() {
        let bw: CGFloat = 240, bh: CGFloat = 44
        synergiesFrame = CGRect(x: -bw / 2, y: 45 - bh / 2, width: bw, height: bh)
        cardsFrame = CGRect(x: -bw / 2, y: -10 - bh / 2, width: bw, height: bh)
        let bestiaryY: CGFloat = -65
        bestiaryFrame = CGRect(x: -bw / 2, y: bestiaryY - bh / 2, width: bw, height: bh)

        super.init()
        zPosition = 480

        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x000000, alpha: 0.75)
        dim.strokeColor = .clear
        addChild(dim)

        let panel = SKShapeNode(rectOf: CGSize(width: Self.panelW, height: Self.panelH), cornerRadius: 14)
        panel.fillColor = SKColor(hex: 0x141018)
        panel.strokeColor = SKColor(hex: 0xFFAA33, alpha: 0.6)
        panel.lineWidth = 1.5
        panel.glowWidth = 4
        addChild(panel)

        let title = UITheme.label("📖  CODEX", size: UITheme.Size.title, color: UITheme.Color.accent, bold: true)
        title.position = CGPoint(x: 0, y: 96)
        addChild(title)

        addChild(Self.button("⬡  SYNERGIES", center: CGPoint(x: 0, y: 45),
                             size: CGSize(width: 240, height: 44), enabled: true))
        addChild(Self.button("◈  CARDS", center: CGPoint(x: 0, y: -10),
                             size: CGSize(width: 240, height: 44), enabled: true))
        addChild(Self.button("☖  BESTIARY", center: CGPoint(x: 0, y: -65),
                             size: CGSize(width: 240, height: 44), enabled: true))

        let hint = UITheme.label("tap outside to close", size: UITheme.Size.hint, color: UITheme.Color.hint)
        hint.position = CGPoint(x: 0, y: -108)
        addChild(hint)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func button(_ text: String, center: CGPoint, size: CGSize, enabled: Bool) -> SKNode {
        let node = SKNode()
        node.position = center
        let bg = SKShapeNode(rectOf: size, cornerRadius: 8)
        bg.fillColor = enabled ? SKColor(hex: 0x2A1A00) : SKColor(hex: 0x1A1A1A)
        bg.strokeColor = enabled ? SKColor(hex: 0xFFAA33, alpha: 0.7) : SKColor(hex: 0x3A3A3A)
        bg.lineWidth = 1.5
        node.addChild(bg)
        let label = UITheme.label(text, size: UITheme.Size.body,
                                  color: enabled ? UITheme.Color.info : UITheme.Color.disabled, bold: true)
        node.addChild(label)
        return node
    }

    /// Resolve a tap in this node's space to an action (nil = ignore).
    func action(at location: CGPoint) -> Action? {
        if synergiesFrame.contains(location) { return .open(.synergies) }
        if cardsFrame.contains(location) { return .open(.cards) }
        if bestiaryFrame.contains(location) { return .open(.bestiary) }
        let panel = CGRect(x: -Self.panelW / 2, y: -Self.panelH / 2, width: Self.panelW, height: Self.panelH)
        if !panel.contains(location) { return .close }
        return nil
    }

    func present(in parent: SKNode) {
        parent.addChild(self)
        alpha = 0
        run(SKAction.fadeIn(withDuration: 0.15))
    }

    func dismiss() {
        run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.12), SKAction.removeFromParent()]))
    }
}
