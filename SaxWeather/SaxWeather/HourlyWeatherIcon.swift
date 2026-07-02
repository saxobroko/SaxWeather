
import SwiftUI

struct HourlyWeatherIcon: View {
    let weatherCode: Int

    var body: some View {
        ConditionIcon(weatherCode: weatherCode, size: 30)
            .aspectRatio(contentMode: .fit)
    }
}
