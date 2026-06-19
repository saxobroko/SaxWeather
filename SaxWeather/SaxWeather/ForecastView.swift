//
//  ForecastView.swift
//  SaxWeather
//
//  Created by Saxon Brooker on 2025-03-11.
//

import SwiftUI
import Foundation
import CoreLocation
#if canImport(WeatherKit)
import WeatherKit
#endif

struct ForecastView: View {
    @ObservedObject var weatherService: WeatherService
    @State private var selectedDay: WeatherForecast.DailyForecast?
    @State private var hourlyData: [HourlyWeatherData] = []
    @State private var conditionSummary: String = ""
    @State private var isLoadingHourly = true
    @Environment(\.colorScheme) var colorScheme
    
    // Unified card styling
    private var cardBackgroundColor: Color {
        #if os(iOS)
        return colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white
        #elseif os(macOS)
        return colorScheme == .dark ? Color(NSColor.windowBackgroundColor) : Color.white
        #endif
    }
    
    private var cardShadowColor: Color {
        return colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.15)
    }
    
    private var cardFillColor: Color {
        #if os(iOS)
        return Color(UIColor.systemGray5).opacity(0.9)
        #elseif os(macOS)
        return Color(NSColor.windowBackgroundColor).opacity(0.9)
        #endif
    }
    
    private var cardFillColor6: Color {
        #if os(iOS)
        return Color(UIColor.systemGray6)
        #elseif os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    init(weatherService: WeatherService) {
        self.weatherService = weatherService
    }
    
    var body: some View {
        ZStack {
            // Use the centralized background condition
            BackgroundView(condition: weatherService.currentBackgroundCondition)
                .ignoresSafeArea()
            // Add a dark overlay for better contrast
            Color.black.opacity(0.28)
                .blur(radius: 8)
                .ignoresSafeArea()
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 8)
            
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
                                .foregroundColor(.accentColor)
                            
                            Text("Hourly Forecast")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 4)

                        // Weather condition summary.
                        // While loading we render an animated skeleton
                        // placeholder so the card height stays stable and
                        // there's no jarring pop-in when the real text
                        // arrives. When loaded, we crossfade in the real
                        // string.
                        Group {
                            if isLoadingHourly {
                                SkeletonView(cornerRadius: 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 16)
                                    .padding(.horizontal, 20)
                                    .transition(.opacity)
                            } else if !conditionSummary.isEmpty {
                                Text(conditionSummary)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                    .transition(
                                        .opacity.combined(with: .move(edge: .top))
                                    )
                            }
                        }
                        .animation(
                            .easeInOut(duration: 0.35),
                            value: isLoadingHourly
                        )
                        .animation(
                            .easeInOut(duration: 0.35),
                            value: conditionSummary
                        )

                        // Hourly forecast scrollable container.
                        // Skeletons stay in place while loading, then we
                        // crossfade to the real forecast items once the
                        // data arrives — no abrupt swap.
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                if isLoadingHourly {
                                    ForEach(0..<6, id: \.self) { _ in
                                        hourlyForecastItemSkeleton()
                                            .transition(.opacity)
                                    }
                                } else if hourlyData.isEmpty {
                                    Text("No hourly data available")
                                        .foregroundColor(.secondary)
                                        .padding()
                                        .transition(.opacity)
                                } else {
                                    ForEach(hourlyData) { hour in
                                        hourlyForecastItem(hour)
                                            .transition(
                                                .asymmetric(
                                                    insertion: .opacity
                                                        .combined(with: .scale(scale: 0.92)),
                                                    removal: .opacity
                                                )
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .animation(
                            .easeInOut(duration: 0.4),
                            value: isLoadingHourly
                        )
                        .animation(
                            .easeInOut(duration: 0.4),
                            value: hourlyData.count
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBackgroundColor)
                            .shadow(color: cardShadowColor, radius: 10, x: 0, y: 4)
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
                    
                    // Weather data attribution (required for legal compliance)
                    WeatherAttributionView(
                        dataSource: weatherService.forecastDataSource,
                        stationID: UserDefaults.standard.string(forKey: "stationID"),
                        useForecastSource: true
                    )
                    .padding(.top, 16)
                }
                .padding(.vertical)
            }
            .background(Color.clear)
        }
        .sheet(item: $selectedDay) { day in
            DetailedForecastSheet(day: day, unitSystem: weatherService.unitSystem)
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
        .onAppear {
            fetchHourlyForecast()
        }
    }
    
    // Helper function to format date - from your original code
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
    
    // Hourly forecast item view with Lottie animations
    private func hourlyForecastItem(_ forecast: HourlyWeatherData) -> some View {
        // Check if it's night based on hour
        let hour = Calendar.current.component(.hour, from: forecast.time)
        let isNight = hour < 6 || hour > 18
        
        let animationName = WeatherAnimationHelper.animationNameFromCode(for: forecast.weatherCode, isNight: isNight)
        
        #if DEBUG
        // Log the first few forecast items to debug
        if forecast.id < 3 {
            print("🎨 Hourly Forecast Item #\(forecast.id): time=\(forecast.timeString), weatherCode=\(forecast.weatherCode), isNight=\(isNight), animation='\(animationName)'")
        }
        #endif
        
        return VStack(spacing: 12) {
            // Hour (12h format)
            Text(forecast.timeString)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            // Weather Lottie animation - using your existing LottieView and WeatherAnimationHelper
            LottieView(name: animationName)
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
                .fill(cardFillColor)
                .shadow(color: colorScheme == .dark ?
                        Color.black.opacity(0.2) :
                        Color.gray.opacity(0.1),
                       radius: 5, x: 0, y: 2)
        )
        .frame(width: 80)
    }
    
    private func hourlyForecastItemSkeleton() -> some View {
        // Animated shimmer placeholder that mirrors the layout
        // of `hourlyForecastItem(_:)` so the card height and
        // item spacing stay identical between the loading and
        // loaded states — preventing layout shift when data
        // arrives.
        VStack(spacing: 12) {
            // Hour label placeholder
            SkeletonView(cornerRadius: 4)
                .frame(width: 40, height: 14)

            // Weather icon placeholder
            SkeletonView(cornerRadius: 20)
                .frame(width: 40, height: 40)

            // Temperature placeholder
            SkeletonView(cornerRadius: 4)
                .frame(width: 30, height: 16)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardFillColor)
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
                
                // Check if WeatherKit is available and being used
                if #available(iOS 16.0, macOS 13.0, *),
                   weatherService.forecastDataSource == "weatherkit" {
                    // Fetch from WeatherKit for consistency
                    #if DEBUG
                    print("🌍 Using WeatherKit for hourly forecast (matches daily forecast source)")
                    #endif
                    
                    try await fetchWeatherKitHourlyForecast(latitude: latitude, longitude: longitude)
                } else {
                    // Fetch from OpenMeteo
                    #if DEBUG
                    print("🌍 Using OpenMeteo for hourly forecast")
                    #endif
                    
                    try await fetchOpenMeteoHourlyForecast(latitude: latitude, longitude: longitude)
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
    
    @available(iOS 16.0, macOS 13.0, *)
    private func fetchWeatherKitHourlyForecast(latitude: Double, longitude: Double) async throws {
        #if canImport(WeatherKit)
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let weather = try await WeatherKit.WeatherService.shared.weather(for: location)
        
        let hourlyForecast = weather.hourlyForecast
        
        var forecasts: [HourlyWeatherData] = []
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "ha"
        timeFormatter.amSymbol = "am"
        timeFormatter.pmSymbol = "pm"
        
        #if DEBUG
        print("🌤️ Processing \(hourlyForecast.forecast.count) hourly forecasts from WeatherKit")
        #endif
        
        for (i, hour) in hourlyForecast.forecast.prefix(24).enumerated() {
            let timeString = timeFormatter.string(from: hour.date).lowercased()
            let weatherCode = mapWeatherKitConditionToWMOCode(hour.condition)
            
            #if DEBUG
            if i < 5 {
                print("🌤️ Hour \(i): time=\(timeString), temp=\(hour.temperature.value)°, condition=\(hour.condition), mappedCode=\(weatherCode)")
            }
            #endif
            
            forecasts.append(HourlyWeatherData(
                id: i,
                time: hour.date,
                timeString: timeString,
                temperature: hour.temperature.value,
                weatherCode: weatherCode,
                windSpeed: hour.wind.speed.value * 3.6, // m/s to km/h
                windGust: hour.wind.gust?.value ?? 0.0
            ))
        }
        
        let summary = generateWeatherKitConditionSummary(hourlyForecast)
        
        await MainActor.run {
            self.hourlyData = forecasts
            self.conditionSummary = summary
            self.isLoadingHourly = false
        }
        #endif
    }
    
    private func fetchOpenMeteoHourlyForecast(latitude: Double, longitude: Double) async throws {
        // Fetch hourly forecast data
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&hourly=temperature_2m,weather_code,wind_speed_10m,wind_gusts_10m&forecast_hours=24&timezone=auto")!
        
        #if DEBUG
        print("🌍 Fetching hourly forecast from: \(url)")
        #endif
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        #if DEBUG
        // Log raw JSON response to debug weather codes
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📡 Raw API Response (first 500 chars):")
            print(String(jsonString.prefix(500)))
        }
        #endif
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(HourlyAPIResponse.self, from: data)
        
        #if DEBUG
        print("📊 Decoded response: \(response.hourly.weather_code.count) weather codes")
        print("📊 First 5 weather codes: \(Array(response.hourly.weather_code.prefix(5)))")
        #endif
        
        // Process the data
        let forecast = processHourlyForecast(response)
        let summary = generateConditionSummary(response)
        
        await MainActor.run {
            self.hourlyData = forecast
            self.conditionSummary = summary
            self.isLoadingHourly = false
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
    private func processHourlyForecast(_ response: HourlyAPIResponse) -> [HourlyWeatherData] {
        var forecasts: [HourlyWeatherData] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "ha" // 1PM, 2PM, etc.
        timeFormatter.amSymbol = "am"
        timeFormatter.pmSymbol = "pm"
        
        #if DEBUG
        print("🌤️ Processing \(response.hourly.weather_code.count) hourly forecasts")
        #endif
        
        for i in 0..<min(response.hourly.weather_code.count, 24) {
            if let date = formatter.date(from: response.hourly.time[i]) {
                let timeString = timeFormatter.string(from: date).lowercased()
                let weatherCode = response.hourly.weather_code[i]
                
                #if DEBUG
                if i < 5 {  // Only log first 5 to avoid spam
                    print("🌤️ Hour \(i): time=\(timeString), temp=\(response.hourly.temperature_2m[i])°, weatherCode=\(weatherCode)")
                }
                #endif
                
                forecasts.append(HourlyWeatherData(
                    id: i,
                    time: date,
                    timeString: timeString,
                    temperature: response.hourly.temperature_2m[i],
                    weatherCode: weatherCode,
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
    
    // MARK: - WeatherKit Helper Functions
    
    @available(iOS 16.0, macOS 13.0, *)
    private func mapWeatherKitConditionToWMOCode(_ condition: WeatherCondition) -> Int {
        switch condition {
        case .clear: 
            return 0
        case .partlyCloudy, .mostlyClear: 
            return 2
        case .cloudy, .mostlyCloudy: 
            return 3
        case .foggy, .haze, .smoky: 
            return 45
        case .drizzle: 
            return 51
        case .rain, .heavyRain: 
            return 61
        case .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms, .thunderstorms: 
            return 95
        case .freezingRain, .sleet: 
            return 66
        case .snow, .heavySnow, .flurries, .blowingSnow: 
            return 71
        case .frigid: 
            return 71
        case .blizzard: 
            return 75
        case .wintryMix: 
            return 66
        case .breezy, .windy: 
            return 3
        case .hot, .hurricane, .tropicalStorm: 
            return 3
        case .sunFlurries: 
            return 85
        case .sunShowers: 
            return 80
        default: 
            return 0
        }
    }
    
    @available(iOS 16.0, macOS 13.0, *)
    private func generateWeatherKitConditionSummary(_ hourlyForecast: Forecast<HourWeather>) -> String {
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
        
        var conditions: [WeatherCondition: Int] = [:]
        var maxWindGust = 0.0
        
        for hour in hourlyForecast.forecast.prefix(24) {
            conditions[hour.condition, default: 0] += 1
            if let gust = hour.wind.gust?.value {
                maxWindGust = max(maxWindGust, gust)
            }
        }
        
        let dominantCondition = conditions.max(by: { $0.value < $1.value })?.key ?? .clear
        let weatherDescription = weatherKitConditionToDescription(dominantCondition)
        
        let adjustedMaxWindGust = maxWindGust * 3.6 // m/s to km/h
        let windUnit = weatherService.unitSystem == "Metric" ? "km/h" : "mph"
        
        let windInfo = adjustedMaxWindGust >= 10 ? "Wind gusts up to \(Int(adjustedMaxWindGust)) \(windUnit)." : ""
        
        return "\(weatherDescription) \(timeOfDay), continuing through the \(nextPeriod). \(windInfo)".trimmingCharacters(in: .whitespaces)
    }
    
    @available(iOS 16.0, macOS 13.0, *)
    private func weatherKitConditionToDescription(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear: 
            return "Clear conditions"
        case .mostlyClear: 
            return "Mainly clear"
        case .partlyCloudy: 
            return "Partly cloudy"
        case .cloudy, .mostlyCloudy: 
            return "Overcast"
        case .foggy, .haze, .smoky: 
            return "Foggy conditions"
        case .drizzle: 
            return "Light drizzle"
        case .rain: 
            return "Rainy conditions"
        case .heavyRain: 
            return "Heavy rain"
        case .freezingRain, .sleet: 
            return "Freezing rain"
        case .snow, .flurries: 
            return "Snowfall"
        case .heavySnow: 
            return "Heavy snow"
        case .blowingSnow, .blizzard: 
            return "Blizzard conditions"
        case .wintryMix: 
            return "Mixed precipitation"
        case .isolatedThunderstorms, .scatteredThunderstorms: 
            return "Scattered thunderstorms"
        case .strongStorms, .thunderstorms: 
            return "Thunderstorm"
        case .sunShowers: 
            return "Passing showers"
        case .sunFlurries: 
            return "Passing flurries"
        case .breezy, .windy: 
            return "Windy conditions"
        case .hot: 
            return "Hot weather"
        case .frigid: 
            return "Frigid conditions"
        case .hurricane, .tropicalStorm: 
            return "Severe weather"
        default: 
            return "Changing conditions"
        }
    }
}

struct ForecastDayCard: View {
    let day: WeatherForecast.DailyForecast
    let unitSystem: String
    @Environment(\.colorScheme) var colorScheme
    @State private var loadingFailed: Bool = false
    
    private var cardFillColor6: Color {
        #if os(iOS)
        return Color(UIColor.systemGray6)
        #elseif os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    private var animationName: String {
        let name = WeatherAnimationHelper.animationNameFromCode(
            for: day.weatherCode,
            isNight: false
        )
        #if DEBUG
        print("📅 ForecastDayCard: date=\(day.date), weatherCode=\(day.weatherCode), animation='\(name)'")
        #endif
        return name
    }
    
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
                    // For daily forecasts, always use daytime animations (represents the whole day)
                    LottieView(
                        name: animationName,
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
                .fill(cardFillColor6)
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

