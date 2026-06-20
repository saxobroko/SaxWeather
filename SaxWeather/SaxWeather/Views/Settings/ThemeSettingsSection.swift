//
//  ThemeSettingsSection.swift
//  SaxWeather
//
//  Phase 7 — Settings UI rebuild.
//
//  A self-contained `View` that surfaces the "infinitely
//  customisable" features in the existing Settings UI without
//  requiring a full rewrite. Drop it into any `Form` / `List`
//  and it renders three rows:
//
//    1. **Theme** — opens `ProfileSwitcherView` so the user can
//       switch to a built-in preset.
//    2. **Share Theme…** — opens `ProfileImporterView` so the user
//       can export the current theme or import a `.saxtheme` file.
//    3. **Customise everything** — deep-links to the full customisation
//       view (a follow-up phase will replace this stub with the
//       Settings UI rebuild from §4.7).
//
//  Designed to be additive — the existing `SettingsView` keeps all
//  its tabs and just gains this section at the top.
//

import SwiftUI

struct ThemeSettingsSection: View {
    @EnvironmentObject private var customisation: CustomisationRegistry

    @State private var showingProfileSwitcher = false
    @State private var showingProfileImporter = false

    var body: some View {
        Section {
            Button {
                showingProfileSwitcher = true
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme")
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
                Label("Share Theme…", systemImage: "square.and.arrow.up.on.square")
            }
            .buttonStyle(.plain)
        } header: {
            Text("Customisation")
        } footer: {
            Text("Switch between built-in themes, or share your current theme as a .saxtheme file.")
        }
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
        Form {
            ThemeSettingsSection()
        }
        .navigationTitle("Settings")
    }
    .environmentObject(CustomisationRegistry(testProfile: .makeDefault()))
}