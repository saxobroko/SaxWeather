
import Foundation

enum BackgroundResolver {

    static let freeDefaultOverlayOpacity: Double = 0.28

    /// The Aurora Backgrounds cosmetic product ID. Centralised
    /// so the picker UI, the resolver, and the lock checks all
    /// agree on the same constant.
    static let auroraBackgroundsProductID =
        "com.saxweather.cosmetic.aurora.backgrounds"

    // MARK: - Public entry point

    static func resolve(
        condition: String,
        spec: BackgroundSpec,
        sunrise: Date?,
        sunset: Date?,
        now: Date,
        customBackgroundUnlocked: Bool,
        isCosmeticUnlocked: (String) -> Bool = { _ in false }
    ) -> BackgroundStrategy {

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

    static func effectiveOverlayOpacity(
        spec: BackgroundSpec,
        customBackgroundUnlocked: Bool
    ) -> Double {
        customBackgroundUnlocked
            ? spec.overlayOpacity
            : freeDefaultOverlayOpacity
    }

    // MARK: - Time-of-day rule

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
