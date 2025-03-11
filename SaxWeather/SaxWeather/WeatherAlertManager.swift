//
//  WeatherAlertManager.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-03-10
//

import Foundation
import UserNotifications

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
        // Fetch standard weather alerts
        await fetchWeatherAlerts(latitude: latitude, longitude: longitude)
        
        // Fetch minute-by-minute precipitation data
        await fetchPrecipitationForecast(latitude: latitude, longitude: longitude)
    }
    
    private func fetchWeatherAlerts(latitude: Double, longitude: Double) async {
        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&daily=weather_code&forecast_days=3&timezone=auto") else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(AlertResponse.self, from: data)
            
            let newAlerts = processAlerts(from: response)
            await MainActor.run {
                self.alerts = newAlerts
                scheduleAlertNotifications(for: newAlerts)
            }
        } catch {
            print("❌ Error fetching alerts: \(error.localizedDescription)")
        }
    }
    
    private func fetchPrecipitationForecast(latitude: Double, longitude: Double) async {
        // OpenMeteo provides minutely precipitation forecasts for 2 hours
        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&minutely_15=precipitation,precipitation_probability&forecast_minutes=120&timezone=auto") else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let response = try decoder.decode(MinutelyPrecipitationResponse.self, from: data)
            
            await MainActor.run {
                self.processPrecipitationData(response)
            }
        } catch {
            print("❌ Error fetching precipitation forecast: \(error.localizedDescription)")
        }
    }
    
    private func processPrecipitationData(_ response: MinutelyPrecipitationResponse) {
        guard !response.minutely_15.time.isEmpty,
              response.minutely_15.time.count == response.minutely_15.precipitation.count,
              response.minutely_15.time.count == response.minutely_15.precipitation_probability.count else {
            return
        }
        
        let now = Date()
        var timePoints: [PrecipitationTimePoint] = []
        
        // Create precipitation time points from the API data
        for i in 0..<response.minutely_15.time.count {
            let timeString = response.minutely_15.time[i]
            let dateFormatter = ISO8601DateFormatter()
            guard let time = dateFormatter.date(from: timeString) else { continue }
            
            let precipitation = response.minutely_15.precipitation[i]
            let probability = response.minutely_15.precipitation_probability[i]
            
            timePoints.append(PrecipitationTimePoint(
                time: time,
                precipitation: precipitation,
                probability: probability
            ))
        }
        
        // Find rain starting and ending events
        var rainStartTime: Date? = nil
        var rainEndTime: Date? = nil
        
        // Find when rain will start (if it's not raining now)
        if let firstRainPoint = timePoints.first(where: { $0.isRaining && $0.time > now }) {
            rainStartTime = firstRainPoint.time
        }
        
        // Find when rain will stop (if it's currently raining)
        let isRainingNow = timePoints.first(where: { $0.time > now && $0.time < now.addingTimeInterval(15 * 60) })?.isRaining ?? false
        if isRainingNow {
            // Find the first point after now where it stops raining
            for i in 0..<timePoints.count-1 {
                let point = timePoints[i]
                let nextPoint = timePoints[i+1]
                
                if point.time > now && point.isRaining && !nextPoint.isRaining {
                    rainEndTime = nextPoint.time
                    break
                }
            }
        }
        
        // Create timeline object
        let timeline = PrecipitationTimeline(
            timePoints: timePoints,
            rainStartTime: rainStartTime,
            rainEndTime: rainEndTime,
            isRainingNow: isRainingNow
        )
        
        self.precipitationTimeline = timeline
        
        // Schedule notifications for rain starting or stopping
        scheduleRainNotifications(timeline)
    }
    
    private func scheduleRainNotifications(_ timeline: PrecipitationTimeline) {
        guard authorizationStatus == .authorized else { return }
        
        // Remove existing precipitation notifications
        notificationCenter.getPendingNotificationRequests { requests in
            let rainNotificationIds = requests.filter { $0.identifier.starts(with: "rain_") }.map { $0.identifier }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: rainNotificationIds)
        }
        
        // Schedule rain start notification if applicable
        if let startTime = timeline.rainStartTime {
            let minutesUntilStart = Int(startTime.timeIntervalSince(Date()) / 60)
            if minutesUntilStart > 0 && minutesUntilStart <= 120 {
                let content = UNMutableNotificationContent()
                content.title = "Rain Alert"
                content.body = "Rain expected to start in \(minutesUntilStart) minutes"
                content.sound = .default
                
                // Notify 5 minutes before rain starts, or immediately if less than 5 minutes away
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
        
        // Schedule rain end notification if applicable
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
    
    private func processAlerts(from response: AlertResponse) -> [WeatherAlert] {
        var alerts: [WeatherAlert] = []
        
        // Process weather codes into alerts
        for (index, weatherCode) in response.daily.weather_code.enumerated() {
            if let date = ISO8601DateFormatter().date(from: response.daily.time[index]) {
                if let alert = createAlertFromWeatherCode(weatherCode, for: date) {
                    alerts.append(alert)
                }
            }
        }
        
        return alerts
    }
    
    private func createAlertFromWeatherCode(_ code: Int, for date: Date) -> WeatherAlert? {
        // Weather code severity mapping
        // Based on WMO weather codes
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateString = dateFormatter.string(from: date)
        
        switch code {
        case 95...99:
            // Severe thunderstorms/lightning
            return WeatherAlert(id: UUID().uuidString, 
                               type: "Severe Storm", 
                               severity: .severe, 
                               description: "Thunderstorm with lightning expected on \(dateString)", 
                               date: date)
        case 85...94:
            // Snow/precipitation
            return WeatherAlert(id: UUID().uuidString, 
                               type: "Heavy Snow", 
                               severity: .warning, 
                               description: "Heavy snow expected on \(dateString)", 
                               date: date)
        case 71...84:
            // Rain/freezing rain
            return WeatherAlert(id: UUID().uuidString, 
                               type: "Heavy Rain", 
                               severity: .warning, 
                               description: "Heavy rain predicted on \(dateString)", 
                               date: date)
        case 65...70:
            // Rain
            return WeatherAlert(id: UUID().uuidString, 
                               type: "Moderate Rain", 
                               severity: .advisory, 
                               description: "Moderate rainfall expected on \(dateString)", 
                               date: date)
        default:
            return nil
        }
    }
    
    func scheduleAlertNotifications(for alerts: [WeatherAlert]) {
        // Clear existing notifications except rain notifications
        notificationCenter.getPendingNotificationRequests { requests in
            let alertNotificationIds = requests.filter { !$0.identifier.starts(with: "rain_") }.map { $0.identifier }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: alertNotificationIds)
        }
        
        // Only schedule notifications if permission granted
        guard authorizationStatus == .authorized else { return }
        
        for alert in alerts {
            // Only notify for non-information alerts within next 24 hours
            if alert.severity != .information && 
               alert.date.timeIntervalSinceNow < 86400 && 
               alert.date.timeIntervalSinceNow > 0 {
                
                let content = UNMutableNotificationContent()
                content.title = "\(alert.severity.rawValue): \(alert.type)"
                content.body = alert.description
                content.sound = .default
                
                // Notify 3 hours before the alert time
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

struct AlertResponse: Codable {
    let daily: DailyAlerts
    
    struct DailyAlerts: Codable {
        let time: [String]
        let weather_code: [Int]
    }
}

struct MinutelyPrecipitationResponse: Codable {
    let minutely_15: Minutely15Data
    
    struct Minutely15Data: Codable {
        let time: [String]
        let precipitation: [Double]
        let precipitation_probability: [Int]
    }
}

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
    }
}
