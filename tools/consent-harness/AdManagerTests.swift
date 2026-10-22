import Foundation

@MainActor final class UIViewController {
    final class View { var window: NSObject? = NSObject() }
    var viewIfLoaded: View? = View()
    var presentedViewController: UIViewController?
}
@MainActor final class IAPManager {
    static let shared = IAPManager()
    var hasRemovedAds = false
}
final class Request {}
protocol FullScreenPresentingAd {}
protocol FullScreenContentDelegate {
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error)
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd)
}
@MainActor final class RewardedAd: FullScreenPresentingAd {
    struct Load { let unit: String; let callback: (RewardedAd?, Error?) -> Void }
    static var requests: [Load] = []
    static var presentations = 0
    var fullScreenContentDelegate: FullScreenContentDelegate?
    var reward: (() -> Void)?
    static func load(with unit: String, request: Request, completion: @escaping (RewardedAd?, Error?) -> Void) {
        requests.append(Load(unit: unit, callback: completion))
    }
    func present(from: UIViewController, userDidEarnRewardHandler: @escaping () -> Void) {
        Self.presentations += 1
        reward = userDidEarnRewardHandler
    }
}
@MainActor final class Services: AdConsentServices {
    var entitlement: AdEntitlementStatus = .nonOwner
    func prepareEntitlement() {}
    var isActive = true; var canPresent = true; var canRequestAds = false
    var trackingStatus: AdTrackingStatus = .notDetermined
    var privacyOptionsRequired = false
    var update: ((Bool) -> Void)?
    var startCount = 0
    func updateConsent(_ completion: @escaping (Bool) -> Void) { update = completion }
    func presentRequiredConsent(_ completion: @escaping (Bool) -> Void) { completion(true) }
    func requestTracking(_ completion: @escaping () -> Void) { completion() }
    func startAds(_ completion: @escaping () -> Void) { startCount += 1; completion() }
    func presentPrivacyOptions(_ completion: @escaping () -> Void) { completion() }
}
@MainActor enum Fixture {
    static let services = Services()
    static let coordinator = AdConsentCoordinator(services: services)
}
extension AdConsentCoordinator { static var shared: AdConsentCoordinator { Fixture.coordinator } }

@main struct AdManagerTests {
    @MainActor static func main() async {
        var assertions = 0
        func check(_ value: @autoclosure () -> Bool, _ name: String) {
            assertions += 1
            if !value() { fatalError("FAIL: \(name)") }
        }
        func settle() async { for _ in 0..<10 { await Task.yield() }; try? await Task.sleep(nanoseconds: 20_000_000) }
        let services = Fixture.services
        let manager = AdReviveManager()
        manager.preloadAd(); manager.preloadAd(); manager.preloadBlessingChoiceAd()
        check(RewardedAd.requests.isEmpty && services.startCount == 0, "all title/run warm loads blocked before consent")
        services.canRequestAds = true; services.update?(true)
        check(RewardedAd.requests.isEmpty, "UMP alone never opens ATT gate")
        services.trackingStatus = .denied
        Fixture.coordinator.becameActive()
        check(RewardedAd.requests.count == 6 && services.startCount == 1, "six placements drain once after both gates")
        let old = RewardedAd.requests
        services.trackingStatus = .authorized
        for item in old { item.callback(RewardedAd(), nil) }
        await settle()
        var result: Bool?
        let vc = UIViewController()
        manager.requestRevive(from: vc) { result = $0 }
        check(result == false && RewardedAd.presentations == 0, "stale load callback cannot populate cache")
        check(RewardedAd.requests.count == 7, "unready request queues gated reload")
        manager.preloadAd()
        check(RewardedAd.requests.count == 12, "in-flight same-placement load deduplicated")
        let ads = (6..<12).map { _ in RewardedAd() }
        for (index, ad) in zip(6..<12, ads) { RewardedAd.requests[index].callback(ad, nil) }
        await settle()
        let actions: [(@escaping (Bool) -> Void) -> Void] = [
            { manager.requestRevive(from: vc, completion: $0) },
            { manager.requestRerollAd(from: vc, completion: $0) },
            { manager.requestXPBoost(from: vc, completion: $0) },
            { manager.requestExtraCardAd(from: vc, completion: $0) },
            { manager.requestBlessingChoiceAd(from: vc, completion: $0) },
            { manager.requestExtraPickAd(from: vc, completion: $0) }
        ]
        // Revoke consent after caches complete. Every presentation path must close.
        services.canRequestAds = false
        for action in actions { result = nil; action { result = $0 }; check(result == false, "revoked cache rejects presentation") }
        check(RewardedAd.presentations == 0, "no stale presentation across all six paths")
        IAPManager.shared.hasRemovedAds = true
        for action in actions { result = nil; action { result = $0 }; check(result == true, "Remove Ads benefits remain free while privacy gate closed") }
        check(RewardedAd.requests.count == 12, "Remove Ads never reloads")
        IAPManager.shared.hasRemovedAds = false
        services.canRequestAds = true; Fixture.coordinator.becameActive()
        let fresh = AdReviveManager()
        let offset = RewardedAd.requests.count
        fresh.preloadAd()
        let liveAds = (0..<6).map { _ in RewardedAd() }
        for (index, ad) in liveAds.enumerated() { RewardedAd.requests[offset + index].callback(ad, nil) }
        await settle()
        let freshActions: [(@escaping (Bool) -> Void) -> Void] = [
            { fresh.requestRevive(from: vc, completion: $0) },
            { fresh.requestRerollAd(from: vc, completion: $0) },
            { fresh.requestXPBoost(from: vc, completion: $0) },
            { fresh.requestExtraCardAd(from: vc, completion: $0) },
            { fresh.requestBlessingChoiceAd(from: vc, completion: $0) },
            { fresh.requestExtraPickAd(from: vc, completion: $0) }
        ]
        for (index, action) in freshActions.enumerated() {
            var successes = 0; var failures = 0
            let before = RewardedAd.requests.count
            action { if $0 { successes += 1 } else { failures += 1 } }
            check(RewardedAd.presentations == index + 1, "every placement presents valid cache")
            services.canPresent = false // SDK fullscreen is still open when reward fires
            liveAds[index].reward?(); liveAds[index].reward?()
            check(successes == 1 && failures == 0, "earned reward delivered once")
            check(RewardedAd.requests.count == before, "reward reload waits for modal dismissal")
            services.canPresent = true
            liveAds[index].fullScreenContentDelegate?.adDidDismissFullScreenContent(liveAds[index])
            await settle()
            check(RewardedAd.requests.count == before + 1, "dismiss delegate wakes one reload")
            check(successes == 1 && failures == 0, "dismissal does not cancel earned reward")
        }
        print("PASS: \(assertions) actual AdReviveManager assertions (SDK/UI stubbed)")
    }
}
