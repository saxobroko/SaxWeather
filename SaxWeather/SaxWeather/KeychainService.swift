//
//  KeychainService.swift
//  SaxWeather
//
//  Created by Saxon on 8/3/2025.
//


//
//  KeychainService.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-03-08
//

import Foundation
import KeychainSwift

class KeychainService {
    static let shared = KeychainService()
    private let keychain = KeychainSwift()
    private let apiKeyPrefix = "com.saxobroko.saxweather."
    
    private init() {
        // Set default access type to ensure keys are available while app is running
        keychain.accessGroup = nil
        keychain.synchronizable = false
    }
    
    // MARK: - API Keys
    
    func saveApiKey(_ key: String, forService service: String) {
        keychain.set(key, forKey: apiKeyPrefix + service)
    }
    
    func getApiKey(forService service: String) -> String? {
        return keychain.get(apiKeyPrefix + service)
    }
    
    func deleteApiKey(forService service: String) -> Bool {
        return keychain.delete(apiKeyPrefix + service)
    }
    
    // MARK: - Migration from UserDefaults
    
    func migrateApiKeysFromUserDefaults() {
        let defaults = UserDefaults.standard
        
        // Migrate Weather Underground API key
        if let wuApiKey = defaults.string(forKey: "wuApiKey"), !wuApiKey.isEmpty {
            saveApiKey(wuApiKey, forService: "wu")
            // Optionally clear from UserDefaults after migration
            // defaults.removeObject(forKey: "wuApiKey")
        }
        
        // Migrate OpenWeatherMap API key
        if let owmApiKey = defaults.string(forKey: "owmApiKey"), !owmApiKey.isEmpty {
            saveApiKey(owmApiKey, forService: "owm") 
            // defaults.removeObject(forKey: "owmApiKey")
        }
        
        // Add other API keys as needed
    }
}