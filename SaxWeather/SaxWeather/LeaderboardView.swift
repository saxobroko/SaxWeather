//
//  LeaderboardView.swift
//  SaxWeather
//
//  Created by saxobroko on 2026-01-28
//

import SwiftUI

struct LeaderboardView: View {
    @StateObject private var leaderboard = CloudKitLeaderboardManager.shared
    @State private var showingOptIn = false
    @State private var showingSettings = false
    
    var body: some View {
        Group {
            if !leaderboard.hasOptedIn {
                notOptedInView
            } else {
                leaderboardContent
            }
        }
        .onAppear {
            Task {
                await leaderboard.fetchLeaderboard()
            }
        }
        .sheet(isPresented: $showingOptIn) {
            LeaderboardOptInView()
        }
        .sheet(isPresented: $showingSettings) {
            LeaderboardSettingsView()
        }
    }
    
    // MARK: - Not Opted In View
    private var notOptedInView: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy")
                .font(.system(size: 80))
                .foregroundStyle(.yellow.gradient)
            
            Text("Join the Leaderboard")
                .font(.title.bold())
            
            Text("See how you rank among SaxWeather supporters! Completely optional and privacy-focused.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showingOptIn = true
            } label: {
                Text("Join Now")
                    .fontWeight(.semibold)
                    .frame(maxWidth: 200)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            
            // Show top supporters even if not opted in (public info)
            if !leaderboard.supporters.isEmpty {
                Divider()
                    .padding(.vertical)
                
                Text("Top Supporters")
                    .font(.headline)
                
                topSupportersList
            }
        }
        .padding()
    }
    
    // MARK: - Leaderboard Content
    private var leaderboardContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with settings
                HStack {
                    Text("Leaderboard")
                        .font(.title.bold())
                    Spacer()
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Your Rank Card
                if let currentUser = leaderboard.currentUserSupporter,
                   let rank = leaderboard.getUserRank() {
                    yourRankCard(user: currentUser, rank: rank)
                }
                
                // Top 3 Podium
                if leaderboard.supporters.count >= 3 {
                    podiumView
                        .padding(.vertical)
                }
                
                // All Supporters List
                VStack(spacing: 0) {
                    ForEach(Array(leaderboard.supporters.enumerated()), id: \.element.id) { index, supporter in
                        supporterRow(supporter: supporter, rank: index + 1)
                        
                        if index < leaderboard.supporters.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .refreshable {
            await leaderboard.fetchLeaderboard()
        }
    }
    
    // MARK: - Your Rank Card
    private func yourRankCard(user: Supporter, rank: Int) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Rank")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("#\(rank)")
                            .font(.title.bold())
                        Text(user.displayRank)
                            .font(.title)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(user.tierName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(user.contributionCount) contribution\(user.contributionCount == 1 ? "" : "s")")
                        .font(.headline)
                }
            }
            
            // Next tier progress
            if user.contributionCount < 10 {
                nextTierProgress(currentCount: user.contributionCount)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.5), lineWidth: 2)
        )
        .padding(.horizontal)
    }
    
    private func nextTierProgress(currentCount: Int) -> some View {
        let nextMilestone: Int
        let nextTier: String
        
        switch currentCount {
        case 0...2:
            nextMilestone = 3
            nextTier = "Cake Patron 🍰"
        case 3...4:
            nextMilestone = 5
            nextTier = "Pizza Champion 🍕"
        case 5...9:
            nextMilestone = 10
            nextTier = "Party Legend 🎉"
        default:
            nextMilestone = currentCount
            nextTier = "Max Tier"
        }
        
        let remaining = nextMilestone - currentCount
        let progress = Double(currentCount) / Double(nextMilestone)
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Next tier: \(nextTier)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(remaining) more")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - Podium View (Top 3)
    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // 2nd Place
            if leaderboard.supporters.count >= 2 {
                podiumPlace(supporter: leaderboard.supporters[1], rank: 2, height: 80)
            }
            
            // 1st Place (tallest)
            if leaderboard.supporters.count >= 1 {
                podiumPlace(supporter: leaderboard.supporters[0], rank: 1, height: 100)
            }
            
            // 3rd Place
            if leaderboard.supporters.count >= 3 {
                podiumPlace(supporter: leaderboard.supporters[2], rank: 3, height: 60)
            }
        }
        .padding(.horizontal)
    }
    
    private func podiumPlace(supporter: Supporter, rank: Int, height: CGFloat) -> some View {
        VStack(spacing: 8) {
            // Medal
            Text(rank == 1 ? "🥇" : rank == 2 ? "🥈" : "🥉")
                .font(.system(size: 40))
            
            // Name
            Text(supporter.isAnonymous ? "Anonymous" : supporter.displayName)
                .font(.caption.bold())
                .lineLimit(1)
            
            // Tier emoji
            Text(supporter.displayRank)
                .font(.title2)
            
            // Count
            Text("\(supporter.contributionCount)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Podium
            RoundedRectangle(cornerRadius: 8)
                .fill(rank == 1 ? Color.yellow.gradient : rank == 2 ? Color.gray.gradient : Color.orange.gradient)
                .frame(height: height)
                .overlay(
                    Text("#\(rank)")
                        .font(.title.bold())
                        .foregroundColor(.white)
                )
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Supporter Row
    private func supporterRow(supporter: Supporter, rank: Int) -> some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(rank)")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            
            // Tier emoji
            Text(supporter.displayRank)
                .font(.title3)
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(supporter.isAnonymous ? "Anonymous" : supporter.displayName)
                    .font(.body.bold())
                Text(supporter.tierName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Contribution count
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(supporter.contributionCount)")
                    .font(.title3.bold())
                    .foregroundColor(.blue)
                Text("tip\(supporter.contributionCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            rank <= 3 ? Color.yellow.opacity(0.1) : Color.clear
        )
    }
    
    // MARK: - Top Supporters List (for non-opted in view)
    private var topSupportersList: some View {
        VStack(spacing: 0) {
            ForEach(Array(leaderboard.supporters.prefix(10).enumerated()), id: \.element.id) { index, supporter in
                HStack(spacing: 12) {
                    Text("#\(index + 1)")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                    
                    Text(supporter.displayRank)
                    
                    Text(supporter.isAnonymous ? "Anonymous" : supporter.displayName)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(supporter.contributionCount)")
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                
                if index < min(9, leaderboard.supporters.count - 1) {
                    Divider()
                }
            }
        }
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview {
    LeaderboardView()
}
