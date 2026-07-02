
import Foundation

@MainActor
enum ProfileToAppStorageBridge {

    // MARK: - Registry → UserDefaults

    static func bridge(_ knobs: KnobStorage, to defaults: UserDefaults = .standard) {
        dispatchPrecondition(condition: .onQueue(.main))

        // Visual
        defaults.set(knobs.visual.accentColor.rawString, forKey: "accentColor")
        defaults.set(knobs.visual.colorScheme, forKey: "colorScheme")
        defaults.set(knobs.visual.useSystemTextSize, forKey: "useSystemTextSize")
        defaults.set(knobs.visual.fontScale, forKey: "customTextSizeMultiplier")
        defaults.set(knobs.visual.boldText, forKey: "boldText")
        defaults.set(knobs.visual.increaseContrast, forKey: "increaseContrast")
        defaults.set(knobs.visual.cardStyle.rawValue, forKey: "cardStyle")
        defaults.set(knobs.visual.cornerRadius, forKey: "cornerRadius")
        defaults.set(knobs.visual.cardOpacity, forKey: "cardOpacity")
        defaults.set(knobs.visual.cardFillColor.rawString, forKey: "cardFillColor")
        defaults.set(knobs.visual.cardBorderColor.rawString, forKey: "cardBorderColor")
        defaults.set(knobs.visual.cardBorderWidth, forKey: "cardBorderWidth")
        defaults.set(knobs.visual.cardTint.rawString, forKey: "cardTint")
        defaults.set(knobs.visual.cardShadowOpacity, forKey: "cardShadowOpacity")
        defaults.set(knobs.visual.cardShadowRadius, forKey: "cardShadowRadius")
        defaults.set(knobs.visual.cardShadowX, forKey: "cardShadowX")
        defaults.set(knobs.visual.cardShadowY, forKey: "cardShadowY")
        defaults.set(knobs.visual.cardBlurIntensity, forKey: "cardBlurIntensity")
        defaults.set(knobs.visual.cardGlassOpacity, forKey: "cardGlassOpacity")
        defaults.set(knobs.visual.cardHighlightIntensity, forKey: "cardHighlightIntensity")
        defaults.set(knobs.visual.cardTintOverlay.rawString, forKey: "cardTintOverlay")
        defaults.set(knobs.visual.cardTintOverlayOpacity, forKey: "cardTintOverlayOpacity")
        defaults.set(knobs.visual.cardBorderGradientStart.rawString, forKey: "cardBorderGradientStart")
        defaults.set(knobs.visual.cardBorderGradientEnd.rawString, forKey: "cardBorderGradientEnd")
        defaults.set(knobs.visual.cardBorderGradientOpacity, forKey: "cardBorderGradientOpacity")
        defaults.set(knobs.visual.cardNeumorphicInset, forKey: "cardNeumorphicInset")
        defaults.set(knobs.visual.cardPaddingH, forKey: "cardPaddingH")
        defaults.set(knobs.visual.cardPaddingV, forKey: "cardPaddingV")
        defaults.set(knobs.visual.typography.rawValue, forKey: "typography")

        // Background — `nil` removes the key, which `@AppStorage`
        // then reads back as `nil`.
        defaults.set(knobs.background.useCustom, forKey: "useCustomBackground")
        defaults.set(knobs.background.customImageData, forKey: "userCustomBackground")
        defaults.set(knobs.background.overlayOpacity, forKey: "overlayOpacity")
        defaults.set(knobs.background.mode.rawValue, forKey: "backgroundMode")
        defaults.set(knobs.background.timeOfDayRule.rawValue, forKey: "backgroundTimeOfDayRule")

        // Iconography
        defaults.set(knobs.iconography.disableWeatherAnimations,
                     forKey: "disableWeatherAnimations")
        defaults.set(knobs.iconography.lottiePlaybackSpeed,
                     forKey: "lottiePlaybackSpeed")
        defaults.set(knobs.iconography.lottieLoopMode.rawValue,
                     forKey: "lottieLoopMode")
        defaults.set(knobs.iconography.lottieAnimationSet.rawValue,
                     forKey: "lottieAnimationSet")
        defaults.set(knobs.iconography.weatherIconStyle.rawValue,
                     forKey: "weatherIconStyle")
        defaults.set(knobs.iconography.symbolSet.rawValue, forKey: "symbolSet")
        defaults.set(knobs.iconography.iconSizeMultiplier, forKey: "iconSizeMultiplier")

        // Layout
        defaults.set(knobs.layout.forecastDays, forKey: "forecastDays")
        defaults.set(knobs.layout.displayMode, forKey: "displayMode")
        defaults.set(knobs.layout.showHamburgerMenu, forKey: "showHamburgerMenu")
        defaults.set(knobs.layout.hourlyHours, forKey: "hourlyHours")
        defaults.set(knobs.layout.cardDensity.rawValue, forKey: "cardDensity")
        defaults.set(knobs.layout.swipeBetweenLocations, forKey: "swipeBetweenLocations")
        defaults.set(knobs.layout.showLocationHeader, forKey: "showLocationHeader")
        defaults.set(knobs.layout.showHeroLastUpdated, forKey: "showHeroLastUpdated")
        defaults.set(knobs.layout.compactCardsInLandscape, forKey: "compactCardsInLandscape")

        // Data
        defaults.set(knobs.data.unitSystem, forKey: "unitSystem")
        defaults.set(knobs.data.useOpenMeteoAsDefault,
                     forKey: "useOpenMeteoAsDefault")
        defaults.set(knobs.data.disableAPIKeys, forKey: "disableAPIKeys")
        defaults.set(knobs.data.preferredDataSource.rawValue,
                     forKey: "preferredDataSource")
        defaults.set(knobs.data.refreshCadence.rawValue, forKey: "refreshCadence")
        defaults.set(knobs.data.backgroundRefreshEnabled,
                     forKey: "backgroundRefreshEnabled")
        defaults.set(knobs.data.temperaturePrecision, forKey: "temperaturePrecision")
        defaults.set(knobs.data.windPrecision, forKey: "windPrecision")
        defaults.set(knobs.data.pressurePrecision, forKey: "pressurePrecision")
        defaults.set(knobs.data.showLocationLabel, forKey: "showLocationLabel")

        // Forecast
        defaults.set(knobs.forecast.hourlyChartType.rawValue, forKey: "hourlyChartType")
        defaults.set(knobs.forecast.hourlyCardStyle.rawValue, forKey: "hourlyCardStyle")
        defaults.set(knobs.forecast.dailyCardStyle.rawValue, forKey: "dailyCardStyle")
        defaults.set(knobs.forecast.precipitationOverlay, forKey: "precipitationOverlay")
        defaults.set(knobs.forecast.showSunArc, forKey: "showSunArc")
        defaults.set(knobs.forecast.showMoonPhase, forKey: "showMoonPhase")
        defaults.set(knobs.forecast.showHourlySummary, forKey: "showHourlySummary")
        defaults.set(knobs.forecast.chartAxes, forKey: "chartAxes")
        defaults.set(knobs.forecast.detailedColumnCount, forKey: "detailedColumnCount")

        // Behaviour
        defaults.set(knobs.behaviour.enableHapticFeedback,
                     forKey: "enableHapticFeedback")
        defaults.set(knobs.behaviour.speakWeatherAlerts,
                     forKey: "speakWeatherAlerts")
        defaults.set(knobs.behaviour.hapticIntensity.rawValue, forKey: "hapticIntensity")
        defaults.set(knobs.behaviour.pullToRefresh, forKey: "pullToRefresh")
        defaults.set(knobs.behaviour.tapDayToExpand, forKey: "tapDayToExpand")
        defaults.set(knobs.behaviour.longPressToCustomise,
                     forKey: "longPressToCustomise")
        defaults.set(knobs.behaviour.confirmDestructive, forKey: "confirmDestructive")
        defaults.set(knobs.behaviour.weatherAlertSounds, forKey: "weatherAlertSounds")
        if let s = knobs.behaviour.quietHoursStart {
            defaults.set(s, forKey: "quietHoursStart")
        } else {
            defaults.removeObject(forKey: "quietHoursStart")
        }
        if let e = knobs.behaviour.quietHoursEnd {
            defaults.set(e, forKey: "quietHoursEnd")
        } else {
            defaults.removeObject(forKey: "quietHoursEnd")
        }
        defaults.set(knobs.behaviour.refreshSound, forKey: "refreshSound")
        defaults.set(knobs.behaviour.vibrateOnPullToRefresh,
                     forKey: "vibrateOnPullToRefresh")
        defaults.set(knobs.behaviour.confirmQuit, forKey: "confirmQuit")

        // Accessibility
        defaults.set(knobs.accessibility.reduceMotion, forKey: "reduceMotion")
        defaults.set(knobs.accessibility.enhancedVoiceOverLabels,
                     forKey: "enhancedVoiceOverLabels")
        defaults.set(knobs.accessibility.reduceMotionForce, forKey: "reduceMotionForce")
        defaults.set(knobs.accessibility.highContrastOutline, forKey: "highContrastOutline")
        defaults.set(knobs.accessibility.hapticOnSelection, forKey: "hapticOnSelection")
        defaults.set(knobs.accessibility.tapticOnRefresh, forKey: "tapticOnRefresh")

        // Power user
        defaults.set(knobs.powerUser.widgetRefreshPolicy.rawValue,
                     forKey: "widgetRefreshPolicy")
        defaults.set(knobs.powerUser.shareThemeOnExport, forKey: "shareThemeOnExport")
        defaults.set(knobs.powerUser.debugOverlay, forKey: "debugOverlay")
        defaults.set(knobs.powerUser.experimentalNewHeroLayout,
                     forKey: "experimentalNewHeroLayout")
        defaults.set(knobs.powerUser.experimentalSwipeRefresh,
                     forKey: "experimentalSwipeRefresh")
    }

    // MARK: - UserDefaults → KnobStorage (first-launch seeding)

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
        if let v = defaults.string(forKey: "cardStyle"),
           let parsed = CardStyle(rawValue: v) {
            knobs.visual.cardStyle = parsed
        }
        if defaults.object(forKey: "cornerRadius") != nil {
            knobs.visual.cornerRadius = defaults.double(forKey: "cornerRadius")
        }
        if defaults.object(forKey: "cardOpacity") != nil {
            knobs.visual.cardOpacity = defaults.double(forKey: "cardOpacity")
        }
        if let v = defaults.string(forKey: "cardFillColor") {
            knobs.visual.cardFillColor = ColourToken(rawString: v)
        }
        if let v = defaults.string(forKey: "cardBorderColor") {
            knobs.visual.cardBorderColor = ColourToken(rawString: v)
        }
        if defaults.object(forKey: "cardBorderWidth") != nil {
            knobs.visual.cardBorderWidth = defaults.double(forKey: "cardBorderWidth")
        }
        if let v = defaults.string(forKey: "cardTint") {
            knobs.visual.cardTint = ColourToken(rawString: v)
        }
        if defaults.object(forKey: "cardShadowOpacity") != nil {
            knobs.visual.cardShadowOpacity = defaults.double(forKey: "cardShadowOpacity")
        }
        if defaults.object(forKey: "cardShadowRadius") != nil {
            knobs.visual.cardShadowRadius = defaults.double(forKey: "cardShadowRadius")
        }
        if defaults.object(forKey: "cardShadowX") != nil {
            knobs.visual.cardShadowX = defaults.double(forKey: "cardShadowX")
        }
        if defaults.object(forKey: "cardShadowY") != nil {
            knobs.visual.cardShadowY = defaults.double(forKey: "cardShadowY")
        }
        if defaults.object(forKey: "cardBlurIntensity") != nil {
            knobs.visual.cardBlurIntensity = defaults.double(forKey: "cardBlurIntensity")
        }
        if defaults.object(forKey: "cardGlassOpacity") != nil {
            knobs.visual.cardGlassOpacity = defaults.double(forKey: "cardGlassOpacity")
        }
        if defaults.object(forKey: "cardHighlightIntensity") != nil {
            knobs.visual.cardHighlightIntensity = defaults.double(forKey: "cardHighlightIntensity")
        }
        if let v = defaults.string(forKey: "cardTintOverlay") {
            knobs.visual.cardTintOverlay = ColourToken(rawString: v)
        }
        if defaults.object(forKey: "cardTintOverlayOpacity") != nil {
            knobs.visual.cardTintOverlayOpacity = defaults.double(forKey: "cardTintOverlayOpacity")
        }
        if let v = defaults.string(forKey: "cardBorderGradientStart") {
            knobs.visual.cardBorderGradientStart = ColourToken(rawString: v)
        }
        if let v = defaults.string(forKey: "cardBorderGradientEnd") {
            knobs.visual.cardBorderGradientEnd = ColourToken(rawString: v)
        }
        if defaults.object(forKey: "cardBorderGradientOpacity") != nil {
            knobs.visual.cardBorderGradientOpacity = defaults.double(forKey: "cardBorderGradientOpacity")
        }
        if defaults.object(forKey: "cardNeumorphicInset") != nil {
            knobs.visual.cardNeumorphicInset = defaults.bool(forKey: "cardNeumorphicInset")
        }
        if defaults.object(forKey: "cardPaddingH") != nil {
            knobs.visual.cardPaddingH = defaults.double(forKey: "cardPaddingH")
        }
        if defaults.object(forKey: "cardPaddingV") != nil {
            knobs.visual.cardPaddingV = defaults.double(forKey: "cardPaddingV")
        }
        if let v = defaults.string(forKey: "typography"),
           let parsed = TypographyFamily(rawValue: v) {
            knobs.visual.typography = parsed
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
        if let v = defaults.string(forKey: "backgroundTimeOfDayRule"),
           let parsed = TimeOfDayRule(rawValue: v) {
            knobs.background.timeOfDayRule = parsed
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
        if let v = defaults.string(forKey: "lottieLoopMode"),
           let parsed = AnimationLoopMode(rawValue: v) {
            knobs.iconography.lottieLoopMode = parsed
        }
        if let v = defaults.string(forKey: "lottieAnimationSet"),
           let parsed = LottieAnimationSet(rawValue: v) {
            knobs.iconography.lottieAnimationSet = parsed
        }
        if let v = defaults.string(forKey: "weatherIconStyle"),
           let parsed = WeatherIconStyle(rawValue: v) {
            knobs.iconography.weatherIconStyle = parsed
        }
        if let v = defaults.string(forKey: "symbolSet"),
           let parsed = SymbolVariant(rawValue: v) {
            knobs.iconography.symbolSet = parsed
        }
        if defaults.object(forKey: "iconSizeMultiplier") != nil {
            knobs.iconography.iconSizeMultiplier =
                defaults.double(forKey: "iconSizeMultiplier")
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
        if defaults.object(forKey: "hourlyHours") != nil {
            knobs.layout.hourlyHours = defaults.integer(forKey: "hourlyHours")
        }
        if let v = defaults.string(forKey: "cardDensity"),
           let parsed = CardDensity(rawValue: v) {
            knobs.layout.cardDensity = parsed
        }
        if defaults.object(forKey: "swipeBetweenLocations") != nil {
            knobs.layout.swipeBetweenLocations =
                defaults.bool(forKey: "swipeBetweenLocations")
        }
        if defaults.object(forKey: "showLocationHeader") != nil {
            knobs.layout.showLocationHeader =
                defaults.bool(forKey: "showLocationHeader")
        }
        if defaults.object(forKey: "showHeroLastUpdated") != nil {
            knobs.layout.showHeroLastUpdated =
                defaults.bool(forKey: "showHeroLastUpdated")
        }
        if defaults.object(forKey: "compactCardsInLandscape") != nil {
            knobs.layout.compactCardsInLandscape =
                defaults.bool(forKey: "compactCardsInLandscape")
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
        if let v = defaults.string(forKey: "preferredDataSource"),
           let parsed = PreferredDataSource(rawValue: v) {
            knobs.data.preferredDataSource = parsed
        }
        if let v = defaults.string(forKey: "refreshCadence"),
           let parsed = RefreshCadence(rawValue: v) {
            knobs.data.refreshCadence = parsed
        }
        if defaults.object(forKey: "backgroundRefreshEnabled") != nil {
            knobs.data.backgroundRefreshEnabled =
                defaults.bool(forKey: "backgroundRefreshEnabled")
        }
        if defaults.object(forKey: "temperaturePrecision") != nil {
            knobs.data.temperaturePrecision =
                defaults.integer(forKey: "temperaturePrecision")
        }
        if defaults.object(forKey: "windPrecision") != nil {
            knobs.data.windPrecision =
                defaults.integer(forKey: "windPrecision")
        }
        if defaults.object(forKey: "pressurePrecision") != nil {
            knobs.data.pressurePrecision =
                defaults.integer(forKey: "pressurePrecision")
        }
        if defaults.object(forKey: "showLocationLabel") != nil {
            knobs.data.showLocationLabel =
                defaults.bool(forKey: "showLocationLabel")
        }

        // Forecast
        if let v = defaults.string(forKey: "hourlyChartType"),
           let parsed = ChartType(rawValue: v) {
            knobs.forecast.hourlyChartType = parsed
        }
        if let v = defaults.string(forKey: "hourlyCardStyle"),
           let parsed = HourlyCardStyle(rawValue: v) {
            knobs.forecast.hourlyCardStyle = parsed
        }
        if let v = defaults.string(forKey: "dailyCardStyle"),
           let parsed = DailyCardStyle(rawValue: v) {
            knobs.forecast.dailyCardStyle = parsed
        }
        if defaults.object(forKey: "precipitationOverlay") != nil {
            knobs.forecast.precipitationOverlay =
                defaults.bool(forKey: "precipitationOverlay")
        }
        if defaults.object(forKey: "showSunArc") != nil {
            knobs.forecast.showSunArc = defaults.bool(forKey: "showSunArc")
        }
        if defaults.object(forKey: "showMoonPhase") != nil {
            knobs.forecast.showMoonPhase =
                defaults.bool(forKey: "showMoonPhase")
        }
        if defaults.object(forKey: "showHourlySummary") != nil {
            knobs.forecast.showHourlySummary =
                defaults.bool(forKey: "showHourlySummary")
        }
        if defaults.object(forKey: "chartAxes") != nil {
            knobs.forecast.chartAxes = defaults.bool(forKey: "chartAxes")
        }
        if defaults.object(forKey: "detailedColumnCount") != nil {
            knobs.forecast.detailedColumnCount =
                defaults.integer(forKey: "detailedColumnCount")
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
        if let v = defaults.string(forKey: "hapticIntensity"),
           let parsed = HapticIntensity(rawValue: v) {
            knobs.behaviour.hapticIntensity = parsed
        }
        if defaults.object(forKey: "pullToRefresh") != nil {
            knobs.behaviour.pullToRefresh =
                defaults.bool(forKey: "pullToRefresh")
        }
        if defaults.object(forKey: "tapDayToExpand") != nil {
            knobs.behaviour.tapDayToExpand =
                defaults.bool(forKey: "tapDayToExpand")
        }
        if defaults.object(forKey: "longPressToCustomise") != nil {
            knobs.behaviour.longPressToCustomise =
                defaults.bool(forKey: "longPressToCustomise")
        }
        if defaults.object(forKey: "confirmDestructive") != nil {
            knobs.behaviour.confirmDestructive =
                defaults.bool(forKey: "confirmDestructive")
        }
        if defaults.object(forKey: "weatherAlertSounds") != nil {
            knobs.behaviour.weatherAlertSounds =
                defaults.bool(forKey: "weatherAlertSounds")
        }
        if defaults.object(forKey: "quietHoursStart") != nil {
            knobs.behaviour.quietHoursStart =
                defaults.integer(forKey: "quietHoursStart")
        }
        if defaults.object(forKey: "quietHoursEnd") != nil {
            knobs.behaviour.quietHoursEnd =
                defaults.integer(forKey: "quietHoursEnd")
        }
        if defaults.object(forKey: "refreshSound") != nil {
            knobs.behaviour.refreshSound = defaults.bool(forKey: "refreshSound")
        }
        if defaults.object(forKey: "vibrateOnPullToRefresh") != nil {
            knobs.behaviour.vibrateOnPullToRefresh =
                defaults.bool(forKey: "vibrateOnPullToRefresh")
        }
        if defaults.object(forKey: "confirmQuit") != nil {
            knobs.behaviour.confirmQuit = defaults.bool(forKey: "confirmQuit")
        }

        // Accessibility
        if defaults.object(forKey: "reduceMotion") != nil {
            knobs.accessibility.reduceMotion = defaults.bool(forKey: "reduceMotion")
        }
        if defaults.object(forKey: "enhancedVoiceOverLabels") != nil {
            knobs.accessibility.enhancedVoiceOverLabels =
                defaults.bool(forKey: "enhancedVoiceOverLabels")
        }
        if defaults.object(forKey: "reduceMotionForce") != nil {
            knobs.accessibility.reduceMotionForce =
                defaults.bool(forKey: "reduceMotionForce")
        }
        if defaults.object(forKey: "highContrastOutline") != nil {
            knobs.accessibility.highContrastOutline =
                defaults.bool(forKey: "highContrastOutline")
        }
        if defaults.object(forKey: "hapticOnSelection") != nil {
            knobs.accessibility.hapticOnSelection =
                defaults.bool(forKey: "hapticOnSelection")
        }
        if defaults.object(forKey: "tapticOnRefresh") != nil {
            knobs.accessibility.tapticOnRefresh =
                defaults.bool(forKey: "tapticOnRefresh")
        }

        // Power user
        if let v = defaults.string(forKey: "widgetRefreshPolicy"),
           let parsed = WidgetRefreshPolicy(rawValue: v) {
            knobs.powerUser.widgetRefreshPolicy = parsed
        }
        if defaults.object(forKey: "shareThemeOnExport") != nil {
            knobs.powerUser.shareThemeOnExport =
                defaults.bool(forKey: "shareThemeOnExport")
        }
        if defaults.object(forKey: "debugOverlay") != nil {
            knobs.powerUser.debugOverlay = defaults.bool(forKey: "debugOverlay")
        }
        if defaults.object(forKey: "experimentalNewHeroLayout") != nil {
            knobs.powerUser.experimentalNewHeroLayout =
                defaults.bool(forKey: "experimentalNewHeroLayout")
        }
        if defaults.object(forKey: "experimentalSwipeRefresh") != nil {
            knobs.powerUser.experimentalSwipeRefresh =
                defaults.bool(forKey: "experimentalSwipeRefresh")
        }

        return knobs
    }

    // MARK: - Key registry

    /// Every UserDefaults key the bridge writes or reads. Useful
    /// for tests and for future debug tooling that needs to wipe
    /// all customisation state.
    static let allBridgedKeys: [String] = [
        // Visual
        "accentColor", "colorScheme", "useSystemTextSize",
        "customTextSizeMultiplier", "boldText", "increaseContrast",
        "cardStyle", "cornerRadius", "cardOpacity", "cardFillColor",
        "cardBorderColor", "cardBorderWidth", "cardTint",
        "cardShadowOpacity", "cardShadowRadius", "cardShadowX",
        "cardShadowY", "cardBlurIntensity", "cardGlassOpacity",
        "cardHighlightIntensity",
        "cardTintOverlay", "cardTintOverlayOpacity",
        "cardBorderGradientStart", "cardBorderGradientEnd",
        "cardBorderGradientOpacity",
        "cardNeumorphicInset",
        "cardPaddingH", "cardPaddingV",
        "typography",
        // Background
        "useCustomBackground", "userCustomBackground", "overlayOpacity",
        "backgroundMode", "backgroundTimeOfDayRule",
        // Iconography
        "disableWeatherAnimations", "lottiePlaybackSpeed",
        "lottieLoopMode", "lottieAnimationSet",
        "weatherIconStyle", "symbolSet", "iconSizeMultiplier",
        // Layout
        "forecastDays", "displayMode", "showHamburgerMenu",
        "hourlyHours", "cardDensity", "swipeBetweenLocations",
        "showLocationHeader", "showHeroLastUpdated", "compactCardsInLandscape",
        // Data
        "unitSystem", "useOpenMeteoAsDefault", "disableAPIKeys",
        "preferredDataSource", "refreshCadence",
        "backgroundRefreshEnabled", "temperaturePrecision",
        "windPrecision", "pressurePrecision", "showLocationLabel",
        // Forecast
        "hourlyChartType", "hourlyCardStyle", "dailyCardStyle",
        "precipitationOverlay", "showSunArc", "showMoonPhase",
        "showHourlySummary", "chartAxes", "detailedColumnCount",
        // Behaviour
        "enableHapticFeedback", "speakWeatherAlerts",
        "hapticIntensity", "pullToRefresh", "tapDayToExpand",
        "longPressToCustomise", "confirmDestructive",
        "weatherAlertSounds", "quietHoursStart", "quietHoursEnd",
        "refreshSound", "vibrateOnPullToRefresh", "confirmQuit",
        // Accessibility
        "reduceMotion", "enhancedVoiceOverLabels",
        "reduceMotionForce", "highContrastOutline",
        "hapticOnSelection", "tapticOnRefresh",
        // Power user
        "widgetRefreshPolicy", "shareThemeOnExport",
        "debugOverlay", "experimentalNewHeroLayout",
        "experimentalSwipeRefresh",
    ]
}
