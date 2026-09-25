// BossStatusTellNode.swift
// Sparkforge
//
// v2.1 Abilities A4a placeholder tell (A9 art replaces it): an arena boss's
// Burn and Bleed, as a small row pinned just right of its HP bar. Bosses
// can't reuse the enemy rim tell — the Slag Titan's rim is already molten
// orange, the Marchwarden's turns orange as it advances, and the Faceted
// Lie's own damage reads are never red/orange — so every boss wears the same
// row instead: a blood drop while bleeding (flaring on each tick), then one
// ember pip per Burn stack (gold while burning, dimmed while dormant).

import SpriteKit

final class BossStatusTellNode: SKNode {

    private let drop: SKShapeNode
    private var pips: [SKShapeNode] = []
    private var drawnStacks = -1
    private var drawnBurning = false
    private var drawnBleeding = false

    private static let dropSlot: CGFloat = 4
    private static let pipStart: CGFloat = 13
    private static let pipSpacing: CGFloat = 6

    override init() {
        let r: CGFloat = 3.2
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: r * 1.9))
        path.addQuadCurve(to: CGPoint(x: r, y: -r * 0.2), control: CGPoint(x: r * 0.9, y: r * 0.9))
        path.addArc(center: CGPoint(x: 0, y: -r * 0.2), radius: r, startAngle: 0, endAngle: .pi, clockwise: true)
        path.addQuadCurve(to: CGPoint(x: 0, y: r * 1.9), control: CGPoint(x: -r * 0.9, y: r * 0.9))
        drop = SKShapeNode(path: path)
        drop.fillColor = SKColor(hex: 0xE0203A)
        drop.strokeColor = SKColor(hex: 0xFF8A99, alpha: 0.8)
        drop.lineWidth = 0.8
        drop.position = CGPoint(x: BossStatusTellNode.dropSlot, y: -1)
        drop.isHidden = true
        super.init()
        zPosition = 12
        addChild(drop)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Redraw only when something visible changed.
    func refresh(burnStacks: Int, burning: Bool, bleeding: Bool) {
        if bleeding != drawnBleeding {
            drawnBleeding = bleeding
            drop.isHidden = !bleeding
        }
        guard burnStacks != drawnStacks || burning != drawnBurning else { return }
        drawnStacks = burnStacks
        drawnBurning = burning
        while pips.count < burnStacks {
            let pip = SKShapeNode(circleOfRadius: 2.4)
            pip.strokeColor = .clear
            pip.position = CGPoint(x: BossStatusTellNode.pipStart + CGFloat(pips.count) * BossStatusTellNode.pipSpacing, y: 0)
            addChild(pip)
            pips.append(pip)
        }
        for (i, pip) in pips.enumerated() {
            pip.isHidden = i >= burnStacks
            pip.fillColor = SKColor(hex: burning ? 0xFFB84D : 0x8A4A2A, alpha: burning ? 1.0 : 0.55)
            pip.glowWidth = burning ? 2 : 0
        }
    }

    /// v2.1 A6 (CL-73 placeholder tell): Phase's Anomaly on the boss — a second
    /// row of indigo diamonds, one per stack, dimmed while the 2s trigger
    /// cooldown runs. Never purple (purple = danger).
    private var anomalyPips: [SKShapeNode] = []
    private var drawnAnomaly = -1
    private var drawnAnomalyCooling = false

    func refreshAnomaly(stacks: Int, cooling: Bool, threshold: Int) {
        guard stacks != drawnAnomaly || cooling != drawnAnomalyCooling else { return }
        drawnAnomaly = stacks
        drawnAnomalyCooling = cooling
        while anomalyPips.count < threshold {
            let pip = SKShapeNode(rectOf: CGSize(width: 3.4, height: 3.4))
            pip.zRotation = .pi / 4
            pip.strokeColor = .clear
            pip.fillColor = SKColor(hex: GameConfig.VoidTree.indigoLightHex)
            pip.glowWidth = 1.5
            pip.position = CGPoint(x: BossStatusTellNode.dropSlot + CGFloat(anomalyPips.count) * BossStatusTellNode.pipSpacing,
                                   y: -8)
            addChild(pip)
            anomalyPips.append(pip)
        }
        for (i, pip) in anomalyPips.enumerated() {
            pip.isHidden = !(i < stacks || cooling)
            pip.alpha = cooling ? 0.3 : 1.0
        }
    }

    /// A Bleed tick landed: the drop flares.
    func pulseBleed() {
        drop.removeAction(forKey: "bleedTick")
        drop.setScale(1.45)
        drop.run(SKAction.scale(to: 1.0, duration: 0.2), withKey: "bleedTick")
    }
}
