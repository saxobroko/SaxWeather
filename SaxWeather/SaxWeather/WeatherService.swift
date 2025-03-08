//
//  WeatherService.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-25 04:49:47
//

import Foundation
import CoreLocation

class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var weather: Weather?
    @Published var forecast: WeatherForecast?
    @Published var error: String?
    @Published var isLoading = false
    @Published private(set) var _useGPS: Bool
    @Published private(set) var _unitSystem: String
    
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
            _useGPS = newValue
            UserDefaults.standard.set(newValue, forKey: "useGPS")
            
            if newValue {
                requestLocation()
            } else {
                // Validate saved coordinates - if they're empty, revert to GPS
                let savedLat = UserDefaults.standard.string(forKey: "latitude") ?? ""
                let savedLon = UserDefaults.standard.string(forKey: "longitude") ?? ""
                
                if savedLat.isEmpty || savedLon.isEmpty {
                    print("⚠️ No saved coordinates found, reverting to GPS")
                    _useGPS = true
                    UserDefaults.standard.set(true, forKey: "useGPS")
                    requestLocation()
                } else {
                    locationManager.stopUpdatingLocation()
                }
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
        let wuApiKey = UserDefaults.standard.string(forKey: "wuApiKey") ?? ""
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        let owmApiKey = UserDefaults.standard.string(forKey: "owmApiKey") ?? ""
        
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
                print("⚠️ No valid coordinates available for weather data, requesting location")
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
        
        async let wuObservation = (!wuApiKey.isEmpty && !stationID.isEmpty) ?
            fetchWUWeather(apiKey: wuApiKey, stationID: stationID) :
            nil

        async let owmWeather = !owmApiKey.isEmpty ?
            fetchOWMWeather(
                apiKey: owmApiKey,
                latitude: lat,  // Using immutable copy
                longitude: lon,  // Using immutable copy
                unitSystem: unitSystem
            ) :
            (nil, nil)

        async let openMeteoWeather = (wuApiKey.isEmpty || stationID.isEmpty) && owmApiKey.isEmpty ?
            fetchOpenMeteoWeather(
                latitude: lat,  // Using immutable copy
                longitude: lon  // Using immutable copy
            ) :
        (nil, nil)
        
        let (wuData, (owmCurrent, owmDaily), (openMeteoCurrent, openMeteoDaily)) = try await (wuObservation, owmWeather, openMeteoWeather)
        
        var weather = Weather(
            wuObservation: wuData,
            owmCurrent: owmCurrent ?? openMeteoCurrent,
            owmDaily: owmDaily ?? openMeteoDaily,
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
            print("❌ Weather Underground Error: Empty API key or station ID")
            throw WeatherError.invalidAPIKey
        }
        
        let urlString = "https://api.weather.com/v2/pws/observations/current?stationId=\(stationID)&format=json&units=m&numericPrecision=decimal&apiKey=\(apiKey)"
        print("🌐 Weather Underground URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Weather Underground Error: Invalid URL")
            throw WeatherError.invalidURL
        }
        
        var request = createURLRequest(from: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Weather Underground Response Status: \(httpResponse.statusCode)")
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 Weather Underground Response Body:")
                print(responseString)
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let wuResponse = try decoder.decode(WUResponse.self, from: data)
            
            if let observation = wuResponse.observations.first {
                print("✅ Weather Underground Data Parsed Successfully:")
                print("- Temperature: \(observation.metric.temp)°C")
                print("- Humidity: \(observation.humidity)%")
                print("- Wind Speed: \(observation.metric.windSpeed) m/s")
                print("- Pressure: \(observation.metric.pressure) hPa")
            }
            
            return wuResponse.observations.first
        } catch {
            print("❌ Weather Underground Error:", error)
            print("❌ Error Details:", error.localizedDescription)
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
            print("❌ OpenWeatherMap Error:", error.localizedDescription)
            print("❌ Error Details:", error)
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
        print("📍 Location updated: \(locations.first?.coordinate ?? CLLocationCoordinate2D())")
        
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
        print("❌ Location Error: \(error.localizedDescription)")
        
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
            print("📍 Location authorization granted")
            // Request a location update
            locationManager.startUpdatingLocation()
            
            // Add a timer to stop location updates after a short period
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                print("⏱️ Stopping location updates after timeout")
                self?.locationManager.stopUpdatingLocation()
            }
            
            // Refresh weather data with new location permissions
            Task { [weak self] in
                guard let self = self else { return }
                await self.fetchWeather()
            }
        case .denied, .restricted:
            print("⚠️ Location permission denied")
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
            print("📍 Requesting location authorization")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 Location authorization already granted, starting location updates")
            // Use startUpdatingLocation with a timeout instead of requestLocation
            locationManager.startUpdatingLocation()
            
            // Add a timer to stop location updates after a short period
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                print("⏱️ Stopping location updates after timeout")
                self?.locationManager.stopUpdatingLocation()
            }
        case .denied, .restricted:
            print("⚠️ Location access denied or restricted")
            // Fall back to manual coordinates if available
            Task { [weak self] in
                guard let self = self else { return }
                await MainActor.run {
                    self.error = "Location access denied. Please check your settings or enter coordinates manually."
                }
            }
        @unknown default:
            print("⚠️ Unknown location authorization status")
            locationManager.requestWhenInUseAuthorization()
        }
    }
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
