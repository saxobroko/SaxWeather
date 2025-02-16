import SwiftUI
import CoreLocation

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var weatherService: WeatherService
    
    @AppStorage("wuApiKey") private var wuApiKey = ""
    @AppStorage("stationID") private var stationID = ""
    @AppStorage("owmApiKey") private var owmApiKey = ""
    @AppStorage("latitude") private var latitude = ""
    @AppStorage("longitude") private var longitude = ""
    @AppStorage("unitSystem") private var unitSystem = "Metric"
    
    @State private var showingSaveConfirmation = false
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    private let unitSystems = ["Metric", "Imperial"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Weather Underground Settings")) {
                    TextField("API Key", text: $wuApiKey)
                    TextField("Station ID", text: $stationID)
                }
                .textCase(nil)
                
                Section(header: Text("OpenWeatherMap Settings")) {
                    TextField("API Key", text: $owmApiKey)
                }
                .textCase(nil)
                
                Section(header: Text("Location Settings")) {
                    Toggle("Use GPS", isOn: $weatherService.useGPS)
                    
                    if !weatherService.useGPS {
                        TextField("Latitude", text: $latitude)
                            .keyboardType(.decimalPad)
                        TextField("Longitude", text: $longitude)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(header: Text("Unit System")) {
                    Picker("Unit System", selection: $unitSystem) {
                        ForEach(unitSystems, id: \.self) { system in
                            Text(system).tag(system)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
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
    }
    
    private func validateInputs() -> Bool {
        // Check if at least one service is configured
        let hasWUConfig = !wuApiKey.isEmpty && !stationID.isEmpty
        let hasOWMConfig = !owmApiKey.isEmpty
        
        // Location validation
        let hasValidLocation = weatherService.useGPS || (!latitude.isEmpty && !longitude.isEmpty)
        
        if !hasWUConfig && !hasOWMConfig {
            validationMessage = "Please configure at least one weather service (Weather Underground or OpenWeatherMap)"
            return false
        }
        
        if !hasValidLocation {
            validationMessage = "Please enable GPS or enter manual coordinates"
            return false
        }
        
        // Validate individual service configurations
        if !wuApiKey.isEmpty && stationID.isEmpty {
            validationMessage = "Station ID is required when using Weather Underground"
            return false
        }
        
        if !stationID.isEmpty && wuApiKey.isEmpty {
            validationMessage = "Weather Underground API key is required when using a Station ID"
            return false
        }
        
        return true
    }
    
    private func saveSettings() {
        guard validateInputs() else {
            showingValidationAlert = true
            return
        }
        
        // Save settings
        weatherService.unitSystem = unitSystem
        
        print("✅ Settings saved: Unit System = \(unitSystem), Use GPS = \(weatherService.useGPS)")
        print("✅ Weather Underground: \(wuApiKey.isEmpty ? "Disabled" : "Enabled")")
        print("✅ OpenWeatherMap: \(owmApiKey.isEmpty ? "Disabled" : "Enabled")")
        
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
