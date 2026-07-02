//
//  FollowerSnapshot.swift
//  SaxTrack
//
//  Created on 7/1/2026.
//

import Foundation
import SwiftData

@Model
final class FollowerSnapshot {
    var date: Date
    var followerCount: Int
    var followingCount: Int
    var mutualCount: Int
    var nonFollowersCount: Int
    var followerUsernames: [String]
    var followingUsernames: [String]
    
    init(date: Date = Date(), followerCount: Int, followingCount: Int, mutualCount: Int, nonFollowersCount: Int, followerUsernames: [String], followingUsernames: [String]) {
        self.date = date
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.mutualCount = mutualCount
        self.nonFollowersCount = nonFollowersCount
        self.followerUsernames = followerUsernames
        self.followingUsernames = followingUsernames
    }
}
