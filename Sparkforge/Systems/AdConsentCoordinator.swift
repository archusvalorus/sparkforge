// One launch coordinator. UMP consent and ATT are separate gates.
import Foundation

enum AdTrackingStatus: Equatable { case notDetermined, restricted, denied, authorized }

@MainActor
protocol AdConsentServices: AnyObject {
    var entitlement: AdEntitlementStatus { get }
    func prepareEntitlement()
    var isActive: Bool { get }
    var canPresent: Bool { get }
    var canRequestAds: Bool { get }
    var trackingStatus: AdTrackingStatus { get }
    var privacyOptionsRequired: Bool { get }
    func updateConsent(_ completion: @escaping (Bool) -> Void)
    func presentRequiredConsent(_ completion: @escaping (Bool) -> Void)
    func requestTracking(_ completion: @escaping () -> Void)
    func startAds(_ completion: @escaping () -> Void)
    func presentPrivacyOptions(_ completion: @escaping () -> Void)
}

extension Notification.Name {
    static let adPrivacyDidChange = Notification.Name("sparkforge.adPrivacyDidChange")
}

@MainActor
final class AdConsentCoordinator {
    private let services: AdConsentServices
    private var event = 0
    private var updateAttempt = -1
    private var trackingAttempt = -1
    private var updateComplete = false
    private var formComplete = false
    private var busy = false
    private var sdkStarting = false
    private var sdkStarted = false
    private var lastEntitlement: AdEntitlementStatus
    private var entitlementRevision = 0
    private var lastTracking: AdTrackingStatus?
    private var lastCanRequest: Bool
    private(set) var generation = 0
    private(set) var usedCachedConsent = false

    private struct Pending {
        weak var owner: AnyObject?
        let placement: String
        let action: (Int) -> Void
    }
    private var pending: [Pending] = []

    init(services: AdConsentServices) {
        self.services = services
        lastEntitlement = services.entitlement
        lastTracking = nil
        lastCanRequest = false
    }

    #if DEBUG
    var diagnostic: String {
        "entitlement=\(services.entitlement) event=\(event) attempt=\(updateAttempt) active=\(services.isActive) presenter=\(services.canPresent) busy=\(busy) update=\(updateComplete) form=\(formComplete) sdk=\(sdkStarted)"
    }
    #endif
    var privacyOptionsRequired: Bool { services.entitlement == .nonOwner && services.privacyOptionsRequired }
    var ready: Bool {
        reconcile()
        return services.entitlement == .nonOwner && services.isActive && !busy && updateComplete && formComplete
            && services.canRequestAds && services.trackingStatus != .notDetermined && sdkStarted
    }
    func isCurrent(_ value: Int) -> Bool { ready && generation == value }
    func canPresentAd(generation value: Int) -> Bool { isCurrent(value) && services.canPresent }

    func becameActive() { presenterBecameReady() }
    func presenterBecameReady() {
        event += 1
        services.prepareEntitlement()
        pump()
    }
    func entitlementDidChange() {
        event += 1
        pump()
    }
    func becameInactive() { reconcile() }

    func whenReady(owner: AnyObject, placement: String, action: @escaping (Int) -> Void) {
        pending.removeAll { $0.owner == nil || ($0.owner === owner && $0.placement == placement) }
        pending.append(Pending(owner: owner, placement: placement, action: action))
        services.prepareEntitlement()
        pump()
    }

    private func invalidate() {
        generation += 1
        NotificationCenter.default.post(name: .adPrivacyDidChange, object: nil)
    }
    private func reconcile() {
        let entitlement = services.entitlement
        if entitlement != lastEntitlement {
            lastEntitlement = entitlement
            entitlementRevision += 1
            updateComplete = false
            formComplete = false
            usedCachedConsent = false
            updateAttempt = -1
            trackingAttempt = -1
            lastTracking = nil
            lastCanRequest = false
            invalidate()
        }
        // Owners/unknown users do not even consult UMP/ATT status APIs.
        guard entitlement == .nonOwner else { return }
        let tracking = services.trackingStatus
        let canRequest = services.canRequestAds
        if tracking != lastTracking || canRequest != lastCanRequest {
            lastTracking = tracking
            lastCanRequest = canRequest
            invalidate()
        }
    }

    private func pump() {
        reconcile()
        pending.removeAll { $0.owner == nil }
        if services.entitlement == .owner { pending.removeAll() }
        guard services.entitlement == .nonOwner, services.isActive, services.canPresent, !busy else { return }
        if !updateComplete {
            guard updateAttempt != event else { return }
            updateAttempt = event
            busy = true
            invalidate()
            let revision = entitlementRevision
            services.updateConsent { [weak self] success in
                guard let self else { return }
                self.busy = false
                self.reconcile()
                guard self.services.entitlement == .nonOwner, self.entitlementRevision == revision else {
                    self.pump()
                    return
                }
                // UMP owns cached consent. Never substitute our own persisted boolean.
                self.usedCachedConsent = !success && self.services.canRequestAds
                self.updateComplete = success || self.usedCachedConsent
                self.updateAttempt = self.event
                self.pump()
            }
            return
        }
        if !formComplete {
            busy = true
            let revision = entitlementRevision
            services.presentRequiredConsent { [weak self] success in
                guard let self else { return }
                self.busy = false
                self.reconcile()
                guard self.services.entitlement == .nonOwner, self.entitlementRevision == revision else {
                    self.pump()
                    return
                }
                // An unsuccessful form may still leave valid previous-session consent.
                self.formComplete = success || self.services.canRequestAds
                if !self.formComplete { self.updateComplete = false; self.updateAttempt = self.event }
                NotificationCenter.default.post(name: .adPrivacyDidChange, object: nil)
                self.pump()
            }
            return
        }
        guard services.canRequestAds else { return }
        if services.trackingStatus == .notDetermined {
            guard trackingAttempt != event else { return }
            busy = true
            trackingAttempt = event
            let revision = entitlementRevision
            services.requestTracking { [weak self] in
                guard let self else { return }
                self.busy = false
                self.reconcile()
                guard self.services.entitlement == .nonOwner, self.entitlementRevision == revision else {
                    self.pump()
                    return
                }
                // A dismissed/unresolved system request stays closed until a NEW readiness event.
                self.trackingAttempt = self.event
                self.pump()
            }
            return
        }
        guard sdkStarted else {
            guard !sdkStarting else { return }
            sdkStarting = true
            services.startAds { [weak self] in
                guard let self else { return }
                // Initialization completion is independent of consent generation.
                self.sdkStarting = false
                self.sdkStarted = true
                self.pump()
            }
            return
        }
        guard ready else { return }
        let work = pending
        pending.removeAll()
        for item in work where item.owner != nil {
            guard ready else {
                pending.append(item)
                continue
            }
            item.action(generation)
        }
    }

    @discardableResult
    func presentPrivacyOptions() -> Bool {
        guard services.entitlement == .nonOwner, services.isActive, services.canPresent, !busy, privacyOptionsRequired else { return false }
        busy = true
        invalidate()
        let revision = entitlementRevision
        services.presentPrivacyOptions { [weak self] in
            guard let self else { return }
            self.busy = false
            self.reconcile()
            guard self.services.entitlement == .nonOwner, self.entitlementRevision == revision else {
                self.pump()
                return
            }
            self.formComplete = true
            self.reconcile()
            NotificationCenter.default.post(name: .adPrivacyDidChange, object: nil)
            self.pump()
        }
        return true
    }
}
