//
//  WeatherService.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-25 03:15:23
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
        
        async let openMeteoWeather = (wuApiKey.isEmpty || stationID.isEmpty) && owmApiKey.isEmpty ?
        fetchOpenMeteoWeather(
            latitude: latitude,
            longitude: longitude
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
}
