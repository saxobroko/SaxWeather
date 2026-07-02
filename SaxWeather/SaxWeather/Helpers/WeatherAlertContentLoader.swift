
import Foundation

enum WeatherAlertContentLoader {

    struct Content {
        var text: String?
        var imageData: Data?

        var isEmpty: Bool { text == nil && imageData == nil }
    }

    static func sourceHomepageURL(for source: String) -> URL? {
        switch source.lowercased() {
        case "bom":
            return URL(string: "https://www.bom.gov.au/weather-and-climate/warnings-and-alerts")
        case "weatherkit":
            return URL(string: "https://weather.apple.com")
        default:
            return nil
        }
    }

    static func sourceLinkLabel(for source: String) -> String {
        switch source.lowercased() {
        case "bom":
            return "View on Bureau of Meteorology"
        case "weatherkit":
            return "View on Apple Weather"
        default:
            return "View source website"
        }
    }

    static func detailLinkLabel(for source: String) -> String {
        switch source.lowercased() {
        case "bom":
            return "Open full warning"
        case "weatherkit":
            return "Open full alert details"
        default:
            return "Open full details"
        }
    }

    static func loadDetailContent(from url: URL, source: String) async -> Content {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 25

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let html = String(data: data, encoding: .utf8) else {
                return Content()
            }

            let imageData = extractEmbeddedImage(from: html)
            let sanitized = removeNonContentBlocks(from: html)
            let text: String?
            if source.lowercased() == "bom" {
                text = extractBOMMainText(from: sanitized)
            } else {
                text = extractPlainText(from: sanitized)
            }
            return Content(text: text, imageData: imageData)
        } catch {
            return Content()
        }
    }

    /// Extracts the first embedded base64 image (BOM warning maps are inlined
    /// as `data:image/...;base64,...` in an `<img>` tag).
    private static func extractEmbeddedImage(from html: String) -> Data? {
        guard let match = html.range(
            of: "data:image/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+/=\\s]+",
            options: .regularExpression
        ) else {
            return nil
        }

        let dataURI = String(html[match])
        guard let commaIndex = dataURI.firstIndex(of: ",") else { return nil }
        let base64 = dataURI[dataURI.index(after: commaIndex)...]
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()

        return Data(base64Encoded: base64)
    }

    private static func extractBOMMainText(from html: String) -> String? {
        guard let mainRange = html.range(of: "<div id=\"main\">") else {
            return extractPlainText(from: html)
        }
        let mainHTML = String(html[mainRange.lowerBound...])
        let paragraphs = extractParagraphs(from: mainHTML)
        let joined = paragraphs.joined(separator: "\n\n")
        return joined.isEmpty ? nil : joined
    }

    private static func extractParagraphs(from html: String) -> [String] {
        var results: [String] = []
        var searchRange = html.startIndex..<html.endIndex

        while let open = html.range(of: "<p", options: .caseInsensitive, range: searchRange),
              let closeStart = html.range(of: ">", range: open.upperBound..<html.endIndex),
              let close = html.range(of: "</p>", options: .caseInsensitive, range: closeStart.upperBound..<html.endIndex) {
            let inner = String(html[closeStart.upperBound..<close.lowerBound])
            let text = decodeHTML(stripTags(from: inner))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty,
               !text.hasPrefix("IDV"),
               text != "TOP PRIORITY FOR IMMEDIATE BROADCAST",
               !looksLikeCode(text) {
                results.append(text)
            }
            searchRange = close.upperBound..<html.endIndex
        }

        return results
    }

    private static func extractPlainText(from html: String) -> String? {
        let text = decodeHTML(stripTags(from: html))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || looksLikeCode(text) { return nil }
        return text
    }

    /// Detects leftover JavaScript/markup fragments (e.g. Google Tag Manager)
    /// that should never be shown as warning copy.
    private static func looksLikeCode(_ text: String) -> Bool {
        let markers = [
            "function(", "function (", "dataLayer", "gtm.", "googletagmanager",
            "window.", "document.", "var ", "();", "){", "//<![cdata[", "addeventlistener"
        ]
        let lower = text.lowercased()
        return markers.contains { lower.contains($0.lowercased()) }
    }

    /// Removes elements whose text content is not human-readable copy
    /// (scripts, styles, etc.) so their bodies don't leak into extracted text.
    private static func removeNonContentBlocks(from html: String) -> String {
        var cleaned = html
        let blockTags = ["script", "style", "noscript", "head", "template", "svg", "iframe"]
        for tag in blockTags {
            let pattern = "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)>"
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        // Drop HTML comments (can contain conditional scripts).
        cleaned = cleaned.replacingOccurrences(
            of: "<!--[\\s\\S]*?-->",
            with: " ",
            options: .regularExpression
        )
        return cleaned
    }

    private static func stripTags(from html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    }

    private static func decodeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
    }
}
