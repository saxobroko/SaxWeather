//
//  BuiltInProfiles.swift
//  SaxWeather
//
//  Factory functions for the five non-deletable starter profiles.
//  New users pick one at onboarding; existing users can switch from
//  Settings. All presets derive from the default `KnobStorage()`
//  and tweak a handful of knobs, so they remain trivially easy to
//  understand and easy to test.
//

import Foundation

enum BuiltInProfiles {
    /// Build the live `CustomisationProfile` for a given preset.
    /// The default profile always uses the default `KnobStorage()`,
    /// which itself matches the existing `@AppStorage` defaults.
    static func profile(for builtIn: BuiltInProfile) -> CustomisationProfile {
        switch builtIn {
        case .default:       return makeDefault()
        case .minimalist:    return makeMinimalist()
        case .powerUser:     return makePowerUser()
        case .accessibility: return makeAccessibility()
        case .batterySaver:  return makeBatterySaver()
        }
    }

    /// Every built-in profile, in display order. Useful for the
    /// Settings UI's profile switcher and for the onboarding
    /// "Pick a starting vibe" step.
    static func all() -> [CustomisationProfile] {
        BuiltInProfile.allCases.map { profile(for: $0) }
    }

    // MARK: - Presets

    /// Identical to `KnobStorage()` but tagged as the default
    /// profile. Returns a fresh UUID each call.
    static func makeDefault() -> CustomisationProfile {
        CustomisationProfile(name: "Default", builtIn: .default)
    }

    /// "Less is more" — summary layout, no animations, no extended
    /// cards, short forecast window, slightly larger text.
    static func makeMinimalist() -> CustomisationProfile {
        var profile = makeDefault()
        profile.builtIn = .minimalist
        profile.name = "Minimalist"
        var knobs = profile.knobs
        knobs.layout.displayMode = "Summary"
        knobs.iconography.disableWeatherAnimations = true
        knobs.layout.forecastDays = 3
        knobs.layout.hiddenHomeSections = [.extended]
        knobs.visual.fontScale = 1.2
        profile.knobs = knobs
        return profile
    }

    /// Everything visible — detailed layout, 14-day forecast,
    /// 48-hour hourly, area chart, axes on.
    static func makePowerUser() -> CustomisationProfile {
        var profile = makeDefault()
        profile.builtIn = .powerUser
        profile.name = "Power User"
        var knobs = profile.knobs
        knobs.layout.displayMode = "Detailed"
        knobs.layout.forecastDays = 14
        knobs.layout.hourlyHours = 48
        knobs.forecast.hourlyChartType = .area
        knobs.forecast.hourlyCardStyle = .detailed
        knobs.forecast.precipitationOverlay = true
        knobs.forecast.chartAxes = true
        profile.knobs = knobs
        return profile
    }

    /// High legibility — bold, contrast, reduce motion, larger
    /// text, enhanced VoiceOver labels, relaxed spacing.
    static func makeAccessibility() -> CustomisationProfile {
        var profile = makeDefault()
        profile.builtIn = .accessibility
        profile.name = "Accessibility"
        var knobs = profile.knobs
        knobs.visual.boldText = true
        knobs.visual.increaseContrast = true
        knobs.accessibility.reduceMotion = true
        knobs.visual.fontScale = 1.3
        knobs.accessibility.enhancedVoiceOverLabels = true
        knobs.layout.cardDensity = .relaxed
        profile.knobs = knobs
        return profile
    }

    /// Conserves battery — reduce motion, slow refresh cadence,
    /// no Lottie, compact hourly, dim overlay.
    static func makeBatterySaver() -> CustomisationProfile {
        var profile = makeDefault()
        profile.builtIn = .batterySaver
        profile.name = "Battery Saver"
        var knobs = profile.knobs
        knobs.accessibility.reduceMotion = true
        knobs.data.refreshCadence = .batterySaver
        knobs.iconography.disableWeatherAnimations = true
        knobs.forecast.hourlyCardStyle = .compact
        knobs.background.overlayOpacity = 0.5
        profile.knobs = knobs
        return profile
    }
}
