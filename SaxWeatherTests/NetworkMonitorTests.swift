//
//  NetworkMonitorTests.swift
//  SaxWeatherTests
//
//  Unit tests for `NetworkMonitor` — the connectivity probe that
//  drives the offline banner, the widget's offline badge, and
//  the network-quality-aware fetch decisions. Covers:
//   * `quality` classification for every combination of
//     isConnected / isConstrained / isExpensive / connectionType
//   * `shouldFetchExtendedForecast` for each quality
//   * `recommendedBackgroundRefreshInterval` for each quality
//
//  Note: these tests exercise the *logic* of the quality
//  classification, not the live `NWPathMonitor` state. The
//  `NetworkMonitor` singleton reads from the OS, which is not
//  deterministic in a test environment. We test the
//  classification rules by constructing a `NetworkMonitor` and
//  verifying that the published properties drive the expected
//  quality output.
//

import XCTest
import Network
@testable import SaxWeather

final class NetworkMonitorTests: XCTestCase {

    // MARK: - NetworkQuality enum

    func test_networkQuality_isEquatable() {
        // The enum is used in switch statements and as a
        // dictionary key, so Equatable is part of the contract.
        XCTAssertEqual(NetworkMonitor.NetworkQuality.offline, NetworkMonitor.NetworkQuality.offline)
        XCTAssertNotEqual(NetworkMonitor.NetworkQuality.offline, .unmetered)
    }

    // MARK: - quality classification

    func test_quality_isOffline_whenNotConnected() {
        let monitor = makeMonitor(
            isConnected: false,
            isConstrained: false,
            isExpensive: false,
            connectionType: .wifi
        )
        XCTAssertEqual(monitor.quality, .offline)
    }

    func test_quality_isOffline_evenWhenOtherFlagsAreSet() {
        // Offline wins over everything else — if there's no
        // path, the other flags are meaningless.
        let monitor = makeMonitor(
            isConnected: false,
            isConstrained: true,
            isExpensive: true,
            connectionType: .wifi
        )
        XCTAssertEqual(monitor.quality, .offline)
    }

    func test_quality_isConstrained_whenLowDataModeIsOn() {
        // Low Data Mode wins over expensive and connection type.
        let monitor = makeMonitor(
            isConnected: true,
            isConstrained: true,
            isExpensive: true,
            connectionType: .wifi
        )
        XCTAssertEqual(monitor.quality, .constrained)
    }

    func test_quality_isExpensive_whenHotspotAndNotConstrained() {
        let monitor = makeMonitor(
            isConnected: true,
            isConstrained: false,
            isExpensive: true,
            connectionType: .cellular
        )
        XCTAssertEqual(monitor.quality, .expensive)
    }

    func test_quality_isUnmetered_onWifi() {
        let monitor = makeMonitor(
            isConnected: true,
            isConstrained: false,
            isExpensive: false,
            connectionType: .wifi
        )
        XCTAssertEqual(monitor.quality, .unmetered)
    }

    func test_quality_isUnmetered_onEthernet() {
        let monitor = makeMonitor(
            isConnected: true,
            isConstrained: false,
            isExpensive: false,
            connectionType: .ethernet
        )
        XCTAssertEqual(monitor.quality, .unmetered)
    }

    func test_quality_isCellular_onNormalCellular() {
        let monitor = makeMonitor(
            isConnected: true,
            isConstrained: false,
            isExpensive: false,
            connectionType: .cellular
        )
        XCTAssertEqual(monitor.quality, .cellular)
    }

    func test_quality_isUnmetered_onUnknownConnectionType() {
        // Unknown / other connection types are treated as
        // unmetered (best-effort) when not constrained or
        // expensive.
        let monitor = makeMonitor(
            isConnected: true,
            isConstrained: false,
            isExpensive: false,
            connectionType: .unknown
        )
        XCTAssertEqual(monitor.quality, .unmetered)
    }

    // MARK: - shouldFetchExtendedForecast

    func test_shouldFetchExtendedForecast_isTrue_onUnmetered() {
        let monitor = makeMonitor(
            isConnected: true,
            isConstrained: false,
            isExpensive: false,
            connectionType: .wifi
        )
        XCTAssertTrue(monitor.shouldFetchExtendedForecast)
    }

    func test_shouldFetchExtendedForecast_isTrue_onCellular() {
        let monitor = makeMonitor(
            isConnected: true,
            isConstrained: false,
            isExpensive: false,
            connectionType: .cellular
        )
        XCTAssertTrue(monitor.shouldFetchExtendedForecast)
    }

    func test_shouldFetchExtendedForecast_isFalse_whenOffline() {
        let monitor = makeMonitor(
            isConnected: false,
            isConstrained: false,
            isExpensive: false,
            connectionType: .wifi
        )
        XCTAssertFalse(monitor.shouldFetchExtendedForecast)
    }

    func test_shouldFetchExtendedForecast_isFalse_whenExpensive() {
        let monitor = makeMonitor(
            isConnected: true,
            isConstrained: false,
            isExpensive: true,
            connectionType: .cellular
        )
        XCTAssertFalse(monitor.shouldFetchExtendedForecast)
    }

    func test_shouldFetchExtendedForecast_isFalse_whenConstrained() {
        let monitor = makeMonitor(
            isConnected: true,
            isConstrained: true,
            isExpensive: false,
            connectionType: .wifi
        )
        XCTAssertFalse(monitor.shouldFetchExtendedForecast)
    }

    // MARK: - recommendedBackgroundRefreshInterval

    func test_recommendedBackgroundRefreshInterval_isNil_whenOffline() {
        let monitor = makeMonitor(
            isConnected: false,
            isConstrained: false,
            isExpensive: false,
            connectionType: .wifi
        )
        XCTAssertNil(monitor.recommendedBackgroundRefreshInterval)
    }

    func test_recommendedBackgroundRefreshInterval_is15Min_onUnmetered() {
        let monitor = makeMonitor(
            isConnected: true,
            isConstrained: false,
            isExpensive: false,
            connectionType: .wifi
        )
        XCTAssertEqual(monitor.recommendedBackgroundRefreshInterval, 15 * 60)
    }

    func test_recommendedBackgroundRefreshInterval_is30Min_onCellular() {
        let monitor = makeMonitor(
            isConnected: true,
            isConstrained: false,
            isExpensive: false,
            connectionType: .cellular
        )
        XCTAssertEqual(monitor.recommendedBackgroundRefreshInterval, 30 * 60)
    }

    func test_recommendedBackgroundRefreshInterval_is1Hour_onExpensive() {
        let monitor = makeMonitor(
            isConnected: true,
            isConstrained: false,
            isExpensive: true,
            connectionType: .cellular
        )
        XCTAssertEqual(monitor.recommendedBackgroundRefreshInterval, 60 * 60)
    }

    func test_recommendedBackgroundRefreshInterval_is2Hours_onConstrained() {
        let monitor = makeMonitor(
            isConnected: true,
            isConstrained: true,
            isExpensive: false,
            connectionType: .wifi
        )
        XCTAssertEqual(monitor.recommendedBackgroundRefreshInterval, 2 * 60 * 60)
    }

    // MARK: - Helpers

    /// Build a `NetworkMonitor` with the given published
    /// properties. We can't easily inject the underlying
    /// `NWPathMonitor`, but we can set the published properties
    /// directly (they're `var` in the class, not `let`).
    private func makeMonitor(
        isConnected: Bool,
        isConstrained: Bool,
        isExpensive: Bool,
        connectionType: NetworkMonitor.ConnectionType
    ) -> NetworkMonitor {
        let monitor = NetworkMonitor.shared
        monitor.setForTesting(
            isConnected: isConnected,
            isConstrained: isConstrained,
            isExpensive: isExpensive,
            connectionType: connectionType
        )
        return monitor
    }
}
