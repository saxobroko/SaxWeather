//
//  AccentColorHelper.swift
//  SaxWeather
//
//  Created by GitHub Copilot on 2026-01-10
//

import SwiftUI

/// Helper to manage app-wide accent color based on user preference
struct AccentColorHelper {
    /// Convert accent color string to SwiftUI Color
    static func color(from name: String) -> Color {
        switch name.lowercased() {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "teal": return .teal
        case "cyan": return .cyan
        case "indigo": return .indigo
        default: return .blue // Default fallback
        }
    }
}

/// View modifier to apply accent color from AppStorage
struct AccentColorModifier: ViewModifier {
    @AppStorage("accentColor") private var accentColor = "blue"
    
    func body(content: Content) -> some View {
        content
            .tint(AccentColorHelper.color(from: accentColor))
    }
}

extension View {
    /// Apply the user's selected accent color to this view
    func applyAccentColor() -> some View {
        self.modifier(AccentColorModifier())
    }
}
