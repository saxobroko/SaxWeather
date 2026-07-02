import Foundation

/// Shared state for App Intent → in-app navigation.
///
/// `ShowForecastIntent` can run before `ContentView` has subscribed to
/// notifications, so we persist the target location in the App Group and
/// consume it when the app becomes active.
enum AppIntentNavigation {
    static let navigateNotification = Notification.Name("NavigateToLocation")

    private static let pendingLocationIDKey = "pendingNavigateLocationID"
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
}
