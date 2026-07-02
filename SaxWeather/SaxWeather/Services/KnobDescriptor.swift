
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
    case accessibility
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
        + layout + forecast + data + behaviour + accessibility
        + content + widget + powerUser

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
              owningRoute: .appearance),
        .init(id: "cornerRadius", displayName: "Corner Radius",
              group: .visual, symbolName: "roundedtop.and.roundedbottom",
              summary: "How rounded card corners are (0–28 pt).",
              searchTokens: ["corner", "radius", "rounded", "shape"],
              owningRoute: .appearance),
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
              owningRoute: .appearance),
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
              owningRoute: .appearance),
        .init(id: "homeSectionOrder", displayName: "Home Section Order",
              group: .layout, symbolName: "arrow.up.arrow.down.square",
              summary: "Drag-reorder the home-screen sections.",
              searchTokens: ["home", "section", "order", "reorder", "layout"],
              owningRoute: .preferences),
        .init(id: "hiddenHomeSections", displayName: "Hidden Sections",
              group: .layout, symbolName: "eye.slash.fill",
              summary: "Sections to hide from the home screen.",
              searchTokens: ["home", "hidden", "section", "hide"],
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
              owningRoute: .appearance),
        .init(id: "compactCardsInLandscape", displayName: "Compact Cards in Landscape",
              group: .layout, symbolName: "rectangle.compress.vertical",
              summary: "Shrink card padding when the device is in landscape.",
              searchTokens: ["landscape", "compact", "card", "density", "orientation"],
              owningRoute: .appearance),
    ]

    // MARK: - Forecast

    private static let forecast: [KnobDescriptor] = [
        .init(id: "hourlyChartType", displayName: "Hourly Chart Type",
              group: .forecast, symbolName: "chart.line.uptrend.xyaxis",
              summary: "Line, bar, area, or gradient hourly chart.",
              searchTokens: ["hourly", "chart", "graph", "line", "bar", "area", "gradient"],
              owningRoute: .appearance),
        .init(id: "hourlyCardStyle", displayName: "Hourly Card Style",
              group: .forecast, symbolName: "rectangle.grid.1x2.fill",
              summary: "Compact or detailed hourly cells.",
              searchTokens: ["hourly", "card", "cell", "compact", "detailed", "row"],
              owningRoute: .appearance),
        .init(id: "dailyCardStyle", displayName: "Daily Card Style",
              group: .forecast, symbolName: "list.bullet.rectangle",
              summary: "Row, grid, or bars daily layout.",
              searchTokens: ["daily", "card", "row", "grid", "bar", "bars", "list"],
              owningRoute: .appearance),
        .init(id: "chartAxes", displayName: "Chart Axes",
              group: .forecast, symbolName: "ruler.fill",
              summary: "Show numeric axes on the hourly chart.",
              searchTokens: ["chart", "axis", "axes", "ruler", "label", "number"],
              owningRoute: .appearance),
        .init(id: "precipitationOverlay", displayName: "Precipitation Overlay",
              group: .forecast, symbolName: "cloud.rain.fill",
              summary: "Show precipitation bars on the hourly chart.",
              searchTokens: ["precipitation", "overlay", "rain", "bars", "hourly"],
              owningRoute: .appearance),
        .init(id: "showSunArc", displayName: "Sun Arc",
              group: .forecast, symbolName: "sun.horizon.fill",
              summary: "Visual sunrise/sunset arc on the hero card.",
              searchTokens: ["sun", "arc", "sunrise", "sunset", "hero"],
              owningRoute: .appearance),
        .init(id: "showMoonPhase", displayName: "Moon Phase",
              group: .forecast, symbolName: "moon.stars.fill",
              summary: "Show current moon phase on the hero card.",
              searchTokens: ["moon", "phase", "hero", "lunar"],
              owningRoute: .appearance),
        .init(id: "showHourlySummary", displayName: "Hourly Summary Header",
              group: .forecast, symbolName: "text.alignleft",
              summary: "Show “Next 24 hours” header above the hourly strip.",
              searchTokens: ["hourly", "summary", "header", "title", "next", "tonight"],
              owningRoute: .appearance),
        .init(id: "detailedColumnCount", displayName: "Detail Grid Columns",
              group: .forecast, symbolName: "square.grid.2x2.fill",
              summary: "Number of metric cards per row in the Details grid (1–3).",
              searchTokens: ["detail", "details", "grid", "column", "columns", "card"],
              owningRoute: .appearance),
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
              owningRoute: .preferences),
        .init(id: "disableAPIKeys", displayName: "Disable API Keys",
              group: .data, symbolName: "key.slash",
              summary: "Don't use any keyed weather provider.",
              searchTokens: ["api", "key", "disable", "off", "credentials"],
              owningRoute: .preferences),
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
        .init(id: "visibleMetrics", displayName: "Visible Metric Cards",
              group: .data, symbolName: "checklist",
              summary: "Which metric cards appear in the Details section.",
              searchTokens: ["metric", "visible", "show", "details", "card", "cards"],
              owningRoute: .preferences),
        .init(id: "hourlyMetrics", displayName: "Hourly Metrics",
              group: .data, symbolName: "list.bullet.indent",
              summary: "Which fields appear in each hourly cell.",
              searchTokens: ["hourly", "metric", "fields", "temperature", "precip", "wind"],
              owningRoute: .preferences),
        .init(id: "extendedCardsEnabled", displayName: "Extended Cards",
              group: .data, symbolName: "square.stack.3d.up.fill",
              summary: "AQI, UV, pollen, and sun-moon cards enabled.",
              searchTokens: ["extended", "card", "aqi", "uv", "pollen", "sun", "moon"],
              owningRoute: .preferences),
        .init(id: "showLocationLabel", displayName: "Show Location Label",
              group: .data, symbolName: "mappin.circle.fill",
              summary: "Always show “Weather for X” on the hero card.",
              searchTokens: ["location", "label", "name", "header", "show", "title"],
              owningRoute: .appearance),
    ]

    // MARK: - Behaviour

    private static let behaviour: [KnobDescriptor] = [
        .init(id: "enableHapticFeedback", displayName: "Haptic Feedback",
              group: .behaviour, symbolName: "iphone.radiowaves.left.and.right",
              summary: "Vibrate on interactions.",
              searchTokens: ["haptic", "vibration", "feedback", "rumble"],
              owningRoute: .accessibility),
        .init(id: "hapticIntensity", displayName: "Haptic Intensity",
              group: .behaviour, symbolName: "waveform",
              summary: "Light, medium, or heavy haptic strength.",
              searchTokens: ["haptic", "intensity", "strength", "light", "medium", "heavy"],
              owningRoute: .accessibility),
        .init(id: "pullToRefresh", displayName: "Pull to Refresh",
              group: .behaviour, symbolName: "arrow.down.circle.fill",
              summary: "Allow drag-down to refresh.",
              searchTokens: ["pull", "refresh", "drag", "gesture"],
              owningRoute: .preferences),
        .init(id: "tapDayToExpand", displayName: "Tap Day to Expand",
              group: .behaviour, symbolName: "hand.tap.fill",
              summary: "Tap a daily card to open the detail sheet.",
              searchTokens: ["tap", "day", "expand", "detail", "gesture"],
              owningRoute: .preferences),
        .init(id: "longPressToCustomise", displayName: "Long-Press to Customise",
              group: .behaviour, symbolName: "hand.point.up.left.fill",
              summary: "Long-press a section to customise it inline.",
              searchTokens: ["long", "press", "customise", "customize", "gesture"],
              owningRoute: .preferences),
        .init(id: "confirmDestructive", displayName: "Confirm Destructive Actions",
              group: .behaviour, symbolName: "exclamationmark.triangle.fill",
              summary: "Ask before resetting or deleting a profile.",
              searchTokens: ["confirm", "destructive", "reset", "delete", "warning"],
              owningRoute: .preferences),
        .init(id: "weatherAlertSounds", displayName: "Weather Alert Sounds",
              group: .behaviour, symbolName: "speaker.wave.3.fill",
              summary: "Play a sound for severe weather alerts.",
              searchTokens: ["alert", "sound", "warning", "severe", "weather", "audio"],
              owningRoute: .preferences),
        .init(id: "quietHours", displayName: "Quiet Hours",
              group: .behaviour, symbolName: "moon.zzz.fill",
              summary: "Mute alerts and sounds during a daily time range.",
              searchTokens: ["quiet", "hours", "night", "mute", "do", "not", "disturb", "dnd",
                             "silence"],
              owningRoute: .preferences),
        .init(id: "refreshSound", displayName: "Refresh Sound",
              group: .behaviour, symbolName: "bell.fill",
              summary: "Play a tick when refresh completes.",
              searchTokens: ["refresh", "sound", "tick", "bell", "audio"],
              owningRoute: .preferences),
        .init(id: "vibrateOnPullToRefresh", displayName: "Vibrate on Refresh",
              group: .behaviour, symbolName: "iphone.gen3.radiowaves.left.and.right",
              summary: "Vibrate when pull-to-refresh completes successfully.",
              searchTokens: ["vibrate", "haptic", "refresh", "pull", "feedback"],
              owningRoute: .accessibility),
        .init(id: "confirmQuit", displayName: "Confirm Before Quitting",
              group: .behaviour, symbolName: "rectangle.portrait.and.arrow.right.fill",
              summary: "Ask before the app exits (catches swipe-away accidents).",
              searchTokens: ["quit", "exit", "confirm", "swipe", "close"],
              owningRoute: .preferences),
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

    // MARK: - Content

    private static let content: [KnobDescriptor] = [
        .init(id: "language", displayName: "Language",
              group: .content, symbolName: "globe",
              summary: "Override the system language.",
              searchTokens: ["language", "locale", "translation", "i18n"],
              owningRoute: .preferences),
        .init(id: "terminologySet", displayName: "Terminology",
              group: .content, symbolName: "text.bubble.fill",
              summary: "Feels-like vs apparent vs 体感.",
              searchTokens: ["terminology", "feels", "like", "apparent", "language"],
              owningRoute: .preferences),
        .init(id: "locationNicknames", displayName: "Location Nicknames",
              group: .content, symbolName: "tag.fill",
              summary: "Per-saved-location custom label overrides.",
              searchTokens: ["nickname", "label", "location", "rename", "custom", "tag"],
              owningRoute: .preferences),
        .init(id: "customLabels", displayName: "Custom Metric Labels",
              group: .content, symbolName: "character.bubble.fill",
              summary: "User-defined labels for metric cards.",
              searchTokens: ["label", "metric", "rename", "custom", "naming"],
              owningRoute: .preferences),
    ]

    // MARK: - Widget

    private static let widget: [KnobDescriptor] = [
        .init(id: "widgetStyle.small", displayName: "Small Widget Style",
              group: .widget, symbolName: "square.grid.2x2.fill",
              summary: "Classic, minimal, icon, or graph.",
              searchTokens: ["widget", "small", "style", "classic", "minimal", "icon", "graph"],
              owningRoute: .preferences),
        .init(id: "widgetStyle.medium", displayName: "Medium Widget Style",
              group: .widget, symbolName: "rectangle.split.2x1.fill",
              summary: "Hero + forecast, hero + hourly, or graph.",
              searchTokens: ["widget", "medium", "style", "hero", "forecast", "hourly", "graph"],
              owningRoute: .preferences),
        .init(id: "widgetStyle.large", displayName: "Large Widget Style",
              group: .widget, symbolName: "rectangle.fill",
              summary: "Full, table, or chart composition.",
              searchTokens: ["widget", "large", "style", "full", "table", "chart"],
              owningRoute: .preferences),
        .init(id: "widgetBackground", displayName: "Widget Background",
              group: .widget, symbolName: "rectangle.dashed",
              summary: "Transparent, system, vignette, or user image.",
              searchTokens: ["widget", "background", "transparent", "vignette"],
              owningRoute: .preferences),
        .init(id: "widgetAccentSource", displayName: "Widget Accent Source",
              group: .widget, symbolName: "paintbrush.pointed.fill",
              summary: "Follow the app accent or use a widget-only override.",
              searchTokens: ["widget", "accent", "tint", "colour", "color", "override",
                             "follow"],
              owningRoute: .preferences),
        .init(id: "widgetTapAction", displayName: "Widget Tap Action",
              group: .widget, symbolName: "hand.tap.fill",
              summary: "Open app, refresh, or open a specific location.",
              searchTokens: ["widget", "tap", "action", "open", "refresh"],
              owningRoute: .preferences),
    ]

    // MARK: - Power User

    private static let powerUser: [KnobDescriptor] = [
        .init(id: "experimentalFlags", displayName: "Experimental Flags",
              group: .powerUser, symbolName: "flag.fill",
              summary: "Per-flag opt-ins for unfinished features.",
              searchTokens: ["experimental", "flag", "beta", "feature", "lab"],
              owningRoute: .preferences),
        .init(id: "shortcutName", displayName: "Custom Shortcut Phrase",
              group: .powerUser, symbolName: "mic.fill",
              summary: "Phrase used to invoke the app from Shortcuts.",
              searchTokens: ["shortcut", "siri", "phrase", "invoke", "voice", "automation"],
              owningRoute: .preferences),
        .init(id: "shareThemeOnExport", displayName: "Sanitise Theme on Export",
              group: .powerUser, symbolName: "lock.shield.fill",
              summary: "Strip credentials and coordinates before exporting a .saxtheme.",
              searchTokens: ["share", "export", "theme", "strip", "credentials", "sanitise",
                             "privacy"],
              owningRoute: .preferences),
        .init(id: "widgetRefreshPolicy", displayName: "Widget Refresh Policy",
              group: .powerUser, symbolName: "clock.arrow.circlepath",
              summary: "Frequent, normal, or battery-saver refresh.",
              searchTokens: ["widget", "refresh", "policy", "frequent", "battery"],
              owningRoute: .preferences),
        .init(id: "debugOverlay", displayName: "Debug Overlay",
              group: .powerUser, symbolName: "ladybug.fill",
              summary: "Show FPS / version badge over the UI.",
              searchTokens: ["debug", "overlay", "fps", "badge", "developer"],
              owningRoute: .preferences),
        .init(id: "experimentalNewHeroLayout", displayName: "Experimental: New Hero",
              group: .powerUser, symbolName: "sparkles",
              summary: "Try the redesigned hero card layout.",
              searchTokens: ["experimental", "hero", "new", "layout", "redesign", "lab"],
              owningRoute: .preferences),
        .init(id: "experimentalSwipeRefresh", displayName: "Experimental: Swipe Refresh",
              group: .powerUser, symbolName: "arrow.down.to.line",
              summary: "Allow pull-to-refresh anywhere on the home screen.",
              searchTokens: ["experimental", "swipe", "refresh", "pull", "lab"],
              owningRoute: .preferences),
    ]
}

// MARK: - KnobStorage convenience

extension KnobStorage {
    var allEditableKnobCount: Int {
        KnobDescriptor.catalogue.count
    }
}