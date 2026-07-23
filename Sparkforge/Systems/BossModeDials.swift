// BossModeDials.swift
// Sparkforge
//
// v2.0 (Unit B3) — the Boss Mode CHALLENGE DIALS.
//
// Boss Mode is a sandbox, and a sandbox that only goes one direction isn't one.
// The dials move in BOTH directions on purpose:
//   • UP    — a challenge run, for players who have already beaten the set
//   • DOWN  — a way to actually see a fight you keep dying to
//
// Turning a fight down is not a lesser mode. Sparkforge has no paywalls and no
// gates; the dials are the same philosophy applied to difficulty. What keeps
// this from warping the game is that Boss Mode's rewards are already
// sandbox-isolated (Forge XP capped per run), so a dialled-down run can't buy
// progression a normal run couldn't.
//
// Each dial is a MULTIPLIER around 1.0 (= the fight exactly as authored).
// State is session-transient, never persisted: a difficulty you set once should
// not silently govern a run you start next week.

import CoreGraphics
import Foundation

@MainActor
final class BossModeDials {

    static let shared = BossModeDials()
    private init() {}

    /// Boss durability — scales max health at spawn.
    var hp: CGFloat = 1.0
    /// Boss threat — scales damage the player takes from boss-class sources.
    var atk: CGFloat = 1.0
    /// Boss armour — a FLAT reduction per hit, matching how DEF works for the
    /// player. Deliberately not a second HP dial: flat reduction punishes
    /// many-small-hits builds and rewards big single hits, so it's a different
    /// challenge axis rather than a duplicate of the same one.
    var def: CGFloat = 1.0

    // MARK: - Range

    static let minValue: CGFloat = 0.5
    static let maxValue: CGFloat = 2.0
    static let step: CGFloat = 0.25

    /// The DEF dial's flat reduction at 1.0×, before scaling. Small on purpose:
    /// flat reduction compounds hard against fast, low-damage builds.
    static let defBaseReduction: Int = 2

    /// True when every dial sits at the authored value.
    var isDefault: Bool { hp == 1.0 && atk == 1.0 && def == 1.0 }

    /// A compact readout for the run summary — nil when nothing was changed,
    /// so an untouched run doesn't claim a modifier it never used.
    var summaryText: String? {
        guard !isDefault else { return nil }
        func fmt(_ v: CGFloat) -> String {
            let s = String(format: "%.2f", Double(v))
            return s.hasSuffix("0") ? String(s.dropLast()) : s
        }
        return "HP \(fmt(hp))×  ·  ATK \(fmt(atk))×  ·  DEF \(fmt(def))×"
    }

    /// The flat armour a boss should carry under the current DEF dial.
    var flatDamageReduction: Int {
        Int((CGFloat(Self.defBaseReduction) * def).rounded()) - Self.defBaseReduction
    }

    // MARK: - Mutation

    func adjust(_ key: Key, by delta: CGFloat) {
        let clamp: (CGFloat) -> CGFloat = { min(Self.maxValue, max(Self.minValue, $0)) }
        switch key {
        case .hp:  hp = clamp(hp + delta)
        case .atk: atk = clamp(atk + delta)
        case .def: def = clamp(def + delta)
        }
    }

    func value(_ key: Key) -> CGFloat {
        switch key {
        case .hp: return hp
        case .atk: return atk
        case .def: return def
        }
    }

    func reset() {
        hp = 1.0; atk = 1.0; def = 1.0
    }

    enum Key: String, CaseIterable {
        case hp, atk, def

        var label: String {
            switch self {
            case .hp:  return "BOSS HP"
            case .atk: return "BOSS ATK"
            case .def: return "BOSS DEF"
            }
        }

        var colorHex: UInt32 {
            switch self {
            case .hp:  return 0x66DD66
            case .atk: return 0xFF7744
            case .def: return 0x4AA3FF
            }
        }
    }
}
