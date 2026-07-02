
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct ThemeEditorCard: View {
    @EnvironmentObject private var customisation: CustomisationRegistry

    @State private var jsonString: String = ""
    @State private var lastRefresh: Date = .distantPast
    @State private var actionMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            jsonPreview
            actions
            if let message = actionMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
        .onAppear(perform: refresh)
        .onChange(of: customisation.profile) { _ in
            refresh()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "paintpalette.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
                Text("Theme Editor")
                    .font(.title2.bold())
                Spacer()
                Text("Schema v\(customisation.profile.schemaVersion)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text("Live JSON view of the active customisation profile.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var jsonPreview: some View {
        ScrollView {
            Text(jsonString.isEmpty ? "Loading…" : jsonString)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(8)
        }
        .frame(maxHeight: 240)
        #if canImport(UIKit)
        .background(Color(.systemBackground).opacity(0.6))
        #elseif canImport(AppKit)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
        #else
        .background(Color.white.opacity(0.6))
        #endif
        .cornerRadius(8)
    }

    private var actions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                actionButton(
                    title: "Reveal in Finder",
                    systemImage: "folder",
                    color: .blue
                ) {
                    revealInFinder()
                }
                actionButton(
                    title: "Reload",
                    systemImage: "arrow.clockwise",
                    color: .orange
                ) {
                    customisation.reloadFromDisk()
                    refresh()
                    actionMessage = String(localized: "Reloaded from disk.")
                }
            }
            actionButton(
                title: "Reset to Defaults",
                systemImage: "arrow.uturn.backward",
                color: .red
            ) {
                customisation.resetTo(.default)
                refresh()
                actionMessage = String(localized: "Reset to Default profile.")
            }
        }
    }

    private func actionButton(
        title: LocalizedStringKey,
        systemImage: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }

    // MARK: - Actions

    private func refresh() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(customisation.profile),
           let string = String(data: data, encoding: .utf8) {
            jsonString = string
        }
        lastRefresh = Date()
    }

    private func revealInFinder() {
        #if canImport(AppKit)
        guard let url = customisation.profileFileURL else {
            actionMessage = String(localized: "Profile file isn't available outside a signed app context.")
            return
        }
        // Ensure the file exists so Finder can reveal it.
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // Trigger a persist by setting the same knobs.
            customisation.setKnobs(customisation.profile.knobs)
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        actionMessage = String(localized: "Revealed \(url.lastPathComponent) in Finder.")
        #else
        actionMessage = String(localized: "Reveal in Finder is only available on macOS.")
        #endif
    }
}