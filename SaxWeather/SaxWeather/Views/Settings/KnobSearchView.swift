//
//  KnobSearchView.swift
//  SaxWeather
//
//  "Infinitely customisable" — Settings UI surface (Phase 7+).
//
//  A search-driven Settings view that surfaces every knob the
//  registry knows about. Typing a query filters the catalogue
//  (case-insensitive, matched against each knob's `searchTokens`).
//
//  Every row is **tappable**: tapping opens `KnobEditorSheet`,
//  which renders the right editor for the knob's type — Toggle
//  for Bool, Slider for Double, Stepper for Int, Picker for Enum,
//  TextField for freeform String. The editor sheet also exposes
//  a "Reset to default" action for the knob.
//
//  See `plans/INFINITE_CUSTOMISATION_PLAN.md` §3.3.
//

import SwiftUI

struct KnobSearchView: View {
    @EnvironmentObject private var customisation: CustomisationRegistry
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    /// Knob currently being edited. Setting this presents the
    /// editor sheet. `nil` = no sheet.
    @State private var editing: KnobDescriptor?

    var body: some View {
        NavigationStack {
            Group {
                if filteredKnobs.isEmpty {
                    emptyState
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search every setting…")
            #else
            .searchable(text: $query, placement: .toolbar, prompt: "Search every setting…")
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editing) { descriptor in
                KnobEditorSheet(descriptor: descriptor)
                    .environmentObject(customisation)
            }
        }
    }

    // MARK: - Filtering

    private var filteredKnobs: [KnobDescriptor] {
        customisation.searchKnobs(query)
    }

    private var groupedResults: [(KnobGroup, [KnobDescriptor])] {
        let grouped = Dictionary(grouping: filteredKnobs, by: \.group)
        return KnobGroup.allCases
            .compactMap { group -> (KnobGroup, [KnobDescriptor])? in
                guard let knobs = grouped[group], !knobs.isEmpty else { return nil }
                return (group, knobs.sorted { $0.displayName < $1.displayName })
            }
            .sorted { $0.0.sortOrder < $1.0.sortOrder }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(query.isEmpty ? "Type to search" : "No matches for '\(query)'")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        List {
            ForEach(groupedResults, id: \.0) { group, knobs in
                Section {
                    ForEach(knobs) { knob in
                        Button {
                            editing = knob
                        } label: {
                            KnobRow(descriptor: knob)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(group.rawValue)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Row

private struct KnobRow: View {
    let descriptor: KnobDescriptor
    @EnvironmentObject private var customisation: CustomisationRegistry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: descriptor.symbolName)
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(descriptor.displayName)
                    .font(.body)
                Text(descriptor.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(currentValueLabel)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    /// Best-effort human-readable current value for the knob.
    /// Delegates to the shared `SearchKnobValueFormatter` so the
    /// Search results inside the in-Settings `.searchable` bar
    /// and the standalone `KnobSearchView` always agree. Falls
    /// back to "—" when the descriptor doesn't map to a known
    /// registry keypath (which happens for nested widget sub-specs
    /// like `widgetStyle.small`).
    private var currentValueLabel: String {
        SearchKnobValueFormatter.label(for: descriptor.id, in: customisation.profile)
    }
}

// MARK: - Editor sheet

/// Per-knob value editor. Dispatches on `descriptor.id` to the
/// right SwiftUI primitive for the knob's value type. The set of
/// cases is exhaustive for everything currently in
/// `KnobDescriptor.catalogue`; unrecognised IDs fall through to a
/// "not yet editable inline" placeholder so the sheet never crashes.
struct KnobEditorSheet: View {
    let descriptor: KnobDescriptor
    @EnvironmentObject private var customisation: CustomisationRegistry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(descriptor.displayName)
                                .font(.headline)
                            Text(descriptor.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: descriptor.symbolName)
                            .foregroundStyle(.tint)
                    }
                }

                Section("Value") {
                    editor
                }

                Section {
                    Button(role: .destructive) {
                        resetToDefault()
                    } label: {
                        Label("Reset to Default", systemImage: "arrow.uturn.backward")
                    }
                }
            }
            .navigationTitle(descriptor.displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
    }

    // MARK: - Editor dispatch

    @ViewBuilder
    private var editor: some View {
        switch descriptor.id {
        // MARK: Booleans — Visual
        case "boldText":
            bool(\.visual.boldText)
        case "useSystemTextSize":
            bool(\.visual.useSystemTextSize)
        case "increaseContrast":
            bool(\.visual.increaseContrast)

        // MARK: Booleans — Background
        case "backgroundUseCustom":
            bool(\.background.useCustom)

        // MARK: Booleans — Iconography
        case "disableWeatherAnimations":
            bool(\.iconography.disableWeatherAnimations)

        // MARK: Booleans — Layout
        case "showHamburgerMenu":
            bool(\.layout.showHamburgerMenu)
        case "swipeBetweenLocations":
            bool(\.layout.swipeBetweenLocations)
        case "showLocationHeader":
            bool(\.layout.showLocationHeader)
        case "compactCardsInLandscape":
            bool(\.layout.compactCardsInLandscape)

        // MARK: Booleans — Forecast
        case "precipitationOverlay":
            bool(\.forecast.precipitationOverlay)
        case "showSunArc":
            bool(\.forecast.showSunArc)
        case "showMoonPhase":
            bool(\.forecast.showMoonPhase)
        case "chartAxes":
            bool(\.forecast.chartAxes)
        case "showHourlySummary":
            bool(\.forecast.showHourlySummary)

        // MARK: Booleans — Data
        case "useOpenMeteoAsDefault":
            bool(\.data.useOpenMeteoAsDefault)
        case "disableAPIKeys":
            bool(\.data.disableAPIKeys)
        case "backgroundRefreshEnabled":
            bool(\.data.backgroundRefreshEnabled)
        case "showLocationLabel":
            bool(\.data.showLocationLabel)

        // MARK: Booleans — Behaviour
        case "enableHapticFeedback":
            bool(\.behaviour.enableHapticFeedback)
        case "pullToRefresh":
            bool(\.behaviour.pullToRefresh)
        case "tapDayToExpand":
            bool(\.behaviour.tapDayToExpand)
        case "longPressToCustomise":
            bool(\.behaviour.longPressToCustomise)
        case "confirmDestructive":
            bool(\.behaviour.confirmDestructive)
        case "weatherAlertSounds":
            bool(\.behaviour.weatherAlertSounds)
        case "speakWeatherAlerts":
            bool(\.behaviour.speakWeatherAlerts)
        case "refreshSound":
            bool(\.behaviour.refreshSound)
        case "vibrateOnPullToRefresh":
            bool(\.behaviour.vibrateOnPullToRefresh)
        case "confirmQuit":
            bool(\.behaviour.confirmQuit)

        // MARK: Booleans — Accessibility
        case "reduceMotion":
            bool(\.accessibility.reduceMotion)
        case "reduceMotionForce":
            bool(\.accessibility.reduceMotionForce)
        case "enhancedVoiceOverLabels":
            bool(\.accessibility.enhancedVoiceOverLabels)
        case "highContrastOutline":
            bool(\.accessibility.highContrastOutline)
        case "hapticOnSelection":
            bool(\.accessibility.hapticOnSelection)
        case "tapticOnRefresh":
            bool(\.accessibility.tapticOnRefresh)

        // MARK: Booleans — Power User
        case "shareThemeOnExport":
            bool(\.powerUser.shareThemeOnExport)
        case "debugOverlay":
            bool(\.powerUser.debugOverlay)
        case "experimentalNewHeroLayout":
            bool(\.powerUser.experimentalNewHeroLayout)
        case "experimentalSwipeRefresh":
            bool(\.powerUser.experimentalSwipeRefresh)

        // MARK: Doubles
        case "fontScale":
            slider(\.visual.fontScale, in: 0.75...1.5, step: 0.05,
                   format: "%.2f×")
        case "cardOpacity":
            slider(\.visual.cardOpacity, in: 0.4...1.0, step: 0.05,
                   format: "%.2f")
        case "cornerRadius":
            slider(\.visual.cornerRadius, in: 0...28, step: 1,
                   format: "%.0f pt")
        case "lottiePlaybackSpeed":
            slider(\.iconography.lottiePlaybackSpeed, in: 0.25...2.0, step: 0.05,
                   format: "%.2f×")
        case "backgroundOverlayOpacity":
            slider(\.background.overlayOpacity, in: 0...0.7, step: 0.05,
                   format: "%.2f")
        case "iconSizeMultiplier":
            slider(\.iconography.iconSizeMultiplier, in: 0.7...1.6, step: 0.05,
                   format: "%.2f×")

        // MARK: Integers
        case "forecastDays":
            intStepper(\.layout.forecastDays, in: 3...14, step: 1,
                       suffix: " days")
        case "hourlyHours":
            intStepper(\.layout.hourlyHours, in: 12...48, step: 12,
                       suffix: " h")
        case "temperaturePrecision":
            intStepper(\.data.temperaturePrecision, in: 0...2, step: 1,
                       suffix: " dp")
        case "windPrecision":
            intStepper(\.data.windPrecision, in: 0...1, step: 1,
                       suffix: " dp")
        case "pressurePrecision":
            intStepper(\.data.pressurePrecision, in: 0...2, step: 1,
                       suffix: " dp")
        case "detailedColumnCount":
            intStepper(\.forecast.detailedColumnCount, in: 1...3, step: 1,
                       suffix: " columns")

        // MARK: String-typed enums via Picker
        case "colorScheme":
            stringPicker(\.visual.colorScheme, options: ["system", "light", "dark"])
        case "unitSystem":
            stringPicker(\.data.unitSystem, options: ["Metric", "Imperial", "UK"])
        case "displayMode":
            stringPicker(\.layout.displayMode, options: ["Summary", "Detailed"])

        // MARK: Typed enums
        case "cardStyle":
            enumPicker(\.visual.cardStyle, type: CardStyle.self)
        case "typography":
            enumPicker(\.visual.typography, type: TypographyFamily.self)
        case "backgroundMode":
            enumPicker(\.background.mode, type: BackgroundMode.self)
        case "backgroundTimeOfDayRule":
            enumPicker(\.background.timeOfDayRule, type: TimeOfDayRule.self)
        case "cardDensity":
            enumPicker(\.layout.cardDensity, type: CardDensity.self)
        case "lottieAnimationSet":
            enumPicker(\.iconography.lottieAnimationSet, type: LottieAnimationSet.self)
        case "lottieLoopMode":
            enumPicker(\.iconography.lottieLoopMode, type: AnimationLoopMode.self)
        case "weatherIconStyle":
            enumPicker(\.iconography.weatherIconStyle, type: WeatherIconStyle.self)
        case "symbolSet":
            enumPicker(\.iconography.symbolSet, type: SymbolVariant.self)
        case "hourlyChartType":
            enumPicker(\.forecast.hourlyChartType, type: ChartType.self)
        case "hourlyCardStyle":
            enumPicker(\.forecast.hourlyCardStyle, type: HourlyCardStyle.self)
        case "dailyCardStyle":
            enumPicker(\.forecast.dailyCardStyle, type: DailyCardStyle.self)
        case "preferredDataSource":
            enumPicker(\.data.preferredDataSource, type: PreferredDataSource.self)
        case "refreshCadence":
            enumPicker(\.data.refreshCadence, type: RefreshCadence.self)
        case "hapticIntensity":
            enumPicker(\.behaviour.hapticIntensity, type: HapticIntensity.self)
        case "terminologySet":
            enumPicker(\.content.terminologySet, type: TerminologySet.self)
        case "widgetRefreshPolicy":
            enumPicker(\.powerUser.widgetRefreshPolicy, type: WidgetRefreshPolicy.self)

        // MARK: Sub-spec knobs (read-only summary)
        case "widgetStyle.small",
             "widgetStyle.medium",
             "widgetStyle.large",
             "widgetBackground",
             "widgetTapAction",
             "widgetAccentSource":
            notEditableInline("Edit widget variants from the Widget section in Settings.")

        // MARK: Complex / collection knobs (read-only summary)
        case "palette",
             "backgroundDynamicTint",
             "backgroundPerCondition",
             "backgroundGradient",
             "lottieOverrideMap",
             "homeSectionOrder",
             "hiddenHomeSections",
             "visibleMetrics",
             "hourlyMetrics",
             "extendedCardsEnabled",
             "locationNicknames",
             "customLabels",
             "experimentalFlags",
             "language",
             "shortcutName",
             "quietHours",
             "accentColor":
            notEditableInline(
                "This setting is best edited from its dedicated section. Tap Back and use the matching tab.")

        default:
            notEditableInline("No inline editor yet for this knob.")
        }
    }

    // MARK: - Editor helpers

    /// Generic boolean toggle bound to a writable key path on
    /// `KnobStorage`. Reading goes through `customisation.profile.knobs`
    /// (so we always see the current persisted value); writing
    /// routes through `customisation.set(_:_:)` so the bridge to
    /// UserDefaults and the widget reload fire as usual.
    @ViewBuilder
    private func bool(_ keyPath: WritableKeyPath<KnobStorage, Bool>) -> some View {
        let binding = Binding<Bool>(
            get: { customisation.profile.knobs[keyPath: keyPath] },
            set: { customisation.set(keyPath, $0) }
        )
        Toggle(isOn: binding) {
            Text("Enabled")
        }
    }

    @ViewBuilder
    private func slider(
        _ keyPath: WritableKeyPath<KnobStorage, Double>,
        in range: ClosedRange<Double>,
        step: Double,
        format: String
    ) -> some View {
        let binding = Binding<Double>(
            get: { customisation.profile.knobs[keyPath: keyPath] },
            set: { customisation.set(keyPath, $0) }
        )
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current")
                Spacer()
                Text(String(format: format, binding.wrappedValue))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: binding, in: range, step: step)
        }
    }

    @ViewBuilder
    private func intStepper(
        _ keyPath: WritableKeyPath<KnobStorage, Int>,
        in range: ClosedRange<Int>,
        step: Int,
        suffix: String
    ) -> some View {
        let binding = Binding<Int>(
            get: { customisation.profile.knobs[keyPath: keyPath] },
            set: { customisation.set(keyPath, $0) }
        )
        Stepper(value: binding, in: range, step: step) {
            HStack {
                Text("Current")
                Spacer()
                Text("\(binding.wrappedValue)\(suffix)")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func stringPicker(
        _ keyPath: WritableKeyPath<KnobStorage, String>,
        options: [String]
    ) -> some View {
        let binding = Binding<String>(
            get: { customisation.profile.knobs[keyPath: keyPath] },
            set: { customisation.set(keyPath, $0) }
        )
        Picker("Value", selection: binding) {
            ForEach(options, id: \.self) { option in
                Text(option).tag(option)
            }
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private func enumPicker<T: RawRepresentable & Hashable & CaseIterable>(
        _ keyPath: WritableKeyPath<KnobStorage, T>,
        type: T.Type
    ) -> some View where T.RawValue == String {
        let binding = Binding<T>(
            get: { customisation.profile.knobs[keyPath: keyPath] },
            set: { customisation.set(keyPath, $0) }
        )
        // `T.allCases` is `T.AllCases: Collection`; SwiftUI's
        // `ForEach(_:id:content:)` wants `RandomAccessCollection`.
        // Coercing to `Array<T>` gives us that for free.
        Picker("Value", selection: binding) {
            ForEach(Array(T.allCases), id: \.self) { value in
                Text(value.rawValue.capitalized).tag(value)
            }
        }
        .pickerStyle(.menu)
    }

    /// Placeholder shown for knobs we don't have an inline editor
    /// for yet (composite values, sub-spec fields, freeform text).
    /// Keeps the sheet from looking broken — the user always gets a
    /// next-step message instead of a crash.
    private func notEditableInline(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Reset

    /// Reset this single knob to its default. Builds a fresh
    /// `KnobStorage()` (whose defaults match the app's shipped
    /// behaviour) and copies the knob's value at the matching
    /// key path into the active profile.
    private func resetToDefault() {
        let defaults = KnobStorage()
        // Walk the same dispatch table the editor used, applying
        // the default value at the matching key path.
        switch descriptor.id {
        // Visual
        case "accentColor":         customisation.set(\.visual.accentColor, defaults.visual.accentColor)
        case "palette":             customisation.set(\.visual.palette, defaults.visual.palette)
        case "cardStyle":           customisation.set(\.visual.cardStyle, defaults.visual.cardStyle)
        case "cornerRadius":        customisation.set(\.visual.cornerRadius, defaults.visual.cornerRadius)
        case "fontScale":           customisation.set(\.visual.fontScale, defaults.visual.fontScale)
        case "boldText":            customisation.set(\.visual.boldText, defaults.visual.boldText)
        case "useSystemTextSize":   customisation.set(\.visual.useSystemTextSize, defaults.visual.useSystemTextSize)
        case "typography":          customisation.set(\.visual.typography, defaults.visual.typography)
        case "increaseContrast":    customisation.set(\.visual.increaseContrast, defaults.visual.increaseContrast)
        case "colorScheme":         customisation.set(\.visual.colorScheme, defaults.visual.colorScheme)
        case "cardOpacity":         customisation.set(\.visual.cardOpacity, defaults.visual.cardOpacity)
        // Background
        case "backgroundMode":      customisation.set(\.background.mode, defaults.background.mode)
        case "backgroundUseCustom": customisation.set(\.background.useCustom, defaults.background.useCustom)
        case "backgroundOverlayOpacity":
            customisation.set(\.background.overlayOpacity, defaults.background.overlayOpacity)
        case "backgroundTimeOfDayRule":
            customisation.set(\.background.timeOfDayRule, defaults.background.timeOfDayRule)
        case "backgroundDynamicTint":
            customisation.set(\.background.dynamicTint, defaults.background.dynamicTint)
        case "backgroundPerCondition":
            customisation.set(\.background.perCondition, defaults.background.perCondition)
        case "backgroundGradient":
            customisation.set(\.background.gradient, defaults.background.gradient)
        // Iconography
        case "lottieAnimationSet":
            customisation.set(\.iconography.lottieAnimationSet, defaults.iconography.lottieAnimationSet)
        case "lottieOverrideMap":
            customisation.set(\.iconography.lottieOverrideMap, defaults.iconography.lottieOverrideMap)
        case "lottiePlaybackSpeed":
            customisation.set(\.iconography.lottiePlaybackSpeed, defaults.iconography.lottiePlaybackSpeed)
        case "lottieLoopMode":
            customisation.set(\.iconography.lottieLoopMode, defaults.iconography.lottieLoopMode)
        case "disableWeatherAnimations":
            customisation.set(\.iconography.disableWeatherAnimations, defaults.iconography.disableWeatherAnimations)
        case "weatherIconStyle":
            customisation.set(\.iconography.weatherIconStyle, defaults.iconography.weatherIconStyle)
        case "symbolSet":
            customisation.set(\.iconography.symbolSet, defaults.iconography.symbolSet)
        case "iconSizeMultiplier":
            customisation.set(\.iconography.iconSizeMultiplier, defaults.iconography.iconSizeMultiplier)
        // Layout
        case "displayMode":         customisation.set(\.layout.displayMode, defaults.layout.displayMode)
        case "forecastDays":        customisation.set(\.layout.forecastDays, defaults.layout.forecastDays)
        case "hourlyHours":         customisation.set(\.layout.hourlyHours, defaults.layout.hourlyHours)
        case "cardDensity":         customisation.set(\.layout.cardDensity, defaults.layout.cardDensity)
        case "homeSectionOrder":    customisation.set(\.layout.homeSectionOrder, defaults.layout.homeSectionOrder)
        case "hiddenHomeSections":  customisation.set(\.layout.hiddenHomeSections, defaults.layout.hiddenHomeSections)
        case "showHamburgerMenu":   customisation.set(\.layout.showHamburgerMenu, defaults.layout.showHamburgerMenu)
        case "swipeBetweenLocations":
            customisation.set(\.layout.swipeBetweenLocations, defaults.layout.swipeBetweenLocations)
        case "showLocationHeader":
            customisation.set(\.layout.showLocationHeader, defaults.layout.showLocationHeader)
        case "compactCardsInLandscape":
            customisation.set(\.layout.compactCardsInLandscape, defaults.layout.compactCardsInLandscape)
        // Forecast
        case "hourlyChartType":     customisation.set(\.forecast.hourlyChartType, defaults.forecast.hourlyChartType)
        case "hourlyCardStyle":     customisation.set(\.forecast.hourlyCardStyle, defaults.forecast.hourlyCardStyle)
        case "dailyCardStyle":      customisation.set(\.forecast.dailyCardStyle, defaults.forecast.dailyCardStyle)
        case "precipitationOverlay":
            customisation.set(\.forecast.precipitationOverlay, defaults.forecast.precipitationOverlay)
        case "showSunArc":          customisation.set(\.forecast.showSunArc, defaults.forecast.showSunArc)
        case "showMoonPhase":       customisation.set(\.forecast.showMoonPhase, defaults.forecast.showMoonPhase)
        case "chartAxes":           customisation.set(\.forecast.chartAxes, defaults.forecast.chartAxes)
        case "showHourlySummary":   customisation.set(\.forecast.showHourlySummary, defaults.forecast.showHourlySummary)
        case "detailedColumnCount":
            customisation.set(\.forecast.detailedColumnCount, defaults.forecast.detailedColumnCount)
        // Data
        case "unitSystem":          customisation.set(\.data.unitSystem, defaults.data.unitSystem)
        case "temperaturePrecision":
            customisation.set(\.data.temperaturePrecision, defaults.data.temperaturePrecision)
        case "windPrecision":       customisation.set(\.data.windPrecision, defaults.data.windPrecision)
        case "pressurePrecision":   customisation.set(\.data.pressurePrecision, defaults.data.pressurePrecision)
        case "preferredDataSource":
            customisation.set(\.data.preferredDataSource, defaults.data.preferredDataSource)
        case "useOpenMeteoAsDefault":
            customisation.set(\.data.useOpenMeteoAsDefault, defaults.data.useOpenMeteoAsDefault)
        case "disableAPIKeys":      customisation.set(\.data.disableAPIKeys, defaults.data.disableAPIKeys)
        case "refreshCadence":      customisation.set(\.data.refreshCadence, defaults.data.refreshCadence)
        case "backgroundRefreshEnabled":
            customisation.set(\.data.backgroundRefreshEnabled, defaults.data.backgroundRefreshEnabled)
        case "visibleMetrics":      customisation.set(\.data.visibleMetrics, defaults.data.visibleMetrics)
        case "hourlyMetrics":       customisation.set(\.data.hourlyMetrics, defaults.data.hourlyMetrics)
        case "extendedCardsEnabled":
            customisation.set(\.data.extendedCardsEnabled, defaults.data.extendedCardsEnabled)
        case "showLocationLabel":   customisation.set(\.data.showLocationLabel, defaults.data.showLocationLabel)
        // Behaviour
        case "enableHapticFeedback":
            customisation.set(\.behaviour.enableHapticFeedback, defaults.behaviour.enableHapticFeedback)
        case "hapticIntensity":     customisation.set(\.behaviour.hapticIntensity, defaults.behaviour.hapticIntensity)
        case "pullToRefresh":       customisation.set(\.behaviour.pullToRefresh, defaults.behaviour.pullToRefresh)
        case "tapDayToExpand":      customisation.set(\.behaviour.tapDayToExpand, defaults.behaviour.tapDayToExpand)
        case "longPressToCustomise":
            customisation.set(\.behaviour.longPressToCustomise, defaults.behaviour.longPressToCustomise)
        case "confirmDestructive":  customisation.set(\.behaviour.confirmDestructive, defaults.behaviour.confirmDestructive)
        case "weatherAlertSounds":  customisation.set(\.behaviour.weatherAlertSounds, defaults.behaviour.weatherAlertSounds)
        case "speakWeatherAlerts":  customisation.set(\.behaviour.speakWeatherAlerts, defaults.behaviour.speakWeatherAlerts)
        case "quietHoursStart":     customisation.set(\.behaviour.quietHoursStart, defaults.behaviour.quietHoursStart)
        case "quietHoursEnd":       customisation.set(\.behaviour.quietHoursEnd, defaults.behaviour.quietHoursEnd)
        case "refreshSound":        customisation.set(\.behaviour.refreshSound, defaults.behaviour.refreshSound)
        case "vibrateOnPullToRefresh":
            customisation.set(\.behaviour.vibrateOnPullToRefresh, defaults.behaviour.vibrateOnPullToRefresh)
        case "confirmQuit":         customisation.set(\.behaviour.confirmQuit, defaults.behaviour.confirmQuit)
        // Accessibility
        case "reduceMotion":        customisation.set(\.accessibility.reduceMotion, defaults.accessibility.reduceMotion)
        case "reduceMotionForce":
            customisation.set(\.accessibility.reduceMotionForce, defaults.accessibility.reduceMotionForce)
        case "enhancedVoiceOverLabels":
            customisation.set(\.accessibility.enhancedVoiceOverLabels, defaults.accessibility.enhancedVoiceOverLabels)
        case "highContrastOutline":
            customisation.set(\.accessibility.highContrastOutline, defaults.accessibility.highContrastOutline)
        case "hapticOnSelection":   customisation.set(\.accessibility.hapticOnSelection, defaults.accessibility.hapticOnSelection)
        case "tapticOnRefresh":     customisation.set(\.accessibility.tapticOnRefresh, defaults.accessibility.tapticOnRefresh)
        // Content
        case "language":            customisation.set(\.content.language, defaults.content.language)
        case "terminologySet":      customisation.set(\.content.terminologySet, defaults.content.terminologySet)
        case "locationNicknames":
            customisation.set(\.content.locationNicknames, defaults.content.locationNicknames)
        case "customLabels":        customisation.set(\.content.customLabels, defaults.content.customLabels)
        // Power User
        case "experimentalFlags":   customisation.set(\.powerUser.experimentalFlags, defaults.powerUser.experimentalFlags)
        case "shortcutName":        customisation.set(\.powerUser.shortcutName, defaults.powerUser.shortcutName)
        case "widgetRefreshPolicy":
            customisation.set(\.powerUser.widgetRefreshPolicy, defaults.powerUser.widgetRefreshPolicy)
        case "shareThemeOnExport":  customisation.set(\.powerUser.shareThemeOnExport, defaults.powerUser.shareThemeOnExport)
        case "debugOverlay":        customisation.set(\.powerUser.debugOverlay, defaults.powerUser.debugOverlay)
        case "experimentalNewHeroLayout":
            customisation.set(\.powerUser.experimentalNewHeroLayout, defaults.powerUser.experimentalNewHeroLayout)
        case "experimentalSwipeRefresh":
            customisation.set(\.powerUser.experimentalSwipeRefresh, defaults.powerUser.experimentalSwipeRefresh)
        // Widget (single-key resets; sub-spec knobs not in scope here)
        case "widgetAccentSource":
            customisation.set(\.widget.accentFollowsApp, defaults.widget.accentFollowsApp)
        default:
            break
        }
    }
}

#Preview {
    KnobSearchView()
        .environmentObject(CustomisationRegistry.shared)
}
