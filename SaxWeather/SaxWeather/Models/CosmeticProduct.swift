
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

    let priceTier: PriceTier

    let productKind: CosmeticKind

    let packID: String?

    let packDisplayName: String

    let assetReferences: [String]

    let tileImageName: String?

    let widgetParity: Bool

    let seasonalWindow: SeasonalWindow?

    let familyShareable: Bool

    let previewDurationSeconds: Int

    let priceCents: Int

    let isShipped: Bool

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
    var resolvedPackDisplayName: String {
        if !packDisplayName.isEmpty { return packDisplayName }
        if let packID = packID, !packID.isEmpty {
            return packID.prefix(1).uppercased() + packID.dropFirst()
        }
        return displayName
    }
}

extension CosmeticProduct {
    var shortID: String {
        if let lastDot = id.lastIndex(of: ".") {
            return String(id[id.index(after: lastDot)...])
        }
        return id
    }

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
