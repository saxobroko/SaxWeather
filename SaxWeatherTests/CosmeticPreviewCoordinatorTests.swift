//
//  CosmeticPreviewCoordinatorTests.swift
//  SaxWeatherTests
//
//  Phase 3 — Live cosmetic-preview coordinator tests.
//
//  Covers:
//    • The coordinator dispatches the right destination
//      for each cosmetic kind.
//    • The coordinator restores the original profile when
//      the user taps "Stop Preview" (the explicit
//      endPreview path).
//    • The coordinator restores the original profile when
//      the timer expires (the implicit endPreview path
//      triggered by `presentedDestination` going back to
//      `nil`).
//    • Phase 4 — preview applies the palette to the live
//      profile. When the user previews the Aurora Palette,
//      the live profile's palette must be the Aurora palette
//      (not the default).
//

import XCTest
@testable import SaxWeather

@MainActor
final class CosmeticPreviewCoordinatorTests: XCTestCase {

    // MARK: - Destination dispatch

    /// Backgrounds → main weather view.
    func test_previewCoordinator_dispatchesToCorrectDestinationPerKind_backgrounds() {
        let backgrounds = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!
        XCTAssertEqual(
            CosmeticPreviewCoordinator.destination(for: backgrounds.productKind),
            .mainWeather
        )
    }

    /// Palette → main weather view.
    func test_previewCoordinator_dispatchesToCorrectDestinationPerKind_palette() {
        let palette = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.palette"
        )!
        XCTAssertEqual(
            CosmeticPreviewCoordinator.destination(for: palette.productKind),
            .mainWeather
        )
    }

    /// Chart → forecast view.
    func test_previewCoordinator_dispatchesToCorrectDestinationPerKind_chart() {
        let chart = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.chart"
        )!
        XCTAssertEqual(
            CosmeticPreviewCoordinator.destination(for: chart.productKind),
            .forecast
        )
    }

    /// Badge / Pack / Bundle / Icons / Font / Haptics /
    /// Sound / Widget Theme / App Icon — no live preview
    /// destination. The "Preview" button is hidden for
    /// these per `CosmeticDetailView.supportsPreview`, so
    /// the coordinator must report `nil` defensively in
    /// case it's ever called for one of these kinds.
    func test_previewCoordinator_dispatchesToCorrectDestinationPerKind_kindsWithoutPreview() {
        let kindsWithoutPreview: [CosmeticKind] = [
            .badge, .supporterPack, .bundle,
            .icons, .font, .haptic, .sound,
            .widgetTheme, .appIcon
        ]
        for kind in kindsWithoutPreview {
            XCTAssertNil(
                CosmeticPreviewCoordinator.destination(for: kind),
                "kind \(kind) should not have a preview destination"
            )
        }
    }

    // MARK: - Restore on Stop

    /// When the user taps "Stop Preview" (or the timer
    /// fires), the coordinator must clear its destination,
    /// drop the snapshot, and publish the reopenProductID
    /// so `ContentView` can re-present the detail view.
    func test_previewCoordinator_restoresOnStop() {
        let coordinator = CosmeticPreviewCoordinator()
        let backgrounds = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!
        let original = CustomisationProfile.makeDefault()

        coordinator.startPreview(of: backgrounds, originalProfile: original)
        XCTAssertEqual(coordinator.presentedDestination, .mainWeather)
        XCTAssertNotNil(coordinator.previewingProductName)
        XCTAssertNotNil(coordinator.snapshotProfile)
        XCTAssertTrue(coordinator.hasActivePreview)

        // Simulate the user tapping "Stop Preview".
        coordinator.endPreview(reopenForProductID: backgrounds.id)

        XCTAssertNil(coordinator.presentedDestination)
        XCTAssertNil(coordinator.previewingProductName)
        XCTAssertNil(coordinator.snapshotProfile)
        XCTAssertFalse(coordinator.hasActivePreview)
        XCTAssertEqual(coordinator.reopenProductID, backgrounds.id)
    }

    /// Same as above, but invoked without a reopen product
    /// ID (the user explicitly chose to stop and *not* be
    /// sent back to the detail view). `reopenProductID`
    /// stays `nil`.
    func test_previewCoordinator_stopWithoutReopen() {
        let coordinator = CosmeticPreviewCoordinator()
        let palette = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.palette"
        )!

        coordinator.startPreview(of: palette, originalProfile: .makeDefault())
        coordinator.endPreview(reopenForProductID: nil)

        XCTAssertFalse(coordinator.hasActivePreview)
        XCTAssertNil(coordinator.reopenProductID)
    }

    // MARK: - Restore on timer expiry

    /// When the 30-second timer expires, the preview flow
    /// mirrors the "Stop" path: destination → nil, snapshot
    /// cleared, reopenProductID published so the user is
    /// popped back to the detail view.
    func test_previewCoordinator_restoresOnTimerExpiry() {
        let coordinator = CosmeticPreviewCoordinator()
        let chart = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.chart"
        )!

        coordinator.startPreview(of: chart, originalProfile: .makeDefault())
        XCTAssertEqual(coordinator.presentedDestination, .forecast)

        // Simulate the timer firing — `ContentView`'s
        // onChange handler would call endPreview with the
        // product ID so the user lands back on the detail
        // view.
        coordinator.endPreview(reopenForProductID: chart.id)

        XCTAssertNil(coordinator.presentedDestination)
        XCTAssertFalse(coordinator.hasActivePreview)
        XCTAssertEqual(coordinator.reopenProductID, chart.id)
    }

    // MARK: - Snapshot integrity

    /// The snapshot stored on the coordinator must be the
    /// exact profile passed to `startPreview(...)` — the
    /// caller relies on this to restore the user's real
    /// profile when the preview ends.
    func test_previewCoordinator_preservesSnapshot() {
        let coordinator = CosmeticPreviewCoordinator()
        let product = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!

        var profile = CustomisationProfile.makeDefault()
        profile.name = "My Custom Theme"
        profile.knobs.background.mode = .preset

        coordinator.startPreview(of: product, originalProfile: profile)

        let snapshot = coordinator.snapshotProfile
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.name, "My Custom Theme")
        XCTAssertEqual(snapshot?.knobs.background.mode, .preset)
    }

    // MARK: - Phase 4: Preview applies palette to live profile

    /// When the user previews the Aurora Palette, the live
    /// profile's palette must be the Aurora palette (not the
    /// default). This is the contract that makes the Aurora
    /// Palette preview actually visible.
    ///
    /// We verify this by:
    ///   1. Creating a test registry with the default palette.
    ///   2. Starting a preview of the Aurora Palette via
    ///      `PreviewProfileManager.startPreview(...)`.
    ///   3. Applying the previewed profile to the registry.
    ///   4. Asserting that the registry's palette is the
    ///      Aurora palette.
    func test_preview_appliesPaletteToLiveProfile() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        let manager = PreviewProfileManager()
        let palette = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.palette"
        )!

        // Before: default palette.
        XCTAssertNotEqual(
            registry.profile.knobs.visual.palette,
            .cosmeticAurora,
            "default profile must not have the Aurora palette"
        )

        // Start the preview. The manager applies the cosmetic
        // to the inout profile.
        var workingProfile = registry.profile
        _ = manager.startPreview(of: palette, applyingTo: &workingProfile)

        // The inout profile must have the Aurora palette.
        XCTAssertEqual(
            workingProfile.knobs.visual.palette,
            .cosmeticAurora,
            "previewed profile must have the Aurora palette"
        )

        // Apply the previewed profile to the registry (this is
        // what `CosmeticDetailView.startPreview()` does).
        registry.apply(workingProfile)

        // The registry must now have the Aurora palette.
        XCTAssertEqual(
            registry.profile.knobs.visual.palette,
            .cosmeticAurora,
            "registry must store the Aurora palette after apply(_:)"
        )
    }
// MARK: - Part B: Preview applies chart skin to live profile

/// When the user previews the Aurora Chart Skin, the live
/// profile's chart skin must be the Aurora chart skin (not
/// the default). This is the contract that makes the Aurora
/// Chart Skin preview actually visible.
///
/// We verify this by:
///   1. Creating a test registry with the default chart skin.
///   2. Starting a preview of the Aurora Chart Skin via
///      `PreviewProfileManager.startPreview(...)`.
///   3. Applying the previewed profile to the registry.
///   4. Asserting that the registry's chart skin is the
///      Aurora chart skin.
@MainActor func test_preview_appliesChartSkinToLiveProfile() {
    let registry = CustomisationRegistry(testProfile: .makeDefault())
    let manager = PreviewProfileManager()
    let chart = CosmeticCatalog.product(
        id: "com.saxweather.cosmetic.aurora.chart"
    )!

    // Before: default chart skin.
    XCTAssertNotEqual(
        registry.profile.knobs.forecast.chartSkin,
        .aurora,
        "default profile must not have the Aurora chart skin"
    )

    // Start the preview. The manager applies the cosmetic
    // to the inout profile.
    var workingProfile = registry.profile
    _ = manager.startPreview(of: chart, applyingTo: &workingProfile)

    // The inout profile must have the Aurora chart skin.
    XCTAssertEqual(
        workingProfile.knobs.forecast.chartSkin,
        .aurora,
        "previewed profile must have the Aurora chart skin"
    )

    // Apply the previewed profile to the registry (this is
    // what `CosmeticDetailView.startPreview()` does).
    registry.apply(workingProfile)

    // The registry must now have the Aurora chart skin.
    XCTAssertEqual(
        registry.profile.knobs.forecast.chartSkin,
        .aurora,
        "registry must store the Aurora chart skin after apply(_:)"
    )
}
}
