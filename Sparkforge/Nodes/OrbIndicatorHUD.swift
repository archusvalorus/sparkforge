// OrbIndicatorHUD.swift
// Sparkforge
//
// v2.0 (HUD readout pass) — edge-of-screen direction markers for off-screen
// pickups. Arena 5 doubled the field, and orbs became genuinely hard to FIND:
// a pickup you can't locate isn't a decision, it's a lottery. These little
// triangles point toward off-screen orbs and shrink with distance, so the
// player can still choose "is that heal worth the walk?"
//
// Colour discipline is canon and unchanged: BLUE = magnet (utility),
// GREEN = health. Health orbs stay non-magnetized — walking to them is a
// positioning decision, which is exactly why finding them has to be possible.
//
// Camera-anchored. Triangles are pooled (no per-frame node churn).

import SpriteKit

final class OrbIndicatorHUD: SKNode {

    /// One tracked pickup: world position + its canonical colour.
    struct Target {
        let position: CGPoint
        let colorHex: UInt32
    }

    private var pool: [SKShapeNode] = []
    private let edgeInset: CGFloat = 26      // how far inside the screen edge markers sit
    private let hideRadius: CGFloat = 40     // don't mark something basically on top of you

    /// Rebuild markers for this frame.
    /// - Parameters:
    ///   - targets: world-space pickups to mark.
    ///   - center: the world point the camera is centred on (the player).
    ///   - viewSize: the scene size (camera-local screen extents).
    func update(targets: [Target], center: CGPoint, viewSize: CGSize) {
        let halfW = viewSize.width / 2 - edgeInset
        let halfH = viewSize.height / 2 - edgeInset
        var used = 0

        for t in targets {
            let dx = t.position.x - center.x
            let dy = t.position.y - center.y

            // On-screen (or right on top of us) → no marker needed.
            let onScreen = abs(dx) < halfW && abs(dy) < halfH
            let dist = (dx * dx + dy * dy).squareRoot()
            if onScreen || dist < hideRadius { continue }

            let marker = markerAt(index: used)
            used += 1

            // Project onto the screen-edge rectangle along the direction vector.
            let scale = min(halfW / max(abs(dx), 0.0001), halfH / max(abs(dy), 0.0001))
            marker.position = CGPoint(x: dx * scale, y: dy * scale)
            marker.zRotation = atan2(dy, dx)

            // Distance read: nearer = larger + more opaque.
            let t01 = min(dist / 1400, 1.0)
            marker.setScale(1.15 - 0.5 * t01)
            marker.alpha = 0.95 - 0.45 * t01

            let color = SKColor(hex: t.colorHex)
            marker.fillColor = color
            marker.strokeColor = color
            marker.isHidden = false
        }

        // Park unused markers.
        if used < pool.count {
            for i in used..<pool.count { pool[i].isHidden = true }
        }
    }

    func clear() { pool.forEach { $0.isHidden = true } }

    /// Pooled triangle pointing along +x (rotated to the target direction).
    private func markerAt(index: Int) -> SKShapeNode {
        if index < pool.count { return pool[index] }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 11, y: 0))
        path.addLine(to: CGPoint(x: -7, y: 7))
        path.addLine(to: CGPoint(x: -7, y: -7))
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        node.lineWidth = 1
        node.glowWidth = 3
        node.zPosition = 240
        addChild(node)
        pool.append(node)
        return node
    }
}
