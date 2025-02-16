//
//  SettingsView.swift
//  SaxWeather
//
//  Created by Saxo_Broko on 2025-02-16 02:25:56
//

import SwiftUI
import CoreLocation

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var systemColorScheme
    @ObservedObject var weatherService: WeatherService
    
    @AppStorage("wuApiKey") private var wuApiKey = ""
    @AppStorage("stationID") private var stationID = ""
    @AppStorage("owmApiKey") private var owmApiKey = ""
    @AppStorage("latitude") private var latitude = ""
    @AppStorage("longitude") private var longitude = ""
    @AppStorage("unitSystem") private var unitSystem = "Metric"
    @AppStorage("colorScheme") private var colorScheme = "system"
    @AppStorage("useWunderground") private var useWunderground = false
    @AppStorage("useOpenWeather") private var useOpenWeather = false
    
    @State private var showingSaveConfirmation = false
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    private let unitSystems = ["Metric", "Imperial"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Weather Services")) {
                    Toggle("Weather Underground", isOn: $useWunderground)
                    Toggle("OpenWeatherMap", isOn: $useOpenWeather)
                }
                
                if useWunderground {
                    Section(header: Text("Weather Underground Settings")) {
                        TextField("API Key", text: $wuApiKey)
                        TextField("Station ID", text: $stationID)
                    }
                    .textCase(nil)
                }
                
                if useOpenWeather {
                    Section(header: Text("OpenWeatherMap Settings")) {
                        TextField("API Key", text: $owmApiKey)
                        
                        Toggle("Use GPS", isOn: $weatherService.useGPS)
                        
                        if !weatherService.useGPS {
                            TextField("Latitude", text: $latitude)
                                .keyboardType(.decimalPad)
                            TextField("Longitude", text: $longitude)
                                .keyboardType(.decimalPad)
                        }
                    }
                    .textCase(nil)
                }
                
                Section(header: Text("Unit System")) {
                    Picker("Unit System", selection: $unitSystem) {
                        ForEach(unitSystems, id: \.self) { system in
                            Text(system).tag(system)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $colorScheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: colorScheme) { newValue in
                        updateColorScheme(to: newValue)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.gray)
                    }
                    
                    Link(destination: URL(string: "https://github.com/saxobroko/SaxWeather")!) {
                        HStack {
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text("Made by Saxo_Broko")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveSettings()
                }
            )
            .alert(isPresented: $showingValidationAlert) {
                Alert(
                    title: Text("Invalid Settings"),
                    message: Text(validationMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay(
                SaveConfirmationView(isShowing: $showingSaveConfirmation)
            )
        }
        .preferredColorScheme(getPreferredColorScheme())
    }
    
    private func getPreferredColorScheme() -> ColorScheme? {
        switch colorScheme {
        case "light":
            return .light
        case "dark":
            return .dark
        case "system":
            return systemColorScheme
        default:
            return nil
        }
    }
    
    private func updateColorScheme(to newValue: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        window.overrideUserInterfaceStyle = {
            switch newValue {
            case "light":
                return .light
            case "dark":
                return .dark
            case "system":
                return .unspecified
            default:
                return .unspecified
            }
        }()
    }
    
    private func validateInputs() -> Bool {
        print("🔍 Validating inputs...")
        
        // First check if at least one service is enabled
        if !useWunderground && !useOpenWeather {
            validationMessage = "Please enable at least one weather service"
            print("❌ Validation failed: No weather service enabled")
            return false
        }
        
        // Validate Weather Underground settings if enabled
        if useWunderground {
            if wuApiKey.isEmpty || stationID.isEmpty {
                validationMessage = "Please provide both API Key and Station ID for Weather Underground"
                print("❌ Validation failed: Missing Weather Underground credentials")
                return false
            }
        }
        
        // Validate OpenWeatherMap settings if enabled
        if useOpenWeather {
            if owmApiKey.isEmpty {
                validationMessage = "Please provide an API Key for OpenWeatherMap"
                print("❌ Validation failed: Missing OpenWeatherMap API key")
                return false
            }
            
            // Only validate location if OpenWeatherMap is enabled
            let hasValidLocation = weatherService.useGPS || (!latitude.isEmpty && !longitude.isEmpty)
            if !hasValidLocation {
                validationMessage = "Please enable GPS or enter manual coordinates for OpenWeatherMap"
                print("❌ Validation failed: No location data available")
                return false
            }
            
            // Print current location data for debugging
            if weatherService.useGPS {
                print("📍 Using GPS Location")
            } else {
                print("📍 Using Manual Location:")
                print("   - Latitude: \(latitude)")
                print("   - Longitude: \(longitude)")
            }
        }
        
        print("✅ Validation passed")
        return true
    }

    private func saveSettings() {
        print("\n📝 Saving Settings...")
        
        guard validateInputs() else {
            showingValidationAlert = true
            return
        }
        
        // Save settings
        weatherService.unitSystem = unitSystem
        
        // Clear unused service settings
        if !useWunderground {
            wuApiKey = ""
            stationID = ""
            print("🧹 Cleared Weather Underground settings")
        }
        
        if !useOpenWeather {
            owmApiKey = ""
            if !useWunderground {  // Only clear location if Weather Underground isn't being used
                latitude = ""
                longitude = ""
                weatherService.useGPS = false
                print("🧹 Cleared OpenWeatherMap settings and location data")
            }
        }
        
        print("\n📊 Current Settings:")
        print("- Unit System: \(unitSystem)")
        print("- Weather Underground: \(useWunderground ? "Enabled" : "Disabled")")
        print("- OpenWeatherMap: \(useOpenWeather ? "Enabled" : "Disabled")")
        
        if useOpenWeather {
            print("\n🌍 OpenWeatherMap Configuration:")
            print("- Use GPS: \(weatherService.useGPS)")
            
            // Print the complete API URL for debugging
            let units = unitSystem == "Metric" ? "metric" : "imperial"
            let lat = latitude
            let lon = longitude
            
            print("\n🔗 API Information:")
            print("- Base URL: https://api.openweathermap.org/data/3.0/onecall")
            print("- Parameters:")
            print("  • lat: \(lat)")
            print("  • lon: \(lon)")
            print("  • units: \(units)")
            print("  • exclude: minutely,hourly,alerts")
            print("  • appid: \(String(owmApiKey.prefix(6)))...")
            
            let apiUrl = "https://api.openweathermap.org/data/3.0/onecall?lat=\(lat)&lon=\(lon)&exclude=minutely,hourly,alerts&units=\(units)&appid=\(owmApiKey)"
            print("\n📡 Complete API URL:")
            print(apiUrl)
        }
        
        // Dismiss view immediately
        presentationMode.wrappedValue.dismiss()
        
        // Show floating confirmation
        withAnimation {
            showingSaveConfirmation = true
        }
        
        // Hide confirmation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showingSaveConfirmation = false
            }
        }
        
        print("\n🔄 Refreshing weather data...")
        
        // Refresh weather with new settings
        Task { @MainActor in
            await weatherService.fetchWeather()
        }
    }
}

struct SaveConfirmationView: View {
    @Binding var isShowing: Bool
    
    var body: some View {
        if isShowing {
            VStack {
                Text("Settings Saved")
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green)
                    )
            }
            .transition(.move(edge: .top))
            .zIndex(1)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(weatherService: WeatherService())
    }
}
