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
    case noData
}
