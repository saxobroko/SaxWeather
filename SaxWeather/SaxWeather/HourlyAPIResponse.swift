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
struct HourlyData: Identifiable {
    let id: Int
    let time: Date
    let timeString: String
    let temperature: Double
    let weatherCode: Int
    let windSpeed: Double
    let windGust: Double
}
