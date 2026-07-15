// BestiaryCodexNode.swift
// Sparkforge
//
// v1.8 Unit 9 (A4): the Bestiary codex page. A scrollable list of every enemy
// family + boss (BestiaryFamily), read from CodexManager: encountered families
// reveal name + kill count + Lyra flavor in the family color; unencountered show
// "???" / "Unrecorded hostile signature." Bosses get a 👑 marker + thicker
// stroke. The reserved Mote slot (hiddenUntilFutureVersion) is skipped entirely
// — the empty chair is intentional until v2.0.
//
// Styled from UITheme; fixed header + ✕ close; notch/safe-area aware. Same
// CodexPage interface as the Synergies page, so the pause menu drives it the
// same way (drag scrolls, ✕ closes).

import SpriteKit

final class BestiaryCodexNode: SKNode, CodexPage {

    private static let sideMargin: CGFloat = 16

    private let content = SKNode()
    private let closeButton = SKNode()

    private let viewportTop: CGFloat
    private let viewportHeight: CGFloat
    private let contentHeight: CGFloat
    private var scrollableExtra: CGFloat { max(0, contentHeight - viewportHeight) }

    init(width: CGFloat, height: CGFloat, topInset: CGFloat, bottomInset: CGFloat) {
        let topSafe = height / 2 - topInset
        let headerArea: CGFloat = 72
        viewportTop = topSafe - headerArea
        let viewportBottom = -height / 2 + bottomInset + 12
        viewportHeight = viewportTop - viewportBottom

        let usableW = width - Self.sideMargin * 2
        let rowH: CGFloat = 84
        let rowGap: CGFloat = 10
        // Only the families that render in this version (Mote is hidden).
        let families = BestiaryFamily.allCases.filter { !$0.hiddenUntilFutureVersion }
        contentHeight = CGFloat(families.count) * (rowH + rowGap) + 8

        super.init()
        zPosition = 500

        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x0A0A0C, alpha: 0.96)
        dim.strokeColor = .clear
        addChild(dim)

        // --- Fixed header ---
        let title = UITheme.label("BESTIARY", size: UITheme.Size.display,
                                  color: UITheme.Color.accent, bold: true)
        title.position = CGPoint(x: 0, y: topSafe - 22)
        addChild(title)

        let sub = UITheme.label("the forge keeps receipts",
                                size: UITheme.Size.label, color: UITheme.Color.info)
        sub.position = CGPoint(x: 0, y: topSafe - 48)
        addChild(sub)

        closeButton.position = CGPoint(x: width / 2 - 30, y: topSafe - 22)
        let closeBG = SKShapeNode(circleOfRadius: 16)
        closeBG.fillColor = SKColor(hex: 0x1E1E22)
        closeBG.strokeColor = SKColor(hex: 0x555555)
        closeBG.lineWidth = 1
        closeButton.addChild(closeBG)
        closeButton.addChild(UITheme.label("✕", size: UITheme.Size.heading,
                                           color: UITheme.Color.info, bold: true))
        addChild(closeButton)

        // --- Scrollable body ---
        let crop = SKCropNode()
        let mask = SKShapeNode(rectOf: CGSize(width: width, height: viewportHeight))
        mask.fillColor = .white
        mask.strokeColor = .clear
        mask.position = CGPoint(x: 0, y: viewportBottom + viewportHeight / 2)
        crop.maskNode = mask
        addChild(crop)

        content.position = CGPoint(x: 0, y: viewportTop)
        crop.addChild(content)

        var y: CGFloat = -8
        for family in families {
            let discovered = CodexManager.shared.hasEncountered(family)
            let kills = CodexManager.shared.kills(of: family)
            content.addChild(Self.row(family: family, discovered: discovered, kills: kills,
                                      width: usableW,
                                      center: CGPoint(x: 0, y: y - rowH / 2),
                                      height: rowH))
            y -= rowH + rowGap
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Family row

    private static func row(family: BestiaryFamily, discovered: Bool, kills: Int,
                            width: CGFloat, center: CGPoint, height: CGFloat) -> SKNode {
        let row = SKNode()
        row.position = center
        let colorHex = family.colorHex

        let plate = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 8)
        plate.fillColor = discovered ? SKColor(hex: colorHex, alpha: 0.12)
                                     : SKColor(hex: 0x141414, alpha: 0.55)
        plate.strokeColor = discovered ? SKColor(hex: colorHex, alpha: 0.9)
                                       : SKColor(hex: 0x3A3A3A)
        plate.lineWidth = (discovered && family.isBoss) ? 2.5 : 1  // bosses: thicker stroke
        row.addChild(plate)

        let portraitX = -width / 2 + 34
        let textLeft = -width / 2 + 66
        let right = width / 2 - 14

        if discovered {
            // Live code-drawn portrait of the actual enemy.
            if let portrait = portrait(for: family) {
                portrait.position = CGPoint(x: portraitX, y: 0)
                row.addChild(portrait)
            }

            let name = UITheme.label(family.isBoss ? "👑 \(family.displayName)" : family.displayName,
                                     size: UITheme.Size.body,
                                     color: UpgradeCardNode.brightColor(hex: colorHex), bold: true)
            name.horizontalAlignmentMode = .left
            name.verticalAlignmentMode = .top
            name.position = CGPoint(x: textLeft, y: height / 2 - 12)
            row.addChild(name)

            // Kill count, right-aligned on the name row.
            let count = UITheme.label(kills == 1 ? "1 slain" : "\(kills) slain",
                                      size: UITheme.Size.caption, color: UITheme.Color.infoSoft)
            count.horizontalAlignmentMode = .right
            count.verticalAlignmentMode = .top
            count.position = CGPoint(x: right, y: height / 2 - 13)
            row.addChild(count)

            // Flavor (white info), wrapped in the text column.
            let textW = width - 66 - 16
            for (li, line) in Self.wrap(family.flavor, maxChars: Int(textW / 6.6)).prefix(3).enumerated() {
                let l = UITheme.label(line, size: UITheme.Size.caption, color: UITheme.Color.info)
                l.horizontalAlignmentMode = .left
                l.verticalAlignmentMode = .top
                l.position = CGPoint(x: textLeft, y: height / 2 - 36 - CGFloat(li) * 14)
                row.addChild(l)
            }
        } else {
            // Concealed placeholder in the portrait slot.
            let disc = SKShapeNode(circleOfRadius: 15)
            disc.fillColor = SKColor(hex: 0x161616)
            disc.strokeColor = SKColor(hex: 0x3A3A3A)
            disc.lineWidth = 1
            disc.position = CGPoint(x: portraitX, y: 0)
            row.addChild(disc)
            let q = UITheme.label("?", size: UITheme.Size.heading, color: UITheme.Color.disabled, bold: true)
            q.position = CGPoint(x: portraitX, y: 0)
            row.addChild(q)

            let name = UITheme.label("???", size: UITheme.Size.body,
                                     color: UITheme.Color.disabled, bold: true)
            name.horizontalAlignmentMode = .left
            name.position = CGPoint(x: textLeft, y: 12)
            row.addChild(name)

            let note = UITheme.label("Unrecorded hostile signature.",
                                     size: UITheme.Size.caption, color: UITheme.Color.hint)
            note.horizontalAlignmentMode = .left
            note.position = CGPoint(x: textLeft, y: -12)
            row.addChild(note)
        }

        return row
    }

    // MARK: - Enemy portraits (code-drawn — Sparkforge has no sprite assets)

    /// A small live portrait built from the family's ACTUAL enemy node —
    /// physics stripped, scaled to fit, recentered. Idle animations (eye pulse,
    /// halo bob, wing flutter) keep playing, so the portraits feel alive.
    private static func portrait(for family: BestiaryFamily) -> SKNode? {
        let node: SKNode
        switch family {
        case .melee:        node = EnemyNode()
        case .ranged:       node = RangedEnemyNode()
        case .ashling:      node = AshlingNode(elapsed: 30, isShard: false)
        case .braceguard:   node = BraceguardNode(elapsed: 30)
        case .relayImp:     node = RelayImpNode(elapsed: 30)
        case .grounder:     node = GrounderNode(elapsed: 30)
        case .staticHalo:   node = StaticHaloNode(elapsed: 30)
        case .circuitWasp:  node = CircuitWaspNode(elapsed: 30)
        case .shardTwin:    node = ShardTwinNode(elapsed: 30)
        case .paneStalker:  node = PaneStalkerNode(elapsed: 30)
        case .echoLeech:    node = EchoLeechNode(elapsed: 30)
        case .miniBoss:     let e = EnemyNode(); e.isMiniBoss = true; node = e
        case .slagTitan:    node = BossNode(config: BossNode.slagTitan)
        case .quenchWarden: node = QuenchWardenNode()
        case .dynamoChoir:  node = DynamoChoirNode()
        case .facetedLie:   node = FacetedLieNode()
        case .mote:         return nil
        }
        stripPhysics(node)

        let frame = node.calculateAccumulatedFrame()
        let dim = max(frame.width, frame.height, 1)
        let scale = min(1.2, 42 / dim)
        node.setScale(scale)

        // Recenter the (possibly off-origin) content within a container.
        let container = SKNode()
        node.position = CGPoint(x: -frame.midX * scale, y: -frame.midY * scale)
        container.addChild(node)
        return container
    }

    private static func stripPhysics(_ node: SKNode) {
        node.physicsBody = nil
        node.children.forEach { stripPhysics($0) }
    }

    // MARK: - CodexPage

    func scroll(by dy: CGFloat) {
        guard scrollableExtra > 0 else { return }
        let minY = viewportTop
        let maxY = viewportTop + scrollableExtra
        content.position.y = min(maxY, max(minY, content.position.y + dy))
    }

    func hitTestClose(at location: CGPoint) -> Bool {
        return closeButton.calculateAccumulatedFrame().insetBy(dx: -8, dy: -8).contains(location)
    }

    func present(in parent: SKNode) {
        parent.addChild(self)
        alpha = 0
        run(SKAction.fadeIn(withDuration: 0.15))
    }

    func dismiss() {
        run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.12),
            SKAction.removeFromParent()
        ]))
    }

    private static func wrap(_ text: String, maxChars: Int) -> [String] {
        let cap = max(6, maxChars)
        let words = text.split(separator: " ")
        var lines: [String] = []
        var current = ""
        for word in words {
            if current.isEmpty { current = String(word) }
            else if current.count + 1 + word.count <= cap { current += " " + word }
            else { lines.append(current); current = String(word) }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }
}
