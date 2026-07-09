// RangedEnemyNode.swift
// Sparkforge
//
// Ranged enemy variant. Stops at engage range and fires slow
// purple projectiles at the player. Distinct purple color scheme
// with slit/diamond eyes to visually differentiate from melee chasers.

import SpriteKit

final class RangedEnemyNode: EnemyNode {
    
    // MARK: - Ranged State
    
    private var timeSinceLastShot: TimeInterval = 0
    private(set) var isInRange: Bool = false
    
    /// Callback for GameScene to spawn the actual projectile node
    /// (since the enemy can't add nodes to the scene directly)
    var onFireProjectile: ((CGPoint, CGPoint) -> Void)?  // (position, direction)
    
    // MARK: - Init
    
    override init(health: Int = GameConfig.Enemy.baseHealth,
         moveSpeed: CGFloat = GameConfig.Enemy.baseSpeed * 0.75,
         xpValue: Int = GameConfig.Leveling.baseEnemyXP + 1) {
        
        super.init(health: health, moveSpeed: moveSpeed, xpValue: xpValue)
        
        // Override visuals to purple theme
        applyRangedVisuals()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Visual Override
    
    private func applyRangedVisuals() {
        // Recolor the body and rim to purple
        // Access inherited nodes by enumerating children
        for child in children {
            if let shape = child as? SKShapeNode {
                // Rim glow (the outer ring, slightly larger)
                if shape.glowWidth > 0 && shape.fillColor == .clear {
                    shape.strokeColor = SKColor(hex: GameConfig.RangedEnemy.rimGlowColorHex, alpha: 0.7)
                }
                // Body (filled circle)
                if shape.fillColor != .clear && shape.glowWidth == 0 {
                    shape.fillColor = SKColor(hex: GameConfig.RangedEnemy.bodyColorHex)
                }
            }
        }
        
        // Recolor eyes to purple
        recolorEyes(to: GameConfig.RangedEnemy.eyeColorHex)
    }
    
    /// Recolor eye nodes to a different color
    private func recolorEyes(to hex: UInt32) {
        for child in children {
            if let shape = child as? SKShapeNode,
               shape.zPosition == 6,
               shape.fillColor == SKColor(hex: 0xFF2222) {
                shape.fillColor = SKColor(hex: hex)
                shape.glowWidth = 3
            }
        }
    }
    
    // MARK: - AI Override
    
    /// Ranged AI: approach until in range, then stop and shoot
    func rangedChase(target: CGPoint, deltaTime: TimeInterval, globalSlow: CGFloat = 0) {
        let distToTarget = position.distance(to: target)
        let engageRange = GameConfig.RangedEnemy.engageRange
        
        if distToTarget > engageRange {
            // Too far — chase normally
            isInRange = false
            chase(target: target, deltaTime: deltaTime, globalSlow: globalSlow)
        } else {
            // In range — stop and shoot
            isInRange = true
            timeSinceLastShot += deltaTime
            
            if timeSinceLastShot >= GameConfig.RangedEnemy.fireInterval {
                timeSinceLastShot = 0
                
                let direction = (target - position).normalized
                onFireProjectile?(position, direction)
                
                // Visual: brief flash on fire
                fireFlash()
            }
        }
    }
    
    // MARK: - Visual Feedback
    
    private func fireFlash() {
        // Eyes flare bright on shot
        for child in children {
            if let shape = child as? SKShapeNode, shape.zPosition == 6 {
                let flash = SKAction.sequence([
                    SKAction.run { shape.fillColor = .white },
                    SKAction.wait(forDuration: 0.08),
                    SKAction.run { [weak self] in
                        shape.fillColor = SKColor(hex: GameConfig.RangedEnemy.eyeColorHex)
                        _ = self  // Keep reference alive
                    }
                ])
                shape.run(flash)
            }
        }
        
        // Brief scale pulse
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.05),
            SKAction.scale(to: 1.0, duration: 0.08)
        ])
        run(pulse)
    }
}
