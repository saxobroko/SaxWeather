//
//  CosmeticAssetStoreTests.swift
//  SaxWeatherTests
//

import XCTest
@testable import SaxWeather

@MainActor
final class CosmeticAssetStoreTests: XCTestCase {

    func test_conditionKey_mapsWeatherConditionToAssetSuffix() {
        let store = CosmeticAssetStore()
        XCTAssertEqual(store.conditionKey(forWeatherCondition: "sunny"), "sunny")
        XCTAssertEqual(store.conditionKey(forWeatherCondition: "clear-day"), "sunny")
        XCTAssertEqual(store.conditionKey(forWeatherCondition: "night"), "default")
    }

    func test_remoteURL_usesCDNBase() {
        let store = CosmeticAssetStore()
        XCTAssertEqual(
            store.remoteURL(forCondition: "rainy").absoluteString,
            "https://weather.saxobroko.com/assets/aurora/rainy.jpg"
        )
    }

    func test_unlocksAuroraBackgrounds_includesBundleAndSupporterPack() {
        XCTAssertTrue(
            CosmeticAssetStore.unlocksAuroraBackgrounds(
                productID: BackgroundResolver.auroraBackgroundsProductID
            )
        )
        XCTAssertTrue(
            CosmeticAssetStore.unlocksAuroraBackgrounds(
                productID: CosmeticCatalog.supporterPackID
            )
        )
        XCTAssertTrue(
            CosmeticAssetStore.unlocksAuroraBackgrounds(
                productID: "com.saxweather.cosmetic.bundle.mega.aurora"
            )
        )
        XCTAssertFalse(
            CosmeticAssetStore.unlocksAuroraBackgrounds(
                productID: "com.saxweather.cosmetic.aurora.palette"
            )
        )
    }

    func test_auroraCatalogListsRemoteAssetReferences() {
        let product = CosmeticCatalog.product(
            id: BackgroundResolver.auroraBackgroundsProductID
        )!
        XCTAssertEqual(product.assetReferences.count, 8)
        XCTAssertTrue(
            product.assetReferences.allSatisfy { $0.hasPrefix("assets/aurora/") }
        )
    }
}
