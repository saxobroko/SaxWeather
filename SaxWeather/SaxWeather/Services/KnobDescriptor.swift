
import Foundation

struct KnobDescriptor: Identifiable, Hashable {
    let id: String
    let displayName: String
    let group: KnobGroup
    let symbolName: String
    let summary: String
    let searchTokens: [String]
    /// Which settings tab owns this knob. Search-result taps
    /// navigate here so the user lands on the relevant page.
    let owningRoute: KnobOwningRoute

    init(
        id: String,
        displayName: String,
        group: KnobGroup,
        symbolName: String,
        summary: String,
        searchTokens: [String],
        owningRoute: KnobOwningRoute = .preferences
    ) {
        self.id = id
        self.displayName = displayName
        self.group = group
        self.symbolName = symbolName
        self.summary = summary
        self.searchTokens = searchTokens
        self.owningRoute = owningRoute
    }
}

/// Which settings tab a knob is exposed under. Used by the
/// `.searchable` bar in Settings so tapping a knob navigates the
/// user to the page where they can edit it.
enum KnobOwningRoute: Hashable {
    case appearance
    case preferences
    case behaviour
    case accessibility
    case weatherData
    case cardStyle
}

extension KnobDescriptor {
    /// Whether the knob is locked behind the custom-background IAP.
    /// `false` for free knobs.
    var requiresCustomBackgroundIAP: Bool {
        switch id {
        case "backgroundMode",
             "backgroundUseCustom",
             "backgroundDynamicTint",
             "backgroundTimeOfDayRule":
            return true
        default:
            return false
        }
    }
}

enum KnobGroup: String, CaseIterable, Hashable {
    case visual        = "Visual"
    case background    = "Background"
    case iconography   = "Iconography"
    case layout        = "Layout"
    case data          = "Data"
    case behaviour     = "Behaviour"
    case accessibility = "Accessibility"
    case content       = "Content"
    case powerUser     = "Power User"
    case widget        = "Widget"
    case forecast      = "Forecast"

    var sortOrder: Int {
        switch self {
        case .visual:        return 0
        case .background:    return 1
        case .iconography:   return 2
        case .layout:        return 3
        case .forecast:      return 4
        case .data:          return 5
        case .behaviour:     return 6
        case .accessibility: return 7
        case .content:       return 8
        case .widget:        return 9
        case .powerUser:     return 10
        }
    }
}

extension KnobDescriptor {
    /// The full catalogue. Order within each group matches the
    /// declaration order in the corresponding spec struct.
    static let catalogue: [KnobDescriptor] = visual + background + iconography
        + layout + data + behaviour + accessibility + powerUser

    // MARK: - Visual

    private static let visual: [KnobDescriptor] = [
        .init(id: "accentColor", displayName: "Accent Colour",
              group: .visual, symbolName: "paintbrush.fill",
              summary: "Colour used for buttons, links, and highlights.",
              searchTokens: ["accent", "colour", "color", "tint", "theme", "brand"],
              owningRoute: .appearance),
        .init(id: "palette", displayName: "Custom Palette",
              group: .visual, symbolName: "swatchpalette.fill",
              summary: "Five-colour palette (bg, surface, text, muted, danger).",
              searchTokens: ["palette", "swatch", "colour", "color", "theme", "background",
                             "surface", "text", "muted", "danger"],
              owningRoute: .appearance),
        .init(id: "cardStyle", displayName: "Card Style",
              group: .visual, symbolName: "rectangle.stack.fill",
              summary: "Material used for cards (glass, solid, outline, neumorphic).",
              searchTokens: ["card", "material", "glass", "solid", "outline", "neumorphic"],
              owningRoute: .cardStyle),
        .init(id: "cornerRadius", displayName: "Corner Radius",
              group: .visual, symbolName: "roundedtop.and.roundedbottom",
              summary: "How rounded card corners are (0–28 pt).",
              searchTokens: ["corner", "radius", "rounded", "shape"],
              owningRoute: .cardStyle),
        .init(id: "fontScale", displayName: "Text Size",
              group: .visual, symbolName: "textformat.size",
              summary: "Multiplier applied to body text (0.75×–1.5×).",
              searchTokens: ["text", "size", "font", "scale", "scale", "large", "small"],
              owningRoute: .accessibility),
        .init(id: "boldText", displayName: "Bold Text",
              group: .visual, symbolName: "bold",
              summary: "Force-bold body text regardless of system setting.",
              searchTokens: ["bold", "text", "weight", "strong"],
              owningRoute: .accessibility),
        .init(id: "useSystemTextSize", displayName: "Respect Dynamic Type",
              group: .visual, symbolName: "textformat",
              summary: "Follow the system text-size setting.",
              searchTokens: ["dynamic", "type", "system", "text", "size", "accessibility"],
              owningRoute: .accessibility),
        .init(id: "typography", displayName: "Typography",
              group: .visual, symbolName: "textformat.alt",
              summary: "Font family (system, rounded, serif, mono).",
              searchTokens: ["typography", "font", "family", "rounded", "serif", "mono"],
              owningRoute: .appearance),
        .init(id: "increaseContrast", displayName: "Increase Contrast",
              group: .visual, symbolName: "circle.lefthalf.filled",
              summary: "Add a high-contrast outline around text.",
              searchTokens: ["contrast", "outline", "high", "legibility", "accessibility"],
              owningRoute: .accessibility),
        .init(id: "colorScheme", displayName: "Colour Scheme",
              group: .visual, symbolName: "circle.lefthalf.filled",
              summary: "App-wide light, dark, or system theme.",
              searchTokens: ["colour", "color", "scheme", "light", "dark", "system", "theme"],
              owningRoute: .appearance),
        .init(id: "cardOpacity", displayName: "Card Opacity",
              group: .visual, symbolName: "circle.lefthalf.filled",
              summary: "Translucency of card backgrounds.",
              searchTokens: ["card", "opacity", "translucency", "alpha"],
              owningRoute: .cardStyle),
    ]

    // MARK: - Background

    private static let background: [KnobDescriptor] = [
        .init(id: "backgroundMode", displayName: "Background Mode",
              group: .background, symbolName: "photo.fill",
              summary: "Preset, custom image, gradient, or dynamic accent.",
              searchTokens: ["background", "mode", "preset", "image", "gradient"],
              owningRoute: .appearance),
        .init(id: "backgroundUseCustom", displayName: "Use Custom Image",
              group: .background, symbolName: "photo",
              summary: "Toggle the user-supplied background photo.",
              searchTokens: ["background", "custom", "image", "photo", "user"],
              owningRoute: .appearance),
        .init(id: "backgroundOverlayOpacity", displayName: "Overlay Opacity",
              group: .background, symbolName: "circle.lefthalf.filled",
              summary: "Strength of the dark overlay on top of the background.",
              searchTokens: ["overlay", "opacity", "dark", "tint", "dim"],
              owningRoute: .appearance),
        .init(id: "backgroundTimeOfDayRule", displayName: "Time-of-Day Rule",
              group: .background, symbolName: "clock.fill",
              summary: "Swap background by time of day.",
              searchTokens: ["time", "day", "night", "background", "swap"],
              owningRoute: .appearance),
        .init(id: "backgroundDynamicTint", displayName: "Background Dynamic Tint",
              group: .background, symbolName: "paintpalette.fill",
              summary: "Tint applied to dynamic-accent backgrounds.",
              searchTokens: ["background", "dynamic", "tint", "accent", "colour", "color"],
              owningRoute: .appearance),
        .init(id: "backgroundPerCondition", displayName: "Per-Condition Backgrounds",
              group: .background, symbolName: "photo.stack.fill",
              summary: "Override the background image per weather condition.",
              searchTokens: ["background", "condition", "per", "weather", "photo", "image",
                             "override"],
              owningRoute: .appearance),
        .init(id: "backgroundGradient", displayName: "Background Gradient",
              group: .background, symbolName: "rectangle.lefthalf.inset.filled",
              summary: "Top and bottom colours and opacities of the gradient.",
              searchTokens: ["background", "gradient", "top", "bottom", "colour", "color",
                             "fade"],
              owningRoute: .appearance),
    ]

    // MARK: - Iconography

    private static let iconography: [KnobDescriptor] = [
        .init(id: "lottieAnimationSet", displayName: "Animation Set",
              group: .iconography, symbolName: "play.rectangle.fill",
              summary: "Bundled Lottie, bundled static, or custom JSON.",
              searchTokens: ["animation", "lottie", "set", "icon", "bundled", "custom"],
              owningRoute: .appearance),
        .init(id: "lottieOverrideMap", displayName: "Per-Condition Animations",
              group: .iconography, symbolName: "list.bullet.rectangle.fill",
              summary: "Override the Lottie animation per weather condition.",
              searchTokens: ["animation", "lottie", "override", "per", "condition", "custom",
                             "json", "map"],
              owningRoute: .appearance),
        .init(id: "lottiePlaybackSpeed", displayName: "Playback Speed",
              group: .iconography, symbolName: "gauge.with.dots.needle.67percent",
              summary: "Multiplier on animation speed (0.25×–2×).",
              searchTokens: ["playback", "speed", "animation", "fast", "slow", "lottie"],
              owningRoute: .appearance),
        .init(id: "lottieLoopMode", displayName: "Loop Mode",
              group: .iconography, symbolName: "repeat",
              summary: "Loop forever or play once.",
              searchTokens: ["loop", "repeat", "play", "once", "animation"],
              owningRoute: .appearance),
        .init(id: "disableWeatherAnimations", displayName: "Disable Animations",
              group: .iconography, symbolName: "pause.circle.fill",
              summary: "Force static SF Symbol icons instead of Lottie.",
              searchTokens: ["animation", "disable", "static", "icon", "lottie", "off"],
              owningRoute: .accessibility),
        .init(id: "weatherIconStyle", displayName: "Icon Style",
              group: .iconography, symbolName: "paintpalette.fill",
              summary: "Multicolour, monochrome, or outlined SF Symbols.",
              searchTokens: ["icon", "style", "colour", "color", "multicolor", "monochrome", "outline"],
              owningRoute: .appearance),
        .init(id: "symbolSet", displayName: "Symbol Variant",
              group: .iconography, symbolName: "scribble.variable",
              summary: "Filled, outlined, or automatic SF Symbol variant.",
              searchTokens: ["symbol", "variant", "filled", "outline", "automatic", "sf"],
              owningRoute: .appearance),
        .init(id: "iconSizeMultiplier", displayName: "Icon Size",
              group: .iconography, symbolName: "plus.magnifyingglass",
              summary: "Global multiplier on weather-condition icon size (0.7×–1.6×).",
              searchTokens: ["icon", "size", "scale", "magnify", "shrink", "bigger"],
              owningRoute: .appearance),
    ]

    // MARK: - Layout

    private static let layout: [KnobDescriptor] = [
        .init(id: "displayMode", displayName: "Home Layout",
              group: .layout, symbolName: "rectangle.split.3x1",
              summary: "Summary, Detailed, Compact, or Power layout.",
              searchTokens: ["layout", "display", "mode", "summary", "detailed", "compact", "power"],
              owningRoute: .preferences),
        .init(id: "forecastDays", displayName: "Forecast Days",
              group: .layout, symbolName: "calendar",
              summary: "Number of days in the daily forecast (3/5/7/10/14).",
              searchTokens: ["forecast", "days", "daily", "window"],
              owningRoute: .preferences),
        .init(id: "hourlyHours", displayName: "Hourly Window",
              group: .layout, symbolName: "clock.fill",
              summary: "Hours shown in the hourly forecast (12/24/48).",
              searchTokens: ["hourly", "hours", "window", "forecast"],
              owningRoute: .preferences),
        .init(id: "cardDensity", displayName: "Card Density",
              group: .layout, symbolName: "rectangle.compress.vertical",
              summary: "Spacing between cards (compact/regular/relaxed).",
              searchTokens: ["card", "density", "spacing", "compact", "regular", "relaxed"],
              owningRoute: .preferences),
        .init(id: "showHamburgerMenu", displayName: "Show Location Button",
              group: .layout, symbolName: "location.fill",
              summary: "Floating button to switch saved locations.",
              searchTokens: ["hamburger", "menu", "location", "button", "floating"],
              owningRoute: .preferences),
        .init(id: "swipeBetweenLocations", displayName: "Swipe Between Locations",
              group: .layout, symbolName: "hand.draw.fill",
              summary: "Swipe horizontally to switch saved locations.",
              searchTokens: ["swipe", "gesture", "location", "switch", "next", "previous"],
              owningRoute: .preferences),
        .init(id: "showLocationHeader", displayName: "Show Location Header",
              group: .layout, symbolName: "mappin.and.ellipse",
              summary: "Show the “Weather for X” header above the hero card.",
              searchTokens: ["header", "location", "title", "label", "name", "hide"],
              owningRoute: .preferences),
        .init(id: "previewBeforeChangingLocation", displayName: "Preview Before Changing Location",
              group: .layout, symbolName: "eye.fill",
              summary: "Show weather preview before switching or adding a location.",
              searchTokens: ["preview", "location", "switch", "peek", "before", "change"],
              owningRoute: .preferences),
        .init(id: "showHeroLastUpdated", displayName: "Show Hero Last Updated",
              group: .layout, symbolName: "clock.arrow.circlepath",
              summary: "Show the “Last updated” button on the hero card.",
              searchTokens: ["last", "updated", "refresh", "stale", "hero", "button", "hide"],
              owningRoute: .preferences),
        .init(id: "compactCardsInLandscape", displayName: "Compact Cards in Landscape",
              group: .layout, symbolName: "rectangle.compress.vertical",
              summary: "Shrink card padding when the device is in landscape.",
              searchTokens: ["landscape", "compact", "card", "density", "orientation"],
              owningRoute: .preferences),
    ]

    // MARK: - Data

    private static let data: [KnobDescriptor] = [
        .init(id: "unitSystem", displayName: "Units",
              group: .data, symbolName: "thermometer.medium",
              summary: "Metric, Imperial, or UK units.",
              searchTokens: ["unit", "units", "metric", "imperial", "uk", "temperature", "system"],
              owningRoute: .preferences),
        .init(id: "temperaturePrecision", displayName: "Temperature Precision",
              group: .data, symbolName: "thermometer.transmission",
              summary: "Decimal places shown on temperature values (0–2).",
              searchTokens: ["temperature", "precision", "decimal", "place", "rounding"],
              owningRoute: .preferences),
        .init(id: "windPrecision", displayName: "Wind Precision",
              group: .data, symbolName: "wind",
              summary: "Decimal places shown on wind speed (0–1).",
              searchTokens: ["wind", "precision", "decimal", "place", "rounding", "speed"],
              owningRoute: .preferences),
        .init(id: "pressurePrecision", displayName: "Pressure Precision",
              group: .data, symbolName: "barometer",
              summary: "Decimal places shown on pressure values (0–2).",
              searchTokens: ["pressure", "precision", "decimal", "place", "rounding", "barometer"],
              owningRoute: .preferences),
        .init(id: "preferredDataSource", displayName: "Preferred Source",
              group: .data, symbolName: "antenna.radiowaves.left.and.right",
              summary: "Auto, WeatherKit, Open-Meteo, WU, or OWM.",
              searchTokens: ["source", "data", "weatherkit", "openmeteo", "wu", "owm", "auto"],
              owningRoute: .preferences),
        .init(id: "useOpenMeteoAsDefault", displayName: "Use Open-Meteo as Default",
              group: .data, symbolName: "cloud.sun.fill",
              summary: "Prefer Open-Meteo over WeatherKit when possible.",
              searchTokens: ["openmeteo", "default", "open-meteo", "source"],
              owningRoute: .weatherData),
        .init(id: "disableAPIKeys", displayName: "Disable API Keys",
              group: .data, symbolName: "key.slash",
              summary: "Don't use any keyed weather provider.",
              searchTokens: ["api", "key", "disable", "off", "credentials"],
              owningRoute: .weatherData),
        .init(id: "refreshCadence", displayName: "Refresh Cadence",
              group: .data, symbolName: "arrow.clockwise.circle.fill",
              summary: "How aggressively to refresh weather data.",
              searchTokens: ["refresh", "cadence", "battery", "aggressive", "normal"],
              owningRoute: .preferences),
        .init(id: "backgroundRefreshEnabled", displayName: "Background Refresh",
              group: .data, symbolName: "arrow.triangle.2.circlepath",
              summary: "Allow the app to refresh in the background.",
              searchTokens: ["background", "refresh", "bg", "fetch"],
              owningRoute: .preferences),
        .init(id: "showLocationLabel", displayName: "Show Location Label",
              group: .data, symbolName: "mappin.circle.fill",
              summary: "Always show “Weather for X” on the hero card.",
              searchTokens: ["location", "label", "name", "header", "show", "title"],
              owningRoute: .preferences),
    ]

    // MARK: - Behaviour

    private static let behaviour: [KnobDescriptor] = [
        .init(id: "enableHapticFeedback", displayName: "Haptic Feedback",
              group: .behaviour, symbolName: "iphone.radiowaves.left.and.right",
              summary: "Vibrate on interactions.",
              searchTokens: ["haptic", "vibration", "feedback", "rumble"],
              owningRoute: .behaviour),
        .init(id: "hapticIntensity", displayName: "Haptic Intensity",
              group: .behaviour, symbolName: "waveform",
              summary: "Light, medium, or heavy haptic strength.",
              searchTokens: ["haptic", "intensity", "strength", "light", "medium", "heavy"],
              owningRoute: .behaviour),
        .init(id: "pullToRefresh", displayName: "Pull to Refresh",
              group: .behaviour, symbolName: "arrow.down.circle.fill",
              summary: "Allow drag-down to refresh.",
              searchTokens: ["pull", "refresh", "drag", "gesture"],
              owningRoute: .behaviour),
        .init(id: "tapDayToExpand", displayName: "Tap Day to Expand",
              group: .behaviour, symbolName: "hand.tap.fill",
              summary: "Tap a daily card to open the detail sheet.",
              searchTokens: ["tap", "day", "expand", "detail", "gesture"],
              owningRoute: .behaviour),
        .init(id: "longPressToCustomise", displayName: "Long-Press to Customise",
              group: .behaviour, symbolName: "hand.point.up.left.fill",
              summary: "Long-press a section to customise it inline.",
              searchTokens: ["long", "press", "customise", "customize", "gesture"],
              owningRoute: .behaviour),
        .init(id: "confirmDestructive", displayName: "Confirm Destructive Actions",
              group: .behaviour, symbolName: "exclamationmark.triangle.fill",
              summary: "Ask before resetting or deleting a profile.",
              searchTokens: ["confirm", "destructive", "reset", "delete", "warning"],
              owningRoute: .behaviour),
        .init(id: "weatherAlertSounds", displayName: "Weather Alert Sounds",
              group: .behaviour, symbolName: "speaker.wave.3.fill",
              summary: "Play a sound for severe weather alerts.",
              searchTokens: ["alert", "sound", "warning", "severe", "weather", "audio"],
              owningRoute: .behaviour),
        .init(id: "rainAlertsEnabled", displayName: "Rain Alerts",
              group: .behaviour, symbolName: "cloud.rain.fill",
              summary: "Notify when rain is expected to start or stop.",
              searchTokens: ["rain", "precipitation", "alert", "notification", "umbrella"],
              owningRoute: .behaviour),
        .init(id: "severeWeatherAlertsEnabled", displayName: "Severe Weather Alerts",
              group: .behaviour, symbolName: "exclamationmark.triangle.fill",
              summary: "Notify for official severe weather warnings.",
              searchTokens: ["severe", "warning", "alert", "storm", "weatherkit", "bom"],
              owningRoute: .behaviour),
        .init(id: "aiAlertSummariesEnabled", displayName: "AI Alert Summaries",
              group: .behaviour, symbolName: "sparkles",
              summary: "Explain and summarise weather warnings in plain language, on-device.",
              searchTokens: ["ai", "apple", "intelligence", "summary", "summarise", "summarize",
                             "explain", "plain", "language", "alert", "warning"],
              owningRoute: .behaviour),
        .init(id: "quietHours", displayName: "Quiet Hours",
              group: .behaviour, symbolName: "moon.zzz.fill",
              summary: "Mute alerts and sounds during a daily time range.",
              searchTokens: ["quiet", "hours", "night", "mute", "do", "not", "disturb", "dnd",
                             "silence"],
              owningRoute: .behaviour),
        .init(id: "refreshSound", displayName: "Refresh Sound",
              group: .behaviour, symbolName: "bell.fill",
              summary: "Play a tick when refresh completes.",
              searchTokens: ["refresh", "sound", "tick", "bell", "audio"],
              owningRoute: .behaviour),
        .init(id: "vibrateOnPullToRefresh", displayName: "Vibrate on Refresh",
              group: .behaviour, symbolName: "iphone.gen3.radiowaves.left.and.right",
              summary: "Vibrate when pull-to-refresh completes successfully.",
              searchTokens: ["vibrate", "haptic", "refresh", "pull", "feedback"],
              owningRoute: .behaviour),
        .init(id: "confirmQuit", displayName: "Confirm Before Quitting",
              group: .behaviour, symbolName: "rectangle.portrait.and.arrow.right.fill",
              summary: "Ask before the app exits (catches swipe-away accidents).",
              searchTokens: ["quit", "exit", "confirm", "swipe", "close"],
              owningRoute: .behaviour),
    ]

    // MARK: - Accessibility

    private static let accessibility: [KnobDescriptor] = [
        .init(id: "reduceMotion", displayName: "Reduce Motion",
              group: .accessibility, symbolName: "tortoise.fill",
              summary: "Disable non-essential animations.",
              searchTokens: ["reduce", "motion", "animation", "accessibility", "slow"],
              owningRoute: .accessibility),
        .init(id: "reduceMotionForce", displayName: "Force Reduce Motion",
              group: .accessibility, symbolName: "tortoise.circle.fill",
              summary: "Always-on reduce motion regardless of OS setting.",
              searchTokens: ["reduce", "motion", "force", "accessibility"],
              owningRoute: .accessibility),
        .init(id: "enhancedVoiceOverLabels", displayName: "Enhanced VoiceOver Labels",
              group: .accessibility, symbolName: "eye.trianglebadge.exclamationmark.fill",
              summary: "More verbose screen-reader hints.",
              searchTokens: ["voiceover", "screen", "reader", "label", "accessibility", "a11y"],
              owningRoute: .accessibility),
        .init(id: "highContrastOutline", displayName: "High-Contrast Outline",
              group: .accessibility, symbolName: "square.dashed",
              summary: "Outlines around text for low-vision users.",
              searchTokens: ["contrast", "outline", "high", "vision", "accessibility"],
              owningRoute: .accessibility),
        .init(id: "hapticOnSelection", displayName: "Haptic on Selection",
              group: .accessibility, symbolName: "hand.point.up.left.fill",
              summary: "Vibrate when a picker value changes.",
              searchTokens: ["haptic", "selection", "picker", "change", "vibration"],
              owningRoute: .accessibility),
        .init(id: "tapticOnRefresh", displayName: "Taptic on Refresh",
              group: .accessibility, symbolName: "arrow.triangle.2.circlepath",
              summary: "Taptic engine pulse when the app refreshes data.",
              searchTokens: ["taptic", "refresh", "haptic", "feedback", "tick"],
              owningRoute: .accessibility),
    ]

    // MARK: - Power User

    private static let powerUser: [KnobDescriptor] = [
        .init(id: "experimentalNewHeroLayout", displayName: "Experimental: New Hero",
              group: .powerUser, symbolName: "sparkles",
              summary: "Try the redesigned hero card layout.",
              searchTokens: ["experimental", "hero", "new", "layout", "redesign", "lab"],
              owningRoute: .behaviour),
        .init(id: "experimentalSwipeRefresh", displayName: "Experimental: Swipe Refresh",
              group: .powerUser, symbolName: "arrow.down.to.line",
              summary: "Allow pull-to-refresh anywhere on the home screen.",
              searchTokens: ["experimental", "swipe", "refresh", "pull", "lab"],
              owningRoute: .behaviour),
    ]
}

// MARK: - KnobStorage convenience

extension KnobStorage {
    var allEditableKnobCount: Int {
        KnobDescriptor.catalogue.count
    }
}