//
//  ChartSkinPickerView.swift
//  SaxWeather
//
//  Phase 5 — Aurora chart skin picker UI.
//
//  In-app picker for `ForecastSpec.chartSkin`. Lists every
//  `ChartSkin` case (the free `Default` and the cosmetic
//  `Aurora`) using the same per-row lock-and-buy pattern
//  as `BackgroundModeRow` in `BackgroundSettingsView`:
//
//    • Free rows commit the selection to the profile
//      immediately.
//    • Owned paid rows commit the selection immediately.
//    • Locked paid rows (the Aurora Chart Skin for users
//      who don't own it) present the in-app cosmetics
//      store at the required product's detail sheet —
//      they do NOT commit the selection, so a locked
//      row can never become the active skin by accident.
//
//  The picker reads the current skin from
//  `CustomisationRegistry` and writes selections back
//  via `registry.set(\.forecast.chartSkin, …)`. The
//  `ChartPaletteStore` (Part B reactivity fix) observes
//  the registry and re-renders the hourly forecast pill
//  strip when the change lands — so the picker
//  re-renders the checkmark the moment the user taps a
//  row, and the chart visual updates at the same time.
//
//  Reached via Settings → Appearance → Chart Style, and
//  via the "Use now" / "Use this" buttons on the Aurora
//  Chart Skin cosmetic detail sheet.
//

import SwiftUI

/// Root view for the chart-skin picker. Presented as a
/// sheet from the Appearance settings row, and from
/// `ContentView` when the user taps "Use now" / "Use
/// this" on the Aurora Chart Skin cosmetic detail sheet.
struct ChartSkinPickerView: View {
    @EnvironmentObject private var customisationRegistry: CustomisationRegistry
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    /// Sheet entry point for the locked-row flow. When
    /// non-nil, `CosmeticsStoreView` is presented
    /// pointing at the product the user needs to buy.
    @State private var pendingLockedProductID: String?

    /// The chart skin currently active in the profile.
    /// Driven by the registry's published profile so the
    /// checkmark updates immediately on selection.
    private var activeSkin: ChartSkin {
        customisationRegistry.profile.knobs.forecast.chartSkin
    }

    var body: some View {
        NavigationStack {
            settingsForm
                .navigationTitle(String(
                    localized: "Chart Style",
                    comment: "Title of the chart skin picker view."
                ))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                #if os(iOS)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(
                            localized: "Done",
                            comment: "Done button on the chart skin picker."
                        )) {
                            dismiss()
                        }
                    }
                }
                #endif
                .sheet(item: Binding(
                    get: { pendingLockedProductID.map { LockedProductID(value: $0) } },
                    set: { pendingLockedProductID = $0?.value }
                )) { wrapper in
                    CosmeticsStoreView(initialPendingProductID: wrapper.value)
                }
        }
    }

    // MARK: - Form

    private var settingsForm: some View {
        Form {
            Section {
                ForEach(ChartSkin.allCases, id: \.self) { skin in
                    ChartSkinRow(
                        skin: skin,
                        isSelected: skin == activeSkin,
                        isOwned: { pid in storeManager.owns(pid) },
                        onTapOwned: {
                            customisationRegistry.set(
                                \.forecast.chartSkin,
                                skin
                            )
                        },
                        onTapLocked: { productID in
                            pendingLockedProductID = productID
                        }
                    )
                }
            } header: {
                Label(
                    String(
                        localized: "Chart Style",
                        comment: "Header on the chart skin picker section."
                    ),
                    systemImage: "chart.xyaxis.line"
                )
            } footer: {
                Text(
                    String(
                        localized: "The free Default uses a neutral blue-to-orange gradient. Themed skins are cosmetic add-ons — buy the matching pack to unlock them.",
                        comment: "Footer on the chart skin picker section."
                    )
                )
            }
        }
    }
}

// MARK: - ChartSkinRow

/// A single row in the chart-skin picker. Mirrors
/// `BackgroundModeRow`'s shape: small colour-swatch
/// preview, display name, optional lock badge, checkmark
/// when selected. Tapping a free or owned row commits
/// the selection; tapping a locked row fires
/// `onTapLocked`.
struct ChartSkinRow: View {
    let skin: ChartSkin
    let isSelected: Bool
    let isOwned: (String) -> Bool
    let onTapOwned: () -> Void
    let onTapLocked: (String) -> Void

    private var isLocked: Bool {
        guard let pid = skin.requiredProductID else { return false }
        return !isOwned(pid)
    }

    var body: some View {
        Button {
            if isLocked, let pid = skin.requiredProductID {
                onTapLocked(pid)
            } else {
                onTapOwned()
            }
        } label: {
            HStack(spacing: 12) {
                preview
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(skin.displayName)
                            .font(.body)
                            .foregroundColor(.primary)
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .imageScale(.small)
                                .foregroundStyle(.orange)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(skin.displayName)
        .accessibilityValue(
            isSelected
                ? String(
                    localized: "Selected",
                    comment: "Accessibility value: row is the active chart skin."
                )
                : (isLocked
                    ? String(
                        localized: "Locked",
                        comment: "Accessibility value: row is locked behind a purchase."
                      )
                    : String(
                        localized: "Available",
                        comment: "Accessibility value: row is available to pick."
                      ))
        )
        .accessibilityAddTraits(.isButton)
    }

    /// Compact left-to-right gradient preview matching
    /// what the hourly pill strip renders. Five stripes
    /// so the user can see the warm-to-cold (or default
    /// blue-to-orange) shape at a glance.
    private var preview: some View {
        HStack(spacing: 0) {
            ForEach(0..<skin.colors.count, id: \.self) { idx in
                skin.colors[idx]
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 44, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
        )
        .accessibilityHidden(true)
    }

    private var subtitle: String {
        if isLocked, let pid = skin.requiredProductID,
           let product = CosmeticCatalog.product(id: pid) {
            return String(
                format: String(
                    localized: "Tap to buy %@ — $%.2f",
                    comment: "Locked-row subtitle on the chart skin picker. %1$@ is the product name, %2$.2f is the price."
                ),
                product.displayName,
                Double(product.priceCents) / 100.0
            )
        }
        if skin.requiredProductID == nil {
            return String(
                localized: "Free — uses the shipped chart styling.",
                comment: "Subtitle for the free Default chart skin row."
            )
        }
        return String(
            localized: "Cosmetic skin — installed when the matching pack is owned.",
            comment: "Subtitle for an owned cosmetic chart skin row."
        )
    }
}

#if DEBUG
#Preview("Chart Skin Picker") {
    ChartSkinPickerView()
        .environmentObject(CustomisationRegistry.shared)
        .environmentObject(StoreManager.shared)
}
#endif
