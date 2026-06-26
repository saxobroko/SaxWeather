//
//  SettingsBehaviour.swift
//  SaxWeather
//
//  Centralised read-only access to the BehaviourSpec settings that
//  are defined in `BehaviourSettingsView` (and surfaced via
//  `CustomisationRegistry`) but consumed by views/services
//  scattered across the codebase.
//
//  Every property here reads the matching `@AppStorage` key. Writes
//  still happen in the SwiftUI views via the existing
//  `.onChange(of: …) { customisationRegistry.set(\…, newValue) }`
//  bridge, so the registry remains the single mutation path.
//
//  Created: phase-9 implementation of the long-unimplemented
//  behaviour settings.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Centralised reader for behaviour settings. All values are
/// resolved lazily from `UserDefaults.standard` so the helper stays
/// cheap to call from any view, service, or notification path.
enum SettingsBehaviour {

    // MARK: - Haptics

    /// `true` → haptic feedback is allowed anywhere in the app.
    /// Matches `@AppStorage("enableHapticFeedback")` (default `true`).
    static var enableHapticFeedback: Bool {
        if UserDefaults.standard.object(forKey: "enableHapticFeedback") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "enableHapticFeedback")
    }

    /// `true` → taptic pulse when refresh completes successfully.
    /// Matches `@AppStorage("tapticOnRefresh")` (default `true`).
    static var tapticOnRefresh: Bool {
        if UserDefaults.standard.object(forKey: "tapticOnRefresh") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "tapticOnRefresh")
    }

    /// `true` → vibrate (haptic success) when pull-to-refresh
    /// completes. Gated by `enableHapticFeedback` so users who
    /// disable haptics don't feel this either.
    /// Matches `@AppStorage("vibrateOnPullToRefresh")` (default
    /// `true`).
    static var vibrateOnPullToRefresh: Bool {
        if UserDefaults.standard.object(forKey: "vibrateOnPullToRefresh") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "vibrateOnPullToRefresh")
    }

    /// `true` → very light selection feedback on toggles/pickers.
    /// Matches `@AppStorage("hapticOnSelection")` (default `true`).
    static var hapticOnSelection: Bool {
        if UserDefaults.standard.object(forKey: "hapticOnSelection") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "hapticOnSelection")
    }

    // MARK: - Gestures

    /// `true` → user can drag-down inside the scroll view to
    /// refresh the weather. When `false` the `.refreshable`
    /// modifier is omitted entirely so the system control never
    /// appears.
    /// Matches `@AppStorage("pullToRefresh")` (default `true`).
    static var pullToRefresh: Bool {
        if UserDefaults.standard.object(forKey: "pullToRefresh") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "pullToRefresh")
    }

    /// `true` → tapping a day card in the daily forecast opens
    /// the detail sheet. When `false` the tap is a no-op (the
    /// card remains visible but does not respond).
    /// Matches `@AppStorage("tapDayToExpand")` (default `true`).
    static var tapDayToExpand: Bool {
        if UserDefaults.standard.object(forKey: "tapDayToExpand") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "tapDayToExpand")
    }

    /// `true` → long-press a day card to open the per-card
    /// customisation sheet (theme override / pin). When `false`
    /// long-press is ignored.
    /// Matches `@AppStorage("longPressToCustomise")` (default
    /// `true`).
    static var longPressToCustomise: Bool {
        if UserDefaults.standard.object(forKey: "longPressToCustomise") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "longPressToCustomise")
    }

    // MARK: - Destructive / quit confirmations

    /// `true` → show an alert before deleting a saved location
    /// or removing other destructive data.
    /// Matches `@AppStorage("confirmDestructive")` (default `true`).
    static var confirmDestructive: Bool {
        if UserDefaults.standard.object(forKey: "confirmDestructive") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "confirmDestructive")
    }

    /// `true` → show "Are you sure you want to quit?" alert
    /// when the user backgrounds the app from the home screen.
    /// iOS does not let us intercept the home button, so the
    /// closest reliable place to act on this is the
    /// `scenePhase` transition. We use it to make sure no
    /// destructive background work is silently cancelled.
    /// Matches `@AppStorage("confirmQuit")` (default `false`).
    static var confirmQuit: Bool {
        UserDefaults.standard.bool(forKey: "confirmQuit")
    }

    // MARK: - Alerts & sounds

    /// `true` → weather alert local notifications play the
    /// default sound. When `false` notifications are delivered
    /// silently (alert text only).
    /// Matches `@AppStorage("weatherAlertSounds")` (default
    /// `true`).
    static var weatherAlertSounds: Bool {
        if UserDefaults.standard.object(forKey: "weatherAlertSounds") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "weatherAlertSounds")
    }

    /// `true` → system taptic engine pulse when refresh
    /// completes (in addition to optional sound). Today this is
    /// a synonym for `tapticOnRefresh`; kept as its own key so
    /// future audio work has somewhere to land without another
    /// migration.
    /// Matches `@AppStorage("refreshSound")` (default `false`).
    static var refreshSound: Bool {
        UserDefaults.standard.bool(forKey: "refreshSound")
    }

    // MARK: - Quiet hours

    /// Hour-of-day (0-23) when quiet hours begin. `nil` means
    /// quiet hours are off.
    /// Matches `@AppStorage("quietHoursStart")` (default 22,
    /// but treated as `nil` because the BehaviourSpec stores an
    /// optional Int).
    static var quietHoursStart: Int? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "quietHoursStart") != nil else { return nil }
        return defaults.integer(forKey: "quietHoursStart")
    }

    /// Hour-of-day (0-23) when quiet hours end. `nil` means
    /// quiet hours are off.
    /// Matches `@AppStorage("quietHoursEnd")` (default 7,
    /// but treated as `nil` to match `quietHoursStart`).
    static var quietHoursEnd: Int? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "quietHoursEnd") != nil else { return nil }
        return defaults.integer(forKey: "quietHoursEnd")
    }

    /// `true` when the current wall-clock time falls inside the
    /// configured quiet hours window. The window wraps midnight
    /// (e.g. 22 → 07).
    static var isInQuietHours: Bool {
        guard let start = quietHoursStart,
              let end = quietHoursEnd else { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        if start == end { return false }
        if start < end {
            return hour >= start && hour < end
        }
        // Wraps midnight (start > end).
        return hour >= start || hour < end
    }

    // MARK: - Speech

    /// `true` → speak weather alert summaries aloud when they
    /// arrive (route through AVSpeechSynthesizer). Today this
    /// is exposed via the accessibility VoiceOver channel; the
    /// flag is honoured by `WeatherAlertManager` when posting
    /// notifications.
    /// Matches `@AppStorage("speakWeatherAlerts")` (default
    /// `true`).
    static var speakWeatherAlerts: Bool {
        if UserDefaults.standard.object(forKey: "speakWeatherAlerts") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "speakWeatherAlerts")
    }

    // MARK: - Convenience side-effects

    /// Trigger the user-configured refresh feedback (taptic
    /// pulse and/or audio) when a fetch completes successfully.
    /// No-op if both feedback options are off or haptics are
    /// globally disabled.
    static func triggerRefreshFeedback(success: Bool) {
        guard success else { return }
        #if canImport(UIKit)
        guard enableHapticFeedback else { return }
        if vibrateOnPullToRefresh || tapticOnRefresh {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        if refreshSound {
            // Light audio feedback. Wrapped in
            // AudioServicesPlaySystemSound so it works even
            // when the silent switch is on but doesn't bypass
            // the user's mute toggle entirely.
            AudioServicesPlaySystemSound(1057) // Tink
        }
        #endif
    }

    // MARK: - Speech

    #if canImport(AVFoundation)
    /// Singleton synth used for alert narration. We keep this on
    /// the helper so multiple call sites can route through the
    /// same instance and the audio session stays consistent.
    private static let speechSynthesizer = AVSpeechSynthesizer()
    #endif

    /// Speak a weather-alert summary aloud. Honours
    /// `speakWeatherAlerts` and is a no-op when VoiceOver is
    /// already running (VoiceOver speaks everything anyway,
    /// adding our own speech would double-narrate).
    static func speakWeatherAlert(title: String, body: String) {
        #if canImport(AVFoundation)
        guard speakWeatherAlerts else { return }
        // Avoid double-narration when VoiceOver is active.
        if UIAccessibility.isVoiceOverRunning { return }
        let utterance = AVSpeechUtterance(string: "\(title). \(body)")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        speechSynthesizer.speak(utterance)
        #endif
    }

    // MARK: - Experimental

    /// `true` → use the redesigned hero card layout.
    /// Matches `@AppStorage("experimentalNewHeroLayout")` (default `false`).
    static var experimentalNewHeroLayout: Bool {
        UserDefaults.standard.bool(forKey: "experimentalNewHeroLayout")
    }

    /// `true` → allow pull-to-refresh anywhere on the home
    /// screen, not just inside the scroll view.
    /// Matches `@AppStorage("experimentalSwipeRefresh")` (default `false`).
    static var experimentalSwipeRefresh: Bool {
        UserDefaults.standard.bool(forKey: "experimentalSwipeRefresh")
    }

    // MARK: - Preferences / Layout

    /// `true` → swipe horizontally on the home screen to
    /// switch saved locations. Matches
    /// `@AppStorage("swipeBetweenLocations")` (default `true`).
    static var swipeBetweenLocations: Bool {
        if UserDefaults.standard.object(forKey: "swipeBetweenLocations") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "swipeBetweenLocations")
    }

    /// `true` → shrink card padding in landscape orientation.
    /// Matches `@AppStorage("compactCardsInLandscape")` (default `true`).
    static var compactCardsInLandscape: Bool {
        if UserDefaults.standard.object(forKey: "compactCardsInLandscape") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "compactCardsInLandscape")
    }

    /// `true` → display the location name on the hero card
    /// even after scrolling. Matches
    /// `@AppStorage("showLocationLabel")` (default `true`).
    static var showLocationLabel: Bool {
        if UserDefaults.standard.object(forKey: "showLocationLabel") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "showLocationLabel")
    }

    /// `true` → display “Weather for X” header above the
    /// hero card. Matches
    /// `@AppStorage("showLocationHeader")` (default `true`).
    static var showLocationHeader: Bool {
        if UserDefaults.standard.object(forKey: "showLocationHeader") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "showLocationHeader")
    }

    /// Hourly-forecast window length. Matches
    /// `@AppStorage("hourlyHours")` (default 24).
    static var hourlyHours: Int {
        let raw = UserDefaults.standard.object(forKey: "hourlyHours") as? Int
        return raw ?? 24
    }

    /// Card density preference. Matches
    /// `@AppStorage("cardDensity")` (default "regular").
    static var cardDensity: String {
        UserDefaults.standard.string(forKey: "cardDensity") ?? "regular"
    }

    // MARK: - Appearance / Iconography

    /// Icon size multiplier. Matches
    /// `@AppStorage("iconSizeMultiplier")` (default 1.0).
    static var iconSizeMultiplier: Double {
        let raw = UserDefaults.standard.object(forKey: "iconSizeMultiplier") as? Double
        return raw ?? 1.0
    }

    /// Lottie loop mode. Matches `@AppStorage("lottieLoopMode")`
    /// (default "loop"). Possible values: "loop", "playOnce",
    /// "autoReverse".
    static var lottieLoopMode: String {
        UserDefaults.standard.string(forKey: "lottieLoopMode") ?? "loop"
    }

    /// Lottie animation set. Matches
    /// `@AppStorage("lottieAnimationSet")` (default "bundled").
    static var lottieAnimationSet: String {
        UserDefaults.standard.string(forKey: "lottieAnimationSet") ?? "bundled"
    }
}
