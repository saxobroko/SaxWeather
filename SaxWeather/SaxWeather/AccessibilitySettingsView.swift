//
//  AccessibilitySettingsView.swift
//  SaxWeather
//
//  Created by saxobroko on 2026-01-18
//

import SwiftUI

struct AccessibilitySettingsView: View {
    // Phase 2 bridge — customisation registry injected at the app
    // root via `.environmentObject`. Every setting write below
    // routes through `.onChange` to the registry.
    @EnvironmentObject private var customisationRegistry: CustomisationRegistry

    /// Whether the view body wraps itself in a `NavigationStack`.
    /// Defaults to `true` so existing `NavigationLink` call sites
    /// keep their nav chrome. Set to `false` when the view is
    /// pushed onto an existing `NavigationStack` via
    /// `.navigationDestination(for:)` — wrapping a second
    /// `NavigationStack` inside the pushed view causes SwiftUI to
    /// flash black during the push transition.
    var wrappedInNavigationStack: Bool = true
    // MARK: - Dynamic Type
    @AppStorage("useSystemTextSize") private var useSystemTextSize = true
    @AppStorage("customTextSizeMultiplier") private var customTextSizeMultiplier = 1.0

    // MARK: - Motion & Animations
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("reduceMotionForce") private var reduceMotionForce = false
    @AppStorage("disableWeatherAnimations") private var disableWeatherAnimations = false

    // MARK: - Visual Enhancements
    @AppStorage("increaseContrast") private var increaseContrast = false
    @AppStorage("highContrastOutline") private var highContrastOutline = false
    @AppStorage("boldText") private var boldText = false

    // MARK: - VoiceOver Support
    @AppStorage("enhancedVoiceOverLabels") private var enhancedVoiceOverLabels = true
    @AppStorage("speakWeatherAlerts") private var speakWeatherAlerts = true

     // MARK: - Haptic Feedback
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    @AppStorage("hapticOnSelection") private var hapticOnSelection = true
    @AppStorage("tapticOnRefresh") private var tapticOnRefresh = true
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        let content = accessibilityForm
        #if os(iOS)
        if wrappedInNavigationStack {
            NavigationStack { content }
        } else {
            content
        }
        #elseif os(macOS)
        ScrollView {
            VStack(spacing: 20) {
                GroupBox(label: Text("Text Size").font(.title3).fontWeight(.semibold)) {
                    textSizeSection
                        .padding()
                }
                GroupBox(label: Text("Motion & Animations").font(.title3).fontWeight(.semibold)) {
                    motionSection
                        .padding()
                }
                GroupBox(label: Text("Visual Enhancements").font(.title3).fontWeight(.semibold)) {
                    visualSection
                        .padding()
                }
                GroupBox(label: Text("VoiceOver").font(.title3).fontWeight(.semibold)) {
                    voiceOverSection
                        .padding()
                }
                GroupBox(label: Text("Haptic Feedback").font(.title3).fontWeight(.semibold)) {
                    hapticSection
                        .padding()
                }
                GroupBox(label: Text("Reset").font(.title3).fontWeight(.semibold)) {
                    resetSection
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Accessibility")
        #endif
    }

    /// The iOS `Form` (and its `.onChange` modifiers) lifted out
    /// of `body` so the wrapping `NavigationStack` is optional.
    /// Returning a single view from a helper keeps the modifier
    /// chain readable and avoids the nested-stack flash that
    /// happens when SwiftUI pushes an inner `NavigationStack`
    /// onto an outer one.
    @ViewBuilder
    private var accessibilityForm: some View {
        #if os(iOS)
        Form {
            textSizeSection
            motionSection
            visualSection
            voiceOverSection
            hapticSection
            extraSection
            resetSection
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
        // Phase 2 bridge — forward every accessibility setting
        // write to the registry.
        .onChange(of: useSystemTextSize) { newValue in
            customisationRegistry.set(\.visual.useSystemTextSize, newValue)
        }
        .onChange(of: customTextSizeMultiplier) { newValue in
            customisationRegistry.set(\.visual.fontScale, newValue)
        }
        .onChange(of: reduceMotion) { newValue in
            customisationRegistry.set(\.accessibility.reduceMotion, newValue)
        }
        .onChange(of: reduceMotionForce) { newValue in
            customisationRegistry.set(\.accessibility.reduceMotionForce, newValue)
        }
        .onChange(of: disableWeatherAnimations) { newValue in
            customisationRegistry.set(\.iconography.disableWeatherAnimations, newValue)
        }
        .onChange(of: increaseContrast) { newValue in
            customisationRegistry.set(\.visual.increaseContrast, newValue)
        }
        .onChange(of: highContrastOutline) { newValue in
            customisationRegistry.set(\.accessibility.highContrastOutline, newValue)
        }
        .onChange(of: boldText) { newValue in
            customisationRegistry.set(\.visual.boldText, newValue)
        }
        .onChange(of: enhancedVoiceOverLabels) { newValue in
            customisationRegistry.set(\.accessibility.enhancedVoiceOverLabels, newValue)
        }
        .onChange(of: speakWeatherAlerts) { newValue in
            customisationRegistry.set(\.behaviour.speakWeatherAlerts, newValue)
        }
        .onChange(of: enableHapticFeedback) { newValue in
            customisationRegistry.set(\.behaviour.enableHapticFeedback, newValue)
        }
        .onChange(of: hapticOnSelection) { newValue in
            customisationRegistry.set(\.accessibility.hapticOnSelection, newValue)
        }
        .onChange(of: tapticOnRefresh) { newValue in
            customisationRegistry.set(\.accessibility.tapticOnRefresh, newValue)
        }
        #else
        EmptyView()
        #endif
    }

    // MARK: - Sections
    
    private var textSizeSection: some View {
        Group {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $useSystemTextSize) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Use System Text Size", systemImage: "textformat.size")
                        Text("Follow system Dynamic Type settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityLabel("Use System Text Size")
                .accessibilityHint("When enabled, text will resize according to your system settings")
                
                if !useSystemTextSize {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Custom Text Size", systemImage: "textformat")
                            Spacer()
                            Text("\(Int(customTextSizeMultiplier * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $customTextSizeMultiplier, in: 0.75...1.5, step: 0.05)
                            .accessibilityLabel("Custom Text Size")
                            .accessibilityValue("\(Int(customTextSizeMultiplier * 100)) percent")
                        
                        HStack {
                            Text("Smaller")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Larger")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var motionSection: some View {
        Group {
            Toggle(isOn: $reduceMotion) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Reduce Motion", systemImage: "gyroscope")
                    Text("Minimize UI animations and transitions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Reduce Motion")
            .accessibilityHint("Reduces animations throughout the app")
            
            Divider()
            
            Toggle(isOn: $disableWeatherAnimations) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Disable Weather Icons", systemImage: "cloud.sun")
                    Text("Use static weather icons instead of animated ones")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Disable Weather Icon Animations")
            .accessibilityHint("Shows static weather icons instead of animated ones")
        }
    }
    
    private var visualSection: some View {
        Group {
            Toggle(isOn: $increaseContrast) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Increase Contrast", systemImage: "circle.lefthalf.filled")
                    Text("Enhance contrast for better readability")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Increase Contrast")
            .accessibilityHint("Makes text and UI elements more distinct")
            
            Divider()
            
            Toggle(isOn: $boldText) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Bold Text", systemImage: "bold")
                    Text("Make all text heavier for improved legibility")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Bold Text")
            .accessibilityHint("Makes all text appear bolder")
        }
    }
    
    private var voiceOverSection: some View {
        Group {
            Toggle(isOn: $enhancedVoiceOverLabels) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Enhanced VoiceOver", systemImage: "speaker.wave.3")
                    Text("Provide detailed descriptions for screen readers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Enhanced VoiceOver Labels")
            .accessibilityHint("Provides more detailed descriptions when using VoiceOver")
            
            Divider()
            
            Toggle(isOn: $speakWeatherAlerts) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Announce Weather Alerts", systemImage: "megaphone")
                    Text("Automatically announce severe weather warnings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Announce Weather Alerts")
            .accessibilityHint("Speaks severe weather alerts when they occur")
        }
    }
    
    private var hapticSection: some View {
        Group {
            #if os(iOS)
            Toggle(isOn: $enableHapticFeedback) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                    Text("Feel touch feedback for actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Note: Pull-to-refresh haptic cannot be disabled (iOS limitation)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .accessibilityLabel("Haptic Feedback")
            .accessibilityHint("Enables vibration feedback for interactions")
            #else
            Text("Haptic feedback is only available on iOS devices")
                .font(.caption)
                .foregroundColor(.secondary)
            #endif
        }
    }
    
    private var autoRefreshSection: some View {
        EmptyView()
    }
    
    /// v2 — extra toggles added in the schema-v2 expansion.
    /// Kept in their own section so the original six sections
    /// stay byte-identical to the pre-v2 file (no merge risk).
    private var extraSection: some View {
        Group {
            Toggle(isOn: $reduceMotionForce) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Force Reduce Motion", systemImage: "tortoise.circle.fill")
                    Text("Always reduce motion, even when the system setting is off.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Divider()
            Toggle(isOn: $highContrastOutline) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("High-Contrast Outline", systemImage: "square.dashed")
                    Text("Add an outline around text for low-vision users.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Divider()
            Toggle(isOn: $hapticOnSelection) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Haptic on Selection", systemImage: "hand.point.up.left.fill")
                    Text("Vibrate when a picker value changes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Divider()
            Toggle(isOn: $tapticOnRefresh) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Taptic on Refresh", systemImage: "arrow.triangle.2.circlepath")
                    Text("Pulse the taptic engine when weather data refreshes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var resetSection: some View {
        Group {
            Button(role: .destructive) {
                resetToDefaults()
            } label: {
                HStack {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                    Spacer()
                }
            }
            .accessibilityLabel("Reset Accessibility Settings to Defaults")
            .accessibilityHint("Resets all accessibility preferences to their default values")
        }
    }
    
    // MARK: - Actions
    
    private func resetToDefaults() {
        useSystemTextSize = true
        customTextSizeMultiplier = 1.0
        reduceMotion = false
        disableWeatherAnimations = false
        increaseContrast = false
        boldText = false
        enhancedVoiceOverLabels = true
        speakWeatherAlerts = false
        enableHapticFeedback = true
    }
}

#Preview {
    AccessibilitySettingsView()
}
