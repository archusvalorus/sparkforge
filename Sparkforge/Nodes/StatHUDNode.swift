// StatHUDNode.swift
// Sparkforge
//
// v1.9 Unit 5: the playfield stat HUD — a compact right-side readout of live
// combat modifiers so players see where their build stands and make informed
// level-up choices. Right-aligned, below the pause button; sits above the
// level-up/stat-choice dim so it stays legible while choosing.
//
// Rows are a simple extensible list (Brandon: "a running list of combat
// modifiers") — add a Row and set it in update(from:) to grow the readout.

import SpriteKit

final class StatHUDNode: SKNode {

    /// One readout line: a tinted short label + its value.
    private final class Row: SKNode {
        private let valueLabel: SKLabelNode
        init(label: String, colorHex: UInt32) {
            valueLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            super.init()
            let name = SKLabelNode(fontNamed: "Menlo-Bold")
            name.text = label
            name.fontSize = 10
            name.fontColor = SKColor(hex: colorHex)
            name.horizontalAlignmentMode = .left
            name.verticalAlignmentMode = .center
            name.position = CGPoint(x: -Self.width, y: 0)
            addChild(name)

            valueLabel.fontSize = 11
            valueLabel.fontColor = SKColor(hex: 0xFFFFFF)
            valueLabel.horizontalAlignmentMode = .right
            valueLabel.verticalAlignmentMode = .center
            valueLabel.position = .zero
            addChild(valueLabel)
        }
        @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
        func set(_ value: String) { valueLabel.text = value }
        static let width: CGFloat = 108   // fits "MV SPD" + "1.2x +20%"
    }

    private static let rowHeight: CGFloat = 17

    // HP is intentionally omitted — it's the HP bar at the top of the HUD.
    private let atkRow, defRow, atkSpdRow, mvSpdRow: Row

    override init() {
        atkRow   = Row(label: "ATK",     colorHex: 0xFF8833)
        defRow   = Row(label: "DEF",     colorHex: 0x4C90D0)
        atkSpdRow = Row(label: "ATK SPD", colorHex: 0xF2D24B)
        mvSpdRow  = Row(label: "MV SPD",  colorHex: 0x6FCF6F)
        super.init()

        let rows = [atkRow, defRow, atkSpdRow, mvSpdRow]

        // Background plate sized to the rows, for legibility over the arena.
        let padX: CGFloat = 8, padY: CGFloat = 7
        let plateW = Row.width + padX * 2
        let plateH = CGFloat(rows.count) * Self.rowHeight + padY * 2
        let plate = SKShapeNode(rectOf: CGSize(width: plateW, height: plateH), cornerRadius: 7)
        plate.fillColor = SKColor(hex: 0x0C0C0E, alpha: 0.55)
        plate.strokeColor = SKColor(hex: 0x333333, alpha: 0.6)
        plate.lineWidth = 1
        // Rows span y = 0 … −(count−1)·rowHeight; center the plate on that span.
        plate.position = CGPoint(x: -Row.width / 2,
                                 y: -CGFloat(rows.count - 1) * Self.rowHeight / 2)
        addChild(plate)

        var y: CGFloat = 0
        for row in rows {
            row.position = CGPoint(x: 0, y: y)
            addChild(row)
            y -= Self.rowHeight
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Refresh from live stats. Cheap — safe to call every frame.
    func update(from stats: PlayerStats) {
        // Effective per-shot attack: (base + HP-fed ATK) × the build multiplier,
        // including DEF→damage conversions (Unbroken Core, Iron Skin) so a
        // shield/DEF build sees its ATK climb as DEF is stacked.
        atkRow.set("\(stats.displayAttack)")
        defRow.set("\(stats.defense)")
        // Shots per second from the effective interval.
        let shotsPerSec = stats.effectiveFireInterval > 0 ? 1.0 / stats.effectiveFireInterval : 0
        atkSpdRow.set(String(format: "%.1f/s", shotsPerSec))
        // Move speed as multiplier AND % total over base (Brandon: show both).
        let mvPct = (stats.moveSpeedMultiplier - 1.0) * 100
        mvSpdRow.set(String(format: "%.1fx %+.0f%%", stats.moveSpeedMultiplier, mvPct))
    }
}
