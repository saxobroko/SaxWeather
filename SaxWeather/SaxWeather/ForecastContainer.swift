//
//  ForecastContainer.swift
//  SaxWeather
//
//  Created by Saxon on 1/3/2025.
//

import SwiftUI

struct ForecastContainer: View {
    @ObservedObject var weatherService: WeatherService
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) { // Zero spacing for seamless integration
                    // Unified container for both sections with integrated styling
                    VStack(spacing: 16) {
                        // Hourly forecast section
                        if weatherService.forecast != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Today's Weather")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                HourlyForecastView(weatherService: weatherService)
                            }
                        }
                        
                        // Main forecast content
                        if let forecast = weatherService.forecast {
                            if forecast.daily.isEmpty {
                                emptyForecastView
                            } else {
                                // Pass weatherService to ForecastView
                                ForecastView(weatherService: weatherService)
                            }
                        } else if let error = weatherService.error {
                            errorView(message: error)
                        } else {
                            loadingView
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    // Apply a unified background to the entire container
                    .background(
                        colorScheme == .dark ?
                            Color.black.opacity(0.9) :
                            Color.blue.opacity(0.1)
                    )
                    .cornerRadius(0) // No rounded corners for seamless appearance
                }
            }
            .edgesIgnoringSafeArea(.bottom) // Extend to bottom edge
            .navigationTitle("Forecast")
            .onAppear {
                if weatherService.forecast == nil {
                    fetchForecast()
                }
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
                .padding()
            
            Button("Retry") {
                fetchForecast()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
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
        Task {
            await weatherService.fetchForecasts()
        }
    }
}
