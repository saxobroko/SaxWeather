//
//  WeatherService.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-16 03:07:17
//

import Foundation
import CoreLocation

@MainActor
class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var weather: Weather?
    @Published var error: String?
    @Published var isLoading = false
    @Published var useGPS = false {
        didSet {
            if useGPS {
                requestLocation()
            } else {
                stopUpdatingLocation()
            }
        }
    }
    
    @Published var unitSystem: String {
        didSet {
            if oldValue != unitSystem {
                if var currentWeather = weather {
                    currentWeather.convertUnits(from: oldValue, to: unitSystem)
                    weather = currentWeather
                }
                UserDefaults.standard.set(unitSystem, forKey: "unitSystem")
            }
        }
    }
    
    private let locationManager: CLLocationManager
    private var lastLocationUpdate: Date?
    private let locationUpdateThreshold: TimeInterval = 300
    
    override init() {
        self.locationManager = CLLocationManager()
        self.unitSystem = UserDefaults.standard.string(forKey: "unitSystem") ?? "Metric"
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 1000
        locationManager.allowsBackgroundLocationUpdates = false
    }
    
    // MARK: - Weather Methods
    func fetchWeather() async {
        isLoading = true
        error = nil
        
        do {
            weather = try await fetchWeatherData()
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    private func fetchWeatherData() async throws -> Weather {
        let wuApiKey = UserDefaults.standard.string(forKey: "wuApiKey") ?? ""
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        let owmApiKey = UserDefaults.standard.string(forKey: "owmApiKey") ?? ""
        let latitude = useGPS ? "\(locationManager.location?.coordinate.latitude ?? 0)" :
                              UserDefaults.standard.string(forKey: "latitude") ?? ""
        let longitude = useGPS ? "\(locationManager.location?.coordinate.longitude ?? 0)" :
                               UserDefaults.standard.string(forKey: "longitude") ?? ""
        
        async let wuObservation = (!wuApiKey.isEmpty && !stationID.isEmpty) ?
            fetchWUWeather(apiKey: wuApiKey, stationID: stationID) :
            nil
        
        async let owmWeather = !owmApiKey.isEmpty ?
            fetchOWMWeather(
                apiKey: owmApiKey,
                latitude: latitude,
                longitude: longitude,
                unitSystem: unitSystem
            ) :
            (nil, nil)
        
        let (wuData, (owmCurrent, owmDaily)) = try await (wuObservation, owmWeather)
        
        var weather = Weather(
            wuObservation: wuData,
            owmCurrent: owmCurrent,
            owmDaily: owmDaily,
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
        
        // Add numericPrecision=decimal to the URL parameters
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
                print("- Humidity: \(observation.humidity)%")  // humidity is at root level
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
        // Updated to use the free Current Weather API
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(latitude)&lon=\(longitude)&units=\(units)&appid=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let request = createURLRequest(from: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Add response status code logging
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 OpenWeatherMap API Response Status: \(httpResponse.statusCode)")
                
                // Log response body for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📡 OpenWeatherMap API Response Body:")
                    print(responseString)
                }
                
                // Check for specific error status codes
                if httpResponse.statusCode == 401 {
                    print("❌ OpenWeatherMap Error: Invalid API key")
                    throw WeatherError.invalidAPIKey
                } else if httpResponse.statusCode != 200 {
                    print("❌ OpenWeatherMap Error: Unexpected status code \(httpResponse.statusCode)")
                    throw WeatherError.apiError("Status code: \(httpResponse.statusCode)")
                }
            }
            
            // Decode the new response format
            let currentWeather = try JSONDecoder().decode(CurrentWeatherResponse.self, from: data)
            
            // Convert the current weather response to our existing format
            let owmCurrent = OWMCurrent(
                temp: currentWeather.main.temp,
                feels_like: currentWeather.main.feels_like,
                humidity: Double(currentWeather.main.humidity),
                dew_point: calculateDewPoint(temp: currentWeather.main.temp, humidity: Double(currentWeather.main.humidity)),
                pressure: Double(currentWeather.main.pressure),
                wind_speed: currentWeather.wind.speed,
                wind_gust: currentWeather.wind.gust ?? 0,
                uvi: 0, // Current weather API doesn't provide UV index
                clouds: Double(currentWeather.clouds.all)
            )
            
            // Create a simple daily forecast using current temperature as both min and max
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

    // Helper function to calculate dew point since it's not provided in the current weather API
    private func calculateDewPoint(temp: Double, humidity: Double) -> Double {
        let a = 17.27
        let b = 237.7
        
        let alpha = ((a * temp) / (b + temp)) + log(humidity/100.0)
        let dewPoint = (b * alpha) / (a - alpha)
        return dewPoint
    }

    // New struct to match the Current Weather API response
    struct CurrentWeatherResponse: Codable {
        struct Main: Codable {
            let temp: Double
            let feels_like: Double
            let temp_min: Double
            let temp_max: Double
            let pressure: Int
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
    
    private func createURLRequest(from url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 15
        return request
    }
    
    // MARK: - Location Methods
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        if let lastUpdate = lastLocationUpdate,
           Date().timeIntervalSince(lastUpdate) < locationUpdateThreshold {
            return
        }
        
        print("✅ Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        UserDefaults.standard.set("\(location.coordinate.latitude)", forKey: "latitude")
        UserDefaults.standard.set("\(location.coordinate.longitude)", forKey: "longitude")
        lastLocationUpdate = Date()
        
        if useGPS {
            Task {
                await fetchWeather()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location update failed:", error.localizedDescription)
    }
}
