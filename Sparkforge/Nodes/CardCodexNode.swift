// CardCodexNode.swift
// Sparkforge
//
// v1.9 Unit 2: the Cards codex page (deferred from v1.8 Unit 8). A browsable,
// scrollable grid of the whole card pool grouped by tree. Discovered (ever
// OFFERED) cards render name + tier depth and open a detail modal on tap;
// undiscovered cards show "???" in tree colors. Tapping a discovered card opens
// the shared CardDetailNode, which renders the card's full tier ladder — the
// "tier absorption" of this unit.
//
// Discovery persists via CodexManager.hasOfferedCard (no schema churn). Card
// TIERS are per-run, so the codex shows each card's ladder as reference (depth
// + per-rung copy), not a lifetime "tier reached" — that only exists in-run.

import SpriteKit

final class CardCodexNode: SKNode, CodexPage {

    private static let sideMargin: CGFloat = 16
    private static let chipGap: CGFloat = 8
    private static let chipsPerRow = 3

    private let content = SKNode()
    private let closeButton = SKNode()

    private let viewportTop: CGFloat
    private let viewportHeight: CGFloat
    private let contentHeight: CGFloat
    private var scrollableExtra: CGFloat { max(0, contentHeight - viewportHeight) }

    /// Card definitions (with any tier ladders) — read-only; a throwaway
    /// manager instance, never used for run state.
    private let cards: [UpgradeManager.UpgradeCard]
    /// Per-chip hit data in `content` space: card + center + size.
    private var chipFrames: [(card: UpgradeManager.UpgradeCard, center: CGPoint, size: CGSize)] = []

    private var detailNode: CardDetailNode?

    init(width: CGFloat, height: CGFloat, topInset: CGFloat, bottomInset: CGFloat) {
        let catalog = UpgradeManager().allCards
        cards = catalog

        let topSafe = height / 2 - topInset
        let headerArea: CGFloat = 72
        viewportTop = topSafe - headerArea
        let viewportBottom = -height / 2 + bottomInset + 12
        viewportHeight = viewportTop - viewportBottom

        // --- measure content ---
        let usableW = width - Self.sideMargin * 2
        let chipW = (usableW - Self.chipGap * CGFloat(Self.chipsPerRow - 1)) / CGFloat(Self.chipsPerRow)
        let chipH: CGFloat = 52
        let headerH: CGFloat = 28
        let rowGap: CGFloat = 8

        // Group cards by primary tree, preserving Tag order.
        let trees = UpgradeManager.Tag.allCases
        let grouped: [(tag: UpgradeManager.Tag, cards: [UpgradeManager.UpgradeCard])] =
            trees.compactMap { tag in
                let inTree = catalog.filter { $0.tag == tag }
                return inTree.isEmpty ? nil : (tag, inTree)
            }

        var measured: CGFloat = 8
        for group in grouped {
            let rows = Int(ceil(Double(group.cards.count) / Double(Self.chipsPerRow)))
            measured += headerH + CGFloat(rows) * (chipH + rowGap) + 6
        }
        contentHeight = measured

        super.init()
        zPosition = 500

        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = SKColor(hex: 0x0A0A0C, alpha: 0.96)
        dim.strokeColor = .clear
        addChild(dim)

        // --- Fixed header ---
        let title = UITheme.label("CARDS", size: UITheme.Size.display,
                                  color: UITheme.Color.accent, bold: true)
        title.position = CGPoint(x: 0, y: topSafe - 22)
        addChild(title)

        let sub = UITheme.label("discovered as you're offered them",
                                size: UITheme.Size.label, color: UITheme.Color.info)
        sub.position = CGPoint(x: 0, y: topSafe - 48)
        addChild(sub)

        closeButton.position = CGPoint(x: width / 2 - 30, y: topSafe - 22)
        let closeBG = SKShapeNode(circleOfRadius: 16)
        closeBG.fillColor = SKColor(hex: 0x1E1E22)
        closeBG.strokeColor = SKColor(hex: 0x555555)
        closeBG.lineWidth = 1
        closeButton.addChild(closeBG)
        let closeX = UITheme.label("✕", size: UITheme.Size.heading, color: UITheme.Color.info, bold: true)
        closeButton.addChild(closeX)
        addChild(closeButton)

        // --- Scrollable, clipped body ---
        let crop = SKCropNode()
        let mask = SKShapeNode(rectOf: CGSize(width: width, height: viewportHeight))
        mask.fillColor = .white
        mask.strokeColor = .clear
        mask.position = CGPoint(x: 0, y: viewportBottom + viewportHeight / 2)
        crop.maskNode = mask
        addChild(crop)

        content.position = CGPoint(x: 0, y: viewportTop)
        crop.addChild(content)

        // --- Build rows ---
        let left = -usableW / 2
        var y: CGFloat = -8

        for group in grouped {
            let colorHex = UpgradeCardNode.color(for: group.tag)
            let isNeutral = (group.tag == .neutral)

            let header = UITheme.label("\(UpgradeCardNode.emoji(for: group.tag))  \(group.tag.rawValue.uppercased())",
                                       size: UITheme.Size.heading,
                                       color: isNeutral ? UITheme.Color.infoSoft : SKColor(hex: colorHex),
                                       bold: true)
            header.horizontalAlignmentMode = .left
            header.verticalAlignmentMode = .top
            header.position = CGPoint(x: left, y: y)
            content.addChild(header)
            y -= headerH

            for (i, card) in group.cards.enumerated() {
                let col = i % Self.chipsPerRow
                let row = i / Self.chipsPerRow
                let cx = left + chipW / 2 + CGFloat(col) * (chipW + Self.chipGap)
                let cy = y - CGFloat(row) * (chipH + rowGap) - chipH / 2
                let discovered = CodexManager.shared.hasOfferedCard(card.id)
                let size = CGSize(width: chipW, height: chipH)
                content.addChild(Self.chip(card: card, colorHex: colorHex,
                                           discovered: discovered,
                                           center: CGPoint(x: cx, y: cy), size: size))
                if discovered {
                    chipFrames.append((card, CGPoint(x: cx, y: cy), size))
                }
            }
            let rows = Int(ceil(Double(group.cards.count) / Double(Self.chipsPerRow)))
            y -= CGFloat(rows) * (chipH + rowGap) + 6
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Card chip

    private static func chip(card: UpgradeManager.UpgradeCard, colorHex: UInt32,
                             discovered: Bool, center: CGPoint, size: CGSize) -> SKNode {
        let chip = SKNode()
        chip.position = center

        let plate = SKShapeNode(rectOf: size, cornerRadius: 7)
        plate.fillColor = discovered ? SKColor(hex: colorHex, alpha: 0.16)
                                     : SKColor(hex: 0x141414, alpha: 0.6)
        plate.strokeColor = discovered ? SKColor(hex: colorHex, alpha: 0.9)
                                       : SKColor(hex: 0x3A3A3A)
        plate.lineWidth = 1
        chip.addChild(plate)

        // v1.7 dual-tag: split accent — right sliver wears the second tree.
        if discovered, let second = card.secondaryTag {
            let half = SKShapeNode(rectOf: CGSize(width: size.width, height: 4), cornerRadius: 2)
            half.fillColor = SKColor(hex: UpgradeCardNode.color(for: second))
            half.strokeColor = .clear
            half.position = CGPoint(x: 0, y: -size.height / 2 + 4)
            chip.addChild(half)
        }

        if discovered {
            let name = UITheme.label(card.name, size: UITheme.Size.body,
                                     color: UpgradeCardNode.brightColor(hex: colorHex), bold: true)
            name.verticalAlignmentMode = .center
            name.position = CGPoint(x: 0, y: card.maxTier > 1 ? 8 : 0)
            var fs = UITheme.Size.body
            let maxW = size.width - 12
            while name.frame.width > maxW && fs > UITheme.Size.infoFloor {
                fs -= 0.5; name.fontSize = fs
            }
            chip.addChild(name)

            // Tier-depth pips for multi-tier cards (reference, not per-run).
            if card.maxTier > 1 {
                let pips = UITheme.label(String(repeating: "◈", count: card.maxTier),
                                         size: UITheme.Size.caption, color: SKColor(hex: colorHex, alpha: 0.9))
                pips.verticalAlignmentMode = .center
                pips.position = CGPoint(x: 0, y: -11)
                chip.addChild(pips)
            }
        } else {
            let locked = UITheme.label("???", size: UITheme.Size.heading,
                                       color: UITheme.Color.disabled, bold: true)
            locked.verticalAlignmentMode = .center
            locked.position = .zero
            chip.addChild(locked)
        }

        return chip
    }

    // MARK: - CodexPage

    func scroll(by dy: CGFloat) {
        guard detailNode == nil else { return }   // frozen while a detail is open
        guard scrollableExtra > 0 else { return }
        let minY = viewportTop
        let maxY = viewportTop + scrollableExtra
        content.position.y = min(maxY, max(minY, content.position.y + dy))
    }

    func hitTestClose(at location: CGPoint) -> Bool {
        // While a detail modal is open, the ✕ is covered — never close the page.
        guard detailNode == nil else { return false }
        return closeButton.calculateAccumulatedFrame().insetBy(dx: -8, dy: -8).contains(location)
    }

    /// A tap-up: open a card's detail, or close an open one. Returns true when
    /// consumed so the host skips its close handling.
    func handleTapUp(at location: CGPoint) -> Bool {
        if detailNode != nil {
            detailNode?.dismiss()
            detailNode = nil
            return true
        }
        // Convert the page-space tap into the scrolled content's space.
        let local = content.convert(location, from: self)
        for entry in chipFrames {
            let frame = CGRect(x: entry.center.x - entry.size.width / 2,
                               y: entry.center.y - entry.size.height / 2,
                               width: entry.size.width, height: entry.size.height)
            if frame.contains(local) {
                presentDetail(for: entry.card)
                return true
            }
        }
        return false
    }

    private func presentDetail(for card: UpgradeManager.UpgradeCard) {
        // Synergy tiers reflect LIFETIME discovery (persisted), matching the
        // codex's cross-run frame.
        let synTiers = UpgradeManager.synergyTiers(for: card.tag).map {
            CardDetailNode.TierLine(threshold: $0.threshold, title: $0.title, effect: $0.effect,
                                    reached: CodexManager.shared.hasSeenSynergy(tag: card.tag, tier: $0.threshold))
        }
        // Card ladder as reference — no per-run "reached" on the title screen.
        let ladder: [CardDetailNode.CardTierLine]? = card.maxTier > 1
            ? (1...card.maxTier).map {
                CardDetailNode.CardTierLine(tier: $0, effect: card.description(forTier: $0), reached: false)
              }
            : nil
        let content = CardDetailNode.Content(name: card.name, tag: card.tag,
                                             secondaryTag: card.secondaryTag,
                                             effect: card.description, tiers: synTiers,
                                             cardTierLine: nil, cardLadder: ladder)
        let detail = CardDetailNode(content: content)
        detail.present(in: self)
        detailNode = detail
        AudioManager.shared.play(.cardSelect)
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
}
