// CultivatedZoneNode.swift
// Sparkforge
//
// v2.0 Phase C (C1.2) — cultivated ground, the Growth tree's foundational
// primitive.
//
// Growth is the only tree that modifies the ARENA rather than Spark, and this
// is the object that does it. The defining property (Brandon, Jul 23) is that
// a zone TRACKS WHO IS IN IT and treats them differently:
//
//   • Spark   — this is his ground. Standing on it nourishes him.
//   • enemies — this is not their ground. Standing on it costs them.
//
// That asymmetry is the whole fantasy, so it lives in the primitive rather than
// in whatever card happens to create a zone. Terra plants the first one; the
// Tree capstone plants and grows its own; Terra+ cards reach in and modify every
// active zone at once (`apply(modifier:)`).
//
// Palette per the creative handoff §4: forest body for the terrain, living
// accent for the rim. Deliberately NOT the brighter health green — that stays
// exclusive to healing pickups, and cultivated ground must stay quieter than
// enemy attacks so it reads as terrain rather than as a threat.

import SpriteKit

final class CultivatedZoneNode: SKNode {

    /// Current influence radius. Never set directly — go through `setRadius`
    /// so the visual and the collision test can't drift apart.
    private(set) var radius: CGFloat

    private let ground = SKShapeNode()
    private let rim = SKShapeNode()

    // MARK: - Init

    init(radius: CGFloat) {
        self.radius = radius
        super.init()
        zPosition = 1.5          // above the arena floor, below actors + pickups

        ground.fillColor = SKColor(hex: 0x174A2A, alpha: 0.22)
        ground.strokeColor = .clear
        addChild(ground)

        rim.fillColor = .clear
        rim.strokeColor = SKColor(hex: 0x5FCF62, alpha: 0.40)
        rim.lineWidth = 1.5
        addChild(rim)

        applyRadiusToPaths()

        // A slow breath, so it reads as something living rather than a UI decal.
        run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.85, duration: 1.6),
            SKAction.fadeAlpha(to: 1.0, duration: 1.6)
        ])), withKey: "breathe")
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Geometry

    private func applyRadiusToPaths() {
        let path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius,
                                            width: radius * 2, height: radius * 2),
                          transform: nil)
        ground.path = path
        rim.path = path
    }

    /// Grow (or shrink) the zone. Used by Terra+ cards and by the Tree capstone
    /// as it matures — the Tree EXPANDS its ground rather than being replaced,
    /// so the same organism tells one continuous lifecycle.
    func setRadius(_ newRadius: CGFloat, animated: Bool = true) {
        let target = max(1, newRadius)
        guard target != radius else { return }
        radius = target
        applyRadiusToPaths()
        guard animated else { return }
        // A brief swell so growth is legible at a glance.
        removeAction(forKey: "grow")
        setScale(0.94)
        let swell = SKAction.scale(to: 1.0, duration: 0.35)
        swell.timingMode = .easeOut
        run(swell, withKey: "grow")
    }

    // MARK: - Occupancy

    /// Does this ground cover that position? The single source of truth for
    /// both the player's benefits and the enemies' penalties.
    ///
    /// Named `covers` rather than `contains` deliberately — SKNode already has
    /// `contains(_:)` for its own hit-testing, and silently overriding it would
    /// be a trap for whoever writes the next Growth card.
    func covers(_ point: CGPoint) -> Bool {
        position.distance(to: point) < radius
    }
}
