//
//  HapticFeedbackHelper.swift
//  SaxWeather
//
//  Created on 13/01/2026
//

#if canImport(UIKit)
import UIKit
import SwiftUI

/// Centralized haptic feedback manager for consistent user feedback throughout the app
class HapticFeedbackHelper {
    static let shared = HapticFeedbackHelper()
    
    private init() {}
    
    /// Check if haptic feedback is enabled in settings
    private var isHapticEnabled: Bool {
        // If the key doesn't exist yet, default to true (enabled)
        if UserDefaults.standard.object(forKey: "enableHapticFeedback") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "enableHapticFeedback")
    }
    
    /// Light impact - for button taps and UI interactions
    func light() {
        guard isHapticEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Medium impact - for refresh actions
    func medium() {
        guard isHapticEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Heavy impact - for important actions
    func heavy() {
        guard isHapticEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    /// Success haptic - for successful operations
    func success() {
        guard isHapticEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Warning haptic - for weather alerts
    func warning() {
        guard isHapticEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    /// Error haptic - for failed operations
    func error() {
        guard isHapticEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    /// Selection haptic - for picker changes
    func selection() {
        guard isHapticEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
#endif
