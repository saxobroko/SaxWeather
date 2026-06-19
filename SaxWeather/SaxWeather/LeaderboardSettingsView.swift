//
//  LeaderboardSettingsView.swift
//  SaxWeather
//
//  Created by saxobroko on 2026-01-28
//

import SwiftUI

struct LeaderboardSettingsView: View {
    @StateObject private var leaderboard = CloudKitLeaderboardManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName = UserDefaults.standard.string(forKey: "leaderboardDisplayName") ?? ""
    @State private var isAnonymous = UserDefaults.standard.bool(forKey: "leaderboardIsAnonymous")
    @State private var showingOptOutConfirmation = false
    @State private var showingDataDeletionInfo = false
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display Name", text: $displayName)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                    
                    Toggle("Show as Anonymous", isOn: $isAnonymous)
                    
                    Button("Update") {
                        Task {
                            isProcessing = true
                            _ = await leaderboard.updateDisplayName(displayName, isAnonymous: isAnonymous)
                            isProcessing = false
                        }
                    }
                    .disabled(displayName.isEmpty || isProcessing)
                } header: {
                    Text("Display Settings")
                } footer: {
                    Text("Your display name can be up to 20 characters. Use letters, numbers, spaces, and underscores only.")
                }
                
                Section {
                    if let currentUser = leaderboard.currentUserSupporter {
                        LabeledContent("Contributions", value: "\(currentUser.contributionCount)")
                        LabeledContent("Tier", value: currentUser.tierName)
                        if let rank = leaderboard.getUserRank() {
                            LabeledContent("Rank", value: "#\(rank)")
                        }
                    }
                } header: {
                    Text("Your Stats")
                }
                
                Section {
                    Button {
                        showingDataDeletionInfo = true
                    } label: {
                        HStack {
                            Label("Privacy & Data", systemImage: "lock.shield")
                            Spacer()
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("We take your privacy seriously. Your data is stored securely and never shared with third parties.")
                }
                
                Section {
                    Button(role: .destructive) {
                        showingOptOutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            if isProcessing {
                                ProgressView()
                            } else {
                                Text("Leave Leaderboard")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isProcessing)
                } footer: {
                    Text("This will permanently remove your entry from the leaderboard. You can rejoin anytime by leaving another tip.")
                }
            }
            .navigationTitle("Leaderboard Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Leave Leaderboard?", isPresented: $showingOptOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    Task {
                        isProcessing = true
                        let success = await leaderboard.optOut()
                        isProcessing = false
                        if success {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("This will permanently delete your leaderboard entry and all associated data. You can rejoin anytime.")
            }
            .alert("Privacy & Data", isPresented: $showingDataDeletionInfo) {
                Button("OK") { }
            } message: {
                Text("""
                What we collect:
                • Display name (chosen by you)
                • Number of contributions
                • Dates of contributions
                
                What we DON'T collect:
                • Email addresses
                • Phone numbers
                • Dollar amounts
                • Any personal information
                
                Your data is:
                • Stored securely in iCloud
                • Never sold or shared
                • Deleted immediately when you opt-out
                • Fully under your control
                
                You can delete your data anytime by leaving the leaderboard.
                """)
            }
        }
    }
}

#Preview {
    LeaderboardSettingsView()
}
