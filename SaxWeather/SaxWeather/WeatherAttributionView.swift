//
//  WeatherAttributionView.swift
//  SaxWeather
//
//  Created by GitHub Copilot on 2026-01-09.
//

import SwiftUI

/// Displays attribution for the currently active weather data source
/// Satisfies legal requirements for WeatherKit, Open-Meteo, OpenWeatherMap, Weather Underground, BOM, and MET.no
struct WeatherAttributionView: View {
    let dataSource: String
    let stationID: String?
    let useForecastSource: Bool // Use forecast source instead of current weather source
    let useAlertSource: Bool // Use alert source (for Alerts screen)
    let usePrecipitationSource: Bool // Precipitation forecast on Alerts screen
    
    init(dataSource: String, stationID: String? = nil, useForecastSource: Bool = false, useAlertSource: Bool = false, usePrecipitationSource: Bool = false) {
        self.dataSource = dataSource
        self.stationID = stationID
        self.useForecastSource = useForecastSource
        self.useAlertSource = useAlertSource
        self.usePrecipitationSource = usePrecipitationSource
    }
    
    var body: some View {
        if let attribution = attributionInfo {
            Link(destination: attribution.url) {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                    Text(attribution.text)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .opacity(0.7)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
    
    /// Returns the appropriate attribution text and URL based on the active data source
    private var attributionInfo: (text: String, url: URL)? {
        switch dataSource.lowercased() {
        case "weatherkit":
            if useAlertSource {
                return (
                    "Alerts from Apple WeatherKit",
                    URL(string: "https://weather.apple.com")!
                )
            } else {
                return (
                    "Weather data from Apple Weather",
                    URL(string: "https://weather.apple.com")!
                )
            }
            
        case "openmeteo":
            if usePrecipitationSource {
                return (
                    "Precipitation forecast by Open-Meteo.com",
                    URL(string: "https://open-meteo.com/")!
                )
            }
            return (
                "Weather data by Open-Meteo.com",
                URL(string: "https://open-meteo.com/")!
            )
            
        case "weatherunderground":
            let stationText = stationID.map { " \($0)" } ?? ""
            return (
                "Data from WU Station\(stationText)",
                URL(string: "https://www.wunderground.com/")!
            )
            
        case "openweathermap":
            return (
                "Weather data from OpenWeatherMap",
                URL(string: "https://openweathermap.org/")!
            )
            
        case "bom":
            return (
                "Alerts from Bureau of Meteorology",
                URL(string: "http://www.bom.gov.au/")!
            )
            
        case "metno":
            return nil

        case "none":
            return nil
            
        default:
            // No attribution needed for unknown sources
            return nil
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        Text("Main Weather View")
            .font(.title)
        Spacer()
        
        VStack(spacing: 16) {
            WeatherAttributionView(dataSource: "weatherkit", stationID: nil)
            Divider()
            WeatherAttributionView(dataSource: "openmeteo", stationID: nil)
            Divider()
            WeatherAttributionView(dataSource: "weatherunderground", stationID: "KSUNBU78")
            Divider()
            WeatherAttributionView(dataSource: "openweathermap", stationID: nil)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding()
    }
}
