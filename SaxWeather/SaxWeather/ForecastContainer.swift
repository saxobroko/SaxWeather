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
                        // Hourly forecast section.
                        // Fades in once the forecast is available
                        // so the page doesn't render an empty slot.
                        if weatherService.forecast != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Today's Weather")
                                    .font(.headline)
                                    .fontWeight(.bold)

                                HourlyForecastView(weatherService: weatherService)
                            }
                            .transition(
                                .opacity.combined(with: .move(edge: .top))
                            )
                        }
                        
                        // Main forecast content.
                        // Each branch (loading / error / empty /
                        // populated) crossfades so the container
                        // never snaps abruptly between states.
                        if let forecast = weatherService.forecast {
                            if forecast.daily.isEmpty {
                                emptyForecastView
                                    .transition(.opacity)
                            } else {
                                // Pass weatherService to ForecastView
                                ForecastView(weatherService: weatherService)
                                    .transition(.opacity)
                            }
                        } else if let error = weatherService.error {
                            errorView(weatherError: error)
                                .transition(.opacity)
                        } else {
                            loadingView
                                .transition(.opacity)
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
                    .animation(
                        .easeInOut(duration: 0.4),
                        value: weatherService.forecast?.daily.count
                    )
                    .animation(
                        .easeInOut(duration: 0.4),
                        value: weatherService.error?.localizedDescription
                    )
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
