
import Foundation
import Combine

protocol EntitlementPersistence: AnyObject {
    /// Read the persisted set. Returns an empty set when no
    /// value has been written yet (or when the underlying
    /// store is unreachable).
    func loadOwnedProductIDs() -> Set<String>

    func saveOwnedProductIDs(_ ids: Set<String>)
}

final class AppGroupEntitlementPersistence: EntitlementPersistence {
    static let appGroupSuiteName = "group.com.saxobroko.SaxWeather"

    /// The `UserDefaults` instance we'll write to. Held as a
    /// property so an injected test fake can swap it out.
    private let defaults: UserDefaults

    /// Designated init — defaults to the App Group suite.
    /// Pass an explicit `UserDefaults` (e.g. `.standard`) for
    /// tests that want to inspect the bytes written.
    init(defaults: UserDefaults? = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")) {
        // Prefer the App Group suite; fall back to standard if
        // the suite can't be opened (typical on simulators
        // without the entitlement wired up).
        self.defaults = defaults ?? .standard
    }

    func loadOwnedProductIDs() -> Set<String> {
        let stored = defaults.stringArray(forKey: EntitlementStore.persistenceKey) ?? []
        return Set(stored)
    }

    func saveOwnedProductIDs(_ ids: Set<String>) {
        defaults.set(Array(ids), forKey: EntitlementStore.persistenceKey)
    }
}

@MainActor
final class EntitlementStore: ObservableObject {

    /// The set of product IDs the user currently owns. Includes
    /// the Supporter Pack ID when owned — see `isOwned(_:)`
    /// for the short-circuit.
    @Published private(set) var ownedProductIDs: Set<String> = []

    static let persistenceKey = "ownedCosmeticProductIDs"

    @Published private(set) var hasLoadedFromDisk: Bool = false

    private let persistence: EntitlementPersistence

    // MARK: - Init

    /// Production init — uses the App Group persistence
    /// backend. The widget extension reads the same suite
    /// via `WidgetEntitlementReader`.
    convenience init() {
        self.init(persistence: AppGroupEntitlementPersistence())
    }

    init(persistence: EntitlementPersistence) {
        self.persistence = persistence
        loadFromDisk()
    }

    // MARK: - Read

    func isOwned(_ productID: String) -> Bool {
        if ownedProductIDs.contains(productID) { return true }
        if ownedProductIDs.contains(CosmeticCatalog.supporterPackID) {
            return true
        }
        return false
    }

    /// Convenience overload — reads the same way as the
    /// `String` variant. Useful in SwiftUI views that already
    /// have a `CosmeticProduct` in scope.
    func isOwned(_ product: CosmeticProduct) -> Bool {
        isOwned(product.id)
    }

    /// `true` if the user owns the Supporter Pack. Used by the
    /// auto-unlock helper for the Supporter Badge — see
    /// `ownsBadgeForSupporterPack(_:)` below.
    static func ownsBadgeForSupporterPack(_ ownedIDs: Set<String>) -> Bool {
        ownedIDs.contains(CosmeticCatalog.supporterPackID)
    }

    // MARK: - Write

    /// Add `productID` to the owned set and persist. Idempotent
    /// — calling twice with the same ID is a no-op apart from
    /// the persistence write.
    func grant(_ productID: String) {
        guard !ownedProductIDs.contains(productID) else { return }
        ownedProductIDs.insert(productID)
        persist()
    }

    #if DEBUG || TESTING
    func revoke(_ productID: String) {
        guard ownedProductIDs.contains(productID) else { return }
        ownedProductIDs.remove(productID)
        persist()
    }
    #endif

    /// Reset the entire cache. **DEBUG-only.** Used by the
    /// debug "Reset Cosmetics" affordance (or by tests).
    #if DEBUG || TESTING
    func resetAll() {
        ownedProductIDs.removeAll()
        persist()
    }
    #endif

    // MARK: - Persistence

    /// Read the persisted cache from the persistence backend
    /// and load it into `ownedProductIDs`. Idempotent.
    func loadFromDisk() {
        ownedProductIDs = persistence.loadOwnedProductIDs()
        hasLoadedFromDisk = true
    }

    /// Persist `ownedProductIDs` via the persistence backend.
    private func persist() {
        persistence.saveOwnedProductIDs(ownedProductIDs)
    }
}

// MARK: - In-memory persistence (test-only)

#if DEBUG || TESTING
final class InMemoryEntitlementPersistence: EntitlementPersistence {
    private var storage: Set<String>

    init(initial: Set<String> = []) {
        self.storage = initial
    }

    func loadOwnedProductIDs() -> Set<String> {
        storage
    }

    func saveOwnedProductIDs(_ ids: Set<String>) {
        storage = ids
    }
}
#endif
