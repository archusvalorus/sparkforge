// SettingsManager.swift
// Sparkforge
//
// v1.7: Player-facing settings, UserDefaults-backed.
// bgmEnabled is a placeholder toggle until BGM tracks land.

import Foundation

final class SettingsManager {

    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let sfxEnabled = "sf_sfxEnabled"
        static let bgmEnabled = "sf_bgmEnabled"
        /// v2.0 (E2). Stores a Tag rawValue; absent or empty = no ban (RANDOM).
        static let bannedFamily = "sf_bannedFamily"
    }

    private init() {
        defaults.register(defaults: [
            Keys.sfxEnabled: true,
            Keys.bgmEnabled: true
        ])
    }

    var sfxEnabled: Bool {
        get { defaults.bool(forKey: Keys.sfxEnabled) }
        set { defaults.set(newValue, forKey: Keys.sfxEnabled) }
    }

    var bgmEnabled: Bool {
        get { defaults.bool(forKey: Keys.bgmEnabled) }
        set { defaults.set(newValue, forKey: Keys.bgmEnabled) }
    }

    /// v2.0 (E2): the one colour family this player never wants offered.
    ///
    /// `nil` is RANDOM and is the DEFAULT — no ban, the roll simply decides.
    /// That matters: the loop is "tap to ignite", so opting in has to be a
    /// choice you make once in Settings, never a gate on every run.
    ///
    /// Exactly one ban, deliberately (Brandon): one lets a player dodge the
    /// tree they'll never play; two starts letting them engineer the run, and
    /// that tension is the first thing optimization kills.
    ///
    /// Stored as a rawValue rather than an index so reordering `Tag` — which
    /// will happen as trees ship — can never silently re-point a saved ban at a
    /// different tree.
    var bannedFamily: UpgradeManager.Tag? {
        get {
            guard let raw = defaults.string(forKey: Keys.bannedFamily), !raw.isEmpty,
                  let tag = UpgradeManager.Tag(rawValue: raw), tag != .neutral else { return nil }
            return tag
        }
        set { defaults.set(newValue?.rawValue ?? "", forKey: Keys.bannedFamily) }
    }
}
