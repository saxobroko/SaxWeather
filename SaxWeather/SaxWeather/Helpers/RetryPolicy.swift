//
//  RetryPolicy.swift
//  SaxWeather
//
//  Created on 16/06/2026
//
//  Configurable exponential-backoff schedule for retry buttons
//  throughout the app. The default policy is a 1-2-4-8-second
//  ladder with a hard cap of 3 attempts, which matches iOS
//  conventions for transient network failures.
//

import Foundation

struct RetryPolicy: Equatable {
    var maxAttempts: Int
    /// Initial delay before the first retry, in seconds.
    var baseDelay: TimeInterval
    /// Hard cap on any single delay. Prevents the ladder
    /// from growing unbounded for high attempt counts.
    var maxDelay: TimeInterval
    /// Multiplier applied between successive attempts.
    /// With `baseDelay = 1.0` and `multiplier = 2.0`, the
    /// ladder is 1s → 2s → 4s → 8s → 16s, capped at `maxDelay`.
    var backoffMultiplier: Double

    /// Default policy: 1s → 2s → 4s, capped at 3 attempts.
    /// Matches typical "tap a few times to retry" UX without
    /// frustrating the user.
    static let `default` = RetryPolicy(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 8.0,
        backoffMultiplier: 2.0
    )

    static let immediate = RetryPolicy(
        maxAttempts: 0,
        baseDelay: 0,
        maxDelay: 0,
        backoffMultiplier: 1.0
    )

    /// Delay (in seconds) before the `attempt`-th retry, where
    /// `attempt` is 1-indexed. Returns 0 for `attempt <= 0`
    /// or when the policy is set to `immediate`.
    func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0, baseDelay > 0 else { return 0 }
        let raw = baseDelay * pow(backoffMultiplier, Double(attempt - 1))
        return min(raw, maxDelay)
    }
}
