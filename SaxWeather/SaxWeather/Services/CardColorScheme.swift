
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct CardColorScheme: Equatable, Sendable {
    static var defaultCardBackground: Color {
        #if canImport(UIKit)
        return Color(.secondarySystemBackground)
        #elseif canImport(AppKit)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(white: 0.96)
        #endif
    }

    /// The accent colour for the card's content (e.g. icon,
    /// value text). This is the colour the user sees most
    /// prominently on the card.
    let accent: Color
    /// The secondary colour for the card's content (e.g.
    /// subtitle text, secondary icons). Used for less
    /// prominent elements.
    let secondary: Color
    let background: Color
    /// The border colour for the card. Used by `.outline` card
    /// styles as the stroke colour. Other styles use this as a
    /// subtle accent border.
    let border: Color
    let tint: Color

    static let auroraOverride = CardColorScheme(
        accent:    Color(red: 0.77, green: 0.88, blue: 0.86), // mint
        secondary: Color(red: 0.36, green: 0.75, blue: 0.74), // teal
        background: Color(red: 0.12, green: 0.31, blue: 0.47), // ocean blue
        border:    Color(red: 0.95, green: 0.71, blue: 0.63), // coral
        tint:      Color(red: 0.12, green: 0.31, blue: 0.47)  // ocean blue
    )

    // MARK: - Per-card defaults

    /// Default colour scheme for the temperature card on the
    /// main page. Uses warm tones (temperature = heat =
    /// orange/red) so the card reads as a temperature display.
    static let temperatureCardDefault = CardColorScheme(
        accent:    Color.orange,
        secondary: Color.secondary,
        background: Self.defaultCardBackground,
        border:    Color.orange.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the precipitation card on the
    /// main page. Uses blue tones (rain = water = blue) so the
    /// card reads as a rain display.
    static let precipitationCardDefault = CardColorScheme(
        accent:    Color.blue,
        secondary: Color.secondary,
        background: Self.defaultCardBackground,
        border:    Color.blue.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the wind card on the main
    /// page. Uses teal tones (wind = air = teal) so the card
    /// reads as a wind display.
    static let windCardDefault = CardColorScheme(
        accent:    Color.teal,
        secondary: Color.secondary,
        background: Self.defaultCardBackground,
        border:    Color.teal.opacity(0.3),
        tint:      Color.clear
    )

    static let sunriseCardDefault = CardColorScheme(
        accent:    Color.orange,
        secondary: Color.secondary,
        background: Self.defaultCardBackground,
        border:    Color.orange.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the UV index card. Uses
    /// purple tones (UV = radiation = purple) so the card
    /// reads as a UV display.
    static let uvIndexCardDefault = CardColorScheme(
        accent:    Color.purple,
        secondary: Color.secondary,
        background: Self.defaultCardBackground,
        border:    Color.purple.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the air quality card. Uses
    /// the AQI category colour (green for good, red for
    /// unhealthy, etc.) so the card reads as an AQI display.
    static let airQualityCardDefault = CardColorScheme(
        accent:    Color.green,
        secondary: Color.secondary,
        background: Self.defaultCardBackground,
        border:    Color.green.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the pollen card. Uses green
    /// tones (pollen = plant = green) so the card reads as a
    /// pollen display.
    static let pollenCardDefault = CardColorScheme(
        accent:    Color.green,
        secondary: Color.secondary,
        background: Self.defaultCardBackground,
        border:    Color.green.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the hourly forecast pill
    /// strip. Uses the system accent colour so the strip
    /// reads as a neutral forecast display.
    static let hourlyForecastCardDefault = CardColorScheme(
        accent:    Color.accentColor,
        secondary: Color.secondary,
        background: Self.defaultCardBackground,
        border:    Color.accentColor.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the daily forecast card. Uses
    /// the system accent colour so the card reads as a neutral
    /// forecast display.
    static let dailyForecastCardDefault = CardColorScheme(
        accent:    Color.accentColor,
        secondary: Color.secondary,
        background: Self.defaultCardBackground,
        border:    Color.accentColor.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the weather alert card. Uses
    /// red/orange tones (alert = warning = red/orange) so the
    /// card reads as an alert display.
    static let weatherAlertCardDefault = CardColorScheme(
        accent:    Color.red,
        secondary: Color.secondary,
        background: Self.defaultCardBackground,
        border:    Color.red.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the hero card (the main
    /// temperature display). Uses the system accent colour so
    /// the card reads as a neutral hero display.
    static let heroCardDefault = CardColorScheme(
        accent:    Color.accentColor,
        secondary: Color.secondary,
        background: Self.defaultCardBackground,
        border:    Color.accentColor.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the weather details card
    /// (humidity, pressure, etc.). Uses the system accent
    /// colour so the card reads as a neutral details display.
    static let weatherDetailsCardDefault = CardColorScheme(
        accent:    Color.accentColor,
        secondary: Color.secondary,
        background: Self.defaultCardBackground,
        border:    Color.accentColor.opacity(0.3),
        tint:      Color.clear
    )

    // MARK: - Resolution

    static func resolve(
        defaultScheme: CardColorScheme,
        activePalette: Palette,
        isOwned: (String) -> Bool = { _ in false }
    ) -> CardColorScheme {
        if activePalette == .cosmeticAurora,
           isOwned("com.saxweather.cosmetic.aurora.palette") {
            return auroraOverride
        }
        return defaultScheme
    }
}

// MARK: - Convenience for common cards

extension CardColorScheme {
    static func temperatureCard(
        activePalette: Palette,
        isOwned: (String) -> Bool = { _ in false }
    ) -> CardColorScheme {
        resolve(
            defaultScheme: temperatureCardDefault,
            activePalette: activePalette,
            isOwned: isOwned
        )
    }

    static func precipitationCard(
        activePalette: Palette,
        isOwned: (String) -> Bool = { _ in false }
    ) -> CardColorScheme {
        resolve(
            defaultScheme: precipitationCardDefault,
            activePalette: activePalette,
            isOwned: isOwned
        )
    }

    static func windCard(
        activePalette: Palette,
        isOwned: (String) -> Bool = { _ in false }
    ) -> CardColorScheme {
        resolve(
            defaultScheme: windCardDefault,
            activePalette: activePalette,
            isOwned: isOwned
        )
    }

    static func sunriseCard(
        activePalette: Palette,
        isOwned: (String) -> Bool = { _ in false }
    ) -> CardColorScheme {
        resolve(
            defaultScheme: sunriseCardDefault,
            activePalette: activePalette,
            isOwned: isOwned
        )
    }

    static func uvIndexCard(
        activePalette: Palette,
        isOwned: (String) -> Bool = { _ in false }
    ) -> CardColorScheme {
        resolve(
            defaultScheme: uvIndexCardDefault,
            activePalette: activePalette,
            isOwned: isOwned
        )
    }

    static func airQualityCard(
        activePalette: Palette,
        isOwned: (String) -> Bool = { _ in false }
    ) -> CardColorScheme {
        resolve(
            defaultScheme: airQualityCardDefault,
            activePalette: activePalette,
            isOwned: isOwned
        )
    }

    static func pollenCard(
        activePalette: Palette,
        isOwned: (String) -> Bool = { _ in false }
    ) -> CardColorScheme {
        resolve(
            defaultScheme: pollenCardDefault,
            activePalette: activePalette,
            isOwned: isOwned
        )
    }

    static func hourlyForecastCard(
        activePalette: Palette,
        isOwned: (String) -> Bool = { _ in false }
    ) -> CardColorScheme {
        resolve(
            defaultScheme: hourlyForecastCardDefault,
            activePalette: activePalette,
            isOwned: isOwned
        )
    }

    static func dailyForecastCard(
        activePalette: Palette,
        isOwned: (String) -> Bool = { _ in false }
    ) -> CardColorScheme {
        resolve(
            defaultScheme: dailyForecastCardDefault,
            activePalette: activePalette,
            isOwned: isOwned
        )
    }

    static func weatherAlertCard(
        activePalette: Palette,
        isOwned: (String) -> Bool = { _ in false }
    ) -> CardColorScheme {
        resolve(
            defaultScheme: weatherAlertCardDefault,
            activePalette: activePalette,
            isOwned: isOwned
        )
    }

    static func heroCard(
        activePalette: Palette,
        isOwned: (String) -> Bool = { _ in false }
    ) -> CardColorScheme {
        resolve(
            defaultScheme: heroCardDefault,
            activePalette: activePalette,
            isOwned: isOwned
        )
    }

    static func weatherDetailsCard(
        activePalette: Palette,
        isOwned: (String) -> Bool = { _ in false }
    ) -> CardColorScheme {
        resolve(
            defaultScheme: weatherDetailsCardDefault,
            activePalette: activePalette,
            isOwned: isOwned
        )
    }
}