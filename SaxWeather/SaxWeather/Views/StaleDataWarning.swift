//
//  StaleDataWarning.swift
//  SaxWeather
//
//  Created on 16/06/2026
//
//  Escalation banner when cached weather is older than the
//  freshness threshold. The hero's `HeroLastUpdatedButton`
//  already shows the relative time and handles one-tap refresh,
//  so this banner only adds a stronger warning — no duplicate
//  timestamp text.
//

import SwiftUI

struct StaleDataWarning: View {
    @ObservedObject var weatherService: WeatherService

    var body: some View {
        if let lastFetch = weatherService.lastSuccessfulFetch,
           WidgetStaleness.isStale(lastFetch) {
            HStack(spacing: 10) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 14, weight: .semibold))
                Text("Weather may be outdated — tap below to refresh")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.yellow.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.yellow.opacity(0.45), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

#Preview("Stale") {
    StaleDataWarning(weatherService: {
        let svc = WeatherService()
        svc.lastSuccessfulFetch = Date().addingTimeInterval(-7200)
        return svc
    }())
        .padding()
}
