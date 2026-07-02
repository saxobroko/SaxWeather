//
//  FeedbackConfig.swift
//  SaxWeather
//

import Foundation
#if canImport(MessageUI)
import MessageUI
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Developer-facing constants for in-app feedback.
/// Change `supportEmail` here if the contact address moves.
enum FeedbackConfig {
    static let supportEmail = "weatherapp@saxobroko.com"
    static let appName = "SaxWeather"
}

enum FeedbackCategory: String, CaseIterable, Identifiable, Hashable {
    case bug
    case idea
    case other

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .bug:
            return String(localized: "Bug Report", comment: "Feedback category for reporting bugs.")
        case .idea:
            return String(localized: "Feature Idea", comment: "Feedback category for feature requests.")
        case .other:
            return String(localized: "Other", comment: "Feedback category for general feedback.")
        }
    }

    var navigationTitle: String {
        switch self {
        case .bug:
            return String(localized: "Send Feedback", comment: "Navigation title for bug feedback form.")
        case .idea:
            return String(localized: "Request a Feature", comment: "Navigation title for feature request form.")
        case .other:
            return String(localized: "Contact Developer", comment: "Navigation title for general feedback form.")
        }
    }

    var subjectTag: String {
        switch self {
        case .bug: return "Bug Report"
        case .idea: return "Feature Idea"
        case .other: return "Feedback"
        }
    }

    var symbolName: String {
        switch self {
        case .bug: return "ladybug.fill"
        case .idea: return "lightbulb.fill"
        case .other: return "envelope.fill"
        }
    }
}

struct FeedbackMailDraft: Equatable {
    let recipients: [String]
    let subject: String
    /// Plain text for clipboard fallback.
    let body: String
    /// Explicit HTML with `<br>` tags — Mail collapses raw newlines otherwise.
    let htmlBody: String
}

enum FeedbackMailBodyFormatter {
    static func normalizeNewlines(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    static func plainTextBody(
        message: String,
        replyEmail: String,
        dataSource: String,
        unitSystem: String
    ) -> String {
        var lines = linesFromMessage(message)
        if !replyEmail.isEmpty {
            lines.append("")
            lines.append("Reply-to: \(replyEmail)")
        }
        lines.append(contentsOf: FeedbackDiagnostics.plainLines(dataSource: dataSource, unitSystem: unitSystem))
        return lines.joined(separator: "\n")
    }

    static func htmlBody(
        message: String,
        replyEmail: String,
        dataSource: String,
        unitSystem: String
    ) -> String {
        var lines = linesFromMessage(message)
        if !replyEmail.isEmpty {
            lines.append("")
            lines.append("Reply-to: \(replyEmail)")
        }
        lines.append(contentsOf: FeedbackDiagnostics.plainLines(dataSource: dataSource, unitSystem: unitSystem))

        let htmlLines = lines.map { line -> String in
            let escaped = htmlEscape(line)
            return escaped.isEmpty ? "&nbsp;" : escaped
        }

        let content = htmlLines.joined(separator: "<br>")
        return """
        <html><head><meta charset="utf-8"></head><body style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;font-size:14px;line-height:1.5;color:#000000;">\(content)</body></html>
        """
    }

    private static func linesFromMessage(_ message: String) -> [String] {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return normalizeNewlines(trimmed).components(separatedBy: "\n")
    }

    private static func htmlEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// `URLQueryAllowed` leaves newlines unencoded; mailto handlers then collapse them to spaces.
    static func mailtoParameter(_ value: String) -> String {
        normalizeNewlines(value).unicodeScalars.map { scalar in
            switch scalar {
            case "\n":
                return "%0D%0A"
            case "\r":
                return ""
            default:
                let character = String(scalar)
                let encoded = character.addingPercentEncoding(
                    withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))
                ) ?? character
                return encoded
            }
        }.joined()
    }
}

enum FeedbackDiagnostics {
    static func plainLines(dataSource: String, unitSystem: String) -> [String] {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

        return [
            "",
            "---",
            "Diagnostics (please don't remove)",
            "App: \(FeedbackConfig.appName) \(version) (\(build))",
            platformLine(),
            "Data source: \(dataSource)",
            "Unit system: \(unitSystem)",
            "---"
        ]
    }

    private static func platformLine() -> String {
        #if os(iOS)
        return "iOS: \(UIDevice.current.systemVersion)"
        #elseif os(macOS)
        return "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)"
        #else
        return "Platform: \(ProcessInfo.processInfo.operatingSystemVersionString)"
        #endif
    }
}

enum FeedbackSendOutcome: Equatable {
    case presentMailComposer(FeedbackMailDraft)
    case openedMailApp
    case copiedToClipboard
}

enum FeedbackSender {
    static func canPresentInAppMail() -> Bool {
        #if canImport(MessageUI)
        MFMailComposeViewController.canSendMail()
        #else
        false
        #endif
    }

    static func makeDraft(
        category: FeedbackCategory,
        message: String,
        replyEmail: String,
        dataSource: String,
        unitSystem: String
    ) -> FeedbackMailDraft {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = "[\(FeedbackConfig.appName)] \(category.subjectTag)"
        let email = replyEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        return FeedbackMailDraft(
            recipients: [FeedbackConfig.supportEmail],
            subject: subject,
            body: FeedbackMailBodyFormatter.plainTextBody(
                message: trimmedMessage,
                replyEmail: email,
                dataSource: dataSource,
                unitSystem: unitSystem
            ),
            htmlBody: FeedbackMailBodyFormatter.htmlBody(
                message: trimmedMessage,
                replyEmail: email,
                dataSource: dataSource,
                unitSystem: unitSystem
            )
        )
    }

    static func send(draft: FeedbackMailDraft) -> FeedbackSendOutcome {
        #if canImport(MessageUI)
        if MFMailComposeViewController.canSendMail() {
            return .presentMailComposer(draft)
        }
        #endif

        if let mailtoURL = mailtoURL(for: draft), openURL(mailtoURL) {
            return .openedMailApp
        }

        copyToClipboard(clipboardText(for: draft))
        return .copiedToClipboard
    }

    private static func mailtoURL(for draft: FeedbackMailDraft) -> URL? {
        let to = draft.recipients.joined(separator: ",")
        let subject = FeedbackMailBodyFormatter.mailtoParameter(draft.subject)
        let body = FeedbackMailBodyFormatter.mailtoParameter(draft.body)
        return URL(string: "mailto:\(to)?subject=\(subject)&body=\(body)")
    }

    private static func openURL(_ url: URL) -> Bool {
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        return true
        #elseif canImport(AppKit)
        return NSWorkspace.shared.open(url)
        #else
        return false
        #endif
    }

    private static func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    private static func clipboardText(for draft: FeedbackMailDraft) -> String {
        """
        To: \(draft.recipients.joined(separator: ", "))
        Subject: \(draft.subject)

        \(draft.body)
        """
    }
}
