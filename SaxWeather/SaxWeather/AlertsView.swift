//
//  AlertsView.swift
//  SaxWeather
//
//  Created by Saxon on 10/3/2025.
//

import SwiftUI

struct AlertsView: View {
    @ObservedObject var alertManager: WeatherAlertManager
    @ObservedObject var weatherService: WeatherService
    @State private var isRefreshing = false

    var body: some View {
        NavigationView {
            ZStack {
                // Use the centralized background condition
                BackgroundView(condition: weatherService.currentBackgroundCondition)
                    .ignoresSafeArea()

                // --- Foreground content ---
                ScrollView {
                    VStack(spacing: 20) {
                        // Precipitation Timeline Section
                        if let timeline = alertManager.precipitationTimeline {
                            precipitationSection(timeline)
                        }

                        // Weather Alerts Section
                        alertsSection

                        // Notifications Permission Section
                        if alertManager.authorizationStatus != .authorized {
                            notificationPermissionView
                        }
                    }
                    .padding()
                }
                .navigationTitle("Weather Alerts")
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
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
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
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
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
                                .fill(precipitationColor(for: point))
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
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .position(x: 0, y: 12)
            }
        }
        .frame(height: 24)
    }

    private func precipitationColor(for point: PrecipitationTimePoint) -> Color {
        if !point.isRaining { return Color.clear }

        switch point.intensity {
        case .none:
            return Color.clear
        case .light:
            return Color.blue.opacity(0.3)
        case .moderate:
            return Color.blue.opacity(0.6)
        case .heavy:
            return Color.blue.opacity(0.9)
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
                .font(.headline)
                .padding(.horizontal)

            if alertManager.alerts.isEmpty {
                Text("No weather alerts for your location")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                ForEach(alertManager.alerts) { alert in
                    alertView(for: alert)
                }
            }
        }
    }

    private func alertView(for alert: WeatherAlert) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(alertSeverityColor(alert.severity))
                    .frame(width: 12, height: 12)

                Text(alert.type)
                    .font(.headline)

                Spacer()

                Text(alert.severity.rawValue)
                    .font(.subheadline)
                    .foregroundColor(alertSeverityColor(alert.severity))
            }

            Text(alert.description)
                .font(.body)
                .padding(.top, 4)

            Text(formatDate(alert.date))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Stay Updated")
                .font(.headline)

            Text("Enable notifications to receive alerts when rain is expected to start or stop, and for severe weather events.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                alertManager.requestNotificationPermissions()
            } label: {
                Text("Enable Notifications")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func refreshData() async {
        isRefreshing = true

        var latitude = 0.0
        var longitude = 0.0

        if weatherService.useGPS, let location = weatherService.locationManager.location {
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
        } else if let lat = Double(UserDefaults.standard.string(forKey: "latitude") ?? ""),
                  let lon = Double(UserDefaults.standard.string(forKey: "longitude") ?? "") {
            latitude = lat
            longitude = lon
        }

        if latitude != 0.0 && longitude != 0.0 {
            await alertManager.fetchAlerts(latitude: latitude, longitude: longitude)
        }

        isRefreshing = false
    }
}

// MARK: - Preview Provider

struct AlertsView_Previews: PreviewProvider {
    static var previews: some View {
        let weatherService = WeatherService()
        let alertManager = WeatherAlertManager()

        return AlertsView(alertManager: alertManager, weatherService: weatherService)
    }
}
