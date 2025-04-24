//
//  WeatherAnimationView.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-03-08
//

import SwiftUI

struct WeatherAnimationView: View {
    let weather: Weather?
    let forecast: WeatherForecast? // Changed from ForecastData to match your model
    @State private var animationLoaded = false
    
    var body: some View {
        ZStack {
            // Try to load Lottie animation based on condition
            if let condition = weather?.condition {
                let isNight = determineIfNight()
                LottieView(name: animationNameForCondition(condition, isNight: isNight))
                    .frame(width: 150, height: 150)
                    .onAppear {
                        // Mark as loaded after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            animationLoaded = true
                        }
                    }
            } else {
                // Fallback if no weather data available
                LottieView(name: "clear_day")
                    .frame(width: 150, height: 150)
            }
            
            // Fallback to SF Symbol if animation doesn't load
            if !animationLoaded {
                Image(systemName: fallbackSymbolName())
                    .font(.system(size: 80))
                    .symbolRenderingMode(.multicolor)
                    .opacity(animationLoaded ? 0 : 1)
            }
        }
    }
    
    private func determineIfNight() -> Bool {
        // Check if we have sunrise/sunset data in the forecast
        if let daily = forecast?.daily.first,
           let sunrise = daily.sunrise,
           let sunset = daily.sunset {
            let now = Date()
            return now < sunrise || now > sunset
        } else {
            // Fallback to time-based detection
            let hour = Calendar.current.component(.hour, from: Date())
            return hour < 6 || hour > 18
        }
    }
    
    private func animationNameForCondition(_ condition: String, isNight: Bool) -> String {
        let lowercased = condition.lowercased()
        
        if lowercased.contains("clear") || lowercased.contains("sunny") {
            return isNight ? "clear-night" : "clear-day"
        } else if lowercased.contains("partly cloudy") {
            return isNight ? "partly-cloudy-night" : "partly-cloudy"
        } else if lowercased.contains("cloud") || lowercased.contains("overcast") {
            return "cloudy"
        } else if lowercased.contains("fog") || lowercased.contains("mist") {
            return "foggy"
        } else if lowercased.contains("rain") || lowercased.contains("shower") || lowercased.contains("drizzle") || 
                  lowercased.contains("snow") || lowercased.contains("sleet") || lowercased.contains("ice") {
            return "rainy"
        } else if lowercased.contains("thunder") || lowercased.contains("lightning") || lowercased.contains("storm") {
            return "thunderstorm"
        }
        
        // Default fallback
        return isNight ? "clear-night" : "clear-day"
    }
    
    private func fallbackSymbolName() -> String {
        if let condition = weather?.condition {
            let lowercased = condition.lowercased()
            
            if lowercased.contains("clear") || lowercased.contains("sunny") {
                return determineIfNight() ? "moon.stars.fill" : "sun.max.fill"
            } else if lowercased.contains("partly cloudy") {
                return determineIfNight() ? "cloud.moon.fill" : "cloud.sun.fill"
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
        }
        
        return "sun.max.fill" // Default fallback
    }
}
