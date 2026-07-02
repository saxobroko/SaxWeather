//
//  DetailedForecastSheet.swift
//  SaxWeather
//
//  Created by Saxon on 11/3/2025.
//

import SwiftUI

private func backgroundFillColor(_ colorScheme: ColorScheme) -> Color {
    #if os(iOS)
    return Color(UIColor.systemGray6)
    #elseif os(macOS)
    return Color(NSColor.windowBackgroundColor)
    #endif
}

struct DetailedForecastSheet: View {
    let day: WeatherForecast.DailyForecast
    let unitSystem: String
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode

    // Shared asymmetric transition reused across the
    // detail grid so each card fades and scales in uniformly.
    private var cardTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.9)),
            removal: .opacity
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with date and dismiss button
                HStack {
                    Text(formattedDate(day.date))
                        .font(.title2.bold())
                    
                    Spacer()
                    
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Main weather info
                VStack(spacing: 16) {
                    // Lottie animation with temperature
                    HStack(spacing: 25) {
                        ConditionIcon(
                            weatherCode: day.weatherCode,
                            isNight: false,
                            size: 120
                        )
                        .frame(width: 120, height: 120)
                        
                        // Temperature
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(Int(round(day.tempMax)))°")
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            
                            Text("\(Int(round(day.tempMin)))°")
                                .font(.system(size: 32, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 10)
                    
                    // Weather description
                    Text(weatherDescription(day.weatherCode))
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .styledCard()
                .padding(.horizontal)
                
                // Detailed weather data
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    // Sunrise
                    WeatherDetailCard(
                        icon: "sunrise.fill",
                        label: "Sunrise",
                        value: day.sunrise != nil ? formattedTime(day.sunrise!) : "N/A",
                        color: .orange
                    )
                    .transition(cardTransition)
                    
                    // Sunset
                    WeatherDetailCard(
                        icon: "sunset.fill",
                        label: "Sunset",
                        value: day.sunset != nil ? formattedTime(day.sunset!) : "N/A",
                        color: .orange
                    )
                    .transition(cardTransition)
                    
                    // Humidity
                    WeatherDetailCard(
                        icon: "humidity.fill",
                        label: "Humidity",
                        value: "\(Int(round(day.humidity)))%",
                        color: .blue
                    )
                    .transition(cardTransition)
                    
                    // UV Index
                    WeatherDetailCard(
                        icon: "sun.max.fill",
                        label: "UV Index",
                        value: "\(Int(round(day.uvIndex)))",
                        color: .purple
                    )
                    .transition(cardTransition)
                    
                    // Wind Speed
                    WeatherDetailCard(
                        icon: "wind",
                        label: "Wind Speed",
                        value: "\(Int(round(day.windSpeed))) \(unitSystem == "Metric" ? "km/h" : "mph")",
                        color: .teal
                    )
                    .transition(cardTransition)
                    
                    // Precipitation
                    WeatherDetailCard(
                        icon: "drop.fill",
                        label: "Precipitation",
                        value: "\(Int(round(day.precipitationProbability)))%",
                        color: .blue
                    )
                    .transition(cardTransition)
                }
                .padding(.horizontal)
                // Stable identity drives the transition when the
                // sheet is re-presented for a different day.
                .animation(
                    .easeInOut(duration: 0.4),
                    value: day.date
                )

                Spacer(minLength: 20)
            }
        }
    }
    
    // Helper function to format date
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
    
    // Helper function to format time
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    // Weather description based on weather code
    private func weatherDescription(_ code: Int) -> String {
        switch code {
        case 0: return "Clear skies"
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

// Detailed Weather Card
struct WeatherDetailCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .styledCard()
    }
}

// MARK: - Detail Box
struct DetailBox: View {
    let icon: String
    let title: String
    let value: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 14) {
            Text(icon)
                .font(.system(size: 28))
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .styledCard()
    }
}

// MARK: - Sun Timing View
struct SunTimingView: View {
    let icon: String
    let title: String
    let time: String
    
    var body: some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.system(size: 28))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Text(time)
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// Preview provider
struct DetailedForecastSheet_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample day forecast for preview
        // Using the correct parameter order as specified in the error message
        let sampleDay = WeatherForecast.DailyForecast(
            id: UUID(),
            date: Date(),
            tempMax: 25.0,
            tempMin: 15.0,
            precipitation: 0.0,
            precipitationProbability: 10.0,
            weatherCode: 1,
            windSpeed: 12.0,
            windDirection: 180.0,
            humidity: 65.0,
            pressure: 1013.0,
            uvIndex: 4.0,
            sunrise: Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: Date()),
            sunset: Calendar.current.date(bySettingHour: 18, minute: 45, second: 0, of: Date())
        )
        
        DetailedForecastSheet(day: sampleDay, unitSystem: "Metric")
    }
}
