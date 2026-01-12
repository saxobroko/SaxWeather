//
//  OnboardingView.swift
//  SaxWeather
//
//  Redesigned: 2026-01-10
//  Simple, focused onboarding emphasizing Apple Weather as primary
//

import SwiftUI
import CoreLocation

struct OnboardingView: View {
    @Binding var isFirstLaunch: Bool
    @ObservedObject var weatherService: WeatherService
    @EnvironmentObject var storeManager: StoreManager
    @State private var currentStep = 0
    @State private var locationPermissionGranted = false
    
    private let steps = [
        OnboardingStep(
            title: "Welcome to\nSaxWeather",
            description: "",
            systemImage: "cloud.sun.fill",
            iconColor: Color.blue
        ),
        OnboardingStep(
            title: "Enable Location",
            description: "Get accurate weather for your current location",
            systemImage: "location.circle.fill",
            iconColor: Color.green
        ),
        OnboardingStep(
            title: "Optional: API Keys",
            description: "Add Weather Underground or OpenWeatherMap for additional data sources (not required)",
            systemImage: "key.fill",
            iconColor: Color.orange
        ),
        OnboardingStep(
            title: "You're All Set!",
            description: "Enjoy beautiful weather forecasts",
            systemImage: "checkmark.circle.fill",
            iconColor: Color.green
        )
    ]
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    steps[currentStep].iconColor.opacity(0.1),
                    Color.clear
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Icon
                Image(systemName: steps[currentStep].systemImage)
                    .font(.system(size: 80, weight: .thin))
                    .foregroundColor(steps[currentStep].iconColor)
                    .padding(.bottom, 20)
                    .transition(.scale.combined(with: .opacity))
                
                // Title
                Text(steps[currentStep].title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                
                // Description
                Text(steps[currentStep].description)
                    .font(.system(size: 17))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                
                // Action button for location step
                if currentStep == 1 {
                    Button(action: requestLocationPermission) {
                        HStack {
                            Image(systemName: locationPermissionGranted ? "checkmark.circle.fill" : "location.fill")
                            Text(locationPermissionGranted ? "Location Enabled" : "Enable Location")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 16)
                        .background(locationPermissionGranted ? Color.green : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(locationPermissionGranted)
                    .padding(.top, 10)
                }
                
                Spacer()
                
                // Progress indicators
                HStack(spacing: 10) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(currentStep == index ? steps[currentStep].iconColor : Color.gray.opacity(0.3))
                            .frame(width: currentStep == index ? 24 : 8, height: 8)
                            .animation(.spring(), value: currentStep)
                    }
                }
                .padding(.bottom, 20)
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button(action: {
                            withAnimation(.spring()) {
                                currentStep -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    
                    if currentStep < steps.count - 1 {
                        Button(action: {
                            withAnimation(.spring()) {
                                currentStep += 1
                            }
                        }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                    } else {
                        Button(action: {
                            withAnimation {
                                isFirstLaunch = false
                            }
                            // Start fetching weather immediately
                            Task {
                                await weatherService.fetchWeather(calledFrom: "OnboardingView.getStarted")
                            }
                        }) {
                            HStack {
                                Text("Get Started")
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
        .animation(.spring(), value: currentStep)
    }
    
    private func requestLocationPermission() {
        let status = weatherService.locationManager.authorizationStatus
        
        #if os(iOS)
        switch status {
        case .notDetermined:
            weatherService.locationManager.requestWhenInUseAuthorization()
            // Give a moment for the permission dialog to appear and be dismissed
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                checkLocationPermission()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            locationPermissionGranted = true
            weatherService.useGPS = true
        default:
            break
        }
        #elseif os(macOS)
        switch status {
        case .notDetermined:
            weatherService.locationManager.requestAlwaysAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                checkLocationPermission()
            }
        case .authorized:
            locationPermissionGranted = true
            weatherService.useGPS = true
        default:
            break
        }
        #endif
    }
    
    private func checkLocationPermission() {
        let status = weatherService.locationManager.authorizationStatus
        
        #if os(iOS)
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            withAnimation {
                locationPermissionGranted = true
                weatherService.useGPS = true
            }
        }
        #elseif os(macOS)
        if status == .authorized {
            withAnimation {
                locationPermissionGranted = true
                weatherService.useGPS = true
            }
        }
        #endif
    }
}

struct OnboardingStep {
    let title: String
    let description: String
    let systemImage: String
    let iconColor: Color
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isFirstLaunch: .constant(true), weatherService: WeatherService())
            .environmentObject(StoreManager.shared)
    }
}
