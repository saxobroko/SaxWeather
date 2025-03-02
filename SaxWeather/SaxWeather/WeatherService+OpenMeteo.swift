//
//  WeatherService+OpenMeteo.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-26 14:42:31
//

import Foundation
import CoreLocation

extension WeatherService {
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
}
