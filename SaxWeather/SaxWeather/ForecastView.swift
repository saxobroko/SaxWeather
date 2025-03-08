import SwiftUI
import Foundation

struct ForecastView: View {
    let forecast: WeatherForecast
    let unitSystem: String
    @State private var selectedDay: WeatherForecast.DailyForecast?
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var storeManager: StoreManager
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // Background view that extends to edges
                Group {
                    if let firstDay = forecast.daily.first {
                        BackgroundView(condition: weatherConditionString(for: firstDay.weatherCode))
                    } else {
                        BackgroundView(condition: "default")
                    }
                }
                .edgesIgnoringSafeArea(.all)
                
                // Main content with reduced top padding
                ScrollView {
                    VStack(spacing: 24) {
                        // Header section with improved contrast
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Weather Forecast")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 2, x: 0, y: 1)
                            
                            Text("Next \(forecast.daily.count) days")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black, radius: 2, x: 0, y: 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        
                        // Daily forecast cards in a vertical stack
                        LazyVStack(spacing: 24) {
                            ForEach(forecast.daily) { day in
                                VStack(alignment: .leading, spacing: 8) {
                                    // Date header above the card with improved contrast
                                    Text(formattedDate(day.date))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .shadow(color: .black, radius: 2, x: 0, y: 1)
                                        .padding(.horizontal, 4)
                                    
                                    // The card itself
                                    ForecastDayCard(day: day, unitSystem: unitSystem)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedDay = day
                                        }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    // Use minimal top padding - just enough to clear status bar
                    .padding(.top, 16)
                    .padding(.bottom, 30)
                }
            }
            .sheet(item: $selectedDay) { day in
                DetailedForecastSheet(day: day, unitSystem: unitSystem)
            }
            .navigationBarHidden(true)
        }
    }
    
    // Helper function to format date
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
    
    // Helper function to convert weather code to condition string
    private func weatherConditionString(for code: Int) -> String {
        switch code {
        case 0, 1:
            return "sunny"
        case 61, 63, 65, 80, 81, 82:
            return "rainy"
        case 71, 73, 75, 77, 85, 86:
            return "snowy"
        case 95, 96, 99:
            return "thunder"
        default:
            return "default"
        }
    }
}

struct ForecastDayCard: View {
    let day: WeatherForecast.DailyForecast
    let unitSystem: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 20) {
            // Left: Weather icon and temperatures - Fixed icon container
            HStack(spacing: 12) {
                Text(day.weatherSymbol)
                    .font(.system(size: 32))  // Slightly smaller font
                    .frame(width: 44, height: 44)  // Fixed frame to prevent cutoff
                    .minimumScaleFactor(0.7)  // Allow scaling down if needed
                
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ?
                      Color(UIColor.systemGray6) :
                      Color.white)
                .shadow(radius: 3)
        )
    }
}

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

struct DetailedForecastSheet: View {
    let day: WeatherForecast.DailyForecast
    let unitSystem: String
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var storeManager: StoreManager
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Use BackgroundView in the detailed sheet too
                BackgroundView(condition: weatherConditionString(for: day.weatherCode))
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with weather overview
                        VStack(spacing: 16) {
                            Text(day.weatherSymbol)
                                .font(.system(size: 72))
                                .frame(height: 80)
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 2, x: 0, y: 1)
                            
                            VStack(spacing: 8) {
                                Text(dateFormatter.string(from: day.date))
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 2, x: 0, y: 1)
                                
                                HStack(alignment: .firstTextBaseline, spacing: 16) {
                                    Text("\(Int(round(day.tempMax)))°")
                                        .font(.system(size: 42, weight: .medium, design: .rounded))
                                        .monospacedDigit()
                                        .fixedSize(horizontal: true, vertical: false)
                                        .foregroundColor(.white)
                                        .shadow(color: .black, radius: 2, x: 0, y: 1)
                                    
                                    Text("/ \(Int(round(day.tempMin)))°")
                                        .font(.title2)
                                        .monospacedDigit()
                                        .fixedSize(horizontal: true, vertical: false)
                                        .foregroundColor(.white.opacity(0.8))
                                        .shadow(color: .black, radius: 2, x: 0, y: 1)
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        
                        // Description of weather conditions
                        Text(weatherDescription(for: day.weatherCode))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2, x: 0, y: 1)
                            .padding(.horizontal)
                        
                        Divider()
                            .background(Color.white.opacity(0.3))
                            .padding(.horizontal)
                        
                        // Weather details grid
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weather Details")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 2, x: 0, y: 1)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                DetailBox(icon: "💨", title: "Wind Speed", value: "\(Int(round(day.windSpeed))) \(unitSystem == "Metric" ? "km/h" : "mph")")
                                DetailBox(icon: "🧭", title: "Wind Direction", value: "\(compassDirection(from: day.windDirection))")
                                DetailBox(icon: "💧", title: "Humidity", value: "\(Int(round(day.humidity)))%")
                                DetailBox(icon: "🌧️", title: "Rain Probability", value: "\(Int(round(day.precipitationProbability)))%")
                                DetailBox(icon: "🌡️", title: "Pressure", value: "\(Int(round(day.pressure))) \(unitSystem == "Metric" ? "hPa" : "inHg")")
                                DetailBox(icon: "☀️", title: "UV Index", value: uvIndexDescription(value: Int(round(day.uvIndex))))
                            }
                            .padding(.horizontal)
                        }
                        
                        if let sunrise = day.sunrise, let sunset = day.sunset {
                            Divider()
                                .background(Color.white.opacity(0.3))
                                .padding(.horizontal)
                            
                            // Sun schedule
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Sun Schedule")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 2, x: 0, y: 1)
                                    .padding(.horizontal)
                                
                                HStack(spacing: 20) {
                                    SunTimingView(icon: "🌅", title: "Sunrise", time: timeFormatter.string(from: sunrise))
                                    
                                    Divider()
                                        .frame(height: 40)
                                    
                                    SunTimingView(icon: "🌇", title: "Sunset", time: timeFormatter.string(from: sunset))
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(colorScheme == .dark ?
                                              Color(UIColor.systemGray6) :
                                              Color.white)
                                        .shadow(radius: 5)
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitle("Weather Details", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            })
        }
    }
    
    // Helper functions for weather descriptions
    private func weatherDescription(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1, 2, 3: return "Partly cloudy"
        case 45, 48: return "Foggy conditions"
        case 51, 53, 55: return "Light drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rainfall"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snow fall"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Weather conditions"
        }
    }
    
    // Helper function to convert weather code to condition string for BackgroundView
    private func weatherConditionString(for code: Int) -> String {
        switch code {
        case 0, 1:
            return "sunny"
        case 61, 63, 65, 80, 81, 82:
            return "rainy"
        case 71, 73, 75, 77, 85, 86:
            return "snowy"
        case 95, 96, 99:
            return "thunder"
        default:
            return "default"
        }
    }
    
    private func compassDirection(from degrees: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((degrees + 22.5).truncatingRemainder(dividingBy: 360) / 45.0)
        return directions[index % 8]  // Ensure index is in bounds
    }
    
    private func uvIndexDescription(value: Int) -> String {
        switch value {
        case 0...2: return "\(value) - Low"
        case 3...5: return "\(value) - Moderate"
        case 6...7: return "\(value) - High"
        case 8...10: return "\(value) - Very High"
        default: return "\(value) - Extreme"
        }
    }
}
