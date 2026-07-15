// UITheme.swift
// Sparkforge
//
// The central UI style system. Before this, every node hardcoded its own
// fontSize (20+ distinct values, 6–44pt) and picked colors ad hoc — which is
// why text kept drifting too small and information kept getting greyed out.
// This is the single source of truth for typography and text color.
//
// TWO RULES, enforced here so they hold by default:
//   1. INFORMATION text never renders below `Size.infoFloor` (10pt). The
//      `label(...)` factory clamps to it — you cannot accidentally go smaller.
//   2. INFORMATION text is never greyed. Use `Color.info` / `Color.infoSoft`
//      for anything a player reads to learn something. The muted greys
//      (`Color.hint`, `Color.disabled`) are for DECORATION only — throwaway
//      hints ("tap to close"), dividers, and intentionally-concealed states
//      ("???"). Never put real information in them.

import SpriteKit

enum UITheme {

    enum Font {
        static let regular = "Menlo"
        static let bold = "Menlo-Bold"
    }

    /// Semantic sizes. `infoFloor` is the smallest any readable text may be.
    enum Size {
        static let infoFloor: CGFloat = 10
        static let display: CGFloat = 24   // page titles (SYNERGIES, PAUSED)
        static let title: CGFloat = 20
        static let heading: CGFloat = 16   // section headers
        static let body: CGFloat = 13      // primary info
        static let label: CGFloat = 12     // compact info (chips, list items)
        static let caption: CGFloat = 10   // the floor — smallest allowed info
        static let hint: CGFloat = 10      // decorative hints (non-info)
    }

    enum Color {
        // Information — always readable, NEVER greyed.
        static let info = SKColor(hex: 0xF2F2F2)
        static let infoSoft = SKColor(hex: 0xDCDCDC)   // secondary info, still clearly readable
        static let accent = SKColor(hex: 0xFFAA33)     // brand amber
        // Decoration ONLY — never carry information in these.
        static let hint = SKColor(hex: 0x8A8A8A)       // "tap to close", captions of no consequence
        static let disabled = SKColor(hex: 0x6A6A6A)   // locked "???" / unavailable
    }

    /// A label pre-styled from the presets. Clamps to the info floor so text
    /// can never be built smaller than 10pt through this path.
    static func label(_ text: String,
                      size: CGFloat = Size.body,
                      color: SKColor = Color.info,
                      bold: Bool = false) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: bold ? Font.bold : Font.regular)
        l.text = text
        l.fontSize = max(Size.infoFloor, size)
        l.fontColor = color
        l.verticalAlignmentMode = .center
        return l
    }
}
