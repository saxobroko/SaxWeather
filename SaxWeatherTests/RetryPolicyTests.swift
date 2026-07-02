//
//  RetryPolicyTests.swift
//  SaxWeatherTests
//
//  Unit tests for `RetryPolicy` — the exponential-backoff
//  schedule that drives the "Try Again" button. Covers:
//   * The default policy's exponential ladder (1s → 2s → 4s → 8s)
//   * The `maxDelay` cap
//   * The `immediate` preset (no backoff)
//   * Edge cases (attempt 0, negative attempt)
//

import XCTest
@testable import SaxWeather

final class RetryPolicyTests: XCTestCase {

    // MARK: - Default policy

    func test_defaultPolicy_exponentialLadder() {
        let policy = RetryPolicy.default
        XCTAssertEqual(policy.delay(forAttempt: 1), 1)
        XCTAssertEqual(policy.delay(forAttempt: 2), 2)
        XCTAssertEqual(policy.delay(forAttempt: 3), 4)
        XCTAssertEqual(policy.delay(forAttempt: 4), 8)
    }

    func test_defaultPolicy_capsAtMaxDelay() {
        let policy = RetryPolicy.default
        // 5th attempt would be 16s without the cap; maxDelay is 8s.
        XCTAssertEqual(policy.delay(forAttempt: 5), 8)
        XCTAssertEqual(policy.delay(forAttempt: 10), 8)
        XCTAssertEqual(policy.delay(forAttempt: 100), 8)
    }

    func test_defaultPolicy_maxAttempts() {
        XCTAssertEqual(RetryPolicy.default.maxAttempts, 3)
    }

    // MARK: - Immediate preset

    func test_immediatePolicy_returnsZero_forEveryAttempt() {
        let policy = RetryPolicy.immediate
        XCTAssertEqual(policy.delay(forAttempt: 1), 0)
        XCTAssertEqual(policy.delay(forAttempt: 2), 0)
        XCTAssertEqual(policy.delay(forAttempt: 5), 0)
    }

    // MARK: - Edge cases

    func test_delay_returnsZero_forAttemptZero() {
        let policy = RetryPolicy.default
        XCTAssertEqual(policy.delay(forAttempt: 0), 0)
    }

    func test_delay_returnsZero_forNegativeAttempt() {
        let policy = RetryPolicy.default
        XCTAssertEqual(policy.delay(forAttempt: -1), 0)
        XCTAssertEqual(policy.delay(forAttempt: -100), 0)
    }

    func test_delay_returnsZero_whenBaseDelayIsZero() {
        let policy = RetryPolicy(
            maxAttempts: 3,
            baseDelay: 0,
            maxDelay: 60,
            backoffMultiplier: 2.0
        )
        XCTAssertEqual(policy.delay(forAttempt: 1), 0)
        XCTAssertEqual(policy.delay(forAttempt: 5), 0)
    }

    // MARK: - Custom policies

    func test_customPolicy_respectsMultiplier() {
        let policy = RetryPolicy(
            maxAttempts: 5,
            baseDelay: 2,
            maxDelay: 1000,
            backoffMultiplier: 3.0
        )
        XCTAssertEqual(policy.delay(forAttempt: 1), 2)
        XCTAssertEqual(policy.delay(forAttempt: 2), 6)
        XCTAssertEqual(policy.delay(forAttempt: 3), 18)
        XCTAssertEqual(policy.delay(forAttempt: 4), 54)
    }

    func test_customPolicy_capsAtMaxDelay() {
        let policy = RetryPolicy(
            maxAttempts: 10,
            baseDelay: 1,
            maxDelay: 5,
            backoffMultiplier: 2.0
        )
        // 1, 2, 4, 8→5, 16→5, 32→5
        XCTAssertEqual(policy.delay(forAttempt: 1), 1)
        XCTAssertEqual(policy.delay(forAttempt: 2), 2)
        XCTAssertEqual(policy.delay(forAttempt: 3), 4)
        XCTAssertEqual(policy.delay(forAttempt: 4), 5)
        XCTAssertEqual(policy.delay(forAttempt: 5), 5)
    }

    // MARK: - Equatable

    func test_equality() {
        let a = RetryPolicy(maxAttempts: 3, baseDelay: 1, maxDelay: 8, backoffMultiplier: 2)
        let b = RetryPolicy(maxAttempts: 3, baseDelay: 1, maxDelay: 8, backoffMultiplier: 2)
        let c = RetryPolicy(maxAttempts: 4, baseDelay: 1, maxDelay: 8, backoffMultiplier: 2)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
