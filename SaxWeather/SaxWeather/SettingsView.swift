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
    @AppStorage("wuApiKey") private var wuApiKey = ""
    @AppStorage("stationID") private var stationID = ""
    @AppStorage("owmApiKey") private var owmApiKey = ""
    @AppStorage("latitude") private var latitude = ""
    @AppStorage("longitude") private var longitude = ""
    @AppStorage("unitSystem") private var unitSystem = "Metric"
    @AppStorage("colorScheme") private var colorScheme = "system"
    @AppStorage("forecastDays") private var forecastDays = 7
    @AppStorage("displayMode") private var displayMode = "Summary"
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
    @State private var citySearchCompleter = MKLocalSearchCompleter()
    @State private var citySearchError: String? = nil
    @State private var citySearchCoordinate: CLLocationCoordinate2D? = nil
    @State private var citySearchCompleterDelegate: CitySearchCompleterDelegate? = nil

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
                        GroupBox(label: Text("Saved Locations").font(.title2)) {
                            savedLocationsSection
                                .padding()
                        }
                        GroupBox(label: Text("Weather Sources").font(.title2)) {
                            weatherSourcesSection
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
                
                #if os(iOS)
                APIKeyTextField(
                    text: $wuApiKey,
                    placeholder: "API Key",
                    isFocused: focusedField == .wuApiKey,
                    onDone: { focusedField = nil }
                )
                .frame(height: 36)
                #else
                TextField("API Key", text: $wuApiKey)
                    .textFieldStyle(.roundedBorder)
                #endif
                
                #if os(iOS)
                APIKeyTextField(
                    text: $stationID,
                    placeholder: "Station ID",
                    isFocused: focusedField == .stationID,
                    onDone: { focusedField = nil }
                )
                .frame(height: 36)
                #else
                TextField("Station ID", text: $stationID)
                    .textFieldStyle(.roundedBorder)
                #endif
            }
            
            VStack(alignment: .leading) {
                Text("OpenWeatherMap")
                    .font(.headline)
                
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
            
            Button("Save API Keys") {
                saveAPIKeys()
            }.buttonStyle(.bordered)
            .onAppear {
                loadAPIKeys()
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
            Picker("Display Mode", selection: $displayMode) {
                ForEach(displayModes, id: \.self) { mode in
                    Text(mode).tag(mode)
                }
            }
            #if os(macOS)
            .pickerStyle(.radioGroup)
            #endif
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
                        Task { await weatherService.fetchWeather() }
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
                Button("Enter Custom Coordinates") {
                    addLocationMode = .manual
                }
                Button("Search City/Town") {
                    addLocationMode = .search
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
                            let loc = SavedLocation(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
                            locationsManager.addLocation(loc)
                            locationsManager.selectLocation(loc)
                            weatherService.useGPS = false
                            Task { await weatherService.fetchWeather() }
                            showingAddLocationSheet = false
                            citySearchQuery = ""
                            citySearchResults = []
                            selectedSearchCompletion = nil
                            citySearchCoordinate = nil
                            citySearchError = nil
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
        if isFocused && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
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

