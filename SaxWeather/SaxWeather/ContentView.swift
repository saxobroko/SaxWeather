import SwiftUI
import CoreLocation

// MARK: - Content View
struct ContentView: View {
    @StateObject private var weatherService = WeatherService()
    @State private var showSettings = false
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                BackgroundView(condition: weatherService.weather?.condition ?? "default")
                
                ScrollView {
                    VStack {
                        if let weather = weatherService.weather, weather.hasData {
                            WeatherMainView(weather: weather)
                            WeatherDetailsView(weather: weather)
                        } else {
                            Text("Loading weather data...")
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Button {
                            Task {
                                isRefreshing = true
                                await weatherService.fetchWeather()
                                isRefreshing = false
                            }
                        } label: {
                            HStack {
                                if isRefreshing {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text("Refresh")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding()
                        .disabled(isRefreshing)
                    }
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                                .foregroundColor(.white)
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView(weatherService: weatherService)
                }
            }
            .onAppear {
                Task {
                    await weatherService.fetchWeather()
                }
            }
        }
    }
}

// MARK: - Background View
struct BackgroundView: View {
    let condition: String
    
    var body: some View {
        GeometryReader { geometry in
            Image(backgroundImage(for: condition))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay(
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                )
        }
        .ignoresSafeArea()
    }
    
    private func backgroundImage(for condition: String) -> String {
        switch condition.lowercased() {
        case "sunny":
            return "weather_background_sunny"
        case "rainy":
            return "weather_background_rainy"
        case "windy":
            return "weather_background_windy"
        case "snowy":
            return "weather_background_snowy"
        case "thunder":
            return "weather_background_thunder"
        default:
            return "weather_background_default"
        }
    }
}

// MARK: - Weather Main View
struct WeatherMainView: View {
    let weather: Weather
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    
    private var temperatureUnit: String {
        unitSystem == "Metric" ? "°C" : "°F"
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if let temperature = weather.temperature {
                Text("\(temperature, specifier: "%.1f")\(temperatureUnit)")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(.white)
            }
            
            if let feelsLike = weather.feelsLike {
                Text("Feels like \(feelsLike, specifier: "%.1f")\(temperatureUnit)")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            
            HStack {
                if let high = weather.high {
                    Text("H: \(high, specifier: "%.1f")\(temperatureUnit)")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                if let low = weather.low {
                    Text("L: \(low, specifier: "%.1f")\(temperatureUnit)")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.vertical, 50)
    }
}

// MARK: - Weather Details View
struct WeatherDetailsView: View {
    let weather: Weather
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    
    private var temperatureUnit: String {
        unitSystem == "Metric" ? "°C" : "°F"
    }
    
    private var speedUnit: String {
        unitSystem == "Metric" ? "km/h" : "mph"
    }
    
    private var pressureUnit: String {
        unitSystem == "Metric" ? "hPa" : "inHg"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(weatherMetrics, id: \.title) { metric in
                if let value = metric.value {
                    WeatherRowView(title: metric.title, value: value)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.8))
                .shadow(radius: 5)
        )
        .padding(.horizontal)
    }
    
    private var weatherMetrics: [(title: String, value: String?)] {
        [
            ("Humidity", weather.humidity.map { "\($0)%" }),
            ("Dew Point", weather.dewPoint.map { String(format: "%.1f%@", $0, temperatureUnit) }),
            ("Pressure", weather.pressure.map { String(format: "%.1f %@", $0, pressureUnit) }),
            ("Wind Speed", weather.windSpeed.map { String(format: "%.1f %@", $0, speedUnit) }),
            ("Wind Gust", weather.windGust.map { String(format: "%.1f %@", $0, speedUnit) }),
            ("UV Index", weather.uvIndex.map { "\($0)" }),
            ("Solar Radiation", weather.solarRadiation.map { "\($0) W/m²" })
        ]
    }
}

// MARK: - Weather Row View
struct WeatherRowView: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.blue)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.black)
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
