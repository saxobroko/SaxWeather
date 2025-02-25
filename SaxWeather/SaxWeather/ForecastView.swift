//
//  ForecastView.swift
//  SaxWeather
//
//  Created by Saxon on 25/2/2025.
//


//
//  ForecastView.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-25 04:00:05
//

import SwiftUI

struct ForecastView: View {
    let forecast: WeatherForecast
    let unitSystem: String
    
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
                        DailyForecastCard(day: day, unitSystem: unitSystem)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
    }
}

struct DailyForecastCard: View {
    let day: WeatherForecast.DailyForecast
    let unitSystem: String
    
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
            
            if day.precipitationProbability > 0 {
                HStack {
                    Text("💧")
                    Text("\(Int(round(day.precipitationProbability)))%")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(width: 80)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

#Preview {
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
