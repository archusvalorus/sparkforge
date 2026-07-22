// CapstoneTimerHUD.swift
// Sparkforge
//
// v2.0 (HUD readout pass) — a reusable, camera-anchored countdown readout for
// TIMER-based capstones (Everglow's eruption, Polar Vortex, and later the
// Variegated Rainbow "SUPER!" laser).
//
// WHY: knowing the big boom lands in 4s is player AGENCY — it decides whether
// you kite and gather or dive in. Surprise is worth less than decision-making.
//
// This generalizes the approach behind Erasure's "VOID COLLAPSE" timer, but
// deliberately NOT its visual: that giant centre-screen number is a *doom*
// grammar for a run-ending event. Routine cadence gets a compact row instead,
// and MULTIPLE capstones can be active at once, so rows stack.
//
// Readout grammar across the game: gauges = STACKS (StackGaugeNode),
// timers = CADENCE (this).

import SpriteKit

final class CapstoneTimerHUD: SKNode {

    private struct Row {
        let node: SKLabelNode
        let colorHex: UInt32
        let label: String
    }

    private var rows: [String: Row] = [:]
    private var order: [String] = []          // stable display order (insertion)
    private let rowHeight: CGFloat = 19

    /// Seconds remaining below which the row flips to its urgent tint + pulses.
    private let urgentThreshold: TimeInterval = 3.0

    override init() {
        super.init()
        zPosition = 250
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Show or refresh a capstone's countdown row. Call every frame while the
    /// capstone is active; cheap (only re-renders when the displayed text changes).
    func set(_ id: String, label: String, colorHex: UInt32, remaining: TimeInterval) {
        let row: Row
        if let existing = rows[id] {
            row = existing
        } else {
            let node = SKLabelNode(fontNamed: "Menlo-Bold")
            node.fontSize = 13
            // Right-aligned: this HUD lives in the RIGHT column under the stat
            // box, deliberately OUT of the centre lane (level-up announcements
            // and upgrade cards own the middle — they collided there).
            node.horizontalAlignmentMode = .right
            node.verticalAlignmentMode = .center
            addChild(node)
            row = Row(node: node, colorHex: colorHex, label: label)
            rows[id] = row
            order.append(id)
            layout()
        }

        let secs = max(0, remaining)
        let text = "\(label)  \(String(format: "%.1f", secs))s"
        guard row.node.text != text else { return }
        row.node.text = text

        let urgent = secs <= urgentThreshold
        row.node.fontColor = SKColor(hex: colorHex, alpha: urgent ? 1.0 : 0.85)
        if urgent && row.node.action(forKey: "urgent") == nil {
            row.node.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: 1.14, duration: 0.22),
                SKAction.scale(to: 1.0, duration: 0.22)
            ])), withKey: "urgent")
        } else if !urgent {
            row.node.removeAction(forKey: "urgent")
            row.node.setScale(1.0)
        }
    }

    /// Remove a capstone's row (it deactivated / the run ended).
    func clear(_ id: String) {
        guard let row = rows.removeValue(forKey: id) else { return }
        row.node.removeFromParent()
        order.removeAll { $0 == id }
        layout()
    }

    func clearAll() {
        rows.values.forEach { $0.node.removeFromParent() }
        rows.removeAll()
        order.removeAll()
    }

    /// Stack rows downward so multiple active capstones never overlap.
    private func layout() {
        for (i, id) in order.enumerated() {
            rows[id]?.node.position = CGPoint(x: 0, y: -CGFloat(i) * rowHeight)
        }
    }
}
