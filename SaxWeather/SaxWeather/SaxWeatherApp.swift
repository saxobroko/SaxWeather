import SwiftUI
#if os(iOS)
import UIKit
import UserNotifications
import BackgroundTasks
#endif

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    static let backgroundTaskIdentifier = "com.saxobroko.SaxWeather.refresh"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.backgroundTaskIdentifier, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        return true
    }
    
    func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next background refresh
        scheduleAppRefresh()
        
        // Create a background task
        task.expirationHandler = {
            // Clean up any ongoing tasks
            task.setTaskCompleted(success: false)
        }
        
        // Get location from UserDefaults
        let lat = Double(UserDefaults.standard.string(forKey: "latitude") ?? "") ?? 0
        let lon = Double(UserDefaults.standard.string(forKey: "longitude") ?? "") ?? 0
        
        guard lat != 0, lon != 0 else {
            task.setTaskCompleted(success: false)
            return
        }
        
        // Fetch weather alerts in background
        WeatherAlertManager.shared.fetchAlertsInBackground(latitude: lat, longitude: lon) { rainExpected in
            task.setTaskCompleted(success: true)
        }
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
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
                    
                    #if os(iOS)
                    // Schedule background refresh
                    appDelegate.scheduleAppRefresh()
                    #endif
                }
        }
    }
}
