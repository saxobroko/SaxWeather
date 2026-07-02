//
//  EntitlementStoreTests.swift
//  SaxWeatherTests
//
//  Phase 1 — Cosmetic-only monetization foundation tests.
//  Phase 2 — refactored to use `InMemoryEntitlementPersistence`
//            for hermetic tests (no `UserDefaults` pollution,
//            no App Group suite reliance) and to cover the
//            shared App Group `UserDefaults` suite path the
//            widget extension reads from.
//
//  Covers:
//   • Direct ownership (`grant` + `isOwned`).
//   • The Supporter Pack short-circuit — owning the
//     Supporter Pack reports `isOwned == true` for every
//     other product without any explicit grant.
//   • Persistence across instances via the `Persistence`
//     protocol abstraction.
//   • The App Group `UserDefaults` suite is the default
//     production backend.
//   • The `revoke` / `resetAll` DEBUG-only methods.
//

import XCTest
@testable import SaxWeather

@MainActor
final class EntitlementStoreTests: XCTestCase {

    // MARK: - Setup / teardown

    override func setUp() async throws {
        // Clear BOTH possible persistence backends so a test
        // using `InMemoryPersistence` doesn't leak into one
        // using the App Group suite (or vice versa).
        let appGroup = UserDefaults(suiteName: AppGroupEntitlementPersistence.appGroupSuiteName)
        appGroup?.removeObject(forKey: EntitlementStore.persistenceKey)
        UserDefaults.standard.removeObject(forKey: EntitlementStore.persistenceKey)
    }

    override func tearDown() async throws {
        let appGroup = UserDefaults(suiteName: AppGroupEntitlementPersistence.appGroupSuiteName)
        appGroup?.removeObject(forKey: EntitlementStore.persistenceKey)
        UserDefaults.standard.removeObject(forKey: EntitlementStore.persistenceKey)
    }

    // MARK: - Direct ownership

    func test_ownsProduct_directly() {
        let store = EntitlementStore(persistence: InMemoryEntitlementPersistence())
        XCTAssertFalse(store.isOwned("com.saxweather.cosmetic.aurora.backgrounds"),
                       "fresh store should not own anything")
        store.grant("com.saxweather.cosmetic.aurora.backgrounds")
        XCTAssertTrue(store.isOwned("com.saxweather.cosmetic.aurora.backgrounds"),
                      "after grant, the store should report ownership")
    }

    func test_doesNotOwn_unownedProduct() {
        let store = EntitlementStore(persistence: InMemoryEntitlementPersistence())
        XCTAssertFalse(store.isOwned("com.saxweather.cosmetic.aurora.backgrounds"))
        XCTAssertFalse(store.isOwned(CosmeticCatalog.supporterPackID))
        XCTAssertFalse(store.isOwned("never.heard.of.it"))
    }

    // MARK: - Supporter Pack short-circuit

    func test_ownsProduct_viaSupporterPack_shortCircuit() {
        let store = EntitlementStore(persistence: InMemoryEntitlementPersistence())
        // Grant only the Supporter Pack. The short-circuit
        // should report `isOwned == true` for every other
        // product ID — even IDs that don't exist yet.
        store.grant(CosmeticCatalog.supporterPackID)

        XCTAssertTrue(store.isOwned(CosmeticCatalog.supporterPackID),
                      "the Supporter Pack itself is owned")
        XCTAssertTrue(store.isOwned("com.saxweather.cosmetic.aurora.backgrounds"),
                      "Supporter Pack short-circuits Aurora Backgrounds")
        XCTAssertTrue(store.isOwned("com.saxweather.cosmetic.aurora.palette"),
                      "Supporter Pack short-circuits Aurora Palette")
        XCTAssertTrue(store.isOwned("com.saxweather.cosmetic.supporter.badge"),
                      "Supporter Pack short-circuits the Supporter Badge")
        XCTAssertTrue(store.isOwned("com.saxweather.cosmetic.future.never.shipped"),
                      "Supporter Pack short-circuits unknown future products — this is the 'every future cosmetic' promise")
    }

    func test_ownsBadgeForSupporterPack_helper() {
        // Direct test of the static helper used by the
        // auto-unlock logic in `CosmeticCatalog`.
        XCTAssertFalse(
            EntitlementStore.ownsBadgeForSupporterPack([])
        )
        XCTAssertFalse(
            EntitlementStore.ownsBadgeForSupporterPack(["com.saxweather.cosmetic.aurora.backgrounds"])
        )
        XCTAssertTrue(
            EntitlementStore.ownsBadgeForSupporterPack([CosmeticCatalog.supporterPackID])
        )
    }

    // MARK: - Persistence (in-memory backend)

    func test_grant_persistsAcrossInstances_viaInMemoryBackend() {
        let persistence = InMemoryEntitlementPersistence()
        let firstStore = EntitlementStore(persistence: persistence)
        firstStore.grant("com.saxweather.cosmetic.aurora.backgrounds")
        // The grant should have hit the in-memory backend
        // already (the `saveOwnedProductIDs(_:)` call in
        // `grant` is synchronous).
        let secondStore = EntitlementStore(persistence: persistence)
        XCTAssertTrue(
            secondStore.isOwned("com.saxweather.cosmetic.aurora.backgrounds"),
            "a fresh EntitlementStore should hydrate from the same Persistence and see the prior grant"
        )
    }

    func test_loadFromDisk_setsHasLoadedFlag() {
        let store = EntitlementStore(persistence: InMemoryEntitlementPersistence())
        XCTAssertTrue(store.hasLoadedFromDisk,
                      "init should call loadFromDisk and set the flag")
    }

    // MARK: - App Group persistence (production backend)

    func test_defaultInit_writesToAppGroupSuite() {
        // The default `EntitlementStore()` uses the App Group
        // suite as its persistence backend. After a `grant`,
        // the owned-product set should be readable from the
        // shared suite (so the widget extension can read it).
        let store = EntitlementStore()
        store.grant("com.saxweather.cosmetic.aurora.backgrounds")

        let appGroup = UserDefaults(suiteName: AppGroupEntitlementPersistence.appGroupSuiteName)
        let stored = appGroup?.stringArray(forKey: EntitlementStore.persistenceKey) ?? []
        XCTAssertTrue(
            stored.contains("com.saxweather.cosmetic.aurora.backgrounds"),
            "The production backend should write the owned set to the App Group UserDefaults suite"
        )
    }

    func test_appGroupBackend_roundTripsThroughSharedSuite() {
        // Round-trip: write through `AppGroupEntitlementPersistence`
        // then read back through a fresh `EntitlementStore`
        // using the same backend. Mirrors the real host-app /
        // widget-app hand-off.
        let backend = AppGroupEntitlementPersistence()
        backend.saveOwnedProductIDs([
            CosmeticCatalog.supporterPackID,
            "com.saxweather.cosmetic.aurora.lottie"
        ])

        let store = EntitlementStore(persistence: backend)
        XCTAssertTrue(
            store.isOwned(CosmeticCatalog.supporterPackID),
            "Supporter Pack should hydrate from the App Group suite"
        )
        XCTAssertTrue(
            store.isOwned("com.saxweather.cosmetic.aurora.lottie"),
            "Aurora Lottie should hydrate from the App Group suite"
        )
        // Supporter-Pack short-circuit still applies when
        // ownership is hydrated from the App Group backend.
        XCTAssertTrue(
            store.isOwned("com.saxweather.cosmetic.aurora.backgrounds"),
            "Short-circuit should still work for the Aurora Backgrounds product ID"
        )
    }

    // MARK: - Revoke (DEBUG-only)

    #if DEBUG
    func test_revoke_onlyAvailableInDebug() {
        let store = EntitlementStore(persistence: InMemoryEntitlementPersistence())
        store.grant("com.saxweather.cosmetic.aurora.backgrounds")
        XCTAssertTrue(store.isOwned("com.saxweather.cosmetic.aurora.backgrounds"))
        store.revoke("com.saxweather.cosmetic.aurora.backgrounds")
        XCTAssertFalse(store.isOwned("com.saxweather.cosmetic.aurora.backgrounds"))
    }

    func test_resetAll_clearsTheEntireCache() {
        let store = EntitlementStore(persistence: InMemoryEntitlementPersistence())
        store.grant("com.saxweather.cosmetic.aurora.backgrounds")
        store.grant("com.saxweather.cosmetic.aurora.palette")
        store.grant(CosmeticCatalog.supporterPackID)
        store.resetAll()
        XCTAssertTrue(store.ownedProductIDs.isEmpty)
    }
    #endif
}
