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

    private(set) var hasRemovedAds: Bool = false

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
        hasRemovedAds = UserDefaults.standard.bool(forKey: purchaseKey)
        ownedProductIDs = Set(UserDefaults.standard.stringArray(forKey: ownedProductsKey) ?? [])

        // Verify with StoreKit on launch
        Task {
            await verifyPurchases()
        }

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
            setAdsRemoved(true)
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
        do {
            guard let product = try await fetchProduct() else {
                print("[IAP] Product not found")
                return false
            }
            
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    setAdsRemoved(true)
                    return true
                }
                return false
                
            case .userCancelled:
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
    
    /// Restore purchases
    func restorePurchases() async {
        await verifyPurchases()
    }
    
    // MARK: - Verification
    
    private func verifyPurchases() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                recordEntitlement(transaction.productID)   // handles Remove Ads + skins
                await transaction.finish()
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
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                recordEntitlement(transaction.productID)   // handles Remove Ads + skins
                await transaction.finish()
            }
        }
    }
    
    // MARK: - State Management
    
    private func setAdsRemoved(_ removed: Bool) {
        hasRemovedAds = removed
        UserDefaults.standard.set(removed, forKey: purchaseKey)
        
        #if DEBUG
        print("[IAP] Ads removed: \(removed)")
        #endif
    }
}
