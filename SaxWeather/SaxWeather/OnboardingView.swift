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
            description: "SaxWeather supports both Weather Underground and OpenWeatherMap. You can use either one or both services.",
            systemImage: "server.rack"
        ),
        OnboardingStep(
            title: "Weather Underground",
            description: "If you have a personal weather station, you can connect it using Weather Underground. You'll need your API key and Station ID.",
            systemImage: "thermometer.sun.fill"
        ),
        OnboardingStep(
            title: "OpenWeatherMap",
            description: "Get weather data for any location using OpenWeatherMap. You'll need an API key and can use GPS or manual coordinates.",
            systemImage: "location.fill"
        ),
        OnboardingStep(
            title: "Let's Get Started",
            description: "Open settings to configure your weather services and start receiving weather data.",
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
                        isFirstLaunch = false
                    }
                }
        }
    }
    
    private func validateSettings() -> Bool {
        let hasWUConfig = !UserDefaults.standard.string(forKey: "wuApiKey")!.isEmpty &&
                         !UserDefaults.standard.string(forKey: "stationID")!.isEmpty
        
        let hasOWMConfig = !UserDefaults.standard.string(forKey: "owmApiKey")!.isEmpty &&
                          (UserDefaults.standard.bool(forKey: "useGPS") ||
                           (!UserDefaults.standard.string(forKey: "latitude")!.isEmpty &&
                            !UserDefaults.standard.string(forKey: "longitude")!.isEmpty))
        
        return hasWUConfig || hasOWMConfig
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