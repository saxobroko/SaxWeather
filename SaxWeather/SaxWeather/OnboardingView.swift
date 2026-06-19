//
//  OnboardingView.swift
//  SaxWeather
//
//  Overhauled: 2026-06-16
//  Modern paged onboarding that showcases every key feature
//  of the app (location, multiple locations, animations,
//  widgets, alerts, customization, optional API keys).
//

import SwiftUI
import CoreLocation
import UserNotifications
import Lottie

// MARK: - Notifications

extension Notification.Name {
    /// Posted by the onboarding "API Keys" step when the user
    /// taps the link-out button. `ContentView` listens for this
    /// and switches to the Settings tab.
    static let openSettingsToAPIKeys = Notification.Name("SaxWeather.openSettingsToAPIKeys")

    /// Posted by the debug menu's "Re-run Onboarding" button.
    /// `ContentView` listens for this and resets
    /// `isFirstLaunch` so the onboarding flow is re-presented
    /// immediately.
    static let debugRerunOnboarding = Notification.Name("SaxWeather.debugRerunOnboarding")
}

// MARK: - Root Onboarding View

struct OnboardingView: View {
    @Binding var isFirstLaunch: Bool
    @ObservedObject var weatherService: WeatherService
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("accentColor") private var accentColor: String = "blue"

    @State private var currentStep: Int = 0

    /// Total number of onboarding pages. Centralised here so
    /// the progress indicator, button enablement, and "Skip"
    /// visibility all stay in sync if a step is added/removed.
    private let totalSteps = 8

    /// Resolved accent color used for the progress indicator
    /// and primary action buttons. Kept here so the shared
    /// chrome and per-step content agree.
    private var accent: Color {
        OnboardingView.color(from: accentColor)
    }

    /// Surface color for cards and content blocks. Matches
    /// the main app's `cardBackgroundColor` pattern in
    /// `ForecastView` so the onboarding looks like part of
    /// the same product.
    private var cardBackground: Color {
        #if os(iOS)
        return colorScheme == .dark
            ? Color(UIColor.systemGray6)
            : Color.white
        #elseif os(macOS)
        return colorScheme == .dark
            ? Color(NSColor.windowBackgroundColor)
            : Color.white
        #endif
    }

    var body: some View {
        ZStack {
            // Clean, app-matching background. A subtle
            // vertical gradient with a hint of the user's
            // accent color at the top, fading into the
            // standard surface color. No heavy purple.
            onboardingBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: skip button (hidden on the final
                // "Ready" step).
                topBar

                // Paged content. Each step is its own subview
                // for readability and so previews can target
                // individual steps.
                TabView(selection: $currentStep) {
                    WelcomeStep(accent: accent, cardBackground: cardBackground)
                        .tag(0)
                    LocationStep(
                        weatherService: weatherService,
                        cardBackground: cardBackground,
                        onComplete: { advance() }
                    )
                    .tag(1)
                    MultipleLocationsStep(cardBackground: cardBackground)
                        .tag(2)
                    AnimationsStep(cardBackground: cardBackground)
                        .tag(3)
                    WidgetsStep(cardBackground: cardBackground)
                        .tag(4)
                    AlertsStep(cardBackground: cardBackground, onComplete: { advance() })
                        .tag(5)
                    CustomizationStep(cardBackground: cardBackground)
                        .tag(6)
                    APIKeysStep(
                        cardBackground: cardBackground,
                        onOpenSettings: { openAPISettings() }
                    )
                    .tag(7)
                    ReadyStep(
                        cardBackground: cardBackground,
                        accent: accent,
                        onGetStarted: { completeOnboarding() }
                    )
                    .tag(8)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentStep)

                // Bottom chrome: progress + back/next.
                bottomBar
            }
        }
        .preferredColorScheme(nil) // honour system Dark Mode
    }

    // MARK: Background

    private var onboardingBackground: some View {
        ZStack {
            // Base surface colour, matching the main app.
            (colorScheme == .dark
             ? Color(UIColor.systemBackground)
             : Color(UIColor.systemGroupedBackground))

            // Soft accent-tinted radial highlight at the top.
            // Gives the page a hint of personality without
            // overwhelming the content.
            RadialGradient(
                gradient: Gradient(colors: [
                    accent.opacity(colorScheme == .dark ? 0.18 : 0.12),
                    Color.clear
                ]),
                center: .top,
                startRadius: 20,
                endRadius: 500
            )
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 0.4), value: currentStep)
        .animation(.easeInOut(duration: 0.3), value: colorScheme)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            // Reserve space so the skip button is right-aligned
            // even when no back button is shown.
            Color.clear.frame(width: 1, height: 1)

            Spacer()

            if currentStep < totalSteps {
                Button("Skip") {
                    completeOnboarding()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(Color.primary.opacity(0.06))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 20) {
            // Custom progress indicator (capsule row).
            OnboardingProgressIndicator(
                currentStep: currentStep,
                totalSteps: totalSteps + 1,
                accent: accent
            )
            .padding(.horizontal, 20)

            // Back / Next row (hidden on the first and last
            // steps respectively - those steps surface their
            // own primary action).
            HStack(spacing: 12) {
                if currentStep > 0 {
                    Button(action: goBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.primary.opacity(0.08))
                        )
                    }
                }

                if currentStep < totalSteps {
                    Button(action: advance) {
                        HStack(spacing: 6) {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(accent)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: Navigation helpers

    private func advance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            currentStep = min(currentStep + 1, totalSteps)
        }
    }

    private func goBack() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            currentStep = max(currentStep - 1, 0)
        }
    }

    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isFirstLaunch = false
        }
        // Kick off the first weather fetch so the main UI
        // has data ready when it appears.
        Task {
            await weatherService.fetchWeather(calledFrom: "OnboardingView.completeOnboarding")
        }
    }

    private func openAPISettings() {
        // Set the flag first so the main UI shows, then post
        // the notification that ContentView listens for to
        // switch to the Settings tab.
        withAnimation(.easeInOut(duration: 0.4)) {
            isFirstLaunch = false
        }
        Task {
            await weatherService.fetchWeather(calledFrom: "OnboardingView.openAPISettings")
        }
        // Defer the notification slightly so ContentView has
        // time to mount the TabView.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .openSettingsToAPIKeys, object: nil)
        }
    }

    // MARK: Static helpers

    /// Map the user's accent color preference string to a
    /// SwiftUI `Color`. Mirrors the resolution logic in
    /// `SaxWeatherApp` so the onboarding matches the rest
    /// of the app.
    static func color(from name: String) -> Color {
        switch name.lowercased() {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "teal": return .teal
        case "cyan": return .cyan
        case "indigo": return .indigo
        default: return .blue
        }
    }
}

// MARK: - Progress Indicator

private struct OnboardingProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep ? accent : Color.primary.opacity(0.15))
                    .frame(width: index == currentStep ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel("Onboarding step \(currentStep + 1) of \(totalSteps)")
    }
}

// MARK: - Shared step chrome

/// Wraps each step with a consistent layout: hero icon
/// (with a soft glow), title, description, and an optional
/// action area. Keeps the per-step subviews focused on their
/// unique content.
private struct OnboardingStepContainer<Content: View>: View {
    let icon: String
    let iconColors: [Color]
    let title: String
    let subtitle: String?
    let cardBackground: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 12)

            // Hero icon with a soft glow halo. Uses the
            // per-step gradient colours to give each page
            // a subtle identity.
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: iconColors.map { $0.opacity(0.25) } + [Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 8)

                Image(systemName: icon)
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.bottom, 4)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 16))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 24)

            content()
                .padding(.horizontal, 20)

            Spacer()
        }
    }
}

/// Small card-style container used inside steps for feature
/// pills, mock lists, widget previews, etc. Matches the main
/// app's card aesthetic (white surface in light mode,
/// systemGray6 in dark mode, rounded corners, subtle shadow).
private struct OnboardingCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let background: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(
                color: colorScheme == .dark
                    ? .black.opacity(0.3)
                    : .gray.opacity(0.15),
                radius: 8,
                x: 0,
                y: 2
            )
    }
}

// MARK: - Step 0: Welcome

private struct WelcomeStep: View {
    let accent: Color
    let cardBackground: Color

    var body: some View {
        OnboardingStepContainer(
            icon: "cloud.sun.fill",
            iconColors: [accent, accent.opacity(0.6)],
            title: "Welcome to SaxWeather",
            subtitle: "Beautiful, accurate weather forecasts powered by Apple Weather, Open-Meteo, and your favourite weather stations.",
            cardBackground: cardBackground
        ) {
            VStack(spacing: 10) {
                FeaturePill(icon: "sparkles", text: "Stunning animations", accent: accent)
                FeaturePill(icon: "location.fill", text: "GPS & saved locations", accent: accent)
                FeaturePill(icon: "bell.badge.fill", text: "Severe weather alerts", accent: accent)
                FeaturePill(icon: "square.grid.2x2.fill", text: "Home screen widgets", accent: accent)
            }
            .padding(.top, 8)
        }
    }
}

private struct FeaturePill: View {
    let icon: String
    let text: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accent)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

// MARK: - Step 1: Location

private struct LocationStep: View {
    @ObservedObject var weatherService: WeatherService
    let cardBackground: Color
    let onComplete: () -> Void

    @State private var locationPermissionGranted = false
    @State private var locationDenied = false

    var body: some View {
        OnboardingStepContainer(
            icon: "location.circle.fill",
            iconColors: [.green, .teal],
            title: "Enable Location",
            subtitle: "Get accurate weather for where you are right now. You can add more locations any time.",
            cardBackground: cardBackground
        ) {
            VStack(spacing: 12) {
                if locationDenied {
                    // Permission explicitly denied. Show the
                    // "Open Settings" path. Mirrors the
                    // pre-overhaul behaviour so users aren't
                    // stuck on a dead-end "Next" button.
                    VStack(spacing: 10) {
                        Text("SaxWeather needs location access to show weather for where you are. You can add a location manually later in Settings.")
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        Button(action: { AppSettingsRouter.open() }) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Open Settings")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: 280)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange)
                            )
                        }
                    }
                } else {
                    Button(action: requestLocationPermission) {
                        HStack {
                            Image(systemName: locationPermissionGranted ? "checkmark.circle.fill" : "location.fill")
                            Text(locationPermissionGranted ? "Location Enabled" : "Enable Location")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(locationPermissionGranted ? Color.green : Color.blue)
                        )
                    }
                    .disabled(locationPermissionGranted)
                }
            }
        }
        .onAppear { checkLocationPermission() }
    }

    // MARK: Location permission helpers

    private func requestLocationPermission() {
        let status = weatherService.locationManager.authorizationStatus

        #if os(iOS)
        switch status {
        case .notDetermined:
            weatherService.locationManager.requestWhenInUseAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                checkLocationPermission()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            withAnimation { locationPermissionGranted = true }
            weatherService.useGPS = true
        case .denied, .restricted:
            withAnimation { locationDenied = true }
        @unknown default:
            break
        }
        #elseif os(macOS)
        switch status {
        case .notDetermined:
            weatherService.locationManager.requestAlwaysAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                checkLocationPermission()
            }
        case .authorized:
            withAnimation { locationPermissionGranted = true }
            weatherService.useGPS = true
        case .denied, .restricted:
            withAnimation { locationDenied = true }
        @unknown default:
            break
        }
        #endif
    }

    private func checkLocationPermission() {
        let status = weatherService.locationManager.authorizationStatus

        #if os(iOS)
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            withAnimation {
                locationPermissionGranted = true
                locationDenied = false
            }
            weatherService.useGPS = true
        } else if status == .denied || status == .restricted {
            withAnimation { locationDenied = true }
        }
        #elseif os(macOS)
        if status == .authorized {
            withAnimation {
                locationPermissionGranted = true
                locationDenied = false
            }
            weatherService.useGPS = true
        } else if status == .denied || status == .restricted {
            withAnimation { locationDenied = true }
        }
        #endif
    }
}

// MARK: - Step 2: Multiple Locations

private struct MultipleLocationsStep: View {
    let cardBackground: Color

    var body: some View {
        OnboardingStepContainer(
            icon: "mappin.and.ellipse",
            iconColors: [.blue, .cyan],
            title: "Track Multiple Locations",
            subtitle: "Save your favourite spots (home, work, a holiday destination) and switch between them with a tap.",
            cardBackground: cardBackground
        ) {
            VStack(spacing: 8) {
                MockLocationRow(icon: "location.fill", name: "Current Location", subtitle: "GPS", isPrimary: true, cardBackground: cardBackground)
                MockLocationRow(icon: "house.fill", name: "Home", subtitle: "Melbourne, AU", isPrimary: false, cardBackground: cardBackground)
                MockLocationRow(icon: "briefcase.fill", name: "Work", subtitle: "Sydney, AU", isPrimary: false, cardBackground: cardBackground)
                MockLocationRow(icon: "airplane", name: "Holiday", subtitle: "Tokyo, JP", isPrimary: false, cardBackground: cardBackground)

                Text("Add as many as you like in Settings, then Locations.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }
}

private struct MockLocationRow: View {
    let icon: String
    let name: String
    let subtitle: String
    let isPrimary: Bool
    let cardBackground: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isPrimary ? .white : .blue)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(isPrimary ? Color.blue : Color.blue.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isPrimary {
                Text("Active")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Color.blue)
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isPrimary ? Color.blue.opacity(0.08) : Color.primary.opacity(0.04))
        )
    }
}

// MARK: - Step 3: Animations

private struct AnimationsStep: View {
    let cardBackground: Color

    /// All available Lottie animations in the bundle. Kept
    /// in sync with the `Lottie Animations` folder.
    private let animations: [(name: String, label: String)] = [
        ("clear-day", "Clear"),
        ("cloudy", "Cloudy"),
        ("rainy", "Rain"),
        ("thunderstorm", "Storm"),
        ("snowy", "Snow"),
        ("foggy", "Fog")
    ]

    var body: some View {
        OnboardingStepContainer(
            icon: "sparkles",
            iconColors: [.orange, .yellow],
            title: "Beautiful Animations",
            subtitle: "Every condition is brought to life with smooth, hand-crafted animations.",
            cardBackground: cardBackground
        ) {
            VStack(spacing: 12) {
                // Grid of Lottie previews so the user can
                // see the variety of animations the app uses.
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(animations, id: \.name) { animation in
                        AnimationTile(
                            name: animation.name,
                            label: animation.label,
                            cardBackground: cardBackground
                        )
                    }
                }

                Text("Animations adapt to the current weather and time of day.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct AnimationTile: View {
    let name: String
    let label: String
    let cardBackground: Color

    var body: some View {
        VStack(spacing: 6) {
            LottieView(name: name, loopMode: .loop)
                .frame(width: 70, height: 70)
                .accessibilityLabel("\(label) animation preview")

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Step 4: Widgets

private struct WidgetsStep: View {
    let cardBackground: Color

    var body: some View {
        OnboardingStepContainer(
            icon: "square.grid.2x2.fill",
            iconColors: [.orange, .red],
            title: "Home Screen Widgets",
            subtitle: "Pin the weather to your Home Screen and Lock Screen with gorgeous, always up to date widgets.",
            cardBackground: cardBackground
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    MockWidgetCard(size: "Small", cardBackground: cardBackground) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Melbourne")
                                .font(.system(size: 11, weight: .semibold))
                                .opacity(0.7)
                            Text("22°")
                                .font(.system(size: 32, weight: .bold))
                            Text("Sunny")
                                .font(.system(size: 11))
                                .opacity(0.7)
                        }
                    }

                    MockWidgetCard(size: "Medium", cardBackground: cardBackground) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Melbourne")
                                    .font(.system(size: 11, weight: .semibold))
                                    .opacity(0.7)
                                Text("22°")
                                    .font(.system(size: 32, weight: .bold))
                                Text("Sunny, H:25 L:14")
                                    .font(.system(size: 10))
                                    .opacity(0.7)
                            }
                            Spacer()
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.orange)
                        }
                    }
                }

                Text("Add widgets from the iOS widget gallery after setup.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct MockWidgetCard<Content: View>: View {
    let size: String
    let cardBackground: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .foregroundColor(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(
            color: Color.gray.opacity(0.15),
            radius: 6,
            x: 0,
            y: 2
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(size) widget preview")
    }
}

// MARK: - Step 5: Alerts

private struct AlertsStep: View {
    let cardBackground: Color
    let onComplete: () -> Void

    @State private var notificationPermissionGranted = false
    @State private var notificationDenied = false
    @State private var isRequesting = false

    var body: some View {
        OnboardingStepContainer(
            icon: "bell.badge.fill",
            iconColors: [.red, .pink],
            title: "Severe Weather Alerts",
            subtitle: "Get notified the moment dangerous weather heads your way: storms, floods, extreme heat, and more.",
            cardBackground: cardBackground
        ) {
            VStack(spacing: 12) {
                if notificationDenied {
                    VStack(spacing: 10) {
                        Text("Notifications are off. You can enable them any time in Settings, then Notifications, then SaxWeather.")
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        Button(action: { AppSettingsRouter.open() }) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Open Settings")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: 280)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange)
                            )
                        }
                    }
                } else {
                    Button(action: requestNotificationPermission) {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Image(systemName: notificationPermissionGranted ? "checkmark.circle.fill" : "bell.fill")
                            }
                            Text(notificationPermissionGranted ? "Alerts Enabled" : "Enable Alerts")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(notificationPermissionGranted ? Color.green : Color.red)
                        )
                    }
                    .disabled(notificationPermissionGranted || isRequesting)
                }

                Text("You can change this any time in Settings.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .onAppear { checkNotificationPermission() }
    }

    private func requestNotificationPermission() {
        isRequesting = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                isRequesting = false
                if let error {
                    print("⚠️ Notification permission error: \(error.localizedDescription)")
                }
                if granted {
                    withAnimation { notificationPermissionGranted = true }
                } else {
                    withAnimation { notificationDenied = true }
                }
            }
        }
    }

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    notificationPermissionGranted = true
                case .denied:
                    notificationDenied = true
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}

// MARK: - Step 6: Customization

private struct CustomizationStep: View {
    let cardBackground: Color

    var body: some View {
        OnboardingStepContainer(
            icon: "paintbrush.fill",
            iconColors: [.pink, .purple],
            title: "Make It Yours",
            subtitle: "Personalise the look, the units, and the data sources to match your style.",
            cardBackground: cardBackground
        ) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    CustomizationTile(
                        icon: "photo.fill",
                        title: "Backgrounds",
                        subtitle: "Stunning weather-themed photos",
                        tint: .blue,
                        cardBackground: cardBackground
                    )
                    CustomizationTile(
                        icon: "drop.fill",
                        title: "Accent",
                        subtitle: "9 colour options",
                        tint: .purple,
                        cardBackground: cardBackground
                    )
                }

                HStack(spacing: 10) {
                    CustomizationTile(
                        icon: "thermometer",
                        title: "Units",
                        subtitle: "Metric, Imperial, UK",
                        tint: .orange,
                        cardBackground: cardBackground
                    )
                    CustomizationTile(
                        icon: "slider.horizontal.3",
                        title: "Sources",
                        subtitle: "Apple, WU, Open-Meteo",
                        tint: .green,
                        cardBackground: cardBackground
                    )
                }

                Text("All tweakable in Settings, then Appearance.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct CustomizationTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let cardBackground: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(tint)
                )
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Step 7: API Keys (optional)

private struct APIKeysStep: View {
    let cardBackground: Color
    let onOpenSettings: () -> Void

    var body: some View {
        OnboardingStepContainer(
            icon: "key.fill",
            iconColors: [.yellow, .orange],
            title: "Optional: API Keys",
            subtitle: "Add a Weather Underground or OpenWeatherMap key for hyper-local station data. Not required: Apple Weather and Open-Meteo work great out of the box.",
            cardBackground: cardBackground
        ) {
            VStack(spacing: 12) {
                Button(action: onOpenSettings) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                        Text("Add API Keys in Settings")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
                }

                Text("Stored securely in your iOS Keychain.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Step 8: Ready

private struct ReadyStep: View {
    let cardBackground: Color
    let accent: Color
    let onGetStarted: () -> Void

    var body: some View {
        OnboardingStepContainer(
            icon: "checkmark.circle.fill",
            iconColors: [.green, .mint],
            title: "You're All Set!",
            subtitle: "Enjoy beautiful, accurate weather forecasts.",
            cardBackground: cardBackground
        ) {
            VStack(spacing: 12) {
                Button(action: onGetStarted) {
                    HStack {
                        Text("Get Started")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 300)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(accent)
                    )
                    .shadow(color: accent.opacity(0.3), radius: 10, x: 0, y: 4)
                }

                Text("You can revisit this tour any time from the Debug menu.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Previews

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isFirstLaunch: .constant(true), weatherService: WeatherService())
            .environmentObject(StoreManager.shared)
    }
}
