//
//  ProfileSwitcherView.swift
//  SaxWeather
//
//  Phase 7 — Settings UI rebuild.
//
//  A sheet that lists every built-in profile and lets the user
//  switch to it with one tap. Tapping a row calls
//  `CustomisationRegistry.resetTo(_:)`, which writes through to
//  UserDefaults, persists the profile to the App Group, and reloads
//  widget timelines — so the whole app updates instantly.
//
//  The active profile shows a checkmark. Switching to a different
//  profile dismisses the sheet and the new theme lands on the next
//  render pass.
//
//  See `plans/INFINITE_CUSTOMISATION_PLAN.md` §4.7.
//

import SwiftUI

struct ProfileSwitcherView: View {
    @EnvironmentObject private var customisation: CustomisationRegistry
    @Environment(\.dismiss) private var dismiss

    /// Optional callback fired after a successful switch. Lets the
    /// parent view show a confirmation toast without having to
    /// observe the registry directly.
    var onSelect: ((BuiltInProfile) -> Void)? = nil

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
}

// MARK: - Row

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