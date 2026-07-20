import SpriteKit

/// A reusable segmented "rage gauge": a centered row of pip orbs that light up
/// as a stack accumulates and flash-empty on release.
///
/// Built first for Iron Maiden's Kinetic Reserve (v1.9), but deliberately
/// generic — any capstone with a charge/stack meter reuses it by calling
/// `configure(capacity:filledColor:)` once when it activates, then `setFilled`
/// on change and `flashRelease` on trigger. Candidates: Everglow rage, Erasure
/// Unstable stacks, and future Growth meters. Camera-anchored HUD node; hidden
/// (alpha 0) until configured with a non-zero capacity.
final class StackGaugeNode: SKNode {

    private var pips: [SKShapeNode] = []
    private var filledColor: UInt32 = 0xC0C8D0
    private var lit: Int = 0
    private let pipRadius: CGFloat
    private let spacing: CGFloat

    init(pipRadius: CGFloat = 5.5, spacing: CGFloat = 16) {
        self.pipRadius = pipRadius
        self.spacing = spacing
        super.init()
        alpha = 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Build (or rebuild) the gauge for a capacity + fill color. Capacity 0 hides
    /// it — call that when the owning capstone isn't active. Safe to call often.
    func configure(capacity: Int, filledColor: UInt32) {
        self.filledColor = filledColor
        pips.forEach { $0.removeFromParent() }
        pips.removeAll()
        lit = 0
        guard capacity > 0 else { alpha = 0; return }

        let totalWidth = CGFloat(capacity - 1) * spacing
        for i in 0..<capacity {
            let pip = SKShapeNode(circleOfRadius: pipRadius)
            pip.position = CGPoint(x: -totalWidth / 2 + CGFloat(i) * spacing, y: 0)
            addChild(pip)
            pips.append(pip)
            dimPip(pip)
        }
        alpha = 1
    }

    /// Light exactly `count` pips (clamped). Newly-lit pips pop.
    func setFilled(_ count: Int) {
        // Cancel any pending release-dim so a quick refill isn't clobbered by it.
        removeAction(forKey: "release")
        let clamped = max(0, min(count, pips.count))
        for (i, pip) in pips.enumerated() {
            if i < clamped {
                lightPip(pip, newlyLit: i >= lit)
            } else {
                dimPip(pip)
            }
        }
        lit = clamped
    }

    /// Flash every pip bright, then empty the gauge — the "reserve released" beat.
    func flashRelease() {
        for pip in pips {
            pip.removeAction(forKey: "pop")
            pip.fillColor = SKColor(hex: filledColor, alpha: 1.0)
            pip.strokeColor = SKColor(hex: filledColor, alpha: 1.0)
            pip.glowWidth = 8
            pip.setScale(1.0)
            pip.run(SKAction.sequence([
                SKAction.scale(to: 1.8, duration: 0.08),
                SKAction.scale(to: 1.0, duration: 0.14)
            ]))
        }
        lit = 0
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.14),
            SKAction.run { [weak self] in self?.pips.forEach { self?.dimPip($0) } }
        ]), withKey: "release")
    }

    // MARK: - Pip states

    private func lightPip(_ pip: SKShapeNode, newlyLit: Bool) {
        pip.fillColor = SKColor(hex: filledColor, alpha: 0.9)
        pip.strokeColor = SKColor(hex: filledColor, alpha: 1.0)
        pip.glowWidth = 4
        if newlyLit {
            pip.removeAction(forKey: "pop")
            pip.setScale(1.6)
            pip.run(SKAction.scale(to: 1.0, duration: 0.18), withKey: "pop")
        }
    }

    private func dimPip(_ pip: SKShapeNode) {
        pip.removeAction(forKey: "pop")
        pip.fillColor = SKColor(hex: filledColor, alpha: 0.08)
        pip.strokeColor = SKColor(hex: filledColor, alpha: 0.5)
        pip.lineWidth = 1.5
        pip.glowWidth = 0
        pip.setScale(1.0)
    }
}
