import Foundation

@main struct IAPTests {
    @MainActor static func main() async {
        let name = CommandLine.arguments[1]
        let id = "com.brandon.Sparkforge.removeads"
        for key in ["sparkforge_ads_removed", "sparkforge_owned_products"] { UserDefaults.standard.removeObject(forKey: key) }
        defer { for key in ["sparkforge_ads_removed", "sparkforge_owned_products"] { UserDefaults.standard.removeObject(forKey: key) } }
        var count = 0
        func check(_ value: @autoclosure () -> Bool, _ label: String) {
            count += 1; guard value() else { fatalError("FAIL \(name): \(label)") }
        }
        func settle() async { for _ in 0..<30 { await Task.yield() }; try? await Task.sleep(nanoseconds: 20_000_000) }
        var held: AsyncStream<VerificationResult<Transaction>>.Continuation?
        let stream = AsyncStream<VerificationResult<Transaction>> { held = $0 }
        switch name {
        case "fresh", "delayed-owner", "purchase-race", "update-race": StoreFixture.snapshots = [stream]
        case "cached-owner":
            UserDefaults.standard.set(true, forKey: "sparkforge_ads_removed")
            StoreFixture.snapshots = [stream]
        case "revocation-during-finish":
            StoreFixture.holdFinish = true
            StoreFixture.snapshots = [StoreFixture.snapshot([.verified(Transaction(id))])]
        case "unverified": StoreFixture.snapshots = [StoreFixture.snapshot([.unverified(Transaction(id), NSError(domain: "test", code: 1))])]
        default: StoreFixture.snapshots = [StoreFixture.snapshot([])]
        }
        let manager = IAPManager()
        check(manager.adEntitlementStatus == (name == "cached-owner" ? .owner : .unknown), "initial ownership never defaults nonowner")
        await settle()
        switch name {
        case "fresh":
            check(manager.adEntitlementStatus == .unknown, "no early callback is not nonowner")
            held?.yield(.verified(Transaction("skin.test"))); await settle()
            check(manager.adEntitlementStatus == .unknown && manager.isPurchased("skin.test"), "skin does not complete entitlement scan")
            held?.finish(); await settle()
            check(manager.adEntitlementStatus == .nonOwner, "full empty RemoveAds enumeration resolves nonowner")
        case "cached-owner":
            check(manager.hasRemovedAds && manager.adEntitlementStatus == .owner, "cached owner remains free while scan delayed")
            held?.yield(.unverified(Transaction(id), NSError(domain: "test", code: 1))); held?.finish(); await settle()
            check(manager.hasRemovedAds && manager.adEntitlementStatus == .owner, "unverified scan cannot remove cached owner")
        case "delayed-owner":
            check(manager.adEntitlementStatus == .unknown, "delayed owner kept unknown")
            held?.yield(.verified(Transaction(id))); await settle()
            check(manager.hasRemovedAds && manager.isPurchased(id) && manager.ownedProductIDs.contains(id), "verified owner recognized before enumeration ends")
            held?.finish(); await settle(); check(manager.adEntitlementStatus == .owner, "owner remains after exhaustion")
        case "unverified":
            check(manager.adEntitlementStatus == .unknown && !manager.hasRemovedAds, "failed verification cannot allow ads")
            manager.ensureAdEntitlementResolved(); await settle()
            check(manager.adEntitlementStatus == .nonOwner, "later full verified retry can recover")
        case "purchase-race":
            StoreFixture.purchaseResult = .success(.verified(Transaction(id)))
            let bought = await manager.purchaseRemoveAds()
            held?.finish(); await settle()
            check(bought && manager.hasRemovedAds && manager.adEntitlementStatus == .owner, "purchase outranks old cancelled empty scan")
        case "update-race":
            StoreFixture.updateContinuation?.yield(.verified(Transaction(id))); await settle()
            held?.finish(); await settle()
            check(manager.hasRemovedAds && manager.adEntitlementStatus == .owner, "update purchase outranks earlier empty snapshot")
        case "purchase-error":
            check(manager.adEntitlementStatus == .nonOwner, "initial full scan complete")
            StoreFixture.purchaseError = true
            let bought = await manager.purchaseRemoveAds()
            check(!bought && manager.adEntitlementStatus == .unknown, "purchase error leaves ad permission unknown")
            StoreFixture.purchaseError = false; manager.ensureAdEntitlementResolved(); await settle()
            check(manager.adEntitlementStatus == .nonOwner, "fresh verification after error recovers")
        case "restore-error":
            StoreFixture.syncError = true; await manager.restorePurchases()
            check(manager.adEntitlementStatus == .unknown, "restore error cannot imply nonowner")
            StoreFixture.syncError = false
            StoreFixture.snapshots = [StoreFixture.snapshot([.verified(Transaction(id))])]
            await manager.restorePurchases(); check(manager.hasRemovedAds && manager.adEntitlementStatus == .owner, "successful restore recognizes owner")
        case "restore-race":
            StoreFixture.holdSync = true
            let restore = Task { await manager.restorePurchases() }; await settle()
            check(manager.adEntitlementStatus == .unknown, "sync pending closes ad gate")
            StoreFixture.updateContinuation?.yield(.verified(Transaction(id))); await settle()
            StoreFixture.syncContinuation?.resume(throwing: NSError(domain: "test", code: 2))
            await restore.value
            check(manager.hasRemovedAds && manager.adEntitlementStatus == .owner, "late restore error cannot overwrite newer owner")
        case "restore-serialized":
            StoreFixture.holdSync = true
            let restore = Task { await manager.restorePurchases() }; await settle()
            await manager.restorePurchases()
            let bought = await manager.purchaseRemoveAds()
            check(!bought && StoreFixture.purchaseCalls == 0 && StoreFixture.syncCalls == 1, "concurrent restore/purchase do not duplicate StoreKit UI")
            StoreFixture.snapshots = [StoreFixture.snapshot([.verified(Transaction(id))])]
            StoreFixture.syncContinuation?.resume(); await restore.value
            check(manager.hasRemovedAds, "serialized restore finishes with owner")
        case "revocation":
            StoreFixture.updateContinuation?.yield(.verified(Transaction(id))); await settle()
            check(manager.hasRemovedAds, "owner update granted")
            StoreFixture.snapshots = [stream]
            StoreFixture.updateContinuation?.yield(.verified(Transaction(id, revoked: true))); await settle()
            check(!manager.hasRemovedAds && manager.adEntitlementStatus == .unknown, "revoked owner waits fresh snapshot")
            held?.finish(); await settle()
            check(manager.adEntitlementStatus == .nonOwner, "fresh verified snapshot permits nonowner after revocation")
        case "revocation-during-finish":
            check(manager.hasRemovedAds, "owner recognized before transaction finish resumes")
            StoreFixture.updateContinuation?.yield(.verified(Transaction(id, revoked: true))); await settle()
            check(manager.adEntitlementStatus == .nonOwner && !manager.hasRemovedAds, "revocation refresh completes despite old finish suspended")
            StoreFixture.finishContinuation?.resume(); await settle()
            check(!manager.hasRemovedAds, "old cancelled scan cannot regrant revoked owner")
        case "pending":
            StoreFixture.purchaseResult = .pending
            let bought = await manager.purchaseRemoveAds()
            check(!bought && manager.adEntitlementStatus == .unknown, "pending purchase is not ownership or nonownership")
            StoreFixture.updateContinuation?.yield(.verified(Transaction(id))); await settle()
            check(manager.hasRemovedAds, "approval update supplies free benefits")
        default: fatalError("unknown test")
        }
        print("PASS: IAP \(name): \(count) assertions (actual body, StoreKit fake)")
    }
}
