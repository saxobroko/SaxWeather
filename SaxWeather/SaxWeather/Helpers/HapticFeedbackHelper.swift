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

    /// `true` when the user has explicitly enabled selection
    /// haptics on toggles / pickers. Gated by the master
    /// `enableHapticFeedback` switch at every call site.
    private var isSelectionHapticEnabled: Bool {
        if UserDefaults.standard.object(forKey: "hapticOnSelection") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "hapticOnSelection")
    }

    private var intensityStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        guard let raw = UserDefaults.standard.string(forKey: "hapticIntensity") else {
            return .medium
        }
        switch raw {
        case "light":  return .light
        case "heavy":  return .heavy
        default:       return .medium
        }
    }

    func light() {
        guard isHapticEnabled else { return }
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch intensityStyle {
        case .light:  style = .light
        case .heavy:  style = .medium
        default:      style = .light
        }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    func medium() {
        guard isHapticEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: intensityStyle)
        generator.impactOccurred()
    }

    func heavy() {
        guard isHapticEnabled else { return }
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch intensityStyle {
        case .light:  style = .medium
        case .heavy:  style = .heavy
        default:      style = .heavy
        }
        let generator = UIImpactFeedbackGenerator(style: style)
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
    
    func selection() {
        guard isHapticEnabled, isSelectionHapticEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
#endif
