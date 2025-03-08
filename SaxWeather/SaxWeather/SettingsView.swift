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

    private let unitSystems = ["Metric", "Imperial", "UK"]
    private let colorSchemes = ["system", "light", "dark"]
    private let forecastDayOptions = [3, 5, 7, 10, 14]
    
    var body: some View {
        NavigationView {
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
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Settings"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
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
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                TextField("Station ID", text: $stationID)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            VStack(alignment: .leading) {
                Text("OpenWeatherMap")
                    .font(.headline)
                
                TextField("API Key", text: $owmApiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            Button("Save API Keys") {
                saveAPIKeys()
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
            
            if !weatherService.useGPS {
                VStack(alignment: .leading) {
                    Text("Manual Coordinates")
                        .font(.headline)
                        .padding(.top)
                    
                    HStack {
                        TextField("Latitude", text: $latitude)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("Longitude", text: $longitude)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Button("Save Coordinates") {
                        saveCoordinates()
                    }
                    .padding(.top, 5)
                }
            }
        }
    }
    
    private var unitsAndDisplaySection: some View {
        Group {
            Picker("Unit System", selection: $unitSystem) {
                ForEach(unitSystems, id: \.self) { unit in
                    Text(unit).tag(unit)
                }
            }
            .onChange(of: unitSystem) { newValue in
                weatherService.unitSystem = newValue
            }
            
            Picker("Appearance", selection: $colorScheme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            
            Picker("Forecast Days", selection: $forecastDays) {
                ForEach(forecastDayOptions, id: \.self) { days in
                    Text("\(days) Days").tag(days)
                }
            }
            .onChange(of: forecastDays) { _ in
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
        
        UserDefaults.standard.set(trimmedWUKey, forKey: "wuApiKey")
        UserDefaults.standard.set(trimmedStationID, forKey: "stationID")
        UserDefaults.standard.set(trimmedOWMKey, forKey: "owmApiKey")
        
        alertMessage = "API keys saved successfully!"
        showingAlert = true
        
        // Refresh weather data with new API keys
        Task {
            await weatherService.fetchWeather()
        }
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
        
        // Refresh weather data with new coordinates
        Task {
            await weatherService.fetchWeather()
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(weatherService: WeatherService())
            .environmentObject(StoreManager.shared)
    }
}
