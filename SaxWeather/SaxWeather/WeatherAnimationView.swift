//
//  WeatherAnimationView.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-03-08
//
//  Phase 6 — migrated from `LottieView(name:)` to `ConditionIcon`
//  so the iconography knobs in `IconographySpec` (playback speed,
//  loop mode, override map, icon style, symbol variant) are
//  honoured automatically. The previous 1-second "show fallback
//  while loading" delay is no longer needed — `ConditionIcon`
//  shows the SF Symbol fallback only when the Lottie JSON fails
//  to load, which is the more useful behaviour.
//

import SwiftUI

struct WeatherAnimationView: View {
    let weather: Weather?
    let forecast: WeatherForecast?

    var body: some View {
        // Phase 6 — single entry point for "give me the icon for
        // condition X at night Y". Picks between Lottie and SF
        // Symbol based on the active customisation profile.
        ConditionIcon(
            condition: weather?.condition ?? "Clear",
            isNight: determineIfNight(),
            size: 150
        )
        .frame(width: 150, height: 150)
    }

    private func determineIfNight() -> Bool {
        // Check if we have sunrise/sunset data in the forecast
        if let daily = forecast?.daily.first,
           let sunrise = daily.sunrise,
           let sunset = daily.sunset {
            let now = Date()
            return now < sunrise || now > sunset
        } else {
            // Fallback to time-based detection
            let hour = Calendar.current.component(.hour, from: Date())
            return hour < 6 || hour > 18
        }
    }
}
