//
//  WidgetStalenessTests.swift
//  SaxWeatherTests
//
//  Unit tests for `WidgetStaleness` — the freshness threshold
//  that drives the widget's "Updated Xm ago" footer and the
//  host-app's stale data warning. Covers:
//   * Nil date is stale
//   * Fresh date is not stale
//   * Date older than threshold is stale
//   * Date exactly at threshold is not stale (boundary)
//   * Injectable `now` for deterministic tests
//

import XCTest
@testable import SaxWeather

final class WidgetStalenessTests: XCTestCase {

    // MARK: - Threshold constant

    func test_threshold_is30Minutes() {
        // The threshold is part of the public contract — if it
        // changes, the widget's "Updated Xm ago" footer and the
        // host-app's stale data warning both change behaviour.
        XCTAssertEqual(WidgetStaleness.threshold, 30 * 60)
    }

    // MARK: - isStale(_:now:)

    func test_isStale_returnsTrue_forNilDate() {
        XCTAssertTrue(WidgetStaleness.isStale(nil))
    }

    func test_isStale_returnsFalse_forFreshDate() {
        let now = Date()
        let fresh = now.addingTimeInterval(-60) // 1 minute ago
        XCTAssertFalse(WidgetStaleness.isStale(fresh, now: now))
    }

    func test_isStale_returnsFalse_forDateAtThreshold() {
        // Boundary: exactly at the threshold should NOT be stale.
        // The check is `> threshold`, not `>= threshold`.
        let now = Date()
        let atThreshold = now.addingTimeInterval(-WidgetStaleness.threshold)
        XCTAssertFalse(WidgetStaleness.isStale(atThreshold, now: now))
    }

    func test_isStale_returnsTrue_forDateJustPastThreshold() {
        let now = Date()
        let justPast = now.addingTimeInterval(-WidgetStaleness.threshold - 1)
        XCTAssertTrue(WidgetStaleness.isStale(justPast, now: now))
    }

    func test_isStale_returnsTrue_forVeryOldDate() {
        let now = Date()
        let ancient = now.addingTimeInterval(-86400 * 7) // 1 week ago
        XCTAssertTrue(WidgetStaleness.isStale(ancient, now: now))
    }

    func test_isStale_returnsFalse_forFutureDate() {
        // A date in the future (e.g. clock skew) should not be
        // considered stale — the data is "fresh" relative to
        // the current clock.
        let now = Date()
        let future = now.addingTimeInterval(3600)
        XCTAssertFalse(WidgetStaleness.isStale(future, now: now))
    }

    // MARK: - Injectable now

    func test_isStale_usesInjectedNow() {
        // Verify the `now` parameter is actually used (not just
        // `Date()`). If someone refactors and accidentally
        // removes the parameter, this test catches it.
        let date = Date(timeIntervalSince1970: 1_000_000)
        let now = date.addingTimeInterval(100)
        XCTAssertFalse(WidgetStaleness.isStale(date, now: now))

        let laterNow = date.addingTimeInterval(WidgetStaleness.threshold + 100)
        XCTAssertTrue(WidgetStaleness.isStale(date, now: laterNow))
    }
}
