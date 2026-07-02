//
//  AlertsView.swift
//  SaxWeather
//
//  Created by Saxon on 10/3/2025.
//

import SwiftUI

private var secondarySystemBackgroundColor: Color {
    #if os(iOS)
    return Color(UIColor.secondarySystemBackground)
    #elseif os(macOS)
    return Color(NSColor.windowBackgroundColor)
    #endif
}

struct AlertsView: View {
    @EnvironmentObject var alertManager: WeatherAlertManager
    @ObservedObject var weatherService: WeatherService
    @State private var isRefreshing = false
    @ObservedObject private var registry = CustomisationRegistry.shared
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var chartPaletteStore: ChartPaletteStore

    private var alertsBackgroundStrategy: BackgroundStrategy {
        BackgroundResolver.resolve(
            condition: weatherService.currentBackgroundCondition,
            spec: registry.profile.knobs.background,
            sunrise: weatherService.forecast?.daily.first?.sunrise,
            sunset: weatherService.forecast?.daily.first?.sunset,
            now: Date(),
            customBackgroundUnlocked: storeManager.customBackgroundUnlocked,
            isCosmeticUnlocked: storeManager.owns
        )
    }

    private var alertsOverlayOpacity: Double {
        BackgroundResolver.effectiveOverlayOpacity(
            spec: registry.profile.knobs.background,
            customBackgroundUnlocked: storeManager.customBackgroundUnlocked
        )
    }

    var body: some View {
        ZStack {
            BackgroundView(strategy: alertsBackgroundStrategy)
                .ignoresSafeArea()
            // Add a dark overlay for better contrast.
            Color.black.opacity(alertsOverlayOpacity)
                .blur(radius: 8)
                .ignoresSafeArea()
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 8)

            // --- Foreground content ---
            ScrollView {
                VStack(spacing: 20) {
                    // Precipitation Timeline Section.
                    // Fades in from the bottom when the timeline
                    // data becomes available.
                    if let timeline = alertManager.precipitationTimeline {
                        precipitationSection(timeline)
                            .transition(
                                .opacity.combined(with: .move(edge: .bottom))
                            )
                    }

                    // Weather Alerts Section
                    alertsSection

                    // Notifications Permission Section
                    if alertManager.authorizationStatus != .authorized {
                        notificationPermissionView
                            .transition(.opacity)
                    }

                    // Weather alert attribution (required for legal compliance)
                    Group {
                        if alertManager.precipitationTimeline != nil {
                            WeatherAttributionView(
                                dataSource: alertManager.precipitationDataSource,
                                stationID: nil,
                                usePrecipitationSource: true
                            )
                        }
                        if alertManager.alertDataSource != "none" {
                            WeatherAttributionView(
                                dataSource: alertManager.alertDataSource,
                                stationID: nil,
                                useAlertSource: true
                            )
                        }
                    }
                    .padding(.top, 16)
                    .transition(.opacity)
                }
                .padding()
                .animation(
                    .easeInOut(duration: 0.4),
                    value: alertManager.precipitationTimeline?.timePoints.count
                )
                .animation(
                    .easeInOut(duration: 0.4),
                    value: alertManager.alerts.count
                )
                .animation(
                    .easeInOut(duration: 0.4),
                    value: alertManager.authorizationStatus
                )
            }
            .refreshable {
                await refreshData()
            }
        }
        .onAppear {
            Task {
                await refreshData()
            }
        }
    }

    // MARK: - Precipitation Timeline Section

    private func precipitationSection(_ timeline: PrecipitationTimeline) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Precipitation Forecast")
                .font(.headline)

            // Rain start/stop info and outlook
            Group {
                if timeline.isRainingNow {
                    HStack {
                        Image(systemName: "umbrella.fill")
                            .foregroundColor(.blue)
                        if let minutes = timeline.minutesUntilRainStops {
                            Text("It is currently raining. Rain expected to stop in \(formattedTimeInterval(minutes: minutes)).")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        } else {
                            Text("It is currently raining. No stop time in the next 2 hours.")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    // Extended outlook after rain stops, if known
                    if let endTime = timeline.rainEndTime {
                        // Find if there's another rainStartTime after endTime (within 2 hours)
                        if let moreRain = timeline.timePoints.first(where: {
                            $0.time > endTime && $0.isRaining && $0.time.timeIntervalSinceNow <= 120*60
                        }) {
                            let minutes = Int(moreRain.time.timeIntervalSinceNow / 60)
                            Text("More rain expected again in \(formattedTimeInterval(minutes: minutes)).")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else if endTime.timeIntervalSinceNow <= 120*60 {
                            Text("No rain expected for at least 2 hours after rain stops.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else if let minutes = timeline.minutesUntilRainStarts {
                    HStack {
                        Image(systemName: "cloud.rain")
                            .foregroundColor(.blue)
                        Text("Rain expected to start in \(formattedTimeInterval(minutes: minutes))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                } else {
                    HStack {
                        Image(systemName: "sun.max")
                            .foregroundColor(.orange)
                        Text("No rain expected in the next 2 hours")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(.bottom, 4)

            // Precipitation Timeline Bar
            VStack(alignment: .leading, spacing: 6) {
                precipitationTimelineBar(timeline)

                // Time markers
                HStack(alignment: .top) {
                    Text("Now")
                        .font(.caption)
                        .frame(width: 40, alignment: .leading)

                    Spacer()

                    Text("+15m")
                        .font(.caption)
                        .frame(width: 40, alignment: .center)

                    Spacer()

                    Text("+30m")
                        .font(.caption)
                        .frame(width: 40, alignment: .center)

                    Spacer()

                    Text("+60m")
                        .font(.caption)
                        .frame(width: 40, alignment: .center)

                    Spacer()

                    Text("+120m")
                        .font(.caption)
                        .frame(width: 40, alignment: .trailing)
                }
                .foregroundColor(.secondary)
            }

            // Precipitation intensity legend
            HStack(spacing: 16) {
                legendItem(color: Color.blue.opacity(0.3), text: "Light")
                legendItem(color: Color.blue.opacity(0.6), text: "Moderate")
                legendItem(color: Color.blue.opacity(0.9), text: "Heavy")
            }
            .padding(.top, 8)
        }
        .padding()
        .styledCard()
    }

    /// Formats a minutes value as "X minutes", "1 hour", "2 hours", "1 day", or "1 day 2 hours"
    private func formattedTimeInterval(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minute" + (minutes == 1 ? "" : "s")
        } else {
            let totalHours = Int(round(Double(minutes) / 60.0))
            let days = totalHours / 24
            let hours = totalHours % 24
            var parts: [String] = []
            if days > 0 {
                parts.append("\(days) day" + (days == 1 ? "" : "s"))
            }
            if hours > 0 {
                parts.append("\(hours) hour" + (hours == 1 ? "" : "s"))
            }
            return parts.joined(separator: " ")
        }
    }

    private func precipitationTimelineBar(_ timeline: PrecipitationTimeline) -> some View {
        let chartColors = ChartColorScheme.precipitationTimeline(
            activeSkin: chartPaletteStore.activeSkin
        )
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(chartColors.background)
                    .frame(height: 24)
                    .cornerRadius(12)

                // Precipitation bars for each time point
                ForEach(timeline.timePoints.indices, id: \.self) { index in
                    let point = timeline.timePoints[index]
                    let now = Date()

                    // Skip points in the past
                    if point.time > now {
                        let minutesSinceNow = point.time.timeIntervalSince(now) / 60
                        let totalMinutes = 120.0 // 2 hour forecast

                        // Calculate position on timeline (0 to 1)
                        let position = CGFloat(minutesSinceNow / totalMinutes)

                        // Only show future points
                        if position >= 0 && position <= 1 {
                            Rectangle()
                                .fill(precipitationColor(for: point, scheme: chartColors))
                                .frame(
                                    width: 12,
                                    height: 24
                                )
                                .cornerRadius(4)
                                .position(
                                    x: position * geometry.size.width,
                                    y: 12
                                )
                        }
                    }
                }

                // Time markers (vertical lines)
                Group {
                    // +15 minutes marker
                    Rectangle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 1, height: 24)
                        .position(x: geometry.size.width * 0.25, y: 12)

                    // +30 minutes marker
                    Rectangle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 1, height: 24)
                        .position(x: geometry.size.width * 0.5, y: 12)

                    // +60 minutes marker
                    Rectangle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 1, height: 24)
                        .position(x: geometry.size.width * 0.75, y: 12)
                }

                // Current time indicator
                Circle()
                    .fill(chartColors.accent)
                    .frame(width: 8, height: 8)
                    .position(x: 0, y: 12)
            }
        }
        .frame(height: 24)
    }

    private func precipitationColor(
        for point: PrecipitationTimePoint,
        scheme: ChartColorScheme
    ) -> Color {
        if !point.isRaining { return Color.clear }

        let base = scheme.primary
        switch point.intensity {
        case .none:
            return Color.clear
        case .light:
            return base.opacity(0.3)
        case .moderate:
            return base.opacity(0.6)
        case .heavy:
            return base.opacity(0.9)
        }
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 12, height: 12)
                .cornerRadius(2)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Weather Alerts Section

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weather Alerts")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            if alertManager.alerts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("No Active Alerts")
                        .font(.headline)
                    
                    Text("No weather alerts for your location")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal)
                .styledCard()
                .padding(.horizontal)
            } else {
                ForEach(alertManager.alerts) { alert in
                    alertView(for: alert)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.92)),
                                removal: .opacity
                            )
                        )
                }
                .animation(
                    .easeInOut(duration: 0.4),
                    value: alertManager.alerts.count
                )
            }
        }
    }

    private func alertView(for alert: WeatherAlert) -> some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(alertSeverityColor(alert.severity))
                    .frame(width: 16, height: 16)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(alert.type)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(alertSeverityColor(alert.severity))
                        
                        Text(alert.severity.rawValue.uppercased())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(alertSeverityColor(alert.severity))
                    }
                }
                
                Spacer(minLength: 0)
                
                // Show chevron icon if URL is available
                if alert.detailsURL != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !alert.description.isEmpty && alert.description != alert.type {
                Text(alert.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(5)
                    .padding(.leading, 28)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(alert.date, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Show "Tap for details" hint if URL is available
                if alert.detailsURL != nil {
                    Spacer()
                    Text("Tap for details")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.leading, 28)
        }
        .padding(16)
        .styledCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(alertSeverityColor(alert.severity).opacity(0.3), lineWidth: 2)
        )
        .padding(.horizontal)
        
        // Wrap in button if URL is available
        if let url = alert.detailsURL {
            return AnyView(
                Button(action: {
                    #if os(iOS)
                    UIApplication.shared.open(url)
                    #elseif os(macOS)
                    NSWorkspace.shared.open(url)
                    #endif
                }) {
                    content
                }
                .buttonStyle(PlainButtonStyle())
            )
        } else {
            return AnyView(content)
        }
    }

    private func alertSeverityColor(_ severity: WeatherAlert.AlertSeverity) -> Color {
        switch severity.color {
        case "red":
            return Color.red
        case "orange":
            return Color.orange
        case "yellow":
            return Color.yellow
        default:
            return Color.blue
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Notifications Permission View

    private var notificationPermissionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stay Updated")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Get notified about weather changes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("Enable notifications to receive rain start/stop alerts and severe weather warnings for your location.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                alertManager.requestNotificationPermissions()
            } label: {
                HStack {
                    Image(systemName: "bell.fill")
                    Text("Enable Notifications")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding(16)
        .styledCard()
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func refreshData() async {
        isRefreshing = true

        // Use WeatherService's coordinate helper to respect API key settings
        if let coords = await weatherService.getCoordinates() {
            await alertManager.fetchAlerts(latitude: coords.latitude, longitude: coords.longitude)
        }

        isRefreshing = false
    }
}

// MARK: - Preview Provider

struct AlertsView_Previews: PreviewProvider {
    static var previews: some View {
        let weatherService = WeatherService()

        return AlertsView(weatherService: weatherService)
            .environmentObject(WeatherAlertManager.shared)
    }
}
