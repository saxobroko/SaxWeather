
import Foundation
import SwiftUI

@MainActor
final class AnimationRegistry {
    /// Process-wide singleton. The first access from the main actor
    /// initialises the registry against `CustomisationRegistry.shared`.
    static let shared = AnimationRegistry(customisation: .shared)

    /// The customisation registry we read knobs from.
    let customisation: CustomisationRegistry

    init(customisation: CustomisationRegistry) {
        self.customisation = customisation
    }

    // MARK: - Name resolution

    func name(for condition: String, isNight: Bool = false) -> String {
        let baseName = WeatherAnimationHelper.animationName(
            for: condition,
            isNight: isNight
        )
        return applyOverrides(baseName: baseName, condition: condition)
    }

    /// Resolve the Lottie animation name for an Open-Meteo WMO
    /// weather code. Honours `lottieOverrideMap` first, then falls
    /// back to `WeatherAnimationHelper.animationNameFromCode(...)`.
    func name(forWeatherCode code: Int, isNight: Bool = false) -> String {
        let baseName = WeatherAnimationHelper.animationNameFromCode(
            for: code,
            isNight: isNight
        )
        return applyOverrides(baseName: baseName, condition: nil)
    }

    /// The SF Symbol fallback for a textual condition. Used when
    /// animations are disabled, when the user chose
    /// `.bundledStatic`, or when the Lottie JSON fails to load.
    func symbolName(for condition: String, isNight: Bool = false) -> String {
        let lowercased = condition.lowercased()

        if lowercased.contains("clear") || lowercased.contains("sunny") {
            return isNight ? "moon.stars.fill" : "sun.max.fill"
        } else if lowercased.contains("partly cloudy") {
            return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        } else if lowercased.contains("cloud") || lowercased.contains("overcast") {
            return "cloud.fill"
        } else if lowercased.contains("fog") || lowercased.contains("mist") {
            return "cloud.fog.fill"
        } else if lowercased.contains("rain") || lowercased.contains("shower") || lowercased.contains("drizzle") {
            return "cloud.rain.fill"
        } else if lowercased.contains("snow") || lowercased.contains("sleet") || lowercased.contains("ice") {
            return "cloud.snow.fill"
        } else if lowercased.contains("thunder") || lowercased.contains("lightning") || lowercased.contains("storm") {
            return "cloud.bolt.rain.fill"
        }

        return isNight ? "moon.stars.fill" : "sun.max.fill"
    }

    /// The SF Symbol fallback for an Open-Meteo WMO weather code.
    func symbolName(forWeatherCode code: Int, isNight: Bool = false) -> String {
        switch code {
        case 0:
            return isNight ? "moon.stars.fill" : "sun.max.fill"
        case 1, 2:
            return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55, 56, 57:
            return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86:
            return "cloud.snow.fill"
        case 95, 96, 99:
            return "cloud.bolt.fill"
        default:
            return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        }
    }

    // MARK: - Knob accessors

    /// Whether Lottie animations should be rendered at all.
    /// `false` when the user disabled animations or when reduce
    /// motion is on.
    var animationsEnabled: Bool {
        let knobs = customisation.profile.knobs
        return !knobs.iconography.disableWeatherAnimations
            && !knobs.accessibility.reduceMotion
    }

    /// The playback speed multiplier (0.25…2.0). Applied to
    /// `LottieAnimationView.animationSpeed`.
    var playbackSpeed: Double {
        customisation.profile.knobs.iconography.lottiePlaybackSpeed
    }

    /// The loop mode preference from the registry.
    var loopMode: AnimationLoopMode {
        customisation.profile.knobs.iconography.lottieLoopMode
    }

    /// The animation set preference.
    var animationSet: LottieAnimationSet {
        customisation.profile.knobs.iconography.lottieAnimationSet
    }

    /// The icon style (multicolor / monochrome / outline).
    var iconStyle: WeatherIconStyle {
        customisation.profile.knobs.iconography.weatherIconStyle
    }

    /// The SF Symbol variant preference.
    var symbolVariant: SymbolVariant {
        customisation.profile.knobs.iconography.symbolSet
    }

    /// Whether the resolved animation name has a custom override
    /// in `lottieOverrideMap`. Useful for the Settings UI to show
    /// which conditions are customised.
    func hasOverride(for condition: String? = nil, baseName: String? = nil) -> Bool {
        let map = customisation.profile.knobs.iconography.lottieOverrideMap
        if let baseName = baseName, map[baseName] != nil { return true }
        if let condition = condition, map[condition] != nil { return true }
        return false
    }

    // MARK: - Private

    private func applyOverrides(baseName: String, condition: String?) -> String {
        let map = customisation.profile.knobs.iconography.lottieOverrideMap
        if let override = map[baseName] {
            return override
        }
        if let condition = condition, let override = map[condition] {
            return override
        }
        return baseName
    }
}