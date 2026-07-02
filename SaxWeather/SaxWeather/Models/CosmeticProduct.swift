//
//  CosmeticProduct.swift
//  SaxWeather
//
//  Phase 1 — Cosmetic-only monetization foundation.
//  Phase 2 — added `packDisplayName` for forward-compatible
//            localised pack labels.
//  Phase 3 — added `tileImageName` for per-IAP tile images
//            dropped into `Assets.xcassets`.
//
//  One static description of a paid cosmetic item in the
//  catalog. Every paid cosmetic in `CosmeticCatalog` is a value
//  of this type; the in-app store UI reads its fields, the
//  resolver reads its `id` to look up StoreKit products, and
//  `EntitlementStore` reads its `id` to decide whether the user
//  owns it.
//
//  This struct is intentionally *value-only*: it carries no
//  StoreKit `Product` reference, no UI state, and no
//  presentation logic. The runtime StoreKit product (with
//  localized `displayPrice`, etc.) is loaded by `StoreManager`
//  and stored separately in a `[String: Product]` dictionary.
//
//  See `plans/COSMETIC_MONETIZATION_PLAN.md` §3 (catalog) and
//  §4.2 (data model).
//

import Foundation

/// A static description of a paid cosmetic item. The catalog
/// (see `CosmeticCatalog`) holds the full set; the in-app store
/// UI and the entitlement system both read these values.
struct CosmeticProduct: Identifiable, Hashable, Codable, Sendable {
    /// StoreKit product ID, e.g. `"com.saxweather.cosmetic.aurora.backgrounds"`.
    /// Matches the entry in `configuration.storekit` and in
    /// App Store Connect.
    let id: String

    /// User-facing name shown in the store tile, detail sheet,
    /// and any "Owned" labels.
    let displayName: String

    /// One-line tagline shown under the display name. Explains
    /// what the cosmetic *does* in calm, factual language — never
    /// hype or pressure.
    let subtitle: String

    /// Price tier — drives the store layout, the ethical-copy
    /// rules, and the analytics roll-up. The actual price the
    /// user sees at purchase time comes from StoreKit's
    /// `Product.displayPrice` (regional), not this field.
    let priceTier: PriceTier

    /// What kind of cosmetic this is. Drives the integration
    /// point (which switch / picker / resolver path consumes
    /// the product) and the store category grouping.
    let productKind: CosmeticKind

    /// The "pack" this item belongs to. `nil` for standalone
    /// items, the Supporter Pack, and one-off helpers. Bundles
    /// use this as their own id (so `products(inPack:)` works
    /// for both the bundle's contents and the bundle itself).
    let packID: String?

    /// Phase 2 — user-facing display name for the pack this
    /// product belongs to. Set per-product so translations can
    /// override the derived English fallback without forcing
    /// every locale to ship a strings catalog. When empty,
    /// callers should fall back to `resolvedPackDisplayName`,
    /// which derives a sensible default from the catalog data.
    ///
    /// Examples:
    ///   - Aurora items: `"Aurora"`
    ///   - Neon items:   `"Neon"`
    ///   - Bundles:      `"Mega Pack: Aurora"` (the bundle's
    ///                   *own* display name, since the bundle is
    ///                   itself the "pack" for store-list
    ///                   rendering)
    ///
    /// Adding the field now future-proofs the catalog against
    /// localised pack names arriving via `Localizable.xcstrings`
    /// later — see `plans/COSMETIC_MONETIZATION_PLAN.md` §3.11.6.
    let packDisplayName: String

    /// Names of asset files / imagesets / lottie JSONs / etc.
    /// the cosmetic ships with. Used by later phases to wire
    /// the actual visuals in; informational in Phase 1 (no
    /// shipped cosmetics need it yet).
    let assetReferences: [String]

    /// Phase 3 — optional name of an imageset in
    /// `Assets.xcassets/` for the cosmetic's tile image.
    /// Conventions:
    ///   * `nil` (default) → no custom image; the store card
    ///     and detail-view hero fall back to a kind-appropriate
    ///     SF Symbol placeholder (see `CosmeticTilePlaceholder`).
    ///   * non-nil → an imageset name like
    ///     `"cosmetic_tile_aurora_backgrounds"`. The view layer
    ///     resolves it via `UIImage(named:)`; if `nil` comes
    ///     back (the JPEG hasn't been dropped in yet), the
    ///     placeholder kicks in defensively.
    ///
    /// The catalog auto-populates this for every entry with a
    /// canonical name following `cosmetic_tile_<short_id>`,
    /// where `<short_id>` is the last segment of `id`. The user
    /// drops a `tile.jpg` into the matching imageset directory
    /// to opt into a custom preview image.
    let tileImageName: String?

    /// `true` if the widget extension should honour this
    /// cosmetic. The widget reads the entitlement cache via
    /// `WidgetSharedConfig` (see Phase 2). For Phase 1 this
    /// is informational — only the Aurora Backgrounds IAP has
    /// widget parity, and the widget extension isn't being
    /// touched yet.
    let widgetParity: Bool

    /// Optional seasonal purchase window. `nil` for always-
    /// available items. When set, App Store Connect's
    /// availability flag mirrors this window, and the
    /// client-side `CosmeticCatalog.isCurrentlyPurchasable(_:)`
    /// check matches it for the "Returns [date]" copy.
    let seasonalWindow: SeasonalWindow?

    /// Whether this product can be shared via Family Sharing.
    /// **Always `false` for SaxWeather cosmetics** — see
    /// `plans/COSMETIC_MONETIZATION_PLAN.md` §1.2 and §4.5.
    /// Exposed as a field for forward-compatibility (e.g. if
    /// Apple changes the default) but never `true` in v1.
    let familyShareable: Bool

    /// How long the "Preview on your forecast" timer runs,
    /// in seconds. Defaults to 30 — see `plans/COSMETIC_MONETIZATION_PLAN.md`
    /// §5.3.
    let previewDurationSeconds: Int

    /// US-tier price in cents. Used as a fallback display
    /// when the StoreKit product hasn't loaded yet (the
    /// runtime price always wins when available). Examples:
    /// 99 = $0.99, 199 = $1.99, 399 = $3.99, 2499 = $24.99.
    let priceCents: Int

    /// `true` if this product is live in the App Store /
    /// `configuration.storekit` and should be shown in the
    /// store UI. `false` for products that are catalogued for
    /// future phases but not yet purchasable — they exist in
    /// `CosmeticCatalog.allProducts` so the single source of
    /// truth is in place from day one, but the store tiles
    /// and detail sheets hide them.
    let isShipped: Bool

    /// SF Symbol used as a stand-in for the cosmetic in the
    /// store tile / detail header. Real preview art arrives
    /// in later phases; the SF Symbol is enough for Phase 1.
    let symbolName: String

    init(
        id: String,
        displayName: String,
        subtitle: String,
        priceTier: PriceTier,
        productKind: CosmeticKind,
        packID: String? = nil,
        packDisplayName: String = "",
        assetReferences: [String] = [],
        tileImageName: String? = nil,
        widgetParity: Bool = false,
        seasonalWindow: SeasonalWindow? = nil,
        familyShareable: Bool = false,
        previewDurationSeconds: Int = 30,
        priceCents: Int,
        isShipped: Bool = false,
        symbolName: String = "sparkles"
    ) {
        self.id = id
        self.displayName = displayName
        self.subtitle = subtitle
        self.priceTier = priceTier
        self.productKind = productKind
        self.packID = packID
        self.packDisplayName = packDisplayName
        self.assetReferences = assetReferences
        self.tileImageName = tileImageName
        self.widgetParity = widgetParity
        self.seasonalWindow = seasonalWindow
        self.familyShareable = familyShareable
        self.previewDurationSeconds = previewDurationSeconds
        self.priceCents = priceCents
        self.isShipped = isShipped
        self.symbolName = symbolName
    }
}

extension CosmeticProduct {
    /// The user-facing pack name to display in the store UI.
    ///
    /// Returns `packDisplayName` when it's set (e.g. `"Aurora"`,
    /// `"Mega Pack: Aurora"`). When `packDisplayName` is empty,
    /// falls back to a sensible English derivation:
    ///   * If `packID` is `nil` (a standalone cosmetic),
    ///     returns the cosmetic's own `displayName`.
    ///   * Otherwise, capitalises `packID` so `"aurora"`
    ///     becomes `"Aurora"` and `"hapticsAndSound"` becomes
    ///     `"HapticsAndSound"` (the latter is then formatted
    ///     in call sites if a friendlier form is needed).
    ///
    /// This is the single function the UI should read for the
    /// pack label — never read `packDisplayName` directly.
    var resolvedPackDisplayName: String {
        if !packDisplayName.isEmpty { return packDisplayName }
        if let packID = packID, !packID.isEmpty {
            return packID.prefix(1).uppercased() + packID.dropFirst()
        }
        return displayName
    }
}

extension CosmeticProduct {
    /// The canonical short ID for this product — the trailing
    /// segment after the last `.` in `id`. Used by
    /// `defaultTileImageName` and by image-asset naming
    /// conventions.
    var shortID: String {
        if let lastDot = id.lastIndex(of: ".") {
            return String(id[id.index(after: lastDot)...])
        }
        return id
    }

    /// The default `tileImageName` for this product, following
    /// the convention `cosmetic_tile_<short_id>`. The catalog
    /// uses this to populate `tileImageName` so the user knows
    /// exactly which imageset to drop the JPEG into.
    var defaultTileImageName: String {
        "cosmetic_tile_\(shortID)"
    }
}

// MARK: - PriceTier

/// Price tier — drives the store layout, the ethical-copy
/// rules, and the analytics roll-up. Doesn't carry the
/// actual price (that comes from StoreKit / `priceCents`).
enum PriceTier: String, Codable, CaseIterable, Hashable, Sendable {
    /// $0.99–$1.99. Single small item.
    case micro
    /// $2.99–$4.99. Standard item.
    case standard
    /// $6.99–$9.99. Premium item (seasonal packs).
    case premium
    /// $7.99–$19.99. Bundle of multiple items.
    case bundle
    /// The Supporter Pack — its own tier because it carries
    /// the unique "every current + every future" promise.
    case supporter
}

// MARK: - CosmeticKind

/// What kind of cosmetic this is. Drives the integration
/// point (which switch / picker / resolver path consumes
/// the product) and the store category grouping.
enum CosmeticKind: String, Codable, CaseIterable, Hashable, Sendable {
    /// Per-condition background images. Replaces the shipped
    /// `weather_background_*` imagesets with a themed set.
    case backgrounds
    /// A 5-colour palette. Replaces `VisualSpec.palette` with
    /// a preset.
    case palette
    /// Themed weather-condition icons. Replaces SF Symbols
    /// with custom artwork.
    case icons
    /// Themed chart skin for the hourly chart.
    case chart
    /// A designer font family.
    case font
    /// A Core Haptics pattern file.
    case haptic
    /// A curated sound pack.
    case sound
    /// A widget-only theme.
    case widgetTheme
    /// An alternate `AppIcon-*.appiconset`.
    case appIcon
    /// The "Supporter" badge — private acknowledgement, no
    /// visual effect on the app itself.
    case badge
    /// The "Supporter Pack" — unlock-all bundle.
    case supporterPack
    /// A bundle of multiple individual items sold at a
    /// discount.
    case bundle
}

// MARK: - SeasonalWindow

/// Annual availability window for a seasonal pack. Each
/// window has four Int properties (start month/day, end
/// month/day). So `SeasonalWindow(startMonth: 10, startDay: 1,
/// endMonth: 11, endDay: 5)` is the Oct 1 → Nov 5 window.
///
/// The `isCurrentlyInWindow(date:)` helper handles
/// wrap-around (e.g. Dec 1 → Jan 7 spans the year boundary):
/// if `startMonth > endMonth`, the window is "active when
/// the date is on/after the start OR on/before the end".
/// For a non-wrapping window (e.g. Oct 1 → Nov 5), the
/// date just needs to fall in the inclusive range.
///
/// We use four `Int` properties (not a `(Int, Int)` tuple)
/// because Swift can't auto-synthesise `Codable` for
/// `Equatable` tuples. The four-property shape is also
/// easier to read at the call site (no positional
/// ambiguity between month and day).
struct SeasonalWindow: Codable, Hashable, Sendable {
    /// Inclusive start month — 1…12.
    let startMonth: Int
    /// Inclusive start day — 1…31.
    let startDay: Int
    /// Inclusive end month — 1…12.
    let endMonth: Int
    /// Inclusive end day — 1…31.
    let endDay: Int

    /// Convenience init that takes `(month, day)` tuples —
    /// matches the spec's preferred call site (`start: (10, 1),
    /// end: (11, 5)`).
    init(start: (Int, Int), end: (Int, Int)) {
        self.startMonth = start.0
        self.startDay = start.1
        self.endMonth = end.0
        self.endDay = end.1
    }

    /// Designated init for direct property assignment —
    /// useful when reading from a JSON-decoded source where
    /// the properties are already flattened.
    init(startMonth: Int, startDay: Int, endMonth: Int, endDay: Int) {
        self.startMonth = startMonth
        self.startDay = startDay
        self.endMonth = endMonth
        self.endDay = endDay
    }

    /// `true` if `date` is inside this annual window.
    /// Wrap-around (e.g. Dec 1 → Jan 7) is handled by
    /// checking the start-month > end-month case first.
    func isCurrentlyInWindow(date: Date = .now) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let comps = calendar.dateComponents([.month, .day], from: date)
        guard let month = comps.month, let day = comps.day else {
            return false
        }
        // Pack `(month, day)` into a single comparable
        // integer: months are 1…12, so this is a stable sort
        // key for the year. Day-of-year math isn't reliable
        // because February can have 28 or 29 days.
        let dayKey = month * 100 + day
        let startKey = startMonth * 100 + startDay
        let endKey = endMonth * 100 + endDay

        if startKey <= endKey {
            // Non-wrapping window (e.g. Oct 1 → Nov 5).
            return dayKey >= startKey && dayKey <= endKey
        } else {
            // Wrapping window (e.g. Dec 1 → Jan 7): active if
            // the date is on/after the start OR on/before the
            // end.
            return dayKey >= startKey || dayKey <= endKey
        }
    }
}
