// CinderHaloNode.swift
// Sparkforge
//
// v1.6 Arena 2 enemy (Lyra canon): the orbiter.
// Drifts into orbit around the player at medium range and tightens the
// circle over time. "Creates movement pressure without copying ranged
// enemies — the player has to cut through or reposition, not simply
// kite backward forever."

import SpriteKit

final class CinderHaloNode: EnemyNode {

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
        applyHaloVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Visuals

    private func applyHaloVisuals() {
        for child in children {
            if let shape = child as? SKShapeNode {
                if shape.fillColor != .clear && shape.glowWidth == 0 {
                    shape.fillColor = SKColor(hex: 0x15181D)
                }
                if shape.glowWidth > 0 && shape.fillColor == .clear {
                    shape.strokeColor = SKColor(hex: 0x6A6256, alpha: 0.5)
                }
            }
        }

        // The broken halo — an offset rotating arc ring
        let r = GameConfig.Enemy.visualRadius
        let haloContainer = SKNode()
        haloContainer.position = CGPoint(x: 3, y: 2)  // offset = "broken" feel
        haloContainer.zPosition = 7

        let halo = SKShapeNode()
        let haloPath = CGMutablePath()
        haloPath.addArc(center: .zero, radius: r + 6,
                        startAngle: 0, endAngle: .pi * 1.65, clockwise: false)
        halo.path = haloPath
        halo.strokeColor = SKColor(hex: 0x8A8478, alpha: 0.8)
        halo.fillColor = .clear
        halo.lineWidth = 1.5
        halo.glowWidth = 2
        haloContainer.addChild(halo)
        addChild(haloContainer)

        haloContainer.run(SKAction.repeatForever(
            SKAction.rotate(byAngle: .pi * 2, duration: 1.8)
        ))
    }

    // MARK: - Orbit AI

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
