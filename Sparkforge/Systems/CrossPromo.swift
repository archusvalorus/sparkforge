// CrossPromo.swift
// Sparkforge
//
// Forgebound Labs cross-promotion — the "hallways" between our titles
// (docs/cross-app-crosspromo-note.md). The title-screen "More from the Forge"
// plug opens a RANDOM live sibling's App Store card in-app via
// SKStoreProductViewController — discovery, never a gate (monetization canon).
//
// Roster source of truth: the Notion App Portfolio Registry. Update this list
// as titles ship or are pulled — one line per game, no other change needed.
// Reciprocity (the same plug pointing back) rolls out per app as each gets a
// pass; Sparkforge is the first hallway.

import Foundation

enum CrossPromo {

    /// One live Forgebound Labs game, for the store-card promo.
    struct Sibling {
        let name: String
        let appStoreID: Int
    }

    /// Live sibling GAMES on the App Store (excludes Sparkforge itself, the
    /// unsubmitted Idle Architect, and non-game utilities like W4D).
    static let siblings: [Sibling] = [
        Sibling(name: "Delve: Endless Dungeon", appStoreID: 6760491058),
        Sibling(name: "Alchemy Lab: Elements",  appStoreID: 6761089448),
        Sibling(name: "Signal & Noise",         appStoreID: 6760982151),
        Sibling(name: "Rune Circuit",           appStoreID: 6761017048),
    ]

    /// A random sibling to feature this visit (nil only if the roster is empty).
    static func randomSibling() -> Sibling? {
        siblings.randomElement()
    }
}
