//
//  NonFollowersView.swift
//  SaxTrack
//
//  Created on 7/1/2026.
//

import SwiftUI

struct NonFollowersView: View {
    @Bindable var viewModel: FollowerTrackingViewModel
    @State private var searchText = ""
    
    var filteredUsers: [InstagramUser] {
        if searchText.isEmpty {
            return viewModel.nonFollowers
        } else {
            return viewModel.nonFollowers.filter {
                $0.username.localizedCaseInsensitiveContains(searchText) ||
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.nonFollowers.isEmpty {
                    emptyState
                } else {
                    userList
                }
            }
            .navigationTitle("Don't Follow Back")
            .searchable(text: $searchText, prompt: "Search users")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Data Yet", systemImage: "person.fill.questionmark")
        } description: {
            Text("Import your Instagram data to see who doesn't follow you back")
        }
    }
    
    // MARK: - User List
    
    private var userList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Summary Card
                summaryCard
                
                // User List
                ForEach(filteredUsers) { user in
                    UserCard(user: user) {
                        // Open Instagram profile
                        if let url = URL(string: "instagram://user?username=\(user.username)") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.nonFollowers.count)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.orange.gradient)
                    
                    Text("users don't follow back")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "person.fill.xmark")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange.gradient)
            }
            
            if !viewModel.nonFollowers.isEmpty {
                Divider()
                
                Text("These are people you follow who don't follow you back. Consider unfollowing them to maintain a balanced ratio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .glassCard()
    }
}

// MARK: - User Card

struct UserCard: View {
    let user: InstagramUser
    var action: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                // Profile Picture Placeholder
                Circle()
                    .fill(.linearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(user.username.prefix(1).uppercased())
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Status Badge
                if user.doesntFollowBack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.orange)
                } else if user.isMutual {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding()
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        NonFollowersView(viewModel: FollowerTrackingViewModel(modelContext: ModelContext(try! ModelContainer(for: InstagramUser.self, FollowerSnapshot.self, FollowerChange.self))))
    }
}
