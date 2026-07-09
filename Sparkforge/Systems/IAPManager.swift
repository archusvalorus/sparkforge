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
    
    // MARK: - Keys
    
    private let purchaseKey = "sparkforge_ads_removed"
    
    // MARK: - Init
    
    private init() {
        // Load cached state
        hasRemovedAds = UserDefaults.standard.bool(forKey: purchaseKey)
        
        // Verify with StoreKit on launch
        Task {
            await verifyPurchases()
        }
        
        // Listen for transaction updates
        Task {
            await listenForTransactions()
        }
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
                if transaction.productID == IAPManager.removeAdsProductID {
                    setAdsRemoved(true)
                    await transaction.finish()
                }
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
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                if transaction.productID == IAPManager.removeAdsProductID {
                    setAdsRemoved(true)
                    await transaction.finish()
                }
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
