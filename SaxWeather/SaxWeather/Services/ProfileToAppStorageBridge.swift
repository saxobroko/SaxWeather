//
//  ProfileToAppStorageBridge.swift
//  SaxWeather
//
//  Phase 2 — bidirectional bridge between `KnobStorage` (the
//  customisation engine's source of truth) and the existing
//  `@AppStorage` keys that the app has shipped with.
//
//  Why: the registry should be the single mutation path, but
//  dozens of views still read settings via `@AppStorage` (which
//  reads from `UserDefaults`). Rather than rewrite every view in
//  Phase 2, the bridge writes every knob to its corresponding
//  UserDefaults key on every mutation — so existing `@AppStorage`
//  reads keep working unchanged.
//
//  Two directions:
//    * `bridge(_:to:)` — registry → UserDefaults. Called after
//      every `set` / `apply`. Idempotent and cheap.
//    * `readFromAppStorage(from:)` — UserDefaults → KnobStorage.
//      Used once at first launch (post-Phase-2 deploy) to seed
//      the registry from any user customisations that already
//      lived in UserDefaults.
//
//  Credentials (`wuApiKey`, `stationID`, `owmApiKey`) and
//  coordinates (`latitude`, `longitude`) are intentionally NOT
//  bridged — they are not knobs.
//
//  See `plans/INFINITE_CUSTOMISATION_PLAN.md` §4.2.
//

import Foundation

@MainActor
enum ProfileToAppStorageBridge {

    // MARK: - Registry → UserDefaults

    /// Write every bridged knob to its corresponding `@AppStorage`
    /// key. Called by the registry after every `apply(_:)` and
    /// `set(_:_:)` so existing `@AppStorage` views continue to
    /// reflect the active profile without code changes.
    ///
    /// - Parameters:
    ///   - knobs: the current `KnobStorage` snapshot.
    ///   - defaults: target UserDefaults. Defaults to `.standard`.
    ///     Tests inject an isolated suite.
    static func bridge(_ knobs: KnobStorage, to defaults: UserDefaults = .standard) {
        dispatchPrecondition(condition: .onQueue(.main))

        // Visual
        defaults.set(knobs.visual.accentColor.rawString, forKey: "accentColor")
        defaults.set(knobs.visual.colorScheme, forKey: "colorScheme")
        defaults.set(knobs.visual.useSystemTextSize, forKey: "useSystemTextSize")
        defaults.set(knobs.visual.fontScale, forKey: "customTextSizeMultiplier")
        defaults.set(knobs.visual.boldText, forKey: "boldText")
        defaults.set(knobs.visual.increaseContrast, forKey: "increaseContrast")

        // Background — `nil` removes the key, which `@AppStorage`
        // then reads back as `nil`.
        defaults.set(knobs.background.useCustom, forKey: "useCustomBackground")
        defaults.set(knobs.background.customImageData, forKey: "userCustomBackground")
        defaults.set(knobs.background.overlayOpacity, forKey: "overlayOpacity")
        defaults.set(knobs.background.mode.rawValue, forKey: "backgroundMode")

        // Iconography
        defaults.set(knobs.iconography.disableWeatherAnimations,
                     forKey: "disableWeatherAnimations")
        // Phase 6 — playback speed is read by `LottieView` via
        // `@AppStorage("lottiePlaybackSpeed")` so the
        // `LottieAnimationView.animationSpeed` honours the
        // registry knob.
        defaults.set(knobs.iconography.lottiePlaybackSpeed,
                     forKey: "lottiePlaybackSpeed")

        // Layout
        defaults.set(knobs.layout.forecastDays, forKey: "forecastDays")
        defaults.set(knobs.layout.displayMode, forKey: "displayMode")
        defaults.set(knobs.layout.showHamburgerMenu, forKey: "showHamburgerMenu")

        // Data
        defaults.set(knobs.data.unitSystem, forKey: "unitSystem")
        defaults.set(knobs.data.useOpenMeteoAsDefault,
                     forKey: "useOpenMeteoAsDefault")
        defaults.set(knobs.data.disableAPIKeys, forKey: "disableAPIKeys")

        // Behaviour
        defaults.set(knobs.behaviour.enableHapticFeedback,
                     forKey: "enableHapticFeedback")
        defaults.set(knobs.behaviour.speakWeatherAlerts,
                     forKey: "speakWeatherAlerts")

        // Accessibility
        defaults.set(knobs.accessibility.reduceMotion, forKey: "reduceMotion")
        defaults.set(knobs.accessibility.enhancedVoiceOverLabels,
                     forKey: "enhancedVoiceOverLabels")
    }

    // MARK: - UserDefaults → KnobStorage (first-launch seeding)

    /// Build a `KnobStorage` from existing UserDefaults values.
    /// Used only at first launch after Phase 2 ships, to seed the
    /// registry from any settings the user has already customised
    /// via the existing UI. After this runs once, the registry is
    /// the source of truth and overrides UserDefaults on
    /// subsequent writes.
    ///
    /// Crucially, every read uses `defaults.object(forKey:) != nil`
    /// (not `defaults.bool(forKey:)`) so we don't accidentally
    /// overwrite a knob with `false` just because the user has
    /// never set that key.
    static func readFromAppStorage(from defaults: UserDefaults = .standard) -> KnobStorage {
        var knobs = KnobStorage()

        // Visual
        if let v = defaults.string(forKey: "accentColor") {
            knobs.visual.accentColor = ColourToken(rawString: v)
        }
        if let v = defaults.string(forKey: "colorScheme") {
            knobs.visual.colorScheme = v
        }
        if defaults.object(forKey: "useSystemTextSize") != nil {
            knobs.visual.useSystemTextSize = defaults.bool(forKey: "useSystemTextSize")
        }
        if defaults.object(forKey: "customTextSizeMultiplier") != nil {
            knobs.visual.fontScale = defaults.double(forKey: "customTextSizeMultiplier")
        }
        if defaults.object(forKey: "boldText") != nil {
            knobs.visual.boldText = defaults.bool(forKey: "boldText")
        }
        if defaults.object(forKey: "increaseContrast") != nil {
            knobs.visual.increaseContrast = defaults.bool(forKey: "increaseContrast")
        }

        // Background
        if defaults.object(forKey: "useCustomBackground") != nil {
            knobs.background.useCustom = defaults.bool(forKey: "useCustomBackground")
        }
        if let data = defaults.data(forKey: "userCustomBackground") {
            knobs.background.customImageData = data
        }
        if defaults.object(forKey: "overlayOpacity") != nil {
            knobs.background.overlayOpacity =
                defaults.double(forKey: "overlayOpacity")
        }
        if let mode = defaults.string(forKey: "backgroundMode"),
           let parsed = BackgroundMode(rawValue: mode) {
            knobs.background.mode = parsed
        }

        // Iconography
        if defaults.object(forKey: "disableWeatherAnimations") != nil {
            knobs.iconography.disableWeatherAnimations =
                defaults.bool(forKey: "disableWeatherAnimations")
        }
        if defaults.object(forKey: "lottiePlaybackSpeed") != nil {
            knobs.iconography.lottiePlaybackSpeed =
                defaults.double(forKey: "lottiePlaybackSpeed")
        }

        // Layout
        if defaults.object(forKey: "forecastDays") != nil {
            knobs.layout.forecastDays = defaults.integer(forKey: "forecastDays")
        }
        if let v = defaults.string(forKey: "displayMode") {
            knobs.layout.displayMode = v
        }
        if defaults.object(forKey: "showHamburgerMenu") != nil {
            knobs.layout.showHamburgerMenu = defaults.bool(forKey: "showHamburgerMenu")
        }

        // Data
        if let v = defaults.string(forKey: "unitSystem") {
            knobs.data.unitSystem = v
        }
        if defaults.object(forKey: "useOpenMeteoAsDefault") != nil {
            knobs.data.useOpenMeteoAsDefault =
                defaults.bool(forKey: "useOpenMeteoAsDefault")
        }
        if defaults.object(forKey: "disableAPIKeys") != nil {
            knobs.data.disableAPIKeys = defaults.bool(forKey: "disableAPIKeys")
        }

        // Behaviour
        if defaults.object(forKey: "enableHapticFeedback") != nil {
            knobs.behaviour.enableHapticFeedback =
                defaults.bool(forKey: "enableHapticFeedback")
        }
        if defaults.object(forKey: "speakWeatherAlerts") != nil {
            knobs.behaviour.speakWeatherAlerts =
                defaults.bool(forKey: "speakWeatherAlerts")
        }

        // Accessibility
        if defaults.object(forKey: "reduceMotion") != nil {
            knobs.accessibility.reduceMotion = defaults.bool(forKey: "reduceMotion")
        }
        if defaults.object(forKey: "enhancedVoiceOverLabels") != nil {
            knobs.accessibility.enhancedVoiceOverLabels =
                defaults.bool(forKey: "enhancedVoiceOverLabels")
        }

        return knobs
    }

    // MARK: - Key registry

    /// Every UserDefaults key the bridge writes or reads. Useful
    /// for tests and for future debug tooling that needs to wipe
    /// all customisation state.
    static let allBridgedKeys: [String] = [
        "accentColor",
        "colorScheme",
        "useSystemTextSize",
        "customTextSizeMultiplier",
        "boldText",
        "increaseContrast",
        "useCustomBackground",
        "userCustomBackground",
        "overlayOpacity",
        "backgroundMode",
        "disableWeatherAnimations",
        "lottiePlaybackSpeed",
        "forecastDays",
        "displayMode",
        "showHamburgerMenu",
        "unitSystem",
        "useOpenMeteoAsDefault",
        "disableAPIKeys",
        "enableHapticFeedback",
        "speakWeatherAlerts",
        "reduceMotion",
        "enhancedVoiceOverLabels",
    ]
}
