//
//  PrecipitationTimelineBuilder.swift
//  SaxWeather
//
//  Builds a two-hour precipitation timeline from Open-Meteo hourly
//  data, aligned with WidgetRainLine probability thresholds.
//

import Foundation

enum PrecipitationTimelineBuilder {
    private static let amountThreshold = 0.05
    private static let horizon: TimeInterval = 2 * 3600

    static func build(from hourly: [HourlyPrecipitation], now: Date = Date()) -> PrecipitationTimeline {
        let threshold = WidgetRainLine.probabilityThreshold

        func isSignificantRain(_ entry: HourlyPrecipitation) -> Bool {
            entry.probability >= threshold && entry.amount > amountThreshold
        }

        let windowEnd = now.addingTimeInterval(horizon)
        let timePoints: [PrecipitationTimePoint] = hourly
            .filter { $0.hour >= now && $0.hour <= windowEnd }
            .map {
                PrecipitationTimePoint(
                    time: $0.hour,
                    precipitation: $0.amount,
                    probability: $0.probability
                )
            }

        let currentHour = hourly.first { entry in
            Calendar.current.compare(entry.hour, to: now, toGranularity: .hour) == .orderedSame
        }
        let isRainingNow = currentHour.map(isSignificantRain) ?? false

        var rainStartTime: Date?
        var rainEndTime: Date?

        if !isRainingNow {
            rainStartTime = hourly
                .filter { $0.hour > now && $0.hour <= windowEnd && isSignificantRain($0) }
                .sorted { $0.hour < $1.hour }
                .first?
                .hour
        } else {
            let futureHours = hourly
                .filter { $0.hour >= now && $0.hour <= windowEnd }
                .sorted { $0.hour < $1.hour }

            for index in futureHours.indices {
                guard isSignificantRain(futureHours[index]) else { continue }
                if index + 1 < futureHours.count, !isSignificantRain(futureHours[index + 1]) {
                    rainEndTime = futureHours[index + 1].hour
                    break
                }
            }
        }

        return PrecipitationTimeline(
            timePoints: timePoints,
            rainStartTime: rainStartTime,
            rainEndTime: rainEndTime,
            isRainingNow: isRainingNow
        )
    }
}
