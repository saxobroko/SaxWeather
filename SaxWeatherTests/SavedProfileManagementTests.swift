//
//  SavedProfileManagementTests.swift
//  SaxWeatherTests
//
//  Phase 7 acceptance tests for saved-profile management and the
//  knob search catalogue:
//
//    • `saveCurrentAs(name:)` adds a profile to `savedProfiles`
//      and deduplicates by name (overwrite, same UUID).
//    • `deleteSavedProfile(id:)` removes a saved profile.
//    • `renameSavedProfile(id:to:)` renames and rejects collisions.
//    • `applySavedProfile(id:)` applies a saved profile.
//    • `searchKnobs(_:)` filters the catalogue by query.
//    • `allKnobs` returns the full catalogue.
//

import XCTest
@testable import SaxWeather

@MainActor
final class SavedProfileManagementTests: XCTestCase {

    // MARK: - saveCurrentAs

    func test_saveCurrentAs_addsProfileToSavedList() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        XCTAssertTrue(registry.savedProfiles.isEmpty)

        registry.saveCurrentAs(name: "My Theme")
        XCTAssertEqual(registry.savedProfiles.count, 1)
        XCTAssertEqual(registry.savedProfiles.first?.name, "My Theme")
    }

    func test_saveCurrentAs_overwritesExistingProfileWithSameName() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        registry.saveCurrentAs(name: "My Theme")
        let originalID = registry.savedProfiles.first?.id
        XCTAssertNotNil(originalID)

        // Tweak the profile, then save under the same name.
        registry.set(\.data.unitSystem, "Imperial")
        registry.saveCurrentAs(name: "My Theme")

        XCTAssertEqual(registry.savedProfiles.count, 1, "Should overwrite, not duplicate")
        XCTAssertEqual(registry.savedProfiles.first?.id, originalID, "UUID should be preserved")
        XCTAssertEqual(registry.savedProfiles.first?.knobs.data.unitSystem, "Imperial")
    }

    func test_saveCurrentAs_trimsWhitespace() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        registry.saveCurrentAs(name: "   Padded Name   ")
        XCTAssertEqual(registry.savedProfiles.first?.name, "Padded Name")
    }

    func test_saveCurrentAs_rejectsEmptyName() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        registry.saveCurrentAs(name: "   ")
        XCTAssertTrue(registry.savedProfiles.isEmpty)
    }

    // MARK: - deleteSavedProfile

    func test_deleteSavedProfile_removesProfile() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        registry.saveCurrentAs(name: "Theme A")
        registry.saveCurrentAs(name: "Theme B")
        XCTAssertEqual(registry.savedProfiles.count, 2)

        let idA = registry.savedProfiles[0].id
        registry.deleteSavedProfile(id: idA)
        XCTAssertEqual(registry.savedProfiles.count, 1)
        XCTAssertEqual(registry.savedProfiles.first?.name, "Theme B")
    }

    func test_deleteSavedProfile_unknownIDIsNoOp() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        registry.saveCurrentAs(name: "Theme A")
        registry.deleteSavedProfile(id: UUID())
        XCTAssertEqual(registry.savedProfiles.count, 1)
    }

    // MARK: - renameSavedProfile

    func test_renameSavedProfile_succeeds() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        registry.saveCurrentAs(name: "Old Name")
        let id = registry.savedProfiles.first!.id

        let result = registry.renameSavedProfile(id: id, to: "New Name")
        XCTAssertTrue(result)
        XCTAssertEqual(registry.savedProfiles.first?.name, "New Name")
    }

    func test_renameSavedProfile_rejectsCollision() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        registry.saveCurrentAs(name: "Theme A")
        registry.saveCurrentAs(name: "Theme B")
        let idA = registry.savedProfiles[0].id

        let result = registry.renameSavedProfile(id: idA, to: "Theme B")
        XCTAssertFalse(result, "Should refuse to rename into an existing name")
        XCTAssertEqual(registry.savedProfiles[0].name, "Theme A")
    }

    func test_renameSavedProfile_rejectsEmptyName() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        registry.saveCurrentAs(name: "Theme A")
        let id = registry.savedProfiles.first!.id

        let result = registry.renameSavedProfile(id: id, to: "   ")
        XCTAssertFalse(result)
        XCTAssertEqual(registry.savedProfiles.first?.name, "Theme A")
    }

    // MARK: - applySavedProfile

    func test_applySavedProfile_replacesActiveProfile() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        registry.set(\.data.unitSystem, "Imperial")
        registry.saveCurrentAs(name: "Imperial Theme")
        let savedID = registry.savedProfiles.first!.id

        // Switch to a different built-in profile, then apply the
        // saved one.
        registry.resetTo(.minimalist)
        XCTAssertEqual(registry.profile.knobs.data.unitSystem, "Metric")

        registry.applySavedProfile(id: savedID)
        XCTAssertEqual(registry.profile.knobs.data.unitSystem, "Imperial")
    }

    func test_applySavedProfile_unknownIDIsNoOp() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        registry.saveCurrentAs(name: "Theme A")
        registry.resetTo(.minimalist)

        registry.applySavedProfile(id: UUID())
        // Should remain on Minimalist (apply didn't change anything).
        XCTAssertEqual(registry.profile.builtIn, .minimalist)
    }

    // MARK: - Codable round trip

    func test_savedProfiles_surviveCodableRoundTrip() throws {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        registry.saveCurrentAs(name: "Theme A")
        registry.saveCurrentAs(name: "Theme B")
        registry.set(\.data.unitSystem, "UK")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(registry.savedProfiles)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode([CustomisationProfile].self, from: data)

        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored[0].name, "Theme A")
        XCTAssertEqual(restored[1].name, "Theme B")
        XCTAssertEqual(restored[0].knobs.data.unitSystem, "UK")
    }
}

// MARK: - Knob search

@MainActor
final class KnobSearchTests: XCTestCase {

    func test_allKnobs_isNotEmpty() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        XCTAssertFalse(registry.allKnobs.isEmpty)
    }

    func test_searchKnobs_emptyQueryReturnsEverything() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        let all = registry.allKnobs.count
        XCTAssertEqual(registry.searchKnobs("").count, all)
        XCTAssertEqual(registry.searchKnobs("   ").count, all)
    }

    func test_searchKnobs_matchesByDisplayName() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        let results = registry.searchKnobs("accent")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.id == "accentColor" })
    }

    func test_searchKnobs_matchesByAlias() {
        // "colour" alias should match "color" tokens (and vice versa).
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        let colour = registry.searchKnobs("colour")
        let color = registry.searchKnobs("color")
        XCTAssertFalse(colour.isEmpty)
        XCTAssertFalse(color.isEmpty)
    }

    func test_searchKnobs_matchesBySymbol() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        let results = registry.searchKnobs("animation")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.id.hasPrefix("lottie") })
    }

    func test_searchKnobs_noMatchReturnsEmpty() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        let results = registry.searchKnobs("zzzz_no_match_zzzz")
        XCTAssertTrue(results.isEmpty)
    }

    func test_searchKnobs_caseInsensitive() {
        let registry = CustomisationRegistry(testProfile: .makeDefault())
        let lower = registry.searchKnobs("font")
        let upper = registry.searchKnobs("FONT")
        let mixed = registry.searchKnobs("FoNt")
        XCTAssertEqual(lower.count, upper.count)
        XCTAssertEqual(lower.count, mixed.count)
    }
}
