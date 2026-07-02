import Foundation

/// Shared state for App Intent → in-app navigation.
///
/// `ShowForecastIntent` can run before `ContentView` has subscribed to
/// notifications, so we persist the target location in the App Group and
/// consume it when the app becomes active.
enum AppIntentNavigation {
    static let navigateNotification = Notification.Name("NavigateToLocation")
    static let weatherLinkNotification = Notification.Name("NavigateToWeatherLink")

    private static let pendingLocationIDKey = "pendingNavigateLocationID"
    private static let pendingWeatherLinkKey = "pendingWeatherLink"
    private static let appGroupID = "group.com.saxobroko.SaxWeather"

    static func storePendingLocation(id: UUID) {
        let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        defaults.set(id.uuidString, forKey: pendingLocationIDKey)

        NotificationCenter.default.post(
            name: navigateNotification,
            object: nil,
            userInfo: ["locationId": id]
        )
    }

    static func consumePendingLocationID() -> UUID? {
        let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        guard let idString = defaults.string(forKey: pendingLocationIDKey),
              let id = UUID(uuidString: idString) else {
            return nil
        }
        defaults.removeObject(forKey: pendingLocationIDKey)
        return id
    }

    static func storePendingWeatherLink(_ link: PendingWeatherLink) {
        let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        if let data = try? JSONEncoder().encode(link) {
            defaults.set(data, forKey: pendingWeatherLinkKey)
        }

        NotificationCenter.default.post(
            name: weatherLinkNotification,
            object: nil
        )
    }

    static func consumePendingWeatherLink() -> PendingWeatherLink? {
        let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        guard let data = defaults.data(forKey: pendingWeatherLinkKey),
              let link = try? JSONDecoder().decode(PendingWeatherLink.self, from: data) else {
            return nil
        }
        defaults.removeObject(forKey: pendingWeatherLinkKey)
        return link
    }

    #if DEBUG
    /// Non-consuming read for the debug tab.
    static func peekPendingLocationID() -> UUID? {
        let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        guard let idString = defaults.string(forKey: pendingLocationIDKey) else { return nil }
        return UUID(uuidString: idString)
    }

    /// Non-consuming read for the debug tab.
    static func peekPendingWeatherLink() -> PendingWeatherLink? {
        let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        guard let data = defaults.data(forKey: pendingWeatherLinkKey) else { return nil }
        return try? JSONDecoder().decode(PendingWeatherLink.self, from: data)
    }
    #endif
}
