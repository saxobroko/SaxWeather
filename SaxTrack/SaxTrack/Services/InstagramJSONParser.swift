// InstagramJSONParser.swift
// Parses Instagram's official data export JSON files

import Foundation

struct InstagramJSONParser {
    
    // MARK: - Instagram Export Structures
    
    struct InstagramFollowersExport: Codable {
        let followers_1: [FollowerEntry]?
        
        struct FollowerEntry: Codable {
            let string_list_data: [StringData]
            
            struct StringData: Codable {
                let href: String?
                let value: String
                let timestamp: Int?
            }
        }
    }
    
    struct InstagramFollowingExport: Codable {
        let relationships_following: [FollowingEntry]?
        
        struct FollowingEntry: Codable {
            let string_list_data: [StringData]
            
            struct StringData: Codable {
                let href: String?
                let value: String
                let timestamp: Int?
            }
        }
    }
    
    // MARK: - Parse Methods
    
    /// Parse followers from Instagram's JSON export
    static func parseFollowers(from data: Data) throws -> [String] {
        let decoder = JSONDecoder()
        
        // Try new format first (2024+)
        if let export = try? decoder.decode(InstagramFollowersExport.self, from: data),
           let followers = export.followers_1 {
            return followers.compactMap { $0.string_list_data.first?.value }
        }
        
        // Try legacy format
        if let legacyExport = try? decoder.decode([LegacyFollower].self, from: data) {
            return legacyExport.map { $0.username ?? $0.value ?? "" }.filter { !$0.isEmpty }
        }
        
        throw ParseError.invalidFormat
    }
    
    /// Parse following from Instagram's JSON export
    static func parseFollowing(from data: Data) throws -> [String] {
        let decoder = JSONDecoder()
        
        // Try new format first (2024+)
        if let export = try? decoder.decode(InstagramFollowingExport.self, from: data),
           let following = export.relationships_following {
            return following.compactMap { $0.string_list_data.first?.value }
        }
        
        // Try legacy format
        if let legacyExport = try? decoder.decode([LegacyFollowing].self, from: data) {
            return legacyExport.map { $0.username ?? $0.value ?? "" }.filter { !$0.isEmpty }
        }
        
        throw ParseError.invalidFormat
    }
    
    /// Auto-detect format and parse
    static func autoParseUsernames(from data: Data) throws -> (usernames: [String], type: ImportType) {
        // Try followers first
        if let followers = try? parseFollowers(from: data), !followers.isEmpty {
            return (followers, .followers)
        }
        
        // Try following
        if let following = try? parseFollowing(from: data), !following.isEmpty {
            return (following, .following)
        }
        
        throw ParseError.invalidFormat
    }
    
    // MARK: - Legacy Formats (2023 and earlier)
    
    struct LegacyFollower: Codable {
        let username: String?
        let value: String?
    }
    
    struct LegacyFollowing: Codable {
        let username: String?
        let value: String?
    }
    
    // MARK: - Supporting Types
    
    enum ImportType {
        case followers
        case following
    }
    
    enum ParseError: LocalizedError {
        case invalidFormat
        case emptyData
        case unsupportedVersion
        
        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "File format not recognized. Please use Instagram's official data export."
            case .emptyData:
                return "File is empty or corrupted."
            case .unsupportedVersion:
                return "This Instagram export version is not supported yet."
            }
        }
    }
}
