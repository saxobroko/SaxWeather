//
//  WidgetSyncService.swift
//  SaxWeather
//
//  Centralised, atomic synchronisation of all widget-visible state
//  (unit system, GPS / manual coordinates, data source preference,
//  cache invalidation token). Replaces the ad-hoc duplicate
//  `syncWidgetSettingsToSharedDefaults` call-sites that previously
//  existed on `WeatherService` and `SavedLocationsManager` and that
//  were the root cause of:
//
//    1. Data staleness – cached `latestWeather` was served even
//       after a background refresh failed or was delayed.
//    2. Unit-system mismatch – the cache stayed around in the old
//       units until a new fetch completed.
//    3. Coordinate-sync lag – GPS coordinates did not propagate to
//       the widget's manual `latitude` / `longitude` keys until a
//       second `CLLocationManager` callback fired.
//
//  Every public mutator pushes a complete, consistent snapshot of
//  widget-visible state into the shared App Group defaults and then
//  asks WidgetKit to reload all timelines. A monotonically
//  increasing `widgetDataVersion` key is bumped whenever unit
//  system, useGPS, coordinates (including last-known GPS), or
//  data-source preference changes so the widget can detect that
//  its cache is no longer current and force a fresh fetch.
//
//  `invalidateWidgetData()` lets the host explicitly mark the
//  cache as stale (e.g. after a background refresh failed),
//  and `stampCachedPayload()` records the current
//  `widgetDataVersion` alongside the cached unit system and
//  coordinates so the widget can detect a version mismatch
//  even when the cache timestamp is still fresh.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Centralised widget-sync service.
final class WidgetSyncService {
    static let shared = WidgetSyncService()

    // MARK: - Shared keys
    enum Keys {
        static let latestWeather     = "latestWeather"
        static let unitSystem        = "unitSystem"
        static let useGPS            = "useGPS"
        static let latitude          = "latitude"
        static let longitude         = "longitude"
        static let lastKnownLatitude = "lastKnownLatitude"
        static let lastKnownLongitude = "lastKnownLongitude"
        static let useOpenMeteoAsDefault = "useOpenMeteoAsDefault"
        /// Monotonically increasing token the widget can use to
        /// detect that the host app's settings have changed and
        /// that the cache should be considered stale.
        static let widgetDataVersion = "widgetDataVersion"
        /// Last value of `unitSystem` baked into the cache. The
        /// widget compares this against the live value in shared
        /// defaults to detect unit-system mismatch.
        static let cachedUnitSystem  = "cachedUnitSystem"
        /// Last baked-in (lat, lon) – widget compares against
        /// current values to detect location drift.
        static let cachedLatitude    = "cachedLatitude"
        static let cachedLongitude   = "cachedLongitude"
        static let cachedWidgetDataVersion = "cachedWidgetDataVersion"
        static let dataInvalidatedAt = "dataInvalidatedAt"
        static let hasEverFetched = "hasEverFetched"
    }

    // MARK: - Staleness threshold
    /// Maximum age of cached widget data before the widget treats
    /// it as stale. 15 minutes is a comfortable balance between
    /// freshness and the iOS background-refresh cadence.
    static let staleDataThreshold: TimeInterval = 15 * 60

    // MARK: - Suite handle
    private let sharedDefaults: UserDefaults? = UserDefaults(
        suiteName: "group.com.saxobroko.SaxWeather"
    )

    /// User-facing unit system keys we treat as a change. Anything
    /// else (display mode, theme, etc.) is irrelevant to the widget.
    static let recognisedUnitSystems: Set<String> = ["Metric", "Imperial", "UK"]

    private init() {}

    // MARK: - Snapshot sync

    func syncAll(
        unitSystem: String,
        useGPS: Bool,
        manualLatitude: String?,
        manualLongitude: String?,
        lastKnownLatitude: String?,
        lastKnownLongitude: String?,
        useOpenMeteoAsDefault: Bool
    ) {
        guard let sharedDefaults else { return }

        let previousVersion = sharedDefaults.integer(forKey: Keys.widgetDataVersion)
        let previousUnit    = sharedDefaults.string(forKey: Keys.unitSystem)
        let previousLat     = sharedDefaults.string(forKey: Keys.latitude)
        let previousLon     = sharedDefaults.string(forKey: Keys.longitude)
        let previousUseGPS  = sharedDefaults.bool(forKey: Keys.useGPS)
        let previousOpenMet = sharedDefaults.bool(forKey: Keys.useOpenMeteoAsDefault)
        // Track the last-known GPS coordinates too. Without this,
        // a GPS-mode user moving to a new location would never
        // bump the version (the manual lat/lon keys stay empty
        // in GPS mode) and the widget would never be told to
        // re-read the cache. This is the root cause of
        // "Widget coordinates might not sync properly with the
        // main app when location settings change".
        let previousLastKnownLat = sharedDefaults.string(forKey: Keys.lastKnownLatitude)
        let previousLastKnownLon = sharedDefaults.string(forKey: Keys.lastKnownLongitude)

        sharedDefaults.set(unitSystem, forKey: Keys.unitSystem)
        sharedDefaults.set(useGPS, forKey: Keys.useGPS)
        sharedDefaults.set(useOpenMeteoAsDefault, forKey: Keys.useOpenMeteoAsDefault)

        // Coordinates
        if let manualLatitude, !manualLatitude.isEmpty {
            sharedDefaults.set(manualLatitude, forKey: Keys.latitude)
        }
        if let manualLongitude, !manualLongitude.isEmpty {
            sharedDefaults.set(manualLongitude, forKey: Keys.longitude)
        }
        if let lastKnownLatitude, !lastKnownLatitude.isEmpty {
            sharedDefaults.set(lastKnownLatitude, forKey: Keys.lastKnownLatitude)
        }
        if let lastKnownLongitude, !lastKnownLongitude.isEmpty {
            sharedDefaults.set(lastKnownLongitude, forKey: Keys.lastKnownLongitude)
        }

        // Bump the version token if anything that affects widget
        // interpretation actually changed. The widget treats any
        // version bump as "cache is no longer authoritative – go
        // fetch fresh data".
        //
        // IMPORTANT: must also compare the last-known GPS
        // coordinates – a GPS-mode user moving to a new location
        // would otherwise leave `previousLat`/`previousLon` as
        // `nil` on both sides of the comparison and silently
        // fail to bump the version. That is the root cause of
        // "Widget coordinates might not sync properly with the
        // main app when location settings change".
        let somethingChanged =
            previousUnit != unitSystem ||
            previousUseGPS != useGPS ||
            previousOpenMet != useOpenMeteoAsDefault ||
            previousLat != manualLatitude ||
            previousLon != manualLongitude ||
            previousLastKnownLat != lastKnownLatitude ||
            previousLastKnownLon != lastKnownLongitude

        if somethingChanged {
            sharedDefaults.set(previousVersion + 1, forKey: Keys.widgetDataVersion)
            #if DEBUG
            print("🔄 WidgetSyncService: version bumped to \(previousVersion + 1) (unit/useGPS/coord/source changed)")
            #endif
        }

        reloadAllTimelines()
    }

    // MARK: - Targeted updates

    /// Sync only the unit system (e.g. user just toggled °C / °F
    /// in Preferences). Bumps the version token and asks the widget
    /// to reload.
    func syncUnitSystem(_ unitSystem: String) {
        let snapshot = currentSnapshot()
        syncAll(
            unitSystem: unitSystem,
            useGPS: snapshot.useGPS,
            manualLatitude: snapshot.manualLatitude,
            manualLongitude: snapshot.manualLongitude,
            lastKnownLatitude: snapshot.lastKnownLatitude,
            lastKnownLongitude: snapshot.lastKnownLongitude,
            useOpenMeteoAsDefault: snapshot.useOpenMeteoAsDefault
        )
    }

    /// Sync the manual coordinate selection. Bumps the version
    /// token if the new coordinates differ from the previous ones.
    func syncManualCoordinates(latitude: String, longitude: String) {
        let snapshot = currentSnapshot()
        syncAll(
            unitSystem: snapshot.unitSystem,
            useGPS: false,
            manualLatitude: latitude,
            manualLongitude: longitude,
            lastKnownLatitude: snapshot.lastKnownLatitude,
            lastKnownLongitude: snapshot.lastKnownLongitude,
            useOpenMeteoAsDefault: snapshot.useOpenMeteoAsDefault
        )
    }

    func syncGPSCoordinates(latitude: String, longitude: String) {
        let snapshot = currentSnapshot()
        syncAll(
            unitSystem: snapshot.unitSystem,
            useGPS: true,
            manualLatitude: nil,
            manualLongitude: nil,
            lastKnownLatitude: latitude,
            lastKnownLongitude: longitude,
            useOpenMeteoAsDefault: snapshot.useOpenMeteoAsDefault
        )
    }

    /// Refresh widget timelines only – useful when the host app
    /// has finished a fetch and wants the widget to pick up the
    /// new `latestWeather` payload.
    func reloadAllTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - Cache-version stamping

    func stampCachedPayload(
        latitude: Double?,
        longitude: Double?,
        unitSystem: String
    ) {
        guard let sharedDefaults else { return }
        if let latitude {
            sharedDefaults.set("\(latitude)", forKey: Keys.cachedLatitude)
        }
        if let longitude {
            sharedDefaults.set("\(longitude)", forKey: Keys.cachedLongitude)
        }
        sharedDefaults.set(unitSystem, forKey: Keys.cachedUnitSystem)
        // Stamp the current `widgetDataVersion` so the widget
        // can compare it against the live value to detect that
        // host-app state has changed since this cache was
        // baked. Without this stamp, the widget would only
        // detect staleness via the timestamp and would miss
        // instantaneous unit / GPS / source changes.
        let currentVersion = sharedDefaults.integer(forKey: Keys.widgetDataVersion)
        sharedDefaults.set(currentVersion, forKey: Keys.cachedWidgetDataVersion)
    }

    func invalidateWidgetData() {
        guard let sharedDefaults else { return }
        sharedDefaults.set(
            Date().timeIntervalSince1970,
            forKey: Keys.dataInvalidatedAt
        )
        #if DEBUG
        print("⚠️ WidgetSyncService: widget data marked invalid at \(Date())")
        #endif
        reloadAllTimelines()
    }

    func clearInvalidation() {
        guard let sharedDefaults else { return }
        sharedDefaults.removeObject(forKey: Keys.dataInvalidatedAt)
    }

    // MARK: - First-sync tracking

    func markHasEverFetched() {
        guard let sharedDefaults else { return }
        let current = sharedDefaults.bool(forKey: Keys.hasEverFetched)
        if !current {
            sharedDefaults.set(true, forKey: Keys.hasEverFetched)
            #if DEBUG
            print("✅ WidgetSyncService: marked hasEverFetched=true (host has saved at least one payload)")
            #endif
        }
    }

    /// Reset the "host has saved" flag. Test-only – the
    /// production app should never need to clear this.
    func resetHasEverFetched() {
        sharedDefaults?.removeObject(forKey: Keys.hasEverFetched)
    }

    // MARK: - Snapshot reader
    private struct Snapshot {
        let unitSystem: String
        let useGPS: Bool
        let manualLatitude: String?
        let manualLongitude: String?
        let lastKnownLatitude: String?
        let lastKnownLongitude: String?
        let useOpenMeteoAsDefault: Bool
    }

    private func currentSnapshot() -> Snapshot {
        let shared = sharedDefaults
        let standard = UserDefaults.standard
        return Snapshot(
            unitSystem: standard.string(forKey: Keys.unitSystem) ?? "Metric",
            useGPS: standard.bool(forKey: Keys.useGPS),
            manualLatitude: standard.string(forKey: Keys.latitude),
            manualLongitude: standard.string(forKey: Keys.longitude),
            lastKnownLatitude: shared?.string(forKey: Keys.lastKnownLatitude),
            lastKnownLongitude: shared?.string(forKey: Keys.lastKnownLongitude),
            useOpenMeteoAsDefault: standard.bool(forKey: Keys.useOpenMeteoAsDefault)
        )
    }
}
