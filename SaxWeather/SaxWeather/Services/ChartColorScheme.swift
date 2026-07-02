
import SwiftUI

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

    static let auroraOverride = ChartColorScheme(
        primary:   Color(red: 0.12, green: 0.31, blue: 0.47), // ocean blue
        secondary: Color(red: 0.36, green: 0.75, blue: 0.74), // teal
        accent:    Color(red: 0.95, green: 0.71, blue: 0.63), // coral
        background: Color(red: 0.04, green: 0.11, blue: 0.23) // deep navy
    )

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

    static let rainProbabilityDefault = ChartColorScheme(
        primary:   Color.blue,
        secondary: Color.blue.opacity(0.6),
        accent:    Color.white,
        background: Color.secondary.opacity(0.2)
    )

    static let precipitationTimelineDefault = ChartColorScheme(
        primary:   Color.blue.opacity(0.9),
        secondary: Color.blue.opacity(0.6),
        accent:    Color.red,
        background: Color.gray.opacity(0.3)
    )

    static let hourlyForecastDefault = ChartColorScheme(
        primary:   Color.blue,
        secondary: Color.teal,
        accent:    Color.orange,
        background: Color.clear
    )

    // MARK: - Resolution

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