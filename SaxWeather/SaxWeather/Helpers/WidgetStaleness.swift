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

    /// Short relative time for hero labels and widgets —
    /// "just now", "12m ago", "2h ago", or "yesterday".
    /// `now` is injectable for tests and `TimelineView`.
    static func relativeUpdateString(from date: Date, now: Date = Date()) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "yesterday"
    }
}
