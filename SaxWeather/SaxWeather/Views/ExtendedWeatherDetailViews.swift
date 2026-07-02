//
//  ExtendedWeatherDetailViews.swift
//  SaxWeather
//
//  Created on 13/01/2026
//

import SwiftUI

// MARK: - Air Quality Detail View
struct AirQualityDetailView: View {
    let data: AirQualityData
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Main AQI Display
                    VStack(spacing: 16) {
                        Text("\(data.aqi)")
                            .font(.system(size: 72, weight: .bold))
                            .foregroundColor(data.category.color)
                        
                        Text(data.category.rawValue)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(data.category.healthAdvice)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .styledCard()
                    .padding(.horizontal)
                    
                    // Pollutant Levels
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pollutant Levels")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            if let pm25 = data.pollutants?.pm25 {
                                PollutantRow(name: "PM2.5", value: pm25, unit: "µg/m³", info: "Fine particulate matter")
                            }
                            if let pm10 = data.pollutants?.pm10 {
                                PollutantRow(name: "PM10", value: pm10, unit: "µg/m³", info: "Coarse particulate matter")
                            }
                            if let o3 = data.pollutants?.o3 {
                                PollutantRow(name: "O₃", value: o3, unit: "µg/m³", info: "Ozone")
                            }
                            if let no2 = data.pollutants?.no2 {
                                PollutantRow(name: "NO₂", value: no2, unit: "µg/m³", info: "Nitrogen dioxide")
                            }
                            if let so2 = data.pollutants?.so2 {
                                PollutantRow(name: "SO₂", value: so2, unit: "µg/m³", info: "Sulfur dioxide")
                            }
                            if let co = data.pollutants?.co {
                                PollutantRow(name: "CO", value: co, unit: "µg/m³", info: "Carbon monoxide")
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Health Recommendations by Category
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Health Recommendations")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            HealthRecommendationCard(
                                category: "General Public",
                                recommendation: getGeneralRecommendation(for: data.aqi),
                                color: data.category.color
                            )
                            
                            HealthRecommendationCard(
                                category: "Sensitive Groups",
                                recommendation: getSensitiveRecommendation(for: data.aqi),
                                color: data.category.color
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // AQI Scale Reference
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AQI Scale Reference")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            AQIScaleReferenceRow(range: "0-50", category: "Good", color: .green)
                            AQIScaleReferenceRow(range: "51-100", category: "Moderate", color: .yellow)
                            AQIScaleReferenceRow(range: "101-150", category: "Unhealthy for Sensitive Groups", color: .orange)
                            AQIScaleReferenceRow(range: "151-200", category: "Unhealthy", color: .red)
                            AQIScaleReferenceRow(range: "201-300", category: "Very Unhealthy", color: .purple)
                            AQIScaleReferenceRow(range: "301-500", category: "Hazardous", color: .brown)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Air Quality")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #endif
        }
    }
    
    private func getGeneralRecommendation(for aqi: Int) -> String {
        switch aqi {
        case 0...50:
            return "Air quality is satisfactory. Enjoy outdoor activities."
        case 51...100:
            return "Air quality is acceptable. Unusually sensitive people should consider limiting prolonged outdoor exertion."
        case 101...150:
            return "Members of sensitive groups may experience health effects. The general public is less likely to be affected."
        case 151...200:
            return "Some members of the general public may experience health effects. Sensitive groups should avoid prolonged outdoor exertion."
        case 201...300:
            return "Health alert: The risk of health effects is increased for everyone. Avoid prolonged outdoor exertion."
        default:
            return "Health warning: Everyone should avoid all outdoor exertion. Stay indoors with windows closed."
        }
    }
    
    private func getSensitiveRecommendation(for aqi: Int) -> String {
        switch aqi {
        case 0...50:
            return "No precautions needed. Safe for all activities."
        case 51...100:
            return "Consider reducing prolonged or heavy outdoor exertion if you experience symptoms."
        case 101...150:
            return "Reduce prolonged or heavy outdoor exertion. Take more breaks and do less intense activities."
        case 151...200:
            return "Avoid prolonged or heavy outdoor exertion. Move activities indoors or reschedule."
        case 201...300:
            return "Avoid all outdoor exertion. Stay indoors and keep activity levels low."
        default:
            return "Remain indoors with windows closed. Use air purifiers if available."
        }
    }
}

// MARK: - UV Index Detail View
struct UVIndexDetailView: View {
    let data: UVIndexData
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Main UV Display
                    VStack(spacing: 16) {
                        Text("\(data.index)")
                            .font(.system(size: 72, weight: .bold))
                            .foregroundColor(data.category.color)
                        
                        Text(data.category.rawValue)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.secondary)
                            Text("Time to burn: \(data.timeToBurn)")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .styledCard()
                    .padding(.horizontal)
                    
                    // Time to Burn by Skin Type
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Time to Burn by Skin Type")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            TimeToBurnRow(skinType: "I (Very Fair)", time: calculateBurnTime(uvIndex: data.index, skinType: 1), description: "Always burns, never tans")
                            TimeToBurnRow(skinType: "II (Fair)", time: calculateBurnTime(uvIndex: data.index, skinType: 2), description: "Usually burns, tans minimally")
                            TimeToBurnRow(skinType: "III (Medium)", time: calculateBurnTime(uvIndex: data.index, skinType: 3), description: "Sometimes burns, gradually tans")
                            TimeToBurnRow(skinType: "IV (Olive)", time: calculateBurnTime(uvIndex: data.index, skinType: 4), description: "Rarely burns, tans easily")
                            TimeToBurnRow(skinType: "V (Brown)", time: calculateBurnTime(uvIndex: data.index, skinType: 5), description: "Very rarely burns, tans darkly")
                            TimeToBurnRow(skinType: "VI (Dark Brown/Black)", time: calculateBurnTime(uvIndex: data.index, skinType: 6), description: "Never burns, deeply pigmented")
                        }
                        .padding(.horizontal)
                    }
                    
                    // Protection Recommendations
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Protection Recommendations")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ProtectionCard(
                                icon: "sun.max.fill",
                                title: "Sunscreen",
                                recommendation: getSunscreenRecommendation(for: data.index),
                                color: data.category.color
                            )
                            
                            ProtectionCard(
                                icon: "eyeglasses",
                                title: "Eye Protection",
                                recommendation: getEyeProtectionRecommendation(for: data.index),
                                color: data.category.color
                            )
                            
                            ProtectionCard(
                                icon: "tshirt.fill",
                                title: "Clothing",
                                recommendation: getClothingRecommendation(for: data.index),
                                color: data.category.color
                            )
                            
                            ProtectionCard(
                                icon: "clock.fill",
                                title: "Timing",
                                recommendation: "Peak UV hours: \(data.peakHours). Seek shade during these times.",
                                color: data.category.color
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // UV Index Scale
                    VStack(alignment: .leading, spacing: 16) {
                        Text("UV Index Scale")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            UVScaleReferenceRow(range: "0-2", category: "Low", color: .green, description: "Minimal protection needed")
                            UVScaleReferenceRow(range: "3-5", category: "Moderate", color: .yellow, description: "Protection recommended")
                            UVScaleReferenceRow(range: "6-7", category: "High", color: .orange, description: "Protection essential")
                            UVScaleReferenceRow(range: "8-10", category: "Very High", color: .red, description: "Extra protection required")
                            UVScaleReferenceRow(range: "11+", category: "Extreme", color: .purple, description: "Maximum protection needed")
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("UV Index")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #endif
        }
    }
    
    private func calculateBurnTime(uvIndex: Int, skinType: Int) -> String {
        // Approximate burn time calculation based on UV index and skin type
        let baseMinutes: [Int] = [67, 100, 150, 200, 300, 400] // Minutes for UV index 1
        
        guard skinType >= 1 && skinType <= 6, uvIndex > 0 else {
            return "N/A"
        }
        
        let minutes = baseMinutes[skinType - 1] / uvIndex
        
        if minutes < 10 {
            return "< 10 min"
        } else if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
    
    private func getSunscreenRecommendation(for uvIndex: Int) -> String {
        switch uvIndex {
        case 0...2:
            return "SPF 15+ recommended for extended outdoor exposure."
        case 3...5:
            return "SPF 30+ recommended. Reapply every 2 hours."
        case 6...7:
            return "SPF 50+ essential. Reapply every 1.5 hours and after swimming."
        case 8...10:
            return "SPF 50+ water-resistant sunscreen required. Reapply every hour."
        default:
            return "SPF 50+ broad-spectrum, water-resistant. Reapply every 30 minutes."
        }
    }
    
    private func getEyeProtectionRecommendation(for uvIndex: Int) -> String {
        switch uvIndex {
        case 0...2:
            return "Sunglasses optional for comfort."
        case 3...5:
            return "UV-blocking sunglasses recommended."
        case 6...7:
            return "UV-blocking sunglasses essential. Consider a wide-brimmed hat."
        default:
            return "UV-blocking sunglasses and wide-brimmed hat mandatory."
        }
    }
    
    private func getClothingRecommendation(for uvIndex: Int) -> String {
        switch uvIndex {
        case 0...2:
            return "Normal clothing is adequate."
        case 3...5:
            return "Wear light-colored, loose-fitting clothing."
        case 6...7:
            return "Wear protective clothing. Consider UPF-rated fabrics."
        default:
            return "Wear UPF 50+ clothing, long sleeves, and pants. Minimize exposed skin."
        }
    }
}

// MARK: - Sun/Moon Detail View
struct SunMoonDetailView: View {
    let data: SunMoonData
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private var dayLength: String {
        let interval = data.sunset.timeIntervalSince(data.sunrise)
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }
    
    private var timeUntilSunrise: String? {
        if data.sunrise > Date() {
            let interval = data.sunrise.timeIntervalSince(Date())
            let hours = Int(interval) / 3600
            let minutes = Int(interval) % 3600 / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
        return nil
    }
    
    private var timeUntilSunset: String? {
        if data.sunset > Date() {
            let interval = data.sunset.timeIntervalSince(Date())
            let hours = Int(interval) / 3600
            let minutes = Int(interval) % 3600 / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
        return nil
    }
    
    private var goldenHourMorning: (start: Date, end: Date) {
        // Golden hour: ~1 hour before sunrise to sunrise
        let start = data.sunrise.addingTimeInterval(-3600)
        return (start, data.sunrise)
    }
    
    private var goldenHourEvening: (start: Date, end: Date) {
        // Golden hour: sunset to ~1 hour after sunset
        let end = data.sunset.addingTimeInterval(3600)
        return (data.sunset, end)
    }
    
    private var blueHourMorning: (start: Date, end: Date) {
        // Blue hour: ~40 min before sunrise to ~20 min before sunrise
        let start = data.sunrise.addingTimeInterval(-2400)
        let end = data.sunrise.addingTimeInterval(-1200)
        return (start, end)
    }
    
    private var blueHourEvening: (start: Date, end: Date) {
        // Blue hour: ~20 min after sunset to ~40 min after sunset
        let start = data.sunset.addingTimeInterval(1200)
        let end = data.sunset.addingTimeInterval(2400)
        return (start, end)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Sun Times
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sun Times")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            SunTimeCard(
                                icon: "sunrise.fill",
                                title: "Sunrise",
                                time: data.sunrise,
                                countdown: timeUntilSunrise,
                                color: .orange
                            )
                            
                            SunTimeCard(
                                icon: "sunset.fill",
                                title: "Sunset",
                                time: data.sunset,
                                countdown: timeUntilSunset,
                                color: .purple
                            )
                            
                            InfoCard(
                                icon: "sun.max.fill",
                                title: "Day Length",
                                value: dayLength,
                                color: .yellow
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Photography Times
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Photography Times")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            PhotoTimeCard(
                                title: "Morning Golden Hour",
                                description: "Best for warm, soft lighting",
                                startTime: goldenHourMorning.start,
                                endTime: goldenHourMorning.end,
                                color: .orange
                            )
                            
                            PhotoTimeCard(
                                title: "Morning Blue Hour",
                                description: "Ideal for moody, blue-toned shots",
                                startTime: blueHourMorning.start,
                                endTime: blueHourMorning.end,
                                color: .blue
                            )
                            
                            PhotoTimeCard(
                                title: "Evening Golden Hour",
                                description: "Perfect for portraits and landscapes",
                                startTime: goldenHourEvening.start,
                                endTime: goldenHourEvening.end,
                                color: .orange
                            )
                            
                            PhotoTimeCard(
                                title: "Evening Blue Hour",
                                description: "Great for cityscapes and night photography",
                                startTime: blueHourEvening.start,
                                endTime: blueHourEvening.end,
                                color: .blue
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Moon Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Moon Information")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            MoonPhaseCard(moonPhase: data.moonPhase)
                            
                            if let moonrise = data.moonrise {
                                InfoCard(
                                    icon: "moonrise.fill",
                                    title: "Moonrise",
                                    value: moonrise.formatted(date: .omitted, time: .shortened),
                                    color: .indigo
                                )
                            }
                            
                            if let moonset = data.moonset {
                                InfoCard(
                                    icon: "moonset.fill",
                                    title: "Moonset",
                                    value: moonset.formatted(date: .omitted, time: .shortened),
                                    color: .indigo
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Sun & Moon")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #endif
        }
    }
}

// MARK: - Precipitation Detail View
struct PrecipitationDetailView: View {
    let data: [HourlyPrecipitation]
    var timeZoneIdentifier: String? = nil
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var unit: UnitSystem {
        UnitSystem.from(rawValue: unitSystem)
    }

    private var hourLabelFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        if let timeZoneIdentifier,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            formatter.timeZone = timeZone
        }
        return formatter
    }
    
    private var peakPrecipitation: HourlyPrecipitation? {
        data.max(by: { $0.probability < $1.probability })
    }
    
    private var totalPrecipitation: Double {
        data.reduce(0) { $0 + $1.amount }
    }
    
    private var averageProbability: Int {
        guard !data.isEmpty else { return 0 }
        return data.reduce(0) { $0 + $1.probability } / data.count
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Summary
                    VStack(alignment: .leading, spacing: 16) {
                        Text("24-Hour Summary")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            if let peak = peakPrecipitation {
                                InfoCard(
                                    icon: "cloud.rain.fill",
                                    title: "Peak Precipitation",
                                    value: "\(peak.probability)% at \(hourLabelFormatter.string(from: peak.hour))",
                                    color: .blue
                                )
                            }
                            
                            InfoCard(
                                icon: "drop.fill",
                                title: "Total Expected",
                                value: UnitConverter.formatPrecipitation(totalPrecipitation, unit: unit),
                                color: .cyan
                            )
                            
                            InfoCard(
                                icon: "percent",
                                title: "Average Probability",
                                value: "\(averageProbability)%",
                                color: .indigo
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Hourly Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Hourly Breakdown")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            ForEach(data.prefix(24), id: \.hour) { hour in
                                HourlyPrecipRow(
                                    data: hour,
                                    timeZoneIdentifier: timeZoneIdentifier
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Precipitation")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #endif
        }
    }
}

// MARK: - Supporting Views

struct PollutantRow: View {
    let name: String
    let value: Double
    let unit: String
    let info: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                Text(info)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "%.1f", value))
                .font(.system(size: 18, weight: .bold))
            +
            Text(" \(unit)")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct HealthRecommendationCard: View {
    let category: String
    let recommendation: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(color)
                Text(category)
                    .font(.system(size: 16, weight: .semibold))
            }
            
            Text(recommendation)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct AQIScaleReferenceRow: View {
    let range: String
    let category: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(range)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 60, alignment: .leading)
            
            Text(category)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct TimeToBurnRow: View {
    let skinType: String
    let time: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Type \(skinType)")
                    .font(.system(size: 15, weight: .semibold))
                
                Spacer()
                
                Text(time)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.red)
            }
            
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ProtectionCard: View {
    let icon: String
    let title: String
    let recommendation: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(recommendation)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct UVScaleReferenceRow: View {
    let range: String
    let category: String
    let color: Color
    let description: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(range)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 50, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category)
                    .font(.system(size: 14, weight: .medium))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

struct SunTimeCard: View {
    let icon: String
    let title: String
    let time: Date
    let countdown: String?
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                
                if let countdown = countdown {
                    Text("in \(countdown)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(time.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 18, weight: .bold))
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 32)
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PhotoTimeCard: View {
    let title: String
    let description: String
    let startTime: Date
    let endTime: Date
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("Start:")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(startTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 14, weight: .medium))
                }
                
                HStack(spacing: 4) {
                    Text("End:")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(endTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 14, weight: .medium))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct MoonPhaseCard: View {
    let moonPhase: SunMoonData.MoonPhase
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: moonPhase.icon)
                .font(.system(size: 48))
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(moonPhase.rawValue)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(moonPhase.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct HourlyPrecipRow: View {
    let data: HourlyPrecipitation
    var timeZoneIdentifier: String? = nil
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"

    private var unit: UnitSystem {
        UnitSystem.from(rawValue: unitSystem)
    }
    
    private var hourLabelFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        if let timeZoneIdentifier,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            formatter.timeZone = timeZone
        }
        return formatter
    }
    
    private var intensityColor: Color {
        switch data.probability {
        case 0...20: return .green
        case 21...50: return .yellow
        case 51...70: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        HStack {
            Text(hourLabelFormatter.string(from: data.hour))
                .font(.system(size: 14, weight: .medium))
                .frame(width: 70, alignment: .leading)
            
            // Probability bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 20)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(intensityColor)
                        .frame(width: geometry.size.width * CGFloat(data.probability) / 100, height: 20)
                        .cornerRadius(4)
                    
                    Text("\(data.probability)%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.leading, 4)
                }
            }
            .frame(height: 20)
            
            Text(UnitConverter.formatPrecipitation(data.amount, unit: unit))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}
