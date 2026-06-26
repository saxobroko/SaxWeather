//
//  ChartColorScheme.swift
//  SaxWeather
//
//  Per-chart colour schemes with cosmetic override support.
//
//  Why per-chart defaults?
//  ------------------------
//  Each chart in the app has its own visual identity. The rain
//  probability chart uses blue tones (rain = water = blue). The
//  hourly forecast pill strip uses a cool→warm gradient (cold
//  hours → blue, warm hours → orange). The precipitation timeline
//  bar uses blue intensity ramps (light → moderate → heavy rain).
//
//  Hardcoding a single "Aurora palette" for every chart would
//  erase that identity. Instead, each chart defines its own
//  default colour scheme, and the Aurora Chart Skin is an
//  *override* on top of the default — not a replacement.
//
//  Resolution order:
//    1. If the active chart skin is `.aurora` AND the user owns
//       the Aurora Chart Skin (or the Supporter Pack), return
//       the Aurora override colours.
//    2. Otherwise, return the chart's own default colours.
//
//  This means free users always see the chart's intended look,
//  and Aurora owners see the Aurora palette on top of it.
//

import SwiftUI

/// A colour scheme for a single chart surface. Each chart in
/// the app defines its own default `ChartColorScheme`; the
/// Aurora Chart Skin is an override on top of the default.
///
/// The fields are intentionally semantic (not "first colour",
/// "second colour") so each chart can interpret them in its own
/// way. For example, the rain probability chart uses `primary`
/// for the bar fill and `secondary` for the gradient stop; the
/// hourly forecast pill strip uses `primary` through `accent`
/// as a left-to-right gradient.
struct ChartColorScheme: Equatable, Sendable {
    /// The dominant colour for the chart (e.g. bar fill, line
    /// stroke). Charts that use a gradient use this as the
    /// top stop.
    let primary: Color
    /// The secondary colour for the chart (e.g. gradient
    /// bottom stop, secondary line). Charts that don't need a
    /// secondary colour can set this equal to `primary`.
    let secondary: Color
    /// The accent colour for the chart (e.g. "now" indicator,
    /// peak marker). Charts that don't need an accent can set
    /// this equal to `primary`.
    let accent: Color
    /// The background colour for the chart (e.g. grid lines,
    /// track). Charts that don't need a background can set
    /// this to `.clear`.
    let background: Color

    /// The Aurora override — installed when the user owns the
    /// Aurora Chart Skin IAP (or the Supporter Pack). The five
    /// colours match `Palette.cosmeticAurora` so the chart
    /// looks consistent with the rest of the Aurora cosmetics.
    static let auroraOverride = ChartColorScheme(
        primary:   Color(red: 0.12, green: 0.31, blue: 0.47), // ocean blue
        secondary: Color(red: 0.36, green: 0.75, blue: 0.74), // teal
        accent:    Color(red: 0.95, green: 0.71, blue: 0.63), // coral
        background: Color(red: 0.04, green: 0.11, blue: 0.23) // deep navy
    )

    /// A 5-colour gradient suitable for a left-to-right
    /// `LinearGradient`. Charts that need a gradient (e.g. the
    /// hourly forecast pill strip) use this to build the
    /// gradient from the scheme's `primary`, `secondary`, and
    /// `accent` colours.
    ///
    /// The default scheme produces a cool→warm gradient
    /// (blue → teal → green → yellow → orange). The Aurora
    /// override produces a deep navy → ocean blue → teal →
    /// mint → coral gradient.
    var gradientColors: [Color] {
        switch self {
        case Self.auroraOverride:
            return [
                Color(red: 0.04, green: 0.11, blue: 0.23),  // deep navy
                Color(red: 0.12, green: 0.31, blue: 0.47),  // ocean blue
                Color(red: 0.36, green: 0.75, blue: 0.74),  // teal
                Color(red: 0.77, green: 0.88, blue: 0.86),  // mint
                Color(red: 0.95, green: 0.71, blue: 0.63)   // coral
            ]
        default:
            return [
                Color.blue,
                Color.teal,
                Color.green,
                Color.yellow,
                Color.orange
            ]
        }
    }

    // MARK: - Per-chart defaults

    /// Default colour scheme for the rain probability chart on
    /// the main page (`PrecipitationGraphView`). Uses blue tones
    /// because rain = water = blue. The `primary` is the bar
    /// fill, `secondary` is the gradient bottom stop, `accent`
    /// is the "now" indicator, and `background` is the grid
    /// lines.
    static let rainProbabilityDefault = ChartColorScheme(
        primary:   Color.blue,
        secondary: Color.blue.opacity(0.6),
        accent:    Color.white,
        background: Color.secondary.opacity(0.2)
    )

    /// Default colour scheme for the precipitation timeline bar
    /// in `AlertsView`. Uses blue intensity ramps (light →
    /// moderate → heavy rain) so the timeline reads as a
    /// rain-intensity heat map.
    static let precipitationTimelineDefault = ChartColorScheme(
        primary:   Color.blue.opacity(0.9),
        secondary: Color.blue.opacity(0.6),
        accent:    Color.red,
        background: Color.gray.opacity(0.3)
    )

    /// Default colour scheme for the hourly forecast pill strip
    /// in `HourlyForecastView`. Uses a cool→warm gradient so
    /// the strip reads as a temperature heat map (cold hours →
    /// blue, warm hours → orange).
    static let hourlyForecastDefault = ChartColorScheme(
        primary:   Color.blue,
        secondary: Color.teal,
        accent:    Color.orange,
        background: Color.clear
    )

    // MARK: - Resolution

    /// Resolve the colour scheme for a given chart, applying
    /// the Aurora override when the active skin is `.aurora`
    /// AND the user owns the Aurora Chart Skin (or the
    /// Supporter Pack).
    ///
    /// - Parameters:
    ///   - defaultScheme: the chart's own default colour
    ///     scheme. Used when the active skin is `.none` or
    ///     when the user doesn't own the Aurora Chart Skin.
    ///   - activeSkin: the currently active chart skin (after
    ///     gating by ownership). When this is `.aurora` AND
    ///     `isOwned` returns `true`, the Aurora override is
    ///     returned instead of the default.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Typically
    ///     `{ storeManager.owns($0) }`.
    /// - Returns: the resolved colour scheme.
    static func resolve(
        defaultScheme: ChartColorScheme,
        activeSkin: ChartSkin,
        isOwned: (String) -> Bool = { _ in false }
    ) -> ChartColorScheme {
        switch activeSkin {
        case .aurora:
            // Only apply the Aurora override when the user
            // owns the Aurora Chart Skin (or the Supporter
            // Pack). This prevents the Aurora look from
            // appearing if the user somehow has the Aurora
            // skin selected without owning it.
            if isOwned("com.saxweather.cosmetic.aurora.chart") {
                return auroraOverride
            }
            return defaultScheme
        case .none:
            return defaultScheme
        }
    }
}

// MARK: - Convenience for the rain probability chart

extension ChartColorScheme {
    /// Convenience for the rain probability chart. Returns the
    /// resolved colour scheme for the rain probability chart
    /// given the active chart skin.
    ///
    /// - Parameters:
    ///   - activeSkin: the currently active chart skin.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Defaults to "never
    ///     owned" so the default look is preserved unless the
    ///     caller explicitly passes an ownership check.
    /// - Returns: the resolved colour scheme.
    static func rainProbability(
        activeSkin: ChartSkin,
        isOwned: (String) -> Bool = { _ in false }
    ) -> ChartColorScheme {
        resolve(
            defaultScheme: rainProbabilityDefault,
            activeSkin: activeSkin,
            isOwned: isOwned
        )
    }

    /// Convenience for the precipitation timeline bar. Returns
    /// the resolved colour scheme for the precipitation timeline
    /// bar given the active chart skin.
    ///
    /// - Parameters:
    ///   - activeSkin: the currently active chart skin.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Defaults to "never
    ///     owned" so the default look is preserved unless the
    ///     caller explicitly passes an ownership check.
    /// - Returns: the resolved colour scheme.
    static func precipitationTimeline(
        activeSkin: ChartSkin,
        isOwned: (String) -> Bool = { _ in false }
    ) -> ChartColorScheme {
        resolve(
            defaultScheme: precipitationTimelineDefault,
            activeSkin: activeSkin,
            isOwned: isOwned
        )
    }

    /// Convenience for the hourly forecast pill strip. Returns
    /// the resolved colour scheme for the hourly forecast pill
    /// strip given the active chart skin.
    ///
    /// - Parameters:
    ///   - activeSkin: the currently active chart skin.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Defaults to "never
    ///     owned" so the default look is preserved unless the
    ///     caller explicitly passes an ownership check.
    /// - Returns: the resolved colour scheme.
    static func hourlyForecast(
        activeSkin: ChartSkin,
        isOwned: (String) -> Bool = { _ in false }
    ) -> ChartColorScheme {
        resolve(
            defaultScheme: hourlyForecastDefault,
            activeSkin: activeSkin,
            isOwned: isOwned
        )
    }
}