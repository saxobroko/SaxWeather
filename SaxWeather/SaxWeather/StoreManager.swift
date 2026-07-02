//
//  StoreManager.swift
//  SaxWeather
//
//  StoreKit 2 facade for every IAP the app sells.
//
//  Two independent product streams
//  -------------------------------
//  1. The legacy single product `"CustomBackground50c"` — a
//     non-consumable IAP that unlocks the custom-background
//     UI. Loaded and purchased via `loadProducts()` /
//     `purchaseCustomBackground()`. The Tip Jar (see
//     [`TipJarView.swift`](TipJarView.swift)) uses its own
//     self-contained `TipStoreManager` and is NOT wired into
//     this class — that's intentional; tips are consumables
//     and don't need an entitlement cache.
//  2. Cosmetic non-consumables — every product ID in
//     [`CosmeticCatalog`](Services/CosmeticCatalog.swift) is
//     loaded via `loadCosmeticProducts()` and purchased via
//     `purchaseCosmetic(_:)`. Entitlements are mirrored into
//     `entitlementStore` for the UI to read on every render.
//
//  Entitlement model
//  -----------------
//  The authoritative source for "did the user buy this?" is
//  StoreKit 2's `Transaction.currentEntitlements`. We mirror
//  the verified transactions into
//  [`EntitlementStore`](Services/EntitlementStore.swift) on:
//    * app launch (initial query)
//    * every `Transaction.updates` event (backgrounded app)
//    * every successful `purchaseCosmetic` call
//    * every successful `purchaseCustomBackground` call
//
//  The `EntitlementStore` is the **only** place the Supporter
//  Pack short-circuit lives — see the file's header comment.
//

import SwiftUI
import StoreKit

/// Result of a purchase attempt, exposed to the UI layer. The
/// raw `VerificationResult<StoreKit.Transaction>` is internal —
/// callers don't need to know about JWS verification.
enum PurchaseResult: Equatable {
    /// The product was purchased (or was already owned and
    /// restored) and the entitlement is now granted.
    case success
    /// The user explicitly cancelled the purchase sheet.
    case cancelled
    /// The purchase is awaiting approval (e.g. Ask to Buy).
    /// The entitlement will be granted when the transaction
    /// resolves — see the `Transaction.updates` loop.
    case pending
    /// The purchase failed. The associated `String` is a
    /// user-facing error message.
    case failed(String)
}

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    // MARK: - Legacy IAP (CustomBackground50c)
    //
    // The single non-cosmetic IAP the app sells. Kept as
    // a separate field pair so the existing TipJar /
    // BackgroundSettingsView code paths keep working without
    // any API changes.
    private let legacyProductID = "CustomBackground50c"

    /// `true` when the user owns the legacy "Custom
    /// Backgrounds" IAP. Backed by `entitlementStore` — the
    /// field is a computed view so a single source of truth
    /// owns the answer.
    var customBackgroundUnlocked: Bool {
        entitlementStore.isOwned(legacyProductID)
    }

    /// The legacy Custom Backgrounds product, loaded from
    /// `configuration.storekit`. The `BackgroundSettingsView`
    /// uses this to show the Buy button.
    @Published private(set) var products: [Product] = []

    // MARK: - Cosmetic IAPs
    //
    // Every product ID in `CosmeticCatalog.allProducts` is
    // loaded into `cosmeticProducts`. The store UI looks
    // products up by ID via `cosmeticProduct(id:)` and reads
    // the localised `displayPrice` from the StoreKit product.
    @Published private(set) var cosmeticProducts: [Product] = []
    private var cosmeticProductsByID: [String: Product] = [:]

    /// Shared entitlement cache. Read by the store UI to show
    /// the "Owned ✓" badge, read by `BackgroundResolver` (via
    /// `customBackgroundUnlocked`) to gate paid backgrounds,
    /// and read by `SettingsView`'s About section to surface
    /// the Supporter Badge.
    let entitlementStore: EntitlementStore

    // MARK: - Per-product purchase state
    //
    // The legacy `purchaseInProgress: Bool` covered a single
    // purchase at a time; cosmetics need per-product spinners
    // because the store tile UI shows an in-flight indicator
    // on the specific tile being purchased.
    @Published var purchaseInProgress: Bool = false
    /// The product ID currently being purchased, or `nil` if
    /// no purchase is in flight. Drives the per-tile spinner
    /// in the cosmetics store.
    @Published var purchaseInProgressID: String? = nil
    @Published var purchaseError: String?

    // MARK: - Init

    private init() {
        // The `EntitlementStore` is owned by the
        // `StoreManager` so the cache lifecycle matches
        // the store lifecycle. We instantiate it here in
        // the init body (which is `@MainActor`-isolated)
        // rather than as a default parameter value
        // (which would be evaluated in a nonisolated
        // context and fail to compile).
        self.entitlementStore = EntitlementStore()

        Task {
            // Bootstrap every product stream. Order matters
            // only for human readability — each loader is
            // independent and the UI tolerates any order.
            await loadProducts()
            await loadCosmeticProducts()
            await refreshEntitlements()
        }

        // Listen for transactions in real-time. This is the
        // path that catches Ask-to-Buy approvals, refunds,
        // and Family Sharing revocations, and it also
        // delivers the transaction for any purchase the user
        // completed while the app was backgrounded.
        Task {
            for await result in StoreKit.Transaction.updates {
                await self.handleTransactionResult(result)
            }
        }
    }

    // MARK: - Legacy IAP — Custom Backgrounds

    /// Load the legacy single product (CustomBackground50c).
    /// Kept for backward compatibility with the existing
    /// `BackgroundSettingsView`.
    func loadProducts() async {
        do {
            #if DEBUG
            print("🔍 Attempting to load product with ID: \(legacyProductID)")
            #endif

            let storeProducts = try await Product.products(for: [legacyProductID])

            self.products = storeProducts

            if storeProducts.isEmpty {
                #if DEBUG
                print("⚠️ No products found with ID: \(legacyProductID)")
                #endif
                self.purchaseError = "Product not found. Check configuration."
            } else {
                #if DEBUG
                print("✅ Successfully loaded \(storeProducts.count) products")
                for product in storeProducts {
                    print("📦 Found: \(product.id) - \(product.displayName)")
                }
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Error loading products: \(error)")
            #endif
            self.purchaseError = "Error: \(error.localizedDescription)"
        }
    }

    /// Purchase the legacy "Custom Backgrounds" IAP. Preserved
    /// as-is from the original implementation — the Tip Jar
    /// still uses it via the in-file `TipStoreManager`.
    func purchaseCustomBackground() async {
        guard let product = products.first(where: { $0.id == legacyProductID }) else {
            purchaseError = "Product not found"
            return
        }

        purchaseInProgress = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    entitlementStore.grant(legacyProductID)
                    await transaction.finish()
                    #if DEBUG
                    print("Purchase successful")
                    #endif
                } else {
                    purchaseError = "Transaction verification failed"
                }
            case .userCancelled:
                #if DEBUG
                print("User cancelled")
                #endif
            case .pending:
                purchaseError = "Purchase pending approval"
            @unknown default:
                purchaseError = "Unknown purchase result"
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            #if DEBUG
            print("Purchase error: \(error)")
            #endif
        }

        purchaseInProgress = false
    }

    // MARK: - Cosmetic IAPs

    /// Load every cosmetic product declared in
    /// `CosmeticCatalog.allProducts`. Called once on init; the
    /// UI can re-call this after a "Restore Purchases" to
    /// pick up products added in a newer App Store Connect
    /// schema.
    func loadCosmeticProducts() async {
        let ids = CosmeticCatalog.allProducts.map(\.id)
        do {
            #if DEBUG
            print("🔍 Loading \(ids.count) cosmetic products from StoreKit")
            #endif
            let loaded = try await Product.products(for: ids)
            self.cosmeticProducts = loaded
            self.cosmeticProductsByID = Dictionary(
                uniqueKeysWithValues: loaded.map { ($0.id, $0) }
            )
            #if DEBUG
            print("✅ Loaded \(loaded.count) cosmetic products")
            for product in loaded {
                print("   • \(product.id) — \(product.displayPrice)")
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to load cosmetic products: \(error)")
            #endif
            // Non-fatal — the store UI falls back to the
            // catalog's static `priceCents` when no StoreKit
            // product is available.
        }
    }

    /// Look up a loaded StoreKit product by ID. Returns
    /// `nil` for products that haven't loaded yet (or that
    /// aren't shipped). Use `CosmeticCatalog.product(id:)`
    /// for the static catalog data instead.
    func cosmeticProduct(id: String) -> Product? {
        cosmeticProductsByID[id]
    }

    /// Purchase a cosmetic product. On success, the
    /// `EntitlementStore` is updated synchronously and a
    /// `cosmeticPurchaseCompleted` notification is posted so
    /// any observers can react.
    ///
    /// - Throws: StoreKit errors propagate. UI code should
    ///   catch them and surface a friendly message.
    @discardableResult
    func purchaseCosmetic(_ product: Product) async throws -> PurchaseResult {
        purchaseInProgressID = product.id
        purchaseError = nil
        defer {
            purchaseInProgressID = nil
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                entitlementStore.grant(product.id)
                await transaction.finish()
                NotificationCenter.default.post(
                    name: Self.cosmeticPurchaseCompleted,
                    object: self,
                    userInfo: ["productID": product.id]
                )
                return .success
            case .unverified:
                return .failed("Transaction verification failed")
            }
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .failed("Unknown purchase result")
        }
    }

    // MARK: - Entitlement refresh

    /// Walk `Transaction.currentEntitlements` and grant every
    /// non-consumable product ID the user actually owns. Safe
    /// to call multiple times — `EntitlementStore.grant` is
    /// idempotent.
    ///
    /// Covers the legacy `CustomBackground50c` IAP as well as
    /// every cosmetic product. Unknown product IDs are
    /// silently skipped (forward-compatibility — a product
    /// added in a newer version that this build doesn't
    /// recognise won't crash older builds).
    func refreshEntitlements() async {
        let knownIDs: Set<String> = Set(CosmeticCatalog.allProducts.map(\.id))
            .union([legacyProductID])

        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                #if DEBUG
                print("⚠️ Skipping unverified transaction \(result)")
                #endif
                continue
            }
            // Only grant products we know about. This keeps
            // the cache clean and makes a missing product ID
            // visible (e.g. one removed from the catalog).
            guard knownIDs.contains(transaction.productID) else {
                #if DEBUG
                print("ℹ️ Ignoring unknown product ID: \(transaction.productID)")
                #endif
                continue
            }
            // A `.revoked` transaction means the user got a
            // refund or lost Family Sharing. Drop the
            // entitlement from the cache.
            if transaction.revocationDate != nil {
                #if DEBUG
                print("ℹ️ Transaction revoked: \(transaction.productID)")
                #endif
                #if DEBUG
                entitlementStore.revoke(transaction.productID)
                #endif
            } else {
                entitlementStore.grant(transaction.productID)
            }
            await transaction.finish()
        }
    }

    /// Single-transaction handler for the `Transaction.updates`
    /// listener. Applies the same logic as
    /// `refreshEntitlements()` but for one transaction at a
    /// time — so backgrounded apps receive Ask-to-Buy
    /// approvals, refunds, and Family Sharing changes
    /// immediately.
    private func handleTransactionResult(
        _ result: VerificationResult<StoreKit.Transaction>
    ) async {
        guard case .verified(let transaction) = result else {
            #if DEBUG
            print("⚠️ Skipping unverified transaction update")
            #endif
            return
        }
        let knownIDs: Set<String> = Set(CosmeticCatalog.allProducts.map(\.id))
            .union([legacyProductID])
        guard knownIDs.contains(transaction.productID) else { return }

        if transaction.revocationDate != nil {
            #if DEBUG
            entitlementStore.revoke(transaction.productID)
            #endif
        } else {
            entitlementStore.grant(transaction.productID)
        }
        await transaction.finish()

        // Tell the UI a transaction just landed so any
        // "loading…" placeholders can refresh.
        NotificationCenter.default.post(
            name: Self.cosmeticEntitlementsChanged,
            object: self,
            userInfo: ["productID": transaction.productID]
        )
    }

    // MARK: - Ownership helpers (Supporter Pack short-circuit)
    //
    // The single line that turns the Supporter Pack's "every
    // current and every future cosmetic" promise into a
    // one-line implementation lives in
    // `EntitlementStore.isOwned(_:)`. The helpers below are
    // thin pass-throughs so SwiftUI views can write
    // `storeManager.owns(product)` without having to know
    // about the entitlement cache directly.
    func owns(_ productID: String) -> Bool {
        entitlementStore.isOwned(productID)
    }
    func owns(_ product: CosmeticProduct) -> Bool {
        entitlementStore.isOwned(product)
    }

    // MARK: - Restore purchases

    /// Restore every non-consumable the user owns. Triggers
    /// an `AppStore.sync()` (Apple's prompt to re-fetch
    /// receipts) and re-walks `Transaction.currentEntitlements`.
    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            #if DEBUG
            print("⚠️ AppStore.sync() failed: \(error)")
            #endif
            // Continue anyway — `refreshEntitlements` will
            // still pick up whatever the device has cached.
        }
        await refreshEntitlements()
    }

    // MARK: - Notifications

    /// Posted after `purchaseCosmetic` succeeds. The UI
    /// listens to dismiss the purchase sheet, scroll the
    /// newly-owned tile into view, and re-render the
    /// "Owned ✓" badge.
    static let cosmeticPurchaseCompleted = Notification.Name(
        "StoreManager.cosmeticPurchaseCompleted"
    )

    /// Posted when the `Transaction.updates` loop processes a
    /// new verified transaction. Used to keep derived UI
    /// state (e.g. the Supporter Badge in About) in sync with
    /// the entitlement cache.
    static let cosmeticEntitlementsChanged = Notification.Name(
        "StoreManager.cosmeticEntitlementsChanged"
    )
}
