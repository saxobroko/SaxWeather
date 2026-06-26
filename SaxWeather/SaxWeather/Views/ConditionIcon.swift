//
//  ConditionIcon.swift
//  SaxWeather
//
//  Phase 6 — Iconography & animation engine.
//
//  `ConditionIcon` is the single entry point for "give me the icon
//  for condition X at night Y at size Z". It reads the active
//  customisation profile via `AnimationRegistry` and picks between:
//
//    • Lottie animation (when `animationsEnabled` and the user
//      hasn't chosen `.bundledStatic`).
//    • SF Symbol fallback (when animations are disabled, when the
//      user chose `.bundledStatic`, or when the Lottie JSON fails
//      to load).
//
//  Every `LottieView(name:)` call site in the app should migrate to
//  `ConditionIcon` so the iconography knobs in `IconographySpec`
//  (playback speed, loop mode, override map, icon style, symbol
//  variant) are honoured automatically.
//
//  See `plans/INFINITE_CUSTOMISATION_PLAN.md` §4.6.
//
//  Phase 3 — removed the Aurora Lottie cosmetic and its
//  `LottieSkinOverlay` modifier. The bundled Lottie animations
//  are still wired in (they're the free default for everyone);
//  only the paid colour overlay is gone.
//

import SwiftUI
import Lottie

/// A weather condition icon that respects the active customisation
/// profile. Use this instead of `LottieView(name:)` directly.
struct ConditionIcon: View {
    /// Textual condition (e.g. "Partly Cloudy"). Mutually exclusive
    /// with `weatherCode` — if both are set, `condition` wins.
    let condition: String?
    /// Open-Meteo WMO weather code. Used when `condition` is nil.
    let weatherCode: Int?
    /// Whether it's currently night. Affects the resolved animation
    /// name and the SF Symbol fallback.
    let isNight: Bool
    /// The icon's logical size in points. The view renders at this
    /// size; the SF Symbol fallback uses ~80% of it for visual
    /// balance.
    let size: CGFloat

    @EnvironmentObject private var customisation: CustomisationRegistry
    @EnvironmentObject private var storeManager: StoreManager
    @State private var loadingFailed = false

    /// Textual condition convenience init.
    init(condition: String, isNight: Bool = false, size: CGFloat = 40) {
        self.condition = condition
        self.weatherCode = nil
        self.isNight = isNight
        self.size = size
    }

    /// WMO weather code convenience init.
    init(weatherCode: Int, isNight: Bool = false, size: CGFloat = 40) {
        self.condition = nil
        self.weatherCode = weatherCode
        self.isNight = isNight
        self.size = size
    }

    /// User-configured icon size multiplier. Defaults to 1.0
    /// when the key is missing.
    private var resolvedSize: CGFloat {
        CGFloat(SettingsBehaviour.iconSizeMultiplier) * size
    }

    var body: some View {
        Group {
            if shouldUseLottie && !loadingFailed {
                LottieView(
                    name: animationName,
                    loopMode: lottieLoopMode,
                    loadingFailed: $loadingFailed
                )
            } else {
                symbolView
            }
        }
        .frame(width: resolvedSize, height: resolvedSize)
        // Re-resolve when the profile changes so toggling a knob
        // (e.g. disable animations) updates the icon immediately.
        .id(animationName)
    }

    // MARK: - Resolution

    /// Whether to render a Lottie animation. `false` when animations
    /// are disabled, when the user chose `.bundledStatic`, or when
    /// the user chose `.custom` without an override for this
    /// condition.
    private var shouldUseLottie: Bool {
        let registry = AnimationRegistry.shared
        guard registry.animationsEnabled else { return false }
        switch registry.animationSet {
        case .bundled:
            return true
        case .bundledStatic:
            return false
        case .custom:
            // Only show Lottie when there's an override for this
            // condition; otherwise fall back to the SF Symbol.
            return registry.hasOverride(
                for: condition,
                baseName: animationName
            )
        }
    }

    /// The resolved Lottie animation name.
    private var animationName: String {
        let registry = AnimationRegistry.shared
        if let condition = condition {
            return registry.name(for: condition, isNight: isNight)
        } else if let code = weatherCode {
            return registry.name(forWeatherCode: code, isNight: isNight)
        }
        return isNight ? "clear-night" : "clear-day"
    }

    /// The resolved SF Symbol fallback name.
    private var symbolName: String {
        let registry = AnimationRegistry.shared
        if let condition = condition {
            return registry.symbolName(for: condition, isNight: isNight)
        } else if let code = weatherCode {
            return registry.symbolName(forWeatherCode: code, isNight: isNight)
        }
        return isNight ? "moon.stars.fill" : "sun.max.fill"
    }

    /// The Lottie loop mode from the registry.
    private var lottieLoopMode: LottieLoopMode {
        switch AnimationRegistry.shared.loopMode {
        case .loop:    return .loop
        case .playOnce: return .playOnce
        }
    }

    /// The SF Symbol rendering mode from the registry.
    private var symbolRenderingMode: SymbolRenderingMode {
        switch AnimationRegistry.shared.iconStyle {
        case .multicolor:  return .multicolor
        case .monochrome:  return .monochrome
        case .outline:     return .monochrome
        }
    }

    /// The SF Symbol variant preference from the registry.
    private var symbolVariant: SymbolVariant {
        AnimationRegistry.shared.symbolVariant
    }

    /// The SF Symbol fallback view.
    private var symbolView: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.8))
            .symbolRenderingMode(symbolRenderingMode)
            .symbolVariant(variantPreference)
            .foregroundColor(.primary)
            .accessibilityLabel(Text(symbolName))
    }

    /// Map our `SymbolVariant` enum to SwiftUI's `SymbolVariants`.
    /// `SymbolVariants` has no `.outline` member — for the outline
    /// preference we return `.none` and rely on
    /// `.symbolRenderingMode(.monochrome)` (already set above) to
    /// produce the outlined appearance.
    private var variantPreference: SymbolVariants {
        switch symbolVariant {
        case .automatic: return .none
        case .filled:    return .fill
        case .outline:   return .none
        }
    }
}
