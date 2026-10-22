// AdReviveManager.swift
// Sparkforge
//
// Manages rewarded ads for revive, reroll, and XP boost.
// Compatible with Google Mobile Ads SDK 13.x+
//
// v1.5: Added XP boost ad placement for post-run forge XP doubling.

import UIKit
import GoogleMobileAds

@MainActor
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
        guard !GameRunPreferences.isIsolated else { return }
        guard !adsRemoved else { return }
        preloadReviveAd()
        preloadRerollAd()
        preloadXPBoostAd()
        preloadExtraCardAd()
        preloadBlessingChoiceAd()
        preloadExtraPickAd()
    }
    
    // A cache belongs to the consent generation that requested it. A changed
    // consent/ATT state invalidates both completed and still-in-flight loads.
    private var cacheGeneration = -1
    private var loading: [String: UUID] = [:]

    private func synchronizePrivacy() {
        _ = AdConsentCoordinator.shared.ready
        let current = AdConsentCoordinator.shared.generation
        guard cacheGeneration != current else { return }
        cacheGeneration = current
        loading.removeAll()
        reviveAd = nil
        rerollAd = nil
        xpBoostAd = nil
        extraCardAd = nil
        blessingChoiceAd = nil
        extraPickAd = nil
    }

    private func load(_ placement: String, unitID: String,
                      store: @escaping (AdReviveManager, RewardedAd) -> Void) {
        guard !GameRunPreferences.isIsolated else { return }
        guard !adsRemoved else { return }
        #if DEBUG
        guard !AdConsentPlatform.shared.systemATTTest else { return } // OS-permission proof never loads ads
        #endif
        AdConsentCoordinator.shared.whenReady(owner: self, placement: placement) { [weak self] generation in
            guard let self, !self.adsRemoved else { return }
            self.synchronizePrivacy()
            guard AdConsentCoordinator.shared.isCurrent(generation), self.loading[placement] == nil else { return }
            let token = UUID()
            self.loading[placement] = token
            RewardedAd.load(with: unitID, request: Request()) { [weak self] ad, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.synchronizePrivacy()
                    guard self.loading[placement] == token else { return }
                    self.loading[placement] = nil
                    guard !self.adsRemoved, AdConsentCoordinator.shared.isCurrent(generation), let ad else {
                        if let error { print("[AdRevive] \(placement) unavailable: \(error.localizedDescription)") }
                        return
                    }
                    ad.fullScreenContentDelegate = self
                    store(self, ad)
                }
            }
        }
    }

    private func mayPresent() -> Bool {
        synchronizePrivacy()
        return activeAd == nil && AdConsentCoordinator.shared.canPresentAd(generation: cacheGeneration)
    }

    private func preloadReviveAd() {
        load("revive", unitID: Self.reviveAdUnitID) { owner, ad in owner.reviveAd = ad }
    }

    private func preloadRerollAd() {
        load("reroll", unitID: Self.rerollAdUnitID) { owner, ad in owner.rerollAd = ad }
    }

    private func preloadXPBoostAd() {
        load("xpBoost", unitID: Self.xpBoostAdUnitID) { owner, ad in owner.xpBoostAd = ad }
    }

    private func preloadExtraCardAd() {
        load("extraCard", unitID: Self.extraCardAdUnitID) { owner, ad in owner.extraCardAd = ad }
    }

    func preloadBlessingChoiceAd() {
        load("blessingChoice", unitID: Self.blessingChoiceAdUnitID) { owner, ad in owner.blessingChoiceAd = ad }
    }

    private func preloadExtraPickAd() {
        load("extraPick", unitID: Self.extraPickAdUnitID) { owner, ad in owner.extraPickAd = ad }
    }

    // MARK: - v1.7: Extra Pick Flow

    func requestExtraPickAd(from viewController: UIViewController?, completion: @escaping (Bool) -> Void) {
        guard !GameRunPreferences.isIsolated else { completion(false); return }
        if adsRemoved {
            completion(true)
            return
        }

        guard mayPresent(), let ad = extraPickAd, let vc = viewController,
              vc.viewIfLoaded?.window != nil, vc.presentedViewController == nil else {
            preloadExtraPickAd()
            print("[AdRevive] Extra pick ad not ready")
            completion(false)
            return
        }

        extraPickAd = nil
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
        guard !GameRunPreferences.isIsolated else { completion(false); return }
        if adsRemoved {
            completion(true)
            return
        }

        guard mayPresent(), let ad = blessingChoiceAd, let vc = viewController,
              vc.viewIfLoaded?.window != nil, vc.presentedViewController == nil else {
            preloadBlessingChoiceAd()
            print("[AdRevive] Blessing choice ad not ready")
            completion(false)
            return
        }

        blessingChoiceAd = nil
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
        guard !GameRunPreferences.isIsolated else { completion(false); return }
        guard canRevive else {
            completion(false)
            return
        }
        
        if adsRemoved {
            reviveUsedThisRun = true
            completion(true)
            return
        }
        
        guard mayPresent(), let ad = reviveAd, let vc = viewController,
              vc.viewIfLoaded?.window != nil, vc.presentedViewController == nil else {
            preloadReviveAd()
            print("[AdRevive] Revive ad not ready")
            completion(false)
            return
        }
        
        reviveAd = nil
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
        guard !GameRunPreferences.isIsolated else { completion(false); return }
        if adsRemoved {
            completion(true)
            return
        }
        
        guard mayPresent(), let ad = rerollAd, let vc = viewController,
              vc.viewIfLoaded?.window != nil, vc.presentedViewController == nil else {
            preloadRerollAd()
            print("[AdRevive] Reroll ad not ready")
            completion(false)
            return
        }
        
        rerollAd = nil
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
        guard !GameRunPreferences.isIsolated else { completion(false); return }
        if adsRemoved {
            completion(true)
            return
        }

        guard mayPresent(), let ad = extraCardAd, let vc = viewController,
              vc.viewIfLoaded?.window != nil, vc.presentedViewController == nil else {
            preloadExtraCardAd()
            print("[AdRevive] Extra card ad not ready")
            completion(false)
            return
        }

        extraCardAd = nil
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
        guard !GameRunPreferences.isIsolated else { completion(false); return }
        guard canBoostXP else {
            completion(false)
            return
        }
        
        if adsRemoved {
            xpBoostUsedThisRun = true
            completion(true)
            return
        }
        
        guard mayPresent(), let ad = xpBoostAd, let vc = viewController,
              vc.viewIfLoaded?.window != nil, vc.presentedViewController == nil else {
            preloadXPBoostAd()
            print("[AdRevive] XP boost ad not ready")
            completion(false)
            return
        }
        
        xpBoostAd = nil
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
            AdConsentCoordinator.shared.presenterBecameReady()
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
            AdConsentCoordinator.shared.presenterBecameReady()
        }
    }
}
