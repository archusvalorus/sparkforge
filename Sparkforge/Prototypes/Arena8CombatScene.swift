#if DEBUG
import SpriteKit
import UIKit

final class Arena8CombatScene: SKScene {
    private let model = Arena8CombatModel()
    private let world = SKNode()
    private let rig = SKCameraNode()
    private let hud = SKNode()
    private let joystick = VirtualJoystick()
    private let status = SKLabelNode(fontNamed: "Menlo")
    private var buttons: [String: SKLabelNode] = [:]
    private var lastTime: TimeInterval = 0
    private var manualHold = false
    private var foreground = true
    private var installed = false

    override func didMove(to view: SKView) {
        guard !installed else { return }; installed = true
        model.reset() // Also establishes fresh actors on same-instance re-entry.
        backgroundColor = SKColor(hex: 0x111522)
        physicsWorld.gravity = .zero
        addChild(world); world.addChild(model.root); addChild(rig); camera = rig
        // Camera follows Spark at 1x. Joystick/HUD remain in native scene units.
        rig.addChild(hud); hud.zPosition = 200
        rig.addChild(joystick); joystick.zPosition = 300
        let floor = SKShapeNode(rect: GameConfig.Arena8Prototype.world)
        floor.fillColor = SKColor(hex: 0x253A48); floor.strokeColor = SKColor(hex: 0xB7C7DB); floor.lineWidth = 3
        world.addChild(floor)
        for footprint in model.geometry.geometry.blockedFootprints {
            let node = SKShapeNode(rectOf: CGSize(width: footprint.halfExtents.width * 2, height: footprint.halfExtents.height * 2))
            node.position = footprint.center; node.fillColor = SKColor(hex: 0x131823)
            node.strokeColor = SKColor(hex: 0x8DA0BB); node.lineWidth = 3; world.addChild(node)
        }
        let top = size.height / 2 - view.safeAreaInsets.top
        func label(_ text: String, y: CGFloat, size: CGFloat) -> SKLabelNode {
            let l = SKLabelNode(fontNamed: "Menlo-Bold"); l.text = text; l.fontSize = size
            l.position.y = y; hud.addChild(l); return l
        }
        _ = label("ARENA 8 / COMBAT BRIDGE", y: top - 28, size: 15)
        _ = label("Real nodes / base loadout / no saves", y: top - 48, size: 10)
        for (i, name) in ["PAUSE", "RESET", "LS", "FIRE", "SPAWN", "SHOVE"].enumerated() {
            let l = label(name, y: top - 78 - CGFloat(i / 3) * 30, size: 12)
            l.position.x = CGFloat(i % 3 - 1) * size.width / 3
            l.fontColor = SKColor(hex: 0xAFC6FF); buttons[name] = l
        }
        status.fontSize = 10; status.position.y = top - 137; hud.addChild(status)
        _ = label("Joystick moves / FIRE toggles auto-fire", y: -size.height / 2 + view.safeAreaInsets.bottom + 46, size: 10)
        _ = label("SPAWN after kill / XP banks; no drafts", y: -size.height / 2 + view.safeAreaInsets.bottom + 28, size: 10)
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundHold), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(foregroundReady), name: UIApplication.didBecomeActiveNotification, object: nil)
        render()
        if ProcessInfo.processInfo.arguments.contains("--arena8-combat-checks") { Arena8CombatChecks.run(scene: self) }
    }

    // Executable lifecycle/camera seam, called only by the explicit check arg.
    func verifyLifecycle() -> [String: Bool] {
        model.player.position = CGPoint(x: -220, y: 0); render()
        let follows = rig.position == model.player.position && rig.xScale == 1 && rig.yScale == 1
        model.fire(toward: CGPoint(x: 280, y: 0))
        let point = model.projectiles.first?.position, age = model.elapsed
        backgroundHold(); update(100); update(110)
        let froze = model.held && model.root.isPaused && model.elapsed == age && model.projectiles.first?.position == point
        foregroundReady(); update(120)
        let resumes = !model.held && model.elapsed == age
        manualHold = true; backgroundHold(); foregroundReady()
        let keepsPause = model.held
        model.reset(); manualHold = false; foreground = true; lastTime = 0; render()
        return ["scene-player-follow-camera": follows, "scene-background-freeze": froze,
                "scene-resume-no-catchup": resumes, "scene-background-preserves-manual-pause": keepsPause]
    }

    override func update(_ time: TimeInterval) {
        let dt = lastTime == 0 ? 0 : time - lastTime; lastTime = time
        model.held = manualHold || !foreground
        model.step(dt, direction: joystick.direction); render()
    }

    private func render() {
        rig.position = model.player.position
        status.text = "HP \(model.stats.currentHP) XP \(model.player.currentXP) K \(model.kills) / LS \(model.longShot ? "ON" : "OFF") FIRE \(model.firing ? "ON" : "OFF") \(model.player.isDead ? "DEAD: RESET" : model.held ? "HELD" : "ACTIVE")"
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: hud)
            if let key = buttons.keys.first(where: { buttons[$0]?.frame.insetBy(dx: -8, dy: -9).contains(p) == true }) {
                joystick.forceRelease()
                switch key {
                case "PAUSE": manualHold.toggle()
                case "RESET": model.reset(); manualHold = false; lastTime = 0
                case "LS": if !model.held && !model.player.isDead { model.longShot.toggle() }
                case "FIRE": if !model.held && !model.player.isDead { model.firing.toggle() }
                case "SPAWN": _ = model.spawnEnemy()
                case "SHOVE": model.shovePlayer(by: CGPoint(x: GameConfig.Arena8Combat.shoveDistance, y: 0))
                default: break
                }
                model.held = manualHold || !foreground; render()
            } else if !model.held && !model.player.isDead { joystick.handleTouchBegan(touch, in: self) }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { for t in touches { joystick.handleTouchMoved(t, in: self) } }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { for t in touches { joystick.handleTouchEnded(t) } }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { for t in touches { joystick.handleTouchEnded(t) } }
    @objc private func backgroundHold() { foreground = false; model.held = true; joystick.forceRelease(); lastTime = 0 }
    @objc private func foregroundReady() { foreground = true; model.held = manualHold; lastTime = 0 }
    override func willMove(from view: SKView) {
        NotificationCenter.default.removeObserver(self); joystick.forceRelease()
        model.cancel(); world.removeAllChildren(); hud.removeAllChildren(); rig.removeAllChildren(); removeAllChildren()
        buttons.removeAll(); installed = false; lastTime = 0; manualHold = false; foreground = true
    }
}
#endif
