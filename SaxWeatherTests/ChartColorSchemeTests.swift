//
//  ChartColorSchemeTests.swift
//  SaxWeatherTests
//
//  Part F — Per-chart colour scheme tests.
//
//  Covers:
//    • The Aurora override is distinct from the default
//      schemes.
//    • Each chart has its own default colour scheme that is
//      distinct from the others.
//    • The resolution logic correctly applies the Aurora
//      override when the active skin is `.aurora` AND the
//      user owns the Aurora Chart Skin.
//    • The resolution logic does NOT apply the Aurora override
//      when the user doesn't own the Aurora Chart Skin.
//    • The default colour schemes match the original hardcoded
//      colours.
//

import XCTest
import SwiftUI
@testable import SaxWeather

@MainActor
final class ChartColorSchemeTests: XCTestCase {

    // MARK: - Aurora override

    /// The Aurora override must be distinct from the default
    /// schemes. This is the contract that makes the Aurora
    /// Chart Skin visible on every chart.
    func test_chartColorScheme_auroraOverride_isDistinctFromDefault() {
        let aurora = ChartColorScheme.auroraOverride
        let rainDefault = ChartColorScheme.rainProbabilityDefault
        let precipDefault = ChartColorScheme.precipitationTimelineDefault
        let hourlyDefault = ChartColorScheme.hourlyForecastDefault

        // The Aurora override must have different colours than
        // every default scheme.
        XCTAssertNotEqual(
            aurora.primary, rainDefault.primary,
            "Aurora primary must differ from rain probability default"
        )
        XCTAssertNotEqual(
            aurora.primary, precipDefault.primary,
            "Aurora primary must differ from precipitation timeline default"
        )
        XCTAssertNotEqual(
            aurora.primary, hourlyDefault.primary,
            "Aurora primary must differ from hourly forecast default"
        )
    }

    // MARK: - Per-chart defaults

    /// Each chart must have its own default colour scheme that
    /// is distinct from the others. This is the contract that
    /// preserves each chart's visual identity when no cosmetic
    /// is equipped.
    func test_chartColorScheme_perChartDefaults_areDistinct() {
        let rainDefault = ChartColorScheme.rainProbabilityDefault
        let precipDefault = ChartColorScheme.precipitationTimelineDefault
        let hourlyDefault = ChartColorScheme.hourlyForecastDefault

        // The rain probability chart uses blue tones.
        XCTAssertEqual(
            rainDefault.primary, Color.blue,
            "rain probability default must use Color.blue"
        )

        // The precipitation timeline uses blue intensity ramps.
        XCTAssertEqual(
            precipDefault.primary, Color.blue.opacity(0.9),
            "precipitation timeline default must use Color.blue.opacity(0.9)"
        )

        // The hourly forecast uses a cool→warm gradient.
        XCTAssertEqual(
            hourlyDefault.primary, Color.blue,
            "hourly forecast default must use Color.blue"
        )
        XCTAssertEqual(
            hourlyDefault.secondary, Color.teal,
            "hourly forecast default must use Color.teal"
        )

        // The rain probability and precipitation timeline
        // defaults must be distinct (different opacity).
        XCTAssertNotEqual(
            rainDefault.primary, precipDefault.primary,
            "rain probability and precipitation timeline defaults must be distinct"
        )
    }

    /// The default colour schemes must match the original
    /// hardcoded colours exactly. This is the contract that
    /// preserves the original look of the app when no cosmetic
    /// is equipped.
    func test_chartColorScheme_defaultMatchesOriginalHardcodedColours() {
        // Rain probability chart: blue bars, blue gradient
        // bottom stop, white "now" indicator, secondary grid
        // lines.
        XCTAssertEqual(
            ChartColorScheme.rainProbabilityDefault.primary,
            Color.blue,
            "rain probability default primary must be Color.blue"
        )
        XCTAssertEqual(
            ChartColorScheme.rainProbabilityDefault.secondary,
            Color.blue.opacity(0.6),
            "rain probability default secondary must be Color.blue.opacity(0.6)"
        )
        XCTAssertEqual(
            ChartColorScheme.rainProbabilityDefault.accent,
            Color.white,
            "rain probability default accent must be Color.white"
        )
        XCTAssertEqual(
            ChartColorScheme.rainProbabilityDefault.background,
            Color.secondary.opacity(0.2),
            "rain probability default background must be Color.secondary.opacity(0.2)"
        )

        // Precipitation timeline bar: blue intensity ramps,
        // red current time indicator, gray track.
        XCTAssertEqual(
            ChartColorScheme.precipitationTimelineDefault.primary,
            Color.blue.opacity(0.9),
            "precipitation timeline default primary must be Color.blue.opacity(0.9)"
        )
        XCTAssertEqual(
            ChartColorScheme.precipitationTimelineDefault.secondary,
            Color.blue.opacity(0.6),
            "precipitation timeline default secondary must be Color.blue.opacity(0.6)"
        )
        XCTAssertEqual(
            ChartColorScheme.precipitationTimelineDefault.accent,
            Color.red,
            "precipitation timeline default accent must be Color.red"
        )
        XCTAssertEqual(
            ChartColorScheme.precipitationTimelineDefault.background,
            Color.gray.opacity(0.3),
            "precipitation timeline default background must be Color.gray.opacity(0.3)"
        )

        // Hourly forecast pill strip: cool→warm gradient.
        XCTAssertEqual(
            ChartColorScheme.hourlyForecastDefault.primary,
            Color.blue,
            "hourly forecast default primary must be Color.blue"
        )
        XCTAssertEqual(
            ChartColorScheme.hourlyForecastDefault.secondary,
            Color.teal,
            "hourly forecast default secondary must be Color.teal"
        )
        XCTAssertEqual(
            ChartColorScheme.hourlyForecastDefault.accent,
            Color.orange,
            "hourly forecast default accent must be Color.orange"
        )
        XCTAssertEqual(
            ChartColorScheme.hourlyForecastDefault.background,
            Color.clear,
            "hourly forecast default background must be Color.clear"
        )
    }

    // MARK: - Resolution

    /// The resolution logic must apply the Aurora override
    /// when the active skin is `.aurora` AND the user owns the
    /// Aurora Chart Skin.
    func test_chartColorScheme_resolve_appliesAuroraOverride() {
        let rainDefault = ChartColorScheme.rainProbabilityDefault
        let resolvedAurora = ChartColorScheme.resolve(
            defaultScheme: rainDefault,
            activeSkin: .aurora,
            isOwned: { _ in true }
        )
        let resolvedNone = ChartColorScheme.resolve(
            defaultScheme: rainDefault,
            activeSkin: .none,
            isOwned: { _ in true }
        )

        // When the active skin is `.aurora` AND the user owns
        // the Aurora Chart Skin, the resolved scheme must be
        // the Aurora override.
        XCTAssertEqual(
            resolvedAurora, ChartColorScheme.auroraOverride,
            "resolve with .aurora and ownership must return the Aurora override"
        )

        // When the active skin is `.none`, the resolved
        // scheme must be the default scheme.
        XCTAssertEqual(
            resolvedNone, rainDefault,
            "resolve with .none must return the default scheme"
        )
    }

    /// The resolution logic must NOT apply the Aurora override
    /// when the user doesn't own the Aurora Chart Skin. This
    /// is the contract that prevents the Aurora look from
    /// appearing if the user somehow has the Aurora Chart
    /// Skin selected without owning it.
    func test_chartColorScheme_auroraOverrideOnlyWhenOwned() {
        let rainDefault = ChartColorScheme.rainProbabilityDefault

        // Aurora skin selected but NOT owned.
        let resolvedNotOwned = ChartColorScheme.resolve(
            defaultScheme: rainDefault,
            activeSkin: .aurora,
            isOwned: { _ in false }
        )

        // The resolved scheme must be the default scheme, not
        // the Aurora override.
        XCTAssertEqual(
            resolvedNotOwned, rainDefault,
            "Aurora skin without ownership must resolve to the default scheme"
        )
        XCTAssertNotEqual(
            resolvedNotOwned, ChartColorScheme.auroraOverride,
            "Aurora skin without ownership must not resolve to the Aurora override"
        )

        // Aurora skin selected AND owned.
        let resolvedOwned = ChartColorScheme.resolve(
            defaultScheme: rainDefault,
            activeSkin: .aurora,
            isOwned: { _ in true }
        )

        // The resolved scheme must be the Aurora override.
        XCTAssertEqual(
            resolvedOwned, ChartColorScheme.auroraOverride,
            "Aurora skin with ownership must resolve to the Aurora override"
        )
    }

    /// The convenience methods must return the resolved scheme
    /// for each chart. This is the contract that the chart
    /// views rely on.
    func test_chartColorScheme_convenienceMethods_returnResolvedScheme() {
        // Rain probability with .none must return the default.
        let rainNone = ChartColorScheme.rainProbability(
            activeSkin: .none,
            isOwned: { _ in true }
        )
        XCTAssertEqual(
            rainNone, ChartColorScheme.rainProbabilityDefault,
            "rainProbability(.none) must return the default"
        )

        // Rain probability with .aurora AND ownership must return the Aurora override.
        let rainAurora = ChartColorScheme.rainProbability(
            activeSkin: .aurora,
            isOwned: { _ in true }
        )
        XCTAssertEqual(
            rainAurora, ChartColorScheme.auroraOverride,
            "rainProbability(.aurora, owned) must return the Aurora override"
        )

        // Rain probability with .aurora but NO ownership must return the default.
        let rainAuroraNotOwned = ChartColorScheme.rainProbability(
            activeSkin: .aurora,
            isOwned: { _ in false }
        )
        XCTAssertEqual(
            rainAuroraNotOwned, ChartColorScheme.rainProbabilityDefault,
            "rainProbability(.aurora, not owned) must return the default"
        )

        // Precipitation timeline with .none must return the default.
        let precipNone = ChartColorScheme.precipitationTimeline(
            activeSkin: .none,
            isOwned: { _ in true }
        )
        XCTAssertEqual(
            precipNone, ChartColorScheme.precipitationTimelineDefault,
            "precipitationTimeline(.none) must return the default"
        )

        // Precipitation timeline with .aurora AND ownership must return the Aurora override.
        let precipAurora = ChartColorScheme.precipitationTimeline(
            activeSkin: .aurora,
            isOwned: { _ in true }
        )
        XCTAssertEqual(
            precipAurora, ChartColorScheme.auroraOverride,
            "precipitationTimeline(.aurora, owned) must return the Aurora override"
        )

        // Hourly forecast with .none must return the default.
        let hourlyNone = ChartColorScheme.hourlyForecast(
            activeSkin: .none,
            isOwned: { _ in true }
        )
        XCTAssertEqual(
            hourlyNone, ChartColorScheme.hourlyForecastDefault,
            "hourlyForecast(.none) must return the default"
        )

        // Hourly forecast with .aurora AND ownership must return the Aurora override.
        let hourlyAurora = ChartColorScheme.hourlyForecast(
            activeSkin: .aurora,
            isOwned: { _ in true }
        )
        XCTAssertEqual(
            hourlyAurora, ChartColorScheme.auroraOverride,
            "hourlyForecast(.aurora, owned) must return the Aurora override"
        )
    }

    // MARK: - Gradient colours

    /// The `gradientColors` property must return a 5-colour
    /// gradient suitable for a left-to-right `LinearGradient`.
    /// This is the contract that the hourly forecast pill
    /// strip relies on.
    func test_chartColorScheme_gradientColors_returnsFiveColors() {
        let defaultGradient = ChartColorScheme.hourlyForecastDefault.gradientColors
        let auroraGradient = ChartColorScheme.auroraOverride.gradientColors

        XCTAssertEqual(
            defaultGradient.count, 5,
            "default gradient must have 5 colours"
        )
        XCTAssertEqual(
            auroraGradient.count, 5,
            "Aurora gradient must have 5 colours"
        )

        // The two gradients must be distinct.
        XCTAssertNotEqual(
            defaultGradient[0].description, auroraGradient[0].description,
            "default and Aurora gradients must have different first colours"
        )
    }
}
