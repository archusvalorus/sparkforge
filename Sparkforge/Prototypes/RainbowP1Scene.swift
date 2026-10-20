// Isolated DEBUG review lab. No live card, game combat, progression or saves.
#if DEBUG
import SpriteKit
import UIKit

final class RainbowP1Scene: SKScene {
    private typealias C = GameConfig.RainbowPrototype
    private var model = RainbowP1Model()
    private var attacker = RainbowP1Model.Attacker()
    private var geometry = ArenaGeometry.open
    private let board = CGRect(x: -900, y: -900, width: 1800, height: 1800)
    private var targets: [RainbowP1Model.Target] = []
    private var targetHomes: [CGPoint] = []
    private var targetNodes: [SKShapeNode] = []
    private var targetLabels: [SKLabelNode] = []
    private var walls: [SKShapeNode] = []
    private let world = SKNode()
    private let rig = SKCameraNode()
    private let hud = SKNode()
    private let timerHUD = CapstoneTimerHUD()
    private let joystick = VirtualJoystick()
    private let spark = SKShapeNode(circleOfRadius: C.playerRadius)
    private let leadingLine = SKShapeNode()
    private let warningGuide = SKShapeNode()
    private let superText = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var bands: [SKShapeNode] = []
    private let stateLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let resultLabel = SKLabelNode(fontNamed: "Menlo")
    private var buttons: [String: SKLabelNode] = [:]
    private var lastUpdate: TimeInterval = 0
    private var activeTime: TimeInterval = 0
    private var cameraPan: CGFloat = 0
    private var installed = false
    private var hitCount = 0
    private var killCount = 0
    private var chainRoots = 0

    override func didMove(to view: SKView) {
        guard !installed else { return }
        installed = true
        backgroundColor = SKColor(hex: 0x10121E)
        camera = rig
        hud.zPosition = 200
        addChild(world)
        addChild(rig)
        rig.addChild(hud)
        rig.addChild(joystick)
        joystick.zPosition = 300
        buildFixture()
        buildPresentation()
        buildHUD()
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundHold), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundHold), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(foregroundReady), name: UIApplication.didBecomeActiveNotification, object: nil)
        resetFixture(newRun: true)
        model.select()
        render()
    }

    private func buildFixture() {
        // Two test wall pieces with an open gap; not an authored arena.
        let wallX: CGFloat = 0
        let wallY = min(size.height * 0.16, 110)
        geometry = ArenaGeometry(blockedFootprints: [
            Footprint(center: CGPoint(x: wallX, y: wallY), halfExtents: CGSize(width: 8, height: wallY - 28), cornerRadius: 0, label: "P1_upper"),
            Footprint(center: CGPoint(x: wallX, y: -wallY), halfExtents: CGSize(width: 8, height: wallY - 28), cornerRadius: 0, label: "P1_lower")
        ])
        for footprint in geometry.blockedFootprints {
            let node = SKShapeNode(rectOf: CGSize(width: footprint.halfExtents.width * 2, height: footprint.halfExtents.height * 2))
            node.position = footprint.center
            node.fillColor = SKColor(hex: 0x454C60)
            node.strokeColor = SKColor(hex: 0x8891A5)
            node.zPosition = 10
            world.addChild(node)
            walls.append(node)
        }
        let x = min(size.width * 0.30, 125)
        targetHomes = [CGPoint(x: -x, y: 90), CGPoint(x: x, y: 120),
                       CGPoint(x: x, y: -115), CGPoint(x: -x, y: -155),
                       CGPoint(x: -x, y: 0), CGPoint(x: x, y: 0),
                       CGPoint(x: 55, y: -200)]
        let fieldScale = min(1, max(0.5, (size.height / 2 - (view?.safeAreaInsets.top ?? 0) - 210) / 150))
        targetHomes = targetHomes.map { CGPoint(x: $0.x, y: $0.y * fieldScale) }
        for i in targetHomes.indices {
            let node = SKShapeNode(circleOfRadius: i == 6 ? C.targetRadius * 2 : C.targetRadius)
            node.zPosition = 20
            world.addChild(node)
            targetNodes.append(node)
            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.fontSize = 10
            label.zPosition = 40
            world.addChild(label)
            targetLabels.append(label)
        }
        spark.fillColor = SKColor(hex: 0xFFE9B2)
        spark.strokeColor = SKColor(hex: 0xFF9922)
        spark.glowWidth = 5
        spark.zPosition = 35
        world.addChild(spark)
    }

    private func buildPresentation() {
        let colors: [UInt32] = [0xFF244C, 0xFF861C, 0xFFD21C, 0x31DC63, 0x19C9F0, 0x4356ED, 0xA837EE]
        for color in colors {
            let band = SKShapeNode()
            band.fillColor = SKColor(hex: color, alpha: 0.66)
            band.strokeColor = .clear
            band.zPosition = 15
            world.addChild(band)
            bands.append(band)
        }
        leadingLine.strokeColor = .white
        leadingLine.lineWidth = 2
        leadingLine.glowWidth = 3
        leadingLine.zPosition = 30
        world.addChild(leadingLine)
        warningGuide.strokeColor = SKColor(hex: 0xFFE99B, alpha: 0.6)
        warningGuide.fillColor = SKColor(hex: 0xA837EE, alpha: 0.08)
        warningGuide.lineWidth = 2
        warningGuide.zPosition = 12
        world.addChild(warningGuide)
        superText.text = "SUPER!"
        superText.fontSize = min(46, size.width * 0.13)
        superText.fontColor = .white
        superText.verticalAlignmentMode = .center
        superText.zPosition = 45
        world.addChild(superText)
    }

    private func buildHUD() {
        let top = size.height / 2 - (view?.safeAreaInsets.top ?? 0)
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "RAINBOW  /  P1 LAB"
        title.fontSize = 17
        title.position = CGPoint(x: 0, y: top - 24)
        hud.addChild(title)
        let hint = SKLabelNode(fontNamed: "AvenirNext-Regular")
        hint.text = "Aim with Spark · white line deals the hit"
        hint.fontSize = 11
        hint.position = CGPoint(x: 0, y: top - 44)
        hud.addChild(hint)
        let names = ["SELECT", "PAUSE", "LEVEL", "LONG SHOT", "BOARD", "RESET", "PAN", "END"]
        for (i, name) in names.enumerated() {
            let node = SKLabelNode(fontNamed: "Menlo-Bold")
            node.name = name
            node.text = name
            node.fontSize = 11
            node.fontColor = SKColor(hex: 0xAFC6FF)
            node.position = CGPoint(x: (CGFloat(i % 4) - 1.5) * size.width / 4,
                                    y: top - 77 - CGFloat(i / 4) * 34)
            hud.addChild(node)
            buttons[name] = node
        }
        stateLabel.fontSize = 10
        stateLabel.position = CGPoint(x: 0, y: top - 142)
        hud.addChild(stateLabel)
        timerHUD.position = CGPoint(x: size.width / 2 - 16, y: top - 168)
        hud.addChild(timerHUD)
        resultLabel.fontSize = 10
        resultLabel.position = CGPoint(x: 0, y: -size.height / 2 + (view?.safeAreaInsets.bottom ?? 0) + 24)
        hud.addChild(resultLabel)
    }

    private var viewport: CGRect {
        CGRect(x: rig.position.x - size.width / 2, y: rig.position.y - size.height / 2,
               width: size.width, height: size.height)
    }
    private func resetFixture(newRun: Bool) {
        if newRun { model.newRun() } else { model.boardHandoff() }
        targets = targetHomes.enumerated().map { i, p in
            var target = RainbowP1Model.Target(id: i, previous: p, position: p)
            target.health = i == 6 ? 280 : 70
            target.arenaBoss = i == 6
            target.radius = i == 6 ? C.targetRadius * 2 : C.targetRadius
            target.snowman = i == 3
            return target
        }
        for i in targets.indices {
            targetLabels[i].text = targets[i].arenaBoss ? "BOSS FIXTURE 280" : "70"
        }
        hitCount = 0; killCount = 0; chainRoots = 0
        activeTime = 0
        cameraPan = 0
        rig.position = .zero
        spark.position = CGPoint(x: -min(size.width * 0.3, 125), y: -65)
        joystick.forceRelease()
        lastUpdate = 0
    }

    override func update(_ currentTime: TimeInterval) {
        let raw = lastUpdate == 0 ? 0 : currentTime - lastUpdate
        lastUpdate = currentTime
        let dt = model.activeStep(raw)
        let oldViewport = viewport, oldOrigin = spark.position
        if dt > 0 {
            activeTime += dt
            let proposed = spark.position + joystick.direction * (C.playerSpeed * CGFloat(dt))
            let visible = viewport.intersection(board).insetBy(dx: C.playerRadius, dy: C.playerRadius)
            let clamped = CGPoint(x: min(visible.maxX, max(visible.minX, proposed.x)),
                                  y: min(visible.maxY, max(visible.minY, proposed.y)))
            spark.position = geometry.resolve(clamped, actorRadius: C.playerRadius)
            for i in targets.indices {
                targets[i].previous = targets[i].position
                if i == 4 { targets[i].position.x = CGFloat(sin(activeTime * 1.3)) * min(size.width * 0.36, 145) }
                if i == 5 { targets[i].position.y = CGFloat(sin(activeTime * 1.7)) * 20 }
            }
        }
        let frame = model.advance(raw, fromViewport: oldViewport, toViewport: viewport,
                                  fromOrigin: oldOrigin, toOrigin: spark.position, board: board,
                                  attacker: attacker, targets: targets, geometry: geometry)
        for contact in frame.contacts {
            guard let i = targets.firstIndex(where: { $0.id == contact.targetID }) else { continue }
            targets[i].health = max(0, targets[i].health - contact.entry.dealt)
            if contact.meltsSnowman { targets[i].snowman = false }
            hitCount += 1
            if contact.killed { killCount += 1 }
            if contact.emitsChainRoot { chainRoots += 1 }
            targetLabels[i].text = "\(contact.crit ? "CRIT " : "")−\(contact.hit.dealt) / \(targets[i].health)"
        }
        render()
    }

    private func render() {
        if model.owned {
            timerHUD.set("rainbow-p1", label: "SUPER!", colorHex: 0xFFE88E,
                         remaining: model.remaining, pulses: model.holds.isEmpty)
        } else { timerHUD.clear("rainbow-p1") }
        stateLabel.text = !model.owned ? "NOT SELECTED · SELECT starts the 20s clock" :
            (model.holds.isEmpty ? "ACTIVE · fixture damage 10 → 35" : "HELD · countdown and contact frozen")
        buttons["LONG SHOT"]?.text = attacker.longShotT4 ? "LS NEXT: ON" : "LS NEXT: OFF"
        buttons["LONG SHOT"]?.fontColor = attacker.longShotT4 ? SKColor(hex: 0xFFE88E) : SKColor(hex: 0xAFC6FF)
        buttons["PAUSE"]?.fontColor = model.holds.contains(.pause) ? SKColor(hex: 0xFFE88E) : SKColor(hex: 0xAFC6FF)
        buttons["LEVEL"]?.fontColor = model.holds.contains(.levelUp) ? SKColor(hex: 0xFFE88E) : SKColor(hex: 0xAFC6FF)
        resultLabel.text = "HITS \(hitCount)   KILLS \(killCount)   CHAIN ROOTS \(chainRoots)"
        for i in targets.indices {
            let target = targets[i]
            targetNodes[i].position = target.position
            targetNodes[i].alpha = target.health > 0 ? 1 : 0.15
            let captured = model.sweep
            let blocked = !(captured?.attacker.longShotT4 ?? attacker.longShotT4)
                && geometry.segmentBlockedExact(captured?.origin ?? spark.position, target.position)
            targetNodes[i].fillColor = target.snowman ? SKColor(hex: 0xB7F4FF) : SKColor(hex: blocked ? 0x555D74 : 0xE47B8A)
            targetNodes[i].strokeColor = .white
            targetLabels[i].position = target.position + CGPoint(x: 0, y: target.radius + 7)
            if targetLabels[i].text == nil { targetLabels[i].text = target.arenaBoss ? "BOSS FIXTURE 280" : "70" }
        }
        warningGuide.isHidden = !model.warning
        if model.warning {
            let proposed = RainbowP1Model.laneFootprint(viewport: viewport, origin: spark.position, board: board)
            warningGuide.path = proposed.isNull || proposed.isEmpty ? nil : CGPath(rect: proposed, transform: nil)
            warningGuide.alpha = model.holds.isEmpty ? 0.5 + CGFloat(sin(model.elapsed * 12)) * 0.2 : 0.5
        }
        guard let sweep = model.sweep else {
            leadingLine.isHidden = true
            superText.isHidden = true
            for band in bands { band.isHidden = true }
            return
        }
        leadingLine.isHidden = false
        superText.isHidden = false
        let path = CGMutablePath()
        path.move(to: CGPoint(x: sweep.frontX, y: sweep.footprint.minY))
        path.addLine(to: CGPoint(x: sweep.frontX, y: sweep.footprint.maxY))
        leadingLine.path = path
        let width = min(C.trailLength, max(0, sweep.frontX - sweep.footprint.minX))
        for (i, band) in bands.enumerated() {
            band.isHidden = false
            band.path = CGPath(rect: CGRect(x: sweep.frontX - width,
                                            y: sweep.footprint.minY + CGFloat(i) * sweep.footprint.height / CGFloat(bands.count),
                                            width: width, height: sweep.footprint.height / CGFloat(bands.count)), transform: nil)
        }
        superText.position = CGPoint(x: sweep.frontX - min(C.trailLength / 2, width / 2), y: sweep.footprint.midY)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: hud)
            if let name = buttons.keys.first(where: { key in
                guard let button = buttons[key] else { return false }
                return button.frame.insetBy(dx: -9, dy: -10).contains(point)
            }) {
                joystick.forceRelease()
                switch name {
                case "SELECT": model.select()
                case "PAUSE": model.setHold(.pause, !model.holds.contains(.pause))
                case "LEVEL": model.setHold(.levelUp, !model.holds.contains(.levelUp))
                case "LONG SHOT": attacker.longShotT4.toggle()
                case "BOARD": resetFixture(newRun: false)
                case "RESET": resetFixture(newRun: true)
                case "PAN": cameraPan = cameraPan == 0 ? 70 : 0; rig.position.x = cameraPan
                case "END": model.endRun()
                default: break
                }
                render()
            } else if model.holds.isEmpty && model.owned { joystick.handleTouchBegan(touch, in: self) }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { joystick.handleTouchMoved(touch, in: self) }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { joystick.handleTouchEnded(touch) }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { joystick.handleTouchEnded(touch) }
    }
    @objc private func backgroundHold() {
        model.setHold(.background, true)
        joystick.forceRelease()
        lastUpdate = 0
        render()
    }
    @objc private func foregroundReady() {
        model.setHold(.background, false)
        lastUpdate = 0
        render()
    }
    override func willMove(from view: SKView) {
        NotificationCenter.default.removeObserver(self)
        joystick.forceRelease()
        model.endRun()
        timerHUD.clearAll()
        removeAllActions()
        world.removeAllChildren()
        hud.removeAllChildren()
        rig.removeAllChildren()
        removeAllChildren()
        targets.removeAll()
        targetHomes.removeAll()
        targetNodes.removeAll()
        targetLabels.removeAll()
        walls.removeAll()
        bands.removeAll()
        buttons.removeAll()
        installed = false
    }
}
#endif
