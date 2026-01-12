//
//  DateFormatter+Extensions.swift
//  SaxWeather
//
//  Created by GitHub Copilot on 2025-12-18
//

import Foundation

extension DateFormatter {
    /// Shared ISO8601 date formatter for weather data parsing
    static let weatherISO8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withTimeZone]
        return formatter
    }()
    
    /// Shared date formatter for display in the app
    static let weatherDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// Shared date formatter for alert RSS feeds
    static let alertRSS: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
        return formatter
    }()
}

extension Date {
    /// Format date for weather display
    var weatherDisplayString: String {
        DateFormatter.weatherDisplay.string(from: self)
    }
    
    /// Parse ISO8601 date string commonly used in weather APIs
    static func fromWeatherISO8601(_ string: String) -> Date? {
        return DateFormatter.weatherISO8601.date(from: string)
    }
}
