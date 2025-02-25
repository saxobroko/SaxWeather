import SwiftUI

@main
struct SaxWeatherApp: App {
    init() {
        // Register default values for UserDefaults
        let defaults: [String: Any] = [
            "forecastDays": 7
        ]
        UserDefaults.standard.register(defaults: defaults)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
