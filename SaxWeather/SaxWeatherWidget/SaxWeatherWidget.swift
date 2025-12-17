//
//  SaxWeatherWidget.swift
//  SaxWeatherWidget
//
//  Created by Saxon on 18/5/2025.
//

import WidgetKit
import SwiftUI
import Foundation

// MARK: - Widget Weather Data Model
fileprivate struct WidgetWeatherData: Codable {
    let temperature: Double
    let condition: String
    let humidity: Double
    let windSpeed: Double
    let high: Double
    let low: Double
    let lastUpdate: Double
}

struct WeatherWidgetEntry: TimelineEntry {
    let date: Date
    let temperature: Double?
    let condition: String?
    let high: Double?
    let low: Double?
    let humidity: Double?
    let feelsLike: Double?
    let windSpeed: Double?
    let uvIndex: Int?
    let pressure: Double?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherWidgetEntry {
        WeatherWidgetEntry(
            date: Date(),
            temperature: 21.0,
            condition: "Sunny",
            high: 24.0,
            low: 18.0,
            humidity: 60.0,
            feelsLike: 22.0,
            windSpeed: 15.0,
            uvIndex: 5,
            pressure: 1013.0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherWidgetEntry) -> ()) {
        let entry = loadWeatherEntry() ?? WeatherWidgetEntry(
            date: Date(),
            temperature: 21.0,
            condition: "Sunny",
            high: 24.0,
            low: 18.0,
            humidity: 60.0,
            feelsLike: 22.0,
            windSpeed: 15.0,
            uvIndex: 5,
            pressure: 1013.0
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherWidgetEntry>) -> ()) {
        let entry = loadWeatherEntry() ?? WeatherWidgetEntry(
            date: Date(),
            temperature: nil,
            condition: nil,
            high: nil,
            low: nil,
            humidity: nil,
            feelsLike: nil,
            windSpeed: nil,
            uvIndex: nil,
            pressure: nil
        )
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadWeatherEntry() -> WeatherWidgetEntry? {
        let sharedDefaults = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
        
        guard let data = sharedDefaults?.data(forKey: "latestWeather") else {
            return nil
        }
        
        // Try to decode from JSON dictionary format
        if let weatherDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            let temperature = weatherDict["temperature"] as? Double
            let condition = weatherDict["condition"] as? String
            let high = weatherDict["high"] as? Double
            let low = weatherDict["low"] as? Double
            let humidity = weatherDict["humidity"] as? Double
            let feelsLike = weatherDict["feelsLike"] as? Double
            let windSpeed = weatherDict["windSpeed"] as? Double
            let uvIndex = weatherDict["uvIndex"] as? Int
            let pressure = weatherDict["pressure"] as? Double
            
            return WeatherWidgetEntry(
                date: Date(),
                temperature: temperature,
                condition: condition,
                high: high,
                low: low,
                humidity: humidity,
                feelsLike: feelsLike,
                windSpeed: windSpeed,
                uvIndex: uvIndex,
                pressure: pressure
            )
        }
        
        return nil
    }
}

struct SaxWeatherWidgetEntryView : View {
    var entry: WeatherWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            smallWidgetView
        case .systemMedium:
            mediumWidgetView
        case .systemLarge:
            largeWidgetView
        default:
            smallWidgetView
        }
    }
    
    private var smallWidgetView: some View {
        VStack(spacing: 8) {
            if let temp = entry.temperature {
                Spacer()
                
                // Weather icon with SF Symbols - larger for impact
                Image(systemName: weatherIconName(for: entry.condition))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        weatherIconColor(for: entry.condition),
                        weatherIconColor(for: entry.condition).opacity(0.5)
                    )
                    .font(.system(size: 50, weight: .medium))
                    .shadow(color: weatherIconColor(for: entry.condition).opacity(0.3), radius: 4, x: 0, y: 2)
                    .padding(.top, 4)
                
                // Large, bold temperature - main focus
                Text("\(String(format: "%.1f", temp))°")
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                
                // Small high/low display - compact
                if let high = entry.high, let low = entry.low {
                    HStack(spacing: 6) {
                        Text("H:\(String(format: "%.1f", high))°")
                            .foregroundColor(.red.opacity(0.8))
                        Text("L:\(String(format: "%.1f", low))°")
                            .foregroundColor(.blue.opacity(0.8))
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
                
                Spacer()
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "cloud.sun.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No Data")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
    
    private var mediumWidgetView: some View {
        VStack(spacing: 12) {
            if let temp = entry.temperature {
                // Top row - Icon, temp, and condition
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: weatherIconName(for: entry.condition))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            weatherIconColor(for: entry.condition),
                            weatherIconColor(for: entry.condition).opacity(0.5)
                        )
                        .font(.system(size: 56, weight: .medium))
                        .shadow(color: weatherIconColor(for: entry.condition).opacity(0.3), radius: 4, x: 0, y: 2)
                        .frame(width: 65)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(String(format: "%.1f", temp))°")
                            .font(.system(size: 52, weight: .heavy))
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.8)
                        
                        if let condition = entry.condition {
                            Text(condition)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                }
                
                // Bottom row - High/Low and Feels Like in compact cards
                HStack(spacing: 8) {
                    // High/Low card
                    if let high = entry.high, let low = entry.low {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red.opacity(0.8))
                                Text("H:\(String(format: "%.1f", high))°")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue.opacity(0.8))
                                Text("L:\(String(format: "%.1f", low))°")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Feels Like
                    if let feelsLike = entry.feelsLike {
                        HStack(spacing: 4) {
                            Image(systemName: "thermometer.medium")
                                .font(.system(size: 12))
                                .foregroundColor(.orange.opacity(0.8))
                            Text("Feels \(String(format: "%.1f", feelsLike))°")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "cloud.sun.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 50))
                    Text("No Data Available")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
    
    private var largeWidgetView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let temp = entry.temperature {
                // Top section - Main weather info
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: weatherIconName(for: entry.condition))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            weatherIconColor(for: entry.condition),
                            weatherIconColor(for: entry.condition).opacity(0.5)
                        )
                        .font(.system(size: 64, weight: .medium))
                        .shadow(color: weatherIconColor(for: entry.condition).opacity(0.3), radius: 6, x: 0, y: 3)
                        .frame(width: 70)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Match main app temperature style
                        Text("\(String(format: "%.1f", temp))°")
                            .font(.system(size: 62, weight: .heavy))
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.7)
                        
                        if let condition = entry.condition {
                            Text(condition)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Feels like right below condition
                        if let feelsLike = entry.feelsLike {
                            Text("Feels like \(String(format: "%.1f", feelsLike))°")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                Divider()
                    .padding(.vertical, 2)
                
                // Details section with cards - 3x2 grid layout
                VStack(spacing: 8) {
                    // First row - High/Low
                    if let high = entry.high, let low = entry.low {
                        HStack(spacing: 8) {
                            // High temp card
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.red.opacity(0.8))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("High")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.1f", high))°")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(8)
                            
                            // Low temp card
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue.opacity(0.8))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Low")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.1f", low))°")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Second row - Humidity and Wind Speed
                    HStack(spacing: 8) {
                        if let humidity = entry.humidity {
                            HStack {
                                Image(systemName: "humidity.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.cyan.opacity(0.8))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Humidity")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.0f", humidity))%")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.cyan.opacity(0.08))
                            .cornerRadius(8)
                        }
                        
                        if let windSpeed = entry.windSpeed {
                            HStack {
                                Image(systemName: "wind")
                                    .font(.system(size: 18))
                                    .foregroundColor(.green.opacity(0.8))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Wind")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.1f", windSpeed)) km/h")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                        .minimumScaleFactor(0.8)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Third row - UV Index and Pressure
                    HStack(spacing: 8) {
                        if let uvIndex = entry.uvIndex {
                            HStack {
                                Image(systemName: "sun.max.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.orange.opacity(0.8))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("UV Index")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("\(uvIndex)")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.08))
                            .cornerRadius(8)
                        }
                        
                        if let pressure = entry.pressure {
                            HStack {
                                Image(systemName: "gauge.with.dots.needle.50percent")
                                    .font(.system(size: 18))
                                    .foregroundColor(.purple.opacity(0.8))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Pressure")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.0f", pressure)) hPa")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                        .minimumScaleFactor(0.8)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "cloud.sun.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 64))
                    Text("No Weather Data")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("Open the app to refresh")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
    }
    
    private func weatherSymbol(for condition: String?) -> String {
        guard let condition = condition?.lowercased() else { return "☀️" }
        
        if condition.contains("clear") || condition.contains("sunny") {
            return "☀️"
        } else if condition.contains("partly cloudy") {
            return "⛅"
        } else if condition.contains("cloud") || condition.contains("overcast") {
            return "☁️"
        } else if condition.contains("rain") || condition.contains("shower") {
            return "🌧️"
        } else if condition.contains("snow") {
            return "❄️"
        } else if condition.contains("thunder") || condition.contains("storm") {
            return "⛈️"
        } else if condition.contains("fog") || condition.contains("mist") {
            return "🌫️"
        }
        
        return "☀️"
    }
    
    @ViewBuilder
    private func weatherIcon(for condition: String?) -> some View {
        let iconName = weatherIconName(for: condition)
        
        ZStack {
            // Background glow effect
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            weatherIconColor(for: condition).opacity(0.3),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 5,
                        endRadius: 50
                    )
                )
                .frame(width: 80, height: 80)
            
            // Main icon
            Image(systemName: iconName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 50, weight: .light))
                .foregroundStyle(weatherIconColor(for: condition))
        }
    }
    
    private func weatherIconName(for condition: String?) -> String {
        guard let condition = condition?.lowercased() else { return "sun.max.fill" }
        
        let isNight = isNighttime()
        
        if condition.contains("clear") || condition.contains("sunny") {
            return isNight ? "moon.stars.fill" : "sun.max.fill"
        } else if condition.contains("partly cloudy") {
            return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        } else if condition.contains("cloud") || condition.contains("overcast") {
            return "cloud.fill"
        } else if condition.contains("rain") || condition.contains("shower") {
            return "cloud.rain.fill"
        } else if condition.contains("snow") {
            return "cloud.snow.fill"
        } else if condition.contains("thunder") || condition.contains("storm") {
            return "cloud.bolt.rain.fill"
        } else if condition.contains("fog") || condition.contains("mist") {
            return "cloud.fog.fill"
        }
        
        return isNight ? "moon.stars.fill" : "sun.max.fill"
    }
    
    private func weatherIconColor(for condition: String?) -> Color {
        guard let condition = condition?.lowercased() else { return .yellow }
        
        if condition.contains("clear") || condition.contains("sunny") {
            return .yellow
        } else if condition.contains("partly cloudy") {
            return .orange
        } else if condition.contains("cloud") || condition.contains("overcast") {
            return .gray
        } else if condition.contains("rain") || condition.contains("shower") {
            return .blue
        } else if condition.contains("snow") {
            return .cyan
        } else if condition.contains("thunder") || condition.contains("storm") {
            return .purple
        } else if condition.contains("fog") || condition.contains("mist") {
            return .gray.opacity(0.6)
        }
        
        return .yellow
    }
    
    private func isNighttime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour > 18
    }
}

@main
struct SaxWeatherWidget: Widget {
    let kind: String = "SaxWeatherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SaxWeatherWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("SaxWeather")
        .description("Shows the latest weather from SaxWeather app.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    SaxWeatherWidget()
} timeline: {
    WeatherWidgetEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8, humidity: 62.0, feelsLike: 29.5, windSpeed: 15.0, uvIndex: 8, pressure: 1015.0)
    WeatherWidgetEntry(date: .now, temperature: 18.4, condition: "Cloudy", high: 20.3, low: 15.7, humidity: 78.0, feelsLike: 17.2, windSpeed: 22.0, uvIndex: 3, pressure: 1008.0)
    WeatherWidgetEntry(date: .now, temperature: 12.6, condition: "Rainy", high: 14.2, low: 9.8, humidity: 85.0, feelsLike: 10.8, windSpeed: 28.5, uvIndex: 2, pressure: 1002.0)
}

#Preview(as: .systemMedium) {
    SaxWeatherWidget()
} timeline: {
    WeatherWidgetEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8, humidity: 62.0, feelsLike: 29.5, windSpeed: 15.0, uvIndex: 8, pressure: 1015.0)
    WeatherWidgetEntry(date: .now, temperature: 18.4, condition: "Partly Cloudy", high: 20.3, low: 15.7, humidity: 78.0, feelsLike: 17.2, windSpeed: 22.0, uvIndex: 3, pressure: 1008.0)
}

#Preview(as: .systemLarge) {
    SaxWeatherWidget()
} timeline: {
    WeatherWidgetEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8, humidity: 62.0, feelsLike: 29.5, windSpeed: 15.0, uvIndex: 8, pressure: 1015.0)
    WeatherWidgetEntry(date: .now, temperature: 5.2, condition: "Snowy", high: 7.1, low: 2.3, humidity: 92.0, feelsLike: 2.8, windSpeed: 35.5, uvIndex: 1, pressure: 998.0)
}
