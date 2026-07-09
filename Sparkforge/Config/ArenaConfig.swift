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

struct ArenaConfig {
    let id: Int
    let name: String
    let displayName: String     // Title screen section header
    let flavorLine: String      // Title screen flavor when selected
    let floorColorHex: UInt32
    let boundaryColorHex: UInt32
    let dangerGlowHex: UInt32   // Pulsing ring outside the boundary
    let detailLineHex: UInt32   // Floor motif line work

    static let crucible = ArenaConfig(
        id: 0,
        name: "The Crucible",
        displayName: "ARENA 1: THE CRUCIBLE",
        flavorLine: "survive the fire",
        floorColorHex: 0x1A1A1A,
        boundaryColorHex: 0x3A1A0A,
        dangerGlowHex: 0x441100,
        detailLineHex: 0x252525
    )

    static let quench = ArenaConfig(
        id: 1,
        name: "The Quench",
        displayName: "ARENA 2: THE QUENCH",
        flavorLine: "hold your shape after the fire leaves",
        floorColorHex: 0x11151A,
        boundaryColorHex: 0x6A6256,
        dangerGlowHex: 0x3A3A34,
        detailLineHex: 0x272C33
    )

    static let all: [ArenaConfig] = [crucible, quench]

    /// The currently selected arena, clamped to what's unlocked.
    static var current: ArenaConfig {
        let pm = ProgressionManager.shared
        let maxIndex = min(pm.arenasUnlocked, all.count) - 1
        let index = max(0, min(pm.currentArena, maxIndex))
        return all[index]
    }
}
