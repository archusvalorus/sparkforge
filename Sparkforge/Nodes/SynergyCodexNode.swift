// SynergyCodexNode.swift
// Sparkforge
//
// v1.8 Unit 7 (A2): the Synergies codex page. A browsable 7×3 grid of every
// synergy tier — six flavored trees plus a "Neutral · Unaligned" row so the
// grid reads complete (visual 21, mechanical 18). Discovered tiers reveal
// title + effect; undiscovered show only tree + tier ("???", concealed).
//
// v1.8 rework (Brandon): styled entirely from UITheme (≥10pt info, never
// greyed), a fixed header with a ✕ close button (upper-right), and a scrollable
// body — drag up/down to see the whole grid. Taps are for scrolling; only the
// ✕ closes. GameScene forwards touch began/moved/ended while it's open.

import SpriteKit

/// A full-screen scrollable codex page (Synergies / Bestiary / …). The pause
/// menu drives whichever one is open through this interface.
protocol CodexPage: SKNode {
    func scroll(by dy: CGFloat)
    func hitTestClose(at location: CGPoint) -> Bool
    func dismiss()
    /// v1.9 Unit 2: a tap-up (not a drag) at `location` in this page's space.
    /// Returns true if the page consumed it (e.g. opened/closed a card detail)
    /// so the host skips its own close handling. Default: false (no-op).
    func handleTapUp(at location: CGPoint) -> Bool
}

extension CodexPage {
    func handleTapUp(at location: CGPoint) -> Bool { false }
}

final class SynergyCodexNode: SKNode, CodexPage {

    private static let sideMargin: CGFloat = 16
    private static let chipGap: CGFloat = 8

    private let content = SKNode()   // the scrollable rows
    private let closeButton = SKNode()

    private let viewportTop: CGFloat
    private let viewportHeight: CGFloat
    private let contentHeight: CGFloat
    private var scrollableExtra: CGFloat { max(0, contentHeight - viewportHeight) }

    init(width: CGFloat, height: CGFloat, topInset: CGFloat, bottomInset: CGFloat) {
        // Everything hangs below the top safe area so the title clears the
        // notch / Dynamic Island.
        let topSafe = height / 2 - topInset
        let headerArea: CGFloat = 72   // title + subtitle block
        viewportTop = topSafe - headerArea
        let viewportBottom = -height / 2 + bottomInset + 12
        viewportHeight = viewportTop - viewportBottom

        // --- measure content (built below) ---
        let usableW = width - Self.sideMargin * 2
        let chipW = (usableW - Self.chipGap * 2) / 3
        let chipH: CGFloat = 98        // tall enough to contain 3-line effects
        let headerH: CGFloat = 30      // gap between a tree name and its chips
        let rowGap: CGFloat = 14
        let rowH = headerH + chipH + rowGap
        let trees = UpgradeManager.Tag.allCases
        contentHeight = CGFloat(trees.count) * rowH + 8

        super.init()
        zPosition = 500

        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x0A0A0C, alpha: 0.96)
        dim.strokeColor = .clear
        addChild(dim)

        // --- Fixed header ---
        let title = UITheme.label("SYNERGIES", size: UITheme.Size.display,
                                  color: UITheme.Color.accent, bold: true)
        title.position = CGPoint(x: 0, y: topSafe - 22)
        addChild(title)

        let sub = UITheme.label("discovered as you earn them",
                                size: UITheme.Size.label, color: UITheme.Color.info)  // 12pt, white
        sub.position = CGPoint(x: 0, y: topSafe - 48)
        addChild(sub)

        // ✕ close button — fixed, upper-right, generous hit area.
        closeButton.position = CGPoint(x: width / 2 - 30, y: topSafe - 22)
        let closeBG = SKShapeNode(circleOfRadius: 16)
        closeBG.fillColor = SKColor(hex: 0x1E1E22)
        closeBG.strokeColor = SKColor(hex: 0x555555)
        closeBG.lineWidth = 1
        closeButton.addChild(closeBG)
        let closeX = UITheme.label("✕", size: UITheme.Size.heading, color: UITheme.Color.info, bold: true)
        closeButton.addChild(closeX)
        addChild(closeButton)

        // --- Scrollable body, clipped to the viewport ---
        let crop = SKCropNode()
        let mask = SKShapeNode(rectOf: CGSize(width: width, height: viewportHeight))
        mask.fillColor = .white
        mask.strokeColor = .clear
        mask.position = CGPoint(x: 0, y: viewportBottom + viewportHeight / 2)
        crop.maskNode = mask
        addChild(crop)

        content.position = CGPoint(x: 0, y: viewportTop)  // content y=0 at viewport top
        crop.addChild(content)

        // --- Build the rows into `content` (top-down from y=0) ---
        let left = -usableW / 2
        var y: CGFloat = -8

        for tag in trees {
            let colorHex = UpgradeCardNode.color(for: tag)
            let isNeutral = (tag == .neutral)

            let header = UITheme.label("\(UpgradeCardNode.emoji(for: tag))  \(tag.rawValue.uppercased())",
                                       size: UITheme.Size.heading,
                                       color: isNeutral ? UITheme.Color.infoSoft
                                                        : SKColor(hex: colorHex),  // raw tree color — more pop
                                       bold: true)
            header.horizontalAlignmentMode = .left
            header.verticalAlignmentMode = .top
            header.position = CGPoint(x: left, y: y)
            content.addChild(header)

            let tiers = UpgradeManager.synergyTiers(for: tag)
            let cy = y - headerH - chipH / 2
            if tiers.isEmpty {
                let band = SKShapeNode(rectOf: CGSize(width: usableW, height: chipH), cornerRadius: 8)
                band.fillColor = SKColor(hex: 0x141414, alpha: 0.5)
                band.strokeColor = SKColor(hex: 0x3A3A3A)
                band.lineWidth = 1
                band.position = CGPoint(x: 0, y: cy)
                content.addChild(band)

                let note = UITheme.label("Unaligned — no synergy",
                                         size: UITheme.Size.body, color: UITheme.Color.infoSoft)
                note.position = CGPoint(x: 0, y: cy)
                content.addChild(note)
            } else {
                for (i, tier) in tiers.enumerated() {
                    let cx = left + chipW / 2 + CGFloat(i) * (chipW + Self.chipGap)
                    let discovered = CodexManager.shared.hasSeenSynergy(tag: tag, tier: tier.threshold)
                    content.addChild(Self.chip(tier: tier, colorHex: colorHex, discovered: discovered,
                                               center: CGPoint(x: cx, y: cy),
                                               size: CGSize(width: chipW, height: chipH)))
                }
            }
            y -= rowH
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Tier chip

    private static func chip(tier: UpgradeManager.SynergyTier, colorHex: UInt32,
                             discovered: Bool, center: CGPoint, size: CGSize) -> SKNode {
        let chip = SKNode()
        chip.position = center

        let plate = SKShapeNode(rectOf: size, cornerRadius: 8)
        plate.fillColor = discovered ? SKColor(hex: colorHex, alpha: 0.16)
                                     : SKColor(hex: 0x141414, alpha: 0.6)
        plate.strokeColor = discovered ? SKColor(hex: colorHex, alpha: 0.9)
                                       : SKColor(hex: 0x3A3A3A)
        plate.lineWidth = 1
        chip.addChild(plate)

        // Tier badge — top-left; tree+tier stays visible even when locked.
        let badge = UITheme.label("\(tier.threshold)", size: UITheme.Size.caption,
                                  color: discovered ? SKColor(hex: colorHex) : UITheme.Color.disabled,
                                  bold: true)
        badge.horizontalAlignmentMode = .left
        badge.position = CGPoint(x: -size.width / 2 + 9, y: size.height / 2 - 13)
        chip.addChild(badge)

        if discovered {
            // Title sits well below the tier number so they don't crowd.
            let title = UITheme.label(tier.title, size: UITheme.Size.body,
                                      color: UpgradeCardNode.brightColor(hex: colorHex), bold: true)
            title.position = CGPoint(x: 0, y: size.height / 2 - 34)
            // auto-shrink to fit width, but never below the info floor
            var fs = UITheme.Size.body
            let maxW = size.width - 14
            while title.frame.width > maxW && fs > UITheme.Size.infoFloor {
                fs -= 0.5; title.fontSize = fs
            }
            chip.addChild(title)

            let lines = Self.wrap(tier.effect, maxChars: Int(size.width / 6.2)).prefix(3)
            for (li, line) in lines.enumerated() {
                let l = UITheme.label(line, size: UITheme.Size.caption, color: UITheme.Color.info)
                l.position = CGPoint(x: 0, y: size.height / 2 - 54 - CGFloat(li) * 13)
                chip.addChild(l)
            }
        } else {
            let locked = UITheme.label("???", size: UITheme.Size.heading, color: UITheme.Color.disabled, bold: true)
            locked.position = .zero
            chip.addChild(locked)
        }

        return chip
    }

    // MARK: - Scroll + close (driven by GameScene via the pause menu)

    /// `dy` is the finger's vertical delta in this node's space (up = positive).
    func scroll(by dy: CGFloat) {
        guard scrollableExtra > 0 else { return }
        let minY = viewportTop
        let maxY = viewportTop + scrollableExtra
        content.position.y = min(maxY, max(minY, content.position.y + dy))
    }

    /// True if `location` (in this node's space) hit the ✕ button.
    func hitTestClose(at location: CGPoint) -> Bool {
        return closeButton.calculateAccumulatedFrame().insetBy(dx: -8, dy: -8).contains(location)
    }

    // MARK: - Presentation

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
