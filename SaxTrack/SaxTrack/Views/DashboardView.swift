//
//  DashboardView.swift
//  SaxTrack
//
//  Created on 7/1/2026.
//

import SwiftUI

struct DashboardView: View {
    @Bindable var viewModel: FollowerTrackingViewModel
    @State private var showingImportSheet = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Stats Cards
                    statsSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Recent Activity Preview
                    if !viewModel.recentChanges.isEmpty {
                        recentActivitySection
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("SaxTrack")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingImportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingImportSheet) {
                FileImportView(viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Text("Track Your Instagram")
                .font(.title2.bold())
            
            Text("Stay updated on your followers")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Followers",
                value: "\(viewModel.stats.followers)",
                icon: "person.fill",
                color: .blue
            )
            
            StatCard(
                title: "Following",
                value: "\(viewModel.stats.following)",
                icon: "person.2.fill",
                color: .purple
            )
            
            StatCard(
                title: "Don't Follow Back",
                value: "\(viewModel.stats.nonFollowers)",
                icon: "person.fill.xmark",
                color: .orange
            )
            
            StatCard(
                title: "Mutual",
                value: "\(viewModel.stats.mutual)",
                icon: "person.2.circle.fill",
                color: .green
            )
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                QuickActionButton(
                    title: "Import Data",
                    subtitle: "Update your follower list",
                    icon: "square.and.arrow.down.fill",
                    color: .blue
                ) {
                    showingImportSheet = true
                }
                
                NavigationLink {
                    NonFollowersView(viewModel: viewModel)
                } label: {
                    QuickActionButton(
                        title: "View Non-Followers",
                        subtitle: "\(viewModel.stats.nonFollowers) users",
                        icon: "person.fill.xmark",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)
                
                NavigationLink {
                    ChangesView(viewModel: viewModel)
                } label: {
                    QuickActionButton(
                        title: "Recent Changes",
                        subtitle: "\(viewModel.recentChanges.prefix(10).count) recent activities",
                        icon: "clock.fill",
                        color: .green
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Recent Activity
    
    private var recentActivitySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink("See All") {
                    ChangesView(viewModel: viewModel)
                }
                .font(.subheadline)
            }
            
            VStack(spacing: 8) {
                ForEach(viewModel.recentChanges.prefix(5)) { change in
                    ChangeRow(change: change)
                }
            }
            .glassCard()
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color.gradient)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassCard()
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var action: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color.gradient)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .glassCard()
        }
    }
}

// MARK: - Glass Card Modifier

extension View {
    func glassCard() -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}

#Preview {
    NavigationStack {
        DashboardView(viewModel: FollowerTrackingViewModel(modelContext: ModelContext(try! ModelContainer(for: InstagramUser.self, FollowerSnapshot.self, FollowerChange.self))))
    }
}
