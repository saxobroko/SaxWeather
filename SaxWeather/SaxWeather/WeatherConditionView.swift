//
//  WeatherConditionView.swift
//  SaxWeather
//
//  Created by Saxon on 8/3/2025.
//


import SwiftUI

struct WeatherConditionView: View {
    let condition: String
    @State private var loadingFailed: Bool = false
    
    var body: some View {
        ZStack {
            if loadingFailed {
                // SF Symbol fallback
                Image(systemName: symbolNameFor(condition: condition))
                    .font(.system(size: 100))
                    .symbolRenderingMode(.multicolor)
            } else {
                // Try Lottie first
                LottieView(
                    name: animationNameFor(condition: condition),
                    loadingFailed: $loadingFailed
                )
            }
        }
        .frame(height: 150)
    }
    
    private func animationNameFor(condition: String) -> String {
        let lowercased = condition.lowercased()
        let isNight = isNighttime()
        
        if lowercased.contains("clear") || lowercased.contains("sunny") {
            return isNight ? "clear-night" : "clear-day"
        } else if lowercased.contains("partly cloudy") {
            return isNight ? "partly-cloudy-night" : "partly-cloudy"
        } else if lowercased.contains("cloud") || lowercased.contains("overcast") {
            return "cloudy"
        } else if lowercased.contains("fog") || lowercased.contains("mist") {
            return "foggy"
        } else if lowercased.contains("rain") || lowercased.contains("shower") || lowercased.contains("drizzle") {
            return "rainy"
        } else if lowercased.contains("snow") || lowercased.contains("sleet") || lowercased.contains("ice") {
            return "snow" // Make sure this file exists
        } else if lowercased.contains("thunder") || lowercased.contains("lightning") || lowercased.contains("storm") {
            return "thunderstorm"
        }
        
        return isNight ? "clear-night" : "clear-day"
    }
    
    private func symbolNameFor(condition: String) -> String {
        let lowercased = condition.lowercased()
        let isNight = isNighttime()
        
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
        
        return isNight ? "moon.stars.fill" : "sun.max.fill"
    }
    
    private func isNighttime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour > 18
    }
}