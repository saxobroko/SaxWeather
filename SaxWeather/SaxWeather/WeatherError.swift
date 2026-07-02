//
//  WeatherError.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-02-25 04:46:29
//

import Foundation
import CoreLocation

enum WeatherError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case invalidAPIKey
    /// 401 Unauthorized – key was rejected by the provider
    /// (often because the user revoked it from their account).
    case apiKeyRevoked(service: String)
    /// 403 Forbidden – key is valid in form, but access is denied
    /// (e.g. account suspended, billing issue, IP blocked).
    case apiKeyForbidden(service: String)
    /// 429 Too Many Requests – key works but quota is exhausted.
    case apiKeyQuotaExceeded(service: String)
    case apiError(String)
    case decodingError(String)
    case noData

    // MARK: - HTTP status

    case httpError(statusCode: Int, retryAfter: TimeInterval?)

    // MARK: - Network reachability

    /// The device has no usable network path. This is distinct from
    /// `apiError` so the UI can suggest a connectivity fix rather
    /// than retrying the API call.
    case noNetwork
    /// The request took longer than the caller is willing to wait.
    case timeout
    /// We have a cached value, but it is older than the caller
    /// considers acceptable. `age` is in seconds.
    case staleData(age: TimeInterval)

    // MARK: - Location

    /// The user (or device) has denied location access. The UI
    /// should offer an "Open Settings" deep link.
    case locationDenied
    /// Location is restricted (parental controls, MDM profile, etc).
    /// The user cannot enable this themselves.
    case locationRestricted
    /// CoreLocation returned a transient error (e.g. can't fix).
    case locationUnavailable

    // MARK: - Legacy string description

    /// Human-friendly text suitable for logs and developer-facing
    /// messages. Prefer `ErrorPresentation.message` for the UI.
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidAPIKey:
            return "Invalid API key"
        case .apiKeyRevoked(let service):
            return "Your \(displayName(for: service)) API key was rejected (it may have been revoked). Please re-enter a valid key in Settings."
        case .apiKeyForbidden(let service):
            return "Access to \(displayName(for: service)) was denied. Your account may be suspended or out of quota."
        case .apiKeyQuotaExceeded(let service):
            return "You've hit the \(displayName(for: service)) request limit. Try again later or upgrade your plan."
        case .apiError(let message):
            return "API error: \(message)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .noData:
            return "No weather data available"
        case .httpError(let statusCode, let retryAfter):
            if let retryAfter = retryAfter {
                return "HTTP \(statusCode) — retry in \(Int(retryAfter))s"
            }
            return "HTTP \(statusCode)"
        case .noNetwork:
            return "No internet connection"
        case .timeout:
            return "The request timed out"
        case .staleData(let age):
            let minutes = Int(age / 60)
            return "Cached weather is \(minutes) minute\(minutes == 1 ? "" : "s") old"
        case .locationDenied:
            return "Location access is denied"
        case .locationRestricted:
            return "Location services are restricted"
        case .locationUnavailable:
            return "Couldn't determine your location"
        }
    }

    // MARK: - UI presentation

    var presentation: ErrorPresentation {
        switch self {
        case .invalidURL, .decodingError, .apiError:
            return ErrorPresentation(
                iconName: "exclamationmark.triangle.fill",
                title: LocalizedStringResource("error.generic.title", defaultValue: "Something Went Wrong"),
                message: LocalizedStringResource("error.generic.message", defaultValue: "We hit an unexpected problem fetching the weather. Please try again."),
                isRetryable: true,
                suggestedAction: .retry
            )
        case .invalidResponse:
            return ErrorPresentation(
                iconName: "exclamationmark.triangle.fill",
                title: LocalizedStringResource("error.invalidResponse.title", defaultValue: "Bad Server Response"),
                message: LocalizedStringResource("error.invalidResponse.message", defaultValue: "The weather service sent back something we didn't expect. Please try again in a moment."),
                isRetryable: true,
                suggestedAction: .retry
            )
        case .invalidAPIKey, .apiKeyRevoked, .apiKeyForbidden:
            return ErrorPresentation(
                iconName: "key.slash.fill",
                title: LocalizedStringResource("error.apiKey.title", defaultValue: "API Key Issue"),
                message: LocalizedStringResource("error.apiKey.message", defaultValue: "One of your weather service keys is invalid or has been revoked. Open Settings to update it."),
                isRetryable: false,
                suggestedAction: .openSettings
            )
        case .apiKeyQuotaExceeded:
            return ErrorPresentation(
                iconName: "hourglass",
                title: LocalizedStringResource("error.apiKeyQuota.title", defaultValue: "Rate Limit Reached"),
                message: LocalizedStringResource("error.apiKeyQuota.message", defaultValue: "You've used up your request quota for this service. Try again later or upgrade your plan."),
                isRetryable: true,
                suggestedAction: .retry
            )
        case .noData:
            return ErrorPresentation(
                iconName: "tray.fill",
                title: LocalizedStringResource("error.noData.title", defaultValue: "No Weather Data"),
                message: LocalizedStringResource("error.noData.message", defaultValue: "There's no weather data to show for this location yet. Open the app to refresh."),
                isRetryable: true,
                suggestedAction: .retry
            )
        case .httpError(let statusCode, let retryAfter):
            switch statusCode {
            case 401, 403:
                // Auth issues: don't retry, send the user to
                // settings to fix the key.
                return ErrorPresentation(
                    iconName: "key.slash.fill",
                    title: LocalizedStringResource("error.httpAuth.title", defaultValue: "Service Unavailable"),
                    message: LocalizedStringResource("error.httpAuth.message", defaultValue: "The weather service rejected the request. Open Settings to verify your API key."),
                    isRetryable: false,
                    suggestedAction: .openSettings
                )
            case 404:
                // 404: the location or endpoint doesn't exist.
                // Retrying with the same input is pointless.
                return ErrorPresentation(
                    iconName: "questionmark.circle.fill",
                    title: LocalizedStringResource("error.httpNotFound.title", defaultValue: "Not Found"),
                    message: LocalizedStringResource("error.httpNotFound.message", defaultValue: "The weather service couldn't find this location. Try a different one."),
                    isRetryable: false,
                    suggestedAction: .none
                )
            case 429:
                // Rate limited: respect the Retry-After hint
                // when the server provides one, fall back to
                // a long default.
                let policy = retryAfter.map { delay in
                    RetryPolicy(
                        maxAttempts: 3,
                        baseDelay: delay,
                        maxDelay: max(delay, 60),
                        backoffMultiplier: 1.5
                    )
                } ?? RetryPolicy(
                    maxAttempts: 3,
                    baseDelay: 30,
                    maxDelay: 120,
                    backoffMultiplier: 2.0
                )
                return ErrorPresentation(
                    iconName: "hourglass",
                    title: LocalizedStringResource("error.httpRateLimited.title", defaultValue: "Rate Limit Reached"),
                    message: LocalizedStringResource("error.httpRateLimited.message", defaultValue: "Too many requests — the weather service asked us to slow down. We'll try again shortly."),
                    isRetryable: true,
                    suggestedAction: .retry,
                    retryPolicy: policy
                )
            case 500...599:
                // Server-side issue. Use a longer-than-default
                // initial delay to give the server time to
                // recover before the next attempt.
                let policy = RetryPolicy(
                    maxAttempts: 4,
                    baseDelay: 5,
                    maxDelay: 30,
                    backoffMultiplier: 2.0
                )
                return ErrorPresentation(
                    iconName: "server.rack",
                    title: LocalizedStringResource("error.httpServer.title", defaultValue: "Service Unavailable"),
                    message: LocalizedStringResource("error.httpServer.message", defaultValue: "The weather service is having problems right now. We'll keep retrying."),
                    isRetryable: true,
                    suggestedAction: .retry,
                    retryPolicy: policy
                )
            default:
                // Other 4xx (400, 408, 410, 422, etc.) —
                // client error, retrying with the same input
                // is unlikely to help.
                return ErrorPresentation(
                    iconName: "exclamationmark.triangle.fill",
                    title: LocalizedStringResource("error.httpClient.title", defaultValue: "Request Failed"),
                    message: LocalizedStringResource("error.httpClient.message", defaultValue: "The weather service rejected the request. Please try a different location or check your settings."),
                    isRetryable: false,
                    suggestedAction: .none
                )
            }
        case .noNetwork:
            return ErrorPresentation(
                iconName: "wifi.slash",
                title: LocalizedStringResource("error.noNetwork.title", defaultValue: "You're Offline"),
                message: LocalizedStringResource("error.noNetwork.message", defaultValue: "We can't reach the weather service. Check your Wi-Fi or cellular connection and try again."),
                isRetryable: true,
                suggestedAction: .retry
            )
        case .timeout:
            return ErrorPresentation(
                iconName: "clock.badge.exclamationmark",
                title: LocalizedStringResource("error.timeout.title", defaultValue: "Request Timed Out"),
                message: LocalizedStringResource("error.timeout.message", defaultValue: "The weather service didn't respond in time. Please try again."),
                isRetryable: true,
                suggestedAction: .retry
            )
        case .staleData(let age):
            let minutes = Int(age / 60)
            return ErrorPresentation(
                iconName: "clock.arrow.circlepath",
                title: LocalizedStringResource("error.staleData.title", defaultValue: "Weather May Be Outdated"),
                message: LocalizedStringResource("error.staleData.message", defaultValue: "The last successful update was \(minutes) minute\(minutes == 1 ? "" : "s") ago. Open the app to refresh."),
                isRetryable: true,
                suggestedAction: .retry
            )
        case .locationDenied:
            return ErrorPresentation(
                iconName: "location.slash.fill",
                title: LocalizedStringResource("error.locationDenied.title", defaultValue: "Location Access Denied"),
                message: LocalizedStringResource("error.locationDenied.message", defaultValue: "SaxWeather can't show weather for your current location. Enable location access in Settings to use GPS, or enter coordinates manually."),
                isRetryable: false,
                suggestedAction: .openSettings
            )
        case .locationRestricted:
            return ErrorPresentation(
                iconName: "location.slash.fill",
                title: LocalizedStringResource("error.locationRestricted.title", defaultValue: "Location Restricted"),
                message: LocalizedStringResource("error.locationRestricted.message", defaultValue: "Location services are restricted on this device. You can still add a location manually."),
                isRetryable: false,
                suggestedAction: .openSettings
            )
        case .locationUnavailable:
            return ErrorPresentation(
                iconName: "location.slash",
                title: LocalizedStringResource("error.locationUnavailable.title", defaultValue: "Couldn't Find You"),
                message: LocalizedStringResource("error.locationUnavailable.message", defaultValue: "We couldn't determine your current location. Make sure you're outdoors or near a window and try again."),
                isRetryable: true,
                suggestedAction: .retry
            )
        }
    }

    /// True when the error indicates the stored API key is no longer valid
    /// and the user should be informed in the UI.
    var isKeyHealthIssue: Bool {
        switch self {
        case .invalidAPIKey, .apiKeyRevoked, .apiKeyForbidden, .apiKeyQuotaExceeded:
            return true
        default:
            return false
        }
    }

    /// A short, human friendly service name used in error messages.
    private func displayName(for service: String) -> String {
        switch service.lowercased() {
        case "wu", "weatherunderground":
            return "Weather Underground"
        case "owm", "openweathermap":
            return "OpenWeatherMap"
        default:
            return service.uppercased()
        }
    }
}

// MARK: - Error presentation model

struct ErrorPresentation: Equatable {
    /// SF Symbol name suitable for the error category.
    let iconName: String
    /// Short headline (1-3 words).
    let title: LocalizedStringResource
    /// Longer explanation safe to show to end users.
    let message: LocalizedStringResource
    /// Whether a "Try Again" button makes sense for this error.
    let isRetryable: Bool
    /// The primary action the UI should suggest.
    let suggestedAction: ErrorAction
    let retryPolicy: RetryPolicy?

    init(
        iconName: String,
        title: LocalizedStringResource,
        message: LocalizedStringResource,
        isRetryable: Bool,
        suggestedAction: ErrorAction,
        retryPolicy: RetryPolicy? = nil
    ) {
        self.iconName = iconName
        self.title = title
        self.message = message
        self.isRetryable = isRetryable
        self.suggestedAction = suggestedAction
        self.retryPolicy = retryPolicy
    }
}

enum ErrorAction: Equatable {
    case retry
    case openSettings
    case none
}

// MARK: - Error mapping

extension WeatherError {
    static func parseRetryAfter(from headerValue: String?) -> TimeInterval? {
        guard let raw = headerValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else { return nil }

        // Form 1: integer seconds. RFC 7231 allows up to 10
        // digits but in practice servers use 1-3. Be generous.
        if let seconds = Int(raw), seconds >= 0 {
            return TimeInterval(seconds)
        }

        // Form 2: HTTP-date.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        // RFC 7231 §7.1.1.1 — three accepted formats.
        for format in [
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEEE, dd-MMM-yy HH:mm:ss zzz",
            "EEE MMM d HH:mm:ss yyyy"
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return max(0, date.timeIntervalSinceNow)
            }
        }
        return nil
    }

    static func from(_ error: Error) -> WeatherError {
        // Already a WeatherError? Pass through.
        if let weatherError = error as? WeatherError {
            return weatherError
        }

        // URL layer — distinguish offline, timeout, and other
        // transport errors so the UI can react differently.
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .dataNotAllowed,
                 .internationalRoamingOff:
                return .noNetwork
            case .timedOut:
                return .timeout
            case .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed:
                return .noNetwork
            default:
                return .apiError(urlError.localizedDescription)
            }
        }

        // CoreLocation layer.
        //
        // Note: `CLError.Code` does NOT have a `.restricted` case
        // — restricted is a `CLAuthorizationStatus` value, only
        // surfaced via `CLLocationManager.authorizationStatus`.
        // The `WeatherService` location-permission callback is
        // where `.locationRestricted` originates; this mapper
        // therefore only sees `.denied` and transient errors.
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                return .locationDenied
            case .locationUnknown, .network, .regionMonitoringDenied, .regionMonitoringFailure:
                return .locationUnavailable
            default:
                return .locationUnavailable
            }
        }

        // Decoding errors get a slightly nicer default message than
        // the raw NSError description.
        if error is DecodingError {
            return .decodingError(error.localizedDescription)
        }

        return .apiError(error.localizedDescription)
    }
}
