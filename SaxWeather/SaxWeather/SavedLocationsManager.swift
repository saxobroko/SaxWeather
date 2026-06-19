import Foundation
import Combine
import CoreLocation

class SavedLocationsManager: ObservableObject {
    @Published var locations: [SavedLocation] = []
    @Published var selectedLocation: SavedLocation?
    
    private let userDefaultsKey = "savedLocations"
    private let selectedLocationKey = "selectedLocationID"
    
    init() {
        loadLocations()
        loadSelectedLocation()
    }
    
    func addLocation(_ location: SavedLocation) {
        locations.append(location)
        saveLocations()
    }
    
    /// Adds a new location with validation
    /// - Parameters:
    ///   - name: Location name
    ///   - latitude: Latitude coordinate
    ///   - longitude: Longitude coordinate
    /// - Returns: True if location was added successfully, false otherwise
    @discardableResult
    func addLocation(name: String, latitude: Double, longitude: Double) -> Bool {
        do {
            let location = try SavedLocation(name: name, latitude: latitude, longitude: longitude)
            addLocation(location)
            return true
        } catch {
            print("Failed to add location: \(error.localizedDescription)")
            return false
        }
    }
    
    func removeLocation(_ location: SavedLocation) {
        locations.removeAll { $0.id == location.id }
        saveLocations()
        // If the removed location was selected, fallback to GPS
        if selectedLocation?.id == location.id {
            selectCurrentLocation()
        }
    }
    
    func selectLocation(_ location: SavedLocation) {
        selectedLocation = location
        UserDefaults.standard.set(location.id.uuidString, forKey: selectedLocationKey)
        // Update UserDefaults for latitude/longitude and disable GPS
        let latString = "\(location.latitude)"
        let lonString = "\(location.longitude)"
        UserDefaults.standard.set(latString, forKey: "latitude")
        UserDefaults.standard.set(lonString, forKey: "longitude")
        UserDefaults.standard.set(false, forKey: "useGPS")
        WidgetSyncService.shared.syncManualCoordinates(
            latitude: latString,
            longitude: lonString
        )
    }

    func selectCurrentLocation() {
        selectedLocation = currentLocationEntry
        UserDefaults.standard.set(true, forKey: "useGPS")
        // Re-sync the widget with the new useGPS flag. Coordinates
        // come from the previously-published lastKnown* values if
        // any; if none exist yet, the widget will simply trigger a
        // fresh fetch on its next reload.
        let shared = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
        let lat = UserDefaults.standard.string(forKey: "lastKnownLatitude")
            ?? shared?.string(forKey: "lastKnownLatitude")
        let lon = UserDefaults.standard.string(forKey: "lastKnownLongitude")
            ?? shared?.string(forKey: "lastKnownLongitude")
        if let lat, let lon, !lat.isEmpty, !lon.isEmpty {
            WidgetSyncService.shared.syncGPSCoordinates(
                latitude: lat,
                longitude: lon
            )
        } else {
            WidgetSyncService.shared.syncAll(
                unitSystem: UserDefaults.standard.string(forKey: "unitSystem") ?? "Metric",
                useGPS: true,
                manualLatitude: nil,
                manualLongitude: nil,
                lastKnownLatitude: nil,
                lastKnownLongitude: nil,
                useOpenMeteoAsDefault: UserDefaults.standard.bool(forKey: "useOpenMeteoAsDefault")
            )
        }
    }
    
    var currentLocationEntry: SavedLocation {
        SavedLocation.currentLocationEntry
    }
    
    private func saveLocations() {
        if let data = try? JSONEncoder().encode(locations) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func loadLocations() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            locations = decoded
        } else {
            locations = []
        }
    }
    
    private func loadSelectedLocation() {
        // First check if GPS is enabled in UserDefaults
        let useGPS = UserDefaults.standard.bool(forKey: "useGPS")
        
        if useGPS {
            // GPS is enabled, use current location entry
            selectedLocation = currentLocationEntry
            return
        }
        
        // Otherwise, try to load saved location selection
        if let idString = UserDefaults.standard.string(forKey: selectedLocationKey),
           let uuid = UUID(uuidString: idString),
           let found = locations.first(where: { $0.id == uuid }) {
            selectedLocation = found
        } else {
            // Fallback to current location
            selectedLocation = currentLocationEntry
        }
    }
    
}
