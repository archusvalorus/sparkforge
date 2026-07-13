// MagnetOrbNode.swift
// Sparkforge
//
// v1.4: Blue-purple magnet pickup that spawns periodically.
// When collected, instantly vacuums ALL XP orbs on the field to the player.
// Pure dopamine.

import SpriteKit

final class MagnetOrbNode: SKNode {
    
    private let despawnTime: TimeInterval
    private var age: TimeInterval = 0
    
    private let orbNode: SKShapeNode
    private let glowNode: SKShapeNode
    private let iconNode: SKShapeNode
    
    override init() {
        self.despawnTime = GameConfig.MagnetOrb.despawnTime
        
        let r = GameConfig.MagnetOrb.visualRadius
        
        // Outer glow — electric feel
        glowNode = SKShapeNode(circleOfRadius: r + 5)
        glowNode.fillColor = SKColor(hex: GameConfig.MagnetOrb.glowColorHex, alpha: 0.25)
        glowNode.strokeColor = .clear
        glowNode.glowWidth = 8
        glowNode.zPosition = 3
        
        // Core orb
        orbNode = SKShapeNode(circleOfRadius: r)
        orbNode.fillColor = SKColor(hex: GameConfig.MagnetOrb.colorHex, alpha: 0.9)
        orbNode.strokeColor = SKColor(hex: GameConfig.MagnetOrb.colorHex, alpha: 0.5)
        orbNode.lineWidth = 1.5
        orbNode.zPosition = 4
        
        // Magnet icon — simple U-shape
        let iconPath = CGMutablePath()
        let half = r * 0.4
        // Left arm
        iconPath.move(to: CGPoint(x: -half, y: half))
        iconPath.addLine(to: CGPoint(x: -half, y: -half * 0.3))
        // Curve at bottom
        iconPath.addQuadCurve(to: CGPoint(x: half, y: -half * 0.3),
                              control: CGPoint(x: 0, y: -half))
        // Right arm
        iconPath.addLine(to: CGPoint(x: half, y: half))
        
        iconNode = SKShapeNode()
        iconNode.path = iconPath
        iconNode.strokeColor = .white
        iconNode.fillColor = .clear
        iconNode.lineWidth = 1.8
        iconNode.alpha = 0.9
        iconNode.zPosition = 5
        
        super.init()
        
        addChild(glowNode)
        addChild(orbNode)
        addChild(iconNode)
        
        setupPhysics()
        startAnimations()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Physics
    
    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: GameConfig.MagnetOrb.pickupRadius)
        body.isDynamic = false
        body.categoryBitMask = GameConfig.Physics.magnetOrb
        body.contactTestBitMask = GameConfig.Physics.player
        body.collisionBitMask = 0
        physicsBody = body
    }
    
    // MARK: - Animation
    
    private func startAnimations() {
        // Electric shimmer — faster than health orb
        let shimmer = SKAction.sequence([
            SKAction.scale(to: 1.12, duration: 0.35),
            SKAction.scale(to: 0.92, duration: 0.35)
        ])
        orbNode.run(SKAction.repeatForever(shimmer))
        
        // Rotating glow
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 4.0)
        glowNode.run(SKAction.repeatForever(rotate))
        
        // Glow pulse
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.5),
            SKAction.fadeAlpha(to: 0.15, duration: 0.5)
        ])
        glowNode.run(SKAction.repeatForever(pulse))
        
        // Spawn pop-in
        setScale(0.01)
        run(SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.15),
            SKAction.scale(to: 0.95, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.06)
        ]))
    }
    
    // MARK: - Update
    
    /// Call each frame. Returns true when orb should despawn.
    func update(deltaTime: TimeInterval) -> Bool {
        age += deltaTime
        
        // Start fading in last 2 seconds
        if age > despawnTime - 2.0 {
            let remaining = despawnTime - age
            let fadeAlpha = max(0, CGFloat(remaining / 2.0))
            alpha = fadeAlpha
        }
        
        return age >= despawnTime
    }
    
    // MARK: - Collection
    
    /// Play collection effect and remove
    func collect() {
        physicsBody = nil
        
        // Electric burst + fade
        let burst = SKShapeNode(circleOfRadius: 30)
        burst.fillColor = SKColor(hex: GameConfig.MagnetOrb.colorHex, alpha: 0.3)
        burst.strokeColor = SKColor(hex: GameConfig.MagnetOrb.colorHex, alpha: 0.6)
        burst.lineWidth = 2
        burst.glowWidth = 8
        burst.zPosition = 3
        burst.position = .zero
        addChild(burst)
        
        let expand = SKAction.group([
            SKAction.scale(to: 3.0, duration: 0.3),
            SKAction.fadeOut(withDuration: 0.3)
        ])
        burst.run(SKAction.sequence([expand, SKAction.removeFromParent()]))
        
        // Pop the orb itself
        let collect = SKAction.group([
            SKAction.scale(to: 1.5, duration: 0.15),
            SKAction.fadeOut(withDuration: 0.15)
        ])
        orbNode.run(collect)
        iconNode.run(collect)
        glowNode.run(SKAction.fadeOut(withDuration: 0.15))
        
        run(SKAction.sequence([SKAction.wait(forDuration: 0.35), SKAction.removeFromParent()]))
    }
    
    // MARK: - Spawn Position
    
    /// Random position within the arena, away from edges
    static func randomArenaPosition() -> CGPoint {
        let maxR = GameConfig.Arena.radius * 0.75
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance = CGFloat.random(in: 30...maxR)
        return CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
    }
}
