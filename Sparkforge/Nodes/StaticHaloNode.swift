// StaticHaloNode.swift
// Sparkforge
//
// v1.7 Arena 3 enemy (Lyra canon): the returned orbiter.
// Cinder Halo reborn — renamed because "cinder" pointed at the player's
// ember lane, and restyled per the v1.6 field report: the halo floats
// ABOVE the head (gently bobbing, never a ring around the body — rings
// read as shields). Pale-gold static family, serene slit eyes.
// "Not every threat beelines. Some threats choose position."
// The proven v1.6 orbit AI carries over unchanged.

import SpriteKit

final class StaticHaloNode: EnemyNode {

    // MARK: - Orbit State

    private var orbitRadius: CGFloat = 150 * DeviceScale.gameplay
    private let minOrbitRadius: CGFloat = 70 * DeviceScale.gameplay
    /// Points/sec the orbit tightens
    private let tightenRate: CGFloat = 3.0 * DeviceScale.gameplay
    /// Clockwise or counter-clockwise, fixed per individual
    private let orbitDirection: CGFloat = Bool.random() ? 1 : -1

    // MARK: - Init

    init(elapsed: TimeInterval) {
        let health = elapsed < 60 ? 2 : Int.random(in: 3...4)
        super.init(health: health,
                   moveSpeed: GameConfig.Enemy.baseSpeed * 0.9,
                   xpValue: health + 1)
        applyStaticVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Visuals

    private func applyStaticVisuals() {
        for child in children {
            if let shape = child as? SKShapeNode {
                if shape.fillColor != .clear && shape.glowWidth == 0 && shape.zPosition != 6 {
                    shape.fillColor = SKColor(hex: 0x15181D)
                }
                if shape.glowWidth > 0 && shape.fillColor == .clear {
                    // Rim — dark machinery with a static-gold undertone
                    shape.strokeColor = SKColor(hex: 0xF6D36B, alpha: 0.35)
                }
                // Face → pale gold, eyes squashed into serene slits
                if shape.zPosition == 6 {
                    if shape.fillColor != .clear {
                        shape.fillColor = SKColor(hex: 0xF6D36B)
                        shape.yScale = 0.35
                    }
                    if shape.strokeColor != .clear {
                        shape.strokeColor = SKColor(hex: 0xE8C455, alpha: 0.85)
                    }
                }
            }
        }

        // The halo — a small ellipse floating ABOVE the head, bobbing.
        // Never around the body: ornament, not armor.
        let r = GameConfig.Enemy.visualRadius
        let halo = SKShapeNode(ellipseOf: CGSize(width: r * 1.1, height: 4.5))
        halo.fillColor = .clear
        halo.strokeColor = SKColor(hex: 0xF6D36B, alpha: 0.85)
        halo.lineWidth = 1.5
        halo.glowWidth = 2
        halo.position = CGPoint(x: 0, y: r + 9)
        halo.zPosition = 7
        addChild(halo)

        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 2, duration: 1.1),
            SKAction.moveBy(x: 0, y: -2, duration: 1.1)
        ])
        bob.timingMode = .easeInEaseOut
        halo.run(SKAction.repeatForever(bob))
    }

    // MARK: - Orbit AI (v1.6, proven)

    override func chase(target: CGPoint, deltaTime: TimeInterval, globalSlow: CGFloat = 0) {
        guard !isStunned else { return }

        let effectiveSlow = min(currentSlow + globalSlow, 0.8)
        let speed = moveSpeed * (1.0 - effectiveSlow)

        // The noose tightens
        orbitRadius = max(minOrbitRadius, orbitRadius - tightenRate * CGFloat(deltaTime))

        let toTarget = target - position
        let dist = toTarget.length

        if dist > orbitRadius + 40 {
            // Too far — close in directly
            position += toTarget.normalized * speed * CGFloat(deltaTime)
        } else {
            // In orbit range — tangential drift with a radial correction
            let radial = toTarget.normalized
            let tangent = CGPoint(x: -radial.y * orbitDirection,
                                  y: radial.x * orbitDirection)
            let radialError = dist - orbitRadius
            let move = (tangent + radial * (radialError / 40)).normalized
            position += move * speed * CGFloat(deltaTime)
        }
    }
}
