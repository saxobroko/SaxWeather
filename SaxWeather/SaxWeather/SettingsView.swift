//
//  SettingsView.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-26
//

import SwiftUI
import CoreLocation

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
