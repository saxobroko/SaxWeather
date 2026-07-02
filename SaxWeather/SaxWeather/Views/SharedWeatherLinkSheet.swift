//
//  SharedWeatherLinkSheet.swift
//  SaxWeather
//
//  Full-screen preview when opening a shared weather link.
//

import SwiftUI
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

struct SharedWeatherLinkSheet: View {
    let link: PendingWeatherLink
    @ObservedObject var locationsManager: SavedLocationsManager
    let onDismiss: () -> Void

    @StateObject private var previewWeatherService = WeatherService()
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var customisationRegistry: CustomisationRegistry

    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    @AppStorage("displayMode") private var displayMode: String = "Summary"
    @AppStorage("disableAPIKeys") private var disableAPIKeys = false

    @State private var selectedFeelsLikeMetric: WeatherMetricInfo?
    @State private var didAddLocation = false
    @State private var showAddedAlert = false

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
                    Button(action: addLocation) {
                        Image(systemName: addButtonSymbol)
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(addButtonColor)
                    }
                    .disabled(isLocationAlreadySaved || didAddLocation)
                    .accessibilityLabel(isLocationAlreadySaved ? "Location already saved" : "Add location")
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
        .task {
            configurePreviewService()
            await previewWeatherService.fetchWeather(calledFrom: "SharedWeatherLinkSheet")
        }
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
                await previewWeatherService.fetchWeather(calledFrom: "SharedWeatherLinkSheet.retry")
            } onOpenSettings: {
                AppSettingsRouter.open()
            }
            .padding(.top, 40)
        } else {
            ProgressView("Loading shared weather…")
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

    private var footerView: some View {
        VStack(spacing: 4) {
            WeatherAttributionView(
                dataSource: previewWeatherService.currentDataSource,
                stationID: link.stationID
            )

            Text("Shared via SaxWeather")
                .accessibleFont(size: 12)
                .foregroundColor(.primary)
                .padding(.bottom, 10)
        }
    }

    // MARK: - Helpers

    private var locationTitle: String {
        if let name = link.name, !name.isEmpty {
            return name
        }
        if let weatherName = previewWeatherService.weather?.locationName, !weatherName.isEmpty {
            return weatherName
        }
        return String(format: "%.4f, %.4f", link.latitude, link.longitude)
    }

    private var shouldShowLocationHeader: Bool {
        guard SettingsBehaviour.showLocationHeader else { return false }

        let wuApiKey = KeychainService.shared.getApiKey(forService: "wu") ?? ""
        let stationID = link.stationID ?? ""
        let hasWeatherUnderground = !wuApiKey.isEmpty && !stationID.isEmpty

        if hasWeatherUnderground && !disableAPIKeys {
            return false
        }

        return true
    }

    private var isLocationAlreadySaved: Bool {
        locationsManager.locations.contains {
            abs($0.latitude - link.latitude) < 0.0001
                && abs($0.longitude - link.longitude) < 0.0001
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

    private func configurePreviewService() {
        previewWeatherService.useGPS = false
        previewWeatherService.shareLinkPreview = ShareLinkPreviewContext(
            latitude: link.latitude,
            longitude: link.longitude,
            stationID: link.stationID
        )
        previewWeatherService.currentLocation = CLLocationCoordinate2D(
            latitude: link.latitude,
            longitude: link.longitude
        )
    }

    private func addLocation() {
        guard !isLocationAlreadySaved else { return }

        if locationsManager.addLocation(
            name: locationTitle,
            latitude: link.latitude,
            longitude: link.longitude
        ) {
            didAddLocation = true
            showAddedAlert = true
            #if canImport(UIKit)
            HapticFeedbackHelper.shared.success()
            #endif
        }
    }
}
