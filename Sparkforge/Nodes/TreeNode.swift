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

    /// Height of the crown above the planting point — where the NATURE CANON
    /// fires from. Published because the launcher used a hardcoded +30pt, which
    /// was fine on a shrub and lands halfway up a redwood's trunk. Animals have
    /// to come out of the canopy or the whole gag stops reading.
    private(set) var crownHeight: CGFloat = 0

    override init() {
        super.init()
        zPosition = 3   // above the ground, below Spark
        trunk.fillColor = SKColor(hex: 0x5A3A1A)   // bark brown
        trunk.strokeColor = .clear
        addChild(trunk)
        setTier(1)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    /// Trunk height per tier — a REDWOOD ramp (Brandon, Jul 27).
    ///
    /// The capstone's physical avatar should be a landmark, and by T5 this is
    /// ~5× Spark's height. Redwood proportions are also what make that SAFE in
    /// a top-down game: tall and narrow grows the tree NORTH on screen rather
    /// than ballooning outward from where it's planted, so it becomes an anchor
    /// without eating the play space. A big round oak at these heights would be
    /// a wall you fight behind.
    private static let trunkHeights: [CGFloat] = [30, 52, 82, 118, 165]
    private static let trunkWidths:  [CGFloat] = [5, 7, 9, 12, 16]

    /// Grow to a tier. Rebuilds the silhouette and pops so the growth reads.
    func setTier(_ newTier: Int) {
        tier = newTier
        canopy.forEach { $0.removeFromParent() }
        canopy.removeAll()

        let s = DeviceScale.gameplay
        let idx = max(0, min(4, newTier - 1))
        let h = Self.trunkHeights[idx] * s
        let w = Self.trunkWidths[idx] * s

        // A tapered trunk with a slight root flare — a rectangle reads as a
        // post, and the flare is what makes it read as GROWN.
        let bole = CGMutablePath()
        bole.move(to: CGPoint(x: -w * 0.9, y: 0))
        bole.addLine(to: CGPoint(x: -w * 0.42, y: h * 0.55))
        bole.addLine(to: CGPoint(x: -w * 0.30, y: h))
        bole.addLine(to: CGPoint(x:  w * 0.30, y: h))
        bole.addLine(to: CGPoint(x:  w * 0.42, y: h * 0.55))
        bole.addLine(to: CGPoint(x:  w * 0.9, y: 0))
        bole.closeSubpath()
        trunk.path = bole

        // Canopy: layered boughs stacked up the top half, narrow like a conifer
        // rather than a ball. Each tier adds another layer, so maturing reads as
        // the crown CLIMBING.
        //
        // Opacity falls as the tree grows — deliberately. TreeNode draws above
        // enemies (they sit at z 0, this is z 3), so at redwood scale a solid
        // crown would hide anything walking behind it. Growth's fantasy is a
        // landmark, not a blind spot.
        let layers = 2 + newTier                       // 3 … 7
        let leaf: UInt32 = newTier >= 5 ? 0x6FE37A : 0x2E8B47
        let alpha: CGFloat = max(0.60, 0.95 - CGFloat(newTier) * 0.07)
        let crownBottom = h * 0.42
        let crownTop = h * 1.06
        crownHeight = h * 0.92
        for i in 0..<layers {
            let t = CGFloat(i) / CGFloat(max(1, layers - 1))   // 0 at base … 1 at tip
            let y = crownBottom + (crownTop - crownBottom) * t
            // Widest low, tapering to the crown — the conifer silhouette.
            let width = (w * 5.4) * (1.0 - t * 0.72)
            let height = (h * 0.16) * (1.0 - t * 0.35)
            let bough = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
            bough.fillColor = SKColor(hex: leaf, alpha: alpha)
            bough.strokeColor = SKColor(hex: 0x174A2A, alpha: 0.45)
            bough.lineWidth = 1
            bough.position = CGPoint(x: 0, y: y)
            bough.zPosition = CGFloat(i) * 0.01
            addChild(bough)
            canopy.append(bough)
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
