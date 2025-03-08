//
//  OpenMeteoService.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-26 14:11:18
//

import Foundation

actor OpenMeteoService {
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    func fetchWeather(latitude: Double, longitude: Double, unitSystem: String = "Metric") async throws -> OpenMeteoResponse {
        let urlString = "https://api.open-meteo.com/v1/forecast?" +
            "latitude=\(latitude)" +
            "&longitude=\(longitude)" +
            "&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,wind_speed_10m,wind_gusts_10m,pressure_msl,cloud_cover,uv_index" +
            "&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,weather_code,wind_speed_10m_max,wind_direction_10m_dominant,relative_humidity_2m_max,pressure_msl_max,uv_index_max,sunrise,sunset" +
            "&timezone=UTC"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        #if DEBUG
        print("📡 Fetching weather from OpenMeteo: \(url.absoluteString)")
        #endif
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WeatherError.apiError("Invalid response")
            }
            
            #if DEBUG
            print("📡 OpenMeteo Response Status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 OpenMeteo Response Body:")
                print(responseString)
            }
            #endif
            
            guard httpResponse.statusCode == 200 else {
                throw WeatherError.apiError("Status code: \(httpResponse.statusCode)")
            }
            
            return try jsonDecoder.decode(OpenMeteoResponse.self, from: data)
        } catch {
            #if DEBUG
            print("❌ OpenMeteo Error:", error.localizedDescription)
            #endif
            throw WeatherError.apiError(error.localizedDescription)
        }
    }
}
