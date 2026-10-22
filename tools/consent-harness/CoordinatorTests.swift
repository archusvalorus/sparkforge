import Foundation

@MainActor final class Fake: AdConsentServices {
    var entitlement: AdEntitlementStatus = .nonOwner
    func prepareEntitlement() {}
    var isActive = true
    var canPresent = true
    var sdkReads = 0
    private var requestPermission = false
    var canRequestAds: Bool {
        get { sdkReads += 1; return requestPermission }
        set { requestPermission = newValue }
    }
    private var tracking: AdTrackingStatus = .notDetermined
    var trackingStatus: AdTrackingStatus {
        get { sdkReads += 1; return tracking }
        set { tracking = newValue }
    }
    var privacyOptionsRequired = false
    var updateOK = true
    var formOK = true
    var consentAtUpdate = true
    var attResult: AdTrackingStatus = .authorized
    var umpResolvesATT = false
    var holdUpdate = false
    var holdStart = false
    var holdTracking = false
    var trackingCallback: (() -> Void)?
    var updateCallback: ((Bool) -> Void)?
    var startCallback: (() -> Void)?
    var calls: [String] = []
    func updateConsent(_ completion: @escaping (Bool) -> Void) {
        calls.append("update")
        if holdUpdate { updateCallback = completion; return }
        if updateOK { canRequestAds = consentAtUpdate }
        completion(updateOK)
    }
    func presentRequiredConsent(_ completion: @escaping (Bool) -> Void) {
        calls.append("form")
        if umpResolvesATT { trackingStatus = attResult }
        completion(formOK)
    }
    func requestTracking(_ completion: @escaping () -> Void) {
        calls.append("att")
        if holdTracking { trackingCallback = completion; return }
        trackingStatus = attResult
        completion()
    }
    func startAds(_ completion: @escaping () -> Void) {
        calls.append("start")
        if holdStart { startCallback = completion; return }
        completion()
    }
    func presentPrivacyOptions(_ completion: @escaping () -> Void) {
        calls.append("options")
        completion()
    }
}
final class Owner {}

@main struct CoordinatorTests {
    @MainActor static func main() {
        var assertions = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            assertions += 1
            guard condition() else { fatalError("FAIL: \(name)") }
        }
        for status in [AdTrackingStatus.authorized, .denied, .restricted] {
            let f = Fake(); f.trackingStatus = status
            let c = AdConsentCoordinator(services: f); let owner = Owner()
            var loads = 0
            c.whenReady(owner: owner, placement: "revive") { _ in loads += 1 }
            check(f.calls == ["update", "form", "start"], "terminal status ordering")
            check(loads == 1 && c.ready, "terminal status opens separate gates")
            c.becameActive(); check(f.calls.filter { $0 == "start" }.count == 1, "start once")
        }
        do {
            let f = Fake(); let c = AdConsentCoordinator(services: f); let o = Owner()
            var loads = 0
            c.whenReady(owner: o, placement: "title") { _ in loads += 1 }
            check(f.calls == ["update", "form", "att", "start"], "ATT before SDK before title load")
            check(loads == 1, "queued title drains")
            let generation = c.generation
            f.trackingStatus = .denied
            check(!c.isCurrent(generation), "ATT change invalidates cached generation")
            check(c.ready, "denied remains a resolved ATT choice")
        }
        do {
            let f = Fake(); f.attResult = .notDetermined
            let c = AdConsentCoordinator(services: f); let o = Owner()
            var loads = 0
            c.whenReady(owner: o, placement: "revive") { _ in loads += 1 }
            check(!c.ready && !f.calls.contains("start") && loads == 0, "unresolved ATT blocks SDK")
            check(f.calls.filter { $0 == "att" }.count == 1, "no request loop")
            f.attResult = .denied; c.becameActive()
            check(c.ready && f.calls.filter { $0 == "att" }.count == 2, "later active retries unresolved")
        }
        do {
            let f = Fake(); f.umpResolvesATT = true
            let c = AdConsentCoordinator(services: f); c.becameActive()
            check(c.ready && !f.calls.contains("att"), "UMP ATT not duplicated")
        }
        for cached in [false, true] {
            let f = Fake(); f.updateOK = false; f.canRequestAds = cached; f.trackingStatus = .denied
            let c = AdConsentCoordinator(services: f); c.becameActive()
            check(c.ready == cached && c.usedCachedConsent == cached, "SDK cached consent only on error")
            check(f.calls.filter { $0 == "update" }.count == 1, "error no spin")
            if !cached { f.updateOK = true; c.becameActive(); check(c.ready, "update retries next activation") }
        }
        do {
            let f = Fake(); f.consentAtUpdate = false
            let c = AdConsentCoordinator(services: f); c.becameActive()
            check(!c.ready && !f.calls.contains("att") && !f.calls.contains("start"), "UMP false blocks ATT/SDK")
        }
        do {
            let f = Fake(); f.isActive = false
            let c = AdConsentCoordinator(services: f); let o = Owner(); var loads = 0
            c.whenReady(owner: o, placement: "revive") { _ in loads += 1 }
            check(f.calls.isEmpty, "inactive does not start consent")
            f.isActive = true; f.canPresent = false; c.becameActive()
            check(f.calls.isEmpty, "presenter pending does not start consent")
            f.canPresent = true; c.presenterBecameReady()
            check(c.ready && loads == 1, "presenter readiness retries")
            f.isActive = false
            check(!c.ready && !c.canPresentAd(generation: c.generation), "background closes all access")
        }
        do {
            let f = Fake(); f.holdUpdate = true
            let c = AdConsentCoordinator(services: f); var first: Owner? = Owner(); let second = Owner()
            var firstLoads = 0; var secondLoads = 0
            c.whenReady(owner: first!, placement: "same") { _ in firstLoads += 100 }
            c.whenReady(owner: first!, placement: "same") { _ in firstLoads += 1 }
            c.whenReady(owner: second, placement: "same") { _ in secondLoads += 1 }
            check(f.calls == ["update"], "one in-flight consent update")
            first = nil
            f.canRequestAds = true; f.updateCallback?(true)
            check(firstLoads == 0 && secondLoads == 1, "weak owner and per-owner placement")
        }
        do {
            let f = Fake(); f.holdStart = true; f.trackingStatus = .authorized
            let c = AdConsentCoordinator(services: f); c.becameActive()
            f.canRequestAds = false
            f.startCallback?()
            check(!c.ready, "consent revoked during SDK initialization")
            f.canRequestAds = true; c.becameActive()
            check(c.ready && f.calls.filter { $0 == "start" }.count == 1, "stale SDK completion records initialization")
            let epoch = c.generation
            f.privacyOptionsRequired = true
            check(c.presentPrivacyOptions(), "required options reachable")
            check(!c.isCurrent(epoch), "privacy options invalidate existing ad caches")
            f.canPresent = false
            check(!c.canPresentAd(generation: c.generation), "modal blocks cached presentation")
            check(!c.presentPrivacyOptions(), "options cannot overlap modal")
        }
        do {
            let f = Fake(); f.holdTracking = true
            let c = AdConsentCoordinator(services: f); c.becameActive()
            f.isActive = false; c.becameInactive()
            f.trackingStatus = .authorized; f.trackingCallback?()
            check(!c.ready && !f.calls.contains("start"), "ATT callback while inactive stays closed")
            f.isActive = true; c.becameActive()
            check(c.ready && f.calls.filter { $0 == "att" }.count == 1, "active after ATT callback opens without reasking")
        }
        do {
            let f = Fake(); f.holdTracking = true
            let c = AdConsentCoordinator(services: f); c.becameActive()
            f.canPresent = false; f.trackingStatus = .authorized; f.trackingCallback?()
            check(!c.ready, "ATT completion while presenter blocked waits")
            f.canPresent = true; c.presenterBecameReady()
            check(c.ready, "dismissed presenter explicitly resumes")
        }
        for ownership in [AdEntitlementStatus.unknown, .owner] {
            let f = Fake(); f.entitlement = ownership
            let c = AdConsentCoordinator(services: f); let o = Owner()
            c.whenReady(owner: o, placement: "revive") { _ in fatalError("owner/unknown ad") }
            c.becameActive()
            check(!c.ready && !c.privacyOptionsRequired && !c.presentPrivacyOptions(), "owner/unknown has no ad/consent UI")
            check(f.calls.isEmpty && f.sdkReads == 0, "owner/unknown never touches UMP/ATT status or startup")
        }
        do {
            let f = Fake(); f.entitlement = .unknown
            let c = AdConsentCoordinator(services: f); let o = Owner(); var loads = 0
            c.whenReady(owner: o, placement: "revive") { _ in loads += 1 }
            c.becameActive(); check(loads == 0 && f.calls.isEmpty, "delayed entitlement has no early fallback")
            f.entitlement = .nonOwner; c.entitlementDidChange()
            check(c.ready && loads == 1 && f.calls == ["update", "form", "att", "start"], "completed nonowner drains normal consent path")
            let epoch = c.generation
            f.entitlement = .owner; c.entitlementDidChange()
            check(!c.isCurrent(epoch), "purchase invalidates live ad generation")
        }
        do {
            let f = Fake(); f.holdUpdate = true
            let c = AdConsentCoordinator(services: f); c.becameActive()
            f.entitlement = .owner; c.entitlementDidChange()
            f.canRequestAds = true; f.updateCallback?(true)
            check(f.calls == ["update"] && !c.ready, "purchase during UMP blocks form/ATT/SDK")
        }
        do {
            let f = Fake(); f.holdTracking = true
            let c = AdConsentCoordinator(services: f); c.becameActive()
            f.entitlement = .owner; c.entitlementDidChange()
            f.trackingStatus = .authorized; f.trackingCallback?()
            check(!f.calls.contains("start") && !c.ready, "purchase during existing ATT blocks SDK")
        }
        do {
            let f = Fake(); f.holdStart = true; f.trackingStatus = .authorized
            let c = AdConsentCoordinator(services: f); let o = Owner(); var loads = 0
            c.whenReady(owner: o, placement: "revive") { _ in loads += 1 }
            f.entitlement = .owner; c.entitlementDidChange(); f.startCallback?()
            check(!c.ready && loads == 0, "purchase while SDK already starting blocks subsequent loads")
            f.entitlement = .nonOwner; c.entitlementDidChange()
            check(c.ready && f.calls.filter { $0 == "update" }.count == 2 && f.calls.filter { $0 == "start" }.count == 1,
                  "verified nonowner return refreshes consent without double SDK start")
        }
        do {
            let state = AdEntitlementState(cachedOwner: false)
            check(state.status == .unknown, "fresh state is unknown before any scan callback")
            let old = state.beginResolution()
            check(state.status == .unknown, "empty early entitlement not nonowner")
            state.confirmedOwner(); state.completeResolution(old, verified: true, owner: false)
            check(state.status == .owner && state.hasRemovedAds, "new purchase outranks stale empty snapshot")
            state.revokedOwner()
            check(state.status == .unknown && !state.hasRemovedAds, "revocation waits fresh verification")
            let token = state.beginResolution(); state.completeResolution(token, verified: false, owner: false)
            check(state.status == .unknown, "verification error cannot create nonowner")
            let next = state.beginResolution(); state.completeResolution(next, verified: true, owner: false)
            check(state.status == .nonOwner, "fully verified empty enumeration establishes nonowner")
            let cached = AdEntitlementState(cachedOwner: true)
            let failed = cached.beginResolution(); cached.completeResolution(failed, verified: false, owner: false)
            check(cached.status == .owner && cached.hasRemovedAds, "cached verified owner benefits survive verification failure")
        }
        print("PASS: \(assertions) coordinator assertions")
    }
}
