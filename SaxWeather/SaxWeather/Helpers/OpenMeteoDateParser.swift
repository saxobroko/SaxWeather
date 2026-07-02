//
//  OpenMeteoDateParser.swift
//  SaxWeather
//

import Foundation

/// Parses Open-Meteo timestamp strings, which are returned in the
/// requested timezone without a UTC offset suffix.
enum OpenMeteoDateParser {
    private static let formats = [
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm"
    ]

    static func timeZone(
        identifier: String?,
        utcOffsetSeconds: Int?
    ) -> TimeZone {
        if let identifier,
           let timeZone = TimeZone(identifier: identifier) {
            return timeZone
        }

        if let utcOffsetSeconds {
            return TimeZone(secondsFromGMT: utcOffsetSeconds) ?? .current
        }

        return .current
    }

    static func date(
        from timeString: String,
        timeZone: TimeZone
    ) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: timeString) {
                return date
            }
        }

        return nil
    }

    static func date(
        from timeString: String,
        identifier: String?,
        utcOffsetSeconds: Int?
    ) -> Date? {
        date(
            from: timeString,
            timeZone: timeZone(identifier: identifier, utcOffsetSeconds: utcOffsetSeconds)
        )
    }
}
