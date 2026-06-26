//
//  PalettePickerView.swift
//  SaxWeather
//
//  Phase 5 — Aurora palette / chart picker UI.
//
//  In-app picker for `VisualSpec.palette`. Lists every
//  pickable palette (the free `Default` and the
//  cosmetic-themed `Aurora`) using the same per-row
//  lock-and-buy pattern as `BackgroundModeRow` in
//  `BackgroundSettingsView`:
//
//    • Free rows commit the selection to the profile
//      immediately.
//    • Owned paid rows commit the selection immediately.
//    • Locked paid rows (the Aurora Palette for users
//      who don't own it) present the in-app cosmetics
//      store at the required product's detail sheet —
//      they do NOT commit the selection, so a locked
//      row can never become the active palette by
//      accident.
//
//  The picker reads the current palette from
//  `CustomisationRegistry` (the single source of truth
//  for the active profile) and writes selections back
//  via `registry.set(\.visual.palette, …)`. The
//  `ColourTokenStore` (Part B reactivity fix) observes
//  the registry and re-renders any view that reads
//  `colourTokenStore.palette` when the change lands —
//  so the picker re-renders the checkmark the moment
//  the user taps a row, and every consumer of the
//  palette (cards, backgrounds, etc.) updates at the
//  same time.
//
//  Reached via Settings → Appearance → Palette, and
//  via the "Use now" / "Use this" buttons on the
//  Aurora Palette cosmetic detail sheet (see
//  `CosmeticUsageCoordinator` for the navigation
//  plumbing).
//

import SwiftUI

/// Root view for the palette picker. Presented as a
/// sheet from the Appearance settings row, and from
/// `ContentView` when the user taps "Use now" / "Use
/// this" on the Aurora Palette cosmetic detail sheet.
struct PalettePickerView: View {
    @EnvironmentObject private var customisationRegistry: CustomisationRegistry
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    /// Sheet entry point for the locked-row flow. When
    /// non-nil, `CosmeticsStoreView` is presented
    /// pointing at the product the user needs to buy.
    @State private var pendingLockedProductID: String?

    /// The palette currently active in the profile.
    /// Driven by the registry's published profile so
    /// the checkmark updates immediately on selection.
    private var activePalette: Palette {
        customisationRegistry.profile.knobs.visual.palette
    }

    var body: some View {
        NavigationStack {
            settingsForm
                .navigationTitle(String(
                    localized: "Palette",
                    comment: "Title of the palette picker view."
                ))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(
                            localized: "Done",
                            comment: "Done button on the palette picker."
                        )) {
                            dismiss()
                        }
                    }
                }
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
                ForEach(Palette.selectablePalettes) { entry in
                    SelectablePaletteRow(
                        entry: entry,
                        isSelected: entry.palette == activePalette,
                        isOwned: { pid in storeManager.owns(pid) },
                        onTapOwned: {
                            customisationRegistry.set(
                                \.visual.palette,
                                entry.palette
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
                        localized: "Palette",
                        comment: "Header on the palette picker section."
                    ),
                    systemImage: "paintpalette.fill"
                )
            } footer: {
                Text(
                    String(
                        localized: "The free Default palette uses the shipped theme tokens. Themed palettes are cosmetic add-ons — buy the matching pack to unlock them.",
                        comment: "Footer on the palette picker section."
                    )
                )
            }
        }
    }
}

// MARK: - SelectablePaletteRow

/// A single row in the palette picker. Mirrors
/// `BackgroundModeRow`'s shape: swatch thumbnail,
/// display name, optional lock badge, checkmark when
/// selected. Tapping a free or owned row commits the
/// selection; tapping a locked row fires `onTapLocked`.
struct SelectablePaletteRow: View {
    let entry: SelectablePalette
    let isSelected: Bool
    let isOwned: (String) -> Bool
    let onTapOwned: () -> Void
    let onTapLocked: (String) -> Void

    private var isLocked: Bool {
        guard let pid = entry.requiredProductID else { return false }
        return !isOwned(pid)
    }

    var body: some View {
        Button {
            if isLocked, let pid = entry.requiredProductID {
                onTapLocked(pid)
            } else {
                onTapOwned()
            }
        } label: {
            HStack(spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.displayName)
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
        .accessibilityLabel(entry.displayName)
        .accessibilityValue(
            isSelected
                ? String(
                    localized: "Selected",
                    comment: "Accessibility value: row is the active palette."
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

    /// Five-colour swatch showing the palette's tokens
    /// in the same order the picker stores them
    /// (background → surface → text → muted → danger).
    /// Falls back to a neutral swatch if a token can't
    /// be resolved.
    private var thumbnail: some View {
        let tokens: [ColourToken] = [
            entry.palette.background,
            entry.palette.surface,
            entry.palette.text,
            entry.palette.muted,
            entry.palette.danger,
        ]
        return ZStack {
            HStack(spacing: 0) {
                ForEach(0..<tokens.count, id: \.self) { index in
                    tokens[index].color
                        .frame(maxWidth: .infinity)
                }
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
        if isLocked, let pid = entry.requiredProductID,
           let product = CosmeticCatalog.product(id: pid) {
            return String(
                format: String(
                    localized: "Tap to buy %@ — $%.2f",
                    comment: "Locked-row subtitle on the palette picker. %1$@ is the product name, %2$.2f is the price."
                ),
                product.displayName,
                Double(product.priceCents) / 100.0
            )
        }
        if entry.requiredProductID == nil {
            return String(
                localized: "Free — uses the shipped theme tokens.",
                comment: "Subtitle for the free Default palette row."
            )
        }
        return String(
            localized: "Cosmetic palette — installed when the matching pack is owned.",
            comment: "Subtitle for an owned cosmetic palette row."
        )
    }
}

#if DEBUG
#Preview("Palette Picker") {
    PalettePickerView()
        .environmentObject(CustomisationRegistry.shared)
        .environmentObject(StoreManager.shared)
}
#endif
