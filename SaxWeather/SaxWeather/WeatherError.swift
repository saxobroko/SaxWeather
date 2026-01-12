//
//  WeatherError.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-25 04:46:29
//

import Foundation

enum WeatherError: Error {
    case invalidURL
    case invalidResponse
    case invalidAPIKey
    case apiError(String)
    case decodingError(String)
    case noData
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
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
