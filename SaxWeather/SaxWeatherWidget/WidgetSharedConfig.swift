//
//  WidgetSharedConfig.swift
//  SaxWeatherWidget
//
//  Constants and helpers used by the widget extension to read
//  host-app state from the App Group defaults and to decide
//  whether the cached `latestWeather` payload is still valid.
//
//  The corresponding host-side writer lives in
//  `SaxWeather/WidgetSyncService.swift`. The two files share the
//  same key strings and staleness threshold, but they intentionally
//  do NOT depend on each other (extensions cannot import the
//  host app's modules) so the constants are duplicated by design.
//

import Foundation

enum WidgetSharedConfig {
    /// App Group suite that both host and widget can read.
    static let appGroupSuiteName = "group.com.saxobroko.SaxWeather"

    /// Maximum age of cached widget data before the widget treats
    /// it as stale. Mirrors `WidgetSyncService.staleDataThreshold`.
    static let staleDataThreshold: TimeInterval = 15 * 60

    enum Keys {
        static let latestWeather       = "latestWeather"
        static let unitSystem          = "unitSystem"
        static let useGPS              = "useGPS"
        static let latitude            = "latitude"
        static let longitude           = "longitude"
        static let lastKnownLatitude   = "lastKnownLatitude"
        static let lastKnownLongitude  = "lastKnownLongitude"
        static let useOpenMeteoAsDefault = "useOpenMeteoAsDefault"
        static let widgetDataVersion   = "widgetDataVersion"
        static let cachedUnitSystem    = "cachedUnitSystem"
        static let cachedLatitude      = "cachedLatitude"
        static let cachedLongitude     = "cachedLongitude"
        /// Value of `widgetDataVersion` baked into the most
        /// recent cache. The widget compares this against the
        /// live `widgetDataVersion` to detect host-app state
        /// changes even when the cache timestamp is still
        /// fresh. See `WidgetSyncService.stampCachedPayload`.
        static let cachedWidgetDataVersion = "cachedWidgetDataVersion"
        /// Timestamp the host wrote to explicitly mark the
        /// cached `latestWeather` payload as invalid (e.g.
        /// when a background refresh failed). See
        /// `WidgetSyncService.invalidateWidgetData`.
        static let dataInvalidatedAt   = "dataInvalidatedAt"
        /// Boolean set by the host the first time it writes
        /// a successful `latestWeather` payload. The widget
        /// reads this to distinguish between "host has never
        /// been launched" and "cache happens to be empty
        /// right now". See
        /// `WidgetSyncService.markHasEverFetched`.
        static let hasEverFetched     = "hasEverFetched"
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupSuiteName)
    }
}

/// Lightweight, side-effect-free inspection of the cached
/// `latestWeather` payload. The widget uses this to decide whether
/// it can show the cache directly or must first trigger a fresh
/// fetch.
enum WidgetCacheInspector {
    /// Treat the cache as stale if it is older than the
    /// `staleDataThreshold` or has no timestamp at all.
    static func isStale(_ cachedPayload: [String: Any]) -> Bool {
        guard let timestamp = cachedPayload["lastUpdateDate"] as? Double else {
            return true
        }
        let lastUpdate = Date(timeIntervalSince1970: timestamp)
        return Date().timeIntervalSince(lastUpdate) > WidgetSharedConfig.staleDataThreshold
    }

    /// Has the host app changed its unit system since the cache
    /// was last written?
    static func isUnitSystemMismatch(_ cachedPayload: [String: Any]) -> Bool {
        let defaults = WidgetSharedConfig.sharedDefaults
        let liveUnit = defaults?.string(forKey: WidgetSharedConfig.Keys.unitSystem) ?? "Metric"
        let bakedUnit = (cachedPayload["unitSystem"] as? String)
            ?? defaults?.string(forKey: WidgetSharedConfig.Keys.cachedUnitSystem)
        guard let bakedUnit else { return false }
        return bakedUnit != liveUnit
    }

    /// Have the host app's coordinates drifted (GPS update, manual
    /// change, saved-location switch) since the cache was baked?
    static func isLocationMismatch(_ cachedPayload: [String: Any]) -> Bool {
        let defaults = WidgetSharedConfig.sharedDefaults
        let useGPS = defaults?.bool(forKey: WidgetSharedConfig.Keys.useGPS) ?? false

        // Live lat/lon the widget will use for its next fetch.
        let liveLat: String?
        let liveLon: String?
        if useGPS {
            liveLat = defaults?.string(forKey: WidgetSharedConfig.Keys.lastKnownLatitude)
                ?? defaults?.string(forKey: WidgetSharedConfig.Keys.latitude)
            liveLon = defaults?.string(forKey: WidgetSharedConfig.Keys.lastKnownLongitude)
                ?? defaults?.string(forKey: WidgetSharedConfig.Keys.longitude)
        } else {
            liveLat = defaults?.string(forKey: WidgetSharedConfig.Keys.latitude)
            liveLon = defaults?.string(forKey: WidgetSharedConfig.Keys.longitude)
        }

        // Coordinates baked into the cache. Fall back to a stamp
        // the host app writes via WidgetSyncService.stampCachedPayload.
        let bakedLat = (cachedPayload["latitude"] as? Double)
            .map { String($0) }
            ?? defaults?.string(forKey: WidgetSharedConfig.Keys.cachedLatitude)
        let bakedLon = (cachedPayload["longitude"] as? Double)
            .map { String($0) }
            ?? defaults?.string(forKey: WidgetSharedConfig.Keys.cachedLongitude)

        // If we don't have a live position yet, don't claim a mismatch.
        guard let liveLat, let liveLon,
              !liveLat.isEmpty, !liveLon.isEmpty else { return false }

        // First-ever cache: nothing to compare against.
        guard let bakedLat, let bakedLon,
              !bakedLat.isEmpty, !bakedLon.isEmpty else { return false }

        return bakedLat != liveLat || bakedLon != liveLon
    }

    /// Has the host app bumped its `widgetDataVersion` since the
    /// cache was baked? This catches unit-system changes, data
    /// source changes, *and* last-known GPS coordinate changes
    /// in a single, cheap comparison – the host bumps the
    /// version on any of those, and the cache stamps the value
    /// it was baked against via
    /// `WidgetSyncService.stampCachedPayload`.
    ///
    /// Returns false if the cache doesn't carry a version stamp
    /// yet (e.g. it was written by a previous build of the
    /// host), in which case the timestamp-based staleness check
    /// is the only fallback.
    static func isVersionMismatch(_ cachedPayload: [String: Any]) -> Bool {
        let defaults = WidgetSharedConfig.sharedDefaults
        let liveVersion = defaults?.integer(forKey: WidgetSharedConfig.Keys.widgetDataVersion) ?? 0
        let bakedVersion: Int? = {
            if let inline = cachedPayload["widgetDataVersion"] as? Int { return inline }
            if let stamped = defaults?.object(forKey: WidgetSharedConfig.Keys.cachedWidgetDataVersion) as? Int {
                return stamped
            }
            return nil
        }()
        guard let bakedVersion else { return false }
        return bakedVersion < liveVersion
    }

    /// Has the host app explicitly invalidated the cache (e.g.
    /// because a background refresh failed)? Returns true if
    /// the host wrote a `dataInvalidatedAt` timestamp later
    /// than the cache's own `lastUpdateDate`, in which case
    /// the cache is no longer trustworthy even if it has not
    /// aged out yet.
    static func isExplicitlyInvalidated(_ cachedPayload: [String: Any]) -> Bool {
        let defaults = WidgetSharedConfig.sharedDefaults
        guard let invalidatedAt = defaults?.object(forKey: WidgetSharedConfig.Keys.dataInvalidatedAt) as? Double,
              invalidatedAt > 0 else {
            return false
        }
        // If the cache has a timestamp and the invalidation
        // happened after it, the cache is stale by definition.
        if let bakedTimestamp = cachedPayload["lastUpdateDate"] as? Double {
            return invalidatedAt > bakedTimestamp
        }
        // Cache has no timestamp at all – treat any
        // invalidation as a mismatch.
        return true
    }
}
