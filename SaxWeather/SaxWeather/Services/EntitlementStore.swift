//
//  EntitlementStore.swift
//  SaxWeather
//
//  Phase 1 — Cosmetic-only monetization foundation.
//  Phase 2 — refactored to write through a `Persistence`
//            protocol backed by the App Group `UserDefaults`
//            suite so the widget extension can read the same
//            owned-product set without `UserDefaults.standard`
//            divergence.
//
//  The client-side entitlement cache. The *authoritative*
//  source for whether the user owns a product is StoreKit 2's
//  `Transaction.currentEntitlements`; this class is just a
//  fast, observable in-memory cache that the UI can read on
//  every render without hitting StoreKit.
//
//  Persistence
//  -----------
//  Phase 2 — the cache is mirrored to the shared App Group
//  `UserDefaults` suite (`group.com.saxobroko.SaxWeather`)
//  under the key `ownedCosmeticProductIDs`. Two consumers
//  read this key:
//
//    1. The host app — same as before, so the UI can render
//       the correct "Owned" state on the very first frame
//       after launch, before StoreKit finishes its initial
//       query.
//    2. The widget extension — `WidgetEntitlementReader`
//       reads the same key from the same suite to resolve
//       widget-side cosmetic state (Phase 2: foundation
//       only; the actual picker UI ships in Phase 4).
//
//  Before Phase 2 the key was written to `UserDefaults.standard`,
//  which is *not* visible to the widget process — that's the
//  bug this refactor fixes. If the App Group suite is
//  unavailable for any reason (mis-configured entitlement,
//  simulator quirk), we fall back to `UserDefaults.standard`
//  so the host app keeps working.
//
//  The Supporter Pack short-circuit
//  --------------------------------
//  `isOwned(_:)` returns `true` for every product ID when the
//  user owns `CosmeticCatalog.supporterPackID`. This single
//  line is what implements the "every current and every future
//  cosmetic" promise from
//  `plans/COSMETIC_MONETIZATION_PLAN.md` §3.8: when a new
//  cosmetic is added in a future version, no `isOwned` call
//  site needs to change — the short-circuit already returns
//  `true` for the new ID.
//
//  The `Persistence` protocol
//  --------------------------
//  A minimal protocol abstracts the read/write pair so unit
//  tests can swap in `InMemoryPersistence` (no `UserDefaults`
//  pollution, no App Group reliance). The production default
//  is `AppGroupUserDefaultsPersistence`, which writes through
//  to `UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")`.
//

import Foundation
import Combine

/// Storage for the owned-product set. Implementations only
/// need to round-trip `Set<String>` through `UserDefaults`
/// (or an equivalent key/value store). The protocol exists so
/// tests can inject an in-memory backend and so the widget
/// extension can share the same shape when we eventually
/// consolidate the read paths.
protocol EntitlementPersistence: AnyObject {
    /// Read the persisted set. Returns an empty set when no
    /// value has been written yet (or when the underlying
    /// store is unreachable).
    func loadOwnedProductIDs() -> Set<String>

    /// Persist `ownedProductIDs` to whatever store the
    /// implementation wraps. Implementations should be
    /// synchronous — `EntitlementStore.grant(_:)` calls this
    /// inline so a UI render immediately after a purchase
    /// sees the new value.
    func saveOwnedProductIDs(_ ids: Set<String>)
}

/// Production persistence — writes the owned-product set to
/// the App Group `UserDefaults` suite so the widget extension
/// can read it. Falls back to `UserDefaults.standard` when
/// the suite is unreachable so the host app keeps working.
final class AppGroupEntitlementPersistence: EntitlementPersistence {
    /// Same suite used by `WidgetSharedConfig` and the
    /// `SaxWeather.entitlements` file. Hard-coded (rather
    /// than read from the entitlement at runtime) so the
    /// value is testable without booting the app.
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

/// Observable cache of which cosmetic product IDs the user
/// owns. Authoritative source is StoreKit 2's
/// `Transaction.currentEntitlements`; this class is the
/// client-side mirror the UI reads.
@MainActor
final class EntitlementStore: ObservableObject {

    /// The set of product IDs the user currently owns. Includes
    /// the Supporter Pack ID when owned — see `isOwned(_:)`
    /// for the short-circuit.
    @Published private(set) var ownedProductIDs: Set<String> = []

    /// The UserDefaults key the cache is persisted under.
    /// Exposed as a constant so tests can clear it (on
    /// either the App Group suite or `.standard`, depending
    /// on which `Persistence` is in play).
    static let persistenceKey = "ownedCosmeticProductIDs"

    /// `true` after the initial `loadFromDisk()` has run.
    /// The UI can use this to render an "Owned" badge
    /// immediately on launch instead of showing a flicker of
    /// the "Buy" state.
    @Published private(set) var hasLoadedFromDisk: Bool = false

    /// The persistence backend. Production defaults to the
    /// App Group suite (see `AppGroupEntitlementPersistence`);
    /// tests inject `InMemoryEntitlementPersistence`.
    private let persistence: EntitlementPersistence

    // MARK: - Init

    /// Production init — uses the App Group persistence
    /// backend. The widget extension reads the same suite
    /// via `WidgetEntitlementReader`.
    convenience init() {
        self.init(persistence: AppGroupEntitlementPersistence())
    }

    /// Designated init. Accepts any `EntitlementPersistence`
    /// so tests can inject an in-memory backend and the
    /// widget can later share the same logic with a
    /// shared-suit reader.
    init(persistence: EntitlementPersistence) {
        self.persistence = persistence
        loadFromDisk()
    }

    // MARK: - Read

    /// `true` if the user owns the given product, OR owns the
    /// Supporter Pack. This is the **single short-circuit** that
    /// turns the Supporter Pack's promise into a one-line
    /// implementation — see the file header for context.
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

    /// Remove `productID` from the owned set. **DEBUG-only** —
    /// production code never revokes entitlements directly;
    /// StoreKit tells us when a transaction is revoked (refund,
    /// family-sharing change, etc.) via `Transaction.updates`.
    #if DEBUG
    func revoke(_ productID: String) {
        guard ownedProductIDs.contains(productID) else { return }
        ownedProductIDs.remove(productID)
        persist()
    }
    #endif

    /// Reset the entire cache. **DEBUG-only.** Used by the
    /// debug "Reset Cosmetics" affordance (or by tests).
    #if DEBUG
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

#if DEBUG
/// `EntitlementPersistence` backed by a plain dictionary.
/// Tests use this so they don't need a live App Group suite
/// (and don't pollute `UserDefaults`).
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
