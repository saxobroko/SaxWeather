//
//  ContentView.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-26 14:48:57
//

import SwiftUI
import CoreLocation

// MARK: - Content View
struct ContentView: View {
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
                
                // Tab 3: Settings
                SettingsView(weatherService: weatherService)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
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
        BackgroundView(condition: weatherService.weather?.condition ?? "default")
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
                VStack(spacing: 8) {
                    // Current Temperature Display
                    if let temperature = weather.temperature {
                        Text(String(format: "%.1f%@", temperature, temperatureUnit))
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
                .padding(.vertical, 50)
                
                WeatherDetailsView(weather: weather)
                
            } else {
                Text("Loading weather data...")
                    .foregroundColor(.primary)
                    .padding()
            }
        }
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
// MARK: - Background View
struct BackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    let condition: String
    
    var body: some View {
        GeometryReader { geometry in
            Image(backgroundImage(for: condition))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay(
                    Color.black.opacity(colorScheme == .dark ? 0.5 : 0.3)
                        .edgesIgnoringSafeArea(.all)
                )
        }
        .ignoresSafeArea()
    }
    
    private func backgroundImage(for condition: String) -> String {
        switch condition.lowercased() {
        case "sunny":
            return "weather_background_sunny"
        case "rainy":
            return "weather_background_rainy"
        case "windy":
            return "weather_background_windy"
        case "snowy":
            return "weather_background_snowy"
        case "thunder":
            return "weather_background_thunder"
        default:
            return "weather_background_default"
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
