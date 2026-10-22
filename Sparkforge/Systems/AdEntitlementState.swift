import Foundation

enum AdEntitlementStatus: Equatable { case unknown, owner, nonOwner }

/// StoreKit-independent state machine. A missing early result never means nonowner.
@MainActor
final class AdEntitlementState {
    private(set) var status: AdEntitlementStatus
    private(set) var hasRemovedAds: Bool
    private var revision = 0
    var onChange: (() -> Void)?

    init(cachedOwner: Bool) {
        hasRemovedAds = cachedOwner
        status = cachedOwner ? .owner : .unknown
    }

    @discardableResult
    func beginResolution() -> Int {
        revision += 1
        setStatus(hasRemovedAds ? .owner : .unknown)
        return revision
    }

    func completeResolution(_ token: Int, verified: Bool, owner: Bool) {
        guard token == revision else { return }
        if !verified { setStatus(hasRemovedAds ? .owner : .unknown); return }
        hasRemovedAds = owner
        setStatus(owner ? .owner : .nonOwner)
    }

    func confirmedOwner() {
        revision += 1 // an arriving purchase/restore outranks an older empty snapshot
        hasRemovedAds = true
        setStatus(.owner)
    }

    func revokedOwner() {
        revision += 1
        hasRemovedAds = false
        setStatus(.unknown) // re-enumerate; a replacement entitlement may exist
    }

    private func setStatus(_ value: AdEntitlementStatus) {
        status = value
        onChange?()
    }
}

extension Notification.Name {
    static let adEntitlementDidChange = Notification.Name("sparkforge.adEntitlementDidChange")
}
