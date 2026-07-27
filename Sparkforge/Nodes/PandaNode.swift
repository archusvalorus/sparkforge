// PandaNode.swift
// Sparkforge
//
// v2.0 (C2) — a panda.
//
// PLACEHOLDER ART, like the Nature Canon roster: shaped enough to read as a
// panda at a glance (round body, black ears, eye patches, a waddle), plain
// enough that the art pass replaces it wholesale alongside the kaiju, the
// samurai and the skins.
//
// It is a puppet, deliberately. It knows how to waddle, roll, sit and look
// pleased; it does not know why it is doing any of those things. GameScene owns
// the decision — which matters here more than usual, because the one thing
// Panda must never acquire is legible internal logic.
//
// Not a FamiliarNode: that template is a winged, home-following companion bound
// to Spark. A panda is not bound to Spark. A panda is its own guy.

import SpriteKit

final class PandaNode: SKNode {

    private let body = SKShapeNode()
    private let leftEar = SKShapeNode()
    private let rightEar = SKShapeNode()
    private let leftPatch = SKShapeNode()
    private let rightPatch = SKShapeNode()
    private let muzzle = SKShapeNode()

    /// Facing, preserved across scale changes.
    private var bodyScale: CGFloat = 1.0
    private var waddlePhase: CGFloat = 0

    private let white = SKColor(hex: 0xF2F0EA)
    private let black = SKColor(hex: 0x1A1A1A)

    /// The panda's drawn width in points before any scaling — the body ellipse
    /// spans -11…11. Kept explicit so the size ladder in GameConfig can be
    /// expressed in POINTS ACROSS rather than in an opaque multiplier, and so it
    /// survives the swap from these shapes to a sprite unchanged.
    static let naturalWidth: CGFloat = 22

    /// Scale that renders a panda at `GameConfig.Panda.bodyWidth`.
    static var baseScale: CGFloat { GameConfig.Panda.bodyWidth / naturalWidth }

    override init() {
        super.init()
        zPosition = 7
        let s = DeviceScale.gameplay

        for ear in [leftEar, rightEar] {
            ear.path = CGPath(ellipseIn: CGRect(x: -3.5 * s, y: -3.5 * s,
                                                width: 7 * s, height: 7 * s), transform: nil)
            ear.fillColor = black
            ear.strokeColor = .clear
            addChild(ear)
        }
        leftEar.position = CGPoint(x: -7 * s, y: 8 * s)
        rightEar.position = CGPoint(x: 7 * s, y: 8 * s)

        body.path = CGPath(ellipseIn: CGRect(x: -11 * s, y: -10 * s,
                                             width: 22 * s, height: 20 * s), transform: nil)
        body.fillColor = white
        body.strokeColor = SKColor(hex: 0x9A968C, alpha: 0.9)
        body.lineWidth = 1
        addChild(body)

        // The eye patches do most of the identification work at this size.
        for patch in [leftPatch, rightPatch] {
            patch.path = CGPath(ellipseIn: CGRect(x: -3 * s, y: -4 * s,
                                                  width: 6 * s, height: 8 * s), transform: nil)
            patch.fillColor = black
            patch.strokeColor = .clear
            body.addChild(patch)
        }
        leftPatch.position = CGPoint(x: -4.5 * s, y: 2 * s)
        rightPatch.position = CGPoint(x: 4.5 * s, y: 2 * s)
        leftPatch.zRotation = 0.25
        rightPatch.zRotation = -0.25

        muzzle.path = CGPath(ellipseIn: CGRect(x: -2 * s, y: -2 * s,
                                               width: 4 * s, height: 3 * s), transform: nil)
        muzzle.fillColor = black
        muzzle.strokeColor = .clear
        muzzle.position = CGPoint(x: 0, y: -3 * s)
        body.addChild(muzzle)

        setBodyScale(Self.baseScale)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Movement

    /// Waddle toward a point. Returns true once it has arrived.
    @discardableResult
    func waddle(toward point: CGPoint, speed: CGFloat, dt: TimeInterval) -> Bool {
        let delta = point - position
        if delta.length < 4 * DeviceScale.gameplay { return true }
        let dir = delta.normalized
        position += dir * speed * CGFloat(dt)

        // The waddle: a slight side-to-side rock, because walking straight would
        // suggest purpose.
        waddlePhase += CGFloat(dt) * 9
        zRotation = sin(waddlePhase) * 0.10
        if dir.x < -0.05 { xScale = -bodyScale }
        else if dir.x > 0.05 { xScale = bodyScale }
        return false
    }

    func setBodyScale(_ scale: CGFloat) {
        bodyScale = scale
        yScale = scale
        xScale = xScale < 0 ? -scale : scale
    }

    // MARK: - Poses

    /// Tuck into a ball and spin — the roll.
    func startRolling() {
        removeAction(forKey: "pose")
        zRotation = 0
        run(SKAction.repeatForever(SKAction.rotate(byAngle: -.pi * 2, duration: 0.4)),
            withKey: "roll")
        body.run(SKAction.scaleY(to: 0.9, duration: 0.1))
    }

    func stopRolling() {
        removeAction(forKey: "roll")
        run(SKAction.rotate(toAngle: 0, duration: 0.15), withKey: "pose")
        body.run(SKAction.scaleY(to: 1.0, duration: 0.1))
    }

    /// Sit down. Squashes slightly and stops moving. That's the whole pose.
    func sit() {
        removeAction(forKey: "pose")
        zRotation = 0
        run(SKAction.group([SKAction.scaleY(to: bodyScale * 0.86, duration: 0.2),
                            SKAction.scaleX(to: xScale < 0 ? -bodyScale * 1.1 : bodyScale * 1.1,
                                            duration: 0.2)]), withKey: "pose")
    }

    /// Look pleased. Does nothing else. This is a complete implementation.
    func lookPleased() {
        removeAction(forKey: "pose")
        run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scaleY(to: bodyScale * 1.06, duration: 0.5),
            SKAction.scaleY(to: bodyScale * 0.98, duration: 0.5)
        ])), withKey: "pose")
    }

    /// A small pleased bounce — used when a panda has just done its one thing.
    func bounce() {
        body.run(SKAction.sequence([SKAction.scale(to: 1.18, duration: 0.1),
                                    SKAction.scale(to: 1.0, duration: 0.12)]))
    }

    /// A bamboo sword, held at the side. The only visual tell the samurai gives,
    /// and by the time you've noticed it the strike has usually happened.
    func equipSword() {
        guard childNode(withName: "sword") == nil else { return }
        let s = DeviceScale.gameplay
        let sword = SKShapeNode(rectOf: CGSize(width: 2.4 * s, height: 26 * s), cornerRadius: 1.2 * s)
        sword.name = "sword"
        sword.fillColor = SKColor(hex: 0x9FCB63)
        sword.strokeColor = SKColor(hex: 0x4E7A2A, alpha: 0.95)
        sword.lineWidth = 1
        sword.position = CGPoint(x: 10 * s, y: 0)
        sword.zRotation = 0.35
        sword.zPosition = 1
        addChild(sword)
    }

    /// One strike. Wind up, cut, hold the follow-through.
    func strike(completion: @escaping () -> Void) {
        removeAction(forKey: "pose")
        let sword = childNode(withName: "sword")
        sword?.run(SKAction.sequence([
            SKAction.rotate(toAngle: -1.5, duration: 0.28),          // raised
            SKAction.wait(forDuration: 0.12),
            SKAction.rotate(toAngle: 1.9, duration: 0.06)            // through
        ]))
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.4),
            SKAction.run(completion)
        ]))
    }

    /// Bows. Not to you.
    func bow() {
        removeAction(forKey: "pose")
        run(SKAction.sequence([
            SKAction.scaleY(to: bodyScale * 0.7, duration: 0.25),
            SKAction.wait(forDuration: 0.35),
            SKAction.scaleY(to: bodyScale, duration: 0.25)
        ]), withKey: "pose")
    }

    /// A tiny hat. There is no further explanation, and there will not be one.
    func wearHat() {
        guard childNode(withName: "hat") == nil else { return }
        let s = DeviceScale.gameplay
        let hat = SKNode()
        hat.name = "hat"

        let brim = SKShapeNode(rectOf: CGSize(width: 13 * s, height: 1.8 * s), cornerRadius: 0.9 * s)
        brim.fillColor = SKColor(hex: 0xB4482E)
        brim.strokeColor = .clear
        hat.addChild(brim)

        let crown = SKShapeNode(rectOf: CGSize(width: 7 * s, height: 6 * s), cornerRadius: 1 * s)
        crown.fillColor = SKColor(hex: 0xB4482E)
        crown.strokeColor = .clear
        crown.position = CGPoint(x: 0, y: 3.4 * s)
        hat.addChild(crown)

        hat.position = CGPoint(x: 0, y: 12 * s)
        hat.setScale(0.1)
        addChild(hat)
        hat.run(SKAction.scale(to: 1.0, duration: 0.2))
    }

    /// Step into a portal that was not there a moment ago.
    func enterPortal(completion: @escaping () -> Void) {
        removeAction(forKey: "pose")
        let s = DeviceScale.gameplay
        let portal = SKShapeNode(ellipseOf: CGSize(width: 30 * s, height: 10 * s))
        portal.fillColor = SKColor(hex: 0x120A1E, alpha: 0.95)
        portal.strokeColor = SKColor(hex: 0x7A4FD0, alpha: 0.9)
        portal.lineWidth = 2
        portal.glowWidth = 4
        portal.zPosition = -1
        portal.position = CGPoint(x: 0, y: -9 * s)
        portal.setScale(0.05)
        addChild(portal)

        portal.run(SKAction.scale(to: 1.0, duration: 0.3))
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.35),
            SKAction.group([SKAction.scaleY(to: 0.05, duration: 0.35),
                            SKAction.moveBy(x: 0, y: -10 * s, duration: 0.35)]),
            SKAction.run { portal.run(SKAction.sequence([SKAction.scale(to: 0.05, duration: 0.25),
                                                         SKAction.removeFromParent()])) },
            SKAction.wait(forDuration: 0.25),
            SKAction.removeFromParent(),
            SKAction.run(completion)
        ]))
    }

    /// Wander off and cease to be the scene's problem.
    func leave(completion: @escaping () -> Void) {
        removeAction(forKey: "pose")
        run(SKAction.sequence([
            SKAction.group([SKAction.fadeOut(withDuration: 0.5),
                            SKAction.moveBy(x: 0, y: 6, duration: 0.5)]),
            SKAction.removeFromParent(),
            SKAction.run(completion)
        ]))
    }
}
