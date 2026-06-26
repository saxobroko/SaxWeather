//
//  ProfileSwitcherView.swift
//  SaxWeather
//
//  Phase 7 — Settings UI rebuild.
//
//  A sheet that lists every built-in profile and every user-saved
//  profile and lets the user switch to one with a single tap.
//
//  Layout:
//
//    1. **Built-in Profiles** — the five non-deletable presets
//       (Default / Minimalist / Power User / Accessibility / Battery
//       Saver). Tapping a row applies it via
//       `CustomisationRegistry.resetTo(_:)`, which writes through
//       to UserDefaults, persists the profile to the App Group, and
//       reloads widget timelines.
//    2. **Saved Profiles** — user-named profiles from
//       `CustomisationRegistry.savedProfiles`. Tapping applies via
//       `applySavedProfile(id:)`. Swipe-to-delete + a rename
//       alert on long-press.
//    3. **Save Current as New…** — a footer action that prompts
//       for a name and calls `saveCurrentAs(name:)`.
//

import SwiftUI

struct ProfileSwitcherView: View {
    @EnvironmentObject private var customisation: CustomisationRegistry
    @Environment(\.dismiss) private var dismiss

    /// Optional callback fired after a successful switch. Lets the
    /// parent view show a confirmation toast without having to
    /// observe the registry directly.
    var onSelect: ((BuiltInProfile) -> Void)? = nil

    @State private var renameTarget: CustomisationProfile?
    @State private var renameText: String = ""
    @State private var showingNewProfileAlert = false
    @State private var newProfileName: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(BuiltInProfile.allCases) { profile in
                        Button {
                            select(profile)
                        } label: {
                            ProfileRow(
                                profile: profile,
                                isActive: customisation.profile.builtIn == profile
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Built-in Profiles")
                } footer: {
                    Text("Switching applies the preset immediately. You can tweak individual settings afterwards.")
                }

                if !customisation.savedProfiles.isEmpty {
                    Section {
                        ForEach(customisation.savedProfiles) { saved in
                            Button {
                                apply(saved)
                            } label: {
                                SavedProfileRow(
                                    profile: saved,
                                    isActive: customisation.profile.id == saved.id
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    customisation.deleteSavedProfile(id: saved.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    beginRename(saved)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    } header: {
                        Text("Saved Profiles")
                    } footer: {
                        Text("Swipe a profile to rename or delete it.")
                    }
                }

                Section {
                    Button {
                        newProfileName = ""
                        showingNewProfileAlert = true
                    } label: {
                        Label("Save Current as New…", systemImage: "plus.square.on.square")
                    }
                }
            }
            .navigationTitle("Theme")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Save Current Theme", isPresented: $showingNewProfileAlert) {
                TextField("Profile name", text: $newProfileName)
                Button("Save") {
                    let trimmed = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    customisation.saveCurrentAs(name: trimmed)
                    #if canImport(UIKit)
                    HapticFeedbackHelper.shared.light()
                    #endif
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Give this theme a name so you can switch back to it later.")
            }
            .alert("Rename Profile",
                   isPresented: .constant(renameTarget != nil),
                   presenting: renameTarget) { target in
                TextField("Profile name", text: $renameText)
                Button("Rename") {
                    customisation.renameSavedProfile(id: target.id, to: renameText)
                    renameTarget = nil
                }
                Button("Cancel", role: .cancel) {
                    renameTarget = nil
                }
            } message: { target in
                Text("Rename '\(target.name)'.")
            }
        }
    }

    private func select(_ profile: BuiltInProfile) {
        guard customisation.profile.builtIn != profile else {
            dismiss()
            return
        }
        customisation.resetTo(profile)
        onSelect?(profile)
        #if canImport(UIKit)
        HapticFeedbackHelper.shared.light()
        #endif
        dismiss()
    }

    private func apply(_ saved: CustomisationProfile) {
        guard customisation.profile.id != saved.id else {
            dismiss()
            return
        }
        customisation.applySavedProfile(id: saved.id)
        #if canImport(UIKit)
        HapticFeedbackHelper.shared.light()
        #endif
        dismiss()
    }

    private func beginRename(_ profile: CustomisationProfile) {
        renameText = profile.name
        renameTarget = profile
    }
}

// MARK: - Rows

private struct ProfileRow: View {
    let profile: BuiltInProfile
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: profile.symbolName)
                .font(.title2)
                .foregroundStyle(profile.tint)
                .frame(width: 36, height: 36)
                .background(profile.tint.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(profile.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}

private struct SavedProfileRow: View {
    let profile: CustomisationProfile
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.square.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
                .frame(width: 36, height: 36)
                .background(Color.indigo.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text("Saved \(profile.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}

// MARK: - BuiltInProfile display helpers

extension BuiltInProfile {
    /// SF Symbol used as the row icon.
    var symbolName: String {
        switch self {
        case .default:       return "circle.fill"
        case .minimalist:    return "leaf.fill"
        case .powerUser:     return "bolt.fill"
        case .accessibility: return "accessibility"
        case .batterySaver:  return "battery.50"
        }
    }

    /// Tint applied to the row icon.
    var tint: Color {
        switch self {
        case .default:       return .blue
        case .minimalist:    return .green
        case .powerUser:     return .orange
        case .accessibility: return .purple
        case .batterySaver:  return .yellow
        }
    }

    /// One-line description shown under the profile name.
    var subtitle: String {
        switch self {
        case .default:
            return "Ships with the app — matches every default setting."
        case .minimalist:
            return "Less is more. No animations, 3-day forecast, larger text."
        case .powerUser:
            return "Everything visible. 14-day forecast, 48-hour hourly, charts."
        case .accessibility:
            return "High legibility. Bold text, contrast, reduce motion."
        case .batterySaver:
            return "Conserves battery. No Lottie, slow refresh, compact cards."
        }
    }
}