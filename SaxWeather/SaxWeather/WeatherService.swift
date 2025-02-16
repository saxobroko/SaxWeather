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
        guard !apiKey.isEmpty, !stationID.isEmpty else { return nil }
        
        let urlString = "https://api.weather.com/v2/pws/observations/current?stationId=\(stationID)&format=json&units=m&apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let request = createURLRequest(from: url)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(WUResponse.self, from: data)
            return response.observations.first
        } catch {
            print("❌ Weather Underground Error:", error.localizedDescription)
            return nil
        }
    }
    
    private func fetchOWMWeather(
        apiKey: String,
        latitude: String,
        longitude: String,
        unitSystem: String
    ) async throws -> (OWMCurrent?, OWMDaily?) {
        guard !apiKey.isEmpty, !latitude.isEmpty, !longitude.isEmpty else {
            return (nil, nil)
        }
        
        let units = unitSystem == "Metric" ? "metric" : "imperial"
        let urlString = "https://api.openweathermap.org/data/2.5/onecall?lat=\(latitude)&lon=\(longitude)&exclude=minutely,hourly,alerts&units=\(units)&appid=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let request = createURLRequest(from: url)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(OWMResponse.self, from: data)
            return (response.current, response.daily.first)
        } catch {
            print("❌ OpenWeatherMap Error:", error.localizedDescription)
            return (nil, nil)
        }
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
