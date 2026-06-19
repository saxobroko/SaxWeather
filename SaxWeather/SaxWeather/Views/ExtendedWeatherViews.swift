//
//  ExtendedWeatherViews.swift
//  SaxWeather
//
//  Created on 13/01/2026
//

import SwiftUI

// MARK: - Air Quality Card
struct AirQualityCardView: View {
    let data: AirQualityData
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
            #if canImport(UIKit)
            HapticFeedbackHelper.shared.light()
            #endif
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "aqi.medium")
                        .font(.system(size: 20))
                        .foregroundColor(data.category.color)
                    
                    Text("Air Quality")
                        .font(.system(size: 17, weight: .semibold))
                    
                    Spacer()
                    
                    Text(data.category.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                // AQI Number with color indicator
                HStack(alignment: .bottom, spacing: 8) {
                    Text("\(data.aqi)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(data.category.color)
                    
                    Text("AQI")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
                
                // Color scale
                AQIScaleView(currentAQI: data.aqi)
                
                // Health advice
                Text(data.category.healthAdvice)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Tap hint
                Text("Tap for detailed health recommendations")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
                    .italic()
            }
            .padding(16)
            .glassCardBackground(colorScheme: colorScheme)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            AirQualityDetailView(data: data)
        }
    }
}

// MARK: - AQI Color Scale
struct AQIScaleView: View {
    let currentAQI: Int
    
    private let aqiRanges: [(range: ClosedRange<Int>, color: Color)] = [
        (0...50, .green),
        (51...100, .yellow),
        (101...150, .orange),
        (151...200, .red),
        (201...300, .purple),
        (301...500, .brown)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Color gradient bar
                HStack(spacing: 0) {
                    ForEach(aqiRanges, id: \.range.lowerBound) { item in
                        Rectangle()
                            .fill(item.color)
                            .frame(width: geometry.size.width / CGFloat(aqiRanges.count))
                    }
                }
                .frame(height: 8)
                .cornerRadius(4)
                
                // Current position indicator
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(colorFor(aqi: currentAQI), lineWidth: 3)
                    )
                    .offset(x: offsetFor(aqi: currentAQI, in: geometry.size.width))
            }
        }
        .frame(height: 16)
    }
    
    private func colorFor(aqi: Int) -> Color {
        aqiRanges.first(where: { $0.range.contains(aqi) })?.color ?? .gray
    }
    
    private func offsetFor(aqi: Int, in width: CGFloat) -> CGFloat {
        let clampedAQI = min(500, max(0, aqi))
        let percentage = CGFloat(clampedAQI) / 500.0
        return (width * percentage) - 8 // -8 to center the indicator
    }
}

// MARK: - UV Index Card
struct UVIndexCardView: View {
    let data: UVIndexData
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
            #if canImport(UIKit)
            HapticFeedbackHelper.shared.light()
            #endif
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 20))
                        .foregroundColor(data.category.color)
                    
                    Text("UV Index")
                        .font(.system(size: 17, weight: .semibold))
                    
                    Spacer()
                    
                    Text(data.category.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                // UV Number
                HStack(alignment: .bottom, spacing: 8) {
                    Text("\(data.index)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(data.category.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Time to burn")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(data.timeToBurn)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.bottom, 8)
                }
                
                Divider()
                
                // Recommendations
                VStack(alignment: .leading, spacing: 8) {
                    RecommendationRow(icon: "figure.walk", text: data.sunscreenRecommendation)
                    RecommendationRow(icon: "clock.fill", text: "Peak hours: \(data.peakHours)")
                }
                
                // Tap hint
                Text("Tap for burn times by skin type")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
                    .italic()
            }
            .padding(16)
            .glassCardBackground(colorScheme: colorScheme)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            UVIndexDetailView(data: data)
        }
    }
}

// MARK: - Pollen Card
struct PollenCardView: View {
    let data: PollenData
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
                Text("Pollen Forecast")
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
            }
            
            // Pollen levels
            VStack(spacing: 10) {
                if let tree = data.tree {
                    PollenLevelRow(type: "Tree", level: tree)
                }
                if let grass = data.grass {
                    PollenLevelRow(type: "Grass", level: grass)
                }
                if let weed = data.weed {
                    PollenLevelRow(type: "Weed", level: weed)
                }
            }
            
            // Warning if applicable
            if let warning = data.warning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(warning)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .glassCardBackground(colorScheme: colorScheme)
    }
}

struct PollenLevelRow: View {
    let type: String
    let level: PollenData.PollenLevel
    
    var body: some View {
        HStack {
            Text(type)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 60, alignment: .leading)
            
            // Level indicator
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 8)
                
                // Fill
                GeometryReader { geometry in
                    Capsule()
                        .fill(level.color)
                        .frame(width: geometry.size.width * CGFloat(level.rawValue) / 4.0)
                }
                .frame(height: 8)
            }
            
            Text(level.description)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(level.color)
                .frame(width: 70, alignment: .trailing)
        }
    }
}

// MARK: - Sun/Moon Card
struct SunMoonCardView: View {
    let data: SunMoonData
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
            #if canImport(UIKit)
            HapticFeedbackHelper.shared.light()
            #endif
        }) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with chevron
                HStack {
                    Text("Sun & Moon")
                        .font(.system(size: 17, weight: .semibold))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                // Sunrise/Sunset
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 24) {
                        // Sunrise
                        VStack(spacing: 4) {
                            Image(systemName: "sunrise.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.orange)
                            Text(data.sunrise, style: .time)
                                .font(.system(size: 16, weight: .semibold))
                            Text("Sunrise")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Sun arc visualization
                        SunArcView(sunrise: data.sunrise, sunset: data.sunset)
                            .frame(height: 60)
                        
                        Spacer()
                        
                        // Sunset
                        VStack(spacing: 4) {
                            Image(systemName: "sunset.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.orange)
                            Text(data.sunset, style: .time)
                                .font(.system(size: 16, weight: .semibold))
                            Text("Sunset")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Golden hour info
                    Text("📸 Golden Hour: \(data.goldenHour.evening.start, style: .time) - \(data.sunset, style: .time)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Moon phase
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        Image(systemName: data.moonPhase.icon)
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(data.moonPhase.rawValue)
                                .font(.system(size: 16, weight: .semibold))
                            Text(data.moonPhase.description)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    if let moonrise = data.moonrise, let moonset = data.moonset {
                        HStack {
                            Text("Rise: \(moonrise, style: .time)")
                            Spacer()
                            Text("Set: \(moonset, style: .time)")
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    }
                }
                
                // Tap hint
                Text("Tap for photography times & moon details")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
                    .italic()
            }
            .padding(16)
            .glassCardBackground(colorScheme: colorScheme)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            SunMoonDetailView(data: data)
        }
    }
}

// MARK: - Sun Arc Visualization
struct SunArcView: View {
    let sunrise: Date
    let sunset: Date
    
    var body: some View {
        GeometryReader { geometry in
            let now = Date()
            let isNight = now < sunrise || now > sunset
            let progress = calculateProgress(now: now)
            
            ZStack {
                // Arc path
                Path { path in
                    let rect = CGRect(origin: .zero, size: geometry.size)
                    path.addArc(
                        center: CGPoint(x: rect.midX, y: rect.maxY),
                        radius: rect.width / 2,
                        startAngle: .degrees(180),
                        endAngle: .degrees(0),
                        clockwise: false
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: [.orange.opacity(0.3), .yellow.opacity(0.5), .orange.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 3
                )
                
                // Sun position
                if !isNight {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.yellow, .orange],
                                center: .center,
                                startRadius: 0,
                                endRadius: 8
                            )
                        )
                        .frame(width: 16, height: 16)
                        .position(sunPosition(progress: progress, in: geometry.size))
                }
            }
        }
    }
    
    private func calculateProgress(now: Date) -> Double {
        guard now >= sunrise && now <= sunset else { return 0 }
        let totalDuration = sunset.timeIntervalSince(sunrise)
        let elapsed = now.timeIntervalSince(sunrise)
        return elapsed / totalDuration
    }
    
    private func sunPosition(progress: Double, in size: CGSize) -> CGPoint {
        let angle = .pi * (1 - progress) // π to 0 (180° to 0°)
        let radius = size.width / 2
        let x = size.width / 2 + radius * cos(angle)
        let y = size.height - radius * sin(angle)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Precipitation Graph
struct PrecipitationGraphView: View {
    let hourlyData: [HourlyPrecipitation]
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
            #if canImport(UIKit)
            HapticFeedbackHelper.shared.light()
            #endif
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "cloud.rain.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    
                    Text("Rain Probability")
                        .font(.system(size: 17, weight: .semibold))
                    
                    Spacer()
                    
                    Text("Next 24h")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                // Graph
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        // Grid lines
                        ForEach([25, 50, 75], id: \.self) { percent in
                            Path { path in
                                let y = geometry.size.height * (1 - CGFloat(percent) / 100)
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                            }
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        }

                        // "Now" indicator. The vertical line marks
                        // the current hour so users can tell which
                        // bar is *right now* vs. upcoming. Without
                        // this, the chart looked like a single
                        // undifferentiated strip of bars — a
                        // common source of the "glitchy" feel
                        // users reported.
                        if let nowIndex = currentHourIndex() {
                            let columnWidth = columnWidth(in: geometry.size)
                            let x = columnWidth * CGFloat(nowIndex) + columnWidth / 2
                            Rectangle()
                                .fill(Color.white.opacity(0.85))
                                .frame(width: 2, height: geometry.size.height)
                                .position(x: x, y: geometry.size.height / 2)
                                .shadow(color: .black.opacity(0.3), radius: 1)
                        }

                        // Bars. We use `frame(maxWidth: .infinity)`
                        // on each bar so the HStack actually
                        // fills the GeometryReader — without it,
                        // the bars cluster to the leading edge on
                        // some devices, which read as a layout
                        // glitch. The 1.5pt minimum bar height
                        // also keeps 0% bars visible (a single
                        // hairline at the bottom) so the row
                        // never appears empty for users with no
                        // rain in the next 24 hours.
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(Array(hourlyData.prefix(24).enumerated()), id: \.offset) { _, data in
                                VStack(spacing: 2) {
                                    Spacer(minLength: 0)

                                    // Bar
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    colorForProbability(data.probability),
                                                    colorForProbability(data.probability).opacity(0.6)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(
                                            maxWidth: .infinity,
                                            minHeight: 1.5,
                                            idealHeight: barHeight(probability: data.probability, container: geometry.size.height),
                                            maxHeight: barHeight(probability: data.probability, container: geometry.size.height)
                                        )
                                        .cornerRadius(2)
                                        .animation(.easeInOut(duration: 0.4), value: data.probability)

                                    // Hour label (show every 3 hours)
                                    if Calendar.current.component(.hour, from: data.hour) % 3 == 0 {
                                        Text(data.hour, style: .time)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                            .fixedSize()
                                    } else {
                                        // Reserve vertical space for
                                        // the hidden labels so the
                                        // bars don't jump up/down
                                        // as the visible labels
                                        // appear at the 3-hour
                                        // boundaries.
                                        Text(" ")
                                            .font(.system(size: 9))
                                            .opacity(0)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .frame(height: 120)
                // Top-level animation on the whole graph so
                // transitions between fetches (e.g. when the user
                // changes location) ease smoothly instead of
                // snapping.
                .animation(.easeInOut(duration: 0.3), value: hourlyData.count)
                
                // Legend
                HStack(spacing: 16) {
                    LegendItem(color: .blue.opacity(0.3), text: "Light")
                    LegendItem(color: .blue.opacity(0.6), text: "Moderate")
                    LegendItem(color: .blue.opacity(0.9), text: "Heavy")
                }
                .font(.system(size: 11))
                
                // Tap hint
                Text("Tap for hourly breakdown")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
                    .italic()
            }
            .padding(16)
            .glassCardBackground(colorScheme: colorScheme)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            PrecipitationDetailView(data: hourlyData)
        }
    }
    
    private func colorForProbability(_ probability: Int) -> Color {
        switch probability {
        case 0..<30: return .blue.opacity(0.3)
        case 30..<60: return .blue.opacity(0.6)
        default: return .blue.opacity(0.9)
        }
    }

    /// Index of the column whose hour matches the current
    /// device clock. Returns `nil` when the "now" hour is not
    /// in the displayed range (e.g. late at night when the
    /// 24-hour window is already in tomorrow's afternoon).
    private func currentHourIndex() -> Int? {
        let now = Date()
        return hourlyData.prefix(24).firstIndex { entry in
            Calendar.current.isDate(entry.hour, equalTo: now, toGranularity: .hour)
        }
    }

    /// Width of one bar column in the chart. We compute this
    /// from the container width, the number of columns, and
    /// the inter-column spacing so the "now" indicator sits
    /// exactly between the bars regardless of device size.
    private func columnWidth(in size: CGSize) -> CGFloat {
        let columns = max(1, hourlyData.prefix(24).count)
        let spacing: CGFloat = 2
        let totalSpacing = spacing * CGFloat(columns - 1)
        return max(0, (size.width - totalSpacing) / CGFloat(columns))
    }

    /// Pinned-bar height for a given probability. We cap the
    /// drawn height at `container` so 100% bars still leave a
    /// hairline of breathing room at the top — the previous
    /// implementation hit the very top edge of the
    /// GeometryReader which made high-probability bars look
    /// "stuck" to the card.
    private func barHeight(probability: Int, container: CGFloat) -> CGFloat {
        let cappedContainer = max(0, container - 2)
        return cappedContainer * CGFloat(probability) / 100
    }
}

// MARK: - Helper Views
struct RecommendationRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}

struct LegendItem: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Glass Card Modifier
extension View {
    func glassCardBackground(colorScheme: ColorScheme) -> some View {
        self
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)
                    
                    LinearGradient(
                        colors: colorScheme == .dark ? [
                            Color.black.opacity(0.2),
                            Color.black.opacity(0.1),
                            Color.clear
                        ] : [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: colorScheme == .dark ? [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1)
                            ] : [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}
