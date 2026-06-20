//
//  ProfileImporterView.swift
//  SaxWeather
//
//  Phase 7 — Settings UI rebuild.
//
//  Export and import `.saxtheme` profiles. The view is a single
//  sheet with two sections:
//
//    1. **Export** — exports the active profile to a `.saxtheme`
//       JSON file in the user's Documents directory and presents a
//       `ShareLink` so the user can AirDrop it, save it to Files,
//       or share it any other way. Credentials
//       (`wuApiKey` / `stationID` / `owmApiKey`) are stripped from
//       the export by default — honouring `shareThemeOnExport`.
//
//    2. **Import** — opens a `.fileImporter` for `.saxtheme` files.
//       The selected file is read, validated, migrated via
//       `ProfileMigrator`, and a confirmation alert appears before
//       the imported profile is applied via
//       `CustomisationRegistry.apply(_:)`.
//
//  See `plans/INFINITE_CUSTOMISATION_PLAN.md` §2.9 and §4.7.
//

import SwiftUI
import UniformTypeIdentifiers

struct ProfileImporterView: View {
    @EnvironmentObject private var customisation: CustomisationRegistry
    @Environment(\.dismiss) private var dismiss

    /// The custom UTType for `.saxtheme` files. Falls back to
    /// `json` if the UTI isn't registered (e.g. older app builds
    /// that pre-date the Phase 8 Info.plist update).
    static let saxthemeContentType: UTType = {
        UTType("com.saxobroko.saxtheme") ?? .json
    }()

    @State private var exportedURL: URL?
    @State private var exportError: String?
    @State private var showingFileImporter = false
    @State private var pendingImportURL: URL?
    @State private var pendingImportProfile: CustomisationProfile?
    @State private var importError: String?
    @State private var showingImportConfirmation = false
    @State private var stripCredentials = true

    var body: some View {
        NavigationStack {
            Form {
                exportSection
                importSection
            }
            .navigationTitle("Share Theme")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [Self.saxthemeContentType, .json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImporterResult(result)
            }
            .alert("Import Theme?",
                   isPresented: $showingImportConfirmation,
                   presenting: pendingImportProfile) { profile in
                Button("Apply", role: .destructive) {
                    applyImport(profile)
                }
                Button("Cancel", role: .cancel) {
                    pendingImportProfile = nil
                    pendingImportURL = nil
                }
            } message: { profile in
                Text("'\(profile.name)' will replace your current theme.")
            }
            .alert("Import Failed",
                   isPresented: .constant(importError != nil),
                   presenting: importError) { _ in
                Button("OK", role: .cancel) { importError = nil }
            } message: { message in
                Text(message)
            }
            .alert("Export Failed",
                   isPresented: .constant(exportError != nil),
                   presenting: exportError) { _ in
                Button("OK", role: .cancel) { exportError = nil }
            } message: { message in
                Text(message)
            }
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        Section {
            if let url = exportedURL {
                ShareLink(item: url) {
                    Label("Share \(url.lastPathComponent)", systemImage: "square.and.arrow.up")
                }
                Button {
                    doExport()
                } label: {
                    Label("Export Again", systemImage: "arrow.clockwise")
                }
            } else {
                Button {
                    doExport()
                } label: {
                    Label("Export Current Theme", systemImage: "square.and.arrow.up")
                }
            }

            Toggle("Strip credentials before sharing", isOn: $stripCredentials)
        } header: {
            Text("Export")
        } footer: {
            Text("Exports your current theme as a .saxtheme file. Credentials (API keys) are removed before sharing.")
        }
    }

    private func doExport() {
        do {
            let url = try customisation.exportProfile()
            exportedURL = url
            exportError = nil
        } catch {
            exportError = error.localizedDescription
            exportedURL = nil
        }
    }

    // MARK: - Import

    private var importSection: some View {
        Section {
            Button {
                showingFileImporter = true
            } label: {
                Label("Choose .saxtheme File…", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Import")
        } footer: {
            Text("Imports a .saxtheme file from Files, AirDrop, or another app. Your current theme is replaced.")
        }
    }

    private func handleFileImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            pendingImportURL = url
            validateImport(from: url)
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func validateImport(from url: URL) {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let data = try Data(contentsOf: url)
            let profile = try ProfileMigrator.migrate(data)
            pendingImportProfile = profile
            importError = nil
            showingImportConfirmation = true
        } catch {
            importError = humanReadable(error)
            pendingImportProfile = nil
        }
    }

    private func applyImport(_ profile: CustomisationProfile) {
        customisation.apply(profile)
        pendingImportProfile = nil
        pendingImportURL = nil
        #if canImport(UIKit)
        HapticFeedbackHelper.shared.light()
        #endif
        dismiss()
    }

    private func humanReadable(_ error: Error) -> String {
        if let migratorError = error as? ProfileMigratorError {
            switch migratorError {
            case .unsupportedVersion(let v):
                return "This theme was made for a newer version of SaxWeather (schema v\(v))."
            case .invalidFormat:
                return "The file isn't a valid .saxtheme document."
            }
        }
        return error.localizedDescription
    }
}