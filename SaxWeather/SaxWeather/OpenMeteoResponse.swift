//
//  OpenMeteoResponse.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-26 14:18:07
//

import Foundation

struct OpenMeteoResponse: Codable {
    let latitude: Double
    let longitude: Double
    let generationtime_ms: Double?
    let utc_offset_seconds: Int?
    let timezone: String?
    let timezone_abbreviation: String?
    let elevation: Double?
    // Make these optional since they're not always included in the response
    let current_units: CurrentUnits?
    let current: Current?
    let daily_units: DailyUnits?
    let daily: Daily
    
    init(from decoder: Decoder) throws {
        #if DEBUG
        print("⚡️ Starting to decode OpenMeteoResponse")
        #endif
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Debug print available keys
        #if DEBUG
        print("🔑 Available keys in JSON:", container.allKeys.map { $0.stringValue })
        #endif
        
        do {
            self.latitude = try container.decode(Double.self, forKey: .latitude)
            #if DEBUG
            print("✅ Decoded latitude:", self.latitude)
            #endif
            
            self.longitude = try container.decode(Double.self, forKey: .longitude)
            #if DEBUG
            print("✅ Decoded longitude:", self.longitude)
            #endif
            
            // Try decoding generationtime_ms with extra debug info
            #if DEBUG
            print("🔍 Attempting to decode generationtime_ms")
            #endif
            self.generationtime_ms = try container.decodeIfPresent(Double.self, forKey: .generationtime_ms)
            #if DEBUG
            print("✅ Successfully decoded generationtime_ms:", self.generationtime_ms ?? 0.0)
            #endif
            
            self.utc_offset_seconds = try container.decodeIfPresent(Int.self, forKey: .utc_offset_seconds)
            self.timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
            self.timezone_abbreviation = try container.decodeIfPresent(String.self, forKey: .timezone_abbreviation)
            self.elevation = try container.decodeIfPresent(Double.self, forKey: .elevation)
            
            // Make these optional - decode only if present
            self.current_units = try container.decodeIfPresent(CurrentUnits.self, forKey: .current_units)
            self.current = try container.decodeIfPresent(Current.self, forKey: .current)
            
            self.daily_units = try container.decodeIfPresent(DailyUnits.self, forKey: .daily_units)
            self.daily = try container.decode(Daily.self, forKey: .daily)
        } catch {
            #if DEBUG
            print("❌ Decoding error:", error)
            print("❌ Error location:", error.localizedDescription)
            #endif
            throw error
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case generationtime_ms
        case utc_offset_seconds
        case timezone
        case timezone_abbreviation
        case elevation
        case current_units
        case current
        case daily_units
        case daily
    }
    
    struct CurrentUnits: Codable {
        let time: String
        let interval: String
        let temperature_2m: String
        let relative_humidity_2m: String
        let apparent_temperature: String
        let precipitation: String
        let wind_speed_10m: String
        let wind_gusts_10m: String
        let pressure_msl: String
        let cloud_cover: String
        let uv_index: String
    }
    
    struct Current: Codable {
        let time: String?
        let interval: Int?
        let temperature_2m: Double?
        let relative_humidity_2m: Int?
        let apparent_temperature: Double?
        let precipitation: Double?
        let wind_speed_10m: Double?
        let wind_gusts_10m: Double?
        // Current wind direction in degrees (0-360). Optional
        // because older cached Open-Meteo responses may not
        // include it. Callers fall back to the daily-dominant
        // direction when this is nil.
        let wind_direction_10m: Double?
        let pressure_msl: Double?
        let cloud_cover: Int?
        let uv_index: Double?
    }
    
    struct DailyUnits: Codable {
        let time: String
        let temperature_2m_max: String
        let temperature_2m_min: String
        let precipitation_sum: String
        let precipitation_probability_max: String
        let weather_code: String
        let wind_speed_10m_max: String
        let wind_direction_10m_dominant: String
        let relative_humidity_2m_max: String
        let pressure_msl_max: String
        let uv_index_max: String
        let sunrise: String
        let sunset: String
    }
    
    struct Daily: Codable {
        let time: [String]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let precipitation_sum: [Double?]
        let precipitation_probability_max: [Int]
        let weather_code: [Int]
        let wind_speed_10m_max: [Double]
        let wind_direction_10m_dominant: [Double?]
        let relative_humidity_2m_max: [Int]
        let pressure_msl_max: [Double]
        let uv_index_max: [Double]
        let sunrise: [String]
        let sunset: [String]
    }
}

// MARK: - Helper Extensions
extension OpenMeteoResponse {
    func getDate(from dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withTimeZone]
        return formatter.date(from: dateString)
    }
    
    var currentDate: Date? {
        guard let current = current, let time = current.time else { return nil }
        return getDate(from: time)
    }
}

// MARK: - Weather Integration Extensions
extension OpenMeteoResponse.Current {
    var temperature2m: Double { temperature_2m ?? 0.0 }
    var relativeHumidity2m: Double { Double(relative_humidity_2m ?? 0) }
    var apparentTemperature: Double { apparent_temperature ?? 0.0 }
    var windSpeed10m: Double { wind_speed_10m ?? 0.0 }
    var windGusts10m: Double { wind_gusts_10m ?? 0.0 }
    var pressureMsl: Double { pressure_msl ?? 0.0 }
    var cloudCover: Int { cloud_cover ?? 0 }
    var uvIndex: Double { uv_index ?? 0.0 }
}

extension OpenMeteoResponse.Daily {
    var temperature2mMax: [Double] { temperature_2m_max }
    var temperature2mMin: [Double] { temperature_2m_min }
    var precipitationSum: [Double] { precipitation_sum.map { $0 ?? 0.0 } }
    var precipitationProbabilityMax: [Int] { precipitation_probability_max }
    var weatherCode: [Int] { weather_code }
    var windSpeed10mMax: [Double] { wind_speed_10m_max }
    var windDirection10mDominant: [Int] { wind_direction_10m_dominant.map { Int($0 ?? 0.0) } }
    var relativeHumidity2mMax: [Double] { relative_humidity_2m_max.map { Double($0) } }
    var pressureMslMax: [Double] { pressure_msl_max }
    var uvIndexMax: [Double] { uv_index_max }
    var dates: [Date] { time.compactMap { getDate(from: $0) } } // Changed from 'time' to 'dates'
    
    private func getDate(from dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withTimeZone]
        return formatter.date(from: dateString)
    }
}
