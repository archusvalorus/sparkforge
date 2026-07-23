// MoteNode.swift
// Sparkforge
//
// v2.0 (Unit 3) — MOTE. The studio mascot who enters by deleting the player.
//
// "Most mascots enter by waving. Mote enters by deleting the player.
//  That is the joke. That is the brand. That is the hook."
//
// Canon visual DNA (Forgebound Labs studio canon — Mote predates Sparkforge and
// appears across projects): floating body, BLACK VOID FACE, glowing purple eyes,
// cracked horn crown, tattered cloak, THREE-fingered hands, purple arcane over
// greyscale, and slight asymmetry that must NOT be polished out.
//
// He is not an enemy and not a boss: no health, no hitbox, no HP bar. He is a
// scripted event wearing a character. He should read as smaller than expected,
// faster than expected, and ruder than expected — "cosmic lint / murder fairy /
// tiny impossible bastard."
//
// NOTE (asset pipeline): the handoff calls Mote the natural first TEXTURED
// sprite (Lyra's character sheet exists). This is a faithful procedural stand-in
// so the sequence can ship; swapping in a sprite later means replacing buildBody()
// only — nothing else in the entrance sequence touches his internals.
// See docs/mote-v2.0-handoff.md.

import SpriteKit

final class MoteNode: SKNode {

    /// Deliberately tiny. The joke is that this ends you.
    static let bodyRadius: CGFloat = 13

    private let eyeL = SKShapeNode(circleOfRadius: 2.6)
    private let eyeR = SKShapeNode(circleOfRadius: 2.2)   // asymmetry is canon

    override init() {
        super.init()
        zPosition = 400          // above everything — he is not part of the scene's rules
        buildBody()
        startFloat()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func buildBody() {
        let R = MoteNode.bodyRadius

        // Neon-white aura — the "from another layer of the app" too-crisp glow.
        let aura = SKShapeNode(circleOfRadius: R * 1.7)
        aura.fillColor = SKColor(hex: 0xC79BFF, alpha: 0.22)
        aura.strokeColor = SKColor(hex: 0xE9D6FF, alpha: 0.85)
        aura.lineWidth = 1.5
        aura.glowWidth = 14
        aura.zPosition = -1
        addChild(aura)

        // Tattered cloak — greyscale, asymmetric, ragged hem.
        let cloak = SKShapeNode()
        let cp = CGMutablePath()
        cp.move(to: CGPoint(x: -R * 0.95, y: R * 0.35))
        cp.addLine(to: CGPoint(x:  R * 0.90, y: R * 0.42))
        cp.addLine(to: CGPoint(x:  R * 1.05, y: -R * 0.85))
        cp.addLine(to: CGPoint(x:  R * 0.45, y: -R * 0.45))   // ragged
        cp.addLine(to: CGPoint(x:  R * 0.10, y: -R * 1.15))
        cp.addLine(to: CGPoint(x: -R * 0.35, y: -R * 0.50))
        cp.addLine(to: CGPoint(x: -R * 0.80, y: -R * 1.00))
        cp.closeSubpath()
        cloak.path = cp
        cloak.fillColor = SKColor(hex: 0xE8E8EE)
        cloak.strokeColor = SKColor(hex: 0x9A93A8, alpha: 0.9)
        cloak.lineWidth = 1
        cloak.zPosition = 1
        addChild(cloak)

        // The void face — a black hole where a face should be.
        let face = SKShapeNode(circleOfRadius: R * 0.72)
        face.fillColor = SKColor(hex: 0x05040A)
        face.strokeColor = SKColor(hex: 0xB88CFF, alpha: 0.55)
        face.lineWidth = 1.2
        face.position = CGPoint(x: 0, y: R * 0.18)
        face.zPosition = 2
        addChild(face)

        // Glowing purple eyes — mismatched on purpose.
        for (eye, dx) in [(eyeL, -R * 0.26), (eyeR, R * 0.28)] {
            eye.fillColor = SKColor(hex: 0xC77BFF)
            eye.strokeColor = .clear
            eye.glowWidth = 7
            eye.blendMode = .add
            eye.position = CGPoint(x: dx, y: R * 0.22)
            eye.zPosition = 3
            addChild(eye)
        }

        // Cracked horn crown — uneven, a couple of stubs, one broken short.
        let hornSpecs: [(x: CGFloat, h: CGFloat, lean: CGFloat)] = [
            (-R * 0.62, R * 0.85, -0.22), (-R * 0.18, R * 1.15, -0.05),
            ( R * 0.26, R * 0.60,  0.14), ( R * 0.66, R * 0.95,  0.30)
        ]
        for spec in hornSpecs {
            let horn = SKShapeNode()
            let p = CGMutablePath()
            let baseY = R * 0.66
            p.move(to: CGPoint(x: spec.x - R * 0.13, y: baseY))
            p.addLine(to: CGPoint(x: spec.x + spec.lean * R, y: baseY + spec.h))
            p.addLine(to: CGPoint(x: spec.x + R * 0.13, y: baseY))
            p.closeSubpath()
            horn.path = p
            horn.fillColor = SKColor(hex: 0xF2EFF7)
            horn.strokeColor = SKColor(hex: 0x8A7FA0, alpha: 0.9)
            horn.lineWidth = 0.8
            horn.zPosition = 2.5
            addChild(horn)
        }

        // THREE-fingered hands — tiny, and canon.
        for side in [CGFloat(-1), 1] {
            let hand = SKNode()
            hand.position = CGPoint(x: side * R * 1.02, y: -R * 0.18)
            for f in 0..<3 {
                let finger = SKShapeNode(rectOf: CGSize(width: R * 0.16, height: R * 0.34),
                                         cornerRadius: R * 0.07)
                finger.fillColor = SKColor(hex: 0xF2EFF7)
                finger.strokeColor = .clear
                finger.position = CGPoint(x: CGFloat(f - 1) * R * 0.19,
                                          y: CGFloat(f == 1 ? 0.06 : 0) * R)
                hand.addChild(finger)
            }
            hand.zPosition = 1.5
            addChild(hand)
        }
    }

    /// He floats. He does not walk, and he is never still.
    private func startFloat() {
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 3.5, duration: 0.9),
            SKAction.moveBy(x: 0, y: -3.5, duration: 0.9)
        ])
        bob.timingMode = .easeInEaseOut
        run(SKAction.repeatForever(bob), withKey: "float")
    }

    /// A slow blink right before he moves — the "he looked at you" beat.
    func regard() {
        let blink = SKAction.sequence([
            SKAction.scaleY(to: 0.15, duration: 0.09),
            SKAction.scaleY(to: 1.0, duration: 0.12)
        ])
        eyeL.run(blink)
        eyeR.run(SKAction.sequence([SKAction.wait(forDuration: 0.04), blink]))
    }

    /// Mote speaks only AFTER the hit. Funny-rude, never cruel.
    static let lines = [
        "Bet that hurt, heehee!", "Boop.", "Found you.", "Nope!",
        "That looked important.", "You were doing great!", "Tiny but decisive.",
        "Aww, you had momentum.", "Deleted with love.", "The anvil said no.", "Mote wins."
    ]

    /// A speech bubble pinned above him.
    func say(_ text: String) {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 13
        label.fontColor = SKColor(hex: 0x1A1030)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        let pad: CGFloat = 12
        let w = label.frame.width + pad * 2, h = label.frame.height + pad
        let bubble = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 8)
        bubble.fillColor = SKColor(hex: 0xF2EAFF)
        bubble.strokeColor = SKColor(hex: 0xC77BFF)
        bubble.lineWidth = 2
        bubble.glowWidth = 5
        bubble.position = CGPoint(x: 0, y: MoteNode.bodyRadius * 3.1)
        bubble.zPosition = 5
        bubble.addChild(label)
        bubble.setScale(0.2)
        bubble.alpha = 0
        addChild(bubble)

        let pop = SKAction.group([SKAction.scale(to: 1.0, duration: 0.22),
                                  SKAction.fadeIn(withDuration: 0.18)])
        pop.timingMode = .easeOut
        bubble.run(pop)
    }
}
