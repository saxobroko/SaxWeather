//
//  SettingsBackupAndRestoreView.swift
//  SaxWeather
//
//  Phase 7 — Settings UI rebuild.
//
//  A dedicated sub-page that surfaces the "infinitely customisable"
//  features under the "Settings Backup and Restore" branding. The
//  underlying mechanism is still theme/profile switching plus
//  `.saxtheme` import/export, but it is now framed for users as
//  backing up their settings and restoring them — either from a
//  built-in preset or from a shared `.saxtheme` file.
//
//  Two rows are exposed inside a single Section:
//
//    1. **Active Backup** — opens `ProfileSwitcherView` so the user
//       can switch to a built-in preset (functionally a "restore
//       from a bundled backup").
//    2. **Back Up & Share Settings…** — opens `ProfileImporterView`
//       so the user can export their current settings as a
//       `.saxtheme` file, or restore from one they have received.
//
//  Designed to be reached via a `NavigationLink` from the main
//  Settings list — it owns its own `navigationTitle` so it reads
//  correctly when pushed onto the settings stack.
//

import SwiftUI

struct SettingsBackupAndRestoreView: View {
    @EnvironmentObject private var customisation: CustomisationRegistry

    @State private var showingProfileSwitcher = false
    @State private var showingProfileImporter = false

    var body: some View {
        List {
            Section {
                Button {
                    showingProfileSwitcher = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Active Backup")
                            Text(customisation.profile.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: customisation.profile.builtIn.symbolName)
                            .foregroundStyle(customisation.profile.builtIn.tint)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    showingProfileImporter = true
                } label: {
                    Label("Back Up & Share Settings…", systemImage: "square.and.arrow.up.on.square")
                }
                .buttonStyle(.plain)
            } header: {
                Text("Settings Backup and Restore")
            } footer: {
                Text("Switch between built-in backups, or share your current settings as a .saxtheme file. Use the search bar above to find any setting.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingProfileSwitcher) {
            ProfileSwitcherView()
        }
        .sheet(isPresented: $showingProfileImporter) {
            ProfileImporterView()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsBackupAndRestoreView()
            .navigationTitle("Settings")
    }
    .environmentObject(CustomisationRegistry(testProfile: .makeDefault()))
}