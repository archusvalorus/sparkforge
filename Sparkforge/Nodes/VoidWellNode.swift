// VoidWellNode.swift
// Sparkforge
//
// v2.1 Abilities A6 (Void): ONE parametric black hole for every preset —
// Gravity Well (a spent primary shot), Null Bloom (small, from a kill) and the
// ×3 Blackhole (every 5th primary volley). Its rules live in `VoidWellState`
// (pure, proven by tools/void-harness); this node is the placeholder look
// (A9 art replaces it) and a handle the scene drives. Replaces the v1.6
// GravityWellNode and Null Bloom's slowing zone.
//
// Deep indigo, deliberately NOT purple — purple is enemy danger (CL-86).

import SpriteKit

final class VoidWellNode: SKNode {

    var state: VoidWellState {
        didSet {
            if abs(state.radius - drawnRadius) > 0.5 { redraw() }
        }
    }

    private let ringNode = SKShapeNode()
    private let coreNode = SKShapeNode()
    private let swirlNode = SKShapeNode()
    private var drawnRadius: CGFloat = 0

    init(state: VoidWellState) {
        self.state = state
        super.init()

        let V = GameConfig.VoidTree.self
        ringNode.strokeColor = SKColor(hex: V.indigoHex, alpha: 0.55)
        ringNode.fillColor = SKColor(hex: V.indigoDeepHex, alpha: state.preset == .nullBloom ? 0.12 : 0.18)
        ringNode.lineWidth = 1.5
        ringNode.glowWidth = 4
        ringNode.zPosition = 0
        // The ×3 Blackhole reads heavier: a near-black core.
        coreNode.fillColor = SKColor(hex: 0x05060F, alpha: state.preset == .blackhole ? 0.85 : 0.0)
        coreNode.strokeColor = .clear
        coreNode.zPosition = 0.5
        swirlNode.strokeColor = SKColor(hex: V.indigoLightHex, alpha: 0.6)
        swirlNode.fillColor = .clear
        swirlNode.lineWidth = 1.5
        swirlNode.zPosition = 1
        addChild(ringNode)
        addChild(coreNode)
        addChild(swirlNode)
        redraw()

        swirlNode.run(SKAction.repeatForever(SKAction.rotate(byAngle: -.pi * 2, duration: 0.8)))
        ringNode.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 0.92, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ])))
        setScale(0.0)
        run(SKAction.scale(to: 1.0, duration: 0.15))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    /// Dead Circuit growth redraws the hole at its new radius.
    private func redraw() {
        let r = state.radius
        drawnRadius = r
        ringNode.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
        let core = r * 0.35
        coreNode.path = CGPath(ellipseIn: CGRect(x: -core, y: -core, width: core * 2, height: core * 2), transform: nil)
        let swirl = CGMutablePath()
        swirl.addArc(center: .zero, radius: r * 0.5, startAngle: 0, endAngle: .pi * 1.4, clockwise: false)
        swirlNode.path = swirl
    }

    /// A hostile projectile vanished into the hole.
    func showAbsorb(at point: CGPoint) {
        let spark = SKShapeNode(circleOfRadius: 3)
        spark.fillColor = SKColor(hex: GameConfig.VoidTree.indigoLightHex)
        spark.strokeColor = .clear
        spark.glowWidth = 3
        spark.position = point - position
        spark.zPosition = 2
        addChild(spark)
        spark.run(SKAction.sequence([
            SKAction.group([SKAction.move(to: .zero, duration: 0.12), SKAction.scale(to: 0.2, duration: 0.12)]),
            SKAction.removeFromParent()
        ]))
    }

    /// Leave the world. A Dead Circuit collapse flashes outward first.
    func collapseAndRemove(burst: Bool) {
        removeAllActions()
        if burst, let parent = parent {
            let r = state.radius
            let flash = SKShapeNode(circleOfRadius: r)
            flash.strokeColor = SKColor(hex: 0xFFFFFF, alpha: 0.9)
            flash.fillColor = SKColor(hex: GameConfig.VoidTree.indigoHex, alpha: 0.35)
            flash.lineWidth = 3
            flash.glowWidth = 6
            flash.position = position
            flash.zPosition = zPosition + 1
            parent.addChild(flash)
            flash.run(SKAction.sequence([
                SKAction.group([SKAction.scale(to: 1.35, duration: 0.25), SKAction.fadeOut(withDuration: 0.25)]),
                SKAction.removeFromParent()
            ]))
        }
        run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 0.0, duration: 0.2),
                SKAction.fadeOut(withDuration: 0.2)
            ]),
            SKAction.removeFromParent()
        ]))
    }
}
