//
//  CosmeticDeepLinkHandler.swift
//  SaxWeather
//
//  Phase 2 — URL-scheme foundation for cosmetics.
//
//  Parses incoming `saxweather://cosmetic/<productID>` URLs
//  and publishes the resolved product ID so the SwiftUI
//  layer can navigate to the right cosmetic detail sheet.
//
//  Why a dedicated handler?
//  ------------------------
//  * `SaxWeatherApp`'s `.onOpenURL` modifier needs a
//    `@MainActor` observable it can route to.
//  * Validation (product ID exists in the catalog) is
//    centralised here so every consumer sees the same
//    answer.
//  * The handler is `@MainActor` and `ObservableObject` so it
//    plays nicely with SwiftUI's `@StateObject` /
//    `@EnvironmentObject` patterns — same shape as
//    `StoreManager`.
//
//  URL shape
//  ---------
//  * `saxweather://cosmetic/<productID>` — valid. The
//    `<productID>` is validated against
//    `CosmeticCatalog.allProducts`.
//  * `saxweather://other/<anything>` — rejected (wrong host).
//  * `https://example.com/foo` — rejected (wrong scheme).
//  * Anything that doesn't parse as a URL — rejected.
//
//  Why a class instead of a free function?
//  ---------------------------------------
//  SwiftUI's `.onOpenURL` is fire-and-forget; there's no
//  built-in place to "publish a value to be consumed by the
//  next view render". An `ObservableObject` solves this — the
//  view that cares (`ContentView`) observes `pendingProductID`
//  and re-renders when it changes.
//
//  Concurrency
//  -----------
//  All public surface is `@MainActor`-isolated so callers
//  don't need to think about thread hops. The parser itself
//  is pure and synchronous; URL parsing is cheap enough that
//  dispatching to a background queue would cost more than it
//  saves.
//

import Foundation
import SwiftUI

/// Parses `saxweather://cosmetic/<productID>` URLs and
/// publishes the validated product ID so the UI layer can
/// present `CosmeticDetailView` for the matching product.
///
/// Injected as a `@StateObject` in `SaxWeatherApp` and
/// observed by `ContentView`. Tests instantiate it directly
/// to drive `handle(url:)` synchronously.
@MainActor
final class CosmeticDeepLinkHandler: ObservableObject {

    /// The most recently received valid product ID, or
    /// `nil` if no deep link has been processed (or the
    /// handler was cleared). SwiftUI views observe this and
    /// react by presenting `CosmeticDetailView`.
    ///
    /// Cleared via `clearPending()` after the consumer reads
    /// it, so a stale value doesn't re-trigger the same
    /// presentation on the next render pass.
    @Published private(set) var pendingProductID: String?

    // MARK: - URL scheme constants

    /// The URL scheme registered in `Info.plist`. Public so
    /// tests and the `.onOpenURL` modifier can reference the
    /// same string.
    static let scheme = "saxweather"

    /// The URL host this handler responds to (i.e. the
    /// segment after `saxweather://`).
    static let host = "cosmetic"

    // MARK: - Public API

    /// Process an incoming URL. Returns `true` if the URL was
    /// a well-formed `saxweather://cosmetic/<id>` pointing at
    /// a known product (in which case `pendingProductID` is
    /// set). Returns `false` for malformed, foreign-scheme,
    /// wrong-host, or unknown-product-ID URLs — `pendingProductID`
    /// is left untouched in those cases so a previously-set
    /// pending value isn't accidentally cleared.
    @discardableResult
    func handle(url: URL) -> Bool {
        guard url.scheme?.lowercased() == Self.scheme else {
            #if DEBUG
            print("ℹ️ CosmeticDeepLinkHandler: rejected URL with scheme \(url.scheme ?? "nil")")
            #endif
            return false
        }

        // Use `host` rather than `URLComponents.host` because
        // `host` for custom-scheme URLs is `nil` on some
        // iOS versions — the `host` segment is exposed via
        // the path on `saxweather://cosmetic/<id>` URLs.
        guard let host = url.host?.lowercased(), host == Self.host else {
            // Fallback: check the path's first segment too,
            // since `URLComponents` may parse the URL
            // differently from `URL.host`.
            let firstSegment = url.pathComponents.first(where: { $0 != "/" })
            guard firstSegment?.lowercased() == Self.host else {
                #if DEBUG
                print("ℹ️ CosmeticDeepLinkHandler: rejected URL with host \(url.host ?? "nil") / first segment \(firstSegment ?? "nil")")
                #endif
                return false
            }
            return validateAndPublish(id: extractProductID(from: url))
        }

        return validateAndPublish(id: extractProductID(from: url))
    }

    /// Convenience for pre-parsed strings (mostly used by
    /// tests and by callers that already hold the product ID).
    /// Does the same validation as `handle(url:)` but skips
    /// the URL parsing layer.
    @discardableResult
    func handle(productID: String) -> Bool {
        validateAndPublish(id: productID)
    }

    /// Clear `pendingProductID`. The UI calls this after it
    /// has presented the detail sheet so the same pending
    /// value doesn't re-trigger presentation on a re-render.
    func clearPending() {
        pendingProductID = nil
    }

    // MARK: - Private helpers

    /// Pull the product ID segment out of a `cosmetic/<id>`
    /// URL. Returns the trimmed string when the shape is
    /// right, otherwise `nil`.
    private func extractProductID(from url: URL) -> String? {
        // `URL.pathComponents` for `saxweather://cosmetic/abc`
        // yields `["/", "abc"]` on most iOS versions — strip
        // the leading slash and take the first non-empty
        // segment. We also tolerate a deeper path so a future
        // `cosmetic/<id>/<action>` extension keeps working
        // (we'd take the first segment after `cosmetic`).
        let components = url.pathComponents.filter { $0 != "/" }
        guard let first = components.first else { return nil }
        let trimmed = first.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Verify the supplied ID exists in `CosmeticCatalog` and
    /// publish it on `pendingProductID`. Returns `true` if
    /// the publish happened.
    private func validateAndPublish(id: String?) -> Bool {
        guard let id = id, !id.isEmpty else { return false }
        guard CosmeticCatalog.product(id: id) != nil else {
            #if DEBUG
            print("ℹ️ CosmeticDeepLinkHandler: rejected unknown product ID '\(id)'")
            #endif
            return false
        }
        pendingProductID = id
        return true
    }
}