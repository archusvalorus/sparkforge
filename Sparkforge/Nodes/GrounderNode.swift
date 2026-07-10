// GrounderNode.swift
// Sparkforge
//
// v1.7 Arena 3 enemy (Lyra canon): the planted threat.
// Chases until it's near enough, then roots itself and emits periodic
// danger pulses — an expanding tell ring, then the discharge. Zone
// denial the player must route around; the Coilworks teaches routing.
// GameScene wires onDangerPulse to the shared hazard damage path.

import SpriteKit

final class GrounderNode: EnemyNode {

    /// Fired at the damaging moment of each pulse: (center, radius, damage)
    var onDangerPulse: ((CGPoint, CGFloat, Int) -> Void)?

    private var isPlanted = false

    // MARK: - Init

    init(elapsed: TimeInterval) {
        let health = elapsed < 60 ? 3 : Int.random(in: 4...5)
        super.init(health: health,
                   moveSpeed: GameConfig.Enemy.baseSpeed * 0.8,
                   xpValue: health)

        applyGrounderVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Visuals

    private func applyGrounderVisuals() {
        for child in children {
            if let shape = child as? SKShapeNode {
                if shape.fillColor != .clear && shape.glowWidth == 0 && shape.zPosition != 6 {
                    shape.fillColor = SKColor(hex: 0x181A16)
                }
                if shape.glowWidth > 0 && shape.fillColor == .clear {
                    shape.strokeColor = SKColor(hex: 0xF6D36B, alpha: 0.45)
                }
                if shape.zPosition == 6 {
                    if shape.fillColor != .clear {
                        shape.fillColor = SKColor(hex: 0xF6D36B)
                    }
                    if shape.strokeColor != .clear {
                        shape.strokeColor = SKColor(hex: 0xE8C455, alpha: 0.85)
                    }
                }
            }
        }
        setScale(1.1)
    }

    // MARK: - Behavior

    override func chase(target: CGPoint, deltaTime: TimeInterval, globalSlow: CGFloat = 0) {
        guard !isPlanted else { return }
        guard !isStunned else { return }

        let dist = (target - position).length
        if dist <= GameConfig.CoilworksEnemies.grounderPlantRange * DeviceScale.gameplay {
            plant()
            return
        }

        let effectiveSlow = min(currentSlow + globalSlow, 0.8)
        let speed = moveSpeed * (1.0 - effectiveSlow)
        position += (target - position).normalized * speed * CGFloat(deltaTime)
    }

    /// Root in place and begin the pulse cycle
    private func plant() {
        isPlanted = true

        // Rooting legs — short angular spikes, ground language not a ring
        let r = GameConfig.Enemy.visualRadius
        for angle in stride(from: CGFloat.pi / 6, to: 2 * .pi, by: .pi / 3) {
            let leg = SKShapeNode(rectOf: CGSize(width: 2, height: 7), cornerRadius: 1)
            leg.fillColor = SKColor(hex: 0xF6D36B, alpha: 0.6)
            leg.strokeColor = .clear
            leg.position = CGPoint(x: cos(angle) * (r + 4), y: sin(angle) * (r + 4))
            leg.zRotation = angle - .pi / 2
            leg.zPosition = 4
            leg.setScale(0)
            addChild(leg)
            leg.run(SKAction.scale(to: 1.0, duration: 0.2))
        }

        startPulseCycle()
    }

    private func startPulseCycle() {
        let cfg = GameConfig.CoilworksEnemies.self
        let radius = cfg.grounderPulseRadius * DeviceScale.gameplay

        let cycle = SKAction.sequence([
            SKAction.wait(forDuration: cfg.grounderPulseRest, withRange: 0.6),
            SKAction.run { [weak self] in self?.showPulseTell(radius: radius) },
            SKAction.wait(forDuration: cfg.grounderPulseTell),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.firePulse(radius: radius)
                self.onDangerPulse?(self.position, radius, cfg.grounderPulseDamage)
            }
        ])
        run(SKAction.repeatForever(cycle), withKey: "pulseCycle")
    }

    /// The tell: a faint ring grows out to the exact damage radius
    private func showPulseTell(radius: CGFloat) {
        let tell = SKShapeNode(circleOfRadius: radius)
        tell.fillColor = .clear
        tell.strokeColor = SKColor(hex: 0xF6D36B, alpha: 0.35)
        tell.lineWidth = 1.5
        tell.zPosition = 3
        tell.setScale(0.1)
        addChild(tell)
        tell.run(SKAction.sequence([
            SKAction.scale(to: 1.0, duration: GameConfig.CoilworksEnemies.grounderPulseTell),
            SKAction.removeFromParent()
        ]))
    }

    /// The discharge flash at the moment damage lands
    private func firePulse(radius: CGFloat) {
        let pulse = SKShapeNode(circleOfRadius: radius)
        pulse.fillColor = SKColor(hex: 0xF6D36B, alpha: 0.18)
        pulse.strokeColor = SKColor(hex: 0xF6D36B, alpha: 0.9)
        pulse.lineWidth = 2.5
        pulse.glowWidth = 4
        pulse.zPosition = 3
        addChild(pulse)
        pulse.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.scale(to: 1.06, duration: 0.3)
            ]),
            SKAction.removeFromParent()
        ]))
    }
}
