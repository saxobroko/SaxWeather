//
//  StaleDataWarning.swift
//  SaxWeather
//
//  Created on 16/06/2026
//
//  Small inline banner that surfaces when the cached weather
//  data is older than the freshness threshold. Designed to sit
//  at the top of the main weather view, below the location
//  label, and is hidden entirely when the data is fresh.
//

import SwiftUI

/// Banner that surfaces stale cached weather. Reads the
/// `WeatherService.lastSuccessfulFetch` published property so
/// the warning reactively appears / disappears as the user
/// pulls to refresh or background-refresh updates the data.
struct StaleDataWarning: View {
    @ObservedObject var weatherService: WeatherService
    /// How old the cached data must be (in seconds) for the
    /// warning to appear. 1 hour matches the host-app
    /// background-refresh cadence.
    var threshold: TimeInterval = 60 * 60

    var body: some View {
        if let lastFetch = weatherService.lastSuccessfulFetch,
           Date().timeIntervalSince(lastFetch) > threshold {
            HStack(spacing: 10) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 14, weight: .semibold))
                Text("Weather may be outdated — last updated \(staleText(from: lastFetch))")
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

    /// "12m ago" / "2h ago" / "Yesterday" — same style as the
    /// widget's relative time, kept short so the warning fits
    /// in a single line on small phones.
    private func staleText(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "yesterday"
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
