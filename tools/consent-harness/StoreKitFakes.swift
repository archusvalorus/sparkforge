// Explicit transport fakes for executing the real IAPManager body on the host.
import Foundation

enum VerificationResult<T> { case verified(T), unverified(T, Error) }
@MainActor enum StoreFixture {
    static var snapshots: [AsyncStream<VerificationResult<Transaction>>] = []
    static var snapshotCalls = 0
    static var productsCalls = 0
    static var updateCalls = 0
    static var updateContinuation: AsyncStream<VerificationResult<Transaction>>.Continuation?
    static var purchaseResult: Product.PurchaseResult = .userCancelled
    static var purchaseError = false
    static var purchaseCalls = 0
    static var syncCalls = 0
    static var syncError = false
    static var syncContinuation: CheckedContinuation<Void, Error>?
    static var holdSync = false
    static var holdFinish = false
    static var finishContinuation: CheckedContinuation<Void, Never>?
    static let updates = AsyncStream<VerificationResult<Transaction>> { updateContinuation = $0 }
    static func snapshot(_ values: [VerificationResult<Transaction>]) -> AsyncStream<VerificationResult<Transaction>> {
        AsyncStream { c in for v in values { c.yield(v) }; c.finish() }
    }
}
@MainActor final class Transaction {
    let productID: String
    let revocationDate: Date?
    init(_ id: String, revoked: Bool = false) { productID = id; revocationDate = revoked ? Date() : nil }
    static var currentEntitlements: AsyncStream<VerificationResult<Transaction>> {
        StoreFixture.snapshotCalls += 1
        if !StoreFixture.snapshots.isEmpty { return StoreFixture.snapshots.removeFirst() }
        return StoreFixture.snapshot([])
    }
    static var updates: AsyncStream<VerificationResult<Transaction>> { StoreFixture.updateCalls += 1; return StoreFixture.updates }
    func finish() async {
        if StoreFixture.holdFinish {
            StoreFixture.holdFinish = false
            await withCheckedContinuation { StoreFixture.finishContinuation = $0 }
        }
    }
}
@MainActor struct Product {
    enum PurchaseResult { case success(VerificationResult<Transaction>), userCancelled, pending }
    let id: String
    var displayPrice: String { "$0.00 TEST" }
    static func products(for ids: [String]) async throws -> [Product] {
        StoreFixture.productsCalls += 1
        if StoreFixture.purchaseError { throw NSError(domain: "SFTest", code: 1) }
        return ids.map { Product(id: $0) }
    }
    func purchase() async throws -> PurchaseResult { StoreFixture.purchaseCalls += 1; return StoreFixture.purchaseResult }
}
@MainActor enum AppStore {
    static func sync() async throws {
        StoreFixture.syncCalls += 1
        if StoreFixture.syncError { throw NSError(domain: "SFTest", code: 2) }
        if StoreFixture.holdSync { try await withCheckedThrowingContinuation { StoreFixture.syncContinuation = $0 } }
    }
}
