import SwiftUI
import Foundation

struct ForecastView: View {
    let forecast: WeatherForecast
    let unitSystem: String
    @State private var selectedDay: WeatherForecast.DailyForecast?
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Forecast")
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
                            withAnimation(.spring()) {
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
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding()
    }
}

struct DailyForecastCard: View {
    let day: WeatherForecast.DailyForecast
    let unitSystem: String
    let isSelected: Bool
    
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
                .font(.title)
            
            VStack(alignment: .leading) {
                Text("\(Int(round(day.tempMax)))°")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Text("\(Int(round(day.tempMin)))°")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text("🌧️")
                Text("\(Int(round(day.precipitationProbability)))%")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .opacity(day.precipitationProbability > 0 ? 1 : 0)
            
            HStack {
                Text("💦")
                Text("\(Int(round(day.humidity)))%")
                    .font(.caption)
                    .foregroundColor(.cyan)
            }
        }
        .frame(width: 90, height: 180)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

struct DetailedForecastView: View {
    let day: WeatherForecast.DailyForecast
    let unitSystem: String
    
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
            Text(dateFormatter.string(from: day.date))
                .font(.title3)
                .fontWeight(.bold)
            
            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    DetailRow(icon: "🌡️", label: "High", value: "\(Int(round(day.tempMax)))°")
                    DetailRow(icon: "🌡️", label: "Low", value: "\(Int(round(day.tempMin)))°")
                    if let sunrise = day.sunrise {
                        DetailRow(icon: "🌅", label: "Sunrise", value: timeFormatter.string(from: sunrise))
                    }
                }
                
                VStack(alignment: .leading) {
                    DetailRow(icon: "💨", label: "Wind", value: "\(Int(round(day.windSpeed))) \(unitSystem == "Metric" ? "km/h" : "mph")")
                    DetailRow(icon: "🧭", label: "Direction", value: "\(Int(round(day.windDirection)))°")
                    if let sunset = day.sunset {
                        DetailRow(icon: "🌇", label: "Sunset", value: timeFormatter.string(from: sunset))
                    }
                }
                
                VStack(alignment: .leading) {
                    DetailRow(icon: "💦", label: "Humidity", value: "\(Int(round(day.humidity)))%")
                    DetailRow(icon: "🌡️", label: "Pressure", value: "\(Int(round(day.pressure))) hPa")
                    DetailRow(icon: "☀️", label: "UV Index", value: "\(Int(round(day.uvIndex)))")
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
        .padding(.top)
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(icon)
            VStack(alignment: .leading) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.subheadline)
            }
        }
    }
}

#if DEBUG
struct ForecastView_Previews: PreviewProvider {
    static var previews: some View {
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
    }
}
#endifzx
