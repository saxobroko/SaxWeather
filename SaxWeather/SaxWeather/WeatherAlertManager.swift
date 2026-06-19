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

class WeatherAlertManager: ObservableObject {
    @Published var alerts: [WeatherAlert] = []
    @Published var precipitationTimeline: PrecipitationTimeline?
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var alertDataSource: String = "unknown" // Track which service provided the alerts

    private let notificationCenter = UNUserNotificationCenter.current()

    static let shared = WeatherAlertManager()

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
        print("\n⚠️  WEATHER ALERTS DATA SOURCE")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📍 Fetching alerts for: \(latitude), \(longitude)")
        
        // Priority 1: Try WeatherKit (iOS 16+ / macOS 13+) - USA, Canada, Europe
        if #available(iOS 16.0, macOS 13.0, *) {
            print("📍 Priority 1: Attempting Apple WeatherKit for alerts")
            let weatherKitSuccess = await fetchWeatherKitAlerts(latitude: latitude, longitude: longitude)
            
            if weatherKitSuccess {
                print("✅ SUCCESS: Using Apple WeatherKit for weather alerts")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
                return
            } else {
                print("⚠️  WeatherKit alerts unavailable for this region")
            }
        }
        
        // Priority 2: Regional alert services
        let region = determineRegion(latitude: latitude, longitude: longitude)
        print("🌍 Detected region: \(region)")
        
        // Check if we're in Australia
        if isInAustralia(latitude: latitude, longitude: longitude) {
            print("📍 Priority 2: Attempting Bureau of Meteorology (BOM) for Australian alerts")
            let bomSuccess = await fetchBOMAlerts(latitude: latitude, longitude: longitude)
            
            if bomSuccess {
                print("✅ SUCCESS: Using Bureau of Meteorology (BOM) for weather alerts")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
                return
            } else {
                print("⚠️  BOM alerts unavailable")
            }
        }
        
        // Priority 3: MET.no (Norway + nearby regions only)
        await fetchMetAlertsRSS(latitude: latitude, longitude: longitude)
        await fetchYrNoPrecipitationForecast(latitude: latitude, longitude: longitude)
        
        if alerts.isEmpty {
            print("ℹ️  No active weather alerts for this location")
            print("   Note: MET.no alerts only cover Norway and nearby regions")
            print("   Tip: Upgrade to iOS 16+ / macOS 13+ for global WeatherKit alerts")
        } else {
            print("✅ Found \(alerts.count) active alert(s)")
        }
        
        print("✅ Using MET.NO for weather alerts and precipitation forecast")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
    
    private func determineRegion(latitude: Double, longitude: Double) -> String {
        // Norway coverage: roughly 58°N to 71°N, 4°E to 31°E
        if latitude >= 58 && latitude <= 71 && longitude >= 4 && longitude <= 31 {
            return "Norway (MET.no coverage)"
        }
        // Australia coverage
        if isInAustralia(latitude: latitude, longitude: longitude) {
            return "Australia (BOM coverage)"
        }
        // Add more regions as needed
        return "Outside known coverage area"
    }
    
    // MARK: - Bureau of Meteorology (BOM) - Australia
    
    /// Check if coordinates are within Australia
    private func isInAustralia(latitude: Double, longitude: Double) -> Bool {
        // Australia mainland bounds: roughly -44°S to -10°S, 113°E to 154°E
        // Includes Tasmania, excludes external territories
        return latitude >= -44 && latitude <= -10 && longitude >= 113 && longitude <= 154
    }
    
    /// Fetch weather alerts from Bureau of Meteorology (Australia)
    private func fetchBOMAlerts(latitude: Double, longitude: Double) async -> Bool {
        print("🌏 Fetching BOM alerts for Australian location")
        
        // Determine which state/territory based on coordinates
        let stateCode = determineAustralianState(latitude: latitude, longitude: longitude)
        
        guard let stateCode = stateCode else {
            print("⚠️  Could not determine Australian state for coordinates")
            return false
        }
        
        print("📍 Location in: \(stateCode)")
        
        // BOM RSS feed format: /fwo/[PRODUCTID].warnings_[state].xml
        // Product IDs for all warnings by state:
        // VIC: IDZ00059, NSW: IDZ00057, QLD: IDZ00060, SA: IDZ00056,
        // WA: IDZ00055, TAS: IDZ00058, NT: IDZ00054
        let productID = getBOMProductID(for: stateCode)
        let urlString = "https://www.bom.gov.au/fwo/\(productID).warnings_\(stateCode.lowercased()).xml"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid BOM URL: \(urlString)")
            return false
        }
        
        var request = URLRequest(url: url)
        // BOM requires a proper browser-like User-Agent
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/xml, application/xml, application/rss+xml, */*", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 BOM API response: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    print("❌ BOM API returned error status: \(httpResponse.statusCode)")
                    #if DEBUG
                    print("   URL attempted: \(urlString)")
                    if httpResponse.statusCode == 403 {
                        print("   This may be a User-Agent or authentication issue")
                    } else if httpResponse.statusCode == 404 {
                        print("   The product ID or state code may be incorrect")
                    }
                    #endif
                    return false
                }
            }
            
            // Parse BOM RSS/XML feed
            let bomAlerts = try parseBOMAlerts(from: data)
            
            print("📊 Parsed \(bomAlerts.count) alert(s) from BOM")
            
            if bomAlerts.isEmpty {
                return false
            }
            
            await MainActor.run {
                self.alerts = bomAlerts
                self.alertDataSource = "bom" // Set BOM as the alert source
                scheduleAlertNotifications(for: bomAlerts)
            }
            
            return true
            
        } catch {
            print("❌ Error fetching BOM alerts: \(error.localizedDescription)")
            #if DEBUG
            print("   URL: \(urlString)")
            #endif
            return false
        }
    }
    
    /// Determine Australian state/territory code from coordinates
    private func determineAustralianState(latitude: Double, longitude: Double) -> String? {
        // Rough state boundaries for major population centers
        // These are approximate - BOM warnings are state-wide anyway
        
        // Victoria (Melbourne, etc)
        if latitude >= -39 && latitude <= -34 && longitude >= 140 && longitude <= 150 {
            return "VIC"
        }
        
        // New South Wales (Sydney, etc)
        if latitude >= -37 && latitude <= -28 && longitude >= 141 && longitude <= 154 {
            return "NSW"
        }
        
        // Queensland (Brisbane, etc)
        if latitude >= -29 && latitude <= -10 && longitude >= 138 && longitude <= 154 {
            return "QLD"
        }
        
        // South Australia (Adelaide, etc)
        if latitude >= -38 && latitude <= -26 && longitude >= 129 && longitude <= 141 {
            return "SA"
        }
        
        // Western Australia (Perth, etc)
        if latitude >= -35 && latitude <= -15 && longitude >= 113 && longitude <= 129 {
            return "WA"
        }
        
        // Tasmania
        if latitude >= -44 && latitude <= -39 && longitude >= 144 && longitude <= 149 {
            return "TAS"
        }
        
        // Northern Territory (Darwin, Alice Springs, etc)
        if latitude >= -26 && latitude <= -10 && longitude >= 129 && longitude <= 138 {
            return "NT"
        }
        
        // Australian Capital Territory (Canberra)
        // Small area, falls within NSW coordinates
        if latitude >= -35.9 && latitude <= -35.1 && longitude >= 148.7 && longitude <= 149.4 {
            return "ACT"
        }
        
        return nil
    }
    
    /// Get BOM product ID for state weather warnings
    private func getBOMProductID(for stateCode: String) -> String {
        // BOM product IDs for "all warnings" RSS feeds by state
        switch stateCode.uppercased() {
        case "VIC": return "IDZ00059"  // Victoria
        case "NSW": return "IDZ00057"  // New South Wales
        case "QLD": return "IDZ00060"  // Queensland
        case "SA": return "IDZ00056"   // South Australia
        case "WA": return "IDZ00055"   // Western Australia
        case "TAS": return "IDZ00058"  // Tasmania
        case "NT": return "IDZ00054"   // Northern Territory
        case "ACT": return "IDZ00057"  // ACT uses NSW feed
        default: return "IDZ00059"     // Default to VIC
        }
    }
    
    /// Clean text by removing extra whitespace and line breaks
    private func cleanAlertText(_ text: String) -> String {
        // Remove HTML entities
        var cleaned = text.replacingOccurrences(of: "&amp;", with: "&")
        cleaned = cleaned.replacingOccurrences(of: "&lt;", with: "<")
        cleaned = cleaned.replacingOccurrences(of: "&gt;", with: ">")
        cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
        
        // Replace multiple whitespace/newlines with single space
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Trim whitespace from start and end
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    /// Parse BOM XML alerts into WeatherAlert objects
    private func parseBOMAlerts(from data: Data) throws -> [WeatherAlert] {
        // BOM uses standard RSS 2.0 format, similar to MET.no
        // We can reuse the RSS decoder
        
        let rssResponse = try XMLDecoder().decode(RSS.self, from: data)
        
        guard let items = rssResponse.channel.item, !items.isEmpty else {
            print("ℹ️  No active alerts in BOM feed")
            return []
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
        
        var alerts: [WeatherAlert] = []
        
        for item in items {
            // Clean the title first
            guard let rawTitle = item.title,
                  !rawTitle.isEmpty else {
                continue
            }
            
            let title = cleanAlertText(rawTitle)
            
            // Skip items that are just headers or summaries
            guard !title.lowercased().contains("warning summary") else {
                continue
            }
            
            let severity = determineBOMSeverity(from: title)
            let date = dateFormatter.date(from: item.pubDate ?? "") ?? Date()
            
            // Clean the description too
            let description = item.description.map { cleanAlertText($0) } ?? title
            
            let alert = WeatherAlert(
                id: item.guid ?? UUID().uuidString,
                type: title,
                severity: severity,
                description: description,
                date: date
            )
            
            alerts.append(alert)
            
            #if DEBUG
            print("🔍 BOM Alert:")
            print("   - Title: \(title)")
            print("   - Severity: \(severity.rawValue)")
            print("   - Date: \(date)")
            #endif
        }
        
        return alerts
    }
    
    /// Determine alert severity from BOM alert title
    private func determineBOMSeverity(from title: String) -> WeatherAlert.AlertSeverity {
        let lower = title.lowercased()
        
        // BOM uses: Severe Weather Warning, Severe Thunderstorm Warning, etc.
        if lower.contains("extreme") || lower.contains("emergency") {
            return .extreme
        }
        
        if lower.contains("severe") {
            return .severe
        }
        
        if lower.contains("warning") {
            return .warning
        }
        
        if lower.contains("watch") {
            return .advisory
        }
        
        if lower.contains("advice") || lower.contains("information") {
            return .information
        }
        
        // Default to moderate for unknown BOM alert types
        return .moderate
    }
    
    // MARK: - WeatherKit Alerts (iOS 16+, Global Coverage)
    @available(iOS 16.0, macOS 13.0, *)
    private func fetchWeatherKitAlerts(latitude: Double, longitude: Double) async -> Bool {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        do {
            // Use WeatherKit's shared service instance (same as used for weather data)
            #if canImport(WeatherKit)
            // Try fetching complete weather data (like the working forecast code does)
            // The Weather object might include alerts as a property
            print("🔍 Checking for alerts in Weather object...")
            
            // Try to access alerts - the property might exist on the Weather object
            // Since the forecast call works, maybe alerts come with it
            let weather = try await WeatherKit.WeatherService.shared.weather(for: location)
            if let weatherAlerts = weather.weatherAlerts, !weatherAlerts.isEmpty {
                print("📊 Found \(weatherAlerts.count) alert(s) from complete weather query")
                
                let convertedAlerts = weatherAlerts.map { alert in
                    #if DEBUG
                    print("🔍 Alert Debug Info:")
                    print("   - Summary: \(alert.summary)")
                    print("   - Severity: \(alert.severity)")
                    print("   - Source: \(alert.source)")
                    print("   - Region: \(alert.region ?? "N/A")")
                    print("   - Details URL: \(alert.detailsURL)")
                    #endif
                    
                    // Build a descriptive text for the alert
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
                
                print("📊 Parsed \(convertedAlerts.count) alert(s) from WeatherKit")
                
                await MainActor.run {
                    self.alerts = convertedAlerts
                    self.alertDataSource = "weatherkit" // Set WeatherKit as the alert source
                    if !convertedAlerts.isEmpty {
                        scheduleAlertNotifications(for: convertedAlerts)
                    }
                }
                
                return true
            } else {
                print("📊 No alerts in complete weather query")
                return false
            }
            #else
            return false
            #endif
        } catch {
            print("❌ Error fetching WeatherKit weather: \(error.localizedDescription)")
            return false
        }
    }
    
    @available(iOS 16.0, macOS 13.0, *)
    private func mapWeatherKitSeverity(_ severity: WeatherSeverity) -> WeatherAlert.AlertSeverity {
        switch severity {
        case .extreme:
            return .extreme
        case .severe:
            return .severe
        case .moderate:
            return .moderate
        case .minor:
            return .minor
        case .unknown:
            return .unknown
        @unknown default:
            return .unknown
        }
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
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log response status
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 MET.no API response: \(httpResponse.statusCode)")
            }
            
            let rssResponse = try XMLDecoder().decode(RSS.self, from: data)
            let newAlerts = processMetAlertsRSS(from: rssResponse)
            
            print("📊 Parsed \(newAlerts.count) alert(s) from MET.no RSS")
            
            await MainActor.run {
                self.alerts = newAlerts
                self.alertDataSource = "metno" // Set MET.no as the alert source
                if !newAlerts.isEmpty {
                    scheduleAlertNotifications(for: newAlerts)
                }
            }
        } catch {
            print("❌ Error fetching MET Alerts 2.0 RSS: \(error.localizedDescription)")
            // Don't log raw XML in production - too verbose
            #if DEBUG
            if let urlData = try? Data(contentsOf: url),
               let xmlString = String(data: urlData, encoding: .utf8) {
                print("Debug - MET Alerts RSS preview: \(xmlString.prefix(500))...")
            }
            #endif
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
        // `precipitationTimeline` is `@Published` — must be set on
        // the main thread. This function is called from a
        // background URLSession callback, so hop to MainActor
        // before mutating.
        Task { @MainActor in
            self.precipitationTimeline = timeline
            self.scheduleRainNotifications(timeline)
        }
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

    /// Fetch alerts in the background and trigger a local notification if rain is detected
    func fetchAlertsInBackground(latitude: Double, longitude: Double, completion: @escaping (Bool) -> Void) {
        Task {
            await self.fetchAlerts(latitude: latitude, longitude: longitude)
            // Check if any precipitation is expected in the next 2 hours
            let rainExpected = self.precipitationTimeline?.isRainingNow == true || (self.precipitationTimeline?.minutesUntilRainStarts ?? Int.max) < 120
            #if os(iOS)
            if rainExpected {
                let content = UNMutableNotificationContent()
                content.title = "Rain Alert"
                content.body = "Rain is expected soon in your area."
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                try? await UNUserNotificationCenter.current().add(request)
            }
            #endif
            completion(rainExpected)
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
    var detailsURL: URL? = nil // Optional URL for more details

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
