// UnmadeStarNode.swift
// Sparkforge
//
// v2.0 (Unit 2c) — The Unmade Star: Arena 5's boss and MONUMENT INSTANCE #1.
//
// "A star caught between becoming and breaking. The forge keeps striking. It
// keeps failing. You arrived at the worst possible moment."
//
// Pressure axis: INEVITABILITY — not impact, pressure, rhythm, or deception.
// The arena stops asking and starts deciding. A colossal asymmetrical star-body
// fused with forge structures, anchored across the top third: central star-core,
// fractured anvil crown, orbiting fragments, cracked luminous seams.
//
// 2c.1 = the shell (silhouette, anchoring, HP, phases wired). The phase
// mechanics — Accretion Orbit, Collapse Marks, Starfall Sequence, Weight of the
// Center, and the Final Compression enrage — land in 2c.2.
//
// See docs/arena5-star-anvil-creative.md.

import SpriteKit

final class UnmadeStarNode: MonumentBossNode {

    // Tunables.
    static let baseHealth: Int = 900
    static let contact: Int = 22
    static let xp: Int = 260
    /// Three phases: Accretion → Weight of the Center → Unmaking.
    static let phases: [CGFloat] = [0.66, 0.33]

    private let core = SKShapeNode()
    private let crown = SKShapeNode()
    private var fragments: [SKShapeNode] = []
    private var seams: [SKShapeNode] = []
    private let bodyRadius: CGFloat

    init(arenaRadius: CGFloat, hpScaling: Int = 0) {
        // Sized to dominate the top third of the (doubled) Star Anvil.
        bodyRadius = arenaRadius * 0.40
        super.init(health: UnmadeStarNode.baseHealth + hpScaling,
                   contactDamage: UnmadeStarNode.contact,
                   xpValue: UnmadeStarNode.xp,
                   phaseThresholds: UnmadeStarNode.phases)
        buildBody()
        // Hittable + solid: the whole star body. Slightly inset from the visual
        // so the halo/crown flourishes don't extend the effective hitbox.
        configurePhysics(radius: bodyRadius * 0.92)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Silhouette

    private func buildBody() {
        let R = bodyRadius

        // Outer halo — the star failing to hold shape.
        let halo = SKShapeNode(circleOfRadius: R * 1.06)
        halo.fillColor = SKColor(hex: 0x2A1E52, alpha: 0.5)
        halo.strokeColor = SKColor(hex: 0x6A48C8, alpha: 0.45)
        halo.lineWidth = 3
        halo.glowWidth = 22
        halo.zPosition = -1
        addChild(halo)
        halo.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.7, duration: 2.2),
            SKAction.fadeAlpha(to: 1.0, duration: 2.2)
        ])))

        // Dark forged shell.
        let shell = SKShapeNode(circleOfRadius: R)
        shell.fillColor = SKColor(hex: 0x140F26)
        shell.strokeColor = SKColor(hex: 0xFFD98A, alpha: 0.35)
        shell.lineWidth = 2
        shell.zPosition = 0
        addChild(shell)

        // White-hot star core, breathing.
        core.path = CGPath(ellipseIn: CGRect(x: -R * 0.42, y: -R * 0.42,
                                             width: R * 0.84, height: R * 0.84), transform: nil)
        core.fillColor = SKColor(hex: 0xFFF6E0)
        core.strokeColor = .clear
        core.blendMode = .add
        core.glowWidth = 26
        core.zPosition = 1
        addChild(core)
        core.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.06, duration: 1.5),
            SKAction.scale(to: 0.96, duration: 1.5)
        ])))

        // Fractured anvil crown — asymmetric, hammered, riding the upper shell.
        let cp = CGMutablePath()
        cp.move(to: CGPoint(x: -R * 0.95, y: R * 0.30))
        cp.addLine(to: CGPoint(x: -R * 0.60, y: R * 1.02))
        cp.addLine(to: CGPoint(x: -R * 0.10, y: R * 0.72))
        cp.addLine(to: CGPoint(x:  R * 0.34, y: R * 1.18))
        cp.addLine(to: CGPoint(x:  R * 0.78, y: R * 0.62))
        cp.addLine(to: CGPoint(x:  R * 1.00, y: R * 0.26))
        cp.closeSubpath()
        crown.path = cp
        crown.fillColor = SKColor(hex: 0x1B1436)
        crown.strokeColor = SKColor(hex: 0xFFD98A, alpha: 0.5)
        crown.lineWidth = 2
        crown.zPosition = 2
        addChild(crown)

        // Cracked luminous seams across the body.
        for i in 0..<5 {
            let a = CGFloat(i) / 5 * .pi * 2 + 0.4
            let p = CGMutablePath()
            p.move(to: CGPoint(x: cos(a) * R * 0.18, y: sin(a) * R * 0.18))
            p.addLine(to: CGPoint(x: cos(a + 0.22) * R * 0.62, y: sin(a + 0.22) * R * 0.62))
            p.addLine(to: CGPoint(x: cos(a + 0.08) * R * 0.95, y: sin(a + 0.08) * R * 0.95))
            let seam = SKShapeNode(path: p)
            seam.strokeColor = SKColor(hex: 0xFFC46A, alpha: 0.55)
            seam.lineWidth = 2
            seam.glowWidth = 4
            seam.zPosition = 1.5
            addChild(seam)
            seams.append(seam)
        }

        // Orbiting star fragments — decorative in 2c.1; they become the
        // Accretion Orbit threat paths in 2c.2.
        for i in 0..<6 {
            let frag = SKShapeNode(circleOfRadius: R * 0.055)
            frag.fillColor = SKColor(hex: 0xFFE8B0)
            frag.strokeColor = SKColor(hex: 0xFFD98A, alpha: 0.8)
            frag.glowWidth = 6
            frag.blendMode = .add
            frag.zPosition = 3
            let orbit = SKNode()
            orbit.zPosition = 3
            orbit.addChild(frag)
            frag.position = CGPoint(x: R * (1.18 + CGFloat(i % 3) * 0.12), y: 0)
            orbit.zRotation = CGFloat(i) / 6 * .pi * 2
            let dur = 7.0 + Double(i % 3) * 2.5
            orbit.run(SKAction.repeatForever(
                SKAction.rotate(byAngle: .pi * 2, duration: dur)))
            addChild(orbit)
            fragments.append(frag)
        }
    }

    // MARK: - Feedback / phases

    override func takeDamageFeedback() {
        core.removeAction(forKey: "hit")
        core.run(SKAction.sequence([
            SKAction.run { [weak self] in self?.core.fillColor = .white },
            SKAction.wait(forDuration: 0.05),
            SKAction.run { [weak self] in self?.core.fillColor = SKColor(hex: 0xFFF6E0) }
        ]), withKey: "hit")
    }

    override func phaseDidChange(to phase: Int) {
        // 2c.1: escalate the LOOK; the mechanics arrive in 2c.2.
        // Seams brighten and the crown darkens as the star comes apart.
        let intensity = 0.55 + CGFloat(phase) * 0.2
        for seam in seams {
            seam.strokeColor = SKColor(hex: 0xFFC46A, alpha: min(intensity, 1.0))
            seam.glowWidth = 4 + CGFloat(phase) * 3
        }
        core.glowWidth = 26 + CGFloat(phase) * 10
        run(SKAction.sequence([
            SKAction.scale(to: 1.04, duration: 0.18),
            SKAction.scale(to: 1.0, duration: 0.22)
        ]))
    }

    /// The star finally fails: seams blow out, the core flares, then collapse.
    override func beginDeathSequence() {
        removeAllActions()
        for seam in seams {
            seam.run(SKAction.group([
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.scale(to: 1.3, duration: 0.5)
            ]))
        }
        core.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.4, duration: 0.45),
                SKAction.fadeAlpha(to: 1.0, duration: 0.45)
            ]),
            SKAction.group([
                SKAction.scale(to: 0.0, duration: 0.5),
                SKAction.fadeOut(withDuration: 0.5)
            ])
        ]))
        crown.run(SKAction.group([
            SKAction.fadeOut(withDuration: 0.7),
            SKAction.moveBy(x: 0, y: bodyRadius * 0.2, duration: 0.7)
        ]))
        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.1),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }
}
