//
//  CardColorSchemeTests.swift
//  SaxWeatherTests
//
//  Part F — Per-card colour scheme tests.
//
//  Covers:
//    • The Aurora override is distinct from the default
//      schemes.
//    • Each card has its own default colour scheme that is
//      distinct from the others.
//    • The resolution logic correctly applies the Aurora
//      override when the active palette is `.cosmeticAurora`
//      AND the user owns the Aurora Palette.
//    • The resolution logic does NOT apply the Aurora override
//      when the user doesn't own the Aurora Palette.
//    • The default colour schemes match the original hardcoded
//      colours.
//

import XCTest
import SwiftUI
@testable import SaxWeather

@MainActor
final class CardColorSchemeTests: XCTestCase {

    // MARK: - Aurora override

    /// The Aurora override must be distinct from the default
    /// schemes. This is the contract that makes the Aurora
    /// Palette visible on every card.
    func test_cardColorScheme_auroraOverride_isDistinctFromDefault() {
        let aurora = CardColorScheme.auroraOverride
        let tempDefault = CardColorScheme.temperatureCardDefault
        let precipDefault = CardColorScheme.precipitationCardDefault
        let windDefault = CardColorScheme.windCardDefault

        // The Aurora override must have different colours than
        // every default scheme.
        XCTAssertNotEqual(
            aurora.accent, tempDefault.accent,
            "Aurora accent must differ from temperature card default"
        )
        XCTAssertNotEqual(
            aurora.accent, precipDefault.accent,
            "Aurora accent must differ from precipitation card default"
        )
        XCTAssertNotEqual(
            aurora.accent, windDefault.accent,
            "Aurora accent must differ from wind card default"
        )
    }

    // MARK: - Per-card defaults

    /// Each card must have its own default colour scheme that
    /// is distinct from the others. This is the contract that
    /// preserves each card's visual identity when no cosmetic
    /// is equipped.
    func test_cardColorScheme_perCardDefaults_areDistinct() {
        let tempDefault = CardColorScheme.temperatureCardDefault
        let precipDefault = CardColorScheme.precipitationCardDefault
        let windDefault = CardColorScheme.windCardDefault
        let sunriseDefault = CardColorScheme.sunriseCardDefault
        let uvDefault = CardColorScheme.uvIndexCardDefault
        let airQualityDefault = CardColorScheme.airQualityCardDefault
        let pollenDefault = CardColorScheme.pollenCardDefault

        // The temperature card uses warm tones (orange).
        XCTAssertEqual(
            tempDefault.accent, Color.orange,
            "temperature card default must use Color.orange"
        )

        // The precipitation card uses blue tones.
        XCTAssertEqual(
            precipDefault.accent, Color.blue,
            "precipitation card default must use Color.blue"
        )

        // The wind card uses teal tones.
        XCTAssertEqual(
            windDefault.accent, Color.teal,
            "wind card default must use Color.teal"
        )

        // The sunrise/sunset card uses orange tones.
        XCTAssertEqual(
            sunriseDefault.accent, Color.orange,
            "sunrise card default must use Color.orange"
        )

        // The UV index card uses purple tones.
        XCTAssertEqual(
            uvDefault.accent, Color.purple,
            "UV index card default must use Color.purple"
        )

        // The air quality card uses green tones.
        XCTAssertEqual(
            airQualityDefault.accent, Color.green,
            "air quality card default must use Color.green"
        )

        // The pollen card uses green tones.
        XCTAssertEqual(
            pollenDefault.accent, Color.green,
            "pollen card default must use Color.green"
        )

        // The temperature and precipitation defaults must be
        // distinct (different accent colours).
        XCTAssertNotEqual(
            tempDefault.accent, precipDefault.accent,
            "temperature and precipitation card defaults must be distinct"
        )

        // The wind and precipitation defaults must be
        // distinct (different accent colours).
        XCTAssertNotEqual(
            windDefault.accent, precipDefault.accent,
            "wind and precipitation card defaults must be distinct"
        )
    }

    /// The default colour schemes must match the original
    /// hardcoded colours exactly. This is the contract that
    /// preserves the original look of the app when no cosmetic
    /// is equipped.
    func test_cardColorScheme_defaultMatchesOriginalHardcodedColours() {
        // Temperature card: orange accent (warm tones).
        XCTAssertEqual(
            CardColorScheme.temperatureCardDefault.accent,
            Color.orange,
            "temperature card default accent must be Color.orange"
        )

        // Precipitation card: blue accent (rain = water = blue).
        XCTAssertEqual(
            CardColorScheme.precipitationCardDefault.accent,
            Color.blue,
            "precipitation card default accent must be Color.blue"
        )

        // Wind card: teal accent (wind = air = teal).
        XCTAssertEqual(
            CardColorScheme.windCardDefault.accent,
            Color.teal,
            "wind card default accent must be Color.teal"
        )

        // Sunrise/sunset card: orange accent (warm light).
        XCTAssertEqual(
            CardColorScheme.sunriseCardDefault.accent,
            Color.orange,
            "sunrise card default accent must be Color.orange"
        )

        // UV index card: purple accent (UV = radiation = purple).
        XCTAssertEqual(
            CardColorScheme.uvIndexCardDefault.accent,
            Color.purple,
            "UV index card default accent must be Color.purple"
        )

        // Air quality card: green accent (AQI = good = green).
        XCTAssertEqual(
            CardColorScheme.airQualityCardDefault.accent,
            Color.green,
            "air quality card default accent must be Color.green"
        )

        // Pollen card: green accent (pollen = plant = green).
        XCTAssertEqual(
            CardColorScheme.pollenCardDefault.accent,
            Color.green,
            "pollen card default accent must be Color.green"
        )

        // Every default scheme must have `.clear` tint so the
        // default look is unchanged.
        XCTAssertEqual(
            CardColorScheme.temperatureCardDefault.tint,
            Color.clear,
            "temperature card default tint must be Color.clear"
        )
        XCTAssertEqual(
            CardColorScheme.precipitationCardDefault.tint,
            Color.clear,
            "precipitation card default tint must be Color.clear"
        )
        XCTAssertEqual(
            CardColorScheme.windCardDefault.tint,
            Color.clear,
            "wind card default tint must be Color.clear"
        )
        XCTAssertEqual(
            CardColorScheme.sunriseCardDefault.tint,
            Color.clear,
            "sunrise card default tint must be Color.clear"
        )
        XCTAssertEqual(
            CardColorScheme.uvIndexCardDefault.tint,
            Color.clear,
            "UV index card default tint must be Color.clear"
        )
        XCTAssertEqual(
            CardColorScheme.airQualityCardDefault.tint,
            Color.clear,
            "air quality card default tint must be Color.clear"
        )
        XCTAssertEqual(
            CardColorScheme.pollenCardDefault.tint,
            Color.clear,
            "pollen card default tint must be Color.clear"
        )
        XCTAssertEqual(
            CardColorScheme.hourlyForecastCardDefault.tint,
            Color.clear,
            "hourly forecast card default tint must be Color.clear"
        )
        XCTAssertEqual(
            CardColorScheme.dailyForecastCardDefault.tint,
            Color.clear,
            "daily forecast card default tint must be Color.clear"
        )
        XCTAssertEqual(
            CardColorScheme.weatherAlertCardDefault.tint,
            Color.clear,
            "weather alert card default tint must be Color.clear"
        )
        XCTAssertEqual(
            CardColorScheme.heroCardDefault.tint,
            Color.clear,
            "hero card default tint must be Color.clear"
        )
        XCTAssertEqual(
            CardColorScheme.weatherDetailsCardDefault.tint,
            Color.clear,
            "weather details card default tint must be Color.clear"
        )
    }

    // MARK: - Resolution

    /// The resolution logic must apply the Aurora override
    /// when the active palette is `.cosmeticAurora` AND the
    /// user owns the Aurora Palette.
    func test_cardColorScheme_resolve_appliesAuroraOverride() {
        let tempDefault = CardColorScheme.temperatureCardDefault
        let resolvedAurora = CardColorScheme.resolve(
            defaultScheme: tempDefault,
            activePalette: .cosmeticAurora,
            isOwned: { _ in true }
        )
        let resolvedDefault = CardColorScheme.resolve(
            defaultScheme: tempDefault,
            activePalette: .defaultPalette,
            isOwned: { _ in true }
        )

        // When the active palette is `.cosmeticAurora` AND the
        // user owns the Aurora Palette, the resolved scheme
        // must be the Aurora override.
        XCTAssertEqual(
            resolvedAurora, CardColorScheme.auroraOverride,
            "resolve with .cosmeticAurora and ownership must return the Aurora override"
        )

        // When the active palette is the default, the resolved
        // scheme must be the default scheme.
        XCTAssertEqual(
            resolvedDefault, tempDefault,
            "resolve with default palette must return the default scheme"
        )
    }

    /// The resolution logic must NOT apply the Aurora override
    /// when the user doesn't own the Aurora Palette. This is
    /// the contract that prevents the Aurora look from
    /// appearing if the user somehow has the Aurora Palette
    /// selected without owning it.
    func test_cardColorScheme_auroraOverrideOnlyWhenOwned() {
        let tempDefault = CardColorScheme.temperatureCardDefault

        // Aurora palette selected but NOT owned.
        let resolvedNotOwned = CardColorScheme.resolve(
            defaultScheme: tempDefault,
            activePalette: .cosmeticAurora,
            isOwned: { _ in false }
        )

        // The resolved scheme must be the default scheme, not
        // the Aurora override.
        XCTAssertEqual(
            resolvedNotOwned, tempDefault,
            "Aurora palette without ownership must resolve to the default scheme"
        )
        XCTAssertNotEqual(
            resolvedNotOwned, CardColorScheme.auroraOverride,
            "Aurora palette without ownership must not resolve to the Aurora override"
        )

        // Aurora palette selected AND owned.
        let resolvedOwned = CardColorScheme.resolve(
            defaultScheme: tempDefault,
            activePalette: .cosmeticAurora,
            isOwned: { _ in true }
        )

        // The resolved scheme must be the Aurora override.
        XCTAssertEqual(
            resolvedOwned, CardColorScheme.auroraOverride,
            "Aurora palette with ownership must resolve to the Aurora override"
        )
    }

    /// The convenience methods must return the resolved scheme
    /// for each card. This is the contract that the card
    /// views rely on.
    func test_cardColorScheme_convenienceMethods_returnResolvedScheme() {
        // Temperature card with default palette must return the default.
        let tempDefault = CardColorScheme.temperatureCard(
            activePalette: .defaultPalette,
            isOwned: { _ in true }
        )
        XCTAssertEqual(
            tempDefault, CardColorScheme.temperatureCardDefault,
            "temperatureCard(.defaultPalette) must return the default"
        )

        // Temperature card with Aurora palette AND ownership must return the Aurora override.
        let tempAurora = CardColorScheme.temperatureCard(
            activePalette: .cosmeticAurora,
            isOwned: { _ in true }
        )
        XCTAssertEqual(
            tempAurora, CardColorScheme.auroraOverride,
            "temperatureCard(.cosmeticAurora, owned) must return the Aurora override"
        )

        // Temperature card with Aurora palette but NO ownership must return the default.
        let tempAuroraNotOwned = CardColorScheme.temperatureCard(
            activePalette: .cosmeticAurora,
            isOwned: { _ in false }
        )
        XCTAssertEqual(
            tempAuroraNotOwned, CardColorScheme.temperatureCardDefault,
            "temperatureCard(.cosmeticAurora, not owned) must return the default"
        )

        // Precipitation card with default palette must return the default.
        let precipDefault = CardColorScheme.precipitationCard(
            activePalette: .defaultPalette,
            isOwned: { _ in true }
        )
        XCTAssertEqual(
            precipDefault, CardColorScheme.precipitationCardDefault,
            "precipitationCard(.defaultPalette) must return the default"
        )

        // Precipitation card with Aurora palette AND ownership must return the Aurora override.
        let precipAurora = CardColorScheme.precipitationCard(
            activePalette: .cosmeticAurora,
            isOwned: { _ in true }
        )
        XCTAssertEqual(
            precipAurora, CardColorScheme.auroraOverride,
            "precipitationCard(.cosmeticAurora, owned) must return the Aurora override"
        )

        // Wind card with default palette must return the default.
        let windDefault = CardColorScheme.windCard(
            activePalette: .defaultPalette,
            isOwned: { _ in true }
        )
        XCTAssertEqual(
            windDefault, CardColorScheme.windCardDefault,
            "windCard(.defaultPalette) must return the default"
        )

        // Wind card with Aurora palette AND ownership must return the Aurora override.
        let windAurora = CardColorScheme.windCard(
            activePalette: .cosmeticAurora,
            isOwned: { _ in true }
        )
        XCTAssertEqual(
            windAurora, CardColorScheme.auroraOverride,
            "windCard(.cosmeticAurora, owned) must return the Aurora override"
        )
    }
}
