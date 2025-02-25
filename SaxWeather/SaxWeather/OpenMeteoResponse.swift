//
//  OpenMeteoResponse.swift
//  SaxWeather
//
//  Created by Saxon on 24/2/2025.
//


//
//  OpenMeteoService.swift
//  SaxWeather
//
//  Created by Saxo_Broko on 2025-02-24 07:58:30
//

import Foundation

struct OpenMeteoResponse: Codable {
    let current: OpenMeteoCurrent
    let daily: OpenMeteoDaily
    
    struct OpenMeteoCurrent: Codable {
        let temperature: Double
        let relativeHumidity: Int
        let apparentTemperature: Double
        let precipitation: Double
        let windSpeed: Double
        let windGusts: Double
        let pressure: Double
        let cloudCover: Int
        let uvIndex: Int
        
        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case relativeHumidity = "relative_humidity_2m"
            case apparentTemperature = "apparent_temperature"
            case precipitation = "precipitation"
            case windSpeed = "wind_speed_10m"
            case windGusts = "wind_gusts_10m"
            case pressure = "pressure_msl"
            case cloudCover = "cloud_cover"
            case uvIndex = "uv_index"
        }
    }
    
    struct OpenMeteoDaily: Codable {
        let temperatureMax: [Double]
        let temperatureMin: [Double]
        
        enum CodingKeys: String, CodingKey {
            case temperatureMax = "temperature_2m_max"
            case temperatureMin = "temperature_2m_min"
        }
    }
}

func fetchOpenMeteoWeather(latitude: String, longitude: String) async throws -> (OWMCurrent?, OWMDaily?) {
    let urlString = "https://api.open-meteo.com/v1/forecast?" +
        "latitude=\(latitude)" +
        "&longitude=\(longitude)" +
        "&current=temperature_2m,relative_humidity_2m,apparent_temperature," +
        "precipitation,wind_speed_10m,wind_gusts_10m,pressure_msl,cloud_cover,uv_index" +
        "&daily=temperature_2m_max,temperature_2m_min" +
        "&timezone=auto"
    
    guard let url = URL(string: urlString) else {
        throw WeatherError.invalidURL
    }
    
    let request = URLRequest(url: url)
    
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
        
        let openMeteoResponse = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        
        // Convert OpenMeteo response to our existing format
        let owmCurrent = OWMCurrent(
            temp: openMeteoResponse.current.temperature,
            feels_like: openMeteoResponse.current.apparentTemperature,
            humidity: Double(openMeteoResponse.current.relativeHumidity),
            dew_point: calculateDewPoint(
                temp: openMeteoResponse.current.temperature,
                humidity: Double(openMeteoResponse.current.relativeHumidity)
            ),
            pressure: openMeteoResponse.current.pressure,
            wind_speed: openMeteoResponse.current.windSpeed,
            wind_gust: openMeteoResponse.current.windGusts,
            uvi: openMeteoResponse.current.uvIndex,
            clouds: Double(openMeteoResponse.current.cloudCover)
        )
        
        // Get daily temperature data
        let owmDaily = OWMDaily(temp: OWMDaily.OWMDailyTemp(
            min: openMeteoResponse.daily.temperatureMin.first ?? owmCurrent.temp,
            max: openMeteoResponse.daily.temperatureMax.first ?? owmCurrent.temp
        ))
        
        return (owmCurrent, owmDaily)
    } catch {
        print("❌ OpenMeteo Error:", error.localizedDescription)
        print("❌ Error Details:", error)
        throw WeatherError.apiError(error.localizedDescription)
    }
}

private func calculateDewPoint(temp: Double, humidity: Double) -> Double {
    let a = 17.27
    let b = 237.7
    
    let alpha = ((a * temp) / (b + temp)) + log(humidity/100.0)
    let dewPoint = (b * alpha) / (a - alpha)
    return dewPoint
}
