//
//  ErrorView.swift
//  SaxWeather
//
//  Created on 13/01/2026
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// User-friendly, type-safe error display.
///
/// Pass a [`WeatherError`] and (optionally) callbacks for the
/// suggested primary action. The view picks the right icon, title
/// and message via [`WeatherError.presentation`], so adding a new
/// error case is impossible without providing presentation.
///
/// The retry button uses a [`RetryPolicy`] (default 1s → 2s → 4s)
/// to avoid hammering the API when the user taps repeatedly.
/// While a backoff is in flight, the button shows a live
/// countdown ("Retrying in 2s…") and a spinner. After the policy's
/// `maxAttempts` the button reverts to "Try Again" without any
/// further delay so a determined user is never blocked.
struct ErrorView: View {
    let weatherError: WeatherError
    let onRetry: (() async -> Void)?
    let onOpenSettings: (() -> Void)?
    let retryPolicy: RetryPolicy

    @State private var isRetrying = false
    @State private var attemptCount = 0
    @State private var secondsRemaining: Int = 0

    init(
        weatherError: WeatherError,
        onRetry: (() async -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        retryPolicy: RetryPolicy = .default
    ) {
        self.weatherError = weatherError
        self.onRetry = onRetry
        self.onOpenSettings = onOpenSettings
        self.retryPolicy = retryPolicy
    }

    /// Backwards-compatible initializer for callers that only have
    /// a string. Wraps the message in a generic `.apiError` case so
    /// new code can move to the typed initializer at its leisure.
    @available(*, deprecated, message: "Use the WeatherError initializer so the UI can show a category-specific message.")
    init(error: String, onRetry: @escaping () async -> Void) {
        self.weatherError = .apiError(error)
        self.onRetry = onRetry
        self.onOpenSettings = nil
        self.retryPolicy = .default
    }

    private var presentation: ErrorPresentation {
        weatherError.presentation
    }

    /// The retry policy that actually drives the backoff. The
    /// per-error `presentation.retryPolicy` wins when set
    /// (e.g. a 429 uses the server's `Retry-After` hint), then
    /// the view-level `retryPolicy` parameter, then `RetryPolicy.default`.
    private var effectiveRetryPolicy: RetryPolicy {
        presentation.retryPolicy ?? retryPolicy
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Error icon
            Image(systemName: presentation.iconName)
                .font(.system(size: 60))
                .foregroundColor(.red.opacity(0.8))
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                // User-friendly title
                Text(presentation.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                // Helpful message
                Text(presentation.message)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Primary action button. We render a single button whose
            // label and action depend on the error's suggested
            // action. This avoids the confusing situation of two
            // buttons competing for the user's attention.
            primaryActionButton

            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        switch presentation.suggestedAction {
        case .retry:
            if let onRetry = onRetry {
                Button {
                    startRetry(onRetry: onRetry)
                } label: {
                    retryButtonLabel
                }
                .disabled(isRetrying)
                .accessibilityLabel(isRetrying ? "Retrying, please wait" : "Try again")
            }
        case .openSettings:
            Button {
                #if canImport(UIKit)
                HapticFeedbackHelper.shared.light()
                #endif
                if let onOpenSettings = onOpenSettings {
                    onOpenSettings()
                } else {
                    AppSettingsRouter.open()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        case .none:
            EmptyView()
        }
    }

    /// Label of the retry button. Three states:
    ///   * Idle     – "Try Again" with `arrow.clockwise` icon
    ///   * Waiting  – spinner + live countdown "Retrying in 2s…"
    ///   * Firing   – spinner + "Retrying…" (last second)
    @ViewBuilder
    private var retryButtonLabel: some View {
        HStack(spacing: 8) {
            if isRetrying {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            } else {
                Image(systemName: "arrow.clockwise")
            }
            Text(retryButtonText)
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 32)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    private var retryButtonText: String {
        if isRetrying {
            return secondsRemaining > 0
                ? "Retrying in \(secondsRemaining)s\u{2026}"
                : "Retrying\u{2026}"
        }
        return "Try Again"
    }

    /// Start a single retry cycle. Increments `attemptCount`,
    /// waits for the *effective* policy's delay (showing a live
    /// countdown), then invokes the user's `onRetry` closure.
    /// The Task is not stored — SwiftUI tears down the view when
    /// it goes away, and the `secondsRemaining` write becomes a
    /// no-op.
    private func startRetry(onRetry: @escaping () async -> Void) {
        attemptCount += 1
        let delay = effectiveRetryPolicy.delay(forAttempt: attemptCount)
        isRetrying = true
        #if canImport(UIKit)
        HapticFeedbackHelper.shared.light()
        #endif
        Task {
            // Live countdown for UX. We sleep one second at a
            // time so `secondsRemaining` updates visibly; for
            // very long delays (e.g. a 429 with Retry-After: 60)
            // the cap in `RetryPolicy.delay` keeps the total
            // bounded.
            var remaining = Int(delay)
            while remaining > 0 {
                secondsRemaining = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                remaining -= 1
            }
            secondsRemaining = 0
            await onRetry()
            isRetrying = false
        }
    }
}

/// Compact inline error display. Useful for inline form errors or
/// banner-style messages. Takes a [`WeatherError`] so the icon and
/// color reflect the category, but accepts a `String` for
/// backwards-compat with existing call sites.
struct InlineErrorView: View {
    let weatherError: WeatherError?
    let fallbackMessage: String?
    let onDismiss: (() -> Void)?

    init(weatherError: WeatherError, onDismiss: (() -> Void)? = nil) {
        self.weatherError = weatherError
        self.fallbackMessage = nil
        self.onDismiss = onDismiss
    }

    init(message: String, onDismiss: (() -> Void)? = nil) {
        self.weatherError = nil
        self.fallbackMessage = message
        self.onDismiss = onDismiss
    }

    private var displayMessage: LocalizedStringResource {
        // Prefer the typed `WeatherError` presentation (which
        // resolves from the localization catalog). If the
        // caller supplied a plain `String` fallback, build an
        // ad-hoc `LocalizedStringResource` with the same
        // defaultValue so the behavior is consistent.
        if let message = weatherError?.presentation.message {
            return message
        }
        let fallback = fallbackMessage ?? "Something went wrong"
        // The `defaultValue` parameter is typed as
        // `String.LocalizationValue` (an opaque type backed by
        // an `ExpressibleByStringInterpolation` conformance).
        // Wrapping `fallback` in a string-literal interpolation
        // lets the compiler coerce `String` → `String.LocalizationValue`
        // without an explicit initializer.
        return LocalizedStringResource("error.inline.fallback", defaultValue: "\(fallback)")
    }

    private var displayIcon: String {
        weatherError?.presentation.iconName ?? "exclamationmark.circle.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: displayIcon)
                .foregroundColor(.red)

            Text(displayMessage)
                .font(.system(size: 14))
                .foregroundColor(.primary)

            Spacer()

            if let onDismiss = onDismiss {
                Button(action: {
                    #if canImport(UIKit)
                    HapticFeedbackHelper.shared.light()
                    #endif
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Settings deep link helper

/// Centralised helper for opening the system Settings app. Lives
/// here (rather than in a settings-specific file) because both the
/// `ErrorView` and the location-permission alert need to trigger
/// it.
enum AppSettingsRouter {
    /// Open the app's page in the system Settings app. Safe to
    /// call on iOS, iPadOS, and macOS (Catalyst).
    static func open() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}

// MARK: - Previews

#Preview("Network error") {
    ZStack {
        Color.blue.opacity(0.3).ignoresSafeArea()
        ErrorView(weatherError: .noNetwork, onRetry: { print("retry") })
    }
}

#Preview("Location denied") {
    ZStack {
        Color.blue.opacity(0.3).ignoresSafeArea()
        ErrorView(weatherError: .locationDenied, onOpenSettings: { print("settings") })
    }
}

#Preview("Stale data") {
    ZStack {
        Color.blue.opacity(0.3).ignoresSafeArea()
        ErrorView(weatherError: .staleData(age: 3_600), onRetry: { print("retry") })
    }
}

#Preview("Immediate retry (no backoff)") {
    ZStack {
        Color.blue.opacity(0.3).ignoresSafeArea()
        ErrorView(
            weatherError: .apiError("Boom"),
            onRetry: { print("retry") },
            retryPolicy: .immediate
        )
    }
}

#Preview("Inline Error") {
    InlineErrorView(weatherError: .noNetwork) {
        print("Dismissed")
    }
}
