// DefensiveFlowerNode.swift
// Sparkforge
//
// v2.0 Phase C (C1.3) — the Growth tree's structure primitive: a stationary,
// player-owned mini-turret that grows ON cultivated ground and fires at enemies.
//
// Rooted to Terra by design (Brandon, Jul 24): flowers only ever grow inside the
// garden, never loose in the arena. "Charming, innocent, and alarmingly armed"
// (creative handoff §5) — a wholesome little bloom that visibly turns to aim
// before it fires.
//
// It owns its own look, aim animation and cooldown. The SCENE owns targeting
// (via the shared findPriorityTarget) and the actual shot (via fireProjectile),
// so the flower stays a dumb, reusable body — the same split the Tree capstone's
// structures will reuse.

import SpriteKit

final class DefensiveFlowerNode: SKNode {

    /// Counts down to the next shot. The scene ticks it and fires at zero.
    var fireCooldown: TimeInterval = 0

    private let head = SKNode()          // rotates to aim
    private let stem = SKShapeNode()

    override init() {
        super.init()
        zPosition = 3                    // above the ground (1.5), below actors
        buildBody()

        // A gentle sway so it reads as alive, not as a placed decal. Rides a
        // container the aim rotation doesn't touch, so the two never fight.
        let sway = SKAction.sequence([
            SKAction.rotate(toAngle: 0.06, duration: 1.3),
            SKAction.rotate(toAngle: -0.06, duration: 1.3)
        ])
        sway.timingMode = .easeInEaseOut
        stem.run(SKAction.repeatForever(sway))

        // Grow-in: a little pop so planting reads as a bloom, not a spawn.
        setScale(0.1)
        let bloom = SKAction.scale(to: 1.0, duration: 0.35)
        bloom.timingMode = .easeOut
        run(bloom)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func buildBody() {
        // Stem — deep forest green, the structural tone.
        stem.path = CGPath(rect: CGRect(x: -1.5, y: -14, width: 3, height: 16), transform: nil)
        stem.fillColor = SKColor(hex: 0x2E6B3A)
        stem.strokeColor = .clear
        addChild(stem)

        // A leaf, for silhouette.
        let leaf = SKShapeNode(ellipseOf: CGSize(width: 10, height: 5))
        leaf.fillColor = SKColor(hex: 0x2E8B47)
        leaf.strokeColor = .clear
        leaf.position = CGPoint(x: 5, y: -6)
        leaf.zRotation = -0.5
        stem.addChild(leaf)

        // Head — the business end, sits atop the stem and rotates to aim.
        head.position = CGPoint(x: 0, y: 4)
        stem.addChild(head)

        // Petals — seed-gold ring of small circles.
        for i in 0..<6 {
            let a = CGFloat(i) / 6 * 2 * .pi
            let petal = SKShapeNode(circleOfRadius: 3.4)
            petal.fillColor = SKColor(hex: 0xC9D96F)
            petal.strokeColor = .clear
            petal.position = CGPoint(x: cos(a) * 6, y: sin(a) * 6)
            head.addChild(petal)
        }
        // Center — a dark seed eye, with a short "muzzle" that points where it aims.
        let core = SKShapeNode(circleOfRadius: 3.6)
        core.fillColor = SKColor(hex: 0x5A3A1A)
        core.strokeColor = SKColor(hex: 0xC9D96F, alpha: 0.6)
        core.lineWidth = 1
        head.addChild(core)

        let muzzle = SKShapeNode(path: CGPath(rect: CGRect(x: 5, y: -1, width: 5, height: 2),
                                              transform: nil))
        muzzle.fillColor = SKColor(hex: 0xC9D96F)
        muzzle.strokeColor = .clear
        muzzle.name = "muzzle"
        head.addChild(muzzle)
    }

    /// Turn the head toward a target and return the aim direction. The scene
    /// calls this right before firing so the shot leaves the muzzle.
    @discardableResult
    func aim(at targetPos: CGPoint) -> CGPoint {
        let dir = (targetPos - position).normalized
        head.zRotation = atan2(dir.y, dir.x)
        return dir
    }

    /// A small recoil kick so firing has weight.
    func flashFire() {
        head.removeAction(forKey: "recoil")
        head.run(SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.06),
            SKAction.scale(to: 1.0, duration: 0.12)
        ]), withKey: "recoil")
    }
}
