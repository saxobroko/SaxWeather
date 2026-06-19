//
//  WidgetStaleness.swift
//  SaxWeather
//
//  Created on 16/06/2026
//
//  Centralised "how old is too old" rules for cached weather
//  data. Lives in the main app target so both the host app
//  (which uses it for the stale data warning) and the widget
//  extension (which uses it for the "Updated Xm ago" footer)
//  agree on what counts as fresh. Also reachable from the
//  test target.
//

import Foundation

/// Centralised "how old is too old" rules for cached weather
/// data. Kept in the main app target so the host app, the
/// widget extension, and the test target all see the same
/// threshold.
enum WidgetStaleness {
    /// Cached data older than this is rendered with the "stale"
    /// presentation (e.g. "Updated 32m ago" badge). 30 minutes
    /// matches the typical weather update cadence and the
    /// timeline refresh interval the host uses.
    static let threshold: TimeInterval = 30 * 60

    /// Returns true when `date` is missing or older than the
    /// staleness threshold. `now` is injectable for tests.
    static func isStale(_ date: Date?, now: Date = Date()) -> Bool {
        guard let date else { return true }
        return now.timeIntervalSince(date) > threshold
    }
}
