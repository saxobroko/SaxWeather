
import Foundation
import Network
import Combine

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

    #if DEBUG || TESTING
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

    var shouldFetchExtendedForecast: Bool {
        switch quality {
        case .offline, .expensive, .constrained:
            return false
        case .unmetered, .cellular:
            return true
        }
    }

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
