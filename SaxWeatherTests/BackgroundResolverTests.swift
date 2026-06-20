//
//  BackgroundResolverTests.swift
//  SaxWeatherTests
//
//  Phase 5 acceptance tests for the background engine. The
//  resolver is a pure function, so we can exercise every branch
//  without standing up a UI host.
//
//  Test groups:
//   • IAP gate — every customisation falls back to the free
//     default when the IAP is locked, regardless of mode.
//   • Preset mode — passes the condition through and applies
//     the time-of-day rule when IAP is unlocked.
//   • Time-of-day rule — maps the current time to dawn / day /
//     dusk / night and swaps the shipped imageset accordingly.
//   • Missing sunrise/sunset data falls back to the original
//     condition (no spurious night-time swap).
//   • Per-condition overrides — beat the global mode when IAP
//     is unlocked; ignored when IAP is locked.
//   • `.customImage` mode — gated by the IAP at the resolver
//     level (defence in depth: the settings UI is the primary
//     gate).
//   • `.gradient` and `.dynamicAccent` modes — only honoured
//     when IAP is unlocked.
//   • `effectiveOverlayOpacity` — returns 0.28 when locked,
//     otherwise the spec value.
//

import XCTest
@testable import SaxWeather

@MainActor
final class BackgroundResolverTests: XCTestCase {

    // MARK: - Fixtures

    private static let dawn  = Date(timeIntervalSince1970: 1_700_000_000)
    private static let day   = Date(timeIntervalSince1970: 1_700_010_000)
    private static let dusk  = Date(timeIntervalSince1970: 1_700_018_000)
    private static let night = Date(timeIntervalSince1970: 1_700_028_000)
    private static let sunrise = Date(timeIntervalSince1970: 1_700_003_600)
    private static let sunset  = Date(timeIntervalSince1970: 1_700_014_400)

    private var baseSpec: BackgroundSpec { BackgroundSpec() }

    // MARK: - IAP gate (lock-everything behaviour)

    /// Without the IAP, every spec value is ignored and the free
    /// default (`.preset(condition)`) is returned.
    private func assertFreeDefault<IAPUnlocked>(
        mode: BackgroundMode,
        iapUnlocked: Bool
    ) {
        var spec = baseSpec
        spec.mode = mode
        spec.customImageData = Data([0xAA, 0xBB])
        spec.gradient = GradientSpec(
            topColor: .hex("#FF0000"),
            bottomColor: .named("black"),
            topOpacity: 0.1,
            bottomOpacity: 0.9
        )
        spec.dynamicTint = .named("orange")
        spec.timeOfDayRule = .dawnDayDuskNight
        spec.overlayOpacity = 0.6
        spec.perCondition["rainy"] = PerConditionBackground(
            imageData: Data([0x01])
        )
        let s = BackgroundResolver.resolve(
            condition: "rainy", spec: spec,
            sunrise: Self.sunrise, sunset: Self.sunset,
            now: Self.night,
            customBackgroundUnlocked: iapUnlocked
        )
        XCTAssertEqual(s, .preset(condition: "rainy"),
                       "mode \(mode) with IAP \(iapUnlocked) should resolve to free default")
    }

    func test_iapLocked_presetMode_isFreeDefault() {
        assertFreeDefault(mode: .preset, iapUnlocked: false)
    }

    func test_iapLocked_customImageMode_isFreeDefault() {
        assertFreeDefault(mode: .customImage, iapUnlocked: false)
    }

    func test_iapLocked_gradientMode_isFreeDefault() {
        assertFreeDefault(mode: .gradient, iapUnlocked: false)
    }

    func test_iapLocked_dynamicAccentMode_isFreeDefault() {
        assertFreeDefault(mode: .dynamicAccent, iapUnlocked: false)
    }

    func test_iapLocked_ignoresPerConditionImageOverride() {
        var spec = baseSpec
        spec.perCondition["rainy"] = PerConditionBackground(
            imageData: Data([0x99])
        )
        let s = BackgroundResolver.resolve(
            condition: "rainy", spec: spec,
            sunrise: nil, sunset: nil,
            now: Date(), customBackgroundUnlocked: false)
        XCTAssertEqual(s, .preset(condition: "rainy"))
    }

    func test_iapLocked_ignoresPerConditionGradientOverride() {
        var spec = baseSpec
        spec.perCondition["rainy"] = PerConditionBackground(
            gradientOverride: GradientSpec(
                topColor: .named("red"),
                bottomColor: .named("blue"),
                topOpacity: 0.2, bottomOpacity: 0.8
            )
        )
        let s = BackgroundResolver.resolve(
            condition: "rainy", spec: spec,
            sunrise: nil, sunset: nil,
            now: Date(), customBackgroundUnlocked: false)
        XCTAssertEqual(s, .preset(condition: "rainy"))
    }

    func test_iapLocked_ignoresTimeOfDayRule() {
        var spec = baseSpec
        spec.mode = .preset
        spec.timeOfDayRule = .dawnDayDuskNight
        let s = BackgroundResolver.resolve(
            condition: "rainy", spec: spec,
            sunrise: Self.sunrise, sunset: Self.sunset,
            now: Self.night, customBackgroundUnlocked: false)
        // No swap to "default" — the locked IAP short-circuits
        // before the time-of-day rule is consulted.
        XCTAssertEqual(s, .preset(condition: "rainy"))
    }

    // MARK: - Preset mode (IAP unlocked)

    func test_presetMode_passesConditionThrough() {
        let s = BackgroundResolver.resolve(
            condition: "rainy", spec: baseSpec,
            sunrise: Self.sunrise, sunset: Self.sunset,
            now: Self.day, customBackgroundUnlocked: true)
        XCTAssertEqual(s, .preset(condition: "rainy"))
    }

    func test_presetMode_usesDefaultWhenConditionUnrecognised() {
        let s = BackgroundResolver.resolve(
            condition: "default", spec: baseSpec,
            sunrise: nil, sunset: nil,
            now: Date(), customBackgroundUnlocked: true)
        XCTAssertEqual(s, .preset(condition: "default"))
    }

    // MARK: - Time-of-day rule (IAP unlocked)

    func test_timeOfDay_none_keepsCondition() {
        var spec = baseSpec
        spec.mode = .preset
        spec.timeOfDayRule = .none
        let s = BackgroundResolver.resolve(
            condition: "rainy", spec: spec,
            sunrise: Self.sunrise, sunset: Self.sunset,
            now: Self.night, customBackgroundUnlocked: true)
        XCTAssertEqual(s, .preset(condition: "rainy"))
    }

    func test_timeOfDay_night_swapsToDefault() {
        var spec = baseSpec
        spec.mode = .preset
        spec.timeOfDayRule = .dawnDayDuskNight
        let s = BackgroundResolver.resolve(
            condition: "rainy", spec: spec,
            sunrise: Self.sunrise, sunset: Self.sunset,
            now: Self.night, customBackgroundUnlocked: true)
        XCTAssertEqual(s, .preset(condition: "default"))
    }

    func test_timeOfDay_dawn_swapsToSunny() {
        var spec = baseSpec
        spec.mode = .preset
        spec.timeOfDayRule = .dawnDayDuskNight
        let s = BackgroundResolver.resolve(
            condition: "cloudy", spec: spec,
            sunrise: Self.sunrise, sunset: Self.sunset,
            now: Self.dawn, customBackgroundUnlocked: true)
        XCTAssertEqual(s, .preset(condition: "sunny"))
    }

    func test_timeOfDay_day_keepsCondition() {
        var spec = baseSpec
        spec.mode = .preset
        spec.timeOfDayRule = .dawnDayDuskNight
        let s = BackgroundResolver.resolve(
            condition: "snowy", spec: spec,
            sunrise: Self.sunrise, sunset: Self.sunset,
            now: Self.day, customBackgroundUnlocked: true)
        XCTAssertEqual(s, .preset(condition: "snowy"))
    }

    func test_timeOfDay_dusk_swapsToSunny() {
        var spec = baseSpec
        spec.mode = .preset
        spec.timeOfDayRule = .dawnDayDuskNight
        let s = BackgroundResolver.resolve(
            condition: "foggy", spec: spec,
            sunrise: Self.sunrise, sunset: Self.sunset,
            now: Self.dusk, customBackgroundUnlocked: true)
        XCTAssertEqual(s, .preset(condition: "sunny"))
    }

    func test_timeOfDay_missingSunData_fallsBackToCondition() {
        var spec = baseSpec
        spec.timeOfDayRule = .dawnDayDuskNight
        let s = BackgroundResolver.resolve(
            condition: "rainy", spec: spec,
            sunrise: nil, sunset: nil,
            now: Self.night, customBackgroundUnlocked: true)
        XCTAssertEqual(s, .preset(condition: "rainy"))
    }

    func test_timeOfDay_hourRange_isCurrentlyTreatedAsNone() {
        var spec = baseSpec
        spec.timeOfDayRule = .hourRange
        let s = BackgroundResolver.resolve(
            condition: "rainy", spec: spec,
            sunrise: Self.sunrise, sunset: Self.sunset,
            now: Self.night, customBackgroundUnlocked: true)
        XCTAssertEqual(s, .preset(condition: "rainy"))
    }

    // MARK: - Per-condition overrides (IAP unlocked)

    func test_perCondition_imageOverride_beatsGlobalMode() {
        var spec = baseSpec
        spec.mode = .preset
        spec.perCondition["rainy"] = PerConditionBackground(
            imageData: Data([0x01, 0x02])
        )
        let s = BackgroundResolver.resolve(
            condition: "rainy", spec: spec,
            sunrise: nil, sunset: nil,
            now: Date(), customBackgroundUnlocked: true)
        XCTAssertEqual(s, .customImage(Data([0x01, 0x02])))
    }

    func test_perCondition_gradientOverride_beatsGlobalMode() {
        var spec = baseSpec
        spec.mode = .preset
        spec.perCondition["rainy"] = PerConditionBackground(
            gradientOverride: GradientSpec(
                topColor: .named("red"),
                bottomColor: .named("blue"),
                topOpacity: 0.2,
                bottomOpacity: 0.8
            )
        )
        let s = BackgroundResolver.resolve(
            condition: "rainy", spec: spec,
            sunrise: nil, sunset: nil,
            now: Date(), customBackgroundUnlocked: true)
        XCTAssertEqual(s, .gradient(
            top: .named("red"),
            bottom: .named("blue"),
            topOpacity: 0.2,
            bottomOpacity: 0.8
        ))
    }

    // MARK: - Custom image mode

    func test_customImageMode_withIAP_returnsData() {
        var spec = baseSpec
        spec.mode = .customImage
        spec.customImageData = Data([0xAA, 0xBB])
        let s = BackgroundResolver.resolve(
            condition: "sunny", spec: spec,
            sunrise: nil, sunset: nil,
            now: Date(), customBackgroundUnlocked: true)
        XCTAssertEqual(s, .customImage(Data([0xAA, 0xBB])))
    }

    func test_customImageMode_withoutIAP_fallsBackToPreset() {
        var spec = baseSpec
        spec.mode = .customImage
        spec.customImageData = Data([0xAA, 0xBB])
        let s = BackgroundResolver.resolve(
            condition: "sunny", spec: spec,
            sunrise: nil, sunset: nil,
            now: Date(), customBackgroundUnlocked: false)
        XCTAssertEqual(s, .preset(condition: "sunny"))
    }

    func test_customImageMode_noData_fallsBackToPreset() {
        var spec = baseSpec
        spec.mode = .customImage
        spec.customImageData = nil
        let s = BackgroundResolver.resolve(
            condition: "sunny", spec: spec,
            sunrise: nil, sunset: nil,
            now: Date(), customBackgroundUnlocked: true)
        XCTAssertEqual(s, .preset(condition: "sunny"))
    }

    // MARK: - Gradient mode

    func test_gradientMode_withIAP_returnsConfiguredStops() {
        var spec = baseSpec
        spec.mode = .gradient
        spec.gradient = GradientSpec(
            topColor: .hex("#112233"),
            bottomColor: .named("surface"),
            topOpacity: 0.25,
            bottomOpacity: 0.75
        )
        let s = BackgroundResolver.resolve(
            condition: "rainy", spec: spec,
            sunrise: nil, sunset: nil,
            now: Date(), customBackgroundUnlocked: true)
        XCTAssertEqual(s, .gradient(
            top: .hex("#112233"),
            bottom: .named("surface"),
            topOpacity: 0.25,
            bottomOpacity: 0.75
        ))
    }

    // MARK: - Dynamic accent mode

    func test_dynamicAccentMode_withIAP_returnsTintAndCondition() {
        var spec = baseSpec
        spec.mode = .dynamicAccent
        spec.dynamicTint = .named("orange")
        let s = BackgroundResolver.resolve(
            condition: "cloudy", spec: spec,
            sunrise: nil, sunset: nil,
            now: Date(), customBackgroundUnlocked: true)
        XCTAssertEqual(s, .dynamicAccent(tint: .named("orange"),
                                         condition: "cloudy"))
    }

    func test_dynamicAccentMode_withIAP_appliesTimeOfDayRule() {
        var spec = baseSpec
        spec.mode = .dynamicAccent
        spec.dynamicTint = .named("orange")
        spec.timeOfDayRule = .dawnDayDuskNight
        let s = BackgroundResolver.resolve(
            condition: "rainy", spec: spec,
            sunrise: Self.sunrise, sunset: Self.sunset,
            now: Self.night, customBackgroundUnlocked: true)
        XCTAssertEqual(s, .dynamicAccent(tint: .named("orange"),
                                         condition: "default"))
    }

    // MARK: - effectiveOverlayOpacity

    func test_effectiveOverlayOpacity_returnsFreeDefaultWhenLocked() {
        var spec = baseSpec
        spec.overlayOpacity = 0.6
        let v = BackgroundResolver.effectiveOverlayOpacity(
            spec: spec, customBackgroundUnlocked: false)
        XCTAssertEqual(v, 0.28, accuracy: 0.0001)
    }

    func test_effectiveOverlayOpacity_returnsSpecWhenUnlocked() {
        var spec = baseSpec
        spec.overlayOpacity = 0.6
        let v = BackgroundResolver.effectiveOverlayOpacity(
            spec: spec, customBackgroundUnlocked: true)
        XCTAssertEqual(v, 0.6, accuracy: 0.0001)
    }

    func test_effectiveOverlayOpacity_freeDefaultConstantIs028() {
        XCTAssertEqual(
            BackgroundResolver.freeDefaultOverlayOpacity,
            0.28,
            accuracy: 0.0001
        )
    }

    // MARK: - BackgroundStrategy Codable round-trip

    func test_backgroundStrategy_roundTripsThroughJSON() throws {
        let original: BackgroundStrategy = .gradient(
            top: .hex("#FF8800"),
            bottom: .named("surface"),
            topOpacity: 0.4,
            bottomOpacity: 0.9
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BackgroundStrategy.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
