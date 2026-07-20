import SpriteKit

/// A small independent companion — the reusable "familiar / summon" template.
///
/// First used by Apex's Blood Familiar (a bat). Encapsulates its own look,
/// wing-flap, bob, smooth-follow toward a home point, and lunge/pounce attack
/// animations. Combat (targeting, damage, kill-scaling) is driven by GameScene,
/// so the node stays a reusable visual+movement puppet. Future Familiar/Summoner
/// cards reskin the body + palette and reuse the behavior unchanged.
/// See the familiar-summoner-card-set memory (e.g. the winged-tiger capstone).
final class FamiliarNode: SKNode {

    private let body = SKShapeNode()
    private let leftWing = SKShapeNode()
    private let rightWing = SKShapeNode()
    private let bobAmp: CGFloat
    private var bobPhase: CGFloat = 0
    private(set) var isLunging = false
    private let followLerp: CGFloat = 0.14
    private var bodyScale: CGFloat = 1.0

    init(colorHex: UInt32 = 0xC02040) {
        bobAmp = 6 * DeviceScale.gameplay
        super.init()
        zPosition = 7
        let s = DeviceScale.gameplay

        // Body — a small rounded blood-red core.
        body.path = CGPath(ellipseIn: CGRect(x: -6*s, y: -5*s, width: 12*s, height: 10*s), transform: nil)
        body.fillColor = SKColor(hex: colorHex, alpha: 1.0)
        body.strokeColor = SKColor(hex: 0x400010, alpha: 1.0)
        body.lineWidth = 1
        body.glowWidth = 3
        addChild(body)

        // Wings — two triangles that flap.
        leftWing.path = wingPath(dir: -1, s: s)
        rightWing.path = wingPath(dir: 1, s: s)
        for wing in [leftWing, rightWing] {
            wing.fillColor = SKColor(hex: colorHex, alpha: 0.9)
            wing.strokeColor = SKColor(hex: 0x400010, alpha: 0.9)
            wing.lineWidth = 1
            addChild(wing)
        }

        // Eyes — tiny malicious dots.
        for dx in [-3.0, 3.0] {
            let eye = SKShapeNode(circleOfRadius: 1.4*s)
            eye.fillColor = SKColor(hex: 0xFFDD33, alpha: 1.0)
            eye.strokeColor = .clear
            eye.glowWidth = 2
            eye.position = CGPoint(x: CGFloat(dx)*s, y: 1*s)
            body.addChild(eye)
        }

        // Continuous flap.
        let up = SKAction.scaleY(to: 0.4, duration: 0.14)
        let down = SKAction.scaleY(to: 1.0, duration: 0.14)
        up.timingMode = .easeInEaseOut
        down.timingMode = .easeInEaseOut
        let flap = SKAction.repeatForever(SKAction.sequence([up, down]))
        leftWing.run(flap)
        rightWing.run(flap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func wingPath(dir: CGFloat, s: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: dir*4*s, y: 0))
        p.addLine(to: CGPoint(x: dir*16*s, y: 5*s))
        p.addLine(to: CGPoint(x: dir*13*s, y: -4*s))
        p.closeSubpath()
        return p
    }

    /// Grow the familiar (called per Apex tier). Preserves facing direction.
    func setBodyScale(_ s: CGFloat) {
        bodyScale = s
        yScale = s
        xScale = xScale < 0 ? -s : s
    }

    /// Smooth-follow toward a home point with a gentle bob. Skipped mid-lunge.
    func follow(to home: CGPoint, dt: TimeInterval) {
        guard !isLunging else { return }
        bobPhase += CGFloat(dt) * 4
        let target = CGPoint(x: home.x, y: home.y + sin(bobPhase) * bobAmp)
        position = CGPoint(x: position.x + (target.x - position.x) * followLerp,
                           y: position.y + (target.y - position.y) * followLerp)
        if target.x < position.x - 1 { xScale = -bodyScale }
        else if target.x > position.x + 1 { xScale = bodyScale }
    }

    /// Dart toward a target and snap back — the bite animation.
    func lunge(at targetPos: CGPoint) {
        guard !isLunging else { return }
        isLunging = true
        let home = position
        let approach = CGPoint(x: targetPos.x + (home.x - targetPos.x) * 0.2,
                               y: targetPos.y + (home.y - targetPos.y) * 0.2)
        let dart = SKAction.move(to: approach, duration: 0.12); dart.timingMode = .easeIn
        let back = SKAction.move(to: home, duration: 0.18); back.timingMode = .easeOut
        run(SKAction.sequence([dart, back, SKAction.run { [weak self] in self?.isLunging = false }]))
        body.run(SKAction.sequence([SKAction.scale(to: 1.35, duration: 0.1),
                                    SKAction.scale(to: 1.0, duration: 0.12)]))
    }

    /// A bigger leap with a spin onto a point — the T5 pounce.
    func pounce(at targetPos: CGPoint) {
        guard !isLunging else { return }
        isLunging = true
        let home = position
        let dart = SKAction.move(to: targetPos, duration: 0.14); dart.timingMode = .easeIn
        let back = SKAction.move(to: home, duration: 0.24); back.timingMode = .easeOut
        let spin = SKAction.rotate(byAngle: .pi * 2, duration: 0.38)
        run(SKAction.group([spin,
            SKAction.sequence([dart, back, SKAction.run { [weak self] in self?.isLunging = false }])]))
    }
}
