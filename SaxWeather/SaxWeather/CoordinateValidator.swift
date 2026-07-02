//
//  CoordinateValidator.swift
//  SaxWeather
//
//  Created by Your Name on 2026-06-16.
//

import Foundation
import CoreLocation

/// A utility struct for validating geographic coordinates with comprehensive edge case handling
struct CoordinateValidator {
    
    /// Validation result with detailed information
    struct ValidationResult {
        let isValid: Bool
        let errorMessage: String?
        let normalizedLatitude: Double?
        let normalizedLongitude: Double?
        
        init(isValid: Bool, errorMessage: String? = nil, normalizedLatitude: Double? = nil, normalizedLongitude: Double? = nil) {
            self.isValid = isValid
            self.errorMessage = errorMessage
            self.normalizedLatitude = normalizedLatitude
            self.normalizedLongitude = normalizedLongitude
        }
    }
    
    /// Validates a pair of coordinates with comprehensive checks
    /// - Parameters:
    ///   - latitude: Latitude value to validate
    ///   - longitude: Longitude value to validate
    /// - Returns: ValidationResult with validation status and details
    static func validate(latitude: Double, longitude: Double) -> ValidationResult {
        // Check for NaN values
        guard !latitude.isNaN && !longitude.isNaN else {
            return ValidationResult(isValid: false, errorMessage: "Coordinates cannot be NaN")
        }
        
        // Check for infinity values
        guard !latitude.isInfinite && !longitude.isInfinite else {
            return ValidationResult(isValid: false, errorMessage: "Coordinates cannot be infinite")
        }
        
        // Check for reasonable precision (avoid extremely long decimal values)
        let latStr = String(format: "%.10f", latitude)
        let lonStr = String(format: "%.10f", longitude)
        
        guard latStr.count <= 20 && lonStr.count <= 20 else {
            return ValidationResult(isValid: false, errorMessage: "Coordinates have too many decimal places")
        }
        
        // Check standard bounds
        guard latitude >= -90.0 && latitude <= 90.0 else {
            return ValidationResult(isValid: false, errorMessage: "Latitude must be between -90 and 90 degrees")
        }
        
        guard longitude >= -180.0 && longitude <= 180.0 else {
            return ValidationResult(isValid: false, errorMessage: "Longitude must be between -180 and 180 degrees")
        }
        
        // Check for special problematic values
        if isSpecialProblematicCoordinate(latitude: latitude, longitude: longitude) {
            return ValidationResult(isValid: false, errorMessage: "Coordinates represent a special invalid location")
        }
        
        // Normalize coordinates to standard ranges if needed
        let normalizedLat = normalizeLatitude(latitude)
        let normalizedLon = normalizeLongitude(longitude)
        
        return ValidationResult(
            isValid: true,
            normalizedLatitude: normalizedLat,
            normalizedLongitude: normalizedLon
        )
    }
    
    /// Validates coordinates from string representations
    /// - Parameters:
    ///   - latString: Latitude string to validate
    ///   - lonString: Longitude string to validate
    /// - Returns: ValidationResult with validation status and details
    static func validate(latString: String, lonString: String) -> ValidationResult {
        // Trim whitespace
        let trimmedLat = latString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLon = lonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for empty strings
        guard !trimmedLat.isEmpty && !trimmedLon.isEmpty else {
            return ValidationResult(isValid: false, errorMessage: "Coordinates cannot be empty")
        }
        
        // Try to convert to Double
        guard let latitude = Double(trimmedLat), let longitude = Double(trimmedLon) else {
            return ValidationResult(isValid: false, errorMessage: "Coordinates must be valid decimal numbers")
        }
        
        return validate(latitude: latitude, longitude: longitude)
    }
    
    /// Checks if coordinates represent special problematic locations
    /// - Parameters:
    ///   - latitude: Latitude to check
    ///   - longitude: Longitude to check
    /// - Returns: True if coordinates represent a problematic location
    private static func isSpecialProblematicCoordinate(latitude: Double, longitude: Double) -> Bool {
        // Check for extreme values that might cause issues (but allow 0,0)
        if latitude == 0.0 && longitude == 0.0 {
            return false // Allow (0,0) as it's used for the current location
        }
        
        if abs(latitude) < 0.000001 && abs(longitude) < 0.000001 {
            return true // Very close to zero, likely invalid
        }
        
        return false
    }
    
    /// Normalizes latitude to the standard range [-90, 90]
    /// - Parameter latitude: Latitude value to normalize
    /// - Returns: Normalized latitude value
    private static func normalizeLatitude(_ latitude: Double) -> Double {
        // Handle values that are slightly out of bounds due to floating point errors
        if latitude > 90.0 && latitude <= 90.000001 {
            return 90.0
        }
        if latitude < -90.0 && latitude >= -90.000001 {
            return -90.0
        }
        return latitude
    }
    
    /// Normalizes longitude to the standard range [-180, 180]
    /// - Parameter longitude: Longitude value to normalize
    /// - Returns: Normalized longitude value
    private static func normalizeLongitude(_ longitude: Double) -> Double {
        // Handle values that are slightly out of bounds due to floating point errors
        if longitude > 180.0 && longitude <= 180.000001 {
            return 180.0
        }
        if longitude < -180.0 && longitude >= -180.000001 {
            return -180.0
        }
        
        // Wrap longitude to standard range
        var normalized = longitude
        while normalized > 180.0 {
            normalized -= 360.0
        }
        while normalized < -180.0 {
            normalized += 360.0
        }
        return normalized
    }
}