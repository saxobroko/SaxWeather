//
//  CosmeticUsageCoordinatorTests.swift
//  SaxWeatherTests
//
//  Phase 4 — Purchase → use flow simplification tests.
//
//  Covers:
//   • `useNow(_:)` sets the correct destination for each
//     cosmetic kind that has a settings page.
//   • `useNow(_:)` does NOT set a destination for kinds
//     without a settings page (badge, supporter pack, etc.).
//   • `clearPending()` resets the state.
//

import XCTest
@testable import SaxWeather

@MainActor
final class CosmeticUsageCoordinatorTests: XCTestCase {

    // MARK: - Destination dispatch

    /// Backgrounds → background settings.
    func test_useNow_backgrounds_setsBackgroundSettingsDestination() {
        let coordinator = CosmeticUsageCoordinator()
        let backgrounds = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!

        coordinator.useNow(backgrounds)

        XCTAssertNotNil(coordinator.pendingUsage)
        XCTAssertEqual(
            coordinator.pendingUsage?.destination,
            .backgroundSettings
        )
        XCTAssertEqual(
            coordinator.pendingUsage?.cosmetic.id,
            backgrounds.id
        )
    }

    /// Palette → palette settings.
    func test_useNow_palette_setsPaletteSettingsDestination() {
        let coordinator = CosmeticUsageCoordinator()
        let palette = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.palette"
        )!

        coordinator.useNow(palette)

        XCTAssertNotNil(coordinator.pendingUsage)
        XCTAssertEqual(
            coordinator.pendingUsage?.destination,
            .paletteSettings
        )
        XCTAssertEqual(
            coordinator.pendingUsage?.cosmetic.id,
            palette.id
        )
    }

    /// Chart → chart settings.
    func test_useNow_chart_setsChartSettingsDestination() {
        let coordinator = CosmeticUsageCoordinator()
        let chart = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.chart"
        )!

        coordinator.useNow(chart)

        XCTAssertNotNil(coordinator.pendingUsage)
        XCTAssertEqual(
            coordinator.pendingUsage?.destination,
            .chartSettings
        )
        XCTAssertEqual(
            coordinator.pendingUsage?.cosmetic.id,
            chart.id
        )
    }

    /// Badge / Pack / Bundle / Icons / Font / Haptics /
    /// Sound / Widget Theme / App Icon — no settings page,
    /// so `useNow(_:)` must NOT set a destination.
    func test_useNow_badge_doesNotSetDestination() {
        let coordinator = CosmeticUsageCoordinator()
        let badge = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.supporter.badge"
        )!

        coordinator.useNow(badge)

        XCTAssertNil(
            coordinator.pendingUsage,
            "badge has no settings page — pendingUsage must be nil"
        )
    }

    /// Supporter Pack — no settings page.
    func test_useNow_supporterPack_doesNotSetDestination() {
        let coordinator = CosmeticUsageCoordinator()
        let pack = CosmeticCatalog.product(
            id: CosmeticCatalog.supporterPackID
        )!

        coordinator.useNow(pack)

        XCTAssertNil(
            coordinator.pendingUsage,
            "supporter pack has no settings page — pendingUsage must be nil"
        )
    }

    /// Bundle — no settings page.
    func test_useNow_bundle_doesNotSetDestination() {
        let coordinator = CosmeticUsageCoordinator()
        let bundle = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.bundle.mega.aurora"
        )!

        coordinator.useNow(bundle)

        XCTAssertNil(
            coordinator.pendingUsage,
            "bundle has no settings page — pendingUsage must be nil"
        )
    }

    // MARK: - clearPending

    /// `clearPending()` must reset the state to `nil`.
    func test_clearPending_resetsState() {
        let coordinator = CosmeticUsageCoordinator()
        let backgrounds = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!

        coordinator.useNow(backgrounds)
        XCTAssertNotNil(coordinator.pendingUsage)

        coordinator.clearPending()
        XCTAssertNil(coordinator.pendingUsage)
    }

    /// `clearPending()` is safe to call when no usage is
    /// pending (no-op).
    func test_clearPending_isSafeWhenNoUsagePending() {
        let coordinator = CosmeticUsageCoordinator()
        XCTAssertNil(coordinator.pendingUsage)

        coordinator.clearPending()
        XCTAssertNil(coordinator.pendingUsage)
    }

    // MARK: - Destination dispatch (static)

    /// The static `destination(for:)` helper must return the
    /// correct destination for each kind that has a settings
    /// page.
    func test_destinationForKind_returnsCorrectDestination() {
        XCTAssertEqual(
            CosmeticUsageCoordinator.destination(for: .backgrounds),
            .backgroundSettings
        )
        XCTAssertEqual(
            CosmeticUsageCoordinator.destination(for: .palette),
            .paletteSettings
        )
        XCTAssertEqual(
            CosmeticUsageCoordinator.destination(for: .chart),
            .chartSettings
        )
    }

    /// The static `destination(for:)` helper must return
    /// `nil` for kinds without a settings page.
    func test_destinationForKind_returnsNilForKindsWithoutSettings() {
        let kindsWithoutSettings: [CosmeticKind] = [
            .badge, .supporterPack, .bundle,
            .icons, .font, .haptic, .sound,
            .widgetTheme, .appIcon
        ]
        for kind in kindsWithoutSettings {
            XCTAssertNil(
                CosmeticUsageCoordinator.destination(for: kind),
                "kind \(kind) should not have a usage destination"
            )
        }
    }


    // MARK: - Apply-to-profile behaviour (Phase 5)

    /// `useNow` on the Aurora Palette cosmetic must
    /// set the live profile's `visual.palette` to
    /// `.cosmeticAurora` AND set the destination to
    /// `.paletteSettings` so the picker is presented.
    func test_useNow_palette_setsAuroraPaletteAndNavigatesToPicker() {
        // Start from a known-default registry so the
        // assertion isn't confused by state left over
        // from another test.
        let registry = CustomisationRegistry.shared
        registry.set(\.visual.palette, Palette())
        XCTAssertNotEqual(
            registry.profile.knobs.visual.palette,
            .cosmeticAurora
        )

        let coordinator = CosmeticUsageCoordinator()
        let palette = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.palette"
        )!

        coordinator.useNow(palette) { _ in true }

        XCTAssertEqual(coordinator.pendingUsage?.destination, .paletteSettings)
        XCTAssertEqual(
            registry.profile.knobs.visual.palette,
            .cosmeticAurora,
            "useNow on the Aurora Palette must set the live profile palette to .cosmeticAurora"
        )

        // Reset for the next test.
        registry.set(\.visual.palette, Palette())
    }

    /// `useNow` on the Aurora Chart Skin cosmetic must
    /// set the live profile's `forecast.chartSkin` to
    /// `.aurora` AND set the destination to
    /// `.chartSettings` so the picker is presented.
    func test_useNow_chart_setsAuroraChartSkinAndNavigatesToPicker() {
        let registry = CustomisationRegistry.shared
        registry.set(\.forecast.chartSkin, .none)
        XCTAssertNotEqual(registry.profile.knobs.forecast.chartSkin, .aurora)

        let coordinator = CosmeticUsageCoordinator()
        let chart = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.chart"
        )!

        coordinator.useNow(chart) { _ in true }

        XCTAssertEqual(coordinator.pendingUsage?.destination, .chartSettings)
        XCTAssertEqual(
            registry.profile.knobs.forecast.chartSkin,
            .aurora,
            "useNow on the Aurora Chart Skin must set the live profile chart skin to .aurora"
        )

        // Reset for the next test.
        registry.set(\.forecast.chartSkin, .none)
    }

    /// `useNow` on a cosmetic the user does NOT own
    /// must be a no-op — no profile change, no
    /// destination published. Guards against
    /// accidentally letting a locked row become the
    /// active selection via a programmatic call.
    func test_useNow_doesNothingIfNotOwned() {
        let registry = CustomisationRegistry.shared
        // Start from the default palette.
        registry.set(\.visual.palette, Palette())
        let initialPalette = registry.profile.knobs.visual.palette

        let coordinator = CosmeticUsageCoordinator()
        let palette = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.palette"
        )!

        coordinator.useNow(palette) { _ in false }

        XCTAssertNil(
            coordinator.pendingUsage,
            "useNow on an unowned cosmetic must NOT set pendingUsage"
        )
        XCTAssertEqual(
            registry.profile.knobs.visual.palette,
            initialPalette,
            "useNow on an unowned cosmetic must NOT change the live profile"
        )
    }
}
