//
//  BackgroundRefreshCoordinator.swift
//  SaxWeather
//
//  Centralised scheduler for the iOS `BGAppRefreshTaskRequest` used
//  by the host app to keep the widget timeline fresh.
//
//  Three problems this file addresses (see the discussion in
//  `WIDGET_BACKGROUND_REFRESH_COMPLETE.md`):
//
//  1. **Task Scheduling** – the previous code submitted a flat
//     "5 minutes from now" request every time, regardless of
//     device conditions. iOS may throttle, Low Power Mode may be
//     on, or the user may be on a constrained connection. We now
//     lengthen the interval when the device is in Low Power Mode
//     and surface the *actual* interval through
//     `nextIntervalSeconds` so the debug UI can show the truth.
//
//  2. **Network State** – handled in `NetworkMonitor.swift`. This
//     coordinator does not duplicate the check; it simply
//     consumes the outcome of a refresh attempt and translates
//     it into a sensible next interval.
//
//  3. **Error Recovery** – we persist a counter of consecutive
//     failures in `UserDefaults` and apply exponential backoff
//     (5m → 10m → 20m → 40m → 60m, capped) so that a device that
//     is repeatedly offline at the same time of day does not
//     keep draining its background-refresh budget. The counter
//     resets to zero the next time a refresh succeeds.
//
//  All persisted state lives under standard `UserDefaults` keys
//  prefixed with `bgRefresh.` so the values are easy to inspect
//  from the debugger or a future settings screen.
//

import Foundation
import BackgroundTasks
#if canImport(UIKit)
import UIKit
#endif

final class BackgroundRefreshCoordinator {
    static let shared = BackgroundRefreshCoordinator()

    private init() {}

    // MARK: - Configuration

    /// Base interval used after a successful refresh, in seconds.
    /// 5 minutes matches the previous behaviour and the
    /// `BGAppRefreshTaskRequest` minimum the system honours.
    var baseIntervalSeconds: TimeInterval = 5 * 60

    var maxIntervalSeconds: TimeInterval = 60 * 60

    var maxExponent: Int = 6

    // MARK: - Persistence Keys

    private enum Keys {
        static let consecutiveFailures = "bgRefresh.consecutiveFailures"
        static let lastSuccessDate = "bgRefresh.lastSuccessDate"
        static let lastFailureDate = "bgRefresh.lastFailureDate"
        static let lowPowerModeBackoff = "bgRefresh.lowPowerModeBackoffCount"
    }

    // MARK: - Persisted State

    /// Number of consecutive background refresh attempts that
    /// ended in failure (network error, missing data, expired
    /// task, etc). Reset to zero on the next success.
    var consecutiveFailures: Int {
        get { UserDefaults.standard.integer(forKey: Keys.consecutiveFailures) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.consecutiveFailures) }
    }

    /// Date of the most recent successful background refresh.
    /// `nil` if the app has never recorded a success.
    var lastSuccessDate: Date? {
        get { UserDefaults.standard.object(forKey: Keys.lastSuccessDate) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastSuccessDate) }
    }

    /// Date of the most recent failed background refresh.
    /// `nil` if the app has never recorded a failure.
    var lastFailureDate: Date? {
        get { UserDefaults.standard.object(forKey: Keys.lastFailureDate) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastFailureDate) }
    }

    // MARK: - Derived State

    /// The interval (in seconds) the coordinator will use for the
    /// *next* schedule, factoring in the failure counter but not
    /// the live Low Power Mode state. Useful for the debug UI.
    var nextIntervalSeconds: TimeInterval {
        let failures = consecutiveFailures
        guard failures > 0 else { return baseIntervalSeconds }
        let exponent = min(failures, maxExponent)
        let raw = baseIntervalSeconds * pow(2.0, Double(exponent))
        return min(maxIntervalSeconds, raw)
    }

    /// Earliest begin date the coordinator will use for the next
    /// schedule, evaluated against the current wall-clock time.
    func nextEarliestBeginDate() -> Date {
        return Date(timeIntervalSinceNow: nextIntervalSeconds)
    }

    /// `true` if the device is currently in Low Power Mode. We
    /// back off more aggressively when LPM is on, because iOS
    /// is otherwise likely to deny the request outright.
    var isLowPowerModeEnabled: Bool {
        #if canImport(UIKit)
        return ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        return false
        #endif
    }

    // MARK: - Scheduling

    func scheduleAppRefresh(taskIdentifier: String) {
        let interval = adjustedInterval(forLPM: isLowPowerModeEnabled,
                                        base: baseIntervalSeconds)
        submit(taskIdentifier: taskIdentifier, interval: interval,
               reason: "user-initiated schedule")
    }

    func scheduleNextRefresh(taskIdentifier: String,
                             previousSucceeded: Bool) {
        let interval = nextIntervalSeconds(after: previousSucceeded)
        submit(taskIdentifier: taskIdentifier, interval: interval,
               reason: previousSucceeded
                    ? "previous run succeeded"
                    : "previous run failed (backoff)")
    }

    func recordOutcome(success: Bool) {
        if success {
            if consecutiveFailures > 0 {
                print("✅ Background refresh: resetting failure counter (was \(consecutiveFailures))")
            }
            consecutiveFailures = 0
            lastSuccessDate = Date()
        } else {
            consecutiveFailures += 1
            lastFailureDate = Date()
            let next = nextIntervalSeconds
            print("⚠️ Background refresh: consecutive failures = \(consecutiveFailures); next interval = \(Int(next / 60)) min")
        }
    }

    /// Convenience for callers that want to flip the counter
    /// back to zero (e.g. a debug "Reset" button). Not used by
    /// the production code path.
    func resetFailureCounter() {
        consecutiveFailures = 0
    }

    // MARK: - Private Helpers

    private func nextIntervalSeconds(after previousSucceeded: Bool) -> TimeInterval {
        // We compute the interval from the *current* counter,
        // which reflects the outcome of the last *completed*
        // attempt. If the previous run succeeded the counter is
        // 0 and we use the base interval; if it failed the
        // counter is at least 1 and we apply the backoff.
        let base = nextIntervalSeconds
        return adjustedInterval(forLPM: isLowPowerModeEnabled, base: base)
    }

    private func adjustedInterval(forLPM lpm: Bool,
                                  base: TimeInterval) -> TimeInterval {
        guard lpm else { return base }
        // In Low Power Mode we double the interval but cap at
        // 2× the regular maximum so the widget does not go
        // dark for hours on end.
        let doubled = base * 2
        return min(doubled, maxIntervalSeconds * 2)
    }

    private func submit(taskIdentifier: String,
                        interval: TimeInterval,
                        reason: String) {
        #if canImport(UIKit)
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        do {
            try BGTaskScheduler.shared.submit(request)
            let minutes = Int((interval / 60).rounded())
            let when = request.earliestBeginDate ?? Date()
            print("✅ Background refresh scheduled in \(minutes) min (at \(when)) — \(reason)")
        } catch {
            // The common cases are `.notPermitted` (user disabled
            // Background App Refresh) and `.tooManyPendingTaskRequests`
            // (we already have a request queued). Both are
            // benign; log and move on.
            print("❌ Could not schedule app refresh (\(reason)): \(error)")
        }
        #else
        // macOS does not expose `BGTaskScheduler` /
        // `BGAppRefreshTaskRequest`. The widget timeline is
        // refreshed by the widget extension itself on macOS, so
        // there is nothing to schedule from the host app. Log
        // the intent so the debug UI still shows the interval
        // we *would* have used.
        let minutes = Int((interval / 60).rounded())
        print("ℹ️ Background refresh skipped on macOS (would have been \(minutes) min) — \(reason)")
        #endif
    }
}
