//
//  WeatherKitService.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-01-09
//

import Foundation
import WeatherKit
import CoreLocation

@available(iOS 16.0, macOS 13.0, *)
actor WeatherKitService {
    private let weatherService = WeatherKit.WeatherService.shared
    
    func fetchWeather(latitude: Double, longitude: Double) async throws -> (current: WeatherKit.CurrentWeather, daily: Forecast<DayWeather>?, hourly: Forecast<HourWeather>?) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        #if DEBUG
        print("📡 Fetching weather from WeatherKit for location: \(latitude), \(longitude)")
        #endif
        
        do {
            let weather = try await weatherService.weather(for: location)
            
            #if DEBUG
            print("✅ WeatherKit Data Retrieved Successfully:")
            print("   - Temperature: \(weather.currentWeather.temperature.value)°C")
            print("   - Condition: \(weather.currentWeather.condition.description)")
            print("   - Humidity: \(weather.currentWeather.humidity)")
            print("   - Wind Speed: \(weather.currentWeather.wind.speed.value) m/s")
            print("   - Pressure: \(weather.currentWeather.pressure.value) mbar")
            #endif
            
            return (weather.currentWeather, weather.dailyForecast, weather.hourlyForecast)
        } catch {
            #if DEBUG
            print("❌ WeatherKit Error: \(error.localizedDescription)")
            #endif
            // Funnel through `WeatherError.from(_:)` so URL
            // errors (offline, timeout, DNS) get mapped to
            // `.noNetwork` / `.timeout` rather than a generic
            // `.apiError`. The caller will then surface the
            // right message to the user.
            throw WeatherError.from(error)
        }
    }
}
