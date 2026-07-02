//  DetailedWeatherView.swift
//  SaxWeather
//
//  Created by GitHub Copilot on 2025-05-18
//

import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
import CoreLocation

struct DetailedWeatherView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var weatherService: WeatherService
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    @StateObject private var locationsManager = SavedLocationsManager()
    @State private var selectedMetric: WeatherMetricInfo?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // HERO SECTION — fades in when the underlying
                // weather data becomes available.
                heroSection
                    .padding(.horizontal, 16)
                    .transition(
                        .opacity.combined(with: .move(edge: .top))
                    )

                // GRID OF CARDS (2 columns).
                // Each card gets an asymmetric fade+scale
                // transition so the grid populates smoothly
                // instead of snapping in once data arrives.
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    WeatherCard(
                        title: "Feels Like",
                        value: weatherService.weather?.feelsLike.map { String(format: "%.0f%@", $0, unitSymbol) } ?? "—",
                        icon: "thermometer",
                        onTap: presentFeelsLikeMetric
                    )
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.92)),
                                removal: .opacity
                            )
                        )
                    WeatherCard(
                        title: "UV Index",
                        value: weatherService.weather?.uvIndex.map { String($0) } ?? "—",
                        icon: "sun.max",
                        onTap: { presentMetric(title: "UV Index", value: weatherService.weather?.uvIndex.map { String($0) } ?? "—") }
                    )
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.92)),
                                removal: .opacity
                            )
                        )
                    WeatherCard(
                        title: "Humidity",
                        value: weatherService.weather?.humidity.map { String(format: "%d%%", Int($0)) } ?? "—",
                        icon: "humidity",
                        onTap: { presentMetric(title: "Humidity", value: weatherService.weather?.humidity.map { String(format: "%d%%", Int($0)) } ?? "—") }
                    )
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.92)),
                                removal: .opacity
                            )
                        )
                    WeatherCard(
                        title: "Pressure",
                        value: weatherService.weather?.pressure.map {
                            String(format: "%@ %@", UnitConverter.formatPressure($0), pressureUnit)
                        } ?? "—",
                        icon: "gauge",
                        onTap: {
                            let pressureValue = weatherService.weather?.pressure.map {
                                String(format: "%@ %@", UnitConverter.formatPressure($0), pressureUnit)
                            } ?? "—"
                            presentMetric(title: "Pressure", value: pressureValue)
                        }
                    )
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.92)),
                                removal: .opacity
                            )
                        )
                }
                .padding(.horizontal, 16)
                .animation(
                    .easeInOut(duration: 0.4),
                    value: weatherService.weather?.feelsLike
                )
                .animation(
                    .easeInOut(duration: 0.4),
                    value: weatherService.weather?.uvIndex
                )
                .animation(
                    .easeInOut(duration: 0.4),
                    value: weatherService.weather?.humidity
                )
                .animation(
                    .easeInOut(duration: 0.4),
                    value: weatherService.weather?.pressure
                )

                // WIND CARD (full width).
                if let wind = weatherService.weather?.windSpeed, let gust = weatherService.weather?.windGust {
                    let direction = weatherService.weather?.currentWindDirection
                        ?? Double(weatherService.forecast?.daily.first?.windDirection ?? 0)
                    WindCard(
                        wind: wind,
                        gust: gust,
                        direction: direction,
                        unit: windUnit,
                        onTap: {
                            presentMetric(
                                title: "Wind Speed",
                                value: String(format: "%.0f %@", wind, windUnit)
                            )
                        }
                    )
                        .padding(.horizontal, 16)
                        .transition(
                            .opacity.combined(with: .move(edge: .bottom))
                        )
                }

                // SUNRISE/SUNSET & PRECIPITATION CARDS (side by side)
                HStack(spacing: 12) {
                    if let day = weatherService.forecast?.daily.first {
                        if let sunrise = day.sunrise, let sunset = day.sunset {
                            SunriseCard(sunrise: sunrise, sunset: sunset)
                                .transition(.opacity)
                        }
                        PrecipitationCard(amount: day.precipitation, unitSystem: unitSystem)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .animation(
                    .easeInOut(duration: 0.4),
                    value: weatherService.forecast?.daily.first?.sunrise
                )
                .animation(
                    .easeInOut(duration: 0.4),
                    value: weatherService.forecast?.daily.first?.precipitation
                )

                // HOURLY FORECAST GRAPH
                if !weatherService.hourlyData.isEmpty {
                    hourlyForecastSection
                        .padding(.horizontal, 16)
                        .transition(
                            .opacity.combined(with: .move(edge: .bottom))
                        )
                }

                // DAILY FORECAST
                if let forecast = weatherService.forecast?.daily {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("7-Day Forecast")
                            .font(.headline)
                            .padding(.leading, 4)
                            .transition(.opacity)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(forecast.prefix(7)) { day in
                                    ForecastPane(day: day, unitSystem: unitSystem)
                                        .transition(
                                            .asymmetric(
                                                insertion: .opacity
                                                    .combined(with: .scale(scale: 0.92)),
                                                removal: .opacity
                                            )
                                        )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .animation(
                            .easeInOut(duration: 0.4),
                            value: forecast.count
                        )
                    }
                    .transition(.opacity)
                    .animation(
                        .easeInOut(duration: 0.4),
                        value: forecast.count
                    )
                }
            }
            .padding(.vertical, 16)
            .animation(
                .easeInOut(duration: 0.4),
                value: weatherService.weather?.temperature
            )
            .animation(
                .easeInOut(duration: 0.4),
                value: weatherService.weather?.condition
            )
            .animation(
                .easeInOut(duration: 0.4),
                value: weatherService.hourlyData.count
            )
        }
        .sheet(item: $selectedMetric) { metric in
            WeatherMetricInfoContent(
                title: metric.title,
                value: metric.value,
                description: metric.description
            )
            #if os(iOS)
            .presentationDetents(
                metric.title == "Feels Like" ? [.medium, .large] : [.height(260)]
            )
            .presentationDragIndicator(.visible)
            #endif
        }
    }
    
    private func presentMetric(title: String, value: String) {
        selectedMetric = WeatherMetricInfo(
            title: title,
            value: value,
            description: WeatherMetricDescriptions.description(for: title, unitSystem: unitSystem)
        )
    }

    private func presentFeelsLikeMetric() {
        guard let weather = weatherService.weather,
              let feelsLike = weather.feelsLike else { return }

        selectedMetric = WeatherMetricInfo(
            title: "Feels Like",
            value: String(format: "%.0f%@", feelsLike, unitSymbol),
            description: WeatherMetricDescriptions.feelsLikeDescription(
                for: weather,
                unitSystem: unitSystem
            )
        )
    }
    
    private var unitSymbol: String {
        UnitSystem.from(rawValue: unitSystem).temperatureLabel
    }
    private var windUnit: String {
        UnitSystem.from(rawValue: unitSystem).speedLabel
    }
    private var pressureUnit: String {
        UnitSystem.from(rawValue: unitSystem).pressureLabel
    }
    // Display location name or coordinates
    private var locationDisplayName: String {
        if let selected = locationsManager.selectedLocation {
            if selected.isCurrentLocation {
                return "Current Location"
            } else {
                return selected.name
            }
        }
        // Fallback to coordinates
        if let lat = Double(UserDefaults.standard.string(forKey: "latitude") ?? ""),
           let lon = Double(UserDefaults.standard.string(forKey: "longitude") ?? "") {
            return String(format: "%.3f, %.3f", lat, lon)
        }
        return "Location"
    }
    
    // MARK: - Hero Section
    // Phase 3 — styling delegated to `.styledCard()`. The if/else
    // branches were collapsed because `.styledCard()` does its own
    // iOS-availability check internally. The dark/light text
    // colours are unchanged.
    private var heroSection: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                if let condition = weatherService.weather?.condition {
                    // Phase 6 — migrated to `ConditionIcon` so the
                    // iconography knobs in `IconographySpec` are
                    // honoured automatically.
                    ConditionIcon(condition: condition, size: 100)
                        .frame(width: 100, height: 100)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(locationDisplayName)
                        .font(.title2.bold())
                        .foregroundStyle(colorScheme == .dark ?
                            Color.white.opacity(0.9) :
                            Color.black.opacity(0.85)
                        )
                    Text(Date(), style: .date)
                        .font(.caption)
                        .foregroundStyle(colorScheme == .dark ?
                            Color.white.opacity(0.6) :
                            Color.black.opacity(0.5)
                        )
                    Text(weatherService.weather?.condition ?? "-")
                        .font(.headline)
                        .foregroundStyle(colorScheme == .dark ?
                            Color.white.opacity(0.7) :
                            Color.black.opacity(0.6)
                        )
                    if let temp = weatherService.weather?.temperature {
                        Text(String(format: "%.1f%@", temp, unitSymbol))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(colorScheme == .dark ?
                                Color.white.opacity(0.95) :
                                Color.black.opacity(0.9)
                            )
                    }
                    if let feels = weatherService.weather?.feelsLike {
                        Button(action: presentFeelsLikeMetric) {
                            Text("Feels like " + String(format: "%.0f%@", feels, unitSymbol))
                                .font(.caption)
                                .foregroundStyle(colorScheme == .dark ?
                                    Color.white.opacity(0.6) :
                                    Color.black.opacity(0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Shows how this value was calculated")
                    }
                }
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .styledCard()
    }
    
    // MARK: - Hourly Forecast Section
    // Phase 3 — styling delegated to `.styledCard()`.
    private var hourlyForecastSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hourly Forecast")
                .font(.headline)
                .padding(.leading, 4)
                .foregroundStyle(colorScheme == .dark ?
                    Color.white.opacity(0.9) :
                    Color.black.opacity(0.85)
                )
            WeatherGraphView(hourly: weatherService.hourlyData, unitSystem: unitSystem)
                .frame(height: 180)
                .styledCard()
        }
    }
}

// MARK: - WeatherCard
struct WeatherCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let icon: String
    var onTap: (() -> Void)? = nil

    // Phase 3 — styling (background / border / corner radius) is
    // delegated to `.styledCard()` which reads cardStyle, cornerRadius,
    // cardOpacity and the palette from the customisation registry.
    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    cardContent
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows an explanation of this measurement")
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.accentColor)
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(colorScheme == .dark ?
                        Color.white.opacity(0.7) :
                        Color.black.opacity(0.6)
                    )
            }
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(colorScheme == .dark ?
                    Color.white.opacity(0.9) :
                    Color.black.opacity(0.85)
                )
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .styledCard()
    }
}

// MARK: - WindCard
struct WindCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let wind: Double
    let gust: Double
    let direction: Double
    let unit: String
    var onTap: (() -> Void)? = nil

    // Phase 3 — styling delegated to `.styledCard()`. Reads
    // cardStyle, cornerRadius, cardOpacity and palette from the
    // customisation registry. The if/available branches are
    // removed because `.styledCard()` does its own availability
    // check internally.
    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    cardContent
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows an explanation of this measurement")
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "wind")
                    .font(.body)
                    .foregroundColor(.accentColor)
                Text("WIND")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(colorScheme == .dark ?
                        Color.white.opacity(0.7) :
                        Color.black.opacity(0.6)
                    )
            }

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Speed")
                            .font(.caption)
                            .foregroundStyle(colorScheme == .dark ?
                                Color.white.opacity(0.6) :
                                Color.black.opacity(0.5)
                            )
                        Text(String(format: "%.0f %@", wind, unit))
                            .font(.title2.bold())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gusts")
                            .font(.caption)
                            .foregroundStyle(colorScheme == .dark ?
                                Color.white.opacity(0.6) :
                                Color.black.opacity(0.5)
                            )
                        Text(String(format: "%.0f %@", gust, unit))
                            .font(.headline)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Direction")
                            .font(.caption)
                            .foregroundStyle(colorScheme == .dark ?
                                Color.white.opacity(0.6) :
                                Color.black.opacity(0.5)
                            )
                        Text("\(WindCompassView.cardinalAbbreviation(for: direction)) (\(String(format: "%.0f°", direction)))")
                            .font(.headline)
                    }
                }

                Spacer()

                WindCompassView(
                    direction: direction,
                    size: .regular,
                    showCardinalLabel: false
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .styledCard()
    }
}

// MARK: - SunriseCard
struct SunriseCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let sunrise: Date
    let sunset: Date
    
    var body: some View {
        if #available(iOS 26.2, *) {
            // iOS 26+ Glass Effect
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sunrise")
                        .font(.body)
                        .foregroundColor(.orange)
                    Text("SUNRISE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(colorScheme == .dark ?
                            Color.white.opacity(0.7) :
                            Color.black.opacity(0.6)
                        )
                }
                Text(timeString(sunrise))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ?
                        Color.white.opacity(0.9) :
                        Color.black.opacity(0.85)
                    )
                HStack(spacing: 4) {
                    Image(systemName: "sunset")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Sunset: " + timeString(sunset))
                        .font(.caption)
                        .foregroundStyle(colorScheme == .dark ?
                            Color.white.opacity(0.6) :
                            Color.black.opacity(0.5)
                        )
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)
                    
                    LinearGradient(
                        colors: colorScheme == .dark ? [
                            Color.black.opacity(0.2),
                            Color.black.opacity(0.1),
                            Color.clear
                        ] : [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: colorScheme == .dark ? [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1)
                            ] : [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        } else {
            // Fallback for iOS 25 and earlier
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sunrise")
                        .font(.body)
                        .foregroundColor(.orange)
                    Text("SUNRISE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                Text(timeString(sunrise))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                HStack(spacing: 4) {
                    Image(systemName: "sunset")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Sunset: " + timeString(sunset))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            #if canImport(UIKit)
            .background(Color(.systemBackground))
            #elseif canImport(AppKit)
            .background(Color(NSColor.windowBackgroundColor))
            #else
            .background(Color.white)
            #endif
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - PrecipitationCard
struct PrecipitationCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let amount: Double
    let unitSystem: String

    private var unit: UnitSystem {
        UnitSystem.from(rawValue: unitSystem)
    }

    private var formattedAmount: String {
        UnitConverter.formatPrecipitation(amount, unit: unit, precision: 0)
    }
    
    var body: some View {
        if #available(iOS 26.2, *) {
            // iOS 26+ Glass Effect
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .font(.body)
                        .foregroundColor(.blue)
                    Text("PRECIPITATION")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(colorScheme == .dark ?
                            Color.white.opacity(0.7) :
                            Color.black.opacity(0.6)
                        )
                }
                Text(formattedAmount)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ?
                        Color.white.opacity(0.9) :
                        Color.black.opacity(0.85)
                    )
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(colorScheme == .dark ?
                        Color.white.opacity(0.6) :
                        Color.black.opacity(0.5)
                    )
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)
                    
                    LinearGradient(
                        colors: colorScheme == .dark ? [
                            Color.black.opacity(0.2),
                            Color.black.opacity(0.1),
                            Color.clear
                        ] : [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: colorScheme == .dark ? [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1)
                            ] : [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        } else {
            // Fallback for iOS 25 and earlier
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .font(.body)
                        .foregroundColor(.blue)
                    Text("PRECIPITATION")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                Text(formattedAmount)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            #if canImport(UIKit)
            .background(Color(.systemBackground))
            #elseif canImport(AppKit)
            .background(Color(NSColor.windowBackgroundColor))
            #else
            .background(Color.white)
            #endif
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - WeatherGraphView
struct WeatherGraphView: View {
    let hourly: [HourlyWeatherData]
    let unitSystem: String
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                #if canImport(UIKit)
Color(.systemBackground)
#elseif canImport(AppKit)
Color(NSColor.windowBackgroundColor)
#else
Color.white
#endif
                Text("[Hourly Temperature Graph]")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - ForecastPane
struct ForecastPane: View {
    @Environment(\.colorScheme) private var colorScheme
    let day: WeatherForecast.DailyForecast
    let unitSystem: String
    
    var body: some View {
        if #available(iOS 26.2, *) {
            // iOS 26+ Glass Effect
            VStack(spacing: 6) {
                Text(day.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(colorScheme == .dark ?
                        Color.white.opacity(0.6) :
                        Color.black.opacity(0.5)
                    )
                Text(day.weatherSymbol)
                    .font(.title2)
                Text("\(UnitConverter.formatTemperature(day.tempMax))°")
                    .font(.headline)
                    .foregroundStyle(colorScheme == .dark ?
                        Color.white.opacity(0.9) :
                        Color.black.opacity(0.85)
                    )
                Text("\(UnitConverter.formatTemperature(day.tempMin))°")
                    .font(.caption)
                    .foregroundStyle(colorScheme == .dark ?
                        Color.white.opacity(0.6) :
                        Color.black.opacity(0.5)
                    )
            }
            .frame(width: 70, height: 100)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)
                    
                    LinearGradient(
                        colors: colorScheme == .dark ? [
                            Color.black.opacity(0.2),
                            Color.black.opacity(0.1),
                            Color.clear
                        ] : [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: colorScheme == .dark ? [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1)
                            ] : [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        } else {
            // Fallback for iOS 25 and earlier
            VStack(spacing: 6) {
                Text(day.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(day.weatherSymbol)
                    .font(.title2)
                Text("\(UnitConverter.formatTemperature(day.tempMax))°")
                    .font(.headline)
                Text("\(UnitConverter.formatTemperature(day.tempMin))°")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 70, height: 100)
            #if canImport(UIKit)
            .background(Color(.systemBackground))
            #elseif canImport(AppKit)
            .background(Color(NSColor.windowBackgroundColor))
            #else
            .background(Color.white)
            #endif
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Helpers
private func getSymbol(for condition: String) -> String {
    switch condition.lowercased() {
    case let c where c.contains("cloud"): return "cloud.fill"
    case let c where c.contains("rain"): return "cloud.rain.fill"
    case let c where c.contains("snow"): return "cloud.snow.fill"
    case let c where c.contains("sun"): return "sun.max.fill"
    case let c where c.contains("clear"): return "sun.max"
    case let c where c.contains("thunder"): return "cloud.bolt.rain.fill"
    default: return "cloud"
    }
}

// Phase 6 — `getAnimationName(for:)` removed; `ConditionIcon`
// resolves the animation name via `AnimationRegistry`.

// MARK: - Preview
#Preview {
    DetailedWeatherView(weatherService: WeatherService())
}
