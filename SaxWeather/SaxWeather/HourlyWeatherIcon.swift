//
//  HourlyWeatherIcon.swift
//  SaxWeather
//
//  Created by Saxon on 11/3/2025.
//

import SwiftUI
import Lottie

struct HourlyWeatherIcon: View {
    let weatherCode: Int
    @State private var loadingFailed = false
    
    var body: some View {
        if loadingFailed {
            // Fallback to system icon if Lottie animation fails
            Image(systemName: systemIconName(for: weatherCode))
                .font(.system(size: 30))
                .foregroundColor(.primary)
        } else {
            LottieView(name: lottieNameFromCode(weatherCode), loadingFailed: $loadingFailed)
                .aspectRatio(contentMode: .fit)
        }
    }
    
    private func lottieNameFromCode(_ code: Int) -> String {
        switch code {
        case 0:
            return "clear-day"
        case 1, 2:
            return "partly-cloudy"
        case 3:
            return "cloudy"
        case 45, 48:
            return "foggy"
        case 51, 53, 55, 56, 57:
            return "drizzle"
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return "rainy"
        case 71, 73, 75, 77, 85, 86:
            return "snowy"
        case 95, 96, 99:
            return "thunderstorm"
        default:
            return "partly-cloudy"
        }
    }
    
    private func systemIconName(for code: Int) -> String {
        switch code {
        case 0:
            return "sun.max.fill"
        case 1, 2:
            return "cloud.sun.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55, 56, 57:
            return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86:
            return "cloud.snow.fill" 
        case 95, 96, 99:
            return "cloud.bolt.fill"
        default:
            return "cloud.fill"
        }
    }
}
