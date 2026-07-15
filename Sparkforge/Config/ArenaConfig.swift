// ArenaConfig.swift
// Sparkforge
//
// v1.6: Per-arena visual identity. Arena radius stays device-aware via
// GameConfig.Arena; everything aesthetic lives here.
// Palettes are Lyra canon — see docs/lyra-creative-pass-v1.6.md.
// Color discipline: purple = danger, blue = utility, green = health,
// ember = player/forge/progression. Arena palettes must never collide
// with pickup language.

import CoreGraphics
import Foundation

struct ArenaConfig {
    let id: Int
    let name: String
    let displayName: String     // Title screen section header
    let flavorLine: String      // Title screen flavor when selected
    let floorColorHex: UInt32
    let boundaryColorHex: UInt32
    let dangerGlowHex: UInt32   // Pulsing ring outside the boundary
    let detailLineHex: UInt32   // Floor motif line work
    let accentColorHex: UInt32  // v1.6: title-screen selector box tint/stroke
    // v1.8 (Unit 11): per-arena playfield size. 1.0 = the standard
    // device-aware radius; >1.0 expands the field. Arena is fixed for a run,
    // so GameConfig.Arena.radius folds this in for every consumer at once.
    let radiusScale: CGFloat
    // v1.8 (Unit 11): when the mini-boss/boss bell rings. Standard arenas ring
    // at GameConfig.Wave.miniBossSpawnTime; the larger Mirrorwound rings later
    // so the extra space earns a longer escalation before the bell.
    let bellTime: TimeInterval

    static let crucible = ArenaConfig(
        id: 0,
        name: "The Crucible",
        displayName: "ARENA 1: THE CRUCIBLE",
        flavorLine: "survive the fire",
        floorColorHex: 0x1A1A1A,
        boundaryColorHex: 0x3A1A0A,
        dangerGlowHex: 0x441100,
        detailLineHex: 0x252525,
        accentColorHex: 0xFF7722,
        radiusScale: 1.0,
        bellTime: GameConfig.Wave.miniBossSpawnTime
    )

    static let quench = ArenaConfig(
        id: 1,
        name: "The Quench",
        displayName: "ARENA 2: THE QUENCH",
        flavorLine: "hold your shape after the fire leaves",
        floorColorHex: 0x11151A,
        boundaryColorHex: 0x6A6256,
        dangerGlowHex: 0x3A3A34,
        detailLineHex: 0x272C33,
        accentColorHex: 0xB8B0A4,
        radiusScale: 1.0,
        bellTime: GameConfig.Wave.miniBossSpawnTime
    )

    // v1.7: palette is Lyra canon — static gold reads as pale electrical
    // static, never treasure; idle circuit lines stay very faint (floor
    // must sit below combat priority). See docs/lyra-response-v1.7.md.
    static let coilworks = ArenaConfig(
        id: 2,
        name: "The Coilworks",
        displayName: "ARENA 3: THE COILWORKS",
        flavorLine: "the engine is calculating you",
        floorColorHex: 0x121315,
        boundaryColorHex: 0x5B4A22,
        dangerGlowHex: 0x33290E,
        detailLineHex: 0x23231B,
        accentColorHex: 0xF6D36B,
        radiusScale: 1.0,
        bellTime: GameConfig.Wave.miniBossSpawnTime
    )

    // v1.8 (Unit 11): Arena 4. Palette is Lyra canon — a wound that reflects,
    // not a palace. Floor is near-black smoked glass; boundary is dull
    // tarnished mirror-silver (wounded, not chrome); motif/detail is pale
    // glass highlight for cracks and shard edges; danger glow sits in the
    // deep fracture shadow. Hostile purple (#8E44FF) is reserved for enemy
    // tells/projectiles (Units 12–13), never the environment. Expanded
    // playfield (radiusScale 1.3) — more room to run than the earlier arenas.
    // See docs/lyra-response-v1.8.md (Ask 1).
    static let mirrorwound = ArenaConfig(
        id: 3,
        name: "The Mirrorwound",
        displayName: "ARENA 4: THE MIRRORWOUND",
        flavorLine: "the arena remembers your shape incorrectly",
        floorColorHex: 0x17161A,
        boundaryColorHex: 0x9C948C,
        dangerGlowHex: 0x0B0A0D,
        detailLineHex: 0xD6CCC2,
        accentColorHex: 0x9C948C,
        radiusScale: 1.3,
        bellTime: 120.0   // larger arena → later bell, a longer escalation
    )

    static let all: [ArenaConfig] = [crucible, quench, coilworks, mirrorwound]

    /// The currently selected arena, clamped to what's unlocked.
    static var current: ArenaConfig {
        let pm = ProgressionManager.shared
        let maxIndex = min(pm.arenasUnlocked, all.count) - 1
        let index = max(0, min(pm.currentArena, maxIndex))
        return all[index]
    }
}
