// VignetteNode.swift
// Sparkforge
//
// Screen-edge darkening overlay for atmospheric depth.
// Attaches to camera so it stays fixed on screen.

import SpriteKit

final class VignetteNode: SKNode {
    
    init(size: CGSize) {
        super.init()
        
        zPosition = 50  // Above gameplay, below UI
        
        // Create radial gradient effect using concentric rings
        let steps = 8
        let maxAlpha: CGFloat = 0.6
        
        for i in 0..<steps {
            let progress = CGFloat(i) / CGFloat(steps - 1)
            let innerRadius = size.width * 0.3 * (1.0 - progress) + size.width * 0.5 * progress
            let alpha = maxAlpha * progress * progress  // Quadratic falloff
            
            let ring = SKShapeNode(rectOf: CGSize(width: size.width + 100, height: size.height + 100))
            ring.fillColor = .clear
            ring.strokeColor = SKColor(hex: 0x000000, alpha: alpha)
            ring.lineWidth = size.width * 0.08
            ring.zPosition = CGFloat(i)
            addChild(ring)
        }
        
        // Extra dark corners
        let cornerAlpha: CGFloat = 0.4
        let corners: [(CGFloat, CGFloat)] = [
            (-size.width/2, size.height/2),
            (size.width/2, size.height/2),
            (-size.width/2, -size.height/2),
            (size.width/2, -size.height/2)
        ]
        
        for (cx, cy) in corners {
            let corner = SKShapeNode(circleOfRadius: size.width * 0.15)
            corner.fillColor = SKColor(hex: 0x000000, alpha: cornerAlpha)
            corner.strokeColor = .clear
            corner.glowWidth = size.width * 0.1
            corner.position = CGPoint(x: cx, y: cy)
            corner.zPosition = 10
            addChild(corner)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
