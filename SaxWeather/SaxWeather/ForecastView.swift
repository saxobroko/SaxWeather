//
//  ForecastView.swift
//  SaxWeather
//
//  Created by Saxon Brooker on 2025-03-11.
//

import SwiftUI
import Foundation
import Lottie // Make sure to import Lottie

struct ForecastView: View {
    @ObservedObject var weatherService: WeatherService
    @State private var selectedDay: WeatherForecast.DailyForecast?
    @State private var hourlyData: [HourlyData] = []
    @State private var conditionSummary: String = ""
    @State private var isLoadingHourly = true
    @Environment(\.colorScheme) var colorScheme
    
    init(weatherService: WeatherService) {
        self.weatherService = weatherService
    }
    
    var body: some View {
        let cardBackgroundColor = colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white
        let shadowColor = colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.15)
        
        NavigationView {
            ZStack {
                // BackgroundView implementation
                if let forecast = weatherService.forecast {
                    BackgroundView(condition: getCondition(for: forecast))
                        .ignoresSafeArea()
                }
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Header section - keeping your original styling
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Weather Forecast")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            if let forecast = weatherService.forecast {
                                Text("Next \(forecast.daily.count) days")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        
                        // Improved hourly forecast section
                        VStack(alignment: .leading, spacing: 16) {
                            // Section header
                            HStack {
                                Image(systemName: "clock")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                
                                Text("Hourly Forecast")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            // Weather condition summary
                            if !conditionSummary.isEmpty && !isLoadingHourly {
                                Text(conditionSummary)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                            }
                            
                            // Hourly forecast scrollable container
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    if isLoadingHourly {
                                        ForEach(0..<6, id: \.self) { _ in
                                            hourlyForecastItemSkeleton()
                                        }
                                    } else if hourlyData.isEmpty {
                                        Text("No hourly data available")
                                            .foregroundColor(.secondary)
                                            .padding()
                                    } else {
                                        ForEach(hourlyData) { hour in
                                            hourlyForecastItem(hour)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(cardBackgroundColor)
                                .shadow(color: shadowColor, radius: 10, x: 0, y: 4)
                        )
                        .padding(.horizontal)
                        
                        // YOUR ORIGINAL DAILY FORECAST SECTION
                        // Daily forecast cards in a vertical stack
                        if let forecast = weatherService.forecast {
                            LazyVStack(spacing: 24) {
                                ForEach(forecast.daily) { day in
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Date header above the card
                                        Text(formattedDate(day.date))
                                            .font(.headline)
                                            .padding(.horizontal, 4)
                                        
                                        // The card itself
                                        ForecastDayCard(day: day, unitSystem: weatherService.unitSystem)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedDay = day
                                            }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            // Skeleton loading for daily forecasts
                            LazyVStack(spacing: 24) {
                                ForEach(0..<5, id: \.self) { _ in
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Date header skeleton
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 20)
                                            .cornerRadius(4)
                                            .padding(.horizontal, 4)
                                        
                                        // Card skeleton
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 120)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .redacted(reason: .placeholder)
                        }
                    }
                    .padding(.vertical)
                }
                .background(Color.clear)
            }
            .sheet(item: $selectedDay) { day in
                DetailedForecastSheet(day: day, unitSystem: weatherService.unitSystem)
            }
            .navigationBarHidden(true)
            .onAppear {
                fetchHourlyForecast()
            }
        }
    }
    
    // Get condition for background view
    private func getCondition(for forecast: WeatherForecast) -> String {
        if let firstHourData = hourlyData.first {
            return weatherTypeFor(code: firstHourData.weatherCode)
        } else if let firstDay = forecast.daily.first {
            return weatherTypeFor(code: firstDay.weatherCode)
        } else {
            return "clear"
        }
    }
    
    // Map weather code to weather type for background images
    private func weatherTypeFor(code: Int) -> String {
        switch code {
        case 0, 1: return "sunny"
        case 2, 3: return "cloudy"
        case 45, 48: return "foggy"
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return "rainy"
        case 71, 73, 75, 77, 85, 86: return "snowy"
        case 95, 96, 99: return "thunder"
        default: return "clear"
        }
    }
    
    // Helper function to format date - from your original code
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
    
    // Hourly forecast item view with Lottie animations
    private func hourlyForecastItem(_ forecast: HourlyData) -> some View {
        // Check if it's night based on hour
        let hour = Calendar.current.component(.hour, from: forecast.time)
        let isNight = hour < 6 || hour > 18
        
        return VStack(spacing: 12) {
            // Hour (12h format)
            Text(forecast.timeString)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            // Weather Lottie animation - using your existing LottieView and WeatherAnimationHelper
            LottieView(name: WeatherAnimationHelper.animationNameFromCode(for: forecast.weatherCode, isNight: isNight))
                .frame(width: 40, height: 40)
            
            // Temperature
            Text(tempString(forecast.temperature))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    colorScheme == .dark ?
                    Color(UIColor.systemGray5).opacity(0.9) :
                    Color.white.opacity(0.9)
                )
                .shadow(color: colorScheme == .dark ?
                        Color.black.opacity(0.2) :
                        Color.gray.opacity(0.1),
                       radius: 5, x: 0, y: 2)
        )
        .frame(width: 80)
    }
    
    private func hourlyForecastItemSkeleton() -> some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 14)
            
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
            
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 30, height: 16)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ?
                      Color(UIColor.systemGray5).opacity(0.9) :
                      Color.white.opacity(0.9))
        )
        .frame(width: 80)
    }
    
    // Helper to format temperature based on unit system
    private func tempString(_ temp: Double) -> String {
        var displayTemp = temp
        if weatherService.unitSystem == "Imperial" {
            // Convert Celsius to Fahrenheit
            displayTemp = (temp * 9/5) + 32
        }
        return "\(Int(round(displayTemp)))°"
    }
    
    private func weatherSymbol(for code: Int) -> String {
        switch code {
        case 0: return "☀️"
        case 1: return "🌤️"
        case 2: return "⛅"
        case 3: return "☁️"
        case 45, 48: return "🌫️"
        case 51, 53, 55, 56, 57: return "🌦️"
        case 61, 63, 65, 66, 67: return "🌧️"
        case 71, 73, 75, 77: return "❄️"
        case 80, 81, 82: return "🌦️"
        case 85, 86: return "🌨️"
        case 95, 96, 99: return "⛈️"
        default: return "🌥️"
        }
    }
    
    private func fetchHourlyForecast() {
        isLoadingHourly = true
        
        Task {
            do {
                // Get location coordinates
                let (latitude, longitude) = await getCoordinates()
                guard latitude != 0.0 && longitude != 0.0 else {
                    await MainActor.run {
                        isLoadingHourly = false
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
                    self.isLoadingHourly = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingHourly = false
                    self.conditionSummary = "Unable to load hourly forecast"
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
                try await Task.sleep(for: .seconds(2)) // 2 seconds
                
                if let location = weatherService.locationManager.location {
                    return (location.coordinate.latitude, location.coordinate.longitude)
                }
            } catch {}
        }
        
        return (0.0, 0.0)
    }
    
    // Process hourly forecast data
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
    
    // Generate weather condition summary
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
        let windUnit = weatherService.unitSystem == "Metric" ? "km/h" : "mph"
        
        var adjustedMaxWindGust = maxWindGust
        if weatherService.unitSystem == "Imperial" {
            // Convert to mph if using Imperial
            adjustedMaxWindGust *= 0.621371
        }
        
        let windInfo = adjustedMaxWindGust >= 10 ? "Wind gusts up to \(Int(adjustedMaxWindGust)) \(windUnit)." : ""
        
        return "\(weatherDescription) \(timeOfDay), continuing through the \(nextPeriod). \(windInfo)".trimmingCharacters(in: .whitespaces)
    }
    
    private func weatherCodeToDescription(_ code: Int) -> String {
        switch code {
        case 0: return "Clear conditions"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy conditions"
        case 51, 53, 55: return "Light drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rainy conditions"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snowfall"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Changing conditions"
        }
    }
}

struct ForecastDayCard: View {
    let day: WeatherForecast.DailyForecast
    let unitSystem: String
    @Environment(\.colorScheme) var colorScheme
    @State private var loadingFailed: Bool = false
    
    var body: some View {
        HStack(spacing: 20) {
            // Left: Weather Lottie animation and temperatures
            HStack(spacing: 12) {
                // Use Lottie animation instead of text emoji
                if loadingFailed {
                    Text(day.weatherSymbol)
                        .font(.system(size: 32))
                        .frame(width: 44, height: 44)
                        .minimumScaleFactor(0.7)
                } else {
                    // Get proper day/night animation based on time
                    let isNight = WeatherAnimationHelper.isNighttime(sunrise: day.sunrise, sunset: day.sunset)
                    LottieView(
                        name: WeatherAnimationHelper.animationNameFromCode(
                            for: day.weatherCode,
                            isNight: isNight
                        ),
                        loadingFailed: $loadingFailed
                    )
                    .frame(width: 44, height: 44)
                }
                
                VStack(alignment: .leading) {
                    Text("\(Int(round(day.tempMax)))°")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                    
                    Text("\(Int(round(day.tempMin)))°")
                        .font(.system(size: 17, design: .rounded))
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Right: Key weather data
            HStack(spacing: 16) {
                WeatherDataColumn(
                    icon: "💧",
                    label: "Hum",
                    value: "\(Int(round(day.humidity)))%"
                )
                
                WeatherDataColumn(
                    icon: "🌧️",
                    label: "Rain",
                    value: "\(Int(round(day.precipitationProbability)))%"
                )
                
                WeatherDataColumn(
                    icon: "💨",
                    label: "Wind",
                    value: "\(Int(round(day.windSpeed)))"
                )
            }
            
            // Chevron icon
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .semibold))
                .padding(.leading, 5)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ?
                      Color(UIColor.systemGray6) :
                      Color.white)
                .shadow(color: colorScheme == .dark ?
                        Color.black.opacity(0.3) :
                        Color.gray.opacity(0.2),
                        radius: 8, x: 0, y: 4)
        )
    }
}

// Original WeatherDataColumn from your code
struct WeatherDataColumn: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 20))
            
            Text(label)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .frame(minWidth: 45)
    }
}
