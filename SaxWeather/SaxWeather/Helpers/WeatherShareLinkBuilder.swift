//
//  WeatherShareLinkBuilder.swift
//  SaxWeather
//

import Foundation
import CoreLocation

// MARK: - Place name resolution

enum ShareLocationPlaceholder {
    private static let names: Set<String> = [
        "Current Location",
        "Current Location (GPS)"
    ]

    static func isPlaceholder(_ name: String?) -> Bool {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return true
        }
        return names.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
    }
}

@MainActor
final class ShareLocationResolver {
    static let shared = ShareLocationResolver()

    private struct CacheEntry {
        let name: String
        let timestamp: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 5 * 60
    private let geocoder = CLGeocoder()

    private func cacheKey(latitude: Double, longitude: Double) -> String {
        String(format: "%.4f,%.4f", latitude, longitude)
    }

    static func coordinateFallback(latitude: Double, longitude: Double) -> String {
        String(format: "%.4f, %.4f", latitude, longitude)
    }

    func resolveName(
        latitude: Double,
        longitude: Double,
        preferredName: String?,
        weatherLocationName: String?
    ) async -> String {
        if let weatherName = weatherLocationName,
           !weatherName.isEmpty,
           !ShareLocationPlaceholder.isPlaceholder(weatherName) {
            return weatherName
        }

        if let preferredName,
           !ShareLocationPlaceholder.isPlaceholder(preferredName) {
            return preferredName
        }

        let key = cacheKey(latitude: latitude, longitude: longitude)
        if let entry = cache[key],
           Date().timeIntervalSince(entry.timestamp) < cacheTTL {
            return entry.name
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)
        let resolvedName: String
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            resolvedName = placemarkName(placemarks.first)
                ?? Self.coordinateFallback(latitude: latitude, longitude: longitude)
        } catch {
            resolvedName = Self.coordinateFallback(latitude: latitude, longitude: longitude)
        }

        cache[key] = CacheEntry(name: resolvedName, timestamp: Date())
        return resolvedName
    }

    private func placemarkName(_ placemark: CLPlacemark?) -> String? {
        guard let placemark else { return nil }

        var parts: [String] = []
        if let locality = placemark.locality, !locality.isEmpty {
            parts.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea, !administrativeArea.isEmpty {
            parts.append(administrativeArea)
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

/// Inputs needed to build share links and text summaries.
struct WeatherShareContext {
    let weather: Weather
    let locationName: String
    let unitSystem: String
    let latitude: Double?
    let longitude: Double?
    /// PWS station ID when Weather Underground is the active source.
    let stationID: String?

    static func make(
        weather: Weather,
        locationName: String,
        unitSystem: String,
        weatherService: WeatherService,
        locationsManager: SavedLocationsManager
    ) -> WeatherShareContext {
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        let wuKey = KeychainService.shared.getApiKey(forService: "wu") ?? ""
        let activeStation: String? = (
            weatherService.currentDataSource == "weatherunderground"
            && !wuKey.isEmpty
            && !stationID.isEmpty
        ) ? stationID : nil

        let coordinates = resolveCoordinates(
            weatherService: weatherService,
            locationsManager: locationsManager
        )

        return WeatherShareContext(
            weather: weather,
            locationName: locationName,
            unitSystem: unitSystem,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            stationID: activeStation
        )
    }

    /// Resolves GPS / placeholder names before building share URLs.
    static func makeResolving(
        weather: Weather,
        locationName: String,
        unitSystem: String,
        weatherService: WeatherService,
        locationsManager: SavedLocationsManager
    ) async -> WeatherShareContext {
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        let wuKey = KeychainService.shared.getApiKey(forService: "wu") ?? ""
        let activeStation: String? = (
            weatherService.currentDataSource == "weatherunderground"
            && !wuKey.isEmpty
            && !stationID.isEmpty
        ) ? stationID : nil

        let coordinates = resolveCoordinates(
            weatherService: weatherService,
            locationsManager: locationsManager
        )

        let resolvedName: String
        if let latitude = coordinates.latitude, let longitude = coordinates.longitude {
            resolvedName = await ShareLocationResolver.shared.resolveName(
                latitude: latitude,
                longitude: longitude,
                preferredName: locationName,
                weatherLocationName: weather.locationName
            )
        } else if !ShareLocationPlaceholder.isPlaceholder(locationName) {
            resolvedName = locationName
        } else if let weatherName = weather.locationName, !weatherName.isEmpty {
            resolvedName = weatherName
        } else {
            resolvedName = "Unknown Location"
        }

        return WeatherShareContext(
            weather: weather,
            locationName: resolvedName,
            unitSystem: unitSystem,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            stationID: activeStation
        )
    }

    private static func resolveCoordinates(
        weatherService: WeatherService,
        locationsManager: SavedLocationsManager
    ) -> (latitude: Double?, longitude: Double?) {
        if weatherService.useGPS,
           let location = weatherService.locationManager.location {
            return (location.coordinate.latitude, location.coordinate.longitude)
        }

        if let selected = locationsManager.selectedLocation,
           !selected.isCurrentLocation {
            return (selected.latitude, selected.longitude)
        }

        let lat = Double(UserDefaults.standard.string(forKey: "latitude") ?? "")
        let lon = Double(UserDefaults.standard.string(forKey: "longitude") ?? "")
        return (lat, lon)
    }
}

enum WeatherShareLinkBuilder {
    static let scheme = "saxweather"
    static let host = "weather"
    static let shareBaseURL = "https://weather.saxobroko.com/share"
    static let shareHost = "weather.saxobroko.com"

    /// HTTPS share URL with weather params for rich iMessage / Open Graph previews.
    static func makePublicShareURL(from context: WeatherShareContext) -> URL? {
        guard let latitude = context.latitude,
              let longitude = context.longitude else {
            return nil
        }

        var components = URLComponents(string: shareBaseURL)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "lat", value: String(format: "%.6f", latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.6f", longitude)),
            URLQueryItem(name: "name", value: context.locationName)
        ]

        let unit = UnitSystem.from(rawValue: context.unitSystem)
        let unitCode = unit.usesCelsius ? "C" : "F"

        if let temp = context.weather.temperature {
            queryItems.append(URLQueryItem(name: "temp", value: String(format: "%.1f", temp)))
            queryItems.append(URLQueryItem(name: "unit", value: unitCode))
        }

        queryItems.append(URLQueryItem(name: "condition", value: context.weather.condition))

        if let feels = context.weather.feelsLike {
            queryItems.append(URLQueryItem(name: "feels", value: String(format: "%.1f", feels)))
        }

        if let high = context.weather.high, let low = context.weather.low {
            queryItems.append(URLQueryItem(name: "high", value: String(format: "%.0f", high)))
            queryItems.append(URLQueryItem(name: "low", value: String(format: "%.0f", low)))
        }

        if let stationID = context.stationID, !stationID.isEmpty {
            queryItems.append(URLQueryItem(name: "station", value: stationID))
        }

        components?.queryItems = queryItems
        return components?.url
    }

    /// Deep link that opens this place (and optional PWS station) in SaxWeather.
    static func makeDeepLinkURL(from context: WeatherShareContext) -> URL? {
        guard let latitude = context.latitude,
              let longitude = context.longitude else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.6f", latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.6f", longitude)),
            URLQueryItem(name: "name", value: context.locationName)
        ]

        if let stationID = context.stationID, !stationID.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "station", value: stationID))
        }

        return components.url
    }

    static func makeAppleMapsURL(from context: WeatherShareContext) -> URL? {
        guard let latitude = context.latitude,
              let longitude = context.longitude else {
            return nil
        }

        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: context.locationName)
        ]
        return components?.url
    }

    /// Message body when sharing a SaxWeather link.
    static func makeLinkShareText(from context: WeatherShareContext) -> String {
        guard let publicURL = makePublicShareURL(from: context) else {
            return summaryText(from: context)
        }

        var lines = [
            "Check the weather for \(context.locationName) in SaxWeather:",
            publicURL.absoluteString
        ]

        if let stationID = context.stationID {
            lines.append("Personal weather station: \(stationID)")
        }

        if let mapsURL = makeAppleMapsURL(from: context) {
            lines.append("Map: \(mapsURL.absoluteString)")
        }

        return lines.joined(separator: "\n")
    }

    /// Plain-text weather summary for Messages, email, etc.
    static func summaryText(from context: WeatherShareContext) -> String {
        let unit = UnitSystem.from(rawValue: context.unitSystem)
        let tempSymbol = unit.temperatureLabel

        var parts: [String] = ["\(context.locationName):"]

        if let temp = context.weather.temperature {
            parts.append(String(format: "%.1f%@, %@", temp, tempSymbol, context.weather.condition))
        } else {
            parts.append(context.weather.condition)
        }

        if let feels = context.weather.feelsLike {
            parts.append(String(format: "Feels like %.1f%@", feels, tempSymbol))
        }

        if let high = context.weather.high, let low = context.weather.low {
            parts.append(String(format: "H %.0f%@ · L %.0f%@", high, tempSymbol, low, tempSymbol))
        }

        if let rain = rainLine(from: context) {
            parts.append(rain)
        }

        if let stationID = context.stationID {
            parts.append("PWS \(stationID)")
        }

        parts.append("— SaxWeather")
        return parts.joined(separator: " ")
    }

    private static func rainLine(from context: WeatherShareContext) -> String? {
        let hours = context.weather.hourlyPrecipitation.map {
            (hour: $0.hour, probability: $0.probability)
        }
        guard !hours.isEmpty else { return nil }

        if let nextRain = WidgetRainLine.nextSignificantRain(
            hours: hours,
            timeZoneIdentifier: context.weather.locationTimeZoneIdentifier
        ) {
            return WidgetRainLine.format(nextRain, timeZoneIdentifier: context.weather.locationTimeZoneIdentifier)
        }

        return nil
    }
}
