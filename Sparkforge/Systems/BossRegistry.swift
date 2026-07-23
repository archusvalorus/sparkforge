// BossRegistry.swift
// Sparkforge
//
// v2.0 (Unit B1) — the auto-registering, ARENA-AWARE boss registry behind Boss Mode.
//
// Boss Mode is not just a pool of bosses: every boss carries its arena context.
// That matters because Sparkforge has two boss grammars —
//   • ARENA bosses    — player-scale, mobile, fight fine in a standard field
//   • MONUMENT bosses — colossal set-pieces that REQUIRE their large arena
//                       (The Unmade Star needs the 2.6× Star Anvil to be legible)
//
// The Unmade Star is included from day one deliberately (Brandon: "more upfront
// work, more downstream payoff") — building the registry against the hard case
// means Arena 10/15/20's monuments slot in with no retrofit.
//
// Adding a boss = appending ONE entry. Nothing else changes.
// See the boss-mode-vision + monument-boss-class memories.

import SpriteKit

enum BossGrammar {
    case arena       // mobile, player-scale
    case monument    // anchored set-piece; needs its own arena format loaded
}

struct BossEntry {
    let id: String                 // stable key — matches ProgressionManager defeat records
    let name: String
    /// The arena this boss belongs to. Boss Mode LOADS this arena so the fight
    /// reads the way it was authored (critical for monuments).
    let arenaID: Int
    let grammar: BossGrammar
    let accentHex: UInt32
    /// Builds the boss. `arenaRadius` is passed for monuments that size
    /// themselves against the field; arena bosses simply ignore it.
    let make: (_ arenaRadius: CGFloat, _ hpScaling: Int) -> ArenaBossNode

    /// Only offer what the player has actually felled — re-fighting is a
    /// victory lap, never a preview.
    var isUnlocked: Bool { ProgressionManager.shared.hasDefeatedBoss(id) }
}

@MainActor
final class BossRegistry {

    static let shared = BossRegistry()
    private init() {}

    /// Ordered by arena. New bosses just append — monument or otherwise.
    let all: [BossEntry] = [
        BossEntry(id: "slag_titan", name: "The Slag Titan", arenaID: 0,
                  grammar: .arena, accentHex: 0xFF7722,
                  make: { _, hp in BossNode(config: BossNode.slagTitan, hpScaling: hp) }),

        BossEntry(id: "quench_warden", name: "The Quench Warden", arenaID: 1,
                  grammar: .arena, accentHex: 0xB8B0A4,
                  make: { _, hp in QuenchWardenNode(hpScaling: hp) }),

        BossEntry(id: "dynamo_choir", name: "The Dynamo Choir", arenaID: 2,
                  grammar: .arena, accentHex: 0xF6D36B,
                  make: { _, hp in DynamoChoirNode(hpScaling: hp) }),

        BossEntry(id: "faceted_lie", name: "The Faceted Lie", arenaID: 3,
                  grammar: .arena, accentHex: 0x9C948C,
                  make: { _, hp in FacetedLieNode(hpScaling: hp) }),

        // MONUMENT — instance #1. Needs the doubled Star Anvil loaded.
        BossEntry(id: "unmade_star", name: "The Unmade Star", arenaID: 4,
                  grammar: .monument, accentHex: 0xFFD98A,
                  make: { radius, hp in UnmadeStarNode(arenaRadius: radius, hpScaling: hp) }),
    ]

    // MARK: - Queries

    func entry(_ id: String) -> BossEntry? { all.first { $0.id == id } }

    /// The roster Boss Mode can actually offer.
    var unlocked: [BossEntry] { all.filter { $0.isUnlocked } }

    /// Boss Mode is only worth surfacing once there's something in it.
    var isAvailable: Bool { !unlocked.isEmpty }

    /// Sequential order = the order the player met them (by arena).
    var sequential: [BossEntry] { unlocked.sorted { $0.arenaID < $1.arenaID } }

    /// Mixup draws at random, optionally capped.
    func mixup(count: Int) -> [BossEntry] {
        let pool = unlocked
        guard !pool.isEmpty else { return [] }
        return (0..<max(1, count)).compactMap { _ in pool.randomElement() }
    }
}
