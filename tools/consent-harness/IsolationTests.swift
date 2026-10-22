import Foundation
@main struct IsolationTests {
    @MainActor static func main() async {
        var checks = 0
        func check(_ value: @autoclosure () -> Bool, _ label: String) { checks += 1; precondition(value(), label) }
        check(GameRunPreferences.isIsolated, "run with a real room-preview argument")
        // Registration is memory-only. The standard profile contains an owner
        // sentinel while the preview must see its own empty preference backend.
        UserDefaults.standard.register(defaults: ["sparkforge_ads_removed": true, "sparkforge_owned_products": ["owner-profile-sentinel"]])
        let standardBefore = UserDefaults.standard.dictionaryRepresentation() as NSDictionary
        let owner = ProcessInfo.processInfo.arguments.contains("--isolation-cached-owner")
        if owner { GameRunPreferences.shared.set(true, forKey: "sparkforge_ads_removed") }
        let memoryBefore = GameRunPreferences.shared.dictionaryRepresentation() as NSDictionary
        let iap = IAPManager.shared
        check(iap.hasRemovedAds == owner && iap.adEntitlementStatus == (owner ? .owner : .unknown), "preview entitlement comes only from memory")
        check(!iap.isPurchased("owner-profile-sentinel"), "preview does not inherit purchases")
        iap.ensureAdEntitlementResolved()
        let purchased = await iap.purchaseRemoveAds()
        check(!purchased, "no remove-ads purchase")
        let skinPurchased = await iap.purchase("skin-sentinel")
        check(!skinPurchased, "no skin purchase")
        let skinPrice = await iap.displayPrice(for: "skin-sentinel")
        check(skinPrice == nil, "no skin-price StoreKit fetch")
        let product = await iap.getRemoveAdsProduct()
        check(product == nil, "no remove-ads product fetch")
        let price = await iap.removeAdsDisplayPrice()
        check(price == nil, "no remove-ads price fetch")
        await iap.restorePurchases()
        let platform = AdConsentPlatform.shared
        let visiblePresenter = UIViewController()
        platform.presenter = visiblePresenter
        platform.prepareEntitlement()
        check(!platform.isActive && !platform.canPresent && !platform.canRequestAds && !platform.privacyOptionsRequired, "isolated platform closed")
        check(platform.trackingStatus == .notDetermined, "no ATT read")
        var completions = 0
        platform.updateConsent { check(!$0, "update refused"); completions += 1 }
        platform.presentRequiredConsent { check(!$0, "form refused"); completions += 1 }
        platform.requestTracking { completions += 1 }
        platform.startAds { completions += 1 }
        platform.presentPrivacyOptions { completions += 1 }
        check(completions == 5, "no stalled completion paths")
        let lifecycleBefore = AdConsentCoordinator.shared.diagnostic
        let app = AppLifecycle(); let scene = SceneLifecycle(); let presenter = PresenterLifecycle()
        app.applicationDidBecomeActive(UIApplication.shared); presenter.viewDidAppear(true)
        scene.sceneDidBecomeActive(UIScene()); app.applicationWillResignActive(UIApplication.shared); scene.sceneWillResignActive(UIScene())
        check(platform.presenter === visiblePresenter, "isolated view appearance does not replace presenter")
        check(AdConsentCoordinator.shared.diagnostic == lifecycleBefore, "application and scene lifecycle do not pump isolated coordinator")
        check(!SettingsPrivacyLifecycle.privacyRowRequired, "no privacy row/service startup in rooms")
        // Call all live public entrypoints, including reward paths and resets.
        let ads = AdReviveManager(); var rewards: [Bool] = []
        ads.preloadAd(); ads.preloadBlessingChoiceAd(); ads.reset()
        ads.requestRevive(from: nil) { rewards.append($0) }
        ads.requestRerollAd(from: nil) { rewards.append($0) }
        ads.requestXPBoost(from: nil) { rewards.append($0) }
        ads.requestExtraCardAd(from: nil) { rewards.append($0) }
        ads.requestBlessingChoiceAd(from: nil) { rewards.append($0) }
        ads.requestExtraPickAd(from: nil) { rewards.append($0) }
        for _ in 0..<20 { await Task.yield() }
        check(rewards.count == 6 && rewards.allSatisfy { !$0 }, "no implicit preview rewards")
        check(!ads.reviveUsedThisRun && !ads.xpBoostUsedThisRun, "no reward allowances consumed")
        check(StoreFixture.snapshotCalls == 0 && StoreFixture.updateCalls == 0 && StoreFixture.productsCalls == 0 && StoreFixture.purchaseCalls == 0 && StoreFixture.syncCalls == 0, "zero StoreKit calls")
        check(PlatformCalls.att == 0 && PlatformCalls.ump == 0 && PlatformCalls.ads == 0, "zero ATT UMP MobileAds calls")
        check(RewardedAd.loads == 0 && RewardedAd.presentations == 0, "zero rewarded loads/presentations")
        check(UserDefaults.standard.dictionaryRepresentation() as NSDictionary == standardBefore, "standard profile unchanged")
        check(GameRunPreferences.shared.dictionaryRepresentation() as NSDictionary == memoryBefore, "no unexpected preview preference writes")
        print("PASS: isolation \(ProcessInfo.processInfo.arguments.dropFirst()): \(checks) assertions; real production bodies, explicit SDK/StoreKit fakes")
    }
}
