// IAPManager.swift
// Sparkforge
//
// StoreKit 2 integration for Remove Ads IAP.
// Fully Swift 6 concurrency compliant.

import StoreKit

@MainActor
final class IAPManager {
    
    static let shared = IAPManager()
    
    // MARK: - Product IDs

    static let removeAdsProductID = "com.brandon.Sparkforge.removeads"

    // MARK: - State

    private let adEntitlement: AdEntitlementState
    var hasRemovedAds: Bool { adEntitlement.hasRemovedAds }
    var adEntitlementStatus: AdEntitlementStatus { adEntitlement.status }
    private var entitlementRefresh: Task<Void, Never>?
    private var refreshID = 0
    private var purchaseOrRestoreInProgress = false

    /// v2.0: generic non-consumable entitlements (premium skins, future IAPs).
    /// Every verified product id lands here; `isPurchased(_:)` reads it. Remove
    /// Ads keeps its own bool for back-compat but is ALSO mirrored here.
    private(set) var ownedProductIDs: Set<String> = []

    // MARK: - Keys

    private let purchaseKey = "sparkforge_ads_removed"
    private let ownedProductsKey = "sparkforge_owned_products"

    // MARK: - Init

    private init() {
        // Load cached state
        #if DEBUG
        let testMode = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--privacy-entitlement-test=") }
        let cachedOwner = testMode == nil && UserDefaults.standard.bool(forKey: purchaseKey)
        #else
        let cachedOwner = UserDefaults.standard.bool(forKey: purchaseKey)
        #endif
        adEntitlement = AdEntitlementState(cachedOwner: cachedOwner)
        adEntitlement.onChange = { [weak self] in
            guard let self else { return }
            UserDefaults.standard.set(self.hasRemovedAds, forKey: self.purchaseKey)
            NotificationCenter.default.post(name: .adEntitlementDidChange, object: nil)
        }
        ownedProductIDs = Set(UserDefaults.standard.stringArray(forKey: ownedProductsKey) ?? [])

        #if DEBUG
        // Explicit native test transport: real reducer/bridge, no StoreKit billing.
        // Not compiled into Release; the probe labels StoreKit as stubbed.
        if let testMode {
            if testMode == "--privacy-entitlement-test=owner" { adEntitlement.confirmedOwner() }
            if testMode == "--privacy-entitlement-test=delayed-owner" {
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    self?.adEntitlement.confirmedOwner()
                }
            }
            return
        }
        #endif
        // Verify with StoreKit on launch
        refreshEntitlements()

        // Listen for transaction updates
        Task {
            await listenForTransactions()
        }
    }

    // MARK: - v2.0: Generic entitlements (premium skins, etc.)

    /// Has the user purchased this product id? (Non-consumables only.)
    func isPurchased(_ productID: String) -> Bool {
        if productID == IAPManager.removeAdsProductID { return hasRemovedAds }
        return ownedProductIDs.contains(productID)
    }

    /// Purchase any non-consumable product id. Records the entitlement on success.
    func purchase(_ productID: String) async -> Bool {
        if productID == Self.removeAdsProductID { return await purchaseRemoveAds() }
        do {
            let products = try await Product.products(for: [productID])
            guard let product = products.first else {
                print("[IAP] Product not found: \(productID)")
                return false
            }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    recordEntitlement(productID)
                    return true
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("[IAP] Purchase error (\(productID)): \(error)")
            return false
        }
    }

    /// Localized display price for any product id, or nil if StoreKit hasn't
    /// returned it (e.g. no ASC/.storekit entry yet).
    func displayPrice(for productID: String) async -> String? {
        let products = try? await Product.products(for: [productID])
        return products?.first?.displayPrice
    }

    private func recordEntitlement(_ productID: String) {
        if productID == IAPManager.removeAdsProductID {
            ownedProductIDs.insert(productID)
            UserDefaults.standard.set(Array(ownedProductIDs), forKey: ownedProductsKey)
            adEntitlement.confirmedOwner()
            return
        }
        guard !ownedProductIDs.contains(productID) else { return }
        ownedProductIDs.insert(productID)
        UserDefaults.standard.set(Array(ownedProductIDs), forKey: ownedProductsKey)
        #if DEBUG
        print("[IAP] Entitlement recorded: \(productID)")
        #endif
    }
    
    // MARK: - Purchase
    
    func purchaseRemoveAds() async -> Bool {
        guard !purchaseOrRestoreInProgress else { return false }
        purchaseOrRestoreInProgress = true
        entitlementRefresh?.cancel()
        _ = adEntitlement.beginResolution()
        defer { purchaseOrRestoreInProgress = false }
        do {
            guard let product = try await fetchProduct() else {
                print("[IAP] Product not found")
                return false
            }
            
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification, transaction.revocationDate == nil {
                    recordEntitlement(Self.removeAdsProductID)
                    await transaction.finish()
                    return true
                }
                return false
                
            case .userCancelled:
                refreshEntitlements(force: true)
                return false
                
            case .pending:
                return false
                
            @unknown default:
                return false
            }
        } catch {
            print("[IAP] Purchase error: \(error)")
            return false
        }
    }
    
    /// Only the explicit Restore button calls sync (it may ask for App Store authentication).
    func restorePurchases() async {
        guard !purchaseOrRestoreInProgress else { return }
        purchaseOrRestoreInProgress = true
        entitlementRefresh?.cancel()
        let token = adEntitlement.beginResolution()
        defer { purchaseOrRestoreInProgress = false }
        do {
            try await AppStore.sync()
            let task = refreshEntitlements(force: true)
            await task?.value
        } catch {
            adEntitlement.completeResolution(token, verified: false, owner: false)
        }
    }

    /// Called on lifecycle readiness, not on a timer. Unknown/error never opens ads.
    func ensureAdEntitlementResolved() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--privacy-entitlement-test=") }) { return }
        #endif
        guard adEntitlementStatus == .unknown, !purchaseOrRestoreInProgress else { return }
        refreshEntitlements()
    }

    // MARK: - Verification

    @discardableResult
    private func refreshEntitlements(force: Bool = false) -> Task<Void, Never>? {
        if let entitlementRefresh, !force, !entitlementRefresh.isCancelled { return entitlementRefresh }
        entitlementRefresh?.cancel()
        refreshID += 1
        let currentID = refreshID
        let token = adEntitlement.beginResolution()
        let task = Task { [weak self] in
            guard let self else { return }
            var verified = true
            var owner = false
            for await result in Transaction.currentEntitlements {
                guard !Task.isCancelled else { return }
                switch result {
                case .verified(let transaction):
                    guard transaction.revocationDate == nil else { continue }
                    if transaction.productID == Self.removeAdsProductID { owner = true }
                    self.recordEntitlement(transaction.productID)
                    await transaction.finish()
                case .unverified:
                    verified = false
                }
            }
            guard !Task.isCancelled else { return }
            self.adEntitlement.completeResolution(token, verified: verified, owner: owner)
            if verified && !owner && !self.hasRemovedAds {
                self.ownedProductIDs.remove(Self.removeAdsProductID)
                UserDefaults.standard.set(Array(self.ownedProductIDs), forKey: self.ownedProductsKey)
            }
            if self.refreshID == currentID { self.entitlementRefresh = nil }
        }
        entitlementRefresh = task
        return task
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                if transaction.productID == Self.removeAdsProductID, transaction.revocationDate != nil {
                    adEntitlement.revokedOwner()
                    ownedProductIDs.remove(Self.removeAdsProductID)
                    UserDefaults.standard.set(Array(ownedProductIDs), forKey: ownedProductsKey)
                    refreshEntitlements(force: true)
                } else if transaction.revocationDate == nil {
                    recordEntitlement(transaction.productID)
                }
                await transaction.finish()
            case .unverified:
                // Do not grant access or permit ads using an unverified update.
                refreshEntitlements(force: true)
            }
        }
    }

    // MARK: - Product Fetch
    
    private func fetchProduct() async throws -> Product? {
        let products = try await Product.products(for: [IAPManager.removeAdsProductID])
        return products.first
    }
    
    /// Get the product for UI display (price string, etc.)
    func getRemoveAdsProduct() async -> Product? {
        return try? await fetchProduct()
    }

    /// Localized display price string for the Remove Ads product, or nil if
    /// StoreKit hasn't returned it. Lets callers show the price without
    /// importing StoreKit themselves.
    func removeAdsDisplayPrice() async -> String? {
        return await getRemoveAdsProduct()?.displayPrice
    }
    
}
