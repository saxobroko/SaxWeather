//
//  WeatherService+WeatherKit.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-01-09
//

import Foundation
import CoreLocation

#if canImport(WeatherKit)
import WeatherKit

@available(iOS 16.0, macOS 13.0, *)
extension WeatherService {
    @MainActor
    func fetchWeatherKitWeather(latitude: String, longitude: String) async throws -> Weather {
        guard let lat = Double(latitude), let lon = Double(longitude) else {
            throw WeatherError.invalidURL
        }
        
        let location = CLLocation(latitude: lat, longitude: lon)
        
        // Capture unitSystem before entering the async context
        let units = self.unitSystem
        
        do {
            let weather = try await WeatherKit.WeatherService.shared.weather(for: location)
            
            #if DEBUG
            print("✅ WeatherKit Data Retrieved Successfully:")
            print("   - Temperature: \(weather.currentWeather.temperature.value)°C")
            print("   - Condition: \(weather.currentWeather.condition.description)")
            print("   - Humidity: \(weather.currentWeather.humidity)")
            print("   - Wind Speed: \(weather.currentWeather.wind.speed.value) m/s")
            print("   - Pressure: \(weather.currentWeather.pressure.value) mbar")
            print("   - Forecast days: \(weather.dailyForecast.forecast.count)")
            #endif
            
            var weatherData = Weather(
                weatherKitCurrent: weather.currentWeather,
                weatherKitDaily: weather.dailyForecast,
                unitSystem: units
            )
            
            // Convert units if needed
            if units != "Metric" {
                weatherData.convertUnits(from: "Metric", to: units)
            }
            
            // Store forecast data immediately from WeatherKit
            await MainActor.run {
                self.storeWeatherKitForecast(weather.dailyForecast, unitSystem: units)
            }
            
            return weatherData
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
    
    @MainActor
    private func storeWeatherKitForecast(_ dailyForecast: WeatherKit.Forecast<WeatherKit.DayWeather>, unitSystem: String) {
        // Convert WeatherKit forecast to app's WeatherForecast model
        let forecasts = dailyForecast.forecast.map { daily -> WeatherForecast.DailyForecast in
            // Convert WeatherKit condition to WMO weather code for consistency
            let weatherCode = mapWeatherKitConditionToWMOCode(daily.condition)
            
            #if DEBUG
            print("📅 WeatherKit Forecast: date=\(daily.date), condition=\(daily.condition), mappedCode=\(weatherCode)")
            #endif
            
            return WeatherForecast.DailyForecast(
                date: daily.date,
                tempMax: daily.highTemperature.value,
                tempMin: daily.lowTemperature.value,
                precipitation: daily.precipitationAmount.value,
                precipitationProbability: daily.precipitationChance,
                weatherCode: weatherCode, // Map WeatherKit condition to WMO code
                windSpeed: daily.wind.speed.value * 3.6, // m/s to km/h
                windDirection: daily.wind.direction.value, // Direction is not optional
                humidity: 0, // DayWeather doesn't provide daily humidity average
                pressure: 0, // DayWeather doesn't provide daily pressure average
                uvIndex: Double(daily.uvIndex.value),
                sunrise: daily.sun.sunrise,
                sunset: daily.sun.sunset
            )
        }
        
        self.forecast = WeatherForecast(daily: forecasts)
        self.forecastDataSource = "weatherkit" // Track forecast source
        
        #if DEBUG
        print("✅ Stored \(forecasts.count) days of forecast from WeatherKit")
        #endif
        
        // Update widget with high/low from today's forecast
        if let weather = self.weather {
            self.saveWeatherDataForWidget(weather)
        }
    }
    
    /// Maps WeatherKit WeatherCondition to OpenMeteo WMO weather code
    /// This ensures consistent weather icons across data sources
    private func mapWeatherKitConditionToWMOCode(_ condition: WeatherCondition) -> Int {
        switch condition {
        // Clear
        case .clear:
            return 0
        // Partly cloudy
        case .partlyCloudy, .mostlyClear:
            return 2
        // Cloudy
        case .cloudy, .mostlyCloudy:
            return 3
        // Fog
        case .foggy, .haze, .smoky:
            return 45
        // Drizzle
        case .drizzle:
            return 51
        // Rain
        case .rain, .heavyRain:
            return 61
        case .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms, .thunderstorms:
            return 95
        // Freezing rain
        case .freezingRain, .sleet:
            return 66
        // Snow
        case .snow, .heavySnow, .flurries, .blowingSnow:
            return 71
        case .frigid:
            return 71 // Treat as snow
        case .blizzard:
            return 75 // Heavy snow
        // Mixed precipitation
        case .wintryMix:
            return 66 // Freezing rain
        // Windy conditions
        case .breezy, .windy:
            return 3 // Treat as cloudy
        // Hot/Hurricane (no direct WMO equivalent, use cloudy)
        case .hot, .hurricane, .tropicalStorm:
            return 3
        // Sunflurries/Sunshowers - mixed conditions
        case .sunFlurries:
            return 85 // Snow showers
        case .sunShowers:
            return 80 // Rain showers
        default:
            return 0 // Default to clear if unknown
        }
    }
}
#endif
