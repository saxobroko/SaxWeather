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
    func entities(for identifiers: [WeatherEntity.ID]) async throws -> [WeatherEntity] {
        return []
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
        
        do {
            let response = try await service.fetchWeather(latitude: lat, longitude: lon, unitSystem: unitSystem)
            
            guard let current = response.current else {
                throw IntentError.weatherFetchFailed("No current weather data available.")
            }
            
            var temp = current.temperature_2m ?? 0.0
            var unit = "°C"
            
            if unitSystem == "Imperial" {
                temp = (temp * 9/5) + 32
                unit = "°F"
            }
            
            let tempString = String(format: "%.1f%@", temp, unit)
            let condition = weatherCondition(from: response.daily.weather_code.first ?? 0)
            
            let dialog = IntentDialog("The weather in \(targetLocation.name) is currently \(condition) with a temperature of \(tempString).")
            
            let highVal = response.daily.temperature_2m_max.first.map { unitSystem == "Imperial" ? ($0 * 9/5) + 32 : $0 }
            let lowVal = response.daily.temperature_2m_min.first.map { unitSystem == "Imperial" ? ($0 * 9/5) + 32 : $0 }
            
            let highString = highVal.map { String(format: "%.0f°", $0) }
            let lowString = lowVal.map { String(format: "%.0f°", $0) }
            
            let weatherEntity = WeatherEntity(
                locationName: targetLocation.name,
                temperature: tempString,
                condition: condition,
                high: highString,
                low: lowString
            )
            
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
