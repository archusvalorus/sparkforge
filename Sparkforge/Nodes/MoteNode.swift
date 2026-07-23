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
    static let bodyRadius: CGFloat = 15   // tiny by canon, but the detail must read

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
        let stone = SKColor(hex: 0xD8D4DE)      // pale carved stone
        let stoneEdge = SKColor(hex: 0x8A8296)
        let cloth = SKColor(hex: 0x2A1B44)      // deep violet tattered body
        let arcane = SKColor(hex: 0xB061FF)

        // Arcane aura — he is lit from inside by something else.
        let aura = SKShapeNode(circleOfRadius: R * 1.9)
        aura.fillColor = SKColor(hex: 0x8A3FD8, alpha: 0.16)
        aura.strokeColor = .clear
        aura.glowWidth = 16
        aura.zPosition = -2
        addChild(aura)

        // TWO great curved horns sweeping out and up from the hood.
        for side in [CGFloat(-1), 1] {
            let horn = SKShapeNode()
            let p = CGMutablePath()
            let baseX = side * R * 0.62, baseY = R * 0.34
            p.move(to: CGPoint(x: baseX, y: baseY))
            // outer sweep
            p.addCurve(to: CGPoint(x: side * R * 1.62, y: R * 1.46),
                       control1: CGPoint(x: side * R * 1.52, y: baseY + R * 0.10),
                       control2: CGPoint(x: side * R * 1.78, y: R * 0.92))
            // tip hooks inward
            p.addCurve(to: CGPoint(x: side * R * 0.98, y: R * 0.62),
                       control1: CGPoint(x: side * R * 1.30, y: R * 1.30),
                       control2: CGPoint(x: side * R * 1.22, y: R * 0.86))
            p.closeSubpath()
            horn.path = p
            horn.fillColor = stone
            horn.strokeColor = stoneEdge
            horn.lineWidth = 1
            horn.zPosition = 0.5
            addChild(horn)
        }

        // Tattered body — wide, ragged, hanging below the hood.
        let body = SKShapeNode()
        let bp = CGMutablePath()
        bp.move(to: CGPoint(x: -R * 0.86, y: R * 0.30))
        bp.addLine(to: CGPoint(x:  R * 0.86, y: R * 0.30))
        bp.addLine(to: CGPoint(x:  R * 1.04, y: -R * 0.62))
        bp.addLine(to: CGPoint(x:  R * 0.58, y: -R * 0.34))   // ragged hem
        bp.addLine(to: CGPoint(x:  R * 0.30, y: -R * 1.24))
        bp.addLine(to: CGPoint(x:  R * 0.02, y: -R * 0.52))
        bp.addLine(to: CGPoint(x: -R * 0.34, y: -R * 1.06))
        bp.addLine(to: CGPoint(x: -R * 0.62, y: -R * 0.40))
        bp.addLine(to: CGPoint(x: -R * 1.00, y: -R * 0.70))
        bp.closeSubpath()
        body.path = bp
        body.fillColor = cloth
        body.strokeColor = SKColor(hex: 0x6A4AA8, alpha: 0.8)
        body.lineWidth = 1
        body.zPosition = 1
        addChild(body)

        // The stone hood — the dominant silhouette, framing the void.
        let hood = SKShapeNode(circleOfRadius: R * 0.94)
        hood.fillColor = stone
        hood.strokeColor = stoneEdge
        hood.lineWidth = 1.2
        hood.position = CGPoint(x: 0, y: R * 0.30)
        hood.zPosition = 2
        addChild(hood)

        // The void inside it — a hole where a face should be.
        let face = SKShapeNode(circleOfRadius: R * 0.70)
        face.fillColor = SKColor(hex: 0x040309)
        face.strokeColor = .clear
        face.position = CGPoint(x: 0, y: R * 0.24)
        face.zPosition = 3
        addChild(face)

        // Large oval lavender eyes, softly glowing (slight asymmetry kept).
        for (eye, dx, scale) in [(eyeL, -R * 0.30, CGFloat(1.0)), (eyeR, R * 0.31, CGFloat(0.92))] {
            eye.path = CGPath(ellipseIn: CGRect(x: -R * 0.15, y: -R * 0.21,
                                                width: R * 0.30, height: R * 0.42), transform: nil)
            eye.fillColor = SKColor(hex: 0xE0BBFF)
            eye.strokeColor = .clear
            eye.glowWidth = 8
            eye.blendMode = .add
            eye.setScale(scale)
            eye.position = CGPoint(x: dx, y: R * 0.26)
            eye.zPosition = 4
            addChild(eye)
        }

        // Carved collar at the throat.
        let collar = SKShapeNode(rectOf: CGSize(width: R * 1.34, height: R * 0.30),
                                 cornerRadius: R * 0.11)
        collar.fillColor = stone
        collar.strokeColor = stoneEdge
        collar.lineWidth = 1
        collar.position = CGPoint(x: 0, y: -R * 0.34)
        collar.zPosition = 3.5
        addChild(collar)

        // Diamond pendant with an arcane mark.
        let pendant = SKShapeNode()
        let dp = CGMutablePath()
        dp.move(to: CGPoint(x: 0, y: -R * 0.52))
        dp.addLine(to: CGPoint(x: R * 0.22, y: -R * 0.76))
        dp.addLine(to: CGPoint(x: 0, y: -R * 1.00))
        dp.addLine(to: CGPoint(x: -R * 0.22, y: -R * 0.76))
        dp.closeSubpath()
        pendant.path = dp
        pendant.fillColor = SKColor(hex: 0x1A1030)
        pendant.strokeColor = stone
        pendant.lineWidth = 1
        pendant.zPosition = 3.6
        addChild(pendant)
        let spark = SKShapeNode(circleOfRadius: R * 0.07)
        spark.fillColor = SKColor(hex: 0xD79BFF)
        spark.strokeColor = .clear
        spark.glowWidth = 4
        spark.blendMode = .add
        spark.position = CGPoint(x: 0, y: -R * 0.76)
        spark.zPosition = 3.7
        addChild(spark)

        // THREE-fingered stone hands, crackling with arcane lightning.
        for side in [CGFloat(-1), 1] {
            let hand = SKNode()
            hand.position = CGPoint(x: side * R * 1.16, y: -R * 0.16)
            hand.zPosition = 2.5
            for f in 0..<3 {
                let finger = SKShapeNode(rectOf: CGSize(width: R * 0.17, height: R * 0.40),
                                         cornerRadius: R * 0.08)
                finger.fillColor = stone
                finger.strokeColor = stoneEdge
                finger.lineWidth = 0.6
                finger.position = CGPoint(x: CGFloat(f - 1) * R * 0.21,
                                          y: (f == 1 ? R * 0.09 : 0))
                finger.zRotation = CGFloat(f - 1) * 0.20 * side
                hand.addChild(finger)
            }
            // Jagged arcane crackle off the fingertips.
            for j in 0..<3 {
                let bolt = SKShapeNode()
                let lp = CGMutablePath()
                let ox = side * R * (0.30 + CGFloat(j) * 0.16)
                lp.move(to: CGPoint(x: ox, y: R * 0.10))
                lp.addLine(to: CGPoint(x: ox + side * R * 0.22, y: R * 0.34))
                lp.addLine(to: CGPoint(x: ox + side * R * 0.12, y: R * 0.36))
                lp.addLine(to: CGPoint(x: ox + side * R * 0.34, y: R * 0.66))
                bolt.path = lp
                bolt.strokeColor = arcane
                bolt.lineWidth = 1.3
                bolt.glowWidth = 4
                bolt.blendMode = .add
                hand.addChild(bolt)
                bolt.run(SKAction.repeatForever(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.15, duration: 0.10 + Double(j) * 0.05),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.09 + Double(j) * 0.04)
                ])))
            }
            addChild(hand)
        }

        // Drifting arcane motes around him.
        for i in 0..<6 {
            let m = SKShapeNode(circleOfRadius: R * 0.06)
            m.fillColor = arcane
            m.strokeColor = .clear
            m.glowWidth = 3
            m.blendMode = .add
            let a = CGFloat(i) / 6 * .pi * 2
            m.position = CGPoint(x: cos(a) * R * 1.5, y: sin(a) * R * 1.25)
            m.zPosition = 0
            addChild(m)
            m.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.moveBy(x: 0, y: R * 0.4, duration: 1.1 + Double(i) * 0.13),
                SKAction.moveBy(x: 0, y: -R * 0.4, duration: 1.0 + Double(i) * 0.11)
            ])))
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
