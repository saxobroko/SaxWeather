//
//  CosmeticUsageCoordinator.swift
//  SaxWeather
//
//  Phase 4 — Purchase → use flow simplification.
//  Phase 5 — wire "Use now" / "Use this" to the new
//            palette + chart-skin pickers, and to apply
//            the cosmetic to the live profile before
//            navigating so the user lands on the picker
//            with the new selection already active.
//
//  The "Use now" / "Use this" affordance. After a successful
//  purchase (or when the user taps "Use this" on an owned
//  cosmetic), this coordinator:
//    1. Applies the cosmetic to the live profile
//       (e.g. `VisualSpec.palette = .cosmeticAurora`).
//    2. Publishes a `pendingUsage` value that `ContentView`
//       observes to navigate to the relevant settings page.
//
//  Previously the user had to:
//    1. Open cosmetics store
//    2. Tap a cosmetic
//    3. Tap Buy
//    4. Tap Preview (optional)
//    5. Manually navigate to Settings → Background to
//       actually use it
//
//  Now the user can:
//    1. Open cosmetics store
//    2. Tap a cosmetic
//    3. Tap Buy
//    4. Tap "Use now" on the success sheet
//    5. Land on the relevant settings page with the
//       cosmetic already applied
//
//  Threading: `@MainActor` — every state mutation and
//  observation happens on the main actor, matching the
//  existing `CosmeticPreviewCoordinator` isolation.
//

import SwiftUI
import Combine

/// Where the user should be navigated to after tapping
/// "Use now" / "Use this" on a cosmetic. `ContentView`
/// reads `pendingUsage` to decide which settings page to
/// push.
enum UsageDestination: Equatable {
    /// The Background settings page. Used for `.backgrounds`
    /// cosmetics.
    case backgroundSettings
    /// The Palette settings page. Used for `.palette`
    /// cosmetics.
    case paletteSettings
    /// The Chart settings page. Used for `.chart` cosmetics.
    case chartSettings
}

/// A pending "use this cosmetic" request. Published by
/// `CosmeticUsageCoordinator` when the user taps "Use now"
/// or "Use this". `ContentView` observes this and navigates
/// to the relevant settings page.
struct PendingUsage: Equatable, Identifiable {
    /// The cosmetic to apply.
    let cosmetic: CosmeticProduct
    /// Where to navigate after applying.
    let destination: UsageDestination
    /// Stable identifier for SwiftUI's `.sheet(item:)` /
    /// `.fullScreenCover(item:)` presentation.
    let id = UUID()
}

/// The "Use now" / "Use this" orchestrator. Lives at the
/// `ContentView` level as a `@StateObject` so the navigation
/// logic can observe it without prop-drilling.
@MainActor
final class CosmeticUsageCoordinator: ObservableObject {

    /// The pending usage request, or `nil` when no usage is
    /// pending. `ContentView` observes this to navigate to
    /// the relevant settings page.
    @Published private(set) var pendingUsage: PendingUsage?

    /// Standard init. No long-running work; the coordinator
    /// is inert until `useNow(_:)` is called.
    init() {}

    /// Request that `product` be applied and the user be
    /// navigated to the relevant settings page. Sets
    /// `pendingUsage` based on the product's kind.
    ///
    /// Kinds without a settings page (`.badge`,
    /// `.supporterPack`, `.bundle`, `.icons`, `.font`,
    /// `.haptic`, `.sound`, `.widgetTheme`, `.appIcon`) do
    /// NOT set `pendingUsage` — the "Use this" button is
    /// hidden for these kinds.
    ///
    /// For kinds with a settings page, this method ALSO
    /// applies the cosmetic to the live profile (e.g.
    /// `VisualSpec.palette = .cosmeticAurora` for the
    /// Aurora Palette) so the user lands on the picker
    /// with the new selection already active.
    ///
    /// - Parameter isOwned: Optional ownership check. When
    ///   provided, the coordinator refuses to apply the
    ///   cosmetic if it returns `false` for `product.id` —
    ///   the `useNow` call becomes a no-op. This guards
    ///   against accidentally letting a locked row become
    ///   the active selection. The default closure
    ///   (`{ _ in true }`) preserves the previous "always
    ///   allow" behaviour for callers that don't have an
    ///   ownership check handy.
    func useNow(
        _ product: CosmeticProduct,
        isOwned: (String) -> Bool = { _ in true }
    ) {
        // Refuse to act on a cosmetic the user doesn't
        // own. The UI hides the "Use this" / "Use now"
        // buttons for unowned cosmetics, but the
        // coordinator is defensive in case a programmatic
        // call site forgets to check.
        guard isOwned(product.id) else {
            pendingUsage = nil
            return
        }
        let destination = Self.destination(for: product.productKind)
        guard let destination = destination else {
            // No settings page for this kind — clear any
            // pending usage and return.
            pendingUsage = nil
            return
        }
        // Apply the cosmetic to the live profile so the
        // picker opens with the new selection active. The
        // registry is the single source of truth and the
        // `ColourTokenStore` / `ChartPaletteStore` (Part B)
        // will propagate the change to every consumer.
        applyToProfile(product)
        pendingUsage = PendingUsage(
            cosmetic: product,
            destination: destination
        )
    }

    /// Apply a cosmetic to the live customisation profile.
    /// Used by `useNow(_:)` to commit the selection before
    /// navigating to the picker. Falls through silently for
    /// cosmetic kinds this coordinator doesn't know how to
    /// apply (the picker is the only way to reach those).
    private func applyToProfile(_ product: CosmeticProduct) {
        let registry = CustomisationRegistry.shared
        switch product.productKind {
        case .palette:
            // Map the product ID to the matching `Palette`
            // value. New themed palettes will add their own
            // cases here.
            switch product.id {
            case "com.saxweather.cosmetic.aurora.palette":
                registry.set(\.visual.palette, .cosmeticAurora)
            default:
                break
            }
        case .chart:
            // Map the product ID to the matching `ChartSkin`
            // value. New themed skins will add their own
            // cases here.
            switch product.id {
            case "com.saxweather.cosmetic.aurora.chart":
                registry.set(\.forecast.chartSkin, .aurora)
            default:
                break
            }
        case .backgrounds:
            // Backgrounds apply themselves via the existing
            // `BackgroundResolver` when the user picks the
            // matching mode. The `BackgroundSettingsView`
            // picker is the canonical place to set the mode.
            switch product.id {
            case "com.saxweather.cosmetic.aurora.backgrounds":
                registry.set(\.background.mode, .aurora)
            default:
                break
            }
        case .badge, .supporterPack, .bundle,
             .icons, .font, .haptic, .sound,
             .widgetTheme, .appIcon:
            break
        }
    }

    /// Clear the pending usage. Called by `ContentView` after
    /// navigation completes.
    func clearPending() {
        pendingUsage = nil
    }

    /// Map a cosmetic kind to the destination its "Use now"
    /// should land on. `nil` for kinds with no settings page.
    static func destination(for kind: CosmeticKind) -> UsageDestination? {
        switch kind {
        case .backgrounds:
            return .backgroundSettings
        case .palette:
            return .paletteSettings
        case .chart:
            return .chartSettings
        case .badge, .supporterPack, .bundle,
             .icons, .font, .haptic, .sound,
             .widgetTheme, .appIcon:
            return nil
        }
    }
}