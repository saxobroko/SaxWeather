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

/// Describes how aggressively the "Try Again" button should
/// retry after a failure. Used by [`ErrorView`] so the same
/// behaviour is consistent across the app — pull-to-refresh
/// failures, geocoding errors, API-key errors, etc.
struct RetryPolicy: Equatable {
    /// Maximum number of backoff-delayed retries the user
    /// gets before the button reverts to "Try Again" without
    /// any delay. After this, subsequent taps invoke the
    /// retry closure immediately (no further backoff) so a
    /// determined user is never blocked.
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

    /// Aggressive policy: immediate retries, no backoff. Use
    /// for actions where a long pause would feel broken (e.g.
    /// "Try Again" on a non-network failure like a bad API
    /// key — there's no point waiting to retry that).
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
