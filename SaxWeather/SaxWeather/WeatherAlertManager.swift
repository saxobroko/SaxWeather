//
//  WeatherAlertManager.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-03-10
//

import Foundation
import UserNotifications
import CoreLocation
import XMLCoder

class WeatherAlertManager: ObservableObject {
    @Published var alerts: [WeatherAlert] = []
    @Published var precipitationTimeline: PrecipitationTimeline?
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let notificationCenter = UNUserNotificationCenter.current()

    init() {
        checkNotificationPermissions()
    }

    func checkNotificationPermissions() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    func requestNotificationPermissions() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.authorizationStatus = granted ? .authorized : .denied
                if let error = error {
                    print("⚠️ Notification permission error: \(error.localizedDescription)")
                }
            }
        }
    }

    func fetchAlerts(latitude: Double, longitude: Double) async {
        await fetchMetAlertsRSS(latitude: latitude, longitude: longitude)
        await fetchYrNoPrecipitationForecast(latitude: latitude, longitude: longitude)
    }

    // MARK: - MET Alerts 2.0 (RSS, location based)
    private func fetchMetAlertsRSS(latitude: Double, longitude: Double) async {
        guard let url = URL(string: "https://api.met.no/weatherapi/metalerts/2.0/current.rss?lat=\(latitude)&lon=\(longitude)&lang=en") else {
            print("Invalid MET Alerts 2.0 RSS URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("SaxWeather (github.com/saxobroko/SaxWeather)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try XMLDecoder().decode(RSS.self, from: data)
            let newAlerts = processMetAlertsRSS(from: response)
            await MainActor.run {
                self.alerts = newAlerts
                scheduleAlertNotifications(for: newAlerts)
            }
        } catch {
            print("❌ Error fetching MET Alerts 2.0 RSS: \(error.localizedDescription)")
            if let xmlString = String(data: (try? Data(contentsOf: url)) ?? Data(), encoding: .utf8) {
                print("MET Alerts 2.0 RSS raw:\n\(xmlString)")
            }
        }
    }

    private func processMetAlertsRSS(from response: RSS) -> [WeatherAlert] {
        let items = response.channel.item ?? []
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"

        var alerts: [WeatherAlert] = []
        for entry in items {
            let event = entry.title ?? "Unknown"
            let date = dateFormatter.date(from: entry.pubDate ?? "") ?? Date()
            let description = entry.description ?? event
            let severity = WeatherAlert.AlertSeverity.fromTitle(entry.title ?? "")
            let alert = WeatherAlert(
                id: entry.guid ?? UUID().uuidString,
                type: event,
                severity: severity,
                description: description,
                date: date
            )
            alerts.append(alert)
        }
        return alerts
    }

    // MARK: - YR.NO Precipitation Nowcast (Locationforecast 2.0)
    private func fetchYrNoPrecipitationForecast(latitude: Double, longitude: Double) async {
        guard let url = URL(string: "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=\(latitude)&lon=\(longitude)") else {
            return
        }

        var request = URLRequest(url: url)
        request.setValue("SaxWeather (github.com/saxobroko/SaxWeather)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(YrNoForecastResponse.self, from: data)
            await MainActor.run {
                self.processYrNoPrecipitationData(response)
            }
        } catch {
            print("❌ Error fetching YR.NO precipitation: \(error.localizedDescription)")
        }
    }

    private func processYrNoPrecipitationData(_ response: YrNoForecastResponse) {
        let now = Date()
        var isRainingNow = false
        var rainStartTime: Date? = nil
        var rainEndTime: Date? = nil

        // Use next_1_hours.details.precipitation_amount for all timepoints
        let timePoints: [PrecipitationTimePoint] = response.properties.timeseries.prefix(24*4).compactMap { entry in
            let precip = entry.data.next_1_hours?.details?.precipitation_amount ?? 0.0
            guard let time = ISO8601DateFormatter().date(from: entry.time) else { return nil }
            let probability = (entry.data.next_1_hours?.summary?.symbol_code?.contains("rain") == true) ? 100 : 0
            return PrecipitationTimePoint(time: time, precipitation: precip, probability: probability)
        }

        // Use first entry for "now"
        if let nowEntry = response.properties.timeseries.first,
           let precip = nowEntry.data.next_1_hours?.details?.precipitation_amount,
           let nowTime = ISO8601DateFormatter().date(from: nowEntry.time) {
            isRainingNow = precip > 0.0
            print("DEBUG: Now precip \(precip), isRainingNow: \(isRainingNow), nowTime: \(nowTime), system now: \(now)")
        }

        // Print first 4 entries for troubleshooting
        for entry in response.properties.timeseries.prefix(4) {
            let precip = entry.data.next_1_hours?.details?.precipitation_amount ?? -1
            print("DEBUG: time = \(entry.time), precip = \(precip)")
        }

        // Find rain start (in future)
        if !isRainingNow, let firstRainPoint = timePoints.first(where: { $0.isRaining && $0.time > now }) {
            rainStartTime = firstRainPoint.time
        }
        // Find rain end (if raining now)
        if isRainingNow {
            for i in 0..<timePoints.count-1 {
                let point = timePoints[i]
                let nextPoint = timePoints[i+1]
                // FIXED LOGIC: remove point.time > now, require nextPoint.time > now
                if point.isRaining && !nextPoint.isRaining && nextPoint.time > now {
                    rainEndTime = nextPoint.time
                    break
                }
            }
        }

        let timeline = PrecipitationTimeline(
            timePoints: timePoints,
            rainStartTime: rainStartTime,
            rainEndTime: rainEndTime,
            isRainingNow: isRainingNow
        )
        print("DEBUG: Timeline: isRainingNow=\(timeline.isRainingNow), rainStartTime=\(String(describing: timeline.rainStartTime)), rainEndTime=\(String(describing: timeline.rainEndTime))")
        self.precipitationTimeline = timeline
        scheduleRainNotifications(timeline)
    }

    // MARK: - Notifications

    private func scheduleRainNotifications(_ timeline: PrecipitationTimeline) {
        guard authorizationStatus == .authorized else { return }

        notificationCenter.getPendingNotificationRequests { requests in
            let rainNotificationIds = requests.filter { $0.identifier.starts(with: "rain_") }.map { $0.identifier }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: rainNotificationIds)
        }

        if let startTime = timeline.rainStartTime {
            let minutesUntilStart = Int(startTime.timeIntervalSince(Date()) / 60)
            if minutesUntilStart > 0 && minutesUntilStart <= 120 {
                let content = UNMutableNotificationContent()
                content.title = "Rain Alert"
                content.body = "Rain expected to start in \(minutesUntilStart) minutes"
                content.sound = .default
                let triggerTime = max(1, minutesUntilStart - 5)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(triggerTime * 60), repeats: false)
                let request = UNNotificationRequest(identifier: "rain_start", content: content, trigger: trigger)
                notificationCenter.add(request) { error in
                    if let error = error {
                        print("❌ Error scheduling rain start notification: \(error.localizedDescription)")
                    }
                }
            }
        }

        if let endTime = timeline.rainEndTime {
            let minutesUntilEnd = Int(endTime.timeIntervalSince(Date()) / 60)
            if minutesUntilEnd > 0 && minutesUntilEnd <= 120 {
                let content = UNMutableNotificationContent()
                content.title = "Rain Update"
                content.body = "Rain expected to stop in \(minutesUntilEnd) minutes"
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
                let request = UNNotificationRequest(identifier: "rain_end", content: content, trigger: trigger)
                notificationCenter.add(request) { error in
                    if let error = error {
                        print("❌ Error scheduling rain end notification: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    func scheduleAlertNotifications(for alerts: [WeatherAlert]) {
        notificationCenter.getPendingNotificationRequests { requests in
            let alertNotificationIds = requests.filter { !$0.identifier.starts(with: "rain_") }.map { $0.identifier }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: alertNotificationIds)
        }
        guard authorizationStatus == .authorized else { return }

        for alert in alerts {
            if alert.severity != .information &&
                alert.date.timeIntervalSinceNow < 86400 &&
                alert.date.timeIntervalSinceNow > 0 {
                let content = UNMutableNotificationContent()
                content.title = "\(alert.severity.rawValue): \(alert.type)"
                content.body = alert.description
                content.sound = .default
                let triggerDate = alert.date.addingTimeInterval(-10800)
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger)
                notificationCenter.add(request) { error in
                    if let error = error {
                        print("❌ Error scheduling notification: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// MARK: - RSS Models for MET Alerts

struct RSS: Decodable {
    let channel: RSSChannel
}

struct RSSChannel: Decodable {
    let title: String?
    let item: [RSSItem]?
}

struct RSSItem: Decodable {
    let title: String?
    let description: String?
    let pubDate: String?
    let guid: String?
}

// MARK: - YR.NO FORECAST JSON RESPONSE (locationforecast 2.0)

struct YrNoForecastResponse: Codable {
    struct Properties: Codable {
        struct TimeSeriesEntry: Codable {
            let time: String
            let data: DataEntry
            struct DataEntry: Codable {
                let instant: Instant
                let next_1_hours: Next1Hours?
                let next_6_hours: Next6Hours?
                let next_12_hours: Next12Hours?
                struct Instant: Codable {
                    let details: Details
                    struct Details: Codable {
                        let air_pressure_at_sea_level: Double?
                        let air_temperature: Double?
                        let cloud_area_fraction: Double?
                        let relative_humidity: Double?
                        let wind_from_direction: Double?
                        let wind_speed: Double?
                        let precipitation_amount: Double?
                    }
                }
                struct Next1Hours: Codable {
                    let summary: Summary?
                    let details: NextHourDetails?
                    struct Summary: Codable {
                        let symbol_code: String?
                    }
                    struct NextHourDetails: Codable {
                        let precipitation_amount: Double?
                    }
                }
                struct Next6Hours: Codable {
                    let summary: Summary?
                    let details: Next6HourDetails?
                    struct Summary: Codable {
                        let symbol_code: String?
                    }
                    struct Next6HourDetails: Codable {
                        let precipitation_amount: Double?
                    }
                }
                struct Next12Hours: Codable {
                    let summary: Summary?
                    struct Summary: Codable {
                        let symbol_code: String?
                    }
                }
            }
        }
        let timeseries: [TimeSeriesEntry]
    }
    let properties: Properties
}

// MARK: - SHARED MODELS

struct PrecipitationTimePoint {
    let time: Date
    let precipitation: Double
    let probability: Int

    var isRaining: Bool {
        return precipitation > 0.1 && probability >= 50
    }

    var intensity: PrecipitationIntensity {
        if precipitation <= 0.1 { return .none }
        if precipitation <= 0.5 { return .light }
        if precipitation <= 2.0 { return .moderate }
        return .heavy
    }
}

enum PrecipitationIntensity {
    case none
    case light
    case moderate
    case heavy

    var color: String {
        switch self {
        case .none: return "clear"
        case .light: return "lightBlue"
        case .moderate: return "blue"
        case .heavy: return "darkBlue"
        }
    }
}

struct PrecipitationTimeline {
    let timePoints: [PrecipitationTimePoint]
    let rainStartTime: Date?
    let rainEndTime: Date?
    let isRainingNow: Bool

    var minutesUntilRainStarts: Int? {
        guard let startTime = rainStartTime else { return nil }
        return Int(startTime.timeIntervalSince(Date()) / 60)
    }

    var minutesUntilRainStops: Int? {
        guard let endTime = rainEndTime else { return nil }
        return Int(endTime.timeIntervalSince(Date()) / 60)
    }
}

struct WeatherAlert: Identifiable {
    let id: String
    let type: String
    let severity: AlertSeverity
    let description: String
    let date: Date

    enum AlertSeverity: String {
        case information = "Information"
        case advisory = "Advisory"
        case warning = "Warning"
        case severe = "Severe Warning"

        var color: String {
            switch self {
            case .information: return "blue"
            case .advisory: return "yellow"
            case .warning: return "orange"
            case .severe: return "red"
            }
        }

        // Maps MET Norway v2.0 severity string to our AlertSeverity
        init(metSeverity: String) {
            switch metSeverity.lowercased() {
            case "minor", "low", "yellow":
                self = .advisory
            case "moderate", "orange":
                self = .warning
            case "severe", "high", "red":
                self = .severe
            default:
                self = .information
            }
        }

        // Maps alert severity from title text for RSS
        static func fromTitle(_ title: String) -> AlertSeverity {
            let lower = title.lowercased()
            if lower.contains("yellow") { return .advisory }
            if lower.contains("orange") { return .warning }
            if lower.contains("red") { return .severe }
            return .information
        }
    }
}
