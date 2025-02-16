import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var weatherService = WeatherService()
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                BackgroundView(condition: weatherService.weather?.condition ?? "default")
                
                VStack {
                    Spacer()
                    
                    if let weather = weatherService.weather, weather.hasData {
                        VStack(spacing: 8) {
                            if let temperature = weather.temperature {
                                Text("\(temperature, specifier: "%.1f")°")
                                    .font(.system(size: 80, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            if let feelsLike = weather.feelsLike {
                                Text("Feels like \(feelsLike, specifier: "%.1f")°")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            HStack {
                                if let high = weather.high {
                                    Text("H: \(high, specifier: "%.1f")°")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                if let low = weather.low {
                                    Text("L: \(low, specifier: "%.1f")°")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.top, 50)
                        .padding(.bottom, 50)
                        
                        VStack(spacing: 16) {
                            if let humidity = weather.humidity {
                                WeatherRowView(title: "Humidity", value: "\(humidity)%")
                            }
                            if let dewPoint = weather.dewPoint {
                                WeatherRowView(title: "Dew Point", value: "\(dewPoint)°C")
                            }
                            if let pressure = weather.pressure {
                                WeatherRowView(title: "Pressure", value: "\(pressure) hPa")
                            }
                            if let windSpeed = weather.windSpeed {
                                WeatherRowView(title: "Wind Speed", value: "\(windSpeed) km/h")
                            }
                            if let windGust = weather.windGust {
                                WeatherRowView(title: "Wind Gust", value: "\(windGust) km/h")
                            }
                            if let uvIndex = weather.uvIndex {
                                WeatherRowView(title: "UV Index", value: "\(uvIndex)")
                            }
                            if let solarRadiation = weather.solarRadiation {
                                WeatherRowView(title: "Solar Radiation", value: "\(solarRadiation) W/m²")
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.8))
                                .shadow(radius: 5)
                        )
                        .padding(.horizontal)
                    } else {
                        Text("Fetching weather data...")
                            .foregroundColor(.white)
                            .padding(.top, 50)
                            .padding(.bottom, 50)
                        
                        Button(action: {
                            showSettings = true
                        }) {
                            Text("Set API Keys")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.bottom, 50)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        weatherService.fetchWeather()
                    }) {
                        Text("Refresh Weather")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.bottom, 50)
                    }
                }
                .navigationTitle("")
                .navigationBarHidden(false)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "line.horizontal.3")
                                .imageScale(.large)
                                .foregroundColor(.white)
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView(weatherService: weatherService)
                }
            }
            .onAppear {
                weatherService.fetchWeather() // Fetch data when the view appears
            }
        }
    }
}

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
        .padding()
    }
}

struct BackgroundView: View {
    var condition: String
    
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
    }
    
    func backgroundImage(for condition: String) -> String {
        switch condition {
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
