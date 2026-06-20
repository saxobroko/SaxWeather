//
//  HourlyWeatherIcon.swift
//  SaxWeather
//
//  Created by Saxon on 11/3/2025.
//
//  Phase 6 — migrated from `LottieView(name:)` to `ConditionIcon`
//  so the iconography knobs in `IconographySpec` (playback speed,
//  loop mode, override map, icon style, symbol variant) are
//  honoured automatically.
//

import SwiftUI

struct HourlyWeatherIcon: View {
    let weatherCode: Int

    var body: some View {
        // Phase 6 — single entry point for "give me the icon for
        // WMO code Y". Picks between Lottie and SF Symbol based
        // on the active customisation profile.
        ConditionIcon(weatherCode: weatherCode, size: 30)
            .aspectRatio(contentMode: .fit)
    }
}
