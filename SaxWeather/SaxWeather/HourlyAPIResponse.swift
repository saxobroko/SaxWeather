//
//  HourlyAPIResponse.swift
//  SaxWeather
//
//  Created by Saxon on 11/3/2025.
//

import Foundation

// MARK: - Hourly API Response
struct HourlyAPIResponse: Decodable {
    let latitude: Double
    let longitude: Double
    let timezone: String
    let hourly: HourlyData
    
    struct HourlyData: Decodable {
        let time: [String]
        let temperature_2m: [Double]
        let weather_code: [Int]
        let wind_speed_10m: [Double]
        let wind_gusts_10m: [Double]
    }
}

// MARK: - Hourly Data Model
public struct HourlyWeatherData: Identifiable {
    public let id: Int
    public let time: Date
    public let timeString: String
    public let temperature: Double
    public let weatherCode: Int
    public let windSpeed: Double
    public let windGust: Double
    
    public init(id: Int, time: Date, timeString: String, temperature: Double, weatherCode: Int, windSpeed: Double, windGust: Double) {
        self.id = id
        self.time = time
        self.timeString = timeString
        self.temperature = temperature
        self.weatherCode = weatherCode
        self.windSpeed = windSpeed
        self.windGust = windGust
    }
}
