//
//  CosmeticsStoreView.swift
//  SaxWeather
//
//  Phase 1 — Cosmetic-only monetization foundation.
//  Phase 2 — added `initialPendingProductID` so the view can
//            be opened directly on a specific product via the
//            `saxweather://cosmetic/<productID>` URL scheme
//            (see `CosmeticDeepLinkHandler`).
//  Phase 3 — `FeaturedCosmeticCard` and
//            `CosmeticDetailView` both read the optional
//            `tileImageName` from each `CosmeticProduct`.
//            When a custom tile image has been dropped into
//            `Assets.xcassets/cosmetic_tile_<short_id>.imageset/`,
//            it's used; otherwise a kind-appropriate SF Symbol
//            placeholder fills in.
//  Phase 4 — `SupporterPackCard` now reads the optional
//            `tileImageName` too (previously it used a
//            hardcoded pink/purple gradient that ignored the
//            tile image entirely). The card also gets an
//            honest "Unlocks everything" overlay with a
//            `sparkles` icon.
//

import SwiftUI
import StoreKit

/// Top-level cosmetics store. Pushed onto Settings' navigation
/// stack via the "Cosmetics" row added in Phase 1. Holds the
/// `PreviewProfileManager` as a `@StateObject` so its
/// lifetime matches the view's.
///
/// Phase 2 — the `initialPendingProductID` parameter lets
/// `ContentView` open this store already pointing at a
/// specific product (via the deep link handler). The view
/// looks up the matching `CosmeticProduct` from the catalog
/// on first appear and auto-presents `CosmeticDetailView` for
/// it.
///
/// Phase 3 — observes `CosmeticPreviewCoordinator` so the
/// store sheet auto-dismisses when a live preview starts
/// (the user is being navigated to a live view).
struct CosmeticsStoreView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var registry: CustomisationRegistry
    @EnvironmentObject private var previewCoordinator: CosmeticPreviewCoordinator
    // Phase 4 — read the shared preview manager from the
    // environment so the store sheet always observes the
    // same instance as the countdown overlay in `ContentView`.
    // Previously this was an `@ObservedObject` parameter that
    // defaulted to a fresh `PreviewProfileManager()` when the
    // caller passed `nil` — which meant any sheet opened
    // outside of `ContentView` (Settings → Cosmetics, the
    // palette / chart / background pickers) created its own
    // throwaway instance. The preview then ran on the
    // throwaway instance while the overlay observed the
    // original instance, which still had `remainingSeconds
    // == 0` — so the UI showed "Ends in 0s" immediately.
    @EnvironmentObject private var previewManager: PreviewProfileManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: CosmeticProduct?
    @State private var isRestoring: Bool = false
    @State private var restoreBanner: RestoreBanner?

    /// Phase 2 — when non-nil, the view auto-presents
    /// `CosmeticDetailView` for the matching product on first
    /// appear. Set by `ContentView` after it observes a
    /// non-nil value from `CosmeticDeepLinkHandler.pendingProductID`.
    let initialPendingProductID: String?

    /// Default init — used by Settings, the debug menu, and
    /// any other consumer that just wants to open the store
    /// at the top level.
    @MainActor
    init() {
        self.initialPendingProductID = nil
    }

    /// Designated init for deep-linked opens. The caller
    /// passes the validated product ID; the view looks the
    /// product up from `CosmeticCatalog` itself.
    @MainActor
    init(initialPendingProductID: String?) {
        self.initialPendingProductID = initialPendingProductID
    }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            content
                .navigationTitle(String(
                    localized: "Cosmetics",
                    comment: "Title of the cosmetics store view."
                ))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel(String(
                            localized: "Close",
                            comment: "Accessibility label for the close button."
                        ))
                    }
                }
                .sheet(item: $selectedProduct) { product in
                    CosmeticDetailView(product: product)
                }
                .onAppear {
                    wirePreviewManager()
                    presentDeepLinkedProductIfNeeded()
                }
        }
        #else
        VStack(spacing: 0) {
            HStack {
                Text(String(
                    localized: "Cosmetics",
                    comment: "Title of the cosmetics store view."
                ))
                .font(.title2.bold())
                Spacer()
                Button {
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
        .frame(minWidth: 600, minHeight: 700)
        .sheet(item: $selectedProduct) { product in
            CosmeticDetailView(product: product)
        }
        .onAppear {
            wirePreviewManager()
            presentDeepLinkedProductIfNeeded()
        }
        #endif
    }

    // MARK: - Deep-link handling

    /// Auto-present `CosmeticDetailView` for the product
    /// matching `initialPendingProductID`. Safe to call
    /// multiple times — guards against re-presenting the
    /// same product when SwiftUI re-fires `onAppear`.
    private func presentDeepLinkedProductIfNeeded() {
        guard let productID = initialPendingProductID else { return }
        guard let product = CosmeticCatalog.product(id: productID) else { return }
        // Don't overwrite an already-presented detail sheet.
        guard selectedProduct == nil else { return }
        selectedProduct = product
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                featuredCarousel
                categoryList
                supporterPackSection
                footerSection
            }
            .padding()
        }
        .overlay(alignment: .top) {
            if let banner = restoreBanner {
                RestoreBannerView(banner: banner) {
                    restoreBanner = nil
                }
            }
        }
        // Observe the preview timer so the count-down
        // badge in the corner ticks every second. SwiftUI
        // re-evaluates the view body on every publish.
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            // `remainingSeconds` is read inside the overlay;
            // touching it here keeps SwiftUI honest.
            _ = previewManager.remainingSeconds
        }
        // Phase 3 — when a live preview starts (the user
        // tapped "Preview" inside `CosmeticDetailView`),
        // dismiss this sheet so the user lands on the
        // correct live view underneath. The coordinator's
        // `presentedDestination` drives `ContentView`'s
        // tab switch.
        .onChange(of: previewCoordinator.presentedDestination) { newValue in
            if newValue != nil {
                dismiss()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(String(
                localized: "Make SaxWeather yours.",
                comment: "Cosmetics store headline."
            ))
            .font(.title2.bold())
            .multilineTextAlignment(.center)

            Text(String(
                localized: "Every cosmetic is optional — no features are paywalled.",
                comment: "Cosmetics store subtitle emphasising no paywalled features."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    // MARK: - Featured carousel

    private var featuredCarousel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(
                localized: "Featured",
                comment: "Section header for the featured carousel."
            ))
            .font(.headline)
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(CosmeticCatalog.shippedProducts
                        .filter { $0.productKind != .supporterPack }
                        .sorted { $0.priceCents < $1.priceCents }
                    ) { product in
                        FeaturedCosmeticCard(
                            product: product,
                            isOwned: storeManager.owns(product),
                            isPurchasing: storeManager.purchaseInProgressID == product.id
                        ) {
                            selectedProduct = product
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Category list

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(
                localized: "Packs",
                comment: "Section header for the pack list."
            ))
            .font(.headline)
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(visiblePacks, id: \.id) { pack in
                    PackDisclosureRow(
                        pack: pack,
                        products: CosmeticCatalog.products(inPack: pack.id),
                        isOwned: { product in storeManager.owns(product) },
                        isPurchasing: { product in storeManager.purchaseInProgressID == product.id },
                        onTapProduct: { selectedProduct = $0 }
                    )
                }
            }
        }
    }

    /// The packs visible in the store list. The Supporter
    /// Pack is handled separately in `supporterPackSection`
    /// so it's not duplicated here.
    private var visiblePacks: [CosmeticPack] {
        CosmeticCatalog.shippedProducts
            .filter { $0.productKind != .supporterPack }
            .reduce(into: [CosmeticPack]()) { partial, product in
                guard let packID = product.packID else { return }
                if let idx = partial.firstIndex(where: { $0.id == packID }) {
                    return  // already added
                }
                partial.append(CosmeticPack(id: packID, displayName: packID.capitalized))
            }
    }

    // MARK: - Supporter Pack section

    private var supporterPackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let supporterPack = CosmeticCatalog.product(
                id: CosmeticCatalog.supporterPackID
            ) {
                SupporterPackCard(
                    product: supporterPack,
                    isOwned: storeManager.owns(supporterPack),
                    isPurchasing: storeManager.purchaseInProgressID == supporterPack.id
                ) {
                    selectedProduct = supporterPack
                }
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await restorePurchases() }
            } label: {
                if isRestoring {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(String(
                        localized: "Restore Purchases",
                        comment: "Button to restore previously purchased cosmetics."
                    ))
                    .font(.subheadline)
                }
            }
            .buttonStyle(.bordered)
            .disabled(isRestoring)

            Text(String(
                localized: "All cosmetics are optional. SaxWeather is fully functional without any purchase.",
                comment: "Footer reassurance copy in the cosmetics store."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }

    // MARK: - Preview wiring

    /// Hook the preview manager up to the registry so a
    /// preview swap round-trips through the live profile.
    private func wirePreviewManager() {
        previewManager.onRestore = { profile in
            registry.apply(profile)
        }
    }

    // MARK: - Restore purchases

    private func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }
        await storeManager.restorePurchases()
        let ownedCount = CosmeticCatalog.shippedProducts
            .filter { storeManager.owns($0) }
            .count
        restoreBanner = RestoreBanner(
            message: String(
                localized: "Restored. You own \(ownedCount) cosmetic\(ownedCount == 1 ? "" : "s").",
                comment: "Confirmation banner shown after Restore Purchases completes."
            )
        )
    }
}

// MARK: - FeaturedCosmeticCard

/// A single horizontal carousel card for a featured
/// cosmetic. Phase 3 — renders the product's optional
/// `tileImageName` if the user has dropped a JPEG into the
/// matching imageset; otherwise falls back to the SF Symbol
/// placeholder.
struct FeaturedCosmeticCard: View {
    let product: CosmeticProduct
    let isOwned: Bool
    let isPurchasing: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    tileImage
                        .frame(height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if isOwned {
                        ownedBadge
                            .padding(8)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(product.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack {
                    Text(isOwned
                         ? String(localized: "Owned ✓", comment: "Owned indicator label on a cosmetic tile.")
                         : priceString)
                        .font(.subheadline.bold())
                        .foregroundStyle(isOwned ? .green : .blue)
                    Spacer()
                    if isPurchasing {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .padding(12)
            .frame(width: 220, height: 250, alignment: .topLeading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(product.displayName). \(product.subtitle). \(isOwned ? "Owned" : priceString)"
        )
        .accessibilityAddTraits(.isButton)
    }

    /// The featured-card hero image. Resolves to the
    /// product's `tileImageName` if present (and the JPEG
    /// has been dropped into the asset catalog); otherwise
    /// falls back to a kind-appropriate SF Symbol
    /// placeholder.
    @ViewBuilder
    private var tileImage: some View {
        if let image = CosmeticTileImage.image(for: product) {
            image
                .resizable()
                .scaledToFill()
        } else {
            CosmeticTilePlaceholder(product: product)
        }
    }

    /// Pre-formatted price string from the catalog's
    /// `priceCents` field. Used as a fallback when the
    /// StoreKit product hasn't loaded yet.
    private var priceString: String {
        let dollars = Double(product.priceCents) / 100.0
        return String(format: "$%.2f", dollars)
    }

    private var ownedBadge: some View {
        Label(
            String(localized: "Owned", comment: "Owned badge on a cosmetic tile."),
            systemImage: "checkmark.seal.fill"
        )
        .labelStyle(.iconOnly)
        .imageScale(.large)
        .foregroundStyle(.white, .green)
    }
}

// MARK: - CosmeticPack

/// Lightweight pack descriptor for the category list. The
/// "pack" is just a logical grouping — there's no separate
/// pack object in the catalog. Built on demand by
/// `CosmeticsStoreView.visiblePacks`.
struct CosmeticPack: Identifiable {
    let id: String
    let displayName: String
}

// MARK: - PackDisclosureRow

/// Expandable row showing every product in a pack. Tapping a
/// product opens the detail sheet.
struct PackDisclosureRow: View {
    let pack: CosmeticPack
    let products: [CosmeticProduct]
    let isOwned: (CosmeticProduct) -> Bool
    let isPurchasing: (CosmeticProduct) -> Bool
    let onTapProduct: (CosmeticProduct) -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "shippingbox.fill")
                        .foregroundStyle(.blue)
                    Text(pack.displayName)
                        .font(.headline)
                    Spacer()
                    Text("\(products.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding()
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pack: \(pack.displayName), \(products.count) items")
            .accessibilityHint(isExpanded ? "Collapse" : "Expand")

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(products) { product in
                        ProductRow(
                            product: product,
                            isOwned: isOwned(product),
                            isPurchasing: isPurchasing(product),
                            onTap: { onTapProduct(product) }
                        )
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - ProductRow

/// A single cosmetic row inside an expanded pack.
struct ProductRow: View {
    let product: CosmeticProduct
    let isOwned: Bool
    let isPurchasing: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Phase 3 — render a small thumbnail of the
                // tile image when present, otherwise the
                // kind-appropriate SF Symbol.
                if let image = CosmeticTileImage.image(for: product) {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: product.symbolName)
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 32)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(product.displayName)
                            .font(.subheadline.weight(.semibold))
                        if isOwned {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .imageScale(.small)
                        }
                    }
                    Text(product.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if isPurchasing {
                    ProgressView().controlSize(.small)
                } else if isOwned {
                    Text(String(localized: "Owned", comment: "Owned indicator label on a cosmetic row."))
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                } else {
                    Text(priceString)
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.displayName). \(product.subtitle). \(isOwned ? "Owned" : priceString)")
        .accessibilityAddTraits(.isButton)
    }

    private var priceString: String {
        String(format: "$%.2f", Double(product.priceCents) / 100.0)
    }
}

// MARK: - SupporterPackCard

/// Special card for the Supporter Pack. The pack is
/// render-distinct from the regular catalogue items so it
/// reads as a "thank you for funding" affordance.
///
/// Phase 4 — the hero now reads the optional `tileImageName`
/// first (so a user-dropped JPEG renders), then falls back to
/// the kind-appropriate `CosmeticTilePlaceholder` (which uses
/// a distinctive gold/amber gradient for the Supporter Pack).
/// Previously the card used a hardcoded pink/purple gradient
/// that ignored the tile image entirely.
struct SupporterPackCard: View {
    let product: CosmeticProduct
    let isOwned: Bool
    let isPurchasing: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    tileImage
                        .frame(height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if isOwned {
                        Label(
                            String(localized: "Owned", comment: "Owned badge on a cosmetic tile."),
                            systemImage: "checkmark.seal.fill"
                        )
                        .labelStyle(.iconOnly)
                        .imageScale(.large)
                        .foregroundStyle(.white, .green)
                        .padding(8)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                    Text(product.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    Text(isOwned
                         ? String(localized: "Owned ✓", comment: "Owned indicator label on the Supporter Pack card.")
                         : String(format: "$%.2f", Double(product.priceCents) / 100.0))
                        .font(.subheadline.bold())
                        .foregroundStyle(isOwned ? .green : .pink)
                    Spacer()
                    if isPurchasing {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color.pink.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.displayName). \(product.subtitle). \(isOwned ? "Owned" : String(format: "$%.2f", Double(product.priceCents) / 100.0))")
        .accessibilityAddTraits(.isButton)
    }

    /// The Supporter Pack hero. Resolves to the product's
    /// `tileImageName` if present (and the JPEG has been
    /// dropped into the asset catalog); otherwise falls back
    /// to the kind-appropriate SF Symbol placeholder (which
    /// uses a distinctive gold/amber gradient for the
    /// Supporter Pack).
    @ViewBuilder
    private var tileImage: some View {
        if let image = CosmeticTileImage.image(for: product) {
            image
                .resizable()
                .scaledToFill()
                .overlay(supporterPackOverlay)
        } else {
            CosmeticTilePlaceholder(product: product)
                .overlay(supporterPackOverlay)
        }
    }

    /// Honest overlay copy + icon for the Supporter Pack.
    /// Reads as "premium" without being manipulative — the
    /// `sparkles` icon and "Unlocks everything" text are
    /// factual (the pack does unlock every current and
    /// future cosmetic).
    private var supporterPackOverlay: some View {
        VStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
            Text(String(
                localized: "Unlocks everything",
                comment: "Overlay text on the Supporter Pack tile card."
            ))
            .font(.caption.bold())
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
        }
        .padding(8)
    }
}

// MARK: - RestoreBanner

/// A small transient banner shown after a "Restore
/// Purchases" completes. Dismissible.
struct RestoreBanner: Equatable {
    let message: String
    let id = UUID()
}

struct RestoreBannerView: View {
    let banner: RestoreBanner
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(banner.message)
                .font(.footnote)
                .lineLimit(2)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
        .id(banner.id)
    }
}
