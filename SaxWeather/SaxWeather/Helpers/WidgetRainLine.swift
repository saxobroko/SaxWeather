//
//  WidgetRainLine.swift
//  SaxWeather
//
//  Shared rain-line formatting for the home / lock screen widget
//  and the host app's widget payload writer. Lives in Helpers so
//  both the main app and widget extension targets can compile it.
//

import Foundation

enum WidgetRainLine {
    /// Minimum probability (0–100) before we surface rain on the widget.
    static let probabilityThreshold = 30

    struct NextRain {
        let time: Date
        let probability: Int
        let isNow: Bool
    }

    static func nextSignificantRain(
        hours: [(hour: Date, probability: Int)],
        timeZoneIdentifier: String? = nil,
        now: Date = Date()
    ) -> NextRain? {
        var calendar = Calendar.current
        if let timeZoneIdentifier,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = timeZone
        }

        for item in hours {
            guard item.probability >= probabilityThreshold else { continue }
            let comparison = calendar.compare(item.hour, to: now, toGranularity: .hour)
            guard comparison != .orderedAscending else { continue }
            return NextRain(
                time: item.hour,
                probability: item.probability,
                isNow: comparison == .orderedSame
            )
        }
        return nil
    }

    static func format(_ rain: NextRain, timeZoneIdentifier: String? = nil) -> String {
        if rain.isNow {
            return "Rain now · \(rain.probability)%"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        if let timeZoneIdentifier,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            formatter.timeZone = timeZone
        }
        return "Rain at \(formatter.string(from: rain.time)) · \(rain.probability)%"
    }

    static func formatLine(
        time: Date?,
        probability: Int?,
        timeZoneIdentifier: String?,
        now: Date = Date()
    ) -> String? {
        guard let time, let probability else { return nil }

        var calendar = Calendar.current
        if let timeZoneIdentifier,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = timeZone
        }
        let isNow = calendar.compare(time, to: now, toGranularity: .hour) == .orderedSame
        return format(
            NextRain(time: time, probability: probability, isNow: isNow),
            timeZoneIdentifier: timeZoneIdentifier
        )
    }
}
