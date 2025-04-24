//
//  WeatherError.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-25 07:58:55
//

import Foundation

enum WeatherError: Error {
    case invalidURL
    case invalidResponse
    case missingCredentials
    case decodingError
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .missingCredentials:
            return "Missing API credentials"
        case .decodingError:
            return "Error decoding response"
        }
    }
}
