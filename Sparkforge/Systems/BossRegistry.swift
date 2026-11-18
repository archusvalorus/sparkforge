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

/// Stable room encounter identity shared by campaign and Boss Mode.
enum RoomBossID: String {
    case lockmarshal = "lockmarshal"

    var isEnabled: Bool {
        if !GameRunPreferences.isIsolated { return ArenaConfig.current.id == ArenaConfig.lockworks.id }
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        // The existing isolated natural stream earns this registered room boss.
        // Combined natural/duel flags remain rejected by both route contracts.
        if Arena8NaturalWaveMode.enabled(arguments: args,
            sixRoom: args.contains("--arena8-six"), isolated: GameRunPreferences.isIsolated,
            arena9: args.contains("--arena9-traversal")) { return true }
        return GameRunPreferences.isIsolated && args.contains("--arena8-six")
            && args.contains("--arena8-lockmarshal") && !args.contains("--arena9-traversal")
            && args.filter { $0.hasPrefix("--arena8-") }.allSatisfy {
                ["--arena8-six", "--arena8-title", "--arena8-lockmarshal", "--arena8-lockmarshal-checks",
                 "--arena8-title-input", "--arena8-title-autoplay", "--arena8-six-input"].contains($0)
            }
        #else
        return false
        #endif
    }
}

/// The actual scene supplies its map and spawn; no global/default home fallback.
struct RoomBossEntry {
    let id: RoomBossID
    let map: Arena8GameMap

    func make(at root: CGPoint) -> LockmarshalNode? {
        guard id.isEnabled, map.isSixRoom, map.rooms.count == 6,
              map.valid(root, radius: GameConfig.LockmarshalFixture.bodyRadius) else { return nil }
        return LockmarshalNode(map: map, at: root)
    }
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

        // v2.1 geometry Unit 4: Arena 6. A mobile arena boss that reads the
        // Splitworks' Carrier, gates and routes — Boss Mode loads its home arena
        // (geometry included) like every boss, so the fight is the authored one.
        BossEntry(id: "marchwarden", name: "The Marchwarden", arenaID: 5,
                  grammar: .arena, accentHex: 0x3F8F8A,
                  make: { _, hp in MarchwardenNode(hpScaling: hp) }),
        BossEntry(id: "switchwarden", name: "The Switchwarden", arenaID: 6,
                  grammar: .arena, accentHex: 0xB6AC98,
                  make: { _, hp in
                      let boss = SwitchwardenNode()
                      boss.applyHealthBonus(hp)
                      return boss
                  }),
        BossEntry(id: "lockmarshal", name: "Lockmarshal", arenaID: 7,
                  grammar: .arena, accentHex: 0xD4C49B,
                  make: { _, hp in
                      let map = Arena8GameMap.sixRoom
                      let boss = LockmarshalNode(map: map, at: map.rooms[5].center)
                      boss.applyHealthBonus(hp)
                      return boss
                  }),
    ]

    /// Map-aware room factory; the actual scene retains run/actor ownership.
    func roomEntry(_ id: RoomBossID, map: Arena8GameMap) -> RoomBossEntry? {
        guard id.isEnabled, map.isSixRoom, map.rooms.count == 6 else { return nil }
        return RoomBossEntry(id: id, map: map)
    }

    // MARK: - Queries

    func entry(_ id: String) -> BossEntry? { all.first { $0.id == id } }

    /// The boss an arena answers with, if one is authored yet.
    func entry(forArena arenaID: Int) -> BossEntry? { all.first { $0.arenaID == arenaID } }

    /// How an arena PACES: taken from its boss's grammar rather than from the
    /// arena itself (Brandon, "build once and reuse forever").
    ///
    /// A monument is a chunky anchored set-piece, so the run wants more levels
    /// banked before it lands; a mobile arena boss doesn't. Keying pacing to the
    /// grammar means a new arena inherits the right feel the moment its boss is
    /// registered — no second per-arena table to keep in sync with this one.
    /// Arenas with no authored boss fall back to arena pacing.
    func grammar(forArena arenaID: Int) -> BossGrammar {
        entry(forArena: arenaID)?.grammar ?? .arena
    }

    /// The roster Boss Mode can actually offer.
    var unlocked: [BossEntry] {
        #if DEBUG
        // Dev-only: examine any fight without first earning it on this save.
        if GameConfig.BossMode.debugForceFullRoster { return all }
        #endif
        return all.filter { $0.isUnlocked }
    }

    /// Boss Mode is only worth surfacing once there's something in it.
    var isAvailable: Bool { !unlocked.isEmpty }

    /// Sequential order = the order the player met them (by arena).
    var sequential: [BossEntry] { unlocked.sorted { $0.arenaID < $1.arenaID } }

    /// Mixup draws at random, capped at `count`.
    ///
    /// v2.0 (B2b): draws WITHOUT replacement. The B1 version used
    /// `randomElement()` per slot, which could hand you the same boss twice in
    /// one gauntlet while omitting another entirely — that reads as a bug at
    /// the moment it happens, and it quietly changes run length. Mixup is meant
    /// to be "the same set, a different order", so it shuffles and takes.
    func mixup(count: Int) -> [BossEntry] {
        let pool = unlocked.shuffled()
        guard !pool.isEmpty else { return [] }
        return Array(pool.prefix(max(1, min(count, pool.count))))
    }
}
