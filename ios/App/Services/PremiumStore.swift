import Foundation
import StoreKit
import Observation

// Revenue model: free with banner ads, one-time "Premium" IAP removes ads
// (best fit for the TR market — low willingness to subscribe, ads carry the
// free tier). StoreKit 2, same pattern as the Snowplan app.

@Observable
@MainActor
final class PremiumStore {
    static let productID = "com.onurkuru.bistradar.premium"

    private(set) var isPremium = false
    private(set) var product: Product?
    private(set) var isPurchasing = false
    var lastError: String?

    private var updatesTask: Task<Void, Never>?

    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task {
            for await update in Transaction.updates {
                if let t = try? update.payloadValue { await t.finish(); await refresh() }
            }
        }
        Task { await refresh(); await loadProduct() }
    }

    func loadProduct() async {
        product = try? await Product.products(for: [Self.productID]).first
    }

    func refresh() async {
        var owned = false
        for await entitlement in Transaction.currentEntitlements {
            if let t = try? entitlement.payloadValue, t.productID == Self.productID, t.revocationDate == nil {
                owned = true
            }
        }
        isPremium = owned
    }

    func purchase() async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if case .success(let v) = try await product.purchase(), let t = try? v.payloadValue {
                await t.finish(); await refresh()
            }
        } catch { lastError = error.localizedDescription }
    }

    func restore() async {
        try? await AppStore.sync(); await refresh()
    }
}
