import SwiftUI
import WidgetKit
#if os(iOS)
import UIKit
import UserNotifications
import BackgroundTasks
#endif

#if DEBUG
import CoreLocation
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
        
        // Schedule the first background refresh request as soon as the app launches
        scheduleAppRefresh()
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        return true
    }
    
    func handleAppRefresh(task: BGAppRefreshTask) {
        print("🔄 Background refresh task started at \(Date())")

        // iOS best practice: queue the next refresh request
        // *before* doing the work, in case the app is killed
        // mid-task. The interval is computed from the
        // *previous* run's outcome, which the coordinator
        // already tracks via its `consecutiveFailures` counter.
        let priorSucceeded = BackgroundRefreshCoordinator.shared.consecutiveFailures == 0
        BackgroundRefreshCoordinator.shared.scheduleNextRefresh(
            taskIdentifier: Self.backgroundTaskIdentifier,
            previousSucceeded: priorSucceeded
        )

        let refreshTask = Task { () -> Bool in
            // Pre-flight: if the device is clearly offline, do
            // not waste the iOS background budget on a
            // guaranteed-to-fail HTTP request. We still
            // re-schedule (handled by the coordinator) and
            // reload timelines so the widget can fall back to
            // its own network path on the next tick.
            let snapshot = NetworkMonitor.shared.currentSnapshot()
            if !snapshot.isConnected {
                print("📵 Background refresh: device offline, skipping network call (type: \(snapshot.connectionType.rawValue))")
                WidgetCenter.shared.reloadAllTimelines()
                return false
            }

            let didRefreshStation = await self.refreshStationWeatherForWidget()

            if let coordinates = self.getBackgroundCoordinates() {
                print("📍 Background refresh: Location \(coordinates.latitude), \(coordinates.longitude)")
                await WeatherAlertManager.shared.fetchAlerts(latitude: coordinates.latitude, longitude: coordinates.longitude)
            } else {
                print("⚠️ Background refresh: no saved coordinates available for alerts")
            }

            // If the station refresh failed, explicitly mark
            // the cached widget data as invalid so the widget
            // triggers its own fresh fetch on the next timeline
            // reload instead of serving a stale cache.
            if !didRefreshStation {
                WidgetSyncService.shared.invalidateWidgetData()
            }

            WidgetCenter.shared.reloadAllTimelines()
            print("✅ Background refresh completed and widget timelines reloaded (station updated: \(didRefreshStation))")
            return didRefreshStation
        }

        task.expirationHandler = {
            print("⚠️ Background task expired")
            refreshTask.cancel()
        }

        Task {
            let success = await refreshTask.value
            let finalSuccess = success && !Task.isCancelled
            task.setTaskCompleted(success: finalSuccess)
            // Record the outcome of *this* run so the next
            // `scheduleNextRefresh(...)` call uses an interval
            // that reflects it. The request we already queued
            // at the start of `handleAppRefresh` has a fixed
            // `earliestBeginDate`; the counter steers the one
            // *after* that.
            BackgroundRefreshCoordinator.shared.recordOutcome(success: finalSuccess)
        }
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("🔄 Background fetch invoked")
        // Mirror the BGAppRefreshTask behaviour: queue the
        // next request before doing the work, base the
        // interval on the previous run's outcome, and use the
        // network monitor to avoid a wasted HTTP call.
        let priorSucceeded = BackgroundRefreshCoordinator.shared.consecutiveFailures == 0
        BackgroundRefreshCoordinator.shared.scheduleNextRefresh(
            taskIdentifier: Self.backgroundTaskIdentifier,
            previousSucceeded: priorSucceeded
        )

        Task {
            // Pre-flight network check: skip the call entirely
            // if the device is clearly offline.
            let snapshot = NetworkMonitor.shared.currentSnapshot()
            if !snapshot.isConnected {
                print("📵 Background fetch: device offline, skipping network call (type: \(snapshot.connectionType.rawValue))")
                WidgetCenter.shared.reloadAllTimelines()
                BackgroundRefreshCoordinator.shared.recordOutcome(success: false)
                completionHandler(.noData)
                return
            }

            let didRefreshStation = await self.refreshStationWeatherForWidget()

            if let coordinates = self.getBackgroundCoordinates() {
                print("📍 Background fetch: Location \(coordinates.latitude), \(coordinates.longitude)")
                await WeatherAlertManager.shared.fetchAlerts(latitude: coordinates.latitude, longitude: coordinates.longitude)
            } else {
                print("⚠️ Background fetch: no saved coordinates available for alerts")
            }

            // If the station refresh failed, explicitly mark
            // the cached widget data as invalid so the widget
            // triggers its own fresh fetch on the next timeline
            // reload instead of serving a stale cache.
            if !didRefreshStation {
                WidgetSyncService.shared.invalidateWidgetData()
            }

            WidgetCenter.shared.reloadAllTimelines()
            BackgroundRefreshCoordinator.shared.recordOutcome(success: didRefreshStation)
            print("✅ Background fetch completed and widget timelines reloaded (station updated: \(didRefreshStation))")
            completionHandler(didRefreshStation ? .newData : .noData)
        }
    }

    /// Schedule a background refresh using the base interval
    /// (i.e. **without** applying the backoff). This is the
    /// right entry point for app-lifecycle hooks (launch,
    /// foreground, background) where the user is presumably
    /// present and we want a prompt refresh.
    ///
    /// Task-completion callers should use
    /// `BackgroundRefreshCoordinator.scheduleNextRefresh(...)`
    /// directly instead, so the interval reflects the
    /// previous run's outcome.
    func scheduleAppRefresh() {
        BackgroundRefreshCoordinator.shared.scheduleAppRefresh(
            taskIdentifier: Self.backgroundTaskIdentifier
        )
    }

    private func getBackgroundCoordinates() -> (latitude: Double, longitude: Double)? {
        let sharedDefaults = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
        let useGPS = UserDefaults.standard.bool(forKey: "useGPS")
        
        if useGPS {
            if let latString = sharedDefaults?.string(forKey: "lastKnownLatitude"),
               let lonString = sharedDefaults?.string(forKey: "lastKnownLongitude"),
               let latitude = Double(latString),
               let longitude = Double(lonString) {
                // Validate coordinates using our new validator
                let validationResult = CoordinateValidator.validate(latitude: latitude, longitude: longitude)
                if validationResult.isValid {
                    return (validationResult.normalizedLatitude ?? latitude, validationResult.normalizedLongitude ?? longitude)
                }
            }
        }
        
        if let latString = UserDefaults.standard.string(forKey: "latitude"),
           let lonString = UserDefaults.standard.string(forKey: "longitude"),
           let latitude = Double(latString),
           let longitude = Double(lonString) {
            // Validate coordinates using our new validator
            let validationResult = CoordinateValidator.validate(latitude: latitude, longitude: longitude)
            if validationResult.isValid {
                return (validationResult.normalizedLatitude ?? latitude, validationResult.normalizedLongitude ?? longitude)
            }
        }
        
        if let latString = sharedDefaults?.string(forKey: "latitude"),
           let lonString = sharedDefaults?.string(forKey: "longitude"),
           let latitude = Double(latString),
           let longitude = Double(lonString) {
            // Validate coordinates using our new validator
            let validationResult = CoordinateValidator.validate(latitude: latitude, longitude: longitude)
            if validationResult.isValid {
                return (validationResult.normalizedLatitude ?? latitude, validationResult.normalizedLongitude ?? longitude)
            }
        }
        
        return nil
    }
    
    private func refreshStationWeatherForWidget() async -> Bool {
        let disableAPIKeys = UserDefaults.standard.bool(forKey: "disableAPIKeys")
        guard !disableAPIKeys,
              let apiKey = KeychainService.shared.getApiKey(forService: "wu"),
              !apiKey.isEmpty else {
            return false
        }
        
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        guard !stationID.isEmpty else { return false }
        
        var components = URLComponents(string: "https://api.weather.com/v2/pws/observations/current")
        components?.queryItems = [
            URLQueryItem(name: "stationId", value: stationID),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "units", value: "m"),
            URLQueryItem(name: "numericPrecision", value: "decimal"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        guard let url = components?.url else { return false }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("⚠️ Background station refresh failed: HTTP \(httpResponse.statusCode)")
                return false
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let wuResponse = try decoder.decode(WUResponse.self, from: data)
            guard let observation = wuResponse.observations.first else { return false }
            
            saveStationWeatherForWidget(observation)
            print("✅ Background station weather refreshed for widget")
            return true
        } catch {
            print("⚠️ Background station refresh failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private func saveStationWeatherForWidget(_ observation: WUObservation) {
        let sharedDefaults = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
        let unitSystem = UserDefaults.standard.string(forKey: "unitSystem") ?? "Metric"
        let now = Date()

        // Resolve the *current effective* coordinates: manual
        // mode wins if set, otherwise fall back to the last
        // known GPS coordinates. The previous implementation
        // stamped the cache with last-known GPS coordinates
        // unconditionally, which left a stale stamp when the
        // user was actually in manual mode – the widget would
        // then either fail to detect a real location change
        // or falsely detect one when none happened.
        let useGPS = UserDefaults.standard.bool(forKey: "useGPS")
        let effectiveLatString: String? = {
            if useGPS {
                return sharedDefaults?.string(forKey: "lastKnownLatitude")
                    ?? UserDefaults.standard.string(forKey: "lastKnownLatitude")
            } else {
                return UserDefaults.standard.string(forKey: "latitude")
                    ?? sharedDefaults?.string(forKey: "latitude")
            }
        }()
        let effectiveLonString: String? = {
            if useGPS {
                return sharedDefaults?.string(forKey: "lastKnownLongitude")
                    ?? UserDefaults.standard.string(forKey: "lastKnownLongitude")
            } else {
                return UserDefaults.standard.string(forKey: "longitude")
                    ?? sharedDefaults?.string(forKey: "longitude")
            }
        }()
        let effectiveLat = effectiveLatString.flatMap(Double.init)
        let effectiveLon = effectiveLonString.flatMap(Double.init)
        let currentWidgetDataVersion = sharedDefaults?
            .integer(forKey: WidgetSyncService.Keys.widgetDataVersion) ?? 0

        var widgetData = loadLatestWidgetWeatherData()
        widgetData["lastUpdate"] = now.timeIntervalSince1970
        widgetData["lastUpdateDate"] = now.timeIntervalSince1970
        widgetData["unitSystem"] = unitSystem
        widgetData["dataSource"] = "weatherunderground"
        widgetData["stationID"] = observation.stationID
        // Bake the current `widgetDataVersion` so the widget
        // can detect host-app state changes (unit system, GPS
        // coords, data source) even when the cache timestamp
        // is still fresh.
        widgetData["widgetDataVersion"] = currentWidgetDataVersion
        widgetData["condition"] = widgetData["condition"] as? String ?? "Weather Station"
        widgetData["humidity"] = observation.humidity
        widgetData["uvIndex"] = Int(observation.uv)

        var temperature = observation.metric.temp
        var feelsLike = observation.metric.heatIndex
        var windSpeed = observation.metric.windSpeed
        var pressure = observation.metric.pressure

        if unitSystem == "Imperial" {
            temperature = temperature * 9 / 5 + 32
            feelsLike = feelsLike * 9 / 5 + 32
            windSpeed = windSpeed * 0.621371
            pressure = pressure * 0.02953
        } else if unitSystem == "UK" {
            windSpeed = windSpeed * 0.621371
        }

        widgetData["temperature"] = temperature
        widgetData["feelsLike"] = feelsLike
        widgetData["windSpeed"] = windSpeed
        widgetData["pressure"] = pressure

        if let jsonData = try? JSONSerialization.data(withJSONObject: widgetData, options: []) {
            sharedDefaults?.set(jsonData, forKey: "latestWeather")
        }

        // Push unit / GPS / source preferences into the shared
        // defaults and stamp the cache with the unit system the
        // payload was generated in, so the widget can later detect
        // a unit-system mismatch and force a fresh fetch.
        WidgetSyncService.shared.syncAll(
            unitSystem: unitSystem,
            useGPS: useGPS,
            manualLatitude: useGPS ? nil : UserDefaults.standard.string(forKey: "latitude"),
            manualLongitude: useGPS ? nil : UserDefaults.standard.string(forKey: "longitude"),
            lastKnownLatitude: useGPS
                ? (sharedDefaults?.string(forKey: "lastKnownLatitude")
                    ?? UserDefaults.standard.string(forKey: "lastKnownLatitude")) : nil,
            lastKnownLongitude: useGPS
                ? (sharedDefaults?.string(forKey: "lastKnownLongitude")
                    ?? UserDefaults.standard.string(forKey: "lastKnownLongitude")) : nil,
            useOpenMeteoAsDefault: UserDefaults.standard.bool(forKey: "useOpenMeteoAsDefault")
        )
        // Stamp the cache with the *current effective*
        // coordinates (manual or last-known GPS depending on
        // `useGPS`) and the current `widgetDataVersion`. The
        // widget uses these to detect a unit-system mismatch,
        // a coordinate drift, or a host-app state change
        // (version bump) and force a fresh fetch.
        WidgetSyncService.shared.stampCachedPayload(
            latitude: effectiveLat,
            longitude: effectiveLon,
            unitSystem: unitSystem
        )
        // The cache is now fresh – clear any prior "data
        // invalidated" marker the host may have set after a
        // previous failed background refresh.
        WidgetSyncService.shared.clearInvalidation()
        // Flip the "host has ever saved a payload" flag the
        // widget uses to pick the right "no data" copy.
        // Idempotent; only writes on the very first success.
        WidgetSyncService.shared.markHasEverFetched()
    }
    
    private func loadLatestWidgetWeatherData() -> [String: Any] {
        let sharedDefaults = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
        guard let data = sharedDefaults?.data(forKey: "latestWeather"),
              let weatherData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return [:]
        }
        
        return weatherData
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
                    // Bootstrap widget sync: push the current
                    // unit system, GPS flag, data source
                    // preference and coordinates atomically into
                    // the shared App Group defaults. This
                    // guarantees the widget sees a consistent
                    // snapshot the first time the host app
                    // launches and prevents a stale "first
                    // appearance" with mismatched units.
                    let shared = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
                    WidgetSyncService.shared.syncAll(
                        unitSystem: UserDefaults.standard.string(forKey: "unitSystem") ?? "Metric",
                        useGPS: UserDefaults.standard.bool(forKey: "useGPS"),
                        manualLatitude: UserDefaults.standard.string(forKey: "latitude"),
                        manualLongitude: UserDefaults.standard.string(forKey: "longitude"),
                        lastKnownLatitude: UserDefaults.standard.string(forKey: "lastKnownLatitude")
                            ?? shared?.string(forKey: "lastKnownLatitude"),
                        lastKnownLongitude: UserDefaults.standard.string(forKey: "lastKnownLongitude")
                            ?? shared?.string(forKey: "lastKnownLongitude"),
                        useOpenMeteoAsDefault: UserDefaults.standard.bool(forKey: "useOpenMeteoAsDefault")
                    )

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
