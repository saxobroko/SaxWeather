//
//  BackgroundResolver.swift
//  SaxWeather
//
//  Phase 5 — Background engine.
//
//  Pure function from `(current condition, profile, sunrise/sunset,
//  now, IAP state)` → `BackgroundStrategy`. Pure on purpose: the
//  resolver is the easiest place to test the "what should the
//  background be right now?" question, and keeping it free of
//  SwiftUI / `StoreManager` / `WeatherService` means the test
//  suite can exercise every branch without a UI host.
//
//  IAP GATING
//  ----------
//  Background customisation is sold as a single in-app purchase
//  (the same 50¢ "Custom Backgrounds" product that the original
//  `BackgroundSettingsView` shipped with). Without the IAP the
//  resolver falls back to the *free* default — `.preset(condition)`
//  with the original 0.28 overlay — regardless of what's in the
//  spec. The spec itself isn't modified, so a user who buys the
//  IAP later gets their customisations back, and a user who
//  refunds/expires the IAP simply sees the free default again.
//
//  See `plans/INFINITE_CUSTOMISATION_PLAN.md` §2.5 and §4.5.
//

import Foundation

enum BackgroundResolver {

    /// The overlay strength the home screen should use when the
    /// IAP is locked. Matches the original hard-coded value at
    /// `ContentView.swift:263` before Phase 5.
    static let freeDefaultOverlayOpacity: Double = 0.28

    // MARK: - Public entry point

    /// Resolve the active background into a renderable strategy.
    ///
    /// - Parameters:
    ///   - condition: the current condition code (e.g. `"rainy"`,
    ///     `"sunny"`, `"default"`) — what `WeatherService` already
    ///     publishes as `currentBackgroundCondition`.
    ///   - spec: the active `BackgroundSpec` from the registry.
    ///   - sunrise: today's sunrise, if known. `nil` = no sun data
    ///     yet, fall back to the rule's `.none` behaviour.
    ///   - sunset: today's sunset, if known.
    ///   - now: the current time. Injected so tests can pin it.
    ///   - customBackgroundUnlocked: whether the user has bought
    ///     the "Custom Backgrounds" IAP. When `false`, every
    ///     customisation in the spec is ignored and the free
    ///     default is returned.
    static func resolve(
        condition: String,
        spec: BackgroundSpec,
        sunrise: Date?,
        sunset: Date?,
        now: Date,
        customBackgroundUnlocked: Bool
    ) -> BackgroundStrategy {

        // Short-circuit: without the IAP, every spec is ignored.
        // The user might still *have* a non-default spec (e.g. they
        // bought the IAP, customised, then refunded) — we don't
        // mutate it; we just return the free default here.
        guard customBackgroundUnlocked else {
            return .preset(condition: condition)
        }

        // Step 1 — per-condition override wins over everything.
        // A user who set a per-condition photo for "rainy" should
        // always see that photo when it's raining, regardless of
        // which global mode they picked.
        if let perCond = spec.perCondition[condition] {
            if let data = perCond.imageData {
                return .customImage(data)
            }
            if let grad = perCond.gradientOverride {
                return .gradient(
                    top: grad.topColor,
                    bottom: grad.bottomColor,
                    topOpacity: grad.topOpacity,
                    bottomOpacity: grad.bottomOpacity
                )
            }
        }

        // Step 2 — the global mode.
        switch spec.mode {
        case .preset:
            let effectiveCondition = applyTimeOfDayRule(
                condition: condition,
                rule: spec.timeOfDayRule,
                sunrise: sunrise,
                sunset: sunset,
                now: now
            )
            return .preset(condition: effectiveCondition)

        case .customImage:
            // The IAP is already verified above. If the user has
            // somehow cleared the data, fall back to the preset.
            if let data = spec.customImageData {
                return .customImage(data)
            }
            return .preset(condition: condition)

        case .gradient:
            return .gradient(
                top: spec.gradient.topColor,
                bottom: spec.gradient.bottomColor,
                topOpacity: spec.gradient.topOpacity,
                bottomOpacity: spec.gradient.bottomOpacity
            )

        case .dynamicAccent:
            let effectiveCondition = applyTimeOfDayRule(
                condition: condition,
                rule: spec.timeOfDayRule,
                sunrise: sunrise,
                sunset: sunset,
                now: now
            )
            return .dynamicAccent(tint: spec.dynamicTint,
                                  condition: effectiveCondition)
        }
    }

    /// The overlay opacity the home screen should actually use.
    /// Without the IAP, the spec's value is ignored and the free
    /// default is returned. Callers (`ContentView`, `ForecastView`,
    /// `AlertsView`) use this instead of reading the spec directly.
    static func effectiveOverlayOpacity(
        spec: BackgroundSpec,
        customBackgroundUnlocked: Bool
    ) -> Double {
        customBackgroundUnlocked
            ? spec.overlayOpacity
            : freeDefaultOverlayOpacity
    }

    // MARK: - Time-of-day rule

    /// Four-bucket solar classifier:
    ///   * **night**   — from 1h after sunset to 1h before sunrise
    ///   * **dawn**    — last hour before sunrise → sunrise
    ///   * **day**     — sunrise → sunset
    ///   * **dusk**    — sunset → 1h after sunset
    ///
    /// Returns `nil` if sun data is missing or the rule is `.none`
    /// (caller should use the original condition in that case).
    private static func timeOfDayBucket(
        now: Date,
        sunrise: Date?,
        sunset: Date?
    ) -> TimeOfDayBucket? {
        guard let sunrise = sunrise, let sunset = sunset else { return nil }
        let dawnEnd = sunrise
        let dawnStart = sunrise.addingTimeInterval(-3600)
        let duskStart = sunset
        let duskEnd = sunset.addingTimeInterval(3600)

        if now >= dawnStart && now < dawnEnd { return .dawn }
        if now >= sunrise && now < sunset { return .day }
        if now >= duskStart && now < duskEnd { return .dusk }
        return .night
    }

    private enum TimeOfDayBucket { case dawn, day, dusk, night }

    /// Maps the current time-of-day bucket onto a shipped
    /// `weather_background_*` condition string. The shipped
    /// imagesets are limited (sunny / default / cloudy / etc.),
    /// so:
    ///   * dawn / dusk → "sunny"  (warm)
    ///   * night       → "default" (dark)
    ///   * day         → caller-supplied `condition`
    private static func applyTimeOfDayRule(
        condition: String,
        rule: TimeOfDayRule,
        sunrise: Date?,
        sunset: Date?,
        now: Date
    ) -> String {
        // `.hourRange` is reserved for a future "set X to Y" rule
        // that we don't have UI for yet. Today it falls through to
        // the original condition, same as `.none`.
        guard rule == .dawnDayDuskNight else { return condition }
        guard let bucket = timeOfDayBucket(now: now,
                                           sunrise: sunrise,
                                           sunset: sunset)
        else { return condition }
        switch bucket {
        case .dawn, .dusk: return "sunny"
        case .night:       return "default"
        case .day:         return condition
        }
    }
}
