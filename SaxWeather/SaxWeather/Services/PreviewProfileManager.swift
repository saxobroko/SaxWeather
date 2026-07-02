
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

    @Published private(set) var remainingSeconds: Int = 0

    var onRestore: ((CustomisationProfile) -> Void)?

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

    func cancelPreviewTimer() {
        guard activePreview != nil else { return }
        clearActivePreview()
    }

    // MARK: - Lazy restoration

    @discardableResult
    func restoreIfExpired(restoreTo profile: inout CustomisationProfile) -> Bool {
        guard let active = activePreview else { return false }
        guard active.expiresAt <= Date() else { return false }
        profile = active.originalProfile
        onRestore?(active.originalProfile)
        clearActivePreview()
        return true
    }

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

    static let previewExpiredNotification = Notification.Name(
        "PreviewProfileManager.previewExpired"
    )
}
