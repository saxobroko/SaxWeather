//
//  CosmeticDetailView.swift
//  SaxWeather
//
//  Phase 1 — Cosmetic-only monetization foundation.
//  Phase 3 — Live preview coordinator flow.
//  Phase 4 — Supporter Pack hero now reads the optional
//            `tileImageName` first (so a user-dropped JPEG
//            renders), then falls back to the kind-appropriate
//            `CosmeticTilePlaceholder` (which uses a
//            distinctive gold/amber gradient for the Supporter
//            Pack). Previously the hero used a hardcoded
//            pink/purple gradient that ignored the tile image
//            entirely.
//
//  The detail sheet pushed when a user taps a tile in
//  `CosmeticsStoreView`. Shows the cosmetic's large
//  preview, description, "Buy" / "Owned" action, an
//  optional "Preview on your forecast for 30s" button,
//  and a "Restore Purchases" link at the bottom.
//
//  Phase 3 — the "Preview" button now drives a
//  `CosmeticPreviewCoordinator` instead of silently
//  mutating the profile. The coordinator handles
//  navigation to the relevant live view, runs the
//  countdown, and pops back to this detail view when
//  the preview ends. See `CosmeticPreviewCoordinator` for
//  the full lifecycle.
//  Phase 5 — added the "Use this" / "Use now" affordance.
//  When the user owns the cosmetic, an additional "Use
//  this" button commits the selection to the profile and
//  publishes a `pendingUsage` so `ContentView` can
//  navigate to the matching picker. The button is hidden
//  for cosmetic kinds without a settings page
//  (`supportsUseNow == false`).
//
//  See `plans/COSMETIC_MONETIZATION_PLAN.md` §5.1 for the
//  ethical-copy rules this view follows.
//

import SwiftUI
import StoreKit

/// Detail sheet for a single cosmetic. Presented as a sheet
/// from `CosmeticsStoreView` (and — in Phase 2 — from widget
/// deep links).
struct CosmeticDetailView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var registry: CustomisationRegistry
    @EnvironmentObject private var previewCoordinator: CosmeticPreviewCoordinator
    @EnvironmentObject private var cosmeticUsageCoordinator: CosmeticUsageCoordinator
    // Phase 4 — read the shared preview manager from the
    // environment so the detail sheet always starts previews
    // on the same instance the countdown overlay observes.
    // See `CosmeticsStoreView` for the full rationale.
    @EnvironmentObject private var previewManager: PreviewProfileManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let product: CosmeticProduct

    @State private var isPurchasing: Bool = false
    @State private var purchaseError: String?

    private static let previewTicker = Timer.publish(
        every: 1, on: .main, in: .common
    ).autoconnect()

    var body: some View {
        #if os(iOS)
        NavigationStack {
            content
                .navigationTitle(product.displayName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            cancelPreviewIfActive()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close")
                    }
                }
                .alert("Purchase Failed",
                       isPresented: Binding(
                            get: { purchaseError != nil },
                            set: { if !$0 { purchaseError = nil } }
                       ),
                       presenting: purchaseError) { _ in
                    Button("OK", role: .cancel) { }
                } message: { error in
                    Text(error)
                }
        }
        #else
        VStack(spacing: 0) {
            HStack {
                Text(product.displayName).font(.title2.bold())
                Spacer()
                Button {
                    cancelPreviewIfActive()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
            }
            .padding()
            Divider()
            content
        }
        .frame(minWidth: 500, minHeight: 620)
        .alert("Purchase Failed",
               isPresented: Binding(
                    get: { purchaseError != nil },
                    set: { if !$0 { purchaseError = nil } }
               ),
               presenting: purchaseError) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error)
        }
        #endif
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroPreview
                descriptionSection
                if supportsPreview {
                    previewButton
                }
                purchaseButton
                if supportsUseNow {
                    useNowButton
                }
                if isPreviewing {
                    previewBanner
                }
                metadataSection
                Spacer(minLength: 0)
            }
            .padding()
        }
        .onReceive(Self.previewTicker) { _ in
            // Force the body to re-evaluate every second so
            // any countdown text in the inline preview banner
            // ticks. The coordinator's overlay ticks
            // independently via its own timer.
            _ = previewManager.remainingSeconds
        }
    }

    // MARK: - Hero preview

    private var heroPreview: some View {
        ZStack(alignment: .topTrailing) {
            heroBackground
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            if storeManager.owns(product) {
                ownedBadge.padding(10)
            }
        }
    }

    /// Per-product hero background. Phase 3 — if a custom
    /// tile image has been dropped into
    /// `Assets.xcassets/cosmetic_tile_<short_id>.imageset/`,
    /// render it. Otherwise fall back to:
    ///   1. The Aurora Backgrounds real JPEG (preserved
    ///      behaviour from Phase 3 work).
    ///   2. The Aurora palette gradient for palette
    ///      cosmetics.
    ///   3. The kind-appropriate SF Symbol placeholder
    ///      from `CosmeticTilePlaceholder`.
    ///
    /// Phase 4 — the Supporter Pack now uses the same
    /// `CosmeticTileImage.image(for:)` → `CosmeticTilePlaceholder`
    /// fallback chain as every other cosmetic (previously it
    /// used a hardcoded pink/purple gradient that ignored the
    /// tile image entirely).
    @ViewBuilder
    private var heroBackground: some View {
        if let tileImage = CosmeticTileImage.image(for: product) {
            tileImage
                .resizable()
                .scaledToFill()
        } else if product.id == "com.saxweather.cosmetic.aurora.backgrounds" {
            // Legacy hero: the real Aurora background JPEG,
            // with the existing gradient fallback for when
            // the JPEG isn't on disk. Phase 4 — uses the
            // condition-based asset name (defaults to the
            // "default" Aurora image).
            #if os(iOS)
            if let uiImage = UIImage(
                named: BackgroundResolver.auroraAssetName(
                    forCondition: "default"
                )
            ) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                heroAuroraFallbackGradient
            }
            #elseif os(macOS)
            if let nsImage = NSImage(
                named: BackgroundResolver.auroraAssetName(
                    forCondition: "default"
                )
            ) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                heroAuroraFallbackGradient
            }
            #endif
        } else if product.id == "com.saxweather.cosmetic.aurora.palette" {
            HStack(spacing: 0) {
                ForEach([
                    Color(red: 0.04, green: 0.11, blue: 0.23),
                    Color(red: 0.12, green: 0.31, blue: 0.47),
                    Color(red: 0.36, green: 0.75, blue: 0.74),
                    Color(red: 0.77, green: 0.88, blue: 0.86),
                    Color(red: 0.95, green: 0.71, blue: 0.63)
                ], id: \.description) { colour in
                    colour
                }
            }
        } else if product.id == "com.saxweather.cosmetic.supporter.badge" {
            LinearGradient(
                colors: [.purple.opacity(0.7), .blue.opacity(0.7)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            // Generic kind-appropriate placeholder. Visually
            // distinct per cosmetic kind so the user can tell
            // at a glance what they're looking at. The
            // Supporter Pack falls through here too — its
            // placeholder uses a distinctive gold/amber
            // gradient (see `CosmeticTilePlaceholder`).
            CosmeticTilePlaceholder(product: product)
        }
    }

    /// Defensive missing-asset fallback for the Aurora
    /// Backgrounds hero preview. Mirrors the gradient the
    /// user sees on the home screen if the JPEGs haven't
    /// been dropped into the asset catalog yet.
    private var heroAuroraFallbackGradient: some View {
        let strategy = BackgroundResolver.auroraGradient(
            forCondition: "default"
        )
        if case let .gradient(top, bottom, topOp, bottomOp) = strategy {
            return AnyView(
                LinearGradient(
                    colors: [
                        top.color(for: colorScheme).opacity(topOp),
                        bottom.color(for: colorScheme).opacity(bottomOp)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyView(Color.blue.opacity(0.2))
    }

    private var ownedBadge: some View {
        Label(
            String(localized: "Owned", comment: "Owned badge on a cosmetic tile."),
            systemImage: "checkmark.seal.fill"
        )
        .labelStyle(.titleAndIcon)
        .font(.subheadline.bold())
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.green, in: Capsule())
        .foregroundStyle(.white)
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(product.subtitle)
                .font(.title3)
                .multilineTextAlignment(.leading)
            Text(longDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Honest, factual long-form description per the plan's
    /// ethical-copy rules. No "Unlock" framing, no fake
    /// urgency, no "Limited!" hyperbole.
    private var longDescription: String {
        switch product.id {
        case "com.saxweather.cosmetic.aurora.backgrounds":
            return String(
                localized: "Replaces the eight shipped weather background images with aurora-themed versions. Purely visual — your forecast, your data, your alerts, all work the same. Free alternatives: any custom image you supply, or any of the other built-in presets.",
                comment: "Long description for Aurora Backgrounds."
            )
        case "com.saxweather.cosmetic.aurora.palette":
            return String(
                localized: "Sets the app's five accent colours to deep navy, ocean blue, teal, mint, and coral. Purely visual — every existing customisation knob still works. The free equivalent: pick any other palette, or set each colour manually via the hex picker.",
                comment: "Long description for Aurora Palette."
            )
        case "com.saxweather.cosmetic.supporter.badge":
            return String(
                localized: "Adds a small private acknowledgement in Settings → About. No public visibility, no social comparison, no leaderboard. The free equivalent: no badge, but every other cosmetic is still available.",
                comment: "Long description for Supporter Badge."
            )
        case "com.saxweather.cosmetic.supporter.pack":
            return String(
                localized: "A single one-time purchase that unlocks every current cosmetic and every future cosmetic we ever ship, automatically. No subscriptions, no Family Sharing, no auto-renew. The most cost-effective way to support development and own the entire cosmetic library.",
                comment: "Long description for Supporter Pack."
            )
        default:
            return product.subtitle
        }
    }

    // MARK: - Preview button

    /// `true` for cosmetics that have a meaningful visual
    /// effect the user can preview on their forecast.
    /// Supporter-tier items (Badge, Pack) and bundles have no
    /// single visual effect on the forecast itself, so their
    /// preview button stays hidden.
    private var supportsPreview: Bool {
        switch product.productKind {
        case .backgrounds, .palette, .chart:
            return true
        case .badge, .supporterPack, .bundle,
             .icons, .font, .haptic, .sound,
             .widgetTheme, .appIcon:
            return false
        }
    }

    /// `true` for cosmetics the user can "use now" — i.e.
    /// kinds that map to an in-app settings page
    /// (`backgrounds`, `palette`, `chart`). For these
    /// cosmetics the detail sheet surfaces a "Use this"
    /// / "Use now" button that applies the cosmetic to
    /// the live profile and publishes a `pendingUsage`
    /// so `ContentView` can present the matching picker.
    private var supportsUseNow: Bool {
        switch product.productKind {
        case .backgrounds, .palette, .chart:
            return true
        case .badge, .supporterPack, .bundle,
             .icons, .font, .haptic, .sound,
             .widgetTheme, .appIcon:
            return false
        }
    }

    private var previewButton: some View {
        Button {
            startPreview()
        } label: {
            HStack {
                Image(systemName: isPreviewing ? "stop.circle.fill" : "eye.fill")
                Text(isPreviewing
                     ? String(localized: "End preview", comment: "Button to end an active preview.")
                     : String(
                        localized: "Preview on your forecast for \(product.previewDurationSeconds)s",
                        comment: "Button to start a preview that applies the cosmetic temporarily."
                     ))
                .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(isPreviewing ? .red : .blue)
        .disabled(storeManager.owns(product) == false && !isPreviewing)
    }

    // MARK: - Purchase button

    private var purchaseButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(buttonLabel)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(storeManager.owns(product) ? .green : .blue)
        .disabled(storeManager.owns(product) || isPurchasing)
        .accessibilityLabel(buttonLabel)
    }

    private var buttonLabel: String {
        if storeManager.owns(product) {
            return String(
                localized: "Owned",
                comment: "Owned indicator label on a cosmetic detail sheet."
            )
        }
        return String(
            format: String(
                localized: "Buy $%.2f",
                comment: "Buy button label with the cosmetic's price. %@ is replaced with the formatted price."
            ),
            Double(product.priceCents) / 100.0
        )
    }

    // MARK: - Preview banner

    private var isPreviewing: Bool {
        previewManager.activePreview?.productID == product.id
    }

    @ViewBuilder
    private var previewBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(
                    localized: "Previewing on your forecast",
                    comment: "Banner shown while a preview is active."
                ))
                .font(.subheadline.bold())
                Text("Restores in \(previewManager.remainingSeconds)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                stopPreview(restoreToDetail: false)
            } label: {
                Text("Restore now").font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Price")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "$%.2f", Double(product.priceCents) / 100.0))
            }
            HStack {
                Text("Type")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(productTypeLabel)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Family Sharing")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(localized: "Off", comment: "Family Sharing off indicator."))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .padding()
        .background(Color.secondary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 10))
    }

    private var productTypeLabel: String {
        switch product.priceTier {
        case .micro:     return "Micro"
        case .standard:  return "Standard"
        case .premium:   return "Premium"
        case .bundle:    return "Bundle"
        case .supporter: return "Supporter Pack"
        }
    }

    // MARK: - Use now / Use this

    /// "Use this" / "Use now" button. Tapping it:
    /// 1. Cancels any active preview (the cosmetic is
    ///    about to become the active selection, so the
    ///    preview would otherwise fight the change).
    /// 2. Asks the usage coordinator to apply the
    ///    cosmetic to the profile and publish a
    ///    `pendingUsage` for `ContentView` to consume.
    /// 3. Dismisses the detail sheet so the picker has
    ///    a clean canvas to land on.
    ///
    /// The label switches between "Use now" (just
    /// purchased) and "Use this" (already owned) so the
    /// copy reads naturally for both flows.
    private var useNowButton: some View {
        Button {
            useNow()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text(useNowButtonLabel)
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }

    private var useNowButtonLabel: String {
        if justPurchased {
            return String(
                localized: "Use now",
                comment: "Button to use the cosmetic just purchased."
            )
        }
        return String(
            localized: "Use this",
            comment: "Button to use an already-owned cosmetic."
        )
    }

    /// `true` when the user owns the cosmetic AND
    /// `purchaseJustCompleted` is the most recent signal
    /// we have. The detail view is the only place that
    /// can reliably tell "just purchased" apart from
    /// "owned for a while" — the store manager's
    /// `owns(_:)` stays true after the purchase
    /// completes, so the simplest reliable signal is
    /// "the purchase flow ran on this sheet". We treat
    /// a successful purchase on this sheet as the cue
    /// to switch the label to "Use now".
    @State private var justPurchased: Bool = false

    private func useNow() {
        cancelPreviewIfActive()
        // `storeManager.owns(_:)` returns `true` for the
        // Supporter Pack short-circuit as well, so the
        // coordinator stays a no-op for locked rows the
        // detail view accidentally surfaces.
        cosmeticUsageCoordinator.useNow(product) { pid in
            storeManager.owns(pid)
        }
        dismiss()
    }

    // MARK: - Actions

    private func purchase() async {
        guard let storeKitProduct = storeManager.cosmeticProduct(id: product.id) else {
            // Fall back to catalog's priceCents for the error
            // message — the StoreKit product just hasn't
            // loaded yet (network blip, sandbox issue, etc.).
            purchaseError = "This product isn't available right now. Please try again in a moment."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await storeManager.purchaseCosmetic(storeKitProduct)
            switch result {
            case .success:
                // A successful purchase on this sheet
                // flips the "Use this" label to "Use now"
                // for the lifetime of the sheet. The user
                // can still pick a different cosmetic or
                // close the sheet without tapping the
                // button — that's fine, the label is just
                // a copy hint.
                justPurchased = true
            case .cancelled, .pending:
                break
            case .failed(let message):
                purchaseError = message
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// Phase 3 — drive the live preview coordinator.
    ///
    /// 1. Snapshot the user's current profile.
    /// 2. Start the preview via `PreviewProfileManager` (this
    ///    applies the cosmetic to the registry inout).
    /// 3. Hand the snapshot + product to the coordinator so
    ///    it can pick a destination and trigger navigation.
    /// 4. Dismiss this detail sheet so the live view is
    ///    unobstructed underneath.
    private func startPreview() {
        let originalProfile = registry.profile
        var workingProfile = originalProfile
        _ = previewManager.startPreview(of: product, applyingTo: &workingProfile)
        registry.apply(workingProfile)
        previewCoordinator.startPreview(
            of: product,
            originalProfile: originalProfile
        )
        // The store sheet (host of this detail sheet) listens
        // to `previewCoordinator.presentedDestination` and
        // dismisses itself so the user lands on the right tab.
        dismiss()
    }

    /// Stop an active preview. Called by the inline banner's
    /// "Restore now" button (when the user is still on this
    /// sheet — unusual but supported for safety).
    private func stopPreview(restoreToDetail: Bool) {
        var profile = registry.profile
        previewManager.cancelPreview(restoreTo: &profile)
        registry.apply(profile)
        previewCoordinator.endPreview(
            reopenForProductID: restoreToDetail ? product.id : nil
        )
    }

    /// Cancel any active preview when the sheet dismisses so
    /// the user isn't left with a 30-second timer running in
    /// the background. Only cancels if THIS product is the
    /// active preview — leaves other products' previews alone.
    private func cancelPreviewIfActive() {
        if previewManager.activePreview?.productID == product.id {
            stopPreview(restoreToDetail: false)
        }
    }
}

#if DEBUG
#Preview("Aurora Backgrounds") {
    CosmeticDetailView(
        product: CosmeticCatalog.product(
            id: "com.saxweather.cosmetic.aurora.backgrounds"
        )!
    )
    .environmentObject(StoreManager.shared)
    .environmentObject(CustomisationRegistry.shared)
    .environmentObject(CosmeticPreviewCoordinator())
    .environmentObject(CosmeticUsageCoordinator())
    .environmentObject(PreviewProfileManager())
}
#endif
