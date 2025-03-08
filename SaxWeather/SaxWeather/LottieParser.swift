//
//  LottieParser.swift
//  SaxWeather
//
//  Created by Saxon on 8/3/2025.
//


import Foundation
import Lottie
import SwiftUI

class LottieParser {
    static func loadAnimation(named: String) -> LottieAnimation? {
        // First try to load directly using Lottie's built-in methods
        if let animation = LottieAnimation.named(named) {
            print("✅ Loaded via Lottie.named()")
            return animation
        }
        
        // Next, try to load from JSON with lottie extension
        if let url = Bundle.main.url(forResource: named, withExtension: "lottie") {
            do {
                // Read file data
                let data = try Data(contentsOf: url)
                
                // Check if it's actually a JSON file with .lottie extension
                if let jsonString = String(data: data, encoding: .utf8),
                   jsonString.contains("\"v\"") && 
                   (jsonString.contains("\"layers\"") || jsonString.contains("\"assets\"")) {
                    
                    // It's JSON data with .lottie extension - parse it as JSON
                    if let animation = try? LottieAnimation.from(data: data) {
                        print("✅ Parsed \(named).lottie as JSON")
                        return animation
                    }
                }
                
                // If not parseable as JSON, it might be a .lottie zip file
                // But this requires specific handling or conversion
            } catch {
                print("❌ Error loading \(named).lottie: \(error.localizedDescription)")
            }
        }
        
        // Try with .json extension as fallback
        if let url = Bundle.main.url(forResource: named, withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let animation = try LottieAnimation.from(data: data)
                print("✅ Loaded from \(named).json")
                return animation
            } catch {
                print("❌ Error loading \(named).json: \(error.localizedDescription)")
            }
        }
        
        // Try with hyphens/underscores variations
        let alternateNamed = named.contains("-") ? 
            named.replacingOccurrences(of: "-", with: "_") : 
            named.replacingOccurrences(of: "_", with: "-")
        
        if let url = Bundle.main.url(forResource: alternateNamed, withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let animation = try LottieAnimation.from(data: data)
                print("✅ Loaded from alternate name: \(alternateNamed).json")
                return animation
            } catch {
                print("❌ Error with alternate name: \(error.localizedDescription)")
            }
        }
        
        print("❌ Failed to load animation: \(named)")
        return nil
    }
}