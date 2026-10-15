//
//  BeamNode.swift
//  Sparkforge
//
//  v2.2 Neutral rework, Unit N4: the chaos beam's PICTURE — nothing here
//  decides a hit. Every line of every lane is drawn each frame the beam fires
//  (visually continuous), in the locked palette: an astral-blue glow, a
//  neon-green core and an orange filament. Pixel-flame sizzles mark contact
//  points; they are a pooled, recycled set of small squares — visual ONLY
//  (no Burn, no damage), and the pool's size never limits a contact.
//

import SpriteKit

final class BeamNode: SKNode {
    private let glow = SKShapeNode()
    private let core = SKShapeNode()
    private let filament = SKShapeNode()
    private var sizzles: [SKShapeNode] = []
    private var nextSizzle = 0

    override init() {
        super.init()
        let N = GameConfig.Neutral.self
        zPosition = 7
        for (layer, hex, width, alpha) in [(glow, N.beamAstralBlueHex, N.beamGlowWidth, CGFloat(0.45)),
                                           (core, N.beamNeonGreenHex, N.beamCoreWidth, CGFloat(0.95)),
                                           (filament, N.beamOrangeHex, CGFloat(1), CGFloat(0.9))] {
            layer.strokeColor = SKColor(hex: hex, alpha: alpha)
            layer.lineWidth = width
            layer.lineCap = .round
            layer.fillColor = .clear
            addChild(layer)
        }
        glow.glowWidth = N.beamGlowWidth
        for i in 0..<N.beamSizzlePoolSize {
            let s = SKShapeNode(rectOf: CGSize(width: N.beamSizzleSize, height: N.beamSizzleSize))
            s.fillColor = SKColor(hex: i % 3 == 0 ? N.beamNeonGreenHex : N.beamOrangeHex, alpha: 1)
            s.strokeColor = .clear
            s.zPosition = 1
            s.isHidden = true
            addChild(s)
            sizzles.append(s)
        }
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    /// Draw every line (world coordinates) and show the beam.
    func draw(_ segments: [(CGPoint, CGPoint)]) {
        let path = CGMutablePath()
        for (a, b) in segments {
            path.move(to: a)
            path.addLine(to: b)
        }
        glow.path = path
        core.path = path
        filament.path = path
        isHidden = false
    }

    /// Flash a pixel flame at each contact point, recycling the pool. Visual only.
    func sizzle(at points: [CGPoint]) {
        guard !sizzles.isEmpty else { return }
        let lifetime = GameConfig.Neutral.beamSizzleLifetime
        for point in points.prefix(sizzles.count) {
            let s = sizzles[nextSizzle]
            nextSizzle = (nextSizzle + 1) % sizzles.count
            s.removeAllActions()
            s.position = CGPoint(x: point.x + CGFloat.random(in: -2...2), y: point.y + CGFloat.random(in: -2...2))
            s.alpha = 1
            s.setScale(1)
            s.isHidden = false
            s.run(SKAction.sequence([
                SKAction.group([SKAction.fadeOut(withDuration: lifetime),
                                SKAction.moveBy(x: 0, y: 4, duration: lifetime),
                                SKAction.scale(to: 0.4, duration: lifetime)]),
                SKAction.hide()
            ]))
        }
    }
}
