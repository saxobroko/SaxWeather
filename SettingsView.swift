import SwiftUI
import CoreLocation

struct SettingsView: View {
    @AppStorage("wuApiKey") private var wuApiKey: String = ""
    @AppStorage("owmApiKey") private var owmApiKey: String = ""
    @AppStorage("stationID") private var stationID: String = ""
    @AppStorage("latitude") private var latitude: String = ""
    @AppStorage("longitude") private var longitude: String = ""
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    @State private var useGPS = false
    @ObservedObject var weatherService: WeatherService
    @Environment(\.presentationMode) var presentationMode  // Allows dismissing the view

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Weather Underground API Settings")) {
                    TextField("Enter WU API Key", text: $wuApiKey)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    TextField("Enter Station ID", text: $stationID)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("OpenWeatherMap API Settings")) {
                    TextField("Enter OWM API Key", text: $owmApiKey)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Location Coordinates")) {
                    Toggle(isOn: $useGPS) {
                        Text("Use GPS")
                    }
                    .onChange(of: useGPS) { value in
                        weatherService.useGPS = value
                        if value {
                            weatherService.requestLocation()
                        } else {
                            weatherService.stopUpdatingLocation()
                        }
                    }
                    
                    TextField("Enter Latitude", text: $latitude)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .disabled(useGPS)

                    TextField("Enter Longitude", text: $longitude)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .disabled(useGPS)
                }
                
                Section(header: Text("Unit System")) {
                    Picker("Unit System", selection: $unitSystem) {
                        Text("Metric").tag("Metric")
                        Text("Imperial").tag("Imperial")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section {
                    Text("Made by Saxo_Broko with ❤️")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(
                trailing: Button("Save") {
                    saveSettings()
                    presentationMode.wrappedValue.dismiss() // Close settings screen
                }
            )
        }
    }

    private func saveSettings() {
        // Settings are automatically saved using @AppStorage
        print("✅ Settings saved: WU API Key = \(wuApiKey), OWM API Key = \(owmApiKey), Station ID = \(stationID), Latitude = \(latitude), Longitude = \(longitude), Unit System = \(unitSystem), Use GPS = \(useGPS)")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(weatherService: WeatherService())
    }
}
