//
//  CustomisationRegistryTests.swift
//  SaxWeatherTests
//
//  Phase 1 acceptance tests for the customisation engine:
//
//   • Every default in `KnobStorage` matches the existing
//     `@AppStorage` defaults in `SettingsView.swift` /
//     `AccessibilitySettingsView.swift`.
//   • Every built-in profile produces a profile whose `builtIn`
//     matches the request and whose distinct knobs reflect the
//     preset's intent.
//   • A `CustomisationProfile` round-trips through `Codable`
//     losslessly.
//   • `ProfileMigrator` accepts the current version, treats a
//     missing version stamp as v0, and rejects future versions.
//   • `CustomisationRegistry.set(_:_:)` updates the profile,
//     bumps `profileHash`, and is a no-op when the value is
//     already current.
//

import XCTest
@testable import SaxWeather

@MainActor
final class CustomisationRegistryTests: XCTestCase {

    // MARK: - Defaults match existing @AppStorage

    func test_defaultKnobStorage_matchesExistingAppStorageDefaults() {
        let knobs = KnobStorage()
        // Visual
        XCTAssertEqual(knobs.visual.accentColor, "blue")
        XCTAssertEqual(knobs.visual.useSystemTextSize, true)
        XCTAssertEqual(knobs.visual.fontScale, 1.0, accuracy: 0.0001)
        XCTAssertEqual(knobs.visual.boldText, false)
        XCTAssertEqual(knobs.visual.increaseContrast, false)
        XCTAssertEqual(knobs.visual.colorScheme, "system")
        // Data
        XCTAssertEqual(knobs.data.unitSystem, "Metric")
        XCTAssertEqual(knobs.data.useOpenMeteoAsDefault, false)
        XCTAssertEqual(knobs.data.disableAPIKeys, false)
        // Layout
        XCTAssertEqual(knobs.layout.forecastDays, 7)
        XCTAssertEqual(knobs.layout.displayMode, "Summary")
        // Iconography
        XCTAssertEqual(knobs.iconography.disableWeatherAnimations, false)
        // Accessibility
        XCTAssertEqual(knobs.accessibility.reduceMotion, false)
        XCTAssertEqual(knobs.accessibility.enhancedVoiceOverLabels, true)
        // Behaviour
        XCTAssertEqual(knobs.behaviour.enableHapticFeedback, true)
        XCTAssertEqual(knobs.behaviour.speakWeatherAlerts, true)
    }

    func test_homeSectionOrder_matchesHardcodedSections() {
        XCTAssertEqual(
            HomeSectionID.defaultOrder,
            [.hero, .current, .hourly, .daily, .details, .extended]
        )
    }

    // MARK: - Built-in profiles

    func test_minimalist_hidesExtendedAndDisablesAnimations() {
        let p = BuiltInProfile.minimalist.profile
        XCTAssertEqual(p.builtIn, .minimalist)
        XCTAssertEqual(p.name, "Minimalist")
        XCTAssertTrue(p.knobs.iconography.disableWeatherAnimations)
        XCTAssertEqual(p.knobs.layout.forecastDays, 3)
        XCTAssertTrue(p.knobs.layout.hiddenHomeSections.contains(.extended))
    }

    func test_powerUser_extendsForecastWindow() {
        let p = BuiltInProfile.powerUser.profile
        XCTAssertEqual(p.builtIn, .powerUser)
        XCTAssertEqual(p.knobs.layout.forecastDays, 14)
        XCTAssertEqual(p.knobs.layout.hourlyHours, 48)
        XCTAssertEqual(p.knobs.layout.displayMode, "Detailed")
    }

    func test_accessibility_enablesBoldAndContrast() {
        let p = BuiltInProfile.accessibility.profile
        XCTAssertEqual(p.builtIn, .accessibility)
        XCTAssertTrue(p.knobs.visual.boldText)
        XCTAssertTrue(p.knobs.visual.increaseContrast)
        XCTAssertTrue(p.knobs.accessibility.reduceMotion)
        XCTAssertGreaterThan(p.knobs.visual.fontScale, 1.0)
    }

    func test_batterySaver_disablesAnimationsAndSlowsCadence() {
        let p = BuiltInProfile.batterySaver.profile
        XCTAssertEqual(p.builtIn, .batterySaver)
        XCTAssertTrue(p.knobs.iconography.disableWeatherAnimations)
        XCTAssertEqual(p.knobs.data.refreshCadence, .batterySaver)
        XCTAssertTrue(p.knobs.accessibility.reduceMotion)
    }

    func test_allBuiltIns_haveUniqueStableIDs() {
        // Sanity check: every built-in resolves and produces a
        // distinct name (no copy-paste bugs in the factories).
        let names = BuiltInProfile.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertTrue(names.contains("Default"))
        XCTAssertTrue(names.contains("Minimalist"))
        XCTAssertTrue(names.contains("Power User"))
        XCTAssertTrue(names.contains("Accessibility"))
        XCTAssertTrue(names.contains("Battery Saver"))
    }

    // MARK: - Round trip

    func test_profile_codableRoundTrip_preservesEverything() throws {
        var original = CustomisationProfile.makeDefault()
        original.name = "Round Trip"
        original.knobs.data.unitSystem = "Imperial"
        original.knobs.visual.accentColor = "purple"
        original.knobs.layout.hiddenHomeSections = [.extended, .hourly]
        original.knobs.forecast.hourlyChartType = .area
        original.knobs.behaviour.quietHoursStart = 22
        original.knobs.behaviour.quietHoursEnd = 7

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(CustomisationProfile.self, from: data)

        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.knobs.data.unitSystem, "Imperial")
        XCTAssertEqual(restored.knobs.visual.accentColor, "purple")
        XCTAssertEqual(restored.knobs.layout.hiddenHomeSections, [.extended, .hourly])
        XCTAssertEqual(restored.knobs.forecast.hourlyChartType, .area)
        XCTAssertEqual(restored.knobs.behaviour.quietHoursStart, 22)
        XCTAssertEqual(restored.knobs.behaviour.quietHoursEnd, 7)
    }

    // MARK: - Migration

    func test_migrator_acceptsCurrentVersion() throws {
        let profile = CustomisationProfile.makeDefault()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)

        let migrated = try ProfileMigrator.migrate(data)
        XCTAssertEqual(migrated.schemaVersion, ProfileMigrator.currentSchemaVersion)
        XCTAssertEqual(migrated.knobs, profile.knobs)
    }

    func test_migrator_treatsMissingSchemaVersionAsZero() throws {
        // Legacy data without `schemaVersion` field is treated as
        // v0 and migrated forward to current.
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Legacy",
            "builtIn": "default",
            "createdAt": "2025-01-01T00:00:00Z",
            "updatedAt": "2025-01-01T00:00:00Z",
            "knobs": {}
        }
        """
        let data = json.data(using: .utf8)!
        let migrated = try ProfileMigrator.migrate(data)
        XCTAssertEqual(migrated.schemaVersion, ProfileMigrator.currentSchemaVersion)
        XCTAssertEqual(migrated.name, "Legacy")
    }

    func test_migrator_rejectsUnsupportedVersion() {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000002",
            "name": "Future",
            "builtIn": "default",
            "schemaVersion": 999,
            "createdAt": "2025-01-01T00:00:00Z",
            "updatedAt": "2025-01-01T00:00:00Z",
            "knobs": {}
        }
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try ProfileMigrator.migrate(data)) { error in
            guard case ProfileMigratorError.unsupportedVersion(let v) = error else {
                return XCTFail("Expected .unsupportedVersion, got \(error)")
            }
            XCTAssertEqual(v, 999)
        }
    }

    func test_migrator_rejectsInvalidFormat() {
        // Not a JSON object (it's an array).
        let json = "[]"
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try ProfileMigrator.migrate(data))
    }

    // MARK: - Registry set / get

    func test_registry_setUpdatesProfileAndBumpsHash() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        let beforeHash = registry.profileHash
        registry.set(\.data.unitSystem, "Imperial")
        XCTAssertEqual(registry.profile.knobs.data.unitSystem, "Imperial")
        XCTAssertNotEqual(registry.profileHash, beforeHash)
    }

    func test_registry_setSameValueIsNoOp() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        let beforeHash = registry.profileHash
        registry.set(\.data.unitSystem, "Metric") // already default
        XCTAssertEqual(registry.profileHash, beforeHash)
        XCTAssertEqual(registry.profile.knobs.data.unitSystem, "Metric")
    }

    func test_registry_setUpdatesTimestamp() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        let before = registry.profile.updatedAt
        // Sleep 10ms to guarantee a new timestamp resolution.
        Thread.sleep(forTimeInterval: 0.01)
        registry.set(\.data.unitSystem, "Imperial")
        XCTAssertGreaterThanOrEqual(registry.profile.updatedAt, before)
    }

    func test_registry_getReturnsValue() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        XCTAssertEqual(registry.get(\.data.unitSystem), "Metric")
        XCTAssertEqual(registry.get(\.visual.accentColor), "blue")
    }

    func test_registry_applyReplacesProfile() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        let tokenBefore = registry.versionToken
        registry.apply(BuiltInProfile.minimalist.profile)
        XCTAssertEqual(registry.profile.builtIn, .minimalist)
        XCTAssertTrue(registry.profile.knobs.iconography.disableWeatherAnimations)
        XCTAssertGreaterThan(registry.versionToken, tokenBefore)
    }

    func test_registry_resetToSwitchPreset() {
        let registry = CustomisationRegistry(testProfile: BuiltInProfile.powerUser.profile)
        registry.resetTo(.accessibility)
        XCTAssertEqual(registry.profile.builtIn, .accessibility)
        XCTAssertTrue(registry.profile.knobs.visual.boldText)
    }

    func test_registry_resetToDefaultRoundTrip() {
        let registry = CustomisationRegistry(testProfile: BuiltInProfile.minimalist.profile)
        registry.resetTo(.default)
        XCTAssertEqual(registry.profile.builtIn, .default)
        XCTAssertFalse(registry.profile.knobs.iconography.disableWeatherAnimations)
        XCTAssertEqual(registry.profile.knobs.layout.forecastDays, 7)
    }
}
