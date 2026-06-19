//
//  ProfileToAppStorageBridgeTests.swift
//  SaxWeatherTests
//
//  Phase 2 acceptance tests for the AppStorage bridge.
//
//  Covers:
//   • `bridge(_:to:)` writes every knob to its UserDefaults key.
//   • `readFromAppStorage(from:)` reads existing values.
//   • Missing keys fall back to `KnobStorage()` defaults —
//     never `bool(forKey:)`'s implicit `false`, which would
//     wipe out the true defaults on first launch.
//   • A `KnobStorage` round-trips losslessly through bridge →
//     UserDefaults → readFromAppStorage.
//   • `CustomisationRegistry.set` and `apply` propagate to
//     `UserDefaults.standard` so existing `@AppStorage` views
//     pick up the new value.
//   • Custom background image data round-trips through the
//     bridge (`Data?` ↔ `Data?`).
//

import XCTest
@testable import SaxWeather

@MainActor
final class ProfileToAppStorageBridgeTests: XCTestCase {

    /// Isolated UserDefaults suite for bridge-direct tests. Never
    /// touches `UserDefaults.standard` so test runs are
    /// hermetic and parallelisable.
    private var isolatedDefaults: UserDefaults!

    /// Keys that the registry end-to-end tests will touch in
    /// `UserDefaults.standard`. Wiped in setUp + tearDown so
    /// they don't leak across tests.
    private static let standardKeys = ProfileToAppStorageBridge.allBridgedKeys

    // MARK: - Setup / teardown

    override func setUp() {
        super.setUp()
        wipeStandard()
        let suiteName = "test.sax.bridge.\(UUID().uuidString)"
        isolatedDefaults = UserDefaults(suiteName: suiteName)
        wipe(isolatedDefaults)
    }

    override func tearDown() {
        wipeStandard()
        if let isolatedDefaults {
            for key in Self.standardKeys {
                isolatedDefaults.removeObject(forKey: key)
            }
            isolatedDefaults.removePersistentDomain(
                forName: isolatedDefaults.dictionaryRepresentation().isEmpty
                    ? ""
                    : (isolatedDefaults.dictionaryRepresentation().keys.first.map(String.init) ?? "")
            )
        }
        isolatedDefaults = nil
        super.tearDown()
    }

    private func wipe(_ d: UserDefaults?) {
        guard let d else { return }
        for key in Self.standardKeys {
            d.removeObject(forKey: key)
        }
    }

    private func wipeStandard() {
        for key in Self.standardKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - bridge() write-through

    func test_bridge_writesEveryKnobToUserDefaults() {
        var knobs = KnobStorage()
        knobs.visual.accentColor = .named("purple")
        knobs.visual.colorScheme = "dark"
        knobs.visual.fontScale = 1.3
        knobs.visual.boldText = true
        knobs.data.unitSystem = "Imperial"
        knobs.data.useOpenMeteoAsDefault = true
        knobs.layout.forecastDays = 14
        knobs.layout.displayMode = "Detailed"
        knobs.accessibility.reduceMotion = true
        knobs.behaviour.speakWeatherAlerts = false

        ProfileToAppStorageBridge.bridge(knobs, to: isolatedDefaults)

        XCTAssertEqual(isolatedDefaults.string(forKey: "accentColor"), "purple")
        XCTAssertEqual(isolatedDefaults.string(forKey: "colorScheme"), "dark")
        XCTAssertEqual(
            isolatedDefaults.double(forKey: "customTextSizeMultiplier"),
            1.3,
            accuracy: 0.0001
        )
        XCTAssertEqual(isolatedDefaults.bool(forKey: "boldText"), true)
        XCTAssertEqual(isolatedDefaults.string(forKey: "unitSystem"), "Imperial")
        XCTAssertEqual(isolatedDefaults.bool(forKey: "useOpenMeteoAsDefault"), true)
        XCTAssertEqual(isolatedDefaults.integer(forKey: "forecastDays"), 14)
        XCTAssertEqual(isolatedDefaults.string(forKey: "displayMode"), "Detailed")
        XCTAssertEqual(isolatedDefaults.bool(forKey: "reduceMotion"), true)
        XCTAssertEqual(isolatedDefaults.bool(forKey: "speakWeatherAlerts"), false)
    }

    // MARK: - readFromAppStorage() read-back

    func test_readFromAppStorage_returnsKnobStorageWithValues() {
        isolatedDefaults.set("UK", forKey: "unitSystem")
        isolatedDefaults.set("orange", forKey: "accentColor")
        isolatedDefaults.set(10, forKey: "forecastDays")
        isolatedDefaults.set(true, forKey: "reduceMotion")

        let knobs = ProfileToAppStorageBridge.readFromAppStorage(from: isolatedDefaults)

        XCTAssertEqual(knobs.data.unitSystem, "UK")
        XCTAssertEqual(knobs.visual.accentColor, "orange")
        XCTAssertEqual(knobs.layout.forecastDays, 10)
        XCTAssertEqual(knobs.accessibility.reduceMotion, true)
    }

    func test_readFromAppStorage_returnsDefaultsForEmptyStore() {
        let knobs = ProfileToAppStorageBridge.readFromAppStorage(from: isolatedDefaults)
        XCTAssertEqual(knobs, KnobStorage())
    }

    /// The classic regression: if a view reads `UserDefaults.standard
    /// .bool(forKey: "enhancedVoiceOverLabels")` and the key is
    /// never set, the call returns `false` even though the
    /// `KnobStorage` default is `true`. Without the
    /// `object(forKey:) != nil` guard, a one-time
    /// `readFromAppStorage()` on first launch would silently wipe
    /// the default. This test pins the guard in place.
    func test_readFromAppStorage_preservesKnobStorageDefaultsForMissingBools() {
        let knobs = ProfileToAppStorageBridge.readFromAppStorage(from: isolatedDefaults)
        XCTAssertTrue(knobs.accessibility.enhancedVoiceOverLabels)
        XCTAssertTrue(knobs.behaviour.enableHapticFeedback)
        XCTAssertTrue(knobs.behaviour.speakWeatherAlerts)
        XCTAssertTrue(knobs.visual.useSystemTextSize)
    }

    func test_readFromAppStorage_preservesDefaultStrings() {
        let knobs = ProfileToAppStorageBridge.readFromAppStorage(from: isolatedDefaults)
        XCTAssertEqual(knobs.data.unitSystem, "Metric")
        XCTAssertEqual(knobs.visual.accentColor, "blue")
        XCTAssertEqual(knobs.layout.displayMode, "Summary")
    }

    // MARK: - Round trip

    func test_bridgeThenRead_isLosslessForAllBridgedKeys() {
        var knobs = KnobStorage()
        knobs.visual.accentColor = "teal"
        knobs.visual.colorScheme = "dark"
        knobs.visual.fontScale = 1.15
        knobs.visual.boldText = true
        knobs.visual.increaseContrast = true
        knobs.visual.useSystemTextSize = false
        knobs.data.unitSystem = "UK"
        knobs.data.useOpenMeteoAsDefault = true
        knobs.data.disableAPIKeys = true
        knobs.layout.forecastDays = 14
        knobs.layout.displayMode = "Detailed"
        knobs.layout.showHamburgerMenu = false
        knobs.accessibility.reduceMotion = true
        knobs.accessibility.enhancedVoiceOverLabels = false
        knobs.iconography.disableWeatherAnimations = true
        knobs.behaviour.enableHapticFeedback = false
        knobs.behaviour.speakWeatherAlerts = false
        knobs.background.useCustom = false

        ProfileToAppStorageBridge.bridge(knobs, to: isolatedDefaults)
        let restored = ProfileToAppStorageBridge.readFromAppStorage(from: isolatedDefaults)

        XCTAssertEqual(restored.visual.accentColor, "teal")
        XCTAssertEqual(restored.visual.colorScheme, "dark")
        XCTAssertEqual(restored.visual.fontScale, 1.15, accuracy: 0.0001)
        XCTAssertEqual(restored.visual.boldText, true)
        XCTAssertEqual(restored.visual.increaseContrast, true)
        XCTAssertEqual(restored.visual.useSystemTextSize, false)
        XCTAssertEqual(restored.data.unitSystem, "UK")
        XCTAssertEqual(restored.data.useOpenMeteoAsDefault, true)
        XCTAssertEqual(restored.data.disableAPIKeys, true)
        XCTAssertEqual(restored.layout.forecastDays, 14)
        XCTAssertEqual(restored.layout.displayMode, "Detailed")
        XCTAssertEqual(restored.layout.showHamburgerMenu, false)
        XCTAssertEqual(restored.accessibility.reduceMotion, true)
        XCTAssertEqual(restored.accessibility.enhancedVoiceOverLabels, false)
        XCTAssertEqual(restored.iconography.disableWeatherAnimations, true)
        XCTAssertEqual(restored.behaviour.enableHapticFeedback, false)
        XCTAssertEqual(restored.behaviour.speakWeatherAlerts, false)
        XCTAssertEqual(restored.background.useCustom, false)
    }

    func test_bridge_imageDataRoundTrip() {
        var knobs = KnobStorage()
        let pngBytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        knobs.background.customImageData = Data(pngBytes)
        knobs.background.useCustom = true

        ProfileToAppStorageBridge.bridge(knobs, to: isolatedDefaults)
        let restored = ProfileToAppStorageBridge.readFromAppStorage(from: isolatedDefaults)

        XCTAssertEqual(restored.background.customImageData, Data(pngBytes))
        XCTAssertEqual(restored.background.useCustom, true)
    }

    func test_bridge_imageDataNilRemovesKey() {
        var knobs = KnobStorage()
        knobs.background.customImageData = Data([0x01, 0x02, 0x03])
        ProfileToAppStorageBridge.bridge(knobs, to: isolatedDefaults)
        XCTAssertNotNil(isolatedDefaults.data(forKey: "userCustomBackground"))

        knobs.background.customImageData = nil
        ProfileToAppStorageBridge.bridge(knobs, to: isolatedDefaults)
        XCTAssertNil(isolatedDefaults.data(forKey: "userCustomBackground"))
    }

    // MARK: - End-to-end through the registry

    /// Verifies the Phase 2 acceptance criterion: toggling
    /// `unitSystem` via the registry updates UserDefaults so
    /// every existing `@AppStorage("unitSystem")` view sees the
    /// new value.
    func test_registrySet_writesThroughToStandardUserDefaults() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())

        registry.set(\.data.unitSystem, "Imperial")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "unitSystem"), "Imperial")

        registry.set(\.visual.accentColor, .named("pink"))
        XCTAssertEqual(UserDefaults.standard.string(forKey: "accentColor"), "pink")

        registry.set(\.layout.forecastDays, 10)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "forecastDays"), 10)
    }

    /// Applying a built-in profile propagates every knob it
    /// customises to UserDefaults.
    func test_registryApply_writesThroughToStandardUserDefaults() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        registry.apply(BuiltInProfile.minimalist.profile)

        XCTAssertEqual(UserDefaults.standard.integer(forKey: "forecastDays"), 3)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "disableWeatherAnimations"), true)
    }

    /// `set` is a no-op when the value is unchanged — important
    /// to keep the loop `view → UserDefaults → onChange →
    /// registry.set → bridge → UserDefaults` from re-firing
    /// unnecessarily.
    func test_registrySetSameValueIsNoOp_doesNotTouchUserDefaults() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        // The registry has just been initialised but its test init
        // bypasses the bridge, so UserDefaults is still empty.
        XCTAssertNil(UserDefaults.standard.string(forKey: "unitSystem"))

        registry.set(\.data.unitSystem, "Metric") // already the default
        // No bridge write should have occurred.
        XCTAssertNil(UserDefaults.standard.string(forKey: "unitSystem"))
    }

    // MARK: - allBridgedKeys sanity

    func test_allBridgedKeys_isNonEmptyAndContainsEveryPhase2Key() {
        let keys = ProfileToAppStorageBridge.allBridgedKeys
        XCTAssertFalse(keys.isEmpty)
        XCTAssertTrue(keys.contains("unitSystem"))
        XCTAssertTrue(keys.contains("accentColor"))
        XCTAssertTrue(keys.contains("reduceMotion"))
        XCTAssertTrue(keys.contains("customTextSizeMultiplier"))
        // Credentials and coords are NOT knobs.
        XCTAssertFalse(keys.contains("wuApiKey"))
        XCTAssertFalse(keys.contains("latitude"))
    }
}
