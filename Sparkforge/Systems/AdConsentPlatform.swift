import UIKit
import AppTrackingTransparency
import UserMessagingPlatform
import GoogleMobileAds

@MainActor
final class AdConsentPlatform: AdConsentServices {
    static let shared = AdConsentPlatform()
    weak var presenter: UIViewController?
    private var entitlementObserver: NSObjectProtocol?
    private init() {
        entitlementObserver = NotificationCenter.default.addObserver(forName: .adEntitlementDidChange,
                                                                    object: nil, queue: .main) { _ in
            Task { @MainActor in AdConsentCoordinator.shared.entitlementDidChange() }
        }
    }
    var entitlement: AdEntitlementStatus { IAPManager.shared.adEntitlementStatus }
    func prepareEntitlement() { IAPManager.shared.ensureAdEntitlementResolved() }
    private(set) var updateErrorCode: Int?
    #if DEBUG
    let systemATTTest = ProcessInfo.processInfo.arguments.contains("--privacy-att-system-test")
    #endif
    var isActive: Bool { UIApplication.shared.applicationState == .active }
    var canPresent: Bool {
        guard let presenter else { return false }
        return presenter.viewIfLoaded?.window != nil && presenter.presentedViewController == nil
            && !presenter.isBeingDismissed
    }
    var canRequestAds: Bool {
        guard entitlement == .nonOwner else { return false }
        #if DEBUG
        if systemATTTest { return true }
        #endif
        return ConsentInformation.shared.canRequestAds
    }
    var privacyOptionsRequired: Bool {
        entitlement == .nonOwner && ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }
    var trackingStatus: AdTrackingStatus {
        guard entitlement == .nonOwner else { return .notDetermined }
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }
    func updateConsent(_ completion: @escaping (Bool) -> Void) {
        guard entitlement == .nonOwner else { completion(false); return }
        #if DEBUG
        if systemATTTest { completion(true); return }
        #endif
        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { error in
            DispatchQueue.main.async {
                self.updateErrorCode = (error as NSError?)?.code
                completion(error == nil)
            }
        }
    }
    func presentRequiredConsent(_ completion: @escaping (Bool) -> Void) {
        guard entitlement == .nonOwner else { completion(false); return }
        #if DEBUG
        if systemATTTest { completion(true); return }
        #endif
        guard let presenter, canPresent else { completion(false); return }
        ConsentForm.loadAndPresentIfRequired(from: presenter) { error in
            DispatchQueue.main.async { completion(error == nil) }
        }
    }
    func requestTracking(_ completion: @escaping () -> Void) {
        guard entitlement == .nonOwner, isActive, canPresent else { completion(); return }
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async { completion() }
        }
    }
    func startAds(_ completion: @escaping () -> Void) {
        guard entitlement == .nonOwner else { completion(); return }
        #if DEBUG
        if systemATTTest { completion(); return }
        #endif
        MobileAds.shared.start { _ in DispatchQueue.main.async { completion() } }
    }
    func presentPrivacyOptions(_ completion: @escaping () -> Void) {
        guard entitlement == .nonOwner, let presenter, canPresent else { completion(); return }
        ConsentForm.presentPrivacyOptionsForm(from: presenter) { _ in
            DispatchQueue.main.async { completion() }
        }
    }
}

extension AdConsentCoordinator {
    static let shared = AdConsentCoordinator(services: AdConsentPlatform.shared)
}
