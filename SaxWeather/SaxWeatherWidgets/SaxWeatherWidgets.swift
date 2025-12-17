//
//  SaxWeatherWidgets.swift
//  SaxWeatherWidgets
//
//  Created by Saxon on 24/4/2025.
//

import WidgetKit
import SwiftUI

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

struct WeatherEntry: TimelineEntry {
    let date: Date
    let temperature: Double?
    let condition: String?
    let high: Double?
    let low: Double?
}

struct WeatherProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(
            date: Date(),
            temperature: 21.0,
            condition: "Sunny",
            high: 24.0,
            low: 18.0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> ()) {
        let entry = loadWeatherEntry() ?? WeatherEntry(
            date: Date(),
            temperature: 21.0,
            condition: "Sunny",
            high: 24.0,
            low: 18.0
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> ()) {
        let entry = loadWeatherEntry() ?? WeatherEntry(
            date: Date(),
            temperature: nil,
            condition: nil,
            high: nil,
            low: nil
        )
        
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadWeatherEntry() -> WeatherEntry? {
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
            
            return WeatherEntry(
                date: Date(),
                temperature: temperature,
                condition: condition,
                high: high,
                low: low
            )
        }
        
        return nil
    }
}

struct SaxWeatherWidgetsEntryView : View {
    var entry: WeatherEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        if widgetFamily == .accessoryCircular || widgetFamily == .accessoryRectangular || widgetFamily == .accessoryInline {
            accessoryWidgetView
        } else {
            VStack(spacing: 8) {
                if let temp = entry.temperature {
                    Spacer()
                    
                    // Larger icon for better visibility
                    Image(systemName: weatherIconName(for: entry.condition))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            weatherIconColor(for: entry.condition),
                            weatherIconColor(for: entry.condition).opacity(0.5)
                        )
                        .font(.system(size: 46, weight: .medium))
                        .shadow(color: weatherIconColor(for: entry.condition).opacity(0.3), radius: 3, x: 0, y: 2)
                        .padding(.top, 4)
                    
                    // Larger temperature for better readability
                    Text("\(String(format: "%.1f", temp))°")
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    
                    // Compact high/low display
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
                            .font(.system(size: 46))
                        Text("No Data")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }
    
    @ViewBuilder
    private var accessoryWidgetView: some View {
        switch widgetFamily {
        case .accessoryCircular:
            VStack(spacing: 0) {
                if let temp = entry.temperature {
                    Text(weatherSymbol(for: entry.condition))
                        .font(.system(size: 14))
                    // Match main app temperature style
                    Text("\(String(format: "%.0f", temp))°")
                        .font(.system(size: 20, weight: .heavy))
                        .minimumScaleFactor(0.7)
                    // Add compact high/low display
                    if let high = entry.high, let low = entry.low {
                        HStack(spacing: 2) {
                            Text("\(String(format: "%.0f", high))°")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("/")
                                .font(.system(size: 8, weight: .regular))
                                .foregroundStyle(.tertiary)
                            Text("\(String(format: "%.0f", low))°")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    }
                } else {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 20))
                }
            }
            
        case .accessoryRectangular:
            HStack(spacing: 8) {
                if let temp = entry.temperature {
                    Text(weatherSymbol(for: entry.condition))
                        .font(.system(size: 28))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        // Match main app temperature style - current temp
                        Text("\(String(format: "%.0f", temp))°")
                            .font(.system(size: 24, weight: .heavy))
                        
                        // Show high/low on second line
                        if let high = entry.high, let low = entry.low {
                            HStack(spacing: 4) {
                                HStack(spacing: 1) {
                                    Text("↑")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.red.opacity(0.9))
                                    Text("\(String(format: "%.0f", high))°")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                HStack(spacing: 1) {
                                    Text("↓")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.blue.opacity(0.9))
                                    Text("\(String(format: "%.0f", low))°")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                            }
                        } else if let condition = entry.condition {
                            Text(condition)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                } else {
                    Text("No Data")
                        .font(.caption2)
                }
            }
            
        case .accessoryInline:
            if let temp = entry.temperature {
                HStack(spacing: 4) {
                    Text(weatherSymbol(for: entry.condition))
                    Text("\(String(format: "%.0f", temp))°")
                    if let high = entry.high, let low = entry.low {
                        Text("H:\(String(format: "%.0f", high))° L:\(String(format: "%.0f", low))°")
                    } else if let condition = entry.condition {
                        Text(condition)
                    }
                }
            } else {
                Text("No Weather Data")
            }
            
        default:
            EmptyView()
        }
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
struct SaxWeatherWidgets: Widget {
    let kind: String = "SaxWeatherWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherProvider()) { entry in
            SaxWeatherWidgetsEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("SaxWeather Compact")
        .description("Compact weather widget for lock screen and home screen.")
        .supportedFamilies([
            .systemSmall,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

#Preview(as: .systemSmall) {
    SaxWeatherWidgets()
} timeline: {
    WeatherEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8)
    WeatherEntry(date: .now, temperature: 18.4, condition: "Cloudy", high: 20.3, low: 15.7)
}

#Preview(as: .accessoryCircular) {
    SaxWeatherWidgets()
} timeline: {
    WeatherEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8)
    WeatherEntry(date: .now, temperature: -3.7, condition: "Snowy", high: -1.2, low: -6.5)
}

#Preview(as: .accessoryRectangular) {
    SaxWeatherWidgets()
} timeline: {
    WeatherEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8)
    WeatherEntry(date: .now, temperature: 15.6, condition: "Rainy", high: 17.8, low: 12.4)
}

#Preview(as: .accessoryInline) {
    SaxWeatherWidgets()
} timeline: {
    WeatherEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8)
    WeatherEntry(date: .now, temperature: 15.6, condition: "Rainy", high: 17.8, low: 12.4)
}    
