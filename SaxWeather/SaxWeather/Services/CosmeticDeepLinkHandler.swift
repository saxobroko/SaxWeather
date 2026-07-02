
import Foundation
import SwiftUI

@MainActor
final class CosmeticDeepLinkHandler: ObservableObject {

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