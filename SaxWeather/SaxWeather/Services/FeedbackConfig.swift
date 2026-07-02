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
    static let supportEmail = "rascalxena@y7mail.com"
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
    let body: String
}

enum FeedbackDiagnostics {
    static func footer(dataSource: String, unitSystem: String) -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

        return """

        ---
        Diagnostics (please don't remove)
        App: \(FeedbackConfig.appName) \(version) (\(build))
        \(platformLine())
        Data source: \(dataSource)
        Unit system: \(unitSystem)
        ---
        """
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

        var body = trimmedMessage
        let email = replyEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !email.isEmpty {
            body += "\n\nReply-to: \(email)"
        }
        body += FeedbackDiagnostics.footer(dataSource: dataSource, unitSystem: unitSystem)

        return FeedbackMailDraft(
            recipients: [FeedbackConfig.supportEmail],
            subject: subject,
            body: body
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
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = draft.recipients.joined(separator: ",")
        components.queryItems = [
            URLQueryItem(name: "subject", value: draft.subject),
            URLQueryItem(name: "body", value: draft.body)
        ]
        return components.url
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
