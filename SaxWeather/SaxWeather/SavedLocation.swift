import Foundation
import CoreLocation

/// Error types for coordinate validation
enum CoordinateValidationError: Error, LocalizedError {
    case invalidCoordinates(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCoordinates(let reason):
            return "Invalid coordinates: \(reason)"
        }
    }
}

struct SavedLocation: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var isCurrentLocation: Bool = false
    
    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double, isCurrentLocation: Bool = false) throws {
        // Validate coordinates using our new validator
        let validationResult = CoordinateValidator.validate(latitude: latitude, longitude: longitude)
        
        guard validationResult.isValid else {
            throw CoordinateValidationError.invalidCoordinates(reason: validationResult.errorMessage ?? "Invalid coordinates")
        }
        
        self.id = id
        self.name = name
        self.latitude = validationResult.normalizedLatitude ?? latitude
        self.longitude = validationResult.normalizedLongitude ?? longitude
        self.isCurrentLocation = isCurrentLocation
    }
    
    // Convenience initializer for the special current location entry
    static var currentLocationEntry: SavedLocation {
        return try! SavedLocation(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            name: "Current Location (GPS)",
            latitude: 0,
            longitude: 0,
            isCurrentLocation: true
        )
    }
}