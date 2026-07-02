//
//  LottieDebugView.swift
//  SaxWeather
//
//  DEBUG-only developer panel for app state, share links, widgets, and tooling.
//

#if DEBUG && os(iOS)

import SwiftUI
import Lottie
import WidgetKit
import AppIntents
import os.log

struct LottieDebugView: View {
    @EnvironmentObject private var weatherService: WeatherService
    @EnvironmentObject private var customisationRegistry: CustomisationRegistry
    @ObservedObject var locationsManager: SavedLocationsManager

    @State private var statusMessage: String?
    @State private var showingCopiedAlert = false

    private let appGroupID = "group.com.saxobroko.SaxWeather"
    private let logger = Logger(subsystem: "com.saxobroko.saxweather", category: "Debug")

    private let availableAnimations = [
        "clear-day", "clear-night", "partly-cloudy", "partly-cloudy-night",
        "cloudy", "rainy", "thunderstorm", "foggy"
    ]

    private let registeredIntents: [(name: String, symbol: String)] = [
        ("Get Weather", "cloud.sun"),
        ("Get Forecast", "calendar.badge.clock"),
        ("Rain Next Hour", "cloud.rain"),
        ("UV Index", "sun.max"),
        ("Show Forecast", "calendar")
    ]

    var body: some View {
        List {
            appStateSection
            weatherPayloadSection
            shareLinksSection
            widgetSyncSection
            apiKeysSection
            intentsSection
            lottieSection
            actionsSection
        }
        .navigationTitle("Developer Debug")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Copied", isPresented: $showingCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(statusMessage ?? "Debug bundle copied to clipboard.")
        }
    }

    // MARK: - Sections

    private var appStateSection: some View {
        Section("App State") {
            debugRow("Version", appVersion)
            debugRow("Build", appBuild)
            debugRow("Data source", weatherService.currentDataSource)
            debugRow("Loading", weatherService.isLoading ? "Yes" : "No")
            debugRow("Last fetch", formatDate(weatherService.lastSuccessfulFetch))
            debugRow("Location", locationLabel)
            debugRow("Coordinates", coordinatesLabel)
            debugRow("Use GPS", weatherService.useGPS ? "Yes" : "No")
            debugRow("Unit system", weatherService.unitSystem)
            debugRow("Station ID", stationIDLabel)
            debugRow("Show hero updated", SettingsBehaviour.showHeroLastUpdated ? "On" : "Off")
            debugRow("Saved locations", "\(locationsManager.locations.count)")
        }
    }

    private var weatherPayloadSection: some View {
        Section("Weather Payload") {
            if let weather = weatherService.weather {
                debugRow("Condition", weather.condition)
                debugRow("Temperature", formatOptional(weather.temperature, suffix: tempSuffix))
                debugRow("Feels like", formatOptional(weather.feelsLike, suffix: tempSuffix))
                debugRow("High / Low", highLowLabel(weather))
                debugRow("Humidity", weather.humidity.map { "\($0)%" } ?? "—")
                debugRow("Wind speed", formatOptional(weather.windSpeed, suffix: " \(speedSuffix)"))
                debugRow("Wind direction", windDirectionLabel(weather))
                debugRow("UV index", weather.uvIndex.map(String.init) ?? "—")
                debugRow("Precip hours", "\(weather.hourlyPrecipitation.count)")
                debugRow("Forecasts", "\(weather.forecasts.count)")
                debugRow("Time zone", weather.locationTimeZoneIdentifier ?? "—")
                debugRow("Stale", isWeatherStale ? "Yes" : "No")
            } else {
                Text("No weather loaded")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var shareLinksSection: some View {
        Section("Share Links") {
            if let context = shareContext {
                if let https = WeatherShareLinkBuilder.makePublicShareURL(from: context) {
                    linkRow("HTTPS preview", url: https)
                }
                if let deep = WeatherShareLinkBuilder.makeDeepLinkURL(from: context) {
                    linkRow("Deep link", url: deep)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Share text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(WeatherShareLinkBuilder.makeLinkShareText(from: context))
                        .font(.caption2)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
            } else {
                Text("Need coordinates and weather to build share links.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var widgetSyncSection: some View {
        Section("Widget Sync") {
            let shared = UserDefaults(suiteName: appGroupID)
            debugRow("App group", appGroupID)
            debugRow("Widget data version", widgetDataVersionLabel(shared))
            debugRow("Shared use GPS", boolLabel(shared?.object(forKey: WidgetSyncService.Keys.useGPS) as? Bool))
            debugRow("Shared unit", shared?.string(forKey: WidgetSyncService.Keys.unitSystem) ?? "—")
            debugRow("latestWeather size", latestWeatherSizeLabel(shared))

            if let preview = widgetWeatherPreview(shared) {
                Text(preview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var apiKeysSection: some View {
        Section("API Keys") {
            apiKeyRow("Weather Underground", service: "wu")
            apiKeyRow("OpenWeatherMap", service: "owm")
            debugRow("API keys disabled", UserDefaults.standard.bool(forKey: "disableAPIKeys") ? "Yes" : "No")
        }
    }

  private var intentsSection: some View {
        Section("App Intents") {
            ForEach(registeredIntents, id: \.name) { intent in
                Label(intent.name, systemImage: intent.symbol)
            }
            if let pending = AppIntentNavigation.peekPendingWeatherLink() {
                debugRow("Pending weather link", "\(pending.latitude), \(pending.longitude)")
            } else {
                debugRow("Pending weather link", "None")
            }
        }
    }

    private var lottieSection: some View {
        Section("Lottie Preview") {
            NavigationLink {
                DebugLottiePreviewScreen(availableAnimations: availableAnimations)
            } label: {
                Label("Open Lottie Preview", systemImage: "play.circle.fill")
            }
            Text("Lottie runs outside this list — UIKit animations inside List rows freeze scrolling.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button {
                Task {
                    await weatherService.fetchWeather(calledFrom: "LottieDebugView")
                    statusMessage = "Weather refresh requested."
                }
            } label: {
                Label("Force Weather Refresh", systemImage: "arrow.clockwise")
            }

            Button {
                WidgetCenter.shared.reloadAllTimelines()
                statusMessage = "Widget timelines reloaded."
            } label: {
                Label("Reload Widgets", systemImage: "square.grid.2x2")
            }

            Button {
                copyDebugBundle()
            } label: {
                Label("Copy Debug Bundle JSON", systemImage: "doc.on.doc")
            }

            if let message = statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func debugRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private func linkRow(_ title: String, url: URL) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(url.absoluteString)
                .font(.caption2)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    private func apiKeyRow(_ title: String, service: String) -> some View {
        let key = KeychainService.shared.getApiKey(forService: service) ?? ""
        let status: String
        if key.isEmpty {
            status = "Not set"
        } else {
            let suffix = key.suffix(4)
            status = "Set (…\(suffix))"
        }
        return debugRow(title, status)
    }

    private var shareContext: WeatherShareContext? {
        guard let weather = weatherService.weather else { return nil }
        return WeatherShareContext.make(
            weather: weather,
            locationName: locationLabel,
            unitSystem: weatherService.unitSystem,
            weatherService: weatherService,
            locationsManager: locationsManager
        )
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private var locationLabel: String {
        if let selected = locationsManager.selectedLocation {
            return selected.name
        }
        return UserDefaults.standard.string(forKey: "locationName") ?? "Current Location"
    }

    private var coordinatesLabel: String {
        if let coord = weatherService.currentLocation {
            return String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
        }
        let lat = UserDefaults.standard.string(forKey: "latitude") ?? ""
        let lon = UserDefaults.standard.string(forKey: "longitude") ?? ""
        if !lat.isEmpty, !lon.isEmpty { return "\(lat), \(lon)" }
        return "—"
    }

    private var stationIDLabel: String {
        let station = UserDefaults.standard.string(forKey: "stationID") ?? ""
        return station.isEmpty ? "—" : station
    }

    private var tempSuffix: String {
        UnitSystem.from(rawValue: weatherService.unitSystem).temperatureLabel
    }

    private var speedSuffix: String {
        UnitSystem.from(rawValue: weatherService.unitSystem).speedLabel
    }

    private func formatOptional(_ value: Double?, suffix: String) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f%@", value, suffix)
    }

    private func highLowLabel(_ weather: Weather) -> String {
        guard let high = weather.high, let low = weather.low else { return "—" }
        return String(format: "%.0f / %.0f%@", high, low, tempSuffix)
    }

    private func windDirectionLabel(_ weather: Weather) -> String {
        let direction: Double?
        if let current = weather.currentWindDirection {
            direction = current
        } else if let forecastDir = weather.forecasts.first?.windDirection {
            direction = Double(forecastDir)
        } else {
            direction = nil
        }
        guard let direction else { return "—" }
        return "\(WindCompassView.cardinalAbbreviation(for: direction)) (\(String(format: "%.0f°", direction)))"
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .omitted, time: .standard)
    }

    private func boolLabel(_ value: Bool?) -> String {
        guard let value else { return "—" }
        return value ? "Yes" : "No"
    }

    private func widgetDataVersionLabel(_ shared: UserDefaults?) -> String {
        let version = shared?.integer(forKey: WidgetSyncService.Keys.widgetDataVersion) ?? 0
        return "\(version)"
    }

    private func latestWeatherSizeLabel(_ shared: UserDefaults?) -> String {
        guard let data = shared?.data(forKey: "latestWeather") else { return "0 bytes" }
        return "\(data.count) bytes"
    }

    private func widgetWeatherPreview(_ shared: UserDefaults?) -> String? {
        guard let data = shared?.data(forKey: "latestWeather"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let keys = ["condition", "temperature", "dataSource", "locationName", "lastUpdated"]
        let parts = keys.compactMap { key -> String? in
            guard let value = json[key] else { return nil }
            return "\(key): \(value)"
        }
        return parts.joined(separator: "\n")
    }

    private var isWeatherStale: Bool {
        guard let lastFetch = weatherService.lastSuccessfulFetch else { return true }
        return WidgetStaleness.isStale(lastFetch)
    }

    private func copyDebugBundle() {
        var bundle: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "version": appVersion,
            "build": appBuild,
            "dataSource": weatherService.currentDataSource,
            "unitSystem": weatherService.unitSystem,
            "useGPS": weatherService.useGPS,
            "location": locationLabel,
            "coordinates": coordinatesLabel,
            "stationID": stationIDLabel,
            "isLoading": weatherService.isLoading,
            "isStale": isWeatherStale,
            "lastSuccessfulFetch": weatherService.lastSuccessfulFetch.map {
                ISO8601DateFormatter().string(from: $0)
            } as Any
        ]

        if let weather = weatherService.weather {
            bundle["weather"] = [
                "condition": weather.condition,
                "temperature": weather.temperature as Any,
                "feelsLike": weather.feelsLike as Any,
                "high": weather.high as Any,
                "low": weather.low as Any,
                "humidity": weather.humidity as Any,
                "windSpeed": weather.windSpeed as Any,
                "windDirection": weather.currentWindDirection as Any,
                "precipHours": weather.hourlyPrecipitation.count,
                "forecastDays": weather.forecasts.count,
                "timeZone": weather.locationTimeZoneIdentifier as Any
            ]
        }

        if let context = shareContext {
            bundle["shareHTTPS"] = WeatherShareLinkBuilder.makePublicShareURL(from: context)?.absoluteString as Any
            bundle["shareDeepLink"] = WeatherShareLinkBuilder.makeDeepLinkURL(from: context)?.absoluteString as Any
        }

        if let data = try? JSONSerialization.data(withJSONObject: bundle, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            UIPasteboard.general.string = text
            statusMessage = "Debug bundle copied (\(data.count) bytes)."
            showingCopiedAlert = true
            logger.info("Debug bundle copied to clipboard")
        }
    }
}

// MARK: - Lottie preview (outside List — UIKit Lottie freezes inside List rows)

private struct DebugLottiePreviewScreen: View {
    let availableAnimations: [String]

    @State private var selectedAnimation = "clear-day"
    @State private var loadingFailed = false

    var body: some View {
        VStack(spacing: 24) {
            Picker("Animation", selection: $selectedAnimation) {
                ForEach(availableAnimations, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))

                if loadingFailed {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text("Failed to load \(selectedAnimation)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    RemoteLottieView(
                        name: selectedAnimation,
                        loadingFailed: $loadingFailed
                    )
                }
            }
            .frame(height: 220)
            .padding(.horizontal)

            VStack(spacing: 6) {
                Text(cacheStatusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if loadingFailed {
                    Button("Retry") {
                        loadingFailed = false
                        Task {
                            try? await LottieAssetStore.shared.download(name: selectedAnimation)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 16)
        .navigationTitle("Lottie Preview")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedAnimation) { _ in
            loadingFailed = false
        }
    }

    private var cacheStatusLabel: String {
        if LottieAssetStore.shared.isDownloaded(name: selectedAnimation) {
            return "Cached on device"
        }
        return "Will download from CDN on first play"
    }
}

#endif
