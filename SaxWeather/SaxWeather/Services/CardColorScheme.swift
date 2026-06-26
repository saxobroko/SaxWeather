//
//  CardColorScheme.swift
//  SaxWeather
//
//  Per-card colour schemes with cosmetic override support.
//
//  Why per-card defaults?
//  ----------------------
//  Each card in the app has its own visual identity. The
//  temperature card uses warm tones (temperature = heat =
//  orange/red). The precipitation card uses blue tones (rain =
//  water = blue). The air quality card uses the AQI category
//  colour (green for good, red for unhealthy, etc.).
//
//  Hardcoding a single "Aurora palette" for every card would
//  erase that identity. Instead, each card defines its own
//  default colour scheme, and the Aurora Palette is an
//  *override* on top of the default — not a replacement.
//
//  Resolution order:
//    1. If the active palette is `.cosmeticAurora` AND the user
//       owns the Aurora Palette (or the Supporter Pack), return
//       the Aurora override colours.
//    2. Otherwise, return the card's own default colours.
//
//  This means free users always see the card's intended look,
//  and Aurora owners see the Aurora palette on top of it.
//
//  Note: the `.styledCard()` modifier applies the
//  `CardColorScheme.tint` colour as a low-opacity wash on
//  `.glass` cards. The default `tint` is `.clear` so the
//  default look is unchanged. The Aurora override sets `tint`
//  to the palette's `surface` colour so the Aurora palette is
//  visible on the default home screen — but only when the
//  Aurora Palette is selected AND owned.
//

import SwiftUI

/// A colour scheme for a single card surface. Each card in
/// the app defines its own default `CardColorScheme`; the
/// Aurora Palette is an override on top of the default.
///
/// The fields are intentionally semantic (not "first colour",
/// "second colour") so each card can interpret them in its own
/// way. For example, the temperature card uses `accent` for
/// the temperature value text; the precipitation card uses
/// `accent` for the rain icon.
struct CardColorScheme: Equatable, Sendable {
    /// The accent colour for the card's content (e.g. icon,
    /// value text). This is the colour the user sees most
    /// prominently on the card.
    let accent: Color
    /// The secondary colour for the card's content (e.g.
    /// subtitle text, secondary icons). Used for less
    /// prominent elements.
    let secondary: Color
    /// The background tint for the card. Used by `.solid` and
    /// `.neumorphic` card styles as the fill colour. `.glass`
    /// cards use this as a low-opacity tint on top of the
    /// material.
    let background: Color
    /// The border colour for the card. Used by `.outline` card
    /// styles as the stroke colour. Other styles use this as a
    /// subtle accent border.
    let border: Color
    /// The optional tint wash applied on top of `.glass` cards.
    /// `.clear` (the default) means no tint — the default look
    /// is unchanged. The Aurora override sets this to the
    /// palette's `surface` colour so the Aurora palette is
    /// visible on the default home screen.
    let tint: Color

    /// The Aurora override — installed when the user owns the
    /// Aurora Palette IAP (or the Supporter Pack). The colours
    /// match `Palette.cosmeticAurora` so the card looks
    /// consistent with the rest of the Aurora cosmetics.
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
        background: Color(.secondarySystemBackground),
        border:    Color.orange.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the precipitation card on the
    /// main page. Uses blue tones (rain = water = blue) so the
    /// card reads as a rain display.
    static let precipitationCardDefault = CardColorScheme(
        accent:    Color.blue,
        secondary: Color.secondary,
        background: Color(.secondarySystemBackground),
        border:    Color.blue.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the wind card on the main
    /// page. Uses teal tones (wind = air = teal) so the card
    /// reads as a wind display.
    static let windCardDefault = CardColorScheme(
        accent:    Color.teal,
        secondary: Color.secondary,
        background: Color(.secondarySystemBackground),
        border:    Color.teal.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the sunrise/sunset card on
    /// the main page. Uses orange tones (sunrise/sunset =
    /// warm light = orange) so the card reads as a sun
    /// display.
    static let sunriseCardDefault = CardColorScheme(
        accent:    Color.orange,
        secondary: Color.secondary,
        background: Color(.secondarySystemBackground),
        border:    Color.orange.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the UV index card. Uses
    /// purple tones (UV = radiation = purple) so the card
    /// reads as a UV display.
    static let uvIndexCardDefault = CardColorScheme(
        accent:    Color.purple,
        secondary: Color.secondary,
        background: Color(.secondarySystemBackground),
        border:    Color.purple.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the air quality card. Uses
    /// the AQI category colour (green for good, red for
    /// unhealthy, etc.) so the card reads as an AQI display.
    static let airQualityCardDefault = CardColorScheme(
        accent:    Color.green,
        secondary: Color.secondary,
        background: Color(.secondarySystemBackground),
        border:    Color.green.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the pollen card. Uses green
    /// tones (pollen = plant = green) so the card reads as a
    /// pollen display.
    static let pollenCardDefault = CardColorScheme(
        accent:    Color.green,
        secondary: Color.secondary,
        background: Color(.secondarySystemBackground),
        border:    Color.green.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the hourly forecast pill
    /// strip. Uses the system accent colour so the strip
    /// reads as a neutral forecast display.
    static let hourlyForecastCardDefault = CardColorScheme(
        accent:    Color.accentColor,
        secondary: Color.secondary,
        background: Color(.secondarySystemBackground),
        border:    Color.accentColor.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the daily forecast card. Uses
    /// the system accent colour so the card reads as a neutral
    /// forecast display.
    static let dailyForecastCardDefault = CardColorScheme(
        accent:    Color.accentColor,
        secondary: Color.secondary,
        background: Color(.secondarySystemBackground),
        border:    Color.accentColor.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the weather alert card. Uses
    /// red/orange tones (alert = warning = red/orange) so the
    /// card reads as an alert display.
    static let weatherAlertCardDefault = CardColorScheme(
        accent:    Color.red,
        secondary: Color.secondary,
        background: Color(.secondarySystemBackground),
        border:    Color.red.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the hero card (the main
    /// temperature display). Uses the system accent colour so
    /// the card reads as a neutral hero display.
    static let heroCardDefault = CardColorScheme(
        accent:    Color.accentColor,
        secondary: Color.secondary,
        background: Color(.secondarySystemBackground),
        border:    Color.accentColor.opacity(0.3),
        tint:      Color.clear
    )

    /// Default colour scheme for the weather details card
    /// (humidity, pressure, etc.). Uses the system accent
    /// colour so the card reads as a neutral details display.
    static let weatherDetailsCardDefault = CardColorScheme(
        accent:    Color.accentColor,
        secondary: Color.secondary,
        background: Color(.secondarySystemBackground),
        border:    Color.accentColor.opacity(0.3),
        tint:      Color.clear
    )

    // MARK: - Resolution

    /// Resolve the colour scheme for a given card, applying
    /// the Aurora override when the active palette is
    /// `.cosmeticAurora` AND the user owns the Aurora Palette
    /// (or the Supporter Pack).
    ///
    /// - Parameters:
    ///   - defaultScheme: the card's own default colour
    ///     scheme. Used when the active palette is the default
    ///     or when the user doesn't own the Aurora Palette.
    ///   - activePalette: the currently active palette. When
    ///     this is `.cosmeticAurora` AND `isOwned` returns
    ///     `true`, the Aurora override is returned instead of
    ///     the default.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Typically
    ///     `{ storeManager.owns($0) }`.
    /// - Returns: the resolved colour scheme.
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
    /// Convenience for the temperature card. Returns the
    /// resolved colour scheme for the temperature card given
    /// the active palette.
    ///
    /// - Parameters:
    ///   - activePalette: the currently active palette.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Defaults to "never
    ///     owned" so the default look is preserved unless the
    ///     caller explicitly passes an ownership check.
    /// - Returns: the resolved colour scheme.
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

    /// Convenience for the precipitation card. Returns the
    /// resolved colour scheme for the precipitation card given
    /// the active palette.
    ///
    /// - Parameters:
    ///   - activePalette: the currently active palette.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Defaults to "never
    ///     owned" so the default look is preserved unless the
    ///     caller explicitly passes an ownership check.
    /// - Returns: the resolved colour scheme.
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

    /// Convenience for the wind card. Returns the resolved
    /// colour scheme for the wind card given the active
    /// palette.
    ///
    /// - Parameters:
    ///   - activePalette: the currently active palette.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Defaults to "never
    ///     owned" so the default look is preserved unless the
    ///     caller explicitly passes an ownership check.
    /// - Returns: the resolved colour scheme.
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

    /// Convenience for the sunrise/sunset card. Returns the
    /// resolved colour scheme for the sunrise/sunset card
    /// given the active palette.
    ///
    /// - Parameters:
    ///   - activePalette: the currently active palette.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Defaults to "never
    ///     owned" so the default look is preserved unless the
    ///     caller explicitly passes an ownership check.
    /// - Returns: the resolved colour scheme.
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

    /// Convenience for the UV index card. Returns the resolved
    /// colour scheme for the UV index card given the active
    /// palette.
    ///
    /// - Parameters:
    ///   - activePalette: the currently active palette.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Defaults to "never
    ///     owned" so the default look is preserved unless the
    ///     caller explicitly passes an ownership check.
    /// - Returns: the resolved colour scheme.
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

    /// Convenience for the air quality card. Returns the
    /// resolved colour scheme for the air quality card given
    /// the active palette.
    ///
    /// - Parameters:
    ///   - activePalette: the currently active palette.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Defaults to "never
    ///     owned" so the default look is preserved unless the
    ///     caller explicitly passes an ownership check.
    /// - Returns: the resolved colour scheme.
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

    /// Convenience for the pollen card. Returns the resolved
    /// colour scheme for the pollen card given the active
    /// palette.
    ///
    /// - Parameters:
    ///   - activePalette: the currently active palette.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Defaults to "never
    ///     owned" so the default look is preserved unless the
    ///     caller explicitly passes an ownership check.
    /// - Returns: the resolved colour scheme.
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

    /// Convenience for the hourly forecast pill strip. Returns
    /// the resolved colour scheme for the hourly forecast pill
    /// strip given the active palette.
    ///
    /// - Parameters:
    ///   - activePalette: the currently active palette.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Defaults to "never
    ///     owned" so the default look is preserved unless the
    ///     caller explicitly passes an ownership check.
    /// - Returns: the resolved colour scheme.
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

    /// Convenience for the daily forecast card. Returns the
    /// resolved colour scheme for the daily forecast card given
    /// the active palette.
    ///
    /// - Parameters:
    ///   - activePalette: the currently active palette.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Defaults to "never
    ///     owned" so the default look is preserved unless the
    ///     caller explicitly passes an ownership check.
    /// - Returns: the resolved colour scheme.
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

    /// Convenience for the weather alert card. Returns the
    /// resolved colour scheme for the weather alert card given
    /// the active palette.
    ///
    /// - Parameters:
    ///   - activePalette: the currently active palette.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Defaults to "never
    ///     owned" so the default look is preserved unless the
    ///     caller explicitly passes an ownership check.
    /// - Returns: the resolved colour scheme.
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

    /// Convenience for the hero card. Returns the resolved
    /// colour scheme for the hero card given the active
    /// palette.
    ///
    /// - Parameters:
    ///   - activePalette: the currently active palette.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Defaults to "never
    ///     owned" so the default look is preserved unless the
    ///     caller explicitly passes an ownership check.
    /// - Returns: the resolved colour scheme.
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

    /// Convenience for the weather details card. Returns the
    /// resolved colour scheme for the weather details card
    /// given the active palette.
    ///
    /// - Parameters:
    ///   - activePalette: the currently active palette.
    ///   - isOwned: closure that returns `true` when the user
    ///     owns the given product ID. Defaults to "never
    ///     owned" so the default look is preserved unless the
    ///     caller explicitly passes an ownership check.
    /// - Returns: the resolved colour scheme.
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