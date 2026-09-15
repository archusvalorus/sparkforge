// LinekeeperNode.swift
// Sparkforge
//
// v2.1 (Geometry 2c) — Arena 6 "The Splitworks" roster #2: the ranged anchor.
// Spatial verb: HOLD A LINE.
//
// A walking firing standard. It seeks a VALID firing anchor (standoff from
// Spark, clear line both ways — the scene resolves it against geometry),
// plants with a grounded stance, telegraphs a narrow line, and fires a fast
// bolt that the Fallen Carrier can interrupt (2a's swept blocking). Denied a
// clear shot for too long, it relocates. Lesson: terrain protects you, but
// staying behind the same protection gives the rest of the yard time.
// Design lock §5.2; tunables in GameConfig.Linekeeper. Colour: the body wears
// the arena's charcoal + teal, the eye/seam/bolt stay in the PURPLE family
// (canon: purple = danger).

import SpriteKit

final class LinekeeperNode: EnemyNode {

    private enum Phase { case seek, aim, cooldown }

    /// (muzzle position, direction) — the scene spawns the bolt.
    var onFireProjectile: ((CGPoint, CGPoint) -> Void)?
    /// (my position, Spark's position) → a valid anchor, or nil if none.
    var resolveFiringAnchor: ((CGPoint, CGPoint) -> CGPoint?)?
    var onAnchorChosen: (() -> Void)?
    var onRelocate: (() -> Void)?

    private var phase: Phase = .seek
    private var phaseTimer: TimeInterval = 0
    private var anchor: CGPoint? = nil
    private var deniedTimer: TimeInterval = 0
    private var anchorRetryTimer: TimeInterval = 0
    private var lockedDir: CGPoint = .zero

    private let mast = SKShapeNode()
    private let head = SKShapeNode()
    private let seam = SKShapeNode()
    private let legs = SKNode()
    private let telegraph = SKShapeNode()

    init(health: Int, xpValue: Int) {
        super.init(health: health,
                   moveSpeed: GameConfig.Enemy.baseSpeed * GameConfig.Linekeeper.moveSpeedFactor,
                   xpValue: xpValue)

        setBodyPalette(body: 0x1A1816, rim: 0x3F8F8A, eye: 0xBB44FF)
        let r = GameConfig.Enemy.visualRadius

        // Tall narrow mast rising from the core.
        mast.path = CGPath(roundedRect: CGRect(x: -r * 0.28, y: -r * 0.2, width: r * 0.56, height: r * 3.0),
                           cornerWidth: r * 0.2, cornerHeight: r * 0.2, transform: nil)
        mast.fillColor = SKColor(hex: 0x2A2622)
        mast.strokeColor = SKColor(hex: 0x3F8F8A, alpha: 0.95)
        mast.lineWidth = 1
        mast.zPosition = 7
        addChild(mast)

        // Luminous barrel seam up the mast's front — brightens as it aims.
        let seamPath = CGMutablePath()
        seamPath.move(to: CGPoint(x: 0, y: 0))
        seamPath.addLine(to: CGPoint(x: 0, y: r * 2.5))
        seam.path = seamPath
        seam.strokeColor = SKColor(hex: 0xBB44FF, alpha: 0.35)
        seam.lineWidth = 1.5
        seam.glowWidth = 2
        seam.zPosition = 8
        addChild(seam)

        // Surveying head: a small ceramic disc with a purple slit.
        head.path = CGPath(ellipseIn: CGRect(x: -r * 0.55, y: -r * 0.4, width: r * 1.1, height: r * 0.8), transform: nil)
        head.position = CGPoint(x: 0, y: r * 2.85)
        head.fillColor = SKColor(hex: 0xD9D2C4)
        head.strokeColor = SKColor(hex: 0x3F8F8A, alpha: 0.9)
        head.lineWidth = 1
        head.zPosition = 9
        addChild(head)
        let slit = SKShapeNode(rect: CGRect(x: -r * 0.4, y: -r * 0.07, width: r * 0.8, height: r * 0.14))
        slit.fillColor = SKColor(hex: 0xBB44FF)
        slit.strokeColor = .clear
        slit.glowWidth = 2
        head.addChild(slit)

        // Tripod legs — a boundary marker's stance.
        legs.zPosition = 6
        for (dx, dy) in [(-1.1, -1.4), (1.1, -1.4), (0.0, -1.55)] {
            let leg = SKShapeNode()
            let lp = CGMutablePath()
            lp.move(to: CGPoint(x: 0, y: -r * 0.1))
            lp.addLine(to: CGPoint(x: r * CGFloat(dx), y: r * CGFloat(dy)))
            leg.path = lp
            leg.strokeColor = SKColor(hex: 0xD9D2C4, alpha: 0.85)
            leg.lineWidth = 1.5
            legs.addChild(leg)
        }
        addChild(legs)

        // The narrow aim line, from the head outward. Hidden until aiming.
        telegraph.strokeColor = SKColor(hex: 0xC58BFF, alpha: 0)
        telegraph.lineWidth = 1
        telegraph.glowWidth = 2
        telegraph.zPosition = 2
        addChild(telegraph)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - AI

    override func chase(target: CGPoint, deltaTime dt: TimeInterval, globalSlow: CGFloat = 0) {
        guard !isStunned && !isFrozen else { return }
        let C = GameConfig.Linekeeper.self
        phaseTimer -= dt
        if anchorRetryTimer > 0 { anchorRetryTimer -= dt }
        let goal = goalPosition

        switch phase {
        case .seek:
            // Spark drifted far from the line I was holding → re-anchor.
            if let a = anchor, a.distance(to: goal) > C.standoff * C.reanchorDistanceFactor {
                anchor = nil
            }
            if anchor == nil, anchorRetryTimer <= 0 {
                anchor = resolveFiringAnchor?(position, goal)
                if anchor != nil { onAnchorChosen?() } else { anchorRetryTimer = 0.5 }
            }
            let dest = anchor ?? target       // no valid anchor → routed approach
            let dist = position.distance(to: dest)
            if dist > C.arriveRadius {
                let slow = min(currentSlow + globalSlow, 0.8)
                let dir = (dest - position).normalized
                position += dir * moveSpeed * (1 - slow) * CGFloat(dt)
                deniedTimer = 0
            } else if anchor != nil {
                // Planted. Clear line → aim; denied → count toward relocating.
                if !isOccludedFromGoal {
                    deniedTimer = 0
                    enterAim(toward: goal)
                } else {
                    deniedTimer += dt
                    if deniedTimer >= C.relocateAfter {
                        deniedTimer = 0
                        anchor = nil
                        onRelocate?()
                    }
                }
            }

        case .aim:
            // Grounded and committed; a line that gets covered mid-aim is abandoned.
            if isOccludedFromGoal {
                abortAim()
                return
            }
            if phaseTimer <= 0 { fire() }

        case .cooldown:
            if phaseTimer <= 0 { phase = .seek }
        }
    }

    // MARK: - Phases

    private func enterAim(toward goal: CGPoint) {
        let C = GameConfig.Linekeeper.self
        phase = .aim
        phaseTimer = C.aimDuration
        lockedDir = (goal - position).normalized

        let path = CGMutablePath()
        path.move(to: head.position)
        path.addLine(to: head.position + lockedDir * C.boltRange)
        telegraph.path = path
        telegraph.removeAllActions()
        telegraph.strokeColor = SKColor(hex: 0xC58BFF, alpha: 0.15)
        telegraph.run(SKAction.customAction(withDuration: C.aimDuration) { [weak self] _, t in
            let f = CGFloat(t / C.aimDuration)
            self?.telegraph.strokeColor = SKColor(hex: 0xC58BFF, alpha: 0.15 + 0.7 * f)
        })
        seam.run(SKAction.customAction(withDuration: C.aimDuration) { [weak self] _, t in
            let f = CGFloat(t / C.aimDuration)
            self?.seam.strokeColor = SKColor(hex: 0xBB44FF, alpha: 0.35 + 0.65 * f)
        })
        // Grounded stance: legs spread, mast settles.
        legs.run(SKAction.scaleX(to: 1.35, duration: 0.15))
        mast.run(SKAction.moveTo(y: -GameConfig.Enemy.visualRadius * 0.15, duration: 0.15))
    }

    private func fire() {
        let C = GameConfig.Linekeeper.self
        let muzzle = position + head.position + lockedDir * (GameConfig.Enemy.visualRadius * 0.6)
        onFireProjectile?(muzzle, lockedDir)
        head.run(SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.05),
            SKAction.scale(to: 1.0, duration: 0.1)
        ]))
        standDown()
        phase = .cooldown
        phaseTimer = C.fireInterval
    }

    private func abortAim() {
        standDown()
        phase = .seek
        deniedTimer = 0
    }

    private func standDown() {
        telegraph.removeAllActions()
        telegraph.run(SKAction.customAction(withDuration: 0.12) { [weak self] _, t in
            self?.telegraph.strokeColor = SKColor(hex: 0xC58BFF, alpha: max(0, 0.85 - CGFloat(t / 0.12)))
        })
        seam.removeAllActions()
        seam.strokeColor = SKColor(hex: 0xBB44FF, alpha: 0.35)
        legs.run(SKAction.scaleX(to: 1.0, duration: 0.15))
        mast.run(SKAction.moveTo(y: 0, duration: 0.15))
    }
}
