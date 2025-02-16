import Foundation
import CoreLocation

struct Weather: Codable {
    let temperature: Double?
    let feelsLike: Double?
    let high: Double?
    let low: Double?
    let humidity: Double?
    let dewPoint: Double?
    let pressure: Double?
    let windSpeed: Double?
    let windGust: Double?
    let uvIndex: Int?
    let solarRadiation: Double?
    let condition: String?
    
    var hasData: Bool {
        return temperature != nil || feelsLike != nil || high != nil || low != nil || humidity != nil || dewPoint != nil || pressure != nil || windSpeed != nil || windGust != nil || uvIndex != nil || solarRadiation != nil
    }
    
    init(wuObservation: WUObservation?, owmCurrent: OWMCurrent?, owmDaily: OWMDaily?) {
        self.temperature = wuObservation?.metric.temp ?? owmCurrent?.temp
        self.feelsLike = wuObservation?.metric.heatIndex ?? owmCurrent?.feels_like
        self.high = owmDaily?.temp.max
        self.low = owmDaily?.temp.min
        self.humidity = wuObservation?.humidity ?? owmCurrent?.humidity
        self.dewPoint = wuObservation?.metric.dewpt ?? owmCurrent?.dew_point
        self.pressure = wuObservation?.metric.pressure ?? owmCurrent?.pressure
        self.windSpeed = wuObservation?.metric.windSpeed ?? owmCurrent?.wind_speed
        self.windGust = wuObservation?.metric.windGust ?? owmCurrent?.wind_gust
        self.uvIndex = wuObservation?.uv ?? owmCurrent?.uvi
        self.solarRadiation = wuObservation?.solarRadiation ?? owmCurrent?.clouds
        self.condition = Weather.inferCondition(wuObservation: wuObservation, owmCurrent: owmCurrent)
    }
    
    private static func inferCondition(wuObservation: WUObservation?, owmCurrent: OWMCurrent?) -> String {
        if let wu = wuObservation {
            if wu.metric.temp > 30 { return "sunny" }
            if wu.metric.temp < 0 { return "snowy" }
            if wu.metric.windSpeed > 20 { return "windy" }
            if wu.uv > 5 { return "sunny" }
            if wu.humidity > 80 { return "rainy" }
        }
        if let owm = owmCurrent {
            if owm.temp > 30 { return "sunny" }
            if owm.temp < 0 { return "snowy" }
            if owm.wind_speed > 20 { return "windy" }
            if owm.uvi > 5 { return "sunny" }
            if owm.humidity > 80 { return "rainy" }
        }
        return "default"
    }
}

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

class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var weather: Weather?
    @Published var useGPS = false
    
    private var locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    func fetchWeather() {
        let wuApiKey = UserDefaults.standard.string(forKey: "wuApiKey") ?? ""
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        let owmApiKey = UserDefaults.standard.string(forKey: "owmApiKey") ?? ""
        var latitude = UserDefaults.standard.string(forKey: "latitude") ?? ""
        var longitude = UserDefaults.standard.string(forKey: "longitude") ?? ""
        let unitSystem = UserDefaults.standard.string(forKey: "unitSystem") ?? "Metric"

        if useGPS {
            if let location = locationManager.location?.coordinate {
                latitude = "\(location.latitude)"
                longitude = "\(location.longitude)"
            } else {
                print("❌ No GPS location available")
                return
            }
        }

        let group = DispatchGroup()
        
        var wuObservation: WUObservation?
        var owmCurrent: OWMCurrent?
        var owmDaily: OWMDaily?
        
        if !wuApiKey.isEmpty, !stationID.isEmpty {
            group.enter()
            fetchWUWeather(apiKey: wuApiKey, stationID: stationID) { observation in
                wuObservation = observation
                group.leave()
            }
        }
        
        if !owmApiKey.isEmpty, !latitude.isEmpty, !longitude.isEmpty {
            group.enter()
            fetchOWMWeather(apiKey: owmApiKey, latitude: latitude, longitude: longitude, unitSystem: unitSystem) { current, daily in
                owmCurrent = current
                owmDaily = daily?.first
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.weather = Weather(wuObservation: wuObservation, owmCurrent: owmCurrent, owmDaily: owmDaily)
            if self.weather?.hasData == false {
                self.weather = nil
                print("❌ No observations found")
            } else {
                print("✅ Weather Data Updated:", self.weather ?? "No data")
            }
        }
    }
    
    func fetchWUWeather(apiKey: String, stationID: String, completion: @escaping (WUObservation?) -> Void) {
        let urlString = "https://api.weather.com/v2/pws/observations/current?stationId=\(stationID)&format=json&units=m&apiKey=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for Weather Underground")
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Error fetching weather from Weather Underground: \(error.localizedDescription)")
                completion(nil)
                return
            }
            guard let data = data else {
                print("❌ No data received from Weather Underground")
                completion(nil)
                return
            }
            do {
                let decodedResponse = try JSONDecoder().decode(WUResponse.self, from: data)
                completion(decodedResponse.observations.first)
            } catch {
                print("❌ Decoding Error for Weather Underground:", error)
                completion(nil)
            }
        }.resume()
    }
    
    func fetchOWMWeather(apiKey: String, latitude: String, longitude: String, unitSystem: String, completion: @escaping (OWMCurrent?, [OWMDaily]?) -> Void) {
        let units = unitSystem == "Metric" ? "metric" : "imperial"
        let urlString = "https://api.openweathermap.org/data/2.5/onecall?lat=\(latitude)&lon=\(longitude)&exclude=minutely,hourly,alerts&units=\(units)&appid=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for OpenWeatherMap")
            completion(nil, nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Error fetching weather from OpenWeatherMap: \(error.localizedDescription)")
                completion(nil, nil)
                return
            }
            guard let data = data else {
                print("❌ No data received from OpenWeatherMap")
                completion(nil, nil)
                return
            }
            do {
                let decodedResponse = try JSONDecoder().decode(OWMResponse.self, from: data)
                completion(decodedResponse.current, decodedResponse.daily)
            } catch {
                print("❌ Decoding Error for OpenWeatherMap:", error)
                completion(nil, nil)
            }
        }.resume()
    }
    
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            print("✅ Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            UserDefaults.standard.set("\(location.coordinate.latitude)", forKey: "latitude")
            UserDefaults.standard.set("\(location.coordinate.longitude)", forKey: "longitude")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location update failed: \(error.localizedDescription)")
    }
}
