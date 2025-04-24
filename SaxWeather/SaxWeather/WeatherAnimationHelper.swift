//
//  WeatherAnimationHelper.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-03-08
//

import Foundation

struct WeatherAnimationHelper {
    /// Maps weather condition strings to animation names
    static func animationName(for condition: String, isNight: Bool = false) -> String {
        let conditionLower = condition.lowercased()
        
        switch conditionLower {
        case _ where conditionLower.contains("clear"):
            return isNight ? "clear-night" : "clear-day"
        case _ where conditionLower.contains("partly cloudy"):
            return isNight ? "partly-cloudy-night" : "partly-cloudy-day"
        case _ where conditionLower.contains("cloudy") || conditionLower.contains("overcast"):
            return "cloudy"
        case _ where conditionLower.contains("fog") || conditionLower.contains("mist"):
            return "foggy"
        case _ where conditionLower.contains("drizzle") || conditionLower.contains("light rain"):
            return "rainy"
        case _ where conditionLower.contains("rain") || conditionLower.contains("shower"):
            return "rainy"
        case _ where conditionLower.contains("snow") || conditionLower.contains("sleet") || conditionLower.contains("ice"):
            return "rainy"
        case _ where conditionLower.contains("thunder") || conditionLower.contains("lightning"):
            return "thunderstorm"
        default:
            return isNight ? "clear-night" : "clear-day"
        }
    }
    
    /// Maps OpenMeteo WMO weather codes to animation names
    static func animationNameFromCode(for weatherCode: Int, isNight: Bool = false) -> String {
        switch weatherCode {
        // Clear
        case 0:
            return isNight ? "clear-night" : "clear-day"
        // Mainly clear, partly cloudy
        case 1, 2:
            return isNight ? "partly-cloudy-night" : "partly-cloudy"
        // Overcast
        case 3:
            return "cloudy"
        // Fog
        case 45, 48:
            return "fog"
        // All rain types
        case 51, 53, 55, 61, 63, 65, 66, 67, 80, 81, 82:
            return "rain"
        // Snow
        case 71, 73, 75, 77, 85, 86:
            return "snow"
        // Thunderstorm
        case 95, 96, 99:
            return "thunderstorm"
        default:
            return isNight ? "clear-night" : "clear-day"
        }
    }
    
    /// Determine if it's nighttime based on current time and sunrise/sunset
    static func isNighttime(sunrise: Date?, sunset: Date?) -> Bool {
        guard let sunrise = sunrise, let sunset = sunset else {
            let hour = Calendar.current.component(.hour, from: Date())
            return hour < 6 || hour > 18
        }
        
        let now = Date()
        return now < sunrise || now > sunset
    }
}
