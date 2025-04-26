//
//  Weather.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-26 14:33:23
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
    var forecasts: [Forecast] = []
    
    // MARK: - Forecast Struct
    struct Forecast: Codable {
        var date: Date
        var maxTemp: Double
        var minTemp: Double
        var precipitation: Double
        var weatherCode: Int
        var windSpeed: Double
        var windDirection: Int
        var humidity: Double
        var pressure: Double
        var uvIndex: Double
        
        // MARK: - Initializers
        init(from daily: OpenMeteoResponse.Daily, index: Int) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withTime, .withTimeZone]
            self.date = formatter.date(from: daily.time[index]) ?? Date()
            
            self.maxTemp = daily.temperature_2m_max[index]
            self.minTemp = daily.temperature_2m_min[index]
            self.precipitation = daily.precipitation_sum[index] ?? 0.0
            self.weatherCode = daily.weather_code[index]
            self.windSpeed = daily.wind_speed_10m_max[index]
            self.windDirection = Int(daily.wind_direction_10m_dominant[index] ?? 0.0)
            self.humidity = Double(daily.relative_humidity_2m_max[index])
            self.pressure = daily.pressure_msl_max[index]
            self.uvIndex = daily.uv_index_max[index]
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decode(Date.self, forKey: .date)
            maxTemp = try container.decode(Double.self, forKey: .maxTemp)
            minTemp = try container.decode(Double.self, forKey: .minTemp)
            precipitation = try container.decode(Double.self, forKey: .precipitation)
            weatherCode = try container.decode(Int.self, forKey: .weatherCode)
            windSpeed = try container.decode(Double.self, forKey: .windSpeed)
            windDirection = try container.decode(Int.self, forKey: .windDirection)
            humidity = try container.decode(Double.self, forKey: .humidity)
            pressure = try container.decode(Double.self, forKey: .pressure)
            uvIndex = try container.decode(Double.self, forKey: .uvIndex)
        }
        
        // MARK: - Coding Keys
        private enum CodingKeys: String, CodingKey {
            case date
            case maxTemp
            case minTemp
            case precipitation
            case weatherCode
            case windSpeed
            case windDirection
            case humidity
            case pressure
            case uvIndex
        }
    }
    
    var condition: String {
        return cachedCondition
    }
    
    var hasData: Bool {
        return temperature != nil || feelsLike != nil || high != nil ||
               low != nil || humidity != nil || dewPoint != nil ||
               pressure != nil || windSpeed != nil || windGust != nil ||
               uvIndex != nil || solarRadiation != nil
    }
    
    // MARK: - Private Helper Methods
    private func calculateVaporPressure(temperature: Double, relativeHumidity: Double) -> Double {
        // Saturation vapor pressure using Magnus-Tetens formula
        let saturationVaporPressure = 6.11 * pow(10, (7.5 * temperature) / (237.3 + temperature))
        // Convert relative humidity from percentage to decimal
        let humidityDecimal = relativeHumidity / 100.0
        // Calculate actual vapor pressure
        return saturationVaporPressure * humidityDecimal
    }
    
    private func calculateFeelsLike(temperature: Double, humidity: Double, windSpeed: Double) -> Double {
        let vaporPressure = calculateVaporPressure(temperature: temperature, relativeHumidity: humidity)
        // AT = Ta + 0.33E - 0.70WS - 4.00
        let apparentTemperature = temperature + 0.33 * vaporPressure - 0.70 * windSpeed - 4.00
        return apparentTemperature
    }
    
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
    
    // MARK: - Initializer
    init(wuObservation: WUObservation?, owmCurrent: OWMCurrent?, owmDaily: OWMDaily?, openMeteoResponse: OpenMeteoResponse? = nil, unitSystem: String = "Metric") {
        self.lastUpdateTime = Date()
        
        self.temperature = wuObservation?.metric.temp ?? owmCurrent?.temp ?? openMeteoResponse?.current?.temperature_2m
        self.humidity = wuObservation?.humidity ?? owmCurrent?.humidity ?? Double(openMeteoResponse?.current?.relative_humidity_2m ?? 0)
        self.windSpeed = wuObservation?.metric.windSpeed ?? owmCurrent?.wind_speed ?? openMeteoResponse?.current?.wind_speed_10m
        self.high = owmDaily?.temp.max ?? openMeteoResponse?.daily.temperature_2m_max.first
        self.low = owmDaily?.temp.min ?? openMeteoResponse?.daily.temperature_2m_min.first
        self.dewPoint = wuObservation?.metric.dewpt ?? owmCurrent?.dew_point
        self.pressure = wuObservation?.metric.pressure ?? owmCurrent?.pressure ?? openMeteoResponse?.current?.pressure_msl
        self.windGust = wuObservation?.metric.windGust ?? owmCurrent?.wind_gust ?? openMeteoResponse?.current?.wind_gusts_10m
        self.uvIndex = Int(wuObservation?.uv ?? Double(owmCurrent?.uvi ?? 0))
        self.solarRadiation = wuObservation?.solarRadiation ?? owmCurrent?.clouds ?? Double(openMeteoResponse?.current?.cloud_cover ?? 0)
        
        // Initialize forecasts if OpenMeteo data is available
        if let openMeteoDaily = openMeteoResponse?.daily {
            self.forecasts = zip(0..<openMeteoDaily.time.count, openMeteoDaily.time).map { index, _ in
                Forecast(from: openMeteoDaily, index: index)
            }
        }
        
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
            self.feelsLike = wuObservation?.metric.heatIndex ?? owmCurrent?.feels_like ?? openMeteoResponse?.current?.apparent_temperature
        }
    }
}

// MARK: - Unit Conversion Extension
extension Weather {
    mutating func convertUnits(from: String, to: String) {
        if from == to { return }
        
        #if DEBUG
        print("Converting from \(from) to \(to)")
        #endif
        
        if from == "Metric" && to == "Imperial" {
            if let temp = temperature { temperature = temp * 9/5 + 32 }
            if let feels = feelsLike { feelsLike = feels * 9/5 + 32 }
            if let highTemp = high { high = highTemp * 9/5 + 32 }
            if let lowTemp = low { low = lowTemp * 9/5 + 32 }
            if let dewPointTemp = dewPoint { dewPoint = dewPointTemp * 9/5 + 32 }
            if let speed = windSpeed { windSpeed = speed * 0.621371 }
            if let gust = windGust { windGust = gust * 0.621371 }
            if let press = pressure { pressure = press * 0.02953 }
            
            // Convert forecasts
            for i in 0..<forecasts.count {
                var forecast = forecasts[i]
                forecast.maxTemp = forecast.maxTemp * 9/5 + 32
                forecast.minTemp = forecast.minTemp * 9/5 + 32
                forecast.windSpeed = forecast.windSpeed * 0.621371
                forecast.pressure = forecast.pressure * 0.02953
                forecasts[i] = forecast
            }
            
            #if DEBUG
            print("Converted temperature: \(temperature ?? 0)°F")
            #endif
        } else if from == "Imperial" && to == "Metric" {
            if let temp = temperature { temperature = (temp - 32) * 5/9 }
            if let feels = feelsLike { feelsLike = (feels - 32) * 5/9 }
            if let highTemp = high { high = (highTemp - 32) * 5/9 }
            if let lowTemp = low { low = (lowTemp - 32) * 5/9 }
            if let dewPointTemp = dewPoint { dewPoint = (dewPointTemp - 32) * 5/9 }
            if let speed = windSpeed { windSpeed = speed * 1.60934 }
            if let gust = windGust { windGust = gust * 1.60934 }
            if let press = pressure { pressure = press * 33.8639 }
            
            // Convert forecasts
            for i in 0..<forecasts.count {
                var forecast = forecasts[i]
                forecast.maxTemp = (forecast.maxTemp - 32) * 5/9
                forecast.minTemp = (forecast.minTemp - 32) * 5/9
                forecast.windSpeed = forecast.windSpeed * 1.60934
                forecast.pressure = forecast.pressure * 33.8639
                forecasts[i] = forecast
            }
            
            #if DEBUG
            print("Converted temperature: \(temperature ?? 0)°C")
            #endif
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
    let stationID: String
    let obsTimeUtc: String
    let obsTimeLocal: String
    let neighborhood: String?
    let softwareType: String?
    let country: String?
    let solarRadiation: Double
    let lon: Double
    let realtimeFrequency: Double?
    let epoch: Int
    let lat: Double
    let uv: Double
    let winddir: Int
    let humidity: Double
    let qcStatus: Int
    let metric: WUMetric
}

struct WUMetric: Codable {
    let temp: Double
    let heatIndex: Double
    let dewpt: Double
    let windChill: Double
    let windSpeed: Double
    let windGust: Double
    let pressure: Double
    let precipRate: Double
    let precipTotal: Double
    let elev: Double
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
