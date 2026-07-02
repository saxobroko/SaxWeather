//
//  WeatherErrorTests.swift
//  SaxWeatherTests
//
//  Unit tests for `WeatherError` — the typed error model that
//  drives every error UI in the app. Covers:
//   * `WeatherError.from(_:)` mapping for URLError, CLError,
//     DecodingError, and pass-through of existing WeatherError
//   * `WeatherError.parseRetryAfter(from:)` for both the
//     integer-seconds and HTTP-date forms of the Retry-After
//     header
//   * `WeatherError.presentation` exhaustiveness — every case
//     must produce a non-nil presentation with a non-empty
//     title and message
//

import XCTest
import CoreLocation
@testable import SaxWeather

final class WeatherErrorTests: XCTestCase {

    // MARK: - WeatherError.from(_:) — URLError mapping

    func test_from_mapsURLError_notConnectedToInternet_to_noNetwork() {
        let error = URLError(.notConnectedToInternet)
        XCTAssertEqual(WeatherError.from(error), .noNetwork)
    }

    func test_from_mapsURLError_networkConnectionLost_to_noNetwork() {
        let error = URLError(.networkConnectionLost)
        XCTAssertEqual(WeatherError.from(error), .noNetwork)
    }

    func test_from_mapsURLError_dataNotAllowed_to_noNetwork() {
        let error = URLError(.dataNotAllowed)
        XCTAssertEqual(WeatherError.from(error), .noNetwork)
    }

    func test_from_mapsURLError_internationalRoamingOff_to_noNetwork() {
        let error = URLError(.internationalRoamingOff)
        XCTAssertEqual(WeatherError.from(error), .noNetwork)
    }

    func test_from_mapsURLError_cannotFindHost_to_noNetwork() {
        let error = URLError(.cannotFindHost)
        XCTAssertEqual(WeatherError.from(error), .noNetwork)
    }

    func test_from_mapsURLError_cannotConnectToHost_to_noNetwork() {
        let error = URLError(.cannotConnectToHost)
        XCTAssertEqual(WeatherError.from(error), .noNetwork)
    }

    func test_from_mapsURLError_dnsLookupFailed_to_noNetwork() {
        let error = URLError(.dnsLookupFailed)
        XCTAssertEqual(WeatherError.from(error), .noNetwork)
    }

    func test_from_mapsURLError_timedOut_to_timeout() {
        let error = URLError(.timedOut)
        XCTAssertEqual(WeatherError.from(error), .timeout)
    }

    func test_from_mapsURLError_unknown_to_apiError() {
        let error = URLError(.unknown)
        XCTAssertEqual(WeatherError.from(error), .apiError("The operation couldn’t be completed. (NSURLErrorDomain -1.)"))
    }

    // MARK: - WeatherError.from(_:) — CLError mapping

    func test_from_mapsCLError_denied_to_locationDenied() {
        let error = CLError(.denied)
        XCTAssertEqual(WeatherError.from(error), .locationDenied)
    }

    func test_from_mapsCLError_locationUnknown_to_locationUnavailable() {
        let error = CLError(.locationUnknown)
        XCTAssertEqual(WeatherError.from(error), .locationUnavailable)
    }

    func test_from_mapsCLError_network_to_locationUnavailable() {
        let error = CLError(.network)
        XCTAssertEqual(WeatherError.from(error), .locationUnavailable)
    }

    // MARK: - WeatherError.from(_:) — DecodingError mapping

    func test_from_mapsDecodingError_to_decodingError() {
        // Build a real DecodingError by trying to decode a
        // malformed JSON payload.
        struct Sample: Decodable { let value: Int }
        let malformed = Data("not json".utf8)
        let decoder = JSONDecoder()
        do {
            _ = try decoder.decode(Sample.self, from: malformed)
            XCTFail("Expected decode to throw")
        } catch let decodingError as DecodingError {
            XCTAssertEqual(WeatherError.from(decodingError), .decodingError(decodingError.localizedDescription))
        } catch {
            XCTFail("Expected DecodingError, got \(error)")
        }
    }

    // MARK: - WeatherError.from(_:) — pass-through

    func test_from_passesThroughExistingWeatherError() {
        let original: WeatherError = .noNetwork
        XCTAssertEqual(WeatherError.from(original), original)
    }

    func test_from_passesThroughHttpErrorWithRetryAfter() {
        let original: WeatherError = .httpError(statusCode: 429, retryAfter: 60)
        XCTAssertEqual(WeatherError.from(original), original)
    }

    // MARK: - WeatherError.parseRetryAfter(from:)

    func test_parseRetryAfter_returnsNil_forMissingHeader() {
        XCTAssertNil(WeatherError.parseRetryAfter(from: nil))
    }

    func test_parseRetryAfter_returnsNil_forEmptyHeader() {
        XCTAssertNil(WeatherError.parseRetryAfter(from: ""))
        XCTAssertNil(WeatherError.parseRetryAfter(from: "   "))
    }

    func test_parseRetryAfter_returnsNil_forMalformedHeader() {
        XCTAssertNil(WeatherError.parseRetryAfter(from: "not a number or date"))
    }

    func test_parseRetryAfter_parsesIntegerSeconds() {
        XCTAssertEqual(WeatherError.parseRetryAfter(from: "120"), 120)
        XCTAssertEqual(WeatherError.parseRetryAfter(from: "0"), 0)
        XCTAssertEqual(WeatherError.parseRetryAfter(from: "  60  "), 60)
    }

    func test_parseRetryAfter_rejectsNegativeIntegerSeconds() {
        // Negative values are nonsensical for Retry-After; we
        // treat them as malformed rather than returning a
        // negative delay.
        XCTAssertNil(WeatherError.parseRetryAfter(from: "-30"))
    }

    func test_parseRetryAfter_parsesRFC1123Date() {
        // RFC 7231 §7.1.1.1 — IMF-fixdate format.
        // Use a date 60 seconds in the future so the result is
        // positive regardless of when the test runs.
        let future = Date().addingTimeInterval(60)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        let headerValue = formatter.string(from: future)

        let result = WeatherError.parseRetryAfter(from: headerValue)
        XCTAssertNotNil(result)
        // Allow a few seconds of slack for test execution time.
        XCTAssertEqual(result ?? 0, 60, accuracy: 5)
    }

    func test_parseRetryAfter_parsesRFC850Date() {
        // RFC 7231 §7.1.1.1 — RFC 850 format.
        let future = Date().addingTimeInterval(120)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEEE, dd-MMM-yy HH:mm:ss zzz"
        let headerValue = formatter.string(from: future)

        let result = WeatherError.parseRetryAfter(from: headerValue)
        XCTAssertNotNil(result)
        XCTAssertEqual(result ?? 0, 120, accuracy: 5)
    }

    func test_parseRetryAfter_parsesAsctimeDate() {
        // RFC 7231 §7.1.1.1 — ANSI C asctime() format.
        let future = Date().addingTimeInterval(180)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"
        let headerValue = formatter.string(from: future)

        let result = WeatherError.parseRetryAfter(from: headerValue)
        XCTAssertNotNil(result)
        XCTAssertEqual(result ?? 0, 180, accuracy: 5)
    }

    func test_parseRetryAfter_returnsZeroForPastDate() {
        // A Retry-After date in the past means "retry now" —
        // we clamp to 0 rather than returning a negative delay.
        let past = Date().addingTimeInterval(-3600)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        let headerValue = formatter.string(from: past)

        XCTAssertEqual(WeatherError.parseRetryAfter(from: headerValue), 0)
    }

    // MARK: - WeatherError.presentation — exhaustiveness

    func test_presentation_isNonEmpty_forEveryCase() {
        // Iterate every WeatherError case and verify the
        // presentation has a non-empty title and message key.
        // This catches the case where someone adds a new case
        // and forgets to update the presentation switch.
        let cases: [WeatherError] = [
            .invalidURL,
            .invalidResponse,
            .invalidAPIKey,
            .apiKeyRevoked(service: "wu"),
            .apiKeyForbidden(service: "wu"),
            .apiKeyQuotaExceeded(service: "wu"),
            .apiError("test"),
            .decodingError("test"),
            .noData,
            .httpError(statusCode: 500, retryAfter: nil),
            .httpError(statusCode: 429, retryAfter: 60),
            .noNetwork,
            .timeout,
            .staleData(age: 3600),
            .locationDenied,
            .locationRestricted,
            .locationUnavailable
        ]

        for error in cases {
            let presentation = error.presentation
            // LocalizedStringResource's `key` is the lookup key
            // in the catalog. An empty key would mean the case
            // was added without a proper localization key.
            XCTAssertFalse(
                presentation.title.key.isEmpty,
                "Missing title key for \(error)"
            )
            XCTAssertFalse(
                presentation.message.key.isEmpty,
                "Missing message key for \(error)"
            )
        }
    }

    func test_presentation_isRetryable_forTransientErrors() {
        // Transient errors should be retryable so the user can
        // tap "Try Again" without going to Settings.
        let transient: [WeatherError] = [
            .noNetwork,
            .timeout,
            .staleData(age: 3600),
            .httpError(statusCode: 500, retryAfter: nil),
            .httpError(statusCode: 429, retryAfter: 60),
            .noData,
            .locationUnavailable
        ]
        for error in transient {
            XCTAssertTrue(
                error.presentation.isRetryable,
                "\(error) should be retryable"
            )
        }
    }

    func test_presentation_isNotRetryable_forPermanentErrors() {
        // Permanent errors (auth failures, 404, restricted
        // location) should NOT be retryable — the user needs
        // to take action, not tap "Try Again" repeatedly.
        let permanent: [WeatherError] = [
            .invalidAPIKey,
            .apiKeyRevoked(service: "wu"),
            .apiKeyForbidden(service: "wu"),
            .httpError(statusCode: 401, retryAfter: nil),
            .httpError(statusCode: 404, retryAfter: nil),
            .locationDenied,
            .locationRestricted
        ]
        for error in permanent {
            XCTAssertFalse(
                error.presentation.isRetryable,
                "\(error) should NOT be retryable"
            )
        }
    }

    // MARK: - WeatherError.localizedDescription

    func test_localizedDescription_includesStatusCode_forHttpError() {
        let error = WeatherError.httpError(statusCode: 503, retryAfter: nil)
        XCTAssertTrue(error.localizedDescription.contains("503"))
    }

    func test_localizedDescription_includesRetryAfter_forHttpError() {
        let error = WeatherError.httpError(statusCode: 429, retryAfter: 60)
        XCTAssertTrue(error.localizedDescription.contains("60"))
    }
}
