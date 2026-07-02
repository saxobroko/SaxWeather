
import SwiftUI

struct WeatherConditionView: View {
    let condition: String

    var body: some View {
        ConditionIcon(condition: condition, size: 150)
            .frame(height: 150)
    }
}