//
//  KeychainService.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-03-10
//  Last modified: 2025-03-10 11:10:16 UTC
//

import Foundation
import KeychainSwift
import os.log

class KeychainService {
    static let shared = KeychainService()
    let keychain = KeychainSwift()
    private let apiKeyPrefix = "com.saxobroko.saxweather."
    private let logger = Logger(subsystem: "com.saxobroko.saxweather", category: "KeychainService")
    
    private init() {
        logger.debug("Initializing KeychainService")
        keychain.synchronizable = true  // Enable keychain synchronization across devices
        
        // Test keychain access
        let testKey = "keychain_access_test"
        let testValue = "test_value"
        
        if keychain.set(testValue, forKey: testKey) {
            logger.debug("✅ Successfully accessed keychain")
            if let retrieved = keychain.get(testKey) {
                keychain.delete(testKey)
                logger.debug("✅ Keychain read/write test successful")
            } else {
                logger.error("❌ Failed to read from keychain")
            }
        } else {
            logger.error("❌ Failed to write to keychain")
            logger.error("Last error code: \(self.keychain.lastResultCode)")
        }
    }
    
    // MARK: - API Keys
    
    func saveApiKey(_ key: String, forService service: String) -> Bool {
        logger.debug("Attempting to save API key for service: \(service)")
        let success = keychain.set(key, forKey: apiKeyPrefix + service)
        
        if success {
            logger.debug("Successfully saved API key for service: \(service)")
        } else {
            logger.error("Failed to save API key for service: \(service). Status: \(self.keychain.lastResultCode)")
        }
        
        // Verify the save
        if let savedKey = getApiKey(forService: service) {
            let matches = savedKey == key
            logger.debug("Verification check - Key matches: \(matches)")
            return matches
        }
        
        return false
    }
    
    func getApiKey(forService service: String) -> String? {
        logger.debug("Retrieving API key for service: \(service)")
        let fullKey = apiKeyPrefix + service
        
        if let key = keychain.get(fullKey) {
            logger.debug("Successfully retrieved API key for service: \(service)")
            return key
        } else {
            logger.debug("No API key found for service: \(service)")
            logger.debug("Keychain status code: \(self.keychain.lastResultCode)")
            return nil
        }
    }
    
    func deleteApiKey(forService service: String) -> Bool {
        logger.debug("Attempting to delete API key for service: \(service)")
        let success = keychain.delete(apiKeyPrefix + service)
        
        if success {
            logger.debug("Successfully deleted API key for service: \(service)")
        } else {
            logger.error("Failed to delete API key for service: \(service). Status: \(self.keychain.lastResultCode)")
        }
        
        return success
    }
    
    // MARK: - Migration from UserDefaults
    
    func migrateApiKeysFromUserDefaults() {
        logger.debug("Starting API key migration from UserDefaults")
        let defaults = UserDefaults.standard
        
        // Migrate Weather Underground API key
        if let wuApiKey = defaults.string(forKey: "wuApiKey") {
            logger.debug("Found WU API key in UserDefaults: \(wuApiKey.isEmpty ? "empty" : "not empty")")
            
            if !wuApiKey.isEmpty {
                let fullKey = apiKeyPrefix + "wu"
                logger.debug("Attempting to save WU key with full key: \(fullKey)")
                
                if keychain.set(wuApiKey, forKey: fullKey) {
                    logger.debug("Successfully saved WU key to keychain")
                    defaults.removeObject(forKey: "wuApiKey")
                    defaults.synchronize()
                    
                    // Verify the save
                    if let savedKey = keychain.get(fullKey) {
                        logger.debug("Verified WU key in keychain matches: \(savedKey == wuApiKey)")
                    } else {
                        logger.error("Failed to verify WU key in keychain after save")
                    }
                } else {
                    logger.error("Failed to save WU key to keychain. Status: \(self.keychain.lastResultCode)")
                }
            }
        }
        
        // Migrate OpenWeatherMap API key
        if let owmApiKey = defaults.string(forKey: "owmApiKey") {
            logger.debug("Found OWM API key in UserDefaults: \(owmApiKey.isEmpty ? "empty" : "not empty")")
            
            if !owmApiKey.isEmpty {
                let fullKey = apiKeyPrefix + "owm"
                logger.debug("Attempting to save OWM key with full key: \(fullKey)")
                
                if keychain.set(owmApiKey, forKey: fullKey) {
                    logger.debug("Successfully saved OWM key to keychain")
                    defaults.removeObject(forKey: "owmApiKey")
                    defaults.synchronize()
                    
                    // Verify the save
                    if let savedKey = keychain.get(fullKey) {
                        logger.debug("Verified OWM key in keychain matches: \(savedKey == owmApiKey)")
                    } else {
                        logger.error("Failed to verify OWM key in keychain after save")
                    }
                } else {
                    logger.error("Failed to save OWM key to keychain. Status: \(self.keychain.lastResultCode)")
                }
            }
        }
        
        // Force UserDefaults to sync and verify removal
        defaults.synchronize()
        
        // Verify final state
        let wuStillInDefaults = defaults.string(forKey: "wuApiKey") != nil
        let owmStillInDefaults = defaults.string(forKey: "owmApiKey") != nil
        logger.debug("Final verification - Keys in UserDefaults: WU: \(wuStillInDefaults), OWM: \(owmStillInDefaults)")
        
        // Verify keychain state
        let wuInKeychain = keychain.get(apiKeyPrefix + "wu") != nil
        let owmInKeychain = keychain.get(apiKeyPrefix + "owm") != nil
        logger.debug("Final verification - Keys in Keychain: WU: \(wuInKeychain), OWM: \(owmInKeychain)")
    }
    
    // MARK: - Debug Helpers
    
    func verifyKeychainAccess() -> (canWrite: Bool, canRead: Bool, canDelete: Bool) {
        let testKey = "keychain_test"
        let testValue = "test_value"
        
        // Test writing
        let canWrite = keychain.set(testValue, forKey: testKey)
        
        // Test reading
        let canRead = keychain.get(testKey) != nil
        
        // Test deleting
        let canDelete = keychain.delete(testKey)
        
        return (canWrite, canRead, canDelete)
    }
    
    func getAllStoredKeys() -> [String] {
        // This is a helper method to list all keys with our prefix
        // Note: KeychainSwift doesn't provide direct access to all keys
        // This is just for known services
        let services = ["wu", "owm"]
        return services.compactMap { service in
            let key = apiKeyPrefix + service
            return keychain.get(key) != nil ? key : nil
        }
    }
}
