//
//  LeaderboardDebugView.swift
//  SaxWeather
//
//  Created by saxobroko on 2026-01-28
//

import SwiftUI

struct LeaderboardDebugView: View {
    @StateObject private var leaderboard = CloudKitLeaderboardManager.shared
    @State private var testName = "TestUser"
    
    var body: some View {
        NavigationStack {
            List {
                Section("Current State") {
                    HStack {
                        Text("Opted In:")
                        Spacer()
                        Text(leaderboard.hasOptedIn ? "✅ Yes" : "❌ No")
                            .foregroundColor(leaderboard.hasOptedIn ? .green : .red)
                    }
                    
                    if leaderboard.hasOptedIn {
                        HStack {
                            Text("Your Name:")
                            Spacer()
                            Text(leaderboard.currentUserSupporter?.displayName ?? "Unknown")
                        }
                        
                        HStack {
                            Text("Your Contributions:")
                            Spacer()
                            Text("\(leaderboard.currentUserSupporter?.contributionCount ?? 0)")
                        }
                    }
                    
                    HStack {
                        Text("Total Supporters:")
                        Spacer()
                        Text("\(leaderboard.supporters.count)")
                    }
                }
                
                Section("Test Actions") {
                    if !leaderboard.hasOptedIn {
                        TextField("Test Display Name", text: $testName)
                        
                        Button("Test Opt-In") {
                            Task {
                                await leaderboard.optIn(displayName: testName, isAnonymous: false)
                            }
                        }
                        .disabled(testName.isEmpty)
                        
                        Button("Test Opt-In (Anonymous)") {
                            Task {
                                await leaderboard.optIn(displayName: "", isAnonymous: true)
                            }
                        }
                    } else {
                        Button("Test Increment Contribution") {
                            Task {
                                await leaderboard.incrementContribution()
                            }
                        }
                        
                        Button("Test Opt-Out", role: .destructive) {
                            Task {
                                await leaderboard.optOut()
                            }
                        }
                    }
                    
                    Button("Refresh Leaderboard") {
                        Task {
                            await leaderboard.fetchLeaderboard()
                        }
                    }
                }
                
                if leaderboard.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                
                if let error = leaderboard.error {
                    Section("Error") {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                if !leaderboard.supporters.isEmpty {
                    Section("Leaderboard Data") {
                        ForEach(leaderboard.supporters) { supporter in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(supporter.displayName)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(supporter.contributionCount)")
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(supporter.tierName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Leaderboard Debug")
            .refreshable {
                await leaderboard.fetchLeaderboard()
            }
        }
    }
}

#Preview {
    LeaderboardDebugView()
}
