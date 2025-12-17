//  DetailedWeatherView.swift
//  SaxWeather
//
//  Created by GitHub Copilot on 2025-05-18
//

import Foundation
import SwiftUI
import CoreLocation

struct DetailedWeatherView: View {
    @ObservedObject var weatherService: WeatherService
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    @StateObject private var locationsManager = SavedLocationsManager()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // HERO SECTION
                VStack(spacing: 8) {
                    HStack(alignment: .center, spacing: 20) {
                        if let condition = weatherService.weather?.condition {
                            LottieView(name: getAnimationName(for: condition))
                                .frame(width: 120, height: 120)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(locationDisplayName)
                                .font(.title.bold())
                            Text(Date(), style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(weatherService.weather?.condition ?? "-")
                                .font(.title2)
                            if let temp = weatherService.weather?.temperature {
                                Text(String(format: "%.1f%@", temp, unitSymbol))
                                    .font(.system(size: 54, weight: .bold))
                            }
                            if let feels = weatherService.weather?.feelsLike {
                                Text("Feels like " + String(format: "%.1f%@", feels, unitSymbol))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .cornerRadius(28)
                .shadow(radius: 8)
                .padding(.horizontal)

                // GRID OF CARDS (2 columns)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    WeatherCard(title: "Feels Like", value: weatherService.weather?.feelsLike.map { String(format: "%.0f%@", $0, unitSymbol) } ?? "-", icon: "thermometer")
                    WeatherCard(title: "UV Index", value: weatherService.weather?.uvIndex.map { String($0) } ?? "-", icon: "sun.max")
                    WeatherCard(title: "Humidity", value: weatherService.weather?.humidity.map { String(format: "%d%%", Int($0)) } ?? "-", icon: "humidity")
                }
                .padding(.horizontal)

                // WIND CARD (full width)
                if let wind = weatherService.weather?.windSpeed, let gust = weatherService.weather?.windGust {
                    // Try to get wind direction from forecast if available
                    let direction = weatherService.forecast?.daily.first?.windDirection ?? 0
                    WindCard(wind: wind, gust: gust, direction: direction, unit: windUnit)
                        .padding(.horizontal)
                }

                // SUNRISE/SUNSET & PRECIPITATION CARDS (side by side)
                HStack(spacing: 16) {
                    // Use first daily forecast for sunrise/sunset and precipitation if available
                    if let day = weatherService.forecast?.daily.first {
                        if let sunrise = day.sunrise, let sunset = day.sunset {
                            SunriseCard(sunrise: sunrise, sunset: sunset)
                        }
                        PrecipitationCard(amount: day.precipitation)
                    }
                }
                .padding(.horizontal)

                // HOURLY FORECAST GRAPH
                if !weatherService.hourlyData.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hourly Forecast")
                            .font(.headline)
                            .padding(.leading, 8)
                        WeatherGraphView(hourly: weatherService.hourlyData, unitSystem: unitSystem)
                            .frame(height: 180)
                            .background(.ultraThinMaterial)
                            .cornerRadius(18)
                            .padding(.horizontal, 4)
                    }
                    .padding(.horizontal)
                }

                // DAILY FORECAST
                if let forecast = weatherService.forecast?.daily {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Next Days")
                            .font(.headline)
                            .padding(.leading, 8)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(forecast.prefix(7)) { day in
                                    ForecastPane(day: day, unitSystem: unitSystem)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 16)
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

// MARK: - WeatherCard
struct WeatherCard: View {
    let title: String
    let value: String
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text(title.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .shadow(radius: 2)
    }
}

// MARK: - WindCard
struct WindCard: View {
    let wind: Double
    let gust: Double
    let direction: Double
    let unit: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "wind")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("WIND")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wind")
                        .font(.subheadline)
                    Text(String(format: "%.0f %@", wind, unit))
                        .font(.title2.bold())
                    Text("Gusts")
                        .font(.subheadline)
                    Text(String(format: "%.0f %@", gust, unit))
                        .font(.body)
                    Text("Direction")
                        .font(.subheadline)
                    Text(String(format: "%.0f°", direction))
                        .font(.body)
                }
                Spacer()
                // Compass
                ZStack {
                    Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                    ForEach([0, 90, 180, 270], id: \ .self) { deg in
                        Text(["N", "E", "S", "W"][deg/90])
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .offset(y: -40)
                            .rotationEffect(.degrees(Double(deg)))
                    }
                    Arrow()
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(direction))
                }
                .frame(width: 80, height: 80)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .shadow(radius: 2)
    }
}

struct Arrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + 10))
        path.addLine(to: CGPoint(x: rect.midX - 6, y: rect.minY + 22))
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + 10))
        path.addLine(to: CGPoint(x: rect.midX + 6, y: rect.minY + 22))
        return path
    }
}

// MARK: - SunriseCard
struct SunriseCard: View {
    let sunrise: Date
    let sunset: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sunrise")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("SUNRISE")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(timeString(sunrise))
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Sunset: " + timeString(sunset))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .shadow(radius: 2)
    }
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - PrecipitationCard
struct PrecipitationCard: View {
    let amount: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "drop.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("PRECIPITATION")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(String(format: "%.0f mm", amount))
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Today")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .shadow(radius: 2)
    }
}

// MARK: - WeatherGraphView (stub)
struct WeatherGraphView: View {
    let hourly: [HourlyWeatherData]
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
