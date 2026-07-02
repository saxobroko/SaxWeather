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
#if canImport(WeatherKit)
import WeatherKit
#endif

@MainActor
final class WeatherAlertManager: ObservableObject {
    @Published var alerts: [WeatherAlert] = []
    @Published var precipitationTimeline: PrecipitationTimeline?
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var alertDataSource: String = "none"
    @Published var precipitationDataSource: String = "openmeteo"

    private let notificationCenter = UNUserNotificationCenter.current()
    private let openMeteoService = OpenMeteoService()

    static let shared = WeatherAlertManager()

    init() {
        checkNotificationPermissions()
    }

    func checkNotificationPermissions() {
        notificationCenter.getNotificationSettings { settings in
            Task { @MainActor in
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    func requestNotificationPermissions() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            Task { @MainActor in
                self.authorizationStatus = granted ? .authorized : .denied
                if let error {
                    print("Notification permission error: \(error.localizedDescription)")
                }
            }
        }
    }

    func fetchAlerts(latitude: Double, longitude: Double) async {
        async let rain: Void = fetchRainForecast(latitude: latitude, longitude: longitude)
        async let severe: Void = fetchSevereAlerts(latitude: latitude, longitude: longitude)
        _ = await (rain, severe)
    }

    // MARK: - Rain (Open-Meteo, global)

    private func fetchRainForecast(latitude: Double, longitude: Double) async {
        guard SettingsBehaviour.rainAlertsEnabled else {
            precipitationTimeline = nil
            clearPendingRainNotifications()
            return
        }

        do {
            let hourly = try await openMeteoService.fetchHourlyPrecipitation(
                latitude: latitude,
                longitude: longitude
            )
            let timeline = PrecipitationTimelineBuilder.build(from: hourly)
            precipitationTimeline = timeline
            precipitationDataSource = "openmeteo"
            scheduleRainNotifications(timeline)
        } catch {
            print("Rain forecast fetch failed: \(error.localizedDescription)")
            precipitationTimeline = nil
        }
    }

    // MARK: - Severe alerts (WeatherKit → BOM → none)

    private func fetchSevereAlerts(latitude: Double, longitude: Double) async {
        guard SettingsBehaviour.severeWeatherAlertsEnabled else {
            alerts = []
            alertDataSource = "none"
            clearPendingSevereNotifications()
            return
        }

        if #available(iOS 16.0, macOS 13.0, *) {
            if await fetchWeatherKitAlerts(latitude: latitude, longitude: longitude) {
                return
            }
        }

        if isInAustralia(latitude: latitude, longitude: longitude) {
            if await fetchBOMAlerts(latitude: latitude, longitude: longitude) {
                return
            }
        }

        alerts = []
        alertDataSource = "none"
        clearPendingSevereNotifications()
    }

    // MARK: - Bureau of Meteorology (BOM) - Australia

    private func isInAustralia(latitude: Double, longitude: Double) -> Bool {
        latitude >= -44 && latitude <= -10 && longitude >= 113 && longitude <= 154
    }

    private func fetchBOMAlerts(latitude: Double, longitude: Double) async -> Bool {
        guard let stateCode = determineAustralianState(latitude: latitude, longitude: longitude) else {
            return false
        }

        let productID = getBOMProductID(for: stateCode)
        let urlString = "https://www.bom.gov.au/fwo/\(productID).warnings_\(stateCode.lowercased()).xml"
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/xml, application/xml, application/rss+xml, */*", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }

            let bomAlerts = try parseBOMAlerts(from: data)
            guard !bomAlerts.isEmpty else { return false }

            alerts = bomAlerts
            alertDataSource = "bom"
            scheduleAlertNotifications(for: bomAlerts)
            return true
        } catch {
            print("BOM alerts fetch failed: \(error.localizedDescription)")
            return false
        }
    }

    private func determineAustralianState(latitude: Double, longitude: Double) -> String? {
        if latitude >= -39 && latitude <= -34 && longitude >= 140 && longitude <= 150 { return "VIC" }
        if latitude >= -37 && latitude <= -28 && longitude >= 141 && longitude <= 154 { return "NSW" }
        if latitude >= -29 && latitude <= -10 && longitude >= 138 && longitude <= 154 { return "QLD" }
        if latitude >= -38 && latitude <= -26 && longitude >= 129 && longitude <= 141 { return "SA" }
        if latitude >= -35 && latitude <= -15 && longitude >= 113 && longitude <= 129 { return "WA" }
        if latitude >= -44 && latitude <= -39 && longitude >= 144 && longitude <= 149 { return "TAS" }
        if latitude >= -26 && latitude <= -10 && longitude >= 129 && longitude <= 138 { return "NT" }
        if latitude >= -35.9 && latitude <= -35.1 && longitude >= 148.7 && longitude <= 149.4 { return "ACT" }
        return nil
    }

    private func getBOMProductID(for stateCode: String) -> String {
        switch stateCode.uppercased() {
        case "VIC": return "IDZ00059"
        case "NSW": return "IDZ00057"
        case "QLD": return "IDZ00060"
        case "SA": return "IDZ00056"
        case "WA": return "IDZ00055"
        case "TAS": return "IDZ00058"
        case "NT": return "IDZ00054"
        case "ACT": return "IDZ00057"
        default: return "IDZ00059"
        }
    }

    private func cleanAlertText(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseBOMAlerts(from data: Data) throws -> [WeatherAlert] {
        let rssResponse = try XMLDecoder().decode(RSS.self, from: data)
        guard let items = rssResponse.channel.item, !items.isEmpty else { return [] }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"

        return items.compactMap { item in
            guard let rawTitle = item.title, !rawTitle.isEmpty else { return nil }
            let title = cleanAlertText(rawTitle)
            guard !title.lowercased().contains("warning summary") else { return nil }

            let description = item.description.map { cleanAlertText($0) } ?? title
            return WeatherAlert(
                id: item.guid ?? UUID().uuidString,
                type: title,
                severity: determineBOMSeverity(from: title),
                description: description,
                date: dateFormatter.date(from: item.pubDate ?? "") ?? Date()
            )
        }
    }

    private func determineBOMSeverity(from title: String) -> WeatherAlert.AlertSeverity {
        let lower = title.lowercased()
        if lower.contains("extreme") || lower.contains("emergency") { return .extreme }
        if lower.contains("severe") { return .severe }
        if lower.contains("warning") { return .warning }
        if lower.contains("watch") { return .advisory }
        if lower.contains("advice") || lower.contains("information") { return .information }
        return .moderate
    }

    // MARK: - WeatherKit Alerts

    @available(iOS 16.0, macOS 13.0, *)
    private func fetchWeatherKitAlerts(latitude: Double, longitude: Double) async -> Bool {
        let location = CLLocation(latitude: latitude, longitude: longitude)

        do {
            #if canImport(WeatherKit)
            let weather = try await WeatherKit.WeatherService.shared.weather(for: location)
            let weatherAlerts = weather.weatherAlerts ?? []

            let convertedAlerts = weatherAlerts.map { alert in
                var description = ""
                if let region = alert.region {
                    description += "Region: \(region)\n"
                }
                description += "Source: \(alert.source)"

                return WeatherAlert(
                    id: UUID().uuidString,
                    type: alert.summary,
                    severity: mapWeatherKitSeverity(alert.severity),
                    description: description,
                    date: Date(),
                    detailsURL: alert.detailsURL
                )
            }

            alerts = convertedAlerts
            alertDataSource = "weatherkit"
            if !convertedAlerts.isEmpty {
                scheduleAlertNotifications(for: convertedAlerts)
            } else {
                clearPendingSevereNotifications()
            }
            return true
            #else
            return false
            #endif
        } catch {
            print("WeatherKit alerts fetch failed: \(error.localizedDescription)")
            return false
        }
    }

    @available(iOS 16.0, macOS 13.0, *)
    private func mapWeatherKitSeverity(_ severity: WeatherSeverity) -> WeatherAlert.AlertSeverity {
        switch severity {
        case .extreme: return .extreme
        case .severe: return .severe
        case .moderate: return .moderate
        case .minor: return .minor
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }

    // MARK: - Notifications

    private func clearPendingRainNotifications() {
        notificationCenter.getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix("rain_") }.map(\.identifier)
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func clearPendingSevereNotifications() {
        notificationCenter.getPendingNotificationRequests { requests in
            let ids = requests.filter { !$0.identifier.hasPrefix("rain_") }.map(\.identifier)
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func scheduleRainNotifications(_ timeline: PrecipitationTimeline) {
        guard authorizationStatus == .authorized else { return }
        guard SettingsBehaviour.rainAlertsEnabled else { return }

        clearPendingRainNotifications()
        guard !SettingsBehaviour.isInQuietHours else { return }

        if let startTime = timeline.rainStartTime {
            let minutesUntilStart = Int(startTime.timeIntervalSince(Date()) / 60)
            if minutesUntilStart > 0 && minutesUntilStart <= 120 {
                let content = UNMutableNotificationContent()
                content.title = "Rain Alert"
                content.body = "Rain expected to start in \(minutesUntilStart) minutes"
                content.sound = SettingsBehaviour.weatherAlertSounds ? .default : nil
                let triggerTime = max(1, minutesUntilStart - 5)
                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: TimeInterval(triggerTime * 60),
                    repeats: false
                )
                let request = UNNotificationRequest(identifier: "rain_start", content: content, trigger: trigger)
                notificationCenter.add(request)
            }
        }

        if let endTime = timeline.rainEndTime {
            let minutesUntilEnd = Int(endTime.timeIntervalSince(Date()) / 60)
            if minutesUntilEnd > 0 && minutesUntilEnd <= 120 {
                let content = UNMutableNotificationContent()
                content.title = "Rain Update"
                content.body = "Rain expected to stop in \(minutesUntilEnd) minutes"
                content.sound = SettingsBehaviour.weatherAlertSounds ? .default : nil
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
                let request = UNNotificationRequest(identifier: "rain_end", content: content, trigger: trigger)
                notificationCenter.add(request)
            }
        }
    }

    func scheduleAlertNotifications(for alerts: [WeatherAlert]) {
        guard authorizationStatus == .authorized else { return }
        guard SettingsBehaviour.severeWeatherAlertsEnabled else { return }

        clearPendingSevereNotifications()
        guard !SettingsBehaviour.isInQuietHours else { return }

        for alert in alerts {
            guard alert.severity != .information else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(alert.severity.rawValue): \(alert.type)"
            content.body = alert.description
            content.sound = SettingsBehaviour.weatherAlertSounds ? .default : nil

            let trigger: UNNotificationTrigger
            let age = -alert.date.timeIntervalSinceNow
            if age >= 0 && age < 3600 {
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            } else if alert.date.timeIntervalSinceNow > 0 && alert.date.timeIntervalSinceNow < 86400 {
                let triggerDate = max(alert.date.addingTimeInterval(-900), Date().addingTimeInterval(5))
                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: triggerDate
                )
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            } else {
                continue
            }

            let request = UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger)
            notificationCenter.add(request)

            SettingsBehaviour.speakWeatherAlert(
                title: "\(alert.severity.rawValue): \(alert.type)",
                body: alert.description
            )
        }
    }
}

// MARK: - BOM RSS Models

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

// MARK: - Shared Models

struct PrecipitationTimePoint {
    let time: Date
    let precipitation: Double
    let probability: Int

    var isRaining: Bool {
        precipitation > 0.05 && probability >= WidgetRainLine.probabilityThreshold
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
    var detailsURL: URL? = nil

    enum AlertSeverity: String {
        case information = "Information"
        case advisory = "Advisory"
        case warning = "Warning"
        case severe = "Severe Warning"
        case extreme = "Extreme"
        case moderate = "Moderate"
        case minor = "Minor"
        case unknown = "Unknown"

        var color: String {
            switch self {
            case .information, .unknown: return "blue"
            case .minor, .advisory: return "yellow"
            case .moderate, .warning: return "orange"
            case .severe: return "red"
            case .extreme: return "purple"
            }
        }
    }
}
