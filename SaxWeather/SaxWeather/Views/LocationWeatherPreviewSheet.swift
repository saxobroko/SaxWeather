//
//  LocationWeatherPreviewSheet.swift
//  SaxWeather
//
//  Full-screen weather preview for share links, location peeks,
//  and add-location flows.
//

import SwiftUI
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

struct LocationWeatherPreviewSheet: View {
    let request: LocationWeatherPreviewRequest
    @ObservedObject var locationsManager: SavedLocationsManager
    let onDismiss: () -> Void
    let onUseLocation: (() -> Void)?
    let onAddAndUseLocation: (() -> Void)?

    @StateObject private var previewWeatherService = WeatherService()
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var customisationRegistry: CustomisationRegistry

    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    @AppStorage("displayMode") private var displayMode: String = "Summary"
    @AppStorage("disableAPIKeys") private var disableAPIKeys = false

    @State private var selectedFeelsLikeMetric: WeatherMetricInfo?
    @State private var didAddLocation = false
    @State private var showAddedAlert = false
    @State private var showAPIKeysWarning = false

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundLayer
                    .ignoresSafeArea()

                if displayMode == "Detailed" {
                    DetailedWeatherView(weatherService: previewWeatherService)
                } else {
                    summaryContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white, .white.opacity(0.35))
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .principal) {
                    Text(locationTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    trailingToolbarContent
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(item: $selectedFeelsLikeMetric) { metric in
            WeatherMetricInfoContent(
                title: metric.title,
                value: metric.value,
                description: metric.description,
                windDirection: metric.windDirection
            )
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
        .alert("Location Saved", isPresented: $showAddedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(locationTitle) was added to your saved locations.")
        }
        .alert("API Keys Active", isPresented: $showAPIKeysWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Custom locations are currently ignored because a Weather Underground station is configured. Disable API keys in Settings → Locations to use saved locations.")
        }
        .task {
            configurePreviewService()
            await previewWeatherService.fetchWeather(calledFrom: "LocationWeatherPreviewSheet")
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var trailingToolbarContent: some View {
        switch request.mode {
        case .sharedLink, .peekOnly:
            if showsAddButton {
                Button(action: addLocationOnly) {
                    Image(systemName: addButtonSymbol)
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(addButtonColor)
                }
                .disabled(isLocationAlreadySaved || didAddLocation)
                .accessibilityLabel(
                    isLocationAlreadySaved ? "Location already saved" : "Add location"
                )
            }

        case .locationPeek:
            Button(action: useLocationTapped) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
            }
            .accessibilityLabel("Use this location")

        case .addLocation:
            Button(action: addAndUseTapped) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Add and use location")
        }
    }

    private var showsAddButton: Bool {
        request.mode == .sharedLink || (request.mode == .peekOnly && !isLocationAlreadySaved)
    }

    // MARK: - Layout

    private var summaryContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 8) {
                    weatherHero
                }
            }
            .modifier(PullToRefreshModifier(
                enabled: SettingsBehaviour.pullToRefresh,
                weatherService: previewWeatherService
            ))

            footerView
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var weatherHero: some View {
        if let weather = previewWeatherService.weather, weather.hasData {
            VStack(spacing: 8) {
                if shouldShowLocationHeader {
                    Text("Weather for \(locationTitle)")
                        .accessibleFont(size: 14, weight: .medium)
                        .accessibleContrast()
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .padding(.top, 12)
                }

                if SettingsBehaviour.showHeroLastUpdated {
                    HeroLastUpdatedButton(weatherService: previewWeatherService)
                }

                ConditionIcon(condition: weather.condition, size: 150)
                    .frame(width: 150, height: 150)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .center)

                let unitSymbol = UnitSystem.from(rawValue: unitSystem).temperatureLabel

                if let temperature = weather.temperature {
                    Text(String(format: "%.1f%@", temperature, unitSymbol))
                        .accessibleFont(size: 80, weight: .heavy)
                        .accessibleContrast()
                        .foregroundColor(.primary)
                        .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 2)
                }

                if let feelsLike = weather.feelsLike {
                    Button {
                        selectedFeelsLikeMetric = WeatherMetricInfo(
                            title: "Feels Like",
                            value: String(format: "%.1f%@", feelsLike, unitSymbol),
                            description: WeatherMetricDescriptions.feelsLikeDescription(
                                for: weather,
                                unitSystem: unitSystem
                            )
                        )
                    } label: {
                        Text(String(format: "Feels like %.1f%@", feelsLike, unitSymbol))
                            .accessibleFont(size: 20, weight: .medium)
                            .accessibleContrast()
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    if let high = weather.high {
                        Text(String(format: "H: %.1f%@", high, unitSymbol))
                            .accessibleFont(size: 20, weight: .medium)
                            .accessibleContrast()
                            .foregroundColor(.primary)
                    }
                    if let low = weather.low {
                        Text(String(format: "L: %.1f%@", low, unitSymbol))
                            .accessibleFont(size: 20, weight: .medium)
                            .accessibleContrast()
                            .foregroundColor(.primary)
                    }
                }

                Text(weather.condition)
                    .accessibleFont(size: 24, weight: .semibold)
                    .accessibleContrast()
                    .foregroundColor(.primary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 24)

            WeatherDetailsView(weather: weather)
                .padding(.horizontal, 20)

            ExtendedWeatherSection(weather: weather)
        } else if previewWeatherService.isLoading {
            WeatherLoadingSkeleton()
                .padding(.top, 40)
        } else if let error = previewWeatherService.error {
            ErrorView(weatherError: error) {
                await previewWeatherService.fetchWeather(calledFrom: "LocationWeatherPreviewSheet.retry")
            } onOpenSettings: {
                AppSettingsRouter.open()
            }
            .padding(.top, 40)
        } else {
            ProgressView("Loading weather…")
                .padding(.top, 80)
        }
    }

    private var backgroundLayer: some View {
        let strategy = BackgroundResolver.resolve(
            condition: previewWeatherService.currentBackgroundCondition,
            spec: customisationRegistry.profile.knobs.background,
            sunrise: previewWeatherService.forecast?.daily.first?.sunrise,
            sunset: previewWeatherService.forecast?.daily.first?.sunset,
            now: Date(),
            customBackgroundUnlocked: storeManager.customBackgroundUnlocked,
            isCosmeticUnlocked: storeManager.owns
        )
        return BackgroundView(strategy: strategy)
            .environmentObject(storeManager)
    }

    @ViewBuilder
    private var footerView: some View {
        VStack(spacing: 4) {
            WeatherAttributionView(
                dataSource: previewWeatherService.currentDataSource,
                stationID: request.stationID
            )

            if request.mode == .sharedLink {
                Text("Shared via SaxWeather")
                    .accessibleFont(size: 12)
                    .foregroundColor(.primary)
                    .padding(.bottom, 10)
            }
        }
    }

    // MARK: - Helpers

    private var locationTitle: String {
        if let name = request.name, !name.isEmpty {
            return name
        }
        if let weatherName = previewWeatherService.weather?.locationName, !weatherName.isEmpty {
            return weatherName
        }
        return String(format: "%.4f, %.4f", request.latitude, request.longitude)
    }

    private var shouldShowLocationHeader: Bool {
        guard SettingsBehaviour.showLocationHeader else { return false }

        let wuApiKey = KeychainService.shared.getApiKey(forService: "wu") ?? ""
        let stationID = request.stationID ?? ""
        let hasWeatherUnderground = !wuApiKey.isEmpty && !stationID.isEmpty

        if hasWeatherUnderground && !disableAPIKeys {
            return false
        }

        return true
    }

    private var isLocationAlreadySaved: Bool {
        locationsManager.locations.contains {
            abs($0.latitude - request.latitude) < 0.0001
                && abs($0.longitude - request.longitude) < 0.0001
        }
    }

    private var addButtonSymbol: String {
        if isLocationAlreadySaved || didAddLocation {
            return "checkmark.circle.fill"
        }
        return "plus.circle.fill"
    }

    private var addButtonColor: Color {
        if isLocationAlreadySaved || didAddLocation {
            return .green
        }
        return .white
    }

    private var isOverriddenByAPIKeys: Bool {
        let wuApiKey = KeychainService.shared.getApiKey(forService: "wu") ?? ""
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        return !disableAPIKeys && (!wuApiKey.isEmpty || !stationID.isEmpty)
    }

    private func configurePreviewService() {
        previewWeatherService.useGPS = false
        previewWeatherService.shareLinkPreview = ShareLinkPreviewContext(
            latitude: request.latitude,
            longitude: request.longitude,
            stationID: request.stationID
        )
        previewWeatherService.currentLocation = CLLocationCoordinate2D(
            latitude: request.latitude,
            longitude: request.longitude
        )
    }

    private func useLocationTapped() {
        if isOverriddenByAPIKeys && !request.isGPSPreview {
            showAPIKeysWarning = true
            return
        }
        onUseLocation?()
        onDismiss()
    }

    private func addAndUseTapped() {
        onAddAndUseLocation?()
        onDismiss()
    }

    private func addLocationOnly() {
        guard !isLocationAlreadySaved else { return }

        if locationsManager.addLocation(
            name: locationTitle,
            latitude: request.latitude,
            longitude: request.longitude
        ) {
            didAddLocation = true
            showAddedAlert = true
            #if canImport(UIKit)
            HapticFeedbackHelper.shared.success()
            #endif
        }
    }
}
