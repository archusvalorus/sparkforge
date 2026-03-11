// AdReviveManager.swift
// Sparkforge
//
// Manages rewarded ads for revive and reroll.
// Compatible with Google Mobile Ads SDK 13.x+

import UIKit
import GoogleMobileAds

final class AdReviveManager: NSObject {
    
    // MARK: - Ad Unit IDs
    
    static let reviveAdUnitID = "ca-app-pub-3734133983597932/3682515394"
    static let rerollAdUnitID = "ca-app-pub-3734133983597932/9266014563"
    
    // MARK: - State
    
    private(set) var reviveUsedThisRun: Bool = false
    private var reviveAd: RewardedAd?
    private var rerollAd: RewardedAd?
    private var reviveCompletion: ((Bool) -> Void)?
    private var rerollCompletion: ((Bool) -> Void)?
    
    private enum ActiveAd {
        case revive
        case reroll
    }
    private var activeAd: ActiveAd?
    
    var adsRemoved: Bool {
        return IAPManager.shared.hasRemovedAds
    }
    
    var canRevive: Bool {
        return !reviveUsedThisRun
    }
    
    // MARK: - Preload
    
    func preloadAd() {
        guard !adsRemoved else { return }
        preloadReviveAd()
        preloadRerollAd()
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
    
    // MARK: - Reset
    
    func reset() {
        reviveUsedThisRun = false
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
            case .none:
                break
            }
            self.activeAd = nil
        }
    }
}
