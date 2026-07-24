// TreeNode.swift
// Sparkforge
//
// v2.0 Phase C (C1.6) — the Growth capstone made flesh: one deeply cultivated
// organism that grows through five tiers, sapling → awakened forest.
//
//   T1 Sapling · T2 Rootreach · T3 Shelter · T4 Wild Domain · T5 The Forest Wakes
//
// The node owns only its LOOK per tier. All effects (move speed, regen, the
// animal launcher) live in GameScene reading playerStats.treeTier — the same
// dumb-body / smart-scene split the flowers use. It visibly matures rather than
// being replaced, so it tells one continuous lifecycle (creative handoff §6).

import SpriteKit

final class TreeNode: SKNode {

    private let trunk = SKShapeNode()
    private var canopy: [SKShapeNode] = []
    private(set) var tier = 0

    override init() {
        super.init()
        zPosition = 3   // above the ground, below Spark
        trunk.fillColor = SKColor(hex: 0x5A3A1A)   // bark brown
        trunk.strokeColor = .clear
        addChild(trunk)
        setTier(1)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    /// Grow to a tier. Rebuilds the silhouette and pops so the growth reads.
    func setTier(_ newTier: Int) {
        tier = newTier
        canopy.forEach { $0.removeFromParent() }
        canopy.removeAll()

        // Trunk thickens and rises with the tier.
        let h = 14 + CGFloat(newTier) * 9
        let w = 3 + CGFloat(newTier) * 0.9
        trunk.path = CGPath(rect: CGRect(x: -w/2, y: 0, width: w, height: h), transform: nil)

        // Canopy: more, larger, richer clumps as it matures. T5 goes vivid —
        // the forest is awake.
        let clumps = 1 + newTier                    // 2 … 6
        let leaf = newTier >= 5 ? 0x6Fe37a : 0x2E8B47
        let base = CGPoint(x: 0, y: h)
        for i in 0..<clumps {
            let ang = CGFloat(i) / CGFloat(clumps) * 2 * .pi
            let spread = 6 + CGFloat(newTier) * 3
            let r = 8 + CGFloat(newTier) * 2.2
            let clump = SKShapeNode(circleOfRadius: r)
            clump.fillColor = SKColor(hex: UInt32(leaf), alpha: 0.95)
            clump.strokeColor = SKColor(hex: 0x174A2A, alpha: 0.5)
            clump.lineWidth = 1
            clump.position = CGPoint(x: base.x + cos(ang) * spread * 0.5,
                                     y: base.y + sin(ang) * spread * 0.35 + spread * 0.4)
            addChild(clump)
            canopy.append(clump)
        }

        removeAction(forKey: "grow")
        setScale(0.85)
        let pop = SKAction.scale(to: 1.0, duration: 0.4)
        pop.timingMode = .easeOut
        run(pop, withKey: "grow")

        // T5: a gentle living sway, so the awakened tree reads as alive.
        if newTier >= 5, action(forKey: "sway") == nil {
            let sway = SKAction.sequence([
                SKAction.rotate(toAngle: 0.03, duration: 1.4),
                SKAction.rotate(toAngle: -0.03, duration: 1.4)
            ])
            sway.timingMode = .easeInEaseOut
            run(SKAction.repeatForever(sway), withKey: "sway")
        }
    }
}
