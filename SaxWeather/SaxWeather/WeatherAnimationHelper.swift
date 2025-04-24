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
        case _ where conditionLower.contains("clear") || conditionLower.contains("sunny"):
            return isNight ? "clear-night" : "clear-day"
        case _ where conditionLower.contains("partly cloudy"):
            return isNight ? "partly-cloudy-night" : "partly-cloudy"
        case _ where conditionLower.contains("cloud") || conditionLower.contains("overcast"):
            return "cloudy"
        case _ where conditionLower.contains("fog") || conditionLower.contains("mist"):
            return "foggy"
        case _ where conditionLower.contains("rain") || conditionLower.contains("shower") || 
                  conditionLower.contains("drizzle") || conditionLower.contains("snow") || 
                  conditionLower.contains("sleet") || conditionLower.contains("ice"):
            return "rainy"
        case _ where conditionLower.contains("thunder") || conditionLower.contains("lightning") || 
                  conditionLower.contains("storm"):
            return "thunderstorm"
        default:
            return isNight ? "clear-night" : "clear-day"
        }
    }
    
    /// Maps OpenMeteo WMO weather codes to animation names
    static func animationNameFromCode(for weatherCode: Int, isNight: Bool = false) -> String {
        switch weatherCode {
        case 0: // Clear
            return isNight ? "clear-night" : "clear-day"
        case 1, 2: // Partly cloudy
            return isNight ? "partly-cloudy-night" : "partly-cloudy"
        case 3: // Overcast
            return "cloudy"
        case 45, 48: // Fog
            return "foggy"
        case 51, 53, 55, 61, 63, 65, 66, 67, 80, 81, 82, // Rain
             71, 73, 75, 77, 85, 86: // Snow
            return "rainy"
        case 95, 96, 99: // Thunderstorm
            return "thunderstorm"
        default:
            return isNight ? "clear-night" : "clear-day"
        }
    }
    
    /// Determine if it's nighttime based on current time and sunrise/sunset
    static func isNighttime(sunrise: Date?, sunset: Date?) -> Bool {
        if let sunrise = sunrise, let sunset = sunset {
            let now = Date()
            return now < sunrise || now > sunset
        }
        
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour > 18
    }
}
