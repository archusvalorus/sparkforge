// DEBUG fixture only; no live arena registry, combat, saves or rewards.
#if DEBUG
import SpriteKit
import UIKit

final class Arena8P0Scene: SKScene {
    private typealias C = GameConfig.Arena8Prototype
    private var model = Arena8P0Model()
    private let world = SKNode()
    private let rig = SKCameraNode()
    private let hud = SKNode()
    private let joystick = VirtualJoystick()
    private let spark = SKShapeNode(circleOfRadius: C.playerRadius)
    private var bodies: [SKShapeNode] = []
    private var labels: [SKLabelNode] = []
    private var buttons: [String: SKLabelNode] = [:]
    private let probe = SKShapeNode()
    private let status = SKLabelNode(fontNamed: "Menlo")
    private let footer = SKLabelNode(fontNamed: "Menlo")
    private var lastUpdate: TimeInterval = 0
    private var manualPause = false
    private var foreground = true
    private var installed = false

    override func didMove(to view: SKView) {
        guard !installed else { return }; installed = true
        backgroundColor = SKColor(hex: 0x111522)
        camera = rig; addChild(world); addChild(rig)
        world.setScale(min(1, size.width / (C.world.width + 60)))
        rig.addChild(hud); hud.zPosition = 200
        rig.addChild(joystick); joystick.zPosition = 300
        for rect in [CGRect(x: -420, y: -240, width: 320, height: 480), CGRect(x: -100, y: -60, width: 200, height: 120), CGRect(x: 100, y: -240, width: 320, height: 480)] {
            let floor = SKShapeNode(rect: rect)
            floor.fillColor = SKColor(hex: 0x253A48); floor.strokeColor = .clear
            world.addChild(floor)
        }
        let outer = SKShapeNode(rect: C.world); outer.strokeColor = SKColor(hex: 0xB7C7DB); outer.lineWidth = 3
        world.addChild(outer)
        for f in model.geometry.blockedFootprints {
            let wall = SKShapeNode(rectOf: CGSize(width: f.halfExtents.width * 2, height: f.halfExtents.height * 2))
            wall.position = f.center; wall.fillColor = SKColor(hex: 0x131823); wall.strokeColor = SKColor(hex: 0x8DA0BB); wall.lineWidth = 3
            world.addChild(wall)
        }
        for node in model.geometry.routeNodes {
            let dot = SKShapeNode(circleOfRadius: 4); dot.position = node.position
            dot.fillColor = SKColor(hex: 0x6DB7C6); dot.strokeColor = .clear
            world.addChild(dot)
        }
        spark.fillColor = SKColor(hex: 0xFFE09A); spark.strokeColor = .white; spark.zPosition = 20; world.addChild(spark)
        for radius in C.enemyRadii {
            let body = SKShapeNode(circleOfRadius: radius); body.fillColor = SKColor(hex: 0xF27B83, alpha: 0.55); body.strokeColor = .white; body.lineWidth = 2; body.zPosition = 15
            world.addChild(body); bodies.append(body)
            let label = SKLabelNode(fontNamed: "Menlo-Bold"); label.fontSize = 15; label.zPosition = 30; label.text = "r\(Int(radius))"
            world.addChild(label); labels.append(label)
        }
        probe.lineWidth = 3; probe.zPosition = 10; world.addChild(probe)
        let top = size.height / 2 - view.safeAreaInsets.top
        func text(_ value: String, y: CGFloat, size: CGFloat) -> SKLabelNode {
            let label = SKLabelNode(fontNamed: "Menlo-Bold"); label.text = value; label.fontSize = size; label.position = CGPoint(x: 0, y: y); hud.addChild(label); return label
        }
        _ = text("ARENA 8 / P0 LAB", y: top - 28, size: 17)
        _ = text("Two rooms / open corridor / fixtures", y: top - 50, size: 10)
        for (i, name) in ["PAUSE", "RESET", "LS", "SHOVE"].enumerated() {
            let button = text(name, y: top - 85, size: 12); button.position.x = (CGFloat(i) - 1.5) * size.width / 4
            button.fontColor = SKColor(hex: 0xAFC6FF); buttons[name] = button
        }
        _ = text("Left joystick moves Spark", y: top - 113, size: 11)
        status.fontSize = 10; status.position = CGPoint(x: 0, y: top - 142); hud.addChild(status)
        footer.fontSize = 10; footer.position = CGPoint(x: 0, y: -size.height / 2 + view.safeAreaInsets.bottom + 28); hud.addChild(footer)
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundHold), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(foregroundReady), name: UIApplication.didBecomeActiveNotification, object: nil)
        render()
    }

    override func update(_ time: TimeInterval) {
        let dt = lastUpdate == 0 ? 0 : time - lastUpdate; lastUpdate = time
        model.held = manualPause || !foreground
        model.step(dt, direction: joystick.direction)
        render()
    }

    private func render() {
        spark.position = model.player
        for i in bodies.indices {
            bodies[i].position = model.enemies[i]
            labels[i].position = model.enemies[i] + CGPoint(x: 0, y: C.enemyRadii[i] + 8)
        }
        if let from = model.lastShotFrom, let end = model.lastShotEnd {
            let path = CGMutablePath(); path.move(to: from); path.addLine(to: end); probe.path = path
            probe.strokeColor = SKColor(hex: model.lastShotClear ? 0x61E5A5 : 0xFF7878)
        } else { probe.path = nil }
        status.text = "\(model.held ? "HELD" : "ACTIVE") / LS \(model.longShot ? "ON" : "OFF") / probe \(model.shotCount) \(model.lastShotClear ? "CLEAR" : "BLOCKED")"
        footer.text = "No combat / actor overlap allowed / Debug only"
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: hud)
            if let key = buttons.keys.first(where: { buttons[$0]?.frame.insetBy(dx: -10, dy: -12).contains(p) == true }) {
                joystick.forceRelease()
                switch key {
                case "PAUSE": manualPause.toggle()
                case "RESET": model = Arena8P0Model(); manualPause = false; lastUpdate = 0
                case "LS": model.longShot.toggle()
                case "SHOVE":
                    if !model.held, let moved = model.shove(from: model.player, toward: model.player + CGPoint(x: 600, y: 0), radius: C.playerRadius) { model.player = moved }
                default: break
                }
                model.held = manualPause || !foreground; render()
            } else { joystick.handleTouchBegan(touch, in: self) }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { for touch in touches { joystick.handleTouchMoved(touch, in: self) } }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { for touch in touches { joystick.handleTouchEnded(touch) } }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { for touch in touches { joystick.handleTouchEnded(touch) } }
    @objc private func backgroundHold() { foreground = false; model.held = true; joystick.forceRelease(); lastUpdate = 0 }
    @objc private func foregroundReady() { foreground = true; model.held = manualPause; lastUpdate = 0 }
    override func willMove(from view: SKView) {
        NotificationCenter.default.removeObserver(self); joystick.forceRelease()
        world.removeAllChildren(); hud.removeAllChildren(); rig.removeAllChildren(); removeAllChildren()
        bodies.removeAll(); labels.removeAll(); buttons.removeAll(); model = Arena8P0Model(); manualPause = false; foreground = true; installed = false; lastUpdate = 0
    }
}
#endif
