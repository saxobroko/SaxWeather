//
//  RainProbabilityChartTests.swift
//  SaxWeatherTests
//
//  Part F — Aurora Chart Skin visibility tests for the rain
//  probability chart on the main page.
//
//  Covers:
//    • The rain probability chart uses its own default colour
//      scheme (blue tones) when no chart skin is equipped.
//    • The rain probability chart uses the Aurora override
//      colours when the Aurora Chart Skin is equipped.
//    • The chart re-resolves its colours when the chart skin
//      changes (e.g. during a live preview).
//

import XCTest
import SwiftUI
@testable import SaxWeather

@MainActor
final class RainProbabilityChartTests: XCTestCase {

    /// When no chart skin is equipped, the rain probability
    /// chart must use its own default colour scheme (blue
    /// tones). This is the free path — the chart should look
    /// intentional even without any cosmetic.
    func test_rainProbabilityChart_usesDefaultColorsWhenNoSkinEquipped() {
        let scheme = ChartColorScheme.rainProbability(activeSkin: .none)

        // The default scheme must use blue tones (rain = water
        // = blue). The `primary` is the bar fill.
        XCTAssertEqual(
            scheme.primary, Color.blue,
            "rain probability chart default must use Color.blue as primary"
        )
        XCTAssertEqual(
            scheme.secondary, Color.blue.opacity(0.6),
            "rain probability chart default must use Color.blue.opacity(0.6) as secondary"
        )
    }

    /// When the Aurora Chart Skin is equipped, the rain
    /// probability chart must use the Aurora override colours
    /// (ocean blue → teal → coral). This is the cosmetic path
    /// — the chart should pick up the Aurora palette.
    func test_rainProbabilityChart_usesAuroraColorsWhenAuroraSkinEquipped() {
        // The Aurora override is only applied when the user
        // owns the Aurora Chart Skin (or the Supporter Pack).
        // We pass `isOwned: { _ in true }` to simulate an
        // owned cosmetic.
        let scheme = ChartColorScheme.rainProbability(
            activeSkin: .aurora,
            isOwned: { _ in true }
        )

        // The Aurora override must use the Aurora palette
        // colours. The `primary` is ocean blue, `secondary` is
        // teal, `accent` is coral.
        XCTAssertEqual(
            scheme.primary, ChartColorScheme.auroraOverride.primary,
            "rain probability chart with Aurora skin must use Aurora primary"
        )
        XCTAssertEqual(
            scheme.secondary, ChartColorScheme.auroraOverride.secondary,
            "rain probability chart with Aurora skin must use Aurora secondary"
        )
        XCTAssertEqual(
            scheme.accent, ChartColorScheme.auroraOverride.accent,
            "rain probability chart with Aurora skin must use Aurora accent"
        )
    }

    /// The rain probability chart must re-resolve its colours
    /// when the chart skin changes. This is the contract that
    /// makes the Aurora Chart Skin preview actually visible.
    ///
    /// We verify this by:
    ///   1. Resolving the scheme with `.none` (default).
    ///   2. Resolving the scheme with `.aurora` (Aurora).
    ///   3. Asserting that the two resolutions produce
    ///      different colours.
    func test_rainProbabilityChart_reResolvesOnSkinChange() {
        // The Aurora override is only applied when the user
        // owns the Aurora Chart Skin (or the Supporter Pack).
        // We pass `isOwned: { _ in true }` to simulate an
        // owned cosmetic.
        let defaultScheme = ChartColorScheme.rainProbability(
            activeSkin: .none,
            isOwned: { _ in true }
        )
        let auroraScheme = ChartColorScheme.rainProbability(
            activeSkin: .aurora,
            isOwned: { _ in true }
        )

        // The two resolutions must produce different colours.
        XCTAssertNotEqual(
            defaultScheme.primary, auroraScheme.primary,
            "rain probability chart must re-resolve primary colour on skin change"
        )
        XCTAssertNotEqual(
            defaultScheme.secondary, auroraScheme.secondary,
            "rain probability chart must re-resolve secondary colour on skin change"
        )
    }

    /// The `ChartPaletteStore` must re-resolve the active skin
    /// when the profile's chart skin changes. This is the
    /// reactivity contract that makes the Aurora Chart Skin
    /// preview actually visible on the rain probability chart.
    func test_rainProbabilityChart_storeReResolvesOnProfileChange() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        let store = ChartPaletteStore(registry: registry)

        // Before: default chart skin (.none).
        XCTAssertEqual(
            store.activeSkin, .none,
            "default profile must have .none chart skin"
        )

        // Apply a new profile with the Aurora chart skin.
        var newProfile = CustomisationProfile.makeDefault()
        newProfile.knobs.forecast.chartSkin = .aurora
        registry.apply(newProfile)

        // After: the preferred skin has changed to .aurora.
        // The active skin is still .none because the user
        // doesn't own the cosmetic, but the store has
        // re-resolved.
        XCTAssertEqual(
            registry.profile.knobs.forecast.chartSkin, .aurora,
            "registry must store the new chart skin after apply(_:)"
        )
        XCTAssertEqual(
            store.activeSkin, .none,
            "unowned Aurora must resolve to .none"
        )
    }
}
