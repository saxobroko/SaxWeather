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
    @StateObject private var locationsManager = SavedLocationsManager()
    @State private var showSettings = false
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    @AppStorage("displayMode") private var displayMode: String = "Summary"
    @AppStorage("disableAPIKeys") private var disableAPIKeys = false
    @AppStorage("showHamburgerMenu") private var showHamburgerMenu: Bool = true
    @Environment(\.colorScheme) private var systemColorScheme
    @StateObject private var weatherAlertManager = WeatherAlertManager()
    @State private var activePopup: PopupData?
    @State private var showingLocationMenu = false
    @StateObject private var healthMonitor = APIKeyHealthMonitor.shared
    @State private var selectedTab: Int = 0
    
    // Computed property to check if we should show location text
    private var shouldShowLocationText: Bool {
        // Show location text when:
        // 1. API keys are disabled (using Apple Weather/Open-Meteo with custom locations), OR
        // 2. Using GPS or custom saved locations (not Weather Underground station)
        let wuApiKey = KeychainService.shared.getApiKey(forService: "wu") ?? ""
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        let hasWeatherUnderground = !wuApiKey.isEmpty && !stationID.isEmpty
        
        // Hide when using Weather Underground station (it's location-specific already)
        if hasWeatherUnderground && !disableAPIKeys {
            return false
        }
        
        // Show for GPS and custom locations
        return true
    }
    
    // Computed property for location display
    private var currentLocationText: String {
        // Priority 1: Use location name from weather data source (e.g., WU neighborhood)
        if let locationName = weatherService.weather?.locationName, !locationName.isEmpty {
            return locationName
        }
        
        // Priority 2: Check if using GPS
        if weatherService.useGPS {
            return "Current Location"
        }
        
        // Priority 3: Use saved location from locations manager
        if let selectedLocation = locationsManager.selectedLocation, !selectedLocation.isCurrentLocation {
            return selectedLocation.name
        }
        
        // Priority 4: Fallback to coordinates
        let lat = UserDefaults.standard.string(forKey: "latitude") ?? ""
        let lon = UserDefaults.standard.string(forKey: "longitude") ?? ""
        if !lat.isEmpty && !lon.isEmpty {
            return "\(formatCoordinate(lat)), \(formatCoordinate(lon))"
        }
        
        // Priority 5: Unknown
        return "Unknown Location"
    }
    
    private func formatCoordinate(_ value: String) -> String {
        guard let doubleValue = Double(value) else { return value }
        return String(format: "%.4f", doubleValue)
    }
    
    var body: some View {
        ZStack {
            Group {
                if isFirstLaunch {
                    OnboardingView(isFirstLaunch: $isFirstLaunch, weatherService: weatherService)
                        .preferredColorScheme(selectedColorScheme)
                        .environmentObject(storeManager)
                } else {
                    TabView(selection: $selectedTab) {
                        NavigationStack {
                            mainWeatherView
                        }
                        .tabItem {
                            Label("Weather", systemImage: "cloud.sun.fill")
                        }
                        .tag(0)

                        NavigationStack {
                            ForecastView(weatherService: weatherService)
                        }
                        .tabItem {
                            Label("Forecast", systemImage: "calendar")
                        }
                        .tag(1)

                        NavigationStack {
                            AlertsView(alertManager: weatherAlertManager, weatherService: weatherService)
                        }
                        .tabItem {
                            Label("Alerts", systemImage: "exclamationmark.triangle")
                        }
                        .tag(2)

                        NavigationStack {
                            SettingsView(weatherService: weatherService)
                        }
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(3)

                        #if DEBUG
                        NavigationStack {
                            LottieDebugView()
                        }
                        .tabItem {
                            Label("Debug", systemImage: "ladybug.fill")
                        }
                        .tag(4)
                        #endif
                    }
                    .preferredColorScheme(selectedColorScheme)
                    .onAppear {
                        // Sync LocationsManager with current GPS state
                        if weatherService.useGPS {
                            locationsManager.selectCurrentLocation()
                        }
                        
                        Task {
                            await weatherService.fetchWeather(calledFrom: "TabView.onAppear")
                        }
                    }
                }
            }
            .environment(\.popupState, $activePopup)
            // Listen for the onboarding "API Keys" link-out
            // button. The onboarding step flips `isFirstLaunch`
            // to `false` (so the main UI shows) and posts this
            // notification — we react by jumping straight to
            // the Settings tab.
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsToAPIKeys)) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = 3
                }
            }
            // Listen for the debug menu's "Re-run Onboarding"
            // button. Flipping `isFirstLaunch` back to `true`
            // re-presents the onboarding flow on the next
            // render pass.
            .onReceive(NotificationCenter.default.publisher(for: .debugRerunOnboarding)) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isFirstLaunch = true
                }
            }

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
        .accessibleAnimation(.easeInOut, value: isFirstLaunch)
        .accessibleAnimation(.easeInOut, value: activePopup != nil)
        // Top-of-screen offline banner. Watches
        // `NetworkMonitor.shared` and slides in from the top
        // when the device loses connectivity. The
        // `.safeAreaInset` modifier lets the banner participate
        // in layout (pushing the tab bar down) rather than
        // overlapping it.
        .safeAreaInset(edge: .top, spacing: 0) {
            OfflineBanner()
        }
        // Location-permission alert. `WeatherService.showLocationAlert`
        // is set whenever the user denies (or restricts) location
        // access, or when a `CLLocationManager` callback maps a
        // raw CLError to `.locationDenied` / `.locationRestricted`.
        // We bind a SwiftUI alert here with an "Open Settings"
        // action so the user has a one-tap path to fix the
        // permission.
        .alert(
            "Location Access Required",
            isPresented: $weatherService.showLocationAlert
        ) {
            Button("Open Settings") {
                AppSettingsRouter.open()
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("SaxWeather needs location access to show weather for where you are. You can also add a location manually in Settings.")
        }
    }
    
    // MARK: - Views
    
    private var mainWeatherView: some View {
        ZStack(alignment: .top) {
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

            // Banner shown at the top when at least one API key is
            // detected as invalid. Tap to jump to Settings → Weather Data.
            VStack {
                APIKeyHealthBanner(monitor: healthMonitor) {
                    selectedTab = 3
                }
                .animation(.easeInOut(duration: 0.25), value: healthMonitor.hasAnyBlockingIssue)
                Spacer()
            }

            // Floating hamburger menu button — overlaid on top of content so it
            // does not push the layout down (a "z-index" style overlay).
            if showHamburgerMenu {
                HStack {
                    Spacer()
                    Button {
                        #if canImport(UIKit)
                        HapticFeedbackHelper.shared.light()
                        #endif
                        showingLocationMenu = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                    }
                    .accessibilityLabel("Location Menu")
                    .accessibilityHint("Switch between saved locations")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .allowsHitTesting(true)
            }
        }
        // Removed duplicate .onAppear - already handled by TabView
        .sheet(isPresented: $showingLocationMenu) {
            HamburgerLocationMenuView(
                locationsManager: locationsManager,
                weatherService: weatherService,
                onDismiss: { showingLocationMenu = false }
            )
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
                }
            }
            .refreshable {
                // iOS provides built-in haptic feedback during pull-to-refresh
                // This is handled by the system and cannot be disabled
                await weatherService.fetchWeather(calledFrom: "PullToRefresh")
            }
            footerView
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private var weatherContent: some View {
        Group {
            if let weather = weatherService.weather, weather.hasData {
                VStack(spacing: 8) {
                    // Stale data warning — appears when the
                    // last successful fetch is older than the
                    // freshness threshold (default 1 hour).
                    // Hidden entirely when data is fresh.
                    StaleDataWarning(weatherService: weatherService)
                        .animation(.easeInOut(duration: 0.2), value: weatherService.lastSuccessfulFetch)

                    // Location label - only show when appropriate
                    if shouldShowLocationText {
                        Text("Weather for \(currentLocationText)")
                            .accessibleFont(size: 14, weight: .medium)
                            .accessibleContrast()
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .padding(.top, 20)
                    }
                    
                    #if os(macOS)
                    Spacer().frame(height: 48)
                    LottieView(name: getAnimationName(for: weather.condition))
                        .frame(width: 100, height: 100)
                        .frame(maxWidth: .infinity, alignment: .center)
                    #else
                    LottieView(name: getAnimationName(for: weather.condition))
                        .frame(width: 150, height: 150)
                        .padding(.top, 10)
                        .frame(maxWidth: .infinity, alignment: .center)
                    #endif
                    
                    let unitSymbol = unitSystem == "Metric" ? "°C" : "°F"
                    
                    // Current Temperature Display
                    if let temperature = weather.temperature {
                        #if os(macOS)
                        Text(String(format: "%.1f%@", temperature, unitSymbol))
                            .accessibleFont(size: 100, weight: .black, design: .rounded)
                            .accessibleContrast()
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
                            .shadow(color: Color.white.opacity(0.18), radius: 2, x: 0, y: 0)
                        #else
                        Text(String(format: "%.1f%@", temperature, unitSymbol))
                            .accessibleFont(size: 80, weight: .heavy)
                            .accessibleContrast()
                            .foregroundColor(.primary)
                            .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 2)
                        #endif
                    }
                    if let feelsLike = weather.feelsLike {
                        Text(String(format: "Feels like %.1f%@", feelsLike, unitSymbol))
                            .accessibleFont(size: 20, weight: .medium)
                            .accessibleContrast()
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        if let high = weather.high {
                            Text(String(format: "H: %.1f%@", high, unitSymbol))
                                .accessibleFont(size: 20, weight: .medium)
                                .accessibleContrast()
                                .foregroundColor(.primary)
                        }
                        if let low = weather.low {
                            Text(String(format: "L: %.1f%@", low, unitSymbol))
                                .accessibleFont(size: 20, weight: .medium)
                                .accessibleContrast()
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.vertical, 30)  // Reduced from 50 to accommodate the animation
                
                WeatherDetailsView(weather: weather)

                // Extended weather information
                ExtendedWeatherSection(weather: weather)
            } else if weatherService.isLoading {
                WeatherLoadingSkeleton()
            } else if let error = weatherService.error {
                ErrorView(weatherError: error) {
                    await weatherService.fetchWeather(calledFrom: "ErrorRetry")
                } onOpenSettings: {
                    AppSettingsRouter.open()
                }
            } else if !weatherService.hasValidDataSources() {
                VStack(spacing: 16) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Location Required")
                        .accessibleFont(size: 20, weight: .semibold)
                    
                    if !weatherService.useGPS {
                        Text("Please enable GPS or enter valid coordinates in Settings")
                            .accessibleFont(size: 15)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Open Settings") {
                            // Navigate to settings
                            showSettings = true
                        }
                        .accessibleFont(size: 16, weight: .medium)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    } else {
                        Text("Please enable location access in Settings")
                            .accessibleFont(size: 15)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Open Settings") {
                            weatherService.openSettings()
                        }
                        .accessibleFont(size: 16, weight: .medium)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
            } else {
                Text("Loading weather data...")
                    .accessibleFont(size: 16)
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
    
    private var footerView: some View {
        VStack(spacing: 4) {
            // Weather data attribution (required for legal compliance)
            WeatherAttributionView(
                dataSource: weatherService.currentDataSource,
                stationID: UserDefaults.standard.string(forKey: "stationID")
            )
            
            // App credit
            Text("Made by Saxon")
                .accessibleFont(size: 12)
                .foregroundColor(.primary)
                .padding(.bottom, 10)
        }
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
            ZStack {
                if let forecast = weatherService.forecast {
                    if forecast.daily.isEmpty {
                        emptyForecastView
                    } else {
                        ForecastView(weatherService: weatherService)
                    }
                } else if let error = weatherService.error {
                    errorView(weatherError: error)
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
            .accessibleFont(size: 16, weight: .medium)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
    
    private func errorView(weatherError: WeatherError) -> some View {
        let presentation = weatherError.presentation
        return VStack(spacing: 16) {
            Image(systemName: presentation.iconName)
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text(presentation.title)
                .font(.headline)

            Text(presentation.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                fetchForecast()
            }
            .accessibleFont(size: 16, weight: .medium)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)

            if !weatherService.useGPS {
                Button("Enable GPS Location") {
                    weatherService.useGPS = true
                    fetchForecast()
                }
                .accessibleFont(size: 16, weight: .medium)
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
        if #available(iOS 26.2, *) {
            // iOS 26+ Glass Aesthetic - Transparent with Subtle Dark Tint
            VStack(spacing: 12) {
                ForEach(weatherMetrics, id: \.title) { metric in
                    if let value = metric.value {
                        WeatherRowView(title: metric.title, value: value)
                    }
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background {
                ZStack {
                    // More transparent blur effect
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)  // Increased transparency
                    
                    // Subtle dark tint overlay
                    LinearGradient(
                        colors: colorScheme == .dark ? [
                            Color.black.opacity(0.2),      // Subtle dark tint
                            Color.black.opacity(0.1),      // Even lighter
                            Color.clear
                        ] : [
                            Color.white.opacity(0.15),     // Light mode stays neutral
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))  // Ensure proper rounding
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: colorScheme == .dark ? [
                                Color.white.opacity(0.2),      // Subtle white border
                                Color.white.opacity(0.1)
                            ] : [
                                Color.white.opacity(0.25),     // Light mode border
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 20)
        } else {
            // Fallback for iOS 25 and earlier
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
                    #if os(iOS)
                    .fill(Color(UIColor.systemBackground))
                    #elseif os(macOS)
                    .fill(Color(NSColor.windowBackgroundColor))
                    #endif
                    .shadow(radius: 5)
            )
            .padding(.horizontal)
        }
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

// MARK: - Extended Weather Section
struct ExtendedWeatherSection: View {
    let weather: Weather
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            // Debug: Print what extended data is available (only in debug builds to avoid log spam on every render)
            #if DEBUG
            let _ = print("🔍 ExtendedWeatherSection rendering:")
            let _ = print("   - UV Index: \(weather.uvIndex != nil ? "\(weather.uvIndex!)" : "nil")")
            let _ = print("   - Air Quality: \(weather.airQuality != nil ? "AQI \(weather.airQuality!.aqi)" : "nil")")
            let _ = print("   - Sun Data: \(weather.sunData != nil ? "Available" : "nil")")
            let _ = print("   - Hourly Precip: \(weather.hourlyPrecipitation.count) items")
            #endif

            // UV Index (enhanced with recommendations)
            if let uvIndex = weather.uvIndex {
                let uvData = UVIndexData(uvIndex: uvIndex)
                UVIndexCardView(data: uvData)
                    .padding(.horizontal, 20)
            } else {
                #if DEBUG
                let _ = print("❌ UV Index card NOT showing - uvIndex is nil")
                #endif
            }

            // Air Quality
            if let airQuality = weather.airQuality {
                AirQualityCardView(data: airQuality)
                    .padding(.horizontal, 20)
            } else {
                #if DEBUG
                let _ = print("❌ Air Quality card NOT showing - airQuality is nil")
                #endif
            }

            // Sun/Moon Data
            if let sunData = weather.sunData {
                SunMoonCardView(data: sunData)
                    .padding(.horizontal, 20)
            } else {
                #if DEBUG
                let _ = print("❌ Sun/Moon card NOT showing - sunData is nil")
                #endif
            }

            // Hourly Precipitation Graph
            if !weather.hourlyPrecipitation.isEmpty {
                PrecipitationGraphView(hourlyData: weather.hourlyPrecipitation)
                    .padding(.horizontal, 20)
            } else {
                #if DEBUG
                let _ = print("❌ Precipitation card NOT showing - hourlyPrecipitation is empty")
                #endif
            }

            // Pollen Data
            if let pollen = weather.pollen {
                PollenCardView(data: pollen)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Custom Popup View
struct CustomPopup<Content: View>: View {
    let content: Content
    @Binding var isPresented: Bool
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }
    
    var body: some View {
        if isPresented {
            ZStack {
                // Full screen transparent button to handle dismissal
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented = false
                    }
                
                content
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            #if os(iOS)
                            .fill(Color(UIColor.systemBackground))
                            #elseif os(macOS)
                            .fill(Color(NSColor.windowBackgroundColor))
                            #endif
                            .shadow(color: .black.opacity(0.2), radius: 8)
                    )
            }
            .transition(.opacity)
            .zIndex(999) // Ensure popup is always on top
        }
    }
}

// MARK: - Weather Row View
struct WeatherRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.popupState) private var popupState
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    let title: String
    let value: String
    
    var description: String {
        switch title {
            case "Humidity":
                return "Humidity is the amount of water vapor present in the air. High humidity can make it feel warmer than it actually is, while low humidity can make it feel cooler."
            case "Dew Point":
                let threshold = unitSystem == "Metric" ? "18°C" : "65°F"
                return "Dew point is the temperature at which water vapor in the air begins to condense. A higher dew point (above \(threshold)) means the air feels more humid and uncomfortable."
            case "Pressure":
                return "Atmospheric pressure affects weather conditions. Falling pressure often indicates approaching storms, while rising pressure typically means clearer weather."
            case "Wind Speed":
                return "Wind speed measures how fast the air is moving. Higher wind speeds can make it feel colder and may affect outdoor activities."
            case "Wind Gust":
                return "Wind gusts are sudden increases in wind speed. They're typically stronger than the average wind speed and can be particularly important for outdoor safety."
            case "UV Index":
                return "The UV Index measures the intensity of ultraviolet radiation from the sun. Higher values (6+) mean greater risk of sun damage and need for protection."
            case "Solar Radiation":
                return "Solar radiation measures the sun's energy reaching Earth's surface. It affects temperature and can impact solar panel efficiency."
            default:
                return "Weather measurement data"
        }
    }
    
    var body: some View {
        if #available(iOS 26.2, *) {
            // iOS 26+ style with subtle dark tint and glass effect
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? 
                            Color.white.opacity(0.6) : 
                            Color.black.opacity(0.5)
                        )
                        .frame(width: 24)
                    
                    Text(title)
                        .accessibleFont(size: 16, weight: .medium)
                        .accessibleContrast()
                        .foregroundStyle(colorScheme == .dark ?
                            Color.white.opacity(0.8) :
                            Color.black.opacity(0.7)
                        )
                }
                
                Spacer()
                
                Text(value)
                    .accessibleFont(size: 16, weight: .semibold)
                    .accessibleContrast()
                    .foregroundStyle(colorScheme == .dark ?
                        Color.white.opacity(0.9) :
                        Color.black.opacity(0.8)
                    )
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                popupState.wrappedValue = PopupData(
                    title: title,
                    value: value,
                    description: description
                )
            }
        } else {
            // Fallback for iOS 25 and earlier
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
            .contentShape(Rectangle())
            .onTapGesture {
                popupState.wrappedValue = PopupData(
                    title: title,
                    value: value,
                    description: description
                )
            }
        }
    }
    
    // Icon mapping for each weather metric
    private var iconName: String {
        switch title {
        case "Humidity": return "humidity.fill"
        case "Dew Point": return "drop.fill"
        case "Pressure": return "gauge.with.dots.needle.bottom.50percent"
        case "Wind Speed": return "wind"
        case "Wind Gust": return "wind.snow"
        case "UV Index": return "sun.max.fill"
        case "Solar Radiation": return "sun.and.horizon.fill"
        default: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Weather Metric Detail View
struct WeatherMetricDetailView: View {
    let title: String
    let value: String
    let description: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(value)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Text(description)
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
    }
}

// MARK: - Hamburger Location Menu

/// A sheet that lists the current GPS option and all saved locations, allowing
/// the user to quickly switch between them. Also offers a quick way to add a new
/// location via the existing map picker.
struct HamburgerLocationMenuView: View {
    @ObservedObject var locationsManager: SavedLocationsManager
    @ObservedObject var weatherService: WeatherService
    let onDismiss: () -> Void

    @AppStorage("disableAPIKeys") private var disableAPIKeys = false

    @State private var showingMapPicker = false
    @State private var mapSelectedLocation: CLLocationCoordinate2D? = nil
    @State private var mapSelectedLocationName: String? = nil
    @State private var showingAlert = false
    @State private var alertMessage = ""

    /// True when the user's Weather Underground configuration would override any
    /// saved/custom locations. In that case the menu is still shown but tapping a
    /// location shows an informational warning.
    private var wuApiKey: String {
        KeychainService.shared.getApiKey(forService: "wu") ?? ""
    }
    private var stationID: String {
        UserDefaults.standard.string(forKey: "stationID") ?? ""
    }
    private var isOverriddenByAPIKeys: Bool {
        !disableAPIKeys && (!wuApiKey.isEmpty || !stationID.isEmpty)
    }

    private var isGPSSelected: Bool {
        if locationsManager.selectedLocation?.isCurrentLocation == true {
            return true
        }
        return weatherService.useGPS
    }

    var body: some View {
        NavigationView {
            List {
                if isOverriddenByAPIKeys {
                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("API Keys Active")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Custom locations below are currently ignored because a Weather Underground station is configured. Disable API keys in Settings → Locations to use saved locations.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    // Current Location (GPS)
                    locationRow(
                        systemImage: "location.fill",
                        tint: .blue,
                        title: "Current Location (GPS)",
                        subtitle: "Use your device's GPS",
                        isSelected: isGPSSelected,
                        isDisabled: false
                    ) {
                        selectCurrentLocation()
                    }

                    if locationsManager.locations.isEmpty {
                        Text("No saved locations yet.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(locationsManager.locations) { location in
                            locationRow(
                                systemImage: "mappin.circle.fill",
                                tint: .accentColor,
                                title: location.name,
                                subtitle: String(
                                    format: "Lat: %.4f, Lon: %.4f",
                                    location.latitude,
                                    location.longitude
                                ),
                                isSelected: !weatherService.useGPS &&
                                    locationsManager.selectedLocation?.id == location.id,
                                isDisabled: false
                            ) {
                                selectLocation(location)
                            }
                        }
                    }
                } header: {
                    Text("Switch Location")
                } footer: {
                    Text("Tap a location to use it. Weather will refresh automatically.")
                }

                if !isOverriddenByAPIKeys {
                    Section {
                        Button {
                            showingMapPicker = true
                        } label: {
                            Label("Add New Location", systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingMapPicker) {
                LocationPickerView(
                    selectedLocation: $mapSelectedLocation,
                    selectedLocationName: $mapSelectedLocationName
                )
                .onDisappear {
                    handleMapSelectionResult()
                }
            }
            .alert("Location", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func locationRow(
        systemImage: String,
        tint: Color,
        title: String,
        subtitle: String,
        isSelected: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundColor(tint)
                    .font(.title3)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }

    // MARK: - Selection Handlers

    private func selectCurrentLocation() {
        #if canImport(UIKit)
        HapticFeedbackHelper.shared.light()
        #endif
        locationsManager.selectCurrentLocation()
        weatherService.useGPS = true
        Task {
            await weatherService.fetchWeather(calledFrom: "HamburgerLocationMenuView.selectGPS")
        }
        onDismiss()
    }

    private func selectLocation(_ location: SavedLocation) {
        #if canImport(UIKit)
        HapticFeedbackHelper.shared.light()
        #endif
        locationsManager.selectLocation(location)
        weatherService.useGPS = false
        Task {
            await weatherService.fetchWeather(calledFrom: "HamburgerLocationMenuView.selectLocation")
        }
        onDismiss()
    }

    private func handleMapSelectionResult() {
        guard let location = mapSelectedLocation else {
            // User cancelled; nothing to do.
            return
        }

        let lat = location.latitude
        let lon = location.longitude
        let validationResult = CoordinateValidator.validate(latitude: lat, longitude: lon)

        guard validationResult.isValid else {
            alertMessage = validationResult.errorMessage ?? "Invalid coordinates. Please try again."
            showingAlert = true
            mapSelectedLocation = nil
            mapSelectedLocationName = nil
            return
        }

        let validatedLat = validationResult.normalizedLatitude ?? lat
        let validatedLon = validationResult.normalizedLongitude ?? lon
        let locationName = mapSelectedLocationName ?? "Selected Location"

        if locationsManager.addLocation(name: locationName, latitude: validatedLat, longitude: validatedLon) {
            if let addedLocation = locationsManager.locations.last {
                locationsManager.selectLocation(addedLocation)
                weatherService.useGPS = false
                Task {
                    await weatherService.fetchWeather(calledFrom: "HamburgerLocationMenuView.addMapLocation")
                }
            }
            mapSelectedLocation = nil
            mapSelectedLocationName = nil
            onDismiss()
        } else {
            alertMessage = "Invalid coordinates. Please try again."
            showingAlert = true
            mapSelectedLocation = nil
            mapSelectedLocationName = nil
        }
    }
}

// MARK: - Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct HamburgerLocationMenuView_Previews: PreviewProvider {
    static var previews: some View {
        HamburgerLocationMenuView(
            locationsManager: SavedLocationsManager(),
            weatherService: WeatherService(),
            onDismiss: {}
        )
    }
}

