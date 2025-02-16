//
//  Weather.swift
//  SaxWeather
//
//  Created by Saxo_Broko on 2025-02-16 03:05:32
//

import Foundation

// MARK: - Weather Model
struct Weather: Codable {
    var temperature: Double?
    var feelsLike: Double?
    var high: Double?
    var low: Double?
    var humidity: Double?
    var dewPoint: Double?
    var pressure: Double?
    var windSpeed: Double?
    var windGust: Double?
    var uvIndex: Int?
    var solarRadiation: Double?
    private let cachedCondition: String
    let lastUpdateTime: Date
    
    var condition: String {
        return cachedCondition
    }
    
    var hasData: Bool {
        return temperature != nil || feelsLike != nil || high != nil ||
               low != nil || humidity != nil || dewPoint != nil ||
               pressure != nil || windSpeed != nil || windGust != nil ||
               uvIndex != nil || solarRadiation != nil
    }
    
    // Calculate vapor pressure from temperature and relative humidity
    private func calculateVaporPressure(temperature: Double, relativeHumidity: Double) -> Double {
        // Saturation vapor pressure using Magnus-Tetens formula
        let saturationVaporPressure = 6.11 * pow(10, (7.5 * temperature) / (237.3 + temperature))
        // Convert relative humidity from percentage to decimal
        let humidityDecimal = relativeHumidity / 100.0
        // Calculate actual vapor pressure
        return saturationVaporPressure * humidityDecimal
    }
    
    // Calculate feels like temperature
    private func calculateFeelsLike(temperature: Double, humidity: Double, windSpeed: Double) -> Double {
        let vaporPressure = calculateVaporPressure(temperature: temperature, relativeHumidity: humidity)
        // AT = Ta + 0.33E - 0.70WS - 4.00
        let apparentTemperature = temperature + 0.33 * vaporPressure - 0.70 * windSpeed - 4.00
        return apparentTemperature
    }
    
    // Ensure metric units for calculation and convert back if needed
    private func ensureMetricAndCalculateFeelsLike(temperature: Double, humidity: Double, windSpeed: Double, currentUnit: String) -> Double {
        var tempInCelsius = temperature
        var windInMetersPerSecond = windSpeed
        
        // Convert to metric if needed
        if currentUnit == "Imperial" {
            tempInCelsius = (temperature - 32) * 5/9
            windInMetersPerSecond = windSpeed * 0.44704 // mph to m/s
        }
        
        // Calculate feels like temperature in Celsius
        let feelsLikeCelsius = calculateFeelsLike(temperature: tempInCelsius,
                                                humidity: humidity,
                                                windSpeed: windInMetersPerSecond)
        
        // Convert back to Fahrenheit if needed
        if currentUnit == "Imperial" {
            return feelsLikeCelsius * 9/5 + 32
        }
        
        return feelsLikeCelsius
    }
    
    init(wuObservation: WUObservation?, owmCurrent: OWMCurrent?, owmDaily: OWMDaily?, unitSystem: String = "Metric") {
        self.lastUpdateTime = Date()
        
        self.temperature = wuObservation?.metric.temp ?? owmCurrent?.temp
        self.humidity = wuObservation?.humidity ?? owmCurrent?.humidity
        self.windSpeed = wuObservation?.metric.windSpeed ?? owmCurrent?.wind_speed
        self.high = owmDaily?.temp.max
        self.low = owmDaily?.temp.min
        self.dewPoint = wuObservation?.metric.dewpt ?? owmCurrent?.dew_point
        self.pressure = wuObservation?.metric.pressure ?? owmCurrent?.pressure
        self.windGust = wuObservation?.metric.windGust ?? owmCurrent?.wind_gust
        self.uvIndex = wuObservation?.uv ?? owmCurrent?.uvi
        self.solarRadiation = wuObservation?.solarRadiation ?? owmCurrent?.clouds
        
        let temp = self.temperature ?? 0
        let uv = self.uvIndex ?? 0
        let wind = self.windSpeed ?? 0
        let hum = self.humidity ?? 0
        
        if temp > 30 || uv > 5 {
            self.cachedCondition = "sunny"
        } else if temp < 0 {
            self.cachedCondition = "snowy"
        } else if wind > 20 {
            self.cachedCondition = "windy"
        } else if hum > 80 {
            self.cachedCondition = "rainy"
        } else {
            self.cachedCondition = "default"
        }
        
        if let temp = self.temperature,
           let hum = self.humidity,
           let wind = self.windSpeed {
            self.feelsLike = ensureMetricAndCalculateFeelsLike(
                temperature: temp,
                humidity: hum,
                windSpeed: wind,
                currentUnit: unitSystem
            )
        } else {
            self.feelsLike = wuObservation?.metric.heatIndex ?? owmCurrent?.feels_like
        }
    }
}

// MARK: - Unit Conversion Extension
extension Weather {
    mutating func convertUnits(from: String, to: String) {
        if from == to { return }
        
        print("Converting from \(from) to \(to)")
        
        if from == "Metric" && to == "Imperial" {
            if let temp = temperature { temperature = temp * 9/5 + 32 }
            if let feels = feelsLike { feelsLike = feels * 9/5 + 32 }
            if let highTemp = high { high = highTemp * 9/5 + 32 }
            if let lowTemp = low { low = lowTemp * 9/5 + 32 }
            if let dewPointTemp = dewPoint { dewPoint = dewPointTemp * 9/5 + 32 }
            if let speed = windSpeed { windSpeed = speed * 0.621371 }
            if let gust = windGust { windGust = gust * 0.621371 }
            if let press = pressure { pressure = press * 0.02953 }
            
            print("Converted temperature: \(temperature ?? 0)°F")
        } else if from == "Imperial" && to == "Metric" {
            if let temp = temperature { temperature = (temp - 32) * 5/9 }
            if let feels = feelsLike { feelsLike = (feels - 32) * 5/9 }
            if let highTemp = high { high = (highTemp - 32) * 5/9 }
            if let lowTemp = low { low = (lowTemp - 32) * 5/9 }
            if let dewPointTemp = dewPoint { dewPoint = (dewPointTemp - 32) * 5/9 }
            if let speed = windSpeed { windSpeed = speed * 1.60934 }
            if let gust = windGust { windGust = gust * 1.60934 }
            if let press = pressure { pressure = press * 33.8639 }
            
            print("Converted temperature: \(temperature ?? 0)°C")
        }
        
        if let temp = temperature,
           let hum = humidity,
           let wind = windSpeed {
            feelsLike = ensureMetricAndCalculateFeelsLike(
                temperature: temp,
                humidity: hum,
                windSpeed: wind,
                currentUnit: to
            )
        }
    }
}

// MARK: - API Response Models
struct WUResponse: Codable {
    let observations: [WUObservation]
}

struct WUObservation: Codable {
    let humidity: Double
    let uv: Int
    let solarRadiation: Double
    let metric: WUMetric

    struct WUMetric: Codable {
        let temp: Double
        let heatIndex: Double
        let dewpt: Double
        let pressure: Double
        let windSpeed: Double
        let windGust: Double
    }
}

struct OWMResponse: Codable {
    let current: OWMCurrent
    let daily: [OWMDaily]
}

struct OWMCurrent: Codable {
    let temp: Double
    let feels_like: Double
    let humidity: Double
    let dew_point: Double
    let pressure: Double
    let wind_speed: Double
    let wind_gust: Double
    let uvi: Int
    let clouds: Double
}

struct OWMDaily: Codable {
    let temp: OWMDailyTemp

    struct OWMDailyTemp: Codable {
        let min: Double
        let max: Double
    }
}

// MARK: - Errors
enum WeatherError: Error {
    case invalidURL
    case noData
    case networkError(String)
}
