//
//  InstagramUser.swift
//  SaxTrack
//
//  Created on 7/1/2026.
//

import Foundation
import SwiftData

@Model
final class InstagramUser {
    @Attribute(.unique) var username: String
    var displayName: String
    var profilePictureURL: String?
    var dateAdded: Date
    var isFollower: Bool
    var isFollowing: Bool
    var lastSeen: Date
    
    init(username: String, displayName: String, profilePictureURL: String? = nil, isFollower: Bool = false, isFollowing: Bool = false) {
        self.username = username
        self.displayName = displayName
        self.profilePictureURL = profilePictureURL
        self.dateAdded = Date()
        self.isFollower = isFollower
        self.isFollowing = isFollowing
        self.lastSeen = Date()
    }
    
    /// Returns true if this user doesn't follow back
    var doesntFollowBack: Bool {
        return isFollowing && !isFollower
    }
    
    /// Returns true if this is a mutual follow
    var isMutual: Bool {
        return isFollower && isFollowing
    }
}
