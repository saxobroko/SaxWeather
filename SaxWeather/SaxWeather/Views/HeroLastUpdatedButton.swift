//
//  HeroLastUpdatedButton.swift
//  SaxWeather
//
//  Tappable "Last updated X ago" label in the main hero.
//  Subtle when data is fresh; more prominent when stale.
//  One tap triggers the same fetch path as pull-to-refresh.
//

import SwiftUI

struct HeroLastUpdatedButton: View {
    @ObservedObject var weatherService: WeatherService
    @State private var lastTapTime: Date?

    /// Fixed slot height so stale/fresh/loading states never push hero content below.
    private static let reservedHeight: CGFloat = 34
    private static let freshTapDebounce: TimeInterval = 10
    private static let staleTapDebounce: TimeInterval = 30

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let now = timeline.date
            let lastFetch = weatherService.lastSuccessfulFetch
            let isStale = lastFetch.map { WidgetStaleness.isStale($0, now: now) } ?? false
            let relative = lastFetch.map { WidgetStaleness.relativeUpdateString(from: $0, now: now) } ?? ""
            let isTapDebounced = isWithinTapDebounce(isStale: isStale)
            let showContent = lastFetch != nil

            ZStack {
                if showContent {
                    Button {
                        refreshWeather(isStale: isStale)
                    } label: {
                        labelContent(relative: relative, isStale: isStale, isTapDebounced: isTapDebounced)
                    }
                    .buttonStyle(.plain)
                    .disabled(weatherService.isLoading || isTapDebounced)
                    .opacity(weatherService.isLoading || isTapDebounced ? 0.55 : 1)
                    .accessibilityLabel(accessibilityLabel(relative: relative, isStale: isStale, isTapDebounced: isTapDebounced))
                    .accessibilityHint(accessibilityHint(isTapDebounced: isTapDebounced))
                }
            }
            .frame(height: Self.reservedHeight)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(!showContent)
        }
    }

    @ViewBuilder
    private func labelContent(relative: String, isStale: Bool, isTapDebounced: Bool) -> some View {
        HStack(spacing: 6) {
            if weatherService.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if isStale {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }

            Text(labelText(relative: relative, isStale: isStale, isTapDebounced: isTapDebounced))
                .font(.system(size: 13, weight: isStale ? .medium : .regular))
                .lineLimit(1)
        }
        .foregroundStyle(foregroundColor(isStale: isStale))
        .padding(.horizontal, isStale ? 12 : 0)
        .padding(.vertical, 6)
        .background {
            if isStale {
                Capsule(style: .continuous)
                    .fill(Color.yellow.opacity(0.18))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                    )
            }
        }
    }

    private func labelText(relative: String, isStale: Bool, isTapDebounced: Bool) -> String {
        if weatherService.isLoading {
            return "Updating…"
        }
        if isTapDebounced {
            return "Refresh already requested"
        }
        if isStale {
            return "Last updated \(relative) · Tap to refresh"
        }
        return "Updated \(relative)"
    }

    private func foregroundColor(isStale: Bool) -> Color {
        if isStale {
            return .primary
        }
        return .secondary.opacity(0.85)
    }

    private func accessibilityLabel(relative: String, isStale: Bool, isTapDebounced: Bool) -> String {
        if weatherService.isLoading {
            return "Updating weather"
        }
        if isTapDebounced {
            return "Refresh already requested"
        }
        if isStale {
            return "Last updated \(relative). Weather may be outdated. Tap to refresh."
        }
        return "Last updated \(relative)"
    }

    private func accessibilityHint(isTapDebounced: Bool) -> String {
        if isTapDebounced {
            return "A refresh is already in progress or was recently requested"
        }
        return "Refreshes weather data"
    }

    private func isWithinTapDebounce(isStale: Bool) -> Bool {
        guard let lastTapTime else { return false }
        let window = isStale ? Self.staleTapDebounce : Self.freshTapDebounce
        return Date().timeIntervalSince(lastTapTime) < window
    }

    private func refreshWeather(isStale: Bool) {
        guard !weatherService.isLoading else { return }

        let debounceWindow = isStale ? Self.staleTapDebounce : Self.freshTapDebounce
        if let lastTap = lastTapTime, Date().timeIntervalSince(lastTap) < debounceWindow {
            #if canImport(UIKit)
            HapticFeedbackHelper.shared.light()
            #endif
            return
        }

        if let lastFetch = weatherService.lastFetchTime,
           Date().timeIntervalSince(lastFetch) < 2.0 {
            #if canImport(UIKit)
            HapticFeedbackHelper.shared.light()
            #endif
            return
        }

        lastTapTime = Date()

        Task {
            let errorBefore = weatherService.error
            await weatherService.fetchWeather(calledFrom: "HeroLastUpdatedTap")
            SettingsBehaviour.triggerRefreshFeedback(
                success: weatherService.error == nil && errorBefore == nil
            )
        }
    }
}

#Preview("Fresh") {
    HeroLastUpdatedButton(weatherService: {
        let svc = WeatherService()
        svc.lastSuccessfulFetch = Date().addingTimeInterval(-300)
        return svc
    }())
}

#Preview("Stale") {
    HeroLastUpdatedButton(weatherService: {
        let svc = WeatherService()
        svc.lastSuccessfulFetch = Date().addingTimeInterval(-7200)
        return svc
    }())
}
