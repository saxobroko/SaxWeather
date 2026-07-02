import Foundation
import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct LocationEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Location"
    static var defaultQuery = LocationEntityQuery()
    
    let id: UUID
    @Property(title: "Name")
    var name: String
    
    @Property(title: "Latitude")
    var latitude: Double
    
    @Property(title: "Longitude")
    var longitude: Double
    
    @Property(title: "Is Current Location")
    var isCurrentLocation: Bool
    
    init(id: UUID, name: String, latitude: Double, longitude: Double, isCurrentLocation: Bool) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.isCurrentLocation = isCurrentLocation
    }
    
    init(from savedLocation: SavedLocation) {
        self.id = savedLocation.id
        self.name = savedLocation.name
        self.latitude = savedLocation.latitude
        self.longitude = savedLocation.longitude
        self.isCurrentLocation = savedLocation.isCurrentLocation
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct LocationEntityQuery: EntityStringQuery {
    func entities(for identifiers: [LocationEntity.ID]) async throws -> [LocationEntity] {
        let allLocations = getAllLocations()
        return allLocations.filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [LocationEntity] {
        return getAllLocations()
    }
    
    func defaultResult() async -> LocationEntity? {
        return getAllLocations().first(where: { $0.isCurrentLocation }) ?? getAllLocations().first
    }
    
    func entities(matching string: String) async throws -> [LocationEntity] {
        let allLocations = getAllLocations()
        return allLocations.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
    
    private func getAllLocations() -> [LocationEntity] {
        // Load from UserDefaults
        let userDefaultsKey = "savedLocations"
        var locations: [SavedLocation] = []
        
        let sharedDefaults = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
        if let data = sharedDefaults?.data(forKey: userDefaultsKey) ?? UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            locations = decoded
        }
        
        // Add current location entry at the top
        var allLocations = [LocationEntity(from: SavedLocation.currentLocationEntry)]
        allLocations.append(contentsOf: locations.map { LocationEntity(from: $0) })
        
        return allLocations
    }
}
