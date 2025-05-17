import SwiftUI
#if os(iOS)
import UIKit
import UserNotifications
#endif

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        return true
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Get location from UserDefaults
        let lat = Double(UserDefaults.standard.string(forKey: "latitude") ?? "") ?? 0
        let lon = Double(UserDefaults.standard.string(forKey: "longitude") ?? "") ?? 0
        guard lat != 0, lon != 0 else {
            completionHandler(.failed)
            return
        }
        WeatherAlertManager.shared.fetchAlertsInBackground(latitude: lat, longitude: lon) { rainExpected in
            completionHandler(rainExpected ? .newData : .noData)
        }
    }
}
#endif

@main
struct SaxWeatherApp: App {
    // Create the shared instances
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var weatherService = WeatherService()
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    init() {
        // Register default values for UserDefaults
        let defaults: [String: Any] = [
            "forecastDays": 7
        ]
        UserDefaults.standard.register(defaults: defaults)
        
        // Set up custom tab bar appearance (iOS only)
        #if os(iOS)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterialDark)
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.3) // Subtle, modern tint with blur
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        #endif
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
