//
//  ExtendedWeatherData.swift
//  SaxWeather
//
//  Created on 13/01/2026
//

import Foundation
import SwiftUI

// MARK: - Air Quality Index
struct AirQualityData: Codable {
    let aqi: Int
    let category: AQICategory
    let pollutants: Pollutants?
    
    enum AQICategory: String, Codable {
        case good = "Good"
        case moderate = "Moderate"
        case unhealthyForSensitive = "Unhealthy for Sensitive Groups"
        case unhealthy = "Unhealthy"
        case veryUnhealthy = "Very Unhealthy"
        case hazardous = "Hazardous"
        
        var color: Color {
            switch self {
            case .good: return .green
            case .moderate: return .yellow
            case .unhealthyForSensitive: return .orange
            case .unhealthy: return .red
            case .veryUnhealthy: return .purple
            case .hazardous: return .brown
            }
        }
        
        var healthAdvice: String {
            switch self {
            case .good:
                return "Air quality is good. Ideal for outdoor activities."
            case .moderate:
                return "Air quality is acceptable. Unusually sensitive people should limit prolonged outdoor exertion."
            case .unhealthyForSensitive:
                return "Sensitive groups should reduce prolonged or heavy outdoor exertion."
            case .unhealthy:
                return "Everyone should reduce prolonged or heavy outdoor exertion."
            case .veryUnhealthy:
                return "Health warnings. Everyone should avoid prolonged outdoor exertion."
            case .hazardous:
                return "Health alert. Everyone should avoid all outdoor exertion."
            }
        }
        
        static func from(aqi: Int) -> AQICategory {
            switch aqi {
            case 0...50: return .good
            case 51...100: return .moderate
            case 101...150: return .unhealthyForSensitive
            case 151...200: return .unhealthy
            case 201...300: return .veryUnhealthy
            default: return .hazardous
            }
        }
    }
    
    struct Pollutants: Codable {
        let pm25: Double?
        let pm10: Double?
        let o3: Double?
        let no2: Double?
        let so2: Double?
        let co: Double?
    }
}

// MARK: - UV Index Enhanced
struct UVIndexData {
    let index: Int
    let category: UVCategory
    let timeToBurn: String
    let sunscreenRecommendation: String
    let peakHours: String
    
    enum UVCategory: String {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case veryHigh = "Very High"
        case extreme = "Extreme"
        
        var color: Color {
            switch self {
            case .low: return .green
            case .moderate: return .yellow
            case .high: return .orange
            case .veryHigh: return .red
            case .extreme: return .purple
            }
        }
        
        static func from(uvIndex: Int) -> UVCategory {
            switch uvIndex {
            case 0...2: return .low
            case 3...5: return .moderate
            case 6...7: return .high
            case 8...10: return .veryHigh
            default: return .extreme
            }
        }
    }
    
    init(uvIndex: Int) {
        self.index = uvIndex
        self.category = UVCategory.from(uvIndex: uvIndex)
        
        // Calculate time to burn (assumes fair skin)
        switch uvIndex {
        case 0...2:
            self.timeToBurn = "60+ minutes"
            self.sunscreenRecommendation = "Minimal sun protection required"
        case 3...5:
            self.timeToBurn = "30-45 minutes"
            self.sunscreenRecommendation = "SPF 15+ recommended"
        case 6...7:
            self.timeToBurn = "15-25 minutes"
            self.sunscreenRecommendation = "SPF 30+ required"
        case 8...10:
            self.timeToBurn = "10-15 minutes"
            self.sunscreenRecommendation = "SPF 50+ required, seek shade"
        default:
            self.timeToBurn = "< 10 minutes"
            self.sunscreenRecommendation = "SPF 50+ required, avoid sun 10am-4pm"
        }
        
        self.peakHours = "10:00 AM - 4:00 PM"
    }
}

// MARK: - Pollen Data
struct PollenData: Codable {
    let tree: PollenLevel?
    let grass: PollenLevel?
    let weed: PollenLevel?
    
    enum PollenLevel: Int, Codable {
        case none = 0
        case low = 1
        case moderate = 2
        case high = 3
        case veryHigh = 4
        
        var description: String {
            switch self {
            case .none: return "None"
            case .low: return "Low"
            case .moderate: return "Moderate"
            case .high: return "High"
            case .veryHigh: return "Very High"
            }
        }
        
        var color: Color {
            switch self {
            case .none: return .gray
            case .low: return .green
            case .moderate: return .yellow
            case .high: return .orange
            case .veryHigh: return .red
            }
        }
    }
    
    var warning: String? {
        let levels = [tree, grass, weed].compactMap { $0 }
        let highLevels = levels.filter { $0.rawValue >= PollenLevel.high.rawValue }
        
        if !highLevels.isEmpty {
            return "High pollen alert! Allergy sufferers should take precautions."
        } else if levels.contains(where: { $0 == .moderate }) {
            return "Moderate pollen levels. Monitor symptoms if sensitive."
        }
        return nil
    }
}

// MARK: - Sun/Moon Data
struct SunMoonData: Codable {
    let sunrise: Date
    let sunset: Date
    let moonPhase: MoonPhase
    let moonrise: Date?
    let moonset: Date?
    
    enum MoonPhase: String, Codable {
        case newMoon = "New Moon"
        case waxingCrescent = "Waxing Crescent"
        case firstQuarter = "First Quarter"
        case waxingGibbous = "Waxing Gibbous"
        case fullMoon = "Full Moon"
        case waningGibbous = "Waning Gibbous"
        case lastQuarter = "Last Quarter"
        case waningCrescent = "Waning Crescent"
        
        var icon: String {
            switch self {
            case .newMoon: return "moonphase.new.moon"
            case .waxingCrescent: return "moonphase.waxing.crescent"
            case .firstQuarter: return "moonphase.first.quarter"
            case .waxingGibbous: return "moonphase.waxing.gibbous"
            case .fullMoon: return "moonphase.full.moon"
            case .waningGibbous: return "moonphase.waning.gibbous"
            case .lastQuarter: return "moonphase.last.quarter"
            case .waningCrescent: return "moonphase.waning.crescent"
            }
        }
        
        var description: String {
            switch self {
            case .newMoon: return "Best for stargazing"
            case .waxingCrescent, .waningCrescent: return "Good for evening/morning observation"
            case .firstQuarter, .lastQuarter: return "Half moon visible"
            case .waxingGibbous, .waningGibbous: return "Nearly full illumination"
            case .fullMoon: return "Peak brightness, ideal for night activities"
            }
        }
        
        static func from(phase: Double) -> MoonPhase {
            // Phase is 0-1 where 0 = new moon, 0.5 = full moon
            switch phase {
            case 0..<0.0625, 0.9375...1.0: return .newMoon
            case 0.0625..<0.1875: return .waxingCrescent
            case 0.1875..<0.3125: return .firstQuarter
            case 0.3125..<0.4375: return .waxingGibbous
            case 0.4375..<0.5625: return .fullMoon
            case 0.5625..<0.6875: return .waningGibbous
            case 0.6875..<0.8125: return .lastQuarter
            default: return .waningCrescent
            }
        }
    }
    
    var goldenHour: (morning: DateInterval, evening: DateInterval) {
        let calendar = Calendar.current
        
        // Morning golden hour: 1 hour before to 1 hour after sunrise
        let morningStart = calendar.date(byAdding: .hour, value: -1, to: sunrise) ?? sunrise
        let morningEnd = calendar.date(byAdding: .hour, value: 1, to: sunrise) ?? sunrise
        
        // Evening golden hour: 1 hour before to sunset
        let eveningStart = calendar.date(byAdding: .hour, value: -1, to: sunset) ?? sunset
        
        return (
            morning: DateInterval(start: morningStart, end: morningEnd),
            evening: DateInterval(start: eveningStart, end: sunset)
        )
    }
}

// MARK: - Hourly Precipitation
struct HourlyPrecipitation: Codable {
    let hour: Date
    let probability: Int // 0-100
    let amount: Double // mm
    
    var intensityDescription: String {
        switch amount {
        case 0: return "None"
        case 0..<0.5: return "Light"
        case 0.5..<2.5: return "Moderate"
        case 2.5..<10: return "Heavy"
        default: return "Very Heavy"
        }
    }
}

// MARK: - What to Wear
struct WhatToWearSuggestion: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

struct WhatToWearData {
    let suggestions: [WhatToWearSuggestion]
    let feelsLikeSummary: String?

    /// Rule-based clothing and accessory suggestions derived from
    /// feels-like temperature, hourly rain probability, wind speed,
    /// and UV index. Returns `nil` when there isn't enough base
    /// weather data to produce meaningful advice.
    static func from(weather: Weather, unitSystem: UnitSystem) -> WhatToWearData? {
        let effectiveTemp = weather.feelsLike ?? weather.temperature
        guard effectiveTemp != nil
            || weather.windSpeed != nil
            || !weather.hourlyPrecipitation.isEmpty
            || weather.uvIndex != nil
        else { return nil }

        var suggestions: [WhatToWearSuggestion] = []

        if let temp = effectiveTemp {
            suggestions.append(contentsOf: clothingSuggestions(
                feelsLike: temp,
                unitSystem: unitSystem
            ))
        }

        if let rainSuggestion = rainSuggestion(
            hourlyData: weather.hourlyPrecipitation,
            timeZoneIdentifier: weather.locationTimeZoneIdentifier
        ) {
            suggestions.append(rainSuggestion)
        }

        if let windSpeed = weather.windSpeed,
           let windSuggestion = windSuggestion(windSpeed: windSpeed, unitSystem: unitSystem) {
            suggestions.append(windSuggestion)
        }

        if let uvIndex = weather.uvIndex,
           let uvSuggestion = uvSuggestion(uvIndex: uvIndex) {
            suggestions.append(uvSuggestion)
        }

        guard !suggestions.isEmpty else { return nil }

        let feelsLikeSummary: String?
        if let feelsLike = weather.feelsLike {
            let label = unitSystem.temperatureLabel
            feelsLikeSummary = String(format: "Feels like %.0f%@", feelsLike, label)
        } else {
            feelsLikeSummary = nil
        }

        return WhatToWearData(
            suggestions: suggestions,
            feelsLikeSummary: feelsLikeSummary
        )
    }

    // MARK: - Clothing (feels-like)

    private static func clothingSuggestions(
        feelsLike: Double,
        unitSystem: UnitSystem
    ) -> [WhatToWearSuggestion] {
        let celsius = UnitConverter.convertTemperature(
            feelsLike,
            from: unitSystem,
            to: .metric
        )

        let text: String
        let icon: String
        switch celsius {
        case ..<(-5):
            text = "Heavy coat, hat & gloves"
            icon = "snowflake"
        case (-5)..<5:
            text = "Warm jacket & layers"
            icon = "coat.fill"
        case 5..<12:
            text = "Jacket recommended"
            icon = "coat.fill"
        case 12..<18:
            text = "Light jacket or sweater"
            icon = "wind"
        case 18..<24:
            text = "Comfortable — light layers optional"
            icon = "tshirt"
        case 24..<30:
            text = "Short sleeves, breathable fabrics"
            icon = "tshirt.fill"
        default:
            text = "Stay cool — light clothing & hydrate"
            icon = "sun.max.fill"
        }

        return [WhatToWearSuggestion(icon: icon, text: text)]
    }

    // MARK: - Rain (hourly precipitation)

    private static let rainProbabilityThreshold = 50

    private static func rainSuggestion(
        hourlyData: [HourlyPrecipitation],
        timeZoneIdentifier: String?
    ) -> WhatToWearSuggestion? {
        guard !hourlyData.isEmpty else { return nil }

        var calendar = Calendar.current
        if let timeZoneIdentifier,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = timeZone
        }

        let now = Date()
        let upcoming = hourlyData.filter {
            calendar.compare($0.hour, to: now, toGranularity: .hour) != .orderedAscending
        }

        guard let rainHour = upcoming.first(where: {
            $0.probability >= rainProbabilityThreshold
        }) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = calendar.timeZone

        let isCurrentHour = calendar.isDate(rainHour.hour, equalTo: now, toGranularity: .hour)
        let timeLabel = formatter.string(from: rainHour.hour)

        let text: String
        if isCurrentHour {
            text = rainHour.probability >= 70
                ? "Umbrella recommended now"
                : "Umbrella recommended"
        } else {
            text = "Umbrella after \(timeLabel)"
        }

        return WhatToWearSuggestion(icon: "umbrella.fill", text: text)
    }

    // MARK: - Wind

    private static func windSuggestion(
        windSpeed: Double,
        unitSystem: UnitSystem
    ) -> WhatToWearSuggestion? {
        let kmh = UnitConverter.convertWind(windSpeed, from: unitSystem, to: .metric)

        switch kmh {
        case 60...:
            return WhatToWearSuggestion(
                icon: "wind",
                text: "Strong winds — windbreaker & secure loose items"
            )
        case 40..<60:
            return WhatToWearSuggestion(
                icon: "wind",
                text: "Windbreaker recommended"
            )
        default:
            return nil
        }
    }

    // MARK: - UV

    private static func uvSuggestion(uvIndex: Int) -> WhatToWearSuggestion? {
        switch uvIndex {
        case 8...:
            return WhatToWearSuggestion(
                icon: "sun.max.fill",
                text: "SPF 50+ & hat — high UV"
            )
        case 6...7:
            return WhatToWearSuggestion(
                icon: "sun.max.fill",
                text: "SPF 30+ & hat recommended"
            )
        case 3...5:
            return WhatToWearSuggestion(
                icon: "sun.max.fill",
                text: "Sunscreen recommended"
            )
        default:
            return nil
        }
    }
}
