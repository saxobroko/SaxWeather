//
//  CosmeticCatalogTests.swift
//  SaxWeatherTests
//
//  Phase 1 — Cosmetic-only monetization foundation tests.
//  Phase 2 — Aurora Pack complete + Mega Pack: Aurora bundle.
//  Phase 3 — Aurora Lottie removed; Mega Pack: Aurora grants
//            three items, not four. Per-IAP tile image slot.
//  Phase 4 — Supporter Pack tile image regression test.
//

import XCTest
@testable import SaxWeather

final class CosmeticCatalogTests: XCTestCase {

    // MARK: - Phase 1 + Phase 2 product presence

    func test_allPhase1ProductsArePresent() {
        let shippedIDs = Set(CosmeticCatalog.shippedProducts.map(\.id))

        // The 2 Phase 1 cosmetics must all be shipped.
        XCTAssertTrue(
            shippedIDs.contains("com.saxweather.cosmetic.aurora.backgrounds"),
            "Aurora Backgrounds must be shipped in Phase 1"
        )
        XCTAssertTrue(
            shippedIDs.contains("com.saxweather.cosmetic.aurora.palette"),
            "Aurora Palette must be shipped in Phase 1"
        )
        XCTAssertTrue(
            shippedIDs.contains("com.saxweather.cosmetic.supporter.badge"),
            "Supporter Badge must be shipped in Phase 1"
        )

        // The Supporter Pack is also shipped in Phase 1 per
        // the plan's locked decisions.
        XCTAssertTrue(
            shippedIDs.contains(CosmeticCatalog.supporterPackID),
            "Supporter Pack must be shipped in Phase 1"
        )

        // Phase 2: Aurora Chart Skin + Mega Pack: Aurora
        // are now shipped too. Aurora Lottie was removed
        // in Phase 3 (see Part B of the cleanup pass).
        XCTAssertTrue(
            shippedIDs.contains("com.saxweather.cosmetic.aurora.chart"),
            "Aurora Chart Skin must be shipped in Phase 2"
        )
        XCTAssertTrue(
            shippedIDs.contains("com.saxweather.cosmetic.bundle.mega.aurora"),
            "Mega Pack: Aurora must be shipped in Phase 2"
        )

        // Phase 3 — Aurora Lottie must NOT be in the catalog
        // at all (let alone shipped).
        XCTAssertFalse(
            shippedIDs.contains("com.saxweather.cosmetic.aurora.lottie"),
            "Aurora Lottie was removed in Phase 3 and must not be shipped"
        )
        XCTAssertNil(
            CosmeticCatalog.product(id: "com.saxweather.cosmetic.aurora.lottie"),
            "Aurora Lottie must not exist in the catalog"
        )

        // Phase 3+ products must NOT be shipped.
        XCTAssertFalse(
            shippedIDs.contains("com.saxweather.cosmetic.seasonal.halloween"),
            "Halloween Pack belongs to Phase 3 and must not be shipped yet"
        )
    }

    func test_supporterPackID_isCorrect() {
        XCTAssertEqual(
            CosmeticCatalog.supporterPackID,
            "com.saxweather.cosmetic.supporter.pack"
        )
    }

    // MARK: - Lookup helpers

    func test_product_lookup_returnsCorrectItem() {
        let product = CosmeticCatalog.product(id: "com.saxweather.cosmetic.aurora.backgrounds")
        XCTAssertNotNil(product)
        XCTAssertEqual(product?.displayName, "Aurora Backgrounds")
        XCTAssertEqual(product?.priceCents, 399)
        XCTAssertEqual(product?.priceTier, .standard)
    }

    func test_product_lookup_returnsNilForUnknown() {
        XCTAssertNil(CosmeticCatalog.product(id: "not.a.real.product"))
    }

    // MARK: - isCurrentlyPurchasable

    func test_isCurrentlyPurchasable_respectsShippedFlag() {
        let auroraBackgrounds = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!
        XCTAssertTrue(
            CosmeticCatalog.isCurrentlyPurchasable(auroraBackgrounds),
            "Aurora Backgrounds is shipped and non-seasonal — always purchasable"
        )

        let auroraChart = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.chart"
        )!
        XCTAssertTrue(
            CosmeticCatalog.isCurrentlyPurchasable(auroraChart),
            "Aurora Chart Skin is shipped in Phase 2 — always purchasable"
        )

        let supporterPack = CosmeticCatalog.product(
            id: CosmeticCatalog.supporterPackID
        )!
        XCTAssertTrue(
            CosmeticCatalog.isCurrentlyPurchasable(supporterPack),
            "Supporter Pack is shipped and non-seasonal"
        )
    }

    func test_isCurrentlyPurchasable_respectsSeasonalWindow() {
        // Halloween: Dec 1 → Jan 7. Test that the in-window
        // check is irrelevant when the product is un-shipped
        // (it always returns false).
        let halloween = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.seasonal.halloween"
        )!
        XCTAssertFalse(
            CosmeticCatalog.isCurrentlyPurchasable(halloween),
            "Halloween is un-shipped, so the in-window check is irrelevant"
        )
    }

    // MARK: - Store visibility (catalog + StoreKit)

    func test_isPurchasableInStore_requiresShippedAndStoreKit() {
        let auroraBackgrounds = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!
        let storeKitIDs: Set<String> = [auroraBackgrounds.id]

        XCTAssertTrue(
            CosmeticCatalog.isPurchasableInStore(
                auroraBackgrounds,
                storeKitAvailableIDs: storeKitIDs
            )
        )
        XCTAssertFalse(
            CosmeticCatalog.isPurchasableInStore(
                auroraBackgrounds,
                storeKitAvailableIDs: []
            ),
            "Shipped products missing from StoreKit must not be purchasable"
        )

        let neonBackgrounds = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.neon.backgrounds"
        )!
        XCTAssertFalse(
            CosmeticCatalog.isPurchasableInStore(
                neonBackgrounds,
                storeKitAvailableIDs: [neonBackgrounds.id]
            ),
            "Un-shipped products must not be purchasable even when StoreKit returns them"
        )
    }

    func test_isPurchasableInStore_respectsSeasonalWindowWhenShipped() {
        var halloween = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.seasonal.halloween"
        )!
        // Simulate a shipped Halloween pack that ASC approved.
        halloween = CosmeticProduct(
            id: halloween.id,
            displayName: halloween.displayName,
            subtitle: halloween.subtitle,
            priceTier: halloween.priceTier,
            productKind: halloween.productKind,
            packID: halloween.packID,
            packDisplayName: halloween.packDisplayName,
            assetReferences: halloween.assetReferences,
            tileImageName: halloween.tileImageName,
            widgetParity: halloween.widgetParity,
            seasonalWindow: halloween.seasonalWindow,
            familyShareable: halloween.familyShareable,
            previewDurationSeconds: halloween.previewDurationSeconds,
            priceCents: halloween.priceCents,
            isShipped: true,
            symbolName: halloween.symbolName
        )
        let storeKitIDs: Set<String> = [halloween.id]
        let inWindow = makeDate(month: 10, day: 15)
        let outOfWindow = makeDate(month: 12, day: 15)

        XCTAssertTrue(
            CosmeticCatalog.isPurchasableInStore(
                halloween,
                storeKitAvailableIDs: storeKitIDs,
                at: inWindow
            )
        )
        XCTAssertFalse(
            CosmeticCatalog.isPurchasableInStore(
                halloween,
                storeKitAvailableIDs: storeKitIDs,
                at: outOfWindow
            )
        )
    }

    func test_isVisibleInStore_keepsOwnedProductsWithoutStoreKit() {
        let auroraBackgrounds = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!
        let owned: Set<String> = [auroraBackgrounds.id]

        XCTAssertTrue(
            CosmeticCatalog.isVisibleInStore(
                auroraBackgrounds,
                storeKitAvailableIDs: [],
                isOwned: { owned.contains($0.id) }
            ),
            "Owned products stay visible when ASC temporarily withholds them"
        )
        XCTAssertFalse(
            CosmeticCatalog.isVisibleInStore(
                auroraBackgrounds,
                storeKitAvailableIDs: [],
                isOwned: { _ in false }
            ),
            "Unowned products missing from StoreKit must be hidden"
        )
    }

    func test_isVisibleInStore_bundleHiddenWhenNotInStoreKit() {
        let megaAurora = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.bundle.mega.aurora"
        )!
        let auroraOnly: Set<String> = [
            "com.saxweather.cosmetic.aurora.backgrounds",
            "com.saxweather.cosmetic.aurora.palette",
            "com.saxweather.cosmetic.aurora.chart"
        ]

        XCTAssertFalse(
            CosmeticCatalog.isVisibleInStore(
                megaAurora,
                storeKitAvailableIDs: auroraOnly,
                isOwned: { _ in false }
            ),
            "Bundles must be approved in ASC themselves — component IDs are not enough"
        )
        XCTAssertTrue(
            CosmeticCatalog.isVisibleInStore(
                megaAurora,
                storeKitAvailableIDs: auroraOnly.union([megaAurora.id]),
                isOwned: { _ in false }
            )
        )
    }

    func test_isVisibleInStore_starterBundleStaysHiddenWhenUnshipped() {
        let starter = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.bundle.starter"
        )!
        let storeKitIDs: Set<String> = [starter.id]

        XCTAssertFalse(
            CosmeticCatalog.isVisibleInStore(
                starter,
                storeKitAvailableIDs: storeKitIDs,
                isOwned: { _ in false }
            ),
            "Starter Pack references un-shipped items and remains catalog-gated off"
        )
    }

    // MARK: - Seasonal window

    func test_seasonalWindow_handlesNonWrappingWindow() {
        // Halloween: Oct 1 → Nov 5 (non-wrapping).
        let window = SeasonalWindow(start: (10, 1), end: (11, 5))

        // In-window samples.
        let octFirst = makeDate(month: 10, day: 1)
        let oct15 = makeDate(month: 10, day: 15)
        let nov5 = makeDate(month: 11, day: 5)
        XCTAssertTrue(window.isCurrentlyInWindow(date: octFirst))
        XCTAssertTrue(window.isCurrentlyInWindow(date: oct15))
        XCTAssertTrue(window.isCurrentlyInWindow(date: nov5))

        // Out-of-window samples.
        let sep30 = makeDate(month: 9, day: 30)
        let nov6 = makeDate(month: 11, day: 6)
        let dec15 = makeDate(month: 12, day: 15)
        XCTAssertFalse(window.isCurrentlyInWindow(date: sep30))
        XCTAssertFalse(window.isCurrentlyInWindow(date: nov6))
        XCTAssertFalse(window.isCurrentlyInWindow(date: dec15))
    }

    func test_seasonalWindow_handlesWraparound() {
        // Christmas: Dec 1 → Jan 7 (wraps around the year
        // boundary).
        let window = SeasonalWindow(start: (12, 1), end: (1, 7))

        // In-window samples — both sides of the boundary.
        let dec1 = makeDate(month: 12, day: 1)
        let dec25 = makeDate(month: 12, day: 25)
        let dec31 = makeDate(month: 12, day: 31)
        let jan1 = makeDate(month: 1, day: 1)
        let jan7 = makeDate(month: 1, day: 7)
        XCTAssertTrue(window.isCurrentlyInWindow(date: dec1), "Dec 1 is the start")
        XCTAssertTrue(window.isCurrentlyInWindow(date: dec25), "Dec 25 is in-window")
        XCTAssertTrue(window.isCurrentlyInWindow(date: dec31), "Dec 31 is in-window")
        XCTAssertTrue(window.isCurrentlyInWindow(date: jan1), "Jan 1 is in-window (wrap)")
        XCTAssertTrue(window.isCurrentlyInWindow(date: jan7), "Jan 7 is the end")

        // Out-of-window samples — both sides of the window.
        let nov30 = makeDate(month: 11, day: 30)
        let jan8 = makeDate(month: 1, day: 8)
        let feb15 = makeDate(month: 2, day: 15)
        let jun1 = makeDate(month: 6, day: 1)
        XCTAssertFalse(window.isCurrentlyInWindow(date: nov30), "Nov 30 is before start")
        XCTAssertFalse(window.isCurrentlyInWindow(date: jan8), "Jan 8 is after end")
        XCTAssertFalse(window.isCurrentlyInWindow(date: feb15))
        XCTAssertFalse(window.isCurrentlyInWindow(date: jun1))
    }

    // MARK: - Phase 3: Aurora Lottie removal

    /// Regression: the Aurora Lottie cosmetic was removed in
    /// Phase 3 (cleanup pass Part B). It must not appear in
    /// the catalog, must not be in the shipped list, and must
    /// not be reachable via any lookup.
    func test_auroraLottieProduct_isRemoved() {
        XCTAssertNil(
            CosmeticCatalog.product(id: "com.saxweather.cosmetic.aurora.lottie"),
            "Aurora Lottie must not exist in the catalog after Phase 3 removal"
        )
        let shippedIDs = Set(CosmeticCatalog.shippedProducts.map(\.id))
        XCTAssertFalse(
            shippedIDs.contains("com.saxweather.cosmetic.aurora.lottie"),
            "Aurora Lottie must not appear in the shipped list"
        )
        // And the .lottie `CosmeticKind` case has been
        // removed too — no product can report
        // `productKind == .lottie`. We verify this indirectly:
        // if any product still had a "lottie" kind, the
        // catalog would also have to declare the kind case,
        // which it no longer does. The above checks on
        // product IDs and the shipped list are sufficient
        // to lock down the removal.
    }

    // MARK: - Phase 3: Aurora Pack has three shipped items (not four)

    /// Regression: Mega Pack: Aurora originally granted 4
    /// items (Backgrounds, Lottie, Palette, Chart). After
    /// Lottie removal it grants 3 items.
    func test_auroraPack_hasThreeShippedItemsAfterLottieRemoval() {
        let shippedIDs = Set(CosmeticCatalog.shippedProducts.map(\.id))
        let auroraIDs: Set<String> = [
            "com.saxweather.cosmetic.aurora.backgrounds",
            "com.saxweather.cosmetic.aurora.palette",
            "com.saxweather.cosmetic.aurora.chart"
        ]
        for id in auroraIDs {
            XCTAssertTrue(
                shippedIDs.contains(id),
                "Aurora Pack item \(id) must be shipped in Phase 3"
            )
        }
        XCTAssertEqual(
            auroraIDs.intersection(shippedIDs).count,
            3,
            "All three Aurora items must be in the shipped list"
        )
        // No Lottie in the shipped Aurora set.
        XCTAssertFalse(
            shippedIDs.contains("com.saxweather.cosmetic.aurora.lottie"),
            "Aurora Lottie must not be in the shipped Aurora set after Phase 3 removal"
        )
    }

    /// Regression: Mega Pack: Aurora should grant 3 items
    /// (Backgrounds, Palette, Chart Skin) — not 4. Lottie
    /// was removed in Phase 3.
    func test_megaPackAurora_grantsThreeItemsNotFour() {
        // The bundle itself is shipped.
        let bundle = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.bundle.mega.aurora"
        )
        XCTAssertNotNil(bundle, "Mega Pack: Aurora must exist in the catalog")
        XCTAssertTrue(bundle?.isShipped ?? false)
        XCTAssertEqual(bundle?.priceCents, 999, "Mega Pack: Aurora is $9.99")

        // The pack's "contents" — items whose packID == "aurora"
        // — must include exactly 3 items (Backgrounds, Palette,
        // Chart). Lottie must NOT appear.
        let auroraPackItems = CosmeticCatalog.products(inPack: "aurora")
            .filter { $0.id != "com.saxweather.cosmetic.bundle.mega.aurora" }
        XCTAssertEqual(
            auroraPackItems.count, 3,
            "Mega Pack: Aurora must grant exactly 3 items (Backgrounds, Palette, Chart)"
        )
        let auroraPackIDs = Set(auroraPackItems.map(\.id))
        XCTAssertEqual(
            auroraPackIDs,
            Set([
                "com.saxweather.cosmetic.aurora.backgrounds",
                "com.saxweather.cosmetic.aurora.palette",
                "com.saxweather.cosmetic.aurora.chart"
            ]),
            "Mega Pack: Aurora contents must match the three expected items exactly"
        )
        XCTAssertFalse(
            auroraPackIDs.contains("com.saxweather.cosmetic.aurora.lottie"),
            "Aurora Lottie must not be in the Mega Pack: Aurora contents"
        )
    }

    // MARK: - Phase 2: Mega Pack: Aurora is shipped

    func test_megaPackAurora_isShipped() {
        let product = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.bundle.mega.aurora"
        )
        XCTAssertNotNil(product, "Mega Pack: Aurora must exist in the catalog")
        XCTAssertTrue(product?.isShipped ?? false, "Mega Pack: Aurora must be shipped in Phase 2")
        XCTAssertEqual(product?.priceCents, 999, "Mega Pack: Aurora is $9.99")
        XCTAssertEqual(product?.priceTier, .bundle)
        XCTAssertEqual(product?.productKind, .bundle)
    }

    // MARK: - Phase 2: packDisplayName is present on every product

    func test_packDisplayName_isPresentForAllProducts() {
        // Every product in the catalog must carry a non-empty
        // `packDisplayName` (Phase 2 spec). The catalog uses
        // explicit names like "Aurora", "Neon", "Mega Pack:
        // Aurora", etc.
        for product in CosmeticCatalog.allProducts {
            XCTAssertFalse(
                product.packDisplayName.isEmpty,
                "Product \(product.id) is missing a packDisplayName — every catalog entry must set one explicitly"
            )
        }
    }

    func test_packDisplayName_resolvedPackDisplayName_fallsBackToDerived() {
        // Construct a `CosmeticProduct` with an empty
        // `packDisplayName`. `resolvedPackDisplayName` should
        // fall back to a derived English name from `packID`.
        let product = CosmeticProduct(
            id: "test.product.with.empty.packDisplayName",
            displayName: "Test Display Name",
            subtitle: "Test subtitle",
            priceTier: .micro,
            productKind: .backgrounds,
            packID: "aurora",
            packDisplayName: "",
            priceCents: 99
        )
        XCTAssertEqual(
            product.resolvedPackDisplayName,
            "Aurora",
            "Empty packDisplayName should fall back to capitalised packID"
        )

        // When both `packDisplayName` and `packID` are empty,
        // falls back to the product's own displayName.
        let standalone = CosmeticProduct(
            id: "test.standalone",
            displayName: "Standalone Item",
            subtitle: "Standalone subtitle",
            priceTier: .micro,
            productKind: .backgrounds,
            packID: nil,
            packDisplayName: "",
            priceCents: 99
        )
        XCTAssertEqual(
            standalone.resolvedPackDisplayName,
            "Standalone Item",
            "Empty packDisplayName + nil packID should fall back to displayName"
        )

        // When `packDisplayName` is set, it wins regardless of
        // packID.
        let explicit = CosmeticProduct(
            id: "test.explicit",
            displayName: "Explicit Display Name",
            subtitle: "Test subtitle",
            priceTier: .micro,
            productKind: .backgrounds,
            packID: "ignored-pack-id",
            packDisplayName: "My Pack",
            priceCents: 99
        )
        XCTAssertEqual(
            explicit.resolvedPackDisplayName,
            "My Pack",
            "Non-empty packDisplayName should override any derived value"
        )
    }

    // MARK: - Phase 3: tileImageName is set on every product

    func test_tileImageName_isSetForEveryProduct() {
        // Every product in the catalog must carry a non-nil
        // `tileImageName` so the user knows which imageset to
        // drop a JPEG into. Names follow the convention
        // `cosmetic_tile_<pack-segment>...`.
        for product in CosmeticCatalog.allProducts {
            XCTAssertNotNil(
                product.tileImageName,
                "Product \(product.id) is missing tileImageName — every catalog entry must set one"
            )
            // And it must follow the convention.
            if let name = product.tileImageName {
                XCTAssertTrue(
                    name.hasPrefix("cosmetic_tile_"),
                    "Product \(product.id) tileImageName '\(name)' should start with 'cosmetic_tile_'"
                )
            }
        }
    }

    // MARK: - Phase 4: Supporter Pack tile image regression

    /// Regression: the Supporter Pack tile image was missing
    /// in Phase 3 (the card used a hardcoded gradient that
    /// ignored the tile image entirely). Phase 4 fixes this
    /// by reading the optional `tileImageName` first, then
    /// falling back to the kind-appropriate placeholder.
    /// This test asserts the Supporter Pack has a non-nil
    /// `tileImageName` so the placeholder fallback chain
    /// works correctly.
    func test_supporterPackTileImageName_isSet() {
        let supporterPack = CosmeticCatalog.product(
            id: CosmeticCatalog.supporterPackID
        )
        XCTAssertNotNil(
            supporterPack,
            "Supporter Pack must exist in the catalog"
        )
        XCTAssertNotNil(
            supporterPack?.tileImageName,
            "Supporter Pack must have a non-nil tileImageName so the placeholder fallback chain works"
        )
        XCTAssertEqual(
            supporterPack?.tileImageName,
            "cosmetic_tile_supporter_pack",
            "Supporter Pack tileImageName must follow the cosmetic_tile_<short_id> convention"
        )
    }

    // MARK: - Regression: Phase 4+ items stay un-shipped

    func test_neonSeasonalEtc_areNotYetShipped() {
        // Phase 4+ items must NOT be promoted in Phase 3 —
        // their `isShipped` flag stays `false` so the store
        // UI doesn't surface them yet.
        let shippedIDs = Set(CosmeticCatalog.shippedProducts.map(\.id))

        let futureIDs = [
            // Neon pack
            "com.saxweather.cosmetic.neon.backgrounds",
            "com.saxweather.cosmetic.neon.palette",
            "com.saxweather.cosmetic.neon.icons",
            // Seasonal pack
            "com.saxweather.cosmetic.seasonal.halloween",
            "com.saxweather.cosmetic.seasonal.christmas",
            "com.saxweather.cosmetic.seasonal.pride",
            "com.saxweather.cosmetic.seasonal.autumn",
            // Typography
            "com.saxweather.cosmetic.font.editorial",
            "com.saxweather.cosmetic.font.mono",
            "com.saxweather.cosmetic.font.handwritten",
            // Haptics & Sound
            "com.saxweather.cosmetic.haptic.rain",
            "com.saxweather.cosmetic.haptic.wind",
            "com.saxweather.cosmetic.sound.synth",
            // Widgets
            "com.saxweather.cosmetic.widget.backgrounds",
            "com.saxweather.cosmetic.widget.themes",
            // App icons
            "com.saxweather.cosmetic.appicon.minimal",
            "com.saxweather.cosmetic.appicon.illustrated",
            // Bundles that ship later
            "com.saxweather.cosmetic.bundle.starter",
            "com.saxweather.cosmetic.bundle.mega.neon",
            "com.saxweather.cosmetic.bundle.mega.seasonal"
        ]
        for id in futureIDs {
            XCTAssertFalse(
                shippedIDs.contains(id),
                "Phase 4+ product \(id) must not be promoted to shipped in Phase 3"
            )
        }
    }

    // MARK: - Helpers

    /// Build a `Date` in the current year for the given
    /// (month, day). Used so the seasonal-window tests
    /// don't care about which calendar year we're in.
    private func makeDate(month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = Calendar(identifier: .gregorian).component(.year, from: Date())
        components.month = month
        components.day = day
        components.hour = 12  // noon — avoids DST edge cases
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
