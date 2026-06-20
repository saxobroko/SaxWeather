//
//  AnimationRegistryTests.swift
//  SaxWeatherTests
//
//  Phase 6 acceptance tests for the iconography & animation engine:
//
//   • `AnimationRegistry.name(for:isNight:)` resolves to the
//     bundled mapping when no override is set.
//   • `lottieOverrideMap` overrides the bundled mapping by base
//     animation name or by original condition string.
//   • `symbolName(for:isNight:)` and `symbolName(forWeatherCode:)`
//     return the correct SF Symbol for every condition.
//   • `animationsEnabled` is `false` when `disableWeatherAnimations`
//     or `reduceMotion` is on.
//   • `playbackSpeed`, `loopMode`, `animationSet`, `iconStyle`, and
//     `symbolVariant` all read from the active profile.
//   • `hasOverride(for:baseName:)` correctly detects overrides.
//

import XCTest
@testable import SaxWeather

@MainActor
final class AnimationRegistryTests: XCTestCase {

    // MARK: - Name resolution (textual condition)

    func test_nameForCondition_returnsBundledMappingWhenNoOverride() {
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: .makeDefault())
        )
        XCTAssertEqual(registry.name(for: "Clear", isNight: false), "clear-day")
        XCTAssertEqual(registry.name(for: "Clear", isNight: true), "clear-night")
        XCTAssertEqual(registry.name(for: "Partly Cloudy", isNight: false), "partly-cloudy-day")
        XCTAssertEqual(registry.name(for: "Partly Cloudy", isNight: true), "partly-cloudy-night")
        XCTAssertEqual(registry.name(for: "Cloudy"), "cloudy")
        XCTAssertEqual(registry.name(for: "Rainy"), "rainy")
        XCTAssertEqual(registry.name(for: "Thunderstorm"), "thunderstorm")
    }

    func test_nameForCondition_honoursOverrideByBaseName() {
        let profile = CustomisationProfile.makeDefault()
        profile.knobs.iconography.lottieOverrideMap = [
            "clear-day": "my-custom-clear-day"
        ]
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: profile)
        )
        XCTAssertEqual(registry.name(for: "Clear", isNight: false), "my-custom-clear-day")
        // Night variant still uses the bundled mapping.
        XCTAssertEqual(registry.name(for: "Clear", isNight: true), "clear-night")
    }

    func test_nameForCondition_honoursOverrideByConditionString() {
        let profile = CustomisationProfile.makeDefault()
        profile.knobs.iconography.lottieOverrideMap = [
            "Rainy": "my-rainy.json"
        ]
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: profile)
        )
        XCTAssertEqual(registry.name(for: "Rainy"), "my-rainy.json")
    }

    // MARK: - Name resolution (WMO code)

    func test_nameForWeatherCode_returnsBundledMappingWhenNoOverride() {
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: .makeDefault())
        )
        XCTAssertEqual(registry.name(forWeatherCode: 0, isNight: false), "clear-day")
        XCTAssertEqual(registry.name(forWeatherCode: 0, isNight: true), "clear-night")
        XCTAssertEqual(registry.name(forWeatherCode: 1, isNight: false), "partly-cloudy")
        XCTAssertEqual(registry.name(forWeatherCode: 3), "cloudy")
        XCTAssertEqual(registry.name(forWeatherCode: 61), "rainy")
        XCTAssertEqual(registry.name(forWeatherCode: 71, isNight: false), "snowy-day")
        XCTAssertEqual(registry.name(forWeatherCode: 95), "thunderstorm")
    }

    func test_nameForWeatherCode_honoursOverride() {
        let profile = CustomisationProfile.makeDefault()
        profile.knobs.iconography.lottieOverrideMap = [
            "rainy": "my-rainy.json"
        ]
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: profile)
        )
        XCTAssertEqual(registry.name(forWeatherCode: 61), "my-rainy.json")
    }

    // MARK: - SF Symbol fallback (textual condition)

    func test_symbolNameForCondition_returnsCorrectSymbol() {
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: .makeDefault())
        )
        XCTAssertEqual(registry.symbolName(for: "Clear", isNight: false), "sun.max.fill")
        XCTAssertEqual(registry.symbolName(for: "Clear", isNight: true), "moon.stars.fill")
        XCTAssertEqual(registry.symbolName(for: "Partly Cloudy", isNight: false), "cloud.sun.fill")
        XCTAssertEqual(registry.symbolName(for: "Partly Cloudy", isNight: true), "cloud.moon.fill")
        XCTAssertEqual(registry.symbolName(for: "Cloudy"), "cloud.fill")
        XCTAssertEqual(registry.symbolName(for: "Foggy"), "cloud.fog.fill")
        XCTAssertEqual(registry.symbolName(for: "Rainy"), "cloud.rain.fill")
        XCTAssertEqual(registry.symbolName(for: "Snowy"), "cloud.snow.fill")
        XCTAssertEqual(registry.symbolName(for: "Thunderstorm"), "cloud.bolt.rain.fill")
    }

    // MARK: - SF Symbol fallback (WMO code)

    func test_symbolNameForWeatherCode_returnsCorrectSymbol() {
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: .makeDefault())
        )
        XCTAssertEqual(registry.symbolName(forWeatherCode: 0, isNight: false), "sun.max.fill")
        XCTAssertEqual(registry.symbolName(forWeatherCode: 0, isNight: true), "moon.stars.fill")
        XCTAssertEqual(registry.symbolName(forWeatherCode: 1, isNight: false), "cloud.sun.fill")
        XCTAssertEqual(registry.symbolName(forWeatherCode: 3), "cloud.fill")
        XCTAssertEqual(registry.symbolName(forWeatherCode: 45), "cloud.fog.fill")
        XCTAssertEqual(registry.symbolName(forWeatherCode: 51), "cloud.drizzle.fill")
        XCTAssertEqual(registry.symbolName(forWeatherCode: 61), "cloud.rain.fill")
        XCTAssertEqual(registry.symbolName(forWeatherCode: 71), "cloud.snow.fill")
        XCTAssertEqual(registry.symbolName(forWeatherCode: 95), "cloud.bolt.fill")
    }

    // MARK: - Knob accessors

    func test_animationsEnabled_isTrueByDefault() {
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: .makeDefault())
        )
        XCTAssertTrue(registry.animationsEnabled)
    }

    func test_animationsEnabled_isFalseWhenDisableWeatherAnimationsIsTrue() {
        let profile = CustomisationProfile.makeDefault()
        profile.knobs.iconography.disableWeatherAnimations = true
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: profile)
        )
        XCTAssertFalse(registry.animationsEnabled)
    }

    func test_animationsEnabled_isFalseWhenReduceMotionIsTrue() {
        let profile = CustomisationProfile.makeDefault()
        profile.knobs.accessibility.reduceMotion = true
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: profile)
        )
        XCTAssertFalse(registry.animationsEnabled)
    }

    func test_playbackSpeed_readsFromProfile() {
        let profile = CustomisationProfile.makeDefault()
        profile.knobs.iconography.lottiePlaybackSpeed = 0.5
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: profile)
        )
        XCTAssertEqual(registry.playbackSpeed, 0.5, accuracy: 0.0001)
    }

    func test_loopMode_readsFromProfile() {
        let profile = CustomisationProfile.makeDefault()
        profile.knobs.iconography.lottieLoopMode = .playOnce
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: profile)
        )
        XCTAssertEqual(registry.loopMode, .playOnce)
    }

    func test_animationSet_readsFromProfile() {
        let profile = CustomisationProfile.makeDefault()
        profile.knobs.iconography.lottieAnimationSet = .bundledStatic
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: profile)
        )
        XCTAssertEqual(registry.animationSet, .bundledStatic)
    }

    func test_iconStyle_readsFromProfile() {
        let profile = CustomisationProfile.makeDefault()
        profile.knobs.iconography.weatherIconStyle = .monochrome
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: profile)
        )
        XCTAssertEqual(registry.iconStyle, .monochrome)
    }

    func test_symbolVariant_readsFromProfile() {
        let profile = CustomisationProfile.makeDefault()
        profile.knobs.iconography.symbolSet = .outline
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: profile)
        )
        XCTAssertEqual(registry.symbolVariant, .outline)
    }

    // MARK: - hasOverride

    func test_hasOverride_returnsTrueWhenBaseNameIsOverridden() {
        let profile = CustomisationProfile.makeDefault()
        profile.knobs.iconography.lottieOverrideMap = [
            "clear-day": "my-clear-day"
        ]
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: profile)
        )
        XCTAssertTrue(registry.hasOverride(baseName: "clear-day"))
        XCTAssertFalse(registry.hasOverride(baseName: "rainy"))
    }

    func test_hasOverride_returnsTrueWhenConditionIsOverridden() {
        let profile = CustomisationProfile.makeDefault()
        profile.knobs.iconography.lottieOverrideMap = [
            "Rainy": "my-rainy.json"
        ]
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: profile)
        )
        XCTAssertTrue(registry.hasOverride(for: "Rainy"))
        XCTAssertFalse(registry.hasOverride(for: "Clear"))
    }

    func test_hasOverride_returnsFalseWhenNoOverrides() {
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(testProfile: .makeDefault())
        )
        XCTAssertFalse(registry.hasOverride(for: "Clear", baseName: "clear-day"))
    }

    // MARK: - Built-in profile integration

    func test_minimalistProfile_disablesAnimations() {
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(
                testProfile: BuiltInProfile.minimalist.profile
            )
        )
        XCTAssertFalse(registry.animationsEnabled)
    }

    func test_batterySaverProfile_disablesAnimations() {
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(
                testProfile: BuiltInProfile.batterySaver.profile
            )
        )
        XCTAssertFalse(registry.animationsEnabled)
    }

    func test_defaultProfile_keepsAnimationsEnabled() {
        let registry = AnimationRegistry(
            customisation: CustomisationRegistry(
                testProfile: BuiltInProfile.default.profile
            )
        )
        XCTAssertTrue(registry.animationsEnabled)
        XCTAssertEqual(registry.playbackSpeed, 1.0, accuracy: 0.0001)
        XCTAssertEqual(registry.loopMode, .loop)
        XCTAssertEqual(registry.animationSet, .bundled)
        XCTAssertEqual(registry.iconStyle, .multicolor)
        XCTAssertEqual(registry.symbolVariant, .filled)
    }
}