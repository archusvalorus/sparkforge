// SnowmanState.swift
// Sparkforge
//
// v2.1 Abilities A2 (Chill): one enemy's Whiteout transformation — pure, on
// game time, proven by tools/chill-harness. EnemyNode owns one and wears the
// costume.
//
// Q-C3: once per enemy per cooldown; bosses never (they aren't EnemyNodes);
// boss-class (elites / mini-bosses) at the BossClass debuff scale.
// CL-7 (Brandon, Sep 17): at Whiteout T3, damage MELTS a snowman. The form is
// consumed BEFORE any melt damage, so it can never trigger twice. Normals
// die; an elite takes the triggering hit and THEN an additional fraction of
// its max HP — and may die to either.

import CoreGraphics
import Foundation

struct SnowmanState {

    enum Melt: Equatable {
        /// Not a melting snowman — handle the damage normally.
        case none
        /// A normal enemy: it dies.
        case dies
        /// An elite: apply the hit, then this much extra damage.
        case elite(extraDamage: Int)
    }

    private(set) var form = GameTimer()
    private(set) var cooldown = GameTimer()
    private(set) var meltsOnDamage = false

    var isSnowman: Bool { form.isActive }

    /// Try to transform. Returns the duration actually applied, or nil if this
    /// enemy is already a snowman or transformed too recently.
    mutating func begin(duration: TimeInterval, cooldown cd: TimeInterval, meltsOnDamage: Bool,
                        isBossClass: Bool, bossClassScale: CGFloat) -> TimeInterval? {
        guard duration > 0, !isSnowman, !cooldown.isActive else { return nil }
        let applied = isBossClass ? duration * TimeInterval(bossClassScale) : duration
        form.start(applied)
        cooldown.start(cd)
        self.meltsOnDamage = meltsOnDamage
        return applied
    }

    /// Advance game time. Returns true on the tick the form wears off by itself.
    mutating func tick(_ dt: TimeInterval) -> Bool {
        cooldown.tick(dt)
        guard form.tick(dt) else { return false }
        meltsOnDamage = false
        return true
    }

    /// Damage arrived. If this melts the snowman the form is consumed HERE,
    /// before the caller applies anything — a second call returns `.none`.
    mutating func onDamage(_ amount: Int, isBossClass: Bool, maxHealth: Int, eliteFraction: CGFloat) -> Melt {
        guard isSnowman, meltsOnDamage, amount > 0 else { return .none }
        form.cancel()
        meltsOnDamage = false
        guard isBossClass else { return .dies }
        return .elite(extraDamage: max(1, Int(CGFloat(maxHealth) * eliteFraction)))
    }
}
