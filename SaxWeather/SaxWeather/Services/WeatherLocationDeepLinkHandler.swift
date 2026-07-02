//
//  WeatherLocationDeepLinkHandler.swift
//  SaxWeather
//

import Foundation

/// Handles `saxweather://weather?...` and `https://weather.saxobroko.com/share?...` links.
@MainActor
final class WeatherLocationDeepLinkHandler: ObservableObject {
    @Published private(set) var pendingLink: PendingWeatherLink?

    @discardableResult
    func handle(url: URL) -> Bool {
        if let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" {
            return handleUniversalLink(url)
        }

        guard url.scheme?.lowercased() == WeatherShareLinkBuilder.scheme else {
            return false
        }

        let host = url.host?.lowercased()
        let firstPathSegment = url.pathComponents.first(where: { $0 != "/" })?.lowercased()
        guard host == WeatherShareLinkBuilder.host || firstPathSegment == WeatherShareLinkBuilder.host else {
            return false
        }

        return parseWeatherQuery(from: url)
    }

    private func handleUniversalLink(_ url: URL) -> Bool {
        guard url.host?.lowercased() == WeatherShareLinkBuilder.shareHost else {
            return false
        }

        let path = url.path.lowercased()
        guard path == "/share" || path.hasPrefix("/share/") else {
            return false
        }

        return parseWeatherQuery(from: url)
    }

    @discardableResult
    private func parseWeatherQuery(from url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return false
        }

        let values = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        guard let latString = values["lat"],
              let lonString = values["lon"],
              let latitude = Double(latString),
              let longitude = Double(lonString) else {
            return false
        }

        let name = values["name"]
        let stationID = values["station"]

        let link = PendingWeatherLink(
            latitude: latitude,
            longitude: longitude,
            name: name,
            stationID: stationID
        )

        pendingLink = link
        AppIntentNavigation.storePendingWeatherLink(link)
        return true
    }

    func clearPending() {
        pendingLink = nil
    }
}

struct PendingWeatherLink: Codable, Equatable, Identifiable {
    let latitude: Double
    let longitude: Double
    let name: String?
    let stationID: String?

    var id: String {
        "\(latitude)-\(longitude)-\(stationID ?? "")-\(name ?? "")"
    }
}
