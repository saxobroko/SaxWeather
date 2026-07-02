//
//  WeatherAlertProximityFilter.swift
//  SaxWeather
//
//  Filters state-wide BOM warnings down to those geographically near the user.
//

import Foundation
import CoreLocation

actor WeatherAlertProximityFilter {
    static let shared = WeatherAlertProximityFilter()

    private let geocoder = CLGeocoder()
    private var cache: [String: CLLocationCoordinate2D?] = [:]

    /// Keeps alerts whose affected area is within `maxDistanceKm` of the user.
    /// Alerts whose location cannot be resolved are kept, so a genuinely relevant
    /// warning is never hidden just because geocoding failed.
    func filter(
        alerts: [WeatherAlert],
        userLatitude: Double,
        userLongitude: Double,
        stateName: String,
        maxDistanceKm: Double
    ) async -> [WeatherAlert] {
        let user = CLLocation(latitude: userLatitude, longitude: userLongitude)
        var result: [WeatherAlert] = []

        for alert in alerts {
            if await shouldKeep(
                alert: alert,
                user: user,
                stateName: stateName,
                maxDistanceKm: maxDistanceKm
            ) {
                result.append(alert)
            }
        }

        return result
    }

    private func shouldKeep(
        alert: WeatherAlert,
        user: CLLocation,
        stateName: String,
        maxDistanceKm: Double
    ) async -> Bool {
        let components = areaComponents(for: alert)
        guard !components.isEmpty else { return true }

        var anyResolved = false
        for component in components {
            guard let coordinate = await coordinate(for: component, stateName: stateName) else {
                continue
            }
            anyResolved = true
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if location.distance(from: user) <= maxDistanceKm * 1000 {
                return true
            }
        }

        // If nothing resolved we can't judge distance, so keep it to be safe.
        return !anyResolved
    }

    private func areaComponents(for alert: WeatherAlert) -> [String] {
        let source = alert.affectedArea ?? extractAfterFor(alert.type)
        guard let source, !source.isEmpty else { return [] }

        let separators = CharacterSet(charactersIn: ",&/")
        var tokens = source
            .replacingOccurrences(of: " and ", with: ",")
            .components(separatedBy: separators)

        tokens = tokens.map { cleanComponent($0) }.filter { !$0.isEmpty }

        // De-duplicate while preserving order.
        var seen = Set<String>()
        return tokens.filter { seen.insert($0.lowercased()).inserted }
    }

    private func extractAfterFor(_ title: String) -> String? {
        let ns = title.lowercased() as NSString
        let range = ns.range(of: " for ", options: .backwards)
        guard range.location != NSNotFound else { return nil }
        let start = range.location + range.length
        return String(title.dropFirst(start))
    }

    private func cleanComponent(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let noisePrefixes = ["parts of ", "part of ", "people in ", "the "]
        let noiseSuffixes = [
            " forecast districts", " forecast district",
            " districts", " district", " region", " regions"
        ]

        var lower = text.lowercased()
        for prefix in noisePrefixes where lower.hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count))
            lower = text.lowercased()
        }
        for suffix in noiseSuffixes where lower.hasSuffix(suffix) {
            text = String(text.dropLast(suffix.count))
            lower = text.lowercased()
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private func coordinate(for component: String, stateName: String) async -> CLLocationCoordinate2D? {
        let query = "\(component), \(stateName), Australia"
        let key = query.lowercased()
        if let cached = cache[key] {
            return cached
        }

        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            let coordinate = placemarks.first?.location?.coordinate
            cache[key] = coordinate
            return coordinate
        } catch {
            // Throttling or "no result" – record nil so we don't retry this run.
            cache[key] = CLLocationCoordinate2D?.none
            return nil
        }
    }
}
