//
//  FollowerChange.swift
//  SaxTrack
//
//  Created on 7/1/2026.
//

import Foundation
import SwiftData

enum ChangeType: String, Codable {
    case followed = "followed"
    case unfollowed = "unfollowed"
    case youFollowed = "you_followed"
    case youUnfollowed = "you_unfollowed"
}

@Model
final class FollowerChange {
    var username: String
    var displayName: String
    var changeType: String // Stores ChangeType rawValue
    var date: Date
    var isRead: Bool
    
    init(username: String, displayName: String, changeType: ChangeType, date: Date = Date()) {
        self.username = username
        self.displayName = displayName
        self.changeType = changeType.rawValue
        self.date = date
        self.isRead = false
    }
    
    var type: ChangeType {
        ChangeType(rawValue: changeType) ?? .unfollowed
    }
    
    var changeDescription: String {
        switch type {
        case .followed:
            return "\(displayName) started following you"
        case .unfollowed:
            return "\(displayName) unfollowed you"
        case .youFollowed:
            return "You followed \(displayName)"
        case .youUnfollowed:
            return "You unfollowed \(displayName)"
        }
    }
    
    var iconName: String {
        switch type {
        case .followed, .youFollowed:
            return "person.badge.plus.fill"
        case .unfollowed, .youUnfollowed:
            return "person.badge.minus.fill"
        }
    }
    
    var iconColor: String {
        switch type {
        case .followed, .youFollowed:
            return "green"
        case .unfollowed, .youUnfollowed:
            return "red"
        }
    }
}
