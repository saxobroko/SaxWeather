//
//  WeatherService+OpenMeteo.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-26 14:42:31
//

import Foundation
import CoreLocation

extension WeatherService {
    // Local error handling to avoid ambiguity
    private enum OpenMeteoError: Error {
        case missingCoordinates
        case invalidURL
        case invalidResponse(Int)
        case noCurrentData
        case decodingError(Error)
    }
    
    private func handleWeatherError(_ error: OpenMeteoError) -> Error {
        switch error {
        case .missingCoordinates:
            return NSError(domain: "OpenMeteoService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No weather data available: missing coordinates"])
        case .invalidURL:
            return NSError(domain: "OpenMeteoService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        case .invalidResponse(let code):
            return NSError(domain: "OpenMeteoService", code: 3, userInfo: [NSLocalizedDescriptionKey: "API error: status code \(code)"])
        case .noCurrentData:
            return NSError(domain: "OpenMeteoService", code: 4, userInfo: [NSLocalizedDescriptionKey: "No weather data available"])
        case .decodingError(let error):
            return NSError(domain: "OpenMeteoService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response: \(error.localizedDescription)"])
        }
    }
    
    @MainActor
    func fetchOpenMeteoWeather() async {
        let openMeteoService = OpenMeteoService()
        
        do {
            // Get location coordinates either from GPS or stored values
            let lat = useGPS ?
                String(locationManager.location?.coordinate.latitude ?? 0) :
                UserDefaults.standard.string(forKey: "latitude") ?? "0"
            
            let lon = useGPS ?
                String(locationManager.location?.coordinate.longitude ?? 0) :
                UserDefaults.standard.string(forKey: "longitude") ?? "0"
            
            // Convert to Double
            let latitude = Double(lat) ?? 0
            let longitude = Double(lon) ?? 0
            
            let response = try await openMeteoService.fetchWeather(
                latitude: latitude,
                longitude: longitude,
                unitSystem: unitSystem
            )
            
            // Create forecasts separately to break up the complex expression
            let forecasts = createForecasts(from: response.daily)
            
            // Update weather model with the response data
            var weather = Weather(
                wuObservation: nil,
                owmCurrent: nil,
                owmDaily: nil,
                openMeteoResponse: response,
                unitSystem: unitSystem
            )
            
            // Set the forecasts explicitly
            weather.forecasts = forecasts
            
            // Create and set the forecast object for the view
            let dailyForecasts = forecasts.map { forecast in
                WeatherForecast.DailyForecast(
                    date: forecast.date,
                    tempMax: forecast.maxTemp,
                    tempMin: forecast.minTemp,
                    precipitation: forecast.precipitation,
                    precipitationProbability: 0.0, // Use 0.0 to ensure Double type
                    weatherCode: forecast.weatherCode,
                    windSpeed: forecast.windSpeed,
                    windDirection: Double(forecast.windDirection), // Convert Int to Double
                    humidity: forecast.humidity,
                    pressure: forecast.pressure,
                    uvIndex: forecast.uvIndex,
                    sunrise: nil,
                    sunset: nil
                )
            }
            
            self.weather = weather
            self.forecast = WeatherForecast(daily: dailyForecasts)
            
        } catch {
            print("❌ Failed to fetch OpenMeteo weather:", error.localizedDescription)
        }
    }
    
    private func createForecasts(from daily: OpenMeteoResponse.Daily) -> [Weather.Forecast] {
        return daily.time.indices.map { i in
            Weather.Forecast(
                from: daily,
                index: i
            )
        }
    }
    
    private func getDate(from dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withTimeZone]
        return formatter.date(from: dateString)
    }
    
    // MARK: - Enhanced OpenMeteo Methods
    
    // Create a public version of the URL request creator
    func createOpenMeteoRequest(from url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        return request
    }
    
    // Create a public version of the dew point calculator
    func calculateOpenMeteoDewPoint(temp: Double, humidity: Double) -> Double {
        let a = 17.27
        let b = 237.7
        
        let alpha = ((a * temp) / (b + temp)) + log(humidity/100.0)
        let dewPoint = (b * alpha) / (a - alpha)
        return dewPoint
    }
    
    func fetchOpenMeteoWeather(
        latitude: String,
        longitude: String
    ) async throws -> (OWMCurrent?, OWMDaily?) {
        guard !latitude.isEmpty, !longitude.isEmpty else {
            throw handleWeatherError(.missingCoordinates)
        }
        
        let urlString = "https://api.open-meteo.com/v1/forecast?" +
            "latitude=\(latitude)" +
            "&longitude=\(longitude)" +
            "&current=temperature_2m,relative_humidity_2m,apparent_temperature," +
            "precipitation,wind_speed_10m,wind_gusts_10m,pressure_msl,cloud_cover,uv_index" +
            "&daily=temperature_2m_max,temperature_2m_min,precipitation_sum," +
            "precipitation_probability_max,weather_code,wind_speed_10m_max," +
            "wind_direction_10m_dominant,relative_humidity_2m_max,pressure_msl_max," +
            "uv_index_max,sunrise,sunset" +
            "&forecast_days=\(UserDefaults.standard.integer(forKey: "forecastDays"))" +
            "&timezone=UTC"
        
        print("🌐 OpenMeteo URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw handleWeatherError(.invalidURL)
        }
        
        let request = createOpenMeteoRequest(from: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 OpenMeteo API Response Status: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📡 OpenMeteo API Response Body:")
                    print(responseString)
                }
                
                if httpResponse.statusCode != 200 {
                    print("❌ OpenMeteo Error: Unexpected status code \(httpResponse.statusCode)")
                    throw handleWeatherError(.invalidResponse(httpResponse.statusCode))
                }
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys // Ensure we're using exact key names
            let openMeteoResponse = try decoder.decode(OpenMeteoResponse.self, from: data)
            
            createDetailedForecast(from: openMeteoResponse)
            
            guard let current = openMeteoResponse.current else {
                throw handleWeatherError(.noCurrentData)
            }
            
            let owmCurrent = OWMCurrent(
                temp: current.temperature_2m,
                feels_like: current.apparent_temperature,
                humidity: Double(current.relative_humidity_2m),
                dew_point: calculateOpenMeteoDewPoint(
                    temp: current.temperature_2m,
                    humidity: Double(current.relative_humidity_2m)
                ),
                pressure: current.pressure_msl,
                wind_speed: current.wind_speed_10m,
                wind_gust: current.wind_gusts_10m,
                uvi: Int(round(current.uv_index)),
                clouds: Double(current.cloud_cover)
            )
            
            let owmDaily = OWMDaily(temp: OWMDaily.OWMDailyTemp(
                min: openMeteoResponse.daily.temperature_2m_min.first ?? 0,
                max: openMeteoResponse.daily.temperature_2m_max.first ?? 0
            ))
            
            return (owmCurrent, owmDaily)
        } catch let decodingError as DecodingError {
            print("❌ OpenMeteo Error:", decodingError.localizedDescription)
            print("❌ Error Details:", decodingError)
            throw handleWeatherError(.decodingError(decodingError))
        } catch {
            print("❌ OpenMeteo Error:", error.localizedDescription)
            print("❌ Error Details:", error)
            throw handleWeatherError(.decodingError(error))
        }
    }
    
    func createDetailedForecast(from response: OpenMeteoResponse) {
        // Initialize date formatter for ISO8601 dates
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        
        // Create daily forecasts using indices
        var dailyForecasts: [WeatherForecast.DailyForecast] = []
        
        for index in response.daily.time.indices {
            // Skip if any required values are missing
            guard index < response.daily.weather_code.count,
                  index < response.daily.temperature_2m_max.count,
                  index < response.daily.temperature_2m_min.count else {
                continue
            }
            
            let timeString = response.daily.time[index]
            let date = dateFormatter.date(from: timeString) ?? Date()
            
            // Get precipitation sum with fallback to 0
            var precipitation: Double = 0.0
            if index < response.daily.precipitation_sum.count {
                // Force unwrapping with safe default: if it's nil, use 0.0
                precipitation = response.daily.precipitation_sum[index] ?? 0.0
            }
            
            // Get precipitation probability with fallback to 0
            var precipProb: Double = 0.0
            if index < response.daily.precipitation_probability_max.count {
                precipProb = Double(response.daily.precipitation_probability_max[index])
            }
            
            // Get wind speed with fallback to 0
            var windSpeed: Double = 0.0
            if index < response.daily.wind_speed_10m_max.count {
                windSpeed = response.daily.wind_speed_10m_max[index]
            }
            
            // Get wind direction with fallback to 0
            var windDir: Double = 0.0
            if index < response.daily.wind_direction_10m_dominant.count {
                // Force unwrapping with safe default: if it's nil, use 0.0
                windDir = response.daily.wind_direction_10m_dominant[index] ?? 0.0
            }
            
            // Get humidity with fallback to 0
            var humidity: Double = 0.0
            if index < response.daily.relative_humidity_2m_max.count {
                humidity = Double(response.daily.relative_humidity_2m_max[index])
            }
            
            // Get pressure with fallback to 0
            var pressure: Double = 0.0
            if index < response.daily.pressure_msl_max.count {
                pressure = response.daily.pressure_msl_max[index]
            }
            
            // Get UV index with fallback to 0
            var uvIndex: Double = 0.0
            if index < response.daily.uv_index_max.count {
                uvIndex = response.daily.uv_index_max[index]
            }
            
            // Get sunrise/sunset
            let sunriseStr = index < response.daily.sunrise.count ? response.daily.sunrise[index] : ""
            let sunsetStr = index < response.daily.sunset.count ? response.daily.sunset[index] : ""
            let sunrise = dateFormatter.date(from: sunriseStr)
            let sunset = dateFormatter.date(from: sunsetStr)
            
            // Debug info
            print("🔄 Creating forecast for day \(timeString):")
            print("   Temperature: \(response.daily.temperature_2m_max[index])°/\(response.daily.temperature_2m_min[index])°")
            print("   Humidity: \(humidity)%")
            print("   Weather Code: \(response.daily.weather_code[index])")
            print("   Precipitation: \(precipitation)")
            print("   Wind Direction: \(windDir)")
            
            // Create forecast with guaranteed non-optional values
            let forecast = WeatherForecast.DailyForecast(
                date: date,
                tempMax: response.daily.temperature_2m_max[index],
                tempMin: response.daily.temperature_2m_min[index],
                precipitation: precipitation,
                precipitationProbability: precipProb,
                weatherCode: response.daily.weather_code[index],
                windSpeed: windSpeed,
                windDirection: windDir,
                humidity: humidity,
                pressure: pressure,
                uvIndex: uvIndex,
                sunrise: sunrise,
                sunset: sunset
            )
            
            dailyForecasts.append(forecast)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.forecast = WeatherForecast(daily: dailyForecasts)
        }
    }
    
    // MARK: - Forecast Methods
    @MainActor
    func fetchForecasts() async {
        print("🔄 Fetching forecast data...")
        
        // Log current location settings
        print("📱 GPS enabled: \(useGPS)")
        
        // Get location coordinates either from GPS or stored values
        var lat = ""
        var lon = ""
        
        if useGPS && locationManager.location != nil {
            // Use current location if GPS is enabled and we have a location
            lat = String(locationManager.location!.coordinate.latitude)
            lon = String(locationManager.location!.coordinate.longitude)
            print("📍 Using current location: \(lat), \(lon)")
        } else {
            // Try to use saved location
            lat = UserDefaults.standard.string(forKey: "latitude") ?? ""
            lon = UserDefaults.standard.string(forKey: "longitude") ?? ""
            print("📍 Trying saved location: \(lat), \(lon)")
            
            // If GPS is enabled but location is nil, or if no saved coords, request location
            if (useGPS && locationManager.location == nil) || (lat.isEmpty || lon.isEmpty) {
                print("⚠️ No valid coordinates available, requesting location")
                requestLocation()
                
                // Wait a moment for location to update
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                // Check if we got location after waiting
                if let location = locationManager.location {
                    lat = String(location.coordinate.latitude)
                    lon = String(location.coordinate.longitude)
                    print("📍 Got location after request: \(lat), \(lon)")
                }
            }
        }
        
        // Final check for valid coordinates
        guard !lat.isEmpty && !lon.isEmpty,
              let latitude = Double(lat), let longitude = Double(lon) else {
            print("❌ Could not obtain valid coordinates")
            self.error = "Unable to determine location. Please check location permissions or enter coordinates manually."
            return
        }
        
        print("📍 Fetching forecast for coordinates: \(latitude), \(longitude)")
        
        do {
            // Use the forecast-only helper
            self.forecast = try await fetchOpenMeteoForecast(
                latitude: latitude,
                longitude: longitude
            )
            print("✅ Forecast data processing complete")
        } catch {
            print("❌ Failed to fetch forecasts: \(error.localizedDescription)")
            self.error = "Failed to fetch forecast: \(error.localizedDescription)"
        }
    }
    
    var forecastDays: Int {
        let days = UserDefaults.standard.integer(forKey: "forecastDays")
        // Default to 7 if not set or if zero (invalid value)
        return days > 0 ? days : 7
    }

    // Define the OpenMeteo Forecast Response here since it can't be found
    struct OpenMeteoForecastResponse: Decodable {
        let daily: Daily
        
        struct Daily: Decodable {
            let time: [String]
            let weather_code: [Int]
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
            let precipitation_sum: [Double?]
            let precipitation_probability_max: [Int]
            let wind_speed_10m_max: [Double]
            let wind_direction_10m_dominant: [Double?]
            let relative_humidity_2m_max: [Int]
            let pressure_msl_max: [Double]
            let uv_index_max: [Double]
            let sunrise: [String]
            let sunset: [String]
        }
    }

    @MainActor
    func fetchOpenMeteoForecast(latitude: Double, longitude: Double) async throws -> WeatherForecast {
        // Create URL for forecast-only endpoint (no current data)
        let urlString = "https://api.open-meteo.com/v1/forecast?" +
                "latitude=\(latitude)" +
                "&longitude=\(longitude)" +
                "&daily=temperature_2m_max,temperature_2m_min,precipitation_sum," +
                "precipitation_probability_max,weather_code,wind_speed_10m_max," +
                "wind_direction_10m_dominant,relative_humidity_2m_max,pressure_msl_max," +
                "uv_index_max,sunrise,sunset" +
                "&forecast_days=\(forecastDays)" +
                "&timezone=auto"
            
        print("🌐 OpenMeteo Forecast URL: \(urlString) (Requesting \(forecastDays) days)")
            
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "OpenMeteoService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenMeteoService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid API response"])
        }
        
        // For debugging purposes
        if let responseString = String(data: data.prefix(500), encoding: .utf8) {
            print("📡 Forecast Response preview: \(responseString)...")
        }
        
        // Use a separate decoder for the forecast-only response
        let decoder = JSONDecoder()
        
        // Now using our class-level struct
        let forecastResponse = try decoder.decode(OpenMeteoForecastResponse.self, from: data)
        
        // Process the forecast data using the class-level struct
        let dailyForecasts = processForecastDaily(from: forecastResponse.daily)
        return WeatherForecast(daily: dailyForecasts)
    }

    // Method specifically for processing our forecast response
    private func processForecastDaily(from daily: OpenMeteoForecastResponse.Daily) -> [WeatherForecast.DailyForecast] {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        var forecasts: [WeatherForecast.DailyForecast] = []
        
        for index in daily.time.indices {
            guard index < daily.weather_code.count,
                  index < daily.temperature_2m_max.count,
                  index < daily.temperature_2m_min.count else {
                continue
            }
            
            // Extract all optional values with safe defaults
            let precipProbability = index < daily.precipitation_probability_max.count ?
                daily.precipitation_probability_max[index] : 0
            let windSpeed = index < daily.wind_speed_10m_max.count ?
                daily.wind_speed_10m_max[index] : 0.0
            let humidity = index < daily.relative_humidity_2m_max.count ?
                daily.relative_humidity_2m_max[index] : 0
            let pressure = index < daily.pressure_msl_max.count ?
                daily.pressure_msl_max[index] : 0.0
            let uvIndex = index < daily.uv_index_max.count ?
                daily.uv_index_max[index] : 0.0
                
            let sunriseStr = index < daily.sunrise.count ? daily.sunrise[index] : ""
            let sunsetStr = index < daily.sunset.count ? daily.sunset[index] : ""
            
            let precipitation: Double
            if index < daily.precipitation_sum.count, let precip = daily.precipitation_sum[index] {
                precipitation = precip
            } else {
                precipitation = 0.0
            }

            let windDirection: Double
            if index < daily.wind_direction_10m_dominant.count, let windDir = daily.wind_direction_10m_dominant[index] {
                windDirection = windDir
            } else {
                windDirection = 0.0
            }
            
            let forecast = WeatherForecast.DailyForecast(
                date: dateFormatter.date(from: daily.time[index]) ?? Date(),
                tempMax: daily.temperature_2m_max[index],
                tempMin: daily.temperature_2m_min[index],
                precipitation: precipitation,
                precipitationProbability: Double(precipProbability),
                weatherCode: daily.weather_code[index],
                windSpeed: windSpeed,
                windDirection: windDirection,
                humidity: Double(humidity),
                pressure: pressure,
                uvIndex: uvIndex,
                sunrise: dateFormatter.date(from: sunriseStr),
                sunset: dateFormatter.date(from: sunsetStr)
            )
            
            forecasts.append(forecast)
            print("✅ Added forecast for \(daily.time[index])")
        }
        
        return forecasts
    }
}
