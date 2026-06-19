//
//  CloudKitLeaderboardManager.swift
//  SaxWeather
//
//  Created by saxobroko on 2026-01-28
//

import Foundation
import CloudKit
import CryptoKit

// MARK: - Supporter Model
struct Supporter: Identifiable {
    let id: String
    let displayName: String
    let contributionCount: Int
    let isAnonymous: Bool
    let lastContributionDate: Date
    
    var displayRank: String {
        switch contributionCount {
        case 1...2: return "☕️"
        case 3...4: return "🍰"
        case 5...9: return "🍕"
        default: return "🎉"
        }
    }
    
    var tierName: String {
        switch contributionCount {
        case 1...2: return "Coffee Supporter"
        case 3...4: return "Cake Patron"
        case 5...9: return "Pizza Champion"
        default: return "Party Legend"
        }
    }
}

// MARK: - CloudKit Manager
@MainActor
class CloudKitLeaderboardManager: ObservableObject {
    static let shared = CloudKitLeaderboardManager()
    
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let recordType = "TipSupporter"
    
    // Field names must match CloudKit schema exactly
    private let fieldDisplayName = "displayName"
    private let fieldContributionCount = "contributionCount"
    private let fieldIsAnonymous = "isAnonymous"
    private let fieldFirstContributionDate = "firstContributionDate"
    private let fieldLastContributionDate = "lastContributionDate"
    private let fieldHashedUserID = "hashedUserID"
    
    @Published var supporters: [Supporter] = []
    @Published var currentUserSupporter: Supporter?
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasOptedIn = false
    
    private init() {
        // Use default CloudKit container (configure in Xcode capabilities)
        container = CKContainer.default()
        publicDatabase = container.publicCloudDatabase
        
        #if DEBUG
        print("🔵 CloudKit Leaderboard Manager Initialized")
        print("   Container ID: \(container.containerIdentifier ?? "Unknown")")
        #if targetEnvironment(simulator)
        print("   Environment: Simulator (uses Development)")
        #else
        print("   Environment: Device (check Xcode scheme settings)")
        #endif
        #endif
        
        // Check if user has opted in locally
        hasOptedIn = UserDefaults.standard.bool(forKey: "leaderboardOptedIn")
        
        #if DEBUG
        print("   User opted in: \(hasOptedIn)")
        #endif
        
        Task {
            if hasOptedIn {
                await fetchCurrentUserSupporter()
            }
        }
    }
    
    // MARK: - Privacy: Hashed User ID
    private func hashedUserID() async -> String? {
        do {
            let recordID = try await container.userRecordID()
            let userID = recordID.recordName
            
            // Hash the user ID for privacy (one-way, can't reverse)
            let inputData = Data(userID.utf8)
            let hashed = SHA256.hash(data: inputData)
            return hashed.compactMap { String(format: "%02x", $0) }.joined()
        } catch {
            #if DEBUG
            print("❌ Error getting user ID: \(error)")
            #endif
            return nil
        }
    }
    
    // MARK: - Opt In
    func optIn(displayName: String, isAnonymous: Bool) async -> Bool {
        #if DEBUG
        print("🔵 Starting opt-in process...")
        print("   Display Name: \(displayName)")
        print("   Anonymous: \(isAnonymous)")
        #endif
        
        guard let hashedID = await hashedUserID() else {
            #if DEBUG
            print("❌ Failed to get hashed user ID")
            #endif
            await MainActor.run {
                error = "Unable to verify user identity"
            }
            return false
        }
        
        #if DEBUG
        print("   Hashed ID: \(hashedID)")
        #endif
        
        // Validate display name
        guard validateDisplayName(displayName) else {
            #if DEBUG
            print("❌ Display name validation failed")
            #endif
            await MainActor.run {
                error = "Invalid display name. Use only letters, numbers, and spaces (max 20 characters)"
            }
            return false
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Check if user already exists
            if let existing = await fetchSupporterByHashedID(hashedID) {
                #if DEBUG
                print("   Found existing record, updating...")
                #endif
                // Update existing record
                existing[fieldDisplayName] = displayName
                existing[fieldIsAnonymous] = isAnonymous ? 1 : 0
                existing[fieldContributionCount] = (existing[fieldContributionCount] as? Int ?? 0) + 1
                existing[fieldLastContributionDate] = Date()
                
                let savedRecord = try await publicDatabase.save(existing)
                #if DEBUG
                print("✅ Updated existing record: \(savedRecord.recordID.recordName)")
                #endif
            } else {
                #if DEBUG
                print("   Creating new record...")
                #endif
                // Create new record
                let record = CKRecord(recordType: recordType)
                record[fieldHashedUserID] = hashedID
                record[fieldDisplayName] = displayName
                record[fieldIsAnonymous] = isAnonymous ? 1 : 0
                record[fieldContributionCount] = 1
                record[fieldFirstContributionDate] = Date()
                record[fieldLastContributionDate] = Date()
                
                let savedRecord = try await publicDatabase.save(record)
                #if DEBUG
                print("✅ Created new record: \(savedRecord.recordID.recordName)")
                print("   Record saved to CloudKit successfully!")
                #endif
            }
            
            // Save opt-in status locally
            UserDefaults.standard.set(true, forKey: "leaderboardOptedIn")
            UserDefaults.standard.set(displayName, forKey: "leaderboardDisplayName")
            UserDefaults.standard.set(isAnonymous, forKey: "leaderboardIsAnonymous")
            
            hasOptedIn = true
            
            #if DEBUG
            print("✅ Successfully opted in to leaderboard")
            print("   Fetching leaderboard data...")
            #endif
            
            await fetchLeaderboard()
            await fetchCurrentUserSupporter()
            
            #if DEBUG
            print("   Current supporters count: \(supporters.count)")
            if let currentUser = currentUserSupporter {
                print("   Your stats: \(currentUser.displayName) - \(currentUser.contributionCount) contributions")
            }
            #endif
            
            return true
        } catch {
            #if DEBUG
            print("❌ Error opting in: \(error)")
            if let ckError = error as? CKError {
                print("   CK Error Code: \(ckError.code.rawValue)")
                print("   CK Error: \(ckError.localizedDescription)")
            }
            #endif
            await MainActor.run {
                self.error = "Failed to join leaderboard: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - Update Contribution Count
    func incrementContribution() async {
        guard hasOptedIn, let hashedID = await hashedUserID() else { return }
        
        do {
            guard let record = await fetchSupporterByHashedID(hashedID) else {
                #if DEBUG
                print("⚠️ No existing record found")
                #endif
                return
            }
            
            let currentCount = record[fieldContributionCount] as? Int ?? 0
            record[fieldContributionCount] = currentCount + 1
            record[fieldLastContributionDate] = Date()
            
            try await publicDatabase.save(record)
            
            #if DEBUG
            print("✅ Incremented contribution count to \(currentCount + 1)")
            #endif
            
            await fetchCurrentUserSupporter()
            await fetchLeaderboard()
        } catch {
            #if DEBUG
            print("❌ Error incrementing contribution: \(error)")
            #endif
        }
    }
    
    // MARK: - Fetch Leaderboard
    func fetchLeaderboard() async {
        isLoading = true
        defer { isLoading = false }
        
        #if DEBUG
        print("🔍 Fetching leaderboard from CloudKit...")
        print("   Container: \(container.containerIdentifier ?? "Unknown")")
        print("   Record Type: \(recordType)")
        #endif
        
        // Use CKQueryOperation for more control and better error handling
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: recordType, predicate: predicate)
            
            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = 50
            
            // Explicitly specify which fields we want (sometimes bypasses indexing issues)
            operation.desiredKeys = [
                fieldDisplayName,
                fieldContributionCount,
                fieldIsAnonymous,
                fieldLastContributionDate,
                fieldHashedUserID
            ]
            
            var fetchedRecords: [CKRecord] = []
            
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    fetchedRecords.append(record)
                    #if DEBUG
                    if let displayName = record[self.fieldDisplayName] as? String,
                       let count = record[self.fieldContributionCount] as? Int {
                        print("   ✅ Fetched: \(displayName) - \(count) contributions")
                    }
                    #endif
                case .failure(let error):
                    #if DEBUG
                    print("⚠️ Error fetching record \(recordID): \(error)")
                    #endif
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    #if DEBUG
                    print("   Query completed successfully, fetched \(fetchedRecords.count) records")
                    #endif
                    
                    let supporters = fetchedRecords.compactMap { self.supporterFromRecord($0) }
                    let sortedSupporters = supporters.sorted { $0.contributionCount > $1.contributionCount }
                    
                    Task { @MainActor in
                        self.supporters = sortedSupporters
                        
                        #if DEBUG
                        if sortedSupporters.isEmpty {
                            print("ℹ️ Leaderboard is empty - no supporters have opted in yet")
                        } else {
                            print("✅ Successfully loaded \(sortedSupporters.count) supporters")
                        }
                        #endif
                    }
                    
                case .failure(let error):
                    #if DEBUG
                    print("❌ Query failed: \(error)")
                    if let ckError = error as? CKError {
                        print("   CK Error Code: \(ckError.code.rawValue)")
                        print("   CK Error: \(ckError.localizedDescription)")
                        
                        // Specific handling for indexing errors
                        if ckError.code == .invalidArguments {
                            print("   ⚠️ INDEXING ERROR DETECTED")
                            print("   This is a known CloudKit Development environment bug.")
                            print("   Solution: Deploy schema to Production environment.")
                        }
                    }
                    #endif
                    
                    Task { @MainActor in
                        self.error = "Failed to load leaderboard"
                    }
                }
                
                continuation.resume()
            }
            
            #if DEBUG
            print("   Starting CKQueryOperation...")
            #endif
            
            publicDatabase.add(operation)
        }
    }
    
    // MARK: - Fetch Current User
    func fetchCurrentUserSupporter() async {
        guard let hashedID = await hashedUserID() else { return }
        
        if let record = await fetchSupporterByHashedID(hashedID) {
            await MainActor.run {
                self.currentUserSupporter = supporterFromRecord(record)
            }
        }
    }
    
    // MARK: - Helper: Fetch by Hashed ID
    private func fetchSupporterByHashedID(_ hashedID: String) async -> CKRecord? {
        #if DEBUG
        print("🔍 Searching for hashedUserID: \(hashedID)")
        #endif
        
        // Use CKQueryOperation for better error handling
        return await withCheckedContinuation { (continuation: CheckedContinuation<CKRecord?, Never>) in
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: recordType, predicate: predicate)
            
            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = 100
            
            // Explicitly specify desired fields
            operation.desiredKeys = [
                fieldHashedUserID,
                fieldDisplayName,
                fieldContributionCount,
                fieldIsAnonymous,
                fieldFirstContributionDate,
                fieldLastContributionDate
            ]
            
            var foundRecord: CKRecord? = nil
            
            operation.recordMatchedBlock = { recordID, result in
                guard foundRecord == nil else { return } // Already found
                
                switch result {
                case .success(let record):
                    // Filter by hashedUserID locally
                    if let recordHashedID = record[self.fieldHashedUserID] as? String,
                       recordHashedID == hashedID {
                        #if DEBUG
                        print("✅ Found existing supporter record (local filter)")
                        #endif
                        foundRecord = record
                    }
                case .failure(let error):
                    #if DEBUG
                    print("⚠️ Error fetching record: \(error)")
                    #endif
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    if foundRecord == nil {
                        #if DEBUG
                        print("ℹ️ No existing record found for this user")
                        #endif
                    }
                case .failure(let error):
                    #if DEBUG
                    print("❌ CloudKit Error: \(error.localizedDescription)")
                    if let ckError = error as? CKError {
                        print("   Error Code: \(ckError.errorCode)")
                        if let serverMessage = ckError.userInfo["ServerErrorDescription"] as? String {
                            print("   Server Message: \(serverMessage)")
                        }
                        
                        // Specific handling for indexing errors
                        if ckError.code == .invalidArguments {
                            print("   ⚠️ INDEXING ERROR - CloudKit Development bug")
                            print("   Workaround: Returning nil to create new record")
                        }
                    }
                    #endif
                    
                    // On error, return nil so calling code can create new record
                    foundRecord = nil
                }
                
                continuation.resume(returning: foundRecord)
            }
            
            publicDatabase.add(operation)
        }
    }
    
    // MARK: - Helper: Convert Record to Supporter
    private func supporterFromRecord(_ record: CKRecord) -> Supporter? {
        guard
            let displayName = record[fieldDisplayName] as? String,
            let contributionCount = record[fieldContributionCount] as? Int,
            let isAnonymous = record[fieldIsAnonymous] as? Int,
            let lastContributionDate = record[fieldLastContributionDate] as? Date
        else {
            #if DEBUG
            print("⚠️ Failed to parse record:")
            print("   displayName: \(record[fieldDisplayName] ?? "nil")")
            print("   contributionCount: \(record[fieldContributionCount] ?? "nil")")
            print("   isAnonymous: \(record[fieldIsAnonymous] ?? "nil")")
            print("   lastContributionDate: \(record[fieldLastContributionDate] ?? "nil")")
            #endif
            return nil
        }
        
        return Supporter(
            id: record.recordID.recordName,
            displayName: displayName,
            contributionCount: contributionCount,
            isAnonymous: isAnonymous == 1,
            lastContributionDate: lastContributionDate
        )
    }
    
    // MARK: - Update Display Name
    func updateDisplayName(_ newName: String, isAnonymous: Bool) async -> Bool {
        guard validateDisplayName(newName), let hashedID = await hashedUserID() else {
            await MainActor.run {
                error = "Invalid display name"
            }
            return false
        }
        
        do {
            guard let record = await fetchSupporterByHashedID(hashedID) else { return false }
            
            record[fieldDisplayName] = newName
            record[fieldIsAnonymous] = isAnonymous ? 1 : 0
            
            try await publicDatabase.save(record)
            
            UserDefaults.standard.set(newName, forKey: "leaderboardDisplayName")
            UserDefaults.standard.set(isAnonymous, forKey: "leaderboardIsAnonymous")
            
            await fetchCurrentUserSupporter()
            await fetchLeaderboard()
            
            return true
        } catch {
            #if DEBUG
            print("❌ Error updating display name: \(error)")
            #endif
            return false
        }
    }
    
    // MARK: - Opt Out (Delete Record)
    func optOut() async -> Bool {
        guard let hashedID = await hashedUserID() else { return false }
        
        do {
            guard let record = await fetchSupporterByHashedID(hashedID) else { return false }
            
            _ = try await publicDatabase.deleteRecord(withID: record.recordID)
            
            // Clear local data
            UserDefaults.standard.removeObject(forKey: "leaderboardOptedIn")
            UserDefaults.standard.removeObject(forKey: "leaderboardDisplayName")
            UserDefaults.standard.removeObject(forKey: "leaderboardIsAnonymous")
            
            hasOptedIn = false
            currentUserSupporter = nil
            
            await fetchLeaderboard()
            
            #if DEBUG
            print("✅ Successfully opted out of leaderboard")
            #endif
            
            return true
        } catch {
            #if DEBUG
            print("❌ Error opting out: \(error)")
            #endif
            return false
        }
    }
    
    // MARK: - Validation
    private func validateDisplayName(_ name: String) -> Bool {
        // Length check
        guard name.count > 0 && name.count <= 20 else { return false }
        
        // Character check (letters, numbers, spaces, underscores)
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet.whitespaces).union(CharacterSet(charactersIn: "_"))
        guard name.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else { return false }
        
        // Basic profanity filter (add more words as needed)
        let lowercaseName = name.lowercased()
        let bannedWords = ["fuck", "shit", "damn", "bitch", "ass", "porn", "sex", "nazi", "hitler"]
        for word in bannedWords {
            if lowercaseName.contains(word) {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Get User Rank
    func getUserRank() -> Int? {
        guard let currentUser = currentUserSupporter else { return nil }
        
        // Sort supporters by contribution count
        let sorted = supporters.sorted { $0.contributionCount > $1.contributionCount }
        
        // Find user's position
        if let index = sorted.firstIndex(where: { $0.id == currentUser.id }) {
            return index + 1 // Rank is 1-based
        }
        
        return nil
    }
}
