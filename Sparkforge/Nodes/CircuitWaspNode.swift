// CircuitWaspNode.swift
// Sparkforge
//
// v1.7 Arena 3 enemy (Lyra canon): the broken metronome.
// An angular snap-orbiter — drift, pause, SNAP to the next quarter
// angle, pause, snap again. Where Static Halo is the smooth clock
// hand, the Wasp teaches rhythmic angle pressure. Late/elite tier.

import SpriteKit

final class CircuitWaspNode: EnemyNode {

    // MARK: - Snap State

    private enum Phase {
        case drift
        case pause
        case snap
    }

    private var phase: Phase = .drift
    private var phaseTimer: TimeInterval = 0
    /// Which quarter-angle slot the wasp holds (0–3), advances on snap
    private var angleSlot = Int.random(in: 0...3)
    private let slotDirection: CGFloat = Bool.random() ? 1 : -1

    // MARK: - Init

    init(elapsed: TimeInterval) {
        let health = elapsed < 100 ? 2 : 3
        super.init(health: health,
                   moveSpeed: GameConfig.Enemy.baseSpeed,
                   xpValue: health + 2)

        setScale(0.72)
        applyWaspVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Visuals

    private func applyWaspVisuals() {
        for child in children {
            if let shape = child as? SKShapeNode {
                if shape.fillColor != .clear && shape.glowWidth == 0 && shape.zPosition != 6 {
                    shape.fillColor = SKColor(hex: 0x14161A)
                }
                if shape.glowWidth > 0 && shape.fillColor == .clear {
                    shape.strokeColor = SKColor(hex: 0xF6D36B, alpha: 0.55)
                }
                // Chevron-sharp face: narrow the eyes hard
                if shape.zPosition == 6 {
                    if shape.fillColor != .clear {
                        shape.fillColor = SKColor(hex: 0xF6D36B)
                        shape.xScale = 0.6
                    }
                    if shape.strokeColor != .clear {
                        shape.strokeColor = SKColor(hex: 0xE8C455, alpha: 0.85)
                    }
                }
            }
        }

        // Two angular wing ticks beside the body — ticks, never rings
        let r = GameConfig.Enemy.visualRadius
        for side: CGFloat in [-1, 1] {
            let wing = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: side * (r + 2), y: 2))
            path.addLine(to: CGPoint(x: side * (r + 8), y: 8))
            path.addLine(to: CGPoint(x: side * (r + 6), y: -2))
            wing.path = path
            wing.strokeColor = SKColor(hex: 0xF6D36B, alpha: 0.8)
            wing.fillColor = .clear
            wing.lineWidth = 1.5
            wing.zPosition = 7
            addChild(wing)

            // Nervous flutter
            let flutter = SKAction.sequence([
                SKAction.scaleY(to: 0.7, duration: 0.08),
                SKAction.scaleY(to: 1.0, duration: 0.08),
                SKAction.wait(forDuration: 0.25, withRange: 0.3)
            ])
            wing.run(SKAction.repeatForever(flutter))
        }
    }

    // MARK: - Snap-Orbit AI

    override func chase(target: CGPoint, deltaTime: TimeInterval, globalSlow: CGFloat = 0) {
        guard !isStunned else { return }

        let cfg = GameConfig.CoilworksEnemies.self
        let effectiveSlow = min(currentSlow + globalSlow, 0.8)
        let speed = moveSpeed * (1.0 - effectiveSlow)
        let orbitRadius = cfg.waspOrbitRadius * DeviceScale.gameplay

        // Far away: close in directly, rhythm starts once in range
        let toTarget = target - position
        if toTarget.length > orbitRadius * 2.2 {
            position += toTarget.normalized * speed * CGFloat(deltaTime)
            return
        }

        phaseTimer += deltaTime

        let slotAngle = CGFloat(angleSlot) * (.pi / 2) + .pi / 4
        let slotPoint = target + CGPoint(x: cos(slotAngle) * orbitRadius,
                                         y: sin(slotAngle) * orbitRadius)

        switch phase {
        case .drift:
            // Ease toward the held slot
            let toSlot = slotPoint - position
            if toSlot.length > 4 {
                position += toSlot.normalized * speed * 0.8 * CGFloat(deltaTime)
            }
            if phaseTimer >= cfg.waspDriftTime {
                phase = .pause
                phaseTimer = 0
            }

        case .pause:
            if phaseTimer >= cfg.waspPauseTime {
                angleSlot = (angleSlot + (slotDirection > 0 ? 1 : 3)) % 4
                phase = .snap
                phaseTimer = 0
            }

        case .snap:
            // Burst toward the NEW slot
            let toSlot = slotPoint - position
            if toSlot.length < 6 || phaseTimer >= cfg.waspDriftTime {
                phase = .pause
                phaseTimer = 0
            } else {
                position += toSlot.normalized * speed * cfg.waspSnapMultiplier * CGFloat(deltaTime)
            }
        }
    }
}
