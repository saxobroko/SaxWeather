//
//  PalettePickerTests.swift
//  SaxWeatherTests
//
//  Phase 5 — Aurora palette picker UI tests.
//
//  Covers:
//   • `Palette.selectablePalettes` lists every pickable
//     palette (Default + every shipped Aurora palette).
//   • The picker's `isLocked` computation correctly
//     identifies owned vs unowned palettes.
//   • Tapping an owned palette's row commits the
//     selection to the profile.
//   • Tapping a locked palette's row produces the locked
//     product ID for the cosmetics store to open with.
//   • The `displayName` for the active palette is
//     correctly read from the selectable list.
//

import XCTest
@testable import SaxWeather

@MainActor
final class PalettePickerTests: XCTestCase {

    // MARK: - Selectable list

    /// The selectable list must include at least the
    /// free `Default` palette and the `Aurora` palette.
    /// New themed palettes can be added later; this
    /// test guards the contract.
    func test_palettePicker_showsAllPalettes() {
        let entries = Palette.selectablePalettes
        XCTAssertFalse(entries.isEmpty, "selectablePalettes must not be empty")
        XCTAssertTrue(
            entries.contains { $0.id == "default" },
            "selectablePalettes must contain the free Default entry"
        )
        XCTAssertTrue(
            entries.contains { $0.id == "cosmeticAurora" },
            "selectablePalettes must contain the Aurora entry"
        )
    }

    /// The free `Default` entry must have a `nil`
    /// `requiredProductID` so the picker treats it as
    /// always-available.
    func test_palettePicker_defaultHasNoProductID() {
        let entry = Palette.selectablePalettes.first { $0.id == "default" }
        XCTAssertNotNil(entry)
        XCTAssertNil(
            entry?.requiredProductID,
            "Default palette must have no requiredProductID"
        )
    }

    /// The Aurora entry must require the matching
    /// product ID so the picker can gate it on ownership.
    func test_palettePicker_auroraHasCorrectProductID() {
        let entry = Palette.selectablePalettes.first { $0.id == "cosmeticAurora" }
        XCTAssertNotNil(entry)
        XCTAssertEqual(
            entry?.requiredProductID,
            "com.saxweather.cosmetic.aurora.palette"
        )
    }

    // MARK: - Lock state

    /// When the user does NOT own the Aurora product, the
    /// Aurora row must report itself as locked.
    func test_palettePicker_locksUnownedPalettes() {
        let entry = Palette.selectablePalettes.first { $0.id == "cosmeticAurora" }!
        let isOwned: (String) -> Bool = { _ in false }
        let isLocked = isEntryLocked(entry, isOwned: isOwned)
        XCTAssertTrue(
            isLocked,
            "Aurora row must be locked when the user does not own the product"
        )
    }

    /// When the user DOES own the Aurora product (or the
    /// Supporter Pack), the Aurora row must NOT be locked.
    func test_palettePicker_unlocksOwnedPalettes() {
        let entry = Palette.selectablePalettes.first { $0.id == "cosmeticAurora" }!
        let isOwned: (String) -> Bool = { _ in true }
        let isLocked = isEntryLocked(entry, isOwned: isOwned)
        XCTAssertFalse(
            isLocked,
            "Aurora row must not be locked when the user owns the product"
        )
    }

    /// The free `Default` entry must NEVER be locked.
    func test_palettePicker_defaultIsNeverLocked() {
        let entry = Palette.selectablePalettes.first { $0.id == "default" }!
        // Even when `isOwned` returns false for every
        // product, the Default row is free.
        let isOwned: (String) -> Bool = { _ in false }
        let isLocked = isEntryLocked(entry, isOwned: isOwned)
        XCTAssertFalse(isLocked, "Default row must never be locked")
    }

    // MARK: - Selection commit

    /// Tapping an owned palette must write the
    /// corresponding `Palette` value to the registry's
    /// `visual.palette` knob.
    func test_palettePicker_commitsSelectionOnTap() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        let entry = Palette.selectablePalettes.first { $0.id == "cosmeticAurora" }!
        let isOwned: (String) -> Bool = { _ in true }

        // Simulate the onTapOwned closure body
        if !isEntryLocked(entry, isOwned: isOwned) {
            registry.set(\.visual.palette, entry.palette)
        }

        XCTAssertEqual(
            registry.profile.knobs.visual.palette,
            entry.palette,
            "Tapping the owned Aurora row must commit the Aurora palette"
        )
    }

    /// Tapping the free `Default` row must write the
    /// default palette values to the registry.
    func test_palettePicker_commitsDefaultSelectionOnTap() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        // Pre-set to Aurora to verify the commit overwrites.
        registry.set(\.visual.palette, .cosmeticAurora)
        XCTAssertEqual(registry.profile.knobs.visual.palette, .cosmeticAurora)

        let entry = Palette.selectablePalettes.first { $0.id == "default" }!
        let isOwned: (String) -> Bool = { _ in false }
        if !isEntryLocked(entry, isOwned: isOwned) {
            registry.set(\.visual.palette, entry.palette)
        }

        XCTAssertEqual(
            registry.profile.knobs.visual.palette,
            entry.palette,
            "Tapping the Default row must commit the default palette"
        )
    }

    // MARK: - Locked navigation

    /// Tapping a locked row must surface the product ID
    /// the picker needs to open the cosmetics store with.
    /// The picker's row type isn't directly accessible in
    /// tests, so we reproduce the contract here.
    func test_palettePicker_navigatesToStoreForLockedPalette() {
        let entry = Palette.selectablePalettes.first { $0.id == "cosmeticAurora" }!
        let isOwned: (String) -> Bool = { _ in false }
        let isLocked = isEntryLocked(entry, isOwned: isOwned)
        XCTAssertTrue(isLocked)
        // The onTapLocked closure fires with the
        // `requiredProductID`. Assert it's the right one
        // for the cosmetics store to pick up.
        let pendingLockedProductID: String? = entry.requiredProductID
        XCTAssertEqual(
            pendingLockedProductID,
            "com.saxweather.cosmetic.aurora.palette"
        )
    }

    // MARK: - Display name

    /// The display name for the active palette is
    /// resolved by looking up the matching entry. This
    /// guards the contract `PalettePickerRow` relies on.
    func test_palettePicker_activeDisplayName_resolves() {
        let active = Palette.cosmeticAurora
        let entry = Palette.selectablePalettes.first { $0.palette == active }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.displayName, "Aurora")
    }

    /// The display name for the default (empty)
    /// palette falls back to "Default" if no entry
    /// matches.
    func test_palettePicker_defaultDisplayName_isDefault() {
        let active = Palette()
        let entry = Palette.selectablePalettes.first { $0.palette == active }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.displayName, "Default")
    }

    // MARK: - Helpers

    /// Mirror of `SelectablePaletteRow.isLocked`. The
    /// row is private to the view so the test reproduces
    /// the contract here.
    private func isEntryLocked(
        _ entry: SelectablePalette,
        isOwned: (String) -> Bool
    ) -> Bool {
        guard let pid = entry.requiredProductID else { return false }
        return !isOwned(pid)
    }
}
