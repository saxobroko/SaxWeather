//
//  WeatherError.swift
//  
//
//  Created by Saxon on 16/2/2025.
//


//
//  WeatherError.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-16 06:39:04
//

import Foundation

enum WeatherError: Error {
    case invalidURL
    case noData
    case networkError(String)
    case invalidAPIKey
    case apiError(String)
}