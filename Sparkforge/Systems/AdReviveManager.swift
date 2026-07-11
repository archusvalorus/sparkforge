// AdReviveManager.swift
// Sparkforge
//
// Manages rewarded ads for revive, reroll, and XP boost.
// Compatible with Google Mobile Ads SDK 13.x+
//
// v1.5: Added XP boost ad placement for post-run forge XP doubling.

import UIKit
import GoogleMobileAds

final class AdReviveManager: NSObject {
    
    // MARK: - Ad Unit IDs
    
    // v1.6: DEBUG builds use Google's official rewarded TEST unit so
    // playtests never touch live units — keeps revenue data clean AND
    // protects the AdMob account (watching/clicking your own live ads
    // reads as invalid traffic). Release builds use the real units.
    #if DEBUG
    static let reviveAdUnitID         = "ca-app-pub-3940256099942544/1712485313"
    static let rerollAdUnitID         = "ca-app-pub-3940256099942544/1712485313"
    static let xpBoostAdUnitID        = "ca-app-pub-3940256099942544/1712485313"
    static let extraCardAdUnitID      = "ca-app-pub-3940256099942544/1712485313"
    static let blessingChoiceAdUnitID = "ca-app-pub-3940256099942544/1712485313"
    static let extraPickAdUnitID      = "ca-app-pub-3940256099942544/1712485313"
    #else
    static let reviveAdUnitID         = "ca-app-pub-3734133983597932/3682515394"
    static let rerollAdUnitID         = "ca-app-pub-3734133983597932/9266014563"
    static let xpBoostAdUnitID        = "ca-app-pub-3734133983597932/4094068573"  // v1.6: corrected — matches AdMob console + registry
    static let extraCardAdUnitID      = "ca-app-pub-3734133983597932/8893772917"  // v1.6: level-up +1 card choice
    static let blessingChoiceAdUnitID = "ca-app-pub-3734133983597932/8585404316"  // v1.7: Daily Forge choose-your-blessing
    static let extraPickAdUnitID      = "ca-app-pub-3734133983597932/8417230383"  // v1.7: level-up +1 pick
    #endif
    
    // MARK: - State
    
    private(set) var reviveUsedThisRun: Bool = false
    private(set) var xpBoostUsedThisRun: Bool = false  // v1.5
    private var reviveAd: RewardedAd?
    private var rerollAd: RewardedAd?
    private var xpBoostAd: RewardedAd?  // v1.5
    private var extraCardAd: RewardedAd?  // v1.6
    private var blessingChoiceAd: RewardedAd?  // v1.7
    private var extraPickAd: RewardedAd?  // v1.7
    private var reviveCompletion: ((Bool) -> Void)?
    private var rerollCompletion: ((Bool) -> Void)?
    private var xpBoostCompletion: ((Bool) -> Void)?  // v1.5
    private var extraCardCompletion: ((Bool) -> Void)?  // v1.6
    private var blessingChoiceCompletion: ((Bool) -> Void)?  // v1.7
    private var extraPickCompletion: ((Bool) -> Void)?  // v1.7

    private enum ActiveAd {
        case revive
        case reroll
        case xpBoost        // v1.5
        case extraCard      // v1.6
        case blessingChoice // v1.7
        case extraPick      // v1.7
    }
    private var activeAd: ActiveAd?
    
    var adsRemoved: Bool {
        return IAPManager.shared.hasRemovedAds
    }
    
    var canRevive: Bool {
        return !reviveUsedThisRun
    }
    
    var canBoostXP: Bool {
        return !xpBoostUsedThisRun
    }
    
    // MARK: - Preload
    
    func preloadAd() {
        guard !adsRemoved else { return }
        preloadReviveAd()
        preloadRerollAd()
        preloadXPBoostAd()
        preloadExtraCardAd()
        preloadBlessingChoiceAd()
        preloadExtraPickAd()
    }
    
    private func preloadReviveAd() {
        RewardedAd.load(
            with: AdReviveManager.reviveAdUnitID,
            request: Request()
        ) { [weak self] ad, error in
            if let error = error {
                print("[AdRevive] Failed to load revive ad: \(error.localizedDescription)")
                return
            }
            self?.reviveAd = ad
            self?.reviveAd?.fullScreenContentDelegate = self
            print("[AdRevive] Revive ad loaded")
        }
    }
    
    private func preloadRerollAd() {
        RewardedAd.load(
            with: AdReviveManager.rerollAdUnitID,
            request: Request()
        ) { [weak self] ad, error in
            if let error = error {
                print("[AdRevive] Failed to load reroll ad: \(error.localizedDescription)")
                return
            }
            self?.rerollAd = ad
            self?.rerollAd?.fullScreenContentDelegate = self
            print("[AdRevive] Reroll ad loaded")
        }
    }
    
    private func preloadXPBoostAd() {
        RewardedAd.load(
            with: AdReviveManager.xpBoostAdUnitID,
            request: Request()
        ) { [weak self] ad, error in
            if let error = error {
                print("[AdRevive] Failed to load XP boost ad: \(error.localizedDescription)")
                return
            }
            self?.xpBoostAd = ad
            self?.xpBoostAd?.fullScreenContentDelegate = self
            print("[AdRevive] XP boost ad loaded")
        }
    }
    
    private func preloadExtraCardAd() {
        RewardedAd.load(
            with: AdReviveManager.extraCardAdUnitID,
            request: Request()
        ) { [weak self] ad, error in
            if let error = error {
                print("[AdRevive] Failed to load extra card ad: \(error.localizedDescription)")
                return
            }
            self?.extraCardAd = ad
            self?.extraCardAd?.fullScreenContentDelegate = self
            print("[AdRevive] Extra card ad loaded")
        }
    }

    /// Internal so TitleScene can warm just this unit without loading the run ads
    func preloadBlessingChoiceAd() {
        RewardedAd.load(
            with: AdReviveManager.blessingChoiceAdUnitID,
            request: Request()
        ) { [weak self] ad, error in
            if let error = error {
                print("[AdRevive] Failed to load blessing choice ad: \(error.localizedDescription)")
                return
            }
            self?.blessingChoiceAd = ad
            self?.blessingChoiceAd?.fullScreenContentDelegate = self
            print("[AdRevive] Blessing choice ad loaded")
        }
    }

    private func preloadExtraPickAd() {
        RewardedAd.load(
            with: AdReviveManager.extraPickAdUnitID,
            request: Request()
        ) { [weak self] ad, error in
            if let error = error {
                print("[AdRevive] Failed to load extra pick ad: \(error.localizedDescription)")
                return
            }
            self?.extraPickAd = ad
            self?.extraPickAd?.fullScreenContentDelegate = self
            print("[AdRevive] Extra pick ad loaded")
        }
    }

    // MARK: - v1.7: Extra Pick Flow

    func requestExtraPickAd(from viewController: UIViewController?, completion: @escaping (Bool) -> Void) {
        if adsRemoved {
            completion(true)
            return
        }

        guard let ad = extraPickAd, let vc = viewController else {
            print("[AdRevive] Extra pick ad not ready")
            completion(false)
            return
        }

        extraPickCompletion = completion
        activeAd = .extraPick

        ad.present(from: vc) { [weak self] in
            self?.extraPickCompletion?(true)
            self?.extraPickCompletion = nil
            self?.activeAd = nil
            self?.preloadExtraPickAd()
        }
    }

    // MARK: - v1.7: Blessing Choice Flow

    /// Remove Ads owners choose free — completion fires true immediately.
    func requestBlessingChoiceAd(from viewController: UIViewController?, completion: @escaping (Bool) -> Void) {
        if adsRemoved {
            completion(true)
            return
        }

        guard let ad = blessingChoiceAd, let vc = viewController else {
            print("[AdRevive] Blessing choice ad not ready")
            completion(false)
            return
        }

        blessingChoiceCompletion = completion
        activeAd = .blessingChoice

        ad.present(from: vc) { [weak self] in
            self?.blessingChoiceCompletion?(true)
            self?.blessingChoiceCompletion = nil
            self?.activeAd = nil
            self?.preloadBlessingChoiceAd()
        }
    }

    // MARK: - Revive Flow
    
    func requestRevive(from viewController: UIViewController?, completion: @escaping (Bool) -> Void) {
        guard canRevive else {
            completion(false)
            return
        }
        
        if adsRemoved {
            reviveUsedThisRun = true
            completion(true)
            return
        }
        
        guard let ad = reviveAd, let vc = viewController else {
            print("[AdRevive] Revive ad not ready")
            completion(false)
            return
        }
        
        reviveCompletion = completion
        activeAd = .revive
        
        ad.present(from: vc) { [weak self] in
            self?.reviveUsedThisRun = true
            self?.reviveCompletion?(true)
            self?.reviveCompletion = nil
            self?.activeAd = nil
            self?.preloadReviveAd()
        }
    }
    
    // MARK: - Reroll Flow
    
    func requestRerollAd(from viewController: UIViewController?, completion: @escaping (Bool) -> Void) {
        if adsRemoved {
            completion(true)
            return
        }
        
        guard let ad = rerollAd, let vc = viewController else {
            print("[AdRevive] Reroll ad not ready")
            completion(false)
            return
        }
        
        rerollCompletion = completion
        activeAd = .reroll
        
        ad.present(from: vc) { [weak self] in
            self?.rerollCompletion?(true)
            self?.rerollCompletion = nil
            self?.activeAd = nil
            self?.preloadRerollAd()
        }
    }
    
    // MARK: - v1.6: Extra Card Flow

    func requestExtraCardAd(from viewController: UIViewController?, completion: @escaping (Bool) -> Void) {
        if adsRemoved {
            completion(true)
            return
        }

        guard let ad = extraCardAd, let vc = viewController else {
            print("[AdRevive] Extra card ad not ready")
            completion(false)
            return
        }

        extraCardCompletion = completion
        activeAd = .extraCard

        ad.present(from: vc) { [weak self] in
            self?.extraCardCompletion?(true)
            self?.extraCardCompletion = nil
            self?.activeAd = nil
            self?.preloadExtraCardAd()
        }
    }

    // MARK: - v1.5: XP Boost Flow
    
    func requestXPBoost(from viewController: UIViewController?, completion: @escaping (Bool) -> Void) {
        guard canBoostXP else {
            completion(false)
            return
        }
        
        if adsRemoved {
            xpBoostUsedThisRun = true
            completion(true)
            return
        }
        
        guard let ad = xpBoostAd, let vc = viewController else {
            print("[AdRevive] XP boost ad not ready")
            completion(false)
            return
        }
        
        xpBoostCompletion = completion
        activeAd = .xpBoost
        
        ad.present(from: vc) { [weak self] in
            self?.xpBoostUsedThisRun = true
            self?.xpBoostCompletion?(true)
            self?.xpBoostCompletion = nil
            self?.activeAd = nil
            self?.preloadXPBoostAd()
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        reviveUsedThisRun = false
        xpBoostUsedThisRun = false
        preloadAd()
    }
}

// MARK: - FullScreenContentDelegate

@MainActor
extension AdReviveManager: FullScreenContentDelegate {
    
    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdRevive] Ad failed to present: \(error.localizedDescription)")
        
        Task { @MainActor in
            switch self.activeAd {
            case .revive:
                self.reviveCompletion?(false)
                self.reviveCompletion = nil
                self.preloadReviveAd()
            case .reroll:
                self.rerollCompletion?(false)
                self.rerollCompletion = nil
                self.preloadRerollAd()
            case .xpBoost:
                self.xpBoostCompletion?(false)
                self.xpBoostCompletion = nil
                self.preloadXPBoostAd()
            case .extraCard:
                self.extraCardCompletion?(false)
                self.extraCardCompletion = nil
                self.preloadExtraCardAd()
            case .blessingChoice:
                self.blessingChoiceCompletion?(false)
                self.blessingChoiceCompletion = nil
                self.preloadBlessingChoiceAd()
            case .extraPick:
                self.extraPickCompletion?(false)
                self.extraPickCompletion = nil
                self.preloadExtraPickAd()
            case .none:
                break
            }
            self.activeAd = nil
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            switch self.activeAd {
            case .revive:
                if let completion = self.reviveCompletion {
                    completion(false)
                    self.reviveCompletion = nil
                }
                self.preloadReviveAd()
            case .reroll:
                if let completion = self.rerollCompletion {
                    completion(false)
                    self.rerollCompletion = nil
                }
                self.preloadRerollAd()
            case .xpBoost:
                if let completion = self.xpBoostCompletion {
                    completion(false)
                    self.xpBoostCompletion = nil
                }
                self.preloadXPBoostAd()
            case .extraCard:
                if let completion = self.extraCardCompletion {
                    completion(false)
                    self.extraCardCompletion = nil
                }
                self.preloadExtraCardAd()
            case .blessingChoice:
                if let completion = self.blessingChoiceCompletion {
                    completion(false)
                    self.blessingChoiceCompletion = nil
                }
                self.preloadBlessingChoiceAd()
            case .extraPick:
                if let completion = self.extraPickCompletion {
                    completion(false)
                    self.extraPickCompletion = nil
                }
                self.preloadExtraPickAd()
            case .none:
                break
            }
            self.activeAd = nil
        }
    }
}
