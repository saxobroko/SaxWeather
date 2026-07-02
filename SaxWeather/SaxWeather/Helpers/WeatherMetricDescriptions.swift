//
//  WeatherMetricDescriptions.swift
//  SaxWeather
//

import Foundation

enum WeatherMetricDescriptions {
    static func description(for title: String, unitSystem: String = "Metric") -> String {
        switch title {
        case "Humidity":
            return "Humidity is the amount of water vapor present in the air. High humidity can make it feel warmer than it actually is, while low humidity can make it feel cooler."
        case "Dew Point":
            let usesCelsius = UnitSystem.from(rawValue: unitSystem).usesCelsius
            let threshold = usesCelsius ? "18°C" : "65°F"
            return "Dew point is the temperature at which water vapor in the air begins to condense. A higher dew point (above \(threshold)) means the air feels more humid and uncomfortable."
        case "Pressure":
            return "Atmospheric pressure affects weather conditions. Falling pressure often indicates approaching storms, while rising pressure typically means clearer weather."
        case "Wind Speed":
            return "Wind speed measures how fast the air is moving. Higher wind speeds can make it feel colder and may affect outdoor activities."
        case "Wind Gust":
            return "Wind gusts are sudden increases in wind speed. They're typically stronger than the average wind speed and can be particularly important for outdoor safety."
        case "UV Index":
            return "The UV Index measures the intensity of ultraviolet radiation from the sun. Higher values (6+) mean greater risk of sun damage and need for protection."
        case "Solar Radiation":
            return "Solar radiation measures the sun's energy reaching Earth's surface. It affects temperature and can impact solar panel efficiency."
        default:
            return "Weather measurement data"
        }
    }
}
