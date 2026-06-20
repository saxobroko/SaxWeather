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

struct SettingsView: View {
    @ObservedObject var weatherService: WeatherService
    @EnvironmentObject var storeManager: StoreManager
    /// Customisation engine — Phase 2: every `@AppStorage` write
    /// below is forwarded to the registry via `.onChange` modifiers
    /// attached at the body root, so the registry is the single
    /// mutation path. Reads stay as `@AppStorage` for now.
    @EnvironmentObject private var customisationRegistry: CustomisationRegistry
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
    @StateObject private var locationsManager = SavedLocationsManager()
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
    @State private var mapSelectedLocation: CLLocationCoordinate2D? = nil
    @State private var mapSelectedLocationName: String? = nil

    // For onboarding dismiss button
    var isOnboarding: Bool = false
    @Environment(\.dismiss) private var dismiss

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
            // Phase 2 bridge — every bridged setting forwards its
            // new value to the registry. The existing side effects
            // (Task { fetch… }, etc.) are preserved.
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
                // Phase 3 — accentColor is now a ColourToken; the
                // existing `@AppStorage` writes a plain String, so
                // wrap on the bridge.
                customisationRegistry.set(\.visual.accentColor, ColourToken(rawString: newValue))
            }
            .sheet(isPresented: $showingTipJar) {
                TipJarView()
            }
            .alert("Settings", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        #else
        NavigationStack {
            List {
                // Network quality hint. Sits at the top of the
                // list so the user sees it before tweaking any
                // other setting. Reactive — updates as the user
                // toggles Low Data Mode or moves between WiFi
                // and cellular.
                NetworkQualityHint()

                // Phase 7 — Theme switcher + share/import. Drop-in
                // section that surfaces the "infinitely customisable"
                // features without rewriting the rest of the
                // settings UI.
                ThemeSettingsSection()

                Section {
                    NavigationLink {
                        LocationsSettingsView(
                            locationsManager: locationsManager,
                            disableAPIKeys: $disableAPIKeys,
                            weatherService: weatherService
                        )
                    } label: {
                        Label("Locations", systemImage: "location.fill")
                    }
                    
                    NavigationLink {
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
                    } label: {
                        Label("Weather Data", systemImage: "cloud.sun.fill")
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
                        Label("Preferences", systemImage: "slider.horizontal.3")
                    }
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        Label("Appearance", systemImage: "paintbrush.fill")
                    }
                    
                    NavigationLink {
                        AccessibilitySettingsView()
                    } label: {
                        Label("Accessibility", systemImage: "accessibility")
                    }
                }
                
                Section {
                    Button {
                        showingTipJar = true
                    } label: {
                        HStack {
                            Label("Support Development", systemImage: "heart.fill")
                                .foregroundColor(.pink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityLabel("Support Development")
                    .accessibilityHint("Leave a tip to support the app")
                }
                
                Section {
                    NavigationLink {
                        AboutSettingsView()
                    } label: {
                        Label("About", systemImage: "info.circle.fill")
                    }
                    
                    NavigationLink {
                        AttributionSettingsView(
                            wuApiKey: wuApiKey,
                            stationID: stationID,
                            owmApiKey: owmApiKey,
                            currentDataSource: weatherService.currentDataSource
                        )
                    } label: {
                        Label("Attribution", systemImage: "network")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            // Phase 2 bridge — iOS body. Same as the macOS body:
            // every bridged setting forwards its new value to the
            // registry.
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
                // Phase 3 — accentColor is now a ColourToken; the
                // existing `@AppStorage` writes a plain String, so
                // wrap on the bridge.
                customisationRegistry.set(\.visual.accentColor, ColourToken(rawString: newValue))
            }
            .sheet(isPresented: $showingTipJar) {
                TipJarView()
            }
            .sheet(isPresented: $showingAddLocationSheet) {
                addLocationSheet
            }
            .alert("Settings", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        #endif
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
                            locationsManager.removeLocation(location)
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
                    
                    if locationsManager.addLocation(name: locationName, latitude: validatedLat, longitude: validatedLon) {
                        // Find the newly added location to select it
                        if let addedLocation = locationsManager.locations.last {
                            locationsManager.selectLocation(addedLocation)
                            weatherService.useGPS = false
                            Task {
                                await weatherService.fetchWeather(calledFrom: "SettingsView.addMapLocation")
                            }
                        }
                        // Reset state
                        addLocationMode = nil
                        mapSelectedLocation = nil
                        mapSelectedLocationName = nil
                    } else {
                        alertMessage = "Invalid coordinates. Please try again."
                        showingAlert = true
                    }
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
                        
                        if locationsManager.addLocation(name: newLocationName, latitude: validatedLat, longitude: validatedLon) {
                            // Find the newly added location to select it
                            if let addedLocation = locationsManager.locations.last {
                                locationsManager.selectLocation(addedLocation)
                                weatherService.useGPS = false
                                Task { await weatherService.fetchWeather(calledFrom: "SettingsView.addLocation") }
                            }
                            showingAddLocationSheet = false
                            newLocationName = ""
                            newLatitude = ""
                            newLongitude = ""
                        } else {
                            alertMessage = "Invalid coordinates. Please check your values and try again."
                            showingAlert = true
                        }
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
                                
                                if locationsManager.addLocation(name: name, latitude: validatedLat, longitude: validatedLon) {
                                    // Find the newly added location to select it
                                    if let addedLocation = locationsManager.locations.last {
                                        locationsManager.selectLocation(addedLocation)
                                        weatherService.useGPS = false
                                        Task { await weatherService.fetchWeather(calledFrom: "SettingsView.citySearch") }
                                    }
                                    showingAddLocationSheet = false
                                    citySearchQuery = ""
                                    citySearchResults = []
                                    selectedSearchCompletion = nil
                                    citySearchCoordinate = nil
                                    citySearchError = nil
                                } else {
                                    // Handle error - but we don't have access to alertMessage/showingAlert here
                                    print("Failed to add location")
                                }
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(weatherService: WeatherService())
            .environmentObject(StoreManager.shared)
        SettingsView(weatherService: WeatherService(), isOnboarding: true)
            .environmentObject(StoreManager.shared)
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
                            locationsManager.removeLocation(location)
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
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddLocationSheet) {
            addLocationSheet
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
            .navigationBarItems(leading: Button("Cancel") { showingAddLocationSheet = false })
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
                    
                    if locationsManager.addLocation(name: locationName, latitude: validatedLat, longitude: validatedLon) {
                        // Find the newly added location to select it
                        if let addedLocation = locationsManager.locations.last {
                            locationsManager.selectLocation(addedLocation)
                            weatherService.useGPS = false
                            Task {
                                await weatherService.fetchWeather(calledFrom: "LocationsSettingsView.addMapLocation")
                            }
                        }
                        // Reset state
                        addLocationMode = nil
                        mapSelectedLocation = nil
                        mapSelectedLocationName = nil
                    } else {
                        alertMessage = "Invalid coordinates. Please try again."
                        showingAlert = true
                    }
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
                            
                            if locationsManager.addLocation(name: newLocationName, latitude: validatedLat, longitude: validatedLon) {
                                // Find the newly added location to select it
                                if let addedLocation = locationsManager.locations.last {
                                    locationsManager.selectLocation(addedLocation)
                                    weatherService.useGPS = false
                                    Task {
                                        await weatherService.fetchWeather(calledFrom: "LocationsSettingsView.addManualLocation")
                                    }
                                }
                                showingAddLocationSheet = false
                                addLocationMode = nil
                                newLocationName = ""
                                newLatitude = ""
                                newLongitude = ""
                            } else {
                                alertMessage = "Invalid coordinates. Please check your values and try again."
                                showingAlert = true
                            }
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
            .navigationBarItems(leading: Button("Cancel") {
                addLocationMode = nil
            })
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
                                
                                if locationsManager.addLocation(name: name, latitude: validatedLat, longitude: validatedLon) {
                                    // Find the newly added location to select it
                                    if let addedLocation = locationsManager.locations.last {
                                        locationsManager.selectLocation(addedLocation)
                                        weatherService.useGPS = false
                                        Task {
                                            await weatherService.fetchWeather(calledFrom: "LocationsSettingsView.addCityLocation")
                                        }
                                    }
                                    showingAddLocationSheet = false
                                    addLocationMode = nil
                                    citySearchQuery = ""
                                    citySearchResults = []
                                    selectedSearchCompletion = nil
                                    citySearchCoordinate = nil
                                    citySearchError = nil
                                } else {
                                    alertMessage = "Invalid coordinates. Please try again."
                                    showingAlert = true
                                }
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
            .navigationBarItems(leading: Button("Cancel") {
                addLocationMode = nil
            })
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
    @FocusState var focusedField: SettingsView.Field?
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
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAPIKeys()
        }
    }
}

// MARK: Preferences Settings
struct PreferencesSettingsView: View {
    @Binding var unitSystem: String
    @Binding var colorScheme: String
    @Binding var forecastDays: Int
    @Binding var displayMode: String
    @Binding var useOpenMeteoAsDefault: Bool
    @Binding var owmApiKey: String
    @ObservedObject var weatherService: WeatherService
    @AppStorage("showHamburgerMenu") private var showHamburgerMenu: Bool = true
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
                Toggle(isOn: $showHamburgerMenu) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Location Menu")
                            .font(.body)
                        Text("Display the hamburger menu in the top-right corner of the main weather screen for quick location switching.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Label("Interface", systemImage: "rectangle.grid.2x2")
            } footer: {
                Text("Disable for a more minimalistic experience. You can still manage locations from Settings → Locations.")
            }
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Appearance Settings
struct AppearanceSettingsView: View {
    @EnvironmentObject var storeManager: StoreManager
    @AppStorage("colorScheme") private var colorScheme = "system"
    @AppStorage("accentColor") private var accentColor = "blue"
    
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
            } header: {
                Label("Theme", systemImage: "circle.lefthalf.filled")
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
            }
            
            Section {
                BackgroundSettingsButton()
                    .environmentObject(storeManager)
            } header: {
                Label("Background", systemImage: "photo")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: About Settings
struct AboutSettingsView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundColor(.secondary)
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
        .navigationBarTitleDisplayMode(.inline)
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
        .navigationBarTitleDisplayMode(.inline)
    }
}

