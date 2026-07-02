//
//  APIKeyHealthMonitor.swift
//  SaxWeather
//
//  Tracks whether each API key stored in the keychain is still
//  accepted by its provider. Persists its findings so the UI can
//  warn the user if a key has been revoked, is out of quota, or
//  has been rejected for some other reason.
//
//  Created: 2026-06-16
//

import Foundation
import Combine
import os.log

/// The well-known service identifiers used in the keychain.
/// Centralised so we don't sprinkle string literals around the app.
enum APIKeyService: String, CaseIterable, Codable {
    case weatherUnderground = "wu"
    case openWeatherMap     = "owm"

    var displayName: String {
        switch self {
        case .weatherUnderground: return "Weather Underground"
        case .openWeatherMap:     return "OpenWeatherMap"
        }
    }

    var iconName: String {
        switch self {
        case .weatherUnderground: return "antenna.radiowaves.left.and.right"
        case .openWeatherMap:     return "globe"
        }
    }
}

enum APIKeyHealthStatus: String, Codable {
    /// We have never tried to use this key, or the user has just saved
    /// a new one and we haven't validated it yet.
    case unknown
    /// The last attempt to use this key succeeded.
    case valid
    /// The provider rejected the key outright (HTTP 401, 403, …).
    /// The user almost certainly needs to re-enter a new key.
    case invalid
    /// The key worked but we hit a rate/quota limit (HTTP 429).
    /// The key is fine – the user just needs to wait or upgrade.
    case quotaExceeded
}

struct APIKeyHealthEntry: Codable, Equatable {
    var status: APIKeyHealthStatus
    /// Short description of why the key is in this state.
    var detail: String?
    /// HTTP status code that produced this state, if any.
    var httpStatusCode: Int?
    /// When this state was last updated.
    var lastChecked: Date
    /// When the key was last seen to work.
    var lastSuccess: Date?
    /// When the key was last seen to fail.
    var lastFailure: Date?
    /// Number of consecutive failures (resets on success).
    var consecutiveFailures: Int
    /// A token derived from the key value, used to invalidate the
    /// entry when the user changes the key.
    var keyFingerprint: String?

    static func unknown() -> APIKeyHealthEntry {
        APIKeyHealthEntry(
            status: .unknown,
            detail: nil,
            httpStatusCode: nil,
            lastChecked: Date.distantPast,
            lastSuccess: nil,
            lastFailure: nil,
            consecutiveFailures: 0,
            keyFingerprint: nil
        )
    }
}

/// Singleton that records the health of every API key the app
/// stores in the keychain. SwiftUI views can observe its
/// `@Published` properties to react to changes in real time.
final class APIKeyHealthMonitor: ObservableObject {
    static let shared = APIKeyHealthMonitor()

    /// Per-service health records.
    @Published private(set) var entries: [String: APIKeyHealthEntry]

    /// Bumped whenever any entry changes – useful as a single
    /// `onChange` trigger when views don't need to inspect the
    /// detail.
    @Published private(set) var revision: Int = 0

    private let logger = Logger(subsystem: "com.saxobroko.saxweather", category: "APIKeyHealthMonitor")
    private let defaults: UserDefaults
    private let storageKey = "apiKeyHealth.v1"
    private let queue = DispatchQueue(label: "com.saxobroko.saxweather.apiKeyHealth", qos: .utility)

    // MARK: - Init / persistence

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([String: APIKeyHealthEntry].self, from: data)
        {
            self.entries = decoded
        } else {
            self.entries = [:]
        }

        // Drop stale entries for services that no longer have a key.
        purgeStaleEntries()
    }

    private func persist() {
        let snapshot = entries
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: storageKey)
        }
    }

    // MARK: - Read API

    func entry(for service: APIKeyService) -> APIKeyHealthEntry {
        entries[service.rawValue] ?? .unknown()
    }

    func status(for service: APIKeyService) -> APIKeyHealthStatus {
        entry(for: service).status
    }

    /// True when we believe the stored key is unusable and the
    /// user needs to re-enter it.
    func hasBlockingIssue(for service: APIKeyService) -> Bool {
        status(for: service) == .invalid
    }

    /// True when at least one service is currently flagged as
    /// invalid – used to drive banner UI on the home screen.
    var hasAnyBlockingIssue: Bool {
        APIKeyService.allCases.contains { hasBlockingIssue(for: $0) }
    }

    var blockingServices: [APIKeyService] {
        APIKeyService.allCases.filter { hasBlockingIssue(for: $0) }
    }

    // MARK: - Write API

    /// Call after a successful response from the provider.
    func recordSuccess(for service: APIKeyService) {
        mutateEntry(for: service) { entry in
            entry.status = .valid
            entry.detail = nil
            entry.httpStatusCode = nil
            entry.lastChecked = Date()
            entry.lastSuccess = Date()
            entry.consecutiveFailures = 0
        }
    }

    /// Call when the provider returned an HTTP error that
    /// indicates the stored key is unusable. The status is
    /// derived from the HTTP code.
    func recordFailure(
        for service: APIKeyService,
        httpStatusCode: Int?,
        detail: String? = nil
    ) {
        let derivedStatus: APIKeyHealthStatus
        switch httpStatusCode {
        case 401:
            derivedStatus = .invalid
        case 403:
            derivedStatus = .invalid
        case 429:
            derivedStatus = .quotaExceeded
        default:
            // Non-auth errors (5xx, network) shouldn't taint the key
            // permanently – they're treated as transient.
            if httpStatusCode != nil {
                logger.debug("Non-auth failure for \(service.rawValue, privacy: .public): HTTP \(httpStatusCode ?? 0)")
            }
            mutateEntry(for: service) { entry in
                entry.detail = detail
                entry.httpStatusCode = httpStatusCode
                entry.lastChecked = Date()
                entry.lastFailure = Date()
                entry.consecutiveFailures += 1
            }
            return
        }

        mutateEntry(for: service) { entry in
            entry.status = derivedStatus
            entry.detail = detail ?? defaultDetail(for: derivedStatus, httpStatusCode: httpStatusCode)
            entry.httpStatusCode = httpStatusCode
            entry.lastChecked = Date()
            entry.lastFailure = Date()
            entry.consecutiveFailures += 1
        }
        logger.warning("Recorded \(derivedStatus.rawValue, privacy: .public) for service \(service.rawValue, privacy: .public) (HTTP \(httpStatusCode ?? -1))")
    }

    func recordTransientError(for service: APIKeyService, detail: String? = nil) {
        mutateEntry(for: service) { entry in
            entry.detail = detail
            entry.lastChecked = Date()
            entry.lastFailure = Date()
            entry.consecutiveFailures += 1
        }
    }

    /// Wipe the entry for a service – called when the user
    /// deletes or replaces their key.
    func reset(for service: APIKeyService) {
        mutateEntry(for: service) { entry in
            entry = .unknown()
        }
    }

    /// Wipe entries for services whose key is no longer in the
    /// keychain. Called at launch and after every save.
    func purgeStaleEntries() {
        var didChange = false
        for service in APIKeyService.allCases {
            let keyStillStored: Bool
            switch service {
            case .weatherUnderground:
                keyStillStored = !(KeychainService.shared.getApiKey(forService: service.rawValue) ?? "").isEmpty
            case .openWeatherMap:
                keyStillStored = !(KeychainService.shared.getApiKey(forService: service.rawValue) ?? "").isEmpty
            }

            if !keyStillStored, entries[service.rawValue] != nil {
                entries.removeValue(forKey: service.rawValue)
                didChange = true
            }
        }
        if didChange {
            revision &+= 1
            persist()
        }
    }

    @discardableResult
    func refreshFingerprint(for service: APIKeyService) -> String? {
        guard let key = KeychainService.shared.getApiKey(forService: service.rawValue),
              !key.isEmpty else {
            reset(for: service)
            return nil
        }
        let fingerprint = Self.fingerprint(for: key)
        if entry(for: service).keyFingerprint != fingerprint {
            // New key – forget any history attached to the old one.
            mutateEntry(for: service) { entry in
                entry = APIKeyHealthEntry(
                    status: .unknown,
                    detail: nil,
                    httpStatusCode: nil,
                    lastChecked: Date(),
                    lastSuccess: nil,
                    lastFailure: nil,
                    consecutiveFailures: 0,
                    keyFingerprint: fingerprint
                )
            }
        }
        return fingerprint
    }

    // MARK: - Helpers

    private func mutateEntry(for service: APIKeyService, _ block: (inout APIKeyHealthEntry) -> Void) {
        queue.sync {
            var entry = entries[service.rawValue] ?? .unknown()
            block(&entry)
            entries[service.rawValue] = entry
            persist()
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.revision &+= 1
            self.objectWillChange.send()
        }
    }

    private func defaultDetail(for status: APIKeyHealthStatus, httpStatusCode: Int?) -> String {
        switch status {
        case .invalid:
            if httpStatusCode == 401 {
                return "The provider rejected the API key (HTTP 401). It may have been revoked."
            }
            if httpStatusCode == 403 {
                return "The provider denied access (HTTP 403). Your account may be suspended."
            }
            return "The API key is no longer accepted by the provider."
        case .quotaExceeded:
            return "You have exceeded the provider's request limit (HTTP 429)."
        case .valid, .unknown:
            return ""
        }
    }

    /// A non-reversible fingerprint of an API key. We don't need
    /// (and don't want) to store the actual key value – a stable
    /// hash is enough to detect that the key has changed.
    private static func fingerprint(for key: String) -> String {
        // FNV-1a 64-bit. Cheap, stable, good enough for an in-app
        // change detection token.
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
