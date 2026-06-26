//
//  CosmeticDeepLinkHandlerTests.swift
//  SaxWeatherTests
//
//  Phase 2 — URL-scheme foundation tests for the cosmetic
//  deep link handler.
//
//  Covers:
//    • `saxweather://cosmetic/<id>` parses and publishes
//      the matching product ID.
//    • Unknown product IDs are silently rejected.
//    • Malformed URLs (wrong scheme) are rejected.
//    • Non-cosmetic URLs (`saxweather://other/<x>`) are
//      rejected.
//    • `clearPending()` resets the handler.
//

import XCTest
@testable import SaxWeather

@MainActor
final class CosmeticDeepLinkHandlerTests: XCTestCase {

    // MARK: - Happy path

    func test_parsesValidURL() {
        let handler = CosmeticDeepLinkHandler()
        let url = URL(string: "saxweather://cosmetic/com.saxweather.cosmetic.aurora.lottie")!

        let accepted = handler.handle(url: url)

        XCTAssertTrue(accepted, "Handler should accept a well-formed cosmetic URL")
        XCTAssertEqual(
            handler.pendingProductID,
            "com.saxweather.cosmetic.aurora.lottie"
        )
    }

    func test_parsesValidURL_supporterPack() {
        let handler = CosmeticDeepLinkHandler()
        let url = URL(string: "saxweather://cosmetic/com.saxweather.cosmetic.supporter.pack")!

        let accepted = handler.handle(url: url)

        XCTAssertTrue(accepted)
        XCTAssertEqual(
            handler.pendingProductID,
            "com.saxweather.cosmetic.supporter.pack"
        )
    }

    // MARK: - Rejection paths

    func test_rejectsUnknownProductID() {
        let handler = CosmeticDeepLinkHandler()
        let url = URL(string: "saxweather://cosmetic/invalid.id")!

        let accepted = handler.handle(url: url)

        XCTAssertFalse(accepted, "Handler should reject unknown product IDs")
        XCTAssertNil(
            handler.pendingProductID,
            "pendingProductID should remain nil after rejection"
        )
    }

    func test_rejectsMalformedURL() {
        let handler = CosmeticDeepLinkHandler()
        let url = URL(string: "https://example.com/foo")!

        let accepted = handler.handle(url: url)

        XCTAssertFalse(accepted, "Handler should reject foreign-scheme URLs")
        XCTAssertNil(handler.pendingProductID)
    }

    func test_rejectsNonCosmeticScheme() {
        let handler = CosmeticDeepLinkHandler()
        let url = URL(string: "saxweather://other/foo")!

        let accepted = handler.handle(url: url)

        XCTAssertFalse(accepted, "Handler should reject URLs whose host isn't 'cosmetic'")
        XCTAssertNil(handler.pendingProductID)
    }

    func test_rejectsMissingProductID() {
        let handler = CosmeticDeepLinkHandler()
        // `cosmetic/<empty>` — no ID segment after the host.
        let url = URL(string: "saxweather://cosmetic/")!

        let accepted = handler.handle(url: url)

        XCTAssertFalse(accepted, "Handler should reject URLs with no product ID")
        XCTAssertNil(handler.pendingProductID)
    }

    // MARK: - clearPending

    func test_clearPendingResetsHandler() {
        let handler = CosmeticDeepLinkHandler()
        let url = URL(string: "saxweather://cosmetic/com.saxweather.cosmetic.aurora.backgrounds")!

        // Publish a valid URL, then clear.
        XCTAssertTrue(handler.handle(url: url))
        XCTAssertEqual(
            handler.pendingProductID,
            "com.saxweather.cosmetic.aurora.backgrounds"
        )

        handler.clearPending()

        XCTAssertNil(
            handler.pendingProductID,
            "clearPending() should reset pendingProductID to nil"
        )
    }

    // MARK: - handle(productID:) overload

    func test_handleProductID_overload_validatesAndPublishes() {
        let handler = CosmeticDeepLinkHandler()

        XCTAssertTrue(handler.handle(productID: "com.saxweather.cosmetic.aurora.palette"))
        XCTAssertEqual(handler.pendingProductID, "com.saxweather.cosmetic.aurora.palette")

        handler.clearPending()

        XCTAssertFalse(handler.handle(productID: "not.a.real.id"))
        XCTAssertNil(handler.pendingProductID)
    }

    // MARK: - Existing value not overwritten on rejection

    func test_rejectionDoesNotClearExistingPendingValue() {
        let handler = CosmeticDeepLinkHandler()
        let validURL = URL(string: "saxweather://cosmetic/com.saxweather.cosmetic.aurora.lottie")!
        let badURL = URL(string: "https://example.com/foo")!

        // Publish a valid value first.
        XCTAssertTrue(handler.handle(url: validURL))
        XCTAssertEqual(handler.pendingProductID, "com.saxweather.cosmetic.aurora.lottie")

        // A subsequent bad URL should be rejected, but the
        // pending value should NOT be wiped (the consumer
        // hasn't called `clearPending()` yet).
        XCTAssertFalse(handler.handle(url: badURL))
        XCTAssertEqual(
            handler.pendingProductID,
            "com.saxweather.cosmetic.aurora.lottie",
            "Rejection must not clobber an unconsumed pendingProductID"
        )
    }
}
