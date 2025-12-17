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
        UserDefaults.standard.set("\(location.latitude)", forKey: "latitude")
        UserDefaults.standard.set("\(location.longitude)", forKey: "longitude")
        UserDefaults.standard.set(false, forKey: "useGPS")
    }
    
    func selectCurrentLocation() {
        selectedLocation = currentLocationEntry
        UserDefaults.standard.set(true, forKey: "useGPS")
    }
    
    var currentLocationEntry: SavedLocation {
        SavedLocation(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, name: "Current Location (GPS)", latitude: 0, longitude: 0, isCurrentLocation: true)
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
        if let idString = UserDefaults.standard.string(forKey: selectedLocationKey),
           let uuid = UUID(uuidString: idString),
           let found = locations.first(where: { $0.id == uuid }) {
            selectedLocation = found
        } else {
            selectedLocation = currentLocationEntry
        }
    }
} 