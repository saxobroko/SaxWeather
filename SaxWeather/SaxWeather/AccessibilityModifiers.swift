//
//  AccessibilityModifiers.swift
//  SaxWeather
//
//  Created by saxobroko on 2026-01-18
//

import SwiftUI

// MARK: - Custom Font Size Modifier
struct CustomFontSizeModifier: ViewModifier {
    @AppStorage("useSystemTextSize") private var useSystemTextSize = true
    @AppStorage("customTextSizeMultiplier") private var customTextSizeMultiplier = 1.0
    @AppStorage("boldText") private var boldText = false
    
    let baseSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    
    func body(content: Content) -> some View {
        let size = useSystemTextSize ? baseSize : baseSize * customTextSizeMultiplier
        let fontWeight = boldText ? .bold : weight

        // Debug logging (only in debug builds to avoid console spam on every text re-render)
        #if DEBUG
        let _ = print("📝 Font - Base: \(baseSize), Multiplier: \(customTextSizeMultiplier), Final: \(size), Bold: \(boldText)")
        #endif

        return content
            .font(.system(size: size, weight: fontWeight, design: design))
    }
}

extension View {
    func accessibleFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        self.modifier(CustomFontSizeModifier(baseSize: size, weight: weight, design: design))
    }
}

// MARK: - Animation Modifier
struct AccessibleAnimationModifier<V: Equatable>: ViewModifier {
    @AppStorage("reduceMotion") private var reduceMotion = false
    
    let animation: Animation
    let value: V
    
    func body(content: Content) -> some View {
        if reduceMotion {
            return content.animation(nil, value: value)
        } else {
            return content.animation(animation, value: value)
        }
    }
}

extension View {
    func accessibleAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        self.modifier(AccessibleAnimationModifier(animation: animation, value: value))
    }
}

// MARK: - Transition Modifier
struct AccessibleTransitionModifier: ViewModifier {
    @AppStorage("reduceMotion") private var reduceMotion = false
    
    let transition: AnyTransition
    
    func body(content: Content) -> some View {
        if reduceMotion {
            return AnyView(content.transition(.identity))
        } else {
            return AnyView(content.transition(transition))
        }
    }
}

extension View {
    func accessibleTransition(_ transition: AnyTransition) -> some View {
        self.modifier(AccessibleTransitionModifier(transition: transition))
    }
}

// MARK: - Card Appearance Animation
extension AnyTransition {
    /// Standard fade + scale insert used for weather cards app-wide.
    static var cardAppearance: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.92)),
            removal: .opacity
        )
    }
}

extension Animation {
    static var cardAppearance: Animation {
        .easeInOut(duration: 0.4)
    }
}

extension View {
    /// Applies the standard card appearance transition, respecting Reduce Motion.
    func cardAppearanceTransition() -> some View {
        accessibleTransition(.cardAppearance)
    }

    /// Standard timing for grouped card appearance animations.
    func cardAppearanceAnimation<V: Equatable>(value: V) -> some View {
        accessibleAnimation(.cardAppearance, value: value)
    }
}

// MARK: - Contrast Modifier
struct ContrastModifier: ViewModifier {
    @AppStorage("increaseContrast") private var increaseContrast = false
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        #if DEBUG
        let _ = print("🎨 Contrast Modifier - Enabled: \(increaseContrast), ColorScheme: \(colorScheme == .dark ? "dark" : "light")")
        #endif

        Group {
            if increaseContrast {
                content
                    // Multiple layered shadows for strong outline effect
                    .shadow(color: colorScheme == .dark ? Color.black : Color.black.opacity(0.8), radius: 3, x: 0, y: 2)
                    .shadow(color: colorScheme == .dark ? Color.black : Color.black.opacity(0.6), radius: 2, x: 0, y: 1)
                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.4), radius: 1, x: 0, y: 0)
                    // Stronger brightness adjustment for visibility
                    .brightness(colorScheme == .dark ? 0.1 : -0.1)
                    .contrast(1.1) // Increase overall contrast
            } else {
                content
            }
        }
    }
}

extension View {
    func accessibleContrast() -> some View {
        self.modifier(ContrastModifier())
    }
}

// MARK: - Enhanced VoiceOver Label
extension View {
    func enhancedAccessibilityLabel(_ label: String, hint: String? = nil, value: String? = nil) -> some View {
        @AppStorage("enhancedVoiceOverLabels") var enhancedVoiceOverLabels = true
        
        return self
            .accessibilityLabel(label)
            .if(enhancedVoiceOverLabels && hint != nil) { view in
                view.accessibilityHint(hint!)
            }
            .if(value != nil) { view in
                view.accessibilityValue(value!)
            }
    }
}

// MARK: - Conditional View Modifier
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Note
// HapticFeedbackHelper is defined in Helpers/HapticFeedbackHelper.swift
// and is already available throughout the app.
