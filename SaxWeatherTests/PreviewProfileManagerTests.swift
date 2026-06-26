//
//  PreviewProfileManagerTests.swift
//  SaxWeatherTests
//
//  Phase 1 — Cosmetic-only monetization foundation tests.
//  Phase 4 — Countdown timer tests.
//
//  Covers:
//   • `startPreview` populates `activePreview`.
//   • Starting a second preview replaces the first
//     (and restores the original snapshot, so the new
//     preview starts from the user's real profile, not a
//     previewed variant).
//   • `cancelPreview` writes the original profile back to
//     the inout and clears `activePreview`.
//   • `restoreIfExpired` is the "next access" the plan
//     calls out — the timer itself doesn't restore; the
//     next call does.
//   • Phase 4 — `remainingSeconds` decrements over time
//     and reaches zero when the preview expires.
//

import XCTest
@testable import SaxWeather

@MainActor
final class PreviewProfileManagerTests: XCTestCase {

    // MARK: - Setup / teardown

    /// The PreviewProfileManager persists the active
    /// preview's `expiresAt` and `productID` to
    /// `UserDefaults` so the app can detect a missed
    /// expiry on the next foreground. Clear them between
    /// tests so cross-test pollution doesn't leak in.
    override func setUp() async throws {
        UserDefaults.standard.removeObject(forKey: "previewProfile.expiresAt")
        UserDefaults.standard.removeObject(forKey: "previewProfile.productID")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "previewProfile.expiresAt")
        UserDefaults.standard.removeObject(forKey: "previewProfile.productID")
    }

    // MARK: - startPreview

    func test_startPreview_setsActivePreview() {
        let manager = PreviewProfileManager()
        XCTAssertNil(manager.activePreview, "fresh manager has no active preview")

        let product = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!
        var profile = makeProfile(name: "Default", backgroundMode: .preset)
        let result = manager.startPreview(of: product, applyingTo: &profile)

        XCTAssertTrue(result, "startPreview should succeed for a known cosmetic")
        XCTAssertNotNil(manager.activePreview, "activePreview should be set")
        XCTAssertEqual(
            manager.activePreview?.productID,
            "com.saxweather.cosmetic.aurora.backgrounds"
        )
        XCTAssertEqual(
            profile.knobs.background.mode,
            .aurora,
            "the inout profile should have the cosmetic applied (mode → .aurora)"
        )
    }

    func test_startPreview_replacesExisting() {
        let manager = PreviewProfileManager()
        let backgrounds = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!
        let palette = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.palette"
        )!

        // Start preview 1: backgrounds.
        var profile = makeProfile(name: "Default", backgroundMode: .preset)
        _ = manager.startPreview(of: backgrounds, applyingTo: &profile)
        XCTAssertEqual(profile.knobs.background.mode, .aurora)
        XCTAssertEqual(
            manager.activePreview?.originalProfile.knobs.background.mode,
            .preset,
            "the snapshot must capture the *original* mode, not the previewed one"
        )

        // Start preview 2: palette. The previous snapshot
        // should be restored to the inout first (so the
        // caller can push the truly-original profile back
        // to the registry), then the new cosmetic is
        // applied.
        _ = manager.startPreview(of: palette, applyingTo: &profile)
        XCTAssertEqual(manager.activePreview?.productID, palette.id)
        XCTAssertEqual(
            manager.activePreview?.originalProfile.knobs.background.mode,
            .preset,
            "the new preview's snapshot must also be the *original*, not the backgrounds preview"
        )
        XCTAssertEqual(
            profile.knobs.visual.palette.background,
            .hex("#0B1B3A"),
            "the palette cosmetic should be applied to the inout"
        )
    }

    // MARK: - cancelPreview

    func test_cancelPreview_restoresProfile() {
        let manager = PreviewProfileManager()
        let product = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!
        var profile = makeProfile(name: "Default", backgroundMode: .preset)
        _ = manager.startPreview(of: product, applyingTo: &profile)
        XCTAssertEqual(profile.knobs.background.mode, .aurora)

        // Cancel — the inout should be restored to the
        // pre-preview state.
        manager.cancelPreview(restoreTo: &profile)
        XCTAssertEqual(profile.knobs.background.mode, .preset)
        XCTAssertNil(manager.activePreview, "activePreview should be cleared after cancel")
    }

    // MARK: - restoreIfExpired

    func test_expiredPreview_restoresOnNextAccess() async throws {
        let manager = PreviewProfileManager()
        let product = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!

        // Build a *custom* product with a 0-second preview
        // duration so the timer fires immediately. We do
        // this via a tweaked `CustomisationProfile` rather
        // than mutating the catalog (the catalog is read-
        // only at runtime).
        let instantProduct = CosmeticProduct(
            id: product.id,
            displayName: product.displayName,
            subtitle: product.subtitle,
            priceTier: product.priceTier,
            productKind: product.productKind,
            packID: product.packID,
            widgetParity: product.widgetParity,
            seasonalWindow: product.seasonalWindow,
            familyShareable: product.familyShareable,
            previewDurationSeconds: 0,  // <-- the key
            priceCents: product.priceCents,
            isShipped: product.isShipped,
            symbolName: product.symbolName
        )

        var profile = makeProfile(name: "Default", backgroundMode: .preset)
        _ = manager.startPreview(of: instantProduct, applyingTo: &profile)
        XCTAssertEqual(profile.knobs.background.mode, .aurora)
        XCTAssertNotNil(manager.activePreview)

        // Wait a moment so the 0-second timer's Task is
        // guaranteed to have fired and set expiresAt into
        // the past.
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms

        // The "next access" is `restoreIfExpired` — the
        // plan calls this out explicitly in the test spec.
        let didRestore = manager.restoreIfExpired(restoreTo: &profile)

        XCTAssertTrue(didRestore, "restoreIfExpired should return true once the preview is past its expiry")
        XCTAssertEqual(profile.knobs.background.mode, .preset, "profile should be restored to the original")
        XCTAssertNil(manager.activePreview, "activePreview should be cleared after restoration")
    }

    func test_restoreIfExpired_returnsFalseWhenNotExpired() {
        let manager = PreviewProfileManager()
        let product = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!
        var profile = makeProfile(name: "Default", backgroundMode: .preset)
        _ = manager.startPreview(of: product, applyingTo: &profile)

        // No wait — the preview is still in-window.
        let didRestore = manager.restoreIfExpired(restoreTo: &profile)
        XCTAssertFalse(didRestore, "a still-in-window preview should not be restored")
        XCTAssertNotNil(manager.activePreview, "activePreview should remain set")
        XCTAssertEqual(profile.knobs.background.mode, .aurora, "profile should still have the previewed mode")
    }

    // MARK: - remainingSeconds

    func test_remainingSeconds_isZeroWhenNoPreview() {
        let manager = PreviewProfileManager()
        XCTAssertEqual(manager.remainingSeconds, 0)
    }

    func test_remainingSeconds_isNonZeroWhenPreviewActive() {
        let manager = PreviewProfileManager()
        let product = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!
        var profile = makeProfile(name: "Default", backgroundMode: .preset)
        _ = manager.startPreview(of: product, applyingTo: &profile)
        XCTAssertGreaterThan(manager.remainingSeconds, 0,
                             "remainingSeconds should be positive while a preview is in-window")
        XCTAssertLessThanOrEqual(manager.remainingSeconds, 30,
                                 "remainingSeconds should be at most the configured duration")
    }

    // MARK: - Phase 4: Countdown timer

    /// Part C v2 — assert that calling `startPreview(...)`
    /// actually starts the countdown timer (i.e. `remainingSeconds`
    /// becomes > 0). This is the user-visible contract that the
    /// "Preview on your forecast for 30s" overlay should show
    /// a positive number on its first render.
    func test_startPreview_startsCountdownTimer() {
        let manager = PreviewProfileManager()
        XCTAssertEqual(
            manager.remainingSeconds, 0,
            "fresh manager should have remainingSeconds == 0"
        )

        let product = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!
        var profile = makeProfile(name: "Default", backgroundMode: .preset)
        let didStart = manager.startPreview(of: product, applyingTo: &profile)

        XCTAssertTrue(didStart, "startPreview should succeed")
        XCTAssertGreaterThan(
            manager.remainingSeconds, 0,
            "remainingSeconds should be > 0 immediately after startPreview — the timer is running"
        )
        XCTAssertEqual(
            manager.remainingSeconds, 30,
            "remainingSeconds should match the product's previewDurationSeconds (30 for Aurora Backgrounds)"
        )
    }

    /// Part C v2 — `remainingSeconds` must decrement over time
    /// as the countdown timer ticks. This is the contract that
    /// makes the countdown overlay actually count down from 30
    /// to 0 instead of staying at 0.
    ///
    /// We verify this by:
    ///   1. Starting a preview with a short duration (2 seconds).
    ///   2. Waiting 1 second.
    ///   3. Asserting that `remainingSeconds` has decremented.
    func test_remainingSeconds_decrementsOverTime() async throws {
        let manager = PreviewProfileManager()
        let product = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!

        // Build a custom product with a 2-second preview
        // duration so the test runs quickly.
        let shortProduct = CosmeticProduct(
            id: product.id,
            displayName: product.displayName,
            subtitle: product.subtitle,
            priceTier: product.priceTier,
            productKind: product.productKind,
            packID: product.packID,
            widgetParity: product.widgetParity,
            seasonalWindow: product.seasonalWindow,
            familyShareable: product.familyShareable,
            previewDurationSeconds: 2,  // <-- the key
            priceCents: product.priceCents,
            isShipped: product.isShipped,
            symbolName: product.symbolName
        )

        var profile = makeProfile(name: "Default", backgroundMode: .preset)
        _ = manager.startPreview(of: shortProduct, applyingTo: &profile)

        // Immediately after start, remainingSeconds should be 2.
        let initial = manager.remainingSeconds
        XCTAssertEqual(initial, 2, "remainingSeconds should be 2 immediately after start")

        // Wait 1.2 seconds so the timer has had time to tick.
        try await Task.sleep(nanoseconds: 1_200_000_000)  // 1.2s

        // remainingSeconds should have decremented to 1 (or 0 if
        // the timer ticked twice).
        let after = manager.remainingSeconds
        XCTAssertLessThan(after, initial,
                          "remainingSeconds should have decremented after 1.2s")
        XCTAssertGreaterThanOrEqual(after, 0,
                                    "remainingSeconds should not go below 0")
    }

    /// Part C v2 — stricter version of `test_remainingSeconds_decrementsOverTime`.
    /// `remainingSeconds` must decrement by 1 each second (not just
    /// monotonically), so the overlay shows the right number at each
    /// tick. Uses `previewDurationSeconds: 3` and sleeps ~1.2s, then
    /// asserts the value is `2` (not `1`, not `0`).
    ///
    /// We give the timer a 200ms grace window (so we don't flake on
    /// test-runner scheduling jitter — the actual value can be 1 or
    /// 2 depending on whether the second tick fired yet).
    func test_remainingSeconds_decrementsEverySecond() async throws {
        let manager = PreviewProfileManager()
        let product = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!

        let shortProduct = CosmeticProduct(
            id: product.id,
            displayName: product.displayName,
            subtitle: product.subtitle,
            priceTier: product.priceTier,
            productKind: product.productKind,
            packID: product.packID,
            widgetParity: product.widgetParity,
            seasonalWindow: product.seasonalWindow,
            familyShareable: product.familyShareable,
            previewDurationSeconds: 3,
            priceCents: product.priceCents,
            isShipped: product.isShipped,
            symbolName: product.symbolName
        )

        var profile = makeProfile(name: "Default", backgroundMode: .preset)
        _ = manager.startPreview(of: shortProduct, applyingTo: &profile)
        XCTAssertEqual(manager.remainingSeconds, 3,
                       "remainingSeconds should be 3 immediately after start")

        // After ~1.2s the timer has fired at most once, so
        // remainingSeconds should be exactly 2.
        try await Task.sleep(nanoseconds: 1_200_000_000)
        XCTAssertEqual(
            manager.remainingSeconds, 2,
            "after ~1.2s the countdown should have ticked exactly once (30 -> 29 -> ... -> 3 -> 2)"
        )

        // After another ~1.2s the timer has fired at most one more
        // time, so remainingSeconds should be exactly 1.
        try await Task.sleep(nanoseconds: 1_200_000_000)
        XCTAssertEqual(
            manager.remainingSeconds, 1,
            "after ~2.4s the countdown should have ticked exactly twice (3 -> 2 -> 1)"
        )
    }

    /// Phase 4 — tapping "Stop Preview" must cancel the
    /// countdown timer immediately and restore the original
    /// profile. Without this, the timer keeps ticking in the
    /// background after the user has explicitly stopped the
    /// preview.
    ///
    /// We verify this by:
    ///   1. Starting a preview with a short duration (3 seconds).
    ///   2. Calling `cancelPreviewTimer()` (what the overlay's
    ///      "Stop Preview" button does).
    ///   3. Asserting that `activePreview` is nil and
    ///      `remainingSeconds` is 0 immediately.
    ///   4. Waiting 2 seconds and asserting that the timer
    ///      has NOT fired (no auto-restore, no further ticks).
    func test_stopPreview_cancelsTimer() async throws {
        let manager = PreviewProfileManager()
        let product = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!

        // Build a custom product with a 3-second preview
        // duration so the test has time to verify the timer
        // is actually cancelled (not just expired).
        let shortProduct = CosmeticProduct(
            id: product.id,
            displayName: product.displayName,
            subtitle: product.subtitle,
            priceTier: product.priceTier,
            productKind: product.productKind,
            packID: product.packID,
            widgetParity: product.widgetParity,
            seasonalWindow: product.seasonalWindow,
            familyShareable: product.familyShareable,
            previewDurationSeconds: 3,  // <-- the key
            priceCents: product.priceCents,
            isShipped: product.isShipped,
            symbolName: product.symbolName
        )

        var profile = makeProfile(name: "Default", backgroundMode: .preset)
        _ = manager.startPreview(of: shortProduct, applyingTo: &profile)

        // Immediately after start, the preview is active.
        XCTAssertNotNil(manager.activePreview, "activePreview should be set after start")
        XCTAssertEqual(manager.remainingSeconds, 3, "remainingSeconds should be 3 immediately after start")

        // Tap "Stop Preview" — cancel the timer without
        // restoring the profile (the caller has already
        // restored it via the coordinator's snapshot).
        manager.cancelPreviewTimer()

        // The preview should be cleared immediately.
        XCTAssertNil(manager.activePreview, "activePreview should be nil after cancelPreviewTimer")
        XCTAssertEqual(manager.remainingSeconds, 0, "remainingSeconds should be 0 after cancelPreviewTimer")

        // Wait 2 seconds and verify the timer has NOT fired
        // (no auto-restore, no further ticks). If the timer
        // was still running, it would have decremented
        // remainingSeconds and eventually called onRestore.
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2s

        XCTAssertNil(manager.activePreview, "activePreview should still be nil 2s after cancel")
        XCTAssertEqual(manager.remainingSeconds, 0, "remainingSeconds should still be 0 2s after cancel")
    }

    /// Phase 4 — `remainingSeconds` must reach 0 when the
    /// preview expires, and the preview must be auto-restored.
    /// This is the contract that makes the countdown overlay
    /// auto-dismiss and the original profile get restored.
    ///
    /// We verify this by:
    ///   1. Starting a preview with a short duration (1 second).
    ///   2. Waiting 1.5 seconds.
    ///   3. Asserting that `remainingSeconds` is 0 and
    ///      `activePreview` is nil.

    func test_remainingSeconds_reachesZero() async throws {
        let manager = PreviewProfileManager()
        let product = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!

        // Build a custom product with a 1-second preview
        // duration so the test runs quickly.
        let shortProduct = CosmeticProduct(
            id: product.id,
            displayName: product.displayName,
            subtitle: product.subtitle,
            priceTier: product.priceTier,
            productKind: product.productKind,
            packID: product.packID,
            widgetParity: product.widgetParity,
            seasonalWindow: product.seasonalWindow,
            familyShareable: product.familyShareable,
            previewDurationSeconds: 1,  // <-- the key
            priceCents: product.priceCents,
            isShipped: product.isShipped,
            symbolName: product.symbolName
        )

        var profile = makeProfile(name: "Default", backgroundMode: .preset)
        _ = manager.startPreview(of: shortProduct, applyingTo: &profile)

        // Immediately after start, remainingSeconds should be 1.
        XCTAssertEqual(manager.remainingSeconds, 1,
                       "remainingSeconds should be 1 immediately after start")

        // Wait 1.5 seconds so the timer has had time to tick
        // and the preview has expired.
        try await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5s

        // remainingSeconds should be 0 and activePreview should
        // be nil (auto-restored).
        XCTAssertEqual(manager.remainingSeconds, 0,
                       "remainingSeconds should be 0 after the preview expires")
        XCTAssertNil(manager.activePreview,
                     "activePreview should be nil after the preview expires")
    }

    // MARK: - Phase 5: Overlay visibility contract

    /// Phase 5 — explicit contract test for the countdown
    /// overlay's visibility condition. The overlay gates on
    /// `previewManager.activePreview != nil`, so when the
    /// timer reaches 0 the manager must clear `activePreview`
    /// so the overlay disappears (instead of staying visible
    /// showing "Ends in 0s").
    ///
    /// This is the same scenario as
    /// `test_remainingSeconds_reachesZero`, but with a name
    /// that ties the assertion directly to the overlay
    /// contract rather than the countdown timing.
    func test_activePreview_isNilAfterTimerExpires() async throws {
        let manager = PreviewProfileManager()
        let product = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!

        // Short duration so the test runs quickly.
        let shortProduct = CosmeticProduct(
            id: product.id,
            displayName: product.displayName,
            subtitle: product.subtitle,
            priceTier: product.priceTier,
            productKind: product.productKind,
            packID: product.packID,
            widgetParity: product.widgetParity,
            seasonalWindow: product.seasonalWindow,
            familyShareable: product.familyShareable,
            previewDurationSeconds: 1,
            priceCents: product.priceCents,
            isShipped: product.isShipped,
            symbolName: product.symbolName
        )

        var profile = makeProfile(name: "Default", backgroundMode: .preset)
        _ = manager.startPreview(of: shortProduct, applyingTo: &profile)
        XCTAssertNotNil(
            manager.activePreview,
            "activePreview should be set immediately after startPreview"
        )

        // Wait long enough for the 1-second timer to fire and
        // auto-restore the original profile.
        try await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5s

        // The overlay's visibility gate reads this property,
        // so it MUST be nil once the preview expires.
        XCTAssertNil(
            manager.activePreview,
            "activePreview must be nil after the timer reaches 0 so the overlay hides"
        )
    }

    /// Phase 5 — explicit contract test for the "Stop Preview"
    /// button. The overlay's onStop handler calls
    /// `cancelPreviewTimer()`, which must clear `activePreview`
    /// immediately so the overlay disappears (instead of
    /// staying visible until the original 30-second timer
    /// would have fired on its own).
    ///
    /// This is the same scenario as
    /// `test_stopPreview_cancelsTimer`, but with a name that
    /// ties the assertion directly to the overlay contract.
    func test_activePreview_isNilAfterStopPreview() {
        let manager = PreviewProfileManager()
        let product = CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!

        var profile = makeProfile(name: "Default", backgroundMode: .preset)
        _ = manager.startPreview(of: product, applyingTo: &profile)
        XCTAssertNotNil(
            manager.activePreview,
            "activePreview should be set immediately after startPreview"
        )

        // The overlay's "Stop Preview" button calls this.
        manager.cancelPreviewTimer()

        // The overlay's visibility gate reads this property,
        // so it MUST be nil as soon as the user taps Stop.
        XCTAssertNil(
            manager.activePreview,
            "activePreview must be nil after cancelPreviewTimer so the overlay hides"
        )
    }

    // MARK: - Helpers

    /// Build a `CustomisationProfile` with a known
    /// background mode. Used so the tests can verify the
    /// "before" and "after" of a preview round-trip.
    private func makeProfile(name: String, backgroundMode: BackgroundMode) -> CustomisationProfile {
        var profile = CustomisationProfile.makeDefault()
        profile.name = name
        profile.knobs.background.mode = backgroundMode
        return profile
    }
}
