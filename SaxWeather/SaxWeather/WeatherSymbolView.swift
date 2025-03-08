//
//  WeatherSymbolView.swift
//  SaxWeather
//

import SwiftUI

struct WeatherSymbolView: View {
    let condition: String
    var isNight: Bool = false
    
    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 100))
            .symbolRenderingMode(.multicolor)
    }
    
    private var symbolName: String {
        let lowercased = condition.lowercased()
        
        if lowercased.contains("clear") || lowercased.contains("sunny") {
            return isNight ? "moon.stars.fill" : "sun.max.fill"
        } else if lowercased.contains("partly cloudy") {
            return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        } else if lowercased.contains("cloud") || lowercased.contains("overcast") {
            return "cloud.fill"
        } else if lowercased.contains("fog") || lowercased.contains("mist") {
            return "cloud.fog.fill"
        } else if lowercased.contains("rain") || lowercased.contains("shower") || lowercased.contains("drizzle") {
            return "cloud.rain.fill"
        } else if lowercased.contains("snow") || lowercased.contains("sleet") || lowercased.contains("ice") {
            return "cloud.snow.fill"
        } else if lowercased.contains("thunder") || lowercased.contains("lightning") || lowercased.contains("storm") {
            return "cloud.bolt.rain.fill"
        }
        
        return "sun.max.fill" // Default fallback
    }
}
