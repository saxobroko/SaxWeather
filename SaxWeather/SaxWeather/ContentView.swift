//
//  ContentView.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-26 14:48:57
//

import SwiftUI
import CoreLocation
import StoreKit
import MapKit

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var storeManager: StoreManager
    @StateObject private var weatherService = WeatherService()
    @State private var showSettings = false
    @State private var isRefreshing = false
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    @Environment(\.colorScheme) private var systemColorScheme
    
    var body: some View {
        if isFirstLaunch {
            OnboardingView(isFirstLaunch: $isFirstLaunch, weatherService: weatherService)
                .preferredColorScheme(selectedColorScheme)
                .environmentObject(storeManager)
        } else {
            TabView {
                // Tab 1: Main Weather View
                mainWeatherView
                    .tabItem {
                        Label("Weather", systemImage: "cloud.sun.fill")
                    }
                
                // Tab 2: Forecast - Updated to use ForecastContainerView
                ForecastContainerView(weatherService: weatherService)
                    .tabItem {
                        Label("Forecast", systemImage: "calendar")
                    }
                
                // Tab 4: Settings
                SettingsView(weatherService: weatherService)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                
                // Tab 5: Debug Tab - Only shows in DEBUG builds
                #if DEBUG
                LottieDebugView()
                    .tabItem {
                        Label("Debug", systemImage: "ladybug.fill")
                    }
                #endif
            }
            .preferredColorScheme(selectedColorScheme)
        }
    }
    
    private var mainWeatherView: some View {
        NavigationView {
            ZStack {
                backgroundLayer
                contentLayer
            }
            .onAppear {
                Task {
                    await weatherService.fetchWeather()
                }
            }
        }
    }
    
    private var backgroundLayer: some View {
        // Use the wrapper which properly passes the environment object
        BackgroundViewWrapper(condition: weatherService.weather?.condition ?? "default")
    }
    
    struct BackgroundViewWrapper: View {
        let condition: String
        @EnvironmentObject var storeManager: StoreManager
        
        var body: some View {
            BackgroundView(condition: condition)
                .environmentObject(storeManager)
        }
    }
    
    private var contentLayer: some View {
        VStack {
            ScrollView {
                VStack {
                    weatherContent
                    refreshButton
                }
            }
            footerView
        }
    }
    
    private var weatherContent: some View {
        Group {
            if let weather = weatherService.weather, weather.hasData {
                // Use SF Symbols instead of Lottie
                VStack(spacing: 8) {
                    // Weather animation based on condition
                    LottieView(name: getAnimationName(for: weather.condition))
                        .frame(width: 150, height: 150)
                        .padding(.top, 20)
                    
                    // Current Temperature Display
                    if let temperature = weather.temperature {
                        // Get the unit directly from UserDefaults with a default to celsius
                        let unitSymbol = UserDefaults.standard.string(forKey: "temperatureUnit") == "fahrenheit" ? "°F" : "°C"
                        
                        Text(String(format: "%.1f%@", temperature, unitSymbol))
                            .font(.system(size: 80, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    if let feelsLike = weather.feelsLike {
                        Text(String(format: "Feels like %.1f%@", feelsLike, temperatureUnit))
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        if let high = weather.high {
                            Text(String(format: "H: %.1f%@", high, temperatureUnit))
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        if let low = weather.low {
                            Text(String(format: "L: %.1f%@", low, temperatureUnit))
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.vertical, 30)  // Reduced from 50 to accommodate the animation
                
                WeatherDetailsView(weather: weather)
            } else {
                Text("Loading weather data...")
                    .foregroundColor(.primary)
                    .padding()
            }
        }
    }
    
    // Helper to determine animation name
    private func getAnimationName(for condition: String) -> String {
        let lowercased = condition.lowercased()
        let isNight = isNighttime()
        
        if lowercased.contains("clear") || lowercased.contains("sunny") {
               return isNight ? "clear-night" : "clear-day"
           } else if lowercased.contains("partly cloudy") {
               return isNight ? "partly-cloudy-night" : "partly-cloudy"
           } else if lowercased.contains("cloud") || lowercased.contains("overcast") {
               return "cloudy"
           } else if lowercased.contains("fog") || lowercased.contains("mist") {
               return "foggy"
           } else if lowercased.contains("rain") || lowercased.contains("shower") || lowercased.contains("drizzle") {
               return "rainy"
           } else if lowercased.contains("snow") || lowercased.contains("sleet") || lowercased.contains("ice") {
               return "snow"  // Note: You might need to add this file
           } else if lowercased.contains("thunder") || lowercased.contains("lightning") || lowercased.contains("storm") {
               return "thunderstorm"
           }
        return isNight ? "clear_night" : "clear_day"
    }
    
    // Helper function to determine if it's nighttime
    private func isNighttime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour > 18
    }
    
    private var refreshButton: some View {
        Button {
            Task {
                isRefreshing = true
                await weatherService.fetchWeather()
                isRefreshing = false
            }
        } label: {
            HStack {
                if isRefreshing {
                    ProgressView()
                        .tint(systemColorScheme == .dark ? .white : .blue)
                }
                Text("Refresh")
            }
            .padding()
            .background(systemColorScheme == .dark ? Color.blue.opacity(0.6) : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .disabled(isRefreshing)
    }
    
    private var footerView: some View {
        Text("Made by Saxo_Broko")
            .font(.caption)
            .foregroundColor(.primary)
            .padding(.bottom, 10)
    }
    
    private var temperatureUnit: String {
        UserDefaults.standard.string(forKey: "unitSystem") == "Metric" ? "°C" : "°F"
    }
    
    private var selectedColorScheme: ColorScheme? {
        switch colorScheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return .dark
        }
    }
}

// MARK: - Forecast Container View (renamed to avoid conflict)
struct ForecastContainerView: View {
    @ObservedObject var weatherService: WeatherService
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Group {
                if let forecast = weatherService.forecast {
                    if forecast.daily.isEmpty {
                        emptyForecastView
                    } else {
                        ForecastView(forecast: forecast, unitSystem: weatherService.unitSystem)
                    }
                } else if let error = weatherService.error {
                    errorView(message: error)
                } else {
                    loadingView
                }
            }
            .navigationTitle("Forecast")
        }
        .onAppear {
            if weatherService.forecast == nil {
                fetchForecast()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading forecast data...")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var emptyForecastView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("No forecast data available")
                .font(.headline)
            
            Text("Please check your location settings or try again later")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Refresh") {
                fetchForecast()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error Loading Forecast")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                fetchForecast()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            if !weatherService.useGPS {
                Button("Enable GPS Location") {
                    weatherService.useGPS = true
                    fetchForecast()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private func fetchForecast() {
        isLoading = true
        Task {
            await weatherService.fetchForecasts()
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Weather Details View
struct WeatherDetailsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let weather: Weather
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    
    private var temperatureUnit: String {
        unitSystem == "Metric" ? "°C" : "°F"
    }
    
    private var speedUnit: String {
        unitSystem == "Metric" ? "km/h" : "mph"
    }
    
    private var pressureUnit: String {
        unitSystem == "Metric" ? "hPa" : "inHg"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(weatherMetrics, id: \.title) { metric in
                if let value = metric.value {
                    WeatherRowView(title: metric.title, value: value)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.8))
                .shadow(radius: 5)
        )
        .padding(.horizontal)
    }
    
    private var weatherMetrics: [(title: String, value: String?)] {
        [
            ("Humidity", weather.humidity.map { "\($0)%" }),
            ("Dew Point", weather.dewPoint.map { String(format: "%.1f%@", $0, temperatureUnit) }),
            ("Pressure", weather.pressure.map { String(format: "%.1f %@", $0, pressureUnit) }),
            ("Wind Speed", weather.windSpeed.map { String(format: "%.1f %@", $0, speedUnit) }),
            ("Wind Gust", weather.windGust.map { String(format: "%.1f %@", $0, speedUnit) }),
            ("UV Index", weather.uvIndex.map { "\($0)" }),
            ("Solar Radiation", weather.solarRadiation.map { "\($0) W/m²" })
        ]
    }
}

// MARK: - Weather Row View
struct WeatherRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.blue)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
