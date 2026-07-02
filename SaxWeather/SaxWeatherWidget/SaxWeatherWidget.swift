//
//  SaxWeatherWidget.swift
//  SaxWeatherWidget
//
//  Created by Saxon on 18/5/2025.
//

import WidgetKit
import SwiftUI
import Foundation
import CoreLocation
import Network
#if canImport(WeatherKit)
import WeatherKit
#endif

// MARK: - Widget Weather Data Model
fileprivate struct WidgetWeatherData: Codable {
    let temperature: Double
    let condition: String
    let humidity: Double
    let windSpeed: Double
    let high: Double
    let low: Double
    let lastUpdate: Double
}

struct WeatherWidgetEntry: TimelineEntry {
    let date: Date
    let temperature: Double?
    let condition: String?
    let high: Double?
    let low: Double?
    let humidity: Double?
    let feelsLike: Double?
    let windSpeed: Double?
    let uvIndex: Int?
    let pressure: Double?
    let lastUpdateDate: Date? // Added for "last updated" timestamp

    // MARK: - Data state flags
    //
    // The view layer uses these to choose between three distinct
    // "missing / stale data" presentations:
    //
    //   1. First sync     – no temperature AND `hasEverFetched`
    //                        is false. Shows "Awaiting first sync"
    //                        with an "Open SaxWeather" hint.
    //   2. Stale          – we have a cached value but its age
    //                        exceeds the freshness threshold
    //                        (see `WidgetStaleness.threshold`),
    //                        or we just observed the data is
    //                        old enough to flag it. Shows
    //                        "Updated Xm ago" prominently.
    //   3. Offline        – the most recent network attempt
    //                        failed with a transport error
    //                        (offline / timeout / DNS). When
    //                        combined with cached data the
    //                        widget shows a "wifi.slash" badge
    //                        next to the temperature.
    //
    // All three default to false so existing call sites that
    // build an entry from a known-good source (placeholder,
    // fresh fetch) don't need to change.

    /// True when the device is currently offline as observed by
    /// the most recent network probe.
    let isOffline: Bool
    /// True when `lastUpdateDate` is older than the staleness
    /// threshold.
    let isStale: Bool
    /// False only on the very first run, before the host app
    /// has ever pushed a payload to the shared App Group.
    /// Lets the view show a distinct "open the app to begin"
    /// state instead of "no data".
    let hasEverFetched: Bool

    init(
        date: Date,
        temperature: Double? = nil,
        condition: String? = nil,
        high: Double? = nil,
        low: Double? = nil,
        humidity: Double? = nil,
        feelsLike: Double? = nil,
        windSpeed: Double? = nil,
        uvIndex: Int? = nil,
        pressure: Double? = nil,
        lastUpdateDate: Date? = nil,
        isOffline: Bool = false,
        isStale: Bool = false,
        hasEverFetched: Bool = true
    ) {
        self.date = date
        self.temperature = temperature
        self.condition = condition
        self.high = high
        self.low = low
        self.humidity = humidity
        self.feelsLike = feelsLike
        self.windSpeed = windSpeed
        self.uvIndex = uvIndex
        self.pressure = pressure
        self.lastUpdateDate = lastUpdateDate
        self.isOffline = isOffline
        self.isStale = isStale
        self.hasEverFetched = hasEverFetched
    }
}

// MARK: - Staleness threshold

// MARK: - Lightweight connectivity probe for the widget process

/// The widget process is a separate process from the host app
/// and cannot share the host's `NetworkMonitor` singleton, so we
/// create a one-shot `NWPathMonitor` to do a connectivity
/// pre-flight before attempting a network fetch.
///
/// IMPORTANT: `NWPathMonitor.currentPath` on a *brand new*
/// monitor is documented to return `.requiresConnection` (not
/// satisfied) until the monitor has done its first path update
/// — which on a cold start can take several hundred
/// milliseconds. Reading `currentPath` synchronously and then
/// immediately cancelling the monitor is therefore almost
/// guaranteed to report "offline" even on a connected device,
/// which is what caused the widgets to show the "Awaiting first
/// sync" empty state even when the host app had been launched
/// and the App Group cache was present.
///
/// The fix is to actually wait for the first `pathUpdateHandler`
/// callback (or a short timeout, after which we assume "online"
/// and let the URLSession surface its own transport error).
enum WidgetConnectivity {
    /// Async best-effort connectivity check. Returns `true`
    /// when the path is satisfied, `false` when the path is
    /// clearly unsatisfied. If the path update hasn't arrived
    /// after `timeout` seconds, returns `true` (assume online)
    /// because the URL session will fail naturally if we are
    /// actually offline and we'd rather attempt the fetch
    /// than always show an "offline" placeholder.
    ///
    /// `timeout` defaults to 0.5s — long enough to receive the
    /// first path update on a normal network, short enough
    /// not to eat meaningfully into the ~30s background-
    /// refresh budget.
    static func isReachable(timeout: TimeInterval = 0.5) async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.saxobroko.SaxWeather.widget.connectivity")
            let lock = NSLock()
            var hasResumed = false

            let resume: (Bool) -> Void = { value in
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                monitor.cancel()
                continuation.resume(returning: value)
            }

            monitor.pathUpdateHandler = { path in
                resume(path.status == .satisfied)
            }
            monitor.start(queue: queue)

            // Timeout fallback: if `pathUpdateHandler` hasn't
            // fired within `timeout` seconds, optimistically
            // assume the device is online. The URLSession
            // call below will fail naturally if we are wrong,
            // and we'll tag the resulting entry as offline in
            // that case.
            queue.asyncAfter(deadline: .now() + timeout) {
                resume(true)
            }
        }
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherWidgetEntry {
        WeatherWidgetEntry(
            date: Date(),
            temperature: 21.0,
            condition: "Sunny",
            high: 24.0,
            low: 18.0,
            humidity: 60.0,
            feelsLike: 22.0,
            windSpeed: 15.0,
            uvIndex: 5,
            pressure: 1013.0,
            lastUpdateDate: Date()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherWidgetEntry) -> ()) {
        // Try the cache, then the converted-cache fallback (for
        // unit-system changes), then the placeholder.
        let entry = loadWeatherEntry()
            ?? loadConvertedEntry()
            ?? WeatherWidgetEntry(
                date: Date(),
                temperature: 21.0,
                condition: "Sunny",
                high: 24.0,
                low: 18.0,
                humidity: 60.0,
                feelsLike: 22.0,
                windSpeed: 15.0,
                uvIndex: 5,
                pressure: 1013.0,
                lastUpdateDate: Date()
            )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherWidgetEntry>) -> ()) {
        #if DEBUG
        print("📱 Widget: getTimeline called at \(Date())")
        #endif

        // Snapshot the cache before kicking off the network
        // fetch. Prefer the live cache; fall back to the
        // converted cache so a unit-system change in the host
        // app doesn't leave the widget blank while the fresh
        // fetch is in flight.
        let cachedCurrentEntry = loadWeatherEntry() ?? loadConvertedEntry()

        // Read the host-side "ever saved a payload" flag once.
        // The widget uses this to pick the right "no data" copy
        // when both the cache and the network fetch come back
        // empty – "host has never run" vs "host has run but
        // something is currently wrong".
        let hasEverFetchedFlag = Self.readHasEverFetchedFlag()

        // Fetch fresh weather data asynchronously. The async
        // connectivity probe inside `WidgetConnectivity` waits
        // for the first `NWPathMonitor.pathUpdateHandler` (or a
        // 500ms timeout) so we no longer report "offline" on
        // a cold start when the monitor hasn't observed a path
        // yet.
        Task {
            let isCurrentlyOffline = !(await WidgetConnectivity.isReachable())
            #if DEBUG
            print("📱 Widget: Connectivity probe – offline = \(isCurrentlyOffline)")
            #endif

            var entries: [WeatherWidgetEntry]

            if isCurrentlyOffline {
                // Offline fast path. Fall back to the cached
                // entry (or the empty default) and tag it so
                // the view shows the offline indicator. Honour
                // the host-side "has ever fetched" flag so the
                // empty state reads "You're Offline" rather
                // than "Awaiting first sync" if the host has
                // already saved at least one payload.
                let offlineEntry = Self.tagEntry(
                    cachedCurrentEntry ?? Self.emptyEntry(),
                    isOffline: true,
                    isStale: WidgetStaleness.isStale(cachedCurrentEntry?.lastUpdateDate),
                    hasEverFetched: hasEverFetchedFlag || (cachedCurrentEntry != nil)
                )
                entries = [offlineEntry]
            } else {
                let fresh = await fetchFreshWeatherEntry(cachedCurrentEntry: cachedCurrentEntry)
                if let fresh = fresh {
                    // The fresh fetch already came back via the
                    // cache layer (which writes a fresh timestamp)
                    // so `isStale` is always false here. `isOffline`
                    // is also false because we checked above.
                    entries = fresh
                } else {
                    // Fetch threw. The most common cause at this
                    // point is a transient transport error, so
                    // tag the cached entry as offline + stale.
                    // If we have no cache at all, fall back to
                    // an empty entry. Honour the host-side
                    // "has ever fetched" flag so the view
                    // shows "You're Offline" (not "Awaiting
                    // first sync") when the host has previously
                    // been able to save a payload.
                    let fallback = cachedCurrentEntry ?? Self.emptyEntry()
                    entries = [Self.tagEntry(
                        fallback,
                        isOffline: true,
                        isStale: true,
                        hasEverFetched: hasEverFetchedFlag || (cachedCurrentEntry != nil)
                    )]
                }
            }

            // Ensure we have at least one entry
            if entries.isEmpty {
                entries = [Self.emptyEntry()]
            }

            #if DEBUG
            print("✅ Widget: Timeline created with \(entries.count) entries")
            if let firstEntry = entries.first {
                print("✅ Widget: First entry temp: \(firstEntry.temperature?.description ?? "nil"), offline=\(firstEntry.isOffline), stale=\(firstEntry.isStale), everFetched=\(firstEntry.hasEverFetched)")
            }
            #endif

            // Calculate next update time after the last entry
            // Reduce from 30 to 15 minutes for more frequent updates
            // Background tasks will refresh more often, so widget can be more aggressive
            let nextUpdate = entries.last?.date ?? Date()
            let nextUpdateTime = Calendar.current.date(byAdding: .minute, value: 15, to: nextUpdate) ?? nextUpdate.addingTimeInterval(900)

            #if DEBUG
            print("📱 Widget: Next update scheduled for \(nextUpdateTime)")
            #endif

            let timeline = Timeline(entries: entries, policy: .after(nextUpdateTime))
            completion(timeline)
        }
    }

    /// Build an entry with no weather data, used when there is
    /// no cache and the network is unavailable. The
    /// `hasEverFetched = false` flag tells the view to show the
    /// "Awaiting first sync" state.
    fileprivate static func emptyEntry() -> WeatherWidgetEntry {
        WeatherWidgetEntry(
            date: Date(),
            temperature: nil,
            condition: nil,
            high: nil,
            low: nil,
            humidity: nil,
            feelsLike: nil,
            windSpeed: nil,
            uvIndex: nil,
            pressure: nil,
            lastUpdateDate: nil,
            isOffline: false,
            isStale: false,
            hasEverFetched: false
        )
    }

    /// Apply the three data-state flags to an entry. Used to
    /// tag cached or empty entries with the offline/stale
    /// state derived from the latest network probe.
    fileprivate static func tagEntry(
        _ entry: WeatherWidgetEntry,
        isOffline: Bool,
        isStale: Bool,
        hasEverFetched: Bool
    ) -> WeatherWidgetEntry {
        WeatherWidgetEntry(
            date: entry.date,
            temperature: entry.temperature,
            condition: entry.condition,
            high: entry.high,
            low: entry.low,
            humidity: entry.humidity,
            feelsLike: entry.feelsLike,
            windSpeed: entry.windSpeed,
            uvIndex: entry.uvIndex,
            pressure: entry.pressure,
            lastUpdateDate: entry.lastUpdateDate,
            isOffline: isOffline,
            isStale: isStale,
            hasEverFetched: hasEverFetched
        )
    }

    /// Read the host-side "I have saved at least one payload"
    /// flag. The host sets this to `true` the first time
    /// `saveWeatherDataForWidget` runs successfully (see
    /// `WidgetSyncService.markHasEverFetched`). The widget
    /// uses it to choose the right "no data" copy when both
    /// the cache and the network fetch come back empty —
    /// "Awaiting first sync" (host never ran) vs "You're
    /// Offline" / "Open the app to refresh" (host has run
    /// but the data path is broken right now).
    fileprivate static func readHasEverFetchedFlag() -> Bool {
        guard let defaults = WidgetSharedConfig.sharedDefaults else { return false }
        return defaults.bool(forKey: WidgetSharedConfig.Keys.hasEverFetched)
    }

    /// Write a freshly-fetched entry back to the App Group
    /// cache. This lets the widget self-heal on a fresh
    /// install: the first time the widget renders, it can
    /// fetch from OpenMeteo directly and then leave a payload
    /// in the App Group so the next timeline reload (and
    /// `loadWeatherEntry`) doesn't have to re-fetch.
    ///
    /// Mirrors the host's `saveWeatherDataForWidget` shape
    /// closely enough that the widget's `loadWeatherEntry`
    /// can decode the resulting JSON without any special
    /// handling. Stamps the same `widgetDataVersion` /
    /// `cachedUnitSystem` keys the host uses so the inspector
    /// treats the widget-written cache the same as a
    /// host-written one.
    fileprivate static func writeBackToCache(_ entry: WeatherWidgetEntry) {
        guard let defaults = WidgetSharedConfig.sharedDefaults else { return }
        let now = Date()
        let unitSystem = defaults.string(forKey: WidgetSharedConfig.Keys.unitSystem) ?? "Metric"
        let widgetDataVersion = defaults.integer(forKey: WidgetSharedConfig.Keys.widgetDataVersion)

        var payload: [String: Any] = [
            "lastUpdate": now.timeIntervalSince1970,
            "lastUpdateDate": now.timeIntervalSince1970,
            "unitSystem": unitSystem,
            "dataSource": "openmeteo_widget",
            "widgetDataVersion": widgetDataVersion,
            "hasEverFetched": true
        ]
        if let v = entry.temperature  { payload["temperature"]  = v }
        if let v = entry.condition     { payload["condition"]    = v }
        if let v = entry.high          { payload["high"]         = v }
        if let v = entry.low           { payload["low"]          = v }
        if let v = entry.humidity      { payload["humidity"]     = v }
        if let v = entry.feelsLike     { payload["feelsLike"]    = v }
        if let v = entry.windSpeed     { payload["windSpeed"]    = v }
        if let v = entry.uvIndex       { payload["uvIndex"]      = v }
        if let v = entry.pressure      { payload["pressure"]     = v }

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else { return }
        defaults.set(data, forKey: WidgetSharedConfig.Keys.latestWeather)
        // Mirror the host's stamp so subsequent cache loads
        // don't false-positive on unit-system or version
        // mismatch.
        defaults.set(unitSystem, forKey: WidgetSharedConfig.Keys.cachedUnitSystem)
        defaults.set(widgetDataVersion, forKey: WidgetSharedConfig.Keys.cachedWidgetDataVersion)
        defaults.set(true, forKey: WidgetSharedConfig.Keys.hasEverFetched)
        #if DEBUG
        print("✅ Widget: wrote fresh fetch back to App Group cache")
        #endif
    }
    
    private func fetchFreshWeatherEntry(cachedCurrentEntry: WeatherWidgetEntry?) async -> [WeatherWidgetEntry]? {
        let sharedDefaults = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
        
        // Get location from shared UserDefaults
        let useGPS = sharedDefaults?.bool(forKey: "useGPS") ?? false
        var latitude: Double = 0
        var longitude: Double = 0
        
        #if DEBUG
        print("📱 Widget: Fetching fresh weather data...")
        print("📱 Widget: Use GPS = \(useGPS)")
        #endif
        
        if useGPS {
            // Use last known GPS location
            if let lat = sharedDefaults?.string(forKey: "lastKnownLatitude"),
               let lon = sharedDefaults?.string(forKey: "lastKnownLongitude"),
               let latDouble = Double(lat),
               let lonDouble = Double(lon) {
                latitude = latDouble
                longitude = lonDouble
                #if DEBUG
                print("📱 Widget: Using GPS location: \(latitude), \(longitude)")
                #endif
            } else {
                // Fallback to manual coordinates
                if let lat = sharedDefaults?.string(forKey: "latitude"),
                   let lon = sharedDefaults?.string(forKey: "longitude"),
                   let latDouble = Double(lat),
                   let lonDouble = Double(lon) {
                    latitude = latDouble
                    longitude = lonDouble
                    #if DEBUG
                    print("📱 Widget: Using manual fallback: \(latitude), \(longitude)")
                    #endif
                }
            }
        } else {
            // Use manual coordinates
            if let lat = sharedDefaults?.string(forKey: "latitude"),
               let lon = sharedDefaults?.string(forKey: "longitude"),
               let latDouble = Double(lat),
               let lonDouble = Double(lon) {
                latitude = latDouble
                longitude = lonDouble
                #if DEBUG
                print("📱 Widget: Using manual location: \(latitude), \(longitude)")
                #endif
            }
        }
        
        // Validate coordinates using our new validator
        let validationResult = CoordinateValidator.validate(latitude: latitude, longitude: longitude)
        guard validationResult.isValid else {
            #if DEBUG
            print("❌ Widget: Invalid coordinates - \(validationResult.errorMessage ?? "Unknown error")")
            #endif
            return nil
        }
        
        // Use validated coordinates
        let validatedLatitude = validationResult.normalizedLatitude ?? latitude
        let validatedLongitude = validationResult.normalizedLongitude ?? longitude
        
        let unitSystem = sharedDefaults?.string(forKey: "unitSystem") ?? "Metric"
        
        do {
            let forecastEntries = try await fetchPreferredForecastEntries(
                latitude: validatedLatitude,
                longitude: validatedLongitude,
                unitSystem: unitSystem
            )
            #if DEBUG
            print("✅ Widget: Successfully fetched weather data")
            #endif

            let merged = mergeCurrentEntry(cachedCurrentEntry, withForecastEntries: forecastEntries)
            // Self-heal: write the **fresh forecast's** first
            // entry (current conditions from the live network
            // fetch) back to the App Group cache. We prefer
            // the fresh entry over `merged.first` because the
            // merge can take the temperature from a stale
            // cache when the host's last write was more recent
            // than the cache's timestamp. The host's
            // `saveWeatherDataForWidget` will overwrite this on
            // the next host fetch with the user's preferred
            // data source, so we don't need to be perfectly
            // accurate here – we just need *something* in the
            // cache so the next reload can avoid a full
            // network fetch.
            if let fresh = forecastEntries.first {
                Self.writeBackToCache(fresh)
            }
            return merged
        } catch {
            #if DEBUG
            print("❌ Widget: Error fetching weather: \(error)")
            #endif
            return cachedCurrentEntry.map { [$0] }
        }
    }

    private func fetchPreferredForecastEntries(
        latitude: Double,
        longitude: Double,
        unitSystem: String
    ) async throws -> [WeatherWidgetEntry] {
        let sharedDefaults = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
        let preferOpenMeteo = sharedDefaults?.bool(forKey: "useOpenMeteoAsDefault") ?? false
        
        if !preferOpenMeteo {
            #if canImport(WeatherKit)
            if #available(iOS 16.0, macOS 13.0, *) {
                do {
                    #if DEBUG
                    print("📱 Widget: Attempting WeatherKit forecast (user preference)")
                    #endif
                    return try await fetchWeatherKitWeather(
                        latitude: latitude,
                        longitude: longitude,
                        unitSystem: unitSystem
                    )
                } catch {
                    #if DEBUG
                    print("❌ Widget: WeatherKit forecast failed, falling back to OpenMeteo: \(error)")
                    #endif
                }
            }
            #endif
        }
        
        #if DEBUG
        print("📱 Widget: Using OpenMeteo forecast")
        #endif
        return try await fetchOpenMeteoWeather(
            latitude: latitude,
            longitude: longitude,
            unitSystem: unitSystem
        )
    }

    private func mergeCurrentEntry(
        _ cachedCurrentEntry: WeatherWidgetEntry?,
        withForecastEntries forecastEntries: [WeatherWidgetEntry]
    ) -> [WeatherWidgetEntry] {
        guard let cachedCurrentEntry, cachedCurrentEntry.temperature != nil else {
            return forecastEntries
        }

        let now = Date()
        let firstForecastEntry = forecastEntries.first
        let currentEntry = WeatherWidgetEntry(
            date: now,
            temperature: cachedCurrentEntry.temperature,
            condition: cachedCurrentEntry.condition ?? firstForecastEntry?.condition,
            high: cachedCurrentEntry.high ?? firstForecastEntry?.high,
            low: cachedCurrentEntry.low ?? firstForecastEntry?.low,
            humidity: cachedCurrentEntry.humidity,
            feelsLike: cachedCurrentEntry.feelsLike,
            windSpeed: cachedCurrentEntry.windSpeed,
            uvIndex: cachedCurrentEntry.uvIndex,
            pressure: cachedCurrentEntry.pressure,
            lastUpdateDate: cachedCurrentEntry.lastUpdateDate
        )

        let futureForecastEntries = forecastEntries.filter { $0.date > now.addingTimeInterval(60) }
        return [currentEntry] + futureForecastEntries
    }
    
    private func fetchOpenMeteoWeather(
        latitude: Double,
        longitude: Double,
        unitSystem: String
    ) async throws -> [WeatherWidgetEntry] {
        // Determine temperature unit for API
        let tempUnit = unitSystem == "Imperial" ? "fahrenheit" : "celsius"
        let windUnit = unitSystem == "Metric" ? "kmh" : "mph"
        let pressureUnit = unitSystem == "Imperial" ? "inHg" : "hPa"
        
        let urlString = "https://api.open-meteo.com/v1/forecast?" +
            "latitude=\(latitude)" +
            "&longitude=\(longitude)" +
            "&current=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,pressure_msl,uv_index,weather_code" +
            "&hourly=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,pressure_msl,uv_index,weather_code" +
            "&daily=temperature_2m_max,temperature_2m_min,weather_code" +
            "&temperature_unit=\(tempUnit)" +
            "&wind_speed_unit=\(windUnit)" +
            "&pressure_unit=\(pressureUnit)" +
            "&timezone=auto" +
            "&forecast_hours=24" +
            "&forecast_days=1"
        
        #if DEBUG
        print("📱 Widget: API URL: \(urlString)")
        #endif
        
        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("❌ Widget: Invalid URL")
            #endif
            throw URLError(.badURL)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            #if DEBUG
            if let httpResponse = response as? HTTPURLResponse {
                print("📱 Widget: HTTP Status: \(httpResponse.statusCode)")
            }
            #endif
            
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(OpenMeteoWidgetResponse.self, from: data)
            
            #if DEBUG
            print("📱 Widget: API Response decoded successfully")
            print("📱 Widget: Current data available: \(apiResponse.current != nil)")
            print("📱 Widget: Hourly data available: \(apiResponse.hourly != nil && !apiResponse.hourly!.time.isEmpty)")
            #endif
            
            guard let current = apiResponse.current else {
                #if DEBUG
                print("❌ Widget: No current weather data in response")
                #endif
                throw URLError(.cannotParseResponse)
            }
        
        let daily = apiResponse.daily
        var entries: [WeatherWidgetEntry] = []
        
        // Use hourly data if available, otherwise fall back to current data
        if let hourly = apiResponse.hourly, !hourly.time.isEmpty {
            let calendar = Calendar.current
            let now = Date()
            let currentHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            let parsedHourlyDates = hourly.time.map { parseOpenMeteoHour($0) }
            let startIndex = parsedHourlyDates.firstIndex { date in
                guard let date else { return false }
                return date >= currentHour
            } ?? 0
            
            let availableCount = [
                hourly.time.count,
                hourly.temperature2m.count,
                hourly.relativeHumidity2m.count,
                hourly.apparentTemperature.count,
                hourly.windSpeed10m.count,
                hourly.pressureMsl.count,
                hourly.uvIndex.count,
                hourly.weatherCode.count
            ].min() ?? 0
            let safeStartIndex = availableCount > 0 ? min(startIndex, availableCount - 1) : 0
            let endIndex = min(safeStartIndex + 12, availableCount)
            
            for index in safeStartIndex..<endIndex {
                let fallbackHourOffset = index - safeStartIndex
                let entryDate = parsedHourlyDates[index]
                    ?? calendar.date(byAdding: .hour, value: fallbackHourOffset, to: currentHour)
                    ?? now
                
                let temp = hourly.temperature2m[index]
                let humidity = hourly.relativeHumidity2m[index]
                let feelsLike = hourly.apparentTemperature[index]
                let windSpeed = hourly.windSpeed10m[index]
                let pressure = hourly.pressureMsl[index]
                let uvIndex = Int(hourly.uvIndex[index])
                let weatherCode = hourly.weatherCode[index]

                let condition = mapWeatherCodeToCondition(weatherCode)
                let high = daily.temperature2mMax.first ?? temp
                let low = daily.temperature2mMin.first ?? temp
                
                let entry = WeatherWidgetEntry(
                    date: entryDate,
                    temperature: temp,
                    condition: condition,
                    high: high,
                    low: low,
                    humidity: humidity,
                    feelsLike: feelsLike,
                    windSpeed: windSpeed,
                    uvIndex: uvIndex,
                    pressure: pressure,
                    lastUpdateDate: Date()
                )
                
                entries.append(entry)
            }
            
            #if DEBUG
            print("📱 Widget: Generated \(entries.count) hourly entries")
            #endif
        } else {
            // Fallback to current data only
            let temp = current.temperature2m
            let feelsLike = current.apparentTemperature
            let high = daily.temperature2mMax.first ?? temp
            let low = daily.temperature2mMin.first ?? temp
            let windSpeed = current.windSpeed10m
            let pressure = current.pressureMsl
            
            let condition = mapWeatherCodeToCondition(current.weatherCode)
            
            let entry = WeatherWidgetEntry(
                date: Date(),
                temperature: temp,
                condition: condition,
                high: high,
                low: low,
                humidity: current.relativeHumidity2m,
                feelsLike: feelsLike,
                windSpeed: windSpeed,
                uvIndex: Int(current.uvIndex),
                pressure: pressure,
                lastUpdateDate: Date()
            )
            
            entries.append(entry)
        }
        
        return entries
        } catch {
            #if DEBUG
            print("❌ Widget: Error fetching OpenMeteo weather: \(error)")
            #endif
            throw error
        }
    }

    #if canImport(WeatherKit)
    @available(iOS 16.0, macOS 13.0, *)
    private func fetchWeatherKitWeather(
        latitude: Double,
        longitude: Double,
        unitSystem: String
    ) async throws -> [WeatherWidgetEntry] {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let weather = try await WeatherKit.WeatherService.shared.weather(for: location)
        let dailyForecast = weather.dailyForecast.forecast.first
        
        var high = dailyForecast?.highTemperature.value
        var low = dailyForecast?.lowTemperature.value
        
        if unitSystem == "Imperial" {
            high = high.map { $0 * 9 / 5 + 32 }
            low = low.map { $0 * 9 / 5 + 32 }
        }
        
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        
        let entries = weather.hourlyForecast.forecast
            .filter { $0.date >= currentHour }
            .prefix(12)
            .map { hour -> WeatherWidgetEntry in
                let weatherCode = mapWeatherKitConditionToWMOCode(hour.condition)
                var temperature = hour.temperature.value
                var feelsLike = hour.apparentTemperature.value
                var windSpeed = hour.wind.speed.value * 3.6
                var pressure = hour.pressure.value
                
                if unitSystem == "Imperial" {
                    temperature = temperature * 9 / 5 + 32
                    feelsLike = feelsLike * 9 / 5 + 32
                    windSpeed = windSpeed * 0.621371
                    pressure = pressure * 0.02953
                } else if unitSystem == "UK" {
                    windSpeed = windSpeed * 0.621371
                }
                
                return WeatherWidgetEntry(
                    date: hour.date,
                    temperature: temperature,
                    condition: mapWeatherCodeToCondition(weatherCode),
                    high: high ?? temperature,
                    low: low ?? temperature,
                    humidity: hour.humidity * 100,
                    feelsLike: feelsLike,
                    windSpeed: windSpeed,
                    uvIndex: hour.uvIndex.value,
                    pressure: pressure,
                    lastUpdateDate: now
                )
            }
        
        return Array(entries)
    }

    @available(iOS 16.0, macOS 13.0, *)
    private func mapWeatherKitConditionToWMOCode(_ condition: WeatherCondition) -> Int {
        switch condition {
        case .clear:
            return 0
        case .partlyCloudy, .mostlyClear:
            return 2
        case .cloudy, .mostlyCloudy:
            return 3
        case .foggy, .haze, .smoky:
            return 45
        case .drizzle:
            return 51
        case .rain, .heavyRain:
            return 61
        case .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms, .thunderstorms:
            return 95
        case .freezingRain, .sleet:
            return 66
        case .snow, .heavySnow, .flurries, .blowingSnow:
            return 71
        case .frigid:
            return 71
        case .blizzard:
            return 75
        case .wintryMix:
            return 66
        case .breezy, .windy:
            return 3
        case .hot, .hurricane, .tropicalStorm:
            return 3
        case .sunFlurries:
            return 85
        case .sunShowers:
            return 80
        default:
            return 0
        }
    }
    #endif

    private func parseOpenMeteoHour(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: timeString)
    }
    
    private func mapWeatherCodeToCondition(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mainly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing Drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing Rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow Grains"
        case 80, 81, 82: return "Rain Showers"
        case 85, 86: return "Snow Showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with Hail"
        default: return "Unknown"
        }
    }
    
    private func loadWeatherEntry() -> WeatherWidgetEntry? {
        let sharedDefaults = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")

        guard let data = sharedDefaults?.data(forKey: "latestWeather") else {
            #if DEBUG
            print("⚠️ Widget: No cached payload available")
            #endif
            return nil
        }

        // Try to decode from JSON dictionary format
        guard let weatherDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            #if DEBUG
            print("⚠️ Widget: Cached payload could not be decoded")
            #endif
            return nil
        }

        // Staleness / unit-mismatch / location-mismatch checks. If any
        // of these trip, returning nil forces `getTimeline` to run
        // `fetchFreshWeatherEntry` and overwrite the cache with data
        // that is actually current. This fixes three concrete bugs:
        //
        //   * Data Staleness – background refresh failed/delayed
        //   * Unit System Mismatch – user changed °C/°F in main app
        //   * Coordinate Sync – GPS update or saved-location change
        if WidgetCacheInspector.isStale(weatherDict) {
            #if DEBUG
            print("⚠️ Widget: Cached payload is stale – will refresh")
            #endif
            return nil
        }
        if WidgetCacheInspector.isExplicitlyInvalidated(weatherDict) {
            #if DEBUG
            print("⚠️ Widget: Cached payload explicitly invalidated by host – will refresh")
            #endif
            return nil
        }
        if WidgetCacheInspector.isVersionMismatch(weatherDict) {
            #if DEBUG
            print("⚠️ Widget: Cached payload version older than host's – will refresh")
            #endif
            return nil
        }
        if WidgetCacheInspector.isUnitSystemMismatch(weatherDict) {
            #if DEBUG
            print("⚠️ Widget: Cached payload unit-system mismatches host app – will refresh")
            #endif
            return nil
        }
        if WidgetCacheInspector.isLocationMismatch(weatherDict) {
            #if DEBUG
            print("⚠️ Widget: Cached payload location mismatches host app – will refresh")
            #endif
            return nil
        }

        let temperature = weatherDict["temperature"] as? Double
        let condition = weatherDict["condition"] as? String
        let high = weatherDict["high"] as? Double
        let low = weatherDict["low"] as? Double
        let humidity = weatherDict["humidity"] as? Double
        let feelsLike = weatherDict["feelsLike"] as? Double
        let windSpeed = weatherDict["windSpeed"] as? Double
        let uvIndex = weatherDict["uvIndex"] as? Int
        let pressure = weatherDict["pressure"] as? Double
        let lastUpdateTimestamp = weatherDict["lastUpdateDate"] as? Double

        return WeatherWidgetEntry(
            date: Date(),
            temperature: temperature,
            condition: condition,
            high: high,
            low: low,
            humidity: humidity,
            feelsLike: feelsLike,
            windSpeed: windSpeed,
            uvIndex: uvIndex,
            pressure: pressure,
            lastUpdateDate: lastUpdateTimestamp != nil ? Date(timeIntervalSince1970: lastUpdateTimestamp!) : nil
        )
    }

    /// Best-effort in-widget unit conversion. Used as a
    /// graceful-degradation fallback when the cache is still
    /// valid (timestamp-wise) but the unit system has changed
    /// in the host app. Without this, the widget would have to
    /// either serve stale units (confusing) or force a fresh
    /// network fetch that may fail (blank widget). With this,
    /// the widget shows the converted cache immediately while
    /// the fresh fetch is in flight.
    fileprivate func loadConvertedEntry() -> WeatherWidgetEntry? {
        let sharedDefaults = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
        guard let data = sharedDefaults?.data(forKey: "latestWeather"),
              let weatherDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }
        // Only attempt conversion when the cache is still
        // timestamp-fresh and the *only* mismatch is the unit
        // system. Other mismatches (location, version,
        // explicit invalidation) are stronger signals that the
        // cache is fundamentally wrong, and conversion would
        // hide that.
        if WidgetCacheInspector.isStale(weatherDict) { return nil }
        if WidgetCacheInspector.isExplicitlyInvalidated(weatherDict) { return nil }
        if WidgetCacheInspector.isVersionMismatch(weatherDict) { return nil }
        if WidgetCacheInspector.isLocationMismatch(weatherDict) { return nil }
        if !WidgetCacheInspector.isUnitSystemMismatch(weatherDict) { return nil }

        let liveUnit = sharedDefaults?.string(forKey: WidgetSharedConfig.Keys.unitSystem) ?? "Metric"
        let bakedUnit = (weatherDict["unitSystem"] as? String)
            ?? sharedDefaults?.string(forKey: WidgetSharedConfig.Keys.cachedUnitSystem)
            ?? "Metric"
        guard bakedUnit != liveUnit else { return nil }

        #if DEBUG
        print("🔁 Widget: Converting cached entry from \(bakedUnit) to \(liveUnit)")
        #endif

        func convert(_ value: Double?, _ kind: WidgetUnitKind) -> Double? {
            guard let value else { return nil }
            return WidgetUnitConverter.convert(value, from: bakedUnit, to: liveUnit, kind: kind)
        }

        let temperature = convert(weatherDict["temperature"] as? Double, .temperature)
        let feelsLike   = convert(weatherDict["feelsLike"] as? Double, .temperature)
        let high        = convert(weatherDict["high"] as? Double, .temperature)
        let low         = convert(weatherDict["low"] as? Double, .temperature)
        let windSpeed   = convert(weatherDict["windSpeed"] as? Double, .windSpeed)
        let pressure    = convert(weatherDict["pressure"] as? Double, .pressure)
        let humidity    = weatherDict["humidity"] as? Double
        let uvIndex     = weatherDict["uvIndex"] as? Int
        let condition   = weatherDict["condition"] as? String
        let lastUpdateTimestamp = weatherDict["lastUpdateDate"] as? Double

        return WeatherWidgetEntry(
            date: Date(),
            temperature: temperature,
            condition: condition,
            high: high,
            low: low,
            humidity: humidity,
            feelsLike: feelsLike,
            windSpeed: windSpeed,
            uvIndex: uvIndex,
            pressure: pressure,
            lastUpdateDate: lastUpdateTimestamp != nil ? Date(timeIntervalSince1970: lastUpdateTimestamp!) : nil
        )
    }
}

/// Kind of weather value being unit-converted. Drives the
/// conversion table in `WidgetUnitConverter`.
fileprivate enum WidgetUnitKind {
    case temperature
    case windSpeed
    case pressure
}

/// Best-effort weather-unit conversion. Supports the same
/// three unit systems the host app uses ("Metric",
/// "Imperial", "UK") with simple fixed conversion factors.
/// Not meant to be a full meteorological conversion library;
/// just enough so the widget can show readable values while
/// waiting for a fresh fetch.
fileprivate enum WidgetUnitConverter {
    static func convert(_ value: Double, from source: String, to target: String, kind: WidgetUnitKind) -> Double {
        if source == target { return value }

        // Normalise to Metric as a pivot.
        let metric: Double
        switch (source, kind) {
        case ("Metric", _):
            metric = value
        case ("Imperial", .temperature):
            metric = (value - 32) * 5.0 / 9.0
        case ("Imperial", .windSpeed):
            metric = value / 0.621371  // mph -> km/h
        case ("Imperial", .pressure):
            metric = value / 0.02953   // inHg -> hPa
        case ("UK", .windSpeed):
            metric = value / 0.621371  // UK uses mph; pivot to km/h
        case ("UK", _):
            metric = value             // UK is Metric for temp/pressure
        default:
            metric = value
        }

        // Convert from Metric to target.
        switch (target, kind) {
        case ("Metric", _):
            return metric
        case ("Imperial", .temperature):
            return metric * 9.0 / 5.0 + 32
        case ("Imperial", .windSpeed):
            return metric * 0.621371
        case ("Imperial", .pressure):
            return metric * 0.02953
        case ("UK", .windSpeed):
            return metric * 0.621371
        case ("UK", _):
            return metric
        default:
            return metric
        }
    }
}

struct SaxWeatherWidgetEntryView : View {
    var entry: WeatherWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily

    private var widgetUnitSystem: UnitSystem {
        let raw = WidgetSharedConfig.sharedDefaults?.string(forKey: WidgetSharedConfig.Keys.unitSystem) ?? "Metric"
        return UnitSystem.from(rawValue: raw)
    }
    
    // Helper to format relative time
    private func relativeTimeString(from date: Date?) -> String {
        guard let date = date else { return "" }

        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: date)
        }
    }

    /// Full-bleed placeholder rendered when the widget has no
    /// usable weather data. Renders one of three distinct
    /// states so the user can tell:
    ///
    ///   * First sync  – "Awaiting first sync" + "Open
    ///                    SaxWeather to begin"
    ///   * Offline     – "Offline" + "No cached data; open
    ///                    the app when you're back online"
    ///   * Other       – the legacy "No Weather Data" /
    ///                    "Open the app to refresh" fallback
    @ViewBuilder
    private func widgetNoDataView(iconSize: CGFloat = 64) -> some View {
        if !entry.hasEverFetched {
            // First sync: no host app has ever pushed a payload
            // to the shared App Group.
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "icloud.and.arrow.down")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: iconSize))
                Text("Awaiting First Sync")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("Open SaxWeather to begin")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        } else if entry.isOffline {
            // Offline + we had data before but the cache is empty
            // here for some reason.
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "wifi.slash")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: iconSize))
                    .foregroundColor(.orange)
                Text("You're Offline")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("No cached data. Open the app when you're back online.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        } else {
            // Generic fallback for any other "no data" case
            // (e.g. coordinate validation failed, host app has
            // never been launched, etc.).
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "cloud.sun.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: iconSize))
                Text("No Weather Data")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("Open the app to refresh")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }

    /// Compact offline indicator badge. Rendered in the small
    /// widget's top-right corner when the cached data is being
    /// shown while the device is offline. Designed to be
    /// overlaid without disrupting the existing layout.
    @ViewBuilder
    private func offlineBadge(size: CGFloat = 14) -> some View {
        if entry.isOffline {
            Image(systemName: "wifi.slash")
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(.orange)
                .accessibilityLabel("Offline")
        }
    }
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            smallWidgetView
        case .systemMedium:
            mediumWidgetView
        case .systemLarge:
            largeWidgetView
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        case .accessoryInline:
            accessoryInlineView
        default:
            smallWidgetView
        }
    }
    
    private var smallWidgetView: some View {
        VStack(spacing: 8) {
            if let temp = entry.temperature {
                Spacer()
                
                // Weather icon with SF Symbols - larger for impact
                Image(systemName: weatherIconName(for: entry.condition))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        weatherIconColor(for: entry.condition),
                        weatherIconColor(for: entry.condition).opacity(0.5)
                    )
                    .font(.system(size: 50, weight: .medium))
                    .shadow(color: weatherIconColor(for: entry.condition).opacity(0.3), radius: 4, x: 0, y: 2)
                    .padding(.top, 4)
                
                // Large, bold temperature - main focus
                Text("\(String(format: "%.1f", temp))°")
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                
                // Small high/low display - compact
                if let high = entry.high, let low = entry.low {
                    HStack(spacing: 6) {
                        Text("H:\(String(format: "%.1f", high))°")
                            .foregroundColor(.red.opacity(0.8))
                        Text("L:\(String(format: "%.1f", low))°")
                            .foregroundColor(.blue.opacity(0.8))
                    }
                    .font(.system(size: 11, weight: .semibold))
                }

                Spacer()
            } else {
                // State-aware "no data" view. Renders one of
                // three presentations based on the entry's
                // data state (first sync / offline / generic).
                widgetNoDataView(iconSize: 50)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
    
    private var mediumWidgetView: some View {
        VStack(spacing: 12) {
            if let temp = entry.temperature {
                // Top row - Icon, temp, and condition
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: weatherIconName(for: entry.condition))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            weatherIconColor(for: entry.condition),
                            weatherIconColor(for: entry.condition).opacity(0.5)
                        )
                        .font(.system(size: 56, weight: .medium))
                        .shadow(color: weatherIconColor(for: entry.condition).opacity(0.3), radius: 4, x: 0, y: 2)
                        .frame(width: 65)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(String(format: "%.1f", temp))°")
                            .font(.system(size: 52, weight: .heavy))
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.8)
                        
                        if let condition = entry.condition {
                            Text(condition)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                }
                
                // Bottom row - High/Low and Feels Like in compact cards
                HStack(spacing: 8) {
                    // High/Low card
                    if let high = entry.high, let low = entry.low {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red.opacity(0.8))
                                Text("H:\(String(format: "%.1f", high))°")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue.opacity(0.8))
                                Text("L:\(String(format: "%.1f", low))°")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Feels Like
                    if let feelsLike = entry.feelsLike {
                        HStack(spacing: 4) {
                            Image(systemName: "thermometer.medium")
                                .font(.system(size: 12))
                                .foregroundColor(.orange.opacity(0.8))
                            Text("Feels \(String(format: "%.1f", feelsLike))°")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
            } else {
                // State-aware "no data" view. Renders one of
                // three presentations based on the entry's
                // data state (first sync / offline / generic).
                widgetNoDataView(iconSize: 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
    
    private var largeWidgetView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let temp = entry.temperature {
                // Top section - Main weather info
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: weatherIconName(for: entry.condition))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            weatherIconColor(for: entry.condition),
                            weatherIconColor(for: entry.condition).opacity(0.5)
                        )
                        .font(.system(size: 64, weight: .medium))
                        .shadow(color: weatherIconColor(for: entry.condition).opacity(0.3), radius: 6, x: 0, y: 3)
                        .frame(width: 70)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Match main app temperature style
                        Text("\(String(format: "%.1f", temp))°")
                            .font(.system(size: 62, weight: .heavy))
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.7)
                        
                        if let condition = entry.condition {
                            Text(condition)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Feels like right below condition
                        if let feelsLike = entry.feelsLike {
                            Text("Feels like \(String(format: "%.1f", feelsLike))°")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                Divider()
                    .padding(.vertical, 2)
                
                // Details section with cards - 3x2 grid layout
                VStack(spacing: 8) {
                    // First row - High/Low
                    if let high = entry.high, let low = entry.low {
                        HStack(spacing: 8) {
                            // High temp card
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.red.opacity(0.8))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("High")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.1f", high))°")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(8)
                            
                            // Low temp card
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue.opacity(0.8))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Low")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.1f", low))°")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Second row - Humidity and Wind Speed
                    HStack(spacing: 8) {
                        if let humidity = entry.humidity {
                            HStack {
                                Image(systemName: "humidity.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.cyan.opacity(0.8))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Humidity")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.0f", humidity))%")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.cyan.opacity(0.08))
                            .cornerRadius(8)
                        }
                        
                        if let windSpeed = entry.windSpeed {
                            HStack {
                                Image(systemName: "wind")
                                    .font(.system(size: 18))
                                    .foregroundColor(.green.opacity(0.8))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Wind")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.1f", windSpeed)) \(widgetUnitSystem.speedLabel)")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                        .minimumScaleFactor(0.8)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Third row - UV Index and Pressure
                    HStack(spacing: 8) {
                        if let uvIndex = entry.uvIndex {
                            HStack {
                                Image(systemName: "sun.max.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.orange.opacity(0.8))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("UV Index")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("\(uvIndex)")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.08))
                            .cornerRadius(8)
                        }
                        
                        if let pressure = entry.pressure {
                            HStack {
                                Image(systemName: "gauge.with.dots.needle.50percent")
                                    .font(.system(size: 18))
                                    .foregroundColor(.purple.opacity(0.8))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Pressure")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.0f", pressure)) \(widgetUnitSystem.pressureLabel)")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                        .minimumScaleFactor(0.8)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }
                }
                
              } else {
                // State-aware "no data" view. Renders one of
                // three presentations based on the entry's
                // data state (first sync / offline / generic).
                widgetNoDataView(iconSize: 64)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
    }
    
    // MARK: - Lock Screen Widgets (Accessory)
    
    private var accessoryCircularView: some View {
        VStack(spacing: 0) {
            if let temp = entry.temperature {
                Text(weatherSymbol(for: entry.condition))
                    .font(.system(size: 14))
                Text("\(String(format: "%.0f", temp))°")
                    .font(.system(size: 20, weight: .heavy))
                    .minimumScaleFactor(0.7)
                if let high = entry.high, let low = entry.low {
                    HStack(spacing: 2) {
                        Text("\(String(format: "%.0f", high))°")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("/")
                            .font(.system(size: 8, weight: .regular))
                            .foregroundStyle(.tertiary)
                        Text("\(String(format: "%.0f", low))°")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                }
            } else {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 20))
            }
        }
    }
    
    private var accessoryRectangularView: some View {
        HStack(spacing: 8) {
            if let temp = entry.temperature {
                Text(weatherSymbol(for: entry.condition))
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(String(format: "%.0f", temp))°")
                        .font(.system(size: 24, weight: .heavy))
                    
                    if let high = entry.high, let low = entry.low {
                        HStack(spacing: 4) {
                            HStack(spacing: 1) {
                                Text("↑")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.red.opacity(0.9))
                                Text("\(String(format: "%.0f", high))°")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            HStack(spacing: 1) {
                                Text("↓")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.blue.opacity(0.9))
                                Text("\(String(format: "%.0f", low))°")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                    } else if let condition = entry.condition {
                        Text(condition)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            } else {
                Text("No Data")
                    .font(.caption2)
            }
        }
    }
    
    private var accessoryInlineView: some View {
        Group {
            if let temp = entry.temperature {
                HStack(spacing: 4) {
                    Text(weatherSymbol(for: entry.condition))
                    Text("\(String(format: "%.0f", temp))°")
                    if let high = entry.high, let low = entry.low {
                        Text("H:\(String(format: "%.0f", high))° L:\(String(format: "%.0f", low))°")
                    } else if let condition = entry.condition {
                        Text(condition)
                    }
                }
            } else {
                Text("No Weather Data")
            }
        }
    }
    
    private func weatherSymbol(for condition: String?) -> String {
        guard let condition = condition?.lowercased() else { return "☀️" }
        
        if condition.contains("clear") || condition.contains("sunny") {
            return "☀️"
        } else if condition.contains("partly cloudy") {
            return "⛅"
        } else if condition.contains("cloud") || condition.contains("overcast") {
            return "☁️"
        } else if condition.contains("rain") || condition.contains("shower") {
            return "🌧️"
        } else if condition.contains("snow") {
            return "❄️"
        } else if condition.contains("thunder") || condition.contains("storm") {
            return "⛈️"
        } else if condition.contains("fog") || condition.contains("mist") {
            return "🌫️"
        }
        
        return "☀️"
    }
    
    @ViewBuilder
    private func weatherIcon(for condition: String?) -> some View {
        let iconName = weatherIconName(for: condition)
        
        ZStack {
            // Background glow effect
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            weatherIconColor(for: condition).opacity(0.3),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 5,
                        endRadius: 50
                    )
                )
                .frame(width: 80, height: 80)
            
            // Main icon
            Image(systemName: iconName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 50, weight: .light))
                .foregroundStyle(weatherIconColor(for: condition))
        }
    }
    
    private func weatherIconName(for condition: String?) -> String {
        guard let condition = condition?.lowercased() else { return "sun.max.fill" }
        
        let isNight = isNighttime()
        
        if condition.contains("clear") || condition.contains("sunny") {
            return isNight ? "moon.stars.fill" : "sun.max.fill"
        } else if condition.contains("partly cloudy") {
            return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        } else if condition.contains("cloud") || condition.contains("overcast") {
            return "cloud.fill"
        } else if condition.contains("rain") || condition.contains("shower") {
            return "cloud.rain.fill"
        } else if condition.contains("snow") {
            return "cloud.snow.fill"
        } else if condition.contains("thunder") || condition.contains("storm") {
            return "cloud.bolt.rain.fill"
        } else if condition.contains("fog") || condition.contains("mist") {
            return "cloud.fog.fill"
        }
        
        return isNight ? "moon.stars.fill" : "sun.max.fill"
    }
    
    private func weatherIconColor(for condition: String?) -> Color {
        guard let condition = condition?.lowercased() else { return .yellow }
        
        if condition.contains("clear") || condition.contains("sunny") {
            return .yellow
        } else if condition.contains("partly cloudy") {
            return .orange
        } else if condition.contains("cloud") || condition.contains("overcast") {
            return .gray
        } else if condition.contains("rain") || condition.contains("shower") {
            return .blue
        } else if condition.contains("snow") {
            return .cyan
        } else if condition.contains("thunder") || condition.contains("storm") {
            return .purple
        } else if condition.contains("fog") || condition.contains("mist") {
            return .gray.opacity(0.6)
        }
        
        return .yellow
    }
    
    private func isNighttime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour > 18
    }
}

// MARK: - Daily Forecast Widget

struct ForecastEntry: TimelineEntry {
    let date: Date
    let highTemp: Double?
    let lowTemp: Double?
    let condition: String?
}

struct ForecastProvider: TimelineProvider {
    func placeholder(in context: Context) -> ForecastEntry {
        ForecastEntry(date: Date(), highTemp: 24.0, lowTemp: 18.0, condition: "Partly Cloudy")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ForecastEntry) -> ()) {
        let entry = ForecastEntry(date: Date(), highTemp: 24.0, lowTemp: 18.0, condition: "Partly Cloudy")
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ForecastEntry>) -> ()) {
        #if DEBUG
        print("📱 Forecast Widget: getTimeline called at \(Date())")
        #endif
        
        Task {
            let entry = await fetchFreshForecastEntry() ?? ForecastEntry(
                date: Date(),
                highTemp: nil,
                lowTemp: nil,
                condition: nil
            )
            
            #if DEBUG
            print("✅ Forecast Widget: Timeline entry created with high: \(entry.highTemp?.description ?? "nil")")
            #endif
            
            // Use .atEnd policy for aggressive updates
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
    
    private func fetchFreshForecastEntry() async -> ForecastEntry? {
        let sharedDefaults = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
        
        let useGPS = sharedDefaults?.bool(forKey: "useGPS") ?? false
        var latitude: Double = 0
        var longitude: Double = 0
        
        #if DEBUG
        print("📱 Forecast Widget: Fetching fresh forecast data...")
        #endif
        
        if useGPS {
            if let lat = sharedDefaults?.string(forKey: "lastKnownLatitude"),
               let lon = sharedDefaults?.string(forKey: "lastKnownLongitude"),
               let latDouble = Double(lat),
               let lonDouble = Double(lon) {
                latitude = latDouble
                longitude = lonDouble
            } else {
                if let lat = sharedDefaults?.string(forKey: "latitude"),
                   let lon = sharedDefaults?.string(forKey: "longitude"),
                   let latDouble = Double(lat),
                   let lonDouble = Double(lon) {
                    latitude = latDouble
                    longitude = lonDouble
                }
            }
        } else {
            if let lat = sharedDefaults?.string(forKey: "latitude"),
               let lon = sharedDefaults?.string(forKey: "longitude"),
               let latDouble = Double(lat),
               let lonDouble = Double(lon) {
                latitude = latDouble
                longitude = lonDouble
            }
        }
        
        // Validate coordinates using our new validator
        let validationResult = CoordinateValidator.validate(latitude: latitude, longitude: longitude)
        guard validationResult.isValid else {
            #if DEBUG
            print("❌ Forecast Widget: Invalid coordinates - \(validationResult.errorMessage ?? "Unknown error")")
            #endif
            return nil
        }
        
        // Use validated coordinates
        let validatedLatitude = validationResult.normalizedLatitude ?? latitude
        let validatedLongitude = validationResult.normalizedLongitude ?? longitude
        
        let unitSystem = sharedDefaults?.string(forKey: "unitSystem") ?? "Metric"
        let tempUnit = unitSystem == "Imperial" ? "fahrenheit" : "celsius"
        
        // Update the URL to use validated coordinates
        let urlString = "https://api.open-meteo.com/v1/forecast?" +
            "latitude=\(validatedLatitude)" +
            "&longitude=\(validatedLongitude)" +
            "&daily=temperature_2m_max,temperature_2m_min,weather_code" +
            "&temperature_unit=\(tempUnit)" +
            "&timezone=auto"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoWidgetResponse.self, from: data)
            
            let high = response.daily.temperature2mMax.first
            let low = response.daily.temperature2mMin.first
            let weatherCode = response.daily.weatherCode.first ?? 0
            let condition = weatherCodeToCondition(weatherCode)
            
            #if DEBUG
            print("✅ Forecast Widget: Successfully fetched forecast data")
            #endif
            
            return ForecastEntry(
                date: Date(),
                highTemp: high,
                lowTemp: low,
                condition: condition
            )
        } catch {
            #if DEBUG
            print("❌ Forecast Widget: Error fetching forecast: \(error)")
            #endif
            return nil
        }
    }
    
    private func weatherCodeToCondition(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1, 2, 3: return "Partly Cloudy"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 80, 81, 82: return "Rain Showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Unknown"
        }
    }
}

struct SaxWeatherForecastEntryView: View {
    var entry: ForecastEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryRectangular:
            accessoryRectangularView
        default:
            lockScreenCircularView
        }
    }
    
    private var lockScreenCircularView: some View {
        VStack(spacing: 2) {
            if let high = entry.highTemp {
                Text("\(Int(high.rounded()))°")
                    .font(.system(size: 20, weight: .bold))
            } else {
                Text("--°")
                    .font(.system(size: 20, weight: .bold))
            }
            
            Image(systemName: weatherIcon(for: entry.condition))
                .font(.system(size: 16))
            
            if let low = entry.lowTemp {
                Text("\(Int(low.rounded()))°")
                    .font(.system(size: 14))
                    .opacity(0.7)
            } else {
                Text("--°")
                    .font(.system(size: 14))
                    .opacity(0.7)
            }
        }
    }
    
    private var accessoryRectangularView: some View {
        HStack(spacing: 12) {
            Image(systemName: weatherIcon(for: entry.condition))
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 2) {
                if let high = entry.highTemp {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10))
                        Text("\(Int(high.rounded()))°")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                
                if let low = entry.lowTemp {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10))
                        Text("\(Int(low.rounded()))°")
                            .font(.system(size: 14))
                            .opacity(0.8)
                    }
                }
            }
        }
    }
    
    private func weatherIcon(for condition: String?) -> String {
        guard let condition = condition?.lowercased() else { return "questionmark" }
        
        if condition.contains("clear") || condition.contains("sunny") {
            return "sun.max.fill"
        } else if condition.contains("partly cloudy") || condition.contains("cloudy") {
            return "cloud.sun.fill"
        } else if condition.contains("rain") {
            return "cloud.rain.fill"
        } else if condition.contains("snow") {
            return "cloud.snow.fill"
        } else if condition.contains("thunder") || condition.contains("storm") {
            return "cloud.bolt.rain.fill"
        } else if condition.contains("fog") {
            return "cloud.fog.fill"
        }
        
        return "cloud.fill"
    }
}

@main
struct SaxWeatherWidget: Widget {
    let kind: String = "SaxWeatherWidget"

    private var supportedWidgetFamilies: [WidgetFamily] {
        #if os(iOS)
        return [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ]
        #else
        return [
            .systemSmall,
            .systemMedium,
            .systemLarge
        ]
        #endif
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SaxWeatherWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("SaxWeather")
        .description("Shows current weather with detailed information. Works with all APIs: Weather Underground, OpenWeatherMap, and OpenMeteo.")
        .supportedFamilies(supportedWidgetFamilies)
    }
}


// MARK: - OpenMeteo Response Models for Widgets
struct OpenMeteoWidgetResponse: Codable {
    let current: OpenMeteoCurrentWidget?
    let hourly: OpenMeteoHourlyWidget?
    let daily: OpenMeteoDailyWidget
}

struct OpenMeteoCurrentWidget: Codable {
    let temperature2m: Double
    let relativeHumidity2m: Double
    let apparentTemperature: Double
    let windSpeed10m: Double
    let pressureMsl: Double
    let uvIndex: Double
    let weatherCode: Int
    
    enum CodingKeys: String, CodingKey {
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case apparentTemperature = "apparent_temperature"
        case windSpeed10m = "wind_speed_10m"
        case pressureMsl = "pressure_msl"
        case uvIndex = "uv_index"
        case weatherCode = "weather_code"
    }
}

struct OpenMeteoHourlyWidget: Codable {
    let time: [String]
    let temperature2m: [Double]
    let relativeHumidity2m: [Double]
    let apparentTemperature: [Double]
    let windSpeed10m: [Double]
    let pressureMsl: [Double]
    let uvIndex: [Double]
    let weatherCode: [Int]
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case apparentTemperature = "apparent_temperature"
        case windSpeed10m = "wind_speed_10m"
        case pressureMsl = "pressure_msl"
        case uvIndex = "uv_index"
        case weatherCode = "weather_code"
    }
}

struct OpenMeteoDailyWidget: Codable {
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]
    let weatherCode: [Int]
    
    enum CodingKeys: String, CodingKey {
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case weatherCode = "weather_code"
    }
}

#Preview(as: .systemSmall) {
    SaxWeatherWidget()
} timeline: {
    WeatherWidgetEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8, humidity: 62.0, feelsLike: 29.5, windSpeed: 15.0, uvIndex: 8, pressure: 1015.0, lastUpdateDate: .now)
    WeatherWidgetEntry(date: .now, temperature: 18.4, condition: "Cloudy", high: 20.3, low: 15.7, humidity: 78.0, feelsLike: 17.2, windSpeed: 22.0, uvIndex: 3, pressure: 1008.0, lastUpdateDate: .now.addingTimeInterval(-300))
    WeatherWidgetEntry(date: .now, temperature: 12.6, condition: "Rainy", high: 14.2, low: 9.8, humidity: 85.0, feelsLike: 10.8, windSpeed: 28.5, uvIndex: 2, pressure: 1002.0, lastUpdateDate: .now.addingTimeInterval(-600))
}

#Preview(as: .systemMedium) {
    SaxWeatherWidget()
} timeline: {
    WeatherWidgetEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8, humidity: 62.0, feelsLike: 29.5, windSpeed: 15.0, uvIndex: 8, pressure: 1015.0, lastUpdateDate: .now)
    WeatherWidgetEntry(date: .now, temperature: 18.4, condition: "Partly Cloudy", high: 20.3, low: 15.7, humidity: 78.0, feelsLike: 17.2, windSpeed: 22.0, uvIndex: 3, pressure: 1008.0, lastUpdateDate: .now.addingTimeInterval(-180))
}

#Preview(as: .systemLarge) {
    SaxWeatherWidget()
} timeline: {
    WeatherWidgetEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8, humidity: 62.0, feelsLike: 29.5, windSpeed: 15.0, uvIndex: 8, pressure: 1015.0, lastUpdateDate: .now)
    WeatherWidgetEntry(date: .now, temperature: 5.2, condition: "Snowy", high: 7.1, low: 2.3, humidity: 92.0, feelsLike: 2.8, windSpeed: 35.5, uvIndex: 1, pressure: 998.0, lastUpdateDate: .now.addingTimeInterval(-900))
}

#if os(iOS)
#Preview(as: .accessoryCircular) {
    SaxWeatherWidget()
} timeline: {
    WeatherWidgetEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8, humidity: 62.0, feelsLike: 29.5, windSpeed: 15.0, uvIndex: 8, pressure: 1015.0, lastUpdateDate: .now)
    WeatherWidgetEntry(date: .now, temperature: -3.7, condition: "Snowy", high: -1.2, low: -6.5, humidity: 92.0, feelsLike: -8.2, windSpeed: 32.0, uvIndex: 1, pressure: 995.0, lastUpdateDate: .now.addingTimeInterval(-120))
}

#Preview(as: .accessoryRectangular) {
    SaxWeatherWidget()
} timeline: {
    WeatherWidgetEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8, humidity: 62.0, feelsLike: 29.5, windSpeed: 15.0, uvIndex: 8, pressure: 1015.0, lastUpdateDate: .now)
    WeatherWidgetEntry(date: .now, temperature: 15.6, condition: "Rainy", high: 17.8, low: 12.4, humidity: 88.0, feelsLike: 14.2, windSpeed: 25.0, uvIndex: 2, pressure: 1005.0, lastUpdateDate: .now.addingTimeInterval(-240))
}

#Preview(as: .accessoryInline) {
    SaxWeatherWidget()
} timeline: {
    WeatherWidgetEntry(date: .now, temperature: 28.1, condition: "Sunny", high: 31.5, low: 23.8, humidity: 62.0, feelsLike: 29.5, windSpeed: 15.0, uvIndex: 8, pressure: 1015.0, lastUpdateDate: .now)
    WeatherWidgetEntry(date: .now, temperature: 15.6, condition: "Rainy", high: 17.8, low: 12.4, humidity: 88.0, feelsLike: 14.2, windSpeed: 25.0, uvIndex: 2, pressure: 1005.0, lastUpdateDate: .now.addingTimeInterval(-360))
}
#endif
