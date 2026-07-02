//
//  ContentView.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-26 14:48:57
//

import SwiftUI
import CoreLocation
import StoreKit
import MapKit
#if os(iOS)
import UIKit
#endif

// MARK: - Deep-link wrapper (Phase 2)

/// Phase 2 — `Identifiable` wrapper used to drive the
/// cosmetics-store sheet from a non-`Identifiable` `String?`
/// value. SwiftUI's `.sheet(item:)` requires an `Identifiable`
/// binding; `DeepLinkProductID` adapts the
/// `pendingDeepLinkProductID` string to that shape without
/// forcing `CosmeticProduct` (which is heavier than we need
/// for "just an ID").
struct DeepLinkProductID: Identifiable {
    let value: String
    var id: String { value }
}

/// Phase 5 — `Identifiable` wrapper used to drive the
/// palette / chart-skin picker sheets from a non-
/// `Identifiable` `String?` value. The sheet item is the
/// product ID we want to highlight; the picker itself reads
/// it from the coordinator (already applied to the profile
/// by `CosmeticUsageCoordinator.applyToProfile(_:)`).
struct UsageProductID: Identifiable {
    let value: String
    var id: String { value }
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var locationsManager: SavedLocationsManager
    @StateObject private var weatherService = WeatherService()
    @State private var showSettings = false
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    @AppStorage("displayMode") private var displayMode: String = "Summary"
    @AppStorage("disableAPIKeys") private var disableAPIKeys = false
    @AppStorage("showHamburgerMenu") private var showHamburgerMenu: Bool = true
    // Phase 5 — observes the registry so the background re-renders
    // when the user tweaks a knob in the new Settings UI. The
    // resolver's `effectiveOverlayOpacity` is the source of truth
    // for the overlay (and is IAP-gated); the bridge still writes
    // the spec value through to `@AppStorage("overlayOpacity")`
    // for any legacy reader.
    @ObservedObject private var registry = CustomisationRegistry.shared
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingLocationMenu = false
    @StateObject private var healthMonitor = APIKeyHealthMonitor.shared
    @State private var selectedTab: Int = 0
    // Phase 2 — observe cosmetic deep links (saxweather://cosmetic/<id>).
    // `pendingDeepLinkProductID` drives a sheet that hosts
    // `CosmeticsStoreView` already pointing at the requested
    // product. The handler is injected as an environment object
    // from `SaxWeatherApp`; we only read its `pendingProductID`
    // here and forward it into our own state.
    @EnvironmentObject private var deepLinkHandler: CosmeticDeepLinkHandler
    @EnvironmentObject private var locationDeepLinkHandler: WeatherLocationDeepLinkHandler
    @State private var pendingDeepLinkProductID: String?
    // Phase 5 — drives the palette + chart-skin picker sheets
    // presented in response to a "Use now" / "Use this" tap.
    // The IDs are stored as plain `String`s; the actual picker
    // views are presented via `.sheet(isPresented:)` when the
    // matching pending usage is set.
    @State private var pendingUsagePalette: String?
    @State private var pendingUsageChart: String?
    @State private var pendingUsageBackground: String?
    @State private var selectedFeelsLikeMetric: WeatherMetricInfo?
    @State private var presentedLocationPreview: LocationWeatherPreviewRequest?

    // Phase 3 — live cosmetic-preview coordinator. Owned at the
    // root so navigation logic + countdown overlay can both
    // observe it without prop-drilling. Injected into the env
    // chain below so `CosmeticsStoreView` and
    // `CosmeticDetailView` can read it too.
    @StateObject private var previewCoordinator = CosmeticPreviewCoordinator()

    // Phase 4 — live cosmetic-preview manager. Owned at the
    // app root (`SaxWeatherApp`) and injected via
    // `.environmentObject(...)` so every view that participates
    // in the preview flow observes the *same* instance. The
    // countdown overlay reads `remainingSeconds` from this
    // object so it re-renders every second.
    @EnvironmentObject private var previewManager: PreviewProfileManager

    // Part B — reactive palette store. Owned at the root so
    // every view that uses the palette (cards, backgrounds,
    // etc.) can observe it via `@EnvironmentObject` and
    // re-render when the palette changes (e.g. during a live
    // preview of the Aurora Palette cosmetic).
    @StateObject private var colourTokenStore = ColourTokenStore()

    // Part B — reactive chart palette store. Owned at the
    // root so the hourly forecast view can observe it via
    // `@EnvironmentObject` and re-render when the chart skin
    // or entitlements change (e.g. during a live preview of
    // the Aurora Chart Skin cosmetic).
    @StateObject private var chartPaletteStore = ChartPaletteStore()

    // Phase 5 — "Use now" / "Use this" coordinator. Owns the
    // `pendingUsage` published by `CosmeticDetailView` when
    // the user taps either button. The view observes
    // `pendingUsage` to switch to the right tab and present
    // the matching picker.
    @StateObject private var cosmeticUsageCoordinator = CosmeticUsageCoordinator()

    // Computed property to check if we should show location text.
    // Honours the user-configured `showLocationHeader` setting in
    // addition to the legacy WU override.
    /// Summary-mode share affordance — hidden in Detailed layout.
    private var showShareButton: Bool {
        displayMode != "Detailed"
            && weatherService.weather?.hasData == true
    }

    private var shouldShowLocationText: Bool {
        // User has turned the header off entirely.
        guard SettingsBehaviour.showLocationHeader else { return false }

        // Show location text when:
        // 1. API keys are disabled (using Apple Weather/Open-Meteo with custom locations), OR
        // 2. Using GPS or custom saved locations (not Weather Underground station)
        let wuApiKey = KeychainService.shared.getApiKey(forService: "wu") ?? ""
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        let hasWeatherUnderground = !wuApiKey.isEmpty && !stationID.isEmpty

        // Hide when using Weather Underground station (it's location-specific already)
        if hasWeatherUnderground && !disableAPIKeys {
            return false
        }

        // Show for GPS and custom locations
        return true
    }

    /// Effective card padding for the home screen. Scaled by the
    /// `cardDensity` preference (compact/regular/relaxed) and
    /// further squeezed in landscape when the user has
    /// `compactCardsInLandscape` enabled.
    private var cardSectionSpacing: CGFloat {
        let landscapeTighten: CGFloat = {
            #if os(iOS)
            let isLandscape = UIDevice.current.orientation.isLandscape
            return (isLandscape && SettingsBehaviour.compactCardsInLandscape) ? 8 : 0
            #else
            return 0
            #endif
        }()
        let base: CGFloat
        switch SettingsBehaviour.cardDensity {
        case "compact":  base = 12
        case "relaxed":  base = 28
        default:         base = 20
        }
        return max(8, base - landscapeTighten)
    }
    
    // Computed property for location display
    private var currentLocationText: String {
        // Priority 1: Use location name from weather data source (e.g., WU neighborhood)
        if let locationName = weatherService.weather?.locationName, !locationName.isEmpty {
            return locationName
        }
        
        // Priority 2: Check if using GPS
        if weatherService.useGPS {
            return "Current Location"
        }
        
        // Priority 3: Use saved location from locations manager
        if let selectedLocation = locationsManager.selectedLocation, !selectedLocation.isCurrentLocation {
            return selectedLocation.name
        }
        
        // Priority 4: Fallback to coordinates
        let lat = UserDefaults.standard.string(forKey: "latitude") ?? ""
        let lon = UserDefaults.standard.string(forKey: "longitude") ?? ""
        if !lat.isEmpty && !lon.isEmpty {
            return "\(formatCoordinate(lat)), \(formatCoordinate(lon))"
        }
        
        // Priority 5: Unknown
        return "Unknown Location"
    }
    
    private func formatCoordinate(_ value: String) -> String {
        guard let doubleValue = Double(value) else { return value }
        return String(format: "%.4f", doubleValue)
    }

    private func consumePendingAppIntentNavigation() {
        guard let locationId = AppIntentNavigation.consumePendingLocationID() else { return }
        navigateToLocation(id: locationId)
    }

    private func consumePendingWeatherLink() {
        let link = AppIntentNavigation.consumePendingWeatherLink()
            ?? locationDeepLinkHandler.pendingLink
        guard let link else { return }
        locationDeepLinkHandler.clearPending()
        presentLocationPreview(.sharedLink(from: link))
    }

    private func presentLocationPreview(_ request: LocationWeatherPreviewRequest) {
        withAnimation(.easeInOut(duration: 0.25)) {
            presentedLocationPreview = request
        }
    }

    private func dismissLocationPreview() {
        presentedLocationPreview = nil
    }

    private var isLocationSwitchBlockedByAPIKeys: Bool {
        let wuApiKey = KeychainService.shared.getApiKey(forService: "wu") ?? ""
        let stationID = UserDefaults.standard.string(forKey: "stationID") ?? ""
        return !disableAPIKeys && (!wuApiKey.isEmpty || !stationID.isEmpty)
    }

    private func adoptPreviewLocation(_ request: LocationWeatherPreviewRequest) {
        if request.isGPSPreview {
            locationsManager.selectCurrentLocation()
            weatherService.useGPS = true
        } else if let savedID = request.savedLocationID,
                  let location = locationsManager.locations.first(where: { $0.id == savedID }) {
            locationsManager.selectLocation(location)
            weatherService.useGPS = false
        } else {
            weatherService.useGPS = false

            let latString = String(request.latitude)
            let lonString = String(request.longitude)
            UserDefaults.standard.set(latString, forKey: "latitude")
            UserDefaults.standard.set(lonString, forKey: "longitude")
            WidgetSyncService.shared.syncManualCoordinates(
                latitude: latString,
                longitude: lonString
            )

            if let stationID = request.stationID, !stationID.isEmpty {
                let wuKey = KeychainService.shared.getApiKey(forService: "wu") ?? ""
                if !wuKey.isEmpty {
                    UserDefaults.standard.set(stationID, forKey: "stationID")
                }
            }

            if let match = locationsManager.locations.first(where: {
                abs($0.latitude - request.latitude) < 0.0001
                    && abs($0.longitude - request.longitude) < 0.0001
            }) {
                locationsManager.selectLocation(match)
            }
        }

        Task {
            await weatherService.fetchWeather(calledFrom: "LocationWeatherPreview.adopt")
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTab = 0
        }
    }

    private func addAndUsePreviewLocation(_ request: LocationWeatherPreviewRequest) {
        let rawName = request.name ?? String(
            format: "%.4f, %.4f",
            request.latitude,
            request.longitude
        )
        let locationName = ShareLocationPlaceholder.isPlaceholder(rawName)
            ? ShareLocationResolver.coordinateFallback(
                latitude: request.latitude,
                longitude: request.longitude
            )
            : rawName

        if locationsManager.addLocation(
            name: locationName,
            latitude: request.latitude,
            longitude: request.longitude
        ), let addedLocation = locationsManager.locations.last {
            locationsManager.selectLocation(addedLocation)
            weatherService.useGPS = false
            Task {
                await weatherService.fetchWeather(calledFrom: "LocationWeatherPreview.addAndUse")
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = 0
            }
        }
    }

    /// Applies a shared link as the active app location (e.g. after explicit user action).
    private func navigateToWeatherLink(_ link: PendingWeatherLink) {
        weatherService.useGPS = false

        let latString = String(link.latitude)
        let lonString = String(link.longitude)
        UserDefaults.standard.set(latString, forKey: "latitude")
        UserDefaults.standard.set(lonString, forKey: "longitude")
        WidgetSyncService.shared.syncManualCoordinates(
            latitude: latString,
            longitude: lonString
        )

        if let stationID = link.stationID, !stationID.isEmpty {
            let wuKey = KeychainService.shared.getApiKey(forService: "wu") ?? ""
            if !wuKey.isEmpty {
                UserDefaults.standard.set(stationID, forKey: "stationID")
            }
        }

        if let match = locationsManager.locations.first(where: {
            abs($0.latitude - link.latitude) < 0.0001 && abs($0.longitude - link.longitude) < 0.0001
        }) {
            locationsManager.selectLocation(match)
        }

        Task {
            await weatherService.fetchWeather(calledFrom: "WeatherShareLink")
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTab = 0
        }
    }

    private func navigateToLocation(id locationId: UUID) {
        if let location = locationsManager.locations.first(where: { $0.id == locationId }) {
            locationsManager.selectLocation(location)
            weatherService.useGPS = false
        } else if locationId == SavedLocation.currentLocationEntry.id {
            locationsManager.selectCurrentLocation()
            weatherService.useGPS = true
        } else {
            return
        }

        Task {
            await weatherService.fetchWeather(calledFrom: "AppIntent.NavigateToLocation")
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTab = 1
        }
    }

    var body: some View {
        ZStack {
            Group {
                if isFirstLaunch {
                    OnboardingView(isFirstLaunch: $isFirstLaunch, weatherService: weatherService)
                        .preferredColorScheme(selectedColorScheme)
                        .environmentObject(storeManager)
                } else {
                    TabView(selection: $selectedTab) {
                        NavigationStack {
                            mainWeatherView
                        }
                        .tabItem {
                            Label("Weather", systemImage: "cloud.sun.fill")
                        }
                        .tag(0)

                        NavigationStack {
                            ForecastView(weatherService: weatherService)
                        }
                        .tabItem {
                            Label("Forecast", systemImage: "calendar")
                        }
                        .tag(1)

                        NavigationStack {
                            AlertsView(weatherService: weatherService)
                        }
                        .tabItem {
                            Label("Alerts", systemImage: "exclamationmark.triangle")
                        }
                        .tag(2)

                        NavigationStack {
                            SettingsView(weatherService: weatherService)
                        }
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(3)

                        #if DEBUG
                        NavigationStack {
                            LottieDebugView(locationsManager: locationsManager)
                                .environmentObject(weatherService)
                                .environmentObject(registry)
                        }
                        .tabItem {
                            Label("Debug", systemImage: "ladybug.fill")
                        }
                        .tag(4)
                        #endif
                    }
                    .preferredColorScheme(selectedColorScheme)
                    .onAppear {
                        // Sync LocationsManager with current GPS state
                        if weatherService.useGPS {
                            locationsManager.selectCurrentLocation()
                        }
                    }
                }
            }
            // Phase 3 — inject the preview coordinator so child
            // views (`CosmeticsStoreView`, `CosmeticDetailView`)
            // can observe it.
            .environmentObject(previewCoordinator)
            // Part B — inject the reactive palette + chart
            // palette stores so child views can observe them
            // via `@EnvironmentObject` and re-render when the
            // palette or chart skin changes.
            .environmentObject(colourTokenStore)
            .environmentObject(chartPaletteStore)
            // Phase 5 — inject the "Use now" coordinator so
            // `CosmeticDetailView` can publish `pendingUsage`
            // when the user taps "Use this" or "Use now".
            .environmentObject(cosmeticUsageCoordinator)
            // Listen for the onboarding "API Keys" link-out
            // button. The onboarding step flips `isFirstLaunch`
            // to `false` (so the main UI shows) and posts this
            // notification — we react by jumping straight to
            // the Settings tab.
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsToAPIKeys)) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = 3
                }
            }
            // Phase 4 — listen for the preview-expired notification and
            // restore the original profile. The manager posts this
            // notification when its internal timer reaches 0.
            .onReceive(NotificationCenter.default.publisher(for: PreviewProfileManager.previewExpiredNotification)) { _ in
                var profile = registry.profile
                if previewManager.restoreIfExpired(restoreTo: &profile) {
                    registry.apply(profile)
                    previewCoordinator.endPreview(reopenForProductID: nil)
                }
            }
            // Listen for the debug menu's "Re-run Onboarding"
            // button. Flipping `isFirstLaunch` back to `true`
            // re-presents the onboarding flow on the next
            // render pass.
            .onReceive(NotificationCenter.default.publisher(for: .debugRerunOnboarding)) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isFirstLaunch = true
                }
            }
            // Phase 5 — App Intents navigation. When the user runs
            // the "Show Forecast" intent, we persist the target
            // location and post a notification. onAppear / active
            // also consume any pending location for cold launches.
            .onReceive(NotificationCenter.default.publisher(for: AppIntentNavigation.navigateNotification)) { notification in
                if let locationId = notification.userInfo?["locationId"] as? UUID {
                    navigateToLocation(id: locationId)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: AppIntentNavigation.weatherLinkNotification)) { _ in
                consumePendingWeatherLink()
            }
            .onReceive(NotificationCenter.default.publisher(for: LocationPreviewNavigation.requestNotification)) { _ in
                if let request = LocationPreviewNavigation.consumePending() {
                    presentLocationPreview(request)
                }
            }
            .onAppear {
                consumePendingAppIntentNavigation()
                consumePendingWeatherLink()
                if let request = LocationPreviewNavigation.consumePending() {
                    presentLocationPreview(request)
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    consumePendingAppIntentNavigation()
                    consumePendingWeatherLink()
                    if let request = LocationPreviewNavigation.consumePending() {
                        presentLocationPreview(request)
                    }
                }
            }
            .fullScreenCover(item: $presentedLocationPreview) { request in
                LocationWeatherPreviewSheet(
                    request: request,
                    locationsManager: locationsManager,
                    onDismiss: dismissLocationPreview,
                    onUseLocation: {
                        adoptPreviewLocation(request)
                    },
                    onAddAndUseLocation: {
                        addAndUsePreviewLocation(request)
                    }
                )
                .environmentObject(storeManager)
                .environmentObject(registry)
                .environmentObject(colourTokenStore)
                .environmentObject(chartPaletteStore)
            }
        }
        .accessibleAnimation(.easeInOut, value: isFirstLaunch)
        // Phase 3 — live-preview countdown overlay. Slides in
        // from the top whenever a cosmetic preview is active
        // (after the user tapped "Preview" inside
        // `CosmeticDetailView`). Sits above the offline banner
        // so the user always sees it during a preview.
        .safeAreaInset(edge: .top, spacing: 0) {
            // Phase 5 — also gate on `previewManager.activePreview`.
            // The coordinator's `presentedDestination` is only cleared
            // when the notification handler runs (which is too late —
            // `tickCountdown` already nilled `activePreview` before the
            // notification fires, so `restoreIfExpired` is a no-op and
            // `endPreview` never gets called). Gating on the manager's
            // own published state means the overlay disappears the
            // instant the timer expires, matching the user's
            // expectation that "Ends in 0s" is the *last* frame shown.
            if previewCoordinator.hasActivePreview,
               previewManager.activePreview != nil,
               let name = previewCoordinator.previewingProductName {
                PreviewCountdownOverlay(
                    previewManager: previewManager,
                    productName: name,
                    onStop: { endActivePreviewFromOverlay() }
                )
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // Animate the overlay's appearance / disappearance in sync
        // with the visibility condition above. Without this, the
        // `.transition` only fires for view changes *inside* the
        // `if`, not for the `if` itself flipping false.
        .accessibleAnimation(.easeInOut(duration: 0.25), value: previewManager.activePreview != nil)
        // Top-of-screen offline banner. Watches
        // `NetworkMonitor.shared` and slides in from the top
        // when the device loses connectivity. The
        // `.safeAreaInset` modifier lets the banner participate
        // in layout (pushing the tab bar down) rather than
        // overlapping it.
        .safeAreaInset(edge: .top, spacing: 0) {
            OfflineBanner()
        }
        // Location-permission alert. `WeatherService.showLocationAlert`
        // is set whenever the user denies (or restricts) location
        // access, or when a `CLLocationManager` callback maps a
        // raw CLError to `.locationDenied` / `.locationRestricted`.
        // We bind a SwiftUI alert here with an "Open Settings"
        // action so the user has a one-tap path to fix the
        // permission.
        .alert(
            "Location Access Required",
            isPresented: $weatherService.showLocationAlert
        ) {
            Button("Open Settings") {
                AppSettingsRouter.open()
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("SaxWeather needs location access to show weather for where you are. You can also add a location manually in Settings.")
        }
        // Phase 2 — react to a cosmetic deep link. We mirror the
        // handler's `pendingProductID` into local state (so the
        // sheet can drive its presentation via a stable binding),
        // then clear the handler so a stale value doesn't re-fire
        // on the next render. The handler is the single source of
        // truth for "is there a pending deep link right now?";
        // this view is one of possibly several consumers.
        .onChange(of: deepLinkHandler.pendingProductID) { newValue in
            guard let productID = newValue else { return }
            pendingDeepLinkProductID = productID
            deepLinkHandler.clearPending()
        }
        // Phase 3 — when a live preview starts, switch to the
        // destination tab (main weather or forecast) so the user
        // sees the cosmetic applied to real data.
        .onChange(of: previewCoordinator.presentedDestination) { newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                switch newValue {
                case .mainWeather:
                    selectedTab = 0
                case .forecast:
                    selectedTab = 1
                case .none:
                    break
                }
            }
        }
        // Phase 5 — when the user taps "Use now" / "Use this"
        // on a palette / chart / background cosmetic, the
        // coordinator publishes a `pendingUsage` value. Switch
        // to the Settings tab AND mirror the destination into
        // the matching `pendingUsageX` state so the right
        // picker sheet is presented. Clearing the coordinator
        // immediately after mirroring prevents a re-fire on
        // the next render.
        .onChange(of: cosmeticUsageCoordinator.pendingUsage) { newValue in
            guard let usage = newValue else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = 3
            }
            switch usage.destination {
            case .paletteSettings:
                pendingUsagePalette = usage.cosmetic.id
            case .chartSettings:
                pendingUsageChart = usage.cosmetic.id
            case .backgroundSettings:
                pendingUsageBackground = usage.cosmetic.id
            }
            cosmeticUsageCoordinator.clearPending()
        }
        // Phase 3 — when the preview ends (timer fires or user
        // taps Stop), the coordinator publishes the product ID
        // whose detail view should be re-presented. Mirror it
        // into `pendingDeepLinkProductID` so the existing deep-
        // link sheet handler picks it up and re-opens the store
        // at the right product. We also switch to the Settings
        // tab so the store sheet has somewhere to anchor.
        .onChange(of: previewCoordinator.reopenProductID) { newValue in
            guard let productID = newValue else { return }
            pendingDeepLinkProductID = productID
            previewCoordinator.reopenProductID = nil
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = 3
            }
        }
        // Cosmetics store sheet presented in response to a deep
        // link. Bound through `pendingDeepLinkProductID` so
        // setting it to nil dismisses the sheet. The store view
        // reads the ID and auto-presents `CosmeticDetailView` for
        // the matching product.
        .sheet(item: Binding(
            get: { pendingDeepLinkProductID.map { DeepLinkProductID(value: $0) } },
            set: { newValue in pendingDeepLinkProductID = newValue?.value }
        )) { wrapper in
            CosmeticsStoreView(
                    initialPendingProductID: wrapper.value
                )
                .environmentObject(storeManager)
                .environmentObject(registry)
                .environmentObject(previewCoordinator)
                .environmentObject(cosmeticUsageCoordinator)
        }
        // Phase 5 — palette picker presented in response to
        // a "Use now" / "Use this" tap on the Aurora Palette
        // (or any future .palette cosmetic). The sheet is
        // bound through `pendingUsagePalette`; setting it to
        // nil dismisses the sheet.
        .sheet(item: Binding(
            get: { pendingUsagePalette.map { UsageProductID(value: $0) } },
            set: { newValue in pendingUsagePalette = newValue?.value }
        )) { wrapper in
            PalettePickerView()
                .environmentObject(registry)
                .environmentObject(storeManager)
        }
        // Phase 5 — chart-skin picker presented in response
        // to a "Use now" / "Use this" tap on the Aurora
        // Chart Skin (or any future .chart cosmetic).
        .sheet(item: Binding(
            get: { pendingUsageChart.map { UsageProductID(value: $0) } },
            set: { newValue in pendingUsageChart = newValue?.value }
        )) { wrapper in
            ChartSkinPickerView()
                .environmentObject(registry)
                .environmentObject(storeManager)
        }
    }

    // MARK: - Live preview helpers

    /// Called from the global countdown overlay's "Stop Preview"
    /// button. Restores the original profile via the coordinator's
    /// snapshot so the live view goes back to the user's real
    /// palette / background / chart skin. Does *not* re-present
    /// the detail view — the user explicitly chose to stop, so
    /// we leave them on the live view they were previewing on.
    private func endActivePreviewFromOverlay() {
        // Phase 4 — also cancel the preview manager's
        // timer so it stops ticking immediately. Without
        // this, the manager's `activePreview` stays set
        // and the countdown timer keeps running in the
        // background until it reaches 0.
        previewManager.cancelPreviewTimer()
        if let snapshot = previewCoordinator.snapshotProfile {
            registry.apply(snapshot)
        }
        previewCoordinator.endPreview(reopenForProductID: nil)
    }

    // Phase 2 — wrapper for deep-link product IDs so the sheet
    // can drive its presentation off `Identifiable`. Defined at
    // file scope so the `Binding` above can refer to it without
    // a forward-declaration dance.

    // MARK: - Views
    
    private var mainWeatherView: some View {
        ZStack(alignment: .top) {
            backgroundLayer
            // Add a dark overlay for better contrast.
            // Phase 5: strength comes from the spec via the
            // resolver, which falls back to the free default
            // (0.28) when the IAP is locked.
            Color.black.opacity(currentOverlayOpacity)
                .blur(radius: 8)
                .ignoresSafeArea()
            if displayMode == "Detailed" {
                DetailedWeatherView(weatherService: weatherService)
            } else {
                contentLayer
            }

            // Banner shown at the top when at least one API key is
            // detected as invalid. Tap to jump to Settings → Weather Data.
            VStack {
                APIKeyHealthBanner(monitor: healthMonitor) {
                    selectedTab = 3
                }
                .animation(.easeInOut(duration: 0.25), value: healthMonitor.hasAnyBlockingIssue)
                Spacer()
            }
            .allowsHitTesting(healthMonitor.hasAnyBlockingIssue)

            // Top overlay: share (summary) on the left, hamburger on the right.
            if showShareButton || showHamburgerMenu {
                HStack {
                    if showShareButton,
                       let weather = weatherService.weather,
                       weather.hasData {
                        WeatherShareButton(
                            weather: weather,
                            displayLocationName: currentLocationText,
                            unitSystem: unitSystem,
                            weatherService: weatherService,
                            locationsManager: locationsManager
                        )
                    }

                    Spacer()

                    if showHamburgerMenu {
                        Button {
                            #if canImport(UIKit)
                            HapticFeedbackHelper.shared.light()
                            #endif
                            showingLocationMenu = true
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                                )
                                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                        }
                        .accessibilityLabel("Location Menu")
                        .accessibilityHint("Switch between saved locations")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .allowsHitTesting(true)
            }
        }
        // Removed duplicate .onAppear - already handled by TabView
        .sheet(isPresented: $showingLocationMenu) {
            HamburgerLocationMenuView(
                locationsManager: locationsManager,
                weatherService: weatherService,
                previewBeforeChangingLocation: SettingsBehaviour.previewBeforeChangingLocation,
                isLocationSwitchBlockedByAPIKeys: isLocationSwitchBlockedByAPIKeys,
                onRequestPreview: { request in
                    showingLocationMenu = false
                    presentLocationPreview(request)
                },
                onDismiss: { showingLocationMenu = false }
            )
        }
        .sheet(item: $selectedFeelsLikeMetric) { metric in
            WeatherMetricInfoContent(
                title: metric.title,
                value: metric.value,
                description: metric.description
            )
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
        // `swipeBetweenLocations` Behaviour setting — swipe
        // horizontally on the home screen to switch between
        // saved locations. Only fires when the user has more
        // than one saved location and the setting is on.
        .modifier(LocationSwipeModifier(
            enabled: SettingsBehaviour.swipeBetweenLocations,
            locationsManager: locationsManager,
            weatherService: weatherService,
            previewBeforeChangingLocation: SettingsBehaviour.previewBeforeChangingLocation
                && !isLocationSwitchBlockedByAPIKeys,
            onSwipeToLocation: { target in
                let coordinates = weatherService.currentLocation
                presentLocationPreview(
                    .locationPeek(savedLocation: target, coordinates: coordinates)
                )
            }
        ))
        // `experimentalSwipeRefresh` — register pull-to-refresh on
        // the whole home screen so it works outside the scroll view.
        // ScrollView keeps its own `.refreshable` so the system
        // control still appears when pulling inside the scroll area.
        .modifier(PullToRefreshModifier(
            enabled: SettingsBehaviour.pullToRefresh
                && SettingsBehaviour.experimentalSwipeRefresh,
            weatherService: weatherService
        ))
    }
    
    private var backgroundLayer: some View {
        // Phase 5 — resolve the active `BackgroundSpec` into a
        // `BackgroundStrategy` and hand it to the view. The
        // resolver is a pure function, so re-renders are cheap.
        let strategy = BackgroundResolver.resolve(
            condition: weatherService.currentBackgroundCondition,
            spec: registry.profile.knobs.background,
            sunrise: weatherService.forecast?.daily.first?.sunrise,
            sunset: weatherService.forecast?.daily.first?.sunset,
            now: Date(),
            customBackgroundUnlocked: storeManager.customBackgroundUnlocked,
            isCosmeticUnlocked: { id in
                storeManager.owns(id) || previewManager.isPreviewing(id)
            }
        )
        return BackgroundViewWrapper(strategy: strategy)
    }

    /// Effective overlay opacity, gated on the IAP. The view
    /// reads this instead of `@AppStorage("overlayOpacity")`
    /// directly so the free default (0.28) is used when the
    /// IAP is locked, even if the spec has a different value.
    private var currentOverlayOpacity: Double {
        BackgroundResolver.effectiveOverlayOpacity(
            spec: registry.profile.knobs.background,
            customBackgroundUnlocked: storeManager.customBackgroundUnlocked
        )
    }

    struct BackgroundViewWrapper: View {
        let strategy: BackgroundStrategy
        @EnvironmentObject var storeManager: StoreManager

        var body: some View {
            BackgroundView(strategy: strategy)
                .environmentObject(storeManager)
        }
    }
    
    private var contentLayer: some View {
        VStack {
            ScrollView {
                VStack {
                    weatherContent
                }
            }
            // Honour the `pullToRefresh` Behaviour setting. When
            // disabled the `.refreshable` modifier is omitted
            // entirely, so the system never shows the pull-down
            // spinner and a drag-down does nothing. When enabled
            // we also fire the user-configured
            // `vibrateOnPullToRefresh` / `refreshSound` /
            // `tapticOnRefresh` feedback on success.
            .modifier(PullToRefreshModifier(
                enabled: SettingsBehaviour.pullToRefresh,
                weatherService: weatherService
            ))
            footerView
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private var weatherContent: some View {
        Group {
            if let weather = weatherService.weather, weather.hasData {
                VStack(spacing: 8) {
                    // Location label - only show when appropriate
                    if shouldShowLocationText {
                        Text("Weather for \(currentLocationText)")
                            .accessibleFont(size: 14, weight: .medium)
                            .accessibleContrast()
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .padding(.top, 20)
                    }

                    if SettingsBehaviour.showHeroLastUpdated {
                        HeroLastUpdatedButton(weatherService: weatherService)
                    }
                    
                    #if os(macOS)
                    Spacer().frame(height: 48)
                    // Phase 6 — migrated to `ConditionIcon` so the
                    // iconography knobs in `IconographySpec` are
                    // honoured automatically.
                    ConditionIcon(condition: weather.condition, size: 100)
                        .frame(width: 100, height: 100)
                        .frame(maxWidth: .infinity, alignment: .center)
                    #else
                    ConditionIcon(condition: weather.condition, size: 150)
                        .frame(width: 150, height: 150)
                        .padding(.top, 10)
                        .frame(maxWidth: .infinity, alignment: .center)
                    #endif
                    
                    let unitSymbol = UnitSystem.from(rawValue: unitSystem).temperatureLabel
                    
                    // Current Temperature Display
                    if let temperature = weather.temperature {
                        #if os(macOS)
                        Text(String(format: "%.1f%@", temperature, unitSymbol))
                            .accessibleFont(size: 100, weight: .black, design: .rounded)
                            .accessibleContrast()
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
                            .shadow(color: Color.white.opacity(0.18), radius: 2, x: 0, y: 0)
                        #else
                        Text(String(format: "%.1f%@", temperature, unitSymbol))
                            .accessibleFont(size: 80, weight: .heavy)
                            .accessibleContrast()
                            .foregroundColor(.primary)
                            .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 2)
                        #endif
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
                        .accessibilityHint("Shows how this value was calculated")
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
                }
                .padding(.vertical, 30)  // Reduced from 50 to accommodate the animation

                // 20pt outer gap so the details card lines up
                // with the UV Index / Air Quality / Sun / Moon /
                // Precipitation / Pollen cards further down the
                // page. The `styledCard()` modifier's internal
                // `.frame(maxWidth: .infinity)` would otherwise
                // absorb the gap, so it has to live on the
                // call site.
                WeatherDetailsView(weather: weather)
                    .padding(.horizontal, 20)

                // Extended weather information
                ExtendedWeatherSection(weather: weather)
            } else if weatherService.isLoading {
                WeatherLoadingSkeleton()
            } else if let error = weatherService.error {
                ErrorView(weatherError: error) {
                    await weatherService.fetchWeather(calledFrom: "ErrorRetry")
                } onOpenSettings: {
                    AppSettingsRouter.open()
                }
            } else if !weatherService.hasValidDataSources() {
                VStack(spacing: 16) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Location Required")
                        .accessibleFont(size: 20, weight: .semibold)
                    
                    if !weatherService.useGPS {
                        Text("Please enable GPS or enter valid coordinates in Settings")
                            .accessibleFont(size: 15)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Open Settings") {
                            // Navigate to settings
                            showSettings = true
                        }
                        .accessibleFont(size: 16, weight: .medium)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    } else {
                        Text("Please enable location access in Settings")
                            .accessibleFont(size: 15)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Open Settings") {
                            weatherService.openSettings()
                        }
                        .accessibleFont(size: 16, weight: .medium)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
            } else {
                Text("Loading weather data...")
                    .accessibleFont(size: 16)
                    .foregroundColor(.primary)
                    .padding()
            }
        }
    }

    // Phase 6 — `getAnimationName(for:)` removed; `ConditionIcon`
    // resolves the animation name via `AnimationRegistry`.

    // Helper function to determine if it's nighttime
    private func isNighttime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour > 18
    }
    
    private var footerView: some View {
        VStack(spacing: 4) {
            // Weather data attribution (required for legal compliance)
            WeatherAttributionView(
                dataSource: weatherService.currentDataSource,
                stationID: UserDefaults.standard.string(forKey: "stationID")
            )
            
            // App credit
            Text("Made by Saxon")
                .accessibleFont(size: 12)
                .foregroundColor(.primary)
                .padding(.bottom, 10)
        }
    }
    
    private var temperatureUnit: String {
        UnitSystem.from(rawValue: unitSystem).temperatureLabel
    }
    
    private var selectedColorScheme: ColorScheme? {
        switch colorScheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return .dark
        }
    }
}

// MARK: - Forecast Container View (renamed to avoid conflict)
struct ForecastContainerView: View {
    @ObservedObject var weatherService: WeatherService
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if let forecast = weatherService.forecast {
                    if forecast.daily.isEmpty {
                        emptyForecastView
                    } else {
                        ForecastView(weatherService: weatherService)
                    }
                } else if let error = weatherService.error {
                    errorView(weatherError: error)
                } else {
                    loadingView
                }
            }
            .navigationTitle("Forecast")
        }
        .onAppear {
            if weatherService.forecast == nil {
                fetchForecast()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading forecast data...")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var emptyForecastView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("No forecast data available")
                .font(.headline)
            
            Text("Please check your location settings or try again later")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Refresh") {
                fetchForecast()
            }
            .accessibleFont(size: 16, weight: .medium)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
    
    private func errorView(weatherError: WeatherError) -> some View {
        let presentation = weatherError.presentation
        return VStack(spacing: 16) {
            Image(systemName: presentation.iconName)
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text(presentation.title)
                .font(.headline)

            Text(presentation.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                fetchForecast()
            }
            .accessibleFont(size: 16, weight: .medium)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)

            if !weatherService.useGPS {
                Button("Enable GPS Location") {
                    weatherService.useGPS = true
                    fetchForecast()
                }
                .accessibleFont(size: 16, weight: .medium)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private func fetchForecast() {
        isLoading = true
        Task {
            await weatherService.fetchForecasts()
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Weather Details View
struct WeatherDetailsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let weather: Weather
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    @State private var selectedMetric: WeatherMetricInfo?
    
    private var temperatureUnit: String {
        UnitSystem.from(rawValue: unitSystem).temperatureLabel
    }
    
    private var speedUnit: String {
        UnitSystem.from(rawValue: unitSystem).speedLabel
    }
    
    private var pressureUnit: String {
        UnitSystem.from(rawValue: unitSystem).pressureLabel
    }
    
    var body: some View {
        // Phase 9 — the details card picks up the user-configured
        // card style (glass, solid, outline, neumorphic), the
        // corner radius, the shadow, the tint wash, the border,
        // and the fill colour. The original iOS 26+ look can be
        // reproduced via the Card Settings submenu: Glass + corner
        // radius 24 + a `CardTintOverlay` set to the dark colour
        // + a shadow radius of 20 with y offset 10.
        VStack(spacing: 12) {
            ForEach(weatherMetrics, id: \.title) { metric in
                if let value = metric.value {
                    WeatherRowView(title: metric.title, value: value) {
                        selectedMetric = WeatherMetricInfo(
                            title: metric.title,
                            value: value,
                            description: WeatherMetricDescriptions.description(for: metric.title, unitSystem: unitSystem),
                            windDirection: metric.title == "Wind Speed" ? windDirection : nil
                        )
                    }
                        .transition(
                            .asymmetric(
                                insertion: .opacity
                                    .combined(with: .scale(scale: 0.92)),
                                removal: .opacity
                            )
                        )
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .allowsHitTesting(true)
        .styledCard()
        .sheet(item: $selectedMetric) { metric in
            WeatherMetricInfoContent(
                title: metric.title,
                value: metric.value,
                description: metric.description,
                windDirection: metric.windDirection
            )
            #if os(iOS)
            .presentationDetents(
                metric.windDirection != nil ? [.height(380)] : [.height(260)]
            )
            .presentationDragIndicator(.visible)
            #endif
        }
        .animation(
            .easeInOut(duration: 0.4),
            value: weatherMetrics.compactMap { $0.value }.count
        )
    }
    
    private var weatherMetrics: [(title: String, value: String?)] {
        [
            ("Humidity", weather.humidity.map { "\($0)%" }),
            ("Dew Point", weather.dewPoint.map { String(format: "%.1f%@", $0, temperatureUnit) }),
            ("Pressure", weather.pressure.map { String(format: "%.1f %@", $0, pressureUnit) }),
            ("Wind Speed", weather.windSpeed.map { String(format: "%.1f %@", $0, speedUnit) }),
            ("Wind Gust", weather.windGust.map { String(format: "%.1f %@", $0, speedUnit) }),
            ("UV Index", weather.uvIndex.map { "\($0)" }),
            ("Solar Radiation", weather.solarRadiation.map { "\($0) W/m²" })
        ]
    }

    private var windDirection: Double? {
        if let current = weather.currentWindDirection {
            return current
        }
        if let forecast = weather.forecasts.first {
            return Double(forecast.windDirection)
        }
        return nil
    }

}

// MARK: - Extended Weather Section
struct ExtendedWeatherSection: View {
    let weather: Weather
    @AppStorage("unitSystem") private var unitSystem: String = "Metric"
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            // Debug: Print what extended data is available (only in debug builds to avoid log spam on every render)
            #if DEBUG
            let _ = print("🔍 ExtendedWeatherSection rendering:")
            let _ = print("   - UV Index: \(weather.uvIndex != nil ? "\(weather.uvIndex!)" : "nil")")
            let _ = print("   - Air Quality: \(weather.airQuality != nil ? "AQI \(weather.airQuality!.aqi)" : "nil")")
            let _ = print("   - Sun Data: \(weather.sunData != nil ? "Available" : "nil")")
            let _ = print("   - Hourly Precip: \(weather.hourlyPrecipitation.count) items")
            #endif

            // What to Wear — rule-based suggestions from feels-like,
            // rain probability, wind, and UV.
            if let wearData = WhatToWearData.from(
                weather: weather,
                unitSystem: UnitSystem.from(rawValue: unitSystem)
            ) {
                WhatToWearCardView(data: wearData)
                    .padding(.horizontal, 20)
                    .transition(
                        .opacity.combined(with: .move(edge: .bottom))
                    )
            }

            // UV Index (enhanced with recommendations).
            // Each card slides up and fades in once its data
            // becomes available, so the extended info populates
            // smoothly rather than popping in.
            if let uvIndex = weather.uvIndex {
                let uvData = UVIndexData(uvIndex: uvIndex)
                UVIndexCardView(data: uvData)
                    .padding(.horizontal, 20)
                    .transition(
                        .opacity.combined(with: .move(edge: .bottom))
                    )
            } else {
                #if DEBUG
                let _ = print("❌ UV Index card NOT showing - uvIndex is nil")
                #endif
            }

            // Air Quality
            if let airQuality = weather.airQuality {
                AirQualityCardView(data: airQuality)
                    .padding(.horizontal, 20)
                    .transition(
                        .opacity.combined(with: .move(edge: .bottom))
                    )
            } else {
                #if DEBUG
                let _ = print("❌ Air Quality card NOT showing - airQuality is nil")
                #endif
            }

            // Sun/Moon Data
            if let sunData = weather.sunData {
                SunMoonCardView(data: sunData)
                    .padding(.horizontal, 20)
                    .transition(
                        .opacity.combined(with: .move(edge: .bottom))
                    )
            } else {
                #if DEBUG
                let _ = print("❌ Sun/Moon card NOT showing - sunData is nil")
                #endif
            }

            // Hourly Precipitation Graph
            if !weather.hourlyPrecipitation.isEmpty {
                PrecipitationGraphView(
                    hourlyData: weather.hourlyPrecipitation,
                    timeZoneIdentifier: weather.locationTimeZoneIdentifier
                )
                    .padding(.horizontal, 20)
                    .transition(
                        .opacity.combined(with: .move(edge: .bottom))
                    )
            } else {
                #if DEBUG
                let _ = print("❌ Precipitation card NOT showing - hourlyPrecipitation is empty")
                #endif
            }

            // Pollen Data
            if let pollen = weather.pollen {
                PollenCardView(data: pollen)
                    .padding(.horizontal, 20)
                    .transition(
                        .opacity.combined(with: .move(edge: .bottom))
                    )
            }
        }
        // Bind to the union of all the optional fields so any
        // individual card arrival triggers the same animation
        // curve used elsewhere in the app.
        .animation(
            .easeInOut(duration: 0.4),
            value: weather.uvIndex
        )
        .animation(
            .easeInOut(duration: 0.4),
            value: weather.airQuality?.aqi
        )
        .animation(
            .easeInOut(duration: 0.4),
            value: weather.sunData?.sunrise
        )
        .animation(
            .easeInOut(duration: 0.4),
            value: weather.hourlyPrecipitation.count
        )
        .animation(
            .easeInOut(duration: 0.4),
            value: weather.pollen?.tree
        )
        .animation(
            .easeInOut(duration: 0.4),
            value: weather.feelsLike
        )
        .animation(
            .easeInOut(duration: 0.4),
            value: weather.windSpeed
        )
    }
}

// MARK: - Weather Metric Info
struct WeatherMetricInfo: Identifiable {
    var id: String { title }
    let title: String
    let value: String
    let description: String
    var windDirection: Double? = nil
}

struct WeatherMetricInfoContent: View {
    let title: String
    let value: String
    let description: String
    var windDirection: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(WeatherMetricDescriptions.localizedTitle(for: title))
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(value)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
            }

            Divider()

            if let windDirection {
                VStack(spacing: 8) {
                    WindCompassView(
                        direction: windDirection,
                        size: .regular,
                        showCardinalLabel: false
                    )
                    Text("\(WindCompassView.cardinalAbbreviation(for: windDirection)) (\(String(format: "%.0f°", windDirection)))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            ScrollView {
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Weather Row View
struct WeatherRowView<Accessory: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let onTap: () -> Void
    @ViewBuilder let accessory: () -> Accessory

    init(
        title: String,
        value: String,
        onTap: @escaping () -> Void,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.title = title
        self.value = value
        self.onTap = onTap
        self.accessory = accessory
    }
    
    var body: some View {
        Button(action: onTap) {
            rowContent
                .frame(maxWidth: .infinity, minHeight: 39, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows an explanation of this measurement")
    }

    @ViewBuilder
    private var rowContent: some View {
        if #available(iOS 26.2, *) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ?
                            Color.white.opacity(0.6) :
                            Color.black.opacity(0.5)
                        )
                        .frame(width: 24)

                    Text(WeatherMetricDescriptions.localizedTitle(for: title))
                        .accessibleFont(size: 16, weight: .medium)
                        .accessibleContrast()
                        .foregroundStyle(colorScheme == .dark ?
                            Color.white.opacity(0.8) :
                            Color.black.opacity(0.7)
                        )
                }

                Spacer()

                HStack(spacing: 8) {
                    Text(value)
                        .accessibleFont(size: 16, weight: .semibold)
                        .accessibleContrast()
                        .foregroundStyle(colorScheme == .dark ?
                            Color.white.opacity(0.9) :
                            Color.black.opacity(0.8)
                        )

                    accessory()
                }

                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ?
                        Color.white.opacity(0.45) :
                        Color.black.opacity(0.35)
                    )
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        } else {
            HStack {
                Text(WeatherMetricDescriptions.localizedTitle(for: title))
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                Text(value)
                    .font(.body)
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal)
        }
    }
    
    // Icon mapping for each weather metric
    private var iconName: String {
        switch title {
        case "Humidity": return "humidity.fill"
        case "Dew Point": return "drop.fill"
        case "Pressure": return "gauge.with.dots.needle.bottom.50percent"
        case "Wind Speed": return "wind"
        case "Wind Gust": return "wind.snow"
        case "UV Index": return "sun.max.fill"
        case "Solar Radiation": return "sun.and.horizon.fill"
        default: return "questionmark.circle.fill"
        }
    }
}

extension WeatherRowView where Accessory == EmptyView {
    init(title: String, value: String, onTap: @escaping () -> Void) {
        self.init(title: title, value: value, onTap: onTap, accessory: { EmptyView() })
    }
}

// MARK: - Hamburger Location Menu

/// A sheet that lists the current GPS option and all saved locations, allowing
/// the user to quickly switch between them. Also offers a quick way to add a new
/// location via the existing map picker.
struct HamburgerLocationMenuView: View {
    @ObservedObject var locationsManager: SavedLocationsManager
    @ObservedObject var weatherService: WeatherService
    let previewBeforeChangingLocation: Bool
    let isLocationSwitchBlockedByAPIKeys: Bool
    let onRequestPreview: (LocationWeatherPreviewRequest) -> Void
    let onDismiss: () -> Void

    @AppStorage("disableAPIKeys") private var disableAPIKeys = false

    @State private var showingMapPicker = false
    @State private var mapSelectedLocation: CLLocationCoordinate2D? = nil
    @State private var mapSelectedLocationName: String? = nil
    @State private var showingAlert = false
    @State private var alertMessage = ""

    /// True when the user's Weather Underground configuration would override any
    /// saved/custom locations. In that case the menu is still shown but tapping a
    /// location shows an informational warning.
    private var wuApiKey: String {
        KeychainService.shared.getApiKey(forService: "wu") ?? ""
    }
    private var stationID: String {
        UserDefaults.standard.string(forKey: "stationID") ?? ""
    }
    private var isOverriddenByAPIKeys: Bool {
        isLocationSwitchBlockedByAPIKeys
    }

    private var shouldPreviewBeforeSwitching: Bool {
        previewBeforeChangingLocation && !isOverriddenByAPIKeys
    }

    private var isGPSSelected: Bool {
        if locationsManager.selectedLocation?.isCurrentLocation == true {
            return true
        }
        return weatherService.useGPS
    }

    var body: some View {
        NavigationView {
            List {
                if isOverriddenByAPIKeys {
                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("API Keys Active")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Custom locations below are currently ignored because a Weather Underground station is configured. Disable API keys in Settings → Locations to use saved locations.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    // Current Location (GPS)
                    locationRow(
                        systemImage: "location.fill",
                        tint: .blue,
                        title: String(localized: "Current Location (GPS)"),
                        subtitle: String(localized: "Use your device's GPS"),
                        isSelected: isGPSSelected,
                        isDisabled: false
                    ) {
                        handleLocationTap(locationsManager.currentLocationEntry)
                    }

                    if locationsManager.locations.isEmpty {
                        Text("No saved locations yet.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(locationsManager.locations) { location in
                            locationRow(
                                systemImage: "mappin.circle.fill",
                                tint: .accentColor,
                                title: location.name,
                                subtitle: String(
                                    format: String(localized: "Lat: %.4f, Lon: %.4f"),
                                    location.latitude,
                                    location.longitude
                                ),
                                isSelected: !weatherService.useGPS &&
                                    locationsManager.selectedLocation?.id == location.id,
                                isDisabled: false
                            ) {
                                handleLocationTap(location)
                            }
                            .onLongPressGesture(minimumDuration: 0.5) {
                                #if canImport(UIKit)
                                HapticFeedbackHelper.shared.medium()
                                #endif
                                onRequestPreview(
                                    .peekOnly(
                                        savedLocation: location,
                                        coordinates: weatherService.currentLocation
                                    )
                                )
                            }
                        }
                    }
                } header: {
                    Text("Switch Location")
                } footer: {
                    Text("Tap a location to use it. Weather will refresh automatically.")
                }

                if !isOverriddenByAPIKeys {
                    Section {
                        Button {
                            showingMapPicker = true
                        } label: {
                            Label("Add New Location", systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingMapPicker) {
                LocationPickerView(
                    selectedLocation: $mapSelectedLocation,
                    selectedLocationName: $mapSelectedLocationName
                )
                .onDisappear {
                    handleMapSelectionResult()
                }
            }
            .alert("Location", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func locationRow(
        systemImage: String,
        tint: Color,
        title: String,
        subtitle: String,
        isSelected: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundColor(tint)
                    .font(.title3)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }

    // MARK: - Selection Handlers

    private func handleLocationTap(_ location: SavedLocation) {
        if shouldPreviewBeforeSwitching {
            onRequestPreview(
                .locationPeek(
                    savedLocation: location,
                    coordinates: weatherService.currentLocation
                )
            )
            return
        }

        if location.isCurrentLocation {
            selectCurrentLocation()
        } else {
            selectLocation(location)
        }
    }

    private func selectCurrentLocation() {
        #if canImport(UIKit)
        HapticFeedbackHelper.shared.light()
        #endif
        locationsManager.selectCurrentLocation()
        weatherService.useGPS = true
        Task {
            await weatherService.fetchWeather(calledFrom: "HamburgerLocationMenuView.selectGPS")
        }
        onDismiss()
    }

    private func selectLocation(_ location: SavedLocation) {
        #if canImport(UIKit)
        HapticFeedbackHelper.shared.light()
        #endif
        locationsManager.selectLocation(location)
        weatherService.useGPS = false
        Task {
            await weatherService.fetchWeather(calledFrom: "HamburgerLocationMenuView.selectLocation")
        }
        onDismiss()
    }

    private func handleMapSelectionResult() {
        guard let location = mapSelectedLocation else {
            // User cancelled; nothing to do.
            return
        }

        let lat = location.latitude
        let lon = location.longitude
        let validationResult = CoordinateValidator.validate(latitude: lat, longitude: lon)

        guard validationResult.isValid else {
            alertMessage = validationResult.errorMessage ?? "Invalid coordinates. Please try again."
            showingAlert = true
            mapSelectedLocation = nil
            mapSelectedLocationName = nil
            return
        }

        let validatedLat = validationResult.normalizedLatitude ?? lat
        let validatedLon = validationResult.normalizedLongitude ?? lon
        let locationName = mapSelectedLocationName ?? "Selected Location"

        mapSelectedLocation = nil
        mapSelectedLocationName = nil
        onRequestPreview(
            .addLocation(
                name: locationName,
                latitude: validatedLat,
                longitude: validatedLon
            )
        )
    }
}

// MARK: - Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(StoreManager.shared)
            .environmentObject(SavedLocationsManager())
    }
}

struct HamburgerLocationMenuView_Previews: PreviewProvider {
    static var previews: some View {
        HamburgerLocationMenuView(
            locationsManager: SavedLocationsManager(),
            weatherService: WeatherService(),
            previewBeforeChangingLocation: true,
            isLocationSwitchBlockedByAPIKeys: false,
            onRequestPreview: { _ in },
            onDismiss: {}
        )
    }
}

// MARK: - Pull-to-refresh modifier
//
// Conditionally applies SwiftUI's `.refreshable` so the user can
// disable pull-to-refresh entirely from
// Settings, Behaviour, Gestures. When enabled, the modifier also
// fires the user-configured haptic / sound feedback when a refresh
// completes successfully.
struct PullToRefreshModifier: ViewModifier {
    let enabled: Bool
    @ObservedObject var weatherService: WeatherService

    func body(content: Content) -> some View {
        if enabled {
            content.refreshable {
                let errorBefore = weatherService.error
                await weatherService.fetchWeather(calledFrom: "PullToRefresh")
                // Trigger user feedback (haptic + sound) only when
                // the refresh actually succeeded.
                SettingsBehaviour.triggerRefreshFeedback(
                    success: weatherService.error == nil && errorBefore == nil
                )
            }
        } else {
            content
        }
    }
}

// MARK: - Location-swipe modifier
//
// Horizontal swipe gesture to switch between saved locations on
// the home screen. Honours the `swipeBetweenLocations` setting:
// when disabled the gesture is a no-op so the user can still
// scroll vertically without accidentally changing location.
//
// Also honours the `experimentalSwipeRefresh` setting: when on,
// the pull-to-refresh gesture works anywhere on the home screen
// (not just inside the scroll view). The implementation adds a
// scroll-only `.refreshable` so the system control still appears,
// but the gesture is registered on the whole ZStack so the
// off-scroll-view experiment works.
struct LocationSwipeModifier: ViewModifier {
    let enabled: Bool
    @ObservedObject var locationsManager: SavedLocationsManager
    @ObservedObject var weatherService: WeatherService
    let previewBeforeChangingLocation: Bool
    let onSwipeToLocation: (SavedLocation) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .simultaneousGesture(
                    DragGesture(minimumDistance: 60)
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            handleSwipe(translation: value.translation.width)
                        }
                )
        } else {
            content
        }
    }

    private func handleSwipe(translation: CGFloat) {
        guard abs(translation) > 60 else { return }
        let allOptions: [SavedLocation] = [locationsManager.currentLocationEntry] + locationsManager.locations
        guard allOptions.count > 1 else { return }
        let currentIndex = allOptions.firstIndex { option in
            if weatherService.useGPS {
                return option.isCurrentLocation
            } else if let selected = locationsManager.selectedLocation {
                return option.id == selected.id
            }
            return false
        } ?? 0
        let direction: Int = translation < 0 ? 1 : -1
        let next = (currentIndex + direction + allOptions.count) % allOptions.count
        let target = allOptions[next]
        #if canImport(UIKit)
        HapticFeedbackHelper.shared.light()
        #endif

        if previewBeforeChangingLocation {
            onSwipeToLocation(target)
            return
        }

        if target.isCurrentLocation {
            locationsManager.selectCurrentLocation()
            weatherService.useGPS = true
        } else {
            locationsManager.selectLocation(target)
            weatherService.useGPS = false
        }
        Task {
            await weatherService.fetchWeather(calledFrom: "LocationSwipeModifier")
        }
    }
}

