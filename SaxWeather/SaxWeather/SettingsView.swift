//
//  SettingsView.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-26
//

import SwiftUI
import CoreLocation
import MapKit
#if os(iOS)
import UIKit
#endif

private func requestAddLocationPreview(name: String, latitude: Double, longitude: Double) {
    LocationPreviewNavigation.request(
        .addLocation(name: name, latitude: latitude, longitude: longitude)
    )
}

struct SettingsView: View {
    @ObservedObject var weatherService: WeatherService
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject private var customisationRegistry: CustomisationRegistry
    @EnvironmentObject private var locationsManager: SavedLocationsManager
    @AppStorage("wuApiKey") private var wuApiKey = ""
    @AppStorage("stationID") private var stationID = ""
    @AppStorage("owmApiKey") private var owmApiKey = ""
    @AppStorage("latitude") private var latitude = ""
    @AppStorage("longitude") private var longitude = ""
    @AppStorage("unitSystem") private var unitSystem = "Metric"
    @AppStorage("colorScheme") private var colorScheme = "system"
    @AppStorage("forecastDays") private var forecastDays = 7
    @AppStorage("displayMode") private var displayMode = "Summary"
    @AppStorage("useOpenMeteoAsDefault") private var useOpenMeteoAsDefault = false
    @AppStorage("accentColor") private var accentColor = "blue" // New: accent color
    @AppStorage("disableAPIKeys") private var disableAPIKeys = false // New: disable API keys toggle
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.colorScheme) private var systemColorScheme
    @StateObject private var healthMonitor = APIKeyHealthMonitor.shared
    @State private var showingAddLocationSheet = false
    @State private var addLocationMode: AddLocationMode? = nil
    @State private var newLocationName = ""
    @State private var newLatitude = ""
    @State private var newLongitude = ""
    @State private var citySearchQuery = ""
    @State private var citySearchResults: [MKLocalSearchCompletion] = []
    @State private var selectedSearchCompletion: MKLocalSearchCompletion?
    @State private var isSearchingCity = false
    @State private var citySearchCompleter = MKLocalSearchCompleter()
    @State private var citySearchError: String? = nil
    @State private var citySearchCoordinate: CLLocationCoordinate2D? = nil
    @State private var citySearchCompleterDelegate: CitySearchCompleterDelegate? = nil
    @State private var showingTipJar = false
    @State private var showingCosmeticsStore = false
    @State private var mapSelectedLocation: CLLocationCoordinate2D? = nil
    @State private var mapSelectedLocationName: String? = nil
    // `confirmDestructive` — staged location waiting for
    // confirmation before being removed. Nil = no alert visible.
    @State private var pendingDeleteLocation: SavedLocation? = nil

    // For onboarding dismiss button
    var isOnboarding: Bool = false
    @Environment(\.dismiss) private var dismiss

    @State private var settingsSearchQuery: String = ""
    /// Sheet presented when a search result row opens a sheet
    /// (Theme switcher, Share Theme, Tip Jar).
    @State private var searchSheet: SettingsSheet?
    /// Navigation stack for search-result taps that push onto the
    /// settings list (Locations, Weather Data, etc.).
    @State private var searchNavigationPath = NavigationPath()

    #if os(iOS)
    @FocusState private var focusedField: Field?
    enum Field: Hashable {
        case wuApiKey, stationID, owmApiKey
    }
    #endif

    private let unitSystems = ["Metric", "Imperial", "UK"]
    private let colorSchemes = ["system", "light", "dark"]
    private let forecastDayOptions = [3, 5, 7, 10, 14]
    private let displayModes = ["Summary", "Detailed"]
    
    var body: some View {
        #if os(macOS)
        GeometryReader { geometry in
            ScrollView {
                VStack {
                    Form {
                        GroupBox(label: Text("Saved Locations").font(.title3).fontWeight(.semibold)) {
                            savedLocationsSection
                                .padding()
                        }
                        GroupBox(label: Text("Weather Sources").font(.title3).fontWeight(.semibold)) {
                            weatherSourcesSection
                                .padding()
                        }
                        GroupBox(label: Text("Preferences").font(.title3).fontWeight(.semibold)) {
                            unitsAndDisplaySection
                                .padding()
                        }
                        GroupBox(label: Text("Appearance").font(.title3).fontWeight(.semibold)) {
                            BackgroundSettingsButton()
                                .environmentObject(storeManager)
                                .padding()
                        }
                        GroupBox(label: Text("Accessibility").font(.title3).fontWeight(.semibold)) {
                            NavigationLink(destination: AccessibilitySettingsView()) {
                                Label("Accessibility Settings", systemImage: "accessibility")
                            }
                            .padding()
                        }
                        GroupBox(label: Text("Support").font(.title3).fontWeight(.semibold)) {
                            Button {
                                showingTipJar = true
                            } label: {
                                HStack {
                                    Label("Support Development", systemImage: "heart.fill")
                                        .foregroundColor(.pink)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .padding()

                            Button {
                                showingCosmeticsStore = true
                            } label: {
                                HStack {
                                    Label("Cosmetics", systemImage: "paintbrush.pointed.fill")
                                        .foregroundColor(.accentColor)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .padding()
                        }
                        GroupBox(label: Text("Feedback").font(.title3).fontWeight(.semibold)) {
                            feedbackSection
                                .padding()
                        }
                        GroupBox(label: Text("About").font(.title3).fontWeight(.semibold)) {
                            aboutSection
                                .padding()
                        }
                    }
                    .frame(minWidth: 320, maxWidth: min(geometry.size.width * 0.95, 600))
                    .background(.regularMaterial)
                    .cornerRadius(16)
                    .font(.system(size: 14))
                    .padding(.vertical, 32)
                    .padding(.horizontal, max(24, (geometry.size.width - 600) / 2))
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .center)
            }
            .navigationTitle("Settings")
            .onChange(of: forecastDays) { newValue in
                Task { await weatherService.fetchForecasts() }
                customisationRegistry.set(\.layout.forecastDays, newValue)
            }
            .onChange(of: unitSystem) { newValue in
                weatherService.unitSystem = newValue
                customisationRegistry.set(\.data.unitSystem, newValue)
            }
            .onChange(of: colorScheme) { newValue in
                customisationRegistry.set(\.visual.colorScheme, newValue)
            }
            .onChange(of: displayMode) { newValue in
                customisationRegistry.set(\.layout.displayMode, newValue)
            }
            .onChange(of: useOpenMeteoAsDefault) { newValue in
                customisationRegistry.set(\.data.useOpenMeteoAsDefault, newValue)
            }
            .onChange(of: disableAPIKeys) { newValue in
                customisationRegistry.set(\.data.disableAPIKeys, newValue)
            }
            .onChange(of: accentColor) { newValue in
                customisationRegistry.set(\.visual.accentColor, ColourToken(rawString: newValue))
            }
            .sheet(isPresented: $showingTipJar) {
                TipJarView()
            }
            .sheet(isPresented: $showingCosmeticsStore) {
                CosmeticsStoreView()
            }
            .alert("Settings", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            // `confirmDestructive` Behaviour setting — confirm
            // before removing a saved location.
            .alert(
                "Delete location?",
                isPresented: Binding(
                    get: { pendingDeleteLocation != nil },
                    set: { if !$0 { pendingDeleteLocation = nil } }
                ),
                presenting: pendingDeleteLocation
            ) { location in
                Button("Delete", role: .destructive) {
                    locationsManager.removeLocation(location)
                    pendingDeleteLocation = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteLocation = nil
                }
            } message: { location in
                Text("\"\(location.name)\" will be removed from your saved locations. This cannot be undone.")
            }
        }
        #else
        NavigationStack(path: $searchNavigationPath) {
            Group {
                if settingsSearchQuery.isEmpty {
                    List {
                        settingsTree
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #endif
                } else {
                    SettingsSearchResults(
                        query: settingsSearchQuery,
                        sheet: $searchSheet,
                        navigationPath: $searchNavigationPath
                    )
                }
            }
            .navigationTitle("Settings")
            .sheet(item: $searchSheet) { sheet in
                searchSheetView(for: sheet)
            }
            .navigationDestination(for: SettingsSearchRoute.self) { route in
                searchDestinationView(for: route)
            }
            .onChange(of: settingsSearchQuery) { newValue in
                // Clearing the search drops the user back into the
                // full settings tree, so pop any pushed destinations
                // and dismiss any sheet to avoid stranded sheets.
                if newValue.isEmpty {
                    if !searchNavigationPath.isEmpty {
                        searchNavigationPath = NavigationPath()
                    }
                    searchSheet = nil
                }
            }
            .searchable(
                text: $settingsSearchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search settings"
            )
            // Hide the toolbar search field while in onboarding mode —
            // the onboarding flow has its own navigation chrome and
            // a search bar is noise there.
            .toolbar(settingsSearchQuery.isEmpty ? .visible : .visible, for: .navigationBar)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .onChange(of: forecastDays) { newValue in
                Task { await weatherService.fetchForecasts() }
                customisationRegistry.set(\.layout.forecastDays, newValue)
            }
            .onChange(of: unitSystem) { newValue in
                weatherService.unitSystem = newValue
                customisationRegistry.set(\.data.unitSystem, newValue)
            }
            .onChange(of: colorScheme) { newValue in
                customisationRegistry.set(\.visual.colorScheme, newValue)
            }
            .onChange(of: displayMode) { newValue in
                customisationRegistry.set(\.layout.displayMode, newValue)
            }
            .onChange(of: useOpenMeteoAsDefault) { newValue in
                customisationRegistry.set(\.data.useOpenMeteoAsDefault, newValue)
            }
            .onChange(of: disableAPIKeys) { newValue in
                customisationRegistry.set(\.data.disableAPIKeys, newValue)
            }
            .onChange(of: accentColor) { newValue in
                customisationRegistry.set(\.visual.accentColor, ColourToken(rawString: newValue))
            }
            .sheet(isPresented: $showingTipJar) {
                TipJarView()
            }
            .sheet(isPresented: $showingCosmeticsStore) {
                CosmeticsStoreView()
            }
            .sheet(isPresented: $showingAddLocationSheet) {
                addLocationSheet
            }
            .alert("Settings", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            // `confirmDestructive` — confirm before removing a
            // saved location. Mirrors the macOS-side alert.
            .alert(
                "Delete location?",
                isPresented: Binding(
                    get: { pendingDeleteLocation != nil },
                    set: { if !$0 { pendingDeleteLocation = nil } }
                ),
                presenting: pendingDeleteLocation
            ) { location in
                Button("Delete", role: .destructive) {
                    locationsManager.removeLocation(location)
                    pendingDeleteLocation = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteLocation = nil
                }
            } message: { location in
                Text("\"\(location.name)\" will be removed from your saved locations. This cannot be undone.")
            }
        }
        #endif
    }
    
    // MARK: - Settings search helpers (Phase 7)

    /// View presented when a search result row taps a sheet-
    /// style destination. Built lazily so the sheet body has
    /// access to the same `@AppStorage` / state as the main view.
    @ViewBuilder
    private func searchSheetView(for sheet: SettingsSheet) -> some View {
        switch sheet {
        case .profileImporter:
            ProfileImporterView()
        case .tipJar:
            TipJarView()
        case .searchAllSettings:
            KnobSearchView()
        }
    }

    /// View pushed onto the navigation stack when a search result
    /// row taps a NavigationLink-style destination.
    @ViewBuilder
    private func searchDestinationView(for route: SettingsSearchRoute) -> some View {
        switch route {
        case .locations:
            LocationsSettingsView(
                locationsManager: locationsManager,
                disableAPIKeys: $disableAPIKeys,
                weatherService: weatherService
            )
        case .weatherData:
            #if os(iOS)
            WeatherSourcesSettingsView(
                weatherService: weatherService,
                wuApiKey: $wuApiKey,
                stationID: $stationID,
                owmApiKey: $owmApiKey,
                useOpenMeteoAsDefault: $useOpenMeteoAsDefault,
                disableAPIKeys: $disableAPIKeys,
                locationsManager: locationsManager,
                focusedField: _focusedField,
                saveAPIKeys: saveAPIKeys,
                loadAPIKeys: loadAPIKeys
            )
            #else
            WeatherSourcesSettingsView(
                weatherService: weatherService,
                wuApiKey: $wuApiKey,
                stationID: $stationID,
                owmApiKey: $owmApiKey,
                useOpenMeteoAsDefault: $useOpenMeteoAsDefault,
                disableAPIKeys: $disableAPIKeys,
                locationsManager: locationsManager,
                saveAPIKeys: saveAPIKeys,
                loadAPIKeys: loadAPIKeys
            )
            #endif
        case .preferences:
            PreferencesSettingsView(
                unitSystem: $unitSystem,
                colorScheme: $colorScheme,
                forecastDays: $forecastDays,
                displayMode: $displayMode,
                useOpenMeteoAsDefault: $useOpenMeteoAsDefault,
                owmApiKey: $owmApiKey,
                weatherService: weatherService,
                unitSystems: unitSystems,
                colorSchemes: colorSchemes,
                forecastDayOptions: forecastDayOptions,
                displayModes: displayModes
            )
        case .appearance:
            AppearanceSettingsView()
        case .cardStyle:
            // The new live-preview Card Settings submenu. Reachable
            // via the search bar or the Appearance → Cards row.
            CardSettingsView()
        case .accessibility:
            // `wrappedInNavigationStack: false` — the view is being
            // pushed onto the Settings `NavigationStack` by
            // `.navigationDestination(for:)`, so it must NOT wrap
            // itself in another `NavigationStack`. A nested stack
            // here is what was causing the black flash on tap.
            AccessibilitySettingsView(wrappedInNavigationStack: false)
        case .behaviour:
            BehaviourSettingsView()
        case .backupAndRestore:
            SettingsBackupAndRestoreView()
        case .feedback(let category):
            FeedbackView(
                initialCategory: category,
                dataSource: weatherService.currentDataSource,
                unitSystem: unitSystem
            )
        case .about:
            AboutSettingsView()
        case .attribution:
            AttributionSettingsView(
                wuApiKey: wuApiKey,
                stationID: stationID,
                owmApiKey: owmApiKey,
                currentDataSource: weatherService.currentDataSource
            )
        }
    }

    // MARK: - Settings tree (Phase 7 — extracted for search)

    /// The full Settings list, shown when the search bar is empty.
    /// Extracted as a computed property so the search bar can swap
    /// it out for `SettingsSearchResults` when the user types.
    @ViewBuilder
    private var settingsTree: some View {
        // Network quality hint. Sits at the top of the
        // list so the user sees it before tweaking any
        // other setting. Reactive — updates as the user
        // toggles Low Data Mode or moves between WiFi
        // and cellular.
        NetworkQualityHint()

        // MARK: Weather
        // Everything to do with *what* weather is shown and where
        // it comes from: saved places, data providers, and the
        // units / forecast preferences that shape the numbers.
        Section {
            NavigationLink {
                LocationsSettingsView(
                    locationsManager: locationsManager,
                    disableAPIKeys: $disableAPIKeys,
                    weatherService: weatherService
                )
            } label: {
                settingsRow(
                    title: "Locations",
                    subtitle: "Saved places and current location",
                    systemImage: "location.fill",
                    tint: .blue
                )
            }

            NavigationLink {
                #if os(iOS)
                WeatherSourcesSettingsView(
                    weatherService: weatherService,
                    wuApiKey: $wuApiKey,
                    stationID: $stationID,
                    owmApiKey: $owmApiKey,
                    useOpenMeteoAsDefault: $useOpenMeteoAsDefault,
                    disableAPIKeys: $disableAPIKeys,
                    locationsManager: locationsManager,
                    focusedField: _focusedField,
                    saveAPIKeys: saveAPIKeys,
                    loadAPIKeys: loadAPIKeys
                )
                #else
                WeatherSourcesSettingsView(
                    weatherService: weatherService,
                    wuApiKey: $wuApiKey,
                    stationID: $stationID,
                    owmApiKey: $owmApiKey,
                    useOpenMeteoAsDefault: $useOpenMeteoAsDefault,
                    disableAPIKeys: $disableAPIKeys,
                    locationsManager: locationsManager,
                    saveAPIKeys: saveAPIKeys,
                    loadAPIKeys: loadAPIKeys
                )
                #endif
            } label: {
                settingsRow(
                    title: "Weather Data",
                    subtitle: "Data sources and API keys",
                    systemImage: "cloud.sun.fill",
                    tint: .cyan
                )
            }

            NavigationLink {
                PreferencesSettingsView(
                    unitSystem: $unitSystem,
                    colorScheme: $colorScheme,
                    forecastDays: $forecastDays,
                    displayMode: $displayMode,
                    useOpenMeteoAsDefault: $useOpenMeteoAsDefault,
                    owmApiKey: $owmApiKey,
                    weatherService: weatherService,
                    unitSystems: unitSystems,
                    colorSchemes: colorSchemes,
                    forecastDayOptions: forecastDayOptions,
                    displayModes: displayModes
                )
            } label: {
                settingsRow(
                    title: "Preferences",
                    subtitle: "Units, forecast length, and layout",
                    systemImage: "slider.horizontal.3",
                    tint: .indigo
                )
            }
        } header: {
            Text("Weather")
        } footer: {
            Text("Manage your saved places, choose data providers, and set the units and forecast options used across the app.")
        }

        // MARK: Personalisation
        // How the app looks and feels: theme, motion/haptics, and
        // accessibility accommodations.
        Section {
            NavigationLink {
                AppearanceSettingsView()
            } label: {
                settingsRow(
                    title: "Appearance",
                    subtitle: "Theme, colours, and backgrounds",
                    systemImage: "paintbrush.fill",
                    tint: .purple
                )
            }

            // v2 — Behaviour is the new home for haptics,
            // gestures, alert sounds, and experimental flags.
            NavigationLink {
                BehaviourSettingsView()
            } label: {
                settingsRow(
                    title: "Behaviour",
                    subtitle: "Haptics, gestures, and alert sounds",
                    systemImage: "hand.tap.fill",
                    tint: .orange
                )
            }

            NavigationLink {
                AccessibilitySettingsView()
            } label: {
                settingsRow(
                    title: "Accessibility",
                    subtitle: "Motion, contrast, and VoiceOver",
                    systemImage: "accessibility",
                    tint: .green
                )
            }

            #if os(iOS)
            // Language deep-links to the app's iOS Settings page, where
            // the system per-app language picker appears once the app
            // ships more than one localization. Keeps discovery easy
            // without a fragile in-app language override.
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                settingsRow(
                    title: "Language",
                    subtitle: "Choose the app's language in iOS Settings",
                    systemImage: "globe",
                    tint: .blue,
                    showsChevron: true
                )
            }
            .accessibilityLabel("Language")
            .accessibilityHint("Opens iOS Settings to change the app's language")
            #endif
        } header: {
            Text("Personalisation")
        } footer: {
            // Experimental settings disclaimer. Some knobs in the
            // registry (especially under Behaviour) are still being
            // iterated on and may produce unexpected results.
            Label {
                Text("Some behaviour settings are experimental and may have unintended consequences.")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        // MARK: Advanced
        // The full searchable catalogue of every registry knob for
        // power users who know exactly what they want.
        Section {
            Button {
                searchSheet = .searchAllSettings
            } label: {
                HStack {
                    settingsRow(
                        title: "Search All Settings",
                        subtitle: "Find and edit any option",
                        systemImage: "magnifyingglass",
                        tint: .gray
                    )
                    Spacer()
                    Text("\(customisationRegistry.profile.knobs.allEditableKnobCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Search All Settings")
            .accessibilityHint("Search every customisation knob the registry knows about")
        } header: {
            Text("Advanced")
        } footer: {
            Text("Browse and search every customisation option the app offers in one place.")
        }

        // MARK: Data
        Section {
            NavigationLink {
                SettingsBackupAndRestoreView()
            } label: {
                settingsRow(
                    title: "Backup & Restore",
                    subtitle: "Export, import, and iCloud sync",
                    systemImage: "arrow.triangle.2.circlepath.circle.fill",
                    tint: .teal
                )
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Back up your settings to a .saxtheme file, restore from one, or sync across your devices with iCloud.")
        }

        // MARK: Support
        Section {
            Button {
                showingTipJar = true
            } label: {
                settingsRow(
                    title: "Support Development",
                    subtitle: "Leave a tip for the developer",
                    systemImage: "heart.fill",
                    tint: .pink,
                    showsChevron: true
                )
            }
            .accessibilityLabel("Support Development")
            .accessibilityHint("Leave a tip to support the app")

            Button {
                showingCosmeticsStore = true
            } label: {
                settingsRow(
                    title: "Cosmetics",
                    subtitle: "Themes, palettes, and extras",
                    systemImage: "paintbrush.pointed.fill",
                    tint: .accentColor,
                    showsChevron: true
                )
            }
            .accessibilityLabel("Cosmetics")
            .accessibilityHint("Browse and purchase cosmetic items for the app")
        } header: {
            Text("Support")
        }

        // MARK: Feedback
        Section {
            feedbackSection
        } header: {
            Text("Feedback")
        } footer: {
            Text("Report a bug or suggest an improvement. Diagnostics are attached automatically — no API keys are included.")
        }

        // MARK: About
        Section {
            NavigationLink {
                AboutSettingsView()
            } label: {
                settingsRow(
                    title: "About",
                    subtitle: "Version and app information",
                    systemImage: "info.circle.fill",
                    tint: .blue
                )
            }

            NavigationLink {
                AttributionSettingsView(
                    wuApiKey: wuApiKey,
                    stationID: stationID,
                    owmApiKey: owmApiKey,
                    currentDataSource: weatherService.currentDataSource
                )
            } label: {
                settingsRow(
                    title: "Attribution",
                    subtitle: "Data providers and licences",
                    systemImage: "network",
                    tint: .secondary
                )
            }
        } header: {
            Text("About")
        }
    }

    /// A consistent settings row: a coloured, rounded icon tile
    /// followed by a title and a short explanatory subtitle. Keeps
    /// every top-level destination visually aligned and easier to
    /// scan than a bare `Label`.
    @ViewBuilder
    private func settingsRow(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        showsChevron: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tint)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if showsChevron {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    // Safe accessor for weather values using Mirror
    private func getWeatherValue(_ property: String) -> Any? {
        guard let currentWeather = Mirror(reflecting: weatherService).descendant("currentWeather") else {
            return nil
        }

        return Mirror(reflecting: currentWeather).children.first { $0.label == property }?.value
    }

    // Safe accessor for forecast values using Mirror
    private func getForecastValue(_ property: String) -> Any? {
        guard let forecast = Mirror(reflecting: weatherService).descendant("forecast"),
              let dailyForecasts = Mirror(reflecting: forecast).descendant("daily"),
              let firstForecast = (dailyForecasts as? [Any])?.first else {
            return nil
        }

        return Mirror(reflecting: firstForecast).children.first { $0.label == property }?.value
    }
    
    private var weatherSourcesSection: some View {
        Group {
            // Aggregate warning banner (macOS variant)
            if healthMonitor.hasAnyBlockingIssue {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "key.slash")
                            .foregroundColor(.red)
                        Text("One or more API keys are no longer accepted by the provider.")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    ForEach(healthMonitor.blockingServices, id: \.rawValue) { service in
                        HStack(spacing: 8) {
                            APIKeyHealthStatusBadge(
                                entry: healthMonitor.entry(for: service),
                                compact: true
                            )
                            Text("\(service.displayName) – re-enter a valid key to restore this source.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color.red.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Weather Underground
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.green)
                        .font(.title3)
                    Text("Weather Underground")
                        .font(.headline)
                    Spacer()
                    APIKeyHealthStatusBadge(
                        entry: healthMonitor.entry(for: .weatherUnderground),
                        compact: true
                    )
                }

                Text("Personal weather station data")
                    .font(.caption)
                    .foregroundColor(.secondary)

                APIKeyHealthCard(
                    monitor: healthMonitor,
                    service: .weatherUnderground,
                    weatherService: weatherService
                )

                #if os(iOS)
                APIKeyTextField(
                    text: $wuApiKey,
                    placeholder: "API Key",
                    isFocused: focusedField == .wuApiKey,
                    onDone: { focusedField = nil }
                )
                .frame(height: 36)
                
                APIKeyTextField(
                    text: $stationID,
                    placeholder: "Station ID",
                    isFocused: focusedField == .stationID,
                    onDone: { focusedField = nil }
                )
                .frame(height: 36)
                #else
                TextField("API Key", text: $wuApiKey)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Station ID", text: $stationID)
                    .textFieldStyle(.roundedBorder)
                #endif
            }
            
            Divider()
            
            // OpenWeatherMap
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                        .font(.title3)
                    Text("OpenWeatherMap")
                        .font(.headline)
                    Spacer()
                    APIKeyHealthStatusBadge(
                        entry: healthMonitor.entry(for: .openWeatherMap),
                        compact: true
                    )
                }

                Text("Detailed forecast data")
                    .font(.caption)
                    .foregroundColor(.secondary)

                APIKeyHealthCard(
                    monitor: healthMonitor,
                    service: .openWeatherMap,
                    weatherService: weatherService
                )

                #if os(iOS)
                APIKeyTextField(
                    text: $owmApiKey,
                    placeholder: "API Key",
                    isFocused: focusedField == .owmApiKey,
                    onDone: { focusedField = nil }
                )
                .frame(height: 36)
                #else
                TextField("API Key", text: $owmApiKey)
                    .textFieldStyle(.roundedBorder)
                #endif
            }
            
            Divider()
            
            // Apple WeatherKit
            HStack(spacing: 12) {
                Image(systemName: "apple.logo")
                    .foregroundColor(.primary)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Weather")
                        .font(.headline)
                    
                    if #available(iOS 16.0, macOS 13.0, *) {
                        Text("Built-in (Default)")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Requires iOS 16+")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                if #available(iOS 16.0, macOS 13.0, *) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            
            Divider()
            
            // OpenMeteo
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "cloud.sun.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open-Meteo")
                            .font(.headline)
                        Text("Free alternative")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle("Use as default", isOn: $useOpenMeteoAsDefault)
                    .toggleStyle(.switch)
                    .onChange(of: useOpenMeteoAsDefault) { _ in
                        Task {
                            await weatherService.fetchWeather(calledFrom: "SettingsView.useOpenMeteoAsDefault.onChange")
                        }
                    }
            }
            
            // Save button
            Button(action: saveAPIKeys) {
                Label("Save API Keys", systemImage: "key.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 12)
            .onAppear {
                loadAPIKeys()
            }
        }
    }
    
    private var unitsAndDisplaySection: some View {
        Group {
            // Temperature Unit
            HStack {
                Label("Temperature", systemImage: "thermometer")
                    .frame(width: 140, alignment: .leading)
                
                Spacer()
                
                Picker("", selection: $unitSystem) {
                    ForEach(unitSystems, id: \.self) { unit in
                        Text(unit).tag(unit)
                    }
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.menu)
                #endif
                .onChange(of: unitSystem) { newValue in
                    weatherService.unitSystem = newValue
                }
            }
            
            Divider()
            
            // Theme
            HStack {
                Label("Theme", systemImage: "circle.lefthalf.filled")
                    .frame(width: 140, alignment: .leading)
                
                Spacer()
                
                Picker("", selection: $colorScheme) {
                    Label("System", systemImage: "gear").tag("system")
                    Label("Light", systemImage: "sun.max").tag("light")
                    Label("Dark", systemImage: "moon").tag("dark")
                }
                .pickerStyle(.menu)
            }
            
            Divider()
            
            // Forecast Days
            HStack {
                Label("Forecast Days", systemImage: "calendar")
                    .frame(width: 140, alignment: .leading)
                
                Spacer()
                
                Picker("", selection: $forecastDays) {
                    ForEach(forecastDayOptions, id: \.self) { days in
                        Text("\(days) Days").tag(days)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: forecastDays) { newValue in
                    Task {
                        await weatherService.fetchForecasts()
                    }
                }
            }
            
            Divider()
            
            // Display Mode
            HStack {
                Label("Display Mode", systemImage: "rectangle.split.3x1")
                    .frame(width: 140, alignment: .leading)
                
                Spacer()
                
                Picker("", selection: $displayMode) {
                    ForEach(displayModes, id: \.self) { mode in
                        Text(mode).tag(mode)
                    }
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.segmented)
                #endif
            }
        }
    }
    
    private var feedbackSection: some View {
        Group {
            NavigationLink {
                FeedbackView(
                    initialCategory: .bug,
                    dataSource: weatherService.currentDataSource,
                    unitSystem: unitSystem
                )
            } label: {
                Label("Send Feedback", systemImage: "envelope.fill")
            }

            NavigationLink {
                FeedbackView(
                    initialCategory: .idea,
                    dataSource: weatherService.currentDataSource,
                    unitSystem: unitSystem
                )
            } label: {
                Label("Request a Feature", systemImage: "lightbulb.fill")
            }
        }
    }

    private var aboutSection: some View {
        Group {
            // Version
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Source Code
            Link(destination: URL(string: "https://github.com/saxobroko/SaxWeather")!) {
                HStack {
                    Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Developer
            Link(destination: URL(string: "https://saxobroko.com")!) {
                HStack {
                    Label("Developer", systemImage: "person.circle")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Made with love
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Text("Made with")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.subheadline)
                    Text("by Saxon")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                Spacer()
            }
        }
    }
    
    // Attribution footer - meets legal requirements for all services
    private var attributionFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ATTRIBUTIONS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 10) {
                // Apple Weather (WeatherKit) - REQUIRED when available
                if #available(iOS 16.0, macOS 13.0, *) {
                    Link(destination: URL(string: "https://weather.apple.com")!) {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(.body)
                                .foregroundColor(.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Weather data from Apple Weather")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text("Built-in weather service")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Open-Meteo - REQUIRED (CC BY 4.0)
                Link(destination: URL(string: "https://open-meteo.com")!) {
                    HStack(spacing: 8) {
                        Image(systemName: "cloud.sun.fill")
                            .font(.body)
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weather data by Open-Meteo.com")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Text("Free weather API (CC BY 4.0)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Weather Underground - if configured
                if !wuApiKey.isEmpty && !stationID.isEmpty {
                    Link(destination: URL(string: "https://www.wunderground.com")!) {
                        HStack(spacing: 8) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.body)
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Data from WU Station: \(stationID)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text("Personal weather station")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // OpenWeatherMap - REQUIRED if configured
                if !owmApiKey.isEmpty {
                    Link(destination: URL(string: "https://openweathermap.org")!) {
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .font(.body)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Weather data from OpenWeatherMap")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text("Global weather data provider")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Current source indicator
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                Text("Active source: \(currentDataSourceName)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Data Sources Attribution Section
    
    /// Helper to get human-readable data source name
    private var currentDataSourceName: String {
        switch weatherService.currentDataSource.lowercased() {
        case "weatherkit":
            return "Apple Weather"
        case "openmeteo":
            return "Open-Meteo"
        case "weatherunderground":
            return "Weather Underground"
        case "openweathermap":
            return "OpenWeatherMap"
        case "unknown":
            return "Not yet fetched"
        default:
            return weatherService.currentDataSource
        }
    }
    
    private var savedLocationsSection: some View {
        Section(header:
            Text("Saved Locations")
                .font(.headline)
                .foregroundColor(.accentColor)
                .padding(.vertical, 2)
        ) {
            if !wuApiKey.isEmpty && !stationID.isEmpty {
                Text("Custom locations are ignored when a Weather Underground station is set. Weather data will be fetched from your station's location.")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .font(.callout)
            }
            
            HStack {
                Image(systemName: "location.fill")
                Text("Current Location (GPS)")
                Spacer()
                if locationsManager.selectedLocation?.isCurrentLocation ?? false {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .frame(height: 20)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                #if canImport(UIKit)
                HapticFeedbackHelper.shared.light()
                #endif
                locationsManager.selectCurrentLocation()
                weatherService.useGPS = true
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            ForEach(Array(locationsManager.locations.enumerated()), id: \ .element.id) { idx, location in
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.name)
                            Text("\(formatCoordinate(location.latitude)), \(formatCoordinate(location.longitude))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if locationsManager.selectedLocation?.id == location.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .frame(height: 20)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        locationsManager.selectLocation(location)
                        weatherService.useGPS = false
                        Task { await weatherService.fetchWeather(calledFrom: "SettingsView.savedLocation.onTap") }
                    }
                    #if os(iOS)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            if SettingsBehaviour.confirmDestructive {
                                pendingDeleteLocation = location
                            } else {
                                locationsManager.removeLocation(location)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    #endif
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    if idx < locationsManager.locations.count - 1 {
                        Divider()
                    }
                }
            }
            HStack {
                Spacer()
                Button(action: { showingAddLocationSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Add Location")
                Spacer()
            }
            .padding(.top, 4)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
    }
    
    private var addLocationSheet: some View {
        NavigationView {
            List {
                Button("Use Current Location (GPS)") {
                    locationsManager.selectCurrentLocation()
                    weatherService.useGPS = true
                    showingAddLocationSheet = false
                }
                Button {
                    addLocationMode = .manual
                } label: {
                    Label("Enter Custom Coordinates", systemImage: "number.square")
                }
                Button {
                    addLocationMode = .search
                } label: {
                    Label("Search City/Town", systemImage: "magnifyingglass")
                }
                Button {
                    addLocationMode = .map
                } label: {
                    Label("Select on Map", systemImage: "map")
                }
            }
            .navigationTitle("Add Location")
            #if os(iOS)
            .navigationBarItems(leading: Button("Cancel") { showingAddLocationSheet = false })
            #else
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddLocationSheet = false }
                }
            }
            #endif
            .sheet(item: $addLocationMode) { mode in
                switch mode {
                case .manual:
                    manualCoordinatesSheet
                case .search:
                    citySearchSheet
                case .map:
                    mapSelectionSheet
                }
            }
        }
    }
    
    // Map selection sheet
    private var mapSelectionSheet: some View {
        LocationPickerView(
            selectedLocation: $mapSelectedLocation,
            selectedLocationName: $mapSelectedLocationName
        )
        .onDisappear {
            // When the map picker is dismissed, check if a location was selected
            if let location = mapSelectedLocation {
                let lat = location.latitude
                let lon = location.longitude
                
                // Validate coordinates
                let validationResult = CoordinateValidator.validate(latitude: lat, longitude: lon)
                if validationResult.isValid {
                    let validatedLat = validationResult.normalizedLatitude ?? lat
                    let validatedLon = validationResult.normalizedLongitude ?? lon
                    
                    // Use the geocoded name or a default name
                    let locationName = mapSelectedLocationName ?? "Selected Location"

                    requestAddLocationPreview(
                        name: locationName,
                        latitude: validatedLat,
                        longitude: validatedLon
                    )
                    addLocationMode = nil
                    mapSelectedLocation = nil
                    mapSelectedLocationName = nil
                    showingAddLocationSheet = false
                } else {
                    alertMessage = validationResult.errorMessage ?? "Invalid coordinates. Please try again."
                    showingAlert = true
                }
            }
        }
    }
    
    private var manualCoordinatesSheet: some View {
        VStack(spacing: 20) {
            Form {
                Section {
                    TextField("Location Name", text: $newLocationName)
                    #if os(iOS)
                    CoordinateTextField(text: $newLatitude, placeholder: "Latitude")
                        .frame(height: 36)
                    CoordinateTextField(text: $newLongitude, placeholder: "Longitude")
                        .frame(height: 36)
                    #else
                    TextField("Latitude", text: $newLatitude)
                    TextField("Longitude", text: $newLongitude)
                    #endif
                }
            }
            Button(action: {
                if let lat = Double(newLatitude), let lon = Double(newLongitude), !newLocationName.isEmpty {
                    // Validate coordinates before adding location
                    let validationResult = CoordinateValidator.validate(latitude: lat, longitude: lon)
                    if validationResult.isValid {
                        // Use the new validated coordinates
                        let validatedLat = validationResult.normalizedLatitude ?? lat
                        let validatedLon = validationResult.normalizedLongitude ?? lon
                        
                        requestAddLocationPreview(
                            name: newLocationName,
                            latitude: validatedLat,
                            longitude: validatedLon
                        )
                        showingAddLocationSheet = false
                        addLocationMode = nil
                        newLocationName = ""
                        newLatitude = ""
                        newLongitude = ""
                    } else {
                        alertMessage = validationResult.errorMessage ?? "Invalid coordinates. Please check your values and try again."
                        showingAlert = true
                    }
                }
            }) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Save")
                }
                .padding()
                .frame(maxWidth: 220)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(newLocationName.isEmpty || Double(newLatitude) == nil || Double(newLongitude) == nil)
            .padding(.top, 8)
        }
        .navigationTitle("Custom Coordinates")
    }
    
    private var citySearchSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                TextField("Search for a city or town", text: $citySearchQuery)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: citySearchQuery) { newValue in
                        if newValue.count >= 2 {
                            citySearchCompleter.queryFragment = newValue
                            citySearchError = nil
                        } else {
                            citySearchResults = []
                            citySearchError = nil
                        }
                    }
                if let error = citySearchError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }
                if let selected = selectedSearchCompletion, let coordinate = citySearchCoordinate {
                    VStack(spacing: 12) {
                        Text(selected.title)
                            .font(.headline)
                        Text(selected.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Lat: \(formatCoordinate(coordinate.latitude)), Lon: \(formatCoordinate(coordinate.longitude))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Save") {
                            let name = selected.title
                            let lat = coordinate.latitude
                            let lon = coordinate.longitude
                            
                            // Validate coordinates before adding location
                            let validationResult = CoordinateValidator.validate(latitude: lat, longitude: lon)
                            if validationResult.isValid {
                                // Use the new validated coordinates
                                let validatedLat = validationResult.normalizedLatitude ?? lat
                                let validatedLon = validationResult.normalizedLongitude ?? lon
                                
                                requestAddLocationPreview(
                                    name: name,
                                    latitude: validatedLat,
                                    longitude: validatedLon
                                )
                                showingAddLocationSheet = false
                                addLocationMode = nil
                                citySearchQuery = ""
                                citySearchResults = []
                                selectedSearchCompletion = nil
                                citySearchCoordinate = nil
                                citySearchError = nil
                            } else {
                                // Handle error - but we don't have access to alertMessage/showingAlert here
                                print("Invalid coordinates: \(validationResult.errorMessage ?? "Unknown error")")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List(citySearchResults, id: \ .self) { completion in
                        VStack(alignment: .leading) {
                            Text(completion.title)
                            if !completion.subtitle.isEmpty {
                                Text(completion.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Search for coordinates
                            isSearchingCity = true
                            citySearchError = nil
                            let request = MKLocalSearch.Request(completion: completion)
                            let search = MKLocalSearch(request: request)
                            search.start { response, error in
                                isSearchingCity = false
                                if let error = error {
                                    citySearchError = error.localizedDescription
                                    return
                                }
                                if let item = response?.mapItems.first {
                                    selectedSearchCompletion = completion
                                    citySearchCoordinate = item.placemark.coordinate
                                } else {
                                    citySearchError = "No location found."
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                Button("Cancel") { addLocationMode = nil }
                    .padding(.top)
            }
            .navigationTitle("Search City/Town")
            .onAppear {
                citySearchCompleter.resultTypes = .address
                let delegate = CitySearchCompleterDelegate(
                    onResults: { results in
                        citySearchResults = results
                    },
                    onError: { error in
                        citySearchError = error
                    }
                )
                citySearchCompleter.delegate = delegate
                citySearchCompleterDelegate = delegate
            }
        }
    }
    
    enum AddLocationMode: Identifiable {
        case manual, search, map
        var id: Int { hashValue }
    }
    
    private func saveAPIKeys() {
        let trimmedWUKey = wuApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStationID = stationID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOWMKey = owmApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Save API keys securely in Keychain
        if !trimmedWUKey.isEmpty {
            _ = KeychainService.shared.saveApiKey(trimmedWUKey, forService: "wu")
        } else {
            _ = KeychainService.shared.deleteApiKey(forService: "wu")
        }
        
        if !trimmedOWMKey.isEmpty {
            _ = KeychainService.shared.saveApiKey(trimmedOWMKey, forService: "owm")
        } else {
            _ = KeychainService.shared.deleteApiKey(forService: "owm")
        }
        
        UserDefaults.standard.set(trimmedStationID, forKey: "stationID")
        
        alertMessage = "API keys saved securely!"
        showingAlert = true
        
        Task {
            await weatherService.fetchWeather(calledFrom: "SettingsView.saveAPIKeys")
        }
    }
    
    private func loadAPIKeys() {
        wuApiKey = KeychainService.shared.getApiKey(forService: "wu") ?? ""
        owmApiKey = KeychainService.shared.getApiKey(forService: "owm") ?? ""
        stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
    }
    
    private func validateSettings() -> Bool {
        let wuApiKey = UserDefaults.standard.string(forKey: "wuApiKey") ?? ""
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        let owmApiKey = UserDefaults.standard.string(forKey: "owmApiKey") ?? ""
        let latitude = UserDefaults.standard.string(forKey: "latitude") ?? ""
        let longitude = UserDefaults.standard.string(forKey: "longitude") ?? ""
        let useGPS = UserDefaults.standard.bool(forKey: "useGPS")
        
        let hasWUConfig = !wuApiKey.isEmpty && !stationID.isEmpty
        let hasOWMConfig = !owmApiKey.isEmpty
        
        // For location, we need to ensure either:
        // 1. GPS is enabled and authorized, or
        // 2. Valid manual coordinates are provided
        var hasValidLocation = false
        
        #if os(iOS)
        if useGPS {
            // Check if location services are authorized
            let status = weatherService.locationManager.authorizationStatus
            hasValidLocation = status == .authorizedWhenInUse || status == .authorizedAlways
        } else {
            // Check if manual coordinates are valid
            if let lat = Double(latitude), let lon = Double(longitude) {
                hasValidLocation = lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
            }
        }
        #else
        if let lat = Double(latitude), let lon = Double(longitude) {
            hasValidLocation = lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
        }
        #endif
        
        // Return true if either:
        // 1. We have proper WU config, or
        // 2. We have proper OWM config with valid location, or
        // 3. We have valid location (for OpenMeteo fallback)
        return hasWUConfig || (hasOWMConfig && hasValidLocation) || hasValidLocation
    }
    
    private func formatCoordinate(_ value: Double) -> String {
        return String(format: "%.5g", value)
    }
}

// MARK: - Settings search results (Phase 7)

struct SettingsSearchResults: View {
    @EnvironmentObject private var customisation: CustomisationRegistry
    @EnvironmentObject private var storeManager: StoreManager
    let query: String

    // Sheet / navigation state.
    @Binding var sheet: SettingsSheet?
    @Binding var navigationPath: NavigationPath

    var body: some View {
        List {
            if results.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No matches for '\(query)'")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Try a different word, or clear the search to browse all settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            } else {
                // 1. Locked knobs first — clearly labelled.
                if !lockedKnobs.isEmpty {
                    Section {
                        ForEach(lockedKnobs, id: \.id) { knob in
                            SearchKnobRow(descriptor: knob, isLocked: true) {
                                handleKnobTap(knob)
                            }
                        }
                    } header: {
                        Label("Purchase Required", systemImage: "lock.fill")
                            .foregroundStyle(.orange)
                    } footer: {
                        Text("Unlock Custom Backgrounds to access these settings.")
                    }
                }

                // 2. Free settings rows.
                if !matchingSettings.isEmpty {
                    Section {
                        ForEach(matchingSettings, id: \.id) { item in
                            SearchSettingsRow(item: item) { action in
                                handleSettingsAction(action)
                            }
                        }
                    } header: {
                        Text("Settings")
                    }
                }

                // 3. Free knobs grouped by their spec group.
                ForEach(groupedFreeKnobs, id: \.0) { group, knobs in
                    Section {
                        ForEach(knobs, id: \.id) { knob in
                            SearchKnobRow(descriptor: knob, isLocked: false) {
                                handleKnobTap(knob)
                            }
                        }
                    } header: {
                        Text(group.localizedName)
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    // MARK: - Filtering

    /// Settings rows whose title matches the query.
    private var matchingSettings: [SettingsSearchItem] {
        let lowered = query.lowercased()
        return SettingsSearchItem.all.filter { $0.title.lowercased().contains(lowered) }
    }

    /// Knobs that match the query AND are IAP-locked.
    private var lockedKnobs: [KnobDescriptor] {
        customisation.searchKnobs(query).filter { knob in
            knob.requiresCustomBackgroundIAP && !storeManager.customBackgroundUnlocked
        }
    }

    /// Knobs that match the query AND are NOT IAP-locked (or are
    /// already unlocked).
    private var freeKnobs: [KnobDescriptor] {
        customisation.searchKnobs(query).filter { knob in
            !(knob.requiresCustomBackgroundIAP && !storeManager.customBackgroundUnlocked)
        }
    }

    /// Free knobs grouped by their spec group, in the same order
    /// as `KnobGroup.allCases`.
    private var groupedFreeKnobs: [(KnobGroup, [KnobDescriptor])] {
        let grouped = Dictionary(grouping: freeKnobs, by: \.group)
        return KnobGroup.allCases
            .compactMap { group -> (KnobGroup, [KnobDescriptor])? in
                guard let knobs = grouped[group], !knobs.isEmpty else { return nil }
                return (group, knobs.sorted { $0.displayName < $1.displayName })
            }
            .sorted { $0.0.sortOrder < $1.0.sortOrder }
    }

    /// True when there is at least one row to show.
    private var results: [SearchResult] {
        var out: [SearchResult] = []
        for item in matchingSettings { out.append(.settings(item)) }
        for knob in lockedKnobs { out.append(.knob(knob)) }
        for knob in freeKnobs { out.append(.knob(knob)) }
        return out
    }

    // MARK: - Tap dispatch

    private func handleSettingsAction(_ action: SettingsSearchAction) {
        switch action {
        case .sheet(let s):
            sheet = s
        case .navigate(let route):
            navigationPath.append(route)
        }
    }

    /// Every knob tap navigates to its owning settings page. Locked
    /// knobs open the TipJar instead so the user can unlock.
    private func handleKnobTap(_ knob: KnobDescriptor) {
        #if canImport(UIKit)
        HapticFeedbackHelper.shared.light()
        #endif
        if knob.requiresCustomBackgroundIAP && !storeManager.customBackgroundUnlocked {
            sheet = .tipJar
        } else {
            navigationPath.append(SettingsSearchRoute.from(knob.owningRoute))
        }
    }
}

enum SettingsSearchAction {
    case sheet(SettingsSheet)
    case navigate(SettingsSearchRoute)
}

/// Sheet identifiers the search results can present.
enum SettingsSheet: Identifiable {
    case profileImporter
    case tipJar
    case searchAllSettings

    var id: String {
        switch self {
        case .profileImporter:    return "profileImporter"
        case .tipJar:             return "tipJar"
        case .searchAllSettings:  return "searchAllSettings"
        }
    }
}

/// Routes the search results can push onto the Settings navigation
/// stack. Matches the existing `NavigationLink` destinations in
/// `SettingsView.settingsTree`.
enum SettingsSearchRoute: Hashable {
    case locations
    case weatherData
    case preferences
    case appearance
    case cardStyle
    case accessibility
    case behaviour
    case backupAndRestore
    case feedback(FeedbackCategory)
    case about
    case attribution

    static func from(_ owning: KnobOwningRoute) -> SettingsSearchRoute {
        switch owning {
        case .appearance:    return .appearance
        case .preferences:   return .preferences
        case .behaviour:     return .behaviour
        case .accessibility: return .accessibility
        case .weatherData:   return .weatherData
        case .cardStyle:     return .cardStyle
        }
    }
}

/// One item in the search results — either a top-level settings row
/// or a customisation knob.
private enum SearchResult {
    case settings(SettingsSearchItem)
    case knob(KnobDescriptor)

    var id: String {
        switch self {
        case .settings(let item): return "settings.\(item.id)"
        case .knob(let knob):     return "knob.\(knob.id)"
        }
    }
}

/// A top-level settings row that the search bar can surface.
struct SettingsSearchItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let action: SettingsSearchAction

    /// Every top-level row that the search bar can match against.
    static let all: [SettingsSearchItem] = [
        .init(id: "backupAndRestore", title: String(localized: "Backup & Restore"),
              subtitle: String(localized: "Back up, restore, or sync via iCloud"),
              symbolName: "arrow.triangle.2.circlepath.circle.fill",
              action: .navigate(.backupAndRestore)),
        .init(id: "locations", title: String(localized: "Locations"),
              subtitle: String(localized: "Saved locations & GPS"),
              symbolName: "location.fill",
              action: .navigate(.locations)),
        .init(id: "weatherData", title: String(localized: "Weather Data"),
              subtitle: String(localized: "API keys & data sources"),
              symbolName: "cloud.sun.fill",
              action: .navigate(.weatherData)),
        .init(id: "preferences", title: String(localized: "Preferences"),
              subtitle: String(localized: "Units, forecast window, layout"),
              symbolName: "slider.horizontal.3",
              action: .navigate(.preferences)),
        .init(id: "appearance", title: String(localized: "Appearance"),
              subtitle: String(localized: "Backgrounds, accent, animations"),
              symbolName: "paintbrush.fill",
              action: .navigate(.appearance)),
        .init(id: "cardStyle", title: String(localized: "Card Style"),
              subtitle: String(localized: "Colour, border, shadow, glass, tint"),
              symbolName: "rectangle.stack.fill",
              action: .navigate(.cardStyle)),
        .init(id: "accessibility", title: String(localized: "Accessibility"),
              subtitle: String(localized: "Text size, motion, contrast, VoiceOver"),
              symbolName: "accessibility",
              action: .navigate(.accessibility)),
        .init(id: "support", title: String(localized: "Support Development"),
              subtitle: String(localized: "Leave a tip"),
              symbolName: "heart.fill",
              action: .sheet(.tipJar)),
        .init(id: "sendFeedback", title: String(localized: "Send Feedback"),
              subtitle: String(localized: "Report a bug to the developer"),
              symbolName: "envelope.fill",
              action: .navigate(.feedback(.bug))),
        .init(id: "requestFeature", title: String(localized: "Request a Feature"),
              subtitle: String(localized: "Suggest an improvement"),
              symbolName: "lightbulb.fill",
              action: .navigate(.feedback(.idea))),
        .init(id: "about", title: String(localized: "About"),
              subtitle: String(localized: "Version & developer"),
              symbolName: "info.circle.fill",
              action: .navigate(.about)),
        .init(id: "attribution", title: String(localized: "Attribution"),
              subtitle: String(localized: "Open-Meteo, Apple Weather, WU, OWM"),
              symbolName: "network",
              action: .navigate(.attribution))
    ]
}

// MARK: - Rows

private struct SearchSettingsRow: View {
    let item: SettingsSearchItem
    let onTap: (SettingsSearchAction) -> Void

    var body: some View {
        // `.borderless` button style is the recommended style for
        // tappable rows inside a `List` — it preserves the row's
        // visual styling while still firing the action reliably.
        // We override the accent tint on the icon so the row
        // doesn't pick up the global accent colour.
        Button {
            onTap(item.action)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.symbolName)
                    .font(.body)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .tint(Color.primary)
    }
}

private struct SearchKnobRow: View {
    let descriptor: KnobDescriptor
    let isLocked: Bool
    let onTap: () -> Void
    @EnvironmentObject private var customisation: CustomisationRegistry

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: descriptor.symbolName)
                    .font(.body)
                    .foregroundStyle(isLocked ? Color.orange : Color.accentColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(descriptor.displayName)
                            .font(.body)
                            .foregroundStyle(Color.primary)
                        if isLocked {
                            Text("PRO")
                                .font(.caption2.bold())
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange, in: Capsule())
                        }
                    }
                    Text(descriptor.summary)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(currentValueLabel)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(isLocked ? Color.orange : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .tint(Color.primary)
    }

    private var currentValueLabel: String {
        SearchKnobValueFormatter.label(for: descriptor.id, in: customisation.profile)
    }
}

// MARK: - Value formatter (shared with KnobSearchView)

enum SearchKnobValueFormatter {
    static func label(for knobID: String, in profile: CustomisationProfile) -> String {
        let k = profile.knobs
        switch knobID {
        // Visual
        case "accentColor":                 return k.visual.accentColor.rawString
        case "palette":                     return paletteSummary(k.visual.palette)
        case "cardStyle":                   return k.visual.cardStyle.rawValue
        case "cornerRadius":                return String(format: "%.0f pt", k.visual.cornerRadius)
        case "fontScale":                   return String(format: "%.2f×", k.visual.fontScale)
        case "boldText":                    return k.visual.boldText ? "On" : "Off"
        case "useSystemTextSize":           return k.visual.useSystemTextSize ? "On" : "Off"
        case "typography":                  return k.visual.typography.rawValue
        case "increaseContrast":            return k.visual.increaseContrast ? "On" : "Off"
        case "colorScheme":                 return k.visual.colorScheme.capitalized
        case "cardOpacity":                 return String(format: "%.2f", k.visual.cardOpacity)

        // Background
        case "backgroundMode":              return k.background.mode.rawValue
        case "backgroundUseCustom":         return k.background.useCustom ? "On" : "Off"
        case "backgroundOverlayOpacity":    return String(format: "%.2f", k.background.overlayOpacity)
        case "backgroundTimeOfDayRule":     return k.background.timeOfDayRule.rawValue
        case "backgroundDynamicTint":       return k.background.dynamicTint.rawString
        case "backgroundPerCondition":      return "\(k.background.perCondition.count) overrides"
        case "backgroundGradient":          return gradientSummary(k.background.gradient)

        // Iconography
        case "lottieAnimationSet":          return k.iconography.lottieAnimationSet.rawValue
        case "lottieOverrideMap":           return "\(k.iconography.lottieOverrideMap.count) overrides"
        case "lottiePlaybackSpeed":         return String(format: "%.2f×", k.iconography.lottiePlaybackSpeed)
        case "lottieLoopMode":              return k.iconography.lottieLoopMode.rawValue
        case "disableWeatherAnimations":    return k.iconography.disableWeatherAnimations ? "Off" : "On"
        case "weatherIconStyle":            return k.iconography.weatherIconStyle.rawValue
        case "symbolSet":                   return k.iconography.symbolSet.rawValue
        case "iconSizeMultiplier":          return String(format: "%.2f×", k.iconography.iconSizeMultiplier)

        // Layout
        case "displayMode":                 return k.layout.displayMode
        case "forecastDays":                return "\(k.layout.forecastDays) days"
        case "hourlyHours":                 return "\(k.layout.hourlyHours) h"
        case "cardDensity":                 return k.layout.cardDensity.rawValue
        case "homeSectionOrder":            return "\(k.layout.homeSectionOrder.count) sections"
        case "hiddenHomeSections":          return "\(k.layout.hiddenHomeSections.count) hidden"
        case "showHamburgerMenu":           return k.layout.showHamburgerMenu ? "On" : "Off"
        case "swipeBetweenLocations":       return k.layout.swipeBetweenLocations ? "On" : "Off"
        case "showLocationHeader":          return k.layout.showLocationHeader ? "On" : "Off"
        case "previewBeforeChangingLocation": return k.layout.previewBeforeChangingLocation ? "On" : "Off"
        case "showHeroLastUpdated":         return k.layout.showHeroLastUpdated ? "On" : "Off"
        case "compactCardsInLandscape":     return k.layout.compactCardsInLandscape ? "On" : "Off"

        // Forecast
        case "hourlyChartType":             return k.forecast.hourlyChartType.rawValue
        case "hourlyCardStyle":             return k.forecast.hourlyCardStyle.rawValue
        case "dailyCardStyle":              return k.forecast.dailyCardStyle.rawValue
        case "chartAxes":                   return k.forecast.chartAxes ? "On" : "Off"
        case "precipitationOverlay":        return k.forecast.precipitationOverlay ? "On" : "Off"
        case "showSunArc":                  return k.forecast.showSunArc ? "On" : "Off"
        case "showMoonPhase":               return k.forecast.showMoonPhase ? "On" : "Off"
        case "showHourlySummary":           return k.forecast.showHourlySummary ? "On" : "Off"
        case "detailedColumnCount":         return "\(k.forecast.detailedColumnCount) columns"

        // Data
        case "unitSystem":                  return k.data.unitSystem
        case "temperaturePrecision":        return "\(k.data.temperaturePrecision) dp"
        case "windPrecision":               return "\(k.data.windPrecision) dp"
        case "pressurePrecision":           return "\(k.data.pressurePrecision) dp"
        case "preferredDataSource":         return k.data.preferredDataSource.rawValue
        case "useOpenMeteoAsDefault":       return k.data.useOpenMeteoAsDefault ? "On" : "Off"
        case "disableAPIKeys":              return k.data.disableAPIKeys ? "On" : "Off"
        case "refreshCadence":              return k.data.refreshCadence.rawValue
        case "backgroundRefreshEnabled":    return k.data.backgroundRefreshEnabled ? "On" : "Off"
        case "visibleMetrics":              return "\(k.data.visibleMetrics.count) selected"
        case "hourlyMetrics":               return "\(k.data.hourlyMetrics.count) selected"
        case "extendedCardsEnabled":        return "\(k.data.extendedCardsEnabled.count) enabled"
        case "showLocationLabel":           return k.data.showLocationLabel ? "On" : "Off"

        // Behaviour
        case "enableHapticFeedback":        return k.behaviour.enableHapticFeedback ? "On" : "Off"
        case "hapticIntensity":             return k.behaviour.hapticIntensity.rawValue
        case "pullToRefresh":               return k.behaviour.pullToRefresh ? "On" : "Off"
        case "tapDayToExpand":              return k.behaviour.tapDayToExpand ? "On" : "Off"
        case "longPressToCustomise":        return k.behaviour.longPressToCustomise ? "On" : "Off"
        case "confirmDestructive":          return k.behaviour.confirmDestructive ? "On" : "Off"
        case "weatherAlertSounds":          return k.behaviour.weatherAlertSounds ? "On" : "Off"
        case "rainAlertsEnabled":           return k.behaviour.rainAlertsEnabled ? "On" : "Off"
        case "severeWeatherAlertsEnabled":  return k.behaviour.severeWeatherAlertsEnabled ? "On" : "Off"
        case "aiAlertSummariesEnabled":     return k.behaviour.aiAlertSummariesEnabled ? "On" : "Off"
        case "speakWeatherAlerts":          return k.behaviour.speakWeatherAlerts ? "On" : "Off"
        case "quietHours":                  return quietHoursSummary(start: k.behaviour.quietHoursStart,
                                                                     end:   k.behaviour.quietHoursEnd)
        case "refreshSound":                return k.behaviour.refreshSound ? "On" : "Off"
        case "vibrateOnPullToRefresh":      return k.behaviour.vibrateOnPullToRefresh ? "On" : "Off"
        case "confirmQuit":                 return k.behaviour.confirmQuit ? "On" : "Off"

        // Accessibility
        case "reduceMotion":                return k.accessibility.reduceMotion ? "On" : "Off"
        case "reduceMotionForce":           return k.accessibility.reduceMotionForce ? "On" : "Off"
        case "enhancedVoiceOverLabels":     return k.accessibility.enhancedVoiceOverLabels ? "On" : "Off"
        case "highContrastOutline":         return k.accessibility.highContrastOutline ? "On" : "Off"
        case "hapticOnSelection":           return k.accessibility.hapticOnSelection ? "On" : "Off"
        case "tapticOnRefresh":             return k.accessibility.tapticOnRefresh ? "On" : "Off"

        // Content
        case "language":                    return k.content.language ?? "System"
        case "terminologySet":              return k.content.terminologySet.rawValue
        case "locationNicknames":           return "\(k.content.locationNicknames.count) nicknames"
        case "customLabels":                return "\(k.content.customLabels.count) labels"

        // Widget
        case "widgetStyle.small":           return k.widget.smallStyle.rawValue
        case "widgetStyle.medium":          return k.widget.mediumStyle.rawValue
        case "widgetStyle.large":           return k.widget.largeStyle.rawValue
        case "widgetBackground":            return k.widget.background.rawValue
        case "widgetAccentSource":          return k.widget.accentFollowsApp
                                                    ? "Follows App"
                                                    : "Override (\(k.widget.accentOverride))"
        case "widgetTapAction":             return k.widget.tapAction.rawValue

        // Power user
        case "experimentalFlags":           return "\(k.powerUser.experimentalFlags.count) enabled"
        case "shortcutName":                return k.powerUser.shortcutName ?? "—"
        case "widgetRefreshPolicy":         return k.powerUser.widgetRefreshPolicy.rawValue
        case "shareThemeOnExport":          return k.powerUser.shareThemeOnExport ? "On" : "Off"
        case "debugOverlay":                return k.powerUser.debugOverlay ? "On" : "Off"
        case "experimentalNewHeroLayout":   return k.powerUser.experimentalNewHeroLayout ? "On" : "Off"
        case "experimentalSwipeRefresh":    return k.powerUser.experimentalSwipeRefresh ? "On" : "Off"

        default:                            return "—"
        }
    }

    // MARK: - Composite summaries

    /// Compact one-line summary of the five-colour palette.
    private static func paletteSummary(_ p: Palette) -> String {
        "\(p.background.rawString) / \(p.surface.rawString) / \(p.text.rawString)"
    }

    /// "top → bottom" with each colour's raw token name.
    private static func gradientSummary(_ g: GradientSpec) -> String {
        "\(g.topColor.rawString) → \(g.bottomColor.rawString)"
    }

    /// "22:00 → 07:00" or "Off" when both endpoints are nil.
    private static func quietHoursSummary(start: Int?, end: Int?) -> String {
        guard let s = start, let e = end else { return "Off" }
        return String(format: "%02d:00 → %02d:00", s, e)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(weatherService: WeatherService())
            .environmentObject(StoreManager.shared)
            .environmentObject(SavedLocationsManager())
        SettingsView(weatherService: WeatherService(), isOnboarding: true)
            .environmentObject(StoreManager.shared)
            .environmentObject(SavedLocationsManager())
    }
}

#if os(iOS)
extension View {
    func hideKeyboardOnTap() -> some View {
        self.gesture(
            TapGesture().onEnded { _ in
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        )
    }
}

struct CoordinateTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CoordinateTextField
        init(_ parent: CoordinateTextField) { self.parent = parent }
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        @objc func insertMinus() {
            var t = parent.text
            if t.hasPrefix("-") {
                t.removeFirst()
            } else {
                t = "-" + t
            }
            parent.text = t
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.keyboardType = .decimalPad
        textField.delegate = context.coordinator
        textField.text = text
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChangeSelection(_:)), for: .editingChanged)
        // Add minus button above keyboard
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let minusButton = UIBarButtonItem(title: "Negative -", style: .plain, target: context.coordinator, action: #selector(Coordinator.insertMinus))
        // Style the minus button
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 20, weight: .bold)
        ]
        minusButton.setTitleTextAttributes(attributes, for: .normal)
        minusButton.setTitleTextAttributes(attributes, for: .highlighted)
        minusButton.tintColor = .systemBlue
        toolbar.items = [flex, minusButton]
        // Match the toolbar background to the keyboard background
        toolbar.barTintColor = UIColor.systemBackground
        toolbar.backgroundColor = UIColor.systemBackground
        return returnWithToolbar(textField, toolbar: toolbar)
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
    
    private func returnWithToolbar(_ textField: UITextField, toolbar: UIToolbar) -> UITextField {
        textField.inputAccessoryView = toolbar
        return textField
    }
}

struct APIKeyTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isFocused: Bool
    var onDone: (() -> Void)? = nil

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: APIKeyTextField
        weak var textField: UITextField?
        init(_ parent: APIKeyTextField) { self.parent = parent }
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        @objc func doneTapped() {
            textField?.resignFirstResponder()
            // The parent's onDone callback is fired from
            // textFieldDidEndEditing so the focus state stays in
            // sync no matter how the field resigns first responder
            // (Done button, tap outside, system dismissal, etc.).
        }
        func textFieldDidEndEditing(_ textField: UITextField) {
            // Tell the parent the field resigned first responder so
            // it can clear its @FocusState. This also keeps the
            // SwiftUI focus state in lock-step with the UITextField
            // without us ever calling resignFirstResponder() from
            // updateUIView (which is what was dismissing the
            // keyboard after every keystroke).
            parent.onDone?()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        context.coordinator.textField = textField
        textField.placeholder = placeholder
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.smartInsertDeleteType = .no
        textField.delegate = context.coordinator
        textField.text = text
        textField.borderStyle = .roundedRect
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChangeSelection(_:)), for: .editingChanged)
        // Remove inputAssistantItem (the 3 blank boxes)
        let inputAssistant = textField.inputAssistantItem
        inputAssistant.leadingBarButtonGroups = []
        inputAssistant.trailingBarButtonGroups = []
        // Add Done button above keyboard
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: context.coordinator, action: #selector(Coordinator.doneTapped))
        toolbar.items = [flex, doneButton]
        textField.inputAccessoryView = toolbar
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        // Only request focus when the parent asks us to focus AND
        // the field isn't already first responder. We deliberately
        // do NOT call resignFirstResponder() based on `isFocused`
        // here, because updateUIView is invoked on every text-change
        // re-render and the parent's @FocusState is not
        // automatically kept in sync with the UITextField's first
        // responder status. Calling resignFirstResponder() under
        // those conditions would dismiss the keyboard after every
        // single character the user typed (since `isFocused` is
        // almost always `false` while the user is typing). The Done
        // button, taps outside the field, and other standard UIKit
        // dismissal paths handle the resign naturally, and the
        // coordinator reports the focus change back to the parent
        // through onDone in textFieldDidEndEditing.
        if isFocused && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        }
    }
}
#endif

// Add a delegate class for MKLocalSearchCompleter
class CitySearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    let onResults: ([MKLocalSearchCompletion]) -> Void
    let onError: (String?) -> Void
    init(onResults: @escaping ([MKLocalSearchCompletion]) -> Void, onError: @escaping (String?) -> Void) {
        self.onResults = onResults
        self.onError = onError
    }
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onResults(completer.results)
    }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        onError(error.localizedDescription)
    }
}

// MARK: - Sub-Menu Views

// MARK: Locations Settings
struct LocationsSettingsView: View {
    @ObservedObject var locationsManager: SavedLocationsManager
    @Binding var disableAPIKeys: Bool
    @ObservedObject var weatherService: WeatherService
    @State private var showingAddLocationSheet = false
    @State private var addLocationMode: AddLocationMode? = nil
    @State private var newLocationName = ""
    @State private var newLatitude = ""
    @State private var newLongitude = ""
    @State private var citySearchQuery = ""
    @State private var citySearchResults: [MKLocalSearchCompletion] = []
    @State private var selectedSearchCompletion: MKLocalSearchCompletion?
    @State private var isSearchingCity = false
    @State private var citySearchCompleter = MKLocalSearchCompleter()
    @State private var citySearchError: String? = nil
    @State private var citySearchCoordinate: CLLocationCoordinate2D? = nil
    @State private var citySearchCompleterDelegate: CitySearchCompleterDelegate? = nil
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var mapSelectedLocation: CLLocationCoordinate2D? = nil
    @State private var mapSelectedLocationName: String? = nil
    // `confirmDestructive` — staged location waiting for
    // confirmation before being removed. Nil = no alert visible.
    @State private var pendingDeleteLocation: SavedLocation? = nil

    // Computed properties that read fresh values
    private var wuApiKey: String {
        disableAPIKeys ? "" : (KeychainService.shared.getApiKey(forService: "wu") ?? "")
    }
    
    private var stationID: String {
        disableAPIKeys ? "" : (UserDefaults.standard.string(forKey: "stationID") ?? "")
    }
    
    enum AddLocationMode: Identifiable {
        case manual, search, map
        var id: Int { hashValue }
    }
    
    var body: some View {
        List {
            // Warning banner when API keys override custom locations
            if !disableAPIKeys && (!wuApiKey.isEmpty || !stationID.isEmpty) {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("API Keys Active")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Custom locations below won't be used while Weather Underground is configured.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text("To use custom locations, disable API keys above or remove Weather Underground credentials in Weather Data settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // API Keys Control Section
            Section {
                Toggle(isOn: $disableAPIKeys) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Disable API Keys")
                            .font(.headline)
                        Text("Use only GPS and saved locations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: disableAPIKeys) { newValue in
                    // Refresh weather when toggling API keys (both on and off)
                    Task {
                        await weatherService.fetchWeather(calledFrom: "LocationsSettingsView.disableAPIKeys.onChange")
                    }
                }
            } header: {
                Label("API Keys", systemImage: "key.fill")
            } footer: {
                if disableAPIKeys {
                    Text("API keys for Weather Underground and OpenWeatherMap are currently disabled. Weather data will use Apple Weather, Open-Meteo, or saved locations only.")
                } else if !wuApiKey.isEmpty || !stationID.isEmpty {
                    Text("Weather Underground station is active and will override custom locations.")
                } else {
                    Text("API keys are enabled. Configure them in Weather Data settings.")
                }
            }
            
            // Location Selection Section
            Section {
                // Current Location (GPS) option
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text("Current Location (GPS)")
                    Spacer()
                    if locationsManager.selectedLocation?.isCurrentLocation ?? weatherService.useGPS {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    locationsManager.selectCurrentLocation()
                    weatherService.useGPS = true
                    Task {
                        await weatherService.fetchWeather(calledFrom: "LocationsSettingsView.selectGPS")
                    }
                }
                
                // Saved Locations
                if locationsManager.locations.isEmpty {
                    Text("No saved locations yet")
                        .foregroundColor(.secondary)
                        .font(.callout)
                } else {
                    let isOverriddenByAPIKeys = !disableAPIKeys && (!wuApiKey.isEmpty || !stationID.isEmpty)
                    
                    ForEach(locationsManager.locations) { location in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(location.name)
                                    .font(.headline)
                                Text("Lat: \(location.latitude, specifier: "%.4f"), Lon: \(location.longitude, specifier: "%.4f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if locationsManager.selectedLocation?.id == location.id && !weatherService.useGPS {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .opacity(isOverriddenByAPIKeys ? 0.5 : 1.0)
                        .disabled(isOverriddenByAPIKeys)
                        .onTapGesture {
                            // Only allow selection if not overridden
                            if !isOverriddenByAPIKeys {
                                #if canImport(UIKit)
                                HapticFeedbackHelper.shared.light()
                                #endif
                                locationsManager.selectLocation(location)
                                weatherService.useGPS = false
                                Task {
                                    await weatherService.fetchWeather(calledFrom: "LocationsSettingsView.selectLocation")
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let location = locationsManager.locations[index]
                            if SettingsBehaviour.confirmDestructive {
                                pendingDeleteLocation = location
                            } else {
                                locationsManager.removeLocation(location)
                            }
                        }
                    }
                }
            } header: {
                Text("Active Location")
            } footer: {
                if !disableAPIKeys && (!wuApiKey.isEmpty || !stationID.isEmpty) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text("Custom locations are currently overridden by Weather Underground station. To use custom locations, either disable API keys above or remove Weather Underground credentials in Weather Data settings.")
                                .font(.caption)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    Text("Tap a location to use it. Swipe left to delete.")
                }
            }
            
            Section {
                let isOverriddenByAPIKeys = !disableAPIKeys && (!wuApiKey.isEmpty || !stationID.isEmpty)
                
                Button {
                    showingAddLocationSheet = true
                } label: {
                    Label("Add Location", systemImage: "plus.circle.fill")
                }
                .disabled(isOverriddenByAPIKeys)
                .opacity(isOverriddenByAPIKeys ? 0.5 : 1.0)
            }
        }
        .navigationTitle("Locations")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingAddLocationSheet) {
            addLocationSheet
        }
        // `confirmDestructive` — confirm before deleting a saved
        // location. The swipe-action / `.onDelete` handlers in
        // the list set `pendingDeleteLocation`; this alert
        // owns the actual `removeLocation` call.
        .alert(
            "Delete location?",
            isPresented: Binding(
                get: { pendingDeleteLocation != nil },
                set: { if !$0 { pendingDeleteLocation = nil } }
            ),
            presenting: pendingDeleteLocation
        ) { location in
            Button("Delete", role: .destructive) {
                locationsManager.removeLocation(location)
                pendingDeleteLocation = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteLocation = nil
            }
        } message: { location in
            Text("\"\(location.name)\" will be removed from your saved locations. This cannot be undone.")
        }
        .onAppear {
            // Sync LocationsManager with current GPS state when view appears
            if weatherService.useGPS {
                locationsManager.selectCurrentLocation()
            }
        }
    }

    private var addLocationSheet: some View {
        NavigationView {
            List {
                Button {
                    addLocationMode = .manual
                } label: {
                    Label("Enter Custom Coordinates", systemImage: "number.square")
                }
                Button {
                    addLocationMode = .search
                } label: {
                    Label("Search City/Town", systemImage: "magnifyingglass")
                }
                Button {
                    addLocationMode = .map
                } label: {
                    Label("Select on Map", systemImage: "map")
                }
            }
            .navigationTitle("Add Location")
            #if os(iOS)
            .navigationBarItems(leading: Button("Cancel") { showingAddLocationSheet = false })
            #endif
            .sheet(item: $addLocationMode) { mode in
                switch mode {
                case .manual:
                    manualCoordinatesSheet
                case .search:
                    citySearchSheet
                case .map:
                    mapSelectionSheet
                }
            }
        }
    }
    
    // Map selection sheet
    private var mapSelectionSheet: some View {
        LocationPickerView(
            selectedLocation: $mapSelectedLocation,
            selectedLocationName: $mapSelectedLocationName
        )
        .onDisappear {
            // When the map picker is dismissed, check if a location was selected
            if let location = mapSelectedLocation {
                let lat = location.latitude
                let lon = location.longitude
                
                // Validate coordinates
                let validationResult = CoordinateValidator.validate(latitude: lat, longitude: lon)
                if validationResult.isValid {
                    let validatedLat = validationResult.normalizedLatitude ?? lat
                    let validatedLon = validationResult.normalizedLongitude ?? lon
                    
                    // Use the geocoded name or a default name
                    let locationName = mapSelectedLocationName ?? "Selected Location"

                    requestAddLocationPreview(
                        name: locationName,
                        latitude: validatedLat,
                        longitude: validatedLon
                    )
                    addLocationMode = nil
                    mapSelectedLocation = nil
                    mapSelectedLocationName = nil
                    showingAddLocationSheet = false
                } else {
                    alertMessage = validationResult.errorMessage ?? "Invalid coordinates. Please try again."
                    showingAlert = true
                }
            }
        }
    }
    
    private var manualCoordinatesSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Form {
                    Section {
                        TextField("Location Name", text: $newLocationName)
                        #if os(iOS)
                        CoordinateTextField(text: $newLatitude, placeholder: "Latitude")
                            .frame(height: 36)
                        CoordinateTextField(text: $newLongitude, placeholder: "Longitude")
                            .frame(height: 36)
                        #else
                        TextField("Latitude", text: $newLatitude)
                        TextField("Longitude", text: $newLongitude)
                        #endif
                        
                        // Real-time validation feedback
                        if let validationMessage = getCoordinateValidationMessage() {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(validationMessage)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        } else if !newLatitude.isEmpty && !newLongitude.isEmpty && Double(newLatitude) != nil && Double(newLongitude) != nil {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Coordinates are valid")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Enter Coordinates")
                    } footer: {
                        Text("Latitude: -90 to 90, Longitude: -180 to 180")
                            .font(.caption)
                    }
                }
                Button(action: {
                    if let lat = Double(newLatitude), let lon = Double(newLongitude), !newLocationName.isEmpty {
                        // Validate coordinates before adding location
                        let validationResult = CoordinateValidator.validate(latitude: lat, longitude: lon)
                        if validationResult.isValid {
                            // Use the new validated coordinates
                            let validatedLat = validationResult.normalizedLatitude ?? lat
                            let validatedLon = validationResult.normalizedLongitude ?? lon
                            
                            requestAddLocationPreview(
                                name: newLocationName,
                                latitude: validatedLat,
                                longitude: validatedLon
                            )
                            showingAddLocationSheet = false
                            addLocationMode = nil
                            newLocationName = ""
                            newLatitude = ""
                            newLongitude = ""
                        } else {
                            alertMessage = validationResult.errorMessage ?? "Invalid coordinates. Please check your values and try again."
                            showingAlert = true
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Save")
                    }
                    .padding()
                    .frame(maxWidth: 220)
                    .background(canSave ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!canSave)
                .padding(.top, 8)
            }
            .navigationTitle("Custom Coordinates")
            #if os(iOS)
            .navigationBarItems(leading: Button("Cancel") {
                addLocationMode = nil
            })
            #endif
        }
    }
    
    // Helper function to get validation message for current coordinate input
    private func getCoordinateValidationMessage() -> String? {
        guard !newLatitude.isEmpty || !newLongitude.isEmpty else { return nil }
        
        if newLatitude.isEmpty {
            return "Latitude is required"
        }
        
        if newLongitude.isEmpty {
            return "Longitude is required"
        }
        
        guard let lat = Double(newLatitude) else {
            return "Latitude must be a valid number"
        }
        
        guard let lon = Double(newLongitude) else {
            return "Longitude must be a valid number"
        }
        
        let result = CoordinateValidator.validate(latitude: lat, longitude: lon)
        return result.isValid ? nil : result.errorMessage
    }
    
    // Helper function to determine if save button should be enabled
    private var canSave: Bool {
        guard !newLocationName.isEmpty,
              let lat = Double(newLatitude),
              let lon = Double(newLongitude) else {
            return false
        }
        
        return CoordinateValidator.validate(latitude: lat, longitude: lon).isValid
    }
    
    private var citySearchSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                TextField("Search for a city or town", text: $citySearchQuery)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: citySearchQuery) { newValue in
                        if newValue.count >= 2 {
                            citySearchCompleter.queryFragment = newValue
                            citySearchError = nil
                        } else {
                            citySearchResults = []
                            citySearchError = nil
                        }
                    }
                if let error = citySearchError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }
                if let selected = selectedSearchCompletion, let coordinate = citySearchCoordinate {
                    VStack(spacing: 12) {
                        Text(selected.title)
                            .font(.headline)
                        Text(selected.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Lat: \(formatCoordinate(coordinate.latitude)), Lon: \(formatCoordinate(coordinate.longitude))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Save") {
                            let name = selected.title
                            let lat = coordinate.latitude
                            let lon = coordinate.longitude
                            
                            // Validate coordinates before adding location
                            let validationResult = CoordinateValidator.validate(latitude: lat, longitude: lon)
                            if validationResult.isValid {
                                // Use the new validated coordinates
                                let validatedLat = validationResult.normalizedLatitude ?? lat
                                let validatedLon = validationResult.normalizedLongitude ?? lon
                                
                                requestAddLocationPreview(
                                    name: name,
                                    latitude: validatedLat,
                                    longitude: validatedLon
                                )
                                showingAddLocationSheet = false
                                addLocationMode = nil
                                citySearchQuery = ""
                                citySearchResults = []
                                selectedSearchCompletion = nil
                                citySearchCoordinate = nil
                                citySearchError = nil
                            } else {
                                alertMessage = validationResult.errorMessage ?? "Invalid coordinates. Please try again."
                                showingAlert = true
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List(citySearchResults, id: \.self) { completion in
                        VStack(alignment: .leading) {
                            Text(completion.title)
                            if !completion.subtitle.isEmpty {
                                Text(completion.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isSearchingCity = true
                            citySearchError = nil
                            let request = MKLocalSearch.Request(completion: completion)
                            let search = MKLocalSearch(request: request)
                            search.start { response, error in
                                isSearchingCity = false
                                if let error = error {
                                    citySearchError = error.localizedDescription
                                    return
                                }
                                if let item = response?.mapItems.first {
                                    selectedSearchCompletion = completion
                                    citySearchCoordinate = item.placemark.coordinate
                                } else {
                                    citySearchError = "No location found."
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search City/Town")
            #if os(iOS)
            .navigationBarItems(leading: Button("Cancel") {
                addLocationMode = nil
            })
            #endif
            .onAppear {
                citySearchCompleter.resultTypes = .address
                let delegate = CitySearchCompleterDelegate(
                    onResults: { results in
                        citySearchResults = results
                    },
                    onError: { error in
                        citySearchError = error
                    }
                )
                citySearchCompleter.delegate = delegate
                citySearchCompleterDelegate = delegate
            }
        }
    }
    
    private func formatCoordinate(_ value: Double) -> String {
        return String(format: "%.5g", value)
    }
}

// MARK: Weather Sources Settings
struct WeatherSourcesSettingsView: View {
    @ObservedObject var weatherService: WeatherService
    @Binding var wuApiKey: String
    @Binding var stationID: String
    @Binding var owmApiKey: String
    @Binding var useOpenMeteoAsDefault: Bool
    @Binding var disableAPIKeys: Bool
    @ObservedObject var locationsManager: SavedLocationsManager
    #if os(iOS)
    @FocusState var focusedField: SettingsView.Field?
    #endif
    @StateObject private var healthMonitor = APIKeyHealthMonitor.shared
    let saveAPIKeys: () -> Void
    let loadAPIKeys: () -> Void

    var body: some View {
        List {
            // Aggregate health banner – only shown when at least one
            // stored key is known to be invalid.
            if healthMonitor.hasAnyBlockingIssue {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "key.slash")
                                .foregroundColor(.red)
                            Text("One or more API keys are no longer accepted by the provider.")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        ForEach(healthMonitor.blockingServices, id: \.rawValue) { service in
                            HStack(spacing: 8) {
                                APIKeyHealthStatusBadge(
                                    entry: healthMonitor.entry(for: service),
                                    compact: true
                                )
                                Text("\(service.displayName) – re-enter a valid key to restore this source.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // API Keys Disabled Warning
            if disableAPIKeys {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            Text("API Keys Disabled")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                        
                        Text("Weather Underground and OpenWeatherMap API keys are currently disabled. Only Apple Weather and Open-Meteo are available.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        
                        NavigationLink {
                            LocationsSettingsView(
                                locationsManager: locationsManager,
                                disableAPIKeys: $disableAPIKeys,
                                weatherService: weatherService
                            )
                        } label: {
                            HStack {
                                Text("Enable API Keys in Locations")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Weather Underground
            Section {
                #if os(iOS)
                APIKeyTextField(
                    text: $wuApiKey,
                    placeholder: "API Key",
                    isFocused: focusedField == .wuApiKey,
                    onDone: { focusedField = nil }
                )
                .frame(height: 36)
                .disabled(disableAPIKeys)
                .opacity(disableAPIKeys ? 0.5 : 1.0)
                
                APIKeyTextField(
                    text: $stationID,
                    placeholder: "Station ID",
                    isFocused: focusedField == .stationID,
                    onDone: { focusedField = nil }
                )
                .frame(height: 36)
                .disabled(disableAPIKeys)
                .opacity(disableAPIKeys ? 0.5 : 1.0)
                #else
                TextField("API Key", text: $wuApiKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(disableAPIKeys)
                    .opacity(disableAPIKeys ? 0.5 : 1.0)
                
                TextField("Station ID", text: $stationID)
                    .textFieldStyle(.roundedBorder)
                    .disabled(disableAPIKeys)
                    .opacity(disableAPIKeys ? 0.5 : 1.0)
                #endif
            } header: {
                Label("Weather Underground", systemImage: "antenna.radiowaves.left.and.right")
            } footer: {
                Text("Personal weather station data")
            }

            // Weather Underground health card
            Section {
                APIKeyHealthCard(
                    monitor: healthMonitor,
                    service: .weatherUnderground,
                    weatherService: weatherService
                )
            } header: {
                Text("Key health")
            }

            // OpenWeatherMap
            Section {
                #if os(iOS)
                APIKeyTextField(
                    text: $owmApiKey,
                    placeholder: "API Key",
                    isFocused: focusedField == .owmApiKey,
                    onDone: { focusedField = nil }
                )
                .frame(height: 36)
                .disabled(disableAPIKeys)
                .opacity(disableAPIKeys ? 0.5 : 1.0)
                #else
                TextField("API Key", text: $owmApiKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(disableAPIKeys)
                    .opacity(disableAPIKeys ? 0.5 : 1.0)
                #endif
            } header: {
                Label("OpenWeatherMap", systemImage: "globe")
            } footer: {
                Text("Detailed forecast data")
            }

            // OpenWeatherMap health card
            Section {
                APIKeyHealthCard(
                    monitor: healthMonitor,
                    service: .openWeatherMap,
                    weatherService: weatherService
                )
            } header: {
                Text("Key health")
            }

            // Apple WeatherKit
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Apple Weather")
                            .font(.headline)
                        
                        if #available(iOS 16.0, macOS 13.0, *) {
                            Text("Built-in (Default)")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("Requires iOS 16+")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    if #available(iOS 16.0, macOS 13.0, *) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Open-Meteo
            Section {
                Toggle("Use as default", isOn: $useOpenMeteoAsDefault)
                    .onChange(of: useOpenMeteoAsDefault) { _ in
                        Task {
                            await weatherService.fetchWeather(calledFrom: "WeatherSourcesSettings.useOpenMeteoAsDefault.onChange")
                        }
                    }
            } header: {
                Label("Open-Meteo", systemImage: "cloud.sun.fill")
            } footer: {
                Text("Free alternative")
            }
            
            // Save button
            Section {
                Button(action: saveAPIKeys) {
                    HStack {
                        Spacer()
                        Label("Save API Keys", systemImage: "key.fill")
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(disableAPIKeys)
                .opacity(disableAPIKeys ? 0.5 : 1.0)
            }
        }
        .navigationTitle("Weather Data")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            loadAPIKeys()
        }
    }
}

// MARK: Preferences Settings
struct PreferencesSettingsView: View {
    @EnvironmentObject private var customisationRegistry: CustomisationRegistry

    @Binding var unitSystem: String
    @Binding var colorScheme: String
    @Binding var forecastDays: Int
    @Binding var displayMode: String
    @Binding var useOpenMeteoAsDefault: Bool
    @Binding var owmApiKey: String
    @ObservedObject var weatherService: WeatherService

    // Existing v1 knobs (still @AppStorage — bridged).
    @AppStorage("showHamburgerMenu") private var showHamburgerMenu: Bool = true

    // v2 — every new knob below is bridged through the registry.
    // `@AppStorage` reads the bridged UserDefaults key; `.onChange`
    // forwards writes back into the registry so the profile, the
    // widget, and any future subscribers stay in sync.
    @AppStorage("preferredDataSource") private var preferredDataSource: String = PreferredDataSource.auto.rawValue
    @AppStorage("refreshCadence") private var refreshCadence: String = RefreshCadence.normal.rawValue
    @AppStorage("backgroundRefreshEnabled") private var backgroundRefreshEnabled: Bool = true
    @AppStorage("temperaturePrecision") private var temperaturePrecision: Int = 1
    @AppStorage("windPrecision") private var windPrecision: Int = 0
    @AppStorage("pressurePrecision") private var pressurePrecision: Int = 0
    @AppStorage("hourlyHours") private var hourlyHours: Int = 24
    @AppStorage("cardDensity") private var cardDensity: String = CardDensity.regular.rawValue
    @AppStorage("swipeBetweenLocations") private var swipeBetweenLocations: Bool = true
    @AppStorage("showLocationHeader") private var showLocationHeader: Bool = true
    @AppStorage("previewBeforeChangingLocation") private var previewBeforeChangingLocation: Bool = true
    @AppStorage("showHeroLastUpdated") private var showHeroLastUpdated: Bool = false
    @AppStorage("compactCardsInLandscape") private var compactCardsInLandscape: Bool = true
    @AppStorage("showLocationLabel") private var showLocationLabel: Bool = true

    let unitSystems: [String]
    let colorSchemes: [String]
    let forecastDayOptions: [Int]
    let displayModes: [String]

    // Computed property to determine if using Apple Weather
    private var isUsingAppleWeather: Bool {
        !useOpenMeteoAsDefault && owmApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Available forecast options (limit to 10 for Apple Weather)
    private var availableForecastOptions: [Int] {
        if isUsingAppleWeather {
            return forecastDayOptions.filter { $0 <= 10 }
        }
        return forecastDayOptions
    }

    var body: some View {
        List {
            Section {
                Picker("Temperature Unit", selection: $unitSystem) {
                    ForEach(unitSystems, id: \.self) { unit in
                        Text(unit).tag(unit)
                    }
                }
                .onChange(of: unitSystem) { newValue in
                    weatherService.unitSystem = newValue
                    customisationRegistry.set(\.data.unitSystem, newValue)
                }
            } header: {
                Label("Units", systemImage: "thermometer")
            }

            Section {
                Picker("Forecast Length", selection: $forecastDays) {
                    ForEach(availableForecastOptions, id: \.self) { days in
                        Text("\(days) Days").tag(days)
                    }
                }
                .onChange(of: forecastDays) { newValue in
                    // Auto-adjust if exceeds limit
                    if isUsingAppleWeather && newValue > 10 {
                        forecastDays = 10
                    }
                    Task {
                        await weatherService.fetchForecasts()
                    }
                    customisationRegistry.set(\.layout.forecastDays, newValue)
                }
            } header: {
                Label("Forecast", systemImage: "calendar")
            } footer: {
                if isUsingAppleWeather {
                    Text("Apple Weather limits forecasts to 10 days")
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Picker("Display Mode", selection: $displayMode) {
                    ForEach(displayModes, id: \.self) { mode in
                        Text(mode).tag(mode)
                    }
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.segmented)
                #endif
            } header: {
                Label("View", systemImage: "rectangle.split.3x1")
            }

            Section {
                Picker("Preferred Source", selection: $preferredDataSource) {
                    ForEach(PreferredDataSource.allCases, id: \.self) { src in
                        Text(src.rawValue.capitalized).tag(src.rawValue)
                    }
                }
                Picker("Refresh Cadence", selection: $refreshCadence) {
                    ForEach(RefreshCadence.allCases, id: \.self) { cadence in
                        Text(cadence.rawValue.capitalized).tag(cadence.rawValue)
                    }
                }
                Toggle("Background Refresh", isOn: $backgroundRefreshEnabled)
            } header: {
                Label("Data & Refresh", systemImage: "arrow.triangle.2.circlepath")
            } footer: {
                Text("Aggressive refresh uses more battery; Battery Saver throttles network calls.")
            }
            .onChange(of: preferredDataSource) { newValue in
                if let parsed = PreferredDataSource(rawValue: newValue) {
                    customisationRegistry.set(\.data.preferredDataSource, parsed)
                }
            }
            .onChange(of: refreshCadence) { newValue in
                if let parsed = RefreshCadence(rawValue: newValue) {
                    customisationRegistry.set(\.data.refreshCadence, parsed)
                }
            }
            .onChange(of: backgroundRefreshEnabled) { newValue in
                customisationRegistry.set(\.data.backgroundRefreshEnabled, newValue)
            }

            Section {
                Stepper(value: $temperaturePrecision, in: 0...2) {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text("\(temperaturePrecision) dp")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(value: $windPrecision, in: 0...1) {
                    HStack {
                        Text("Wind")
                        Spacer()
                        Text("\(windPrecision) dp")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(value: $pressurePrecision, in: 0...2) {
                    HStack {
                        Text("Pressure")
                        Spacer()
                        Text("\(pressurePrecision) dp")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Label("Decimal Places", systemImage: "number")
            } footer: {
                Text("How many digits to show after the decimal point for each kind of value.")
            }
            .onChange(of: temperaturePrecision) { newValue in
                customisationRegistry.set(\.data.temperaturePrecision, newValue)
            }
            .onChange(of: windPrecision) { newValue in
                customisationRegistry.set(\.data.windPrecision, newValue)
            }
            .onChange(of: pressurePrecision) { newValue in
                customisationRegistry.set(\.data.pressurePrecision, newValue)
            }

            Section {
                Toggle(isOn: $showHamburgerMenu) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Location Menu")
                            .font(.body)
                        Text("Display the hamburger menu in the top-right corner of the main weather screen for quick location switching.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: showHamburgerMenu) { newValue in
                    customisationRegistry.set(\.layout.showHamburgerMenu, newValue)
                }
                Toggle(isOn: $showLocationHeader) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Location Header")
                            .font(.body)
                        Text("Display “Weather for X” above the hero card.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: showLocationHeader) { newValue in
                    customisationRegistry.set(\.layout.showLocationHeader, newValue)
                }
                Toggle(isOn: $previewBeforeChangingLocation) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview Before Changing Location")
                            .font(.body)
                        Text("Show a full-screen weather preview before switching or adding a location.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: previewBeforeChangingLocation) { newValue in
                    customisationRegistry.set(\.layout.previewBeforeChangingLocation, newValue)
                }
                Toggle(isOn: $showHeroLastUpdated) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Hero Last Updated")
                            .font(.body)
                        Text("Display the “Last updated” button on the hero card.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: showHeroLastUpdated) { newValue in
                    customisationRegistry.set(\.layout.showHeroLastUpdated, newValue)
                }
                Toggle(isOn: $swipeBetweenLocations) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Swipe Between Locations")
                            .font(.body)
                        Text("Swipe horizontally on the home screen to switch saved locations.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: swipeBetweenLocations) { newValue in
                    customisationRegistry.set(\.layout.swipeBetweenLocations, newValue)
                }
                Toggle(isOn: $compactCardsInLandscape) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Compact Cards in Landscape")
                            .font(.body)
                        Text("Shrink card padding when the device is rotated sideways.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: compactCardsInLandscape) { newValue in
                    customisationRegistry.set(\.layout.compactCardsInLandscape, newValue)
                }
                Toggle(isOn: $showLocationLabel) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Always Show Location Label")
                            .font(.body)
                        Text("Show the location name on the hero card even after scrolling.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: showLocationLabel) { newValue in
                    customisationRegistry.set(\.data.showLocationLabel, newValue)
                }
            } header: {
                Label("Interface", systemImage: "rectangle.grid.2x2")
            } footer: {
                Text("Disable for a more minimalistic experience. You can still manage locations from Settings → Locations.")
            }

            Section {
                Picker("Hourly Window", selection: $hourlyHours) {
                    Text("12 hours").tag(12)
                    Text("24 hours").tag(24)
                    Text("48 hours").tag(48)
                }
                Picker("Card Density", selection: $cardDensity) {
                    ForEach(CardDensity.allCases, id: \.self) { d in
                        Text(d.rawValue.capitalized).tag(d.rawValue)
                    }
                }
            } header: {
                Label("Forecast Detail", systemImage: "rectangle.split.3x1.fill")
            }
            .onChange(of: hourlyHours) { newValue in
                customisationRegistry.set(\.layout.hourlyHours, newValue)
            }
            .onChange(of: cardDensity) { newValue in
                if let parsed = CardDensity(rawValue: newValue) {
                    customisationRegistry.set(\.layout.cardDensity, parsed)
                }
            }
        }
        .navigationTitle("Preferences")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: Appearance Settings
struct AppearanceSettingsView: View {
    @EnvironmentObject private var customisationRegistry: CustomisationRegistry
    @EnvironmentObject var storeManager: StoreManager

    // Existing v1 knobs (still @AppStorage — bridged).
    @AppStorage("colorScheme") private var colorScheme = "system"
    @AppStorage("accentColor") private var accentColor = "blue"

    // v2 — every new knob below is bridged through the registry.
    @AppStorage("cardStyle") private var cardStyle: String = CardStyle.glass.rawValue
    @AppStorage("cornerRadius") private var cornerRadius: Double = 16
    @AppStorage("cardOpacity") private var cardOpacity: Double = 0.6
    @AppStorage("typography") private var typography: String = TypographyFamily.system.rawValue
    @AppStorage("weatherIconStyle") private var weatherIconStyle: String = WeatherIconStyle.multicolor.rawValue
    @AppStorage("symbolSet") private var symbolSet: String = SymbolVariant.filled.rawValue
    @AppStorage("iconSizeMultiplier") private var iconSizeMultiplier: Double = 1.0
    @AppStorage("lottiePlaybackSpeed") private var lottiePlaybackSpeed: Double = 1.0
    @AppStorage("lottieLoopMode") private var lottieLoopMode: String = AnimationLoopMode.loop.rawValue
    @AppStorage("lottieAnimationSet") private var lottieAnimationSet: String = LottieAnimationSet.bundled.rawValue
    @AppStorage("overlayOpacity") private var overlayOpacity: Double = 0.28
    @AppStorage("backgroundTimeOfDayRule") private var backgroundTimeOfDayRule: String = TimeOfDayRule.none.rawValue

    // Available accent colors
    private let accentColors: [(name: String, color: Color, icon: String)] = [
        ("Blue", .blue, "drop.fill"),
        ("Purple", .purple, "star.fill"),
        ("Pink", .pink, "heart.fill"),
        ("Red", .red, "flame.fill"),
        ("Orange", .orange, "sun.max.fill"),
        ("Yellow", .yellow, "bolt.fill"),
        ("Green", .green, "leaf.fill"),
        ("Teal", .teal, "drop.triangle.fill"),
        ("Cyan", .cyan, "wind"),
        ("Indigo", .indigo, "moon.stars.fill")
    ]

    var body: some View {
        List {
            Section {
                Picker("Theme", selection: $colorScheme) {
                    Label("System", systemImage: "gear").tag("system")
                    Label("Light", systemImage: "sun.max").tag("light")
                    Label("Dark", systemImage: "moon").tag("dark")
                }
                .onChange(of: colorScheme) { newValue in
                    customisationRegistry.set(\.visual.colorScheme, newValue)
                }
            } header: {
                Label("Theme", systemImage: "circle.lefthalf.filled")
            } footer: {
                Text("Choose whether the app follows your system appearance or stays permanently light or dark.")
            }

            Section {
                ForEach(accentColors, id: \.name) { colorOption in
                    Button(action: {
                        accentColor = colorOption.name.lowercased()
                    }) {
                        HStack {
                            Image(systemName: colorOption.icon)
                                .foregroundColor(colorOption.color)
                                .frame(width: 24)

                            Text(colorOption.name)
                                .foregroundColor(.primary)

                            Spacer()

                            if accentColor == colorOption.name.lowercased() {
                                Image(systemName: "checkmark")
                                    .foregroundColor(colorOption.color)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            } header: {
                Label("Accent Color", systemImage: "paintpalette")
            } footer: {
                Text("The highlight colour used for buttons, links, and selected controls throughout the app.")
            }
            .onChange(of: accentColor) { newValue in
                customisationRegistry.set(\.visual.accentColor, ColourToken(rawString: newValue))
            }

            // The full Card customisation surface now lives
            // in `CardSettingsView` so the user gets a live
            // preview plus all the new colour / border /
            // shadow / tint / glass / shadow controls. The
            // legacy `cardStyle` / `cornerRadius` / `cardOpacity`
            // `@AppStorage` bindings are still loaded here so
            // the v1 settings row keeps working as a quick
            // toggle for the most-used options.
            Section {
                NavigationLink {
                    CardSettingsView()
                } label: {
                    HStack {
                        Label("Card Style…", systemImage: "rectangle.stack.fill")
                        Spacer()
                        Text("\(cardStyle.capitalized) · \(Int(cornerRadius)) pt")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Label("Cards", systemImage: "rectangle.stack.fill")
            } footer: {
                Text("Tap the row to customise every card in the app: style, colour, glass, border, shadow, and tint, with a live preview.")
            }
            .onChange(of: cardStyle) { newValue in
                if let parsed = CardStyle(rawValue: newValue) {
                    customisationRegistry.set(\.visual.cardStyle, parsed)
                }
            }
            .onChange(of: cornerRadius) { newValue in
                customisationRegistry.set(\.visual.cornerRadius, newValue)
            }
            .onChange(of: cardOpacity) { newValue in
                customisationRegistry.set(\.visual.cardOpacity, newValue)
            }

            Section {
                Picker("Typography", selection: $typography) {
                    ForEach(TypographyFamily.allCases, id: \.self) { family in
                        Text(family.rawValue.capitalized).tag(family.rawValue)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Label("Typography", systemImage: "textformat.alt")
            } footer: {
                Text("Pick the font family that suits the look you’re going for. System is the iOS default.")
            }
            .onChange(of: typography) { newValue in
                if let parsed = TypographyFamily(rawValue: newValue) {
                    customisationRegistry.set(\.visual.typography, parsed)
                }
            }

            Section {
                Picker("Icon Style", selection: $weatherIconStyle) {
                    ForEach(WeatherIconStyle.allCases, id: \.self) { s in
                        Text(s.rawValue.capitalized).tag(s.rawValue)
                    }
                }
                Picker("Symbol Variant", selection: $symbolSet) {
                    ForEach(SymbolVariant.allCases, id: \.self) { v in
                        Text(v.rawValue.capitalized).tag(v.rawValue)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Icon Size")
                        Spacer()
                        Text(String(format: "%.2f×", iconSizeMultiplier))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $iconSizeMultiplier, in: 0.7...1.6, step: 0.05)
                }
            } header: {
                Label("Icons", systemImage: "cloud.sun.fill")
            } footer: {
                Text("Control the look of weather icons — colour style, filled vs outline symbols, and their size.")
            }
            .onChange(of: weatherIconStyle) { newValue in
                if let parsed = WeatherIconStyle(rawValue: newValue) {
                    customisationRegistry.set(\.iconography.weatherIconStyle, parsed)
                }
            }
            .onChange(of: symbolSet) { newValue in
                if let parsed = SymbolVariant(rawValue: newValue) {
                    customisationRegistry.set(\.iconography.symbolSet, parsed)
                }
            }
            .onChange(of: iconSizeMultiplier) { newValue in
                customisationRegistry.set(\.iconography.iconSizeMultiplier, newValue)
            }

            Section {
                Picker("Animation Set", selection: $lottieAnimationSet) {
                    ForEach(LottieAnimationSet.allCases, id: \.self) { s in
                        Text(s.rawValue.capitalized).tag(s.rawValue)
                    }
                }
                Picker("Loop Mode", selection: $lottieLoopMode) {
                    ForEach(AnimationLoopMode.allCases, id: \.self) { m in
                        Text(m.rawValue == "loop" ? "Loop forever" : "Play once").tag(m.rawValue)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Playback Speed")
                        Spacer()
                        Text(String(format: "%.2f×", lottiePlaybackSpeed))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $lottiePlaybackSpeed, in: 0.25...2.0, step: 0.05)
                }
            } header: {
                Label("Animations", systemImage: "play.rectangle.fill")
            } footer: {
                Text("Pick which animated icon set to use and how fast it plays.")
            }
            .onChange(of: lottieAnimationSet) { newValue in
                if let parsed = LottieAnimationSet(rawValue: newValue) {
                    customisationRegistry.set(\.iconography.lottieAnimationSet, parsed)
                }
            }
            .onChange(of: lottieLoopMode) { newValue in
                if let parsed = AnimationLoopMode(rawValue: newValue) {
                    customisationRegistry.set(\.iconography.lottieLoopMode, parsed)
                }
            }
            .onChange(of: lottiePlaybackSpeed) { newValue in
                customisationRegistry.set(\.iconography.lottiePlaybackSpeed, newValue)
            }

            Section {
                BackgroundSettingsButton()
                    .environmentObject(storeManager)
            } header: {
                Label("Background", systemImage: "photo")
            } footer: {
                Text("Set a solid colour, gradient, or your own photo as the app background.")
            }

            Section {
                PalettePickerRow()
                ChartSkinPickerRow()
            } header: {
                Label("Cosmetic Colours", systemImage: "paintpalette.fill")
            } footer: {
                Text("Owned cosmetic palettes and chart skins. Locked rows open the cosmetics store when tapped.")
            }

            Section {
                Picker("Time-of-Day Rule", selection: $backgroundTimeOfDayRule) {
                    ForEach(TimeOfDayRule.allCases, id: \.self) { r in
                        Text(r.rawValue == "none" ? "Off"
                             : r.rawValue == "dawnDayDuskNight" ? "Dawn / Day / Dusk / Night"
                             : "Hour Range").tag(r.rawValue)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Overlay Opacity")
                        Spacer()
                        Text(String(format: "%.0f%%", overlayOpacity * 100))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $overlayOpacity, in: 0...0.7, step: 0.05)
                }
            } header: {
                Label("Background Behaviour", systemImage: "clock.fill")
            } footer: {
                Text("Time-of-Day Rule swaps the background image to match the current lighting; Overlay Opacity dims the photo so text stays readable.")
            }
            .onChange(of: backgroundTimeOfDayRule) { newValue in
                if let parsed = TimeOfDayRule(rawValue: newValue) {
                    customisationRegistry.set(\.background.timeOfDayRule, parsed)
                }
            }
            .onChange(of: overlayOpacity) { newValue in
                customisationRegistry.set(\.background.overlayOpacity, newValue)
            }
        }
        .navigationTitle("Appearance")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: Behaviour Settings
//
// v2 — every knob in `BehaviourSpec` that wasn't already
// surfaced in the Accessibility or Preferences tabs lives here.
// Splitting the two halves keeps both source files small and the
// Settings tree scannable: Accessibility → accessibility aids;
// Behaviour → haptics, gestures, alerts, sounds, experimental.
struct BehaviourSettingsView: View {
    @EnvironmentObject private var customisationRegistry: CustomisationRegistry

    // v2 — every @AppStorage below is bridged through the
    // registry via `.onChange` so the registry stays the single
    // source of truth for all customisation state.

    // MARK: - Haptics
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    @AppStorage("hapticIntensity") private var hapticIntensity: String = HapticIntensity.medium.rawValue
    @AppStorage("hapticOnSelection") private var hapticOnSelection = true
    @AppStorage("tapticOnRefresh") private var tapticOnRefresh = true
    @AppStorage("vibrateOnPullToRefresh") private var vibrateOnPullToRefresh = true

    // MARK: - Gestures
    @AppStorage("pullToRefresh") private var pullToRefresh = true
    @AppStorage("tapDayToExpand") private var tapDayToExpand = true
    @AppStorage("longPressToCustomise") private var longPressToCustomise = true
    @AppStorage("confirmDestructive") private var confirmDestructive = true
    @AppStorage("confirmQuit") private var confirmQuit = false

    // MARK: - Alerts & Sounds
    @AppStorage("weatherAlertSounds") private var weatherAlertSounds = true
    @AppStorage("rainAlertsEnabled") private var rainAlertsEnabled = true
    @AppStorage("severeWeatherAlertsEnabled") private var severeWeatherAlertsEnabled = true
    @AppStorage("aiAlertSummariesEnabled") private var aiAlertSummariesEnabled = true
    @AppStorage("quietHoursStart") private var quietHoursStart: Int = 22
    @AppStorage("quietHoursEnd") private var quietHoursEnd: Int = 7
    @AppStorage("refreshSound") private var refreshSound = false

    // MARK: - Experimental
    @AppStorage("experimentalNewHeroLayout") private var experimentalNewHeroLayout = false
    @AppStorage("experimentalSwipeRefresh") private var experimentalSwipeRefresh = false

    private var quietHoursEnabled: Binding<Bool> {
        Binding(
            get: { customisationRegistry.profile.knobs.behaviour.quietHoursStart != nil },
            set: { newValue in
                if newValue {
                    customisationRegistry.set(\.behaviour.quietHoursStart, quietHoursStart)
                    customisationRegistry.set(\.behaviour.quietHoursEnd, quietHoursEnd)
                } else {
                    customisationRegistry.set(\.behaviour.quietHoursStart, Int?.none)
                    customisationRegistry.set(\.behaviour.quietHoursEnd, Int?.none)
                }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $enableHapticFeedback) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                        Text("Vibrate on interactions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Picker("Intensity", selection: $hapticIntensity) {
                    ForEach(HapticIntensity.allCases, id: \.self) { i in
                        Text(i.rawValue.capitalized).tag(i.rawValue)
                    }
                }
                .disabled(!enableHapticFeedback)
                Toggle("Haptic on Selection", isOn: $hapticOnSelection)
                Toggle("Taptic on Refresh", isOn: $tapticOnRefresh)
                Toggle("Vibrate on Pull-to-Refresh", isOn: $vibrateOnPullToRefresh)
            } header: {
                Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
            } footer: {
                Text("Pull-to-refresh haptics cannot be fully disabled (iOS limitation).")
            }
            .onChange(of: enableHapticFeedback) { customisationRegistry.set(\.behaviour.enableHapticFeedback, $0) }
            .onChange(of: hapticIntensity) { newValue in
                if let parsed = HapticIntensity(rawValue: newValue) {
                    customisationRegistry.set(\.behaviour.hapticIntensity, parsed)
                }
            }
            .onChange(of: hapticOnSelection) { customisationRegistry.set(\.accessibility.hapticOnSelection, $0) }
            .onChange(of: tapticOnRefresh) { customisationRegistry.set(\.accessibility.tapticOnRefresh, $0) }
            .onChange(of: vibrateOnPullToRefresh) { customisationRegistry.set(\.behaviour.vibrateOnPullToRefresh, $0) }

            Section {
                Toggle("Pull to Refresh", isOn: $pullToRefresh)
                Toggle("Tap Day to Expand", isOn: $tapDayToExpand)
                Toggle("Long-Press to Customise", isOn: $longPressToCustomise)
                Toggle("Confirm Destructive Actions", isOn: $confirmDestructive)
                Toggle("Confirm Before Quitting", isOn: $confirmQuit)
            } header: {
                Label("Gestures", systemImage: "hand.tap.fill")
            } footer: {
                Text("Turn these off if a particular gesture is getting in the way. Long-Press to Customise works with the inline “Customise this section” menu on the home screen.")
            }
            .onChange(of: pullToRefresh) { customisationRegistry.set(\.behaviour.pullToRefresh, $0) }
            .onChange(of: tapDayToExpand) { customisationRegistry.set(\.behaviour.tapDayToExpand, $0) }
            .onChange(of: longPressToCustomise) { customisationRegistry.set(\.behaviour.longPressToCustomise, $0) }
            .onChange(of: confirmDestructive) { customisationRegistry.set(\.behaviour.confirmDestructive, $0) }
            .onChange(of: confirmQuit) { customisationRegistry.set(\.behaviour.confirmQuit, $0) }

            Section {
                Toggle("Rain Alerts", isOn: $rainAlertsEnabled)
                Toggle("Severe Weather Alerts", isOn: $severeWeatherAlertsEnabled)
                VStack(alignment: .leading, spacing: 2) {
                    Toggle("AI Alert Summaries", isOn: $aiAlertSummariesEnabled)
                        .disabled(!WeatherAlertExplainer.isSupported)
                    if !WeatherAlertExplainer.isSupported {
                        Text("Requires a device with Apple Intelligence enabled.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("Weather Alert Sounds", isOn: $weatherAlertSounds)
                Toggle("Enable Quiet Hours", isOn: quietHoursEnabled)
                if customisationRegistry.profile.knobs.behaviour.quietHoursStart != nil {
                    Stepper(value: $quietHoursStart, in: 0...23) {
                        HStack {
                            Text("Start")
                            Spacer()
                            Text(String(format: "%02d:00", quietHoursStart))
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $quietHoursEnd, in: 0...23) {
                        HStack {
                            Text("End")
                            Spacer()
                            Text(String(format: "%02d:00", quietHoursEnd))
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Toggle("Refresh Sound", isOn: $refreshSound)
            } header: {
                Label("Alerts & Sounds", systemImage: "speaker.wave.3.fill")
            } footer: {
                Text("Rain alerts use Open-Meteo hourly forecasts. Severe alerts use Apple WeatherKit where available, or BOM in Australia. AI Alert Summaries use Apple Intelligence on-device to explain warnings in plain language. Quiet Hours mutes notification sounds during a daily time range.")
            }
            .onChange(of: rainAlertsEnabled) { customisationRegistry.set(\.behaviour.rainAlertsEnabled, $0) }
            .onChange(of: severeWeatherAlertsEnabled) { customisationRegistry.set(\.behaviour.severeWeatherAlertsEnabled, $0) }
            .onChange(of: aiAlertSummariesEnabled) { customisationRegistry.set(\.behaviour.aiAlertSummariesEnabled, $0) }
            .onChange(of: weatherAlertSounds) { customisationRegistry.set(\.behaviour.weatherAlertSounds, $0) }
            .onChange(of: quietHoursStart) { newValue in
                if customisationRegistry.profile.knobs.behaviour.quietHoursStart != nil {
                    customisationRegistry.set(\.behaviour.quietHoursStart, newValue)
                }
            }
            .onChange(of: quietHoursEnd) { newValue in
                if customisationRegistry.profile.knobs.behaviour.quietHoursEnd != nil {
                    customisationRegistry.set(\.behaviour.quietHoursEnd, newValue)
                }
            }
            .onChange(of: refreshSound) { customisationRegistry.set(\.behaviour.refreshSound, $0) }

            Section {
                Toggle(isOn: $experimentalNewHeroLayout) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("New Hero Layout", systemImage: "sparkles")
                        Text("Try the redesigned hero card layout.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Toggle(isOn: $experimentalSwipeRefresh) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Swipe Refresh Anywhere", systemImage: "arrow.down.to.line")
                        Text("Allow pull-to-refresh anywhere on the home screen, not just inside the scroll view.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Label("Experimental", systemImage: "flask")
            } footer: {
                Text("These features are works-in-progress. Enable them to try them out, then file feedback so we know what to polish.")
            }
            .onChange(of: experimentalNewHeroLayout) { customisationRegistry.set(\.powerUser.experimentalNewHeroLayout, $0) }
            .onChange(of: experimentalSwipeRefresh) { customisationRegistry.set(\.powerUser.experimentalSwipeRefresh, $0) }

            Section {
                Button(role: .destructive) {
                    resetAllBehaviourToDefaults()
                } label: {
                    Label("Reset Behaviour to Defaults", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("Behaviour")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func resetAllBehaviourToDefaults() {
        let defaults = KnobStorage()
        customisationRegistry.set(\.behaviour.enableHapticFeedback, defaults.behaviour.enableHapticFeedback)
        customisationRegistry.set(\.behaviour.hapticIntensity, defaults.behaviour.hapticIntensity)
        customisationRegistry.set(\.behaviour.pullToRefresh, defaults.behaviour.pullToRefresh)
        customisationRegistry.set(\.behaviour.tapDayToExpand, defaults.behaviour.tapDayToExpand)
        customisationRegistry.set(\.behaviour.longPressToCustomise, defaults.behaviour.longPressToCustomise)
        customisationRegistry.set(\.behaviour.confirmDestructive, defaults.behaviour.confirmDestructive)
        customisationRegistry.set(\.behaviour.weatherAlertSounds, defaults.behaviour.weatherAlertSounds)
        customisationRegistry.set(\.behaviour.rainAlertsEnabled, defaults.behaviour.rainAlertsEnabled)
        customisationRegistry.set(\.behaviour.severeWeatherAlertsEnabled, defaults.behaviour.severeWeatherAlertsEnabled)
        customisationRegistry.set(\.behaviour.aiAlertSummariesEnabled, defaults.behaviour.aiAlertSummariesEnabled)
        customisationRegistry.set(\.behaviour.refreshSound, defaults.behaviour.refreshSound)
        customisationRegistry.set(\.behaviour.vibrateOnPullToRefresh, defaults.behaviour.vibrateOnPullToRefresh)
        customisationRegistry.set(\.behaviour.confirmQuit, defaults.behaviour.confirmQuit)
        customisationRegistry.set(\.behaviour.quietHoursStart, defaults.behaviour.quietHoursStart)
        customisationRegistry.set(\.behaviour.quietHoursEnd, defaults.behaviour.quietHoursEnd)
        customisationRegistry.set(\.accessibility.hapticOnSelection, defaults.accessibility.hapticOnSelection)
        customisationRegistry.set(\.accessibility.tapticOnRefresh, defaults.accessibility.tapticOnRefresh)
        customisationRegistry.set(\.powerUser.experimentalNewHeroLayout, defaults.powerUser.experimentalNewHeroLayout)
        customisationRegistry.set(\.powerUser.experimentalSwipeRefresh, defaults.powerUser.experimentalSwipeRefresh)
    }
}

// MARK: About Settings
struct AboutSettingsView: View {
    /// The store manager — read so the supporter badge
    /// updates reactively when the user buys a Supporter
    /// cosmetic.
    @EnvironmentObject private var storeManager: StoreManager

    private var isSupporter: Bool {
        storeManager.owns("com.saxweather.cosmetic.supporter.badge")
            || storeManager.owns(CosmeticCatalog.supporterPackID)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    HStack(spacing: 6) {
                        if isSupporter {
                            // The "☕ Supporter" acknowledgement.
                            // SF Symbol + text per the plan —
                            // no asset work required. Visible
                            // only to the user, never
                            // published anywhere else.
                            Label {
                                Text("Supporter")
                                    .font(.subheadline.weight(.semibold))
                            } icon: {
                                Image(systemName: "cup.and.saucer.fill")
                                    .foregroundColor(.orange)
                            }
                            .labelStyle(.titleAndIcon)
                            .accessibilityLabel("Supporter")
                        }
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section {
                Link(destination: URL(string: "https://github.com/saxobroko/SaxWeather")!) {
                    HStack {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Link(destination: URL(string: "https://saxobroko.com")!) {
                    HStack {
                        Label("Developer", systemImage: "person.circle")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section {
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Text("Made with")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.subheadline)
                        Text("by Saxon")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: Attribution Settings
struct AttributionSettingsView: View {
    let wuApiKey: String
    let stationID: String
    let owmApiKey: String
    let currentDataSource: String
    
    var currentDataSourceName: String {
        switch currentDataSource.lowercased() {
        case "weatherkit":
            return "Apple Weather"
        case "openmeteo":
            return "Open-Meteo"
        case "weatherunderground":
            return "Weather Underground"
        case "openweathermap":
            return "OpenWeatherMap"
        case "unknown":
            return "Not yet fetched"
        default:
            return currentDataSource
        }
    }
    
    var body: some View {
        List {
            Section {
                Text("SaxWeather uses multiple weather data providers to give you the most accurate weather information.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            
            // Apple Weather (WeatherKit)
            if #available(iOS 16.0, macOS 13.0, *) {
                Section {
                    Link(destination: URL(string: "https://weather.apple.com")!) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weather data from Apple Weather")
                                .font(.callout)
                            Text("Built-in weather service")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("Apple Weather", systemImage: "apple.logo")
                }
            }
            
            // Open-Meteo
            Section {
                Link(destination: URL(string: "https://open-meteo.com")!) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weather data by Open-Meteo.com")
                            .font(.callout)
                        Text("Free weather API (CC BY 4.0)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Label("Open-Meteo", systemImage: "cloud.sun.fill")
            }
            
            // Weather Underground
            if !wuApiKey.isEmpty && !stationID.isEmpty {
                Section {
                    Link(destination: URL(string: "https://www.wunderground.com")!) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Data from WU Station: \(stationID)")
                                .font(.callout)
                            Text("Personal weather station")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("Weather Underground", systemImage: "antenna.radiowaves.left.and.right")
                }
            }
            
            // OpenWeatherMap
            if !owmApiKey.isEmpty {
                Section {
                    Link(destination: URL(string: "https://openweathermap.org")!) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weather data from OpenWeatherMap")
                                .font(.callout)
                            Text("Global weather data provider")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("OpenWeatherMap", systemImage: "globe")
                }
            }
            
            // Current source
            Section {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Currently using: \(currentDataSourceName)")
                        .font(.callout)
                }
            } header: {
                Text("Active Source")
            }
        }
        .navigationTitle("Attribution")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Phase 5 — Palette + Chart Skin picker rows (cosmetic-only)

struct PalettePickerRow: View {
    @EnvironmentObject private var customisationRegistry: CustomisationRegistry
    @EnvironmentObject private var storeManager: StoreManager
    @State private var showingPalettePicker = false

    private var activePaletteName: String {
        let active = customisationRegistry.profile.knobs.visual.palette
        // Find the matching selectable entry, or fall back to
        // "Default" if the active palette is a user-edited
        // custom one (which isn't in the picker list).
        if let entry = Palette.selectablePalettes.first(where: { $0.palette == active }) {
            return entry.displayName
        }
        return String(
            localized: "Default",
            comment: "Fallback name for an unknown custom palette in the picker row."
        )
    }

    var body: some View {
        Button {
            showingPalettePicker = true
        } label: {
            HStack {
                Image(systemName: "paintpalette.fill")
                Text(String(
                    localized: "Palette",
                    comment: "Title of the palette picker row in Settings."
                ))
                Spacer()
                Text(activePaletteName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingPalettePicker) {
            PalettePickerView()
                .environmentObject(customisationRegistry)
                .environmentObject(storeManager)
        }
    }
}

/// Settings row that presents `ChartSkinPickerView` as a
/// sheet. Mirrors `PalettePickerRow`'s shape; shows the
/// active skin's display name as the detail text.
struct ChartSkinPickerRow: View {
    @EnvironmentObject private var customisationRegistry: CustomisationRegistry
    @EnvironmentObject private var storeManager: StoreManager
    @State private var showingChartSkinPicker = false

    private var activeSkinName: String {
        customisationRegistry.profile.knobs.forecast.chartSkin.displayName
    }

    var body: some View {
        Button {
            showingChartSkinPicker = true
        } label: {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                Text(String(
                    localized: "Chart Style",
                    comment: "Title of the chart skin picker row in Settings."
                ))
                Spacer()
                Text(activeSkinName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingChartSkinPicker) {
            ChartSkinPickerView()
                .environmentObject(customisationRegistry)
                .environmentObject(storeManager)
        }
    }
}
