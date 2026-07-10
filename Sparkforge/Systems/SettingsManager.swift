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
}
