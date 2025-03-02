//
//  BackgroundView.swift
//  SaxWeather
//
//  Created by Saxon on 2/3/2025.
//

import SwiftUI

struct BackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var storeManager: StoreManager
    @AppStorage("userCustomBackground") private var savedImageData: Data?
    @AppStorage("useCustomBackground") private var useCustomBackground = true
    
    let condition: String
    
    var body: some View {
        GeometryReader { geometry in
            // Check if custom background should be used
            if storeManager.customBackgroundUnlocked && useCustomBackground,
               let imageData = savedImageData,
               let customImage = UIImage(data: imageData) {
                // Show custom background
                Image(uiImage: customImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay(
                        Color.black.opacity(colorScheme == .dark ? 0.5 : 0.3)
                            .edgesIgnoringSafeArea(.all)
                    )
            } else {
                // Show default weather-based background
                Image(backgroundImage(for: condition))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay(
                        Color.black.opacity(colorScheme == .dark ? 0.5 : 0.3)
                            .edgesIgnoringSafeArea(.all)
                    )
            }
        }
        .ignoresSafeArea()
    }
    
    private func backgroundImage(for condition: String) -> String {
        switch condition.lowercased() {
        case "sunny":
            return "weather_background_sunny"
        case "rainy":
            return "weather_background_rainy"
        case "windy":
            return "weather_background_windy"
        case "snowy":
            return "weather_background_snowy"
        case "thunder":
            return "weather_background_thunder"
        default:
            return "weather_background_default"
        }
    }
}
