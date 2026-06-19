//
//  WeatherService.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-25 04:49:47
//

import Foundation
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var weather: Weather?
    @Published var forecast: WeatherForecast?
    /// Typed error from the most recent failed fetch. `nil` when
    /// the last fetch succeeded or no fetch has been attempted
    /// yet. The UI layer should prefer the structured
    /// `WeatherError` over the legacy string description so it
    /// can pick a category-specific message via
    /// `WeatherError.presentation`.
    @Published var error: WeatherError?
    @Published var isLoading = false
    @Published private(set) var _useGPS: Bool
    @Published private(set) var _unitSystem: String
    @Published var showLocationAlert = false
    @Published var currentBackgroundCondition: String = "default"
    @Published var hourlyData: [HourlyWeatherData] = []
    
    let locationManager: CLLocationManager
    private var locationTimeoutWorkItem: DispatchWorkItem?
    var currentDataSource: String = "unknown" // Track which service provided current weather data
    var forecastDataSource: String = "unknown" // Track which service provided forecast data
    var fetchTask: Task<Void, Never>? = nil // Track current fetch task
    var lastFetchTime: Date? = nil // Track last fetch time for debouncing
    var forecastFetchTask: Task<Void, Never>? = nil // Track current forecast fetch task
    var lastForecastFetchTime: Date? = nil // Track last forecast fetch time for debouncing
    /// Timestamp of the most recent successful weather fetch.
    /// `nil` until the first fetch completes. Distinct from
    /// `lastFetchTime` (which is updated when a fetch *starts*,
    /// for debouncing) — this is set only after a fresh payload
    /// has been decoded and saved. Used by the host-app stale
    /// data warning so the UI can react when the cached data
    /// becomes too old to be useful.
    @Published var lastSuccessfulFetch: Date?

    /// The user's current geographic location, mirrored from
    /// `CLLocationManager` so SwiftUI views can react to
    /// location changes without having to talk to CoreLocation
    /// directly. `nil` until the first GPS fix arrives or a
    /// manual coordinate is restored from `UserDefaults`.
    @Published var currentLocation: CLLocationCoordinate2D?
    
    var unitSystem: String {
        get { _unitSystem }
        set {
            DispatchQueue.main.async {
                self._unitSystem = newValue
                UserDefaults.standard.set(newValue, forKey: "unitSystem")
                Self.syncWidgetSettingsToSharedDefaults(unitSystem: newValue, useGPS: self._useGPS)
                Task {
                    await self.fetchWeather(calledFrom: "unitSystem.setter")
                }
            }
        }
    }
    
    var useGPS: Bool {
        get { _useGPS }
        set {
            // Only check authorization status when enabling GPS
            if newValue {
                let status = locationManager.authorizationStatus
                switch status {
                case .denied, .restricted:
                    // If permissions are denied, show alert
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self._useGPS = false
                        UserDefaults.standard.set(false, forKey: "useGPS")
                        self.showLocationAlert = true
                    }
                    return
                case .notDetermined:
                    // Request permission
                    locationManager.requestWhenInUseAuthorization()
                    return
                case .authorizedWhenInUse, .authorizedAlways:
                    // Permission already granted, proceed
                    break
                @unknown default:
                    break
                }
                
                // IMPORTANT: When enabling GPS with API keys active, clear saved coordinates
                // This ensures extended weather uses GPS location, not stale custom location
                print("🧹 GPS enabled - clearing any saved custom location coordinates")
                UserDefaults.standard.removeObject(forKey: "latitude")
                UserDefaults.standard.removeObject(forKey: "longitude")
                
                // Important: Ensure the locations manager knows GPS is selected
                // This will update the UI to show "Current Location" as selected
                UserDefaults.standard.set(true, forKey: "useGPS")
            }
            
            // Update the value
            _useGPS = newValue
            UserDefaults.standard.set(newValue, forKey: "useGPS")
            Self.syncWidgetSettingsToSharedDefaults(unitSystem: unitSystem, useGPS: newValue)

            if newValue {
                requestLocation()
            } else {
                // Stop location updates when disabling GPS
                locationManager.stopUpdatingLocation()

                // Switch to manual mode: seed `currentLocation`
                // from the saved coordinates so views stay
                // accurate even after switching away from GPS.
                // If no manual coordinates are saved, leave
                // `currentLocation` unchanged — the last GPS fix
                // (or `nil`) is still the best hint we have.
                let savedLat = UserDefaults.standard.string(forKey: "latitude") ?? ""
                let savedLon = UserDefaults.standard.string(forKey: "longitude") ?? ""
                if !savedLat.isEmpty, !savedLon.isEmpty,
                   let lat = Double(savedLat), let lon = Double(savedLon) {
                    self.currentLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            }
            
            // Refresh weather data when GPS setting changes
            Task {
                await fetchWeather(calledFrom: "useGPS.setter")
            }
        }
    }
    
    override init() {
        // Default to using GPS, read from UserDefaults if available
        self._unitSystem = UserDefaults.standard.string(forKey: "unitSystem") ?? "Metric"

        // Reconcile the health monitor with whatever keys are
        // currently in the keychain. New keys get a fresh
        // fingerprint; missing keys have their entries purged.
        APIKeyHealthMonitor.shared.purgeStaleEntries()
        for service in APIKeyService.allCases {
            APIKeyHealthMonitor.shared.refreshFingerprint(for: service)
        }
        
        // Set useGPS to true by default (or if saved coords are empty)
        let savedLat = UserDefaults.standard.string(forKey: "latitude") ?? ""
        let savedLon = UserDefaults.standard.string(forKey: "longitude") ?? ""
        let hasCoordinates = !savedLat.isEmpty && !savedLon.isEmpty
        
        if UserDefaults.standard.object(forKey: "useGPS") != nil {
            // User has set preference, but validate if they chose manual mode
            let userChoice = UserDefaults.standard.bool(forKey: "useGPS")
            self._useGPS = userChoice || !hasCoordinates // Force GPS if no coordinates
        } else {
            // First launch - default to GPS
            self._useGPS = true
            UserDefaults.standard.set(true, forKey: "useGPS")
        }

        // Initialise `currentLocation` from the best available
        // source so the app has a usable location on cold
        // start. Prefer the last known GPS fix (most recent GPS
        // read) and fall back to the user's saved manual
        // coordinates. Both are seeded synchronously here, then
        // the real delegate callbacks will refine the value as
        // CoreLocation warms up.
        let lastKnownLat = UserDefaults.standard.string(forKey: "lastKnownLatitude") ?? ""
        let lastKnownLon = UserDefaults.standard.string(forKey: "lastKnownLongitude") ?? ""
        if let lat = Double(lastKnownLat), let lon = Double(lastKnownLon),
           !lastKnownLat.isEmpty, !lastKnownLon.isEmpty {
            self.currentLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else if hasCoordinates,
                  let lat = Double(savedLat), let lon = Double(savedLon) {
            self.currentLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        self.locationManager = CLLocationManager()
        super.init()

        Self.syncWidgetSettingsToSharedDefaults(
            unitSystem: _unitSystem,
            useGPS: _useGPS
        )

        locationManager.delegate = self
        
        // If using GPS, immediately request location permissions
        if _useGPS {
            requestLocation()
        }
    }
    
    // MARK: - Weather Methods
    @MainActor
    func fetchWeather(calledFrom: String = "unknown") async {
        // Debounce: Skip if last fetch was less than 2 seconds ago
        if let lastFetch = lastFetchTime, Date().timeIntervalSince(lastFetch) < 2.0 {
            print("⏭️  Skipping fetch from \(calledFrom) - too soon since last request (\(String(format: "%.1f", Date().timeIntervalSince(lastFetch)))s ago)")
            return
        }
        
        print("📍 Fetch initiated from: \(calledFrom)")
        
        // Cancel any existing fetch task
        if let existingTask = fetchTask {
            print("⏸️  Cancelling previous fetch task")
            existingTask.cancel()
        }
        
        // Create new fetch task
        let task = Task { @MainActor in
            guard !Task.isCancelled else {
                print("⏸️  Fetch cancelled - new request started")
                return
            }

            // Pre-flight network check. If the device is clearly
            // offline, fail fast with a typed `WeatherError.noNetwork`
            // so the UI can show the right message and avoid
            // burning the URL session timeout budget on a request
            // that cannot possibly succeed. The check is a
            // snapshot, not a guarantee — if the network drops
            // mid-request the URL session will still surface its
            // own error and we'll catch it below.
            if !NetworkMonitor.shared.currentSnapshot().isConnected {
                self.error = .noNetwork
                self.isLoading = false
                #if canImport(UIKit)
                HapticFeedbackHelper.shared.error()
                #endif
                print("📡 Fetch aborted pre-flight: device is offline")
                return
            }

            self.lastFetchTime = Date()
            self.isLoading = true
            self.error = nil

            do {
                let weatherData = try await self.fetchWeatherData()

                guard !Task.isCancelled else {
                    print("⏸️  Fetch cancelled after data received")
                    return
                }

                self.weather = weatherData
                self.lastSuccessfulFetch = Date()
                print("✅ Weather data updated on main thread - Temp: \(weatherData.temperature ?? 0)°, Source: \(self.currentDataSource)")

                // Update background immediately based on current weather condition
                self.updateBackgroundCondition()

                self.isLoading = false

                // Success haptic feedback
                #if canImport(UIKit)
                HapticFeedbackHelper.shared.success()
                #endif

                self.saveWeatherDataForWidget(weatherData)

                // Fetch extended weather data (AQI, sun/moon, etc.)
                await self.fetchExtendedWeatherData()

                // Fetch forecast data based on the data source used
                await self.fetchForecasts()

                // Update background again after forecast is loaded (for more accurate background)
                self.updateBackgroundCondition()
            } catch {
                guard !Task.isCancelled else { return }

                // Funnel every thrown error through `WeatherError.from(_:)`
                // so the UI always sees a typed error. URLError values
                // (offline, timeout, etc.) and CLError values
                // (denied, restricted, etc.) get mapped to the
                // matching WeatherError case.
                self.error = WeatherError.from(error)
                self.isLoading = false

                // Error haptic feedback
                #if canImport(UIKit)
                HapticFeedbackHelper.shared.error()
                #endif
            }
        }
        
        fetchTask = task
        await task.value
    }
    
    // MARK: - Location Coordinates Helper
    /// Get the correct coordinates for weather data and alerts
    /// Returns the GPS location, custom location, or station location based on settings
    func getCoordinates() async -> (latitude: Double, longitude: Double)? {
        // Check if API keys are disabled
        let disableAPIKeys = UserDefaults.standard.bool(forKey: "disableAPIKeys")
        
        print("🔍 getCoordinates() called:")
        print("   - useGPS: \(useGPS)")
        print("   - disableAPIKeys: \(disableAPIKeys)")
        
        // If using Weather Underground or OpenWeatherMap (and API keys not disabled),
        // those services use their own station/location, so we use saved coordinates
        let wuApiKey = disableAPIKeys ? "" : (KeychainService.shared.getApiKey(forService: "wu") ?? "")
        let stationID = disableAPIKeys ? "" : (UserDefaults.standard.string(forKey: "stationID") ?? "")
        let owmApiKey = disableAPIKeys ? "" : (KeychainService.shared.getApiKey(forService: "owm") ?? "")
        
        let hasWU = !wuApiKey.isEmpty && !stationID.isEmpty
        let hasOWM = !owmApiKey.isEmpty
        
        print("   - hasWU: \(hasWU), hasOWM: \(hasOWM)")
        
        // Check saved coordinates
        let savedLat = UserDefaults.standard.string(forKey: "latitude") ?? ""
        let savedLon = UserDefaults.standard.string(forKey: "longitude") ?? ""
        let hasSavedCoords = !savedLat.isEmpty && !savedLon.isEmpty
        print("   - Has saved coordinates: \(hasSavedCoords) (lat='\(savedLat)', lon='\(savedLon)')")
        
        // IMPORTANT: When API keys are enabled, they provide location-specific data
        // We should NOT use old custom location coordinates - use GPS instead
        
        // Priority 1: API keys with saved coordinates (WU station or OWM location)
        // Only use saved coords if they're from the API service itself
        if (hasWU || hasOWM) && hasSavedCoords && !useGPS {
            // Saved coordinates from API service (station location)
            if let lat = Double(savedLat), let lon = Double(savedLon) {
                print("✅ Using API service coordinates: \(lat), \(lon)")
                return (lat, lon)
            }
        }
        
        // Priority 2: GPS location (if enabled OR if API keys are active but no saved coords)
        if useGPS || (hasWU || hasOWM) {
            if let location = locationManager.location {
                let coords = (location.coordinate.latitude, location.coordinate.longitude)
                print("✅ Using GPS location: \(coords.0), \(coords.1)")
                return coords
            } else if useGPS {
                print("⏳ GPS enabled but location not available, requesting...")
                requestLocation()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                
                if let location = locationManager.location {
                    let coords = (location.coordinate.latitude, location.coordinate.longitude)
                    print("✅ GPS location now available: \(coords.0), \(coords.1)")
                    return coords
                }
            }
        }
        
        // Priority 3: Custom location coordinates (only when API keys disabled and GPS off)
        if !hasWU && !hasOWM && !useGPS && hasSavedCoords {
            if let lat = Double(savedLat), let lon = Double(savedLon) {
                print("✅ Using custom location coordinates: \(lat), \(lon)")
                return (lat, lon)
            }
        }
        
        print("❌ No coordinates available!")
        return nil
    }
    
    // MARK: - Extended Weather Data Fetching
    @MainActor
    private func fetchExtendedWeatherData() async {
        guard let coordinates = await getCoordinates() else {
            print("⚠️ No coordinates available for extended weather data")
            return
        }

        // Respect the user's data plan. The extended payload
        // (AQI, pollen, sun/moon, hourly precipitation) is the
        // largest single fetch in the app — skip it on
        // expensive networks and when Low Data Mode is on.
        // The basic weather + forecast still fetch normally.
        guard NetworkMonitor.shared.shouldFetchExtendedForecast else {
            print("📵 Skipping extended forecast fetch — network quality: \(NetworkMonitor.shared.quality)")
            return
        }

        print("� fetchExtendedWeatherData() called:")
        print("   - Coordinates: \(coordinates.latitude), \(coordinates.longitude)")
        print("   - Current data source: \(self.currentDataSource)")
        print("   - Current weather exists: \(self.weather != nil)")
        
        do {
            // Pass the current data source to respect priority system
            let (airQuality, pollen, sunMoon, hourlyPrecip) = try await ExtendedWeatherService.shared.fetchExtendedData(
                latitude: coordinates.latitude,
                longitude: coordinates.longitude,
                dataSource: self.currentDataSource,
                existingWeather: self.weather
            )
            
            print("📦 Extended data received:")
            print("   - Air Quality: \(airQuality != nil ? "AQI \(airQuality!.aqi)" : "nil")")
            print("   - Pollen: \(pollen != nil ? "Available" : "nil")")
            print("   - Sun/Moon: \(sunMoon != nil ? "Available" : "nil")")
            print("   - Hourly Precip: \(hourlyPrecip.count) items")
            
            // Update weather with extended data. Without
            // mutating `currentWeather` to actually carry the
            // AQI / sun-moon / hourly-precip values, the
            // reassignment below is a no-op and the UI would
            // never see the extended payload.
            if var currentWeather = self.weather {
                currentWeather.airQuality = airQuality
                currentWeather.sunData = sunMoon
                currentWeather.pollen = pollen
                currentWeather.hourlyPrecipitation = hourlyPrecip

                // Reassign through the @Published property so
                // SwiftUI subscribers receive an update event.
                self.weather = currentWeather

                // Explicitly trigger objectWillChange to ensure
                // UI updates even if the new values happen to
                // equal the previous ones.
                self.objectWillChange.send()

                print("✅ Weather object updated with extended data")

                #if DEBUG
                print("✅ Extended weather data fetched (via \(self.currentDataSource)):")
                print("   - Air Quality: \(airQuality?.aqi ?? -1) AQI")
                print("   - Sun/Moon: \(sunMoon != nil ? "Available" : "Not available")")
                print("   - Hourly precipitation: \(hourlyPrecip.count) hours")
                #endif
            } else {
                print("⚠️ Could not update weather - weather object is nil")
            }
        } catch {
            print("⚠️ Failed to fetch extended weather data: \(error)")
            // Don't fail the whole weather fetch if extended data fails
        }
    }
    
    // MARK: - Widget Data Sharing
    func saveWeatherDataForWidget(_ weather: Weather) {
        let sharedDefaults = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")

        // Resolve the coordinates that were actually used for this
        // fetch – they are what the cache should be stamped with so
        // the widget can later detect a location drift.
        var resolvedLatitude: Double?
        var resolvedLongitude: Double?
        if useGPS, let location = locationManager.location {
            resolvedLatitude = location.coordinate.latitude
            resolvedLongitude = location.coordinate.longitude
        } else if let latString = UserDefaults.standard.string(forKey: "latitude"),
                  let lonString = UserDefaults.standard.string(forKey: "longitude"),
                  let lat = Double(latString), let lon = Double(lonString) {
            resolvedLatitude = lat
            resolvedLongitude = lon
        }

        // Push unit / GPS / data-source / coordinates atomically.
        WidgetSyncService.shared.syncAll(
            unitSystem: unitSystem,
            useGPS: useGPS,
            manualLatitude: useGPS ? nil : UserDefaults.standard.string(forKey: "latitude"),
            manualLongitude: useGPS ? nil : UserDefaults.standard.string(forKey: "longitude"),
            lastKnownLatitude: useGPS ? UserDefaults.standard.string(forKey: "lastKnownLatitude")
                ?? (resolvedLatitude.map { "\($0)" }) : nil,
            lastKnownLongitude: useGPS ? UserDefaults.standard.string(forKey: "lastKnownLongitude")
                ?? (resolvedLongitude.map { "\($0)" }) : nil,
            useOpenMeteoAsDefault: UserDefaults.standard.bool(forKey: "useOpenMeteoAsDefault")
        )

        // Create a simple structure to encode with proper nil handling
        let now = Date()
        let currentWidgetDataVersion = sharedDefaults?
            .integer(forKey: WidgetSyncService.Keys.widgetDataVersion) ?? 0
        var widgetData: [String: Any] = [
            "lastUpdate": now.timeIntervalSince1970,
            "lastUpdateDate": now.timeIntervalSince1970,  // Add explicit lastUpdateDate
            "unitSystem": unitSystem,
            "dataSource": currentDataSource,
            // Bake the current `widgetDataVersion` into the
            // cache so the widget can detect host-app state
            // changes (unit system, GPS coords, data source)
            // even when the cache timestamp is still fresh.
            "widgetDataVersion": currentWidgetDataVersion
        ]

        if currentDataSource == "weatherunderground" {
            widgetData["stationID"] = UserDefaults.standard.string(forKey: "stationID") ?? ""
        }

        if let temp = weather.temperature {
            widgetData["temperature"] = temp
        }
        if let feelsLike = weather.feelsLike {
            widgetData["feelsLike"] = feelsLike
        }

        // Get high/low from today's forecast if available (Weather Underground doesn't provide these)
        if let forecast = self.forecast, let today = forecast.daily.first {
            widgetData["high"] = today.tempMax
            widgetData["low"] = today.tempMin
        } else if let high = weather.high {
            widgetData["high"] = high
        }
        if let low = weather.low, widgetData["low"] == nil {
            widgetData["low"] = low
        }

        if let humidity = weather.humidity {
            widgetData["humidity"] = humidity
        }
        if let windSpeed = weather.windSpeed {
            widgetData["windSpeed"] = windSpeed
        }
        if let uvIndex = weather.uvIndex {
            widgetData["uvIndex"] = uvIndex
        }
        if let pressure = weather.pressure {
            widgetData["pressure"] = pressure
        }

        widgetData["condition"] = weather.condition

        if let jsonData = try? JSONSerialization.data(withJSONObject: widgetData, options: []) {
            sharedDefaults?.set(jsonData, forKey: "latestWeather")

            #if DEBUG
            print("✅ Saved weather data to widget:")
            print("   - Temperature: \(weather.temperature ?? 0)°")
            print("   - High: \(widgetData["high"] as? Double ?? 0)°")
            print("   - Low: \(widgetData["low"] as? Double ?? 0)°")
            print("   - Condition: \(weather.condition)")
            print("   - Unit System: \(unitSystem)")
            print("   - Source: \(forecast != nil ? "Forecast data" : "Weather data")")
            #endif
        }

        // Stamp the cache with the unit system, coordinates,
        // and `widgetDataVersion` it was generated in. The
        // widget uses these stamps to detect a unit-system
        // mismatch, a coordinate drift, or a host-app state
        // change (version bump) and force a fresh fetch.
        WidgetSyncService.shared.stampCachedPayload(
            latitude: resolvedLatitude,
            longitude: resolvedLongitude,
            unitSystem: unitSystem
        )
        // Clear any explicit "data invalidated" marker the
        // host may have written earlier (e.g. after a
        // background-refresh failure). The cache is now fresh.
        WidgetSyncService.shared.clearInvalidation()
        // Flip the "host has ever saved a payload" flag the
        // widget uses to pick the right "no data" copy.
        // Idempotent; only writes on the very first success.
        WidgetSyncService.shared.markHasEverFetched()

        // Also reload widget timelines
        #if canImport(WidgetKit)
        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - Widget Settings Sync (legacy)
    /// Retained as a thin shim for any external callers that still
    /// expect this static entry point. Routes through the
    /// centralised service so behaviour stays consistent.
    private static func syncWidgetSettingsToSharedDefaults(unitSystem: String, useGPS: Bool) {
        let shared = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
        WidgetSyncService.shared.syncAll(
            unitSystem: unitSystem,
            useGPS: useGPS,
            manualLatitude: useGPS ? nil : UserDefaults.standard.string(forKey: "latitude"),
            manualLongitude: useGPS ? nil : UserDefaults.standard.string(forKey: "longitude"),
            lastKnownLatitude: useGPS
                ? (shared?.string(forKey: "lastKnownLatitude")
                    ?? UserDefaults.standard.string(forKey: "lastKnownLatitude")) : nil,
            lastKnownLongitude: useGPS
                ? (shared?.string(forKey: "lastKnownLongitude")
                    ?? UserDefaults.standard.string(forKey: "lastKnownLongitude")) : nil,
            useOpenMeteoAsDefault: UserDefaults.standard.bool(forKey: "useOpenMeteoAsDefault")
        )
    }
    
    @MainActor
    private func fetchWeatherData() async throws -> Weather {
        // Check if API keys are disabled
        let disableAPIKeys = UserDefaults.standard.bool(forKey: "disableAPIKeys")
        
        // Only load API keys if they're not disabled
        let wuApiKey = disableAPIKeys ? "" : (KeychainService.shared.getApiKey(forService: "wu") ?? "")
        let stationID = disableAPIKeys ? "" : (UserDefaults.standard.string(forKey: "stationID") ?? "")
        let owmApiKey = disableAPIKeys ? "" : (KeychainService.shared.getApiKey(forService: "owm") ?? "")
        
        print("\n🌤️  CURRENT WEATHER DATA SOURCE")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        if disableAPIKeys {
            print("🔒 API Keys are DISABLED - skipping Weather Underground and OpenWeatherMap")
        }
        
        // Get location coordinates
        var latitude = ""
        var longitude = ""
        
        if useGPS, let location = locationManager.location {
            latitude = "\(location.coordinate.latitude)"
            longitude = "\(location.coordinate.longitude)"
        } else {
            latitude = UserDefaults.standard.string(forKey: "latitude") ?? ""
            longitude = UserDefaults.standard.string(forKey: "longitude") ?? ""
            
            // If GPS is enabled but location is nil, or if no saved coordinates, request location
            if (useGPS && locationManager.location == nil) || (latitude.isEmpty || longitude.isEmpty) {
                #if DEBUG
                print("⚠️ No valid coordinates available for weather data, requesting location")
                #endif
                requestLocation()
                
                // Wait a moment for location to update
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                if let location = locationManager.location {
                    latitude = "\(location.coordinate.latitude)"
                    longitude = "\(location.coordinate.longitude)"
                }
            }
        }
        
        // Final check for valid coordinates
        guard !latitude.isEmpty && !longitude.isEmpty else {
            throw WeatherError.noData
        }
        
        let lat = latitude
        let lon = longitude
        
        // Try Weather Underground first if configured, unless we
        // already know its key has been rejected.
        let wuBlocked = APIKeyHealthMonitor.shared.hasBlockingIssue(for: .weatherUnderground)
        if !wuApiKey.isEmpty && !stationID.isEmpty {
            if wuBlocked {
                print("⏭️  SKIPPED: Weather Underground (key flagged as invalid; not re-attempting)")
            } else {
                print("📍 Priority 1: Attempting Weather Underground (Station ID: \(stationID))")
                do {
                    if let wuData = try await fetchWUWeather(apiKey: wuApiKey, stationID: stationID) {
                        print("✅ SUCCESS: Using Weather Underground for current conditions")
                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

                        currentDataSource = "weatherunderground"

                        var weather = Weather(
                            wuObservation: wuData,
                            owmCurrent: nil,
                            owmDaily: nil,
                            unitSystem: unitSystem
                        )

                        if unitSystem != "Metric" {
                            weather.convertUnits(from: "Metric", to: unitSystem)
                        }

                        return weather
                    }
                } catch {
                    print("❌ FAILED: Weather Underground unavailable (\(error.localizedDescription))")
                    print("   → Falling back to next source...")
                }
            }
        }

        // Try OpenWeatherMap if configured, unless its key is
        // already known to be invalid.
        let owmBlocked = APIKeyHealthMonitor.shared.hasBlockingIssue(for: .openWeatherMap)
        if !owmApiKey.isEmpty {
            if owmBlocked {
                print("⏭️  SKIPPED: OpenWeatherMap (key flagged as invalid; not re-attempting)")
            } else {
                print("📍 Priority 2: Attempting OpenWeatherMap")
                do {
                    let (owmCurrent, owmDaily) = try await fetchOWMWeather(
                        apiKey: owmApiKey,
                        latitude: lat,
                        longitude: lon,
                        unitSystem: unitSystem
                    )

                    print("✅ SUCCESS: Using OpenWeatherMap for current conditions")
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

                    currentDataSource = "openweathermap"

                    var weather = Weather(
                        wuObservation: nil,
                        owmCurrent: owmCurrent,
                        owmDaily: owmDaily,
                        unitSystem: unitSystem
                    )

                    if unitSystem != "Metric" {
                        weather.convertUnits(from: "Metric", to: unitSystem)
                    }

                    return weather
                } catch {
                    print("❌ FAILED: OpenWeatherMap unavailable (\(error.localizedDescription))")
                    print("   → Falling back to next source...")
                }
            }
        }
        
        // Check user preference for default data source
        let useOpenMeteo = UserDefaults.standard.bool(forKey: "useOpenMeteoAsDefault")
        
        // Try WeatherKit as default (iOS 16+, macOS 13+) unless user prefers OpenMeteo
        if !useOpenMeteo {
            if #available(iOS 16.0, macOS 13.0, *) {
                print("📍 Priority 3: Attempting Apple WeatherKit (Default)")
                do {
                    let weather = try await fetchWeatherKitWeather(latitude: lat, longitude: lon)
                    print("✅ SUCCESS: Using Apple WeatherKit for current conditions")
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
                    
                    currentDataSource = "weatherkit"
                    
                    return weather
                } catch {
                    print("❌ FAILED: WeatherKit unavailable (\(error.localizedDescription))")
                    print("   → Falling back to OpenMeteo...")
                }
            } else {
                print("⚠️  SKIPPED: WeatherKit (Requires iOS 16.0+ / macOS 13.0+)")
            }
        } else {
            print("⚙️  SKIPPED: WeatherKit (User preference: OpenMeteo as default)")
        }
        
        // Fallback to OpenMeteo
        print("📍 Priority 4: Using OpenMeteo (Fallback)")
        
        currentDataSource = "openmeteo"
        
        let (openMeteoCurrent, openMeteoDaily) = try await fetchOpenMeteoWeather(
            latitude: lat,
            longitude: lon
        )
        
        print("✅ SUCCESS: Using OpenMeteo for current conditions")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
        var weather = Weather(
            wuObservation: nil,
            owmCurrent: openMeteoCurrent,
            owmDaily: openMeteoDaily,
            unitSystem: unitSystem
        )
        
        if unitSystem != "Metric" {
            weather.convertUnits(from: "Metric", to: unitSystem)
        }
        
        guard weather.hasData else {
            throw WeatherError.noData
        }
        
        return weather
    }
    
    @MainActor
    private func fetchWUWeather(apiKey: String, stationID: String) async throws -> WUObservation? {
        guard !apiKey.isEmpty, !stationID.isEmpty else {
#if DEBUG
            print("❌ Weather Underground Error: Empty API key or station ID")
#endif
            throw WeatherError.invalidAPIKey
        }

        let urlString = "https://api.weather.com/v2/pws/observations/current?stationId=\(stationID)&format=json&units=m&numericPrecision=decimal&apiKey=\(apiKey)"
#if DEBUG
        print("🌐 Weather Underground URL: \(urlString)")
#endif

        guard let url = URL(string: urlString) else {
#if DEBUG
            print("❌ Weather Underground Error: Invalid URL")
#endif
            throw WeatherError.invalidURL
        }

        var request = createURLRequest(from: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
#if DEBUG
                print("📡 Weather Underground Response Status: \(httpResponse.statusCode)")
#endif

                // Detect auth/quota problems and surface them to the
                // health monitor so the UI can warn the user.
                switch httpResponse.statusCode {
                case 200..<300:
                    APIKeyHealthMonitor.shared.recordSuccess(for: .weatherUnderground)
                case 401:
                    APIKeyHealthMonitor.shared.recordFailure(
                        for: .weatherUnderground,
                        httpStatusCode: 401,
                        detail: "Weather Underground rejected the API key (HTTP 401). It may have been revoked from your account."
                    )
                    throw WeatherError.apiKeyRevoked(service: APIKeyService.weatherUnderground.rawValue)
                case 403:
                    APIKeyHealthMonitor.shared.recordFailure(
                        for: .weatherUnderground,
                        httpStatusCode: 403,
                        detail: "Weather Underground denied access (HTTP 403). Your account may be suspended."
                    )
                    throw WeatherError.apiKeyForbidden(service: APIKeyService.weatherUnderground.rawValue)
                case 429:
                    APIKeyHealthMonitor.shared.recordFailure(
                        for: .weatherUnderground,
                        httpStatusCode: 429,
                        detail: "Hit the Weather Underground request limit (HTTP 429)."
                    )
                    throw WeatherError.apiKeyQuotaExceeded(service: APIKeyService.weatherUnderground.rawValue)
                default:
                    APIKeyHealthMonitor.shared.recordTransientError(
                        for: .weatherUnderground,
                        detail: "Unexpected HTTP \(httpResponse.statusCode) from Weather Underground."
                    )
                    throw WeatherError.apiError("Status code: \(httpResponse.statusCode)")
                }
            }

#if DEBUG
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 Weather Underground Response Body:")
                print(responseString)
            }
#endif

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let wuResponse = try decoder.decode(WUResponse.self, from: data)

#if DEBUG
            if let observation = wuResponse.observations.first {
                print("✅ Weather Underground Data Parsed Successfully:")
                print("- Temperature: \(observation.metric.temp)°C")
                print("- Humidity: \(observation.humidity)%")
                print("- Wind Speed: \(observation.metric.windSpeed) m/s")
                print("- Pressure: \(observation.metric.pressure) hPa")
            }
#endif

            return wuResponse.observations.first
        } catch let weatherError as WeatherError {
            throw weatherError
        } catch {
#if DEBUG
            print("❌ Weather Underground Error:", error)
            print("❌ Error Details:", error.localizedDescription)
#endif
            APIKeyHealthMonitor.shared.recordTransientError(
                for: .weatherUnderground,
                detail: error.localizedDescription
            )
            throw WeatherError.apiError(error.localizedDescription)
        }
    }
    
    @MainActor
    private func fetchOWMWeather(
        apiKey: String,
        latitude: String,
        longitude: String,
        unitSystem: String
    ) async throws -> (OWMCurrent?, OWMDaily?) {
        guard !apiKey.isEmpty, !latitude.isEmpty, !longitude.isEmpty else {
            throw WeatherError.invalidAPIKey
        }

        let units = unitSystem == "Metric" ? "metric" : "imperial"
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(latitude)&lon=\(longitude)&units=\(units)&appid=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }

        let request = createURLRequest(from: url)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
#if DEBUG
                print("📡 OpenWeatherMap API Response Status: \(httpResponse.statusCode)")

                if let responseString = String(data: data, encoding: .utf8) {
                    print("📡 OpenWeatherMap API Response Body:")
                    print(responseString)
                }
#endif

                switch httpResponse.statusCode {
                case 200..<300:
                    APIKeyHealthMonitor.shared.recordSuccess(for: .openWeatherMap)
                case 401:
#if DEBUG
                    print("❌ OpenWeatherMap Error: Invalid API key")
#endif
                    APIKeyHealthMonitor.shared.recordFailure(
                        for: .openWeatherMap,
                        httpStatusCode: 401,
                        detail: "OpenWeatherMap rejected the API key (HTTP 401). It may have been revoked from your account."
                    )
                    throw WeatherError.apiKeyRevoked(service: APIKeyService.openWeatherMap.rawValue)
                case 403:
                    APIKeyHealthMonitor.shared.recordFailure(
                        for: .openWeatherMap,
                        httpStatusCode: 403,
                        detail: "OpenWeatherMap denied access (HTTP 403)."
                    )
                    throw WeatherError.apiKeyForbidden(service: APIKeyService.openWeatherMap.rawValue)
                case 429:
                    APIKeyHealthMonitor.shared.recordFailure(
                        for: .openWeatherMap,
                        httpStatusCode: 429,
                        detail: "Hit the OpenWeatherMap request limit (HTTP 429)."
                    )
                    throw WeatherError.apiKeyQuotaExceeded(service: APIKeyService.openWeatherMap.rawValue)
                default:
#if DEBUG
                    print("❌ OpenWeatherMap Error: Unexpected status code \(httpResponse.statusCode)")
#endif
                    APIKeyHealthMonitor.shared.recordTransientError(
                        for: .openWeatherMap,
                        detail: "Unexpected HTTP \(httpResponse.statusCode) from OpenWeatherMap."
                    )
                    throw WeatherError.apiError("Status code: \(httpResponse.statusCode)")
                }
            }

            let currentWeather = try JSONDecoder().decode(CurrentWeatherResponse.self, from: data)

            let owmCurrent = OWMCurrent(
                temp: currentWeather.main.temp,
                feels_like: currentWeather.main.feels_like,
                humidity: Double(currentWeather.main.humidity),
                dew_point: calculateDewPoint(temp: currentWeather.main.temp, humidity: Double(currentWeather.main.humidity)),
                pressure: Double(currentWeather.main.pressure),
                wind_speed: currentWeather.wind.speed,
                wind_gust: currentWeather.wind.gust ?? 0,
                uvi: 0,
                clouds: Double(currentWeather.clouds.all)
            )

            let owmDaily = OWMDaily(temp: OWMDaily.OWMDailyTemp(
                min: currentWeather.main.temp_min,
                max: currentWeather.main.temp_max
            ))

            return (owmCurrent, owmDaily)
        } catch let weatherError as WeatherError {
            throw weatherError
        } catch {
#if DEBUG
            print("❌ OpenWeatherMap Error:", error.localizedDescription)
            print("❌ Error Details:", error)
#endif
            APIKeyHealthMonitor.shared.recordTransientError(
                for: .openWeatherMap,
                detail: error.localizedDescription
            )
            throw WeatherError.apiError(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Functions
    private func calculateDewPoint(temp: Double, humidity: Double) -> Double {
        let a = 17.27
        let b = 237.7
        
        let alpha = ((a * temp) / (b + temp)) + log(humidity/100.0)
        let dewPoint = (b * alpha) / (a - alpha)
        return dewPoint
    }
    
    private func createURLRequest(from url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        return request
    }

    // MARK: - On-Demand API Key Validation

    /// Result of an on-demand API key check.
    enum APIKeyValidationResult: Equatable {
        case unknown
        case valid(detail: String)
        case invalid(detail: String, httpStatusCode: Int?)
        case quotaExceeded(detail: String)
    }

    /// Verify a stored API key by issuing a tiny, side-effect-free
    /// request to the provider. The result is also recorded in the
    /// `APIKeyHealthMonitor` so other UI can react to it.
    @MainActor
    func validateAPIKey(for service: APIKeyService) async -> APIKeyValidationResult {
        switch service {
        case .weatherUnderground:
            return await validateWeatherUndergroundKey()
        case .openWeatherMap:
            return await validateOpenWeatherMapKey()
        }
    }

    private func validateWeatherUndergroundKey() async -> APIKeyValidationResult {
        guard
            let apiKey = KeychainService.shared.getApiKey(forService: APIKeyService.weatherUnderground.rawValue),
            !apiKey.isEmpty
        else {
            return .unknown
        }
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        guard !stationID.isEmpty else {
            // We still want to validate the key even if the station
            // id is missing – fall back to a probe request.
            return await probeWeatherUndergroundKey(apiKey: apiKey)
        }

        let urlString = "https://api.weather.com/v2/pws/observations/current?stationId=\(stationID)&format=json&units=m&numericPrecision=decimal&apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else { return .unknown }

        do {
            let (_, response) = try await URLSession.shared.data(for: createURLRequest(from: url))
            return interpret(httpResponse: response as? HTTPURLResponse, for: .weatherUnderground, withDetail: "Validated against station \(stationID).")
        } catch {
            APIKeyHealthMonitor.shared.recordTransientError(
                for: .weatherUnderground,
                detail: error.localizedDescription
            )
            return .invalid(detail: "Network error: \(error.localizedDescription)", httpStatusCode: nil)
        }
    }

    /// Even without a station id, WU rejects unauthenticated requests
    /// with a clear 401, so we can still probe the key directly.
    private func probeWeatherUndergroundKey(apiKey: String) async -> APIKeyValidationResult {
        let urlString = "https://api.weather.com/v2/pws/observations/current?stationId=__probe__&format=json&units=m&numericPrecision=decimal&apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else { return .unknown }

        do {
            let (_, response) = try await URLSession.shared.data(for: createURLRequest(from: url))
            // A 404 with a known station id is ambiguous – treat 401
            // as a real signal and let everything else pass through
            // to the user.
            return interpret(httpResponse: response as? HTTPURLResponse, for: .weatherUnderground, withDetail: "Probed the WU endpoint (no station configured).")
        } catch {
            APIKeyHealthMonitor.shared.recordTransientError(
                for: .weatherUnderground,
                detail: error.localizedDescription
            )
            return .invalid(detail: "Network error: \(error.localizedDescription)", httpStatusCode: nil)
        }
    }

    private func validateOpenWeatherMapKey() async -> APIKeyValidationResult {
        guard
            let apiKey = KeychainService.shared.getApiKey(forService: APIKeyService.openWeatherMap.rawValue),
            !apiKey.isEmpty
        else {
            return .unknown
        }

        // Use a neutral, well-known coordinate (London) so the call
        // is cheap and side-effect free.
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=51.5074&lon=-0.1278&units=metric&appid=\(apiKey)"
        guard let url = URL(string: urlString) else { return .unknown }

        do {
            let (_, response) = try await URLSession.shared.data(for: createURLRequest(from: url))
            return interpret(httpResponse: response as? HTTPURLResponse, for: .openWeatherMap, withDetail: "Validated against a probe request to OpenWeatherMap.")
        } catch {
            APIKeyHealthMonitor.shared.recordTransientError(
                for: .openWeatherMap,
                detail: error.localizedDescription
            )
            return .invalid(detail: "Network error: \(error.localizedDescription)", httpStatusCode: nil)
        }
    }

    /// Translate an HTTP response into a user-facing validation
    /// result and update the health monitor.
    private func interpret(
        httpResponse: HTTPURLResponse?,
        for service: APIKeyService,
        withDetail successDetail: String
    ) -> APIKeyValidationResult {
        guard let httpResponse else {
            return .invalid(detail: "No HTTP response received.", httpStatusCode: nil)
        }
        switch httpResponse.statusCode {
        case 200..<300:
            APIKeyHealthMonitor.shared.recordSuccess(for: service)
            return .valid(detail: successDetail)
        case 401:
            APIKeyHealthMonitor.shared.recordFailure(
                for: service,
                httpStatusCode: 401,
                detail: "The provider rejected the API key (HTTP 401)."
            )
            return .invalid(
                detail: "The provider rejected the API key (HTTP 401). It may have been revoked.",
                httpStatusCode: 401
            )
        case 403:
            APIKeyHealthMonitor.shared.recordFailure(
                for: service,
                httpStatusCode: 403,
                detail: "The provider denied access (HTTP 403)."
            )
            return .invalid(
                detail: "Access denied (HTTP 403). Your account may be suspended.",
                httpStatusCode: 403
            )
        case 429:
            APIKeyHealthMonitor.shared.recordFailure(
                for: service,
                httpStatusCode: 429,
                detail: "Hit the request limit (HTTP 429)."
            )
            return .quotaExceeded(detail: "Hit the request limit (HTTP 429). Try again later.")
        default:
            APIKeyHealthMonitor.shared.recordTransientError(
                for: service,
                detail: "Unexpected HTTP \(httpResponse.statusCode)."
            )
            return .invalid(
                detail: "Unexpected HTTP \(httpResponse.statusCode) from the provider.",
                httpStatusCode: httpResponse.statusCode
            )
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
#if DEBUG
        print("📍 Location updated: \(locations.first?.coordinate ?? CLLocationCoordinate2D())")
#endif
        
        // Cancel the timeout work item since we got a location
        locationTimeoutWorkItem?.cancel()
        locationTimeoutWorkItem = nil
        
        // Save last known location for widgets to use. Route
        // through the centralised sync service so the unit
        // system, GPS flag, data source preference, and
        // coordinates are pushed atomically. This is the fix
        // for "Widget coordinates might not sync properly with
        // the main app when location settings change".
        if let location = locations.first {
            let latString = "\(location.coordinate.latitude)"
            let lonString = "\(location.coordinate.longitude)"

            // Mirror the GPS coordinates into the standard
            // "lastKnown*" keys so any host code that reads
            // from there (e.g. background alerts) still works.
            UserDefaults.standard.set(latString, forKey: "lastKnownLatitude")
            UserDefaults.standard.set(lonString, forKey: "lastKnownLongitude")

            // Publish the fix on the main thread so SwiftUI
            // observers can react to the new location. We
            // dispatch to main even though the delegate is
            // already called on main, because future callers
            // may invoke the delegate from a background queue.
            DispatchQueue.main.async { [weak self] in
                self?.currentLocation = location.coordinate
            }

            if useGPS {
                WidgetSyncService.shared.syncGPSCoordinates(
                    latitude: latString,
                    longitude: lonString
                )
            } else {
                // Manual mode: still re-sync so unit / source
                // preferences stay consistent with the widget.
                WidgetSyncService.shared.syncAll(
                    unitSystem: unitSystem,
                    useGPS: false,
                    manualLatitude: UserDefaults.standard.string(forKey: "latitude"),
                    manualLongitude: UserDefaults.standard.string(forKey: "longitude"),
                    lastKnownLatitude: latString,
                    lastKnownLongitude: lonString,
                    useOpenMeteoAsDefault: UserDefaults.standard.bool(forKey: "useOpenMeteoAsDefault")
                )
            }
        }
        
        // Stop updating location after we get a reading - only need one update
        locationManager.stopUpdatingLocation()
        
        if useGPS {
            Task { [weak self] in
                guard let self = self else { return }
                await self.fetchWeather(calledFrom: "locationManager.didUpdateLocations")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
#if DEBUG
        print("❌ Location Error: \(error.localizedDescription)")
#endif

        // Map the raw CLError to a typed `WeatherError` so the UI
        // can show a category-specific message. `.denied` and
        // `.restricted` also flip the `showLocationAlert` flag so
        // the app can offer an "Open Settings" deep link in a
        // dedicated alert.
        let mapped = WeatherError.from(error)
        let shouldShowAlert: Bool
        switch mapped {
        case .locationDenied, .locationRestricted:
            shouldShowAlert = true
        default:
            shouldShowAlert = false
        }

        Task { [weak self] in
            guard let self = self else { return }
            await MainActor.run {
                self.error = mapped
                if shouldShowAlert {
                    self.showLocationAlert = true
                }
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
#if DEBUG
            print("📍 Location authorization granted")
#endif
            // Request a location update
            locationManager.startUpdatingLocation()
            
            // Cancel any existing timeout
            locationTimeoutWorkItem?.cancel()
            
            // Add a timer to stop location updates after a short period
            let timeoutItem = DispatchWorkItem { [weak self] in
#if DEBUG
                print("⏱️ Stopping location updates after timeout")
#endif
                self?.locationManager.stopUpdatingLocation()
            }
            locationTimeoutWorkItem = timeoutItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeoutItem)
            
            // Refresh weather data with new location permissions
            Task { [weak self] in
                guard let self = self else { return }
                await self.fetchWeather(calledFrom: "locationManagerDidChangeAuthorization")
            }
        case .denied, .restricted:
#if DEBUG
            print("⚠️ Location permission denied")
#endif
            // Update useGPS to false when permissions are denied
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self._useGPS = false
                UserDefaults.standard.set(false, forKey: "useGPS")
            }

            // Use a typed location error and surface the
            // system-level alert (bound to `showLocationAlert`
            // in `ContentView`) so the user can deep-link to
            // Settings to fix the permission.
            Task { [weak self] in
                guard let self = self else { return }
                await MainActor.run {
                    self.error = .locationDenied
                    self.showLocationAlert = true
                }
            }
        default:
            break
        }
    }
    
    func requestLocation() {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
#if DEBUG
            print("📍 Requesting location authorization")
#endif
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
#if DEBUG
            print("📍 Location authorization already granted, starting location updates")
#endif
            // Use startUpdatingLocation with a timeout instead of requestLocation
            locationManager.startUpdatingLocation()
            
            // Cancel any existing timeout
            locationTimeoutWorkItem?.cancel()
            
            // Add a timer to stop location updates after a short period
            let timeoutItem = DispatchWorkItem { [weak self] in
#if DEBUG
                print("⏱️ Stopping location updates after timeout")
#endif
                self?.locationManager.stopUpdatingLocation()
            }
            locationTimeoutWorkItem = timeoutItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeoutItem)
        case .denied, .restricted:
#if DEBUG
            print("⚠️ Location access denied or restricted")
#endif
            // Update useGPS to false when permissions are denied
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self._useGPS = false
                UserDefaults.standard.set(false, forKey: "useGPS")
            }

            // Surface a typed location error and show the
            // system-level alert (bound in `ContentView`).
            Task { [weak self] in
                guard let self = self else { return }
                await MainActor.run {
                    self.error = .locationDenied
                    self.showLocationAlert = true
                }
            }
        @unknown default:
#if DEBUG
            print("⚠️ Unknown location authorization status")
#endif
            locationManager.requestWhenInUseAuthorization()
        }
    }

    /// Opens the system Settings app at this app's page. Kept as
    /// a thin shim over [`AppSettingsRouter.open`] for backwards
    /// compatibility with call sites that already invoke it
    /// directly on the service.
    func openSettings() {
        AppSettingsRouter.open()
    }
    
    func hasValidDataSources() -> Bool {
        let wuApiKey = KeychainService.shared.getApiKey(forService: "wu") ?? ""
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        let owmApiKey = KeychainService.shared.getApiKey(forService: "owm") ?? ""
        let latitude = UserDefaults.standard.string(forKey: "latitude") ?? ""
        let longitude = UserDefaults.standard.string(forKey: "longitude") ?? ""
        
        // Check if we have valid API configurations
        let hasWUConfig = !wuApiKey.isEmpty && !stationID.isEmpty
        let hasOWMConfig = !owmApiKey.isEmpty
        
        // Check if we have valid location
        var hasValidLocation = false
        if useGPS {
            let status = locationManager.authorizationStatus
            hasValidLocation = hasValidLocationStatus(status)
        } else {
            if let lat = Double(latitude), let lon = Double(longitude) {
                hasValidLocation = lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
            }
        }
        
        // Return true if we have either:
        // 1. Valid WU config
        // 2. Valid OWM config with location
        // 3. Valid location (for OpenMeteo fallback)
        return hasWUConfig || (hasOWMConfig && hasValidLocation) || hasValidLocation
    }
    
    private func hasValidLocationStatus(_ status: CLAuthorizationStatus) -> Bool {
        #if os(iOS)
        return status == .authorizedWhenInUse || status == .authorizedAlways
        #else
        return status == .authorized
        #endif
    }
    
    private func weatherTypeFor(code: Int) -> String {
        switch code {
        case 0, 1: return "sunny"
        case 2, 3: return "cloudy"
        case 45, 48: return "foggy"
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return "rainy"
        case 71, 73, 75, 77, 85, 86: return "snowy"
        case 95, 96, 99: return "thunder"
        default: return "default"
        }
    }
    
    private func updateBackgroundCondition() {
        // Priority 1: Use current weather condition if available
        if let weather = weather, !weather.condition.isEmpty, weather.condition != "default" {
            // Map weather condition string to background type
            let condition = weather.condition.lowercased()
            if condition.contains("clear") || condition.contains("sunny") {
                currentBackgroundCondition = "sunny"
            } else if condition.contains("partly cloudy") || condition.contains("partly-cloudy") {
                currentBackgroundCondition = "partly-cloudy"
            } else if condition.contains("cloud") || condition.contains("overcast") {
                currentBackgroundCondition = "cloudy"
            } else if condition.contains("fog") || condition.contains("mist") {
                currentBackgroundCondition = "foggy"
            } else if condition.contains("rain") || condition.contains("shower") || condition.contains("drizzle") {
                currentBackgroundCondition = "rainy"
            } else if condition.contains("snow") || condition.contains("sleet") || condition.contains("ice") {
                currentBackgroundCondition = "snowy"
            } else if condition.contains("thunder") || condition.contains("lightning") || condition.contains("storm") {
                currentBackgroundCondition = "thunder"
            } else {
                currentBackgroundCondition = weather.condition
            }
            #if DEBUG
            print("🎨 Background updated from weather condition: \(weather.condition) -> \(currentBackgroundCondition)")
            #endif
            return
        }

        // Priority 2: Use forecast data if weather condition not available
        if let forecast = forecast, let firstDay = forecast.daily.first {
            currentBackgroundCondition = weatherTypeFor(code: firstDay.weatherCode)
            #if DEBUG
            print("🎨 Background updated from forecast: \(currentBackgroundCondition)")
            #endif
            return
        }

        // Fallback to default
        currentBackgroundCondition = "default"
        #if DEBUG
        print("🎨 Background set to default")
        #endif
    }
    
    // MARK: - Forecast Methods
    // Note: fetchForecasts() is implemented in WeatherService+OpenMeteo.swift extension
}

// MARK: - Array Extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Response Models
struct CurrentWeatherResponse: Codable {
    struct Main: Codable {
        let temp: Double
        let feels_like: Double
        let temp_min: Double
        let temp_max: Double
        let pressure: Double
        let humidity: Int
    }
    
    struct Wind: Codable {
        let speed: Double
        let gust: Double?
    }
    
    struct Clouds: Codable {
        let all: Int
    }
    
    let main: Main
    let wind: Wind
    let clouds: Clouds
}
