
import SwiftUI

struct WeatherAnimationView: View {
    let weather: Weather?
    let forecast: WeatherForecast?

    var body: some View {
        ConditionIcon(
            condition: weather?.condition ?? "Clear",
            isNight: determineIfNight(),
            size: 150
        )
        .frame(width: 150, height: 150)
    }

    private func determineIfNight() -> Bool {
        // Check if we have sunrise/sunset data in the forecast
        if let daily = forecast?.daily.first,
           let sunrise = daily.sunrise,
           let sunset = daily.sunset {
            let now = Date()
            return now < sunrise || now > sunset
        } else {
            // Fallback to time-based detection
            let hour = Calendar.current.component(.hour, from: Date())
            return hour < 6 || hour > 18
        }
    }
}
