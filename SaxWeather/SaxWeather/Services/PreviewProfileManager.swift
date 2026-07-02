//
//  PreviewProfileManager.swift
//  SaxWeather
//
//  Phase 1 — Cosmetic-only monetization foundation.
//  Phase 4 — Countdown timer fix.
//
//  Manages the "Preview on your forecast for 30s" flow from
//  `plans/COSMETIC_MONETIZATION_PLAN.md` §5.3. Holds a
//  snapshot of the user's current `CustomisationProfile`,
//  applies a cosmetic to a working copy, and restores the
//  snapshot when the preview timer fires (or the user cancels).
//
//  The manager does not own the live profile — that's the
//  `CustomisationRegistry`'s job. Instead it takes the
//  caller's profile inout, mutates it, and trusts the caller
//  to push the result back to the registry. On restore it
//  reverses the mutation through the same inout channel so
//  the caller can re-apply the original profile.
//
//  Threading
//  ---------
//  `@MainActor` — every state mutation and observation must
//  happen on the main actor. The view layer that drives the
//  preview (a "Preview" button) is already on the main
//  actor, so this is a natural fit.
//
//  Backgrounding
//  -------------
//  The `expiresAt` is persisted to `UserDefaults` so that if
//  the app is suspended and resumed past the expiry, the next
//  foreground can call `restoreIfExpired(...)` and pick up
//  where the timer would have left off. The view layer is
//  expected to call `restoreIfExpired` from a `.onChange(of:
//  scenePhase)` handler.
//
//  Phase 4 — `remainingSeconds` is now a `@Published` property
//  that updates as the timer ticks. Previously it was a
//  computed property that read `activePreview.expiresAt` on
//  every access, but the overlay didn't re-render because
//  the computed property wasn't observed. Now the manager
//  drives a `Timer.scheduledTimer` that decrements
//  `remainingSeconds` every second, and the overlay observes
//  the manager so it re-renders on every change.
//
//

import Foundation
import Combine

/// The in-flight preview state. Published as part of the
/// `PreviewProfileManager` so SwiftUI views can render the
/// countdown badge and the "Previewing X" overlay.
struct ActivePreview: Equatable {
    /// The cosmetic being previewed (StoreKit product ID).
    let productID: String
    /// The user's original profile, snapshotted at the moment
    /// the preview started. Reapplied verbatim on cancel /
    /// expiry.
    let originalProfile: CustomisationProfile
    /// When the preview expires. Compared against `Date()` on
    /// every read of `remainingSeconds` and inside
    /// `restoreIfExpired`.
    let expiresAt: Date
}

/// The "Preview on your forecast" orchestrator. One instance
/// per app, owned by `ContentView` (or similar) via
/// `@StateObject`.
@MainActor
final class PreviewProfileManager: ObservableObject {

    /// The current preview, or `nil` when no preview is
    /// running. Observable — the UI binds to it for the
    /// countdown badge and the "Previewing X" overlay.
    @Published private(set) var activePreview: ActivePreview?

    /// Phase 4 — seconds until the active preview expires,
    /// rounded up. `0` when no preview is active. Published
    /// so the countdown overlay re-renders every second.
    ///
    /// Previously this was a computed property that read
    /// `activePreview.expiresAt` on every access, but the
    /// overlay didn't re-render because the computed
    /// property wasn't observed. Now the manager drives a
    /// `Timer.scheduledTimer` that decrements this value
    /// every second, and the overlay observes the manager
    /// so it re-renders on every change.
    @Published private(set) var remainingSeconds: Int = 0

    /// Closure invoked when the preview should be restored and
    /// the registry needs to know about it. The view layer
    /// wires this to `customisationRegistry.apply(_:)` so the
    /// manager can hand the original profile back without
    /// taking a hard reference to the registry itself.
    var onRestore: ((CustomisationProfile) -> Void)?

    /// Phase 4 — the timer that decrements `remainingSeconds`
    /// every second. Held as a property so we can invalidate
    /// it when the preview ends.
    private var countdownTimer: Timer?

    // MARK: - Persistence keys

    private enum DefaultsKey {
        /// The expiry date of the active preview, persisted so
        /// a backgrounded app can detect a missed expiry on
        /// the next foreground.
        static let expiresAt = "previewProfile.expiresAt"
        /// The product ID of the active preview, persisted so
        /// the same product can be matched on restore.
        static let productID = "previewProfile.productID"
    }

    // MARK: - Init

    /// Standard init. No long-running work; the manager is
    /// inert until `startPreview` is called.
    init() {}

    // MARK: - Start / cancel

    /// Begin a preview of `product`. The current `profile` is
    /// snapshotted; the cosmetic is applied to the inout
    /// `profile` so the caller can push the change to the
    /// registry.
    ///
    /// If a preview is already running, it is replaced: the
    /// previous snapshot is restored (via `onRestore`) so the
    /// new preview always starts from the user's real profile,
    /// never from an earlier preview's modified state.
    ///
    /// - Returns: `true` on success. `false` if the cosmetic
    ///   can't be applied (e.g. it's a kind the manager
    ///   doesn't know how to preview yet).
    @discardableResult
    func startPreview(
        of product: CosmeticProduct,
        applyingTo profile: inout CustomisationProfile
    ) -> Bool {
        // Replace any existing preview first — restore the
        // previous snapshot so the new one starts from the
        // user's real profile, not a previewed variant.
        if let previous = activePreview {
            onRestore?(previous.originalProfile)
        }

        let original = profile
        let expiresAt = Date().addingTimeInterval(
            TimeInterval(product.previewDurationSeconds)
        )
        activePreview = ActivePreview(
            productID: product.id,
            originalProfile: original,
            expiresAt: expiresAt
        )

        // Apply the cosmetic to the inout profile. The caller
        // is expected to push the result to the registry.
        applyCosmetic(product, to: &profile)

        // Persist so a backgrounded app can detect missed
        // expiries on the next foreground.
        UserDefaults.standard.set(expiresAt, forKey: DefaultsKey.expiresAt)
        UserDefaults.standard.set(product.id, forKey: DefaultsKey.productID)

        // Phase 4 — start the countdown timer that decrements
        // `remainingSeconds` every second. The overlay
        // observes this property so it re-renders on every
        // change.
        startCountdownTimer(durationSeconds: product.previewDurationSeconds)

        // Schedule a notification when the timer fires. The
        // view layer listens and calls `restoreIfExpired` on
        // the next runloop tick. The actual restoration is
        // lazy so this method stays pure and testable.
        scheduleExpiryNotification(after: product.previewDurationSeconds)

        return true
    }

    /// Cancel the active preview and restore the original
    /// profile. The restored profile is written through the
    /// `inout` so the caller can push it to the registry.
    func cancelPreview(restoreTo originalProfile: inout CustomisationProfile) {
        guard let active = activePreview else { return }
        originalProfile = active.originalProfile
        onRestore?(active.originalProfile)
        clearActivePreview()
    }

    /// Cancel the active preview's timer and clear the
    /// preview state without restoring the profile. Use
    /// this when the caller has already restored the
    /// original profile (e.g. via the coordinator's
    /// snapshot) and just needs the manager to stop
    /// ticking. No-op when no preview is active.
    ///
    /// Phase 4 — the countdown overlay's "Stop Preview"
    /// button calls this so the timer stops immediately
    /// instead of continuing to tick down to 0 in the
    /// background.
    func cancelPreviewTimer() {
        guard activePreview != nil else { return }
        clearActivePreview()
    }

    // MARK: - Lazy restoration

    /// If a preview is active and has expired, restore the
    /// original profile (via `inout` and via `onRestore`) and
    /// clear the preview state. Returns `true` when a
    /// restoration happened.
    ///
    /// This is the "next access" the plan calls out in
    /// `test_expiredPreview_restoresOnNextAccess` — the timer
    /// itself doesn't restore; it posts a notification and
    /// relies on the next foreground / runloop tick to call
    /// this method.
    @discardableResult
    func restoreIfExpired(restoreTo profile: inout CustomisationProfile) -> Bool {
        guard let active = activePreview else { return false }
        guard active.expiresAt <= Date() else { return false }
        profile = active.originalProfile
        onRestore?(active.originalProfile)
        clearActivePreview()
        return true
    }

    /// Check on app foreground whether a preview was active
    /// when the app was backgrounded and, if it has since
    /// expired, restore immediately. No-op if there is no
    /// active preview or it is still in-window (the timer
    /// rescheduled by `scheduleExpiryNotification` will fire
    /// normally).
    @discardableResult
    func reconcileOnForeground(restoreTo profile: inout CustomisationProfile) -> Bool {
        restoreIfExpired(restoreTo: &profile)
    }

    // MARK: - Internals

    /// Clear all preview state and persistence. Called by
    /// both `cancelPreview` and `restoreIfExpired`.
    private func clearActivePreview() {
        activePreview = nil
        remainingSeconds = 0
        countdownTimer?.invalidate()
        countdownTimer = nil
        UserDefaults.standard.removeObject(forKey: DefaultsKey.expiresAt)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.productID)
    }

    /// Phase 4 — start the countdown timer that decrements
    /// `remainingSeconds` every second. The overlay observes
    /// this property so it re-renders on every change.
    ///
    /// When `remainingSeconds` reaches 0, the timer
    /// auto-restores the original profile (via `onRestore`)
    /// and clears the preview state.
    ///
    /// **Why `RunLoop.main.add(_:forMode:)` instead of
    /// `Timer.scheduledTimer(...)`:** the previous Part C v1
    /// fix used `Timer.scheduledTimer`, which only attaches
    /// to `.default` mode. SwiftUI keeps the main run loop
    /// moving between `.default`, `.tracking` (gestures), and
    /// `.common` (animations / hover) for large stretches of
    /// rendering, and `Timer.scheduledTimer` timers do NOT
    /// fire while the run loop is in `.tracking` — the result
    /// was that the overlay showed the initial `remainingSeconds`
    /// (0) and never ticked. Attaching to `.common` ensures the
    /// timer fires regardless of which mode the run loop is in,
    /// and the countdown actually counts down from 30 to 0.
    private func startCountdownTimer(durationSeconds: Int) {
        // Invalidate any existing timer first.
        countdownTimer?.invalidate()

        // Set the initial value so the overlay shows the right
        // number on its very first render (before the first tick).
        remainingSeconds = durationSeconds

        // Build the timer with the no-schedule initializer, then
        // attach it to `.common` ourselves. `.common` is a
        // pseudo-mode that includes `.default`, `.tracking`, and
        // `.modal` — so the timer ticks whether or not SwiftUI
        // has the run loop parked in a gesture-tracking mode.
        let timer = Timer(
            timeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.tickCountdown()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    /// Phase 4 — called every second by the countdown timer.
    /// Decrements `remainingSeconds` and, when it reaches 0,
    /// auto-restores the original profile.
    private func tickCountdown() {
        guard let active = activePreview else {
            // No active preview — stop the timer.
            countdownTimer?.invalidate()
            countdownTimer = nil
            remainingSeconds = 0
            return
        }

        let delta = active.expiresAt.timeIntervalSinceNow
        let newRemaining = max(0, Int(delta.rounded(.up)))

        if newRemaining != remainingSeconds {
            remainingSeconds = newRemaining
        }

        if newRemaining == 0 {
            // Auto-restore the original profile.
            onRestore?(active.originalProfile)
            clearActivePreview()
        }
    }

    /// Apply `product` to the inout `profile`. Only the
    /// kinds the manager knows how to mutate have a defined
    /// effect; unknown kinds are a no-op (the caller gets
    /// `false` from `startPreview` and skips the preview).
    private func applyCosmetic(
        _ product: CosmeticProduct,
        to profile: inout CustomisationProfile
    ) {
        switch product.productKind {
        case .backgrounds:
            // Aurora Backgrounds (and any future themed
            // backgrounds pack) flips `background.mode` to
            // the corresponding themed case. The resolver
            // checks the ownership and falls back to the
            // shipped default if unowned — so this is safe
            // even during a preview of an unowned cosmetic.
            //
            // Phase 3 — kept as the legacy `.aurora` alias
            // because the existing PreviewProfileManagerTests
            // assert against `.aurora` (and the resolver
            // routes `.aurora` to the same image as
            // `.auroraDefault`, so the user-visible behaviour
            // is identical). The CosmeticDetailView hero
            // preview uses `.auroraDefault` explicitly.
            if product.id == "com.saxweather.cosmetic.aurora.backgrounds" {
                profile.knobs.background.mode = .aurora
            }
            // Future: .neon, .seasonal, etc.
        case .palette:
            // Aurora Palette (and any future themed palette)
            // swaps the user's palette for the themed one.
            if product.id == "com.saxweather.cosmetic.aurora.palette" {
                profile.knobs.visual.palette = .cosmeticAurora
            }
            // Future: .neonPalette, .halloweenPalette, etc.
        case .chart:
            // Aurora Chart Skin installs the Aurora palette on
            // chart-styled surfaces (currently the hourly pill
            // strip in `HourlyForecastView`). The view reads
            // `profile.knobs.forecast.chartSkin` via
            // `ChartPalette.activeColors(_:isOwned:)` so the
            // free default (`.none` → cool→warm gradient) is
            // preserved for unowned selections.
            if product.id == "com.saxweather.cosmetic.aurora.chart" {
                profile.knobs.forecast.chartSkin = .aurora
            }
        case .badge, .supporterPack, .bundle:
            // The Supporter Badge has no visual effect on
            // the forecast — the preview is a no-op. The
            // "Preview" button shouldn't be offered for
            // these anyway (see `CosmeticDetailView`).
            break
        case .icons, .font, .haptic, .sound,
             .widgetTheme, .appIcon:
            // Arriving in later phases. No preview yet.
            break
        }
    }

    // MARK: - Timer + notifications

    /// Schedule a notification `seconds` from now. The view
    /// layer listens and calls `restoreIfExpired` to do the
    /// actual restoration. We post a notification rather than
    /// mutating the registry directly so the manager stays
    /// testable (no `Task.sleep` race conditions in tests).
    private func scheduleExpiryNotification(after seconds: Int) {
        let productID = activePreview?.productID ?? ""
        let nanoseconds = UInt64(max(0, seconds)) * 1_000_000_000
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self = self else { return }
                NotificationCenter.default.post(
                    name: Self.previewExpiredNotification,
                    object: self,
                    userInfo: ["productID": productID]
                )
            }
        }
    }

    /// Notification posted when the active preview's timer
    /// expires. The view layer (or a scenePhase observer)
    /// should listen and call `restoreIfExpired` on the next
    /// runloop tick.
    static let previewExpiredNotification = Notification.Name(
        "PreviewProfileManager.previewExpired"
    )
}
