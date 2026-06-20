//
//  WeatherConditionView.swift
//  SaxWeather
//
//  Created by Saxon on 8/3/2025.
//
//  Phase 6 — migrated from `LottieView(name:)` to `ConditionIcon`
//  so the iconography knobs in `IconographySpec` (playback speed,
//  loop mode, override map, icon style, symbol variant) are
//  honoured automatically.
//

import SwiftUI

struct WeatherConditionView: View {
    let condition: String

    var body: some View {
        // Phase 6 — single entry point for "give me the icon for
        // condition X". Picks between Lottie and SF Symbol based
        // on the active customisation profile.
        ConditionIcon(condition: condition, size: 150)
            .frame(height: 150)
    }
}