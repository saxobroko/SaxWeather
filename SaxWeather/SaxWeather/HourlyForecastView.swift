//
//  HourlyForecastView.swift
//  SaxWeather
//
//  Created by Saxon Brooker on 2025-03-11
//

import SwiftUI
import Foundation

struct HourlyForecastView: View {
    @ObservedObject var weatherService: WeatherService
    @State private var hourlyData: [HourlyData] = []
    @State private var conditionSummary: String = "Loading hourly forecast..."
    @State private var isLoading = true
    @State private var error: String?
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundFillColor: Color {
        #if os(iOS)
        return Color(UIColor.systemGray6)
        #elseif os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section title with condition summary
            if !conditionSummary.isEmpty {
                Text(conditionSummary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            // Hourly forecast scrollable container
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if isLoading {
                        ForEach(0..<6, id: \.self) { _ in
                            hourlyForecastItemSkeleton()
                        }
                    } else if hourlyData.isEmpty {
                        Text("No hourly data available")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ForEach(hourlyData) { forecast in
                            hourlyForecastItem(forecast)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(height: 120)  // Set fixed height to ensure scrolling works properly
        }
        .onAppear {
            fetchHourlyForecast()
        }
    }
    
    private func hourlyForecastItem(_ forecast: HourlyData) -> some View {
        VStack(spacing: 8) {
            // Hour (12h format)
            Text(forecast.timeString)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            // Weather emoji
            Text(weatherSymbol(for: forecast.weatherCode))
                .font(.system(size: 24))
                .frame(width: 40, height: 40)
            
            // Temperature
            Text(tempString(forecast.temperature))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? backgroundFillColor : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        )
        .frame(width: 75)
    }
    
    // Helper to format temperature based on unit system
    private func tempString(_ temp: Double) -> String {
        var displayTemp = temp
        if unitSystem == "Imperial" {
            // Convert Celsius to Fahrenheit
            displayTemp = (temp * 9/5) + 32
        }
        return "\(Int(round(displayTemp)))°"
    }
    
    private func hourlyForecastItemSkeleton() -> some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 14)
                .cornerRadius(4)
            
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 30, height: 16)
                .cornerRadius(4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? backgroundFillColor : Color.white)
        )
        .frame(width: 75)
        .redacted(reason: .placeholder)
    }
    
    private func fetchHourlyForecast() {
        isLoading = true
        error = nil
        
        Task {
            do {
                // Get location coordinates
                let (latitude, longitude) = await getCoordinates()
                guard latitude != 0.0 && longitude != 0.0 else {
                    await MainActor.run {
                        isLoading = false
                        error = "Unable to determine location"
                        conditionSummary = "Location unavailable"
                    }
                    return
                }
                
                // Fetch hourly forecast data
                let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&hourly=temperature_2m,weather_code,wind_speed_10m,wind_gusts_10m&forecast_hours=24&timezone=auto")!
                
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoder = JSONDecoder()
                let response = try decoder.decode(HourlyAPIResponse.self, from: data)
                
                // Process the data
                let forecast = processHourlyForecast(response)
                let summary = generateConditionSummary(response)
                
                await MainActor.run {
                    self.hourlyData = forecast
                    self.conditionSummary = summary
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.error = "Failed to load forecast: \(error.localizedDescription)"
                    self.conditionSummary = "Unable to load forecast"
                    print("Error fetching hourly forecast: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func getCoordinates() async -> (Double, Double) {
        if weatherService.useGPS, let location = weatherService.locationManager.location {
            return (location.coordinate.latitude, location.coordinate.longitude)
        } else if let lat = Double(UserDefaults.standard.string(forKey: "latitude") ?? ""),
                  let lon = Double(UserDefaults.standard.string(forKey: "longitude") ?? "") {
            return (lat, lon)
        }
        
        // If using GPS but no location yet, try to wait for location update
        if weatherService.useGPS {
            do {
                weatherService.requestLocation()
                // Wait briefly for location to update
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                if let location = weatherService.locationManager.location {
                    return (location.coordinate.latitude, location.coordinate.longitude)
                }
            } catch {}
        }
        
        return (0.0, 0.0)
    }
    
    private func processHourlyForecast(_ response: HourlyAPIResponse) -> [HourlyData] {
        var forecasts: [HourlyData] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "ha" // 1PM, 2PM, etc.
        timeFormatter.amSymbol = "am"
        timeFormatter.pmSymbol = "pm"
        
        for i in 0..<min(response.hourly.time.count, 24) {
            if let date = formatter.date(from: response.hourly.time[i]) {
                let timeString = timeFormatter.string(from: date).lowercased()
                
                forecasts.append(HourlyData(
                    id: i,
                    time: date,
                    timeString: timeString,
                    temperature: response.hourly.temperature_2m[i],
                    weatherCode: response.hourly.weather_code[i],
                    windSpeed: response.hourly.wind_speed_10m[i],
                    windGust: response.hourly.wind_gusts_10m[i]
                ))
            }
        }
        
        return forecasts
    }
    
    private func generateConditionSummary(_ response: HourlyAPIResponse) -> String {
        // Group weather codes to identify patterns
        var conditions: [Int: Int] = [:] // [weatherCode: count]
        var maxWindGust = 0.0
        
        // Time of day names
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        
        let timeOfDay: String
        let nextPeriod: String
        
        if hour >= 5 && hour < 12 {
            timeOfDay = "this morning"
            nextPeriod = "afternoon"
        } else if hour >= 12 && hour < 17 {
            timeOfDay = "this afternoon"
            nextPeriod = "evening"
        } else if hour >= 17 && hour < 22 {
            timeOfDay = "this evening"
            nextPeriod = "overnight"
        } else {
            timeOfDay = "tonight"
            nextPeriod = "morning"
        }
        
        // Process the hourly data
        for i in 0..<min(response.hourly.weather_code.count, 24) {
            let code = response.hourly.weather_code[i]
            conditions[code, default: 0] += 1
            
            if i < response.hourly.wind_gusts_10m.count {
                maxWindGust = max(maxWindGust, response.hourly.wind_gusts_10m[i])
            }
        }
        
        // Find dominant weather condition
        let dominantCondition = conditions.max(by: { $0.value < $1.value })?.key ?? 0
        
        // Convert weather code to description
        let weatherDescription = weatherCodeToDescription(dominantCondition)
        
        // Format the wind gust info
        let windUnit = unitSystem == "Metric" ? "km/h" : "mph"
        
        var adjustedMaxWindGust = maxWindGust
        if unitSystem == "Imperial" {
            // Convert to mph if using Imperial
            adjustedMaxWindGust *= 0.621371
        }
        
        let windInfo = adjustedMaxWindGust >= 10 ? "Wind gusts up to \(Int(adjustedMaxWindGust)) \(windUnit)." : ""
        
        return "\(weatherDescription) \(timeOfDay), continuing through the \(nextPeriod). \(windInfo)"
    }
    
    private func weatherCodeToDescription(_ code: Int) -> String {
        switch code {
        case 0:
            return "Clear conditions"
        case 1:
            return "Mainly clear"
        case 2:
            return "Partly cloudy"
        case 3:
            return "Overcast"
        case 45, 48:
            return "Foggy conditions"
        case 51, 53, 55:
            return "Light drizzle"
        case 56, 57:
            return "Freezing drizzle"
        case 61, 63, 65:
            return "Rainy conditions"
        case 66, 67:
            return "Freezing rain"
        case 71, 73, 75:
            return "Snowfall"
        case 77:
            return "Snow grains"
        case 80, 81, 82:
            return "Rain showers"
        case 85, 86:
            return "Snow showers"
        case 95:
            return "Thunderstorm"
        case 96, 99:
            return "Thunderstorm with hail"
        default:
            return "Changing conditions"
        }
    }
    
    private func weatherSymbol(for code: Int) -> String {
        switch code {
        case 0:
            return "☀️"
        case 1:
            return "🌤️"
        case 2:
            return "⛅"
        case 3:
            return "☁️"
        case 45, 48:
            return "🌫️"
        case 51, 53, 55, 56, 57:
            return "🌦️"
        case 61, 63, 65, 66, 67:
            return "🌧️"
        case 71, 73, 75, 77:
            return "❄️"
        case 80, 81, 82:
            return "🌦️"
        case 85, 86:
            return "🌨️"
        case 95, 96, 99:
            return "⛈️"
        default:
            return "🌥️"
        }
    }
}
