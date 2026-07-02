//
//  UnitConverter.swift
//  SaxWeather
//
//  Single source of truth for all unit conversions used by the app,
//  widget, and background refresh paths. Centralising the math here
//  prevents the kind of drift we saw when WU/OWM wind (m/s) and
//  Open-Meteo/WeatherKit wind (km/h after conversion) were mixed up
//  at the storage layer.
//
//  The `Weather` model stores wind in km/h in "Metric" mode and
//  mph in "Imperial"/"UK" mode. Temperature is °C in Metric/UK and
//  °F in Imperial. Pressure is hPa in Metric/UK and inHg in Imperial.
//

import Foundation

// MARK: - Unit System

/// Represents the three user-selectable unit systems. Keep the raw
/// string values stable — they are persisted in `UserDefaults`
/// under the `unitSystem` key and shared with the widget extension.
enum UnitSystem: String, CaseIterable {
    case metric   = "Metric"
    case imperial = "Imperial"
    case uk       = "UK"

    /// Whether the system displays temperature in Celsius.
    var usesCelsius: Bool { self != .imperial }

    /// Whether the system displays pressure in hPa.
    var usesHPa: Bool { self != .imperial }

    /// Whether the system displays wind speed in km/h. Only Metric does.
    var usesKmh: Bool { self == .metric }

    /// Display label for temperature.
    var temperatureLabel: String { usesCelsius ? "°C" : "°F" }

    /// Display label for wind speed.
    var speedLabel: String {
        switch self {
        case .metric:   return "km/h"
        case .imperial: return "mph"
        case .uk:       return "mph"
        }
    }

    /// Display label for pressure.
    var pressureLabel: String { usesHPa ? "hPa" : "inHg" }

    /// Whether precipitation is displayed in millimetres. Imperial uses inches.
    var usesMillimeters: Bool { self != .imperial }

    /// Display label for precipitation amount.
    var precipitationLabel: String { usesMillimeters ? "mm" : "in" }

    /// Convert a raw "Metric"-style string (e.g. "Metric", "Imperial",
    /// "UK") into the enum. Falls back to `.metric` for unknown values.
    static func from(rawValue: String) -> UnitSystem {
        UnitSystem(rawValue: rawValue) ?? .metric
    }
}

// MARK: - Conversion factors

enum UnitConverter {

    // MARK: Wind speed
    static let mpsPerKmh: Double  = 3.6       // 1 km/h = 0.27778 m/s
    static let mphPerKmh: Double  = 0.621371  // 1 km/h = 0.621371 mph
    static let mphPerMps: Double  = 2.23694   // 1 m/s = 2.23694 mph
    static let kmhPerMph: Double  = 1.60934   // 1 mph = 1.60934 km/h
    static let mpsPerMph: Double  = 0.44704   // 1 mph = 0.44704 m/s

    // MARK: Pressure
    static let inHgPerHPa: Double = 0.02953   // 1 hPa = 0.02953 inHg
    static let hPaPerInHg: Double = 33.8639   // 1 inHg = 33.8639 hPa
    static let mmPerInch: Double = 25.4

    // MARK: Wind conversions

    static func mpsToKmh(_ value: Double) -> Double { value * mpsPerKmh }
    static func kmhToMps(_ value: Double) -> Double { value / mpsPerKmh }
    static func mpsToMph(_ value: Double) -> Double { value * mphPerMps }
    static func kmhToMph(_ value: Double) -> Double { value * mphPerKmh }
    static func mphToKmh(_ value: Double) -> Double { value * kmhPerMph }
    static func mphToMps(_ value: Double) -> Double { value * mpsPerMph }

    /// Convert a wind speed stored in the `Weather` model for the given
    /// unit system back to metres-per-second. Used by the feels-like
    /// calculations that internally need m/s.
    static func storedWindToMps(_ value: Double, currentUnit: UnitSystem) -> Double {
        switch currentUnit {
        case .metric:   return kmhToMps(value)
        case .imperial: return mphToMps(value)
        case .uk:       return mphToMps(value)
        }
    }

    /// Convert a wind speed stored in the `Weather` model (which is in
    /// km/h when `from` is Metric, mph when `from` is Imperial/UK) to
    /// the unit used by `to`.
    static func convertWind(_ value: Double, from: UnitSystem, to: UnitSystem) -> Double {
        if from == to { return value }
        // Normalise to km/h first.
        let kmh: Double
        switch from {
        case .metric:   kmh = value
        case .imperial: kmh = mphToKmh(value)
        case .uk:       kmh = mphToKmh(value)
        }
        switch to {
        case .metric:   return kmh
        case .imperial: return kmhToMph(kmh)
        case .uk:       return kmhToMph(kmh)
        }
    }

    // MARK: Temperature conversions

    static func celsiusToF(_ c: Double) -> Double { c * 9.0 / 5.0 + 32 }
    static func fToCelsius(_ f: Double) -> Double { (f - 32) * 5.0 / 9.0 }

    /// Convert a temperature stored in the `Weather` model (°C in
    /// Metric/UK, °F in Imperial) to the unit used by `to`.
    static func convertTemperature(_ value: Double, from: UnitSystem, to: UnitSystem) -> Double {
        if from == to { return value }
        let celsius: Double
        switch from {
        case .metric, .uk: celsius = value
        case .imperial:    celsius = fToCelsius(value)
        }
        switch to {
        case .metric, .uk: return celsius
        case .imperial:    return celsiusToF(celsius)
        }
    }

    // MARK: Pressure conversions

    static func hPaToInHg(_ v: Double) -> Double { v * inHgPerHPa }
    static func inHgToHPa(_ v: Double) -> Double { v * hPaPerInHg }

    /// Convert a pressure stored in the `Weather` model (hPa in
    /// Metric/UK, inHg in Imperial) to the unit used by `to`.
    static func convertPressure(_ value: Double, from: UnitSystem, to: UnitSystem) -> Double {
        if from == to { return value }
        let hPa: Double
        switch from {
        case .metric, .uk: hPa = value
        case .imperial:    hPa = inHgToHPa(value)
        }
        switch to {
        case .metric, .uk: return hPa
        case .imperial:    return hPaToInHg(hPa)
        }
    }

    // MARK: API URL helpers

    /// `units=` value for the OpenWeatherMap API. UK has no native
    /// hybrid, so we request metric (m/s) and convert in-app.
    static func openWeatherMapUnits(for unit: UnitSystem) -> String {
        switch unit {
        case .metric, .uk: return "metric"
        case .imperial:    return "imperial"
        }
    }

    /// `units=` value for the Weather Underground PWS API. The `h`
    /// (UK hybrid) profile returns °C + hPa + **mph**, which is exactly
    /// the UK unit system the user picks in Settings.
    static func weatherUndergroundUnits(for unit: UnitSystem) -> String {
        switch unit {
        case .metric:   return "m"
        case .imperial: return "e"
        case .uk:       return "h"
        }
    }

    // MARK: - User-configured precision

    /// Read the user-configured decimal-place count for
    /// temperatures from `@AppStorage("temperaturePrecision")`.
    /// Defaults to 1 when the key is missing.
    static var temperaturePrecision: Int {
        let raw = UserDefaults.standard.object(forKey: "temperaturePrecision") as? Int
        return raw.map { max(0, min($0, 2)) } ?? 1
    }

    /// Read the user-configured decimal-place count for wind
    /// values from `@AppStorage("windPrecision")`. Defaults to 0.
    static var windPrecision: Int {
        let raw = UserDefaults.standard.object(forKey: "windPrecision") as? Int
        return raw.map { max(0, min($0, 1)) } ?? 0
    }

    /// Read the user-configured decimal-place count for pressure
    /// values from `@AppStorage("pressurePrecision")`. Defaults to 0.
    static var pressurePrecision: Int {
        let raw = UserDefaults.standard.object(forKey: "pressurePrecision") as? Int
        return raw.map { max(0, min($0, 2)) } ?? 0
    }

    static func formatTemperature(_ value: Double) -> String {
        let digits = temperaturePrecision
        return String(format: "%.\(digits)f", value)
    }

    /// Format a wind value with the user-configured precision.
    /// Callers append the unit suffix (km/h, mph, etc.).
    static func formatWind(_ value: Double) -> String {
        let digits = windPrecision
        return String(format: "%.\(digits)f", value)
    }

    /// Format a pressure value with the user-configured precision.
    /// Callers append the unit suffix (hPa, inHg, etc.).
    static func formatPressure(_ value: Double) -> String {
        let digits = pressurePrecision
        return String(format: "%.\(digits)f", value)
    }

    static func mmToInches(_ value: Double) -> Double { value / mmPerInch }

    /// Format a precipitation amount stored in millimetres for display.
    static func formatPrecipitation(_ mm: Double, unit: UnitSystem, precision: Int = 1) -> String {
        switch unit {
        case .metric, .uk:
            return String(format: "%.\(precision)f %@", mm, unit.precipitationLabel)
        case .imperial:
            return String(format: "%.\(precision)f %@", mmToInches(mm), unit.precipitationLabel)
        }
    }
}
