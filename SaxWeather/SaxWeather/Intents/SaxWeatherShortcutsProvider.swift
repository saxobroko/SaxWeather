import Foundation
import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct SaxWeatherShortcutsProvider: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetWeatherIntent(),
            phrases: [
                "Get the weather for \(\.$location) in \(.applicationName)",
                "What's the weather for \(\.$location) in \(.applicationName)",
                "Check the weather for \(\.$location) with \(.applicationName)",
                "Get the weather in \(.applicationName)",
                "What's the weather in \(.applicationName)"
            ],
            shortTitle: "Get Weather",
            systemImageName: "cloud.sun"
        )

        AppShortcut(
            intent: ShowForecastIntent(),
            phrases: [
                "Show forecast for \(\.$location) in \(.applicationName)",
                "Open forecast for \(\.$location) in \(.applicationName)",
                "Show forecast in \(.applicationName)"
            ],
            shortTitle: "Show Forecast",
            systemImageName: "calendar"
        )
    }
    
    static var shortcutTileColor: ShortcutTileColor {
        .lightBlue
    }
}
