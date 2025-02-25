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
    @Published var useGPS = false
    @Published private(set) var _unitSystem: String
    
    private let locationManager: CLLocationManager
    
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
        
        override init() {
            self._unitSystem = UserDefaults.standard.string(forKey: "unitSystem") ?? "Metric"
            self.locationManager = CLLocationManager()
            super.init()
            locationManager.delegate = self
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
        let latitude = useGPS ? "\(locationManager.location?.coordinate.latitude ?? 0)" :
                            UserDefaults.standard.string(forKey: "latitude") ?? ""
        let longitude = useGPS ? "\(locationManager.location?.coordinate.longitude ?? 0)" :
                             UserDefaults.standard.string(forKey: "longitude") ?? ""
        
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
            
            let owmCurrent = OWMCurrent(
                    temp: openMeteoResponse.current.temperature_2m,
                    feels_like: openMeteoResponse.current.apparent_temperature,
                    humidity: Double(openMeteoResponse.current.relative_humidity_2m),
                    dew_point: calculateDewPoint(
                        temp: openMeteoResponse.current.temperature_2m,
                        humidity: Double(openMeteoResponse.current.relative_humidity_2m)
                    ),
                    pressure: openMeteoResponse.current.pressure_msl,
                    wind_speed: openMeteoResponse.current.wind_speed_10m,
                    wind_gust: openMeteoResponse.current.wind_gusts_10m,
                    uvi: Int(round(openMeteoResponse.current.uv_index)),
                    clouds: Double(openMeteoResponse.current.cloud_cover)
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
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withTime, .withTimeZone]
        
        // Process daily forecasts
        let dailyForecasts = zip4(
            response.daily.time,
            response.daily.weather_code,
            response.daily.temperature_2m_max,
            response.daily.temperature_2m_min
        ).enumerated().map { index, data in
            let (timeString, code, maxTemp, minTemp) = data
            
            return WeatherForecast.DailyForecast(
                date: dateFormatter.date(from: timeString) ?? Date(),
                tempMax: maxTemp,
                tempMin: minTemp,
                precipitation: response.daily.precipitation_sum[safe: index] ?? 0,
                precipitationProbability: Double(response.daily.precipitation_probability_max[safe: index] ?? 0),
                weatherCode: code,
                windSpeed: response.daily.wind_speed_10m_max[safe: index] ?? 0,
                windDirection: response.daily.wind_direction_10m_dominant[safe: index] ?? 0,
                humidity: Double(response.daily.relative_humidity_2m_max[safe: index] ?? 0),  // Use max humidity
                pressure: response.daily.pressure_msl_max[safe: index] ?? 0,
                uvIndex: response.daily.uv_index_max[safe: index] ?? 0,
                sunrise: dateFormatter.date(from: response.daily.sunrise[safe: index] ?? ""),
                sunset: dateFormatter.date(from: response.daily.sunset[safe: index] ?? "")
            )
        }
        
        DispatchQueue.main.async {
            self.forecast = WeatherForecast(daily: dailyForecasts)        }
    }

    private func zip4<A, B, C, D>(_ a: [A], _ b: [B], _ c: [C], _ d: [D]) -> [(A, B, C, D)] {
        var result: [(A, B, C, D)] = []
        let count = min(a.count, b.count, c.count, d.count)
        for i in 0..<count {
            result.append((a[i], b[i], c[i], d[i]))
        }
        return result
    }
                
                // MARK: - Helper Functions
                
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
            }
