//
//  WidgetEntitlementReader.swift
//  SaxWeatherWidget
//
//  Phase 2 — Widget-side read-only mirror of the host app's
//  cosmetic entitlements.
//
//  Why a separate reader?
//  -----------------------
//  Widget extensions cannot import the host app's modules,
//  so `EntitlementStore` (and its supporting types) isn't
//  reachable from `SaxWeatherWidget`. Instead we read the
//  same App Group `UserDefaults` suite the host writes to
//  (`EntitlementStore.persistenceKey` under the suite
//  `WidgetSharedConfig.appGroupSuiteName`) and answer the
//  same question — "does the user own product X?" — with the
//  same Supporter-Pack short-circuit.
//
//  This is a *foundation-only* type. Phase 4 will drop a
//  widget-side intent picker on top of it; today the reader
//  is reachable but unused in production widget code paths.
//

import Foundation

/// Read-only mirror of the host app's cosmetic entitlement
/// set, suitable for use from the widget extension.
///
/// Construct one on demand — it has no state, just a small
/// lookup. Or call `WidgetEntitlementReader.shared` for the
/// static-singleton convenience that mirrors the host's
/// `EntitlementStore.shared` shape.
///
/// Thread-safety: this type is stateless apart from the
/// shared `UserDefaults` suite, which is itself thread-safe.
struct WidgetEntitlementReader {

    /// The product ID used to short-circuit ownership when
    /// the user owns the Supporter Pack. Duplicated from
    /// `CosmeticCatalog.supporterPackID` so this file stays
    /// decoupled from the host module.
    static let supporterPackID = "com.saxweather.cosmetic.supporter.pack"

    /// The UserDefaults key the host writes its owned-product
    /// set under. Mirrors `EntitlementStore.persistenceKey`.
    static let persistenceKey = "ownedCosmeticProductIDs"

    /// The App Group suite the host writes through. Matches
    /// `WidgetSharedConfig.appGroupSuiteName` and the host
    /// entitlements file.
    static let appGroupSuiteName = "group.com.saxobroko.SaxWeather"

    /// Read the owned product set straight from the shared
    /// App Group suite. Returns an empty set when the suite
    /// is unreachable (e.g. the widget entitlement isn't wired
    /// up in the build settings) so callers can keep rendering
    /// with their free defaults.
    static func loadOwnedProductIDs() -> Set<String> {
        let defaults = UserDefaults(suiteName: appGroupSuiteName)
        let stored = defaults?.stringArray(forKey: persistenceKey) ?? []
        return Set(stored)
    }

    /// `true` when the user owns the given product — either
    /// directly or via the Supporter Pack short-circuit.
    ///
    /// Reads from the shared App Group suite on every call
    /// (cheap — `UserDefaults` is in-memory after first
    /// access). Callers should call this once per render
    /// rather than caching the answer, so a fresh purchase in
    /// the host app picks up after the next widget reload.
    static func isOwned(_ productID: String) -> Bool {
        let owned = loadOwnedProductIDs()
        if owned.contains(productID) { return true }
        if owned.contains(supporterPackID) { return true }
        return false
    }
}