//
//  CosmeticPreviewCoordinator.swift
//  SaxWeather
//
//  Phase 3 — Cosmetic preview UX coordinator.
//
//  The "Preview on your forecast for 30s" button on
//  `CosmeticDetailView` is no longer just a silent mutation
//  of the profile: tapping it now applies the cosmetic AND
//  navigates the user to the most relevant live view so they
//  can actually see what the cosmetic looks like. A
//  countdown overlay sits at the top of the screen for the
//  full 30 seconds. When the timer expires — or the user
//  taps "Stop Preview" — the original profile is restored
//  and the user is returned to the detail view so they can
//  tap Buy if they liked it.
//
//  This coordinator is the single source of truth for that
//  flow. `CosmeticDetailView` calls `startPreview(...)`;
//  `ContentView` observes `presentedDestination` to switch
//  tabs, `shouldReopenDetail` to re-present the cosmetics
//  store sheet after a preview ends, and the
//  `PreviewCountdownOverlay` to show the countdown / stop
//  affordance.
//
//  Threading: `@MainActor` — every state mutation and
//  observation happens on the main actor, matching the
//  existing `PreviewProfileManager` isolation.
//

import SwiftUI
import Combine

/// Which live surface the user should be navigated to for a
/// given preview. `ContentView` reads `presentedDestination`
/// to decide which tab to activate.
///
/// `nil` means "no preview is active, stay where you are".
enum PreviewDestination: Equatable {
    /// The main Weather tab — the cosmetic affects the
    /// background image or the whole-app palette. Used for
    /// `.backgrounds` and `.palette`.
    case mainWeather
    /// The Forecast tab — the cosmetic affects the hourly
    /// chart skin. Used for `.chart`.
    case forecast
}

/// The live-preview coordinator. Lives at the `ContentView`
/// level as a `@StateObject` so the navigation logic and the
/// countdown overlay can both observe it.
@MainActor
final class CosmeticPreviewCoordinator: ObservableObject {

    /// The active preview destination, or `nil` when no
    /// preview is running. `ContentView` observes this to
    /// switch tabs.
    @Published private(set) var presentedDestination: PreviewDestination?

    /// When non-nil, identifies the product ID whose detail
    /// view should be re-presented when the current preview
    /// ends. The view layer consumes + clears this (set it
    /// back to `nil`) to avoid re-firing the same reopen.
    @Published var reopenProductID: String?

    /// The display name of the product currently being
    /// previewed, used by the countdown overlay. `nil` when
    /// no preview is running.
    @Published private(set) var previewingProductName: String?

    /// Snapshot of the original profile, taken at the moment
    /// `startPreview(...)` was called. Read by
    /// `ContentView` to re-apply the user's real profile if
    /// the coordinator is asked to restore (e.g. on expiry
    /// or a `Stop Preview` tap). The coordinator hands this
    /// snapshot back to the `PreviewProfileManager` — the
    /// coordinator itself never mutates the registry.
    @Published private(set) var snapshotProfile: CustomisationProfile?

    // MARK: - Init

    init() {}

    // MARK: - Destination routing

    /// Map a cosmetic kind to the destination its preview
    /// should land on. `nil` for kinds with no meaningful
    /// preview (badge / pack / bundle / icons / font /
    /// haptics / sound / widget theme / app icon — the
    /// "Preview" button is hidden for these per
    /// `CosmeticDetailView.supportsPreview`).
    static func destination(for kind: CosmeticKind) -> PreviewDestination? {
        switch kind {
        case .backgrounds, .palette:
            return .mainWeather
        case .chart:
            return .forecast
        case .badge, .supporterPack, .bundle,
             .icons, .font, .haptic, .sound,
             .widgetTheme, .appIcon:
            return nil
        }
    }

    /// `true` when a preview is currently driving navigation.
    var hasActivePreview: Bool {
        presentedDestination != nil
    }

    // MARK: - Lifecycle

    /// Begin a live preview of `product`. Stores the
    /// destination so `ContentView` can switch tabs, and
    /// caches the display name so the countdown overlay can
    /// label itself.
    ///
    /// This does **not** mutate the registry — that's the
    /// `PreviewProfileManager`'s job. The caller is
    /// expected to call `previewManager.startPreview(...)`
    /// first and pass the same `originalProfile` it
    /// snapshotted to the manager so we hold a consistent
    /// copy here.
    func startPreview(
        of product: CosmeticProduct,
        originalProfile: CustomisationProfile
    ) {
        presentedDestination = Self.destination(for: product.productKind)
        previewingProductName = product.displayName
        snapshotProfile = originalProfile
    }

    /// Clear the active-preview state. Call this after the
    /// caller has called `PreviewProfileManager.cancelPreview(...)`
    /// / `restoreIfExpired(...)` — this method only handles
    /// the coordinator's side of the lifecycle.
    ///
    /// `reopenProductID` is set to the product ID whose
    /// detail view the user should be returned to. Pass
    /// `nil` to skip the reopen step (used by the timer-
    /// expiry path, where we still want to go back to the
    /// detail view).
    func endPreview(reopenForProductID productID: String? = nil) {
        presentedDestination = nil
        previewingProductName = nil
        snapshotProfile = nil
        if let productID = productID {
            reopenProductID = productID
        }
    }
}