import SwiftUI
import WidgetKit
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
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleAppRefresh(task: appRefreshTask)
        }
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        return true
    }
    
    func handleAppRefresh(task: BGAppRefreshTask) {
        print("🔄 Background refresh task started at \(Date())")
        
        // Schedule the next background refresh
        scheduleAppRefresh()
        
        // Create a background task
        task.expirationHandler = {
            print("⚠️ Background task expired")
            // Clean up any ongoing tasks
            task.setTaskCompleted(success: false)
        }
        
        // Get location from UserDefaults with validation
        guard let latString = UserDefaults.standard.string(forKey: "latitude"),
              let lonString = UserDefaults.standard.string(forKey: "longitude"),
              let lat = Double(latString),
              let lon = Double(lonString),
              abs(lat) <= 90,
              abs(lon) <= 180 else {
            print("❌ Background refresh: Invalid location")
            task.setTaskCompleted(success: false)
            return
        }
        
        print("📍 Background refresh: Location \(lat), \(lon)")
        
        // Fetch weather alerts in background
        WeatherAlertManager.shared.fetchAlertsInBackground(latitude: lat, longitude: lon) { rainExpected in
            print("✅ Background refresh completed - rain expected: \(rainExpected)")
            
            // Reload all widget timelines after fetching new data
            WidgetCenter.shared.reloadAllTimelines()
            print("🔄 Widgets reloaded after background refresh")
            
            task.setTaskCompleted(success: true)
        }
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        // Reduced to 5 minutes to keep widget data fresh
        // iOS will respect this as a minimum, but may delay based on system conditions
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background refresh scheduled for \(Date(timeIntervalSinceNow: 5 * 60))")
        } catch {
            print("❌ Could not schedule app refresh: \(error)")
        }
    }
}
#endif

@main
struct SaxWeatherApp: App {
    // Create the shared instances
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var weatherService = WeatherService()
    @AppStorage("accentColor") private var accentColor = "blue"
    @Environment(\.scenePhase) private var scenePhase
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
                .tint(accentColorValue) // Apply user's selected accent color
                .onAppear {
                    // Fetch weather and forecast data when the app appears
                    Task {
                        await weatherService.fetchWeather(calledFrom: "SaxWeatherApp.onAppear")
                        await weatherService.fetchForecasts()
                    }
                    
                    #if os(iOS)
                    // Schedule background refresh
                    appDelegate.scheduleAppRefresh()
                    
                    // Force widget reload when app opens
                    WidgetCenter.shared.reloadAllTimelines()
                    print("🔄 Widgets reloaded on app launch")
                    #endif
                }
                .onChange(of: scenePhase) { newPhase in
                    #if os(iOS)
                    switch newPhase {
                    case .active:
                        // App became active - reload widgets with fresh data
                        WidgetCenter.shared.reloadAllTimelines()
                        print("🔄 Widgets reloaded - app became active")
                        
                        // Re-schedule background refresh
                        appDelegate.scheduleAppRefresh()
                        
                    case .background:
                        // App went to background - schedule next refresh
                        appDelegate.scheduleAppRefresh()
                        print("📱 App entered background - scheduled next refresh")
                        
                    default:
                        break
                    }
                    #endif
                }
        }
    }
    
    // Convert accent color string to Color
    private var accentColorValue: Color {
        switch accentColor.lowercased() {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "teal": return .teal
        case "cyan": return .cyan
        case "indigo": return .indigo
        default: return .blue
        }
    }
}
