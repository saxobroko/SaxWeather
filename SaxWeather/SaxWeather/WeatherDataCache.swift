import Foundation

class WeatherDataCache {
    static let shared = WeatherDataCache()
    
    private var weatherCache: [String: (data: Weather, timestamp: Date)] = [:]
    private var forecastCache: [String: (data: WeatherForecast, timestamp: Date)] = [:]
    private let queue = DispatchQueue(label: "com.saxweather.weathercache", qos: .userInitiated)
    
    // Cache expiration time in seconds (5 minutes)
    private let cacheExpiration: TimeInterval = 300
    
    private init() {}
    
    // MARK: - Weather Cache Methods
    
    func getWeather(for location: String) -> Weather? {
        return queue.sync {
            guard let cached = weatherCache[location],
                  Date().timeIntervalSince(cached.timestamp) < cacheExpiration else {
                return nil
            }
            return cached.data
        }
    }
    
    func setWeather(_ weather: Weather, for location: String) {
        queue.async {
            self.weatherCache[location] = (weather, Date())
        }
    }
    
    // MARK: - Forecast Cache Methods
    
    func getForecast(for location: String) -> WeatherForecast? {
        return queue.sync {
            guard let cached = forecastCache[location],
                  Date().timeIntervalSince(cached.timestamp) < cacheExpiration else {
                return nil
            }
            return cached.data
        }
    }
    
    func setForecast(_ forecast: WeatherForecast, for location: String) {
        queue.async {
            self.forecastCache[location] = (forecast, Date())
        }
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        queue.async {
            self.weatherCache.removeAll()
            self.forecastCache.removeAll()
        }
    }
    
    func clearExpiredCache() {
        queue.async {
            let now = Date()
            self.weatherCache = self.weatherCache.filter { _, value in
                now.timeIntervalSince(value.timestamp) < self.cacheExpiration
            }
            self.forecastCache = self.forecastCache.filter { _, value in
                now.timeIntervalSince(value.timestamp) < self.cacheExpiration
            }
        }
    }
} 