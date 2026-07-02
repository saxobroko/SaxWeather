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
    // Current (live) wind direction in degrees (0-360).
    // Distinct from `forecasts[0].windDirection` which is the
    // day's prevailing direction. Populated from WU
    // (`winddir`), Open-Meteo `current.wind_direction_10m`,
    // or WeatherKit's `currentWeather.wind.direction`.
    var currentWindDirection: Double?
    // Human-readable location label (e.g. Weather Underground
    // neighbourhood name, "Current Location", saved-location
    // name). Surfaces in the header so the user always knows
    // which place they're looking at.
    var locationName: String?
    // Extended metrics fetched separately by
    // `ExtendedWeatherService` and merged onto the base
    // weather record by `WeatherService`. Kept optional /
    // empty-initialised so a missing extended fetch doesn't
    // prevent the basic forecast from displaying.
    var airQuality: AirQualityData?
    var sunData: SunMoonData?
    var pollen: PollenData?
    var hourlyPrecipitation: [HourlyPrecipitation] = []
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
    
    private func calculateHeatIndex(temperatureC: Double, humidity: Double) -> Double {
        // Convert to Fahrenheit for the formula
        let T = temperatureC * 9/5 + 32
        let RH = humidity
        
        // Rothfusz regression (used by US National Weather Service)
        let c1 = -42.379
        let c2 = 2.04901523
        let c3 = 10.14333127
        let c4 = -0.22475541
        let c5 = -0.00683783
        let c6 = -0.05481717
        let c7 = 0.00122874
        let c8 = 0.00085282
        let c9 = -0.00000199
        
        let HI = c1 + (c2 * T) + (c3 * RH) + (c4 * T * RH) + (c5 * T * T) + 
                 (c6 * RH * RH) + (c7 * T * T * RH) + (c8 * T * RH * RH) + 
                 (c9 * T * T * RH * RH)
        
        // Convert back to Celsius
        return (HI - 32) * 5/9
    }
    
    private func calculateWindChill(temperatureC: Double, windSpeedMS: Double) -> Double {
        // Convert wind speed from m/s to km/h for the formula
        let windSpeedKMH = windSpeedMS * 3.6
        
        // Wind chill formula (Environment Canada / US National Weather Service)
        // Only valid for temperatures <= 10°C and wind speeds >= 4.8 km/h
        guard windSpeedKMH >= 4.8 else {
            return temperatureC // Not enough wind for wind chill effect
        }
        
        let windChill = 13.12 + 0.6215 * temperatureC - 11.37 * pow(windSpeedKMH, 0.16) + 
                       0.3965 * temperatureC * pow(windSpeedKMH, 0.16)
        
        return windChill
    }
    
    private func calculateFeelsLike(temperature: Double, humidity: Double, windSpeed: Double) -> Double {
        // Use different formulas based on temperature:
        // - Hot weather (>= 27°C): Heat Index (accounts for humidity making it feel hotter)
        // - Cold weather (<= 10°C): Wind Chill (accounts for wind making it feel colder)
        // - Moderate weather: Australian Apparent Temperature
        
        let feelsLike: Double
        let method: String
        
        if temperature >= 27.0 {
            // Hot weather - use Heat Index
            feelsLike = calculateHeatIndex(temperatureC: temperature, humidity: humidity)
            method = "Heat Index"
        } else if temperature <= 10.0 {
            // Cold weather - use Wind Chill
            feelsLike = calculateWindChill(temperatureC: temperature, windSpeedMS: windSpeed)
            method = "Wind Chill"
        } else {
            // Moderate weather - use Australian Apparent Temperature
            let vaporPressure = calculateVaporPressure(temperature: temperature, relativeHumidity: humidity)
            // AT = Ta + 0.33E - 0.70WS - 4.00
            feelsLike = temperature + 0.33 * vaporPressure - 0.70 * windSpeed - 4.00
            method = "Apparent Temp"
        }
        
        #if DEBUG
        print("🌡️ Feels Like Calculation: temp=\(String(format: "%.1f", temperature))°C, humidity=\(String(format: "%.0f", humidity))%, wind=\(String(format: "%.1f", windSpeed))m/s → feels=\(String(format: "%.1f", feelsLike))°C (using \(method))")
        #endif
        
        return feelsLike
    }
    
    private func ensureMetricAndCalculateFeelsLike(temperature: Double, humidity: Double, windSpeed: Double, currentUnit: String) -> Double {
        let unit = UnitSystem.from(rawValue: currentUnit)
        let tempInCelsius = UnitConverter.convertTemperature(temperature, from: unit, to: .metric)
        let windInMetersPerSecond = UnitConverter.storedWindToMps(windSpeed, currentUnit: unit)

        let feelsLikeCelsius = calculateFeelsLike(
            temperature: tempInCelsius,
            humidity: humidity,
            windSpeed: windInMetersPerSecond
        )

        return UnitConverter.convertTemperature(feelsLikeCelsius, from: .metric, to: unit)
    }
    
    // MARK: - Initializer
    init(wuObservation: WUObservation?, owmCurrent: OWMCurrent?, owmDaily: OWMDaily?, openMeteoResponse: OpenMeteoResponse? = nil, unitSystem: String = "Metric") {
        self.lastUpdateTime = Date()
        
        self.temperature = wuObservation?.metric.temp ?? owmCurrent?.temp ?? openMeteoResponse?.current?.temperature_2m
        self.humidity = wuObservation?.humidity ?? owmCurrent?.humidity ?? Double(openMeteoResponse?.current?.relative_humidity_2m ?? 0)
        self.windSpeed = wuObservation?.metric.windSpeed ?? owmCurrent?.wind_speed ?? openMeteoResponse?.current?.wind_speed_10m
        self.high = owmDaily?.temp.max ?? openMeteoResponse?.daily?.temperature_2m_max.first
        self.low = owmDaily?.temp.min ?? openMeteoResponse?.daily?.temperature_2m_min.first
        self.dewPoint = wuObservation?.metric.dewpt ?? owmCurrent?.dew_point
        self.pressure = wuObservation?.metric.pressure ?? owmCurrent?.pressure ?? openMeteoResponse?.current?.pressure_msl
        self.windGust = wuObservation?.metric.windGust ?? owmCurrent?.wind_gust ?? openMeteoResponse?.current?.wind_gusts_10m

        // WU (units=m) returns wind in m/s. Open-Meteo and
        // WeatherKit store km/h. OWM is normalised at parse time.
        if wuObservation != nil {
            if let speed = windSpeed { windSpeed = UnitConverter.mpsToKmh(speed) }
            if let gust = windGust { windGust = UnitConverter.mpsToKmh(gust) }
        }
        self.uvIndex = Int(wuObservation?.uv ?? Double(owmCurrent?.uvi ?? 0))
        self.solarRadiation = wuObservation?.solarRadiation ?? owmCurrent?.clouds ?? Double(openMeteoResponse?.current?.cloud_cover ?? 0)

        // Current wind direction in degrees (0-360). WU exposes
        // it as Int, Open-Meteo returns Double on the current
        // snapshot. Promote to a single Double so callers
        // (cardinal-direction helpers, etc.) only have to handle
        // one type. Nil when the active source didn't provide
        // one — callers fall back to forecasts[0].windDirection
        // in that case.
        if let wuDir = wuObservation?.winddir {
            self.currentWindDirection = Double(wuDir)
        } else if let omDir = openMeteoResponse?.current?.wind_direction_10m {
            self.currentWindDirection = omDir
        } else {
            self.currentWindDirection = nil
        }

        // Location label: prefer WU's neighbourhood string when
        // available, otherwise defer to the caller (ContentView
        // falls back to GPS / saved-location name).
        if let neighborhood = wuObservation?.neighborhood, !neighborhood.isEmpty {
            self.locationName = neighborhood
        } else {
            self.locationName = nil
        }

        // Extended payloads (AQI / sun-moon / hourly precip) are
        // populated after the fact by ExtendedWeatherService.
        // Initialising them to nil / empty keeps this constructor
        // self-contained and avoids forcing the basic fetch to
        // block on the extended one.
        self.airQuality = nil
        self.sunData = nil
        self.pollen = nil
        self.hourlyPrecipitation = []
        
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
            self.cachedCondition = "Sunny"
        } else if temp < 0 {
            self.cachedCondition = "Snowy"
        } else if wind > 20 {
            self.cachedCondition = "Windy"
        } else if hum > 80 {
            self.cachedCondition = "Rainy"
        } else {
            self.cachedCondition = "Partly Cloudy"
        }
        
        if let temp = self.temperature,
           let hum = self.humidity,
           let wind = self.windSpeed {
            self.feelsLike = ensureMetricAndCalculateFeelsLike(
                temperature: temp,
                humidity: hum,
                windSpeed: wind,
                currentUnit: "Metric"
            )
        } else {
            self.feelsLike = wuObservation?.metric.heatIndex ?? owmCurrent?.feels_like ?? openMeteoResponse?.current?.apparent_temperature
        }
    }
}

// MARK: - Unit Conversion Extension
extension Weather {
    mutating func convertUnits(from: String, to: String) {
        guard from != to else { return }
        let fromUnit = UnitSystem.from(rawValue: from)
        let toUnit = UnitSystem.from(rawValue: to)

        #if DEBUG
        print("Converting from \(from) to \(to)")
        #endif

        if let temp = temperature { temperature = UnitConverter.convertTemperature(temp, from: fromUnit, to: toUnit) }
        if let feels = feelsLike { feelsLike = UnitConverter.convertTemperature(feels, from: fromUnit, to: toUnit) }
        if let highTemp = high { high = UnitConverter.convertTemperature(highTemp, from: fromUnit, to: toUnit) }
        if let lowTemp = low { low = UnitConverter.convertTemperature(lowTemp, from: fromUnit, to: toUnit) }
        if let dewPointTemp = dewPoint { dewPoint = UnitConverter.convertTemperature(dewPointTemp, from: fromUnit, to: toUnit) }
        if let speed = windSpeed { windSpeed = UnitConverter.convertWind(speed, from: fromUnit, to: toUnit) }
        if let gust = windGust { windGust = UnitConverter.convertWind(gust, from: fromUnit, to: toUnit) }
        if let press = pressure { pressure = UnitConverter.convertPressure(press, from: fromUnit, to: toUnit) }

        for i in 0..<forecasts.count {
            var forecast = forecasts[i]
            forecast.maxTemp = UnitConverter.convertTemperature(forecast.maxTemp, from: fromUnit, to: toUnit)
            forecast.minTemp = UnitConverter.convertTemperature(forecast.minTemp, from: fromUnit, to: toUnit)
            forecast.windSpeed = UnitConverter.convertWind(forecast.windSpeed, from: fromUnit, to: toUnit)
            forecast.pressure = UnitConverter.convertPressure(forecast.pressure, from: fromUnit, to: toUnit)
            forecasts[i] = forecast
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
