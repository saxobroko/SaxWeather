//
//  ProfileMigratorTests.swift
//  SaxWeatherTests
//
//  Phase 4 — Aurora Backgrounds single-preset migration tests.
//
//  Covers:
//   • The Aurora Backgrounds migration maps any `.aurora*`
//     `BackgroundMode` to the single `.aurora` case.
//   • The migration is idempotent — re-running it against
//     already-migrated data is safe.
//   • The migration preserves all other fields in the profile.
//

import XCTest
@testable import SaxWeather

final class ProfileMigratorTests: XCTestCase {

    // MARK: - Aurora Backgrounds migration

    /// Phase 4 — any `.aurora*` `BackgroundMode` must migrate
    /// to the single `.aurora` case. This is the migration
    /// that handles profiles saved with the old 8 specific
    /// Aurora cases (`.auroraSunny`, `.auroraCloudy`, etc.).
    func test_auroraModes_migrateToSingleAuroraCase() throws {
        // Build a v2 profile with `.auroraSunny` mode (one of
        // the old specific cases). The migration should map it
        // to `.aurora`.
        let oldModes: [String] = [
            "auroraSunny", "auroraCloudy", "auroraFoggy",
            "auroraRainy", "auroraSnowy", "auroraThunder",
            "auroraWindy", "auroraDefault", "aurora"
        ]
        for oldMode in oldModes {
            let data = makeProfileJSON(schemaVersion: 2, backgroundMode: oldMode)
            let migrated = try ProfileMigrator.migrate(data)

            // The migrated profile must have `.aurora` mode.
            XCTAssertEqual(
                migrated.knobs.background.mode, .aurora,
                "old mode \(oldMode) must migrate to .aurora"
            )
            // The schema version must be bumped to 3.
            XCTAssertEqual(
                migrated.schemaVersion, 3,
                "schema version must be bumped to 3 after migration"
            )
        }
    }

    /// The migration must be idempotent — re-running it
    /// against already-migrated data is safe.
    func test_auroraMigration_isIdempotent() throws {
        let data = makeProfileJSON(schemaVersion: 2, backgroundMode: "auroraSunny")

        // First migration: v2 → v3.
        let migrated1 = try ProfileMigrator.migrate(data)
        XCTAssertEqual(migrated1.knobs.background.mode, .aurora)
        XCTAssertEqual(migrated1.schemaVersion, 3)

        // Re-encode and re-migrate. The migration should be
        // a no-op (the mode is already `.aurora`).
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let reEncoded = try encoder.encode(migrated1)
        let migrated2 = try ProfileMigrator.migrate(reEncoded)
        XCTAssertEqual(migrated2.knobs.background.mode, .aurora)
        XCTAssertEqual(migrated2.schemaVersion, 3)
    }

    /// The migration must preserve all other fields in the
    /// profile (not just the background mode).
    func test_auroraMigration_preservesOtherFields() throws {
        let data = makeProfileJSON(
            schemaVersion: 2,
            backgroundMode: "auroraSunny",
            overlayOpacity: 0.42,
            accentColor: "purple",
            name: "My Custom Theme"
        )
        let migrated = try ProfileMigrator.migrate(data)

        // The background mode must be migrated.
        XCTAssertEqual(migrated.knobs.background.mode, .aurora)
        // The overlay opacity must be preserved.
        XCTAssertEqual(migrated.knobs.background.overlayOpacity, 0.42, accuracy: 0.0001)
        // The accent color must be preserved.
        XCTAssertEqual(migrated.knobs.visual.accentColor, .named("purple"))
        // The name must be preserved.
        XCTAssertEqual(migrated.name, "My Custom Theme")
    }

    /// Non-Aurora modes must NOT be migrated. The migration
    /// only affects `.aurora*` modes.
    func test_nonAuroraModes_areNotMigrated() throws {
        let nonAuroraModes: [String] = [
            "preset", "customImage", "gradient", "dynamicAccent"
        ]
        for mode in nonAuroraModes {
            let data = makeProfileJSON(schemaVersion: 2, backgroundMode: mode)
            let migrated = try ProfileMigrator.migrate(data)

            // The mode must be preserved (not migrated).
            XCTAssertEqual(
                migrated.knobs.background.mode.rawValue, mode,
                "non-Aurora mode \(mode) must not be migrated"
            )
        }
    }

    // MARK: - Helpers

    /// Build a minimal `.saxtheme` JSON document with the
    /// given schema version and background mode. Includes
    /// all required fields so the typed decoder can parse it.
    private func makeProfileJSON(
        schemaVersion: Int,
        backgroundMode: String,
        overlayOpacity: Double = 0.28,
        accentColor: String = "blue",
        name: String = "Test Profile"
    ) -> Data {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "\(name)",
            "builtIn": "default",
            "createdAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-01T00:00:00Z",
            "schemaVersion": \(schemaVersion),
            "knobs": {
                "visual": {
                    "accentColor": "\(accentColor)",
                    "palette": {
                        "background": "system",
                        "surface": "system",
                        "text": "system",
                        "muted": "secondary",
                        "danger": "red"
                    },
                    "cardStyle": "glass",
                    "cornerRadius": 16,
                    "fontScale": 1.0,
                    "boldText": false,
                    "useSystemTextSize": true,
                    "typography": "system",
                    "increaseContrast": false,
                    "colorScheme": "system",
                    "cardOpacity": 0.6,
                    "cardFillColor": "",
                    "cardBorderColor": "system",
                    "cardBorderWidth": 1,
                    "cardTint": "",
                    "cardShadowOpacity": 0.10,
                    "cardShadowRadius": 8,
                    "cardShadowX": 0,
                    "cardShadowY": 4,
                    "cardBlurIntensity": 0.6,
                    "cardGlassOpacity": 0.6,
                    "cardHighlightIntensity": 0.20,
                    "cardTintOverlay": "",
                    "cardTintOverlayOpacity": 0.10,
                    "cardBorderGradientStart": "",
                    "cardBorderGradientEnd": "",
                    "cardBorderGradientOpacity": 0.20,
                    "cardNeumorphicInset": true,
                    "cardPaddingH": 16,
                    "cardPaddingV": 20
                },
                "background": {
                    "mode": "\(backgroundMode)",
                    "useCustom": true,
                    "customImageData": null,
                    "gradient": {
                        "topColor": "blue",
                        "bottomColor": "system",
                        "topOpacity": 0.5,
                        "bottomOpacity": 0.9
                    },
                    "dynamicTint": "blue",
                    "perCondition": {},
                    "timeOfDayRule": "none",
                    "overlayOpacity": \(overlayOpacity)
                },
                "iconography": {
                    "lottieAnimationSet": "bundled",
                    "lottieOverrideMap": {},
                    "lottiePlaybackSpeed": 1.0,
                    "lottieLoopMode": "loop",
                    "disableWeatherAnimations": false,
                    "weatherIconStyle": "multicolor",
                    "symbolSet": "filled",
                    "iconSizeMultiplier": 1.0
                },
                "layout": {
                    "displayMode": "Summary",
                    "homeSectionOrder": ["hero", "current", "hourly", "daily", "details", "extended"],
                    "hiddenHomeSections": [],
                    "forecastDays": 7,
                    "hourlyHours": 24,
                    "cardDensity": "regular",
                    "showHamburgerMenu": true,
                    "swipeBetweenLocations": true,
                    "showLocationHeader": true,
                    "compactCardsInLandscape": true
                },
                "data": {
                    "unitSystem": "Metric",
                    "temperaturePrecision": 1,
                    "windPrecision": 0,
                    "pressurePrecision": 0,
                    "preferredDataSource": "auto",
                    "useOpenMeteoAsDefault": false,
                    "disableAPIKeys": false,
                    "refreshCadence": "normal",
                    "backgroundRefreshEnabled": true,
                    "visibleMetrics": [],
                    "hourlyMetrics": [],
                    "extendedCardsEnabled": [],
                    "showLocationLabel": true
                },
                "behaviour": {
                    "enableHapticFeedback": true,
                    "hapticIntensity": "medium",
                    "pullToRefresh": true,
                    "tapDayToExpand": true,
                    "longPressToCustomise": true,
                    "confirmDestructive": true,
                    "weatherAlertSounds": true,
                    "speakWeatherAlerts": true,
                    "quietHoursStart": null,
                    "quietHoursEnd": null,
                    "refreshSound": false,
                    "vibrateOnPullToRefresh": true,
                    "confirmQuit": false
                },
                "accessibility": {
                    "reduceMotion": false,
                    "reduceMotionForce": false,
                    "enhancedVoiceOverLabels": true,
                    "hapticOnSelection": true,
                    "tapticOnRefresh": true,
                    "highContrastOutline": false
                },
                "content": {
                    "language": null,
                    "terminologySet": "system",
                    "locationNicknames": {},
                    "customLabels": {}
                },
                "powerUser": {
                    "experimentalFlags": [],
                    "shortcutName": null,
                    "widgetRefreshPolicy": "normal",
                    "shareThemeOnExport": true,
                    "debugOverlay": false,
                    "experimentalNewHeroLayout": false,
                    "experimentalSwipeRefresh": false
                },
                "widget": {
                    "smallStyle": "classic",
                    "mediumStyle": "heroForecast",
                    "largeStyle": "full",
                    "background": "system",
                    "accentFollowsApp": true,
                    "accentOverride": "blue",
                    "tapAction": "openApp"
                },
                "forecast": {
                    "hourlyChartType": "line",
                    "hourlyCardStyle": "compact",
                    "dailyCardStyle": "row",
                    "precipitationOverlay": false,
                    "showSunArc": false,
                    "showMoonPhase": false,
                    "showHourlySummary": false,
                    "chartAxes": false,
                    "detailedColumnCount": 3,
                    "chartSkin": "none"
                }
            }
        }
        """
        return json.data(using: .utf8)!
    }
}
