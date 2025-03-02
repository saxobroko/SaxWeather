//
//  WeatherService.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-25 04:49:47
//

import Foundation
import CoreLocation

class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var weather: Weather?
    @Published var forecast: WeatherForecast?
    @Published var error: String?
    @Published var isLoading = false
    @Published private(set) var _useGPS: Bool
    @Published private(set) var _unitSystem: String
    
    let locationManager: CLLocationManager

    var unitSystem: String {
        get { _unitSystem }
        set {
            DispatchQueue.main.async {
                self._unitSystem = newValue
                UserDefaults.standard.set(newValue, forKey: "unitSystem")
                Task {
                    await self.fetchWeather()
                }
            }
        }
    }
    
    var useGPS: Bool {
        get { _useGPS }
        set {
            _useGPS = newValue
            UserDefaults.standard.set(newValue, forKey: "useGPS")
            
            if newValue {
                requestLocation()
            } else {
                // Validate saved coordinates - if they're empty, revert to GPS
                let savedLat = UserDefaults.standard.string(forKey: "latitude") ?? ""
                let savedLon = UserDefaults.standard.string(forKey: "longitude") ?? ""
                
                if savedLat.isEmpty || savedLon.isEmpty {
                    print("⚠️ No saved coordinates found, reverting to GPS")
                    _useGPS = true
                    UserDefaults.standard.set(true, forKey: "useGPS")
                    requestLocation()
                } else {
                    locationManager.stopUpdatingLocation()
                }
            }
            
            // Refresh weather data when GPS setting changes
            Task {
                await fetchWeather()
            }
        }
    }
        
    override init() {
        // Default to using GPS, read from UserDefaults if available
        self._unitSystem = UserDefaults.standard.string(forKey: "unitSystem") ?? "Metric"
        
        // Set useGPS to true by default (or if saved coords are empty)
        let savedLat = UserDefaults.standard.string(forKey: "latitude") ?? ""
        let savedLon = UserDefaults.standard.string(forKey: "longitude") ?? ""
        let hasCoordinates = !savedLat.isEmpty && !savedLon.isEmpty
        
        if UserDefaults.standard.object(forKey: "useGPS") != nil {
            // User has set preference, but validate if they chose manual mode
            let userChoice = UserDefaults.standard.bool(forKey: "useGPS")
            self._useGPS = userChoice || !hasCoordinates // Force GPS if no coordinates
        } else {
            // First launch - default to GPS
            self._useGPS = true
            UserDefaults.standard.set(true, forKey: "useGPS")
        }
        
        self.locationManager = CLLocationManager()
        super.init()
        
        locationManager.delegate = self
        
        // If using GPS, immediately request location permissions
        if _useGPS {
            requestLocation()
        }
    }
    
    // MARK: - Weather Methods
    func fetchWeather() async {
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            let weatherData = try await fetchWeatherData()
            await MainActor.run {
                self.weather = weatherData
                self.isLoading = false
            }
            
            // Always fetch forecast data after weather data is loaded
            await fetchForecasts()
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func fetchWeatherData() async throws -> Weather {
        let wuApiKey = UserDefaults.standard.string(forKey: "wuApiKey") ?? ""
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        let owmApiKey = UserDefaults.standard.string(forKey: "owmApiKey") ?? ""
        
        // Get location coordinates
        var latitude = ""
        var longitude = ""
        
        if useGPS && locationManager.location != nil {
            latitude = "\(locationManager.location!.coordinate.latitude)"
            longitude = "\(locationManager.location!.coordinate.longitude)"
        } else {
            latitude = UserDefaults.standard.string(forKey: "latitude") ?? ""
            longitude = UserDefaults.standard.string(forKey: "longitude") ?? ""
            
            // If GPS is enabled but location is nil, or if no saved coordinates, request location
            if (useGPS && locationManager.location == nil) || (latitude.isEmpty || longitude.isEmpty) {
                print("⚠️ No valid coordinates available for weather data, requesting location")
                requestLocation()
                
                // Wait a moment for location to update
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                if let location = locationManager.location {
                    latitude = "\(location.coordinate.latitude)"
                    longitude = "\(location.coordinate.longitude)"
                }
            }
        }
        
        // Final check for valid coordinates
        guard !latitude.isEmpty && !longitude.isEmpty else {
            throw WeatherError.noData
        }
        
        async let wuObservation = (!wuApiKey.isEmpty && !stationID.isEmpty) ?
            fetchWUWeather(apiKey: wuApiKey, stationID: stationID) :
            nil
        
        async let owmWeather = !owmApiKey.isEmpty ?
            fetchOWMWeather(
                apiKey: owmApiKey,
                latitude: latitude,
                longitude: longitude,
                unitSystem: unitSystem
            ) :
            (nil, nil)
        
        async let openMeteoWeather = (wuApiKey.isEmpty || stationID.isEmpty) && owmApiKey.isEmpty ?
            fetchOpenMeteoWeather(
                latitude: latitude,
                longitude: longitude
            ) :
            (nil, nil)
        
        let (wuData, (owmCurrent, owmDaily), (openMeteoCurrent, openMeteoDaily)) = try await (wuObservation, owmWeather, openMeteoWeather)
        
        var weather = Weather(
            wuObservation: wuData,
            owmCurrent: owmCurrent ?? openMeteoCurrent,
            owmDaily: owmDaily ?? openMeteoDaily,
            unitSystem: unitSystem
        )
        
        if unitSystem != "Metric" {
            weather.convertUnits(from: "Metric", to: unitSystem)
        }
        
        guard weather.hasData else {
            throw WeatherError.noData
        }
        
        return weather
    }
    
    private func fetchWUWeather(apiKey: String, stationID: String) async throws -> WUObservation? {
        guard !apiKey.isEmpty, !stationID.isEmpty else {
            print("❌ Weather Underground Error: Empty API key or station ID")
            throw WeatherError.invalidAPIKey
        }
        
        let urlString = "https://api.weather.com/v2/pws/observations/current?stationId=\(stationID)&format=json&units=m&numericPrecision=decimal&apiKey=\(apiKey)"
        print("🌐 Weather Underground URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Weather Underground Error: Invalid URL")
            throw WeatherError.invalidURL
        }
        
        var request = createURLRequest(from: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Weather Underground Response Status: \(httpResponse.statusCode)")
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 Weather Underground Response Body:")
                print(responseString)
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let wuResponse = try decoder.decode(WUResponse.self, from: data)
            
            if let observation = wuResponse.observations.first {
                print("✅ Weather Underground Data Parsed Successfully:")
                print("- Temperature: \(observation.metric.temp)°C")
                print("- Humidity: \(observation.humidity)%")
                print("- Wind Speed: \(observation.metric.windSpeed) m/s")
                print("- Pressure: \(observation.metric.pressure) hPa")
            }
            
            return wuResponse.observations.first
        } catch {
            print("❌ Weather Underground Error:", error)
            print("❌ Error Details:", error.localizedDescription)
            throw WeatherError.apiError(error.localizedDescription)
        }
    }
    
    private func fetchOWMWeather(
        apiKey: String,
        latitude: String,
        longitude: String,
        unitSystem: String
    ) async throws -> (OWMCurrent?, OWMDaily?) {
        guard !apiKey.isEmpty, !latitude.isEmpty, !longitude.isEmpty else {
            throw WeatherError.invalidAPIKey
        }
        
        let units = unitSystem == "Metric" ? "metric" : "imperial"
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(latitude)&lon=\(longitude)&units=\(units)&appid=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let request = createURLRequest(from: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 OpenWeatherMap API Response Status: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📡 OpenWeatherMap API Response Body:")
                    print(responseString)
                }
                
                if httpResponse.statusCode == 401 {
                    print("❌ OpenWeatherMap Error: Invalid API key")
                    throw WeatherError.invalidAPIKey
                } else if httpResponse.statusCode != 200 {
                    print("❌ OpenWeatherMap Error: Unexpected status code \(httpResponse.statusCode)")
                    throw WeatherError.apiError("Status code: \(httpResponse.statusCode)")
                }
            }
            
            let currentWeather = try JSONDecoder().decode(CurrentWeatherResponse.self, from: data)
            
            let owmCurrent = OWMCurrent(
                temp: currentWeather.main.temp,
                feels_like: currentWeather.main.feels_like,
                humidity: Double(currentWeather.main.humidity),
                dew_point: calculateDewPoint(temp: currentWeather.main.temp, humidity: Double(currentWeather.main.humidity)),
                pressure: Double(currentWeather.main.pressure),
                wind_speed: currentWeather.wind.speed,
                wind_gust: currentWeather.wind.gust ?? 0,
                uvi: 0,
                clouds: Double(currentWeather.clouds.all)
            )
            
            let owmDaily = OWMDaily(temp: OWMDaily.OWMDailyTemp(
                min: currentWeather.main.temp_min,
                max: currentWeather.main.temp_max
            ))
            
            return (owmCurrent, owmDaily)
        } catch {
            print("❌ OpenWeatherMap Error:", error.localizedDescription)
            print("❌ Error Details:", error)
            throw WeatherError.apiError(error.localizedDescription)
        }
    }
    
    private func fetchOpenMeteoWeather(
        latitude: String,
        longitude: String
    ) async throws -> (OWMCurrent?, OWMDaily?) {
        guard !latitude.isEmpty, !longitude.isEmpty else {
            throw WeatherError.noData
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
            throw WeatherError.invalidURL
        }
        
        let request = createURLRequest(from: url)
        
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
                    throw WeatherError.apiError("Status code: \(httpResponse.statusCode)")
                }
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys // Ensure we're using exact key names
            let openMeteoResponse = try decoder.decode(OpenMeteoResponse.self, from: data)
            
            createForecast(from: openMeteoResponse)
            
            guard let current = openMeteoResponse.current else {
                throw WeatherError.noData
            }
            
            let owmCurrent = OWMCurrent(
                temp: current.temperature_2m,
                feels_like: current.apparent_temperature,
                humidity: Double(current.relative_humidity_2m),
                dew_point: calculateDewPoint(
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
        } catch {
            print("❌ OpenMeteo Error:", error.localizedDescription)
            print("❌ Error Details:", error)
            throw WeatherError.apiError(error.localizedDescription)
        }
    }
    
    private func createForecast(from response: OpenMeteoResponse) {
        // Initialize date formatter for ISO8601 dates
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        
        // Create daily forecasts using indices
        var dailyForecasts: [WeatherForecast.DailyForecast] = []
        
        for index in response.daily.time.indices {
            // Skip if any required values are missing
            guard let code = response.daily.weather_code[safe: index],
                  let maxTemp = response.daily.temperature_2m_max[safe: index],
                  let minTemp = response.daily.temperature_2m_min[safe: index] else {
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
            let sunriseStr = response.daily.sunrise[safe: index] ?? ""
            let sunsetStr = response.daily.sunset[safe: index] ?? ""
            let sunrise = dateFormatter.date(from: sunriseStr)
            let sunset = dateFormatter.date(from: sunsetStr)
            
            // Debug info
            print("🔄 Creating forecast for day \(timeString):")
            print("   Temperature: \(maxTemp)°/\(minTemp)°")
            print("   Humidity: \(humidity)%")
            print("   Weather Code: \(code)")
            print("   Precipitation: \(precipitation)")
            print("   Wind Direction: \(windDir)")
            
            // Create forecast with guaranteed non-optional values
            let forecast = WeatherForecast.DailyForecast(
                date: date,
                tempMax: maxTemp,
                tempMin: minTemp,
                precipitation: precipitation,
                precipitationProbability: precipProb,
                weatherCode: code,
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
        
        DispatchQueue.main.async {
            self.forecast = WeatherForecast(daily: dailyForecasts)
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
        var usingCurrentLocation = false
        
        if useGPS && locationManager.location != nil {
            // Use current location if GPS is enabled and we have a location
            lat = String(locationManager.location!.coordinate.latitude)
            lon = String(locationManager.location!.coordinate.longitude)
            usingCurrentLocation = true
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
                    usingCurrentLocation = true
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
    
    // MARK: - Helper Functions

    // Define this struct outside the function to make it available throughout the class
    private struct ForecastAPIResponse: Decodable {
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
    
    private var forecastDays: Int {
        let days = UserDefaults.standard.integer(forKey: "forecastDays")
        // Default to 7 if not set or if zero (invalid value)
        return days > 0 ? days : 7
    }


    @MainActor
    private func fetchOpenMeteoForecast(latitude: Double, longitude: Double) async throws -> WeatherForecast {
        // Create URL for forecast-only endpoint (no current data)
        let urlString = "https://api.open-meteo.com/v1/forecast?" +
                "latitude=\(latitude)" +
                "&longitude=\(longitude)" +
                "&daily=temperature_2m_max,temperature_2m_min,precipitation_sum," +
                "precipitation_probability_max,weather_code,wind_speed_10m_max," +
                "wind_direction_10m_dominant,relative_humidity_2m_max,pressure_msl_max," +
                "uv_index_max,sunrise,sunset" +
                "&forecast_days=\(forecastDays)" +  // Now using the property
                "&timezone=auto"
            
            print("🌐 OpenMeteo Forecast URL: \(urlString) (Requesting \(forecastDays) days)")
            
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WeatherError.apiError("Invalid response")
        }
        
        // For debugging purposes
        if let responseString = String(data: data.prefix(500), encoding: .utf8) {
            print("📡 Forecast Response preview: \(responseString)...")
        }
        
        // Use a separate decoder for the forecast-only response
        let decoder = JSONDecoder()
        
        // Now using our class-level struct
        let forecastResponse = try decoder.decode(ForecastAPIResponse.self, from: data)
        
        // Process the forecast data using the class-level struct
        let dailyForecasts = processForecastDaily(from: forecastResponse.daily)
        return WeatherForecast(daily: dailyForecasts)
    }

    // Method specifically for processing our forecast response
    private func processForecastDaily(from daily: ForecastAPIResponse.Daily) -> [WeatherForecast.DailyForecast] {
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
            let precipProbability = daily.precipitation_probability_max[safe: index] ?? 0
            let windSpeed = daily.wind_speed_10m_max[safe: index] ?? 0.0
            let humidity = daily.relative_humidity_2m_max[safe: index] ?? 0
            let pressure = daily.pressure_msl_max[safe: index] ?? 0.0
            let uvIndex = daily.uv_index_max[safe: index] ?? 0.0
            let sunriseStr = daily.sunrise[safe: index] ?? ""
            let sunsetStr = daily.sunset[safe: index] ?? ""
            let precipitation: Double
            if let precip = daily.precipitation_sum[safe: index] {
                precipitation = precip ?? 0.0  // Unwrap the inner optional
            } else {
                precipitation = 0.0
            }

            let windDirection: Double
            if let windDir = daily.wind_direction_10m_dominant[safe: index] {
                windDirection = windDir ?? 0.0  // Unwrap the inner optional
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

    private func calculateDewPoint(temp: Double, humidity: Double) -> Double {
        let a = 17.27
        let b = 237.7
        
        let alpha = ((a * temp) / (b + temp)) + log(humidity/100.0)
        let dewPoint = (b * alpha) / (a - alpha)
        return dewPoint
    }

    private func createURLRequest(from url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        return request
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("📍 Location updated: \(locations.first?.coordinate ?? CLLocationCoordinate2D())")
        
        // Stop updating location after we get a reading - only need one update
        locationManager.stopUpdatingLocation()
        
        if useGPS {
            Task {
                await fetchWeather()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location Error: \(error.localizedDescription)")
        
        // Handle the error properly
        Task {
            await MainActor.run {
                self.error = "Location error: \(error.localizedDescription)"
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 Location authorization granted")
            // Request a location update
            locationManager.startUpdatingLocation()
            
            // Add a timer to stop location updates after a short period
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                print("⏱️ Stopping location updates after timeout")
                self?.locationManager.stopUpdatingLocation()
            }
            
            // Refresh weather data with new location permissions
            Task {
                await fetchWeather()
            }
        case .denied, .restricted:
            print("⚠️ Location permission denied")
            // Let the user know they need to enable location access
            Task {
                await MainActor.run {
                    self.error = "Location access denied. Please enable in Settings or use manual coordinates."
                }
            }
        default:
            break
        }
    }
    
    func requestLocation() {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            print("📍 Requesting location authorization")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 Location authorization already granted, starting location updates")
            // Use startUpdatingLocation with a timeout instead of requestLocation
            locationManager.startUpdatingLocation()
            
            // Add a timer to stop location updates after a short period
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                print("⏱️ Stopping location updates after timeout")
                self?.locationManager.stopUpdatingLocation()
            }
        case .denied, .restricted:
            print("⚠️ Location access denied or restricted")
            // Fall back to manual coordinates if available
            Task {
                await MainActor.run {
                    self.error = "Location access denied. Please check your settings or enter coordinates manually."
                }
            }
        @unknown default:
            print("⚠️ Unknown location authorization status")
            locationManager.requestWhenInUseAuthorization()
        }
    }
}

// MARK: - Array Extension
private extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Response Models
extension WeatherService {
    struct CurrentWeatherResponse: Codable {
        struct Main: Codable {
            let temp: Double
            let feels_like: Double
            let temp_min: Double
            let temp_max: Double
            let pressure: Double
            let humidity: Int
        }
        
        struct Wind: Codable {
            let speed: Double
            let gust: Double?
        }
        
        struct Clouds: Codable {
            let all: Int
        }
        
        let main: Main
        let wind: Wind
        let clouds: Clouds
    }
    
    enum WeatherError: Error {
        case invalidURL
        case invalidAPIKey
        case apiError(String)
        case decodingError(String)
        case noData
        
        var localizedDescription: String {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidAPIKey:
                return "Invalid API key"
            case .apiError(let message):
                return "API error: \(message)"
            case .decodingError(let message):
                return "Failed to decode response: \(message)"
            case .noData:
                return "No weather data available"
            }
        }
    }
}

// MARK: - OpenMeteo Forecast Response
extension WeatherService {
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
}
