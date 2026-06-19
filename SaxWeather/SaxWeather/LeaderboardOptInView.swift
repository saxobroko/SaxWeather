//
//  LeaderboardOptInView.swift
//  SaxWeather
//
//  Created by saxobroko on 2026-01-28
//

import SwiftUI

struct LeaderboardOptInView: View {
    @StateObject private var leaderboard = CloudKitLeaderboardManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName = ""
    @State private var isAnonymous = false
    @State private var showingPrivacyInfo = false
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    nameInputSection
                    privacySection
                    buttonsSection
                }
                .padding()
            }
            .navigationTitle("Join Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
            }
            .alert("Privacy Notice", isPresented: $showingPrivacyInfo) {
                Button("Got It") { }
            } message: {
                Text("""
                Your privacy is important:
                
                • Only your display name is shown
                • No email or personal info collected
                • You can opt-out anytime
                • All data deleted when you opt-out
                • We never share your data
                """)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow.gradient)
            
            Text("Join the Leaderboard!")
                .font(.title.bold())
            
            Text("Show your support and see how you rank among other SaxWeather supporters!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Display Name")
                .font(.headline)
            
            TextField("Enter your name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.words)
                .disableAutocorrection(true)
            
            Text("Max 20 characters. Letters, numbers, spaces, and underscores only.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Toggle(isOn: $isAnonymous) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Show as Anonymous")
                        .font(.subheadline)
                    Text("Your name won't be displayed, but you'll still be ranked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var privacySection: some View {
        VStack(spacing: 12) {
            Button {
                showingPrivacyInfo = true
            } label: {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.blue)
                    Text("Privacy Protection")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                PrivacyCheckRow(icon: "checkmark.circle.fill", text: "No personal data collected")
                PrivacyCheckRow(icon: "checkmark.circle.fill", text: "Opt-out anytime")
                PrivacyCheckRow(icon: "checkmark.circle.fill", text: "Only contribution count shown")
            }
            .font(.caption)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var buttonsSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await joinLeaderboard()
                }
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Join Leaderboard")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(displayName.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(displayName.isEmpty || isProcessing)
            
            Button("Maybe Later") {
                dismiss()
            }
            .foregroundColor(.secondary)
        }
    }
    
    private func joinLeaderboard() async {
        isProcessing = true
        
        let success = await leaderboard.optIn(
            displayName: isAnonymous ? "Anonymous" : displayName,
            isAnonymous: isAnonymous
        )
        
        isProcessing = false
        
        if success {
            dismiss()
        }
    }
}

struct PrivacyCheckRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 16)
            Text(text)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    LeaderboardOptInView()
}
