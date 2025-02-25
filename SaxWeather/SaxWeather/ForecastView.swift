import SwiftUI
import Foundation

struct ForecastView: View {
    let forecast: WeatherForecast
    let unitSystem: String
    @State private var selectedDay: WeatherForecast.DailyForecast?
    @Environment(\.colorScheme) var colorScheme
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(forecast.daily.count)-Day Forecast") // Dynamic forecast count
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(forecast.daily) { day in
                        DailyForecastCard(
                            day: day,
                            unitSystem: unitSystem,
                            isSelected: selectedDay?.id == day.id
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if selectedDay?.id == day.id {
                                    selectedDay = nil
                                } else {
                                    selectedDay = day
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            if let selected = selectedDay {
                DetailedForecastView(day: selected, unitSystem: unitSystem)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            }
        }
        .padding()
    }
}

struct DailyForecastCard: View {
    let day: WeatherForecast.DailyForecast
    let unitSystem: String
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dateFormatter.string(from: day.date))
                .font(.headline)
            
            Text(day.weatherSymbol)
                .font(.system(size: 28))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(round(day.tempMax)))°")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("\(Int(round(day.tempMin)))°")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer() // Add flexible space to push weather data to bottom
            
            VStack(spacing: 6) {
                // Always show humidity
                WeatherDataRow(
                    icon: "💧",
                    value: "\(Int(round(day.humidity)))%",
                    color: .cyan
                )
                
                // Always show precipitation row but with opacity
                WeatherDataRow(
                    icon: "🌧️",
                    value: "\(Int(round(day.precipitationProbability)))%",
                    color: .blue
                )
                .opacity(day.precipitationProbability > 0 ? 1 : 0)
            }
        }
        .frame(width: 90, height: 180)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.8))
                .shadow(radius: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 2)
        )
    }
}

struct DetailedForecastView: View {
    let day: WeatherForecast.DailyForecast
    let unitSystem: String
    @Environment(\.colorScheme) var colorScheme
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateFormatter.string(from: day.date))
                        .font(.headline)
                    
                    Text("\(Int(round(day.tempMax)))° / \(Int(round(day.tempMin)))°")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(day.weatherSymbol)
                    .font(.system(size: 32))
            }
            
            Divider()
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                DetailGridItem(icon: "💨", label: "Wind", value: "\(Int(round(day.windSpeed))) \(unitSystem == "Metric" ? "km/h" : "mph")")
                DetailGridItem(icon: "🧭", label: "Direction", value: "\(Int(round(day.windDirection)))°")
                DetailGridItem(icon: "💧", label: "Humidity", value: "\(Int(round(day.humidity)))%")
                DetailGridItem(icon: "🌧️", label: "Rain Chance", value: "\(Int(round(day.precipitationProbability)))%")
                DetailGridItem(icon: "🌡️", label: "Pressure", value: "\(Int(round(day.pressure))) hPa")
                DetailGridItem(icon: "☀️", label: "UV Index", value: "\(Int(round(day.uvIndex)))")
                
                if let sunrise = day.sunrise, let sunset = day.sunset {
                    DetailGridItem(icon: "🌅", label: "Sunrise", value: timeFormatter.string(from: sunrise))
                    DetailGridItem(icon: "🌇", label: "Sunset", value: timeFormatter.string(from: sunset))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.8))
                .shadow(radius: 5)
        )
        .padding(.top)
    }
}

struct WeatherDataRow: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(icon)
            Text(value)
                .font(.caption)
                .foregroundColor(color)
        }
    }
}

struct DetailGridItem: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 6) {
            Text(icon)
                .font(.title3)
            
            VStack(spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
struct ForecastView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ForecastView(
                forecast: WeatherForecast(
                    daily: [
                        WeatherForecast.DailyForecast(
                            date: Date(),
                            tempMax: 25,
                            tempMin: 15,
                            precipitation: 0.5,
                            precipitationProbability: 30,
                            weatherCode: 1,
                            windSpeed: 10,
                            windDirection: 180,
                            humidity: 65,
                            pressure: 1013,
                            uvIndex: 5,
                            sunrise: Date(),
                            sunset: Date()
                        )
                    ]
                ),
                unitSystem: "Metric"
            )
            .preferredColorScheme(.light)
            
            ForecastView(
                forecast: WeatherForecast(
                    daily: [
                        WeatherForecast.DailyForecast(
                            date: Date(),
                            tempMax: 25,
                            tempMin: 15,
                            precipitation: 0.5,
                            precipitationProbability: 30,
                            weatherCode: 1,
                            windSpeed: 10,
                            windDirection: 180,
                            humidity: 65,
                            pressure: 1013,
                            uvIndex: 5,
                            sunrise: Date(),
                            sunset: Date()
                        )
                    ]
                ),
                unitSystem: "Metric"
            )
            .preferredColorScheme(.dark)
        }
    }
}
#endif
