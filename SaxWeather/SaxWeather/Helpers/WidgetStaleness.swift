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

enum WidgetStaleness {
    static let threshold: TimeInterval = 30 * 60

    /// Returns true when `date` is missing or older than the
    /// staleness threshold. `now` is injectable for tests.
    static func isStale(_ date: Date?, now: Date = Date()) -> Bool {
        guard let date else { return true }
        return now.timeIntervalSince(date) > threshold
    }
}
