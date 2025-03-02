import SwiftUI

@main
struct SaxWeatherApp: App {
    @StateObject private var storeManager = StoreManager.shared
    
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
                .environmentObject(storeManager)  // Add this line to inject StoreManager into the environment
        }
    }
}
