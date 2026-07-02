//
//  BackgroundResolver.swift
//  SaxWeather
//
//  Phase 5 — Background engine.
//  Phase 4 — Aurora Backgrounds single-preset refactor.
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
//  AURORA BACKGROUNDS — PHASE 4
//  ----------------------------
//  The Aurora Backgrounds cosmetic is now a SINGLE preset
//  (`.aurora`). The resolver picks the right Aurora image
//  based on the current weather condition (not the mode).
//  Previously there were 8 separate `BackgroundMode` cases
//  (`.auroraSunny`, `.auroraCloudy`, etc.) that required the
//  user to pick the right one for their current weather —
//  confusing. Now the user picks `.aurora` once and the
//  resolver does the rest.
//
//  The mapping is HARDCODED — no randomisation, no hashing —
//  so a sunny day always shows the same Aurora image, a rainy
//  day always shows its own Aurora image, and so on. The
//  mapping is defined in `auroraAssetName(forCondition:)`
//  below and documented (with photographer credits) in
//  `LICENSES.md`.
//
//  The view layer (`BackgroundView`) attempts to load the named
//  asset at runtime; if it's missing (e.g. the user is running
//  a stale build that was compiled before the JPEGs landed in
//  the asset catalog), the view falls back to the Aurora palette
//  gradient. The gradient is therefore a defensive missing-asset
//  fallback, not the primary render path.
//

import Foundation

enum BackgroundResolver {

    /// The overlay strength the home screen should use when the
    /// IAP is locked. Matches the original hard-coded value at
    /// `ContentView.swift:263` before Phase 5.
    static let freeDefaultOverlayOpacity: Double = 0.28

    /// The Aurora Backgrounds cosmetic product ID. Centralised
    /// so the picker UI, the resolver, and the lock checks all
    /// agree on the same constant.
    static let auroraBackgroundsProductID =
        "com.saxweather.cosmetic.aurora.backgrounds"

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
    ///   - isCosmeticUnlocked: a closure that takes a cosmetic
    ///     product ID and returns `true` if the user owns it
    ///     (or the Supporter Pack). Defaults to a stub that
    ///     returns `false` — preserves the existing call sites
    ///     in `ContentView` / `ForecastView` / `AlertsView`
    ///     without modification. Phase 1 callers wire this
    ///     to `StoreManager.owns(_:)`.
    static func resolve(
        condition: String,
        spec: BackgroundSpec,
        sunrise: Date?,
        sunset: Date?,
        now: Date,
        customBackgroundUnlocked: Bool,
        isCosmeticUnlocked: (String) -> Bool = { _ in false }
    ) -> BackgroundStrategy {

        // Phase 4 — Aurora Backgrounds single-preset. The
        // resolver picks the right Aurora image based on the
        // current weather condition (not the mode). The
        // mapping is hardcoded — see `auroraAssetName(forCondition:)`
        // below for the full table and `LICENSES.md` for the
        // photographer credits.
        if spec.mode == .aurora {
            if isCosmeticUnlocked(auroraBackgroundsProductID) {
                let assetName = auroraAssetName(forCondition: condition)
                return .auroraImage(name: assetName)
            }
            // Unowned — silent fallback to the free preset
            // (no error, no blocking). The per-condition
            // and time-of-day customisations still apply.
            return .preset(condition: condition)
        }

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

        case .aurora:
            // All Aurora modes are handled by the early-return
            // above. This branch is unreachable in the
            // non-throwing path but Swift needs it for
            // exhaustiveness.
            return .preset(condition: condition)
        }
    }

    // MARK: - Aurora helpers

    /// The asset-catalog name for a given weather condition.
    ///
    /// Hardcoded mapping (Phase 4, non-randomised). If you ever
    /// reorder or replace any of these JPEGs, update the
    /// `LICENSES.md` table at the project root in the same
    /// commit — the source-of-truth for credits is the
    /// `LICENSES.md` file, not this function header.
    ///
    /// Mapping table:
    ///   * `"sunny"`   → `weather_background_aurora_sunny`
    ///   * `"cloudy"`  → `weather_background_aurora_cloudy`
    ///   * `"foggy"`   → `weather_background_aurora_foggy`
    ///   * `"rainy"`   → `weather_background_aurora_rainy`
    ///   * `"snowy"`   → `weather_background_aurora_snowy`
    ///   * `"thunder"` → `weather_background_aurora_thunder`
    ///   * `"windy"`   → `weather_background_aurora_windy`
    ///   * anything else → `weather_background_aurora_default`
    static func auroraAssetName(forCondition condition: String) -> String {
        let normalized = condition.lowercased()
        let mapped: String
        switch normalized {
        case "sunny", "clear-day":
            mapped = "sunny"
        case "cloudy":
            mapped = "cloudy"
        case "foggy":
            mapped = "foggy"
        case "rainy":
            mapped = "rainy"
        case "snowy":
            mapped = "snowy"
        case "thunder":
            mapped = "thunder"
        case "windy":
            mapped = "windy"
        case "night", "clear-night":
            mapped = "default"
        default:
            mapped = "default"
        }
        return "weather_background_aurora_\(mapped)"
    }

    /// Aurora palette gradient for a given weather condition.
    ///
    /// Used by `BackgroundView` as the defensive missing-asset
    /// fallback for the Aurora images — if the JPEG hasn't been
    /// dropped into the asset catalog (e.g. the build is stale
    /// or the asset was renamed by accident), the view renders
    /// this gradient instead. Should never happen in production.
    ///
    /// Colour picks come from `Palette.cosmeticAurora` so the
    /// fallback is visually consistent with the Aurora palette
    /// the user sees in the picker. Each condition gets a
    /// top/bottom pair that "feels right" for the weather.
    static func auroraGradient(
        forCondition condition: String
    ) -> BackgroundStrategy {
        let (top, bottom): (ColourToken, ColourToken)
        switch condition {
        case "sunny", "clear-day":
            top = .hex("#5BC0BE"); bottom = .hex("#0B1B3A")  // teal → deep navy
        case "cloudy":
            top = .hex("#1F4E79"); bottom = .hex("#5BC0BE")  // ocean blue → teal
        case "rainy":
            top = .hex("#1F4E79"); bottom = .hex("#0B1B3A")  // ocean blue → deep navy
        case "snowy":
            top = .hex("#C5E0DC"); bottom = .hex("#1F4E79")  // mint → ocean blue
        case "thunder":
            top = .hex("#F2B5A0"); bottom = .hex("#1F4E79")  // coral → ocean blue
        case "foggy":
            top = .hex("#C5E0DC"); bottom = .hex("#5BC0BE")  // mint → teal
        case "windy":
            top = .hex("#5BC0BE"); bottom = .hex("#C5E0DC")  // teal → mint
        case "night", "clear-night":
            top = .hex("#0B1B3A"); bottom = .hex("#1F4E79")  // deep navy → ocean blue
        default:
            top = .hex("#5BC0BE"); bottom = .hex("#0B1B3A")  // teal → deep navy
        }
        return .gradient(
            top: top,
            bottom: bottom,
            topOpacity: 0.55,
            bottomOpacity: 0.95
        )
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
