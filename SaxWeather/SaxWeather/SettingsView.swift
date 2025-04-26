//
//  SettingsView.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-26
//

import SwiftUI
import CoreLocation
import MapKit

struct SettingsView: View {
    @ObservedObject var weatherService: WeatherService
    @EnvironmentObject var storeManager: StoreManager
    @AppStorage("wuApiKey") private var wuApiKey = ""
    @AppStorage("stationID") private var stationID = ""
    @AppStorage("owmApiKey") private var owmApiKey = ""
    @AppStorage("latitude") private var latitude = ""
    @AppStorage("longitude") private var longitude = ""
    @AppStorage("unitSystem") private var unitSystem = "Metric"
    @AppStorage("colorScheme") private var colorScheme = "system"
    @AppStorage("forecastDays") private var forecastDays = 7
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.colorScheme) private var systemColorScheme
    @StateObject private var locationsManager = SavedLocationsManager()
    @State private var showingAddLocationSheet = false
    @State private var addLocationMode: AddLocationMode? = nil
    @State private var newLocationName = ""
    @State private var newLatitude = ""
    @State private var newLongitude = ""
    @State private var citySearchQuery = ""
    @State private var citySearchResults: [MKLocalSearchCompletion] = []
    @State private var selectedSearchCompletion: MKLocalSearchCompletion?
    @State private var isSearchingCity = false

    // For onboarding dismiss button
    var isOnboarding: Bool = false
    @Environment(\.dismiss) private var dismiss

    private let unitSystems = ["Metric", "Imperial", "UK"]
    private let colorSchemes = ["system", "light", "dark"]
    private let forecastDayOptions = [3, 5, 7, 10, 14]
    
    var body: some View {
        #if os(macOS)
        GeometryReader { geometry in
            ScrollView {
                VStack {
                    Form {
                        GroupBox(label: Text("Saved Locations").font(.title2)) {
                            savedLocationsSection
                                .padding()
                        }
                        GroupBox(label: Text("Weather Sources").font(.title2)) {
                            weatherSourcesSection
                                .padding()
                        }
                        GroupBox(label: Text("Location").font(.title2)) {
                            locationSection
                                .padding()
                        }
                        GroupBox(label: Text("Units & Display").font(.title2)) {
                            unitsAndDisplaySection
                                .padding()
                        }
                        GroupBox(label: Text("Appearance").font(.title2)) {
                            BackgroundSettingsButton()
                                .environmentObject(storeManager)
                                .padding()
                        }
                        GroupBox(label: Text("About").font(.title2)) {
                            aboutSection
                                .padding()
                        }
                        // Save button at the bottom
                        HStack {
                            Spacer()
                            Button("Save") {
                                if validateSettings() {
                                    alertMessage = "Settings saved successfully!"
                                    showingAlert = true
                                    dismiss()
                                } else {
                                    alertMessage = "Missing required settings. Please enter either:\n1. Weather Underground API key and Station ID, or\n2. OpenWeatherMap API key with location, or\n3. Valid location coordinates"
                                    showingAlert = true
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            Spacer()
                        }
                        .padding(.top, 12)
                    }
                    .frame(minWidth: 320, maxWidth: min(geometry.size.width * 0.95, 500))
                    .background(.regularMaterial)
                    .cornerRadius(12)
                    .font(.system(size: 14))
                    .padding(.vertical, 32)
                    .padding(.horizontal, max(24, (geometry.size.width - 500) / 2))
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .center)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        if validateSettings() {
                            alertMessage = "Settings saved successfully!"
                            showingAlert = true
                            dismiss()
                        } else {
                            alertMessage = "Missing required settings. Please enter either:\n1. Weather Underground API key and Station ID, or\n2. OpenWeatherMap API key with location, or\n3. Valid location coordinates"
                            showingAlert = true
                        }
                    }.buttonStyle(.bordered)
                }
                if isOnboarding {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }.buttonStyle(.bordered)
                    }
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Settings"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .alert("Location Access Required", isPresented: $weatherService.showLocationAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Open Settings") { weatherService.openSettings() }
            } message: {
                Text("Location access is required to use GPS. Please enable it in Settings > Privacy > Location Services > SaxWeather")
            }
            .onChange(of: forecastDays) { newValue in
                Task { await weatherService.fetchForecasts() }
            }
        }
        #else
        NavigationStack {
            Form {
                Section(header: Text("Saved Locations")) {
                    savedLocationsSection
                }
                Section(header: Text("Weather Sources")) {
                    weatherSourcesSection
                }
                
                Section(header: Text("Location")) {
                    locationSection
                }
                
                Section(header: Text("Units & Display")) {
                    unitsAndDisplaySection
                }
                
                Section(header: Text("Appearance")) {
                    BackgroundSettingsButton()
                        .environmentObject(storeManager)
                }
                
                Section(header: Text("About")) {
                    aboutSection
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        if validateSettings() {
                            alertMessage = "Settings saved successfully!"
                            showingAlert = true
                            dismiss()
                        } else {
                            alertMessage = "Missing required settings. Please enter either:\n1. Weather Underground API key and Station ID, or\n2. OpenWeatherMap API key with location, or\n3. Valid location coordinates"
                            showingAlert = true
                        }
                    }.buttonStyle(.bordered)
                }
                if isOnboarding {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }.buttonStyle(.bordered)
                    }
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Settings"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .alert("Location Access Required", isPresented: $weatherService.showLocationAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Open Settings") { weatherService.openSettings() }
            } message: {
                Text("Location access is required to use GPS. Please enable it in Settings > Privacy > Location Services > SaxWeather")
            }
            .onChange(of: forecastDays) { newValue in
                Task { await weatherService.fetchForecasts() }
            }
            .sheet(isPresented: $showingAddLocationSheet) {
                addLocationSheet
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
            VStack(alignment: .leading) {
                Text("Weather Underground")
                    .font(.headline)
                
                TextField("API Key", text: $wuApiKey)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    #endif
                
                TextField("Station ID", text: $stationID)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    #endif
            }
            
            VStack(alignment: .leading) {
                Text("OpenWeatherMap")
                    .font(.headline)
                
                TextField("API Key", text: $owmApiKey)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    #endif
            }
            
            Button("Save API Keys") {
                saveAPIKeys()
            }.buttonStyle(.bordered)
            .onAppear {
                loadAPIKeys()
            }
        }
    }
    
    private var locationSection: some View {
        Group {
            Toggle(isOn: $weatherService.useGPS) {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.blue)
                    Text("Use Current Location")
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            #if os(iOS)
            if !weatherService.useGPS {
                VStack(alignment: .leading) {
                    Text("Manual Coordinates")
                        .font(.headline)
                        .padding(.top)
                    
                    HStack {
                        TextField("Latitude", text: $latitude)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Longitude", text: $longitude)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button("Save Coordinates") {
                        saveCoordinates()
                    }.buttonStyle(.bordered)
                    .padding(.top, 5)
                }
            }
            #else
            if !weatherService.useGPS {
                VStack(alignment: .leading) {
                    Text("Manual Coordinates")
                        .font(.headline)
                        .padding(.top)
                    
                    HStack {
                        TextField("Latitude", text: $latitude)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Longitude", text: $longitude)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button("Save Coordinates") {
                        saveCoordinates()
                    }.buttonStyle(.bordered)
                    .padding(.top, 5)
                }
            }
            #endif
        }
    }
    
    private var unitsAndDisplaySection: some View {
        Group {
            Picker("Unit System", selection: $unitSystem) {
                ForEach(unitSystems, id: \.self) { unit in
                    Text(unit).tag(unit)
                }
            }
            #if os(macOS)
            .pickerStyle(.radioGroup)
            #endif
            .onChange(of: unitSystem) { newValue in
                weatherService.unitSystem = newValue
            }
            Picker("Appearance", selection: $colorScheme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            #if os(macOS)
            .pickerStyle(.radioGroup)
            #endif
            Picker("Forecast Days", selection: $forecastDays) {
                ForEach(forecastDayOptions, id: \.self) { days in
                    Text("\(days) Days").tag(days)
                }
            }
            #if os(macOS)
            .pickerStyle(.radioGroup)
            #endif
            .onChange(of: forecastDays) { newValue in
                Task {
                    await weatherService.fetchForecasts()
                }
            }
        }
    }
    
    private var aboutSection: some View {
        Group {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundColor(.secondary)
            }
            
            Link(destination: URL(string: "https://github.com/saxobroko/SaxWeather")!) {
                HStack {
                    Text("Source Code")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.blue)
                }
            }
            
            Link(destination: URL(string: "https://saxobroko.com")!) {
                HStack {
                    Text("Developer Website")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var savedLocationsSection: some View {
        VStack(alignment: .leading) {
            List {
                Button(action: {
                    locationsManager.selectCurrentLocation()
                    weatherService.useGPS = true
                }) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Current Location (GPS)")
                        Spacer()
                        if locationsManager.selectedLocation?.isCurrentLocation ?? false {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
                ForEach(locationsManager.locations) { location in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(location.name)
                            Text("\(location.latitude), \(location.longitude)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if locationsManager.selectedLocation?.id == location.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        locationsManager.selectLocation(location)
                        weatherService.useGPS = false
                        // Update WeatherService with new coordinates
                        Task { await weatherService.fetchWeather() }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            locationsManager.removeLocation(location)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .frame(height: min(220, CGFloat(44 * (locationsManager.locations.count + 1))))
            // Add vertical spacing before the Add Location button
            Spacer(minLength: 12)
            HStack {
                Spacer()
                Button(action: { showingAddLocationSheet = true }) {
                    Label("Add Location", systemImage: "plus")
                        .labelStyle(IconOnlyLabelStyle())
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(Color.blue))
                        .overlay(
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                        )
                }
                .accessibilityLabel("Add Location")
                Spacer()
            }
            .padding(.top, 8)
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
                Button("Enter Custom Coordinates") {
                    addLocationMode = .manual
                }
                Button("Search City/Town") {
                    addLocationMode = .search
                }
            }
            .navigationTitle("Add Location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddLocationSheet = false }
                }
            }
            .sheet(item: $addLocationMode) { mode in
                switch mode {
                case .manual:
                    manualCoordinatesSheet
                case .search:
                    citySearchSheet
                }
            }
        }
    }
    
    private var manualCoordinatesSheet: some View {
        Form {
            Section {
                TextField("Location Name", text: $newLocationName)
                TextField("Latitude", text: $newLatitude)
                    .keyboardType(.decimalPad)
                TextField("Longitude", text: $newLongitude)
                    .keyboardType(.decimalPad)
            }
            // Visually separate the Save button
            Section {
                Button("Save") {
                    if let lat = Double(newLatitude), let lon = Double(newLongitude), !newLocationName.isEmpty {
                        let loc = SavedLocation(name: newLocationName, latitude: lat, longitude: lon)
                        locationsManager.addLocation(loc)
                        locationsManager.selectLocation(loc)
                        weatherService.useGPS = false
                        Task { await weatherService.fetchWeather() }
                        showingAddLocationSheet = false
                        newLocationName = ""
                        newLatitude = ""
                        newLongitude = ""
                    }
                }
                .disabled(newLocationName.isEmpty || Double(newLatitude) == nil || Double(newLongitude) == nil)
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Custom Coordinates")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { addLocationMode = nil }
            }
        }
    }
    
    private var citySearchSheet: some View {
        VStack {
            TextField("Search for a city or town", text: $citySearchQuery)
                .textFieldStyle(.roundedBorder)
                .padding()
            // TODO: Implement search results using MKLocalSearchCompleter and show results
            Text("City search coming soon...")
                .foregroundColor(.secondary)
            Button("Cancel") { addLocationMode = nil }
                .padding(.top)
        }
        .navigationTitle("Search City/Town")
    }
    
    enum AddLocationMode: Identifiable {
        case manual, search
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
            await weatherService.fetchWeather()
        }
    }
    
    private func loadAPIKeys() {
        wuApiKey = KeychainService.shared.getApiKey(forService: "wu") ?? ""
        owmApiKey = KeychainService.shared.getApiKey(forService: "owm") ?? ""
        stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
    }
    
    private func saveCoordinates() {
        guard !latitude.isEmpty, !longitude.isEmpty,
              let lat = Double(latitude), let lon = Double(longitude) else {
            alertMessage = "Please enter valid coordinates."
            showingAlert = true
            return
        }
        
        guard lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 else {
            alertMessage = "Coordinates out of range. Latitude must be between -90 and 90, longitude between -180 and 180."
            showingAlert = true
            return
        }
        
        UserDefaults.standard.set(latitude, forKey: "latitude")
        UserDefaults.standard.set(longitude, forKey: "longitude")
        
        alertMessage = "Coordinates saved successfully!"
        showingAlert = true
        
        Task {
            await weatherService.fetchWeather()
        }
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
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(weatherService: WeatherService())
            .environmentObject(StoreManager.shared)
        SettingsView(weatherService: WeatherService(), isOnboarding: true)
            .environmentObject(StoreManager.shared)
    }
}
