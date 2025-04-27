//
//  WeatherService.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-25 04:49:47
//

import Foundation
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var weather: Weather?
    @Published var forecast: WeatherForecast?
    @Published var error: String?
    @Published var isLoading = false
    @Published private(set) var _useGPS: Bool
    @Published private(set) var _unitSystem: String
    @Published var showLocationAlert = false
    @Published var currentBackgroundCondition: String = "default"
    
    let locationManager: CLLocationManager
    
    var unitSystem: String {
        get { _unitSystem }
        set {
            DispatchQueue.main.async {
                self._unitSystem = newValue
                UserDefaults.standard.set(newValue, forKey: "unitSystem")
                Task {
                    await self.fetchWeather()
                }
            }
        }
    }
    
    var useGPS: Bool {
        get { _useGPS }
        set {
            // Only check authorization status when enabling GPS
            if newValue {
                let status = locationManager.authorizationStatus
                switch status {
                case .denied, .restricted:
                    // If permissions are denied, show alert
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self._useGPS = false
                        UserDefaults.standard.set(false, forKey: "useGPS")
                        self.showLocationAlert = true
                    }
                    return
                case .notDetermined:
                    // Request permission
                    locationManager.requestWhenInUseAuthorization()
                    return
                case .authorizedWhenInUse, .authorizedAlways:
                    // Permission already granted, proceed
                    break
                @unknown default:
                    break
                }
            }
            
            // Update the value
            _useGPS = newValue
            UserDefaults.standard.set(newValue, forKey: "useGPS")
            
            if newValue {
                requestLocation()
            } else {
                // Stop location updates when disabling GPS
                locationManager.stopUpdatingLocation()
            }
            
            // Refresh weather data when GPS setting changes
            Task {
                await fetchWeather()
            }
        }
    }
    
    override init() {
        // Default to using GPS, read from UserDefaults if available
        self._unitSystem = UserDefaults.standard.string(forKey: "unitSystem") ?? "Metric"
        
        // Set useGPS to true by default (or if saved coords are empty)
        let savedLat = UserDefaults.standard.string(forKey: "latitude") ?? ""
        let savedLon = UserDefaults.standard.string(forKey: "longitude") ?? ""
        let hasCoordinates = !savedLat.isEmpty && !savedLon.isEmpty
        
        if UserDefaults.standard.object(forKey: "useGPS") != nil {
            // User has set preference, but validate if they chose manual mode
            let userChoice = UserDefaults.standard.bool(forKey: "useGPS")
            self._useGPS = userChoice || !hasCoordinates // Force GPS if no coordinates
        } else {
            // First launch - default to GPS
            self._useGPS = true
            UserDefaults.standard.set(true, forKey: "useGPS")
        }
        
        self.locationManager = CLLocationManager()
        super.init()
        
        locationManager.delegate = self
        
        // If using GPS, immediately request location permissions
        if _useGPS {
            requestLocation()
        }
    }
    
    // MARK: - Weather Methods
    func fetchWeather() async {
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            let weatherData = try await fetchWeatherData()
            await MainActor.run {
                self.weather = weatherData
                self.isLoading = false
                self.updateBackgroundCondition()
            }
            
            // Always fetch forecast data after weather data is loaded
            await fetchForecasts()
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func fetchWeatherData() async throws -> Weather {
        let wuApiKey = KeychainService.shared.getApiKey(forService: "wu") ?? ""
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        let owmApiKey = KeychainService.shared.getApiKey(forService: "owm") ?? ""
        
        // Get location coordinates
        var latitude = ""
        var longitude = ""
        
        if useGPS && locationManager.location != nil {
            latitude = "\(locationManager.location!.coordinate.latitude)"
            longitude = "\(locationManager.location!.coordinate.longitude)"
        } else {
            latitude = UserDefaults.standard.string(forKey: "latitude") ?? ""
            longitude = UserDefaults.standard.string(forKey: "longitude") ?? ""
            
            // If GPS is enabled but location is nil, or if no saved coordinates, request location
            if (useGPS && locationManager.location == nil) || (latitude.isEmpty || longitude.isEmpty) {
                #if DEBUG
                print("⚠️ No valid coordinates available for weather data, requesting location")
                #endif
                requestLocation()
                
                // Wait a moment for location to update
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                if let location = locationManager.location {
                    latitude = "\(location.coordinate.latitude)"
                    longitude = "\(location.coordinate.longitude)"
                }
            }
        }
        
        // Final check for valid coordinates
        guard !latitude.isEmpty && !longitude.isEmpty else {
            throw WeatherError.noData
        }
        
        let lat = latitude
        let lon = longitude
        
        // Try Weather Underground first if configured
        if !wuApiKey.isEmpty && !stationID.isEmpty {
            do {
                if let wuData = try await fetchWUWeather(apiKey: wuApiKey, stationID: stationID) {
                    var weather = Weather(
                        wuObservation: wuData,
                        owmCurrent: nil,
                        owmDaily: nil,
                        unitSystem: unitSystem
                    )
                    
                    if unitSystem != "Metric" {
                        weather.convertUnits(from: "Metric", to: unitSystem)
                    }
                    
                    return weather
                }
            } catch {
                #if DEBUG
                print("⚠️ Weather Underground fetch failed, falling back to OpenWeatherMap: \(error.localizedDescription)")
                #endif
            }
        }
        
        // Try OpenWeatherMap if configured
        if !owmApiKey.isEmpty {
            do {
                let (owmCurrent, owmDaily) = try await fetchOWMWeather(
                    apiKey: owmApiKey,
                    latitude: lat,
                    longitude: lon,
                    unitSystem: unitSystem
                )
                
                var weather = Weather(
                    wuObservation: nil,
                    owmCurrent: owmCurrent,
                    owmDaily: owmDaily,
                    unitSystem: unitSystem
                )
                
                if unitSystem != "Metric" {
                    weather.convertUnits(from: "Metric", to: unitSystem)
                }
                
                return weather
            } catch {
                #if DEBUG
                print("⚠️ OpenWeatherMap fetch failed, falling back to OpenMeteo: \(error.localizedDescription)")
                #endif
            }
        }
        
        // Fallback to OpenMeteo as last resort
        let (openMeteoCurrent, openMeteoDaily) = try await fetchOpenMeteoWeather(
            latitude: lat,
            longitude: lon
        )
        
        var weather = Weather(
            wuObservation: nil,
            owmCurrent: openMeteoCurrent,
            owmDaily: openMeteoDaily,
            unitSystem: unitSystem
        )
        
        if unitSystem != "Metric" {
            weather.convertUnits(from: "Metric", to: unitSystem)
        }
        
        guard weather.hasData else {
            throw WeatherError.noData
        }
        
        return weather
    }
    
    private func fetchWUWeather(apiKey: String, stationID: String) async throws -> WUObservation? {
        guard !apiKey.isEmpty, !stationID.isEmpty else {
#if DEBUG
            print("❌ Weather Underground Error: Empty API key or station ID")
#endif
            throw WeatherError.invalidAPIKey
        }
        
        let urlString = "https://api.weather.com/v2/pws/observations/current?stationId=\(stationID)&format=json&units=m&numericPrecision=decimal&apiKey=\(apiKey)"
#if DEBUG
        print("🌐 Weather Underground URL: \(urlString)")
#endif
        
        guard let url = URL(string: urlString) else {
#if DEBUG
            print("❌ Weather Underground Error: Invalid URL")
#endif
            throw WeatherError.invalidURL
        }
        
        var request = createURLRequest(from: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
#if DEBUG
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Weather Underground Response Status: \(httpResponse.statusCode)")
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 Weather Underground Response Body:")
                print(responseString)
            }
#endif
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let wuResponse = try decoder.decode(WUResponse.self, from: data)
            
#if DEBUG
            if let observation = wuResponse.observations.first {
                print("✅ Weather Underground Data Parsed Successfully:")
                print("- Temperature: \(observation.metric.temp)°C")
                print("- Humidity: \(observation.humidity)%")
                print("- Wind Speed: \(observation.metric.windSpeed) m/s")
                print("- Pressure: \(observation.metric.pressure) hPa")
            }
#endif
            
            return wuResponse.observations.first
        } catch {
#if DEBUG
            print("❌ Weather Underground Error:", error)
            print("❌ Error Details:", error.localizedDescription)
#endif
            throw WeatherError.apiError(error.localizedDescription)
        }
    }
    
    private func fetchOWMWeather(
        apiKey: String,
        latitude: String,
        longitude: String,
        unitSystem: String
    ) async throws -> (OWMCurrent?, OWMDaily?) {
        guard !apiKey.isEmpty, !latitude.isEmpty, !longitude.isEmpty else {
            throw WeatherError.invalidAPIKey
        }
        
        let units = unitSystem == "Metric" ? "metric" : "imperial"
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(latitude)&lon=\(longitude)&units=\(units)&appid=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let request = createURLRequest(from: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
#if DEBUG
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 OpenWeatherMap API Response Status: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📡 OpenWeatherMap API Response Body:")
                    print(responseString)
                }
                
                if httpResponse.statusCode == 401 {
                    print("❌ OpenWeatherMap Error: Invalid API key")
                    throw WeatherError.invalidAPIKey
                } else if httpResponse.statusCode != 200 {
                    print("❌ OpenWeatherMap Error: Unexpected status code \(httpResponse.statusCode)")
                    throw WeatherError.apiError("Status code: \(httpResponse.statusCode)")
                }
            }
#endif
            
            let currentWeather = try JSONDecoder().decode(CurrentWeatherResponse.self, from: data)
            
            let owmCurrent = OWMCurrent(
                temp: currentWeather.main.temp,
                feels_like: currentWeather.main.feels_like,
                humidity: Double(currentWeather.main.humidity),
                dew_point: calculateDewPoint(temp: currentWeather.main.temp, humidity: Double(currentWeather.main.humidity)),
                pressure: Double(currentWeather.main.pressure),
                wind_speed: currentWeather.wind.speed,
                wind_gust: currentWeather.wind.gust ?? 0,
                uvi: 0,
                clouds: Double(currentWeather.clouds.all)
            )
            
            let owmDaily = OWMDaily(temp: OWMDaily.OWMDailyTemp(
                min: currentWeather.main.temp_min,
                max: currentWeather.main.temp_max
            ))
            
            return (owmCurrent, owmDaily)
        } catch {
#if DEBUG
            print("❌ OpenWeatherMap Error:", error.localizedDescription)
            print("❌ Error Details:", error)
#endif
            throw WeatherError.apiError(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Functions
    private func calculateDewPoint(temp: Double, humidity: Double) -> Double {
        let a = 17.27
        let b = 237.7
        
        let alpha = ((a * temp) / (b + temp)) + log(humidity/100.0)
        let dewPoint = (b * alpha) / (a - alpha)
        return dewPoint
    }
    
    private func createURLRequest(from url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        return request
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
#if DEBUG
        print("📍 Location updated: \(locations.first?.coordinate ?? CLLocationCoordinate2D())")
#endif
        
        // Stop updating location after we get a reading - only need one update
        locationManager.stopUpdatingLocation()
        
        if useGPS {
            Task { [weak self] in
                guard let self = self else { return }
                await self.fetchWeather()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
#if DEBUG
        print("❌ Location Error: \(error.localizedDescription)")
#endif
        
        // Handle the error properly
        Task { [weak self] in
            guard let self = self else { return }
            await MainActor.run {
                self.error = "Location error: \(error.localizedDescription)"
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
#if DEBUG
            print("📍 Location authorization granted")
#endif
            // Request a location update
            locationManager.startUpdatingLocation()
            
            // Add a timer to stop location updates after a short period
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
#if DEBUG
                print("⏱️ Stopping location updates after timeout")
#endif
                self?.locationManager.stopUpdatingLocation()
            }
            
            // Refresh weather data with new location permissions
            Task { [weak self] in
                guard let self = self else { return }
                await self.fetchWeather()
            }
        case .denied, .restricted:
#if DEBUG
            print("⚠️ Location permission denied")
#endif
            // Update useGPS to false when permissions are denied
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self._useGPS = false
                UserDefaults.standard.set(false, forKey: "useGPS")
            }
            
            // Let the user know they need to enable location access
            Task { [weak self] in
                guard let self = self else { return }
                await MainActor.run {
                    self.error = "Location access denied. Please enable in Settings or use manual coordinates."
                }
            }
        default:
            break
        }
    }
    
    func requestLocation() {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
#if DEBUG
            print("📍 Requesting location authorization")
#endif
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
#if DEBUG
            print("📍 Location authorization already granted, starting location updates")
#endif
            // Use startUpdatingLocation with a timeout instead of requestLocation
            locationManager.startUpdatingLocation()
            
            // Add a timer to stop location updates after a short period
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
#if DEBUG
                print("⏱️ Stopping location updates after timeout")
#endif
                self?.locationManager.stopUpdatingLocation()
            }
        case .denied, .restricted:
#if DEBUG
            print("⚠️ Location access denied or restricted")
#endif
            // Update useGPS to false when permissions are denied
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self._useGPS = false
                UserDefaults.standard.set(false, forKey: "useGPS")
            }
            
            // Fall back to manual coordinates if available
            Task { [weak self] in
                guard let self = self else { return }
                await MainActor.run {
                    self.error = "Location access denied. Please check your settings or enter coordinates manually."
                }
            }
        @unknown default:
#if DEBUG
            print("⚠️ Unknown location authorization status")
#endif
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func openSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    func hasValidDataSources() -> Bool {
        let wuApiKey = KeychainService.shared.getApiKey(forService: "wu") ?? ""
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        let owmApiKey = KeychainService.shared.getApiKey(forService: "owm") ?? ""
        let latitude = UserDefaults.standard.string(forKey: "latitude") ?? ""
        let longitude = UserDefaults.standard.string(forKey: "longitude") ?? ""
        
        // Check if we have valid API configurations
        let hasWUConfig = !wuApiKey.isEmpty && !stationID.isEmpty
        let hasOWMConfig = !owmApiKey.isEmpty
        
        // Check if we have valid location
        var hasValidLocation = false
        if useGPS {
            let status = locationManager.authorizationStatus
            hasValidLocation = hasValidLocationStatus(status)
        } else {
            if let lat = Double(latitude), let lon = Double(longitude) {
                hasValidLocation = lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
            }
        }
        
        // Return true if we have either:
        // 1. Valid WU config
        // 2. Valid OWM config with location
        // 3. Valid location (for OpenMeteo fallback)
        return hasWUConfig || (hasOWMConfig && hasValidLocation) || hasValidLocation
    }
    
    private func hasValidLocationStatus(_ status: CLAuthorizationStatus) -> Bool {
        #if os(iOS)
        return status == .authorizedWhenInUse || status == .authorizedAlways
        #else
        return status == .authorized
        #endif
    }
    
    private func weatherTypeFor(code: Int) -> String {
        switch code {
        case 0, 1: return "sunny"
        case 2, 3: return "cloudy"
        case 45, 48: return "foggy"
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return "rainy"
        case 71, 73, 75, 77, 85, 86: return "snowy"
        case 95, 96, 99: return "thunder"
        default: return "default"
        }
    }
    
    private func updateBackgroundCondition() {
        // First try to use the forecast if available
        if let forecast = forecast, let firstDay = forecast.daily.first {
            currentBackgroundCondition = weatherTypeFor(code: firstDay.weatherCode)
        }
        // If no forecast or if the weather condition suggests different weather, use that
        else if let weather = weather, weather.condition != "default" {
            currentBackgroundCondition = weather.condition
        }
        // Fallback to default
        else {
            currentBackgroundCondition = "default"
        }
    }
    
    // MARK: - Forecast Methods
    // Note: fetchForecasts() is implemented in WeatherService+OpenMeteo.swift extension
}

// MARK: - Array Extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Response Models
struct CurrentWeatherResponse: Codable {
    struct Main: Codable {
        let temp: Double
        let feels_like: Double
        let temp_min: Double
        let temp_max: Double
        let pressure: Double
        let humidity: Int
    }
    
    struct Wind: Codable {
        let speed: Double
        let gust: Double?
    }
    
    struct Clouds: Codable {
        let all: Int
    }
    
    let main: Main
    let wind: Wind
    let clouds: Clouds
}

extension WeatherService {
    enum WeatherError: Error {
        case invalidURL
        case invalidAPIKey
        case apiError(String)
        case decodingError(String)
        case noData
        
        var localizedDescription: String {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidAPIKey:
                return "Invalid API key"
            case .apiError(let message):
                return "API error: \(message)"
            case .decodingError(let message):
                return "Failed to decode response: \(message)"
            case .noData:
                return "No weather data available"
            }
        }
    }
}
