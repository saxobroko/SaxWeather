import Foundation
import AppIntents
import SwiftUI

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct WeatherEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Weather"
    static var defaultQuery = WeatherEntityQuery()
    
    let id: UUID
    
    @Property(title: "Location Name")
    var locationName: String
    
    @Property(title: "Temperature")
    var temperature: String
    
    @Property(title: "Condition")
    var condition: String
    
    @Property(title: "High")
    var high: String?
    
    @Property(title: "Low")
    var low: String?
    
    init(id: UUID = UUID(), locationName: String, temperature: String, condition: String, high: String?, low: String?) {
        self.id = id
        self.locationName = locationName
        self.temperature = temperature
        self.condition = condition
        self.high = high
        self.low = low
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(temperature) and \(condition) in \(locationName)")
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct WeatherEntityQuery: EntityQuery {
    private static let appGroupID = "group.com.saxobroko.SaxWeather"
    private static let lastWeatherEntityKey = "lastWeatherEntity"

    func entities(for identifiers: [WeatherEntity.ID]) async throws -> [WeatherEntity] {
        let stored = Self.loadStoredEntities()
        var results: [WeatherEntity] = []

        for id in identifiers {
            if let entity = stored.first(where: { $0.id == id }) {
                results.append(entity)
            } else if let entity = Self.reconstructFromWidgetCache(id: id) {
                results.append(entity)
            }
        }

        return results
    }

    static func persist(_ entity: WeatherEntity) {
        guard let data = try? JSONEncoder().encode(StoredWeatherEntity(from: entity)) else { return }
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        sharedDefaults?.set(data, forKey: lastWeatherEntityKey)
        UserDefaults.standard.set(data, forKey: lastWeatherEntityKey)
    }

    private static func loadStoredEntities() -> [WeatherEntity] {
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        guard let data = sharedDefaults?.data(forKey: lastWeatherEntityKey)
            ?? UserDefaults.standard.data(forKey: lastWeatherEntityKey),
              let stored = try? JSONDecoder().decode(StoredWeatherEntity.self, from: data) else {
            return []
        }
        return [stored.entity]
    }

    private static func reconstructFromWidgetCache(id: WeatherEntity.ID) -> WeatherEntity? {
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        guard let data = sharedDefaults?.data(forKey: WidgetSyncService.Keys.latestWeather),
              let widgetData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let temperature = widgetData["temperature"] as? Double,
              let condition = widgetData["condition"] as? String else {
            return nil
        }

        let units = UnitSystem.from(rawValue: widgetData["unitSystem"] as? String ?? "Metric")
        let tempString = String(format: "%.1f%@", temperature, units.temperatureLabel)
        let highString = (widgetData["high"] as? Double).map { String(format: "%.0f%@", $0, units.temperatureLabel) }
        let lowString = (widgetData["low"] as? Double).map { String(format: "%.0f%@", $0, units.temperatureLabel) }

        let locationName = resolveLocationName(using: sharedDefaults)

        return WeatherEntity(
            id: id,
            locationName: locationName,
            temperature: tempString,
            condition: condition,
            high: highString,
            low: lowString
        )
    }

    private static func resolveLocationName(using sharedDefaults: UserDefaults?) -> String {
        let useGPS = sharedDefaults?.object(forKey: WidgetSyncService.Keys.useGPS) as? Bool
            ?? UserDefaults.standard.bool(forKey: "useGPS")

        let latString: String?
        let lonString: String?
        if useGPS {
            latString = sharedDefaults?.string(forKey: WidgetSyncService.Keys.lastKnownLatitude)
                ?? UserDefaults.standard.string(forKey: "lastKnownLatitude")
            lonString = sharedDefaults?.string(forKey: WidgetSyncService.Keys.lastKnownLongitude)
                ?? UserDefaults.standard.string(forKey: "lastKnownLongitude")
        } else {
            latString = sharedDefaults?.string(forKey: WidgetSyncService.Keys.latitude)
                ?? UserDefaults.standard.string(forKey: "latitude")
            lonString = sharedDefaults?.string(forKey: WidgetSyncService.Keys.longitude)
                ?? UserDefaults.standard.string(forKey: "longitude")
        }

        if let latString, let lonString,
           let latitude = Double(latString), let longitude = Double(lonString),
           let matched = matchSavedLocationName(latitude: latitude, longitude: longitude) {
            return matched
        }

        return useGPS ? "Current Location" : "Weather"
    }

    private static func matchSavedLocationName(latitude: Double, longitude: Double) -> String? {
        let userDefaultsKey = "savedLocations"
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        guard let data = sharedDefaults?.data(forKey: userDefaultsKey)
            ?? UserDefaults.standard.data(forKey: userDefaultsKey),
              let locations = try? JSONDecoder().decode([SavedLocation].self, from: data) else {
            return nil
        }

        return locations.first { location in
            abs(location.latitude - latitude) < 0.01 && abs(location.longitude - longitude) < 0.01
        }?.name
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
private struct StoredWeatherEntity: Codable {
    let id: UUID
    let locationName: String
    let temperature: String
    let condition: String
    let high: String?
    let low: String?

    init(from entity: WeatherEntity) {
        id = entity.id
        locationName = entity.locationName
        temperature = entity.temperature
        condition = entity.condition
        high = entity.high
        low = entity.low
    }

    var entity: WeatherEntity {
        WeatherEntity(
            id: id,
            locationName: locationName,
            temperature: temperature,
            condition: condition,
            high: high,
            low: low
        )
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct GetWeatherIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Weather"
    static var description = IntentDescription("Gets the current weather for a location.")
    
    @Parameter(title: "Location")
    var location: LocationEntity?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get the weather for \(\.$location)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView & ReturnsValue<WeatherEntity> {
        let targetLocation: LocationEntity?
        if let loc = location {
            targetLocation = loc
        } else {
            targetLocation = await LocationEntityQuery().defaultResult()
        }
        
        guard let targetLocation = targetLocation else {
            throw IntentError.locationNotFound
        }
        
        let service = OpenMeteoService()
        
        var lat = targetLocation.latitude
        var lon = targetLocation.longitude
        
        if targetLocation.isCurrentLocation {
            let sharedDefaults = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
            let useGPS = sharedDefaults?.object(forKey: WidgetSyncService.Keys.useGPS) as? Bool
                ?? UserDefaults.standard.bool(forKey: "useGPS")

            if useGPS {
                if let latString = sharedDefaults?.string(forKey: "lastKnownLatitude") ?? UserDefaults.standard.string(forKey: "lastKnownLatitude"),
                   let lonString = sharedDefaults?.string(forKey: "lastKnownLongitude") ?? UserDefaults.standard.string(forKey: "lastKnownLongitude"),
                   let latitude = Double(latString),
                   let longitude = Double(lonString) {
                    lat = latitude
                    lon = longitude
                } else {
                    throw IntentError.locationNotAvailable
                }
            } else {
                if let latString = UserDefaults.standard.string(forKey: "latitude"),
                   let lonString = UserDefaults.standard.string(forKey: "longitude"),
                   let latitude = Double(latString),
                   let longitude = Double(lonString) {
                    lat = latitude
                    lon = longitude
                } else {
                    throw IntentError.locationNotAvailable
                }
            }
        }
        
        let unitSystem = UserDefaults.standard.string(forKey: "unitSystem") ?? "Metric"
        let units = UnitSystem.from(rawValue: unitSystem)
        
        do {
            let response = try await service.fetchWeather(latitude: lat, longitude: lon, unitSystem: unitSystem)
            
            guard let current = response.current else {
                throw IntentError.weatherFetchFailed("No current weather data available.")
            }
            
            let tempCelsius = current.temperature_2m ?? 0.0
            let temp = units.usesCelsius ? tempCelsius : UnitConverter.celsiusToF(tempCelsius)
            let unit = units.temperatureLabel
            let tempString = String(format: "%.1f%@", temp, unit)
            let condition = weatherCondition(from: response.daily?.weather_code.first ?? 0)
            
            let dialog = IntentDialog("The weather in \(targetLocation.name) is currently \(condition) with a temperature of \(tempString).")
            
            let highVal = response.daily?.temperature_2m_max.first.map {
                units.usesCelsius ? $0 : UnitConverter.celsiusToF($0)
            }
            let lowVal = response.daily?.temperature_2m_min.first.map {
                units.usesCelsius ? $0 : UnitConverter.celsiusToF($0)
            }
            
            let highString = highVal.map { String(format: "%.0f°", $0) }
            let lowString = lowVal.map { String(format: "%.0f°", $0) }
            
            let weatherEntity = WeatherEntity(
                locationName: targetLocation.name,
                temperature: tempString,
                condition: condition,
                high: highString,
                low: lowString
            )
            WeatherEntityQuery.persist(weatherEntity)
            
            return .result(
                value: weatherEntity,
                dialog: dialog,
                view: WeatherSnippetView(
                    locationName: targetLocation.name,
                    temperature: tempString,
                    condition: condition,
                    high: highVal,
                    low: lowVal,
                    unit: unit
                )
            )
        } catch {
            throw IntentError.weatherFetchFailed(error.localizedDescription)
        }
    }
    
    private func weatherCondition(from code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1, 2, 3: return "Partly Cloudy"
        case 45, 48: return "Foggy"
        case 51, 53, 55, 56, 57: return "Drizzling"
        case 61, 63, 65, 66, 67: return "Raining"
        case 71, 73, 75, 77: return "Snowing"
        case 80, 81, 82: return "Raining Heavily"
        case 85, 86: return "Snowing Heavily"
        case 95, 96, 99: return "Thunderstorms"
        default: return "Unknown"
        }
    }
    
    enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
        case locationNotFound
        case locationNotAvailable
        case weatherFetchFailed(String)
        
        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .locationNotFound:
                return "Could not find the specified location."
            case .locationNotAvailable:
                return "Current location coordinates are not available. Please open the app to update your location."
            case .weatherFetchFailed(let message):
                return "Failed to fetch weather data: \(message)"
            }
        }
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct ShowForecastIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Forecast"
    static var description = IntentDescription("Opens the app to show the forecast for a location.")
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Location")
    var location: LocationEntity?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Show the forecast for \(\.$location)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let targetLocation: LocationEntity
        if let loc = location {
            targetLocation = loc
        } else {
            guard let defaultLoc = await LocationEntityQuery().defaultResult() else {
                throw IntentError.locationNotFound
            }
            targetLocation = defaultLoc
        }
        
        AppIntentNavigation.storePendingLocation(id: targetLocation.id)

        return .result()
    }
    
    enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
        case locationNotFound
        
        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .locationNotFound:
                return "Could not find the specified location."
            }
        }
    }
}

struct WeatherSnippetView: View {
    let locationName: String
    let temperature: String
    let condition: String
    let high: Double?
    let low: Double?
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(locationName)
                .font(.headline)
            
            HStack(alignment: .firstTextBaseline) {
                Text(temperature)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(condition)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let high = high, let low = low {
                        Text("H: \(String(format: "%.0f", high))° L: \(String(format: "%.0f", low))°")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}
