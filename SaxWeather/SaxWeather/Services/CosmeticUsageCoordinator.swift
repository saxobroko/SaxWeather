
import SwiftUI
import Combine

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