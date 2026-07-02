import Foundation
import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct SaxWeatherShortcutsProvider: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetWeatherIntent(),
            phrases: [
                "What's the weather in \(.applicationName)",
                "What's the weather for \(\.$location) in \(.applicationName)",
                "How's the weather in \(.applicationName)",
                "How's the weather for \(\.$location) in \(.applicationName)",
                "Get the weather for \(\.$location) in \(.applicationName)",
                "Check the weather for \(\.$location) with \(.applicationName)",
                "Tell me the weather in \(.applicationName)",
                "Tell me the weather for \(\.$location) in \(.applicationName)"
            ],
            shortTitle: "Get Weather",
            systemImageName: "cloud.sun"
        )

        AppShortcut(
            intent: GetForecastIntent(),
            phrases: [
                "Get the forecast for \(\.$location) in \(.applicationName)",
                "What's the forecast for \(\.$location) in \(.applicationName)",
                "What's the forecast in \(.applicationName)",
                "Forecast for \(\.$location) in \(.applicationName)"
            ],
            shortTitle: "Get Forecast",
            systemImageName: "calendar.badge.clock"
        )

        AppShortcut(
            intent: RainInNextHourIntent(),
            phrases: [
                "Will it rain in the next hour in \(.applicationName)",
                "Will it rain in the next hour in \(\.$location) with \(.applicationName)",
                "Is rain coming in the next hour in \(.applicationName)",
                "Rain in the next hour in \(.applicationName)"
            ],
            shortTitle: "Rain Next Hour",
            systemImageName: "cloud.rain"
        )

        AppShortcut(
            intent: GetUVIndexIntent(),
            phrases: [
                "What's the UV index in \(.applicationName)",
                "What's the UV index for \(\.$location) in \(.applicationName)",
                "Get the UV index in \(.applicationName)",
                "How strong is the UV in \(.applicationName)"
            ],
            shortTitle: "UV Index",
            systemImageName: "sun.max"
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
