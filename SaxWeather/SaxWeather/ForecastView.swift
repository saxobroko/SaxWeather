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
    @State private var longPressedDay: WeatherForecast.DailyForecast?
    @State private var hourlyData: [HourlyWeatherData] = []
    @State private var conditionSummary: String = ""
    @State private var isLoadingHourly = true
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var registry = CustomisationRegistry.shared
    @EnvironmentObject private var storeManager: StoreManager

    /// Resolved background strategy for the current condition +
    /// active profile + sun position.
    private var forecastBackgroundStrategy: BackgroundStrategy {
        BackgroundResolver.resolve(
            condition: weatherService.currentBackgroundCondition,
            spec: registry.profile.knobs.background,
            sunrise: weatherService.forecast?.daily.first?.sunrise,
            sunset: weatherService.forecast?.daily.first?.sunset,
            now: Date(),
            customBackgroundUnlocked: storeManager.customBackgroundUnlocked,
            isCosmeticUnlocked: storeManager.owns
        )
    }

    /// Effective overlay opacity, gated on the IAP. Falls back
    /// to the free default (0.28) when the IAP is locked.
    private var forecastOverlayOpacity: Double {
        BackgroundResolver.effectiveOverlayOpacity(
            spec: registry.profile.knobs.background,
            customBackgroundUnlocked: storeManager.customBackgroundUnlocked
        )
    }
    
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
            BackgroundView(strategy: forecastBackgroundStrategy)
                .ignoresSafeArea()
            // Add a dark overlay for better contrast.
            Color.black.opacity(forecastOverlayOpacity)
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
                    
                    // Hourly forecast section.
                    // The header + condition summary live in a
                    // styled card so they follow the user's
                    // Card Settings. The `ScrollView` is
                    // intentionally NOT inside the card —
                    // wrapping a horizontal scroll in a clipped
                    // + shadowed frame on iOS 16+ intermittently
                    // swallows the pan gesture, and the items
                    // themselves are already individual cards
                    // (`.styledCard()` per item) so the visual
                    // language is preserved.
                    VStack(alignment: .leading, spacing: 12) {
                        // Section header + condition summary card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "clock")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                                Text("Hourly Forecast")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            Group {
                                if isLoadingHourly {
                                    SkeletonView(cornerRadius: 4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .frame(height: 16)
                                        .transition(.opacity)
                                } else if !conditionSummary.isEmpty {
                                    Text(conditionSummary)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .transition(
                                            .opacity.combined(with: .move(edge: .top))
                                        )
                                }
                            }
                            .cardAppearanceAnimation(value: isLoadingHourly)
                        }
                        .padding(16)
                        .styledCard()
                    }
                    .padding(.horizontal, 20)

                    // Hourly forecast scrollable container.
                    // Placed OUTSIDE the styled card so the pan
                    // gesture is never clipped or shadowed.
                    // Each item is its own small card so the
                    // visual rhythm matches the rest of the app.
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
                                        .cardAppearanceTransition()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                    .cardAppearanceAnimation(value: isLoadingHourly)
                    
                    // YOUR ORIGINAL DAILY FORECAST SECTION
                    // Daily forecast cards in a vertical stack
                    if let forecast = weatherService.forecast {
                        LazyVStack(spacing: 16) {
                            ForEach(forecast.daily) { day in
                                // The card itself — the date
                                // header is now the first row of
                                // the card so it follows the
                                // user's Card Settings. The tap
                                // and long-press gestures are gated
                                // by the Behaviour settings so the
                                // user can disable either one from
                                // Settings, Behaviour, Gestures.
                                ForecastDayCard(day: day, unitSystem: weatherService.unitSystem, dateText: formattedDate(day.date))
                                    .padding(.horizontal, 20)
                                    .contentShape(Rectangle())
                                    .if(SettingsBehaviour.tapDayToExpand) { view in
                                        view.onTapGesture {
                                            #if canImport(UIKit)
                                            if SettingsBehaviour.hapticOnSelection {
                                                HapticFeedbackHelper.shared.light()
                                            }
                                            #endif
                                            selectedDay = day
                                        }
                                    }
                                    .if(SettingsBehaviour.longPressToCustomise) { view in
                                        view.onLongPressGesture(minimumDuration: 0.6) {
                                            #if canImport(UIKit)
                                            if SettingsBehaviour.enableHapticFeedback {
                                                HapticFeedbackHelper.shared.medium()
                                            }
                                            #endif
                                            longPressedDay = day
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Skeleton loading for daily forecasts.
                        // Mirrors the new card layout (date
                        // header inside the card) so the
                        // placeholder height matches the
                        // real card.
                        LazyVStack(spacing: 16) {
                            ForEach(0..<5, id: \.self) { _ in
                                VStack(alignment: .leading, spacing: 10) {
                                    // Date header skeleton
                                    SkeletonView(cornerRadius: 4)
                                        .frame(height: 20)
                                    Divider()
                                        .opacity(0.4)
                                    // Card body skeleton
                                    SkeletonView(cornerRadius: 16)
                                        .frame(height: 80)
                                }
                                .styledCard()
                            }
                        }
                        .padding(.horizontal, 20)
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
        // Long-press customisation sheet. Triggered by the
        // `longPressToCustomise` gesture on each day card.
        .sheet(item: $longPressedDay) { day in
            DayCustomiseSheet(
                day: day,
                unitSystem: weatherService.unitSystem
            )
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
        .onAppear {
            guard hourlyData.isEmpty else { return }
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

        #if DEBUG
        // Log the first few forecast items to debug
        if forecast.id < 3 {
            print("🎨 Hourly Forecast Item #\(forecast.id): time=\(forecast.timeString), weatherCode=\(forecast.weatherCode), isNight=\(isNight)")
        }
        #endif

        return VStack(spacing: 12) {
            // Hour (12h format)
            Text(forecast.timeString)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            ConditionIcon(
                weatherCode: forecast.weatherCode,
                isNight: isNight,
                size: 40
            )
            .frame(width: 40, height: 40)
            
            // Temperature
            Text(tempString(forecast.temperature))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .frame(width: 80)
        .styledCard()
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
        .frame(width: 80)
        .styledCard()
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
        guard hourlyData.isEmpty else { return }
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
        let windUnit = UnitSystem.from(rawValue: weatherService.unitSystem).speedLabel
        
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
        let windUnit = UnitSystem.from(rawValue: weatherService.unitSystem).speedLabel
        
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
    let dateText: String
    @Environment(\.colorScheme) var colorScheme

    private var cardFillColor6: Color {
        #if os(iOS)
        return Color(UIColor.systemGray6)
        #elseif os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Day / date header — now lives inside the card
            // so it follows the user's Card Settings (corner
            // radius, padding, fill, shadow, border, tint).
            HStack {
                Text(dateText)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .semibold))
            }
            Divider()
                .opacity(0.4)
            HStack(spacing: 20) {
                // Left: Weather Lottie animation and temperatures
                HStack(spacing: 12) {
                    ConditionIcon(
                        weatherCode: day.weatherCode,
                        isNight: false,
                        size: 44
                    )
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading) {
                        Text("\(UnitConverter.formatTemperature(day.tempMax))°")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .fixedSize(horizontal: true, vertical: false)

                        Text("\(UnitConverter.formatTemperature(day.tempMin))°")
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
                        value: "\(Int(round(day.windSpeed))) \(UnitSystem.from(rawValue: unitSystem).speedLabel)"
                    )
                }
            }
        }
        // The styledCard() modifier handles the internal
        // padding (driven by `cardPaddingH` / `cardPaddingV`
        // from the user's Card Settings) and the frame. The
        // outer 20pt gap is added at the call site so this
        // card lines up with the hourly card and the main
        // page's UV Index / Air Quality / Sun / Moon /
        // Precipitation / Pollen cards.
        .styledCard()
    }
}

// MARK: - Day Customisation Sheet
//
// Long-press affordance for a single day card. Lets the user pin
// the day's profile / temperature / unit override without leaving
// the forecast. The gesture that presents this sheet is gated by
// `SettingsBehaviour.longPressToCustomise`.

struct DayCustomiseSheet: View {
    let day: WeatherForecast.DailyForecast
    let unitSystem: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("pinnedDayKeys") private var pinnedDayKeysData: String = ""
    @AppStorage("dayNicknames") private var dayNicknamesData: String = ""

    private var dayKey: String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: day.date)
        return String(format: "%04d-%02d-%02d",
                      comps.year ?? 0,
                      comps.month ?? 0,
                      comps.day ?? 0)
    }

    private var isPinned: Bool {
        pinnedKeys.contains(dayKey)
    }

    private var pinnedKeys: Set<String> {
        pinnedDayKeysData
            .split(separator: ",")
            .map(String.init)
            .reduce(into: Set<String>()) { acc, key in
                let trimmed = key.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { acc.insert(trimmed) }
            }
    }

    private var nickname: Binding<String> {
        Binding(
            get: { nicknames[dayKey] ?? "" },
            set: { newValue in
                var n = nicknames
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    n.removeValue(forKey: dayKey)
                } else {
                    n[dayKey] = trimmed
                }
                dayNicknamesData = n
                    .map { "\($0.key)=\($0.value)" }
                    .joined(separator: ",")
            }
        )
    }

    private var nicknames: [String: String] {
        guard !dayNicknamesData.isEmpty else { return [:] }
        var out: [String: String] = [:]
        for pair in dayNicknamesData.split(separator: ",") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                out[parts[0]] = parts[1]
            }
        }
        return out
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.accentColor)
                        Text(day.date.formatted(date: .complete, time: .omitted))
                        Spacer()
                    }
                } header: {
                    Text("Day")
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { isPinned },
                        set: { newValue in
                            var keys = pinnedKeys
                            if newValue {
                                keys.insert(dayKey)
                            } else {
                                keys.remove(dayKey)
                            }
                            pinnedDayKeysData = keys.joined(separator: ",")
                            #if canImport(UIKit)
                            HapticFeedbackHelper.shared.light()
                            #endif
                        }
                    )) {
                        Label("Pin day", systemImage: "pin.fill")
                    }
                    TextField("Nickname (optional)", text: nickname)
                } header: {
                    Text("Customise")
                } footer: {
                    Text("Pinned days stay expanded in the forecast. Nicknames show in the daily header instead of the date.")
                }

                Section {
                    HStack {
                        Label("High", systemImage: "thermometer.sun")
                        Spacer()
                        Text(highString)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Low", systemImage: "thermometer.snowflake")
                        Spacer()
                        Text(lowString)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Condition", systemImage: "cloud")
                        Spacer()
                        Text(day.weatherDescription)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Details")
                }
            }
            .navigationTitle("Customise Day")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var highString: String {
        String(format: "%.0f°", day.tempMax)
    }

    private var lowString: String {
        String(format: "%.0f°", day.tempMin)
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

