//
//  NetworkMonitor.swift
//  SaxWeather
//
//  Lightweight wrapper around `NWPathMonitor` that gives the rest
//  of the app a thread-safe view of the current network state.
//
//  The original background refresh path in `SaxWeatherApp.swift`
//  issued an `URLSession` request on every wake-up, even if the
//  device was clearly offline. iOS gives a `BGAppRefreshTask`
//  roughly 30 seconds of wall time, so burning the budget on a
//  request that cannot possibly succeed is wasteful and feeds
//  back into the iOS throttling that already punishes "noisy"
//  background apps.
//
//  Callers can:
//   * Read the live `isConnected` / `isExpensive` / `isConstrained`
//     properties (publish on the main thread, suitable for SwiftUI).
//   * Use `currentSnapshot()` for a synchronous pre-flight check
//     before a network call. This is a snapshot of the most
//     recent path update, not a fresh probe.
//
//  The monitor starts on first access (singleton init). iOS may
//  take a few hundred milliseconds to deliver the first path
//  update, so the very first `currentSnapshot()` call right after
//  process start can optimistically report `.satisfied` until the
//  first real update arrives. This is acceptable for our use
//  case: the pre-flight check is an optimisation, not a
//  guarantee, and the URL session still surfaces real errors.
//

import Foundation
import Network
import Combine

/// Connectivity monitor backed by `NWPathMonitor`.
///
/// Exposes both a Combine publisher for SwiftUI bindings and a
/// synchronous snapshot for one-shot pre-flight checks before
/// network calls. The class is intentionally a singleton so
/// there is only one `NWPathMonitor` per process.
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    /// Coarse connection type derived from the path's
    /// `availableInterfaces`. The mapping matches what users
    /// typically care about for "should I do a big fetch now?"
    enum ConnectionType: String {
        case wifi
        case cellular
        case ethernet
        case other
        case unknown
    }

    /// Snapshot of the most recent path state, useful for
    /// pre-flight checks without subscribing to updates.
    struct Snapshot {
        let isConnected: Bool
        let isExpensive: Bool
        let isConstrained: Bool
        let connectionType: ConnectionType
    }

    // MARK: - Published State

    /// `true` when the path is satisfied. Defaults to `true` so
    /// the very first update (or absence of one) does not flip
    /// the app into "offline" before the first real probe
    /// arrives.
    @Published private(set) var isConnected: Bool = true

    /// `true` on personal hotspots, tethered networks, and other
    /// expensive interfaces. The background refresh path treats
    /// this as a hint to back off.
    @Published private(set) var isExpensive: Bool = false

    /// `true` on Low Data Mode. The background refresh path
    /// treats this as a hint to back off.
    @Published private(set) var isConstrained: Bool = false

    /// Resolved connection type, derived from the path's
    /// interface list.
    @Published private(set) var connectionType: ConnectionType = .unknown

    // MARK: - Private

    private let monitor: NWPathMonitor
    private let queue: DispatchQueue

    private init() {
        self.monitor = NWPathMonitor()
        self.queue = DispatchQueue(
            label: "com.saxobroko.SaxWeather.network-monitor",
            qos: .utility
        )
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            // Marshal the published values to the main queue so
            // SwiftUI bindings and any UIKit consumers can read
            // them without an extra hop.
            let connected = path.status == .satisfied
            let expensive = path.isExpensive
            let constrained = path.isConstrained
            let resolved: ConnectionType
            if path.usesInterfaceType(.wifi) {
                resolved = .wifi
            } else if path.usesInterfaceType(.cellular) {
                resolved = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                resolved = .ethernet
            } else if path.status == .satisfied {
                resolved = .other
            } else {
                resolved = .unknown
            }
            DispatchQueue.main.async {
                self.isConnected = connected
                self.isExpensive = expensive
                self.isConstrained = constrained
                self.connectionType = resolved
            }
        }
        monitor.start(queue: queue)
    }

    // MARK: - Public API

    /// Test-only injection point. Lets unit tests set the
    /// published properties directly without needing a live
    /// `NWPathMonitor`. Marked with a leading underscore to
    /// discourage production use — the real path updates come
    /// from the `pathUpdateHandler` closure.
    #if DEBUG
    func setForTesting(
        isConnected: Bool? = nil,
        isConstrained: Bool? = nil,
        isExpensive: Bool? = nil,
        connectionType: ConnectionType? = nil
    ) {
        if let isConnected = isConnected { self.isConnected = isConnected }
        if let isConstrained = isConstrained { self.isConstrained = isConstrained }
        if let isExpensive = isExpensive { self.isExpensive = isExpensive }
        if let connectionType = connectionType { self.connectionType = connectionType }
    }
    #endif

    /// Synchronous snapshot of the current path. Safe to call
    /// from any thread.
    ///
    /// This returns whatever `NWPathMonitor` currently knows
    /// about the path. If the monitor has not received its first
    /// update yet (which can happen for a few hundred ms after
    /// process start), the path will be the default-initialised
    /// `.satisfied` value. Callers that need a hard guarantee
    /// should combine the snapshot with their own retry logic.
    func currentSnapshot() -> Snapshot {
        let path = monitor.currentPath
        let connected = path.status == .satisfied
        let expensive = path.isExpensive
        let constrained = path.isConstrained
        let resolved: ConnectionType
        if path.usesInterfaceType(.wifi) {
            resolved = .wifi
        } else if path.usesInterfaceType(.cellular) {
            resolved = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            resolved = .ethernet
        } else if connected {
            resolved = .other
        } else {
            resolved = .unknown
        }
        return Snapshot(
            isConnected: connected,
            isExpensive: expensive,
            isConstrained: constrained,
            connectionType: resolved
        )
    }
}

// MARK: - Network quality

extension NetworkMonitor {
    /// Coarse-grained classification of the current network
    /// path. Combines `connectionType`, `isExpensive`, and
    /// `isConstrained` into a single value the rest of the app
    /// can switch on without re-deriving the same logic.
    enum NetworkQuality: Equatable {
        /// No usable path.
        case offline
        /// WiFi or ethernet — unmetered, fast, no Low Data Mode.
        case unmetered
        /// Cellular on a normal plan — metered but not flagged
        /// as expensive or constrained.
        case cellular
        /// Personal hotspot, tethered, or otherwise flagged as
        /// expensive by the OS.
        case expensive
        /// Low Data Mode is active on any interface.
        case constrained
    }

    /// Current network quality, derived from the published
    /// properties. Cheap to compute; safe to call from any
    /// thread.
    var quality: NetworkQuality {
        guard isConnected else { return .offline }
        if isConstrained { return .constrained }
        if isExpensive { return .expensive }
        switch connectionType {
        case .wifi, .ethernet: return .unmetered
        case .cellular: return .cellular
        case .other, .unknown: return .unmetered
        }
    }

    /// True when the app should fetch the heavy extended
    /// forecast payload (AQI, pollen, sun/moon, hourly
    /// precipitation). Skipped on cellular + Low Data Mode to
    /// respect the user's data plan.
    var shouldFetchExtendedForecast: Bool {
        switch quality {
        case .offline, .expensive, .constrained:
            return false
        case .unmetered, .cellular:
            return true
        }
    }

    /// Recommended background-refresh interval for the current
    /// network quality. WiFi refreshes more aggressively than
    /// cellular; Low Data Mode and expensive networks back off
    /// further. Returns `nil` when offline (no point scheduling).
    var recommendedBackgroundRefreshInterval: TimeInterval? {
        switch quality {
        case .offline: return nil
        case .unmetered: return 15 * 60          // 15 min
        case .cellular: return 30 * 60           // 30 min
        case .expensive: return 60 * 60          // 1 hour
        case .constrained: return 2 * 60 * 60    // 2 hours
        }
    }
}
