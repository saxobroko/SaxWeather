//
//  NetworkQualityHint.swift
//  SaxWeather
//
//  Created on 16/06/2026
//
//  Inline hint shown in Settings that surfaces the current
//  network quality and explains what the app is doing about it.
//  Reactive — watches `NetworkMonitor.shared` so the hint
//  updates as the user toggles Low Data Mode or moves between
//  WiFi and cellular.
//

import SwiftUI

struct NetworkQualityHint: View {
    @ObservedObject private var monitor = NetworkMonitor.shared

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.30), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var iconName: String {
        switch monitor.quality {
        case .offline: return "wifi.slash"
        case .unmetered: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .expensive: return "personalhotspot"
        case .constrained: return "tortoise.fill"
        }
    }

    private var tint: Color {
        switch monitor.quality {
        case .offline: return .red
        case .unmetered: return .green
        case .cellular: return .blue
        case .expensive: return .orange
        case .constrained: return .orange
        }
    }

    private var title: String {
        switch monitor.quality {
        case .offline: return "You're offline"
        case .unmetered: return "Connected via WiFi"
        case .cellular: return "Connected via cellular"
        case .expensive: return "Personal hotspot detected"
        case .constrained: return "Low Data Mode is on"
        }
    }

    private var message: String {
        switch monitor.quality {
        case .offline:
            return "Weather updates will resume when you're back online."
        case .unmetered:
            return "Full forecast data is being fetched."
        case .cellular:
            return "Basic weather is fetched; extended data (AQI, pollen) is skipped to save data."
        case .expensive:
            return "Extended forecast data is skipped to keep data usage low."
        case .constrained:
            return "Extended forecast data is skipped and background refresh runs less often."
        }
    }
}

#Preview("WiFi") {
    NetworkQualityHint()
}

#Preview("Constrained") {
    NetworkQualityHint()
        .onAppear {
            // Preview-only: simulate Low Data Mode by
            // overriding the published property. Real
            // production code reads from NWPathMonitor.
        }
}
