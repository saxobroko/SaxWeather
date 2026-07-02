//
//  RemoteAssetStoreTests.swift
//  SaxWeatherTests
//

import XCTest
@testable import SaxWeather

@MainActor
final class RemoteAssetStoreTests: XCTestCase {

    func test_presetBackground_remoteURL() {
        let store = PresetBackgroundAssetStore.shared
        XCTAssertEqual(
            store.remoteURL(forCondition: "rainy").absoluteString,
            "https://weather.saxobroko.com/assets/backgrounds/rainy.jpg"
        )
        XCTAssertEqual(store.normalizedCondition("sunny"), "default")
        XCTAssertTrue(store.usesBundledAsset(forCondition: "sunny"))
    }

    func test_lottieAsset_remoteURL() {
        XCTAssertEqual(
            LottieAssetStore.shared.remoteURL(forName: "rainy").absoluteString,
            "https://weather.saxobroko.com/assets/lottie/rainy.lottie"
        )
    }

    func test_bomRSSParser_extractsItems() throws {
        let xml = """
        <rss><channel>
        <item>
        <title>Severe Weather Warning</title>
        <description>Heavy rain expected</description>
        <pubDate>Mon, 01 Jul 2026 10:00:00 +1000</pubDate>
        <guid>abc123</guid>
        </item>
        </channel></rss>
        """.data(using: .utf8)!
        let items = try BOMRSSParser.parseItems(from: xml)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "Severe Weather Warning")
    }

    func test_bomRSSParser_extractsLink() throws {
        let xml = """
        <rss><channel>
        <item>
        <title>Severe Weather Warning</title>
        <link>http://reg.bom.gov.au/products/IDV21037.shtml</link>
        <description>Heavy rain expected</description>
        <pubDate>Mon, 01 Jul 2026 10:00:00 +1000</pubDate>
        <guid>http://reg.bom.gov.au/products/IDV21037.shtml</guid>
        </item>
        </channel></rss>
        """.data(using: .utf8)!
        let items = try BOMRSSParser.parseItems(from: xml)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].link, "http://reg.bom.gov.au/products/IDV21037.shtml")
    }

    func test_bomRSSParser_extractsItemWithWhitespaceBeforeClose() throws {
        let xml = """
        <rss><channel>
        <item>
        <title>Warning</title>
        <description>Test</description>
        <pubDate>Mon, 01 Jul 2026 10:00:00 +1000</pubDate>
        <guid>id1</guid>
        
        </item>
        </channel></rss>
        """.data(using: .utf8)!
        let items = try BOMRSSParser.parseItems(from: xml)
        XCTAssertEqual(items.count, 1)
    }

    func test_presetBackground_partlyCloudyMapsToCloudy() {
        let store = PresetBackgroundAssetStore.shared
        XCTAssertEqual(store.normalizedCondition("partly-cloudy"), "cloudy")
        XCTAssertFalse(store.usesBundledAsset(forCondition: "partly-cloudy"))
    }
}
