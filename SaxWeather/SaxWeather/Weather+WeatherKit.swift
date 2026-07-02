//
//  Weather+WeatherKit.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-01-09
//

import Foundation

#if canImport(WeatherKit)
import WeatherKit
import CoreLocation

// Define a typealias to avoid naming conflicts
typealias AppleWeather = WeatherKit.Weather
typealias AppleCurrentWeather = WeatherKit.CurrentWeather
typealias AppleDayWeather = WeatherKit.DayWeather
typealias AppleForecast = WeatherKit.Forecast

@available(iOS 16.0, macOS 13.0, *)
extension Weather {
    /// Initialize Weather from WeatherKit data
    init(weatherKitCurrent: AppleCurrentWeather, weatherKitDaily: AppleForecast<AppleDayWeather>?, unitSystem: String = "Metric") {
        // Current weather data - WeatherKit uses Celsius by default
        let temp = weatherKitCurrent.temperature.value
        let feels = weatherKitCurrent.apparentTemperature.value
        let hum = weatherKitCurrent.humidity * 100 // Convert to percentage
        let dew = weatherKitCurrent.dewPoint.value
        let press = weatherKitCurrent.pressure.value
        let windSpd = weatherKitCurrent.wind.speed.value * 3.6 // Convert m/s to km/h for metric
        var windGst = weatherKitCurrent.wind.gust?.value ?? 0
        if windGst > 0 {
            windGst = windGst * 3.6 // Convert m/s to km/h
        }
        let uv = weatherKitCurrent.uvIndex.value
        let solar = weatherKitCurrent.cloudCover * 100 // Cloud cover as percentage
        
        // Daily forecast data (high/low)
        var hi: Double? = nil
        var lo: Double? = nil
        if let daily = weatherKitDaily?.first {
            hi = daily.highTemperature.value
            lo = daily.lowTemperature.value
        }
        
        // Call the existing initializer
        self.init(
            wuObservation: nil,
            owmCurrent: OWMCurrent(
                temp: temp,
                feels_like: feels,
                humidity: hum,
                dew_point: dew,
                pressure: press,
                wind_speed: windSpd,
                wind_gust: windGst,
                uvi: uv,
                clouds: solar
            ),
            owmDaily: hi != nil && lo != nil ? OWMDaily(temp: OWMDaily.OWMDailyTemp(min: lo!, max: hi!)) : nil,
            unitSystem: unitSystem
        )
    }
}

#endif
