//
//  ChangesView.swift
//  SaxTrack
//
//  Created on 7/1/2026.
//

import SwiftUI

struct ChangesView: View {
    @Bindable var viewModel: FollowerTrackingViewModel
    @State private var filterType: ChangeFilterType = .all
    
    enum ChangeFilterType: String, CaseIterable {
        case all = "All"
        case unfollows = "Unfollows"
        case follows = "Follows"
    }
    
    var filteredChanges: [FollowerChange] {
        switch filterType {
        case .all:
            return viewModel.recentChanges
        case .unfollows:
            return viewModel.recentChanges.filter { $0.type == .unfollowed }
        case .follows:
            return viewModel.recentChanges.filter { $0.type == .followed }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.recentChanges.isEmpty {
                    emptyState
                } else {
                    changesList
                }
            }
            .navigationTitle("Activity")
            .toolbar {
                if !viewModel.recentChanges.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Mark All Read") {
                            viewModel.markAllChangesAsRead()
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Activity", systemImage: "clock.badge")
        } description: {
            Text("Changes to your followers will appear here")
        }
    }
    
    // MARK: - Changes List
    
    private var changesList: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Filter Picker
                Picker("Filter", selection: $filterType) {
                    ForEach(ChangeFilterType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Summary Card
                summaryCard
                
                // Timeline
                LazyVStack(spacing: 8) {
                    ForEach(groupedChanges.keys.sorted(by: >), id: \.self) { date in
                        Section {
                            ForEach(groupedChanges[date] ?? []) { change in
                                ChangeRow(change: change)
                                    .onTapGesture {
                                        viewModel.markChangeAsRead(change)
                                    }
                            }
                        } header: {
                            Text(date, style: .date)
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                VStack {
                    Text("\(viewModel.recentChanges.filter { $0.type == .unfollowed }.count)")
                        .font(.title2.bold())
                        .foregroundStyle(.red.gradient)
                    Text("Unfollows")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                VStack {
                    Text("\(viewModel.recentChanges.filter { $0.type == .followed }.count)")
                        .font(.title2.bold())
                        .foregroundStyle(.green.gradient)
                    Text("New Followers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .glassCard()
        .padding(.horizontal)
    }
    
    // MARK: - Grouped Changes
    
    private var groupedChanges: [Date: [FollowerChange]] {
        Dictionary(grouping: filteredChanges) { change in
            Calendar.current.startOfDay(for: change.date)
        }
    }
}

// MARK: - Change Row

struct ChangeRow: View {
    let change: FollowerChange
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: change.iconName)
                .font(.title3)
                .foregroundStyle(iconColor.gradient)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.15))
                .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(change.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(change.changeDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Time + Unread Badge
            VStack(alignment: .trailing, spacing: 4) {
                Text(change.date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                if !change.isRead {
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding()
        .glassCard()
        .padding(.horizontal)
    }
    
    private var iconColor: Color {
        switch change.type {
        case .followed, .youFollowed:
            return .green
        case .unfollowed, .youUnfollowed:
            return .red
        }
    }
}

#Preview {
    NavigationStack {
        ChangesView(viewModel: FollowerTrackingViewModel(modelContext: ModelContext(try! ModelContainer(for: InstagramUser.self, FollowerSnapshot.self, FollowerChange.self))))
    }
}
