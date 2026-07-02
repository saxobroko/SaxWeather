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
        case "Feels Like":
            return "Feels like estimates how the current conditions actually feel on your body, based on temperature, humidity, and wind."
        default:
            return "Weather measurement data"
        }
    }

    /// Explains how the displayed feels-like value was derived,
    /// including the formula used and the inputs that went into it.
    static func feelsLikeDescription(for weather: Weather, unitSystem: String) -> String {
        let unit = UnitSystem.from(rawValue: unitSystem)
        let speedUnit = unit.speedLabel

        guard let feelsLike = weather.feelsLike else {
            return "Feels like is not available for the current conditions."
        }

        guard let temperature = weather.temperature,
              let humidity = weather.humidity,
              let windSpeed = weather.windSpeed else {
            return """
            This value (\(formatTemperature(feelsLike, unit: unit))) is reported directly by your weather data source rather than being calculated in the app.

            Feels like estimates how the air actually feels on your body — often warmer than the thermometer when humidity is high, or colder when wind is strong.
            """
        }

        let tempC = UnitConverter.convertTemperature(temperature, from: unit, to: .metric)
        let windMps = UnitConverter.storedWindToMps(windSpeed, currentUnit: unit)
        let windKmh = windMps * 3.6

        let tempStr = formatTemperature(temperature, unit: unit)
        let humidityStr = "\(Int(round(humidity)))%"
        let windStr = String(format: "%.1f %@", windSpeed, speedUnit)
        let feelsStr = formatTemperature(feelsLike, unit: unit)

        if tempC >= 27.0 {
            let tempF = tempC * 9 / 5 + 32
            return """
            \(feelsStr) is calculated using the Heat Index because the air temperature is \(tempStr) (27°C / 81°F or above).

            Inputs:
            • Temperature: \(tempStr)
            • Humidity: \(humidityStr)
            • Wind speed: \(windStr)

            Formula (Rothfusz regression, US National Weather Service):
            HI = -42.379
               + 2.04901523×T
               + 10.14333127×RH
               - 0.22475541×T×RH
               - 0.00683783×T²
               - 0.05481717×RH²
               + 0.00122874×T²×RH
               + 0.00085282×T×RH²
               - 0.00000199×T²×RH²

            T = air temperature in °F, RH = relative humidity (%). The result is converted back to Celsius before display.

            Your values: T = \(String(format: "%.1f", tempF))°F, RH = \(humidityStr)

            Heat Index reflects how hot it feels when high humidity slows sweat evaporation, making it feel warmer than the thermometer reads.
            """
        }

        if tempC <= 10.0 {
            if windKmh < 4.8 {
                return """
                \(feelsStr) matches the air temperature (\(tempStr)) because wind speed (\(windStr)) is too low for wind chill to apply (below \(String(format: "%.1f", UnitConverter.convertWind(4.8, from: .metric, to: unit))) \(speedUnit)).

                Inputs:
                • Temperature: \(tempStr)
                • Humidity: \(humidityStr)
                • Wind speed: \(windStr)

                Formula:
                Feels Like = Ta

                Ta = air temperature. Wind Chill only applies at 10°C (50°F) or below when wind is at least 4.8 km/h.

                Your values: Ta = \(String(format: "%.1f", tempC))°C

                Wind Chill increases heat loss from your skin; below the wind threshold, the actual temperature is used.
                """
            }

            return """
            \(feelsStr) is calculated using Wind Chill because the air temperature is \(tempStr) (10°C / 50°F or below) and wind speed is \(windStr).

            Inputs:
            • Temperature: \(tempStr)
            • Humidity: \(humidityStr)
            • Wind speed: \(windStr)

            Formula (Environment Canada / US National Weather Service):
            WC = 13.12 + 0.6215×Ta - 11.37×V^0.16 + 0.3965×Ta×V^0.16

            Ta = air temperature (°C), V = wind speed (km/h).

            Your values: Ta = \(String(format: "%.1f", tempC))°C, V = \(String(format: "%.1f", windKmh)) km/h

            Wind Chill estimates how cold it feels as moving air carries heat away from your body faster than still air.
            """
        }

        let vaporPressure = vaporPressureHpa(temperatureC: tempC, relativeHumidity: humidity)
        return """
        \(feelsStr) is calculated using Apparent Temperature for moderate conditions (between 10°C and 27°C).

        Inputs:
        • Temperature: \(tempStr)
        • Humidity: \(humidityStr)
        • Wind speed: \(windStr)

        Vapor pressure (Magnus-Tetens):
        E = 6.11 × 10^(7.5×Ta / (237.3 + Ta)) × (RH / 100)

        Apparent Temperature:
        AT = Ta + 0.33×E - 0.70×WS - 4.00

        Ta = air temperature (°C), RH = relative humidity (%), WS = wind speed (m/s), E = vapor pressure (hPa).

        Your values: Ta = \(String(format: "%.1f", tempC))°C, RH = \(humidityStr), WS = \(String(format: "%.1f", windMps)) m/s
        E = \(String(format: "%.1f", vaporPressure)) hPa

        This formula combines temperature, humidity, and wind into a single comfort reading — humidity can make it feel warmer, while wind can make it feel cooler.
        """
    }

    private static func vaporPressureHpa(temperatureC: Double, relativeHumidity: Double) -> Double {
        let saturationVaporPressure = 6.11 * pow(10, (7.5 * temperatureC) / (237.3 + temperatureC))
        return saturationVaporPressure * (relativeHumidity / 100.0)
    }

    private static func formatTemperature(_ value: Double, unit: UnitSystem) -> String {
        "\(String(format: "%.1f", value))\(unit.temperatureLabel)"
    }
}
