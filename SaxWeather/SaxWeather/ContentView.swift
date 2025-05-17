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
#if os(iOS)
import UIKit
#endif

// MARK: - Popup Environment
struct PopupData {
    let title: String
    let value: String
    let description: String
}

private struct PopupStateKey: EnvironmentKey {
    static let defaultValue: Binding<PopupData?> = .constant(nil)
}

extension EnvironmentValues {
    var popupState: Binding<PopupData?> {
        get { self[PopupStateKey.self] }
        set { self[PopupStateKey.self] = newValue }
    }
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var storeManager: StoreManager
    @StateObject private var weatherService = WeatherService()
    @State private var showSettings = false
    @State private var isRefreshing = false
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    @AppStorage("displayMode") private var displayMode: String = "Summary"
    @Environment(\.colorScheme) private var systemColorScheme
    @StateObject private var weatherAlertManager = WeatherAlertManager()
    @State private var activePopup: PopupData?
    
    var body: some View {
        ZStack {
            Group {
                if isFirstLaunch {
                    OnboardingView(isFirstLaunch: $isFirstLaunch, weatherService: weatherService)
                        .preferredColorScheme(selectedColorScheme)
                        .environmentObject(storeManager)
                } else {
                    TabView {
                        NavigationStack {
                            mainWeatherView
                        }
                        .tabItem {
                            Label("Weather", systemImage: "cloud.sun.fill")
                        }
                        
                        NavigationStack {
                            ForecastView(weatherService: weatherService)
                        }
                        .tabItem {
                            Label("Forecast", systemImage: "calendar")
                        }
                        
                        NavigationStack {
                            AlertsView(alertManager: weatherAlertManager, weatherService: weatherService)
                        }
                        .tabItem {
                            Label("Alerts", systemImage: "exclamationmark.triangle")
                        }
                        
                        NavigationStack {
                            SettingsView(weatherService: weatherService)
                        }
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        
                        #if os(iOS)
                        NavigationStack {
                            LottieDebugView()
                        }
                        .tabItem {
                            Label("Debug", systemImage: "ladybug.fill")
                        }
                        #endif
                    }
                    .preferredColorScheme(selectedColorScheme)
                    .onAppear {
                        Task {
                            await weatherService.fetchWeather()
                        }
                    }
                }
            }
            .environment(\.popupState, $activePopup)
            
            // Global popup
            if let popupData = activePopup {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        activePopup = nil
                    }
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(popupData.title)
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Text(popupData.value)
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    Text(popupData.description)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)
                }
                .padding()
                .frame(width: 280)
                #if os(iOS)
                .background(Color(UIColor.systemBackground))
                #elseif os(macOS)
                .background(Color(NSColor.windowBackgroundColor))
                #endif
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.2), radius: 8)
            }
        }
        .animation(.easeInOut, value: isFirstLaunch)
        .animation(.easeInOut, value: activePopup != nil)
    }
    
    private var mainWeatherView: some View {
        ZStack {
            backgroundLayer
            // Add a dark overlay for better contrast
            Color.black.opacity(0.28)
                .blur(radius: 8)
                .ignoresSafeArea()
            if displayMode == "Detailed" {
                DetailedWeatherView(weatherService: weatherService)
            } else {
                contentLayer
            }
        }
        .onAppear {
            Task {
                await weatherService.fetchWeather()
            }
        }
    }
    
    private var backgroundLayer: some View {
        // Use the wrapper which properly passes the environment object
        BackgroundViewWrapper(condition: weatherService.currentBackgroundCondition)
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
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private var weatherContent: some View {
        Group {
            if let weather = weatherService.weather, weather.hasData {
                VStack(spacing: 8) {
                    #if os(macOS)
                    Spacer().frame(height: 48)
                    LottieView(name: getAnimationName(for: weather.condition))
                        .frame(width: 100, height: 100)
                        .frame(maxWidth: .infinity, alignment: .center)
                    #else
                    LottieView(name: getAnimationName(for: weather.condition))
                        .frame(width: 150, height: 150)
                        .padding(.top, 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                    #endif
                    
                    let unitSymbol = unitSystem == "Metric" ? "°C" : "°F"
                    
                    // Current Temperature Display
                    if let temperature = weather.temperature {
                        #if os(macOS)
                        Text(String(format: "%.1f%@", temperature, unitSymbol))
                            .font(.system(size: 100, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
                            .shadow(color: Color.white.opacity(0.18), radius: 2, x: 0, y: 0)
                        #else
                        Text(String(format: "%.1f%@", temperature, unitSymbol))
                            .font(.system(size: 80, weight: .heavy))
                            .foregroundColor(.primary)
                            .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 2)
                        #endif
                    }
                    if let feelsLike = weather.feelsLike {
                        Text(String(format: "Feels like %.1f%@", feelsLike, unitSymbol))
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        if let high = weather.high {
                            Text(String(format: "H: %.1f%@", high, unitSymbol))
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        if let low = weather.low {
                            Text(String(format: "L: %.1f%@", low, unitSymbol))
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.vertical, 30)  // Reduced from 50 to accommodate the animation
                
            } else if weatherService.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
            } else if let error = weatherService.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Error Loading Weather")
                        .font(.headline)
                    
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        Task {
                            await weatherService.fetchWeather()
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            } else if !weatherService.hasValidDataSources() {
                VStack(spacing: 16) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Location Required")
                        .font(.headline)
                    
                    if !weatherService.useGPS {
                        Text("Please enable GPS or enter valid coordinates in Settings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Open Settings") {
                            // Navigate to settings
                            showSettings = true
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    } else {
                        Text("Please enable location access in Settings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Open Settings") {
                            weatherService.openSettings()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
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
            return "snowy"
        } else if lowercased.contains("thunder") || lowercased.contains("lightning") || lowercased.contains("storm") {
            return "thunderstorm"
        }
        return isNight ? "clear-night" : "clear-day"
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
        Text("Made by Saxon")
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
