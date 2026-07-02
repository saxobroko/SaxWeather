//
//  AuroraAssetCatalogTests.swift
//  SaxWeatherTests
//
//  Aurora backgrounds are offloaded to weather.saxobroko.com
//  and cached on demand via CosmeticAssetStore.
//

import XCTest
@testable import SaxWeather

final class AuroraAssetCatalogTests: XCTestCase {

    func test_resolver_assetName_matchesEachCondition() {
        XCTAssertEqual(
            BackgroundResolver.auroraAssetName(forCondition: "sunny"),
            "weather_background_aurora_sunny"
        )
        XCTAssertEqual(
            BackgroundResolver.auroraAssetName(forCondition: "cloudy"),
            "weather_background_aurora_cloudy"
        )
        XCTAssertEqual(
            BackgroundResolver.auroraAssetName(forCondition: "foggy"),
            "weather_background_aurora_foggy"
        )
        XCTAssertEqual(
            BackgroundResolver.auroraAssetName(forCondition: "rainy"),
            "weather_background_aurora_rainy"
        )
        XCTAssertEqual(
            BackgroundResolver.auroraAssetName(forCondition: "snowy"),
            "weather_background_aurora_snowy"
        )
        XCTAssertEqual(
            BackgroundResolver.auroraAssetName(forCondition: "thunder"),
            "weather_background_aurora_thunder"
        )
        XCTAssertEqual(
            BackgroundResolver.auroraAssetName(forCondition: "windy"),
            "weather_background_aurora_windy"
        )
        XCTAssertEqual(
            BackgroundResolver.auroraAssetName(forCondition: "default"),
            "weather_background_aurora_default"
        )
    }

    func test_auroraMode_requiresAuroraProductID() {
        let expected = "com.saxweather.cosmetic.aurora.backgrounds"
        XCTAssertEqual(
            BackgroundMode.aurora.requiredProductID, expected,
            ".aurora must require the Aurora Backgrounds product"
        )
    }

    func test_licensesFile_containsAllPhotographerNames() throws {
        let licenses = try loadLicensesFile()
        let photographers = [
            "Johny Goerend",
            "Lucas Marcomini",
            "Luke Stackpoole",
            "Fridi Antrack",
            "Dre Erwin",
            "Anita Shepperd",
            "Jakub Vavra"
        ]
        for name in photographers {
            XCTAssertTrue(
                licenses.contains(name),
                "LICENSES.md must credit photographer '\(name)'"
            )
        }
    }

    func test_licensesFile_mentionsUnsplashLicense() throws {
        let licenses = try loadLicensesFile()
        XCTAssertTrue(
            licenses.contains("Unsplash License"),
            "LICENSES.md must reference the Unsplash License"
        )
    }

    func test_backgroundMode_hasOneAuroraCase() {
        let expected = "com.saxweather.cosmetic.aurora.backgrounds"
        let auroraCases = BackgroundMode.allCases.filter {
            $0.requiredProductID == expected
        }
        XCTAssertEqual(auroraCases.count, 1)
    }

    func test_backgroundMode_containsAuroraCase() {
        XCTAssertTrue(BackgroundMode.allCases.contains(.aurora))
    }

    private func loadLicensesFile() throws -> String {
        let fm = FileManager.default
        let thisFile = #filePath
        let testsDir = (thisFile as NSString).deletingLastPathComponent
        var ancestor = testsDir
        for _ in 0..<6 {
            let candidate = (ancestor as NSString)
                .appendingPathComponent("LICENSES.md")
            if fm.fileExists(atPath: candidate) {
                return try String(contentsOfFile: candidate, encoding: .utf8)
            }
            let parent = (ancestor as NSString).deletingLastPathComponent
            if parent == ancestor { break }
            ancestor = parent
        }
        throw XCTSkip("LICENSES.md not found")
    }
}
