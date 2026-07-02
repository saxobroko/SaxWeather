//
//  FeedbackView.swift
//  SaxWeather
//

import SwiftUI

struct FeedbackView: View {
    let initialCategory: FeedbackCategory
    let dataSource: String
    let unitSystem: String

    @State private var category: FeedbackCategory
    @State private var message = ""
    @State private var replyEmail = ""
    @State private var showingValidationAlert = false
    @State private var showingCopiedAlert = false
    @State private var showingMailComposer = false
    @State private var mailDraft: FeedbackMailDraft?
    @Environment(\.dismiss) private var dismiss

    init(
        initialCategory: FeedbackCategory,
        dataSource: String,
        unitSystem: String
    ) {
        self.initialCategory = initialCategory
        self.dataSource = dataSource
        self.unitSystem = unitSystem
        _category = State(initialValue: initialCategory)
    }

    var body: some View {
        List {
            categorySection
            messageSection
            replySection
            diagnosticsSection
            sendSection
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle(category.navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert(
            String(localized: "Message Required", comment: "Alert title when feedback message is empty."),
            isPresented: $showingValidationAlert
        ) {
            Button(String(localized: "OK", comment: "Dismiss button."), role: .cancel) {}
        } message: {
            Text(String(localized: "Please describe your feedback before sending.", comment: "Validation message for empty feedback."))
        }
        .alert(
            String(localized: "Copied to Clipboard", comment: "Alert title when mail is unavailable."),
            isPresented: $showingCopiedAlert
        ) {
            Button(String(localized: "OK", comment: "Dismiss button."), role: .cancel) {}
        } message: {
            Text(
                String(
                    localized: "No mail account is configured. Your message was copied to the clipboard — paste it into an email to \(FeedbackConfig.supportEmail).",
                    comment: "Explains clipboard fallback when Mail is unavailable."
                )
            )
        }
        #if canImport(MessageUI)
        .sheet(isPresented: $showingMailComposer) {
            if let mailDraft {
                MailComposeView(draft: mailDraft) { _ in
                    showingMailComposer = false
                    dismiss()
                }
            }
        }
        #endif
    }

    private var categorySection: some View {
        Section {
            Picker(
                String(localized: "Category", comment: "Feedback category picker label."),
                selection: $category
            ) {
                ForEach(FeedbackCategory.allCases) { item in
                    Label(item.localizedTitle, systemImage: item.symbolName)
                        .tag(item)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(String(localized: "Category", comment: "Feedback category section header."))
        }
    }

    private var messageSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text(String(localized: "Your message", comment: "Feedback message field placeholder."))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $message)
                    .frame(minHeight: 140)
                    #if os(iOS)
                    .scrollContentBackground(.hidden)
                    #endif
            }
        } header: {
            Text(String(localized: "Message", comment: "Feedback message section header."))
        } footer: {
            Text(categoryFooter)
        }
    }

    private var categoryFooter: String {
        switch category {
        case .bug:
            return String(localized: "What happened? What did you expect? Steps to reproduce help a lot.", comment: "Footer hint for bug reports.")
        case .idea:
            return String(localized: "Describe the feature and how it would help you.", comment: "Footer hint for feature requests.")
        case .other:
            return String(localized: "Questions, praise, or anything else about SaxWeather.", comment: "Footer hint for general feedback.")
        }
    }

    private var replySection: some View {
        Section {
            TextField(
                String(localized: "Email (optional)", comment: "Optional reply email field placeholder."),
                text: $replyEmail
            )
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .autocorrectionDisabled()
            #endif
        } header: {
            Text(String(localized: "Reply Email", comment: "Optional reply email section header."))
        } footer: {
            Text(String(localized: "Leave your email if you'd like a reply. It is only included in the message you send.", comment: "Privacy note for optional email."))
        }
    }

    private var diagnosticsSection: some View {
        Section {
            LabeledContent(
                String(localized: "App version", comment: "Diagnostic label for app version."),
                value: appVersion
            )
            LabeledContent(
                String(localized: "Build", comment: "Diagnostic label for build number."),
                value: buildNumber
            )
            LabeledContent(
                String(localized: "Data source", comment: "Diagnostic label for weather data source."),
                value: dataSource
            )
            LabeledContent(
                String(localized: "Unit system", comment: "Diagnostic label for unit system."),
                value: unitSystem
            )
        } header: {
            Text(String(localized: "Diagnostics", comment: "Diagnostics section header."))
        } footer: {
            Text(String(localized: "Attached automatically when you send. No API keys or personal data are included.", comment: "Diagnostics privacy footer."))
        }
    }

    private var sendSection: some View {
        Section {
            Button {
                sendFeedback()
            } label: {
                Label(
                    String(localized: "Send Feedback", comment: "Primary send feedback button."),
                    systemImage: "paperplane.fill"
                )
            }
            .buttonStyle(.plain)
            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } footer: {
            if FeedbackSender.canPresentInAppMail() {
                Text(String(localized: "Opens Mail with your message prefilled.", comment: "Send via in-app mail hint."))
            } else {
                Text(
                    String(
                        localized: "Opens your mail app, or copies the message if no mail account is set up.",
                        comment: "Send via mailto or clipboard hint."
                    )
                )
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private func sendFeedback() {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showingValidationAlert = true
            return
        }

        let draft = FeedbackSender.makeDraft(
            category: category,
            message: trimmed,
            replyEmail: replyEmail,
            dataSource: dataSource,
            unitSystem: unitSystem
        )

        switch FeedbackSender.send(draft: draft) {
        case .presentMailComposer:
            mailDraft = draft
            showingMailComposer = true
        case .openedMailApp:
            dismiss()
        case .copiedToClipboard:
            showingCopiedAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        FeedbackView(
            initialCategory: .bug,
            dataSource: "openmeteo",
            unitSystem: "Metric"
        )
    }
}
