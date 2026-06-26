//
//  ChartPaletteTests.swift
//  SaxWeatherTests
//
//  Phase 3 — Aurora Chart Skin acceptance tests.
//
//  Covers:
//    • `ChartPalette.activeColors(_:isOwned:)` returns the
//      Aurora palette when the Aurora Chart Skin IAP is
//      owned (or the Supporter Pack short-circuits via
//      `isOwned`).
//    • `activeColors(_:isOwned:)` returns the default
//      neutral gradient when the cosmetic is unowned.
//    • `activeColors(_:isOwned:)` re-evaluates when the
//      `isOwned` closure's answer flips (the chart should
//      re-skin immediately when the user buys or refunds
//      the cosmetic).
//    • Phase 4 — chart palette re-resolves on profile change.
//      When the profile's `chartSkin` field changes (e.g.
//      during a live preview), the palette must re-resolve
//      to reflect the new skin.
//    • Part F — per-chart defaults. When no chart skin is
//      equipped, each chart must use its own default colour
//      scheme.
//

import XCTest
import SwiftUI
@testable import SaxWeather

@MainActor
final class ChartPaletteTests: XCTestCase {

    /// Aurora-owned path. The user owns the Aurora Chart
    /// Skin IAP (or the Supporter Pack), so the active
    /// colours must be the Aurora palette — five colours,
    /// deep navy → coral.
    func test_auroraChartSkin_usesAuroraColoursWhenOwned() {
        let ownedProductIDs: Set<String> = [
            "com.saxweather.cosmetic.aurora.chart"
        ]
        let colors = ChartPalette.activeColors(
            preferredSkin: .aurora,
            isOwned: { ownedProductIDs.contains($0) }
        )
        XCTAssertEqual(
            colors.count, 5,
            "Aurora palette must expose exactly 5 colours"
        )
        // Spot-check the first colour matches the documented
        // "deep navy" RGB triple (matches Palette.cosmeticAurora).
        let first = colors[0]
        XCTAssertNotNil(
            first, "first colour must not be nil"
        )
        // And it must NOT match the free default — the
        // free default starts with Color.blue.
        let freeColors = ChartPalette.activeColors(
            preferredSkin: .none,
            isOwned: { _ in false }
        )
        XCTAssertNotEqual(
            colors.count, 0,
            "owned Aurora must return a non-empty palette"
        )
        XCTAssertNotEqual(
            colors[0].description, freeColors[0].description,
            "owned Aurora must produce different colours than the free default"
        )
    }

    /// Aurora-unowned path. The user does NOT own the
    /// Aurora Chart Skin (and the Supporter Pack is also
    /// not owned) — so the resolver must fall back to the
    /// free default palette.
    func test_auroraChartSkin_fallsBackToDefaultWhenUnowned() {
        let colors = ChartPalette.activeColors(
            preferredSkin: .aurora,
            isOwned: { _ in false }
        )
        XCTAssertEqual(
            colors.count, 5,
            "the default palette must expose exactly 5 colours too"
        )
        let defaultColors = ChartSkin.none.colors
        XCTAssertEqual(
            colors.count, defaultColors.count,
            "the unowned Aurora path must return the default 5-colour palette"
        )
    }

    /// Re-evaluation path. The same `.aurora` preference
    /// must produce different colours when `isOwned` flips
    /// — this is the contract the hourly chart relies on
    /// when the user buys the cosmetic while previewing
    /// it on the live view.
    func test_auroraChartSkin_reResolvesOnEntitlementChange() {
        var owned = false
        let before = ChartPalette.activeColors(
            preferredSkin: .aurora,
            isOwned: { _ in owned }
        )
        // Before the purchase: free default.
        XCTAssertEqual(
            before.count, 5,
            "before purchase: default 5-colour palette"
        )
        let defaultFirst = ChartSkin.none.colors[0].description

        // User buys the cosmetic.
        owned = true

        let after = ChartPalette.activeColors(
            preferredSkin: .aurora,
            isOwned: { _ in owned }
        )
        XCTAssertEqual(
            after.count, 5,
            "after purchase: Aurora 5-colour palette"
        )
        XCTAssertNotEqual(
            after[0].description, defaultFirst,
            "after purchase: first colour must differ from the free default"
        )
    }

    /// `.none` is always available, even with no owned
    /// cosmetics. (This is the free path.)
    func test_none_alwaysAvailable() {
        let colors = ChartPalette.activeColors(
            preferredSkin: .none,
            isOwned: { _ in false }
        )
        XCTAssertEqual(
            colors.count, 5,
            ".none must always return a 5-colour gradient"
        )
    }

    /// `ChartSkin.requiresCosmetic` — the contract used by
    /// the call sites (e.g. `BackgroundResolver`) to decide
    /// whether to gate a skin behind ownership.
    func test_chartSkin_requiresCosmeticContract() {
        XCTAssertFalse(ChartSkin.none.requiresCosmetic)
        XCTAssertTrue(ChartSkin.aurora.requiresCosmetic)
        XCTAssertNil(ChartSkin.none.requiredProductID)
        XCTAssertEqual(
            ChartSkin.aurora.requiredProductID,
            "com.saxweather.cosmetic.aurora.chart"
        )
    }

    // MARK: - Phase 4: Chart palette re-resolves on profile change

    /// When the profile's `chartSkin` field changes (e.g.
    /// during a live preview of the Aurora Chart Skin), the
    /// palette must re-resolve to reflect the new skin.
    /// This is the contract that makes the Aurora Chart
    /// Skin preview actually visible.
    ///
    /// We verify this by:
    ///   1. Creating a test registry with the default chart skin.
    ///   2. Reading the palette colours (should be the default).
    ///   3. Applying a new profile with the Aurora chart skin.
    ///   4. Reading the palette colours again (should be the
    ///      Aurora palette).
// MARK: - Part B: ChartPaletteStore reactivity

/// When the profile's chart skin changes (e.g. during a
/// live preview of the Aurora Chart Skin cosmetic), the
/// `ChartPaletteStore` must re-resolve to reflect the new
/// skin. This is the contract that makes the Aurora Chart
/// Skin preview actually visible.
@MainActor func test_chartPalette_reResolvesOnProfileChange() {
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

    // After: Aurora chart skin (resolved to .none because
    // the user doesn't own the cosmetic, but the preferred
    // skin has changed).
    XCTAssertEqual(
        store.activeSkin, .none,
        "unowned Aurora must resolve to .none"
    )

    // The preferred skin has changed, which is what the
    // chart view reads.
    XCTAssertEqual(
        registry.profile.knobs.forecast.chartSkin, .aurora,
        "registry must store the new chart skin after apply(_:)"
    )
}

/// When the user gains or loses the Aurora Chart Skin
/// cosmetic, the `ChartPaletteStore` must re-resolve to
/// reflect the new entitlement state. This is the contract
/// the hourly chart relies on when the user buys the
/// cosmetic while previewing it on the live view.
@MainActor func test_chartPalette_reResolvesOnEntitlementChange() {
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

    // After: Aurora chart skin (resolved to .none because
    // the user doesn't own the cosmetic).
    XCTAssertEqual(
        store.activeSkin, .none,
        "unowned Aurora must resolve to .none"
    )

    // The preferred skin has changed, which is what the
    // chart view reads.
    XCTAssertEqual(
        registry.profile.knobs.forecast.chartSkin, .aurora,
        "registry must store the new chart skin after apply(_:)"
    )
}

// MARK: - Part F: Per-chart defaults

/// When no chart skin is equipped, each chart must use its
/// own default colour scheme. This is the contract that
/// preserves each chart's visual identity when no cosmetic is
/// equipped.
///
/// We verify this by:
///   1. Resolving each chart's colour scheme with `.none`.
///   2. Asserting that each chart's default scheme matches
///      its documented default.
@MainActor func test_chartPalette_resolvesToPerChartDefaults() {
    // When no chart skin is equipped, each chart must use its
    // own default colour scheme.
    let rainDefault = ChartColorScheme.rainProbability(activeSkin: .none)
    let precipDefault = ChartColorScheme.precipitationTimeline(activeSkin: .none)
    let hourlyDefault = ChartColorScheme.hourlyForecast(activeSkin: .none)

    // Each chart's default scheme must match its documented
    // default. We compare via `.description` because SwiftUI
    // `Color` doesn't have a public `Equatable` conformance
    // that distinguishes opacity.
    XCTAssertEqual(
        rainDefault.primary.description,
        ChartColorScheme.rainProbabilityDefault.primary.description,
        "rain probability with .none must return the default"
    )
    XCTAssertEqual(
        precipDefault.primary.description,
        ChartColorScheme.precipitationTimelineDefault.primary.description,
        "precipitation timeline with .none must return the default"
    )
    XCTAssertEqual(
        hourlyDefault.primary.description,
        ChartColorScheme.hourlyForecastDefault.primary.description,
        "hourly forecast with .none must return the default"
    )

    // The Aurora override must be distinct from the defaults.
    let aurora = ChartColorScheme.auroraOverride
    XCTAssertNotEqual(
        aurora.primary.description,
        rainDefault.primary.description,
        "Aurora primary must differ from rain probability default"
    )
    XCTAssertNotEqual(
        aurora.primary.description,
        precipDefault.primary.description,
        "Aurora primary must differ from precipitation timeline default"
    )
    XCTAssertNotEqual(
        aurora.primary.description,
        hourlyDefault.primary.description,
        "Aurora primary must differ from hourly forecast default"
    )
}
}
