import Foundation
import CoreLocation

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
        // Initialize all stored properties first
        self.lastUpdateTime = Date()
        
        // Initialize weather data properties
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
        
        // Initialize cachedCondition first
        let temp = self.temperature ?? 0
        let uv = self.uvIndex ?? 0
        let wind = self.windSpeed ?? 0
        let hum = self.humidity ?? 0
        
        // Determine condition
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
        
        // Calculate feels like temperature after all required properties are initialized
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
            // Fallback to API provided value if calculation isn't possible
            self.feelsLike = wuObservation?.metric.heatIndex ?? owmCurrent?.feels_like
        }
    }}

// MARK: - Unit Conversion Extension
extension Weather {
    mutating func convertUnits(from: String, to: String) {
        if from == to { return }
        
        print("Converting from \(from) to \(to)")
        
        if from == "Metric" && to == "Imperial" {
            // Metric to Imperial conversions
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
            // Imperial to Metric conversions
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
        
        // Recalculate feels like after unit conversion if we have all required data
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

// MARK: - Weather Service
@MainActor
class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var weather: Weather?
    @Published var useGPS = false {
        didSet {
            if useGPS {
                requestLocation()
            } else {
                stopUpdatingLocation()
            }
        }
    }
    
    @Published var unitSystem: String {
        didSet {
            if oldValue != unitSystem {
                if var currentWeather = weather {
                    currentWeather.convertUnits(from: oldValue, to: unitSystem)
                    weather = currentWeather
                }
                UserDefaults.standard.set(unitSystem, forKey: "unitSystem")
            }
        }
    }
    
    private let locationManager: CLLocationManager
    private var lastLocationUpdate: Date?
    private let locationUpdateThreshold: TimeInterval = 300
    
    override init() {
        self.locationManager = CLLocationManager()
        self.unitSystem = UserDefaults.standard.string(forKey: "unitSystem") ?? "Metric"
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 1000
        locationManager.allowsBackgroundLocationUpdates = false
    }
    
    // MARK: - Weather Methods
    func fetchWeather() async {
        do {
            let weather = try await fetchWeatherData()
            await MainActor.run {
                self.weather = weather
                print("✅ Weather Data Updated:", weather)
            }
        } catch {
            print("❌ Error fetching weather:", error.localizedDescription)
            await MainActor.run {
                self.weather = nil
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
        
        // Only fetch from configured services
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
        
        let (wuData, (owmCurrent, owmDaily)) = try await (wuObservation, owmWeather)
        
        var weather = Weather(
            wuObservation: wuData,
            owmCurrent: owmCurrent,
            owmDaily: owmDaily,
            unitSystem: unitSystem
        )
        
        // Ensure weather data is in the correct unit system
        if unitSystem != "Metric" {
            weather.convertUnits(from: "Metric", to: unitSystem)
        }
        
        guard weather.hasData else {
            throw WeatherError.noData
        }
        
        return weather
    }
    
    private func fetchWUWeather(apiKey: String, stationID: String) async throws -> WUObservation? {
        guard !apiKey.isEmpty, !stationID.isEmpty else { return nil }
        
        let urlString = "https://api.weather.com/v2/pws/observations/current?stationId=\(stationID)&format=json&units=m&apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let request = createURLRequest(from: url)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(WUResponse.self, from: data)
            return response.observations.first
        } catch {
            print("❌ Weather Underground Error:", error.localizedDescription)
            return nil
        }
    }
    
    private func fetchOWMWeather(
        apiKey: String,
        latitude: String,
        longitude: String,
        unitSystem: String
    ) async throws -> (OWMCurrent?, OWMDaily?) {
        guard !apiKey.isEmpty, !latitude.isEmpty, !longitude.isEmpty else {
            return (nil, nil)
        }
        
        let units = unitSystem == "Metric" ? "metric" : "imperial"
        let urlString = "https://api.openweathermap.org/data/2.5/onecall?lat=\(latitude)&lon=\(longitude)&exclude=minutely,hourly,alerts&units=\(units)&appid=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let request = createURLRequest(from: url)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(OWMResponse.self, from: data)
            return (response.current, response.daily.first)
        } catch {
            print("❌ OpenWeatherMap Error:", error.localizedDescription)
            return (nil, nil)
        }
    }
    
    private func createURLRequest(from url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 15
        return request
    }
    
    // MARK: - Location Methods
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        if let lastUpdate = lastLocationUpdate,
           Date().timeIntervalSince(lastUpdate) < locationUpdateThreshold {
            return
        }
        
        print("✅ Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        UserDefaults.standard.set("\(location.coordinate.latitude)", forKey: "latitude")
        UserDefaults.standard.set("\(location.coordinate.longitude)", forKey: "longitude")
        lastLocationUpdate = Date()
        
        if useGPS {
            Task {
                await fetchWeather()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location update failed:", error.localizedDescription)
    }
}

// MARK: - Errors
enum WeatherError: Error {
    case invalidURL
    case noData
    case networkError(String)
}
