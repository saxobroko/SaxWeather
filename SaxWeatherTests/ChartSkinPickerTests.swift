//
//  ChartSkinPickerTests.swift
//  SaxWeatherTests
//
//  Phase 5 — Aurora chart-skin picker UI tests.
//
//  Covers:
//   • `ChartSkin.allCases` lists every pickable skin
//     (Default + every shipped Aurora skin).
//   • The picker's `isLocked` computation correctly
//     identifies owned vs unowned skins.
//   • Tapping an owned skin's row commits the
//     selection to the profile.
//   • Tapping a locked skin's row produces the locked
//     product ID for the cosmetics store to open with.
//   • `ChartSkin.displayName` returns user-facing copy
//     for the picker row labels.
//

import XCTest
@testable import SaxWeather

@MainActor
final class ChartSkinPickerTests: XCTestCase {

    // MARK: - Selectable list

    /// The picker's source of truth — `ChartSkin.allCases`
    /// — must include the free `none` case and the
    /// `aurora` case. New themed skins can be added later;
    /// this test guards the contract.
    func test_chartSkinPicker_showsAllSkins() {
        let skins = ChartSkin.allCases
        XCTAssertFalse(skins.isEmpty, "ChartSkin.allCases must not be empty")
        XCTAssertTrue(
            skins.contains(.none),
            "ChartSkin.allCases must contain the free .none entry"
        )
        XCTAssertTrue(
            skins.contains(.aurora),
            "ChartSkin.allCases must contain the .aurora entry"
        )
    }

    /// The free `.none` case must have a `nil`
    /// `requiredProductID` so the picker treats it as
    /// always-available.
    func test_chartSkinPicker_noneHasNoProductID() {
        XCTAssertNil(ChartSkin.none.requiredProductID)
    }

    /// The `.aurora` case must require the matching
    /// product ID so the picker can gate it on
    /// ownership.
    func test_chartSkinPicker_auroraHasCorrectProductID() {
        XCTAssertEqual(
            ChartSkin.aurora.requiredProductID,
            "com.saxweather.cosmetic.aurora.chart"
        )
    }

    // MARK: - Display name

    /// The display name for `.none` is "Default" so the
    /// picker can offer the free option as a labelled
    /// row.
    func test_chartSkinPicker_defaultDisplayName() {
        XCTAssertEqual(ChartSkin.none.displayName, "Default")
    }

    /// The display name for `.aurora` is "Aurora" so the
    /// picker row reads naturally.
    func test_chartSkinPicker_auroraDisplayName() {
        XCTAssertEqual(ChartSkin.aurora.displayName, "Aurora")
    }

    // MARK: - Lock state

    /// When the user does NOT own the Aurora product, the
    /// Aurora row must report itself as locked.
    func test_chartSkinPicker_locksUnownedSkins() {
        let isOwned: (String) -> Bool = { _ in false }
        let isLocked = isSkinLocked(.aurora, isOwned: isOwned)
        XCTAssertTrue(
            isLocked,
            "Aurora row must be locked when the user does not own the product"
        )
    }

    /// When the user DOES own the Aurora product (or the
    /// Supporter Pack), the Aurora row must NOT be locked.
    func test_chartSkinPicker_unlocksOwnedSkins() {
        let isOwned: (String) -> Bool = { _ in true }
        let isLocked = isSkinLocked(.aurora, isOwned: isOwned)
        XCTAssertFalse(
            isLocked,
            "Aurora row must not be locked when the user owns the product"
        )
    }

    /// The free `.none` skin must NEVER be locked.
    func test_chartSkinPicker_defaultIsNeverLocked() {
        // Even when `isOwned` returns false for every
        // product, the .none row is free.
        let isOwned: (String) -> Bool = { _ in false }
        let isLocked = isSkinLocked(.none, isOwned: isOwned)
        XCTAssertFalse(isLocked, "Default row must never be locked")
    }

    // MARK: - Selection commit

    /// Tapping an owned skin must write the corresponding
    /// `ChartSkin` value to the registry's
    /// `forecast.chartSkin` knob.
    func test_chartSkinPicker_commitsSelectionOnTap() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        let isOwned: (String) -> Bool = { _ in true }
        if !isSkinLocked(.aurora, isOwned: isOwned) {
            registry.set(\.forecast.chartSkin, .aurora)
        }
        XCTAssertEqual(
            registry.profile.knobs.forecast.chartSkin,
            .aurora,
            "Tapping the owned Aurora row must commit the Aurora chart skin"
        )
    }

    /// Tapping the free `.none` row must reset the chart
    /// skin to the default.
    func test_chartSkinPicker_commitsDefaultSelectionOnTap() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        // Pre-set to Aurora to verify the commit overwrites.
        registry.set(\.forecast.chartSkin, .aurora)
        XCTAssertEqual(registry.profile.knobs.forecast.chartSkin, .aurora)

        let isOwned: (String) -> Bool = { _ in false }
        if !isSkinLocked(.none, isOwned: isOwned) {
            registry.set(\.forecast.chartSkin, .none)
        }
        XCTAssertEqual(
            registry.profile.knobs.forecast.chartSkin,
            .none,
            "Tapping the Default row must commit the default chart skin"
        )
    }

    // MARK: - Locked navigation

    /// Tapping a locked row must surface the product ID
    /// the picker needs to open the cosmetics store with.
    func test_chartSkinPicker_navigatesToStoreForLockedSkin() {
        let isOwned: (String) -> Bool = { _ in false }
        let isLocked = isSkinLocked(.aurora, isOwned: isOwned)
        XCTAssertTrue(isLocked)
        let pendingLockedProductID: String? = ChartSkin.aurora.requiredProductID
        XCTAssertEqual(
            pendingLockedProductID,
            "com.saxweather.cosmetic.aurora.chart"
        )
    }

    // MARK: - Helpers

    /// Mirror of `ChartSkinRow.isLocked`. The row is
    /// private to the view so the test reproduces the
    /// contract here.
    private func isSkinLocked(
        _ skin: ChartSkin,
        isOwned: (String) -> Bool
    ) -> Bool {
        guard let pid = skin.requiredProductID else { return false }
        return !isOwned(pid)
    }
}
