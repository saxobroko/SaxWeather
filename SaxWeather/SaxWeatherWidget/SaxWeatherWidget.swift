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
        #if DEBUG
        print("📱 Widget: getTimeline called at \(Date())")
        #endif
        
        // Fetch fresh weather data asynchronously
        Task {
            let entry = await fetchFreshWeatherEntry() ?? loadWeatherEntry() ?? WeatherWidgetEntry(
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
            
            #if DEBUG
            print("✅ Widget: Timeline entry created with temp: \(entry.temperature?.description ?? "nil")")
            #endif
            
            // Schedule next update in 5 minutes (reduced from 15 minutes)
            // This allows the widget to refresh more frequently without needing the app open
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(300)
            
            #if DEBUG
            print("📱 Widget: Next update scheduled for \(nextUpdate)")
            #endif
            
            // Use .after policy with 5-minute intervals for frequent updates
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    private func fetchFreshWeatherEntry() async -> WeatherWidgetEntry? {
        let sharedDefaults = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
        
        // Get location from shared UserDefaults
        let useGPS = sharedDefaults?.bool(forKey: "useGPS") ?? false
        var latitude: Double = 0
        var longitude: Double = 0
        
        #if DEBUG
        print("📱 Widget: Fetching fresh weather data...")
        print("📱 Widget: Use GPS = \(useGPS)")
        #endif
        
        if useGPS {
            // Use last known GPS location
            if let lat = sharedDefaults?.string(forKey: "lastKnownLatitude"),
               let lon = sharedDefaults?.string(forKey: "lastKnownLongitude"),
               let latDouble = Double(lat),
               let lonDouble = Double(lon) {
                latitude = latDouble
                longitude = lonDouble
                #if DEBUG
                print("📱 Widget: Using GPS location: \(latitude), \(longitude)")
                #endif
            } else {
                // Fallback to manual coordinates
                if let lat = sharedDefaults?.string(forKey: "latitude"),
                   let lon = sharedDefaults?.string(forKey: "longitude"),
                   let latDouble = Double(lat),
                   let lonDouble = Double(lon) {
                    latitude = latDouble
                    longitude = lonDouble
                    #if DEBUG
                    print("📱 Widget: Using manual fallback: \(latitude), \(longitude)")
                    #endif
                }
            }
        } else {
            // Use manual coordinates
            if let lat = sharedDefaults?.string(forKey: "latitude"),
               let lon = sharedDefaults?.string(forKey: "longitude"),
               let latDouble = Double(lat),
               let lonDouble = Double(lon) {
                latitude = latDouble
                longitude = lonDouble
                #if DEBUG
                print("📱 Widget: Using manual location: \(latitude), \(longitude)")
                #endif
            }
        }
        
        // Validate coordinates
        guard latitude != 0, longitude != 0 else {
            #if DEBUG
            print("❌ Widget: Invalid coordinates")
            #endif
            return nil
        }
        
        let unitSystem = sharedDefaults?.string(forKey: "unitSystem") ?? "Metric"
        
        do {
            let weatherData = try await fetchOpenMeteoWeather(
                latitude: latitude,
                longitude: longitude,
                unitSystem: unitSystem
            )
            #if DEBUG
            print("✅ Widget: Successfully fetched weather data")
            #endif
            return weatherData
        } catch {
            #if DEBUG
            print("❌ Widget: Error fetching weather: \(error)")
            #endif
            return nil
        }
    }
    
    private func fetchOpenMeteoWeather(
        latitude: Double,
        longitude: Double,
        unitSystem: String
    ) async throws -> WeatherWidgetEntry {
        let urlString = "https://api.open-meteo.com/v1/forecast?" +
            "latitude=\(latitude)" +
            "&longitude=\(longitude)" +
            "&current=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,pressure_msl,uv_index,weather_code" +
            "&daily=temperature_2m_max,temperature_2m_min,weather_code" +
            "&timezone=auto" +
            "&forecast_days=1"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        let response = try decoder.decode(OpenMeteoWidgetResponse.self, from: data)
        
        guard let current = response.current else {
            throw URLError(.cannotParseResponse)
        }
        
        let daily = response.daily
        
        // Convert temperature based on unit system
        var temp = current.temperature2m
        var feelsLike = current.apparentTemperature
        var high = daily.temperature2mMax.first ?? temp
        var low = daily.temperature2mMin.first ?? temp
        var windSpeed = current.windSpeed10m
        var pressure = current.pressureMsl
        
        if unitSystem == "Imperial" {
            temp = temp * 9/5 + 32
            feelsLike = feelsLike * 9/5 + 32
            high = high * 9/5 + 32
            low = low * 9/5 + 32
            windSpeed = windSpeed * 0.621371
            pressure = pressure * 0.02953
        } else if unitSystem == "UK" {
            windSpeed = windSpeed * 0.621371
        }
        
        let condition = mapWeatherCodeToCondition(current.weatherCode)
        
        return WeatherWidgetEntry(
            date: Date(),
            temperature: temp,
            condition: condition,
            high: high,
            low: low,
            humidity: current.relativeHumidity2m,
            feelsLike: feelsLike,
            windSpeed: windSpeed,
            uvIndex: Int(current.uvIndex),
            pressure: pressure
        )
    }
    
    private func mapWeatherCodeToCondition(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mainly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing Drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing Rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow Grains"
        case 80, 81, 82: return "Rain Showers"
        case 85, 86: return "Snow Showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with Hail"
        default: return "Unknown"
        }
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
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        case .accessoryInline:
            accessoryInlineView
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
    
    // MARK: - Lock Screen Widgets (Accessory)
    
    private var accessoryCircularView: some View {
        VStack(spacing: 0) {
            if let temp = entry.temperature {
                Text(weatherSymbol(for: entry.condition))
                    .font(.system(size: 14))
                Text("\(String(format: "%.0f", temp))°")
                    .font(.system(size: 20, weight: .heavy))
                    .minimumScaleFactor(0.7)
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
    }
    
    private var accessoryRectangularView: some View {
        HStack(spacing: 8) {
            if let temp = entry.temperature {
                Text(weatherSymbol(for: entry.condition))
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(String(format: "%.0f", temp))°")
                        .font(.system(size: 24, weight: .heavy))
                    
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
    }
    
    private var accessoryInlineView: some View {
        Group {
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

// MARK: - Daily Forecast Widget

struct ForecastEntry: TimelineEntry {
    let date: Date
    let highTemp: Double?
    let lowTemp: Double?
    let condition: String?
}

struct ForecastProvider: TimelineProvider {
    func placeholder(in context: Context) -> ForecastEntry {
        ForecastEntry(date: Date(), highTemp: 24.0, lowTemp: 18.0, condition: "Partly Cloudy")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ForecastEntry) -> ()) {
        let entry = ForecastEntry(date: Date(), highTemp: 24.0, lowTemp: 18.0, condition: "Partly Cloudy")
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ForecastEntry>) -> ()) {
        #if DEBUG
        print("📱 Forecast Widget: getTimeline called at \(Date())")
        #endif
        
        Task {
            let entry = await fetchFreshForecastEntry() ?? ForecastEntry(
                date: Date(),
                highTemp: nil,
                lowTemp: nil,
                condition: nil
            )
            
            #if DEBUG
            print("✅ Forecast Widget: Timeline entry created with high: \(entry.highTemp?.description ?? "nil")")
            #endif
            
            // Use .atEnd policy for aggressive updates
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
    
    private func fetchFreshForecastEntry() async -> ForecastEntry? {
        let sharedDefaults = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
        
        let useGPS = sharedDefaults?.bool(forKey: "useGPS") ?? false
        var latitude: Double = 0
        var longitude: Double = 0
        
        #if DEBUG
        print("📱 Forecast Widget: Fetching fresh forecast data...")
        #endif
        
        if useGPS {
            if let lat = sharedDefaults?.string(forKey: "lastKnownLatitude"),
               let lon = sharedDefaults?.string(forKey: "lastKnownLongitude"),
               let latDouble = Double(lat),
               let lonDouble = Double(lon) {
                latitude = latDouble
                longitude = lonDouble
            } else {
                if let lat = sharedDefaults?.string(forKey: "latitude"),
                   let lon = sharedDefaults?.string(forKey: "longitude"),
                   let latDouble = Double(lat),
                   let lonDouble = Double(lon) {
                    latitude = latDouble
                    longitude = lonDouble
                }
            }
        } else {
            if let lat = sharedDefaults?.string(forKey: "latitude"),
               let lon = sharedDefaults?.string(forKey: "longitude"),
               let latDouble = Double(lat),
               let lonDouble = Double(lon) {
                latitude = latDouble
                longitude = lonDouble
            }
        }
        
        guard latitude != 0, longitude != 0 else {
            #if DEBUG
            print("❌ Forecast Widget: Invalid coordinates")
            #endif
            return nil
        }
        
        let unitSystem = sharedDefaults?.string(forKey: "unitSystem") ?? "Metric"
        let tempUnit = unitSystem == "Imperial" ? "fahrenheit" : "celsius"
        
        let urlString = "https://api.open-meteo.com/v1/forecast?" +
            "latitude=\(latitude)" +
            "&longitude=\(longitude)" +
            "&daily=temperature_2m_max,temperature_2m_min,weather_code" +
            "&temperature_unit=\(tempUnit)" +
            "&timezone=auto"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoWidgetResponse.self, from: data)
            
            let high = response.daily.temperature2mMax.first
            let low = response.daily.temperature2mMin.first
            let weatherCode = response.daily.weatherCode.first ?? 0
            let condition = weatherCodeToCondition(weatherCode)
            
            #if DEBUG
            print("✅ Forecast Widget: Successfully fetched forecast data")
            #endif
            
            return ForecastEntry(
                date: Date(),
                highTemp: high,
                lowTemp: low,
                condition: condition
            )
        } catch {
            #if DEBUG
            print("❌ Forecast Widget: Error fetching forecast: \(error)")
            #endif
            return nil
        }
    }
    
    private func weatherCodeToCondition(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1, 2, 3: return "Partly Cloudy"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 80, 81, 82: return "Rain Showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Unknown"
        }
    }
}

struct SaxWeatherForecastEntryView: View {
    var entry: ForecastEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryRectangular:
            accessoryRectangularView
        default:
            lockScreenCircularView
        }
    }
    
    private var lockScreenCircularView: some View {
        VStack(spacing: 2) {
            if let high = entry.highTemp {
                Text("\(Int(high.rounded()))°")
                    .font(.system(size: 20, weight: .bold))
            } else {
                Text("--°")
                    .font(.system(size: 20, weight: .bold))
            }
            
            Image(systemName: weatherIcon(for: entry.condition))
                .font(.system(size: 16))
            
            if let low = entry.lowTemp {
                Text("\(Int(low.rounded()))°")
                    .font(.system(size: 14))
                    .opacity(0.7)
            } else {
                Text("--°")
                    .font(.system(size: 14))
                    .opacity(0.7)
            }
        }
    }
    
    private var accessoryRectangularView: some View {
        HStack(spacing: 12) {
            Image(systemName: weatherIcon(for: entry.condition))
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 2) {
                if let high = entry.highTemp {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10))
                        Text("\(Int(high.rounded()))°")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                
                if let low = entry.lowTemp {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10))
                        Text("\(Int(low.rounded()))°")
                            .font(.system(size: 14))
                            .opacity(0.8)
                    }
                }
            }
        }
    }
    
    private func weatherIcon(for condition: String?) -> String {
        guard let condition = condition?.lowercased() else { return "questionmark" }
        
        if condition.contains("clear") || condition.contains("sunny") {
            return "sun.max.fill"
        } else if condition.contains("partly cloudy") || condition.contains("cloudy") {
            return "cloud.sun.fill"
        } else if condition.contains("rain") {
            return "cloud.rain.fill"
        } else if condition.contains("snow") {
            return "cloud.snow.fill"
        } else if condition.contains("thunder") || condition.contains("storm") {
            return "cloud.bolt.rain.fill"
        } else if condition.contains("fog") {
            return "cloud.fog.fill"
        }
        
        return "cloud.fill"
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
        .description("Shows current weather with detailed information. Works with all APIs: Weather Underground, OpenWeatherMap, and OpenMeteo.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}


// MARK: - OpenMeteo Response Models for Widgets
struct OpenMeteoWidgetResponse: Codable {
    let current: OpenMeteoCurrentWidget?
    let daily: OpenMeteoDailyWidget
}

struct OpenMeteoCurrentWidget: Codable {
    let temperature2m: Double
    let relativeHumidity2m: Double
    let apparentTemperature: Double
    let windSpeed10m: Double
    let pressureMsl: Double
    let uvIndex: Double
    let weatherCode: Int
    
    enum CodingKeys: String, CodingKey {
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case apparentTemperature = "apparent_temperature"
        case windSpeed10m = "wind_speed_10m"
        case pressureMsl = "pressure_msl"
        case uvIndex = "uv_index"
        case weatherCode = "weather_code"
    }
}

struct OpenMeteoDailyWidget: Codable {
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]
    let weatherCode: [Int]
    
    enum CodingKeys: String, CodingKey {
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case weatherCode = "weather_code"
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

#Preview(as: .accessoryCircular) {
    SaxWeatherWidget()
} timeline: {
    WeatherWidgetEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8, humidity: 62.0, feelsLike: 29.5, windSpeed: 15.0, uvIndex: 8, pressure: 1015.0)
    WeatherWidgetEntry(date: .now, temperature: -3.7, condition: "Snowy", high: -1.2, low: -6.5, humidity: 92.0, feelsLike: -8.2, windSpeed: 32.0, uvIndex: 1, pressure: 995.0)
}

#Preview(as: .accessoryRectangular) {
    SaxWeatherWidget()
} timeline: {
    WeatherWidgetEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8, humidity: 62.0, feelsLike: 29.5, windSpeed: 15.0, uvIndex: 8, pressure: 1015.0)
    WeatherWidgetEntry(date: .now, temperature: 15.6, condition: "Rainy", high: 17.8, low: 12.4, humidity: 88.0, feelsLike: 14.2, windSpeed: 25.0, uvIndex: 2, pressure: 1005.0)
}

#Preview(as: .accessoryInline) {
    SaxWeatherWidget()
} timeline: {
    WeatherWidgetEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8, humidity: 62.0, feelsLike: 29.5, windSpeed: 15.0, uvIndex: 8, pressure: 1015.0)
    WeatherWidgetEntry(date: .now, temperature: 15.6, condition: "Rainy", high: 17.8, low: 12.4, humidity: 88.0, feelsLike: 14.2, windSpeed: 25.0, uvIndex: 2, pressure: 1005.0)
}
