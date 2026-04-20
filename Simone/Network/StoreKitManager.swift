import Foundation
import Observation
import StoreKit

@Observable
final class StoreKitManager {
    private(set) var products: [Product] = []
    private(set) var purchasedTier: Tier = .flow
    private(set) var lastError: String? = nil

    private var updatesTask: Task<Void, Never>? = nil

    deinit { updatesTask?.cancel() }

    func start() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await self.loadProducts() }
        Task { await self.refreshEntitlements() }
    }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: ProductID.all)
            await MainActor.run { self.products = loaded.sorted { $0.id < $1.id } }
        } catch {
            await MainActor.run { self.lastError = "loadProducts: \(error.localizedDescription)" }
        }
    }

    func purchase(_ product: Product) async throws -> Tier? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let tx = try checkVerified(verification)
            await tx.finish()
            await refreshEntitlements()
            return ProductID.tier(for: product.id)
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var best: Tier = .flow
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let tx) = entitlement else { continue }
            if let tier = ProductID.tier(for: tx.productID), tier > best {
                best = tier
            }
        }
        await MainActor.run { self.purchasedTier = best }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let tx) = result else { return }
        await tx.finish()
        await refreshEntitlements()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
