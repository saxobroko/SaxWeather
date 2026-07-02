//
//  FollowerTrackingViewModel.swift
//  SaxTrack
//
//  Created on 7/1/2026.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
final class FollowerTrackingViewModel {
    var modelContext: ModelContext
    
    var users: [InstagramUser] = []
    var recentChanges: [FollowerChange] = []
    var snapshots: [FollowerSnapshot] = []
    
    var isLoading = false
    var error: String?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadData()
    }
    
    // MARK: - Data Loading
    
    func loadData() {
        loadUsers()
        loadRecentChanges()
        loadSnapshots()
    }
    
    private func loadUsers() {
        let descriptor = FetchDescriptor<InstagramUser>(
            sortBy: [SortDescriptor(\.username)]
        )
        users = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func loadRecentChanges() {
        let descriptor = FetchDescriptor<FollowerChange>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        recentChanges = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func loadSnapshots() {
        let descriptor = FetchDescriptor<FollowerSnapshot>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        snapshots = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Computed Properties
    
    var followers: [InstagramUser] {
        users.filter { $0.isFollower }
    }
    
    var following: [InstagramUser] {
        users.filter { $0.isFollowing }
    }
    
    var nonFollowers: [InstagramUser] {
        users.filter { $0.doesntFollowBack }
    }
    
    var mutualFollowers: [InstagramUser] {
        users.filter { $0.isMutual }
    }
    
    var unreadChangesCount: Int {
        recentChanges.filter { !$0.isRead }.count
    }
    
    var stats: Stats {
        Stats(
            followers: followers.count,
            following: following.count,
            nonFollowers: nonFollowers.count,
            mutual: mutualFollowers.count
        )
    }
    
    // MARK: - Import Data
    
    func importFollowers(_ usernames: [String]) async {
        isLoading = true
        error = nil
        
        // Update existing users or create new ones
        for username in usernames {
            if let existingUser = users.first(where: { $0.username == username }) {
                existingUser.isFollower = true
                existingUser.lastSeen = Date()
            } else {
                let newUser = InstagramUser(username: username, displayName: username, isFollower: true)
                modelContext.insert(newUser)
                users.append(newUser)
            }
        }
        
        // Detect unfollowers
        let currentFollowerUsernames = Set(usernames)
        for user in users where user.isFollower {
            if !currentFollowerUsernames.contains(user.username) {
                user.isFollower = false
                recordChange(username: user.username, displayName: user.displayName, type: .unfollowed)
            }
        }
        
        try? modelContext.save()
        createSnapshot()
        loadData()
        
        isLoading = false
    }
    
    func importFollowing(_ usernames: [String]) async {
        isLoading = true
        error = nil
        
        // Update existing users or create new ones
        for username in usernames {
            if let existingUser = users.first(where: { $0.username == username }) {
                existingUser.isFollowing = true
                existingUser.lastSeen = Date()
            } else {
                let newUser = InstagramUser(username: username, displayName: username, isFollowing: true)
                modelContext.insert(newUser)
                users.append(newUser)
            }
        }
        
        // Detect people you unfollowed
        let currentFollowingUsernames = Set(usernames)
        for user in users where user.isFollowing {
            if !currentFollowingUsernames.contains(user.username) {
                user.isFollowing = false
                recordChange(username: user.username, displayName: user.displayName, type: .youUnfollowed)
            }
        }
        
        try? modelContext.save()
        createSnapshot()
        loadData()
        
        isLoading = false
    }
    
    // MARK: - Change Tracking
    
    private func recordChange(username: String, displayName: String, type: ChangeType) {
        let change = FollowerChange(username: username, displayName: displayName, changeType: type)
        modelContext.insert(change)
    }
    
    private func createSnapshot() {
        let snapshot = FollowerSnapshot(
            followerCount: followers.count,
            followingCount: following.count,
            mutualCount: mutualFollowers.count,
            nonFollowersCount: nonFollowers.count,
            followerUsernames: followers.map { $0.username },
            followingUsernames: following.map { $0.username }
        )
        modelContext.insert(snapshot)
    }
    
    // MARK: - Actions
    
    func markChangeAsRead(_ change: FollowerChange) {
        change.isRead = true
        try? modelContext.save()
        loadRecentChanges()
    }
    
    func markAllChangesAsRead() {
        for change in recentChanges where !change.isRead {
            change.isRead = true
        }
        try? modelContext.save()
        loadRecentChanges()
    }
    
    func deleteUser(_ user: InstagramUser) {
        modelContext.delete(user)
        try? modelContext.save()
        loadUsers()
    }
    
    func clearAllData() {
        // Delete all users
        for user in users {
            modelContext.delete(user)
        }
        // Delete all changes
        for change in recentChanges {
            modelContext.delete(change)
        }
        // Delete all snapshots
        for snapshot in snapshots {
            modelContext.delete(snapshot)
        }
        try? modelContext.save()
        loadData()
    }
}

// MARK: - Stats Model

struct Stats {
    let followers: Int
    let following: Int
    let nonFollowers: Int
    let mutual: Int
}
