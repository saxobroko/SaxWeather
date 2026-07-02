
import Foundation

// MARK: - 1.1 Visual — Colours & Typography

struct VisualSpec: Codable, Hashable {
    var accentColor: ColourToken = .named("blue")
    var palette: Palette = .init()
    /// `.glass` is gated by `#available(iOS 26.2, *)` at the call
    /// site; views fall back to `.solid` on older OSes.
    var cardStyle: CardStyle = .glass
    var cornerRadius: Double = 16
    /// Maps to `@AppStorage("customTextSizeMultiplier")` (1.0).
    var fontScale: Double = 1.0
    /// Matches `@AppStorage("boldText")` default `false`.
    var boldText: Bool = false
    /// Matches `@AppStorage("useSystemTextSize")` default `true`.
    var useSystemTextSize: Bool = true
    var typography: TypographyFamily = .system
    /// Matches `@AppStorage("increaseContrast")` default `false`.
    var increaseContrast: Bool = false
    /// Matches `@AppStorage("colorScheme")` default `"system"`.
    /// Stored as a raw string for backwards compatibility with
    /// `colorScheme == "dark"` checks scattered through views.
    var colorScheme: String = "system"
    var cardOpacity: Double = 0.6
    // MARK: v3 — extended card customisation. All persisted
    // through the existing `ProfileToAppStorageBridge` so the
    // existing profile/theme export keeps working. The defaults
    // match the visual identity of the `.glass` preset so the
    // first launch looks identical to today.
    /// Custom fill colour for `.solid` and `.neumorphic` cards.
    /// Empty string ("") falls back to `palette.surface`. This
    /// is the "what colour is the card itself" knob.
    var cardFillColor: ColourToken = .named("")
    /// Outline / border colour for `.outline` style and the
    /// subtle accent border drawn on every style.
    var cardBorderColor: ColourToken = .named("system")
    /// Width of the outline drawn for `.outline` cards and
    /// around every card. `0` = no border at all.
    var cardBorderWidth: Double = 1
    var cardTint: ColourToken = .named("")
    /// Strength of the drop shadow cast by each card. `0` = no
    /// shadow. Default `0.10` keeps the existing soft shadow
    /// used by the shipped presets.
    var cardShadowOpacity: Double = 0.10
    /// Blur radius of the card drop shadow. Default `8` matches
    /// the existing `shadow(radius: 8, …)` calls.
    var cardShadowRadius: Double = 8
    /// Horizontal offset of the card shadow. Default `0`.
    var cardShadowX: Double = 0
    /// Vertical offset of the card shadow. Default `4`.
    var cardShadowY: Double = 4
    /// Glass blur intensity, `0.0`...`1.0`. Default `0.6` maps to
    /// `.ultraThinMaterial` on older OSes and the official
    /// `Color.glass` API on iOS 26.2+. Higher = more frosted.
    var cardBlurIntensity: Double = 0.6
    var cardGlassOpacity: Double = 0.6
    /// Stroke drawn on the inside of `.glass` cards to give
    /// them a glassy edge highlight. Default `0.20` (subtle).
    var cardHighlightIntensity: Double = 0.20
    var cardTintOverlay: ColourToken = .named("")
    /// Strength of the `cardTintOverlay` linear gradient. The
    /// default 0.10 matches the shipped dark-mode tint.
    var cardTintOverlayOpacity: Double = 0.10
    /// Top-leading colour of the optional border gradient.
    /// Empty string = no gradient border (use `cardBorderColor`
    /// as a solid stroke instead).
    var cardBorderGradientStart: ColourToken = .named("")
    /// Bottom-trailing colour of the optional border gradient.
    var cardBorderGradientEnd: ColourToken = .named("")
    /// Strength of the border gradient.
    var cardBorderGradientOpacity: Double = 0.20
    /// `true` when the card should grow a soft inner shadow on
    /// `.neumorphic` cards. Ignored for other styles.
    var cardNeumorphicInset: Bool = true
    /// Horizontal inner padding the `.styledCard()` modifier
    /// adds around the wrapped content. Default 16 matches the
    /// original WeatherDetailsView padding.
    var cardPaddingH: Double = 16
    /// Vertical inner padding the `.styledCard()` modifier adds
    /// around the wrapped content. Default 20 matches the
    /// original WeatherDetailsView padding.
    var cardPaddingV: Double = 20
}

enum CardStyle: String, Codable, CaseIterable, Hashable {
    case glass, solid, outline, neumorphic
}

enum TypographyFamily: String, Codable, CaseIterable, Hashable {
    case system, rounded, serif, mono
}

struct Palette: Codable, Hashable {
    var background: ColourToken = .named("system")
    var surface: ColourToken = .named("system")
    var text: ColourToken = .named("system")
    var muted: ColourToken = .named("secondary")
    var danger: ColourToken = .named("red")
}

extension Palette {
    static let cosmeticAurora = Palette(
        background: .hex("#0B1B3A"),
        surface:    .hex("#1F4E79"),
        text:       .hex("#C5E0DC"),
        muted:      .hex("#5BC0BE"),
        danger:     .hex("#F2B5A0")
    )

    static let defaultPalette = Palette()

    static let selectablePalettes: [SelectablePalette] = [
        .init(
            id: "default",
            displayName: "Default",
            palette: .defaultPalette,
            requiredProductID: nil
        ),
        .init(
            id: "cosmeticAurora",
            displayName: "Aurora",
            palette: .cosmeticAurora,
            requiredProductID: "com.saxweather.cosmetic.aurora.palette"
        ),
    ]
}

struct SelectablePalette: Identifiable, Hashable {
    let id: String
    let displayName: String
    let palette: Palette
    /// The StoreKit product ID that unlocks this palette.
    /// `nil` for the free `Default` palette.
    let requiredProductID: String?
}

// MARK: - 1.2 Visual — Background

struct BackgroundSpec: Codable, Hashable {
    var mode: BackgroundMode = .preset
    /// Mirrors the existing `useCustomBackground` semantics in
    /// `BackgroundSettingsView`.
    var useCustom: Bool = true
    /// User-supplied background image (JPEG). Encoded as base64 in
    /// `.saxtheme`. Nil = no custom image.
    var customImageData: Data? = nil
    var gradient: GradientSpec = .init()
    /// Tint applied on top of the shipped preset image when
    /// `mode == .dynamicAccent`. Typed as `ColourToken` so it can
    /// reference any named colour, an RGB triple, or a hex string.
    var dynamicTint: ColourToken = .named("blue")
    /// Keyed by condition code (e.g. "clear-day", "rainy").
    /// Empty = use the shipped `Assets.xcassets` imagesets.
    var perCondition: [String: PerConditionBackground] = [:]
    var timeOfDayRule: TimeOfDayRule = .none
    /// Matches the 0.28 dark-overlay default used at
    /// `ContentView.swift:263`.
    var overlayOpacity: Double = 0.28
}

enum BackgroundMode: String, Codable, CaseIterable, Hashable {
    case preset, customImage, gradient, dynamicAccent
    case aurora
}

extension BackgroundMode {
    var requiredProductID: String? {
        switch self {
        case .aurora:
            return "com.saxweather.cosmetic.aurora.backgrounds"
        // Future cases (Phase 4+):
        // case .neon:      return "com.saxweather.cosmetic.neon.backgrounds"
        // case .halloween: return "com.saxweather.cosmetic.seasonal.halloween"
        // case .christmas: return "com.saxweather.cosmetic.seasonal.christmas"
        // case .pride:     return "com.saxweather.cosmetic.seasonal.pride"
        // case .autumn:    return "com.saxweather.cosmetic.seasonal.autumn"
        case .preset, .customImage, .gradient, .dynamicAccent:
            return nil
        }
    }
}

enum TimeOfDayRule: String, Codable, CaseIterable, Hashable {
    case none, dawnDayDuskNight, hourRange
}

struct GradientSpec: Codable, Hashable {
    /// `ColourToken`s so the gradient can use any named / RGB / hex
    /// colour, including references to `Palette.surface` (via the
    /// `"surface"` semantic name in `ColourToken`).
    var topColor: ColourToken = .named("blue")
    var bottomColor: ColourToken = .named("system")
    var topOpacity: Double = 0.5
    var bottomOpacity: Double = 0.9
}

struct PerConditionBackground: Codable, Hashable {
    var imageData: Data? = nil
    var gradientOverride: GradientSpec? = nil
}

// MARK: - 1.3 Visual — Iconography & Animations

struct IconographySpec: Codable, Hashable {
    var lottieAnimationSet: LottieAnimationSet = .bundled
    /// Override the Lottie JSON filename for a given condition
    /// code. Empty = use the bundled asset via
    /// `WeatherAnimationHelper.animationName(for:isNight:)`.
    var lottieOverrideMap: [String: String] = [:]
    var lottiePlaybackSpeed: Double = 1.0
    var lottieLoopMode: AnimationLoopMode = .loop
    /// Matches `@AppStorage("disableWeatherAnimations")` default `false`.
    var disableWeatherAnimations: Bool = false
    var weatherIconStyle: WeatherIconStyle = .multicolor
    var symbolSet: SymbolVariant = .filled
    var iconSizeMultiplier: Double = 1.0
}

enum LottieAnimationSet: String, Codable, CaseIterable, Hashable {
    case bundled, bundledStatic, custom
}

// Renamed from `LottieLoopMode` to avoid clashing with the
// Lottie framework's same-named enum (`Lottie.LottieLoopMode`).
// Swift can't disambiguate two `LottieLoopMode` types in the same
// module, so the customisation engine uses its own name.
enum AnimationLoopMode: String, Codable, CaseIterable, Hashable {
    case loop, playOnce
}

enum WeatherIconStyle: String, Codable, CaseIterable, Hashable {
    case multicolor, monochrome, outline
}

enum SymbolVariant: String, Codable, CaseIterable, Hashable {
    case automatic, filled, outline
}

// MARK: - 1.4 Visual — Layout & Density

struct LayoutSpec: Codable, Hashable {
    /// Matches `@AppStorage("displayMode")` default `"Summary"`.
    /// Raw string for compatibility with the existing
    /// `displayMode == "Detailed"` switch in `ContentView.swift:266`.
    var displayMode: String = "Summary"
    var homeSectionOrder: [HomeSectionID] = HomeSectionID.defaultOrder
    var hiddenHomeSections: Set<HomeSectionID> = []
    /// Matches `@AppStorage("forecastDays")` default `7`.
    var forecastDays: Int = 7
    var hourlyHours: Int = 24
    var cardDensity: CardDensity = .regular
    var showHamburgerMenu: Bool = true
    /// v2 — allow horizontal swipe gestures to move between saved
    /// locations. Off = user must tap the floating location button
    /// to switch.
    var swipeBetweenLocations: Bool = true
    /// v2 — show the "Weather for X" location header above the
    /// hero card. Off hides it for a cleaner minimal look.
    var showLocationHeader: Bool = true
    /// v2 — show a full-screen weather preview before adopting
    /// a new location from the menu, swipe gesture, or settings.
    var previewBeforeChangingLocation: Bool = true
    /// v2 — show the "Last updated" button below the location
    /// header on the hero card. Off hides it for a cleaner look.
    var showHeroLastUpdated: Bool = false
    /// v2 — shrink card padding when the device is in landscape so
    /// more sections fit on screen at once.
    var compactCardsInLandscape: Bool = true
}

enum CardDensity: String, Codable, CaseIterable, Hashable {
    case compact, regular, relaxed
}

enum HomeSectionID: String, Codable, CaseIterable, Hashable, Identifiable {
    case hero, current, hourly, daily, details, extended

    var id: String { rawValue }

    /// Mirrors the hardcoded order in `ContentView.mainWeatherView`
    /// and `DetailedWeatherView` so the default experience is
    /// identical to today.
    static let defaultOrder: [HomeSectionID] =
        [.hero, .current, .hourly, .daily, .details, .extended]
}

// MARK: - 1.5 + 1.6 Data — Units, Precision, Sources, Fields

struct DataSpec: Codable, Hashable {
    /// Matches `@AppStorage("unitSystem")` default `"Metric"`.
    var unitSystem: String = "Metric"
    var temperaturePrecision: Int = 1
    var windPrecision: Int = 0
    var pressurePrecision: Int = 0
    var preferredDataSource: PreferredDataSource = .auto
    /// Matches `@AppStorage("useOpenMeteoAsDefault")` default `false`.
    var useOpenMeteoAsDefault: Bool = false
    /// Matches `@AppStorage("disableAPIKeys")` default `false`.
    var disableAPIKeys: Bool = false
    var refreshCadence: RefreshCadence = .normal
    var backgroundRefreshEnabled: Bool = true
    // Displayed Fields (§1.6) — full MetricID enum lands in Phase 7.
    var visibleMetrics: Set<String> = []
    var hourlyMetrics: Set<String> = []
    var extendedCardsEnabled: Set<String> = []
    var showLocationLabel: Bool = true
}

enum PreferredDataSource: String, Codable, CaseIterable, Hashable {
    case auto, weatherKit, openMeteo, weatherUnderground, openWeatherMap
}

enum RefreshCadence: String, Codable, CaseIterable, Hashable {
    case aggressive, normal, batterySaver
}

// MARK: - 1.7 + 1.8 Behaviour — Interactions, Sound, Notifications

struct BehaviourSpec: Codable, Hashable {
    /// Matches `@AppStorage("enableHapticFeedback")` default `true`.
    var enableHapticFeedback: Bool = true
    var hapticIntensity: HapticIntensity = .medium
    var pullToRefresh: Bool = true
    var tapDayToExpand: Bool = true
    var longPressToCustomise: Bool = true
    var confirmDestructive: Bool = true
    var weatherAlertSounds: Bool = true
    /// Matches `@AppStorage("rainAlertsEnabled")` default `true`.
    var rainAlertsEnabled: Bool = true
    /// Matches `@AppStorage("severeWeatherAlertsEnabled")` default `true`.
    var severeWeatherAlertsEnabled: Bool = true
    /// Matches `@AppStorage("speakWeatherAlerts")` default `true`.
    var speakWeatherAlerts: Bool = true
    /// Hour-of-day in 24h clock. Nil = no quiet hours.
    var quietHoursStart: Int? = nil
    var quietHoursEnd: Int? = nil
    var refreshSound: Bool = false
    /// v2 — vibrate when pull-to-refresh completes successfully.
    /// Gated by `enableHapticFeedback` at the call site so users
    /// who have disabled haptics don't feel this one either.
    var vibrateOnPullToRefresh: Bool = true
    /// v2 — ask "Are you sure you want to quit?" when the user
    /// swipes to dismiss the app. Useful for muscle-memory swipe-
    /// away accidents on iPad.
    var confirmQuit: Bool = false
}

enum HapticIntensity: String, Codable, CaseIterable, Hashable {
    case light, medium, heavy
}

// MARK: - 1.9 Accessibility

struct AccessibilitySpec: Codable, Hashable {
    /// Matches `@AppStorage("reduceMotion")` default `false`.
    var reduceMotion: Bool = false
    var reduceMotionForce: Bool = false
    /// Matches `@AppStorage("enhancedVoiceOverLabels")` default `true`.
    var enhancedVoiceOverLabels: Bool = true
    var hapticOnSelection: Bool = true
    var tapticOnRefresh: Bool = true
    var highContrastOutline: Bool = false
}

// MARK: - 1.10 Content — Language & Terminology

struct ContentSpec: Codable, Hashable {
    /// `nil` = follow system language.
    var language: String? = nil
    var terminologySet: TerminologySet = .system
    /// UUID *strings* → user-chosen nicknames for saved locations.
    /// Using string keys keeps `.saxtheme` JSON readable.
    var locationNicknames: [String: String] = [:]
    /// `MetricID` raw value → user-chosen label.
    var customLabels: [String: String] = [:]
}

enum TerminologySet: String, Codable, CaseIterable, Hashable {
    case system, feelsLike, apparent, japanese
}

// MARK: - 1.11 Power-User

struct PowerUserSpec: Codable, Hashable {
    var experimentalFlags: Set<String> = []
    var shortcutName: String? = nil
    var widgetRefreshPolicy: WidgetRefreshPolicy = .normal
    /// Strip credentials and personal coordinates from exported
    /// `.saxtheme` files. Off = export everything (rarely useful).
    var shareThemeOnExport: Bool = true
    var debugOverlay: Bool = false
    /// v2 — try the new hero card layout. Off until the design is
    /// finalised, then flipped on by default. Lives behind a flag
    /// so users can opt in early without recompiling.
    var experimentalNewHeroLayout: Bool = false
    /// v2 — allow pull-to-refresh anywhere on the home screen,
    /// not just inside the scroll view's content. More forgiving
    /// but occasionally triggers when scrolling stops.
    var experimentalSwipeRefresh: Bool = false
}

enum WidgetRefreshPolicy: String, Codable, CaseIterable, Hashable {
    case frequent, normal, batterySaver
}

// MARK: - 1.12 Widget — Per-Widget Variants

struct WidgetSpec: Codable, Hashable {
    var smallStyle: SmallWidgetStyle = .classic
    var mediumStyle: MediumWidgetStyle = .heroForecast
    var largeStyle: LargeWidgetStyle = .full
    var background: WidgetBackground = .system
    /// `true` → use the active profile's `accentColor`.
    /// `false` → use `accentOverride` instead.
    var accentFollowsApp: Bool = true
    var accentOverride: String = "blue"
    var tapAction: WidgetTapAction = .openApp
}

enum SmallWidgetStyle: String, Codable, CaseIterable, Hashable {
    case classic, minimal, icon, graph
}

enum MediumWidgetStyle: String, Codable, CaseIterable, Hashable {
    case heroForecast, heroHourly, graph
}

enum LargeWidgetStyle: String, Codable, CaseIterable, Hashable {
    case full, table, chart
}

enum WidgetBackground: String, Codable, CaseIterable, Hashable {
    case transparent, system, vignette, userImage
}

enum WidgetTapAction: String, Codable, CaseIterable, Hashable {
    case openApp, refresh
}

// MARK: - 1.13 Forecast Presentation

struct ForecastSpec: Codable, Hashable {
    var hourlyChartType: ChartType = .line
    var hourlyCardStyle: HourlyCardStyle = .compact
    var dailyCardStyle: DailyCardStyle = .row
    var precipitationOverlay: Bool = true
    var showSunArc: Bool = true
    var showMoonPhase: Bool = true
    var chartAxes: Bool = false
    /// v2 — show the "Next 24 hours" / "Tonight" header above
    /// the hourly forecast strip. Off collapses the strip directly
    /// against the hero card for a denser look.
    var showHourlySummary: Bool = true
    /// v2 — number of metric cards shown side-by-side in the
    /// "Details" grid. Range 1…3; `2` is the shipped default.
    var detailedColumnCount: Int = 2
    var chartSkin: ChartSkin = .none
}

enum ChartType: String, Codable, CaseIterable, Hashable {
    case line, bar, area, gradient
}

enum HourlyCardStyle: String, Codable, CaseIterable, Hashable {
    case compact, detailed
}

enum DailyCardStyle: String, Codable, CaseIterable, Hashable {
    case row, grid, bars
}
