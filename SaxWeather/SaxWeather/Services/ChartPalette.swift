
import SwiftUI

enum ChartSkin: String, Codable, CaseIterable, Hashable, Sendable {
    /// No cosmetic — use the default system colours. The free
    /// path; always available.
    case none
    /// Aurora Chart Skin — emerald → teal → mint → ocean
    /// blue → coral gradient. Matches `Palette.cosmeticAurora`.
    case aurora

    /// `true` when this skin needs an owned cosmetic to render.
    /// `.none` is always available; `.aurora` requires the
    /// Aurora Chart Skin IAP (or the Supporter Pack).
    var requiresCosmetic: Bool {
        switch self {
        case .none:  return false
        case .aurora: return true
        }
    }

    /// User-facing name for the chart-skin picker. The
    /// `.none` case is labelled "Default" so the picker can
    /// read as a free-tier row alongside the cosmetic skins.
    var displayName: String {
        switch self {
        case .none:   return "Default"
        case .aurora: return "Aurora"
        }
    }

    /// The product ID that unlocks this skin. `nil` for the
    /// free `.none` skin.
    var requiredProductID: String? {
        switch self {
        case .none:   return nil
        case .aurora: return "com.saxweather.cosmetic.aurora.chart"
        }
    }

    /// The five-colour palette for this skin. Order is
    /// "coldest → warmest" so chart views can build a
    /// left-to-right gradient that reads as a heat map.
    var colors: [Color] {
        switch self {
        case .none:
            // Default neutral: blue → teal → green → yellow →
            // orange. Matches the System default the
            // pre-Phase-2 chart used so existing users see no
            // visual jump.
            return [
                Color.blue,
                Color.teal,
                Color.green,
                Color.yellow,
                Color.orange
            ]
        case .aurora:
            // Aurora palette — matches
            // `Palette.cosmeticAurora`. Hex tokens lifted from
            // the same source of truth so the chart looks
            // consistent with the rest of the Aurora cosmetics.
            return [
                Color(red: 0.04, green: 0.11, blue: 0.23),  // deep navy
                Color(red: 0.12, green: 0.31, blue: 0.47),  // ocean blue
                Color(red: 0.36, green: 0.75, blue: 0.74),  // teal
                Color(red: 0.77, green: 0.88, blue: 0.86),  // mint
                Color(red: 0.95, green: 0.71, blue: 0.63)   // coral
            ]
        }
    }
}

enum ChartPalette {
    static func resolveActiveSkin(
        preferredSkin: ChartSkin,
        isOwned: (String) -> Bool
    ) -> ChartSkin {
        guard preferredSkin.requiresCosmetic,
              let productID = preferredSkin.requiredProductID
        else {
            // `.none` is always available — never gated.
            return preferredSkin
        }
        return isOwned(productID) ? preferredSkin : .none
    }

    /// The five-colour gradient to render in a chart view.
    /// Returns the palette for the resolved skin so callers
    /// don't have to do the gating themselves.
    static func activeColors(
        preferredSkin: ChartSkin,
        isOwned: (String) -> Bool
    ) -> [Color] {
        resolveActiveSkin(
            preferredSkin: preferredSkin,
            isOwned: isOwned
        ).colors
    }
}