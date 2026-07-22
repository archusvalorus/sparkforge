// SkinManager.swift
// Sparkforge
//
// v2.0 "The Arrival" — Unit 1: the reusable, procedural skin framework.
//
// A skin is NOT an art asset. Sparkforge is 100% procedural (SKShapeNode +
// particles + emoji), so a skin is a small PALETTE + a few procedural flags
// (`SkinAppearance`) applied over the existing layered PlayerNode. Build the
// plumbing ONCE here; every future skin (premium Spark, panda skins, the Growth
// skin) is code + config poured into this catalog — never a new asset pipeline.
//
// Skins are PURELY cosmetic — they never touch stats, hitboxes, or abilities.
// Canon: $4.99 baseline premium price (StoreKit-live), earned skins keep the
// free path whole. See docs/v2.0-kickoff.md + memory skin-system-canon.

import SpriteKit

/// How a skin is obtained.
enum SkinTier {
    case base       // the default Spark — always owned, always selectable
    case earned     // unlocked by play (e.g. Arena 5 clear) — free
    case premium    // additive IAP — StoreKit entitlement
}

/// The full procedural look of a Spark skin: a palette + procedural intensity
/// flags. Applied over PlayerNode's layered nodes (glow / ember / inner-core /
/// eyes / trail). `.base` reproduces the stock Spark exactly, so the base Spark
/// is itself "just a skin" — the framework has no special-cased default path.
struct SkinAppearance {
    let coreColorHex: UInt32        // ember body (the readable mass)
    let glowColorHex: UInt32        // soft outer aura
    let innerCoreColorHex: UInt32   // white-hot center
    let eyeColorHex: UInt32         // the two eyes
    let trailColorHex: UInt32       // ember-fleck trail
    let flareRingColorHex: UInt32   // level-up corona ring
    let glowBoost: CGFloat          // outer-glow intensity multiplier (1.0 = base)

    /// The stock Spark — pulls straight from GameConfig so base stays canonical.
    static let base = SkinAppearance(
        coreColorHex: GameConfig.Player.coreColorHex,
        glowColorHex: GameConfig.Player.glowColorHex,
        innerCoreColorHex: GameConfig.Spark.innerCoreColorHex,
        eyeColorHex: GameConfig.Spark.eyeColorHex,
        trailColorHex: 0xFF9933,
        flareRingColorHex: GameConfig.Spark.flareRingColorHex,
        glowBoost: 1.0)
}

/// One catalog entry.
struct SkinDefinition {
    let id: String
    let name: String
    let blurb: String
    let tier: SkinTier
    let appearance: SkinAppearance
    /// Non-nil only for `.premium` skins — the StoreKit product id.
    let iapProductID: String?
}

@MainActor
final class SkinManager {

    static let shared = SkinManager()

    // MARK: - Product ids (premium skins; must match ASC / the .storekit config)

    static let premiumSparkProductID = "com.brandon.Sparkforge.skin.sparkprime"

    // MARK: - Catalog (ordered; auto-registering — future skins just append)

    /// The v2.0 roster grows here. Unit 1 ships base + the earned "Ascended"
    /// Spark (locked until Arena 5) + one premium skin to exercise the IAP path.
    /// Panda skins + Growth skin append in later units — no plumbing changes.
    let catalog: [SkinDefinition] = [
        SkinDefinition(
            id: "spark_base",
            name: "Ember",
            blurb: "The spark, freshly struck.",
            tier: .base,
            appearance: .base,
            iapProductID: nil),

        SkinDefinition(
            id: "spark_ascended",
            name: "Ascended",
            blurb: "A coal that became a star. Earned by clearing Arena 5.",
            tier: .earned,
            appearance: SkinAppearance(
                coreColorHex: 0xFFE08A,        // brighter molten gold
                glowColorHex: 0xFF7A12,        // intense ember halo
                innerCoreColorHex: 0xFFFFFF,   // pure white-hot
                eyeColorHex: 0x0A0A0A,
                trailColorHex: 0xFFC24D,
                flareRingColorHex: 0xFFE6B0,
                glowBoost: 1.3),
            iapProductID: nil),

        SkinDefinition(
            id: "spark_prime",
            name: "Prime Ember",
            blurb: "A refined, jewel-cut ember. Support the forge.",
            tier: .premium,
            appearance: SkinAppearance(
                coreColorHex: 0xFF9E4D,
                glowColorHex: 0xFF4D1A,        // deep, saturated core glow
                innerCoreColorHex: 0xFFF2D8,
                eyeColorHex: 0x0A0A0A,
                trailColorHex: 0xFF7A2E,
                flareRingColorHex: 0xFFB870,
                glowBoost: 1.15),
            iapProductID: premiumSparkProductID),
    ]

    // MARK: - Persistence keys (new; never rename — live-player data)

    private let selectedKey = "sparkforge_selected_skin"
    private func unlockKey(_ id: String) -> String { "sparkforge_skin_unlocked_\(id)" }

    // MARK: - State

    private(set) var selectedID: String

    #if DEBUG
    /// Dev-only: preview/select every skin regardless of unlock (the real
    /// earned-Spark unlock is the Arena 5 clear, which doesn't exist until Unit 3).
    var debugUnlockAll = false
    #endif

    private init() {
        selectedID = UserDefaults.standard.string(forKey: selectedKey) ?? "spark_base"
    }

    // MARK: - Lookup

    func definition(_ id: String) -> SkinDefinition? {
        catalog.first { $0.id == id }
    }

    /// The appearance to render for the currently selected skin (falls back to
    /// base if the stored id ever goes missing, or the skin is no longer owned).
    var selectedAppearance: SkinAppearance {
        guard let def = definition(selectedID), isUnlocked(def) else { return .base }
        return def.appearance
    }

    // MARK: - Ownership / unlock

    func isUnlocked(_ def: SkinDefinition) -> Bool {
        #if DEBUG
        if debugUnlockAll { return true }
        #endif
        switch def.tier {
        case .base:
            return true
        case .earned:
            return UserDefaults.standard.bool(forKey: unlockKey(def.id))
        case .premium:
            guard let pid = def.iapProductID else { return false }
            return IAPManager.shared.isPurchased(pid)
        }
    }

    func isUnlocked(_ id: String) -> Bool {
        guard let def = definition(id) else { return false }
        return isUnlocked(def)
    }

    /// Flip an earned skin's unlock flag (called by the game — e.g. Arena 5 clear
    /// in Unit 3). Idempotent. Returns true if this was a NEW unlock (for reveal FX).
    @discardableResult
    func unlockEarned(_ id: String) -> Bool {
        guard let def = definition(id), def.tier == .earned else { return false }
        let key = unlockKey(id)
        if UserDefaults.standard.bool(forKey: key) { return false }
        UserDefaults.standard.set(true, forKey: key)
        return true
    }

    // MARK: - Selection

    /// Select a skin if it's owned. Returns true on success. Persists.
    @discardableResult
    func select(_ id: String) -> Bool {
        guard let def = definition(id), isUnlocked(def) else { return false }
        selectedID = id
        UserDefaults.standard.set(id, forKey: selectedKey)
        return true
    }

    // MARK: - Reset (parity with other managers' erase-progress path)

    /// Clear earned unlocks + selection back to base. (Premium entitlements are
    /// StoreKit-owned and intentionally NOT cleared — they restore.)
    func resetEarnedProgress() {
        for def in catalog where def.tier == .earned {
            UserDefaults.standard.removeObject(forKey: unlockKey(def.id))
        }
        selectedID = "spark_base"
        UserDefaults.standard.set(selectedID, forKey: selectedKey)
    }
}
