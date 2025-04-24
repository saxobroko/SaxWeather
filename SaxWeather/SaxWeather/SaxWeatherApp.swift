import SwiftUI

@main
struct SaxWeatherApp: App {
    // Create the shared instances
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var weatherService = WeatherService()
    
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
                .environmentObject(storeManager)
                .environmentObject(weatherService)
                .onAppear {
                    // Fetch weather and forecast data when the app appears
                    Task {
                        await weatherService.fetchWeather()
                        await weatherService.fetchForecasts()
                    }
                }
        }
    }
}
