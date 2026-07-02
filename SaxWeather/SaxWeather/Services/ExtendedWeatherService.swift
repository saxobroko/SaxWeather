//
//  ExtendedWeatherService.swift
//  SaxWeather
//
//  Created on 13/01/2026
//

import Foundation

#if canImport(WeatherKit)
import WeatherKit
import CoreLocation
#endif

class ExtendedWeatherService {
    static let shared = ExtendedWeatherService()
    
    private init() {}
    
    func fetchExtendedData(
        latitude: Double,
        longitude: Double,
        dataSource: String,
        existingWeather: Weather? = nil
    ) async throws -> (
        airQuality: AirQualityData?,
        pollen: PollenData?,
        sunMoon: SunMoonData?,
        hourlyPrecip: [HourlyPrecipitation],
        locationTimeZoneIdentifier: String?
    ) {
        
        var airQuality: AirQualityData?
        var sunMoon: SunMoonData?
        var hourlyPrecip: [HourlyPrecipitation] = []
        var locationTimeZoneIdentifier: String?
        let pollen: PollenData? = nil // No data source available yet
        
        // Strategy: Extract from primary source first, then fill gaps with Open-Meteo
        switch dataSource {
        case "weatherkit":
            #if canImport(WeatherKit)
            if #available(iOS 16.0, macOS 13.0, *) {
                (sunMoon, hourlyPrecip) = await fetchFromWeatherKit(latitude: latitude, longitude: longitude)
                locationTimeZoneIdentifier = TimeZone.current.identifier
            }
            #endif
            
        case "openweathermap":
            // OpenWeatherMap has limited extended data in free tier
            // UV index and sunrise/sunset would be in the One Call API (requires subscription)
            // So we'll fall back to Open-Meteo for everything
            break
            
        case "weatherunderground":
            // Weather Underground typically provides station-specific data
            // Extended features not available through PWS API
            // Explicitly fetch from Open-Meteo
            #if DEBUG
            print("📍 WU detected - fetching extended data from Open-Meteo")
            #endif
            break
            
        case "openmeteo":
            // Already using Open-Meteo as primary, fetch everything
            (airQuality, sunMoon, hourlyPrecip, locationTimeZoneIdentifier) = await fetchFromOpenMeteo(
                latitude: latitude,
                longitude: longitude
            )
            return (airQuality, pollen, sunMoon, hourlyPrecip, locationTimeZoneIdentifier)
            
        default:
            break
        }
        
        // Fill gaps with Open-Meteo (always fetch Air Quality from Open-Meteo as fallback)
        if sunMoon == nil || hourlyPrecip.isEmpty || airQuality == nil {
            #if DEBUG
            print("📍 Fetching missing extended data from Open-Meteo (sunMoon: \(sunMoon == nil), precip: \(hourlyPrecip.isEmpty), aqi: \(airQuality == nil))")
            #endif
            
            let (openMeteoAQI, openMeteoSun, openMeteoPrecip, openMeteoTimeZone) = await fetchFromOpenMeteo(
                latitude: latitude,
                longitude: longitude
            )
            
            airQuality = airQuality ?? openMeteoAQI
            sunMoon = sunMoon ?? openMeteoSun
            if hourlyPrecip.isEmpty {
                hourlyPrecip = openMeteoPrecip
            }
            locationTimeZoneIdentifier = locationTimeZoneIdentifier ?? openMeteoTimeZone
            
            #if DEBUG
            print("📍 After Open-Meteo fallback - sunMoon: \(sunMoon != nil), precip: \(hourlyPrecip.count) hours, aqi: \(airQuality?.aqi ?? -1)")
            #endif
        }
        
        return (airQuality, pollen, sunMoon, hourlyPrecip, locationTimeZoneIdentifier)
    }
    
    // MARK: - WeatherKit Data Extraction
    #if canImport(WeatherKit)
    @available(iOS 16.0, macOS 13.0, *)
    private func fetchFromWeatherKit(latitude: Double, longitude: Double) async -> (sunMoon: SunMoonData?, hourlyPrecip: [HourlyPrecipitation]) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        do {
            let weather = try await WeatherKit.WeatherService.shared.weather(for: location)
            
            // Extract sun/moon data from daily forecast
            var sunMoon: SunMoonData?
            if let today = weather.dailyForecast.first,
               let sunrise = today.sun.sunrise,
               let sunset = today.sun.sunset {
                let moonPhase = calculateMoonPhase(for: Date())
                sunMoon = SunMoonData(
                    sunrise: sunrise,
                    sunset: sunset,
                    moonPhase: moonPhase,
                    moonrise: today.moon.moonrise,
                    moonset: today.moon.moonset
                )
            }
            
            // Extract hourly precipitation (next 24 hours)
            let hourlyPrecip = weather.hourlyForecast.forecast.prefix(24).map { hour in
                HourlyPrecipitation(
                    hour: hour.date,
                    probability: Int(hour.precipitationChance * 100),
                    amount: hour.precipitationAmount.value
                )
            }
            
            #if DEBUG
            print("✅ Extended data from WeatherKit: Sun/Moon + \(hourlyPrecip.count)h precipitation")
            #endif
            return (sunMoon, Array(hourlyPrecip))
            
        } catch {
            #if DEBUG
            print("⚠️ Failed to fetch WeatherKit extended data: \(error)")
            #endif
            return (nil, [])
        }
    }
    #endif
    
    // MARK: - Open-Meteo Fallback
    private func fetchFromOpenMeteo(latitude: Double, longitude: Double) async -> (
        airQuality: AirQualityData?,
        sunMoon: SunMoonData?,
        hourlyPrecip: [HourlyPrecipitation],
        locationTimeZoneIdentifier: String?
    ) {
        #if DEBUG
        print("🌍 fetchFromOpenMeteo called with coordinates: \(latitude), \(longitude)")
        #endif
        
        // Fetch each component independently to avoid one failure blocking others
        async let airQualityResult = fetchAirQuality(latitude: latitude, longitude: longitude)
        async let sunMoonResult = fetchSunMoon(latitude: latitude, longitude: longitude)
        async let hourlyPrecipResult = fetchHourlyPrecipitation(latitude: latitude, longitude: longitude)
        
        let airQuality = await airQualityResult
        let sunMoon = await sunMoonResult
        let (hourlyPrecip, locationTimeZoneIdentifier) = await hourlyPrecipResult
        
        #if DEBUG
        print("✅ Extended data from Open-Meteo:")
        print("   - AQI: \(airQuality != nil ? "✓ (AQI \(airQuality!.aqi))" : "✗")")
        print("   - Sun/Moon: \(sunMoon != nil ? "✓" : "✗")")
        print("   - Precipitation: \(hourlyPrecip.count > 0 ? "✓ (\(hourlyPrecip.count)h)" : "✗")")
        #endif
        
        return (airQuality, sunMoon, hourlyPrecip, locationTimeZoneIdentifier)
    }
    private func fetchAirQuality(latitude: Double, longitude: Double) async -> AirQualityData? {
        // Open-Meteo Air Quality API
        let urlString = "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=\(latitude)&longitude=\(longitude)&current=european_aqi,pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone"
        
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(AirQualityResponse.self, from: data)
            
            guard let current = response.current else { return nil }
            
            // European AQI scale (0-100+)
            let aqi = Int(current.european_aqi ?? 50)
            let category = AirQualityData.AQICategory.from(aqi: aqi)
            
            let pollutants = AirQualityData.Pollutants(
                pm25: current.pm2_5,
                pm10: current.pm10,
                o3: current.ozone,
                no2: current.nitrogen_dioxide,
                so2: current.sulphur_dioxide,
                co: current.carbon_monoxide
            )
            
            return AirQualityData(aqi: aqi, category: category, pollutants: pollutants)
        } catch {
            #if DEBUG
            print("❌ Air Quality fetch error: \(error)")
            #endif
            return nil
        }
    }
    
    // MARK: - Sun/Moon Data
    private func fetchSunMoon(latitude: Double, longitude: Double) async -> SunMoonData? {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&daily=sunrise,sunset&timezone=auto&forecast_days=1"
        
        #if DEBUG
        print("🌅 Fetching Sun/Moon data from: \(urlString)")
        #endif
        
        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("❌ Sun/Moon: Invalid URL")
            #endif
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            #if DEBUG
            if let httpResponse = response as? HTTPURLResponse {
                print("🌅 Sun/Moon API response status: \(httpResponse.statusCode)")
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🌅 Sun/Moon raw response: \(jsonString.prefix(200))...")
            }
            #endif
            
            let decodedResponse = try JSONDecoder().decode(SunMoonResponse.self, from: data)
            
            guard let daily = decodedResponse.daily,
                  let sunriseString = daily.sunrise.first,
                  let sunsetString = daily.sunset.first else {
                #if DEBUG
                print("❌ Sun/Moon: Missing daily data or sunrise/sunset")
                print("   - daily exists: \(decodedResponse.daily != nil)")
                print("   - sunrise count: \(decodedResponse.daily?.sunrise.count ?? 0)")
                print("   - sunset count: \(decodedResponse.daily?.sunset.count ?? 0)")
                #endif
                return nil
            }
            
            #if DEBUG
            print("🌅 Sun/Moon strings: sunrise=\(sunriseString), sunset=\(sunsetString)")
            print("🌅 Timezone from API: \(decodedResponse.timezone ?? "unknown")")
            #endif
            
            // Create a date formatter that handles the Open-Meteo format (without timezone suffix)
            let timeZone = OpenMeteoDateParser.timeZone(
                identifier: decodedResponse.timezone,
                utcOffsetSeconds: decodedResponse.utc_offset_seconds
            )
            
            guard let sunrise = OpenMeteoDateParser.date(from: sunriseString, timeZone: timeZone),
                  let sunset = OpenMeteoDateParser.date(from: sunsetString, timeZone: timeZone) else {
                #if DEBUG
                print("❌ Sun/Moon: Failed to parse dates from strings")
                print("   - Tried format: yyyy-MM-dd'T'HH:mm[:ss]")
                print("   - Timezone: \(timeZone.identifier)")
                #endif
                return nil
            }
            
            // Calculate moon phase (simplified - based on date)
            let moonPhase = calculateMoonPhase(for: Date())
            
            #if DEBUG
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            timeFormatter.timeZone = timeZone
            print("✅ Sun/Moon data created:")
            print("   - Sunrise: \(timeFormatter.string(from: sunrise)) (\(sunrise))")
            print("   - Sunset: \(timeFormatter.string(from: sunset)) (\(sunset))")
            print("   - Moon Phase: \(moonPhase)")
            #endif
            
            return SunMoonData(
                sunrise: sunrise,
                sunset: sunset,
                moonPhase: moonPhase,
                moonrise: nil, // Open-Meteo doesn't provide this
                moonset: nil   // Open-Meteo doesn't provide this
            )
        } catch {
            #if DEBUG
            print("❌ Sun/Moon fetch error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   - Missing key: \(key.stringValue) in \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("   - Type mismatch: expected \(type) at \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("   - Value not found: \(type) at \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("   - Data corrupted at \(context.codingPath)")
                @unknown default:
                    print("   - Unknown decoding error")
                }
            }
            #endif
            return nil
        }
    }
    
    // MARK: - Hourly Precipitation
    private func fetchHourlyPrecipitation(latitude: Double, longitude: Double) async -> ([HourlyPrecipitation], String?) {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&hourly=precipitation_probability,precipitation&timezone=auto&forecast_days=2"
        
        #if DEBUG
        print("🌧️ Fetching Precipitation data from: \(urlString)")
        #endif
        
        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("❌ Precipitation: Invalid URL")
            #endif
            return ([], nil)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            #if DEBUG
            if let httpResponse = response as? HTTPURLResponse {
                print("🌧️ Precipitation API response status: \(httpResponse.statusCode)")
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🌧️ Precipitation raw response: \(jsonString.prefix(300))...")
            }
            #endif
            
            let decodedResponse = try JSONDecoder().decode(HourlyPrecipResponse.self, from: data)
            
            guard let hourly = decodedResponse.hourly else {
                #if DEBUG
                print("❌ Precipitation: Missing hourly data")
                #endif
                return ([], nil)
            }
            
            #if DEBUG
            print("🌧️ Precipitation data received: \(hourly.time.count) hours")
            print("🌧️ Timezone from API: \(decodedResponse.timezone ?? "unknown")")
            if let offset = decodedResponse.utc_offset_seconds {
                print("🌧️ UTC offset from API: \(offset)s")
            }
            #endif
            
            let timeZone = OpenMeteoDateParser.timeZone(
                identifier: decodedResponse.timezone,
                utcOffsetSeconds: decodedResponse.utc_offset_seconds
            )
            
            var precipData: [HourlyPrecipitation] = []
            
            for (index, timeString) in hourly.time.enumerated() {
                guard let date = OpenMeteoDateParser.date(from: timeString, timeZone: timeZone) else {
                    #if DEBUG
                    print("⚠️ Failed to parse time: \(timeString)")
                    #endif
                    continue
                }
                
                let probability = hourly.precipitation_probability[index]
                let amount = hourly.precipitation[index]
                
                precipData.append(
                    HourlyPrecipitation(
                        hour: date,
                        probability: probability,
                        amount: amount
                    )
                )
            }
            
            #if DEBUG
            print("✅ Precipitation data created: \(precipData.count) hours")
            #endif
            
            return (precipData, decodedResponse.timezone ?? timeZone.identifier)
        } catch {
            #if DEBUG
            print("❌ Hourly precipitation fetch error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   - Missing key: \(key.stringValue) in \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("   - Type mismatch: expected \(type) at \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("   - Value not found: \(type) at \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("   - Data corrupted at \(context.codingPath)")
                @unknown default:
                    print("   - Unknown decoding error")
                }
            }
            #endif
            return ([], nil)
        }
    }
    
    // MARK: - Helper: Moon Phase Calculation
    private func calculateMoonPhase(for date: Date) -> SunMoonData.MoonPhase {
        // Known new moon: January 1, 2000
        let knownNewMoon = Date(timeIntervalSince1970: 946684800) // Jan 1, 2000
        let daysSinceKnownNewMoon = date.timeIntervalSince(knownNewMoon) / 86400
        
        // Lunar cycle is approximately 29.53 days
        let lunarCycle = 29.53
        let phase = (daysSinceKnownNewMoon.truncatingRemainder(dividingBy: lunarCycle)) / lunarCycle
        
        return SunMoonData.MoonPhase.from(phase: phase)
    }
}

// MARK: - Response Models

struct AirQualityResponse: Codable {
    let current: CurrentAirQuality?
    
    struct CurrentAirQuality: Codable {
        let european_aqi: Double?
        let pm10: Double?
        let pm2_5: Double?
        let carbon_monoxide: Double?
        let nitrogen_dioxide: Double?
        let sulphur_dioxide: Double?
        let ozone: Double?
    }
}

struct SunMoonResponse: Codable {
    let daily: DailySunMoon?
    let timezone: String?
    let utc_offset_seconds: Int?
    
    struct DailySunMoon: Codable {
        let sunrise: [String]
        let sunset: [String]
    }
}

struct HourlyPrecipResponse: Codable {
    let hourly: HourlyPrecip?
    let timezone: String?
    let utc_offset_seconds: Int?
    
    struct HourlyPrecip: Codable {
        let time: [String]
        let precipitation_probability: [Int]
        let precipitation: [Double]
    }
}
