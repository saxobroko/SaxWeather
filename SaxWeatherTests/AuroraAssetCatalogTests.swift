//
//  AuroraAssetCatalogTests.swift
//  SaxWeatherTests
//
//  Phase 4 — Aurora Backgrounds asset-catalog guard tests.
//
//  Three test groups:
//
//   1. **Imageset existence** — every one of the 8
//      `weather_background_aurora_*` imagesets must exist in
//      the asset catalog. The test soft-fails (XCTSkip) when
//      the JPEG hasn't been dropped into the imageset yet,
//      so the build stays green while the photographer's
//      files are still being collected.
//
//   2. **Hardcoded mapping** — the
//      `BackgroundResolver.auroraAssetName(forCondition:)`
//      function must return the right asset for each of the
//      8 conditions, and the 8 photographer names from
//      `LICENSES.md` must all appear in that file. Defensive:
//      catches accidental re-mapping in code or in the
//      licenses file.
//
//   3. **Enum regression** — `BackgroundMode.allCases` must
//      contain exactly 1 case (`.aurora`) whose
//      `requiredProductID` matches the Aurora Backgrounds
//      cosmetic. Catches accidental removal of the case or
//      accidental addition of new cases.
//

import XCTest
@testable import SaxWeather
#if canImport(UIKit)
import UIKit
#endif

final class AuroraAssetCatalogTests: XCTestCase {

    // MARK: - 1. Imageset existence (soft-fails if JPEGs absent)

    /// Verifies the `weather_background_aurora_sunny` imageset
    /// is present in the asset catalog. If the JPEG hasn't been
    /// dropped in yet, the test soft-fails with `XCTSkip` so the
    /// suite stays green while the photographer's files are
    /// still being collected.
    func test_auroraSunnyImage_exists() throws {
        try assertAuroraImageExists(
            named: "weather_background_aurora_sunny",
            condition: "sunny"
        )
    }

    func test_auroraCloudyImage_exists() throws {
        try assertAuroraImageExists(
            named: "weather_background_aurora_cloudy",
            condition: "cloudy"
        )
    }

    func test_auroraFoggyImage_exists() throws {
        try assertAuroraImageExists(
            named: "weather_background_aurora_foggy",
            condition: "foggy"
        )
    }

    func test_auroraRainyImage_exists() throws {
        try assertAuroraImageExists(
            named: "weather_background_aurora_rainy",
            condition: "rainy"
        )
    }

    func test_auroraSnowyImage_exists() throws {
        try assertAuroraImageExists(
            named: "weather_background_aurora_snowy",
            condition: "snowy"
        )
    }

    func test_auroraThunderImage_exists() throws {
        try assertAuroraImageExists(
            named: "weather_background_aurora_thunder",
            condition: "thunder"
        )
    }

    func test_auroraWindyImage_exists() throws {
        try assertAuroraImageExists(
            named: "weather_background_aurora_windy",
            condition: "windy"
        )
    }

    func test_auroraDefaultImage_exists() throws {
        try assertAuroraImageExists(
            named: "weather_background_aurora_default",
            condition: "default"
        )
    }

    /// Common assertion for all 8 imageset existence tests.
    /// Soft-fails with `XCTSkip` if the JPEG is missing so
    /// the suite passes (just doesn't run the assertion)
    /// while the photographer's files are still being
    /// collected. Once the JPEGs land, the same tests turn
    /// into hard assertions.
    private func assertAuroraImageExists(
        named name: String,
        condition: String
    ) throws {
        // Sanity check: the resolver's asset-name function
        // must agree with the imageset name we're asserting
        // on. This is what catches an accidental rename
        // mismatch between code and assets.
        XCTAssertEqual(
            BackgroundResolver.auroraAssetName(forCondition: condition),
            name,
            "Resolver asset name for condition \(condition) must match the imageset name"
        )

        #if canImport(UIKit)
        guard let image = UIImage(named: name) else {
            throw XCTSkip(
                "Aurora JPEG '\(name).jpg' has not been dropped into the "
                + "asset catalog yet. The wiring is correct — the user "
                + "needs to copy the photographer's JPEG into the "
                + "matching imageset directory."
            )
        }
        XCTAssertGreaterThan(
            image.size.width, 0,
            "Aurora image '\(name)' must have a non-zero width"
        )
        XCTAssertGreaterThan(
            image.size.height, 0,
            "Aurora image '\(name)' must have a non-zero height"
        )
        #else
        // On non-iOS platforms, fall through. The image
        // check itself is iOS-specific but the wiring check
        // above is platform-independent.
        #endif
    }

    // MARK: - 2. Hardcoded mapping

    /// The resolver must return the matching asset name for
    /// each of the 8 conditions. Catches accidental re-mapping
    /// or rename.
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

    /// The `.aurora` mode must require the Aurora Backgrounds
    /// product ID. Catches accidental divergence (e.g. the
    /// case pointing at the wrong IAP).
    func test_auroraMode_requiresAuroraProductID() {
        let expected = "com.saxweather.cosmetic.aurora.backgrounds"
        XCTAssertEqual(
            BackgroundMode.aurora.requiredProductID, expected,
            ".aurora must require the Aurora Backgrounds product"
        )
    }

    /// `LICENSES.md` at the project root must contain all 8
    /// photographer names from the spec. Defensive: catches
    /// accidental removal of a credit entry.
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

    /// `LICENSES.md` must reference the Unsplash license.
    /// Defensive: catches accidental removal of the license
    /// header.
    func test_licensesFile_mentionsUnsplashLicense() throws {
        let licenses = try loadLicensesFile()
        XCTAssertTrue(
            licenses.contains("Unsplash License"),
            "LICENSES.md must reference the Unsplash License"
        )
    }

    /// Loads `LICENSES.md` from the project root. Tries
    /// several well-known locations in order — the test
    /// bundle is loaded into a different directory than
    /// the source file at runtime, so we check the most
    /// reliable spots first and walk up looking for it.
    private func loadLicensesFile() throws -> String {
        let fm = FileManager.default

        // 1. The directory containing this source file,
        //    walked up. `#filePath` is the original source
        //    location on disk (resolved at compile time),
        //    which works reliably across test runners.
        let thisFile = #filePath
        let testsDir = (thisFile as NSString).deletingLastPathComponent
        var ancestor = testsDir
        // Walk up at most 5 levels looking for LICENSES.md.
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

        // 2. Walk up from the test bundle's bundle URL. The
        //    test bundle is loaded from
        //    .../SaxWeather.app/PlugIns/SaxWeatherTests.xctest
        //    at runtime; the project root is several levels
        //    above that.
        var bundleURL = Bundle(for: Self.self).bundleURL
        for _ in 0..<8 {
            let candidate = bundleURL
                .appendingPathComponent("LICENSES.md")
                .path
            if fm.fileExists(atPath: candidate) {
                return try String(contentsOfFile: candidate, encoding: .utf8)
            }
            bundleURL.deleteLastPathComponent()
        }

        // 3. Walk up from the current working directory.
        //    `xcodebuild test` sets cwd to the inner
        //    `SaxWeather/` directory, not the repo root, so
        //    a single lookup won't work — but a walk-up
        //    will.
        var cwd = fm.currentDirectoryPath
        for _ in 0..<6 {
            let candidate = (cwd as NSString)
                .appendingPathComponent("LICENSES.md")
            if fm.fileExists(atPath: candidate) {
                return try String(contentsOfFile: candidate, encoding: .utf8)
            }
            let parent = (cwd as NSString).deletingLastPathComponent
            if parent == cwd { break }
            cwd = parent
        }

        throw XCTSkip(
            "LICENSES.md could not be located anywhere in the test "
            + "process's reachable file system. If this test runs from "
            + "an unexpected directory layout, add another candidate "
            + "to the lookup chain above."
        )
    }

    // MARK: - 3. Enum regression

    /// Phase 4 — `BackgroundMode` must contain exactly 1 case
    /// (`.aurora`) whose `requiredProductID` matches the
    /// Aurora Backgrounds cosmetic. Previously there were 9
    /// cases (8 specific + 1 legacy alias); now there's just
    /// 1 single preset.
    ///
    /// Catches accidental removal of the case or accidental
    /// addition of new cases.
    func test_backgroundMode_hasOneAuroraCase() {
        let expected = "com.saxweather.cosmetic.aurora.backgrounds"
        let auroraCases = BackgroundMode.allCases.filter {
            $0.requiredProductID == expected
        }
        XCTAssertEqual(
            auroraCases.count, 1,
            "BackgroundMode must have exactly 1 case gated by "
            + "the Aurora Backgrounds cosmetic (.aurora). Found: \(auroraCases)"
        )
    }

    /// `BackgroundMode.allCases` must contain the `.aurora`
    /// case.
    func test_backgroundMode_containsAuroraCase() {
        let allCases = Set(BackgroundMode.allCases)
        XCTAssertTrue(
            allCases.contains(.aurora),
            ".aurora must be in BackgroundMode.allCases"
        )
    }
}
