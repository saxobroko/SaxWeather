//
//  LocationWeatherPreviewRequest.swift
//  SaxWeather
//

import Foundation
import CoreLocation

/// Drives `LocationWeatherPreviewSheet` for share links, location peeks,
/// add-location flows, and long-press previews.
struct LocationWeatherPreviewRequest: Identifiable, Equatable, Codable {
    enum Mode: String, Codable, Equatable {
        case sharedLink
        case locationPeek
        case addLocation
        case peekOnly
    }

    let id: UUID
    let mode: Mode
    let latitude: Double
    let longitude: Double
    let name: String?
    let stationID: String?
    /// When peeking a saved location (including GPS sentinel).
    let savedLocationID: UUID?

    var isGPSPreview: Bool {
        savedLocationID == SavedLocation.currentLocationEntry.id
    }
}

extension LocationWeatherPreviewRequest {
    static func sharedLink(from link: PendingWeatherLink) -> LocationWeatherPreviewRequest {
        LocationWeatherPreviewRequest(
            id: UUID(),
            mode: .sharedLink,
            latitude: link.latitude,
            longitude: link.longitude,
            name: link.name,
            stationID: link.stationID,
            savedLocationID: nil
        )
    }

    static func locationPeek(
        savedLocation: SavedLocation,
        coordinates: CLLocationCoordinate2D? = nil
    ) -> LocationWeatherPreviewRequest {
        preview(
            mode: .locationPeek,
            savedLocation: savedLocation,
            coordinates: coordinates
        )
    }

    static func peekOnly(
        savedLocation: SavedLocation,
        coordinates: CLLocationCoordinate2D? = nil
    ) -> LocationWeatherPreviewRequest {
        preview(
            mode: .peekOnly,
            savedLocation: savedLocation,
            coordinates: coordinates
        )
    }

    static func addLocation(
        name: String,
        latitude: Double,
        longitude: Double
    ) -> LocationWeatherPreviewRequest {
        LocationWeatherPreviewRequest(
            id: UUID(),
            mode: .addLocation,
            latitude: latitude,
            longitude: longitude,
            name: name,
            stationID: nil,
            savedLocationID: nil
        )
    }

    private static func preview(
        mode: Mode,
        savedLocation: SavedLocation,
        coordinates: CLLocationCoordinate2D?
    ) -> LocationWeatherPreviewRequest {
        let latitude: Double
        let longitude: Double
        if savedLocation.isCurrentLocation, let coordinates {
            latitude = coordinates.latitude
            longitude = coordinates.longitude
        } else {
            latitude = savedLocation.latitude
            longitude = savedLocation.longitude
        }

        let name: String?
        if savedLocation.isCurrentLocation {
            name = "Current Location"
        } else {
            name = savedLocation.name
        }

        return LocationWeatherPreviewRequest(
            id: UUID(),
            mode: mode,
            latitude: latitude,
            longitude: longitude,
            name: name,
            stationID: nil,
            savedLocationID: savedLocation.id
        )
    }
}
