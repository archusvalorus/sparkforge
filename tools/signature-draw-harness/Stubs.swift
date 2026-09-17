// Stubs.swift — signature-draw proof harness (v2.1 abilities Unit 1).
// Compiles the REAL UpgradeManager.swift + PlayerStats.swift on the host.
// Values mirror GameConfig where the draw logic reads them; everything else
// is inert.

import CoreGraphics
import Foundation

enum GameConfig {
    enum Drafting {
        static let gatewayPityLevels: Int = 3
        static let activeColorFamilies: Int = 5
        static func unlockArena(for tag: UpgradeManager.Tag) -> Int {
            switch tag {
            case .growth: return 5
            case .fire, .shock, .bleed, .guardT, .voidT, .chill, .neutral: return 1
            }
        }
    }
    enum Panda {
        static let cardID = "v20_panda"
        static let eligibilityChance: CGFloat = 0.0927
        static let firstOfferWindow: ClosedRange<Int> = 2...5
        static let debugAlwaysEligible: Bool = false
    }
    enum Player {
        static let baseMaxHP: Int = 100
        static let baseAttack: Int = 10
        static let baseDefense: Int = 0
        static let collisionRadius: CGFloat = 10
        static let speed: CGFloat = 250
    }
    enum LevelUp {
        static let hpBonus: Int = 10
        static let attackBonus: Int = 5
        static let defenseBonus: Int = 3
    }
    enum Projectile {
        static let fireInterval: TimeInterval = 0.5
        static let speed: CGFloat = 400
        static let maxRange: CGFloat = 400
        static let multishotFanWidthFactor: CGFloat = 1.5
    }
    enum Growth {
        static let terraRadius: CGFloat = 110
        static let seedFragmentsT1: Int = 3
        static let seedFragmentsT2: Int = 5
        static let seedFragmentsT3: Int = 6
    }
    enum Fire {
        static let forgeBreathBonus: [CGFloat] = [0.25, 0.50, 1.00]
        static let crucibleStackCap: Int = 5
        static let crucibleStackInterval: TimeInterval = 3.0
        static let burnStackDecayInterval: TimeInterval = 2.0
        static let emberBurstDamageFraction: CGFloat = 0.25
        static let emberBurstRadius: CGFloat = 60
        static let glassEngineFireRateBonus: CGFloat = 1.00
        static let glassEngineMaxHPLoss: CGFloat = 0.50
        static let cauterizeThreshold: CGFloat = 0.25
        static let cauterizeInterval: TimeInterval = 3.0
        static let cauterizeHeal: Int = 5
    }
    enum Erasure {
        static let unstableTriggerCooldown: TimeInterval = 2.0
        static let unstableTriggerCooldownT2: TimeInterval = 1.2
    }
    enum Everglow {
        static let baseRadius: CGFloat = 70
        static let basePulseMult: CGFloat = 0.5
        static let rageGainPerHit: CGFloat = 0.01
        static let pulseGrowthCap: CGFloat = 1.0
        static let furnaceAtkGainPerHit: CGFloat = 0.005
        static let atkGrowthCap: CGFloat = 0.5
        static let eruptionMult: CGFloat = 5.0
    }
    enum ForgePath {
        static let defiantBonus: CGFloat = 0.10
    }
    enum IronMaiden {
        static let defToDmgT1: CGFloat = 0.0125
        static let defBonusT1: CGFloat = 0.05
        static let thornsT1: Int = 5
        static let defToDmgT2: CGFloat = 0.025
        static let thornsT2: Int = 17
        static let retaliateMult: CGFloat = 1.5
        static let kineticThreshold: Int = 4
        static let kineticBurstDefMult: CGFloat = 2.0
        static let defBonusT5: CGFloat = 0.15
    }
    enum PolarVortex {
        static let iceburstShardsT1: Int = 3
        static let iceburstShardsT2: Int = 5
        static let iceburstShardsT5: Int = 7
        static let windchillRadius: CGFloat = 130
        static let windchillRadiusT5Mult: CGFloat = 2.1
    }
    enum Skybeam {
        static let tickMultT1: CGFloat = 0.15
        static let tickMultT2: CGFloat = 0.30
        static let acquireRangeT1: CGFloat = 200
        static let acquireRangeT2: CGFloat = 280
    }
    enum Apex {
        static let familiarBaseFrac: CGFloat = 0.10
        static let familiarMaxFrac: CGFloat = 0.50
        static let familiarFracPerStep: CGFloat = 0.01
        static let familiarKillsPerStep: Int = 5
        static let hpToAtkFrac: CGFloat = 0.01
    }
}

final class SettingsManager {
    static let shared = SettingsManager()
    var bannedFamily: UpgradeManager.Tag? = nil
}

final class ProgressionManager {
    static let shared = ProgressionManager()
    var arenasUnlocked: Int = 1
}

final class SkinManager {
    static let shared = SkinManager()
    func revealFamily(_ id: String) {}
    func unlockEarned(_ id: String) {}
}

final class CodexManager {
    static let shared = CodexManager()
    func recordSynergySeen(tag: UpgradeManager.Tag, tier: Int) {}
}

enum ReviewMode {
    static var isActive = false
}

enum UpgradeCardNode {
    static func emoji(for tag: UpgradeManager.Tag) -> String { "•" }
}
