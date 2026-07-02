//
//  ContentView.swift
//  SaxTrack
//
//  Created on 7/1/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: FollowerTrackingViewModel?
    @State private var selectedTab = 0
    @Binding var shortcutImportData: ShortcutIntegrationService.ShortcutImportData?
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                TabView(selection: $selectedTab) {
                    DashboardView(viewModel: viewModel)
                        .tabItem {
                            Label("Dashboard", systemImage: "chart.bar.fill")
                        }
                        .tag(0)
                    
                    NonFollowersView(viewModel: viewModel)
                        .tabItem {
                            Label("Non-Followers", systemImage: "person.fill.xmark")
                        }
                        .tag(1)
                    
                    ChangesView(viewModel: viewModel)
                        .tabItem {
                            Label("Activity", systemImage: "clock.fill")
                        }
                        .badge(viewModel.unreadChangesCount > 0 ? viewModel.unreadChangesCount : nil)
                        .tag(2)
                    
                    SettingsView(viewModel: viewModel)
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        .tag(3)
                }
                .onChange(of: shortcutImportData) { oldValue, newValue in
                    handleShortcutImport(newValue, viewModel: viewModel)
                }
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        viewModel = FollowerTrackingViewModel(modelContext: modelContext)
                    }
            }
        }
    }
    
    private func handleShortcutImport(_ importData: ShortcutIntegrationService.ShortcutImportData?, viewModel: FollowerTrackingViewModel) {
        guard let importData = importData else { return }
        
        Task {
            switch importData.type {
            case .followers:
                await viewModel.importFollowers(importData.usernames)
            case .following:
                await viewModel.importFollowing(importData.usernames)
            }
            
            // Clear after import
            await MainActor.run {
                shortcutImportData = nil
                selectedTab = 0 // Navigate to dashboard
            }
        }
    }
}

#Preview {
    ContentView(shortcutImportData: .constant(nil))
        .modelContainer(for: [InstagramUser.self, FollowerSnapshot.self, FollowerChange.self], inMemory: true)
}
