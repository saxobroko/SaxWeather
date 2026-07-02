//
//  WidgetEntitlementReaderTests.swift
//  SaxWeatherTests
//
//  Phase 2 — Widget-side entitlement reader tests.
//
//  The actual `WidgetEntitlementReader` lives in the widget
//  extension target (`SaxWeatherWidget`) and isn't directly
//  importable from `SaxWeatherTests`. These tests instead
//  exercise the **same App Group `UserDefaults` round-trip
//  contract** the widget depends on — by writing through
//  the production host `EntitlementStore` (which now writes
//  to the App Group suite) and then reading back from the
//  same suite the widget would read from.
//
//  If the host app's `EntitlementStore` stops writing to the
//  App Group suite, these tests fail — catching the exact
//  bug Phase 2 was meant to fix.
//
//  When the widget extension later ships the actual intent
//  picker UI (Phase 4), add a parallel test target inside
//  `SaxWeatherWidget` that exercises the reader directly.
//

import XCTest
@testable import SaxWeather

@MainActor
final class WidgetEntitlementReaderTests: XCTestCase {

    // MARK: - Setup / teardown

    override func setUp() async throws {
        // Always start with a clean App Group suite so the
        // tests don't leak state into each other.
        let appGroup = UserDefaults(suiteName: AppGroupEntitlementPersistence.appGroupSuiteName)
        appGroup?.removeObject(forKey: EntitlementStore.persistenceKey)
    }

    override func tearDown() async throws {
        let appGroup = UserDefaults(suiteName: AppGroupEntitlementPersistence.appGroupSuiteName)
        appGroup?.removeObject(forKey: EntitlementStore.persistenceKey)
    }

    // MARK: - App Group round-trip (the widget's contract)

    /// The widget's `WidgetEntitlementReader.isOwned(_:)`
    /// logic boils down to: "is this product ID in the
    /// `ownedCosmeticProductIDs` array under the App Group
    /// suite, OR is the Supporter Pack ID there?". We
    /// replicate that contract here against the host app's
    /// `EntitlementStore` so any future drift breaks a test
    /// in CI.
    private func widgetIsOwned(_ productID: String) -> Bool {
        let appGroup = UserDefaults(suiteName: AppGroupEntitlementPersistence.appGroupSuiteName)
        let owned = Set(appGroup?.stringArray(forKey: EntitlementStore.persistenceKey) ?? [])
        if owned.contains(productID) { return true }
        if owned.contains(CosmeticCatalog.supporterPackID) { return true }
        return false
    }

    func test_directOwnership_visibleViaAppGroupSuite() {
        let store = EntitlementStore()
        store.grant("com.saxweather.cosmetic.aurora.backgrounds")

        XCTAssertTrue(
            widgetIsOwned("com.saxweather.cosmetic.aurora.backgrounds"),
            "Aurora Backgrounds grant should be visible via the App Group suite"
        )
    }

    func test_supporterPackShortCircuit_visibleViaAppGroupSuite() {
        let store = EntitlementStore()
        store.grant(CosmeticCatalog.supporterPackID)

        // The widget's Supporter-Pack short-circuit gives
        // every product ID a `true` answer.
        XCTAssertTrue(
            widgetIsOwned(CosmeticCatalog.supporterPackID),
            "Supporter Pack itself should be visible via the App Group suite"
        )
        XCTAssertTrue(
            widgetIsOwned("com.saxweather.cosmetic.aurora.lottie"),
            "Supporter Pack should short-circuit Aurora Lottie via the App Group suite"
        )
        XCTAssertTrue(
            widgetIsOwned("com.saxweather.cosmetic.aurora.backgrounds"),
            "Supporter Pack should short-circuit Aurora Backgrounds via the App Group suite"
        )
        XCTAssertTrue(
            widgetIsOwned("com.saxweather.cosmetic.future.never.shipped"),
            "Supporter Pack should short-circuit unknown future product IDs via the App Group suite"
        )
    }

    func test_unownedProduct_returnsFalseViaAppGroupSuite() {
        // Fresh App Group suite; nothing owned.
        XCTAssertFalse(
            widgetIsOwned("com.saxweather.cosmetic.aurora.lottie"),
            "Unowned product should report false via the App Group suite"
        )
        XCTAssertFalse(
            widgetIsOwned(CosmeticCatalog.supporterPackID),
            "Unowned Supporter Pack should report false via the App Group suite"
        )
    }

    func test_revoke_removedViaAppGroupSuite() {
        let store = EntitlementStore()
        store.grant("com.saxweather.cosmetic.aurora.lottie")
        XCTAssertTrue(widgetIsOwned("com.saxweather.cosmetic.aurora.lottie"))

        store.revoke("com.saxweather.cosmetic.aurora.lottie")
        XCTAssertFalse(
            widgetIsOwned("com.saxweather.cosmetic.aurora.lottie"),
            "Revoked product should no longer be visible via the App Group suite"
        )
    }
}
