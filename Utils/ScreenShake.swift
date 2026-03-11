// ScreenShake.swift
// Sparkforge
//
// Screen shake utility for impact feel.
// Call on the scene node to shake the camera/scene.

import SpriteKit

extension SKNode {
    
    /// Quick screen shake. Intensity is max offset in points.
    func shake(intensity: CGFloat = 6, duration: TimeInterval = 0.2) {
        let shakeCount = Int(duration / 0.03)
        var actions: [SKAction] = []
        
        for i in 0..<shakeCount {
            // Decreasing intensity over time
            let progress = CGFloat(i) / CGFloat(shakeCount)
            let currentIntensity = intensity * (1.0 - progress)
            
            let dx = CGFloat.random(in: -currentIntensity...currentIntensity)
            let dy = CGFloat.random(in: -currentIntensity...currentIntensity)
            
            actions.append(SKAction.moveBy(x: dx, y: dy, duration: 0.03))
        }
        
        // Return to original position
        actions.append(SKAction.move(to: .zero, duration: 0.03))
        
        run(SKAction.sequence(actions), withKey: "screenShake")
    }
}
