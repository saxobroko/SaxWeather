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
import CoreLocation

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
            #if os(iOS)
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            #elseif os(macOS)
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            #endif
            
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
                        #if os(macOS)
                        .buttonStyle(.bordered)
                        #endif
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
                        #if os(macOS)
                        Button(action: {
                            // Skip onboarding on macOS
                            isFirstLaunch = false
                        }) {
                            Text("Skip")
                        }
                        .buttonStyle(.bordered)
                        #endif
                    }
                }
                .padding(.bottom, 30)
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(weatherService: weatherService, isOnboarding: true)
                .environmentObject(StoreManager.shared)
                .interactiveDismissDisabled(false)
                .onDisappear {
                    // On macOS, always allow onboarding to complete after settings
                    #if os(macOS)
                    isFirstLaunch = false
                    #else
                    if validateSettings() {
                        DispatchQueue.main.async {
                            isFirstLaunch = false
                        }
                    }
                    #endif
                }
        }
    }
    
    private func validateSettings() -> Bool {
        #if os(macOS)
        // TODO: Implement proper validation for macOS. For now, always allow onboarding to complete.
        return true
        #else
        let wuApiKey = UserDefaults.standard.string(forKey: "wuApiKey") ?? ""
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        let owmApiKey = UserDefaults.standard.string(forKey: "owmApiKey") ?? ""
        let latitude = UserDefaults.standard.string(forKey: "latitude") ?? ""
        let longitude = UserDefaults.standard.string(forKey: "longitude") ?? ""
        let useGPS = UserDefaults.standard.bool(forKey: "useGPS")
        let hasWUConfig = !wuApiKey.isEmpty && !stationID.isEmpty
        let hasOWMConfig = !owmApiKey.isEmpty
        var hasValidLocation = false
        if useGPS {
            let status = weatherService.locationManager.authorizationStatus
            hasValidLocation = hasValidLocationStatus(status)
        } else {
            if let lat = Double(latitude), let lon = Double(longitude) {
                hasValidLocation = lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
            }
        }
        return hasWUConfig || (hasOWMConfig && hasValidLocation) || hasValidLocation
        #endif
    }
    
    private func hasValidLocationStatus(_ status: CLAuthorizationStatus) -> Bool {
        #if os(iOS)
        return status == .authorizedWhenInUse || status == .authorizedAlways
        #else
        // macOS fallback: treat authorized as valid
        return status == .authorized
        #endif
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
