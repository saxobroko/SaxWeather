//
//  ForecastContainer.swift
//  SaxWeather
//
//  Created by Saxon on 1/3/2025.
//


import SwiftUI

struct ForecastContainer: View {
    @ObservedObject var weatherService: WeatherService
    
    var body: some View {
        Group {
            if let forecast = weatherService.forecast {
                ForecastView(
                    forecast: forecast,
                    unitSystem: weatherService.unitSystem
                )
            } else {
                VStack {
                    ProgressView()
                    Text("Loading forecast data...")
                        .padding()
                    Button("Retry") {
                        Task {
                            await weatherService.fetchForecasts()
                        }
                    }
                    .padding()
                }
                .onAppear {
                    Task {
                        await weatherService.fetchForecasts()
                    }
                }
            }
        }
    }
}