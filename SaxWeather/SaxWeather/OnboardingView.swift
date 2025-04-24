//
//  OnboardingView.swift
//  SaxWeather
//
//  Created by Saxon on 16/2/2025.
//


//
//  OnboardingView.swift
//  SaxWeather
//
//  Created by Saxo_Broko on 2025-02-16 02:28:03
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isFirstLaunch: Bool
    @ObservedObject var weatherService: WeatherService
    @State private var currentStep = 0
    @State private var showSettings = false
    
    private let steps = [
        OnboardingStep(
            title: "Welcome to SaxWeather",
            description: "Your personal weather station companion.",
            systemImage: "cloud.sun.fill"
        ),
        OnboardingStep(
            title: "Choose Your Weather Service",
            description: "SaxWeather supports Weather Underground and OpenWeatherMap, with OpenMeteo as a fallback option when no API keys are provided.",
            systemImage: "server.rack"
        ),
        OnboardingStep(
            title: "Weather Underground",
            description: "If you have a personal weather station, you can optionally connect it using Weather Underground. You'll need your API key and Station ID.",
            systemImage: "thermometer.sun.fill"
        ),
        OnboardingStep(
            title: "OpenWeatherMap",
            description: "Get weather data using OpenWeatherMap (optional). You'll need an API key if you choose to use this service.",
            systemImage: "location.fill"
        ),
        OnboardingStep(
            title: "Location Services",
            description: "Enable GPS or set your location manually. This is required if you aren't using Weather Underground.",
            systemImage: "location.circle.fill"
        ),
        OnboardingStep(
            title: "Let's Get Started",
            description: "Open settings to configure your preferred weather services and location.",
            systemImage: "gear"
        )
    ]
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: steps[currentStep].systemImage)
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding()
                
                Text(steps[currentStep].title)
                    .font(.title)
                    .bold()
                    .multilineTextAlignment(.center)
                
                Text(steps[currentStep].description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Progress indicators
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(currentStep == index ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom)
                
                // Navigation buttons
                HStack(spacing: 20) {
                    if currentStep > 0 {
                        Button(action: {
                            withAnimation {
                                currentStep -= 1
                            }
                        }) {
                            Text("Previous")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if currentStep < steps.count - 1 {
                        Button(action: {
                            withAnimation {
                                currentStep += 1
                            }
                        }) {
                            Text("Next")
                                .bold()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(action: {
                            showSettings = true
                        }) {
                            Text("Open Settings")
                                .bold()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.bottom, 30)
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(weatherService: weatherService)
                .interactiveDismissDisabled()
                .onDisappear {
                    // Only dismiss the onboarding if settings are properly configured
                    if validateSettings() {
                        // Ensure we're on the main thread when updating the binding
                        DispatchQueue.main.async {
                            isFirstLaunch = false
                        }
                    }
                }
        }
    }
    
    private func validateSettings() -> Bool {
        let wuApiKey = UserDefaults.standard.string(forKey: "wuApiKey") ?? ""
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        let owmApiKey = UserDefaults.standard.string(forKey: "owmApiKey") ?? ""
        let latitude = UserDefaults.standard.string(forKey: "latitude") ?? ""
        let longitude = UserDefaults.standard.string(forKey: "longitude") ?? ""
        let useGPS = UserDefaults.standard.bool(forKey: "useGPS")
        
        let hasWUConfig = !wuApiKey.isEmpty && !stationID.isEmpty
        let hasOWMConfig = !owmApiKey.isEmpty
        
        // For location, we need to ensure either:
        // 1. GPS is enabled and authorized, or
        // 2. Valid manual coordinates are provided
        var hasValidLocation = false
        
        if useGPS {
            // Check if location services are authorized
            let status = weatherService.locationManager.authorizationStatus
            hasValidLocation = status == .authorizedWhenInUse || status == .authorizedAlways
        } else {
            // Check if manual coordinates are valid
            if let lat = Double(latitude), let lon = Double(longitude) {
                hasValidLocation = lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
            }
        }
        
        // Return true if either:
        // 1. We have proper WU config, or
        // 2. We have proper OWM config with valid location, or
        // 3. We have valid location (for OpenMeteo fallback)
        return hasWUConfig || (hasOWMConfig && hasValidLocation) || hasValidLocation
    }
}

struct OnboardingStep {
    let title: String
    let description: String
    let systemImage: String
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isFirstLaunch: .constant(true), weatherService: WeatherService())
    }
}
