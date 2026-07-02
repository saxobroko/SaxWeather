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
            let forecasts = response.daily.map { createForecasts(from: $0) } ?? []
            
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
            #if DEBUG
            print("❌ Failed to fetch OpenMeteo weather:", error.localizedDescription)
            #endif
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
            "precipitation,wind_speed_10m,wind_direction_10m,wind_gusts_10m,pressure_msl,cloud_cover,uv_index" +
            "&daily=temperature_2m_max,temperature_2m_min,precipitation_sum," +
            "precipitation_probability_max,weather_code,wind_speed_10m_max," +
            "wind_direction_10m_dominant,relative_humidity_2m_max,pressure_msl_max," +
            "uv_index_max,sunrise,sunset" +
            "&forecast_days=\(UserDefaults.standard.integer(forKey: "forecastDays"))" +
            "&timezone=UTC"
        
        #if DEBUG
        print("🌐 OpenMeteo URL: \(urlString)")
        #endif
        
        guard let url = URL(string: urlString) else {
            throw handleWeatherError(.invalidURL)
        }
        
        let request = createOpenMeteoRequest(from: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            #if DEBUG
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
            #endif
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys // Ensure we're using exact key names
            let openMeteoResponse = try decoder.decode(OpenMeteoResponse.self, from: data)
            
            createDetailedForecast(from: openMeteoResponse)
            
            guard let current = openMeteoResponse.current else {
                throw handleWeatherError(.noCurrentData)
            }
            
            let owmCurrent = OWMCurrent(
                temp: current.temperature_2m ?? 0,
                feels_like: current.apparent_temperature ?? 0,
                humidity: Double(current.relative_humidity_2m ?? 0),
                dew_point: calculateOpenMeteoDewPoint(
                    temp: current.temperature_2m ?? 0,
                    humidity: Double(current.relative_humidity_2m ?? 0)
                ),
                pressure: current.pressure_msl ?? 0,
                wind_speed: current.wind_speed_10m ?? 0,
                wind_gust: current.wind_gusts_10m ?? 0,
                uvi: Int(round(current.uv_index ?? 0)),
                clouds: Double(current.cloud_cover ?? 0)
            )
            
            let owmDaily = OWMDaily(temp: OWMDaily.OWMDailyTemp(
                min: openMeteoResponse.daily?.temperature_2m_min.first ?? 0,
                max: openMeteoResponse.daily?.temperature_2m_max.first ?? 0
            ))
            
            return (owmCurrent, owmDaily)
        } catch let decodingError as DecodingError {
            #if DEBUG
            print("❌ OpenMeteo Error:", decodingError.localizedDescription)
            print("❌ Error Details:", decodingError)
            #endif
            throw handleWeatherError(.decodingError(decodingError))
        } catch {
            #if DEBUG
            print("❌ OpenMeteo Error:", error.localizedDescription)
            print("❌ Error Details:", error)
            #endif
            throw handleWeatherError(.decodingError(error))
        }
    }
    
    func createDetailedForecast(from response: OpenMeteoResponse) {
        guard let daily = response.daily else { return }

        // Initialize date formatter for ISO8601 dates
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        
        // Create daily forecasts using indices
        var dailyForecasts: [WeatherForecast.DailyForecast] = []
        
        for index in daily.time.indices {
            // Skip if any required values are missing
            guard index < daily.weather_code.count,
                  index < daily.temperature_2m_max.count,
                  index < daily.temperature_2m_min.count else {
                continue
            }
            
            let timeString = daily.time[index]
            let date = dateFormatter.date(from: timeString) ?? Date()
            
            // Get precipitation sum with fallback to 0
            var precipitation: Double = 0.0
            if index < daily.precipitation_sum.count {
                // Force unwrapping with safe default: if it's nil, use 0.0
                precipitation = daily.precipitation_sum[index] ?? 0.0
            }
            
            // Get precipitation probability with fallback to 0
            var precipProb: Double = 0.0
            if index < daily.precipitation_probability_max.count {
                precipProb = Double(daily.precipitation_probability_max[index])
            }
            
            // Get wind speed with fallback to 0
            var windSpeed: Double = 0.0
            if index < daily.wind_speed_10m_max.count {
                windSpeed = daily.wind_speed_10m_max[index]
            }
            
            // Get wind direction with fallback to 0
            var windDir: Double = 0.0
            if index < daily.wind_direction_10m_dominant.count {
                // Force unwrapping with safe default: if it's nil, use 0.0
                windDir = daily.wind_direction_10m_dominant[index] ?? 0.0
            }
            
            // Get humidity with fallback to 0
            var humidity: Double = 0.0
            if index < daily.relative_humidity_2m_max.count {
                humidity = Double(daily.relative_humidity_2m_max[index])
            }
            
            // Get pressure with fallback to 0
            var pressure: Double = 0.0
            if index < daily.pressure_msl_max.count {
                pressure = daily.pressure_msl_max[index]
            }
            
            // Get UV index with fallback to 0
            var uvIndex: Double = 0.0
            if index < daily.uv_index_max.count {
                uvIndex = daily.uv_index_max[index]
            }
            
            // Get sunrise/sunset
            let sunriseStr = index < daily.sunrise.count ? daily.sunrise[index] : ""
            let sunsetStr = index < daily.sunset.count ? daily.sunset[index] : ""
            let sunrise = dateFormatter.date(from: sunriseStr)
            let sunset = dateFormatter.date(from: sunsetStr)
            
            // Debug info
            #if DEBUG
            print("🔄 Creating forecast for day \(timeString):")
            print("   Temperature: \(daily.temperature_2m_max[index])°/\(daily.temperature_2m_min[index])°")
            print("   Humidity: \(humidity)%")
            print("   Weather Code: \(daily.weather_code[index])")
            print("   Precipitation: \(precipitation)")
            print("   Wind Direction: \(windDir)")
            #endif
            
            // Create forecast with guaranteed non-optional values
            let forecast = WeatherForecast.DailyForecast(
                date: date,
                tempMax: daily.temperature_2m_max[index],
                tempMin: daily.temperature_2m_min[index],
                precipitation: precipitation,
                precipitationProbability: precipProb,
                weatherCode: daily.weather_code[index],
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
        #if DEBUG
        print("\n📅 FORECAST DATA SOURCE")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        #endif
        
        // Check if API keys are disabled
        let disableAPIKeys = UserDefaults.standard.bool(forKey: "disableAPIKeys")
        
        // Check user's forecast source preference
        let preferOpenMeteo = UserDefaults.standard.bool(forKey: "useOpenMeteoAsDefault")
        
        if disableAPIKeys {
            #if DEBUG
            print("🔒 API Keys are DISABLED - using only Apple Weather or Open-Meteo for forecasts")
            #endif
        }
        
        // If WeatherKit was used for current weather, forecasts are already included
        if currentDataSource == "weatherkit" {
            if #available(iOS 16.0, macOS 13.0, *) {
                #if DEBUG
                print("📍 Using Apple WeatherKit for forecasts (matches current weather source)")
                print("✅ SUCCESS: WeatherKit already provided forecast data with current conditions")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
                #endif
                return
            }
        }
        
        // If using WU or OWM for current weather, choose forecast source based on user preference
        if currentDataSource == "weatherunderground" || currentDataSource == "openweathermap" {
            if preferOpenMeteo {
                #if DEBUG
                print("⚙️  Current weather from \(currentDataSource.uppercased()), using OpenMeteo for forecasts (user preference)")
                #endif
            } else {
                // User prefers WeatherKit, try to use it for forecasts
                if #available(iOS 16.0, macOS 13.0, *) {
                    #if DEBUG
                    print("⚙️  Current weather from \(currentDataSource.uppercased()), attempting WeatherKit for forecasts (user preference)")
                    #endif
                    
                    var lat = ""
                    var lon = ""
                    
                    if useGPS && locationManager.location != nil {
                        lat = String(locationManager.location!.coordinate.latitude)
                        lon = String(locationManager.location!.coordinate.longitude)
                    } else {
                        lat = UserDefaults.standard.string(forKey: "latitude") ?? ""
                        lon = UserDefaults.standard.string(forKey: "longitude") ?? ""
                    }
                    
                    if !lat.isEmpty && !lon.isEmpty {
                        do {
                            let _ = try await fetchWeatherKitWeather(latitude: lat, longitude: lon)
                            #if DEBUG
                            print("✅ SUCCESS: Using WeatherKit for forecasts (user preference)")
                            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
                            #endif
                            return
                        } catch {
                            #if DEBUG
                            print("❌ FAILED: WeatherKit forecast unavailable (\(error.localizedDescription))")
                            print("   → Falling back to OpenMeteo")
                            #endif
                        }
                    } else {
                        #if DEBUG
                        print("❌ No coordinates available for WeatherKit forecast, falling back to OpenMeteo")
                        #endif
                    }
                } else {
                    #if DEBUG
                    print("⚠️  User prefers WeatherKit but it's unavailable (iOS 16+ required)")
                    print("   → Using OpenMeteo for forecasts instead")
                    #endif
                }
            }
        }
        
        #if DEBUG
        print("🔄 Fetching forecast data...")
        print("📱 GPS enabled: \(useGPS)")
        print("🎯 Current weather source: \(currentDataSource)")
        #endif
        
        // Get location coordinates either from GPS or stored values
        var lat = ""
        var lon = ""
        
        if useGPS && locationManager.location != nil {
            // Use current location if GPS is enabled and we have a location
            lat = String(locationManager.location!.coordinate.latitude)
            lon = String(locationManager.location!.coordinate.longitude)
            #if DEBUG
            print("📍 Using current location: \(lat), \(lon)")
            #endif
        } else {
            // Try to use saved location
            lat = UserDefaults.standard.string(forKey: "latitude") ?? ""
            lon = UserDefaults.standard.string(forKey: "longitude") ?? ""
            #if DEBUG
            print("📍 Trying saved location: \(lat), \(lon)")
            #endif
            
            // If GPS is enabled but location is nil, or if no saved coords, request location
            if (useGPS && locationManager.location == nil) || (lat.isEmpty || lon.isEmpty) {
                #if DEBUG
                print("⚠️ No valid coordinates available, requesting location")
                #endif
                requestLocation()
                
                // Wait a moment for location to update
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                // Check if we got location after waiting
                if let location = locationManager.location {
                    lat = String(location.coordinate.latitude)
                    lon = String(location.coordinate.longitude)
                    #if DEBUG
                    print("📍 Got location after request: \(lat), \(lon)")
                    #endif
                }
            }
        }
        
        // Final check for valid coordinates
        guard !lat.isEmpty && !lon.isEmpty,
              let latitude = Double(lat), let longitude = Double(lon) else {
            #if DEBUG
            print("❌ Could not obtain valid coordinates")
            #endif
            self.error = WeatherError.apiError("Unable to determine location. Please check location permissions or enter coordinates manually.")
            return
        }

        #if DEBUG
        print("📍 Fetching forecast for coordinates: \(latitude), \(longitude)")
        #endif

        do {
            // Use the forecast-only helper
            #if DEBUG
            print("📍 Fetching forecast data from OpenMeteo")
            #endif
            self.forecast = try await fetchOpenMeteoForecast(
                latitude: latitude,
                longitude: longitude
            )
            self.forecastDataSource = "openmeteo" // Track forecast source
            #if DEBUG
            print("✅ SUCCESS: Using OpenMeteo for \(forecastDays)-day forecast")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            print("✅ Forecast data processing complete")
            #endif

            // Update widget with high/low from today's forecast
            if let weather = self.weather {
                self.saveWeatherDataForWidget(weather)
            }
        } catch {
            #if DEBUG
            print("❌ FAILED: OpenMeteo forecast unavailable (\(error.localizedDescription))")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            print("❌ Failed to fetch forecasts: \(error.localizedDescription)")
            #endif
            self.error = WeatherError.apiError("Failed to fetch forecast: \(error.localizedDescription)")
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
        
        #if DEBUG
        print("🌐 OpenMeteo Forecast URL: \(urlString) (Requesting \(forecastDays) days)")
        #endif
            
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "OpenMeteoService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenMeteoService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid API response"])
        }
        
        // For debugging purposes
        #if DEBUG
        if let responseString = String(data: data.prefix(500), encoding: .utf8) {
            print("📡 Forecast Response preview: \(responseString)...")
        }
        #endif
        
        // Use a separate decoder for the forecast-only response
        let decoder = JSONDecoder()
        
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
            #if DEBUG
            print("✅ Added forecast for \(daily.time[index])")
            #endif
        }
        
        return forecasts
    }
}
