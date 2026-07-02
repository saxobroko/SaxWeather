//
//  LocationPreviewNavigation.swift
//  SaxWeather
//

import Foundation

/// Cross-tab coordinator for presenting `LocationWeatherPreviewSheet`
/// from Settings, the hamburger menu, swipe gestures, and share links.
enum LocationPreviewNavigation {
    static let requestNotification = Notification.Name("PresentLocationWeatherPreview")

    private static let pendingKey = "pendingLocationWeatherPreview"
    private static let appGroupID = "group.com.saxobroko.SaxWeather"

    static func request(_ request: LocationWeatherPreviewRequest) {
        let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        if let data = try? JSONEncoder().encode(request) {
            defaults.set(data, forKey: pendingKey)
        }

        NotificationCenter.default.post(
            name: requestNotification,
            object: nil
        )
    }

    static func consumePending() -> LocationWeatherPreviewRequest? {
        let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        guard let data = defaults.data(forKey: pendingKey),
              let request = try? JSONDecoder().decode(
                LocationWeatherPreviewRequest.self,
                from: data
              ) else {
            return nil
        }
        defaults.removeObject(forKey: pendingKey)
        return request
    }
}
