// ShortcutIntegrationService.swift
// Handles iOS Shortcuts integration for automated data import

import Foundation
import Intents

@available(iOS 17.0, *)
final class ShortcutIntegrationService {
    
    static let shared = ShortcutIntegrationService()
    
    private init() {}
    
    // MARK: - Shortcut URLs
    
    /// URL scheme for importing data via shortcuts
    static let importURLScheme = "saxtrack://import"
    
    /// Handle incoming URL from Shortcuts
    func handleShortcutURL(_ url: URL) -> ShortcutImportData? {
        guard url.scheme == "saxtrack",
              url.host == "import" else {
            return nil
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        guard let typeString = components?.queryItems?.first(where: { $0.name == "type" })?.value,
              let type = ImportType(rawValue: typeString),
              let dataString = components?.queryItems?.first(where: { $0.name == "data" })?.value else {
            return nil
        }
        
        // Decode base64 if needed
        let usernames: [String]
        if let decoded = Data(base64Encoded: dataString),
           let decodedString = String(data: decoded, encoding: .utf8) {
            usernames = parseUsernames(from: decodedString)
        } else {
            usernames = parseUsernames(from: dataString)
        }
        
        return ShortcutImportData(type: type, usernames: usernames)
    }
    
    /// Parse usernames from comma or newline separated string
    private func parseUsernames(from string: String) -> [String] {
        string.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    // MARK: - Clipboard Detection
    
    /// Check if clipboard contains Instagram data
    func detectInstagramDataInClipboard() async -> ClipboardData? {
        #if os(iOS)
        guard let pasteboard = UIPasteboard.general.string else {
            return nil
        }
        
        // Try to detect format
        if pasteboard.contains("instagram.com") || pasteboard.contains("\"value\":") {
            // Might be JSON
            if let data = pasteboard.data(using: .utf8),
               let parsed = try? InstagramJSONParser.autoParseUsernames(from: data) {
                return ClipboardData(
                    usernames: parsed.usernames,
                    type: parsed.type == .followers ? .followers : .following,
                    format: .json
                )
            }
        }
        
        // Try simple username list
        let lines = pasteboard.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 0 && $0.count < 31 } // Instagram username limits
        
        if lines.count >= 3 { // At least 3 usernames to be valid
            return ClipboardData(
                usernames: lines,
                type: nil, // Unknown, user must specify
                format: .plainText
            )
        }
        #endif
        
        return nil
    }
    
    // MARK: - Supporting Types
    
    struct ShortcutImportData {
        let type: ImportType
        let usernames: [String]
    }
    
    struct ClipboardData {
        let usernames: [String]
        let type: ImportType?
        let format: ClipboardFormat
    }
    
    enum ImportType: String {
        case followers
        case following
    }
    
    enum ClipboardFormat {
        case json
        case plainText
    }
}
