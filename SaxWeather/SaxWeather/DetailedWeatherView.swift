//  DetailedWeatherView.swift
//  SaxWeather
//
//  Created by GitHub Copilot on 2025-05-18
//

import SwiftUI
import CoreLocation

// NOTE: All types referenced below (WeatherService, SavedLocationsManager, WeatherForecast, HourlyData, WeatherDetailsView, LottieView) are defined in local files in the same target/module, so no import is needed for them.

struct DetailedWeatherView: View {
    @ObservedObject var weatherService: WeatherService
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    @StateObject private var locationsManager = SavedLocationsManager()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header: Location & Date
                HStack {
                    VStack(alignment: .leading) {
                        Text(locationDisplayName)
                            .font(.title.bold())
                        Text(Date(), style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                // Main Temperature & Condition
                HStack(alignment: .center, spacing: 24) {
                    if let condition = weatherService.weather?.condition {
                        LottieView(name: getAnimationName(for: condition))
                            .frame(width: 100, height: 100)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(weatherService.weather?.condition ?? "-")
                            .font(.title2)
                        if let temp = weatherService.weather?.temperature {
                            Text(String(format: "%.1f%@", temp, unitSymbol))
                                .font(.system(size: 48, weight: .bold))
                        }
                        if let feels = weatherService.weather?.feelsLike {
                            Text("Feels like " + String(format: "%.1f%@", feels, unitSymbol))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                // High/Low, Humidity, Wind, etc. (Summary Panes)
                HStack(spacing: 16) {
                    if let high = weatherService.weather?.high {
                        WeatherPane(title: "High", value: String(format: "%.1f%@", high, unitSymbol), systemImage: "arrow.up")
                    }
                    if let low = weatherService.weather?.low {
                        WeatherPane(title: "Low", value: String(format: "%.1f%@", low, unitSymbol), systemImage: "arrow.down")
                    }
                    if let humidity = weatherService.weather?.humidity {
                        WeatherPane(title: "Humidity", value: String(format: "%d%%", Int(humidity)), systemImage: "humidity")
                    }
                    if let wind = weatherService.weather?.windSpeed {
                        WeatherPane(title: "Wind", value: String(format: "%.1f %@", wind, windUnit), systemImage: "wind")
                    }
                }
                .padding(.horizontal)
                
                // Hourly Graph (if available)
                // NOTE: There is no hourlyData on DailyForecast. Use a shared hourlyData array if available.
                if !weatherService.hourlyData.isEmpty {
                    WeatherGraphView(hourly: weatherService.hourlyData, unitSystem: unitSystem)
                        .frame(height: 180)
                        .padding(.horizontal)
                }
                
                // Forecast Panes
                if let forecast = weatherService.forecast?.daily {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Next Days")
                            .font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(forecast.prefix(7)) { day in
                                    ForecastPane(day: day, unitSystem: unitSystem)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Additional Details
                if let details = weatherService.weather {
                    WeatherDetailsView(weather: details)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var unitSymbol: String {
        unitSystem == "Metric" ? "°C" : "°F"
    }
    private var windUnit: String {
        unitSystem == "Metric" ? "km/h" : "mph"
    }
    // Display location name or coordinates
    private var locationDisplayName: String {
        if let selected = locationsManager.selectedLocation {
            if selected.isCurrentLocation {
                return "Current Location"
            } else {
                return selected.name
            }
        }
        // Fallback to coordinates
        if let lat = Double(UserDefaults.standard.string(forKey: "latitude") ?? ""),
           let lon = Double(UserDefaults.standard.string(forKey: "longitude") ?? "") {
            return String(format: "%.3f, %.3f", lat, lon)
        }
        return "Location"
    }
}

// MARK: - WeatherPane
struct WeatherPane: View {
    let title: String
    let value: String
    let systemImage: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 70, height: 70)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .shadow(radius: 2)
    }
}

// MARK: - ForecastPane
struct ForecastPane: View {
    let day: WeatherForecast.DailyForecast
    let unitSystem: String
    var body: some View {
        VStack(spacing: 6) {
            Text(day.date, style: .date)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(day.weatherSymbol)
                .font(.title2)
            Text(String(format: "%.0f%@", day.tempMax, unitSystem == "Metric" ? "°C" : "°F"))
                .font(.headline)
            Text(String(format: "%.0f%@", day.tempMin, unitSystem == "Metric" ? "°C" : "°F"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 60, height: 90)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - WeatherGraphView (stub)
struct WeatherGraphView: View {
    let hourly: [HourlyData]
    let unitSystem: String
    var body: some View {
        // Placeholder for a temperature line graph
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                Text("[Hourly Temperature Graph]")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Helpers
private func getSymbol(for condition: String) -> String {
    switch condition.lowercased() {
    case let c where c.contains("cloud"): return "cloud.fill"
    case let c where c.contains("rain"): return "cloud.rain.fill"
    case let c where c.contains("snow"): return "cloud.snow.fill"
    case let c where c.contains("sun"): return "sun.max.fill"
    case let c where c.contains("clear"): return "sun.max"
    case let c where c.contains("thunder"): return "cloud.bolt.rain.fill"
    default: return "cloud"
    }
}

private func getAnimationName(for condition: String) -> String {
    switch condition.lowercased() {
    case let c where c.contains("cloud"): return "cloudy"
    case let c where c.contains("rain"): return "rainy"
    case let c where c.contains("snow"): return "snowy"
    case let c where c.contains("sun"): return "sunny"
    case let c where c.contains("clear"): return "clear-day"
    case let c where c.contains("thunder"): return "thunder"
    default: return "default"
    }
}

// MARK: - Preview
#Preview {
    DetailedWeatherView(weatherService: WeatherService())
}
