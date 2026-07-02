//
//  SettingsView.swift
//  SaxTrack
//
//  Created on 7/1/2026.
//

import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: FollowerTrackingViewModel
    @State private var showingClearDataAlert = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            List {
                // Stats Section
                Section {
                    statsRow(title: "Total Users", value: "\(viewModel.users.count)", icon: "person.3.fill", color: .blue)
                    statsRow(title: "Followers", value: "\(viewModel.followers.count)", icon: "person.fill", color: .green)
                    statsRow(title: "Following", value: "\(viewModel.following.count)", icon: "person.2.fill", color: .purple)
                    statsRow(title: "Changes Tracked", value: "\(viewModel.recentChanges.count)", icon: "clock.fill", color: .orange)
                } header: {
                    Text("Statistics")
                }
                
                // Data Management
                Section {
                    Button(role: .destructive) {
                        showingClearDataAlert = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash.fill")
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("This will permanently delete all imported data and change history.")
                }
                
                // About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("2026.01.07")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
                
                // Privacy Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Privacy First", systemImage: "lock.shield.fill")
                            .font(.headline)
                            .foregroundStyle(.blue)
                        
                        Text("SaxTrack stores all your data locally on your device. We never access Instagram directly, collect analytics, or sync your data to the cloud.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Privacy")
                }
                
                // Tips Section
                Section {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 16) {
                            TipRow(
                                icon: "square.and.arrow.down.fill",
                                title: "Export Your Data",
                                description: "Go to Instagram Settings → Privacy → Download Your Information"
                            )
                            
                            Divider()
                            
                            TipRow(
                                icon: "arrow.clockwise",
                                title: "Regular Updates",
                                description: "Import your data weekly to track changes accurately"
                            )
                            
                            Divider()
                            
                            TipRow(
                                icon: "bell.badge.fill",
                                title: "Check Activity",
                                description: "Visit the Activity tab to see who unfollowed you"
                            )
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Label("Usage Tips", systemImage: "lightbulb.fill")
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Help")
                }
            }
            .navigationTitle("Settings")
            .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.clearAllData()
                }
            } message: {
                Text("This will permanently delete all imported data, users, and change history. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Stats Row
    
    private func statsRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color.gradient)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15))
                .clipShape(Circle())
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Tip Row

struct TipRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView(viewModel: FollowerTrackingViewModel(modelContext: ModelContext(try! ModelContainer(for: InstagramUser.self, FollowerSnapshot.self, FollowerChange.self))))
}
