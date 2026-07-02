
import Foundation

/// Namespace (not instantiable) that holds the static catalog
/// of every paid cosmetic. Read-only at runtime — the catalog
/// is compiled in.
enum CosmeticCatalog {

    /// The Supporter Pack's product ID. Referenced from
    /// `EntitlementStore.isOwned(_:)` (the short-circuit) and
    /// from the auto-unlock helper for the Supporter Badge.
    static let supporterPackID = "com.saxweather.cosmetic.supporter.pack"

    /// Every product in the catalog — shipped and not-yet-
    /// shipped alike. Use `product(id:)` / `products(inPack:)`
    /// for lookups; use `shippedProducts` for the store UI.
    static let allProducts: [CosmeticProduct] = aurora
        + neon
        + seasonal
        + typography
        + hapticsAndSound
        + widgets
        + appIcons
        + supporter
        + bundles

    static let shippedProducts: [CosmeticProduct] = allProducts.filter { $0.isShipped }

    // MARK: - Lookups

    /// Lookup by StoreKit product ID. O(n) — fine for the
    /// ~30-item catalog. Returns `nil` for unknown IDs.
    static func product(id: String) -> CosmeticProduct? {
        allProducts.first { $0.id == id }
    }

    static func products(inPack packID: String) -> [CosmeticProduct] {
        var result = allProducts.filter { $0.packID == packID }
        if let bundle = allProducts.first(where: { $0.id == packID }) {
            result.append(bundle)
        }
        return result
    }

    static func isCurrentlyPurchasable(
        _ product: CosmeticProduct,
        at date: Date = .now
    ) -> Bool {
        guard product.isShipped else { return false }
        if let window = product.seasonalWindow,
           !window.isCurrentlyInWindow(date: date) {
            return false
        }
        return true
    }

    // MARK: - Catalog data

    // MARK: Aurora pack
    private static let aurora: [CosmeticProduct] = [
        CosmeticProduct(
            id: "com.saxweather.cosmetic.aurora.backgrounds",
            displayName: "Aurora Backgrounds",
            subtitle: String(
                localized: "Eight aurora-themed background images, one for each weather condition.",
                comment: "Subtitle for the Aurora Backgrounds cosmetic tile."
            ),
            priceTier: PriceTier.standard,
            productKind: CosmeticKind.backgrounds,
            packID: "aurora",
            packDisplayName: "Aurora",
            assetReferences: [],
            tileImageName: "cosmetic_tile_aurora_backgrounds",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 30,
            priceCents: 399,
            isShipped: true,
            symbolName: "photo.stack.fill"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.aurora.palette",
            displayName: "Aurora Palette",
            subtitle: String(
                localized: "A five-colour palette: deep navy, ocean blue, teal, mint, coral.",
                comment: "Subtitle for the Aurora Palette cosmetic tile."
            ),
            priceTier: PriceTier.micro,
            productKind: CosmeticKind.palette,
            packID: "aurora",
            packDisplayName: "Aurora",
            assetReferences: [],
            tileImageName: "cosmetic_tile_aurora_palette",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 30,
            priceCents: 199,
            isShipped: true,
            symbolName: "paintpalette.fill"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.aurora.chart",
            displayName: "Aurora Chart Skin",
            subtitle: String(
                localized: "An aurora-themed gradient for the hourly temperature chart.",
                comment: "Subtitle for the Aurora Hourly Chart Skin cosmetic tile."
            ),
            priceTier: PriceTier.micro,
            productKind: CosmeticKind.chart,
            packID: "aurora",
            packDisplayName: "Aurora",
            assetReferences: [],
            tileImageName: "cosmetic_tile_aurora_chart",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 30,
            priceCents: 199,
            isShipped: true,
            symbolName: "chart.xyaxis.line"
        ),
    ]

    // MARK: Neon pack
    private static let neon: [CosmeticProduct] = [
        CosmeticProduct(
            id: "com.saxweather.cosmetic.neon.backgrounds",
            displayName: "Neon Backgrounds",
            subtitle: String(
                localized: "Eight synthwave-themed background images, one for each weather condition.",
                comment: "Subtitle for the Neon Backgrounds cosmetic tile."
            ),
            priceTier: PriceTier.standard,
            productKind: CosmeticKind.backgrounds,
            packID: "neon",
            packDisplayName: "Neon",
            assetReferences: [],
            tileImageName: "cosmetic_tile_neon_backgrounds",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 30,
            priceCents: 399,
            isShipped: false,
            symbolName: "photo.stack.fill"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.neon.palette",
            displayName: "Neon Palette",
            subtitle: String(
                localized: "A five-colour palette: hot pink, electric blue, cyan, magenta, deep purple.",
                comment: "Subtitle for the Neon Palette cosmetic tile."
            ),
            priceTier: PriceTier.micro,
            productKind: CosmeticKind.palette,
            packID: "neon",
            packDisplayName: "Neon",
            assetReferences: [],
            tileImageName: "cosmetic_tile_neon_palette",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 30,
            priceCents: 199,
            isShipped: false,
            symbolName: "paintpalette.fill"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.neon.icons",
            displayName: "Neon Weather Icons",
            subtitle: String(
                localized: "Custom illustrated weather-condition icons in a neon style.",
                comment: "Subtitle for the Neon Weather Icons cosmetic tile."
            ),
            priceTier: PriceTier.standard,
            productKind: CosmeticKind.icons,
            packID: "neon",
            packDisplayName: "Neon",
            assetReferences: [],
            tileImageName: "cosmetic_tile_neon_icons",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 30,
            priceCents: 299,
            isShipped: false,
            symbolName: "cloud.sun.rain.fill"
        ),
    ]

    // MARK: Seasonal packs
    private static let seasonal: [CosmeticProduct] = [
        CosmeticProduct(
            id: "com.saxweather.cosmetic.seasonal.halloween",
            displayName: "Halloween Pack",
            subtitle: String(
                localized: "Spooky backgrounds, animations, icons, and palette for Halloween.",
                comment: "Subtitle for the Halloween Pack cosmetic tile."
            ),
            priceTier: PriceTier.premium,
            productKind: CosmeticKind.bundle,
            packID: "halloween",
            packDisplayName: "Seasonal",
            assetReferences: [],
            tileImageName: "cosmetic_tile_seasonal_halloween",
            widgetParity: true,
            seasonalWindow: SeasonalWindow(start: (10, 1), end: (11, 5)),
            familyShareable: false,
            previewDurationSeconds: 30,
            priceCents: 699,
            isShipped: false,
            symbolName: "moon.stars.fill"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.seasonal.christmas",
            displayName: "Christmas Pack",
            subtitle: String(
                localized: "Snowy cabin backgrounds, snowflake animations, and a red/green palette.",
                comment: "Subtitle for the Christmas Pack cosmetic tile."
            ),
            priceTier: PriceTier.premium,
            productKind: CosmeticKind.bundle,
            packID: "christmas",
            packDisplayName: "Seasonal",
            assetReferences: [],
            tileImageName: "cosmetic_tile_seasonal_christmas",
            widgetParity: true,
            seasonalWindow: SeasonalWindow(start: (12, 1), end: (1, 7)),
            familyShareable: false,
            previewDurationSeconds: 30,
            priceCents: 699,
            isShipped: false,
            symbolName: "snowflake"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.seasonal.pride",
            displayName: "Pride Pack",
            subtitle: String(
                localized: "Rainbow-themed backgrounds, animations, icons, and palette.",
                comment: "Subtitle for the Pride Pack cosmetic tile."
            ),
            priceTier: PriceTier.premium,
            productKind: CosmeticKind.bundle,
            packID: "pride",
            packDisplayName: "Seasonal",
            assetReferences: [],
            tileImageName: "cosmetic_tile_seasonal_pride",
            widgetParity: true,
            seasonalWindow: SeasonalWindow(start: (6, 1), end: (7, 7)),
            familyShareable: false,
            previewDurationSeconds: 30,
            priceCents: 699,
            isShipped: false,
            symbolName: "rainbow"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.seasonal.autumn",
            displayName: "Autumn Pack",
            subtitle: String(
                localized: "Warm-toned forest backgrounds, falling-leaf animations, and a burnt-orange palette.",
                comment: "Subtitle for the Autumn Pack cosmetic tile."
            ),
            priceTier: PriceTier.premium,
            productKind: CosmeticKind.bundle,
            packID: "autumn",
            packDisplayName: "Seasonal",
            assetReferences: [],
            tileImageName: "cosmetic_tile_seasonal_autumn",
            widgetParity: true,
            seasonalWindow: SeasonalWindow(start: (9, 1), end: (11, 30)),
            familyShareable: false,
            previewDurationSeconds: 30,
            priceCents: 699,
            isShipped: false,
            symbolName: "leaf.fill"
        ),
    ]

    // MARK: Typography pack
    private static let typography: [CosmeticProduct] = [
        CosmeticProduct(
            id: "com.saxweather.cosmetic.font.editorial",
            displayName: "Editorial Font Set",
            subtitle: String(
                localized: "A serif headline font paired with a clean sans-serif for body text.",
                comment: "Subtitle for the Editorial Font Set cosmetic tile."
            ),
            priceTier: PriceTier.standard,
            productKind: CosmeticKind.font,
            packID: "typography",
            packDisplayName: "Typography",
            assetReferences: [],
            tileImageName: "cosmetic_tile_font_editorial",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 30,
            priceCents: 299,
            isShipped: false,
            symbolName: "textformat"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.font.mono",
            displayName: "Mono Code Font Set",
            subtitle: String(
                localized: "A monospace font family for the entire app.",
                comment: "Subtitle for the Mono Code Font Set cosmetic tile."
            ),
            priceTier: PriceTier.micro,
            productKind: CosmeticKind.font,
            packID: "typography",
            packDisplayName: "Typography",
            assetReferences: [],
            tileImageName: "cosmetic_tile_font_mono",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 30,
            priceCents: 199,
            isShipped: false,
            symbolName: "chevron.left.forwardslash.chevron.right"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.font.handwritten",
            displayName: "Handwritten Font Set",
            subtitle: String(
                localized: "A casual handwritten font family for a friendlier feel.",
                comment: "Subtitle for the Handwritten Font Set cosmetic tile."
            ),
            priceTier: PriceTier.micro,
            productKind: CosmeticKind.font,
            packID: "typography",
            packDisplayName: "Typography",
            assetReferences: [],
            tileImageName: "cosmetic_tile_font_handwritten",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 30,
            priceCents: 199,
            isShipped: false,
            symbolName: "scribble.variable"
        ),
    ]

    // MARK: Haptics & Sound pack
    private static let hapticsAndSound: [CosmeticProduct] = [
        CosmeticProduct(
            id: "com.saxweather.cosmetic.haptic.rain",
            displayName: "Rain Haptic Pack",
            subtitle: String(
                localized: "A raindrop-like Core Haptics pattern for selection and refresh.",
                comment: "Subtitle for the Rain Haptic Pack cosmetic tile."
            ),
            priceTier: PriceTier.micro,
            productKind: CosmeticKind.haptic,
            packID: "hapticsAndSound",
            packDisplayName: "Haptics & Sound",
            assetReferences: [],
            tileImageName: "cosmetic_tile_haptic_rain",
            widgetParity: false,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 0,
            priceCents: 199,
            isShipped: false,
            symbolName: "drop.fill"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.haptic.wind",
            displayName: "Wind Haptic Pack",
            subtitle: String(
                localized: "A continuous-breeze Core Haptics pattern for selection and refresh.",
                comment: "Subtitle for the Wind Haptic Pack cosmetic tile."
            ),
            priceTier: PriceTier.micro,
            productKind: CosmeticKind.haptic,
            packID: "hapticsAndSound",
            packDisplayName: "Haptics & Sound",
            assetReferences: [],
            tileImageName: "cosmetic_tile_haptic_wind",
            widgetParity: false,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 0,
            priceCents: 199,
            isShipped: false,
            symbolName: "wind"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.sound.synth",
            displayName: "Synth Refresh Sound Pack",
            subtitle: String(
                localized: "Three short synth tones for the pull-to-refresh sound.",
                comment: "Subtitle for the Synth Refresh Sound Pack cosmetic tile."
            ),
            priceTier: PriceTier.micro,
            productKind: CosmeticKind.sound,
            packID: "hapticsAndSound",
            packDisplayName: "Haptics & Sound",
            assetReferences: [],
            tileImageName: "cosmetic_tile_sound_synth",
            widgetParity: false,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 0,
            priceCents: 199,
            isShipped: false,
            symbolName: "speaker.wave.2.fill"
        ),
    ]

    // MARK: Widgets
    private static let widgets: [CosmeticProduct] = [
        CosmeticProduct(
            id: "com.saxweather.cosmetic.widget.backgrounds",
            displayName: "Widget Background Images",
            subtitle: String(
                localized: "Six curated background images for the home-screen widget.",
                comment: "Subtitle for the Widget Background Images cosmetic tile."
            ),
            priceTier: PriceTier.standard,
            productKind: CosmeticKind.widgetTheme,
            packID: "widgets",
            packDisplayName: "Widgets",
            assetReferences: [],
            tileImageName: "cosmetic_tile_widget_backgrounds",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 30,
            priceCents: 299,
            isShipped: false,
            symbolName: "rectangle.3.group.fill"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.widget.themes",
            displayName: "Widget Theme Skins",
            subtitle: String(
                localized: "Four cohesive widget themes: Classic, Glass, Newspaper, Terminal.",
                comment: "Subtitle for the Widget Theme Skins cosmetic tile."
            ),
            priceTier: PriceTier.standard,
            productKind: CosmeticKind.widgetTheme,
            packID: "widgets",
            packDisplayName: "Widgets",
            assetReferences: [],
            tileImageName: "cosmetic_tile_widget_themes",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 30,
            priceCents: 399,
            isShipped: false,
            symbolName: "rectangle.3.offgrid.fill"
        ),
    ]

    // MARK: App Icons
    private static let appIcons: [CosmeticProduct] = [
        CosmeticProduct(
            id: "com.saxweather.cosmetic.appicon.minimal",
            displayName: "App Icon Pack: Minimal",
            subtitle: String(
                localized: "Four minimalist app icons: line-art weather glyphs on solid backgrounds.",
                comment: "Subtitle for the App Icon Pack: Minimal cosmetic tile."
            ),
            priceTier: PriceTier.standard,
            productKind: CosmeticKind.appIcon,
            packID: "appIcons",
            packDisplayName: "App Icon",
            assetReferences: [],
            tileImageName: "cosmetic_tile_appicon_minimal",
            widgetParity: false,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 0,
            priceCents: 299,
            isShipped: false,
            symbolName: "app.fill"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.appicon.illustrated",
            displayName: "App Icon Pack: Illustrated",
            subtitle: String(
                localized: "Four illustrated app icons: hand-drawn weather scenes.",
                comment: "Subtitle for the App Icon Pack: Illustrated cosmetic tile."
            ),
            priceTier: PriceTier.standard,
            productKind: CosmeticKind.appIcon,
            packID: "appIcons",
            packDisplayName: "App Icon",
            assetReferences: [],
            tileImageName: "cosmetic_tile_appicon_illustrated",
            widgetParity: false,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 0,
            priceCents: 299,
            isShipped: false,
            symbolName: "app.badge.fill"
        ),
    ]

    // MARK: Supporter tier
    private static let supporter: [CosmeticProduct] = [
        CosmeticProduct(
            id: "com.saxweather.cosmetic.supporter.badge",
            displayName: "Supporter Badge",
            subtitle: String(
                localized: "A small private acknowledgement in Settings → About.",
                comment: "Subtitle for the Supporter Badge cosmetic tile."
            ),
            priceTier: PriceTier.micro,
            productKind: CosmeticKind.badge,
            packID: "supporter",
            packDisplayName: "Supporter",
            assetReferences: [],
            tileImageName: "cosmetic_tile_supporter_badge",
            widgetParity: false,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 0,
            priceCents: 99,
            isShipped: true,
            symbolName: "cup.and.saucer.fill"
        ),
        CosmeticProduct(
            id: supporterPackID,
            displayName: "Supporter Pack",
            subtitle: String(
                localized: "Buy once, get every cosmetic — now and forever. Help fund the app you love.",
                comment: "Subtitle for the Supporter Pack cosmetic tile."
            ),
            priceTier: PriceTier.supporter,
            productKind: CosmeticKind.supporterPack,
            packID: "supporter",
            packDisplayName: "Supporter",
            assetReferences: [],
            tileImageName: "cosmetic_tile_supporter_pack",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 0,
            priceCents: 2499,
            isShipped: true,
            symbolName: "heart.circle.fill"
        ),
    ]

    // MARK: Bundles
    private static let bundles: [CosmeticProduct] = [
        CosmeticProduct(
            id: "com.saxweather.cosmetic.bundle.starter",
            displayName: "Starter Pack",
            subtitle: String(
                localized: "Aurora Backgrounds + Aurora Palette + Aurora Chart Skin + Mono Code Font.",
                comment: "Subtitle for the Starter Pack bundle tile."
            ),
            priceTier: PriceTier.bundle,
            productKind: CosmeticKind.bundle,
            packID: "starter",
            packDisplayName: "Starter Pack",
            assetReferences: [],
            tileImageName: "cosmetic_tile_bundle_starter",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 0,
            priceCents: 799,
            isShipped: false,
            symbolName: "shippingbox.fill"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.bundle.mega.aurora",
            displayName: "Mega Pack: Aurora",
            subtitle: String(
                localized: "All three Aurora items — backgrounds, palette, and chart skin.",
                comment: "Subtitle for the Mega Pack: Aurora bundle tile."
            ),
            priceTier: PriceTier.bundle,
            productKind: CosmeticKind.bundle,
            packID: nil,
            packDisplayName: "Mega Pack: Aurora",
            assetReferences: [],
            tileImageName: "cosmetic_tile_bundle_mega_aurora",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 0,
            priceCents: 999,
            isShipped: true,
            symbolName: "shippingbox.and.arrow.backward.fill"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.bundle.mega.neon",
            displayName: "Mega Pack: Neon",
            subtitle: String(
                localized: "All three Neon items — backgrounds, palette, and icons.",
                comment: "Subtitle for the Mega Pack: Neon bundle tile."
            ),
            priceTier: PriceTier.bundle,
            productKind: CosmeticKind.bundle,
            packID: "neon",
            packDisplayName: "Mega Pack: Neon",
            assetReferences: [],
            tileImageName: "cosmetic_tile_bundle_mega_neon",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 0,
            priceCents: 799,
            isShipped: false,
            symbolName: "shippingbox.fill"
        ),
        CosmeticProduct(
            id: "com.saxweather.cosmetic.bundle.mega.seasonal",
            displayName: "Mega Pack: Seasonal",
            subtitle: String(
                localized: "All four seasonal packs — Halloween, Christmas, Pride, and Autumn.",
                comment: "Subtitle for the Mega Pack: Seasonal bundle tile."
            ),
            priceTier: PriceTier.bundle,
            productKind: CosmeticKind.bundle,
            packID: "seasonal",
            packDisplayName: "Mega Pack: Seasonal",
            assetReferences: [],
            tileImageName: "cosmetic_tile_bundle_mega_seasonal",
            widgetParity: true,
            seasonalWindow: nil,
            familyShareable: false,
            previewDurationSeconds: 0,
            priceCents: 1999,
            isShipped: false,
            symbolName: "shippingbox.fill"
        ),
    ]
}
