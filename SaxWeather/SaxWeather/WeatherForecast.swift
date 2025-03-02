//
//  WeatherForecast.swift
//  SaxWeather
//
//  Created by Saxon on 25/2/2025.
//


import Foundation

struct WeatherForecast: Codable {
    let daily: [DailyForecast]
    struct DailyForecast: Codable, Identifiable {
        var id = UUID()
        let date: Date
        let tempMax: Double
        let tempMin: Double
        let precipitation: Double
        let precipitationProbability: Double
        let weatherCode: Int
        let windSpeed: Double
        let windDirection: Double
        let humidity: Double
        let pressure: Double
        let uvIndex: Double
        let sunrise: Date?
        let sunset: Date?
        
        var weatherDescription: String {
            WeatherCode(rawValue: weatherCode)?.description ?? "Unknown"
        }
        
        var weatherSymbol: String {
            WeatherCode(rawValue: weatherCode)?.symbol ?? "❓"
        }
    }
}

enum WeatherCode: Int, Codable {
    case clearSky = 0
    case mainlyClear = 1
    case partlyCloudy = 2
    case overcast = 3
    case fog = 45
    case depositingRimeFog = 48
    case drizzleLight = 51
    case drizzleModerate = 53
    case drizzleDense = 55
    case freezingDrizzleLight = 56
    case freezingDrizzleDense = 57
    case rainSlight = 61
    case rainModerate = 63
    case rainHeavy = 65
    case freezingRainLight = 66
    case freezingRainHeavy = 67
    case snowFallSlight = 71
    case snowFallModerate = 73
    case snowFallHeavy = 75
    case snowGrains = 77
    case rainShowersSlight = 80
    case rainShowersModerate = 81
    case rainShowersViolent = 82
    case snowShowersSlight = 85
    case snowShowersHeavy = 86
    case thunderstormSlight = 95
    case thunderstormWithHail = 96
    case thunderstormHeavyHail = 99
    
    var description: String {
        switch self {
        case .clearSky: return "Clear sky"
        case .mainlyClear: return "Mainly clear"
        case .partlyCloudy: return "Partly cloudy"
        case .overcast: return "Overcast"
        case .fog: return "Fog"
        case .depositingRimeFog: return "Depositing rime fog"
        case .drizzleLight: return "Light drizzle"
        case .drizzleModerate: return "Moderate drizzle"
        case .drizzleDense: return "Dense drizzle"
        case .freezingDrizzleLight: return "Light freezing drizzle"
        case .freezingDrizzleDense: return "Dense freezing drizzle"
        case .rainSlight: return "Slight rain"
        case .rainModerate: return "Moderate rain"
        case .rainHeavy: return "Heavy rain"
        case .freezingRainLight: return "Light freezing rain"
        case .freezingRainHeavy: return "Heavy freezing rain"
        case .snowFallSlight: return "Light snow"
        case .snowFallModerate: return "Moderate snow"
        case .snowFallHeavy: return "Heavy snow"
        case .snowGrains: return "Snow grains"
        case .rainShowersSlight: return "Slight rain showers"
        case .rainShowersModerate: return "Moderate rain showers"
        case .rainShowersViolent: return "Violent rain showers"
        case .snowShowersSlight: return "Light snow showers"
        case .snowShowersHeavy: return "Heavy snow showers"
        case .thunderstormSlight: return "Slight thunderstorm"
        case .thunderstormWithHail: return "Thunderstorm with hail"
        case .thunderstormHeavyHail: return "Thunderstorm with heavy hail"
        }
    }
    
    var symbol: String {
        switch self {
        case .clearSky: return "☀️"
        case .mainlyClear: return "🌤️"
        case .partlyCloudy: return "⛅"
        case .overcast: return "☁️"
        case .fog, .depositingRimeFog: return "🌫️"
        case .drizzleLight, .drizzleModerate, .drizzleDense: return "🌧️"
        case .freezingDrizzleLight, .freezingDrizzleDense: return "🌨️"
        case .rainSlight, .rainModerate: return "🌧️"
        case .rainHeavy: return "⛈️"
        case .freezingRainLight, .freezingRainHeavy: return "🌨️"
        case .snowFallSlight, .snowFallModerate, .snowFallHeavy, .snowGrains: return "🌨️"
        case .rainShowersSlight, .rainShowersModerate: return "🌦️"
        case .rainShowersViolent: return "⛈️"
        case .snowShowersSlight, .snowShowersHeavy: return "🌨️"
        case .thunderstormSlight, .thunderstormWithHail, .thunderstormHeavyHail: return "⛈️"
        }
    }
}
